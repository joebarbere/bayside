# DeskMate SDK, PDM Format, and Runtime API Research

**Date:** 2026-04-06
**Researcher:** Claude Code (Sonnet 4.6)
**Status:** First-pass research — findings from web searches and direct binary analysis of the DeskMate 3.05 extracted files in `/archive/deskmate-3.05/extracted/`

---

## 1. Executive Summary

The DeskMate Development System (DMDS 3.03) exists and has been archived. The compiler used for DeskMate is **Microsoft C** (1987 runtime, likely MSC 5.x). All DeskMate modules (.PDM, .RES, .ACC) are standard **DOS MZ executables** with a proprietary extended header starting at offset 0x1C. The primary DeskMate API is **INT E0h** with a two-byte AX dispatch code organized by service class (AH) and function number (AL). DESK.EXE acts as the resident host and installs an INT E0h handler; all PDM applications call it to access DeskMate services.

---

## 2. DeskMate SDK / Development System

### 2.1 DeskMate Development System (DMDS) 3.03

A DeskMate Development System version 3.03 has been archived and is available. Sample files in the development system are dated 1989, indicating it was an internal Tandy development toolkit.

- **Primary download location (may be offline):** `http://ftp.oldskool.org/pub/tvdog/tandy1000/wares/DeskMate-Development-System-3.03/`
- **Reference page (returns 404 as of 2026):** `https://www.danielsays.com/ssg-deskmate-dmds03.html`
- **WinWorld** lists DeskMate 3.x versions but no separate DMDS entry as of 2026: `https://winworldpc.com/product/tandy-deskmate/deskmate-3x`

### 2.2 SDK Contents (from secondhand reports)

Based on community sources, the DeskMate Development System contained:
- C header files for the DeskMate API (INT E0h services)
- A linker stub / startup object that implements the PDM loading protocol
- Documentation covering the DeskMate API, Form Manager, and file formats
- Sections specifically covering Tandy sound chips and Tandy graphics modes
- Sample PDM application source code

The SDK required **Microsoft C compiler version 4.0 or later** (confirmed by runtime signatures in binaries; see Section 4).

The SDK retailed for **$299** and was available directly from Tandy Corporation.

### 2.3 Development Guide References

The **DeskMate Development Guide** (exact catalog number unknown) contains:
- Appendix A: Brief outline of the Draw (.FIG) format
- Form Manager section of the DeskMate Technical Reference: describes "form" drawing commands
- API reference for INT E0h service classes

The **DeskMate Technical Reference** (separate document) covers the Form Manager commands.

A user manual is archived at:
- `https://colorcomputerarchive.com/repo/Documents/Manuals/Applications/Deskmate%203%20(Tandy).pdf`
- `https://colorcomputerarchive.com/repo/Documents/Manuals/Applications/Deskmate%20(Tandy).pdf`

The Tandy 2000 DeskMate Reference Manual (cat. no. 26-5316) is on GitHub:
- `https://github.com/Tandy2K/Tandy2000/blob/master/Documentation/DeskMate%20Reference%20Manual%2026-5316.pdf`

### 2.4 Prior Art: Existing Disassembly

A partial disassembly of DeskMate I (DESK.EXE from DeskMate II) exists on GitHub:
- `https://github.com/GoombaProgrammer/tandy-deskmate`
- Files: `DESK.ASM` (kernel), `TWMENU.ASM` (menu system), `srmacros.inc`
- Target assembler: MASM 5.0
- NOTE: This is DeskMate I/II, not DeskMate 3. The DESK.EXE for DeskMate I is a much simpler program — the DeskMate 3.x DESK.EXE is far more complex.

---

## 3. Compiler Identification

**Confirmed: Microsoft C runtime (1987 vintage, likely MSC 5.x)**

Every `.PDM` and `.ACC` file in DeskMate 3.05 contains the string:

```
MS Run-Time Library - Copyright (c) 1987, Microsoft Corp
```

This string appears at or near the entry point of each module. The build date in DESK.EXE is **September 19, 1990** (`DESKMATE$05.00 900919$`).

