#!/usr/bin/env python3
"""
DMVID.EXE Disassembler
Generates annotated 16-bit x86 disassembly using Capstone engine.
Targets: DeskMate 3.05 DMVID.EXE (Microsoft C 5.0, small model)
"""

import struct
import sys
from collections import defaultdict
from capstone import *
from capstone.x86 import *

INPUT = "/Users/joe/Documents/GitHub/bayside/archive/deskmate-3.05/extracted/DMVID.EXE"
OUTPUT_ASM = "/Users/joe/Documents/GitHub/bayside/disassembly/raw/dmvid.asm"
OUTPUT_CALLGRAPH = "/Users/joe/Documents/GitHub/bayside/disassembly/raw/dmvid-callgraph.txt"


def safe_operands(insn):
    """Get operands safely, returning empty list for skipdata instructions."""
    try:
        return insn.operands
    except Exception:
        return []


def parse_mz_header(data):
    """Parse DOS MZ executable header."""
    h = {}
    h['magic'] = data[0:2]
    assert h['magic'] == b'MZ', "Not an MZ executable"
    h['last_page_bytes'] = struct.unpack_from('<H', data, 0x02)[0]
    h['pages'] = struct.unpack_from('<H', data, 0x04)[0]
    h['num_relocs'] = struct.unpack_from('<H', data, 0x06)[0]
    h['header_paragraphs'] = struct.unpack_from('<H', data, 0x08)[0]
    h['min_alloc'] = struct.unpack_from('<H', data, 0x0A)[0]
    h['max_alloc'] = struct.unpack_from('<H', data, 0x0C)[0]
    h['ss'] = struct.unpack_from('<H', data, 0x0E)[0]
    h['sp'] = struct.unpack_from('<H', data, 0x10)[0]
    h['checksum'] = struct.unpack_from('<H', data, 0x12)[0]
    h['ip'] = struct.unpack_from('<H', data, 0x14)[0]
    h['cs'] = struct.unpack_from('<H', data, 0x16)[0]
    h['reloc_offset'] = struct.unpack_from('<H', data, 0x18)[0]
    h['overlay'] = struct.unpack_from('<H', data, 0x1A)[0]
    h['header_size'] = h['header_paragraphs'] * 16
    if h['last_page_bytes']:
        h['file_size'] = (h['pages'] - 1) * 512 + h['last_page_bytes']
    else:
        h['file_size'] = h['pages'] * 512
    h['code_size'] = h['file_size'] - h['header_size']

    # Parse relocations
    h['relocs'] = []
    for i in range(h['num_relocs']):
        off = h['reloc_offset'] + i * 4
        r_off = struct.unpack_from('<H', data, off)[0]
        r_seg = struct.unpack_from('<H', data, off + 2)[0]
        file_off = h['header_size'] + r_seg * 16 + r_off
        val = struct.unpack_from('<H', data, file_off)[0]
        h['relocs'].append({
            'seg': r_seg, 'off': r_off,
            'file_off': file_off, 'value': val
        })

    return h


def find_strings(code_data, min_len=4):
    """Find printable ASCII strings in binary data."""
    strings = {}
    i = 0
    while i < len(code_data):
        if 0x20 <= code_data[i] <= 0x7e:
            start = i
            while i < len(code_data) and 0x20 <= code_data[i] <= 0x7e:
                i += 1
            # Accept if terminated by NUL and long enough
            if i - start >= min_len:
                s = code_data[start:i].decode('ascii', errors='replace')
                strings[start] = s
        else:
            i += 1
    return strings


def identify_int21h_functions(ah_val):
    """Return DOS INT 21h function name."""
    funcs = {
        0x00: "terminate_program",
        0x01: "stdin_input_with_echo",
        0x02: "stdout_output",
        0x06: "direct_console_io",
        0x07: "direct_stdin_input_no_echo",
        0x08: "stdin_input_no_echo",
        0x09: "print_string_ds_dx",
        0x0A: "buffered_stdin_input",
        0x0B: "check_stdin_status",
        0x0C: "flush_stdin_and_input",
        0x19: "get_current_drive",
        0x1A: "set_dta",
        0x25: "set_interrupt_vector",
        0x2C: "get_time",
        0x30: "get_dos_version",
        0x33: "get_set_ctrl_break",
        0x35: "get_interrupt_vector",
        0x3C: "create_file",
        0x3D: "open_file",
        0x3E: "close_file",
        0x3F: "read_file",
        0x40: "write_file",
        0x41: "delete_file",
        0x42: "seek_file",
        0x43: "get_set_file_attributes",
        0x44: "ioctl",
        0x47: "get_current_directory",
        0x48: "allocate_memory",
        0x49: "free_memory",
        0x4A: "resize_memory",
        0x4C: "exit_program",
        0x4E: "find_first_file",
        0x4F: "find_next_file",
        0x56: "rename_file",
        0x57: "get_set_file_datetime",
        0x62: "get_psp_address",
    }
    return funcs.get(ah_val, f"unknown_0x{ah_val:02X}")


