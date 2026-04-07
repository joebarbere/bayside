#!/usr/bin/env python3
"""
disasm_pdm.py -- Comprehensive MZ+DM89 disassembler for DeskMate PDM/EXE files.

Uses Capstone x86-16 with recursive descent + prologue scanning.
Produces labeled assembly and detailed call graph analysis.

Usage:
    python3 disasm_pdm.py <input.PDM> <output.asm> <callgraph.txt>
    python3 disasm_pdm.py --batch   (processes DESKTOP.PDM and TEXT.PDM)
"""

import struct
import sys
import os
from collections import defaultdict, OrderedDict
from capstone import Cs, CS_ARCH_X86, CS_MODE_16, CsInsn
from capstone.x86_const import *

# ---------------------------------------------------------------------------
# MZ + DM89 header parsing
# ---------------------------------------------------------------------------

class MZHeader:
    def __init__(self, data):
        if data[0:2] != b'MZ':
            raise ValueError("Not an MZ executable")
        self.e_cblp     = struct.unpack_from('<H', data, 0x02)[0]
        self.e_cp       = struct.unpack_from('<H', data, 0x04)[0]
        self.e_crlc     = struct.unpack_from('<H', data, 0x06)[0]
        self.e_cparhdr  = struct.unpack_from('<H', data, 0x08)[0]
        self.e_minalloc = struct.unpack_from('<H', data, 0x0A)[0]
        self.e_maxalloc = struct.unpack_from('<H', data, 0x0C)[0]
        self.e_ss       = struct.unpack_from('<H', data, 0x0E)[0]
        self.e_sp       = struct.unpack_from('<H', data, 0x10)[0]
        self.e_csum     = struct.unpack_from('<H', data, 0x12)[0]
        self.e_ip       = struct.unpack_from('<H', data, 0x14)[0]
        self.e_cs       = struct.unpack_from('<H', data, 0x16)[0]
        self.e_lfarlc   = struct.unpack_from('<H', data, 0x18)[0]
        self.e_ovno     = struct.unpack_from('<H', data, 0x1A)[0]

        self.hdr_size = self.e_cparhdr * 16
        if self.e_cblp:
            self.file_size = (self.e_cp - 1) * 512 + self.e_cblp
        else:
            self.file_size = self.e_cp * 512

        # DM89 extension
        self.dm89 = data[0x1C:0x20] == b'DM89'
        if self.dm89:
            self.dm_cs = struct.unpack_from('<H', data, 0x26)[0]
            self.dm_ip = struct.unpack_from('<H', data, 0x28)[0]
        else:
            self.dm_cs = self.e_cs
            self.dm_ip = self.e_ip

        # Relocation table
        self.relocs = []
        for i in range(self.e_crlc):
            off = self.e_lfarlc + i * 4
            if off + 4 <= len(data):
                r_off = struct.unpack_from('<H', data, off)[0]
                r_seg = struct.unpack_from('<H', data, off + 2)[0]
                self.relocs.append((r_seg, r_off))


# ---------------------------------------------------------------------------
# Recursive descent disassembler
# ---------------------------------------------------------------------------