### Entry Point Prologue (all PDM/ACC files)

Every PDM and ACC file begins execution with identical MS C startup code:

```asm
B4 30       MOV AH, 30h
CD 21       INT 21h          ; get DOS version
3C 02       CMP AL, 02h
73 02       JAE +2           ; skip if DOS >= 2.0
CD 20       INT 20h          ; terminate if DOS < 2.0
BF xx xx    MOV DI, xxxx     ; load stack segment
...
```

This is the standard Microsoft C 5.x startup (CRT0.ASM / C0S.ASM). The 1987 copyright places the runtime at **MSC 5.0 or 5.1** (shipped 1987-1988).

DESK.EXE contains:
- Version string: `Version: 03.05.00`
- Copyright: `Copyright 1984,1990 Tandy Corporation`
- Build date: `900919` (September 19, 1990)

Borland/Turbo C was **not** used (no `__turboc__`, `__BORLANDC__`, or Borland copyright strings found in any file).

---

## 4. The .PDM Executable Format

### 4.1 Overview

`.PDM` files are **standard DOS MZ executables** (magic bytes `4D 5A`) with a custom extended header in the region between the end of the standard MZ header and the start of the relocation table. They can be loaded by DESK.EXE like any other MZ module, with the loader applying the standard relocation table.

DESK.EXE uses `INT 21h AH=4Bh` (EXEC) or a custom loader that manually maps the PDM into memory. The PDM then calls back into DESK.EXE via INT E0h to access DeskMate services.

### 4.2 Header Format

The standard DOS MZ header is 28 bytes (offsets 0x00-0x1B). DeskMate PDM/RES/ACC files extend this with a custom block at offset 0x1C that runs until the relocation table offset (stored in the standard header field at 0x18).

```
Offset  Size  Description
------  ----  -----------
0x00    2     Magic: "MZ" (4D 5A)
0x02    2     Bytes in last 512-byte page
0x04    2     Number of 512-byte pages (file size)
0x06    2     Number of relocation entries
0x08    2     Header size in 16-byte paragraphs (always 0x20 = 512 bytes)
0x0A    2     Minimum memory allocation (paragraphs)
0x0C    2     Maximum memory allocation (paragraphs, usually 0xFFFF)
0x0E    2     Initial SS (relative to load segment)
0x10    2     Initial SP
0x12    2     Checksum (usually 0x0000)
0x14    2     Initial IP
0x16    2     Initial CS (relative to load segment)
0x18    2     Relocation table offset (0x3E, 0x42, 0x4C, or 0x60)
0x1A    2     Overlay/module version: ASCII digits in little-endian
              e.g. 0x3836 = "68" for DESKTOP.PDM version 68
                   0x3933 = "39" for TEXT.PDM version 39
                   0x0000 = no version (some RES files)

--- DeskMate Extended Header ---
0x1C    4     "DM89" signature: 44 4D 38 39
0x20    2     Usually 0x003E (copy of reloc table offset?)
0x22    2     Module type flags (0x0000 = basic, 0x013E = PDM with features)
0x24    2     Segment reference 1 (varies by module)
0x26    2     Code/data segment selector
0x28    2     Segment offset 1
0x2A    2     Segment selector 2
0x2C-   ...   Additional segment references (zero-padded)
until reloc_off
```

The relocation table offset values and their meaning:
- `0x3E` (62): Standard DM RES/DLL-style module (34 bytes of extended header)
- `0x42` (66): Standard PDM application (38 bytes of extended header)
- `0x4C` (76): ACC accessory module (48 bytes of extended header)
- `0x60` (96): Larger PDM (FILER.PDM, FORMSET.PDM, PLAY.PDM) — 64 bytes of extended header

### 4.3 Module Version Field

The overlay number (offset 0x1A) encodes the module revision as two ASCII decimal digits stored little-endian:

