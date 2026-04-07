# DeskMate 3.05 String Extraction and Analysis

## Date: 2026-04-06

## 1. Compiler Identification

### Confirmed: Microsoft C 5.x (1987 runtime)

Every PDM file and several support binaries contain the string:

    MS Run-Time Library - Copyright (c) 1987, Microsoft Corp

This identifies the compiler as **Microsoft C 5.0 or 5.1** (released 1987-1988).
The copyright year 1987 in the runtime library matches MS C 5.0 exactly.

### Runtime Error Messages (present in all PDMs)

All PDM files contain the standard MS C runtime error block, preceded by the
sentinel `<<NMSG>>`:

    R6000 - stack overflow
    R6001 - null pointer assignment
    R6002 - floating point not loaded
    R6003 - integer divide by 0
    R6009 - not enough space for environment

These are the exact R6xxx messages from the Microsoft C 5.x runtime. The presence
of R6002 ("floating point not loaded") indicates the alternate math library is
linked -- the floating point coprocessor emulator is not bundled, so the programs
use integer math or the alternate FP library that triggers this error if FP is
attempted without a coprocessor and no emulator loaded.

### DESK.EXE Does NOT Contain the MS C Runtime

DESK.EXE (the host shell) does **not** contain the "MS Run-Time Library" string
or the R6xxx error messages. This strongly suggests DESK.EXE was written in
assembly language (or a very minimal C build without the standard runtime).
DESK.EXE is only 19,047 bytes -- small for a shell that manages the entire
DeskMate environment.

The PDM modules each statically link their own copy of the MS C runtime. This
is consistent with MS C 5.x small or medium model compilation where each .EXE
gets its own copy of the CRT startup code.

### Memory Model

The PDM files use standard `push bp; mov bp, sp` prologues and 16-bit near
calls, consistent with **small or medium model** (near data, near or far code).
The CS:IP values in the MZ headers show code segments starting at various
offsets, suggesting medium model (multiple code segments) is possible for
larger PDMs, while small model is used for smaller ones like PLAY.PDM.

### Build Date

DESK.EXE contains an internal version stamp:

    DESKMATE$05.00 900919$

This decodes as:
- Internal version: 05.00
- Build date: 1990-09-19 (September 19, 1990)
- Display version (shown in About dialog): 03.05.00

The `$` delimiters suggest a DOS-style string termination convention.

---

## 2. DM89 Extended MZ Header Format

All DeskMate binaries (EXE, PDM, RES) contain a **DM89>** signature embedded
in the MZ header, starting at offset 0x1C. This is a DeskMate-specific extension
to the standard MZ executable format.

### Header Layout (offsets 0x1A onwards)

| Offset | Size | DESK.EXE | PDMs | Description |
|--------|------|----------|------|-------------|
| 0x1A | 2 | 0x4413 | ASCII digits | Pre-DM89 field (varies) |
| 0x1C | 4 | "DM89" | "DM89" | DeskMate signature magic |
| 0x20 | 2 | ">",0x00 | ">",0x00 | Signature terminator |
| 0x22 | 2 | 0x0000 | 0x013E | PDM header version? (0x013E for all PDMs) |
| 0x24 | 2 | varies | CS value | Code segment (matches MZ CS) |
| 0x26 | 2 | varies | varies | Additional segment info |
| 0x28 | 2 | varies | same as 0x24 | Repeated CS value |
| 0x2A | 4 | varies | 0x00000000 | Reserved/zero |

DESK.EXE has a different extended header layout (0x22 = 0x0000 vs 0x013E),
which makes sense as it is the host, not a loadable PDM module.

The two ASCII bytes at 0x1A before "DM89" in PDMs appear to be a decimal
string encoding a count or size. Examples: "68" for DESKTOP.PDM, "39" for
TEXT.PDM, "20" for HANGMAN.PDM. For PLAY.PDM, bytes 0x1A-0x1B are 0x06 0x01
(not ASCII), suggesting this field may be numeric in some files and ASCII in
others, or it encodes something different for PLAY.PDM's format variant.

---

## 3. DeskMate API / Resource System Discovery

