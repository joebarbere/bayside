# bayside

**Reverse engineering Tandy DeskMate 3.05 into clean, compilable C source code.**

bayside is a preservation and reconstruction project targeting DeskMate 3.05 (1990), the integrated desktop environment that shipped with Tandy 1000-series PCs. The goal is to produce fully annotated disassembly of every DeskMate binary and transpile it into readable C89 that compiles with OpenWatcom and runs identically in DOSBox.

## Status

| Stage | Status | Details |
|-------|--------|---------|
| 1. Research & Acquisition | **Complete** | 148 files extracted from 3 disk image sources; 20 file formats documented; full hardware register maps; desk accessory documentation |
| 2. Binary Analysis | **Complete** | 87 binaries disassembled (565K+ lines of assembly); 8,500+ functions identified; compiler confirmed as Microsoft C 5.x |
| 3. Annotation | **Complete** | All 87 binaries fully annotated — 17 EXE/PDM + 52 RES + 18 ACC; every function named; data structures mapped; INT E0h API reference with 8 service classes |
| 4. C Transpilation | **In Progress** | HANGMAN.PDM rebuilt from source byte-identically; being translated to C function by function (binary splicing) |
| 5. Verification | **In Progress** | Automated: Unicorn boundary/call-trace diff vs. the original (`make trace-check`) + headless DOSBox-X runs in real DeskMate |

See [STATUS.md](STATUS.md) for detailed per-module progress.

## Key Discoveries

- **All DeskMate modules use a custom "DM89" header extension** embedded in the reserved area of the standard DOS MZ executable header. This includes a module type flag, an authoritative CS:IP entry point (overriding the MZ fields), and an import name table for runtime dependency resolution.
- **DESK.EXE implements a dynamic linking system for DOS** via INT E0h, predating Windows DLLs. Seven service classes were identified: core/system, module lifecycle, UI/forms, graphics, window management, event loop, and shell services.
- **DESK.EXE itself is hand-written assembly**, while all other modules (PDMs, ACCs, RES drivers) were compiled with **Microsoft C 5.x (1987)**.
- **The DeskMate Development System 3.03** SDK existed ($299 retail) and required MSC 4.0+. It documented the INT E0h API, Form Manager, and hardware drivers.
- **Five file formats share a common database engine** (DMDB): .FIL, .CLN, .ADR, .HLP, and .CLP all use 2048-byte page sectors with allocation bitmaps.
- **PLAY.PDM is actually "Teach Me!"**, a tutorial player (not a music player) that loads .TUT lesson files through the DMPLAY resource.

## DeskMate 3.05 Components

| Module | Binary | Size | Functions | Description |
|--------|--------|------|-----------|-------------|
| Shell | DESK.EXE | 19 KB | 118 | Main host environment (assembly) |
| Desktop | DESKTOP.PDM | 72 KB | 521 | Desktop UI, icon launcher, file manager |
| Text | TEXT.PDM | 75 KB | 408 | Word processor |
| Worksheet | WRKSHEET.PDM | 60 KB | 416 | Spreadsheet |
| Draw | DRAW.PDM | 78 KB | 554 | Vector graphics editor |
| Calendar | CALENDAR.PDM | 73 KB | 486 | Scheduler with alarms |
| Address Book | ADDRESS.PDM | 61 KB | 316 | Contact manager |
| Filer | FILER.PDM | 40 KB | 318 | Flat-file database |
| Form Set | FORMSET.PDM | 60 KB | 419 | Form designer |
| Telecom | TELECOM.PDM | 36 KB | 269 | Terminal emulator |
| PC-Link | PC_LINK.PDM | 72 KB | 538 | Online service client |
| Hangman | HANGMAN.PDM | 27 KB | 200 | Word game |
| Teach Me! | PLAY.PDM | 12 KB | 114 | Tutorial player |
| Mail Merge | MAILMRGE.PDM | 21 KB | 168 | Mail merge utility |
| Video Config | DMVID.EXE | 16 KB | 74 | Video adapter selection |
| Resources | 51 .RES files | 619 KB | 1,056 | Video, font, sound, database, and printer drivers |
| Accessories | 18 .ACC files | 229 KB | 2,141 | Notepad, alarm, clipboard, help, spell check, etc. |

## Project Structure