def identify_int10h_functions(ah_val):
    """Return BIOS INT 10h function name."""
    funcs = {
        0x00: "set_video_mode",
        0x01: "set_cursor_shape",
        0x02: "set_cursor_position",
        0x03: "get_cursor_position",
        0x05: "set_active_display_page",
        0x06: "scroll_up",
        0x07: "scroll_down",
        0x08: "read_char_attr",
        0x09: "write_char_attr",
        0x0A: "write_char",
        0x0E: "write_char_teletype",
        0x0F: "get_video_mode",
        0x10: "set_palette",
        0x11: "char_generator",
        0x12: "alt_select",
        0x1A: "get_display_combination",
    }
    return funcs.get(ah_val, f"unknown_0x{ah_val:02X}")


def disassemble(data, header):
    """Full disassembly with label extraction."""
    code_start = header['header_size']
    code_data = data[code_start:code_start + header['code_size']]
    entry_offset = header['cs'] * 16 + header['ip']

    md = Cs(CS_ARCH_X86, CS_MODE_16)
    md.detail = True
    md.skipdata = True

    # First pass: collect all instructions and targets
    instructions = []
    call_targets = set()
    jump_targets = set()
    call_map = defaultdict(set)  # caller_addr -> set of callee addrs
    int_calls = []  # (addr, int_num, ah_val)

    for insn in md.disasm(code_data, 0):
        instructions.append(insn)

        ops = safe_operands(insn)
        if insn.mnemonic == 'call':
            if ops and ops[0].type == X86_OP_IMM:
                target = ops[0].imm & 0xFFFF
                call_targets.add(target)
                call_map[insn.address].add(target)
        elif insn.mnemonic in ('jmp', 'je', 'jne', 'jz', 'jnz', 'jg', 'jge',
                                'jl', 'jle', 'ja', 'jae', 'jb', 'jbe', 'jo',
                                'jno', 'js', 'jns', 'jp', 'jnp', 'jcxz',
                                'loop', 'loope', 'loopne'):
            if ops and ops[0].type == X86_OP_IMM:
                target = ops[0].imm & 0xFFFF
                jump_targets.add(target)
        elif insn.mnemonic == 'int':
            if ops and ops[0].type == X86_OP_IMM:
                int_calls.append((insn.address, ops[0].imm))

    # Build instruction map for quick lookup
    insn_map = {insn.address: insn for insn in instructions}
    insn_addrs = sorted(insn_map.keys())

    # Find INT calls with preceding MOV AH,xx
    int_details = []
    for addr, int_num in int_calls:
        ah_val = None
        # Look backwards for mov ah, imm
        idx = insn_addrs.index(addr) if addr in insn_map else -1
        if idx > 0:
            for back in range(1, min(8, idx + 1)):
                prev = insn_map[insn_addrs[idx - back]]
                if prev.mnemonic == 'mov' and prev.op_str.startswith('ah,'):
                    try:
                        ah_val = int(prev.op_str.split(',')[1].strip(), 0)
                    except ValueError:
                        pass
                    break
                # Stop if we hit a call/ret/jmp
                if prev.mnemonic in ('call', 'ret', 'retf', 'jmp', 'int'):
                    break
        int_details.append((addr, int_num, ah_val))

    # Identify function boundaries using push bp; mov bp, sp pattern
    functions = {}
    for i, insn in enumerate(instructions):
        if (insn.mnemonic == 'push' and insn.op_str == 'bp' and
                i + 1 < len(instructions)):
            next_insn = instructions[i + 1]
            if next_insn.mnemonic == 'mov' and next_insn.op_str == 'bp, sp':
                functions[insn.address] = True

    # Label generation
    labels = {}
    # Label call targets
    for t in call_targets:
        if t in functions:
            labels[t] = f"sub_{t:04X}"
        else:
            labels[t] = f"sub_{t:04X}"
    # Also label functions not directly called but identified by prologue
    for t in functions:
        if t not in labels:
            labels[t] = f"sub_{t:04X}"
    # Label jump targets (only if not already a function)
    for t in jump_targets:
        if t not in labels:
            labels[t] = f"loc_{t:04X}"

    # Label entry point
    labels[entry_offset] = "__astart"

    # Find strings for data reference annotation
    # Code-offset strings (used for data segment dump)
    strings = find_strings(code_data, min_len=4)

    # DS-relative string map: instructions reference DS:offset values
    # DS base paragraph is in the relocation values
    ds_para = header['relocs'][0]['value'] if header['relocs'] else 0
    ds_base = ds_para * 16  # offset within code_data
    ds_strings = {}
    if ds_base < len(code_data):
        raw_ds_strings = find_strings(code_data[ds_base:], min_len=3)
        for off, s in raw_ds_strings.items():
            ds_strings[off] = s  # keyed by DS:offset

    # Build caller->callee function-level call graph
    # Map each instruction address to its containing function
    func_addrs = sorted(functions.keys())

    def get_containing_func(addr):
        """Find which function contains this address."""
        best = None
        for fa in func_addrs:
            if fa <= addr:
                best = fa
            else:
                break
        return best

    func_call_graph = defaultdict(set)
    for caller_addr, callees in call_map.items():
        caller_func = get_containing_func(caller_addr)
        if caller_func is not None:
            for callee in callees:
                func_call_graph[caller_func].add(callee)

    return {
        'instructions': instructions,
        'labels': labels,
        'call_targets': call_targets,
        'jump_targets': jump_targets,
        'call_map': call_map,
        'func_call_graph': func_call_graph,
        'functions': functions,
        'int_details': int_details,
        'strings': strings,
        'ds_strings': ds_strings,
        'ds_base': ds_base,
        'code_data': code_data,
        'entry_offset': entry_offset,
        'insn_map': insn_map,
    }


