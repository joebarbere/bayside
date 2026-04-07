#!/usr/bin/env python3
"""
Batch disassembler for DeskMate 3.05 ACC (desk accessory) files.
Parses MZ + DM89 headers, disassembles with Capstone (x86-16),
labels CALL/JMP targets, extracts call graphs, INT usage, and strings.

Adapted from batch_disasm_pdm.py for the 18 ACC files.

Usage:
    python3 batch_disasm_acc.py
"""

import struct
import os
import sys
from collections import defaultdict, OrderedDict

from capstone import Cs, CS_ARCH_X86, CS_MODE_16, CS_GRP_CALL, CS_GRP_JUMP, CS_GRP_RET, CS_GRP_INT

ARCHIVE_DIR = "/Users/joe/Documents/GitHub/bayside/archive/deskmate-3.05/extracted"
OUTPUT_DIR = "/Users/joe/Documents/GitHub/bayside/disassembly/raw/acc"

# All 18 ACC files
TARGETS = [
    ("DMACCESS.ACC", "dmaccess"),
    ("DMALARM.ACC",  "dmalarm"),
    ("DMCLIP.ACC",   "dmclip"),
    ("DMDRWPRT.ACC", "dmdrwprt"),
    ("DMHELP.ACC",   "dmhelp"),
    ("DMNOTEPD.ACC", "dmnotepd"),
    ("DMPD1.ACC",    "dmpd1"),
    ("DMPD2.ACC",    "dmpd2"),
    ("DMPDASCI.ACC", "dmpdasci"),
    ("DMPDIBMM.ACC", "dmpdibmm"),
    ("DMPDLASR.ACC", "dmpdlasr"),
    ("DMPDS.ACC",    "dmpds"),
    ("DMPHONE.ACC",  "dmphone"),
    ("DMPRTSEL.ACC", "dmprtsel"),
    ("DMSERV.ACC",   "dmserv"),
    ("DMSETUP.ACC",  "dmsetup"),
    ("DMSPELL.ACC",  "dmspell"),
    ("DMTODO.ACC",   "dmtodo"),
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


def extract_strings(data, min_length=4):
    """Extract printable ASCII strings from binary data."""
    strings = []
    current = []
    start = None
    for i, b in enumerate(data):
        if 0x20 <= b < 0x7F:
            if not current:
                start = i
            current.append(chr(b))
        else:
            if len(current) >= min_length:
                strings.append((start, ''.join(current)))
            current = []
            start = None
    if len(current) >= min_length:
        strings.append((start, ''.join(current)))
    return strings


def disassemble_acc(filepath, basename):
    """Full disassembly of an ACC file."""
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
        file_off = hdr.header_size + seg * 16 + off
        if file_off + 2 <= len(data):
            target_seg = read_word(data, file_off)
            seg_values.add(target_seg)
        seg_values.add(seg)
    seg_values = sorted(seg_values)
    print(f"  Segment values: {['%04X' % s for s in seg_values]}")

    # Extract strings from load image for summary
    strings = extract_strings(load_image, min_length=4)

    # ----- Disassembly Pass 1: Discover targets -----
    md = Cs(CS_ARCH_X86, CS_MODE_16)
    md.detail = True

    call_targets = defaultdict(int)     # linear_addr -> count of calls
    jmp_targets = set()                 # linear_addr for jump labels
    int_calls = defaultdict(list)       # int_num -> list of (addr, ah_value)
    all_instructions = []               # (address, size, mnemonic, op_str, bytes)

    def track_instruction(mnemonic, op_str, address):
        """Track call/jump/int targets from a single decoded instruction."""
        if mnemonic == "call":
            try:
                target = int(op_str, 0)
                call_targets[target] += 1
            except ValueError:
                pass

        if mnemonic.startswith("j"):
            try:
                target = int(op_str, 0)
                jmp_targets.add(target)
            except ValueError:
                pass

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
            b = load_image[pos]
            all_instructions.append((pos, 1, "db", f"0x{b:02x}", bytes([b])))
            pos += 1
        elif pos < load_size:
            b = load_image[pos]
            all_instructions.append((pos, 1, "db", f"0x{b:02x}", bytes([b])))
            pos += 1

    print(f"  Total instructions decoded: {len(all_instructions)}")
    print(f"  CALL targets: {len(call_targets)}")
    print(f"  JMP targets: {len(jmp_targets)}")

    # ----- Identify functions -----
    functions = OrderedDict()

    # Entry point is always a function
    functions[entry_linear] = "start"

    # All call targets are functions
    for addr in sorted(call_targets.keys()):
        if addr < load_size:
            functions[addr] = f"sub_{addr:05X}"

    # Scan for push bp; mov bp, sp prologues
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

    # ----- Find INT service codes -----
    int_e0_services = set()
    int_21_services = set()

    for i, (addr, size, mnem, ops, raw) in enumerate(all_instructions):
        if mnem == "int":
            int_num = None
            try:
                int_num = int(ops, 0)
            except ValueError:
                continue

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
    asm_lines.append(f"; Generated by batch_disasm_acc.py")
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

    # Strings section
    asm_lines.append(f"; Notable strings found in load image:")
    shown = 0
    for soff, s in strings:
        if shown >= 50:
            asm_lines.append(f";   ... ({len(strings) - 50} more strings)")
            break
        asm_lines.append(f";   0x{soff:05X}: \"{s}\"")
        shown += 1
    asm_lines.append(f";")
    asm_lines.append("")

    for addr, size, mnem, ops, raw in all_instructions:
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
        hex_str = hex_bytes.ljust(14)

        # Replace raw target addresses in operands with labels
        display_ops = ops
        if (mnem == "call" or mnem.startswith("j")) and not ops.startswith("["):
            try:
                if ops.startswith("0x"):
                    target = int(ops, 16)
                else:
                    target = int(ops, 0)
                if target in functions:
                    display_ops = functions[target]
                elif target in jmp_targets:
                    display_ops = f"loc_{target:05X}"
            except ValueError:
                pass

        # Compute seg:off representation
        if entry_cs > 0 and addr >= entry_cs * 16:
            rel = addr - entry_cs * 16
            seg_off_str = f"  ; {entry_cs:04X}:{rel:04X}"
        else:
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

    cg_lines = []
    cg_lines.append(f"Call Graph and Summary: {os.path.basename(filepath)}")
    cg_lines.append(f"{'='*60}")
    cg_lines.append(f"")
    cg_lines.append(f"File: {os.path.basename(filepath)}")
    cg_lines.append(f"Size: {actual_size} bytes")
    cg_lines.append(f"Segments: {len(seg_values)} ({', '.join('%04X' % s for s in seg_values)})")
    cg_lines.append(f"Relocations: {hdr.e_crlc}")
    cg_lines.append(f"Total functions: {len(functions)}")
    cg_lines.append(f"Entry point: {entry_cs:04X}:{entry_ip:04X}")
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

    # Full function list with call edges
    cg_lines.append(f"All functions ({len(functions)}):")
    cg_lines.append(f"{'Address':<10s} {'Name':<22s} {'Size':<8s} {'Calls Made'}")
    cg_lines.append(f"{'-'*10} {'-'*22} {'-'*8} {'-'*30}")

    for func_addr in sorted(functions.keys()):
        name = functions[func_addr]
        sz = func_sizes.get(func_addr, 0)
        func_end = func_addr + sz

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
        "seg_list": seg_values,
        "relocs": hdr.e_crlc,
        "functions": len(functions),
        "imports": imports,
        "int_e0": sorted(int_e0_services),
        "int_21": sorted(int_21_services),
        "int_calls": dict(int_calls),
        "entry": f"{entry_cs:04X}:{entry_ip:04X}",
        "dm_flags": hdr.dm_flags,
        "strings": strings,
    }