```
bayside/
├── archive/                  # Original DeskMate disk images and extracted binaries
│   └── deskmate-3.05/
│       ├── extracted/        # 148 DOS files from the distribution disks
│       ├── iso_contents/     # Archive.org ISO disk images
│       ├── winworld_3.5/     # WinWorld 3.5" disk images
│       └── winworld_5.25/    # WinWorld 5.25" disk images
├── disassembly/
│   ├── raw/                  # Raw Capstone disassembly output
│   │   ├── *.asm             # 17 EXE/PDM disassembly files
│   │   ├── *-callgraph.txt   # Call graphs with INT usage analysis
│   │   ├── res/              # 52 .RES driver disassemblies
│   │   └── acc/              # 18 .ACC accessory disassemblies
│   └── annotated/            # Fully annotated disassembly with named functions
│       ├── *.asm             # 17 EXE/PDM annotated disassemblies
│       ├── res/              # 52 .RES annotated disassemblies
│       └── acc/              # 18 .ACC annotated disassemblies
├── research/
│   ├── docs/                 # DeskMate overview, SDK research, file format specs
│   └── references/           # Tandy hardware register documentation
├── dosbox/
│   ├── configs/              # DOSBox config (Tandy mode, 8086, 4000 cycles)
│   └── scripts/              # Launch scripts for original and rebuilt versions
├── build/                    # Compiled DOS executables (OpenWatcom output)
│   └── hangman/              # HANGMAN.EXE — first transpiled module
├── src/                      # Transpiled C89 source code
│   └── hangman/              # HANGMAN.PDM transpilation (8 files, ~3,900 LOC)
├── tools/                    # Python disassembly and analysis scripts
├── CLAUDE.md                 # Project instructions for Claude Code
└── STATUS.md                 # Per-module reverse engineering status
```

## Getting Started

### Prerequisites

- **DOSBox-X** (recommended) or DOSBox — for running DeskMate in Tandy emulation mode
- **OpenWatcom V2** — for compiling the transpiled C source to DOS executables

Install on macOS:
```bash
# DOSBox-X
brew install --cask dosbox-x

# OpenWatcom V2 (automated installer)
./scripts/setup-watcom.sh --install

# Or activate in current shell (after install)
source scripts/setup-watcom.sh
```

