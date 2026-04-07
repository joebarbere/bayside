# Bayside — Tandy DeskMate Reverse Engineering Project

## Project Overview

Bayside is a reverse engineering project to recreate Tandy DeskMate (primarily version 3.05) as clean C source code. The project works in stages: acquire original binaries, disassemble them, annotate the assembly, transpile to C, and verify the C version produces identical behavior when run in DOSBox.

The name "Bayside" is a codename for this reconstruction effort.

## Goals

1. Preserve and document the original Tandy DeskMate software
2. Produce fully annotated disassembly of all DeskMate executables
3. Transpile the disassembly into readable, compilable C source
4. Verify functional equivalence by running the C version in DOSBox
5. Document all file formats, UI behaviors, and hardware interactions

## Tech Stack

- **Target platform:** MS-DOS (8086/8088 real mode, 512KB RAM)
- **Disassembly:** Ghidra, IDA Free, or Radare2
- **Transpiled language:** C (Watcom C or OpenWatcom for DOS targeting)
- **Emulation:** DOSBox / DOSBox-X (Tandy mode)
- **Build:** Make / CMake for the C rebuild
- **Scripts:** Bash + Python for tooling and analysis
- **CI validation:** DOSBox headless runs comparing original vs rebuilt behavior

## Architecture — Multi-Stage Reverse Engineering Plan

### Stage 1: Research & Acquisition
- Gather DeskMate binaries (archive.org, WinWorld, disk images)
- Document all known versions, file formats, and hardware dependencies
- Set up DOSBox configs to run original DeskMate

### Stage 2: Binary Analysis
- Extract all executables (.EXE, .PDM, .RES) from disk images
- Generate raw disassembly with Ghidra/IDA
- Identify compiler signatures (likely Microsoft C 5.x or Borland C)
- Map out the call graph and module boundaries

### Stage 3: Annotation & Understanding
- Label all functions, variables, and data structures
- Document the DeskMate shell (DESK.EXE) API that .PDM programs call
- Map hardware access: TGA/TGA2 video registers, SN76496 sound chip, DAC
- Understand the .PDM executable format and loader

### Stage 4: C Transpilation
- Convert annotated assembly to C, module by module
- Start with standalone utilities (Calculator, Hangman) as proof of concept
- Progress to core shell (DESK.EXE / DESKTOP.PDM)
- Then each application: Text, Worksheet, Filer, Draw, Music, Sound, etc.

### Stage 5: Verification
- Compile C code with OpenWatcom targeting DOS
- Run in DOSBox with identical config to original
- Compare screen output, file I/O, and behavior
- Automated regression testing via DOSBox screenshots

## Claude Code Subagent Strategy

This project uses Claude Code subagents for parallelized work:

- **Research agents:** Web search for DeskMate documentation, file format specs, hardware registers
- **Disassembly agents:** Analyze and annotate sections of disassembled code
- **Transpilation agents:** Convert annotated assembly blocks to C functions
- **Verification agents:** Write test harnesses and compare behavior
- **Documentation agents:** Maintain the feature status tracker

## Project Structure

```
bayside/
├── CLAUDE.md              # This file — project instructions for Claude
├── STATUS.md              # Feature/module reverse engineering status tracker
├── research/
│   ├── docs/              # DeskMate manuals, technical references, notes
│   ├── screenshots/       # Screenshots of original DeskMate for reference
│   └── references/        # Hardware docs (TGA, SN76496, Tandy DAC)
├── archive/               # Original DeskMate disk images and binaries
│   ├── deskmate-1.0/
│   ├── deskmate-2/
│   ├── personal-deskmate/
│   ├── personal-deskmate-2/
│   ├── deskmate-3.00/
│   ├── deskmate-3.02/
│   └── deskmate-3.05/     # Primary target for reverse engineering
├── dosbox/
│   ├── configs/           # DOSBox config files (Tandy mode, video, sound)
│   └── scripts/           # Launch scripts for original and rebuilt versions
├── disassembly/
│   ├── raw/               # Raw Ghidra/IDA output
│   └── annotated/         # Human/AI-annotated disassembly with labels
├── src/                   # Transpiled C source code
│   ├── common/            # Shared: DOS API wrappers, video, sound, input
│   ├── desktop/           # DESK.EXE shell and DESKTOP.PDM
│   ├── text/              # Text word processor
│   ├── worksheet/         # Worksheet spreadsheet
│   ├── filer/             # Filer database
│   ├── draw/              # Draw vector graphics editor
│   ├── telecom/           # Telecom terminal emulator
│   ├── calendar/          # Calendar/scheduler
│   ├── addressbook/       # Address Book
│   ├── music/             # Music composer (3-channel + samples)
│   ├── sound/             # Sound recorder/editor
│   ├── pclink/            # PC-Link online service client
│   ├── hangman/           # Hangman word game
│   └── calculator/        # Calculator accessory
├── build/                 # Build output directory
├── scripts/               # Build, test, and analysis automation
├── tools/                 # Custom analysis tools (Python/Bash)
└── status/                # Per-module status files for tracking
```