class PDMDisassembler:
    """Recursive-descent disassembler operating on the flat load image."""

    def __init__(self, data, hdr):
        self.raw = data
        self.hdr = hdr
        self.image = data[hdr.hdr_size:]
        self.image_size = len(self.image)

        self.md = Cs(CS_ARCH_X86, CS_MODE_16)
        self.md.detail = True
        self.md.skipdata = False  # we handle data ourselves

        # Core data structures -- keyed by linear offset within load image
        self.insns = {}             # offset -> (mnemonic, op_str, bytes, size, operands_info)
        self.functions = set()       # offsets that are call targets or prologues
        self.jump_targets = set()    # offsets that are jump targets
        self.visited = set()         # offsets where disassembly has been done
        self.call_graph = defaultdict(set)  # func_offset -> {callee_offsets}
        self.callers = defaultdict(set)     # callee_offset -> {caller_offsets}
        self.int_calls = {}          # offset -> (int_num, ax_value_or_None)
        self.strings = {}            # offset -> string
        self.far_calls = {}          # offset -> (seg, off) for far calls

        # Entry point as linear offset
        self.entry = hdr.e_cs * 16 + hdr.e_ip

        # Relocation linear offsets
        self.reloc_offsets = set()
        for r_seg, r_off in hdr.relocs:
            lin = r_seg * 16 + r_off
            if lin < self.image_size:
                self.reloc_offsets.add(lin)

    def _disasm_one(self, offset):
        """Disassemble a single instruction at offset. Returns info tuple or None."""
        if offset < 0 or offset >= self.image_size:
            return None
        code = self.image[offset:offset + 15]  # max x86 instruction length
        if not code:
            return None
        for insn in self.md.disasm(code, offset, count=1):
            # Extract operand info we need
            ops_info = []
            for op in insn.operands:
                ops_info.append({
                    'type': op.type,
                    'imm': op.imm if op.type == X86_OP_IMM else 0,
                    'reg': op.reg if op.type == X86_OP_REG else 0,
                    'mem_base': op.mem.base if op.type == X86_OP_MEM else 0,
                    'mem_disp': op.mem.disp if op.type == X86_OP_MEM else 0,
                })
            return (insn.mnemonic, insn.op_str, bytes(insn.bytes), insn.size, ops_info)
        return None

    def _trace_block(self, start, owner_func):
        """Trace a basic block starting at 'start', belonging to owner_func."""
        addr = start
        while addr < self.image_size:
            if addr in self.visited:
                return  # already traced

            info = self._disasm_one(addr)
            if info is None:
                return

            mnem, op_str, raw_bytes, size, ops_info = info
            self.visited.add(addr)
            self.insns[addr] = info

            # --- Track INT calls ---
            if mnem == 'int' and ops_info and ops_info[0]['type'] == X86_OP_IMM:
                int_num = ops_info[0]['imm']
                ax_val = self._find_ax_before(addr)
                self.int_calls[addr] = (int_num, ax_val)

            # --- Handle CALL (near) ---
            if mnem == 'call':
                if ops_info and ops_info[0]['type'] == X86_OP_IMM:
                    target = ops_info[0]['imm'] & 0xFFFF
                    if 0 <= target < self.image_size:
                        self.functions.add(target)
                        self.call_graph[owner_func].add(target)
                        self.callers[target].add(owner_func)
                        yield target  # schedule for tracing
                # Fall through after call
                addr += size
                continue

            # --- Handle far call ---
            if mnem == 'lcall':
                # Far calls to DeskMate API or CRT -- don't follow
                addr += size
                continue

            # --- Handle unconditional JMP ---
            if mnem == 'jmp':
                if ops_info and ops_info[0]['type'] == X86_OP_IMM:
                    target = ops_info[0]['imm'] & 0xFFFF
                    if 0 <= target < self.image_size:
                        self.jump_targets.add(target)
                        yield ('jmp', target, owner_func)
                return  # end of block

            if mnem == 'ljmp':
                return  # end of block

            # --- Handle conditional jumps ---
            if mnem.startswith('j') and mnem not in ('jmp', 'ljmp'):
                if ops_info and ops_info[0]['type'] == X86_OP_IMM:
                    target = ops_info[0]['imm'] & 0xFFFF
                    if 0 <= target < self.image_size:
                        self.jump_targets.add(target)
                        yield ('jmp', target, owner_func)
                # Fall through
                addr += size
                continue

            # --- Handle LOOP variants ---
            if mnem in ('loop', 'loope', 'loopne', 'loopz', 'loopnz'):
                if ops_info and ops_info[0]['type'] == X86_OP_IMM:
                    target = ops_info[0]['imm'] & 0xFFFF
                    if 0 <= target < self.image_size:
                        self.jump_targets.add(target)
                # Fall through
                addr += size
                continue

            # --- Handle RET / IRET ---
            if mnem in ('ret', 'retf', 'iret', 'retn'):
                return

            # --- Handle HLT ---
            if mnem == 'hlt':
                return

            addr += size

    def _find_ax_before(self, addr):
        """Look back for mov ah,XX or mov ax,XXXX before an INT."""
        ax_val = None
        ah_val = None
        al_val = None

        # Scan backwards through the last ~20 bytes
        scan_start = max(0, addr - 30)
        # Collect instructions before addr
        prev = []
        a = scan_start
        while a < addr:
            if a in self.insns:
                prev.append((a, self.insns[a]))
                a += self.insns[a][3]  # size
            else:
                a += 1

        for a, info in prev[-10:]:  # last 10 instructions
            mnem, op_str, raw_bytes, size, ops_info = info
            if mnem == 'mov' and len(ops_info) == 2:
                dst = ops_info[0]
                src = ops_info[1]
                if dst['type'] == X86_OP_REG and src['type'] == X86_OP_IMM:
                    if dst['reg'] == X86_REG_AX:
                        ax_val = src['imm'] & 0xFFFF
                        ah_val = None
                        al_val = None
                    elif dst['reg'] == X86_REG_AH:
                        ah_val = src['imm'] & 0xFF
                    elif dst['reg'] == X86_REG_AL:
                        al_val = src['imm'] & 0xFF

        if ax_val is not None:
            return ax_val
        if ah_val is not None:
            return (ah_val << 8) | (al_val or 0)
        return None

    def find_prologues(self):
        """Linear scan for 'push bp; mov bp,sp' function prologues."""
        found = set()
        i = 0
        while i < self.image_size - 2:
            if self.image[i] == 0x55:  # push bp
                if (i + 2 < self.image_size and
                    self.image[i+1] == 0x8B and self.image[i+2] == 0xEC):
                    found.add(i)
                    i += 3
                    continue
                if (i + 2 < self.image_size and
                    self.image[i+1] == 0x89 and self.image[i+2] == 0xE5):
                    found.add(i)
                    i += 3
                    continue
            i += 1
        return found

    def find_strings(self, min_len=4):
        """Find ASCII strings in non-code regions."""
        i = 0
        while i < self.image_size:
            if i in self.insns:
                i += self.insns[i][3]  # skip instruction
                continue
            # Try reading a string
            j = i
            while j < self.image_size and (0x20 <= self.image[j] < 0x7F or self.image[j] in (0x0A, 0x0D, 0x09)):
                j += 1
            if j - i >= min_len and j < self.image_size and self.image[j] == 0:
                try:
                    s = self.image[i:j].decode('ascii', errors='replace')
                    self.strings[i] = s
                except:
                    pass
                i = j + 1
            else:
                i += 1

    def run(self):
        """Full disassembly pass."""
        print("    Phase 1: Recursive descent from entry point...")
        self.functions.add(self.entry)

        # BFS-style recursive descent
        work = [(self.entry, self.entry)]  # (addr, owner_func)
        processed_work = set()

        while work:
            addr, owner = work.pop(0)
            key = (addr, owner)
            if key in processed_work:
                continue
            processed_work.add(key)

            if addr in self.visited:
                continue

            for item in self._trace_block(addr, owner):
                if isinstance(item, tuple):
                    # ('jmp', target, owner)
                    _, target, owner2 = item
                    work.append((target, owner2))
                else:
                    # call target -- new function
                    work.append((item, item))

        print(f"    Phase 1 complete: {len(self.insns)} instructions, {len(self.functions)} functions")

        # Phase 2: prologue scan
        print("    Phase 2: Prologue scanning...")
        prologues = self.find_prologues()
        new_funcs = prologues - self.visited
        print(f"    Found {len(prologues)} prologues, {len(new_funcs)} new")

        for addr in sorted(new_funcs):
            if addr not in self.visited:
                self.functions.add(addr)
                work = [(addr, addr)]
                processed_work2 = set()
                while work:
                    a, o = work.pop(0)
                    k = (a, o)
                    if k in processed_work2:
                        continue
                    processed_work2.add(k)
                    if a in self.visited:
                        continue
                    for item in self._trace_block(a, o):
                        if isinstance(item, tuple):
                            _, target, owner2 = item
                            work.append((target, owner2))
                        else:
                            self.functions.add(item)
                            work.append((item, item))

        print(f"    Phase 2 complete: {len(self.insns)} instructions, {len(self.functions)} functions")

        # Phase 3: find strings
        print("    Phase 3: String scanning...")
        self.find_strings()
        print(f"    Found {len(self.strings)} strings")

        # Compute actual byte coverage
        self.bytes_covered = sum(info[3] for info in self.insns.values())
        print(f"    Byte coverage: {self.bytes_covered}/{self.image_size} ({100*self.bytes_covered//self.image_size}%)")

    def get_function_for_addr(self, addr):
        """Find which function owns an address (nearest function start <= addr)."""
        # Use sorted list for binary search
        func_list = sorted(self.functions)
        lo, hi = 0, len(func_list) - 1
        best = None
        while lo <= hi:
            mid = (lo + hi) // 2
            if func_list[mid] <= addr:
                best = func_list[mid]
                lo = mid + 1
            else:
                hi = mid - 1
        return best

    def get_function_insn_count(self, func_addr):
        """Count instructions in a function (until next function)."""
        funcs = sorted(self.functions)
        idx = funcs.index(func_addr) if func_addr in funcs else -1
        if idx < 0:
            return 0
        start = func_addr
        end = funcs[idx + 1] if idx + 1 < len(funcs) else self.image_size
        return sum(1 for a in self.insns if start <= a < end)