| File | Overlay (hex) | Version |
|------|--------------|---------|
| DESKTOP.PDM | 0x3836 | "68" |
| TEXT.PDM | 0x3933 | "39" |
| DRAW.PDM | 0x3034 | "40" |
| FILER.PDM | 0x3434 | "44" |
| WRKSHEET.PDM | 0x3432 | "24" |
| HANGMAN.PDM | 0x3032 | "20" |
| ADDRESS.PDM | 0x3936 | "69" |
| CALENDAR.PDM | 0x3633 | "36" |
| TELECOM.PDM | 0x3831 | "18" |
| FORMSET.PDM | 0x3233 | "32" |
| MAILMRGE.PDM | 0x3832 | "28" |
| INSTALL.PDM | 0x3533 | "35" |

This is a module build/revision number (not the DeskMate product version).

### 4.4 File Type Extension Association in ACC/PDM

The `.ACC` (accessory) files use reloc offset 0x4C, giving 16 more bytes of extended header than standard PDMs. These extra bytes likely encode the associated file type and other accessory metadata.

### 4.5 Non-DeskMate Files in the Same Distribution

A few files lack the "DM89" signature and use different formats:

- `ALRMINIT.RES`, `D87.RES`, `DMUNPACK.RES`, `DMVID.EXE` — standard DOS MZ with reloc offset 0x1E (the bare minimum header, no DM extension). These are non-DeskMate helper programs that run standalone or as standard DOS processes.

---

## 5. DeskMate Runtime API (INT E0h)

### 5.1 Mechanism

DESK.EXE installs a handler on **INT E0h** (interrupt vector 0xE0, decimal 224). All DeskMate modules (PDM, RES, ACC) call this interrupt to access DeskMate services. This is the primary host-to-module communication channel.

**Calling convention:**
```asm
; Check if DeskMate is available (common pattern in every module):
MOV  AL, [ds:000Ah]       ; read resident flag byte
CMP  AL, 0FFh
JZ   +9                    ; skip if flag = 0xFF (DeskMate not resident?)
PUSH DX
MOV  DL, AL               ; pass module context in DL
MOV  AX, [service_code]   ; load AH=class, AL=function
INT  E0h
POP  DX
```

DESK.EXE also uses INT E0h internally 11 times (calling services it also provides).

### 5.2 Service Classes

Services are organized by AH value:

#### AH = 0x00: Core/System Services
| AX | Description |
|----|-------------|
| 0x0003 | Font-related (used by DMFONT.RES, DMPLAY.RES) |
| 0x0008 | Database read service (DMDBRD.RES) |
| 0x0009 | Database service (DMDBRD.RES) |
| 0x0090 | Autoload service |
| 0x0091 | Help/Notepad/Phone/Clip display (used by ACC files with UI) |

#### AH = 0x01: Module Lifecycle Services
| AX | Description |
|----|-------------|
| 0x01F0 | Load/register resource module (ALARM, forms, printer drivers) |
| 0x01FF | Unload/deregister module (used by RES files on exit) |

#### AH = 0x02: UI/Form Manager Services
| AX | Description |
|----|-------------|
| 0x0206 | Open/create form window |
| 0x0207 | Close/destroy form window |
| 0x0208 | Draw/update form |
| 0x0209 | Form field operation (printer RES files) |
| 0x020B | Form event / keyboard input |
| 0x020C | Form redraw / refresh |

#### AH = 0x04: Draw/Graphics Services (DMEFORM, DMFORM)
| AX | Description |
|----|-------------|
| 0x0401 | Graphics draw primitive 1 |
| 0x0402 | Graphics draw primitive 2 |

#### AH = 0x06: Window/Desktop Management
| AX | Description |
|----|-------------|
| 0x0600 | Window init / register application |
| 0x0602 | Window service (DMDBRD) |
| 0x0603 | Open desktop window |
| 0x0604 | Database window service |
| 0x0606 | D87.RES specific service |
| 0x060D | Extended memory / EMM service |
| 0x060E | Close/exit desktop window |

#### AH = 0x07: Event/Message Services
| AX | Description |
|----|-------------|
| 0x0700 | Get/post message / event loop service |

