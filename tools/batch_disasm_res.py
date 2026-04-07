#!/usr/bin/env python3
"""
Batch disassembler for DeskMate 3.05 .RES files.
Uses disasm_mz.py's MZDisassembler for each file, generates .asm and
-callgraph.txt outputs, then writes a summary table.

Usage:
    python3 batch_disasm_res.py
"""

import os
import sys
import struct
import time

# Add tools directory to path so we can import disasm_mz
TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS_DIR)

from disasm_mz import MZDisassembler, MZHeader, INT_ANNOTATIONS

ARCHIVE_DIR = "/Users/joe/Documents/GitHub/bayside/archive/deskmate-3.05/extracted"
OUTPUT_DIR = "/Users/joe/Documents/GitHub/bayside/disassembly/raw/res"

# Skip list: non-executable files
SKIP_FILES = {"TUTKBD.RES"}

# Category assignments for the summary
CATEGORIES = {
    "Video Drivers (DMVE)": [
        "DMVECGA.RES", "DMVEEGA.RES", "DMVEVGA.RES", "DMVEMCGA.RES",
        "DMVEHERC.RES", "DMVE1000.RES", "DMVET.RES", "DMVETC16.RES",
    ],
    "Video Support (DMVS)": [
        "DMVSCGA.RES", "DMVSEGA.RES", "DMVSVGA.RES", "DMVSMCGA.RES",
        "DMVSHERC.RES", "DMVS1000.RES", "DMVST.RES", "DMVSTC16.RES",
    ],
    "Font": ["DMFONT.RES"],
    "Printer Drivers": [
        "DMPD1.RES", "DMPD2.RES", "DMPDASCI.RES", "DMPDIBMM.RES",
        "DMPDLASR.RES", "DMPDS.RES",
    ],
    "Printer Extensions": [
        "DMPE1.RES", "DMPE2.RES", "DMPEIBMM.RES", "DMPELASR.RES",
        "DMPES.RES",
    ],
    "Sound/Music": [
        "DMSSM.RES", "DMPLAY.RES", "DMMDJ.RES", "DMMDP.RES", "DMMDS.RES",
    ],
    "Database Engine": ["DMDBBLD.RES", "DMDBRD.RES", "DMDBUPD.RES"],
    "Form Manager": ["DMFORM.RES", "DMEFORM.RES"],
    "Spelling/Language": [
        "SPELL.RES", "SPL.RES", "DICTARY.RES", "DMTHES.RES", "TRANSLAT.RES",
    ],
    "Utilities": [
        "DMEMM.RES", "DMUNPACK.RES", "PRGUF.RES", "AUTOLOAD.RES",
    ],
    "Alarm/Init": ["ALARM.RES", "ALRMINIT.RES"],
    "Other": ["D87.RES", "PROTOCOL.RES"],
}

# Reverse lookup: filename -> category
FILE_TO_CATEGORY = {}
for cat, files in CATEGORIES.items():
    for f in files:
        FILE_TO_CATEGORY[f] = cat


def detect_format(filepath):
    """Return 'DM89', 'MZ', or 'DATA' based on file header."""
    with open(filepath, "rb") as f:
        header = f.read(0x24)
    if len(header) < 2:
        return "DATA"
    if header[0:2] not in (b'MZ', b'ZM'):
        return "DATA"
    if len(header) >= 0x20 and header[0x1C:0x20] == b'DM89':
        return "DM89"
    return "MZ"