# ---------------------------------------------------------------------------
# INT call classification tables
# ---------------------------------------------------------------------------

INT_E0_SERVICES = {
    0x0100: "dm_init", 0x0101: "dm_terminate", 0x0102: "dm_yield",
    0x0200: "dm_open_window", 0x0201: "dm_close_window",
    0x0202: "dm_draw_text", 0x0203: "dm_draw_char",
    0x0204: "dm_scroll_region", 0x0205: "dm_clear_region",
    0x0206: "dm_set_attribute", 0x0207: "dm_cursor_control",
    0x0208: "dm_get_window_info", 0x0209: "dm_repaint_window",
    0x020A: "dm_select_window",
    0x0300: "dm_menu_define", 0x0301: "dm_menu_enable",
    0x0302: "dm_menu_check", 0x0303: "dm_menu_bar",
    0x0400: "dm_get_event", 0x0401: "dm_peek_event",
    0x0402: "dm_post_event", 0x0403: "dm_flush_events",
    0x0500: "dm_dialog_box", 0x0501: "dm_message_box",
    0x0502: "dm_input_box",
    0x0600: "dm_file_open", 0x0601: "dm_file_close",
    0x0602: "dm_file_read", 0x0603: "dm_file_write",
    0x0700: "dm_alloc_memory", 0x0701: "dm_free_memory",
    0x0800: "dm_timer_set", 0x0801: "dm_timer_cancel",
    0x0900: "dm_clipboard_copy", 0x0901: "dm_clipboard_paste",
    0x0A00: "dm_help_display",
}

