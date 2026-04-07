# DeskMate 3.05 .RES and .ACC File Format Analysis

## Summary

Both .RES (Resource/Driver) and .ACC (Accessory) files are **standard DOS MZ executables**
with a DeskMate-specific extension header embedded at offset 0x1C in the MZ header.
They share the same format with .PDM (Program/Application) files. The extension is
identified by the 4-byte magic signature **"DM89"** at offset 0x1C.

All three file types (.RES, .ACC, .PDM) contain relocatable x86 real-mode code compiled
with **Microsoft C 5.x** (copyright string: "MS Run-Time Library - Copyright (c) 1987,
Microsoft Corp"). They are not standalone executables -- they are loaded and linked at
runtime by the DESK.EXE host environment.

---

## File Inventory

### .RES Files (52 files)

| File | Size | Category | Description |
|------|------|----------|-------------|
| ALARM.RES | 11,427 | Utility | Alarm clock handler |
| ALRMINIT.RES | 9,985 | Utility | Alarm initialization (no DM89 header) |
| AUTOLOAD.RES | 4,244 | System | Auto-load module |
| D87.RES | 818 | System | 8087 FPU support (no DM89 header) |
| DICTARY.RES | 1,586 | Utility | Dictionary module |
| DMDBBLD.RES | 11,858 | Database | Database builder |
| DMDBRD.RES | 21,955 | Database | Database reader |
| DMDBUPD.RES | 13,740 | Database | Database updater |
| DMEFORM.RES | 11,889 | Forms | Electronic forms |
| DMEMM.RES | 2,582 | System | Expanded Memory Manager interface |
| DMFONT.RES | 39,633 | Video | Font data and rendering |
| DMFORM.RES | 9,853 | Forms | Form module |
| DMMDJ.RES | 1,540 | Music | Music driver (Joystick?) |
| DMMDP.RES | 1,493 | Music | Music driver (PC Speaker) |
| DMMDS.RES | 2,113 | Music | Music driver (SN76496 sound chip) |
| DMPD1.RES | 17,692 | Printer | Printer driver #1 |
| DMPD2.RES | 17,692 | Printer | Printer driver #2 |
| DMPDASCI.RES | 6,848 | Printer | ASCII/text printer driver |
| DMPDIBMM.RES | 18,886 | Printer | IBM graphics printer driver |
| DMPDLASR.RES | 19,228 | Printer | Laser printer driver |
| DMPDS.RES | 29,455 | Printer | Printer driver (serial?) |
| DMPE1.RES | 5,138 | Printer | Print engine #1 |
| DMPE2.RES | 5,138 | Printer | Print engine #2 |
| DMPEIBMM.RES | 3,090 | Printer | Print engine (IBM) |
| DMPELASR.RES | 5,330 | Printer | Print engine (laser) |
| DMPES.RES | 3,186 | Printer | Print engine (serial?) |
| DMPLAY.RES | 42,188 | Sound | Sound playback / DAC driver |
| DMSSM.RES | 6,032 | Sound | Sound/sample manager |
| DMTHES.RES | 1,704 | Utility | Thesaurus module |
| DMUNPACK.RES | 3,172 | Utility | Data decompression (no DM89 header) |
| DMVE1000.RES | 5,314 | Video | Video event handler (Tandy 1000) |
| DMVECGA.RES | 5,378 | Video | Video event handler (CGA) |
| DMVEEGA.RES | 5,330 | Video | Video event handler (EGA) |
| DMVEHERC.RES | 5,378 | Video | Video event handler (Hercules) |
| DMVEMCGA.RES | 5,250 | Video | Video event handler (MCGA) |
| DMVET.RES | 5,314 | Video | Video event handler (Tandy TGA) |
| DMVETC16.RES | 5,474 | Video | Video event handler (Tandy TGA 16-color) |
| DMVEVGA.RES | 5,426 | Video | Video event handler (VGA) |
| DMVS1000.RES | 21,922 | Video | Video services (Tandy 1000) |
| DMVSCGA.RES | 23,746 | Video | Video services (CGA) |
| DMVSEGA.RES | 24,082 | Video | Video services (EGA) |
| DMVSHERC.RES | 25,682 | Video | Video services (Hercules) |
| DMVSMCGA.RES | 22,754 | Video | Video services (MCGA) |
| DMVST.RES | 24,322 | Video | Video services (Tandy TGA) |
| DMVSTC16.RES | 23,138 | Video | Video services (Tandy TGA 16-color) |
| DMVSVGA.RES | 23,922 | Video | Video services (VGA) |
| PRGUF.RES | 7,064 | System | Program User Function library |
| PROTOCOL.RES | 11,522 | Telecom | Communication protocol handler |
| SPELL.RES | 8,866 | Utility | Spell checker engine |
| SPL.RES | 27,552 | Utility | Spell checker (larger module) |
| TRANSLAT.RES | 1,586 | Utility | Character translation |
| TUTKBD.RES | 1,931 | Data | Keyboard tutorial data (NOT an MZ executable) |

### .ACC Files (18 files)

| File | Size | Description |
|------|------|-------------|
| DMACCESS.ACC | 7,487 | Accessory launcher/framework |
| DMALARM.ACC | 14,909 | Alarm clock accessory |
| DMCLIP.ACC | 10,507 | Clipboard accessory |
| DMDRWPRT.ACC | 1,638 | Draw print accessory |
| DMHELP.ACC | 31,836 | Help system |
| DMNOTEPD.ACC | 14,295 | Notepad accessory |
| DMPD1.ACC | 6,713 | Printer driver accessory #1 |
| DMPD2.ACC | 6,685 | Printer driver accessory #2 |
| DMPDASCI.ACC | 8,035 | ASCII printer accessory |
| DMPDIBMM.ACC | 9,251 | IBM printer accessory |
| DMPDLASR.ACC | 6,969 | Laser printer accessory |
| DMPDS.ACC | 9,559 | Serial printer accessory |
| DMPHONE.ACC | 20,585 | Phone dialer accessory |
| DMPRTSEL.ACC | 13,643 | Printer selection accessory |
| DMSERV.ACC | 24,187 | Services accessory |
| DMSETUP.ACC | 28,695 | Setup/configuration accessory |
| DMSPELL.ACC | 7,510 | Spell checker accessory |
| DMTODO.ACC | 6,086 | To-do list accessory |

---

## Format Structure

### Overview

```
+------------------+  0x0000
| Standard MZ      |  28 bytes (0x00 - 0x1B)
| Header           |
+------------------+  0x001C
| DM89 Extension   |  Variable length (0x1C - varies)
| Header           |  Typically 0x1C - 0x41 (38 bytes minimum)
+------------------+  0x003C or later
| Import Name      |  0 to N entries, each 10 bytes
| Table (optional) |  (only present if reloc_off > 0x42)
+------------------+  reloc_off
| MZ Relocation    |  reloc_count * 4 bytes
| Table            |
+------------------+
| Zero padding     |  To fill 512-byte header
+------------------+  0x0200 (512)
| Code + Data      |  Actual program content
| Segments         |
+------------------+
```

### Standard MZ Header (0x00 - 0x1B)

Standard DOS MZ .EXE header fields. All files have a 512-byte (32 paragraph) header
(`header_paragraphs` at offset 0x08 = 0x0020 = 32).

| Offset | Size | Field | Notes |
|--------|------|-------|-------|
| 0x00 | 2 | Magic | Always "MZ" (0x4D5A) |
| 0x02 | 2 | Last page bytes | Bytes on last page |
| 0x04 | 2 | Pages | Total 512-byte pages |
| 0x06 | 2 | Relocation count | Number of relocation entries |
| 0x08 | 2 | Header paragraphs | Always 0x0020 (512 bytes) |
| 0x0A | 2 | Min extra paragraphs | Minimum BSS allocation |
| 0x0C | 2 | Max extra paragraphs | Maximum allocation |
| 0x0E | 2 | Initial SS | Stack segment (relative) |
| 0x10 | 2 | Initial SP | Stack pointer |
| 0x12 | 2 | Checksum | Often non-zero |
| 0x14 | 2 | Initial IP | Entry instruction pointer |
| 0x16 | 2 | Initial CS | Code segment (relative) |
| 0x18 | 2 | Relocation offset | Offset to relocation table |
| 0x1A | 2 | Overlay number | Non-zero; used by DeskMate loader |

**Key observation:** The `overlay number` field (0x1A) is repurposed; in standard MZ
executables this is 0 for the main program. Here it carries DeskMate-specific metadata.

### DM89 Extension Header (0x1C - 0x3B)

This 32-byte block extends the MZ header with DeskMate-specific information. It is
present in all .RES, .ACC, and .PDM files except a few legacy modules (ALRMINIT.RES,
D87.RES, DMUNPACK.RES) that use the standard reloc_off=0x1E with no extension.

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x1C | 4 | Magic | "DM89" (0x44 0x4D 0x38 0x39) |
| 0x20 | 1 | DM version | 0x3E ('>') = DM 3.x; 0x3C ('<') = older format |
| 0x21 | 1 | Module subtype | Varies; non-zero for utility/driver RES files |
| 0x22 | 1 | Has imports flag | 0x01 if module has import table; 0x00 if not |
| 0x23 | 1 | DM version echo | Mirrors byte 0x20 when imports present; 0x00 otherwise |
| 0x24 | 2 | Reserved | Always 0x0000 |
| 0x26 | 2 | Primary code seg | Code segment value (matches MZ CS for most files) |
| 0x28 | 2 | Init entry offset | Secondary entry offset (matches MZ IP for many files) |
| 0x2A | 2 | Primary code seg 2 | Always equals field at 0x26 |
| 0x2C | 20 | Reserved / flags | Mostly zeros; some files have additional data |

**Notes on field 0x21 (module subtype):**
- 0x00 = Standard application/accessory module
- 0x0F = CGA/Hercules video driver
- 0x09 = Tandy 16-color video driver
- 0x0C = VGA video driver
- 0x12 = EGA/laser print engine video driver
- 0x13 = Tandy/1000 video driver
- 0x17 = MCGA/form video driver
- 0x18, 0x19 = Printer/database module subtype
- 0x1B = Dictionary/translation
- 0x1E = EMM/print engine/music driver

### Import Name Table (0x42 - reloc_off)

When `reloc_off > 0x42`, the space between 0x42 and reloc_off contains an import
name table. Each entry is **10 bytes**: a null-terminated ASCII name padded with zeros
to exactly 10 bytes.

The number of imports = `(reloc_off - 0x42) / 10`.

| reloc_off | Import slots | Typical usage |
|-----------|-------------|---------------|
| 0x003E | 0 | RES files with no imports |
| 0x0042 | 0 | RES/PDM files with no imports |
| 0x004C | 1 | ACC files importing "dmguf" |
| 0x0056 | 2 | PDM files importing 2 libraries |
| 0x0060 | 3 | PDM files importing 3 libraries |

**Common import names observed:**

| Import Name | Provider | Description |
|-------------|----------|-------------|
| dmguf / DMGUF | DESK.EXE | DeskMate GUI Framework -- core UI API |
| PRGUF | PRGUF.RES | Program User Function library |
| dmdb | DMDB*.RES | Database engine |
| dmform | DMFORM.RES | Forms engine |
| dmplay | DMPLAY.RES | Sound playback engine |
| unpack | DMUNPACK.RES | Data decompression |

**Import table by file:**

| File | Imports |
|------|---------|
| Most .ACC files | dmguf |
| DMPRTSEL.ACC | PRGUF |
| ADDRESS.PDM | dmguf, dmdb |
| FILER.PDM | dmguf, dmform, dmdb |
| FORMSET.PDM | dmguf, dmform, dmdb |
| PLAY.PDM | dmguf, dmplay, unpack |

### Module Descriptor in Code Segment

Some RES files (particularly video drivers) contain a **module descriptor structure**
at the beginning of their code segment (CS:0000). This structure describes the module
to the DeskMate loader and declares runtime dependencies.

**Video Event Handler (DMVExxx.RES) module descriptor format:**

```
CS:0000  db "DMVECGA",0       ; Module name (null-terminated)
CS:0008  dw offset_1          ; Entry point table offset A
CS:000A  dw segment_1         ; Entry point table segment A
CS:000C  dw offset_2          ; Entry point table offset B
CS:000E  dw segment_2         ; Entry point table segment B
CS:0010  (zeros)              ; Reserved / padding
CS:0022  db 03h               ; Dependency count
CS:0023  dw ???               ; Unknown field
CS:0025  db CDh,ABh,BAh,DCh   ; Magic sentinel (0xCDABBADC)
CS:0029  db "DMFONT",0,0      ; Required module #1
CS:0031  db CDh,ABh,BAh,DCh   ; Magic sentinel
CS:0035  db "DMVSCGA",0,0,0,0 ; Required module #2
...
CS:00A1  (entry point code)   ; Actual code begins at CS:IP
```

The magic sentinel **0xCDABBADC** separates dependency entries. Each dependency is
a null-terminated module name identifying a .RES file that must be loaded before this
module can operate.

**Observed dependency chains:**
- DMVECGA.RES requires: DMFONT.RES, DMVSCGA.RES
- DMVEEGA.RES requires: DMFONT.RES, DMVSEGA.RES
- DMVEVGA.RES requires: DMFONT.RES, DMVSVGA.RES
- DMVET.RES requires: DMFONT.RES, DMVST.RES

This confirms that the video subsystem is split into:
- **DMVExxx** -- Video Event handlers (high-level, ~5KB each)
- **DMVSxxx** -- Video Services (low-level drawing, ~22-25KB each)
- **DMFONT** -- Font rendering (shared by all video drivers, 39KB)

---

## Key Differences Between RES, ACC, and PDM

All three file types share the same MZ+DM89 format. The differences are functional,
not structural:

| Aspect | .RES | .ACC | .PDM |
|--------|------|------|------|
| Purpose | Loadable driver/library | Desk accessory | Full application |
| Has imports | Sometimes | Usually (dmguf) | Usually (dmguf + others) |
| Module descriptor | Often (at CS:0) | Rarely | Rarely |
| Dependencies | Via module descriptor | Via import table | Via import table |
| Microsoft C runtime | Present in many | Present in all | Present in all |
| Typical size | 1-42 KB | 2-32 KB | 5-70 KB |
| Loaded by | DESK.EXE on demand | DESK.EXE accessory mgr | DESK.EXE app launcher |

### RES files: Two structural subtypes

1. **With DM89 header** (majority): Standard DM89 format, loaded through the
   DeskMate module loader. May have dependencies declared in the code-segment
   module descriptor.

2. **Without DM89 header** (ALRMINIT.RES, D87.RES, DMUNPACK.RES): Plain MZ
   executables with reloc_off=0x001E. These appear to be older-format modules
   or auxiliary code loaded through a different mechanism.

### Special case: TUTKBD.RES

TUTKBD.RES is **not an MZ executable**. Its first byte is 0x01, followed by the
ASCII string "TUTKBD.RES". This is a pure data file (keyboard tutorial data)
misidentified by its extension; it has no executable code.

---

## Compiler Identification

**Compiler:** Microsoft C 5.x (1987)

**Evidence:**
- Copyright string: `MS Run-Time Library - Copyright (c) 1987, Microsoft Corp`
- Present in all ACC files, all PDM files, and several RES files
- Entry point code pattern in ACC files matches MSC 5.x startup:
  ```
  MOV AH, 30h      ; B4 30
  INT 21h           ; CD 21  -- Get DOS version
  CMP AL, 2         ; 3C 02
  JAE continue      ; 73 02
  INT 20h           ; CD 20  -- Exit if DOS < 2.0
  ```

**Memory model:** Small or Medium model (near code calls observed, far data pointers
in some modules). The video drivers use inter-segment far calls.

---

## DeskMate Module Loading Architecture

Based on the header analysis, the DeskMate module loading system works as follows:

1. **DESK.EXE** is the host environment (standard DOS .EXE)
2. It implements the **DMGUF** (DeskMate GUI Framework) API
3. When loading a .PDM or .ACC:
   - Reads the MZ header and DM89 extension
   - Parses the import name table to identify required libraries
   - Loads any required .RES modules (recursively resolving dependencies)
   - Performs MZ relocations
   - Links import references to loaded module entry points
   - Transfers control to CS:IP
4. .RES files that declare dependencies (via the CS:0 module descriptor with
   CDABBADC sentinels) trigger loading of their own prerequisites
5. The import name "dmguf" / "DMGUF" refers to DESK.EXE's built-in GUI API,
   while other import names (dmdb, dmform, dmplay, unpack, PRGUF) refer to
   .RES library modules that must be loaded first

This architecture is essentially a **simple dynamic linking system** for DOS,
predating Windows DLLs and OS/2 NE executables. The DM89 header extends the MZ
format to support runtime module dependencies without requiring a new executable
format.

---

## Appendix: Header Field Correlation Data

The following table shows the relationship between DM89 extension fields and
standard MZ header fields for all files with DM89 headers:

- **w26 == CS**: True for ~80% of files (all ACC, most RES, all PDM)
- **w28 == IP**: True for ~50% of files (all ACC, some RES, some PDM)
- **w2A == w26**: True for 100% of files (always redundant)

Files where w26 != CS tend to be printer driver RES files (DMPD*.RES) and
a few special-purpose modules (DMALARM.ACC, DMHELP.ACC, DMDRWPRT.ACC).
This suggests the w26/w28 fields may point to a different entry point
used by the DeskMate loader (e.g., an initialization entry vs. the
standard MZ entry point).

---

## Raw Hex Header Samples

### DMVECGA.RES (Video Event -- CGA)
```
00000000: 4d5a 0201 0b00 0500 2000 0000 0100 3001  MZ...... .....0.
00000010: 0200 0000 a100 1701 4200 1101 444d 3839  ........B...DM89
00000020: 3e0f 013e 0000 1701 0000 1701 0600 1601  >..>............
```

### DMACCESS.ACC (Accessory Launcher)
```
00000000: 4d5a 3f01 0f00 0d00 2000 fa00 fa00 ba01  MZ?..... .......
00000010: a00f 0142 0c00 6a01 4c00 0a00 444d 3839  ...B..j.L...DM89
00000020: 3e00 013e 0000 6a01 0c00 6a01 0000 0000  >..>..j...j.....
00000030: 0000 0000 0000 0000 0000 0000 0101 0c00  ................
00000040: 6a01 646d 6775 6600 0000 0000             j.dmguf.....
```

### DESKTOP.PDM (Main Desktop Application)
```
00000000: 4d5a e901 8e00 0d00 2000 7806 b70c 5714  MZ...... .x...W.
00000010: 001c 0000 0e00 4c0e 4200 3638 444d 3839  ......L.B.68DM89
00000020: 3e00 013e 0000 4c0e 0e00 4c0e 0000 0000  >..>..L...L.....
00000030: 0000 0000 0000 0000 0000 0000 0101 0e00  ................
00000040: 4c0e                                      L.
```

### FILER.PDM (Database Application -- 3 imports)
```
Import table at 0x42:
  [0] dmguf    (DeskMate GUI Framework)
  [1] dmform   (Forms engine)
  [2] dmdb     (Database engine)
Relocation table starts at 0x0060
```