def process_file(filepath, basename):
    """Disassemble one RES file. Returns info dict or None on error."""
    filename = os.path.basename(filepath)
    fmt = detect_format(filepath)
    file_size = os.path.getsize(filepath)

    if fmt == "DATA":
        print(f"  SKIP {filename}: not an executable (data file)")
        return {
            "name": filename,
            "size": file_size,
            "format": "DATA",
            "segments": 0,
            "relocs": 0,
            "functions": 0,
            "instructions": 0,
            "strings": 0,
            "int_calls": {},
            "entry": "N/A",
            "error": None,
            "category": FILE_TO_CATEGORY.get(filename, "Unknown"),
        }

    print(f"\n{'='*60}")
    print(f"Processing: {filename} ({fmt}, {file_size} bytes)")
    print(f"{'='*60}")

    try:
        disasm = MZDisassembler(filepath)
        mz = disasm.mz

        print(f"  Header: {mz.header_size} bytes, "
              f"Entry {mz.init_cs:04X}:{mz.init_ip:04X}, "
              f"{mz.num_relocs} relocs")
        if mz.dm89:
            print(f"  DM89 present")
        print(f"  Segments: {', '.join(f'{s:04X}' for s in disasm.segmap.segments)}")

        disasm.analyze()

        n_funcs = len(disasm.call_targets)
        n_insns = len(disasm.instructions)
        n_strings = len(disasm.strings)

        print(f"  {n_insns} instructions, {n_funcs} functions, "
              f"{len(disasm.jump_targets)} jump targets, {n_strings} strings")

        # Write .asm file
        asm_path = os.path.join(OUTPUT_DIR, f"{basename}.asm")
        with open(asm_path, 'w') as f:
            f.write(disasm.format_output())
        print(f"  Wrote: {asm_path}")

        # Write callgraph file
        cg_path = os.path.join(OUTPUT_DIR, f"{basename}-callgraph.txt")
        with open(cg_path, 'w') as f:
            f.write(disasm.format_callgraph())
        print(f"  Wrote: {cg_path}")

        # Collect INT call summary
        int_summary = {}
        for (int_num, ah_val), locs in disasm.int_calls.items():
            key_str = f"INT {int_num:02X}h"
            if ah_val is not None:
                key_str += f"/AH={ah_val:02X}h"
            desc = INT_ANNOTATIONS.get((int_num, ah_val), "")
            int_summary[key_str] = {
                "count": len(locs),
                "desc": desc,
            }

        return {
            "name": filename,
            "size": file_size,
            "format": fmt,
            "segments": len(disasm.segmap.segments),
            "relocs": mz.num_relocs,
            "functions": n_funcs,
            "instructions": n_insns,
            "strings": n_strings,
            "int_calls": int_summary,
            "entry": f"{mz.init_cs:04X}:{mz.init_ip:04X}",
            "error": None,
            "category": FILE_TO_CATEGORY.get(filename, "Unknown"),
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        return {
            "name": filename,
            "size": file_size,
            "format": fmt,
            "segments": 0,
            "relocs": 0,
            "functions": 0,
            "instructions": 0,
            "strings": 0,
            "int_calls": {},
            "entry": "N/A",
            "error": str(e),
            "category": FILE_TO_CATEGORY.get(filename, "Unknown"),
        }


def write_summary(results):
    """Write the res-summary.txt file."""
    summary_path = os.path.join(OUTPUT_DIR, "res-summary.txt")

    lines = []
    lines.append("=" * 80)
    lines.append("DeskMate 3.05 -- .RES File Disassembly Summary")
    lines.append(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"Total files processed: {len(results)}")
    lines.append("=" * 80)
    lines.append("")

    # Overall statistics
    total_size = sum(r["size"] for r in results)
    total_funcs = sum(r["functions"] for r in results)
    total_insns = sum(r["instructions"] for r in results)
    dm89_count = sum(1 for r in results if r["format"] == "DM89")
    mz_count = sum(1 for r in results if r["format"] == "MZ")
    data_count = sum(1 for r in results if r["format"] == "DATA")
    error_count = sum(1 for r in results if r["error"])

    lines.append("OVERALL STATISTICS")
    lines.append("-" * 40)
    lines.append(f"  Total .RES files:    {len(results)}")
    lines.append(f"  MZ+DM89 executables: {dm89_count}")
    lines.append(f"  Plain MZ executables:{mz_count}")
    lines.append(f"  Data files (skipped):{data_count}")
    lines.append(f"  Errors:              {error_count}")
    lines.append(f"  Total size:          {total_size:,} bytes")
    lines.append(f"  Total functions:     {total_funcs}")
    lines.append(f"  Total instructions:  {total_insns}")
    lines.append("")

    # Master table
    lines.append("MASTER TABLE")
    lines.append("-" * 120)
    hdr_fmt = "{:<16s} {:>8s} {:>6s} {:>5s} {:>6s} {:>6s} {:>6s} {:>6s} {:>12s}  {}"
    row_fmt = "{:<16s} {:>8,d} {:>6s} {:>5d} {:>6d} {:>6d} {:>6d} {:>6d} {:>12s}  {}"
    lines.append(hdr_fmt.format(
        "File", "Size", "Format", "Segs", "Relocs", "Funcs", "Insns", "Strs",
        "Entry", "Key INTs"))
    lines.append("-" * 120)

    for r in sorted(results, key=lambda x: x["name"]):
        # Summarize key INT calls
        key_ints = []
        for k, v in sorted(r["int_calls"].items()):
            key_ints.append(f"{k}x{v['count']}")
        int_str = ", ".join(key_ints[:6])
        if len(key_ints) > 6:
            int_str += f" (+{len(key_ints)-6})"

        if r["error"]:
            int_str = f"ERROR: {r['error'][:40]}"

        lines.append(row_fmt.format(
            r["name"], r["size"], r["format"], r["segments"],
            r["relocs"], r["functions"], r["instructions"],
            r["strings"], r["entry"], int_str))
    lines.append("")

    # Group by category
    lines.append("=" * 80)
    lines.append("BREAKDOWN BY CATEGORY")
    lines.append("=" * 80)

    for cat_name, cat_files in CATEGORIES.items():
        cat_results = [r for r in results if r["name"] in cat_files]
        if not cat_results:
            continue

        cat_size = sum(r["size"] for r in cat_results)
        cat_funcs = sum(r["functions"] for r in cat_results)
        cat_insns = sum(r["instructions"] for r in cat_results)

        lines.append("")
        lines.append(f"--- {cat_name} ---")
        lines.append(f"    Files: {len(cat_results)}, "
                     f"Total size: {cat_size:,} bytes, "
                     f"Functions: {cat_funcs}, "
                     f"Instructions: {cat_insns}")

        for r in sorted(cat_results, key=lambda x: x["name"]):
            status = "OK" if not r["error"] else f"ERROR: {r['error'][:30]}"
            if r["format"] == "DATA":
                status = "SKIPPED (data)"
            lines.append(f"    {r['name']:<18s} {r['size']:>8,d} bytes  "
                        f"{r['format']:>4s}  {r['functions']:>3d} funcs  "
                        f"{r['instructions']:>5d} insns  [{status}]")

        # Aggregate INT usage for this category
        cat_ints = {}
        for r in cat_results:
            for k, v in r["int_calls"].items():
                if k not in cat_ints:
                    cat_ints[k] = {"count": 0, "desc": v["desc"]}
                cat_ints[k]["count"] += v["count"]

        if cat_ints:
            lines.append(f"    INT usage:")
            for k in sorted(cat_ints.keys()):
                v = cat_ints[k]
                desc = f"  {v['desc']}" if v['desc'] else ""
                lines.append(f"      {k}: {v['count']}x{desc}")

    # Priority analysis
    lines.append("")
    lines.append("=" * 80)
    lines.append("REVERSE ENGINEERING PRIORITY ANALYSIS")
    lines.append("=" * 80)
    lines.append("")
    lines.append("CRITICAL (needed for DESK.EXE shell to function):")
    lines.append("  - DMVE*.RES / DMVS*.RES: Video drivers are essential for any display output.")
    lines.append("    The DMVE files are small entry-point stubs (~5KB); the DMVS files contain")
    lines.append("    the bulk of the video rendering code (22-26KB each).")
    lines.append("  - DMFONT.RES: Font data and rendering, required for all text display.")
    lines.append("")
    lines.append("HIGH (needed for core application functionality):")
    lines.append("  - DMPLAY.RES: Sound playback engine (42KB, largest .RES). Needed for")
    lines.append("    MUSIC.PDM and SOUND.PDM.")
    lines.append("  - DMSSM.RES: Sound system manager. Companion to DMPLAY.")
    lines.append("  - DMDBBLD.RES/DMDBRD.RES/DMDBUPD.RES: Database engine used by FILER.PDM.")
    lines.append("  - DMFORM.RES/DMEFORM.RES: Form display engine, used by multiple apps.")
    lines.append("  - DMPD*.RES/DMPE*.RES: Printer drivers, needed for TEXT.PDM print function.")
    lines.append("")
    lines.append("MEDIUM:")
    lines.append("  - SPELL.RES/SPL.RES: Spell checker for TEXT.PDM.")
    lines.append("  - PROTOCOL.RES: Communication protocols for TELECOM.PDM.")
    lines.append("  - ALARM.RES/ALRMINIT.RES: Alarm/scheduler support for CALENDAR.PDM.")
    lines.append("  - DMEMM.RES: Extended memory manager (EMS/XMS).")
    lines.append("  - PRGUF.RES: Program user functions framework.")
    lines.append("")
    lines.append("LOW:")
    lines.append("  - DMUNPACK.RES: Data decompression utility.")
    lines.append("  - D87.RES: 8087 FPU emulation stub (818 bytes).")
    lines.append("  - DICTARY.RES/DMTHES.RES/TRANSLAT.RES: Dictionary/thesaurus lookup stubs.")
    lines.append("  - DMMD*.RES: MIDI driver variants (joystick port, parallel, serial).")
    lines.append("  - AUTOLOAD.RES: Auto-load configuration helper.")
    lines.append("")

    with open(summary_path, 'w') as f:
        f.write("\n".join(lines))
        f.write("\n")
    print(f"\nWrote summary: {summary_path}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Discover all .RES files
    res_files = sorted([
        f for f in os.listdir(ARCHIVE_DIR)
        if f.upper().endswith(".RES") and f.upper() not in SKIP_FILES
    ])

    print(f"Found {len(res_files)} .RES files to process (skipping {SKIP_FILES})")

    results = []
    for filename in res_files:
        filepath = os.path.join(ARCHIVE_DIR, filename)
        basename = os.path.splitext(filename)[0].lower()
        info = process_file(filepath, basename)
        if info:
            results.append(info)

    write_summary(results)

    # Final stats
    ok_count = sum(1 for r in results if not r["error"] and r["format"] != "DATA")
    err_count = sum(1 for r in results if r["error"])
    print(f"\n{'='*60}")
    print(f"BATCH COMPLETE: {ok_count} disassembled, {err_count} errors, "
          f"{len(results)} total")
    print(f"Output: {OUTPUT_DIR}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