On Linux, download OpenWatcom V2 from [GitHub releases](https://github.com/open-watcom/open-watcom-v2/releases) (`ow-snapshot.tar.xz`) and extract to `~/watcom`. Then `source scripts/setup-watcom.sh`.

### Running the Original DeskMate 3.05

The original DeskMate binaries live in `archive/deskmate-3.05/extracted/`. To run them:

```bash
./dosbox/scripts/run-original.sh
```

This launches DOSBox-X in Tandy mode (8086 CPU, 640KB RAM, TGA video, 3-voice sound) and boots directly into the DeskMate desktop. From there you can open any application — Text, Draw, Filer, Calendar, Hangman, etc. — through the Programs menu.

**DOSBox-X keyboard shortcuts:**
| Key | Action |
|-----|--------|
| `Ctrl+F5` | Save PNG screenshot |
| `Ctrl+F9` | Kill DOSBox-X |
| `Ctrl+F10` | Release mouse capture |
| `Alt+Enter` | Toggle fullscreen |

The DOSBox config (`dosbox/configs/deskmate-tandy.conf`) matches the original Tandy 1000 hardware:
- `machine=tandy` — TGA/TGA2 video adapter + SN76496 3-voice sound
- `cputype=8086` — real mode only, no protected mode
- `cycles=4000` — approximate Tandy 1000 SX speed
- `memsize=640` — 640KB conventional, no EMS/XMS/UMB

### Development Loop

Everything runs from the top-level `Makefile` (any shell; it sets up the
OpenWatcom environment itself). Requires OpenWatcom V2 in `~/watcom`
(or `$WATCOM`), DOSBox-X (`dosbox-x` on PATH or the
`com.dosbox_x.DOSBox-X` flatpak), ffmpeg, and Python 3.

```bash
make setup          # .venv with capstone + unicorn
make identical      # rebuild HANGMAN.PDM from source with no C: byte-identical check
make hangman        # build build/hangman/HANGMAN.PDM (original + C functions spliced in)
make trace-check    # ~1s: every scenario's boundary + call trace vs. the original
make run-rebuilt    # headless DOSBox-X in real DeskMate, frames in build/run/
make trace          # re-record the golden traces from the original binary
```

**How the rebuild works (binary splicing).** `tools/pdm2wasm.py` turns the
original PDM into linkable OpenWatcom asm with every function and every
DGROUP variable at its original offset. Functions listed in
`src/hangman/replaced.txt` are implemented in C (`src/hangman/*.c`) and
spliced in with a `jmp` at their original address; C calls untranslated
original code through labels (`src/hangman/functions.txt`) and uses
original globals at their original addresses (`src/hangman/dgroup.syms`).
Everything is `__cdecl` (`wcc -ecc`), matching MSC 5.x, so both directions
work. `tools/mkpdm.py` writes the MZ+DM89 header. The binary works at every
step, so each newly translated function is verified on its own.

**How it is verified.** `tools/pdm_trace.py` runs a PDM under Unicorn with a
fake DESK.EXE and records every INT E0h call, every far call into a
DeskMate resource (DMCSR, DMGUF, PRGUF, SPELL), DOS calls, and every call
into a not-yet-translated original function, with arguments. Input
scenarios (`tests/traces/*.json`) script dialog results; their golden
traces (`*.trace`) come from the original binary. A wrong argument in
translated C shows up as a one-line diff naming the call.

**To translate a function:** read it in the disassembly, write it in C
(original address in a comment), add it to `replaced.txt`, name any
globals it touches in `dgroup.syms`, run `make trace-check`. If no
scenario reaches the new code, add one first.

`tools/dosbox_run.py` (behind `make run-original` / `make run-rebuilt`)
boots DeskMate headless in a throwaway copy of the files, records AVI and
extracts PNG frames; `DESK.EXE HANGMAN.PDM` launches Hangman directly.
The earlier hand-written transpilation is kept for reference in
`src/hangman/legacy/` (not built).

## Technical Details

### Target Platform
- **CPU:** Intel 8086/8088 (16-bit real mode)
- **RAM:** 512 KB conventional memory
- **Video:** Tandy TGA/TGA2 (320x200x16 default), CGA, EGA, VGA, Hercules
- **Sound:** SN76496 (3 square-wave + 1 noise, port C0h), Tandy DAC (8-bit mono), PC Speaker
- **OS:** MS-DOS 2.0+

### Compiler & Build
- **Original compiler:** Microsoft C 5.x (1987-1988)
- **Rebuild compiler:** OpenWatcom V2 (C89, targeting DOS)
- **Emulation:** DOSBox-X in Tandy machine mode

### DM89 Executable Format
All DeskMate modules (.PDM, .ACC, .RES) are standard DOS MZ executables with a proprietary extension at offset 0x1C:

| Offset | Field | Description |
|--------|-------|-------------|
| 0x1C | `DM89` | 4-byte magic signature |
| 0x20 | dm_version | Format version (0x003E) |
| 0x22 | dm_type | 0x013E = PDM module, 0x0000 = host |
| 0x26 | dm_cs | Authoritative code segment |
| 0x28 | dm_ip | Authoritative instruction pointer |
| 0x3C | dm_flags | Module capability flags |
| 0x42+ | imports | 10-byte null-padded module name entries |

### Documented File Formats
.PDM, .ACC, .RES, .SND, .SNG, .WKS, .FIL, .CLN, .ADR, .CFG, .HLP, .TUT, .FF1, .FIG, .SPL, .CLP, .R89, .PCL, .RFD, .LBL, .MOD

See [research/docs/file-formats.md](research/docs/file-formats.md) for full specifications.

### Hardware Register Documentation
Complete I/O port maps and programming references for TGA/TGA2 video, SN76496 sound, Tandy DAC, PC speaker, keyboard, joystick, and mouse.

See [research/references/hardware-registers.md](research/references/hardware-registers.md) for the full reference.

## Tools

| Script | Purpose |
|--------|---------|
| `tools/disasm_mz.py` | General-purpose MZ+DM89 disassembler using Capstone x86-16 |
| `tools/disasm_pdm.py` | Recursive descent disassembler with prologue scanning for PDMs |
| `tools/disasm_dmvid.py` | Specialized disassembler for DMVID.EXE (MSC 5.0 small model) |
| `tools/batch_disasm_pdm.py` | Batch disassembly for all 14 PDM application modules |
| `tools/batch_disasm_res.py` | Batch disassembly for all 51 RES resource/driver modules |
| `tools/batch_disasm_acc.py` | Batch disassembly for all 18 ACC desk accessories |
| `scripts/setup-watcom.sh` | Install and configure OpenWatcom V2 for DOS cross-compilation |

## Sources

- [Archive.org — DeskMate 3.05 ISO](https://archive.org/details/DOS-GUI-DOS-Tandy-DeskMate-v3.05-1990)
- [WinWorld — Tandy DeskMate 3.x](https://winworldpc.com/product/tandy-deskmate/deskmate-3x)
- [Nerdly Pleasures — Tandy DeskMate](http://nerdlypleasures.blogspot.com/2024/07/tandy-deskmate-tandys-ace-in-hole.html)
- [oldskool.org — Tandy 1000 DeskMate](http://www.oldskool.org/guides/tvdog/deskmate.html)
- [ToastyTech — DeskMate 3.05](http://toastytech.com/guis/deskmate.html)
- [DeskMate 3 Manual (PDF)](https://colorcomputerarchive.com/repo/Documents/Manuals/Applications/Deskmate%203%20(Tandy).pdf)

## License

This project is for historical preservation and research purposes. Original DeskMate binaries are preserved as abandonware. The transpiled C source code and tooling are original work.