### Shared Resource Module Names

Every PDM file references the same set of shared resource module names. These
are the DeskMate host API modules loaded by DESK.EXE that PDMs call into:

| Module Name | Purpose |
|-------------|---------|
| PRGUF | Program User Functions -- the main DeskMate API library |
| DMGUF | DeskMate General User Functions |
| DMCSR | DeskMate Cursor management |
| DMSPELL | DeskMate Spell checking module |
| DMDB | DeskMate Database engine |
| DMDBRD | DeskMate Database Read module |
| DMDBBLD | DeskMate Database Build module |
| DMTHES | DeskMate Thesaurus |
| DMPLAY | Tutorial playback engine (PLAY.PDM) |
| DMUNPACK | Decompression/unpacking module |
| DMCONFIG | Configuration file reader/writer |
| DMPGSET | Page Setup module (TEXT.PDM) |

The string `;C_FILE_INFO` appears in DESKTOP.PDM, TEXT.PDM, HANGMAN.PDM, DRAW.PDM,
FILER.PDM, and WRKSHEET.PDM. This is likely a structure name or API identifier for
DeskMate's file information system.

### Resource Loading Mechanism

DESK.EXE contains: `WARNING: Resource $ had UseCount = $h`

This confirms DESK.EXE implements a **reference-counted resource manager**.
Resources (.RES files) are loaded on demand and tracked with use counts. The `$`
characters are likely printf-style substitution markers (DeskMate custom format,
not standard C printf).

DESK.EXE also references these resource-related strings:
- `.ACC` -- Accessory modules
- `.RES` -- Resource/driver modules
- `.R89` -- Alternate resource format (possibly version-specific)
- `.PDM` -- Program modules
- `DMOLDAPP.MOD` -- Legacy application compatibility module
- `AUTOLOAD.CFG` -- Lists resources to preload at startup

### File Type References in DESK.EXE

    PDMCOMEXEBATSR -- Lists executable extensions DESK.EXE can launch:
                      PDM, COM, EXE, BAT, and SR (unknown)

### Environment Variables

DESK.EXE reads these DOS environment variables:
- `PATH=` -- Standard DOS path
- `COMSPEC=` -- Path to COMMAND.COM (for shelling out)
- `DMCONFIG=` -- DeskMate configuration directory path
- `DMTASK1=` -- First task slot identifier

---

## 4. DESKTOP.PDM -- Desktop UI Strings

### Menu Structure (complete menu bar)

    File: Get Info, Run, Copy, Delete, Rename, Update screen (Ctrl+U), Exit (Esc), About
    Directory: Create, Change
    Disk: Format, Diskcopy
    View: (display modes)
    Sort by: Name, Type, Date, Size
    Desktop: Create, Delete, Redefine, Display, Remove, Move, Install, Create quick load

### Dialog Strings

Full set of dialog boxes identified:
- File Info (filename, size, date)
- Run File (program + data file selection, CPU clock speed: Normal/Fast)
- Copy File (with floppy disk swap prompts)
- Delete File, Rename File
- Create/Change/Delete Directory
- Disk Info (volume name, free space)
- Format Disk (3.5"/5.25", High Density/Double Sided)
- Copy Disk
- Create/Delete/Redefine Menu
- Create Quick Load

### File Status Bar

    Filename Ext.   Size    Date     Time   Program

    Current Drive: (drive letter)
    No Label

### Error Messages (39 distinct messages)

Comprehensive error handling including:
- File system errors (not found, path errors, disk full, access denied)
- Directory errors (already exists, not empty, cannot create)
- DeskMate-specific errors ("Cannot switch to alternate task",
  "Two non-DeskMate applications may not run at the same time",
  "Could not sign in - DeskMate will exit")

### Application Registry

DESKTOP.PDM contains a complete mapping of application names to PDM files:

| Display Name | PDM File | Internal Key |
|-------------|----------|--------------|
| Teach Me | PLAY.PDM | learn |
| Text | TEXT.PDM | text |
| Filer | FILER.PDM | filer |
| Address Book | ADDRESS.PDM | address |
| Worksheet | WRKSHEET.PDM | worksheet |
| Draw | DRAW.PDM | draw |
| Telecom | TELECOM.PDM | telecom |
| Calendar | CALENDAR.PDM | calendar |
| Hangman | HANGMAN.PDM | hangman |
| Form Setup | FORMSET.PDM | form setup |
| PC-Link | PC_LINK.PDM | pclink |
| Install | INSTALL.PDM | autoconfig |

Additional virtual "applications" (desktop sections):
- month, corkboard, phone, programs, others, to do

### Video Adapter Support Table

DESKTOP.PDM contains null-terminated video mode identifier strings at offset 0x118F0:

    1000CGA     -- 1000-line? CGA mode
    DDGAEGA     -- DGA (Direct Graphics Adapter?) + EGA
    HERCPLANTC16TC4  -- Hercules, Plantronics ColorPlus, Tandy Color 16-color, Tandy Color 4-color
    VGA         -- Standard VGA
    MCGAEGA     -- MCGA + EGA
    LREST256TC40H    -- Low-res?, T256 (Tandy 256-color?), TC40 (Tandy Color 40-column?), Hercules

These are followed by single-character mode codes: C, M, E, T (possibly
CGA, MCGA, EGA, Tandy shorthand codes).

### Networking / Multi-User Strings

    TLLOGIN      -- Tandy Login (network login)
    TENETWRK     -- Network configuration
    TEN_NET      -- TEN = Tandy Enhanced Networking?
    TENSTAT.CFG  -- Network status config
    USER.CFG     -- Per-user configuration
    TOOLSLCT.PDM -- Tool selection module

### Calendar Data

Month names (January through December) and the string "Phone List",
"Corkboard", "Things To Do" -- these are the DeskMate desktop sections.

### Configuration Files Referenced

    DESKTOP.CFG   -- Main desktop configuration (structured binary, see below)
    DESKTOPD.CFG  -- Default/backup desktop config
    TREE.CFG      -- Directory tree cache
    HANGMAN.CFG   -- Hangman game settings
    ALARM.CFG     -- Calendar alarm settings
    USER.CFG      -- Network user profile
    TENSTAT.CFG   -- Network status
    DMCSR.CFG     -- Cursor configuration

### External Program References

    FORMAT.COM    -- DOS format utility (for disk formatting)
    DISKCOPY.COM  -- DOS disk copy utility
    COMMAND.COM   -- DOS command interpreter
    INFOCNTR.PDM  -- Information Center module

### Format Command Arguments

    /T:40   -- 40 tracks
    /T:80   -- 80 tracks
    /F:360  -- 360KB format
    /F:720  -- 720KB format
    /V:     -- Volume label

---

## 5. TEXT.PDM -- Word Processor

### Menu Structure

    File: Open, Save, Save as, Merge, Page setup, Print, Print form letter, Exit, Run, To ASCII, About
    Edit: Cut (Shift+Del), Copy (Ctrl+Ins), Paste (Shift+Ins), Clear (Del),
          Select all, Un-Delete (Ctrl+U), Insert (Ins)
    Text: Proof, Thesaurus, Plain, Bold, Underline, Center (Ctrl+C), Un-Center,
          Indent (Ctrl+I), Dictionary, Translate
    Search: Find (Ctrl+F), Find next (Ctrl+N), Substitute (Ctrl+S)
    Layout: Return to Document, Header, Footer, Page number, Today's date, Add field, Show/Hide
    Picture: Move, Size

### Notable Features

- Spell checking (references DICTARY, DMSPELL, SPELL modules)
- Thesaurus (references DMTHES module)
- Translation (references TRANSLAT module)
- Mail merge (references MAILMRGE.PDM, Address Book integration via PERSONAL.ADR)
- Picture embedding with move/size support
- Header/footer with page numbers and date fields
- CPI (Characters Per Inch) support for printing

### Copyright Anomaly

TEXT.PDM contains TWO copyright strings:
- `DeskMate Copyright 1984, 1989` (older, possibly from the TEXT module itself)
- `DeskMate Copyright 1984, 1990` (newer, from the shared DeskMate About dialog code)