DOS_INT21_FUNCS = {
    0x01: "char_input", 0x02: "char_output", 0x06: "direct_console",
    0x09: "print_string", 0x0A: "buffered_input",
    0x0C: "flush_and_input", 0x0E: "select_disk",
    0x19: "get_current_disk", 0x1A: "set_dta",
    0x25: "set_int_vector", 0x2A: "get_date", 0x2C: "get_time",
    0x30: "get_version", 0x35: "get_int_vector",
    0x36: "get_disk_free", 0x39: "mkdir", 0x3A: "rmdir",
    0x3B: "chdir", 0x3C: "create_file", 0x3D: "open_file",
    0x3E: "close_file", 0x3F: "read_file", 0x40: "write_file",
    0x41: "delete_file", 0x42: "lseek", 0x43: "get_set_attrib",
    0x44: "ioctl", 0x47: "get_current_dir", 0x48: "alloc_mem",
    0x49: "free_mem", 0x4A: "realloc_mem", 0x4B: "exec",
    0x4C: "exit", 0x4E: "find_first", 0x4F: "find_next",
    0x56: "rename", 0x57: "get_set_datetime", 0x5B: "create_new",
}


def classify_int(int_num, ax_val):
    """Return description string for an INT call."""
    if int_num == 0xE0:
        if ax_val is not None:
            name = INT_E0_SERVICES.get(ax_val, f"svc_{ax_val:04X}")
            return f"INT E0h AX={ax_val:04X}h ({name})"
        return "INT E0h (DeskMate API)"
    elif int_num == 0x21:
        if ax_val is not None:
            ah = (ax_val >> 8) & 0xFF
            name = DOS_INT21_FUNCS.get(ah, f"func_{ah:02X}h")
            return f"INT 21h AH={ah:02X}h ({name})"
        return "INT 21h (DOS)"
    elif int_num == 0x10:
        if ax_val is not None:
            ah = (ax_val >> 8) & 0xFF
            return f"INT 10h AH={ah:02X}h (BIOS video)"
        return "INT 10h (BIOS video)"
    elif int_num == 0x16:
        return "INT 16h (BIOS keyboard)"
    elif int_num == 0x20:
        return "INT 20h (DOS terminate)"
    else:
        return f"INT {int_num:02X}h"


# ---------------------------------------------------------------------------
# Label generation
# ---------------------------------------------------------------------------

def make_labels(disasm):
    """Build label map: offset -> name."""
    labels = {}
    labels[disasm.entry] = "__astart"
    for addr in sorted(disasm.functions):
        if addr not in labels:
            labels[addr] = f"sub_{addr:05X}"
    for addr in sorted(disasm.jump_targets):
        if addr not in labels:
            labels[addr] = f"loc_{addr:05X}"
    for addr in disasm.strings:
        if addr not in labels:
            labels[addr] = f"aStr_{addr:05X}"
    return labels


# ---------------------------------------------------------------------------
# MSC 5.x CRT identification
# ---------------------------------------------------------------------------