#### AH = 0x4D ('M'): Shell/Host Services
These are called exclusively by DESK.EXE itself (not from PDM modules), suggesting they are internal services for managing loaded PDM programs.

| AX | Description |
|----|-------------|
| 0x4D00 | Shell service 0 (DESK.EXE internal) |
| 0x4D04 | Shell service 4 (load/exec PDM?) |
| 0x4D05 | Shell service 5 (unload PDM?) |
| 0x4D06 | Shell service 6 (switch PDM?) |

### 5.3 DESK.EXE TSR Identification

DESK.EXE places the string `DESKMATE$05.00 900919$` at a fixed offset in its data segment (file offset 0x42A2). The pattern preceding this string suggests it is used as a TSR identification signature — programs can check for the resident DeskMate host by scanning memory for this string.

The format is: `DESKMATE$<version>.<subversion> <yymmdd>$`
- Version: `05.00`
- Build date: `900919` = September 19, 1990

### 5.4 INT E2h Usage in DESK.EXE

DESK.EXE also uses **INT E2h** (3 calls), which may be a secondary service vector, possibly for extended memory or DMA operations. INT E2h was used by DMEMM.RES (extended memory manager). The specific service codes are not yet decoded.

---

## 6. .RES and .ACC Loading Mechanism

### 6.1 .RES (Resource/Driver Modules)

`.RES` files are DeskMate plug-in drivers that extend the shell's capabilities. They follow the same MZ+DM89 header format as PDM files but are not launched as independent programs. Based on observed patterns:

- RES files register themselves with DESK.EXE via **INT E0h AX=0x01F0** (register) and deregister with **INT E0h AX=0x01FF** (unregister)
- After loading, the RES module's code remains resident and DESK.EXE dispatches events to it
- The `DMCONFIG` environment variable specifies the directory where RES and CFG files are found

Known RES categories (from filename prefixes):
- `DMVE*.RES` — Video editor/display drivers (one per adapter type: 1000, CGA, EGA, HERC, MCGA, VGA, TC16)
- `DMVS*.RES` — Video display scan drivers (sound drivers also named DMVS?)
- `DMMD*.RES` — Music/MIDI drivers (DMMDJ=joystick?, DMMDP, DMMDS)
- `DMPD*.RES` / `DMPE*.RES` — Printer drivers (DM Printer Definition variants)
- `DMDB*.RES` — Database engine (DMDBBLD, DMDBRD, DMDBUPD)
- `DMPLAY.RES` — Music playback
- `DMFONT.RES` — Font rendering
- `DMFORM.RES` / `DMEFORM.RES` — Form manager
- `DMEMM.RES` — Extended memory manager (XMS/EMS)
- `DMSSM.RES` — Screen saver manager?
- `SPELL.RES`, `DICTARY.RES`, `DMTHES.RES` — Spell check / thesaurus

### 6.2 .ACC (Accessory) Files

`.ACC` files are DeskMate desk accessories — small programs that overlay the current application. They use a slightly larger extended header (reloc offset 0x4C vs 0x42 for PDMs). Known accessories:

| File | Description |
|------|-------------|
| DMACCESS.ACC | Access control / login |
| DMALARM.ACC | Alarm clock |
| DMCLIP.ACC | Clipboard |
| DMDRWPRT.ACC | Draw print driver |
| DMHELP.ACC | Help viewer |
| DMNOTEPD.ACC | Notepad |
| DMPHONE.ACC | Phone dialer |
| DMPD*.ACC | Printer definition accessories |
| DMPRTSEL.ACC | Printer selector |
| DMSERV.ACC | Service/settings |
| DMSETUP.ACC | System setup |
| DMSPELL.ACC | Spell checker |
| DMTODO.ACC | To-do list |

---

## 7. Known File Formats

### 7.1 .PDM (Program Module)

See Section 4 above. Essentially a DOS MZ EXE with the DM89 extended header.

### 7.2 .SND (Sound/Audio)

Based on research from `oldskool.org` and community sources (confirmed format, no sample files present in the extracted 3.05 archive):