## DeskMate 3.05 Target Components

| Module | Binary | Priority | Description |
|--------|--------|----------|-------------|
| Shell | DESK.EXE | P0 | Main DeskMate host environment |
| Desktop | DESKTOP.PDM | P0 | Desktop UI, icon launcher, file manager |
| Text | TEXT.PDM | P1 | Word processor |
| Worksheet | WORKSHT.PDM | P1 | Spreadsheet |
| Filer | FILER.PDM | P1 | Flat-file database |
| Draw | DRAW.PDM | P1 | Vector graphics editor |
| Calendar | CALENDAR.PDM | P2 | Scheduler with alarms |
| Address Book | ADDRBOOK.PDM | P2 | Contact manager |
| Music | MUSIC.PDM | P2 | 3-channel music composer |
| Sound | SOUND.PDM | P2 | Digital audio recorder/editor |
| Telecom | TELECOM.PDM | P2 | Terminal emulator |
| Calculator | CALC.PDM | P3 | Calculator accessory |
| Hangman | HANGMAN.PDM | P3 | Word game |
| PC-Link | PCLINK.PDM | P3 | Online service client |
| Video Driver | DMVID.EXE | P1 | Video adapter selection/configuration |
| Resources | *.RES | P1 | Loadable drivers (video, memory, sound, music) |

## Key Technical Details

### Hardware to Emulate in C
- **Tandy Graphics Adapter (TGA/TGA2):** 320x200x16, 640x200x16, mapped at segment B800h
- **SN76496 Sound Chip:** 3 square-wave + 1 noise channel, I/O port C0h
- **Tandy DAC:** 8-bit mono, 5500/11000/22000 Hz sample rates
- **PC Speaker:** Fallback sound on non-Tandy systems

### File Formats to Document
- **.PDM** — DeskMate executable (runs inside DESK.EXE host)
- **.SND** — 8-bit audio (magic byte 0x1A, 16-byte header, optional compression)
- **.SNG** — 3-channel music composition
- **.PNT** — Bitmap graphics (Personal DeskMate)
- **.FIG** — Vector graphics (Draw)
- **.WKS** — Spreadsheet data
- **.FIL** — Database records
- **.RES** — Loadable resource/driver modules
- **.CFG** — Configuration (DESKTOP.CFG)

## Code Style (for transpiled C)

- Use C89/C90 for OpenWatcom compatibility
- Function names: `module_verbNoun()` e.g. `desktop_drawMenuBar()`
- Constants for all hardware addresses and magic numbers
- Preserve original program logic flow — do not "modernize" algorithms
- Comment every function with its original address in the disassembly
- Use `/* address: seg:offset */` comments for traceability

## DOSBox Configuration

Run original DeskMate:
```bash
cd dosbox && ./scripts/run-original.sh
```

Run rebuilt C version:
```bash
cd dosbox && ./scripts/run-rebuilt.sh
```

Both scripts should use Tandy machine type with matching memory/video/sound config.

## Development Commands

### Build (once OpenWatcom is set up)
```bash
# Set up OpenWatcom environment
source scripts/setup-watcom.sh
# Build all modules
make -C src all
```

### Disassemble a binary
```bash
python tools/disasm.py archive/deskmate-3.05/DESK.EXE -o disassembly/raw/desk.asm
```

### Compare original vs rebuilt
```bash
python tools/compare.py --original dosbox/configs/original.conf --rebuilt dosbox/configs/rebuilt.conf
```