def identify_msc_crt(result, header):
    """Identify MSC 5.x CRT startup functions and locate main()."""
    entry = header['cs'] * 16 + header['ip']
    insn_map = result['insn_map']
    labels = result['labels']

    # MSC 5.x __astart typically calls several CRT init functions
    # then calls _main. The call to _main is usually preceded by
    # pushing argc, argv, envp.
    # Look at the entry point code for CALL instructions.
    entry_calls = []
    addr = entry
    insns = result['instructions']
    recording = False
    for insn in insns:
        if insn.address == entry:
            recording = True
        if recording:
            if insn.mnemonic == 'call' and safe_operands(insn) and safe_operands(insn)[0].type == X86_OP_IMM:
                target = safe_operands(insn)[0].imm & 0xFFFF
                entry_calls.append((insn.address, target))
            if insn.mnemonic == 'ret' or insn.mnemonic == 'retf':
                break
            # MSC startup ends with INT 21h/4C or call to _exit
            if insn.address > entry + 0x200:
                break

    # In MSC 5.x small model, __astart calls:
    # 1. __cintDIV (divide error handler setup)
    # 2. __setenvp (set up environment)
    # 3. __setargv (parse command line)
    # 4. _main (the user's main function)
    # 5. _exit (cleanup and terminate)

    # The call to _main is the one preceded by exactly 3 consecutive pushes
    # of word ptr [addr] (envp, argv, argc from CRT globals).
    # In MSC 5.x: push [envp], push [argv], push [argc], call _main
    main_found = False
    for i, (call_addr, target) in enumerate(entry_calls):
        idx = None
        for j, insn in enumerate(insns):
            if insn.address == call_addr:
                idx = j
                break
        if idx is None:
            continue
        # Count consecutive pushes immediately before the call
        push_count = 0
        for back in range(1, min(8, idx + 1)):
            prev = insns[idx - back]
            if prev.mnemonic == 'push':
                push_count += 1
            else:
                break
        # MSC 5.x _main call has exactly 3 pushes (argc, argv, envp)
        if push_count == 3 and not main_found:
            labels[target] = "_main"
            main_found = True
            print(f"  Identified _main at 0x{target:04X} (called from 0x{call_addr:04X} with 3 args pushed)")

    # Label CRT functions based on position relative to _main
    named_main = [t for t, l in labels.items() if l == '_main']
    main_target = named_main[0] if named_main else None
    main_call_addr = None
    if main_target:
        for ca, t in entry_calls:
            if t == main_target:
                main_call_addr = ca
                break

    # CRT init functions are called before _main
    # In MSC 5.x small model: __cintDIV, __setenvp, __setargv
    crt_names = ['__cintDIV', '__setenvp', '__setargv']
    pre_main_calls = [(ca, t) for ca, t in entry_calls
                      if main_call_addr and ca < main_call_addr and t != main_target]
    # Skip early error-path calls (those before the main init block)
    # The init calls are typically the last 3 before _main
    init_calls = pre_main_calls[-3:] if len(pre_main_calls) >= 3 else pre_main_calls
    for i, (ca, t) in enumerate(init_calls):
        if i < len(crt_names):
            labels[t] = crt_names[i]

    # First call after _main is _exit
    if main_call_addr:
        for ca, t in entry_calls:
            if ca > main_call_addr:
                labels[t] = "_exit"
                break

    return entry_calls