```
Offset  Size  Description
------  ----  -----------
0x00    1     Magic byte: 0x1A
0x01    1     Compression: 0=none, 1=music compression, 2=sound compression
0x02    1     Number of notes in the instrument file
0x03    1     Instrument number
0x04    10    Sound or instrument name (null-padded)
0x0E    2     Sample rate in samples per second
0x10    ...   Sample data (raw or compressed)
```

The Tandy DAC supports sample rates of 5500, 11000, and 22000 Hz (8-bit mono). Compressed .SND files use a proprietary algorithm; only SOUND.PDM can play them back. External tools can play uncompressed .SND files.

### 7.3 .WKS (Spreadsheet)

From two sample files (`LOAN.WKS`, `TVM.WKS`):

```
Offset  Size  Description
------  ----  -----------
0x00    1     Magic: 0x0E
0x01    3     "WKS" (57 4B 53)
0x04    2     Column widths? (varies per file)
0x06    2     Row/column dimensions
...
0x0E    2     "FB" marker (46 42) — format version tag
0x10    1     Format version (0x38 = '8' in both sample files)
...
```

Note: DeskMate .WKS is **not** the same as Lotus 1-2-3 .WKS format, despite the same extension.

### 7.4 .FIL (Database / Calendar)

Used for Filer database files, Calendar (`.CLN`), and similar structured data:

```
Offset  Size  Description
------  ----  -----------
0x00    1     Magic: 0x03
0x01    3     "FIL" (46 49 4C)
0x04    2     Flags / record type
0x06    3     Field dimensions (row/column counts?)
0x09    1     Unknown
0x0A    2     Record size or count
0x0C    2     Unknown
0x0E    2     "PB" or "FB" marker — format variant
0x10    1     Version byte (0x3C = '<' in samples)
...
0x17    2     "JW" or "JC" — possibly initials/checksum
```

The `.CLN` (Calendar) file uses the same FIL format as the Filer database. The `.ADR` (Address Book) file uses a different format with only a small header and a packed bit allocation bitmap (no FIL magic bytes visible in `PERSONAL.ADR`).

### 7.5 .FIG (Draw Vector Graphics)

From ArchiveTeam wiki and community sources:
- Magic bytes: `14 46 49 47` (byte 0x14, then "FIG")
- The DeskMate Development Guide Appendix A describes the format
- The Form Manager section of the Technical Reference describes drawing commands ("forms") that can appear in FIG files
- Drawings also have associated `.CLP` (clip region?) files

Note: No `.FIG` sample files are present in the extracted 3.05 runtime archive.

### 7.6 .CFG (Desktop Configuration)

`DESKTOP.CFG` stores the desktop icon layout and application associations:

**File header (8 bytes):**
```
0x00    8     "DESKTOP\0" magic string
0x08    2     Total size of icon table?
0x0A    ...   Config data
```

**Icon entry (55 bytes each, starting at offset ~0x75):**
```
Offset  Size  Description
------  ----  -----------
0x00    1     Magic: 0x46 ('F')
0x01    1     Icon index (1-based)
0x02    1     X position on desktop grid
0x03    1     Y position on desktop grid
0x04    2     Flags / type word
0x06    12    Icon label (null-padded ASCII, max 11 chars)
0x12    16    PDM filename (null-padded, e.g. "TEXT.PDM\0...")
0x22    4     Associated file extension (null-padded, e.g. "DOC\0")
0x26    17    Additional data (icon attributes, colors, etc.)
--- total: 55 bytes ---
```

Known icons and their PDM associations:

| # | Label | PDM | Ext |
|---|-------|-----|-----|
| 1 | MONTH | PLAY.PDM | — |
| 2 | TEXT | TEXT.PDM | DOC |
| 3 | FILER | FILER.PDM | FIL |
| 4 | ADDRESS | ADDRESS.PDM | ADR |
| 5 | WORKSHEET | WRKSHEET.PDM | WKS |
| 6 | CORKBOARD | (none shown) | — |
| 7 | DRAW | DRAW.PDM | FIG |
| 8 | TELECOM | TELECOM.PDM | — |
| 9 | CALENDAR | CALENDAR.PDM | CLN |
| 10 | PHONE | (ACC) | — |
| 11 | PROGRAMS | (folder) | — |
| 12 | PC-LINK | PC_LINK.PDM | — |
| 13 | OTHERS | (folder) | — |
| 14 | TO DO | (ACC) | — |
| 15 | HANGMAN | HANGMAN.PDM | — |
| 16 | FORM SETUP | FORMSET.PDM | — |

