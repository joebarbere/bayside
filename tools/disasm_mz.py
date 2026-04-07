#!/usr/bin/env python3
"""
disasm_mz.py -- MZ DOS executable disassembler for DeskMate reverse engineering

Parses MZ header (with DM89 extension), applies relocations, disassembles
16-bit real-mode code using Capstone with recursive descent from entry point,
resolves call/jump targets to labels, identifies strings, and generates a
call graph.

Usage:
    python3 disasm_mz.py <exe_file> -o <output.asm> [--callgraph <callgraph.txt>]

Reusable for all DeskMate binaries: .EXE, .PDM, .RES, .ACC
"""

import argparse
import struct
import sys
from collections import defaultdict, deque
from capstone import (Cs, CS_ARCH_X86, CS_MODE_16,
                      CS_GRP_CALL, CS_GRP_JUMP, CS_GRP_RET, CS_GRP_INT,
                      CS_OP_IMM)


# ---------------------------------------------------------------------------
# MZ header parsing
# ---------------------------------------------------------------------------

class MZHeader:
    """Standard DOS MZ executable header."""

    def __init__(self, data):
        if len(data) < 28 or data[0:2] not in (b'MZ', b'ZM'):
            raise ValueError("Not a valid MZ executable")

        (self.signature,
         self.last_page_bytes,
         self.pages,
         self.num_relocs,
         self.header_paragraphs,
         self.min_alloc,
         self.max_alloc,
         self.init_ss,
         self.init_sp,
         self.checksum,
         self.init_ip,
         self.init_cs,
         self.reloc_offset,
         self.overlay_num) = struct.unpack_from('<2sHHHHHHHHHHHHH', data, 0)

        self.header_size = self.header_paragraphs * 16

        if self.pages == 0:
            self.image_size = 0
        else:
            self.image_size = (self.pages - 1) * 512
            if self.last_page_bytes > 0:
                self.image_size += self.last_page_bytes
            else:
                self.image_size += 512
        self.code_size = self.image_size - self.header_size

        self.dm89 = None
        if len(data) >= 0x20 and data[0x1C:0x20] == b'DM89':
            self.dm89 = DM89Header(data)

    def read_relocations(self, data):
        relocs = []
        for i in range(self.num_relocs):
            off = self.reloc_offset + i * 4
            if off + 4 > len(data):
                break
            r_off, r_seg = struct.unpack_from('<HH', data, off)
            relocs.append((r_seg, r_off))
        return relocs


class DM89Header:
    def __init__(self, data):
        self.magic = data[0x1C:0x20]
        self.raw = data[0x1C:min(0x3E, len(data))]


# ---------------------------------------------------------------------------
# Segment and relocation tracking
# ---------------------------------------------------------------------------

class SegmentMap:
    def __init__(self, mz, data):
        self.mz = mz
        self.data = data
        self.header_size = mz.header_size

        self.relocations = mz.read_relocations(data)
        self.reloc_file_offsets = set()
        self.segment_values = set()

        for r_seg, r_off in self.relocations:
            file_off = self.header_size + r_seg * 16 + r_off
            if file_off + 1 < len(data):
                seg_val = struct.unpack_from('<H', data, file_off)[0]
                self.segment_values.add(seg_val)
                self.reloc_file_offsets.add(file_off)

        # Always include base segment, entry CS, SS, and reloc location segments
        self.segment_values.add(0)
        self.segment_values.add(mz.init_cs)
        self.segment_values.add(mz.init_ss)
        for r_seg, _ in self.relocations:
            self.segment_values.add(r_seg)

        self.segments = sorted(self.segment_values)

        max_file_para = (len(data) - self.header_size + 15) // 16
        self.file_segments = [s for s in self.segments if s < max_file_para]
        self.bss_segments = [s for s in self.segments if s >= max_file_para]

    def seg_to_file_offset(self, seg, off=0):
        return self.header_size + seg * 16 + off

    def file_offset_to_seg(self, file_off):
        linear = file_off - self.header_size
        best_seg = 0
        for s in self.file_segments:
            if s * 16 <= linear:
                best_seg = s
            else:
                break
        return best_seg, linear - best_seg * 16

    def is_relocation(self, file_off):
        return file_off in self.reloc_file_offsets


