#!/usr/bin/env python3
"""
Batch disassembler for DeskMate 3.05 PDM files.
Parses MZ + DM89 headers, disassembles with Capstone (x86-16),
labels CALL/JMP targets, extracts call graphs and INT usage.

Usage:
    python3 batch_disasm_pdm.py
"""

import struct
import os
import sys
from collections import defaultdict, OrderedDict

from capstone import Cs, CS_ARCH_X86, CS_MODE_16, CS_GRP_CALL, CS_GRP_JUMP, CS_GRP_RET, CS_GRP_INT

ARCHIVE_DIR = "/Users/joe/Documents/GitHub/bayside/archive/deskmate-3.05/extracted"
OUTPUT_DIR = "/Users/joe/Documents/GitHub/bayside/disassembly/raw"

# Files to process: (filename, output_basename)
TARGETS = [
    ("WRKSHEET.PDM", "wrksheet"),
    ("DRAW.PDM",     "draw"),
    ("FILER.PDM",    "filer"),
    ("CALENDAR.PDM", "calendar"),
    ("ADDRESS.PDM",  "address"),
    ("TELECOM.PDM",  "telecom"),
    ("PC_LINK.PDM",  "pc_link"),
    ("FORMSET.PDM",  "formset"),
    ("MAILMRGE.PDM", "mailmrge"),
    ("INSTALL.PDM",  "install-pdm"),
]


def read_word(data, offset):
    return struct.unpack_from("<H", data, offset)[0]