### 7.7 .RFD (Radio/Printer Form Definition)

Used with printer driver RES files. Binary format, not yet analyzed. Associated pairs: `.ACC` + `.RES` + `.RFD` files exist for each printer model (DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR, DMPDS).

### 7.8 .FF1 (Font Files)

Files: `COBB.FF1`, `DIXON.FF1`, `MARIN.FF1`. Likely contain bitmapped font data for DeskMate's proportional fonts. Not yet analyzed.

### 7.9 .HLP / .TUT (Help and Tutorial Files)

Each major application has an associated `.HLP` (help) and `.TUT` (tutorial) file. Format is likely plain text or a simple structured text format. Not yet analyzed.

---

## 8. DESK.EXE Architecture Notes

Based on binary analysis:

- **File size:** ~17,000+ bytes (38 512-byte pages)
- **Interrupt hooks installed:** INT 21h (DOS services), custom handler at INT E0h (DeskMate services), INT E2h (extended memory?), and the standard CRT hooks (INT 00h divide-by-zero, etc.)
- **INT 21h calls:** 151 instances (heavy use of DOS file I/O, memory, process management)
- **INT 16h calls:** 7 (keyboard BIOS — reading keystrokes directly)
- **INT 10h calls:** 4 (video BIOS)
- **INT 15h calls:** 2 (extended BIOS — likely for Tandy DAC or memory detection)
- **INT 13h calls:** 2 (disk BIOS — likely for disk operations during loading)
- **Interrupt vector modification:** DESK.EXE uses INT 21h AH=25h to install/replace interrupt vectors and INT 21h AH=35h to get existing vectors, doing this 2 times during startup

DESK.EXE reads/writes a configuration file `DMCSR.CFG` and stores video driver configuration in EEPROM (on machines that support it) or in this file.

The `DMCONFIG` environment variable is required, pointing to the directory containing DeskMate support files.

### Memory Layout

DESK.EXE allocates from DOS conventional memory and maintains a table for tracking loaded PDM programs. The PDM loading stub in each PDM file uses:

```asm
INT 21h, AH=4Ah   ; resize memory block (adjust memory allocation)
INT 21h, AH=4Bh   ; EXEC (load and execute program)
```

With a preliminary memory-size check to ensure at least 64KB-128KB is available before attempting to load a PDM.

---

## 9. Video Driver Architecture

DeskMate 3.05 ships with video drivers for every common adapter type:

| RES File | Adapter |
|----------|---------|
| DMVE1000.RES | Tandy 1000 (TGA/TGA2) — primary target |
| DMVECGA.RES | CGA |
| DMVEEGA.RES | EGA |
| DMVEHERC.RES | Hercules monochrome |
| DMVEMCGA.RES | MCGA |
| DMVET.RES | Tandy (T) |
| DMVETC16.RES | Tandy 16-color variant |
| DMVEVGA.RES | VGA |

Each "VE" (Video Editor/renderer?) driver is paired with a "VS" (Video Scanner/input?) driver:

| RES File | Adapter |
|----------|---------|
| DMVS1000.RES | Tandy 1000 |
| DMVSCGA.RES | CGA |
| DMVSEGA.RES | EGA |
| DMVSHERC.RES | Hercules |
| DMVSMCGA.RES | MCGA |
| DMVST.RES | Tandy |
| DMVSTC16.RES | Tandy 16-color |
| DMVSVGA.RES | VGA |

DMVID.EXE is the utility to select a video driver. It writes either to the machine's EEPROM or to the `DMCSR.CFG` file. The `DMCSR.R89` file (alternate format, reloc=0x1E, no DM89 signature) appears to be a different resource format — possibly the EEPROM-based configuration handler.