def identify_known_functions(result, header):
    """Identify C library and application functions by analysis."""
    labels = result['labels']

    # --- Manual identifications based on deep analysis ---
    # These are determined by examining calling conventions, string refs,
    # INT usage, and position in the CRT startup chain.

    known = {
        # MSC 5.x CRT startup chain
        0x104A: "__cintDIV",       # Divide-by-zero handler setup
        0x11FC: "__setargv",       # Parse command line into argc/argv
        0x11BA: "__NMSG_WRITE",    # CRT error message writer
        0x1125: "__exit",          # Full exit with cleanup (INT 21h/4Ch)
        0x110E: "_exit",           # Exit entry point

        # C string functions
        0x0EDE: "_strnicmp",       # Case-insensitive compare (3 args: s1, s2, n)
        0x0B20: "_strupr",         # Convert string to uppercase
        0x0B04: "_strlen",         # String length
        0x0A92: "_strcat",         # String concatenation (2 args: dst, src)
        0x0AD2: "_strcpy",         # String copy (2 args: dst, src)
        0x0E86: "_strcmp",         # String comparison
        0x0E54: "_strncat",        # Bounded string concatenation

        # C I/O functions (identified by INT 21h usage)
        0x141B: "__write",         # Low-level write (INT 21h AH=40h)
        0x27B2: "_close",          # Close file handle (INT 21h AH=3Eh)
        0x27D2: "_lseek",          # Seek file (INT 21h AH=42h)
        0x284C: "_read",           # Read from file (INT 21h AH=3Fh)
        0x307E: "_open",           # Open/create file (INT 21h AH=3Dh/3Ch)
        0x2DA6: "_unlink",         # Delete file (INT 21h AH=41h)

        # Printf internals
        0x079C: "_printf",         # Standard printf
        0x1F32: "__fmtout",        # Printf internal formatter
        0x232C: "__fassign",       # Printf field assignment helper

        # Memory management
        0x33B2: "_sbrk",           # Extend data segment (INT 21h AH=48h/4Ah)
        0x2E8C: "__brk",           # Set break value

        # Other CRT helpers
        0x1008: "__cintDIV_init",  # CRT init (checks DOS version)
        0x13F0: "__flush",         # Flush output buffer
        0x1444: "__flsbuf",        # Flush single buffer
        0x16A2: "__dosretax",      # DOS return AX wrapper

        # === Application functions ===
        0x0010: "_main",
        0x00CB: "dmvid_buildConfigPath",    # Build full path to DMCSR.CFG
        0x0130: "dmvid_interactiveMenu",    # Display video mode menu, get selection
        0x022A: "dmvid_detectAdapter",      # Detect installed video adapter
        0x0283: "dmvid_selectByChar",       # Select video mode by single char
        0x0299: "dmvid_selectByName",       # Select video mode by name string
        0x02DE: "dmvid_applySelection",     # Apply chosen video configuration
        0x02EC: "dmvid_writeConfig",        # Write video mode to config file
        0x036D: "dmvid_readConfigSection",  # Read [DMRESCFG]/[DMCONFIG] section
        0x03E1: "dmvid_promptForDisk",      # Prompt to insert config disk
        0x04A7: "dmvid_readConfigValue",    # Read config key value
        0x04E8: "dmvid_updateConfigKey",    # Update csr_config key in file
        0x07D8: "dmvid_showCurrentVideo",   # Display current video driver setting
        0x07F6: "dmvid_readCurrentDriver",  # Read current driver name from config
        0x0772: "dmvid_openConfigFile",     # Open DMCSR.CFG for reading
        0x0898: "dmvid_parseDriverName",    # Parse driver name from config data
        0x08FC: "dmvid_searchConfigKey",    # Search for key=value in config section
    }

    for addr, name in known.items():
        labels[addr] = name