def read_dword(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


class MZHeader:
    def __init__(self, data):
        self.e_magic = read_word(data, 0x00)
        self.e_cblp = read_word(data, 0x02)
        self.e_cp = read_word(data, 0x04)
        self.e_crlc = read_word(data, 0x06)
        self.e_cparhdr = read_word(data, 0x08)
        self.e_minalloc = read_word(data, 0x0A)
        self.e_maxalloc = read_word(data, 0x0C)
        self.e_ss = read_word(data, 0x0E)
        self.e_sp = read_word(data, 0x10)
        self.e_csum = read_word(data, 0x12)
        self.e_ip = read_word(data, 0x14)
        self.e_cs = read_word(data, 0x16)
        self.e_lfarlc = read_word(data, 0x18)
        self.e_ovno = read_word(data, 0x1A)

        # DM89 extended header
        self.dm89_magic = data[0x1C:0x20].decode("ascii", errors="replace")
        self.dm_version = read_word(data, 0x20)
        self.dm_type = read_word(data, 0x22)
        self.dm_cs = read_word(data, 0x26)
        self.dm_ip = read_word(data, 0x28)
        self.dm_cs2 = read_word(data, 0x2A)
        self.dm_flags = read_word(data, 0x3C)

        self.header_size = self.e_cparhdr * 16

        # Compute file size from header
        if self.e_cblp:
            self.file_size = (self.e_cp - 1) * 512 + self.e_cblp
        else:
            self.file_size = self.e_cp * 512

    def entry_cs(self):
        """Use DM89 cs preferentially."""
        return self.dm_cs

    def entry_ip(self):
        """Use DM89 ip preferentially."""
        return self.dm_ip


def parse_imports(data, e_lfarlc):
    """Parse import name table between 0x42 and e_lfarlc."""
    imports = []
    offset = 0x42
    while offset + 10 <= e_lfarlc:
        name_bytes = data[offset:offset+10]
        name = name_bytes.split(b'\x00')[0].decode("ascii", errors="replace")
        if name:
            imports.append(name)
        offset += 10
    return imports


def parse_relocations(data, e_lfarlc, e_crlc):
    """Parse MZ relocation table."""
    relocs = []
    offset = e_lfarlc
    for _ in range(e_crlc):
        if offset + 4 > len(data):
            break
        r_off = read_word(data, offset)
        r_seg = read_word(data, offset + 2)
        relocs.append((r_seg, r_off))
        offset += 4
    return relocs


def compute_segments(relocs, hdr, data_size):
    """Determine unique segment values from relocations and header."""
    segs = set()
    segs.add(0)  # segment 0 always exists (data/code base)
    segs.add(hdr.entry_cs())
    segs.add(hdr.e_ss)
    for seg, off in relocs:
        segs.add(seg)
    # Also look at relocation targets (the segment values stored at relocation points)
    for seg, off in relocs:
        file_off = hdr.header_size + seg * 16 + off
        if file_off + 2 <= len(data_size):
            target_seg = read_word(data_size, file_off)
            segs.add(target_seg)
    return sorted(segs)


def disassemble_pdm(filepath, basename):
    """Full disassembly of a PDM file."""
    print(f"\n{'='*60}")
    print(f"Processing: {os.path.basename(filepath)} -> {basename}")
    print(f"{'='*60}")

    with open(filepath, "rb") as f:
        data = f.read()

    actual_size = len(data)
    hdr = MZHeader(data)

    assert hdr.e_magic == 0x5A4D, f"Not an MZ executable: {filepath}"
    assert hdr.dm89_magic == "DM89", f"No DM89 signature: {filepath}"

    # Parse imports
    imports = parse_imports(data, hdr.e_lfarlc)

    # Parse relocations
    relocs = parse_relocations(data, hdr.e_lfarlc, hdr.e_crlc)

    # Code/data starts after header
    load_image = data[hdr.header_size:]
    load_size = len(load_image)

    entry_cs = hdr.entry_cs()
    entry_ip = hdr.entry_ip()
    entry_linear = entry_cs * 16 + entry_ip

    print(f"  File size: {actual_size} bytes")
    print(f"  Header size: {hdr.header_size} bytes (0x{hdr.header_size:04X})")
    print(f"  Load image: {load_size} bytes")
    print(f"  Entry point: {entry_cs:04X}:{entry_ip:04X} (linear 0x{entry_linear:05X})")
    print(f"  SS:SP = {hdr.e_ss:04X}:{hdr.e_sp:04X}")
    print(f"  Relocations: {hdr.e_crlc}")
    print(f"  Imports: {imports if imports else '(none)'}")
    print(f"  DM flags: 0x{hdr.dm_flags:04X}")

    # Collect unique segment bases from relocation targets
    seg_values = set()
    seg_values.add(0)
    seg_values.add(entry_cs)
    seg_values.add(hdr.e_ss)
    for seg, off in relocs:
        # Read the segment value stored at the relocation point
        file_off = hdr.header_size + seg * 16 + off
        if file_off + 2 <= len(data):
            target_seg = read_word(data, file_off)
            seg_values.add(target_seg)
        seg_values.add(seg)
    seg_values = sorted(seg_values)
    print(f"  Segment values: {['%04X' % s for s in seg_values]}")

    # ----- Disassembly Pass 1: Discover targets -----
    md = Cs(CS_ARCH_X86, CS_MODE_16)
    md.detail = True

    # We'll disassemble the entire load image linearly.
    # Track CALL and JMP targets for labeling.
    call_targets = defaultdict(int)     # linear_addr -> count of calls
    jmp_targets = set()                 # linear_addr for jump labels
    int_calls = defaultdict(list)       # int_num -> list of (addr, ah_value)
    all_instructions = []               # (address, size, mnemonic, op_str, bytes)

    # Disassemble using chunked approach to handle undecodable bytes.
    # md.disasm() stops at the first byte it cannot decode, so we
    # must resume from the next byte when that happens.
    def track_instruction(mnemonic, op_str, address):
        """Track call/jump/int targets from a single decoded instruction."""
        # Track call targets
        if mnemonic == "call":
            try:
                target = int(op_str, 0)
                call_targets[target] += 1
            except ValueError:
                pass

        # Track jump targets
        if mnemonic.startswith("j"):
            try:
                target = int(op_str, 0)
                jmp_targets.add(target)
            except ValueError:
                pass

        # Track INT calls
        if mnemonic == "int":
            try:
                int_num = int(op_str, 0)
                int_calls[int_num].append(address)
            except ValueError:
                pass

    pos = 0
    while pos < load_size:
        decoded_any = False
        for insn in md.disasm(load_image[pos:], pos):
            all_instructions.append((insn.address, insn.size, insn.mnemonic, insn.op_str, bytes(insn.bytes)))
            track_instruction(insn.mnemonic, insn.op_str, insn.address)
            pos = insn.address + insn.size
            decoded_any = True
        if not decoded_any:
            # Could not decode byte at pos -- emit as db and skip
            b = load_image[pos]
            all_instructions.append((pos, 1, "db", f"0x{b:02x}", bytes([b])))
            pos += 1
        elif pos < load_size:
            # disasm stopped mid-stream (hit undecodable byte)
            b = load_image[pos]
            all_instructions.append((pos, 1, "db", f"0x{b:02x}", bytes([b])))
            pos += 1

    print(f"  Total instructions decoded: {len(all_instructions)}")
    print(f"  CALL targets: {len(call_targets)}")
    print(f"  JMP targets: {len(jmp_targets)}")

    # ----- Identify functions -----
    # A function is: a CALL target, OR begins with push bp / mov bp, sp
    functions = OrderedDict()  # linear_addr -> name

    # Entry point is always a function
    functions[entry_linear] = "start"

    # All call targets are functions
    for addr in sorted(call_targets.keys()):
        if addr < load_size:
            functions[addr] = f"sub_{addr:05X}"

    # Also scan for push bp; mov bp, sp prologues
    addr_to_idx = {}
    for i, (addr, size, mnem, ops, raw) in enumerate(all_instructions):
        addr_to_idx[addr] = i

    for i, (addr, size, mnem, ops, raw) in enumerate(all_instructions):
        if mnem == "push" and ops == "bp":
            if i + 1 < len(all_instructions):
                next_mnem = all_instructions[i+1][2]
                next_ops = all_instructions[i+1][3]
                if next_mnem == "mov" and next_ops == "bp, sp":
                    if addr not in functions:
                        functions[addr] = f"sub_{addr:05X}"

    functions = OrderedDict(sorted(functions.items()))
    print(f"  Functions identified: {len(functions)}")

    # ----- Compute function sizes -----
    func_addrs = sorted(functions.keys())
    func_sizes = {}
    for i, addr in enumerate(func_addrs):
        if i + 1 < len(func_addrs):
            func_sizes[addr] = func_addrs[i+1] - addr
        else:
            func_sizes[addr] = load_size - addr

    # ----- Find INT E0h and INT 21h service codes -----
    int_e0_services = set()
    int_21_services = set()

    # Build a quick map from address to instruction index for lookback
    for i, (addr, size, mnem, ops, raw) in enumerate(all_instructions):
        if mnem == "int":
            int_num = None
            try:
                int_num = int(ops, 0)
            except ValueError:
                continue

            # Look backwards for mov ah, XX
            ah_val = None
            for j in range(i-1, max(i-8, -1), -1):
                prev_mnem = all_instructions[j][2]
                prev_ops = all_instructions[j][3]
                if prev_mnem == "mov" and prev_ops.startswith("ah,"):
                    try:
                        ah_val = int(prev_ops.split(",")[1].strip(), 0)
                    except ValueError:
                        pass
                    break
                # Also check for mov ax, XXXX (AH is high byte)
                if prev_mnem == "mov" and prev_ops.startswith("ax,"):
                    try:
                        ax_val = int(prev_ops.split(",")[1].strip(), 0)
                        ah_val = (ax_val >> 8) & 0xFF
                    except ValueError:
                        pass
                    break

            if int_num == 0xE0 and ah_val is not None:
                int_e0_services.add(ah_val)
            elif int_num == 0x21 and ah_val is not None:
                int_21_services.add(ah_val)

    # ----- Pass 2: Generate labeled disassembly -----
    asm_lines = []
    asm_lines.append(f"; Raw disassembly of {os.path.basename(filepath)}")
    asm_lines.append(f"; Generated by batch_disasm_pdm.py")
    asm_lines.append(f";")
    asm_lines.append(f"; File size: {actual_size} bytes")
    asm_lines.append(f"; Load image: {load_size} bytes")
    asm_lines.append(f"; Entry point: {entry_cs:04X}:{entry_ip:04X} (linear 0x{entry_linear:05X})")
    asm_lines.append(f"; SS:SP: {hdr.e_ss:04X}:{hdr.e_sp:04X}")
    asm_lines.append(f"; Relocations: {hdr.e_crlc}")
    asm_lines.append(f"; Imports: {', '.join(imports) if imports else '(none)'}")
    asm_lines.append(f"; Segments: {', '.join('%04X' % s for s in seg_values)}")
    asm_lines.append(f"; Functions: {len(functions)}")
    asm_lines.append(f"; DM flags: 0x{hdr.dm_flags:04X}")
    asm_lines.append(f";")
    asm_lines.append("")

    for addr, size, mnem, ops, raw in all_instructions:
        prefix_parts = []

        # Function label
        if addr in functions:
            asm_lines.append("")
            asm_lines.append(f"; ---- {functions[addr]} ----")
            asm_lines.append(f"{functions[addr]}:")

        # Jump target label (only if not already a function)
        elif addr in jmp_targets:
            asm_lines.append(f"loc_{addr:05X}:")

        # Format: linear_addr  hex_bytes  mnemonic  operands
        hex_bytes = raw.hex()
        # Pad hex bytes to 12 chars for alignment
        hex_str = hex_bytes.ljust(14)

        # Replace raw target addresses in operands with labels where possible
        display_ops = ops
        if (mnem == "call" or mnem.startswith("j")) and ops.startswith("0x"):
            try:
                target = int(ops, 16)
                if target in functions:
                    display_ops = functions[target]
                elif target in jmp_targets:
                    display_ops = f"loc_{target:05X}"
            except ValueError:
                pass
        elif mnem == "call" or mnem.startswith("j"):
            try:
                target = int(ops, 0)
                if target in functions:
                    display_ops = functions[target]
                elif target in jmp_targets:
                    display_ops = f"loc_{target:05X}"
            except ValueError:
                pass

        # Compute seg:off representation
        # Use the entry CS as a reference: if addr >= entry_cs*16, use CS-relative
        seg_off_str = ""
        if entry_cs > 0 and addr >= entry_cs * 16:
            rel = addr - entry_cs * 16
            seg_off_str = f"  ; {entry_cs:04X}:{rel:04X}"
        else:
            # Segment 0 relative
            seg_off_str = f"  ; 0000:{addr:04X}"

        line = f"  {addr:05X}  {hex_str} {mnem:<8s} {display_ops}{seg_off_str}"
        asm_lines.append(line)

    # Write ASM file
    asm_path = os.path.join(OUTPUT_DIR, f"{basename}.asm")
    with open(asm_path, "w") as f:
        f.write("\n".join(asm_lines))
        f.write("\n")
    print(f"  Wrote: {asm_path}")

    # ----- Generate call graph -----
    cg_lines = []
    cg_lines.append(f"Call Graph and Summary: {os.path.basename(filepath)}")
    cg_lines.append(f"{'='*60}")
    cg_lines.append(f"")
    cg_lines.append(f"File: {os.path.basename(filepath)}")
    cg_lines.append(f"Size: {actual_size} bytes")
    cg_lines.append(f"Segments: {len(seg_values)} ({', '.join('%04X' % s for s in seg_values)})")
    cg_lines.append(f"Relocations: {hdr.e_crlc}")
    cg_lines.append(f"Total functions: {len(functions)}")
    cg_lines.append(f"Entry point: {entry_cs:04X}:{entry_ip:04X} (CRT startup -> _main)")
    cg_lines.append(f"Imports: {', '.join(imports) if imports else '(none)'}")
    cg_lines.append(f"DM flags: 0x{hdr.dm_flags:04X}")
    cg_lines.append(f"")

    # INT E0h services (DeskMate API)
    cg_lines.append(f"INT E0h services (DeskMate API): {len(int_e0_services)}")
    if int_e0_services:
        for svc in sorted(int_e0_services):
            cg_lines.append(f"  AH={svc:02X}h")
    else:
        cg_lines.append(f"  (none detected)")
    cg_lines.append(f"")

    # INT 21h services (DOS API)
    cg_lines.append(f"INT 21h services (DOS API): {len(int_21_services)}")
    dos_svc_names = {
        0x00: "Terminate program",
        0x01: "Read character with echo",
        0x02: "Display character",
        0x06: "Direct console I/O",
        0x09: "Display string",
        0x0A: "Buffered input",
        0x0C: "Flush buffer and read",
        0x19: "Get current drive",
        0x1A: "Set DTA",
        0x25: "Set interrupt vector",
        0x2A: "Get date",
        0x2B: "Set date",
        0x2C: "Get time",
        0x2D: "Set time",
        0x30: "Get DOS version",
        0x35: "Get interrupt vector",
        0x36: "Get disk free space",
        0x39: "Create directory",
        0x3A: "Remove directory",
        0x3B: "Change directory",
        0x3C: "Create file",
        0x3D: "Open file",
        0x3E: "Close file",
        0x3F: "Read file",
        0x40: "Write file",
        0x41: "Delete file",
        0x42: "Seek file",
        0x43: "Get/set file attributes",
        0x44: "IOCTL",
        0x47: "Get current directory",
        0x48: "Allocate memory",
        0x49: "Free memory",
        0x4A: "Resize memory block",
        0x4C: "Exit process",
        0x4E: "Find first file",
        0x4F: "Find next file",
        0x56: "Rename file",
        0x57: "Get/set file date/time",
        0x59: "Get extended error",
        0x5A: "Create temporary file",
    }
    if int_21_services:
        for svc in sorted(int_21_services):
            name = dos_svc_names.get(svc, "")
            cg_lines.append(f"  AH={svc:02X}h  {name}")
    else:
        cg_lines.append(f"  (none detected)")
    cg_lines.append(f"")

    # All INT usage
    cg_lines.append(f"All INT calls:")
    for int_num in sorted(int_calls.keys()):
        addrs = int_calls[int_num]
        cg_lines.append(f"  INT {int_num:02X}h: {len(addrs)} call(s)")
    cg_lines.append(f"")

    # Largest functions
    cg_lines.append(f"Largest functions (top 20):")
    sorted_by_size = sorted(func_sizes.items(), key=lambda x: x[1], reverse=True)
    for addr, sz in sorted_by_size[:20]:
        name = functions.get(addr, f"sub_{addr:05X}")
        cg_lines.append(f"  {name:<20s} at 0x{addr:05X}  size={sz} bytes")
    cg_lines.append(f"")

    # Full function list
    cg_lines.append(f"All functions ({len(functions)}):")
    cg_lines.append(f"{'Address':<10s} {'Name':<22s} {'Size':<8s} {'Calls Made'}")
    cg_lines.append(f"{'-'*10} {'-'*22} {'-'*8} {'-'*30}")

    # For each function, find what it calls
    for func_addr in sorted(functions.keys()):
        name = functions[func_addr]
        sz = func_sizes.get(func_addr, 0)
        # Find end of this function
        func_end = func_addr + sz

        # Collect calls made by this function
        calls_made = []
        for iaddr, isize, imnem, iops, iraw in all_instructions:
            if iaddr < func_addr:
                continue
            if iaddr >= func_end:
                break
            if imnem == "call":
                try:
                    if iops.startswith("0x"):
                        target = int(iops, 16)
                    else:
                        target = int(iops, 0)
                    target_name = functions.get(target, f"sub_{target:05X}")
                    calls_made.append(target_name)
                except ValueError:
                    calls_made.append(f"[indirect:{iops}]")

        calls_str = ", ".join(calls_made[:10])
        if len(calls_made) > 10:
            calls_str += f" (+{len(calls_made)-10} more)"
        cg_lines.append(f"0x{func_addr:05X}  {name:<22s} {sz:<8d} {calls_str}")

    # Write call graph
    cg_path = os.path.join(OUTPUT_DIR, f"{basename}-callgraph.txt")
    with open(cg_path, "w") as f:
        f.write("\n".join(cg_lines))
        f.write("\n")
    print(f"  Wrote: {cg_path}")

    return {
        "name": os.path.basename(filepath),
        "basename": basename,
        "size": actual_size,
        "segments": len(seg_values),
        "relocs": hdr.e_crlc,
        "functions": len(functions),
        "imports": imports,
        "int_e0": sorted(int_e0_services),
        "int_21": sorted(int_21_services),
        "entry": f"{entry_cs:04X}:{entry_ip:04X}",
    }


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    results = []
    for filename, basename in TARGETS:
        filepath = os.path.join(ARCHIVE_DIR, filename)
        if not os.path.exists(filepath):
            print(f"WARNING: {filepath} not found, skipping")
            continue
        try:
            info = disassemble_pdm(filepath, basename)
            results.append(info)
        except Exception as e:
            print(f"ERROR processing {filename}: {e}")
            import traceback
            traceback.print_exc()

    # Print summary
    print(f"\n\n{'='*60}")
    print(f"BATCH DISASSEMBLY SUMMARY")
    print(f"{'='*60}")
    print(f"{'File':<16s} {'Size':>8s} {'Segs':>5s} {'Relocs':>7s} {'Funcs':>6s} {'Entry':<12s} {'Imports'}")
    print(f"{'-'*16} {'-'*8} {'-'*5} {'-'*7} {'-'*6} {'-'*12} {'-'*20}")
    for r in results:
        imports_str = ", ".join(r["imports"]) if r["imports"] else "(none)"
        print(f"{r['name']:<16s} {r['size']:>8d} {r['segments']:>5d} {r['relocs']:>7d} {r['functions']:>6d} {r['entry']:<12s} {imports_str}")

    print(f"\nFiles processed: {len(results)}/{len(TARGETS)}")
    print(f"Output directory: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