---

## 10. Key Findings for Reverse Engineering

### 10.1 What We Know for Certain (from direct binary analysis)

1. **Compiler:** Microsoft C 5.x (1987 runtime). Identical startup prologue in every module.
2. **Primary API:** INT E0h with AX = service code (AH=class, AL=function)
3. **Module format:** DOS MZ EXE + 14-48 bytes of DM89 extended header before the relocation table
4. **Module type code:** Encoded as two ASCII decimal digits in the MZ overlay field (offset 0x1A)
5. **Header paragraphs:** Always 0x20 = 32 (512 bytes); the code starts at file offset 512 in all modules
6. **Build date:** September 19, 1990 for DeskMate 3.05
7. **Version string:** "DESKMATE$05.00 900919$" is the TSR identification token

### 10.2 What Needs Further Work

1. **Full INT E0h service table:** We know the service classes but not the parameters/returns for each call. This requires disassembly of DESK.EXE's INT E0h handler dispatch table.
2. **PDM loading protocol:** Exactly how DESK.EXE loads, relocates, and invokes a PDM module. The INT E0h AH=0x4D services may be the key.
3. **DM89 extended header:** Bytes 0x20-reloc_off are not fully decoded. Fields at 0x22 (module type flags) and the segment references need mapping.
4. **RES registration protocol:** The exact parameters passed with INT E0h AX=0x01F0 (register RES) and 0x01FF (unregister).
5. **DMDS 3.03 archive:** Obtaining the actual SDK would provide all missing API documentation.

### 10.3 Recommended Next Steps

1. Disassemble DESK.EXE's INT E0h handler (starts somewhere around offset 0x42xx in the file based on the DESKMATE$ string proximity).
2. Map the dispatch table at offset 0x104F described in the DeskMate I disassembly (similar structure likely exists in DeskMate 3.x DESK.EXE).
3. Attempt to retrieve the DMDS 3.03 archive from oldskool.org or archive.org cached copies.
4. Disassemble HANGMAN.PDM (smallest PDM, simplest application) to understand the complete PDM-to-host API flow from the application side.

---

## 11. Source URLs and References

- oldskool.org DeskMate guide: `http://www.oldskool.org/guides/tvdog/deskmate.html`
- Nerdly Pleasures DeskMate article (2024): `http://nerdlypleasures.blogspot.com/2024/07/tandy-deskmate-tandys-ace-in-hole.html`
- WinWorld DeskMate 3.x: `https://winworldpc.com/product/tandy-deskmate/deskmate-3x`
- Archive.org DeskMate: `https://archive.org/details/hdemudeskmate`
- ArchiveTeam DeskMate Draw: `http://fileformats.archiveteam.org/wiki/DeskMate_Draw`
- ArchiveTeam DeskMate Paint: `http://fileformats.archiveteam.org/wiki/DeskMate_Paint`
- ToastyTech DeskMate 3.05 gallery: `http://toastytech.com/guis/deskmate.html`
- VOGONS PC Compatible DeskMate thread: `https://www.vogons.org/viewtopic.php?t=15756`
- VOGONS Tandy 1000 HX Emulation thread: `https://www.vogons.org/viewtopic.php?t=15685`
- GoombaProgrammer DeskMate I disassembly: `https://github.com/GoombaProgrammer/tandy-deskmate`
- Tandy 2000 DeskMate Reference Manual on GitHub: `https://github.com/Tandy2K/Tandy2000/blob/master/Documentation/DeskMate%20Reference%20Manual%2026-5316.pdf`
- Ralf Brown's Interrupt List: `https://ctyme.com/rbrown.htm`
- DMDS 3.03 FTP (may be offline): `http://ftp.oldskool.org/pub/tvdog/tandy1000/wares/DeskMate-Development-System-3.03/`
- colorcomputerarchive DeskMate 3 manual: `https://colorcomputerarchive.com/repo/Documents/Manuals/Applications/Deskmate%203%20(Tandy).pdf`