This suggests TEXT.PDM was originally compiled in 1989 and the shared About
dialog code was updated in 1990, but both are statically linked into the binary.

---

## 6. HANGMAN.PDM -- Word Game

### Menu Structure

    Game: Save, Restore, Exit (Esc), Run, About
    Players: Define, Add, Delete

### Game Features

- 1-4 player support
- Configurable words per game and wrong guesses limit
- Save/restore game state (HANGMAN.CFG)
- Scoreboard with current game stats
- ASCII art hangman graphics (large block of coordinate data in binary)

### Content Filter

HANGMAN.PDM contains a **profanity filter** -- a list of word fragments that
are excluded from the word selection. The fragments are stored without their
first letter (to save space or obfuscate), e.g.:
- "ortion" (abortion), "astard" (bastard), "ornicat" (fornicate), etc.
- Approximately 70+ filtered word stems covering explicit/vulgar terms

This is notable as a family-friendly content safeguard from Tandy, a company
that sold DeskMate-equipped computers through RadioShack stores.

---

## 7. PLAY.PDM -- Tutorial Player

### Features

- Plays .TUT tutorial lesson files
- Can search the system for available tutorials
- Version check: refuses to run under DeskMate 03.02.00 or earlier
- References DMPLAY and DMUNPACK resource modules
- Smallest PDM at 12,183 bytes -- good candidate for first full disassembly

### Available Tutorials Referenced

    DMINTRO.TUT, ADDRESS.TUT, CALENDAR.TUT, DESKTOP.TUT, DRAW.TUT,
    FILER.TUT, FORMSET.TUT, MUSIC.TUT, SOUND.TUT, TEXT.TUT,
    WRKSHEET.TUT, FINANCE.TUT, INFOCNTR.TUT, KITCHEN.TUT, PERSONAL.TUT

---

## 8. DESKTOP.CFG Binary Format

The DESKTOP.CFG file is a structured binary configuration file. Each record
appears to be a fixed-size entry (approximately 0x3A bytes) containing:

| Offset | Content | Example |
|--------|---------|---------|
| 0x00 | Section name (null-padded to ~13 bytes) | "DESKTOP", "QUICK LOAD" |
| 0x0E | Display name (null-padded to ~13 bytes) | "TEACH ME!", "TEXT" |
| 0x1C | PDM filename (null-padded to ~13 bytes) | "PLAY.PDM", "TEXT.PDM" |
| 0x2E | Data file extension | "DOC", "FIL", "WKS" |
| 0x34 | Flags byte + position bytes | 0x46 = 'F' (flag?) |

---

## 9. Key Findings Summary

### For Compiler/Toolchain Setup
- **Compiler:** Microsoft C 5.0 or 5.1 (1987)
- **Runtime:** MS C 5.x CRT with alternate math library
- **Linker:** Microsoft Linker (implied by MS C)
- **Target:** 8086 real mode, small or medium memory model
- **DESK.EXE:** Likely hand-written assembly (no C runtime)

### For Reverse Engineering Priority
1. **PLAY.PDM** (12KB) -- Smallest, simplest, good first target
2. **HANGMAN.PDM** (27KB) -- Simple game logic, self-contained
3. **DESK.EXE** (19KB) -- Critical host shell, likely assembly
4. **DESKTOP.PDM** (73KB) -- Core UI, many API calls to trace
5. **TEXT.PDM** (75KB) -- Complex application with many features

### For API Documentation
- The PRGUF and DMGUF modules are the primary DeskMate API
- `;C_FILE_INFO` is a key data structure for file operations
- Resource modules use reference counting (UseCount tracking)
- DMCONFIG handles all .CFG file I/O
- Video adapter support is table-driven with mode identifier strings

### For Verification
- Internal version "DESKMATE$05.00 900919$" can be used to verify correct binary
- Display version "03.05.00" appears in the About dialog
- Copyright "1984, 1990 Tandy Corporation" appears in shared code
- The DM89> magic at MZ header offset 0x1C identifies authentic DeskMate binaries