# ---------------------------------------------------------------------------
# String detection
# ---------------------------------------------------------------------------

def find_strings(data, start, end, min_len=4):
    strings = {}
    current = b""
    current_start = 0
    for i in range(start, min(end, len(data))):
        b = data[i]
        if 0x20 <= b < 0x7F or b in (0x0A, 0x0D, 0x09):
            if not current:
                current_start = i
            current += bytes([b])
        else:
            if len(current) >= min_len:
                strings[current_start] = current
            current = b""
    if len(current) >= min_len:
        strings[current_start] = current
    return strings


def escape_bytes(raw):
    result = ""
    for b in (raw if isinstance(raw, (bytes, bytearray)) else raw.encode()):
        if b == 0x0A:
            result += "\\n"
        elif b == 0x0D:
            result += "\\r"
        elif b == 0x09:
            result += "\\t"
        elif 0x20 <= b < 0x7F:
            result += chr(b)
        else:
            result += f"\\x{b:02X}"
    return result


# ---------------------------------------------------------------------------
# DOS INT annotation database
# ---------------------------------------------------------------------------

INT_ANNOTATIONS = {
    (0x10, 0x00): "Set video mode",
    (0x10, 0x01): "Set cursor shape",
    (0x10, 0x02): "Set cursor position",
    (0x10, 0x03): "Get cursor position",
    (0x10, 0x05): "Set active page",
    (0x10, 0x06): "Scroll up",
    (0x10, 0x07): "Scroll down",
    (0x10, 0x08): "Read char/attr at cursor",
    (0x10, 0x09): "Write char/attr at cursor",
    (0x10, 0x0A): "Write char at cursor",
    (0x10, 0x0B): "Set color palette",
    (0x10, 0x0C): "Write pixel",
    (0x10, 0x0D): "Read pixel",
    (0x10, 0x0E): "Write char (teletype)",
    (0x10, 0x0F): "Get video mode",
    (0x10, 0x10): "Set palette registers",
    (0x10, 0x11): "Character generator",
    (0x10, 0x12): "Alternate select",
    (0x10, 0x13): "Write string",
    (0x16, 0x00): "Read keyboard char",
    (0x16, 0x01): "Check keyboard buffer",
    (0x16, 0x02): "Get shift flags",
    (0x13, 0x00): "Reset disk",
    (0x13, 0x02): "Read sectors",
    (0x13, 0x03): "Write sectors",
    (0x21, 0x00): "Terminate program",
    (0x21, 0x01): "Read char with echo",
    (0x21, 0x02): "Write char",
    (0x21, 0x06): "Direct console I/O",
    (0x21, 0x07): "Direct char input",
    (0x21, 0x08): "Read char without echo",
    (0x21, 0x09): "Print string (DS:DX)",
    (0x21, 0x0A): "Buffered input",
    (0x21, 0x0B): "Check input status",
    (0x21, 0x0C): "Flush & read",
    (0x21, 0x19): "Get default drive",
    (0x21, 0x1A): "Set DTA",
    (0x21, 0x25): "Set interrupt vector",
    (0x21, 0x2A): "Get date",
    (0x21, 0x2C): "Get time",
    (0x21, 0x2F): "Get DTA",
    (0x21, 0x30): "Get DOS version",
    (0x21, 0x31): "TSR (keep process)",
    (0x21, 0x33): "Get/set break flag",
    (0x21, 0x35): "Get interrupt vector",
    (0x21, 0x36): "Get disk free space",
    (0x21, 0x38): "Get/set country info",
    (0x21, 0x39): "Create directory",
    (0x21, 0x3A): "Remove directory",
    (0x21, 0x3B): "Change directory",
    (0x21, 0x3C): "Create file",
    (0x21, 0x3D): "Open file",
    (0x21, 0x3E): "Close file",
    (0x21, 0x3F): "Read file",
    (0x21, 0x40): "Write file",
    (0x21, 0x41): "Delete file",
    (0x21, 0x42): "Seek (lseek)",
    (0x21, 0x43): "Get/set file attributes",
    (0x21, 0x44): "IOCTL",
    (0x21, 0x45): "Duplicate handle",
    (0x21, 0x46): "Force duplicate handle",
    (0x21, 0x47): "Get current directory",
    (0x21, 0x48): "Allocate memory",
    (0x21, 0x49): "Free memory",
    (0x21, 0x4A): "Resize memory block",
    (0x21, 0x4B): "EXEC (load/execute)",
    (0x21, 0x4C): "Exit with return code",
    (0x21, 0x4D): "Get return code",
    (0x21, 0x4E): "Find first file",
    (0x21, 0x4F): "Find next file",
    (0x21, 0x50): "Set PSP",
    (0x21, 0x51): "Get PSP",
    (0x21, 0x56): "Rename file",
    (0x21, 0x57): "Get/set file date/time",
    (0x21, 0x59): "Get extended error",
    (0x21, 0x5A): "Create temp file",
    (0x21, 0x5B): "Create new file",
    (0x21, 0x62): "Get PSP address",
}