def classify_acc(name, strings_list):
    """Return a brief description based on filename and strings found."""
    str_texts = [s for _, s in strings_list]
    str_lower = ' '.join(str_texts).lower()

    descs = {
        "DMACCESS.ACC":  "Main accessory manager -- dispatches and loads other .ACC modules",
        "DMALARM.ACC":   "Alarm/notification system -- schedules and displays timed alerts",
        "DMCLIP.ACC":    "Clipboard manager -- cut/copy/paste support across DeskMate apps",
        "DMDRWPRT.ACC":  "Draw print support -- printing backend for DRAW.PDM vector output",
        "DMHELP.ACC":    "Help system -- context-sensitive help viewer for all DeskMate apps",
        "DMNOTEPD.ACC":  "Notepad accessory -- simple text editor/note-taking popup",
        "DMPD1.ACC":     "Printer driver 1 -- device driver for dot-matrix printers",
        "DMPD2.ACC":     "Printer driver 2 -- additional dot-matrix printer support",
        "DMPDASCI.ACC":  "ASCII printer driver -- plain text/generic printer output",
        "DMPDIBMM.ACC":  "IBM matrix printer driver -- IBM Proprinter/compatible support",
        "DMPDLASR.ACC":  "Laser printer driver -- HP LaserJet/compatible PCL output",
        "DMPDS.ACC":     "Printer driver services -- shared printing infrastructure",
        "DMPHONE.ACC":   "Phone dialer -- modem-based telephone dialer accessory",
        "DMPRTSEL.ACC":  "Printer selector -- UI for choosing and configuring printers",
        "DMSERV.ACC":    "Service/utility module -- background services and system utilities",
        "DMSETUP.ACC":   "Setup/preferences -- DeskMate configuration and preferences UI",
        "DMSPELL.ACC":   "Spell checker -- dictionary-based spelling verification",
        "DMTODO.ACC":    "To-do list -- task/reminder tracking accessory",
    }

    desc = descs.get(name, "Unknown accessory")

    # Augment with string evidence
    notable = []
    for s in str_texts:
        sl = s.lower()
        if any(kw in sl for kw in ['error', 'warning', '.hlp', '.dic', '.cfg',
                                     'printer', 'font', 'alarm', 'clip',
                                     'notepad', 'phone', 'spell', 'todo',
                                     'setup', 'help', 'menu', 'file',
                                     'modem', 'baud', 'dial']):
            if len(s) >= 4 and len(s) <= 60:
                notable.append(s)
    # Deduplicate preserving order
    seen = set()
    unique_notable = []
    for s in notable:
        if s not in seen:
            seen.add(s)
            unique_notable.append(s)

    return desc, unique_notable[:10]


