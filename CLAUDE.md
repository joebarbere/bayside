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
│   ├── worksheet/         # Worksheet spreadsheet (WRKSHEET.PDM)
│   ├── filer/             # Filer database
│   ├── draw/              # Draw vector graphics editor
│   ├── telecom/           # Telecom terminal emulator
│   ├── calendar/          # Calendar/scheduler
│   ├── addressbook/       # Address Book (ADDRESS.PDM)
│   ├── pclink/            # PC-Link online service client (PC_LINK.PDM)
│   ├── hangman/           # Hangman word game
│   ├── formset/           # Form designer (FORMSET.PDM)
│   ├── play/              # Music player (PLAY.PDM)
│   └── mailmerge/         # Mail merge (MAILMRGE.PDM)
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
| Worksheet | WRKSHEET.PDM | P1 | Spreadsheet |
| Filer | FILER.PDM | P1 | Flat-file database / file manager |
| Draw | DRAW.PDM | P1 | Vector graphics editor |
| Calendar | CALENDAR.PDM | P2 | Scheduler with alarms |
| Address Book | ADDRESS.PDM | P2 | Address/phone book |
| Telecom | TELECOM.PDM | P2 | Terminal emulator |
| Form Set | FORMSET.PDM | P2 | Form designer |
| Hangman | HANGMAN.PDM | P3 | Word game |
| Play | PLAY.PDM | P3 | Music player |
| PC-Link | PC_LINK.PDM | P3 | Online service client |
| Mail Merge | MAILMRGE.PDM | P3 | Mail merge utility |
| Installer | INSTALL.PDM | P3 | Installer module |
| Video Driver | DMVID.EXE | P1 | Video adapter selection/configuration |
| Resources | *.RES | P1 | Loadable drivers (video, memory, sound, music) |
| Accessories | *.ACC | P2 | Desk accessories (notepad, alarm, clipboard, etc.) |

## Key Technical Details

### Hardware to Emulate in C
- **Tandy Graphics Adapter (TGA/TGA2):** 320x200x16, 640x200x16, mapped at segment B800h
- **SN76496 Sound Chip:** 3 square-wave + 1 noise channel, I/O port C0h
- **Tandy DAC:** 8-bit mono, 5500/11000/22000 Hz sample rates
- **PC Speaker:** Fallback sound on non-Tandy systems

### File Formats to Document
- **.PDM** — DeskMate executable (runs inside DESK.EXE host)
- **.ACC** — DeskMate desk accessories (notepad, alarm, clipboard, spell check, etc.)
- **.SND** — 8-bit audio (magic byte 0x1A, 16-byte header, optional compression)
- **.SNG** — 3-channel music composition
- **.PNT** — Bitmap graphics (Personal DeskMate)
- **.FIG** — Vector graphics (Draw)
- **.WKS** — Spreadsheet data
- **.FIL** — Database records
- **.RES** — Loadable resource/driver modules
- **.CFG** — Configuration (DESKTOP.CFG)
- **.R89** — Resource files (1989 format variant)
- **.MOD** — Module/compatibility files
- **.FF1** — Font files
- **.RFD** — Printer driver definition files
- **.HLP** — Help files
- **.TUT** — Tutorial files
- **.PCL** — Printer control language files

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

All from the top-level Makefile (no need to source anything; works from fish):

```bash
make setup          # .venv (capstone, unicorn)
make identical      # HANGMAN.PDM rebuilt from source, no C: must be byte-identical
make hangman        # build/hangman/HANGMAN.PDM with C functions spliced in
make trace-check    # compare traces of the rebuild vs. golden traces (~1s) -- run after every change
make trace          # re-record golden traces from the original binary
make run-rebuilt    # headless DOSBox-X run inside real DeskMate (frames in build/run/)
make play           # interactive DOSBox-X window with the rebuilt Hangman
```

### Decompilation workflow (binary splicing)
- The original PDM is emitted as asm with original offsets (tools/pdm2wasm.py).
  A C function replaces the original when its definition is preceded by a
  `/* address: 0000:XXXX ... */` comment whose address and name match
  src/hangman/functions.txt. Placement: once every function in 0010-2FFF is
  C, the C code links INTO that range (two-pass link, original segment map
  kept exactly -- real DESK.EXE needs this); otherwise after CRT_TEXT, which
  only runs in the harness. Never between _TEXT and CRT_TEXT.
- Read code with `tools/disfn.py <name|addr>` (calls resolved, arg counts,
  jump tables decoded). Translate faithfully from the disassembly, not from
  the annotations' prose: annotated names/arg descriptions are often guesses.
- Original functions not yet in C are declared old-style in the generated
  build/hangman/protos.h. Functions in C get a full prototype in their area
  header: game.h (0010-0DD7), dialog.h (0DD8-1AFA), draw.h (1AFB-23EA),
  words.h (23EB-2FFF). Never call hangman_itoaBuf/strcpyDI/strlenSI or
  dm_videoNameIndex (register conventions).
- Globals: original DGROUP offsets. Name them in a *.syms file (one per area
  is fine; conflicts fail the build) or use DG8/DG16(addr) until understood.
- No new uninitialised C globals (build fails): the original startup only
  zeroes the original BSS.
- After each function: `make trace-check`. If no scenario reaches the code,
  add tests/traces/hangman-<name>.json and run `make trace` (re-records all
  goldens from the original).

### PDM <-> DeskMate interface (verified with tools/pdm_trace.py)
- INT E0h AX=0206h loads a resource by name (DS:DX) and writes its far entry
  point to ES:BX; 0207h unloads; 0208h queries.
- UI services are far calls into DMCSR; DMCSR dispatches on AX & 0FFFh (args at SS:BP);
  DMGUF/PRGUF calls take args at SS:BX+6. NOT direct INT E0h.
- Service dispatch in DMCSR/DMGUF/PRGUF/SPELL is mapped in
  research/docs/dmcsr-services.md; `tools/resdis.py DMCSR <code>` disassembles
  any service handler. Check a harness model against the handler before
  relying on it.
- Verified against the handlers and modelled to match: the event queue
  (0014h peek holds an event, 0013h get blocks then consumes, 0016h flush
  DISCARDS the held event), keyToChar (PRGUF 0023h), the DMCSR version
  (00D5h = 036Fh), SPELL return codes. Scenario events are input given while
  the program blocks in get; mark an event "ahead" (["key","A","ahead"]) for
  type-ahead that peeks can see. Drawing/dialog/form services are not read
  (traces check their arguments only). Passing traces + a DOSBox playthrough
  together are still the bar.