def format_disassembly(data, header, result):
    """Format disassembly output."""
    lines = []
    labels = result['labels']
    strings = result['strings']
    instructions = result['instructions']
    code_data = result['code_data']

    # Header
    lines.append("; ============================================================================")
    lines.append("; DMVID.EXE - DeskMate 3.05 Video Configuration Utility")
    lines.append("; Raw disassembly generated by disasm_dmvid.py using Capstone")
    lines.append("; ============================================================================")
    lines.append(";")
    lines.append("; MZ Header:")
    lines.append(f";   File size:       {header['file_size']} bytes ({header['file_size']:#x})")
    lines.append(f";   Header size:     {header['header_size']} bytes ({header['header_size']:#x})")
    lines.append(f";   Code+data size:  {header['code_size']} bytes ({header['code_size']:#x})")
    lines.append(f";   Entry point:     {header['cs']:04X}:{header['ip']:04X} (file offset {header['header_size'] + header['cs']*16 + header['ip']:#06x})")
    lines.append(f";   SS:SP:           {header['ss']:04X}:{header['sp']:04X}")
    lines.append(f";   Min alloc:       {header['min_alloc']:#06x} paragraphs ({header['min_alloc']*16} bytes)")
    lines.append(f";   Relocations:     {header['num_relocs']}")
    lines.append(";")
    lines.append("; Relocations:")
    for r in header['relocs']:
        lines.append(f";   {r['seg']:04X}:{r['off']:04X} -> file {r['file_off']:#06x}, value={r['value']:#06x}")
    lines.append(";")
    lines.append("; Compiler: Microsoft C 5.0, small memory model")
    lines.append("; ============================================================================")
    lines.append("")

    # Segment layout info
    lines.append("; Segment layout (small model):")
    lines.append(";   Code segment: 0x0000 - ~0x{:04X}".format(header['ss'] * 16 - 1 if header['ss'] else header['code_size']))
    lines.append(f";   Data segment: 0x{header['relocs'][0]['value'] * 16:04X}+ (seg {header['relocs'][0]['value']:#06x})")
    lines.append(f";   Stack:        SS={header['ss']:04X} SP={header['sp']:04X}")
    lines.append("")

    # String table (DS-relative offsets, as referenced by instructions)
    ds_strings = result['ds_strings']
    lines.append("; ============================================================================")
    lines.append("; String references in data segment (DS:offset)")
    lines.append("; ============================================================================")
    for off in sorted(ds_strings.keys()):
        s = ds_strings[off]
        if len(s) >= 4:
            lines.append(f";   DS:{off:04X}: \"{s}\"")
    lines.append("")

    # Function index
    lines.append("; ============================================================================")
    lines.append("; Function index")
    lines.append("; ============================================================================")
    func_addrs = sorted(result['functions'].keys())
    for fa in func_addrs:
        label = labels.get(fa, f"sub_{fa:04X}")
        lines.append(f";   {fa:04X}  {label}")
    lines.append("")

    lines.append("; ============================================================================")
    lines.append("; CODE SEGMENT")
    lines.append("; ============================================================================")
    lines.append("")

    # Track which addresses are data vs code for the data segment
    # The data segment likely starts around where the relocation value points
    data_seg_offset = header['relocs'][0]['value'] * 16 if header['relocs'] else header['code_size']

    prev_was_data = False
    i = 0
    while i < len(instructions):
        insn = instructions[i]

        # Add label if present
        if insn.address in labels:
            lines.append("")
            label = labels[insn.address]
            # Add separator for functions
            if insn.address in result['functions'] or label.startswith('_'):
                lines.append("; " + "-" * 70)
                lines.append(f"; Function: {label}")
                lines.append(f"; Address:  {insn.address:04X}")
                # Check if it's a call target
                if insn.address in result['call_targets']:
                    callers = [addr for addr, targets in result['call_map'].items()
                               if insn.address in targets]
                    if callers:
                        lines.append(f"; Called from: {', '.join(f'{c:04X}' for c in sorted(callers))}")
                lines.append("; " + "-" * 70)
            lines.append(f"{label}:")

        # Format the instruction line
        addr_str = f"{insn.address:04X}"
        hex_bytes = insn.bytes.hex().upper()
        # Pad hex to 12 chars for alignment
        hex_str = f"{hex_bytes:<16s}"
        mnemonic = insn.mnemonic
        op_str = insn.op_str

        # Add target label as comment for calls and jumps
        comment = ""
        if insn.mnemonic == 'call' and safe_operands(insn) and safe_operands(insn)[0].type == X86_OP_IMM:
            target = safe_operands(insn)[0].imm & 0xFFFF
            if target in labels:
                comment = f"  ; -> {labels[target]}"
        elif insn.mnemonic in ('jmp', 'je', 'jne', 'jz', 'jnz', 'jg', 'jge',
                                'jl', 'jle', 'ja', 'jae', 'jb', 'jbe', 'jo',
                                'jno', 'js', 'jns', 'jp', 'jnp', 'jcxz',
                                'loop', 'loope', 'loopne'):
            if safe_operands(insn) and safe_operands(insn)[0].type == X86_OP_IMM:
                target = safe_operands(insn)[0].imm & 0xFFFF
                if target in labels:
                    comment = f"  ; -> {labels[target]}"

        # Annotate INT calls
        if insn.mnemonic == 'int' and safe_operands(insn) and safe_operands(insn)[0].type == X86_OP_IMM:
            intnum = safe_operands(insn)[0].imm
            if intnum == 0x21:
                comment = "  ; DOS"
            elif intnum == 0x10:
                comment = "  ; BIOS Video"
            elif intnum == 0x16:
                comment = "  ; BIOS Keyboard"
            elif intnum == 0x11:
                comment = "  ; BIOS Equipment List"
            elif intnum == 0x13:
                comment = "  ; BIOS Disk"

        # Annotate string references in MOV/PUSH instructions (DS:offset)
        if insn.mnemonic in ('mov', 'push'):
            for op in safe_operands(insn):
                if op.type == X86_OP_IMM:
                    val = op.imm & 0xFFFF
                    if val in ds_strings and len(ds_strings[val]) >= 3:
                        s = ds_strings[val]
                        if len(s) > 50:
                            s = s[:50] + "..."
                        comment = f'  ; DS:{val:04X} = "{s}"'

        line = f"    {addr_str}: {hex_str} {mnemonic:<8s} {op_str}{comment}"
        lines.append(line)
        i += 1

    # Data segment dump (after last instruction)
    last_insn_end = instructions[-1].address + instructions[-1].size if instructions else 0
    if last_insn_end < len(code_data):
        lines.append("")
        lines.append("; ============================================================================")
        lines.append("; DATA SEGMENT (remaining bytes after code)")
        lines.append("; ============================================================================")

        offset = last_insn_end
        while offset < len(code_data):
            # Check if there's a string here
            if offset in strings:
                s = strings[offset]
                hex_rep = code_data[offset:offset + len(s) + 1].hex().upper()
                lines.append(f"    {offset:04X}: db \"{s}\", 0")
                offset += len(s) + 1  # +1 for NUL
                continue

            # Print as hex bytes, 16 per line
            chunk = code_data[offset:offset + 16]
            hex_str = ' '.join(f'{b:02X}' for b in chunk)
            ascii_str = ''.join(chr(b) if 0x20 <= b <= 0x7e else '.' for b in chunk)
            lines.append(f"    {offset:04X}: db {hex_str:<48s} ; {ascii_str}")
            offset += len(chunk)

    return '\n'.join(lines) + '\n'