def identify_crt_functions(disasm, labels):
    """Identify known MSC 5.x C runtime functions by pattern."""
    renames = {}

    # __astart is already the entry
    renames[disasm.entry] = "__astart"

    # Look for _main: it's typically called from __astart, after pushing
    # argc/argv. The call to main is usually the last call before the
    # exit sequence. In MSC 5.x, __astart calls several CRT init functions
    # then calls main.

    # Find calls from __astart
    if disasm.entry in disasm.call_graph:
        astart_callees = sorted(disasm.call_graph[disasm.entry])
        # The last callee (or second-to-last) is typically _main
        # Actually, _main is called after CRT init -- look for a call
        # that's followed by pushing its return value and calling _exit
        # For now, just note the callees
        if len(astart_callees) >= 2:
            # In MSC 5.x startup: the CRT calls are to far addresses typically,
            # and _main is a near call to the application's main function
            # The near calls that are in the data segment area are likely main
            pass

    # Scan all functions for known patterns
    for func_addr in sorted(disasm.functions):
        if func_addr not in disasm.insns:
            continue

        # Collect first few instructions
        first_insns = []
        a = func_addr
        for _ in range(20):
            if a in disasm.insns:
                first_insns.append((a, disasm.insns[a]))
                a += disasm.insns[a][3]
            else:
                break

        if not first_insns:
            continue

        # Check for _exit pattern: mov ah,4Ch; int 21h
        for i, (a, info) in enumerate(first_insns):
            mnem, op_str, _, _, ops = info
            if mnem == 'mov' and len(ops) == 2:
                if (ops[0]['type'] == X86_OP_REG and ops[0]['reg'] == X86_REG_AH and
                    ops[1]['type'] == X86_OP_IMM and ops[1]['imm'] == 0x4C):
                    if i + 1 < len(first_insns):
                        nm, os2, _, _, _ = first_insns[i+1][1]
                        if nm == 'int':
                            renames[func_addr] = "__exit"
                            break

    return renames


# ---------------------------------------------------------------------------
# Assembly output
# ---------------------------------------------------------------------------

def write_asm(disasm, labels, filename, module_name, hdr):
    """Write full annotated assembly listing."""
    with open(filename, 'w') as f:
        # Header
        f.write(f"; {'='*75}\n")
        f.write(f"; {module_name} -- Raw Disassembly (Capstone x86-16)\n")
        f.write(f"; Generated by disasm_pdm.py (Bayside project)\n")
        f.write(f"; {'='*75}\n;\n")
        f.write(f"; MZ Header:\n")
        f.write(f";   File size:       {hdr.file_size} bytes\n")
        f.write(f";   Header size:     {hdr.hdr_size} bytes\n")
        f.write(f";   Load image:      {disasm.image_size} bytes\n")
        f.write(f";   CS:IP entry:     {hdr.e_cs:04X}:{hdr.e_ip:04X}  (linear 0x{disasm.entry:05X})\n")
        f.write(f";   SS:SP:           {hdr.e_ss:04X}:{hdr.e_sp:04X}\n")
        f.write(f";   Relocations:     {hdr.e_crlc}\n")
        if hdr.dm89:
            f.write(f";   DM89:            CS:IP = {hdr.dm_cs:04X}:{hdr.dm_ip:04X}\n")
        f.write(f";\n")
        f.write(f"; Analysis Results:\n")
        f.write(f";   Functions:        {len(disasm.functions)}\n")
        f.write(f";   Instructions:     {len(disasm.insns)}\n")
        f.write(f";   Strings:          {len(disasm.strings)}\n")
        f.write(f";   INT calls:        {len(disasm.int_calls)}\n")
        f.write(f";   Bytes covered:    {disasm.bytes_covered}/{disasm.image_size} ({100*disasm.bytes_covered//disasm.image_size}%)\n")
        f.write(f"; {'='*75}\n\n")

        # Relocation table
        f.write(f"; Relocation Table ({hdr.e_crlc} entries):\n")
        for r_seg, r_off in hdr.relocs:
            lin = r_seg * 16 + r_off
            if lin + 1 < disasm.image_size:
                val = struct.unpack_from('<H', disasm.image, lin)[0]
                f.write(f";   {r_seg:04X}:{r_off:04X}  linear=0x{lin:05X}  value=0x{val:04X}\n")
        f.write(f"\n")

        # String table (abbreviated)
        if disasm.strings:
            f.write(f"; String Table ({len(disasm.strings)} strings):\n")
            for addr in sorted(disasm.strings.keys()):
                s = disasm.strings[addr]
                if len(s) > 60:
                    s = s[:60] + "..."
                f.write(f';   0x{addr:05X}: "{s}"\n')
            f.write(f"\n")

        f.write(f"; {'='*75}\n")
        f.write(f"; CODE\n")
        f.write(f"; {'='*75}\n\n")

        # Emit instructions in address order
        sorted_addrs = sorted(disasm.insns.keys())
        prev_end = 0

        for idx, addr in enumerate(sorted_addrs):
            mnem, op_str, raw_bytes, size, ops_info = disasm.insns[addr]

            # Gap detection
            if prev_end > 0 and addr > prev_end:
                gap = addr - prev_end
                if gap > 0:
                    # Check if gap contains strings
                    has_string = any(prev_end <= sa < addr for sa in disasm.strings)
                    if gap <= 64 and not has_string:
                        # Show data bytes
                        f.write(f"\n; --- data ({gap} bytes) ---\n")
                        off = prev_end
                        while off < addr:
                            chunk = disasm.image[off:min(off+16, addr)]
                            hex_str = ' '.join(f'{b:02X}' for b in chunk)
                            ascii_str = ''.join(chr(b) if 0x20 <= b < 0x7F else '.' for b in chunk)
                            f.write(f"  {off:05X}  db {hex_str:<48s} ; {ascii_str}\n")
                            off += len(chunk)
                    elif has_string:
                        f.write(f"\n; --- data/strings ({gap} bytes, 0x{prev_end:05X}-0x{addr:05X}) ---\n")
                        off = prev_end
                        while off < addr:
                            if off in disasm.strings:
                                s = disasm.strings[off]
                                raw_s = disasm.image[off:off+len(s)]
                                lbl = labels.get(off, "")
                                if lbl:
                                    f.write(f"{lbl}:\n")
                                f.write(f'  {off:05X}  db "{s}",0\n')
                                off += len(s) + 1
                            elif off in labels:
                                f.write(f"{labels[off]}:\n")
                                f.write(f"  {off:05X}  db {disasm.image[off]:02X}\n")
                                off += 1
                            else:
                                off += 1
                    else:
                        f.write(f"\n; === gap: {gap} bytes (0x{prev_end:05X}-0x{addr:05X}) ===\n\n")

            # Labels
            if addr in labels:
                lbl = labels[addr]
                if addr in disasm.functions:
                    f.write(f"\n; {'~'*60}\n")
                    # Show callers
                    if addr in disasm.callers and disasm.callers[addr]:
                        caller_names = [labels.get(c, f"sub_{c:05X}") for c in sorted(disasm.callers[addr])]
                        f.write(f"; Called by: {', '.join(caller_names[:5])}")
                        if len(caller_names) > 5:
                            f.write(f" (+{len(caller_names)-5} more)")
                        f.write(f"\n")
                    f.write(f"; {'~'*60}\n")
                f.write(f"{lbl}:\n")

            # Format instruction
            hex_str = ' '.join(f'{b:02X}' for b in raw_bytes)
            line = f"  {addr:05X}  {hex_str:<24s} {mnem:<8s} {op_str}"

            # Add label references for branches
            if ops_info and ops_info[0]['type'] == X86_OP_IMM:
                target = ops_info[0]['imm'] & 0xFFFF
                if target in labels and mnem in (
                    'call', 'jmp', 'je', 'jne', 'jz', 'jnz', 'ja', 'jae',
                    'jb', 'jbe', 'jg', 'jge', 'jl', 'jle', 'jc', 'jnc',
                    'jo', 'jno', 'js', 'jns', 'jp', 'jnp', 'jcxz',
                    'loop', 'loope', 'loopne'):
                    line += f"  ; -> {labels[target]}"

            # INT annotations
            if addr in disasm.int_calls:
                int_num, ax_val = disasm.int_calls[addr]
                line += f"  ; {classify_int(int_num, ax_val)}"

            # Relocation markers
            for i in range(size):
                if (addr + i) in disasm.reloc_offsets:
                    line += "  ; [RELOC]"
                    break

            f.write(line + "\n")
            prev_end = addr + size

    print(f"    Assembly: {filename}")
    print(f"    {len(sorted_addrs)} instructions emitted")