def write_summary(results):
    """Write acc-summary.txt with a table and analysis of all ACC files."""
    lines = []
    lines.append("DeskMate 3.05 ACC (Desk Accessory) Disassembly Summary")
    lines.append("=" * 70)
    lines.append("")
    lines.append(f"Total ACC files processed: {len(results)}")
    lines.append(f"Total combined size: {sum(r['size'] for r in results):,} bytes")
    lines.append(f"Total functions identified: {sum(r['functions'] for r in results)}")
    lines.append("")

    # Main table
    lines.append("Overview Table")
    lines.append("-" * 70)
    header = f"{'File':<16s} {'Size':>7s} {'Segs':>5s} {'Reloc':>6s} {'Funcs':>6s} {'Entry':<12s} {'Imports'}"
    lines.append(header)
    lines.append(f"{'-'*16} {'-'*7} {'-'*5} {'-'*6} {'-'*6} {'-'*12} {'-'*20}")
    for r in results:
        imports_str = ", ".join(r["imports"]) if r["imports"] else "(none)"
        lines.append(f"{r['name']:<16s} {r['size']:>7d} {r['segments']:>5d} {r['relocs']:>6d} {r['functions']:>6d} {r['entry']:<12s} {imports_str}")
    lines.append("")

    # INT usage table
    lines.append("INT Call Summary")
    lines.append("-" * 70)
    all_int_nums = set()
    for r in results:
        for k in r["int_calls"]:
            all_int_nums.add(k)

    int_header = f"{'File':<16s}"
    for inum in sorted(all_int_nums):
        int_header += f" {'INT %02Xh' % inum:>8s}"
    lines.append(int_header)
    lines.append("-" * (16 + 9 * len(all_int_nums)))
    for r in results:
        row = f"{r['name']:<16s}"
        for inum in sorted(all_int_nums):
            count = len(r["int_calls"].get(inum, []))
            row += f" {count:>8d}" if count else f" {'':>8s}"
            # We write '-' for zero
        # Re-do properly
        row = f"{r['name']:<16s}"
        for inum in sorted(all_int_nums):
            count = len(r["int_calls"].get(inum, []))
            if count:
                row += f" {count:>8d}"
            else:
                row += f" {'-':>8s}"
        lines.append(row)
    lines.append("")

    # Per-file descriptions
    lines.append("Per-File Analysis")
    lines.append("=" * 70)
    for r in results:
        desc, notable_strings = classify_acc(r["name"], r["strings"])
        lines.append("")
        lines.append(f"--- {r['name']} ---")
        lines.append(f"  Description: {desc}")
        lines.append(f"  Size: {r['size']:,} bytes")
        lines.append(f"  Functions: {r['functions']}")
        lines.append(f"  Imports: {', '.join(r['imports']) if r['imports'] else '(none)'}")
        lines.append(f"  DM flags: 0x{r['dm_flags']:04X}")

        if r["int_e0"]:
            lines.append(f"  INT E0h (DeskMate API) services: {', '.join('AH=%02Xh' % s for s in r['int_e0'])}")
        if r["int_21"]:
            dos_svc_names = {
                0x3C: "Create", 0x3D: "Open", 0x3E: "Close",
                0x3F: "Read", 0x40: "Write", 0x42: "Seek",
                0x41: "Delete", 0x4E: "FindFirst", 0x4F: "FindNext",
                0x48: "Alloc", 0x49: "Free", 0x4A: "Realloc",
                0x2A: "GetDate", 0x2C: "GetTime",
                0x44: "IOCTL", 0x4C: "Exit",
            }
            svc_strs = []
            for s in r["int_21"]:
                name = dos_svc_names.get(s, "")
                svc_strs.append(f"AH={s:02X}h{(' ('+name+')') if name else ''}")
            lines.append(f"  INT 21h (DOS API) services: {', '.join(svc_strs)}")

        if notable_strings:
            lines.append(f"  Notable strings:")
            for s in notable_strings[:8]:
                lines.append(f"    \"{s}\"")
    lines.append("")

    # Reverse engineering priority analysis
    lines.append("")
    lines.append("Reverse Engineering Priority Analysis")
    lines.append("=" * 70)
    lines.append("")
    lines.append("HIGH PRIORITY (core DeskMate infrastructure):")
    lines.append("  DMACCESS.ACC  -- Accessory manager, needed to understand ACC loading")
    lines.append("  DMHELP.ACC    -- Help system, largest ACC, used by all apps")
    lines.append("  DMCLIP.ACC    -- Clipboard, essential for inter-app data exchange")
    lines.append("  DMPDS.ACC     -- Printer driver services, shared printing infrastructure")
    lines.append("  DMSERV.ACC    -- Background services, likely system-wide utilities")
    lines.append("")
    lines.append("MEDIUM PRIORITY (user-facing accessories):")
    lines.append("  DMNOTEPD.ACC  -- Notepad, good standalone RE target (self-contained UI)")
    lines.append("  DMPHONE.ACC   -- Phone dialer, exercises modem/serial port code")
    lines.append("  DMSETUP.ACC   -- Setup, reveals configuration storage format")
    lines.append("  DMALARM.ACC   -- Alarm, shows timer/interrupt handling")
    lines.append("  DMTODO.ACC    -- To-do list, small and self-contained")
    lines.append("  DMSPELL.ACC   -- Spell checker, reveals dictionary file format")
    lines.append("  DMPRTSEL.ACC  -- Printer selector UI")
    lines.append("")
    lines.append("LOW PRIORITY (device-specific drivers):")
    lines.append("  DMPD1.ACC     -- Printer driver 1 (specific hardware)")
    lines.append("  DMPD2.ACC     -- Printer driver 2 (specific hardware)")
    lines.append("  DMPDASCI.ACC  -- ASCII printer (simple output)")
    lines.append("  DMPDIBMM.ACC  -- IBM matrix printer (specific hardware)")
    lines.append("  DMPDLASR.ACC  -- Laser printer (specific hardware)")
    lines.append("  DMDRWPRT.ACC  -- Draw print (tiny, 1.6KB, very specialized)")
    lines.append("")

    summary_path = os.path.join(OUTPUT_DIR, "acc-summary.txt")
    with open(summary_path, "w") as f:
        f.write("\n".join(lines))
        f.write("\n")
    print(f"\nWrote summary: {summary_path}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    results = []
    for filename, basename in TARGETS:
        filepath = os.path.join(ARCHIVE_DIR, filename)
        if not os.path.exists(filepath):
            print(f"WARNING: {filepath} not found, skipping")
            continue
        try:
            info = disassemble_acc(filepath, basename)
            results.append(info)
        except Exception as e:
            print(f"ERROR processing {filename}: {e}")
            import traceback
            traceback.print_exc()

    # Print summary table
    print(f"\n\n{'='*60}")
    print(f"BATCH ACC DISASSEMBLY SUMMARY")
    print(f"{'='*60}")
    print(f"{'File':<16s} {'Size':>8s} {'Segs':>5s} {'Relocs':>7s} {'Funcs':>6s} {'Entry':<12s} {'Imports'}")
    print(f"{'-'*16} {'-'*8} {'-'*5} {'-'*7} {'-'*6} {'-'*12} {'-'*20}")
    for r in results:
        imports_str = ", ".join(r["imports"]) if r["imports"] else "(none)"
        print(f"{r['name']:<16s} {r['size']:>8d} {r['segments']:>5d} {r['relocs']:>7d} {r['functions']:>6d} {r['entry']:<12s} {imports_str}")

    print(f"\nFiles processed: {len(results)}/{len(TARGETS)}")
    print(f"Output directory: {OUTPUT_DIR}")

    # Write the summary file
    if results:
        write_summary(results)


if __name__ == "__main__":
    main()