def generate_callgraph(data, header, result, entry_calls):
    """Generate the call graph document."""
    lines = []
    labels = result['labels']
    functions = result['functions']
    func_call_graph = result['func_call_graph']
    int_details = result['int_details']
    strings = result['strings']
    ds_strings = result['ds_strings']
    instructions = result['instructions']

    lines.append("=" * 78)
    lines.append("DMVID.EXE - DeskMate 3.05 Video Configuration Utility")
    lines.append("Call Graph and Function Analysis")
    lines.append("=" * 78)
    lines.append("")

    # Summary of identified functions
    lines.append("-" * 78)
    lines.append("IDENTIFIED FUNCTIONS SUMMARY")
    lines.append("-" * 78)
    lines.append("")

    # Categorize functions
    crt_funcs = []
    app_funcs = []
    lib_funcs = []
    unknown_funcs = []

    func_addrs = sorted(functions.keys())
    for fa in func_addrs:
        label = labels.get(fa, f"sub_{fa:04X}")
        if label.startswith('__') or label in ('_exit',):
            crt_funcs.append((fa, label))
        elif label.startswith('_main') or label.startswith('_'):
            app_funcs.append((fa, label))
        else:
            unknown_funcs.append((fa, label))

    # Analyze each function's behavior
    func_behaviors = {}
    for fi, fa in enumerate(func_addrs):
        end_addr = func_addrs[fi + 1] if fi + 1 < len(func_addrs) else len(result['code_data'])
        behavior = {
            'int21_funcs': set(),
            'int10_funcs': set(),
            'has_int16': False,
            'has_int11': False,
            'str_refs': [],
            'calls': set(),
            'size': 0,
        }

        insn_count = 0
        for insn in instructions:
            if insn.address < fa:
                continue
            if insn.address >= end_addr:
                break
            insn_count += 1

            if insn.mnemonic == 'int' and safe_operands(insn):
                intnum = safe_operands(insn)[0].imm if safe_operands(insn)[0].type == X86_OP_IMM else 0
                if intnum == 0x16:
                    behavior['has_int16'] = True
                if intnum == 0x11:
                    behavior['has_int11'] = True

            if insn.mnemonic == 'call' and safe_operands(insn) and safe_operands(insn)[0].type == X86_OP_IMM:
                behavior['calls'].add(safe_operands(insn)[0].imm & 0xFFFF)

            # String references via immediate values (DS:offset)
            if insn.mnemonic in ('mov', 'push'):
                for op in safe_operands(insn):
                    if op.type == X86_OP_IMM:
                        val = op.imm & 0xFFFF
                        if val in ds_strings and len(ds_strings[val]) >= 4:
                            behavior['str_refs'].append(ds_strings[val])

        behavior['size'] = insn_count

        # Check INT details for this function's range
        for addr, intnum, ah_val in int_details:
            if fa <= addr < end_addr:
                if intnum == 0x21 and ah_val is not None:
                    behavior['int21_funcs'].add(ah_val)
                elif intnum == 0x10 and ah_val is not None:
                    behavior['int10_funcs'].add(ah_val)

        func_behaviors[fa] = behavior

    # Now try to give meaningful names based on behavior
    for fa in func_addrs:
        label = labels.get(fa, f"sub_{fa:04X}")
        if not label.startswith('sub_'):
            continue  # Already named

        beh = func_behaviors.get(fa, {})
        strs = beh.get('str_refs', [])
        int21 = beh.get('int21_funcs', set())
        int10 = beh.get('int10_funcs', set())

        # Video mode detection
        if 0x1A in int10 or 0x12 in int10:
            labels[fa] = f"dmvid_detectVideoAdapter"
            continue
        if 0x0F in int10 and beh.get('has_int11'):
            labels[fa] = f"dmvid_getVideoInfo"
            continue

        # String output functions
        for s in strs:
            if "AUTO" in s and "detection" in s.lower():
                labels[fa] = "dmvid_showAutoDetect"
                break
            if "Select one" in s:
                labels[fa] = "dmvid_showMenu"
                break
            if "Video configuration has" in s and "updated" in s:
                labels[fa] = "dmvid_showResult"
                break
            if "Video is currently" in s:
                labels[fa] = "dmvid_showCurrentSetting"
                break
            if "Insert the disk" in s:
                labels[fa] = "dmvid_promptForDisk"
                break
            if "DMCSR.CFG" in s and len(strs) <= 3:
                labels[fa] = "dmvid_findConfigFile"
                break

        if labels.get(fa, '').startswith('sub_'):
            # File I/O
            if 0x3D in int21 or 0x3C in int21:
                labels[fa] = f"dmvid_fileOpen_{fa:04X}"
            elif 0x3F in int21 and 0x40 in int21:
                labels[fa] = f"dmvid_fileReadWrite_{fa:04X}"
            elif 0x3F in int21:
                labels[fa] = f"dmvid_fileRead_{fa:04X}"
            elif 0x40 in int21:
                labels[fa] = f"dmvid_fileWrite_{fa:04X}"
            elif 0x4C in int21:
                labels[fa] = f"dmvid_dosExit_{fa:04X}"

        # Keyboard input
        if labels.get(fa, '').startswith('sub_') and beh.get('has_int16'):
            labels[fa] = f"dmvid_getKeyInput_{fa:04X}"

    # Print function summary
    lines.append("CRT Runtime Functions:")
    for fa, label in sorted([(fa, labels.get(fa, f"sub_{fa:04X}")) for fa in func_addrs
                              if labels.get(fa, '').startswith('__') or labels.get(fa, '') == '_exit']):
        lines.append(f"  {fa:04X}  {label}")

    lines.append("")
    lines.append("Application Functions (named):")
    for fa in func_addrs:
        label = labels.get(fa, f"sub_{fa:04X}")
        if label.startswith('_main') or (label.startswith('dmvid_') and not label.startswith('sub_')):
            desc = ""
            beh = func_behaviors.get(fa, {})
            if beh.get('str_refs'):
                first_str = beh['str_refs'][0]
                if len(first_str) > 60:
                    first_str = first_str[:60] + "..."
                desc = f'  refs: "{first_str}"'
            lines.append(f"  {fa:04X}  {label}{desc}")

    lines.append("")
    lines.append("Unidentified Functions:")
    for fa in func_addrs:
        label = labels.get(fa, f"sub_{fa:04X}")
        if label.startswith('sub_'):
            beh = func_behaviors.get(fa, {})
            desc_parts = []
            if beh.get('int21_funcs'):
                funcs_str = ', '.join(f"AH={v:02X}h ({identify_int21h_functions(v)})"
                                      for v in sorted(beh['int21_funcs']))
                desc_parts.append(f"INT 21h: {funcs_str}")
            if beh.get('int10_funcs'):
                funcs_str = ', '.join(f"AH={v:02X}h ({identify_int10h_functions(v)})"
                                      for v in sorted(beh['int10_funcs']))
                desc_parts.append(f"INT 10h: {funcs_str}")
            if beh.get('has_int16'):
                desc_parts.append("INT 16h (keyboard)")
            if beh.get('str_refs'):
                s = beh['str_refs'][0]
                if len(s) > 50:
                    s = s[:50] + "..."
                desc_parts.append(f'str: "{s}"')
            desc = "; ".join(desc_parts) if desc_parts else f"({beh.get('size', '?')} insns)"
            lines.append(f"  {fa:04X}  {label}  -- {desc}")

    # CRT startup chain
    lines.append("")
    lines.append("-" * 78)
    lines.append("CRT STARTUP CHAIN")
    lines.append("-" * 78)
    lines.append("")
    lines.append(f"Entry point: {header['cs']:04X}:{header['ip']:04X} -> __astart")
    lines.append("")
    lines.append("__astart call sequence:")
    for call_addr, target in entry_calls:
        label = labels.get(target, f"sub_{target:04X}")
        lines.append(f"  {call_addr:04X}: call {target:04X}  ; {label}")
    lines.append("")

    # DOS INT 21h usage
    lines.append("-" * 78)
    lines.append("DOS API USAGE (INT 21h)")
    lines.append("-" * 78)
    lines.append("")
    for addr, intnum, ah_val in sorted(int_details):
        if intnum == 0x21:
            func_name = identify_int21h_functions(ah_val) if ah_val is not None else "unknown"
            containing = None
            for fi, fa in enumerate(func_addrs):
                end = func_addrs[fi + 1] if fi + 1 < len(func_addrs) else 0xFFFF
                if fa <= addr < end:
                    containing = labels.get(fa, f"sub_{fa:04X}")
                    break
            ah_str = f"AH={ah_val:02X}h" if ah_val is not None else "AH=??"
            lines.append(f"  {addr:04X}: INT 21h, {ah_str}  {func_name:<30s}  in {containing or '?'}")
    lines.append("")

    # BIOS INT 10h usage
    lines.append("-" * 78)
    lines.append("BIOS VIDEO API USAGE (INT 10h)")
    lines.append("-" * 78)
    lines.append("")
    for addr, intnum, ah_val in sorted(int_details):
        if intnum == 0x10:
            func_name = identify_int10h_functions(ah_val) if ah_val is not None else "unknown"
            containing = None
            for fi, fa in enumerate(func_addrs):
                end = func_addrs[fi + 1] if fi + 1 < len(func_addrs) else 0xFFFF
                if fa <= addr < end:
                    containing = labels.get(fa, f"sub_{fa:04X}")
                    break
            ah_str = f"AH={ah_val:02X}h" if ah_val is not None else "AH=??"
            lines.append(f"  {addr:04X}: INT 10h, {ah_str}  {func_name:<30s}  in {containing or '?'}")
    lines.append("")

    # Other interrupts
    other_ints = [(a, n, v) for a, n, v in int_details if n not in (0x21, 0x10)]
    if other_ints:
        lines.append("-" * 78)
        lines.append("OTHER INTERRUPT USAGE")
        lines.append("-" * 78)
        lines.append("")
        for addr, intnum, ah_val in sorted(other_ints):
            containing = None
            for fi, fa in enumerate(func_addrs):
                end = func_addrs[fi + 1] if fi + 1 < len(func_addrs) else 0xFFFF
                if fa <= addr < end:
                    containing = labels.get(fa, f"sub_{fa:04X}")
                    break
            lines.append(f"  {addr:04X}: INT {intnum:02X}h  in {containing or '?'}")
        lines.append("")

    # Full call graph
    lines.append("-" * 78)
    lines.append("FULL CALL GRAPH (function level)")
    lines.append("-" * 78)
    lines.append("")

    for fa in func_addrs:
        label = labels.get(fa, f"sub_{fa:04X}")
        callees = func_call_graph.get(fa, set())
        if callees:
            callee_strs = []
            for c in sorted(callees):
                cl = labels.get(c, f"sub_{c:04X}")
                callee_strs.append(f"{cl} ({c:04X})")
            lines.append(f"{label} ({fa:04X}):")
            for cs in callee_strs:
                lines.append(f"    -> {cs}")
            lines.append("")

    # Reverse call graph (who calls whom)
    lines.append("-" * 78)
    lines.append("REVERSE CALL GRAPH (callee <- callers)")
    lines.append("-" * 78)
    lines.append("")

    reverse_map = defaultdict(set)
    for caller, callees in func_call_graph.items():
        for callee in callees:
            reverse_map[callee].add(caller)

    for fa in sorted(reverse_map.keys()):
        label = labels.get(fa, f"sub_{fa:04X}")
        callers = reverse_map[fa]
        caller_strs = [f"{labels.get(c, f'sub_{c:04X}')} ({c:04X})" for c in sorted(callers)]
        lines.append(f"{label} ({fa:04X}):")
        for cs in caller_strs:
            lines.append(f"    <- {cs}")
        lines.append("")

    # Video mode strings table
    lines.append("-" * 78)
    lines.append("VIDEO MODE TABLE (from string analysis)")
    lines.append("-" * 78)
    lines.append("")
    mode_strings = [
        ("AUTO", "Automatic detection"),
        ("VGA", "Video Graphics Array, 640x480 16 colors"),
        ("EGA", "Enhanced Graphics Adapter, 640x350 16 colors"),
        ("MCGA", "Multi Color Graphics Array, 640x480 2 colors"),
        ("CGA", "Color Graphics Adapter, 640x200 2 colors"),
        ("HERC", "Hercules, 720x348 monochrome"),
        ("1000", "Tandy 1000, 640x200 4 colors"),
        ("TC16", "Tandy Color, 640x200 16 colors"),
    ]
    for mode, desc in mode_strings:
        lines.append(f"  {mode:<6s} - {desc}")
    lines.append("")

    # Program flow summary
    lines.append("-" * 78)
    lines.append("PROGRAM FLOW SUMMARY")
    lines.append("-" * 78)
    lines.append("")
    lines.append("DMVID.EXE is the DeskMate video driver configuration utility.")
    lines.append("It performs the following operations:")
    lines.append("")
    lines.append("1. CRT startup (__astart -> __setenvp -> __setargv -> _main)")
    lines.append("2. Parse command line for /AUTO switch")
    lines.append("3. Locate DMCSR.CFG configuration file")
    lines.append("4. Read current video driver setting from DMCSR.CFG")
    lines.append("5. If /AUTO: auto-detect video adapter and update config")
    lines.append("6. If interactive: display menu of video options (1-9)")
    lines.append("7. Get user selection via keyboard input")
    lines.append("8. Update DMCSR.CFG with selected video driver name")
    lines.append("9. Display result message and exit")
    lines.append("")
    lines.append("Configuration file: DMCSR.CFG")
    lines.append("Config sections searched: [DMRESCFG], [DMCONFIG]")
    lines.append("Config key: csr_config")
    lines.append("Driver name format: DMVS<mode>.RES (e.g., DMVSVGA.RES)")
    lines.append("")

    return '\n'.join(lines) + '\n'


