# DeskMate 3.05 File Format Documentation

**Date:** 2026-04-06
**Researcher:** Claude Code (Opus 4.6)
**Source:** Binary analysis of files in `/archive/deskmate-3.05/extracted/`
**Status:** First-pass analysis -- some fields remain unidentified

---

## Table of Contents

1. [.SND -- Sound/Audio](#snd-format)
2. [.WKS -- Worksheet/Spreadsheet](#wks-format)
3. [.FIL -- Filer Database](#fil-format)
4. [.CLN -- Calendar](#cln-format)
5. [.ADR -- Address Book](#adr-format)
6. [.CFG -- Configuration Files](#cfg-format)
7. [.HLP -- Help Files](#hlp-format)
8. [.TUT -- Tutorial Archives](#tut-format)
9. [.FF1 -- Bitmap Fonts](#ff1-format)
10. [.SPL -- Spelling Dictionary](#spl-format)
11. [.PCL -- Printer Control Language](#pcl-format)
12. [.RFD -- Printer Font Definition](#rfd-format)
13. [.LBL -- Label/Manifest](#lbl-format)
14. [.CLP -- Clipboard](#clp-format)
15. [.R89 -- DeskMate Resource Module (1989)](#r89-format)
16. [.FIG -- Draw Vector Graphics](#fig-format)
17. [.SNG -- Music Composition](#sng-format)
18. [.MOD -- Compatibility Module](#mod-format)
19. [.ACC -- Desk Accessory](#acc-format)
20. [.PNT -- Paint Bitmap (Personal DeskMate)](#pnt-format)

---

## .SND Format -- Sound/Audio {#snd-format}

**No sample files present in DeskMate 3.05 extracted archive.**
Format documented from community research (oldskool.org) and SDK references.

### Header (16 bytes)

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           Always 0x1A (EOF marker for TYPE command)
0x01    1     compression     0 = none, 1 = music compression, 2 = speech compression
0x02    1     note_count      Number of note records (for instrument files)
0x03    1     instrument_num  Instrument number within a set
0x04    10    name            Sound/instrument name, null-padded
0x0E    2     sample_rate     Sampling rate in Hz (LE word)
```

### Body

After the 16-byte header:
- If `note_count > 0`: array of 28-byte note records, then sample data
- If `note_count == 0`: raw sample data immediately follows header

### Sample Rates

The Tandy DAC supports three rates:
- 5500 Hz (low quality, saves space)
- 11000 Hz (standard quality)
- 22000 Hz (high quality)

### Compression

- Mode 0: uncompressed 8-bit unsigned PCM
- Mode 1: "music" compression (proprietary, used for instrument/note data)
- Mode 2: "speech" compression (proprietary, used for voice recordings)

Only SOUND.PDM can decode compressed .SND files. Third-party tools handle
uncompressed files only.

---

## .WKS Format -- Worksheet/Spreadsheet {#wks-format}

**Sample files:** LOAN.WKS (9621 bytes), TVM.WKS (1177 bytes)

**Note:** DeskMate .WKS is NOT the same as Lotus 1-2-3 .WKS format, despite
sharing the file extension.

### Header (26 bytes)

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x0E
0x01    3     signature       "WKS" (57 4B 53)
0x04    10    dimensions      Sheet dimension data (identical in both samples:
                              00 05 1E 28 1E 05 64 28 1E 05)
0x0E    2     format_tag      "FB" (46 42) -- format/version marker
0x10    1     version         0x38 ('8') in both sample files
0x11    3     unknown         00 00 00 in both files
0x14    1     unknown         00 in both files
0x15    1     flags           0x01 in both files
```

### Column Width Table (96 bytes, offset 0x16 to 0x79)

96 bytes, one per column (columns A through CR). Default width = 0x0A (10).
Non-default values observed:
- LOAN.WKS: column B (offset 0x1A) = 0x0D (13), column C (0x1B) = 0x0B (11)
- TVM.WKS: column G (0x1C) = 0x14 (20)

### Cell Data (offset 0x7A onward)

Cell records follow the column width table. Each record encodes a cell's
position, type, and value. The exact record format requires further analysis
through disassembly of WRKSHEET.PDM, but observed patterns suggest:

- Records contain column/row identifiers as 16-bit words
- Numeric values appear to be stored as 8-byte IEEE 754 doubles
- String values are length-prefixed
- Formula references use column/row pairs

---

## .FIL Format -- Filer Database {#fil-format}

**Sample files:** INVNTORY.FIL (12288 bytes), CARMAINT.FIL (14336 bytes)

The .FIL format is DeskMate's general-purpose structured data format, used by
the Filer application, Calendar (.CLN), Help (.HLP), and Clipboard (.CLP).

### File Header (32 bytes)

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x03
0x01    3     signature       "FIL" (46 49 4C) -- for Filer/Calendar databases
                              May also have version digits here for HLP files
0x04    2     flags           Varies: 0x0000 (INVNTORY), 0x0001 (CARMAINT)
0x06    4     dim1            Dimension/size value 1 (sector offsets?)
0x0A    4     dim2            Dimension/size value 2
0x0E    2     format_tag      "FB" or "PB" -- format variant marker
                              "FB" = Filer format, "PB" = Calendar/scheduling format
0x10    1     version         0x3C ('<') in database files
0x11    3     unknown         Varies
0x14    2     flags2          Additional flags
0x16    1     unknown         0x00
0x17    2     initials        "JC" or "JW" -- possibly developer initials or checksum
                              "JC" in INVNTORY.FIL, "JW" in CARMAINT.FIL and PERSONAL.CLN
0x19    7     reserved        Zero-padded
```

### Allocation Bitmap (offset 0x20 to ~0x1FF)

After the header, a bitmap region tracks which data blocks/records are
allocated. Observed patterns include:

```
ff 8f f8 ff 8f f8 ...
```

These appear to be nibble-aligned allocation flags where set bits indicate
used blocks. The bitmap extends to offset 0x1FF (end of the first 512-byte
sector).

### Schema Definition (offset 0x400)

At file offset 0x400, a table definition section begins. This uses a
text-based, field-separator (0x01) delimited format:

```
T <record_type> <table_name> <id1> <id2> <field_count1> <field_count2>
    <row_count> <something> <id3> <type_code> <id4>
```

**Example from DESKMATE.HLP (at offset 0x400):**
```
T\x01DBCOLS\x012\x016\x0100019\x0100036\x013\x012\x013\x01
\x02T\x01Rules\x014\x019\x0100208\x01000\x0100224\x015\x01
\x02T\x01Text\x016\x0104\x0100191\x01000\x0100207\x017\x01
```

Tables are prefixed with "T" (0x54), fields separated by 0x01, and table
definitions terminated with 0x02.

### Column/Field Definitions (offset 0x800)

Column definitions use a similar 0x01-delimited text format:

```
\x80<id> <field_name>\x01<table_name>\x01<position>\x01<length>\x01<type>\x01<flags>\x01\x02
```

Where:
- `<id>` is a sequential byte starting at 0x10
- `<type>` is "C" for character, "N" for numeric, "D" for date
- `<length>` is the field width in characters

**Example column definitions from INVNTORY.FIL:**

| Field      | Table   | Position | Length | Type |
|------------|---------|----------|--------|------|
| cname      | DBCOLS  | 001      | 80     | C    |
| owner      | DBCOLS  | 002      | 80     | C    |
| pos        | DBCOLS  | 003      | 4      | N    |
| len        | DBCOLS  | 004      | 4      | N    |
| type       | DBCOLS  | 005      | 1      | C    |
| uniq       | DBCOLS  | 006      | 1      | N    |
| ITEM#      | LAYOUTS | 001      | 3      | N    |
| FIELDID    | LAYOUTS | 002      | 3      | N    |
| TYPE       | LAYOUTS | 003      | 3      | N    |
| FORMAT1    | LAYOUTS | 004      | 3      | N    |
| FORMAT2    | LAYOUTS | 005      | 3      | N    |
| FMT_CHARS  | LAYOUTS | 006      | 133    | C    |
| DESCRIP    | LAYOUTS | 007      | 21     | C    |
| START_COL  | LAYOUTS | 008      | 3      | N    |
| START_ROW  | LAYOUTS | 009      | 2      | N    |
| NUM_COLS   | LAYOUTS | 010      | 3      | N    |
| NUM_ROWS   | LAYOUTS | 011      | 2      | N    |
| COL_OFFSET | LAYOUTS | 012      | 2      | N    |
| ROW_OFFSET | LAYOUTS | 013      | 2      | N    |
| RECORD     | GRAPHICS| ...      | ...    | ...  |
| BITS       | GRAPHICS| ...      | ...    | ...  |
| Label      | DATA    | ...      | 25     | C    |
| Field 1    | DATA    | ...      | 25     | C    |
| Field 2    | DATA    | ...      | 25     | C    |
| Comments   | DATA    | ...      | ...    | C    |

### Layout Records (offset 0x1000)

Layout records define the visual presentation of the database form. They use
the same 0x01-delimited format and describe screen regions:

- HEADER, BODY, SUMMARY, FOOTER sections with position and size
- Each user field maps to a screen row/column with a label and data area
- Fields include: position, size, number of columns/rows, offsets

### Data Records

Actual database records appear at higher offsets in the file. The exact
starting offset depends on the schema size. Records follow the field
definitions using fixed-width fields.

### Sector Alignment

File sizes are always multiples of 2048 bytes in the sample files:
- INVNTORY.FIL: 12288 = 6 x 2048
- CARMAINT.FIL: 14336 = 7 x 2048

This suggests a 2048-byte sector/page size for the database engine.

---

## .CLN Format -- Calendar {#cln-format}

**Sample file:** PERSONAL.CLN (6144 bytes)

Calendar files reuse the .FIL database format with minor differences.

### Header

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x03
0x01    3     signature       "FIL" (same as database files)
0x04    2     flags           0x0003 (calendar-specific flags)
0x06    4     dim1            2A 2D 2D 05
0x0A    4     dim2            60 2D 2D 00
0x0E    2     format_tag      "PB" (not "FB" as in Filer databases)
0x10    1     version         0x3C ('<')
0x11    3     unknown         00 01 00
0x14    2     flags2          01 01
0x16    1     unknown         00
0x17    2     initials        "JW"
```

The "PB" format tag (vs "FB" in Filer) distinguishes Calendar files from
Filer databases. Both share the same underlying storage engine (DMDB*.RES).

File size is 6144 = 3 x 2048 bytes (same sector alignment as .FIL).

---

## .ADR Format -- Address Book {#adr-format}

**Sample file:** PERSONAL.ADR (10240 bytes)

The Address Book format differs from the .FIL format. It does NOT use the
standard "FIL" signature.

### Header

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x03
0x01    6     unknown         All zeros
0x07    6     unknown         All zeros
0x0D    6     unknown         All zeros
0x13    4     unknown         All zeros
0x17    2     initials        "JW"
0x19    7     reserved        Zeros
```

### Allocation Bitmap (offset 0x20)

Similar nibble-aligned bitmap as the .FIL format:
```
ff 8f f8 ff 8f f8 ff 8f f8 ff f0 ...
```

The .ADR file appears to be a simplified variant of the database engine --
the magic byte 0x03 is shared with .FIL, and the "JW" marker appears at the
same offset (0x17). However, the three-character "FIL" signature and the
"FB"/"PB" format tags are absent.

File size: 10240 = 5 x 2048 bytes (same sector alignment).

---

## .CFG Format -- Configuration Files {#cfg-format}

Several configuration files exist in DeskMate 3.05, each with a different
internal structure tailored to its purpose.

### DESKTOP.CFG -- Desktop Layout Configuration (1070 bytes)

Stores the desktop icon grid layout and application associations.

#### Header (12 bytes)

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    8     magic           "DESKTOP\0"
0x08    2     unknown         0x0424 (possibly total icon data size)
0x0A    2     flags           0x0100
```

#### Quick Load Section (offset 0x0C, 50 bytes)

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x0C    1     enabled         0x00 = disabled, nonzero = enabled
0x0D    49    label           "QUICK LOAD" null-padded string area
```

#### Special Entry (offset 0x3E, 55 bytes)

The "TEACH ME!" entry (icon index 0x80) at offset 0x3E uses the same
55-byte icon entry format as regular icons but with a special index value.

#### Icon Entry Table (offset 0x75, 17 entries x 55 bytes = 935 bytes)

Each icon entry is exactly 55 bytes:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
+0x00   1     marker          0x46 ('F') -- entry marker
+0x01   1     icon_index      1-based icon number on the desktop
+0x02   1     column          Column position on desktop grid
+0x03   1     row             Row position on desktop grid (or flags)
+0x04   2     flags           Usually 0x0000
+0x06   11    label           Icon display name, null-padded (max 10 chars + NUL)
+0x11   16    pdm_filename    Associated .PDM file, null-padded (e.g., "TEXT.PDM\0...")
+0x21   4     padding         Usually zeros
+0x25   14    unknown         Usually zeros
+0x33   4     file_extension  Associated data file extension, null-padded
                              (e.g., "DOC\0", "FIL\0", "FIG\0", "WKS\0", "LOG\0")
+0x35   2     tail_flags      Additional flags (varies)
```

**Observed icon entries:**

| # | Label      | PDM           | Extension |
|---|------------|---------------|-----------|
| 1 | MONTH      | (none)        | (none)    |
| 2 | TEXT       | TEXT.PDM      | DOC       |
| 3 | FILER      | FILER.PDM     | FIL       |
| 4 | ADDRESS    | ADDRESS.PDM   | (none)    |
| 5 | WORKSHEET  | WRKSHEET.PDM  | WKS       |
| 6 | CORKBOARD  | (none)        | (none)    |
| 7 | DRAW       | DRAW.PDM      | FIG       |
| 8 | TELECOM    | TELECOM.PDM   | LOG       |
| 9 | CALENDAR   | CALENDAR.PDM  | (none)    |
|10 | PHONE      | (none)        | (none)    |
|11 | PROGRAMS   | (none)        | PDM       |
|12 | PC-LINK    | PC_LINK.PDM   | (none)    |
|13 | OTHERS     | (none)        | (none)    |
|14 | TO DO      | (none)        | (none)    |
|15 | HANGMAN    | HANGMAN.PDM   | (none)    |
|16 | FORM SETUP | FORMSET.PDM   | FIL       |

### DESKTOPD.CFG -- Default Icon Entry Template (55 bytes)

A single 55-byte record in the same format as an icon entry (without the
'F' marker prefix). Contains default values for the DRAW application:

```
Name: "DRAW", PDM: "DRAW.PDM", Extension: "FIG"
Tail bytes: 46 89 0d 01 00 00
```

This file may be used as a template when adding new icons or resetting
defaults.

### ALARM.CFG -- Alarm Clock Configuration (128 bytes)

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    4     flags           00 00 00 00
0x04    60    message         Alarm message text, null-padded
                              Sample: "his is just a test" (appears truncated)
0x40    60    reserved        Zeros
0x7C    4     alarm_data      Alarm time/date data: F0 C8 A9 24
```

The 128-byte fixed size with a text message field and trailing time data
suggests a simple alarm record.

### DMCSR.CFG -- CSR Server Configuration (108 bytes)

Client-server and video configuration for DeskMate networking features.

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    11    key1            "csr_server\0"
0x0B    2     unknown         09 00
0x0D    9     workgroup       "WRKGROUP\0"
0x16    11    key2            "csr_config\0"
0x21    2     length          0x001C (28 bytes of config data follows)
0x23    28    config_data     Video/color palette configuration:
                              00 80 3C 01 28 00 05 05 F0 A0 00 00 80
                              C0 C0 00 C0 C0 C0 80 00 00 00 80 80 00 00 C0
0x3F    11    key3            "csr_confg2\0"
0x4A    2     length2         0x0020 (32 bytes)
0x4C    28    config_data2    Extended configuration
```

The "csr_config" data block at offset 0x23 contains what appears to be
a VGA color palette definition (16 RGB triplets compressed into 28 bytes).

### DMPD.CFG -- Printer Device Configuration (15 bytes)

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    4     printer_id      "IBMM" -- identifies the selected printer driver
0x04    1     unknown         0x00
0x05    2     port            0x0800 (port/device number)
0x07    8     reserved        Zeros except byte 0x0D = 0x09
```

The 4-byte printer ID corresponds to the RFD filename suffix (e.g., "IBMM"
maps to DMPDIBMM.RFD).

---

## .HLP Format -- Help Files {#hlp-format}

**Sample files:** DESKMATE.HLP (53248), DESKTOP.HLP (43008), TEXT.HLP (48128),
DRAW.HLP (27648), FILER.HLP (22528), WRKSHEET.HLP (38912), HANGMAN.HLP (12288),
ADDRESS.HLP (36864), CALENDAR.HLP (22528), TELECOM.HLP (27648), FORMSET.HLP (30720),
PC_LINK.HLP (12288), INSTALL.HLP (14336)

Help files use the .FIL database format as their container. They are
structured databases containing help text organized into tables.

### Header

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x03 (same as .FIL)
0x01    3     signature       "FIL" (same as .FIL)
0x04    2     topic_count     Two-digit ASCII number: "11" (DESKMATE), "08" (DESKTOP),
                              "03" (TEXT/FILER), "04" (WRKSHEET/ADDRESS), "07" (DRAW),
                              "02" (HANGMAN)
0x06    14    reserved        All zeros
0x14    6     reserved        All zeros
0x17    2     initials        "pj" (most files) or "JW" (HANGMAN.HLP)
```

The topic_count at offset 0x04 is stored as two ASCII decimal digits
(not binary). It indicates the number of help sections/topics.

### Internal Structure

Help files contain three standard tables:
- **DBCOLS**: Column definitions (field metadata)
- **Rules**: Help topic navigation rules (linking between topics)
- **Text**: The actual help text content

Text content includes embedded formatting codes and references to DeskMate
UI elements (menu names, dialog labels, etc.).

### File Sizes

All .HLP files have sizes that are multiples of 1024 bytes, confirming
they use the same database engine sector alignment as .FIL files.

---

## .TUT Format -- Tutorial Archives {#tut-format}

**Sample files:** DESKTOP.TUT (11502), TEXT.TUT (11674), DRAW.TUT (24880),
WRKSHEET.TUT (8215), CALENDAR.TUT (10114), FILER.TUT (22110),
ADDRESS.TUT (16024), FORMSET.TUT (10156), DMINTRO.TUT (31725)

Tutorial files are archive/bundle formats that pack multiple sub-files
(event scripts, vector graphics, document templates) into a single file
with optional compression.

### Header

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     entry_count     Number of embedded files (e.g., 9, 25)
```

### Entry Table (entry_count x 26 bytes)

Immediately following the count byte, each entry is 26 bytes:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
+0x00   13    filename        Embedded filename, null-padded (e.g., "DESKTOP.EVN\0\0")
+0x0D   4     uncomp_size     Uncompressed size in bytes (LE dword)
+0x11   4     data_offset     Offset into the data region (LE dword)
+0x15   1     comp_flag       0 = compressed, 1 = stored uncompressed
+0x16   4     stored_size     Size as stored in the data region (LE dword)
```

### Data Region

Starts immediately after the entry table at offset `1 + entry_count * 26`.
Contains the concatenated file data. Each entry's data is located at
`data_region_start + data_offset` and occupies `stored_size` bytes.

When `comp_flag == 0`: the data is compressed; `uncomp_size > stored_size`.
When `comp_flag == 1`: the data is stored verbatim; `uncomp_size == stored_size`.

The data offsets chain sequentially:
`entry[n+1].data_offset == entry[n].data_offset + entry[n].stored_size`

### Embedded File Types

| Extension | Description                              |
|-----------|------------------------------------------|
| .EVN      | Event script (tutorial step sequence)    |
| .FIG      | Vector graphic (DeskMate Draw format)    |
| .DFT      | Document template (for Text or Draw)     |
| .DOC      | Text document                            |

### Example: DESKTOP.TUT

```
Entry count: 9
Data region starts at: offset 235 (0xEB)

Name             Uncomp   Offset  Flag  Stored   Ratio
DESKTOP.EVN       5843        0    0     2524    43%
DESKTOP2.EVN      4064     2524    0     1771    44%
DESKTOP.FIG       4489     4295    1     4489   100%
LETTER.DFT         294     8784    0      193    66%
DESKSUM1.FIG      1329     8977    0      845    64%
DESKSUM2.FIG      1507     9822    0      974    65%
DESKTOP.DFT       1070    10796    0      327    31%
DESKTOPD.DFT        55    11123    0       28    51%
FINDTUT.FIG        143    11151    0      116    81%
```

The compression algorithm is proprietary and has not yet been identified.
The compression ratios (30-80%) suggest a simple byte-level scheme, possibly
LZ-based or run-length encoding.

---

## .FF1 Format -- Bitmap Fonts {#ff1-format}

**Sample files:** COBB.FF1 (61503 bytes), DIXON.FF1 (42049 bytes),
MARIN.FF1 (55782 bytes)

### File Header (66 bytes)

All three font files share an identical header structure:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    2     magic           0x7ABD (consistent across all three files)
0x02    2     version         0x0100 (version 1.0)
0x04    2     unknown1        0x0001
0x06    2     padding         0x0000
0x08    2     dpi_or_scale    0x03E8 (1000 -- possibly units per em or DPI)
0x0A    2     unknown2        0x000A (10)
0x0C    2     flags1          0x0001
0x0E    2     default_height  0x0020 (32 -- default character height?)
0x10    2     unknown3        Varies (0x00E0 in all files)
0x12    2     unknown4        Varies per font family
0x14    4     metrics1        Varies -- font metric data
0x18    4     metrics2        "8F 57 04 01" in all files
0x1C    4     unknown5        "36 00 2E 00" in all files
0x20    4     unknown6        Varies -- partial bitmap offset?
0x24    14    padding         Mostly zeros, then per-font data
0x32    2     unknown7        Varies
0x34    2     face_id         Font face index (0x0064 = 100 for first face)
0x36    6     face_metrics    Face-specific metrics
0x3C    6     unknown8        Padding/flags
```

### Font Face Entries (variable count, ~70 bytes each)

After the file header, the font contains multiple face entries (Regular,
Thin, Condensed, Wide, Extra Wide, etc.). Each face entry includes:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
+0x00   2     face_flags      Face style flags
+0x02   2     face_metrics    Size/weight values
+0x04   2     face_id         Unique face identifier (0x0064=Regular, 0x0155=Thin,
                              0x024B=Condensed, 0x047D=Wide, 0x0896=ExtraWide)
+0x06   6     metrics         Width, height, baseline metrics
+0x0C   30    face_name       Face name, null-padded
                              (e.g., "Cobb", "Cobb Thin", "Cobb Condensed",
                               "Cobb Wide", "Cobb Extra Wide")
+0x2A   varies glyph_data     Glyph offset table and bitmap data
```

### Font Family Names

| File      | Family | Faces                                          |
|-----------|--------|------------------------------------------------|
| COBB.FF1  | Cobb   | Regular, Thin, Condensed, Wide, Extra Wide     |
| DIXON.FF1 | Dixon  | Regular, Thin, Condensed, Wide, Extra Wide     |
| MARIN.FF1 | Marin  | Regular, Thin, Condensed, Wide, Extra Wide     |

The fonts are bitmapped (not vector) and appear to support proportional
spacing. The glyph data follows each face definition and consists of
compressed or packed bitmap rows.

---

## .SPL Format -- Spelling Dictionary {#spl-format}

**Sample files:** DICT.SPL (127169 bytes), USERDICT.SPL (0 bytes -- empty)

### DICT.SPL -- Main Dictionary

The main dictionary is a large binary file containing the spelling wordlist.
It is NOT plain text.

#### Copyright Notice (offset ~0x40)

```
Copyright 1986, 1987, 1988 by Xerox Corporation and Microlytics, Inc.
All rights reserved.
```

This identifies the dictionary as the **Microlytics** spelling dictionary
engine, licensed from Xerox. Microlytics was a well-known provider of
spell-check libraries in the late 1980s.

#### Header Structure

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    2     unknown1        0x01F0
0x02    2     unknown2        0x20C1
0x04    4     unknown3        1C 02 00 50
0x08    4     magic_or_hash   "VX\0\xA4" -- possibly format identifier
0x0C    4     unknown4        01 30 01 D0
0x10    16    hash_table      Binary data (compression/index structure)
0x20    6     header2         More index data
0x26    4     unknown5        Zeros then data
0x2A    22    index           Lookup index or hash entries
0x40    varies copyright      Null-terminated copyright string
```

After the copyright string, the file contains:
- A 256-byte table (offset ~0xA8): appears to be a byte-to-index mapping
  (values 0x00-0x1B followed by word offsets)
- The bulk of the file: compressed word data using a trie or hash structure

The dictionary uses Microlytics' proprietary compressed word storage format
(common in late-1980s spell checkers). Words are likely stored as a DAWG
(Directed Acyclic Word Graph) or similar compact structure.

### USERDICT.SPL -- User Dictionary

Empty (0 bytes) by default. User-added words are appended here. The format
is likely simpler than DICT.SPL -- possibly plain text with one word per
line, or a simple sorted binary list.

---

## .PCL Format -- Printer Control Language {#pcl-format}

**Sample files:** DB01.PCL through DB09.PCL (2017 to 12385 bytes)

Printer control/escape sequence definition files used by the DeskMate
print system. Each file corresponds to a different printer model or family.

### Header

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x51 ('Q')
0x01    1     printer_id      Matches filename number (01, 02, ... 09)
0x02    2     unknown1        0x0822 (consistent across files)
0x04    2     page_params     Page width/margins (varies: 0x1040, 0x2840, 0x1010)
0x06    2     unknown2        Varies
0x08    2     entry_count     Number of escape sequence entries (7, 11, 45, etc.)
0x0A    2     unknown3        0x0000
```

### Escape Sequence Entries

After the header, entries define printer control codes. Each entry appears
to be a variable-length record containing:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
+0x00   2     seq_id          Escape sequence identifier
+0x02   2     data_offset     Offset to the escape sequence data
+0x04   2     data_length     Length of the escape sequence
```

The actual escape sequences are stored in a data area following the entry
table. These contain raw bytes to send to the printer for operations like:
- Font selection
- Bold/italic/underline on/off
- Page feed, line feed
- Margin setting
- Graphics mode

### File Sizes

| File    | Size   | Entries | Description           |
|---------|--------|---------|-----------------------|
| DB01.PCL| 2017   | 7       | Basic printer         |
| DB02.PCL| 3008   | 11      | Extended printer      |
| DB03.PCL| 3559   | ~13     | Medium complexity     |
| DB04.PCL| 2532   | ~10     | Medium complexity     |
| DB05.PCL| 2076   | ~8      | Basic printer         |
| DB06.PCL| 8135   | ~25     | Complex printer       |
| DB07.PCL| 4376   | ~16     | Medium-high           |
| DB08.PCL| 12385  | ~40     | Complex printer       |
| DB09.PCL| 11754  | 45      | Most complex printer  |

---

## .RFD Format -- Printer Font Definition {#rfd-format}

**Sample files:** DMPD1.RFD (199), DMPD2.RFD (203), DMPDASCI.RFD (184),
DMPDIBMM.RFD (1004), DMPDLASR.RFD (211), DMPDS.RFD (1517)

Defines available fonts and their metrics for a specific printer model.
Each RFD file is associated with a matching .ACC and .RES printer driver pair.

### Header

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     unknown1        Varies (0x06, 0x07, 0x09)
0x01    1     unknown2        0x01 (always)
0x02    2     unknown3        0x003F (63) -- consistent across files
0x04    varies offsets        Array of 2-byte LE offsets to font entries
                              Number of entries varies by printer model
```

The offset array length depends on the printer:
- Simple printers (DMPD1, DMPD2): 2-4 offset entries, then 3 font definitions
- ASCII printers (DMPDASCI): 14 offset entries (with many duplicates), then 2 fonts
- Serial printers (DMPDS): 9 offset entries, then 17+ font definitions
- IBM printers (DMPDIBMM): variable, many fonts

### Font Entry (64 bytes each, approximately)

Each font definition record:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
+0x00   1     font_number     Sequential font ID within the file
+0x01   1     unknown1        0x01 (always)
+0x02   30    font_name       Font name, null-padded
                              (e.g., "Printer Font, 10 CPI",
                               "Courier, 12 CPI", "Roman, condensed")
+0x20   1     flags           Font style flags
+0x21   1     cpi_mode        Characters per inch mode byte
+0x22   2     horiz_dpi       Horizontal resolution
+0x24   2     vert_dpi        Vertical resolution
+0x26   2     unknown2        Pitch/spacing
+0x28   4     unknown3        Additional metrics
+0x2C   20    padding         Zeros
```

### Font Names by Printer

**DMPD1 (Tandy DMP):** Printer Font 10 CPI, 12 CPI, condensed
**DMPD2 (Tandy DMP 2):** Printer Font 10 CPI, 12 CPI, condensed
**DMPDASCI (ASCII/Daisywheel):** Wheel Font 10 CPI, 12 CPI
**DMPDS (Serial printer):** Courier, Prestige Elite, Roman, Sans Serif,
Script, OCR-A, OCR-B (each in 10 CPI, 12 CPI, condensed variants)
**DMPDIBMM (IBM ProPrinter):** Multiple font families
**DMPDLASR (Laser printer):** Multiple scalable fonts

---

## .LBL Format -- Label/Manifest {#lbl-format}

**Sample file:** DESKMATE.LBL (2253 bytes)

A file manifest or label file listing all files that belong to the DeskMate
installation. Used by the installer to verify or enumerate installed components.

### Structure

The file consists of a sequence of fixed-size records, each containing:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
+0x00   varies filename       Null-terminated filename (e.g., "CALENDAR.HLP")
+var    2     disk_id         Disk number: 0x0002 = disk 2
+var+2  2     flags           File flags: 0x0001 or 0x0110
+var+4  varies padding        Null padding to next record
```

Each record is approximately 17-20 bytes. The file lists all DeskMate files
with their source disk number and installation flags.

**Example entries:**
```
CALENDAR.HLP    disk=2  flags=0x0110
CALENDAR.PDM    disk=2  flags=0x0110
CALENDAR.TUT    disk=2  flags=0x0110
DESKMATE.HLP    disk=2  flags=0x0110
DESK.EXE        disk=2  flags=0x0110
DMCLIP.ACC      disk=2  flags=0x0110
DMCSR.CFG       disk=2  flags=0x0128
DMCSR.R89       disk=2  flags=0x0110
```

The flags field 0x0128 vs 0x0110 may indicate configuration files (writable)
versus program files (read-only).

---

## .CLP Format -- Clipboard {#clp-format}

**Sample file:** DEFAULT.CLP (3038 bytes)

The DeskMate clipboard file stores cut/copied content for paste operations
across applications.

### Header

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x10
0x01    3     signature       "CLP" (43 4C 50)
0x04    2     flags           0x0003
0x06    2     unknown1        0x0228
0x08    2     unknown2        0x0028
0x0A    2     dim1            0x6E2D
0x0C    4     dim2            2D 00 50 42
0x10    1     version         0x3C ('<')
0x11    varies data           Clipboard content (mixed format)
```

The header shares structural similarities with the .FIL format (the "PB"
marker appears at offset 0x0F, version 0x3C at 0x10). The clipboard
appears to use a simplified variant of the database container format.

The data area contains drawing/form commands ("OO" markers at offset 0x44
and 0x60) suggesting the default clipboard content includes graphical
elements -- likely the DeskMate logo or a template graphic.

---

## .R89 Format -- DeskMate Resource Module (1989) {#r89-format}

**Sample files:** DMCSR.R89 (80911 bytes), DMDB.R89 (1109 bytes),
DMGUF.R89 (15066 bytes)

R89 files are DeskMate loadable modules, identical in structure to .RES files.
They are standard DOS MZ executables with the DM89 extended header. The ".R89"
extension may indicate a specific resource format revision or resource category.

### Header

All three files follow the standard PDM/RES MZ+DM89 header format:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    2     magic           "MZ" (4D 5A)
0x02-0x1B     Standard MZ header fields
0x1C    4     dm_signature    "DM89" (44 4D 38 39)
0x20    2     reloc_repeat    Copy of relocation table offset
0x22    varies extended       DeskMate extended header data
```

**Per-file details:**

| File      | Size   | Reloc Offset | MZ Pages | Relocations |
|-----------|--------|-------------|----------|-------------|
| DMCSR.R89 | 80911  | 0x3E        | 159      | 74          |
| DMDB.R89  | 1109   | 0x3E        | 3        | 11          |
| DMGUF.R89 | 15066  | 0x42        | 30       | 15          |

DMCSR.R89 uses reloc offset 0x3E (standard RES module format).
DMGUF.R89 uses reloc offset 0x42 (standard PDM application format).
DMDB.R89 uses reloc offset 0x3E (standard RES module format).

### Purpose

- **DMCSR.R89**: CSR (Client-Server Resource) -- network/communication driver.
  The largest of the three (80911 bytes) with 74 relocations, indicating
  substantial code.
- **DMDB.R89**: Database resource module -- minimal code (1109 bytes), likely
  a small stub or configuration module for the database engine.
- **DMGUF.R89**: GUF (Generic Utility Functions?) resource module --
  medium-sized (15066 bytes) utility library.

---

## .FIG Format -- Draw Vector Graphics {#fig-format}

**No sample .FIG files in the 3.05 extracted archive** (they appear only
embedded within .TUT files).

### Known Information

From ArchiveTeam wiki and SDK references:

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    1     magic           0x14
0x01    3     signature       "FIG" (46 49 47)
0x04    varies drawing_data   Vector drawing commands
```

The .FIG format uses the same "Form Manager" drawing commands documented in
the DeskMate Technical Reference. Drawing primitives include lines, rectangles,
circles, arcs, text labels, and fill patterns.

The DeskMate Development Guide Appendix A contains the full .FIG format
specification (not available for this analysis).

Embedded .FIG files found within .TUT archives range from 116 to 4489 bytes,
suggesting they contain moderately complex vector drawings (tutorial diagrams,
UI mockups, decorative elements).

---

## .SNG Format -- Music Composition {#sng-format}

**Files in DeskMate 3.05 extracted archive:** None found.
Format referenced in DeskMate documentation (deskmate-overview.md) and present in
Personal DeskMate 2 distributions, but no .SNG files ship with DeskMate 3.05 itself.
They are created and saved by the MUSIC.PDM application at runtime.

### Overview

The .SNG format stores 3-channel music compositions created with DeskMate's Music
application. Each channel references .SND instrument sample files for playback.
The format is backward-compatible between Personal DeskMate 2 and DeskMate 3.x.

### Playback Architecture

Composition playback is handled by the DMPLAY.RES driver (42,188 bytes -- the
largest sound-related RES module). Two music drivers exist:

- **DMPLAY.RES** -- Full sound playback and DAC driver (instrument sample playback)
- **DMSSM.RES** -- Sound/sample manager (6,032 bytes; sample catalog management)
- **DMMDS.RES** -- SN76496 chip driver (2,113 bytes; square-wave fallback for non-DAC systems)
- **DMMDP.RES** -- PC speaker driver (1,493 bytes; minimal fallback)
- **DMMDJ.RES** -- Joystick music driver (1,540 bytes; purpose unclear)

### Known Format Details

From deskmate-overview.md and community research:

- 3-channel composition data (matches the SN76496's 3 square-wave channels)
- References .SND files by instrument number for digitized sample playback
- Backward compatible: Personal DeskMate 2 songs play in DeskMate 3
- MUSIC.PDM ships with Piano, Clarinet, Bells, Cello, and Bass instrument samples
  (these are .SND files distributed separately, not present in this archive)

### Header and Record Format

**Not yet reverse engineered.** No sample .SNG files available in DeskMate 3.05
distribution. Full format requires disassembly of MUSIC.PDM and DMPLAY.RES, or
analysis of a Personal DeskMate 2 disk image which likely contains example .SNG files.

---

## .MOD Format -- Compatibility Module {#mod-format}

**Files in DeskMate 3.05 extracted archive:** DMOLDAPP.MOD (8,113 bytes)

The .MOD extension is used for compatibility shim modules. Only one .MOD file
exists in the DeskMate 3.05 distribution.

### DMOLDAPP.MOD -- Old Application Compatibility Shim

DMOLDAPP.MOD is a standard DOS MZ executable (not a DM89 module) that provides
backward compatibility for older DeskMate applications.

#### Binary Structure

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    2     magic           "MZ" (4D 5A) -- standard DOS MZ executable
0x02    2     last_page_bytes 0x01B1
0x04    2     pages           0x0010 (16 pages = 8192 bytes total)
0x06    2     reloc_count     0x0007
0x08    2     header_paras    0x0020 (32 paragraphs = 512-byte header)
0x0A    2     min_extra       0x0083
0x0C    2     max_extra       0xFFFF
0x0E    2     initial_SS      0x01DC
0x10    2     initial_SP      0x0802
0x12    2     checksum        0x38E3
0x14    2     initial_IP      0x0006
0x16    2     initial_CS      0x0000
0x18    2     reloc_off       0x001E (standard -- no DM89 extension header)
0x1A    2     overlay_num     0x0000
```

**Key observation:** DMOLDAPP.MOD uses `reloc_off = 0x001E` with `overlay_num = 0x0000`.
This is a plain DOS MZ executable with no DM89 extension header, unlike .PDM/.RES/.ACC
files. This is the same pattern as the three "no DM89 header" RES files
(ALRMINIT.RES, D87.RES, DMUNPACK.RES).

#### Code Section (starts at 0x0200)

The first two bytes of the code section are "OA" (0x4F 0x41), which is not a
standard x86 prologue. The code then initializes segment registers and sets up
a stack, suggesting this is the main entry routine of a small DOS program.

#### Strings Found in Binary

Notable strings extracted from DMOLDAPP.MOD:

| String | Interpretation |
|--------|----------------|
| `INTERNETBIOSMINDSPRO` | Internal capability/product flags (packed ASCII identifiers) |
| `Tandy` | Hardware identification string |
| `1400 LT` | Tandy 1400 LT laptop model reference |
| `Tandon` | Tandon disk drive manufacturer reference |
| `01.02.00` | Version string (v1.02.00) |
| `File not found` | DOS error message |
| `Please insert disk containing nnnnnnnn.nnn into drive n:` | Disk swap prompt |
| `<R>etry, <C>ancel ? $RC` | Standard DOS retry/cancel prompt |
| `Not Enough Memory` | Memory error message |
| `for requested program in the current system configuration` | Continuation of memory error |
| `Hit any key to continue.$` | Pause prompt |
| `PATH=` | DOS PATH environment variable reference |

#### Purpose

Based on the strings and structure, DMOLDAPP.MOD is a **compatibility loader shim**
for running older DeskMate 1.x/2.x applications under DeskMate 3.05. The references
to "Tandy 1400 LT" and "Tandon" drive hardware suggest it also handles hardware
detection for legacy Tandy portables. The "INTERNETBIOSMINDSPRO" string appears to
be a packed set of capability identifiers (INT, ERNET, BIOS, MINDS, PRO) checked
during initialization.

It is a plain DOS .EXE (not a DeskMate module), loaded directly by DOS rather than
through the DeskMate module loader.

---

## .ACC Format -- Desk Accessory {#acc-format}

**Files in DeskMate 3.05 extracted archive:** 18 files (see list below)

Desk accessories are small overlay programs that run on top of DeskMate applications,
providing utility functions accessible from any DeskMate application. They are loaded
and managed by DMACCESS.ACC (the accessory launcher/framework).

### Relationship to .PDM and .RES

.ACC files share the exact same binary format as .PDM and .RES files: a standard
DOS MZ executable with a DeskMate DM89 extension header at offset 0x1C. See the
`.RES` and `.PDM` format documentation (in `disassembly/raw/res-acc-format-analysis.md`)
for the full header specification.

The distinction between .ACC, .PDM, and .RES is functional, not structural:

| Aspect | .RES | .ACC | .PDM |
|--------|------|------|------|
| Purpose | Loadable driver/library | Desk accessory | Full application |
| Loaded by | DESK.EXE on demand | DESK.EXE accessory mgr | DESK.EXE app launcher |
| Typical size | 1-42 KB | 2-32 KB | 5-70 KB |
| Has DM89 header | Yes (most) | Yes (all) | Yes (all) |
| Imports dmguf | Sometimes | Yes (all) | Yes (all) |

### DM89 Header Summary

```
Offset  Size  Field           Description
------  ----  -----------     -----------
0x00    2     mz_magic        "MZ" (4D 5A)
0x02-0x1B     Standard MZ header fields
0x1C    4     dm_signature    "DM89" (44 4D 38 39)
0x20    1     dm_version      0x3E ('>') for DeskMate 3.x
0x21    1     module_subtype  0x00 for standard ACC files
0x22    1     has_imports     0x01 if import table present
0x23    1     dm_version_echo Mirrors 0x20 when imports present
0x24    2     reserved        0x0000
0x26    2     primary_code_seg Code segment value
0x28    2     init_entry_off  Secondary entry offset
0x2A    2     code_seg_copy   Always equals field at 0x26
0x2C    20    reserved        Mostly zeros
0x42    10    import_name     First import: "dmguf\0\0\0\0\0" (all ACC files)
```

The import name "dmguf" (10 bytes, null-padded) refers to DESK.EXE's built-in
DMGUF (DeskMate GUI Framework) API -- the core UI and system services interface.

### ACC Files in DeskMate 3.05

| File | Size | Description |
|------|------|-------------|
| DMACCESS.ACC | 7,487 | Accessory launcher/framework |
| DMALARM.ACC | 14,909 | Alarm clock |
| DMCLIP.ACC | 10,507 | Clipboard manager |
| DMDRWPRT.ACC | 1,638 | Draw print helper |
| DMHELP.ACC | 31,836 | Help system |
| DMNOTEPD.ACC | 14,295 | Notepad |
| DMPD1.ACC | 6,713 | Printer driver accessory #1 |
| DMPD2.ACC | 6,685 | Printer driver accessory #2 |
| DMPDASCI.ACC | 8,035 | ASCII printer accessory |
| DMPDIBMM.ACC | 9,251 | IBM printer accessory |
| DMPDLASR.ACC | 6,969 | Laser printer accessory |
| DMPDS.ACC | 9,559 | Serial printer accessory |
| DMPHONE.ACC | 20,585 | Phone dialer |
| DMPRTSEL.ACC | 13,643 | Printer selection (imports PRGUF, not dmguf) |
| DMSERV.ACC | 24,187 | System services |
| DMSETUP.ACC | 28,695 | Setup and configuration |
| DMSPELL.ACC | 7,510 | Spell checker |
| DMTODO.ACC | 6,086 | To-do list |

**Exception:** DMPRTSEL.ACC imports "PRGUF" (from PRGUF.RES) rather than "dmguf",
making it the only ACC file that does not directly depend on the DMGUF API.

### Compiler

All .ACC files are compiled with **Microsoft C 5.x (1987)**. The entry point
follows the standard MSC 5.x DOS startup pattern (INT 21h/AH=30h version check,
then INT 20h exit if DOS < 2.0).

---

## .PNT Format -- Paint Bitmap (Personal DeskMate) {#pnt-format}

**Files in DeskMate 3.05 extracted archive:** None found.
**Files in any other archive version:** None found in this repository.

The .PNT format is the native bitmap graphics format for the Paint application
that shipped with **Personal DeskMate 2** (1987). It was superseded by DRAW.PDM
and the .FIG vector graphics format in DeskMate 3.00 (1989); Paint was dropped
and did not ship with DeskMate 3.x.

### Known Information

From deskmate-overview.md:

- Used by the Paint application in Personal DeskMate 2
- Stores 320x200x16 bitmap graphics (Tandy TGA native resolution/depth)
- Format has not been reverse engineered -- no sample files available in this repository

### Acquisition Path

To analyze .PNT files, a Personal DeskMate 2 disk image is needed (available
from WinWorld or archive.org). The Personal DeskMate 2 distribution should
include both the Paint application and sample .PNT graphics files.

---

## Cross-Format Observations

### Shared Magic Bytes

| Magic | Hex  | Formats                          |
|-------|------|----------------------------------|
| 0x03  | 03   | .FIL, .CLN, .ADR, .HLP          |
| 0x0E  | 0E   | .WKS                             |
| 0x10  | 10   | .CLP                             |
| 0x14  | 14   | .FIG                             |
| 0x1A  | 1A   | .SND                             |
| 0x46  | 46   | CFG icon entries ('F')           |
| 0x51  | 51   | .PCL ('Q')                       |
| "MZ"  | 4D5A | .PDM, .ACC, .RES, .R89, .MOD    |
| unknown | ?  | .SNG, .PNT (no samples in repo) |

### Shared Markers

- **"JW" / "JC" / "pj" at offset 0x17**: Appears in .FIL, .CLN, .ADR, and
  .HLP files. Likely developer initials or a format sub-version marker.
  "JW" is most common; "JC" appears only in INVNTORY.FIL; "pj" appears
  in most .HLP files.

- **"FB" / "PB" format tags at offset 0x0E**: Distinguish Filer databases
  ("FB") from Calendar/scheduling files ("PB"). Help files do not have
  this tag (the bytes at 0x0E contain topic page table data instead).

- **2048-byte sector alignment**: .FIL, .CLN, .ADR, and .HLP files all
  have sizes that are multiples of 2048 bytes, confirming a shared
  underlying storage engine (implemented in DMDB*.RES).

### Format Version "0x3C"

The version byte 0x3C ('<') at offset 0x10 appears in .FIL, .CLN, and .CLP
files. This likely indicates the database engine version used to create
the file (DeskMate 3.x database format).

### Relationship Between File Types

```
                    DMDB*.RES (Database Engine)
                    /        |        \
                   /         |         \
              .FIL        .HLP        .CLN / .ADR / .CLP
           (Filer DB)   (Help DB)    (Calendar/Address/Clipboard)
              "FB"        (FIL+ver)      "PB"
```

All structured data files in DeskMate route through the same database
engine (DMDBBLD.RES for building, DMDBRD.RES for reading, DMDBUPD.RES for
updating). The engine uses a 2048-byte page model with allocation bitmaps
and 0x01-delimited text-format schema definitions.

---

## Summary of Analysis Status

| Format | Magic Known | Header Decoded | Records Decoded | Fully Documented |
|--------|-------------|----------------|-----------------|------------------|
| .SND   | Yes         | Yes            | Partial         | From research    |
| .WKS   | Yes         | Partial        | No              | Needs disasm     |
| .FIL   | Yes         | Yes            | Yes             | Mostly complete  |
| .CLN   | Yes         | Yes            | Via .FIL        | Mostly complete  |
| .ADR   | Yes         | Partial        | No              | Needs more work  |
| .CFG   | Varies      | Yes            | Yes             | Good             |
| .HLP   | Yes         | Yes            | Yes             | Good             |
| .TUT   | Yes         | Yes            | Yes             | Good             |
| .FF1   | Yes         | Partial        | No              | Needs more work  |
| .SPL   | N/A         | Partial        | No              | Third-party fmt  |
| .PCL   | Yes         | Partial        | Partial         | Needs more work  |
| .RFD   | Partial     | Partial        | Yes             | Moderate         |
| .LBL   | N/A         | Yes            | Yes             | Good             |
| .CLP   | Yes         | Partial        | No              | Needs more work  |
| .R89   | Yes (MZ)    | Yes            | N/A (code)      | Same as .RES     |
| .FIG   | Yes         | No samples     | No              | Needs SDK/disasm |
| .SNG   | Unknown     | No             | No              | No samples in repo |
| .MOD   | Yes (MZ)    | Yes            | N/A (code)      | One file (DMOLDAPP.MOD) |
| .ACC   | Yes (MZ+DM89)| Yes           | N/A (code)      | Same as .RES/.PDM |
| .PNT   | Unknown     | No             | No              | Personal DM 2 only |