# ---------------------------------------------------------------------------
# Disassembler
# ---------------------------------------------------------------------------

class MZDisassembler:
    """
    Disassemble an MZ DOS executable using recursive descent from entry point,
    with fallback linear sweep to catch unreachable code.
    """

    def __init__(self, filepath):
        with open(filepath, 'rb') as f:
            self.data = f.read()
        self.filepath = filepath
        self.mz = MZHeader(self.data)
        self.segmap = SegmentMap(self.mz, self.data)

        self.md = Cs(CS_ARCH_X86, CS_MODE_16)
        self.md.detail = True

        self.instructions = {}
        self.code_bytes = set()
        self.call_targets = defaultdict(set)
        self.jump_targets = set()
        self.labels = {}
        self.strings = {}
        self.int_calls = defaultdict(list)
        self.file_end = min(self.mz.image_size, len(self.data))

    def analyze(self):
        self._find_strings()
        self._recursive_descent()
        self._linear_sweep_gaps()
        self._filter_strings()
        self._assign_labels()

    def _find_strings(self):
        self.strings = find_strings(self.data, self.mz.header_size,
                                    self.file_end, min_len=4)

    def _recursive_descent(self):
        entry_off = self.segmap.seg_to_file_offset(
            self.mz.init_cs, self.mz.init_ip)
        queue = deque()
        queue.append((entry_off, self.mz.init_cs))
        self._visited_starts = set()
        self._visited_starts.add(entry_off)
        while queue:
            start_off, seg_val = queue.popleft()
            self._disasm_block(start_off, seg_val, queue)

    def _disasm_block(self, start_off, seg_val, queue):
        if start_off < self.mz.header_size or start_off >= self.file_end:
            return
        if start_off in self.code_bytes:
            return

        seg_base_file = self.mz.header_size + seg_val * 16
        ip = start_off - seg_base_file
        if ip < 0:
            seg_val, ip = self.segmap.file_offset_to_seg(start_off)
            seg_base_file = self.mz.header_size + seg_val * 16

        max_bytes = self.file_end - start_off
        code = self.data[start_off:start_off + max_bytes]

        for insn in self.md.disasm(code, ip):
            file_off = seg_base_file + insn.address
            if file_off in self.code_bytes:
                break
            if file_off >= self.file_end:
                break

            self.instructions[file_off] = (insn, seg_val)
            for i in range(insn.size):
                self.code_bytes.add(file_off + i)

            if CS_GRP_INT in insn.groups:
                self._record_int(insn, file_off, seg_val)

            is_call = CS_GRP_CALL in insn.groups
            is_jump = CS_GRP_JUMP in insn.groups

            if is_call or is_jump:
                target = self._resolve_target(insn, seg_val, file_off)
                if target is not None:
                    if is_call:
                        self.call_targets[target].add(file_off)
                    else:
                        self.jump_targets.add(target)
                    if target not in self._visited_starts:
                        self._visited_starts.add(target)
                        t_seg = seg_val
                        if insn.mnemonic in ('lcall', 'ljmp', 'callf', 'jmpf'):
                            parts = insn.op_str.split(':')
                            if len(parts) == 2:
                                try:
                                    t_seg = int(parts[0], 0)
                                except ValueError:
                                    pass
                        queue.append((target, t_seg))

            if CS_GRP_RET in insn.groups:
                break
            if is_jump and not is_call:
                mnem = insn.mnemonic.lower()
                if mnem in ('jmp', 'ljmp', 'jmpf'):
                    break
            if insn.mnemonic.lower() in ('iret', 'iretd'):
                break

    def _linear_sweep_gaps(self):
        string_offsets = set()
        for soff, sbytes in self.strings.items():
            for i in range(len(sbytes)):
                string_offsets.add(soff + i)

        for seg_val in self.segmap.file_segments:
            seg_start = self.segmap.seg_to_file_offset(seg_val)
            seg_idx = self.segmap.file_segments.index(seg_val)
            if seg_idx + 1 < len(self.segmap.file_segments):
                seg_end = self.segmap.seg_to_file_offset(
                    self.segmap.file_segments[seg_idx + 1])
            else:
                seg_end = self.file_end
            seg_end = min(seg_end, self.file_end)

            offset = seg_start
            while offset < seg_end:
                if offset in self.code_bytes or offset in string_offsets:
                    offset += 1
                    continue

                prologue = False
                if offset + 3 <= seg_end:
                    b0 = self.data[offset]
                    b1 = self.data[offset + 1]
                    b2 = self.data[offset + 2]
                    if b0 == 0x55 and ((b1 == 0x8B and b2 == 0xEC) or
                                        (b1 == 0x89 and b2 == 0xE5)):
                        prologue = True

                if prologue:
                    q = deque()
                    q.append((offset, seg_val))
                    if offset not in self._visited_starts:
                        self._visited_starts.add(offset)
                    while q:
                        so, sv = q.popleft()
                        self._disasm_block(so, sv, q)
                offset += 1

    def _filter_strings(self):
        """Remove false-positive strings that overlap with disassembled code."""
        to_remove = []
        for soff, sbytes in self.strings.items():
            # Check if any byte of this string is inside code
            for i in range(len(sbytes)):
                if (soff + i) in self.code_bytes:
                    to_remove.append(soff)
                    break
        for soff in to_remove:
            del self.strings[soff]

    def _resolve_target(self, insn, seg_val, file_off):
        if not insn.operands:
            return None
        op = insn.operands[0]
        if op.type == CS_OP_IMM:
            target_ip = op.imm & 0xFFFF
            target_file = self.mz.header_size + seg_val * 16 + target_ip
            if self.mz.header_size <= target_file < self.file_end:
                return target_file
            return None
        if insn.mnemonic in ('lcall', 'ljmp', 'callf', 'jmpf'):
            parts = insn.op_str.split(':')
            if len(parts) == 2:
                try:
                    far_seg = int(parts[0], 0)
                    far_off = int(parts[1], 0)
                    target_file = (self.mz.header_size
                                   + far_seg * 16 + far_off)
                    if self.mz.header_size <= target_file < self.file_end:
                        return target_file
                except ValueError:
                    pass
        return None

    def _record_int(self, insn, file_off, seg_val):
        try:
            int_num = int(insn.op_str, 0)
        except (ValueError, TypeError):
            return
        ah_val = self._find_ah_before(file_off, seg_val)
        self.int_calls[(int_num, ah_val)].append(file_off)

    def _find_ah_before(self, file_off, seg_val):
        search = sorted(
            [o for o in self.instructions
             if o < file_off and o > file_off - 30],
            reverse=True)
        for off in search[:8]:
            ins, _ = self.instructions[off]
            if ins.mnemonic == 'mov':
                parts = ins.op_str.split(',')
                if len(parts) == 2:
                    dest = parts[0].strip()
                    src = parts[1].strip()
                    try:
                        if dest == 'ah':
                            return int(src, 0) & 0xFF
                        if dest == 'ax':
                            return (int(src, 0) >> 8) & 0xFF
                    except ValueError:
                        pass
        return None

    def _assign_labels(self):
        entry_off = self.segmap.seg_to_file_offset(
            self.mz.init_cs, self.mz.init_ip)
        self.labels[entry_off] = "entry_point"

        for target in sorted(self.call_targets.keys()):
            if target not in self.labels:
                seg, off = self.segmap.file_offset_to_seg(target)
                self.labels[target] = f"sub_{seg:04X}_{off:04X}"

        for target in sorted(self.jump_targets):
            if target not in self.labels:
                seg, off = self.segmap.file_offset_to_seg(target)
                self.labels[target] = f"loc_{seg:04X}_{off:04X}"

    def _find_containing_function(self, file_off):
        func_starts = set(self.call_targets.keys())
        entry = self.segmap.seg_to_file_offset(
            self.mz.init_cs, self.mz.init_ip)
        func_starts.add(entry)
        best = None
        best_off = -1
        for fs in func_starts:
            if fs <= file_off and fs > best_off:
                best_off = fs
                best = self.labels.get(fs, f"func_{fs:04X}")
        return best

    # ------------------------------------------------------------------
    # Output
    # ------------------------------------------------------------------

    def format_output(self):
        lines = []
        self._emit_header(lines)
        self._emit_segments(lines)
        return "\n".join(lines)

    def _emit_header(self, lines):
        lines.append("; " + "=" * 72)
        lines.append(f"; Disassembly of {self.filepath}")
        lines.append("; Generated by disasm_mz.py (Bayside project)")
        lines.append("; " + "=" * 72)
        lines.append("")
        lines.append("; MZ Header:")
        lines.append(f";   File size:        {len(self.data)} bytes")
        lines.append(f";   Header size:      {self.mz.header_size} bytes")
        lines.append(f";   Code size:        {self.mz.code_size} bytes")
        lines.append(f";   Pages:            {self.mz.pages}")
        lines.append(f";   Relocations:      {self.mz.num_relocs}")
        lines.append(f";   Entry point:      "
                     f"{self.mz.init_cs:04X}:{self.mz.init_ip:04X}")
        lines.append(f";   Init SS:SP:       "
                     f"{self.mz.init_ss:04X}:{self.mz.init_sp:04X}")
        lines.append(f";   Min alloc:        "
                     f"0x{self.mz.min_alloc:04X} paragraphs")
        lines.append(f";   Max alloc:        "
                     f"0x{self.mz.max_alloc:04X} paragraphs")
        if self.mz.dm89:
            lines.append(f";   DM89 signature:   present")
            lines.append(f";   DM89 raw:         {self.mz.dm89.raw.hex()}")
        lines.append("")

        lines.append("; Segment Map:")
        for seg in self.segmap.segments:
            foff = self.segmap.seg_to_file_offset(seg)
            kind = ("CODE/DATA" if seg in self.segmap.file_segments
                    else "BSS")
            lines.append(f";   seg_{seg:04X}  file=0x{foff:04X}  ({kind})")
        lines.append("")

        lines.append(f"; Relocation Table ({self.mz.num_relocs} entries):")
        for r_seg, r_off in self.segmap.relocations:
            foff = self.mz.header_size + r_seg * 16 + r_off
            if foff + 1 < len(self.data):
                val = struct.unpack_from('<H', self.data, foff)[0]
                lines.append(f";   {r_seg:04X}:{r_off:04X}  file=0x{foff:04X}"
                             f"  value=seg_{val:04X}")
        lines.append("")

        if self.strings:
            lines.append("; String Table:")
            for off in sorted(self.strings.keys()):
                seg, soff = self.segmap.file_offset_to_seg(off)
                s = escape_bytes(self.strings[off])
                if len(s) > 64:
                    s = s[:64] + "..."
                lines.append(
                    f';   {seg:04X}:{soff:04X} (0x{off:04X}): "{s}"')
            lines.append("")

        lines.append(f"; Analysis Summary:")
        lines.append(f";   Instructions:     {len(self.instructions)}")
        lines.append(f";   Functions (CALL): {len(self.call_targets)}")
        lines.append(f";   Jump targets:     {len(self.jump_targets)}")
        lines.append(f";   Strings:          {len(self.strings)}")
        n_ints = sum(len(v) for v in self.int_calls.values())
        lines.append(f";   INT calls:        {n_ints}")
        lines.append("")

    def _emit_segments(self, lines):
        lines.append("; " + "=" * 72)
        lines.append("; CODE / DATA")
        lines.append("; " + "=" * 72)

        for seg_idx, seg_val in enumerate(self.segmap.file_segments):
            seg_start = self.segmap.seg_to_file_offset(seg_val)
            if seg_idx + 1 < len(self.segmap.file_segments):
                seg_end = self.segmap.seg_to_file_offset(
                    self.segmap.file_segments[seg_idx + 1])
            else:
                seg_end = self.file_end
            seg_end = min(seg_end, self.file_end)
            if seg_start >= len(self.data):
                continue

            size = seg_end - seg_start
            lines.append("")
            lines.append("; " + "-" * 72)
            lines.append(
                f"; SEGMENT seg_{seg_val:04X}  ({size} bytes, "
                f"file 0x{seg_start:04X}-0x{seg_end:04X})")
            lines.append("; " + "-" * 72)
            lines.append(f"seg_{seg_val:04X}:")
            lines.append("")
            self._emit_segment_contents(
                lines, seg_val, seg_start, seg_end)

    def _emit_segment_contents(self, lines, seg_val, seg_start, seg_end):
        offset = seg_start
        while offset < seg_end:
            if offset in self.labels:
                lines.append("")
                lines.append(f"{self.labels[offset]}:")

            if offset in self.instructions:
                insn, _ = self.instructions[offset]
                seg, off = self.segmap.file_offset_to_seg(offset)
                raw = self.data[offset:offset + insn.size]
                hexs = raw.hex()
                if len(hexs) > 16:
                    hexs = hexs[:16]
                annotation = self._annotate_insn(insn, seg_val, offset)
                lines.append(
                    f"  {seg:04X}:{off:04X}  {hexs:<16s}  "
                    f"{insn.mnemonic:<8s} {insn.op_str}{annotation}")
                offset += insn.size

            elif offset in self.strings:
                raw = self.strings[offset]
                seg, off = self.segmap.file_offset_to_seg(offset)
                esc = escape_bytes(raw)
                if len(esc) > 60:
                    esc = esc[:60] + "..."
                chunk_size = 16
                remaining = raw
                pos = offset
                first = True
                while remaining:
                    chunk = remaining[:chunk_size]
                    remaining = remaining[chunk_size:]
                    s2, o2 = self.segmap.file_offset_to_seg(pos)
                    hb = ' '.join(f'{b:02X}' for b in chunk)
                    if first:
                        lines.append(
                            f'  {s2:04X}:{o2:04X}  db {hb:<48s}'
                            f'; "{esc}"')
                        first = False
                    else:
                        lines.append(
                            f'  {s2:04X}:{o2:04X}  db {hb}')
                    pos += len(chunk)
                if pos < seg_end and self.data[pos] in (0x00, 0x24):
                    term = self.data[pos]
                    s2, o2 = self.segmap.file_offset_to_seg(pos)
                    tname = "NUL" if term == 0 else "'$'"
                    lines.append(
                        f'  {s2:04X}:{o2:04X}  db {term:02X}'
                        f'                                                '
                        f'; {tname}')
                    pos += 1
                offset = pos

            else:
                data_start = offset
                while (offset < seg_end
                       and offset not in self.instructions
                       and offset not in self.strings
                       and offset not in self.labels):
                    offset += 1
                pos = data_start
                while pos < offset:
                    chunk_end = min(pos + 16, offset)
                    chunk = self.data[pos:chunk_end]
                    seg, off = self.segmap.file_offset_to_seg(pos)
                    hb = ' '.join(f'{b:02X}' for b in chunk)
                    ap = ''.join(
                        chr(b) if 0x20 <= b < 0x7F else '.'
                        for b in chunk)
                    reloc_note = ""
                    for p in range(pos, chunk_end):
                        if self.segmap.is_relocation(p):
                            val = struct.unpack_from('<H', self.data, p)[0]
                            reloc_note = f" [RELOC->seg_{val:04X}]"
                            break
                    lines.append(
                        f'  {seg:04X}:{off:04X}  db {hb:<48s}'
                        f'; |{ap}|{reloc_note}')
                    pos = chunk_end

    def _annotate_insn(self, insn, seg_val, file_off):
        parts = []
        is_call = CS_GRP_CALL in insn.groups
        is_jump = CS_GRP_JUMP in insn.groups
        if is_call or is_jump:
            target = self._resolve_target(insn, seg_val, file_off)
            if target is not None and target in self.labels:
                parts.append(f"-> {self.labels[target]}")

        if CS_GRP_INT in insn.groups:
            try:
                int_num = int(insn.op_str, 0)
            except (ValueError, TypeError):
                int_num = -1
            ah_val = self._find_ah_before(file_off, seg_val)
            key = (int_num, ah_val)
            if key in INT_ANNOTATIONS:
                parts.append(
                    f"INT {int_num:02X}h/{ah_val:02X}h: "
                    f"{INT_ANNOTATIONS[key]}")
            elif ah_val is not None:
                parts.append(f"INT {int_num:02X}h, AH={ah_val:02X}h")
            else:
                parts.append(f"INT {int_num:02X}h")

        for i in range(insn.size):
            if self.segmap.is_relocation(file_off + i):
                val = struct.unpack_from('<H', self.data, file_off + i)[0]
                parts.append(f"RELOC->seg_{val:04X}")
                break

        str_ref = self._check_string_ref(insn, seg_val)
        if str_ref:
            parts.append(str_ref)

        if parts:
            return "  ; " + " | ".join(parts)
        return ""

    def _check_string_ref(self, insn, seg_val):
        """Check if instruction loads a pointer to a known string."""
        if insn.mnemonic not in ('mov', 'lea'):
            return None
        if ',' not in insn.op_str:
            return None
        parts = insn.op_str.split(',')
        if len(parts) != 2:
            return None
        dest = parts[0].strip()
        # Only check pointer-class registers (dx, si, di, bx)
        # and word-size moves, not ah/al/cl etc.
        if dest not in ('dx', 'si', 'di', 'bx', 'ax'):
            return None
        val_str = parts[1].strip()
        try:
            val = int(val_str, 0)
        except ValueError:
            return None
        # Require offset >= 0x20 to avoid matching small constants
        if val < 0x20:
            return None
        # Check segment 0 (data segment) and current segment
        for check_seg in set([0, seg_val]):
            str_foff = self.mz.header_size + check_seg * 16 + val
            if str_foff in self.strings:
                s = escape_bytes(self.strings[str_foff])
                if len(s) > 48:
                    s = s[:48] + "..."
                return f'"{s}"'
        return None

    # ------------------------------------------------------------------
    # Call graph
    # ------------------------------------------------------------------

    def format_callgraph(self):
        lines = []
        lines.append("; " + "=" * 72)
        lines.append(f"; Call Graph for {self.filepath}")
        lines.append("; Generated by disasm_mz.py (Bayside project)")
        lines.append("; " + "=" * 72)
        lines.append("")
        lines.append(
            f"; Total functions (CALL targets): "
            f"{len(self.call_targets)}")
        lines.append(
            f"; Total jump targets:             "
            f"{len(self.jump_targets)}")
        lines.append(
            f"; Total instructions:             "
            f"{len(self.instructions)}")
        lines.append("")

        lines.append("; Interrupt Usage:")
        for (int_num, ah_val), locs in sorted(self.int_calls.items()):
            key = (int_num, ah_val)
            desc = INT_ANNOTATIONS.get(key, "")
            if ah_val is not None:
                lines.append(
                    f";   INT {int_num:02X}h AH={ah_val:02X}h"
                    f"  x{len(locs):<3d} {desc}")
            else:
                lines.append(
                    f";   INT {int_num:02X}h          x{len(locs)}")
        lines.append("")

        lines.append("; " + "-" * 72)
        lines.append("; Function List")
        lines.append("; " + "-" * 72)
        for target in sorted(self.call_targets.keys()):
            callers = self.call_targets[target]
            label = self.labels.get(target, f"unk_{target:05X}")
            seg, off = self.segmap.file_offset_to_seg(target)
            lines.append(f";")
            lines.append(
                f"; {label}  ({seg:04X}:{off:04X}, file 0x{target:04X})")
            lines.append(
                f";   Called from {len(callers)} location(s):")
            for caller in sorted(callers):
                cseg, coff = self.segmap.file_offset_to_seg(caller)
                containing = self._find_containing_function(caller)
                loc = f"{cseg:04X}:{coff:04X}"
                if containing:
                    lines.append(f";     {loc}  (in {containing})")
                else:
                    lines.append(f";     {loc}")

        lines.append("")
        lines.append("; " + "-" * 72)
        lines.append("; Functions by call count (descending)")
        lines.append("; " + "-" * 72)
        by_count = sorted(self.call_targets.items(),
                          key=lambda x: len(x[1]), reverse=True)
        for target, callers in by_count:
            label = self.labels.get(target, f"unk_{target:05X}")
            lines.append(f";   {len(callers):4d} x  {label}")

        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Disassemble MZ DOS executables (DeskMate/DM89)")
    parser.add_argument("exe_file", help="Path to MZ executable")
    parser.add_argument("-o", "--output", required=True,
                        help="Output assembly file path")
    parser.add_argument("--callgraph", default=None,
                        help="Output call graph file path")
    args = parser.parse_args()

    print(f"[*] Loading {args.exe_file}...")
    disasm = MZDisassembler(args.exe_file)

    print(f"[*] MZ header: {disasm.mz.pages} pages, "
          f"{disasm.mz.num_relocs} relocs, "
          f"entry {disasm.mz.init_cs:04X}:{disasm.mz.init_ip:04X}")
    if disasm.mz.dm89:
        print(f"[*] DM89 signature detected")
    print(f"[*] Segments: "
          f"{', '.join(f'{s:04X}' for s in disasm.segmap.segments)}")

    print(f"[*] Analyzing...")
    disasm.analyze()

    print(f"[*] {len(disasm.instructions)} instructions, "
          f"{len(disasm.call_targets)} functions, "
          f"{len(disasm.jump_targets)} jump targets, "
          f"{len(disasm.strings)} strings")

    print(f"[*] Writing {args.output}...")
    with open(args.output, 'w') as f:
        f.write(disasm.format_output())

    if args.callgraph:
        print(f"[*] Writing {args.callgraph}...")
        with open(args.callgraph, 'w') as f:
            f.write(disasm.format_callgraph())

    print(f"[*] Done.")


if __name__ == '__main__':
    main()