def main():
    print("DMVID.EXE Disassembler")
    print("=" * 40)

    with open(INPUT, "rb") as f:
        data = f.read()

    print(f"File size: {len(data)} bytes")

    # Parse header
    header = parse_mz_header(data)
    print(f"Header size: {header['header_size']}")
    print(f"Entry point: {header['cs']:04X}:{header['ip']:04X}")
    print(f"Relocations: {header['num_relocs']}")

    # Disassemble
    print("\nDisassembling...")
    result = disassemble(data, header)
    print(f"  {len(result['instructions'])} instructions")
    print(f"  {len(result['functions'])} functions (by prologue)")
    print(f"  {len(result['call_targets'])} call targets")
    print(f"  {len(result['int_details'])} interrupt calls")

    # Identify CRT and main
    print("\nIdentifying CRT startup and _main...")
    entry_calls = identify_msc_crt(result, header)

    # Try to identify known functions
    print("Identifying known functions...")
    identify_known_functions(result, header)

    # Generate assembly output
    print(f"\nWriting disassembly to {OUTPUT_ASM}...")
    asm_text = format_disassembly(data, header, result)
    with open(OUTPUT_ASM, 'w') as f:
        f.write(asm_text)
    print(f"  {len(asm_text)} bytes written")

    # Generate call graph
    print(f"Writing call graph to {OUTPUT_CALLGRAPH}...")
    cg_text = generate_callgraph(data, header, result, entry_calls)
    with open(OUTPUT_CALLGRAPH, 'w') as f:
        f.write(cg_text)
    print(f"  {len(cg_text)} bytes written")

    print("\nDone!")


if __name__ == '__main__':
    main()