# ---------------------------------------------------------------------------
# Call graph output
# ---------------------------------------------------------------------------

def write_callgraph(disasm, labels, filename, module_name, hdr):
    """Write detailed call graph and analysis."""
    func_list = sorted(disasm.functions)

    # Compute function sizes
    func_sizes = {}
    for fa in func_list:
        func_sizes[fa] = disasm.get_function_insn_count(fa)

    # Classify INT calls
    int_e0_calls = []
    int_21_calls = []
    other_int_calls = []
    for addr, (int_num, ax_val) in sorted(disasm.int_calls.items()):
        func = disasm.get_function_for_addr(addr)
        fname = labels.get(func, f"sub_{func:05X}") if func else "unknown"
        if int_num == 0xE0:
            int_e0_calls.append((addr, ax_val, fname))
        elif int_num == 0x21:
            int_21_calls.append((addr, ax_val, fname))
        else:
            other_int_calls.append((addr, int_num, ax_val, fname))

    # Unique service codes
    e0_svcs = sorted(set(ax for _, ax, _ in int_e0_calls if ax is not None))
    dos_funcs = sorted(set(((ax >> 8) & 0xFF) for _, ax, _ in int_21_calls if ax is not None))

    # Largest functions
    largest = sorted(func_sizes.items(), key=lambda x: -x[1])[:30]

    with open(filename, 'w') as f:
        f.write(f"{'='*78}\n")
        f.write(f" {module_name} -- Call Graph & Analysis Summary\n")
        f.write(f" Generated by disasm_pdm.py (Bayside project)\n")
        f.write(f"{'='*78}\n\n")

        # --- SUMMARY ---
        f.write(f"SUMMARY\n")
        f.write(f"{'~'*40}\n")
        f.write(f"  Module:              {module_name}\n")
        f.write(f"  File size:           {hdr.file_size} bytes\n")
        f.write(f"  Load image:          {disasm.image_size} bytes\n")
        f.write(f"  Entry point:         {hdr.e_cs:04X}:{hdr.e_ip:04X} (linear 0x{disasm.entry:05X})\n")
        f.write(f"  Total functions:     {len(func_list)}\n")
        f.write(f"  Total instructions:  {len(disasm.insns)}\n")
        f.write(f"  Strings found:       {len(disasm.strings)}\n")
        f.write(f"  Relocations:         {hdr.e_crlc}\n")
        f.write(f"  INT E0h calls:       {len(int_e0_calls)} ({len(e0_svcs)} unique services)\n")
        f.write(f"  INT 21h calls:       {len(int_21_calls)} ({len(dos_funcs)} unique functions)\n")
        f.write(f"  Other INT calls:     {len(other_int_calls)}\n")
        f.write(f"  Bytes disassembled:  {disasm.bytes_covered}/{disasm.image_size} bytes ({100*disasm.bytes_covered//disasm.image_size}%)\n")
        f.write(f"\n")

        # --- MSC CRT CHAIN ---
        f.write(f"MSC 5.x CRT STARTUP CHAIN\n")
        f.write(f"{'~'*40}\n")
        f.write(f"  Entry: {labels.get(disasm.entry, '???')} @ 0x{disasm.entry:05X}\n")
        if disasm.entry in disasm.call_graph:
            for target in sorted(disasm.call_graph[disasm.entry]):
                tname = labels.get(target, f"sub_{target:05X}")
                f.write(f"    calls -> {tname} @ 0x{target:05X}\n")
                if target in disasm.call_graph:
                    for t2 in sorted(disasm.call_graph[target]):
                        t2name = labels.get(t2, f"sub_{t2:05X}")
                        f.write(f"             -> {t2name} @ 0x{t2:05X}\n")
        f.write(f"\n")

        # --- INT E0h CALLS ---
        f.write(f"INT E0h (DeskMate API) CALLS\n")
        f.write(f"{'~'*40}\n")
        if int_e0_calls:
            by_svc = defaultdict(list)
            for addr, ax_val, fname in int_e0_calls:
                by_svc[ax_val if ax_val is not None else -1].append((addr, fname))
            for svc in sorted(by_svc.keys()):
                if svc >= 0:
                    svc_name = INT_E0_SERVICES.get(svc, f"svc_{svc:04X}")
                    f.write(f"  AX={svc:04X}h ({svc_name}):\n")
                else:
                    f.write(f"  AX=???? (unknown):\n")
                for addr, fname in by_svc[svc]:
                    f.write(f"    0x{addr:05X} in {fname}\n")
        else:
            f.write(f"  (none found)\n")
        f.write(f"\n")

        # --- INT 21h CALLS ---
        f.write(f"INT 21h (DOS API) CALLS\n")
        f.write(f"{'~'*40}\n")
        if int_21_calls:
            by_func = defaultdict(list)
            for addr, ax_val, fname in int_21_calls:
                ah = ((ax_val >> 8) & 0xFF) if ax_val is not None else -1
                by_func[ah].append((addr, fname))
            for fnum in sorted(by_func.keys()):
                if fnum >= 0:
                    fn = DOS_INT21_FUNCS.get(fnum, f"func_{fnum:02X}h")
                    f.write(f"  AH={fnum:02X}h ({fn}):\n")
                else:
                    f.write(f"  AH=?? (unknown):\n")
                for addr, fname in by_func[fnum]:
                    f.write(f"    0x{addr:05X} in {fname}\n")
        else:
            f.write(f"  (none found)\n")
        f.write(f"\n")

        # --- OTHER INT CALLS ---
        if other_int_calls:
            f.write(f"OTHER INT CALLS\n")
            f.write(f"{'~'*40}\n")
            for addr, int_num, ax_val, fname in other_int_calls:
                f.write(f"  0x{addr:05X} in {fname}: {classify_int(int_num, ax_val)}\n")
            f.write(f"\n")

        # --- LARGEST FUNCTIONS ---
        f.write(f"LARGEST FUNCTIONS (by instruction count)\n")
        f.write(f"{'~'*40}\n")
        for i, (faddr, count) in enumerate(largest):
            fname = labels.get(faddr, f"sub_{faddr:05X}")
            ncallees = len(disasm.call_graph.get(faddr, set()))
            ncallers = len(disasm.callers.get(faddr, set()))
            f.write(f"  {i+1:3d}. {fname:<35s} {count:5d} insns  (calls {ncallees}, called by {ncallers})\n")
        f.write(f"\n")

        # --- MOST-CALLED FUNCTIONS ---
        f.write(f"MOST-CALLED FUNCTIONS\n")
        f.write(f"{'~'*40}\n")
        by_caller_count = sorted(
            [(fa, len(disasm.callers.get(fa, set()))) for fa in func_list],
            key=lambda x: -x[1]
        )[:20]
        for faddr, ncallers in by_caller_count:
            if ncallers == 0:
                break
            fname = labels.get(faddr, f"sub_{faddr:05X}")
            f.write(f"  {ncallers:3d} callers  {fname}\n")
        f.write(f"\n")

        # --- ALL FUNCTIONS ---
        f.write(f"ALL FUNCTIONS ({len(func_list)})\n")
        f.write(f"{'='*78}\n")
        for faddr in func_list:
            fname = labels.get(faddr, f"sub_{faddr:05X}")
            sz = func_sizes.get(faddr, 0)
            callees = sorted(disasm.call_graph.get(faddr, set()))
            callers_set = sorted(disasm.callers.get(faddr, set()))

            f.write(f"\n{fname} @ 0x{faddr:05X} ({sz} insns)\n")
            if callers_set:
                cnames = [labels.get(c, f"sub_{c:05X}") for c in callers_set]
                f.write(f"  Called by: {', '.join(cnames[:8])}")
                if len(cnames) > 8:
                    f.write(f" (+{len(cnames)-8} more)")
                f.write(f"\n")
            if callees:
                f.write(f"  Calls:\n")
                for c in callees:
                    cn = labels.get(c, f"sub_{c:05X}")
                    f.write(f"    -> {cn}\n")

            # INT calls in this function
            func_ints = [(a, disasm.int_calls[a]) for a in sorted(disasm.int_calls)
                        if disasm.get_function_for_addr(a) == faddr]
            if func_ints:
                f.write(f"  INTs:\n")
                for a, (inum, axv) in func_ints:
                    f.write(f"    {classify_int(inum, axv)}\n")

        # --- CALL GRAPH EDGES ---
        f.write(f"\n\nCALL GRAPH EDGES\n")
        f.write(f"{'='*78}\n")
        for caller in sorted(disasm.call_graph.keys()):
            cname = labels.get(caller, f"sub_{caller:05X}")
            for callee in sorted(disasm.call_graph[caller]):
                tname = labels.get(callee, f"sub_{callee:05X}")
                f.write(f"  {cname} -> {tname}\n")

    print(f"    Call graph: {filename}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def process_one(input_path, asm_out, cg_out, module_name):
    print(f"\n=== Processing {module_name}: {input_path} ===")
    with open(input_path, 'rb') as f:
        data = f.read()

    hdr = MZHeader(data)
    print(f"  MZ: {hdr.file_size} bytes, {hdr.e_crlc} relocs, entry={hdr.e_cs:04X}:{hdr.e_ip:04X}")

    disasm = PDMDisassembler(data, hdr)
    disasm.run()

    labels = make_labels(disasm)
    crt = identify_crt_functions(disasm, labels)
    for addr, name in crt.items():
        labels[addr] = name

    print(f"  Writing outputs...")
    write_asm(disasm, labels, asm_out, module_name, hdr)
    write_callgraph(disasm, labels, cg_out, module_name, hdr)
    print(f"  Complete.")
    return disasm, labels


def main():
    if len(sys.argv) == 4:
        process_one(sys.argv[1], sys.argv[2], sys.argv[3], os.path.basename(sys.argv[1]))
    elif len(sys.argv) >= 2 and sys.argv[1] == '--batch':
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        archive = os.path.join(base, "archive", "deskmate-3.05", "extracted")
        outdir = os.path.join(base, "disassembly", "raw")
        os.makedirs(outdir, exist_ok=True)
        for name, asm, cg in [
            ("DESKTOP.PDM", "desktop.asm", "desktop-callgraph.txt"),
            ("TEXT.PDM", "text.asm", "text-callgraph.txt"),
        ]:
            inp = os.path.join(archive, name)
            if os.path.exists(inp):
                process_one(inp, os.path.join(outdir, asm), os.path.join(outdir, cg), name)
            else:
                print(f"WARNING: {inp} not found")
    else:
        print(f"Usage: {sys.argv[0]} <input.PDM> <output.asm> <callgraph.txt>")
        print(f"       {sys.argv[0]} --batch")
        sys.exit(1)


if __name__ == '__main__':
    main()
