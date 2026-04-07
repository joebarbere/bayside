# DeskMate 3.05 Desk Accessories (.ACC)

**Date:** 2026-04-07
**Researcher:** Claude Code (Sonnet 4.6)
**Sources:** Binary analysis of `/archive/deskmate-3.05/extracted/*.ACC`,
`/disassembly/raw/acc/acc-summary.txt`, `/disassembly/raw/res-acc-format-analysis.md`
**Status:** First-pass analysis from callgraph and header extraction — no deep
function-level annotation yet

---

## Table of Contents

1. [Overview: The ACC System](#overview)
2. [Loading and Lifecycle](#loading-and-lifecycle)
3. [Relationship to .RES and .PDM Files](#relationship-to-res-and-pdm)
4. [ACC Binary Format](#acc-binary-format)
5. [Import Table Details](#import-table-details)
6. [All 18 ACC Files — Quick Reference](#acc-inventory)
7. [Per-Accessory Descriptions](#per-accessory-descriptions)
8. [Printer Driver ACC Group](#printer-driver-acc-group)
9. [INT Call Patterns](#int-call-patterns)
10. [Reverse Engineering Priority](#reverse-engineering-priority)

---

## Overview: The ACC System {#overview}

Desk accessories are small overlay modules loaded by DESK.EXE on demand. They
appear to the user as menu entries under the Accessories menu on the DeskMate
desktop. Unlike full `.PDM` applications (which occupy the entire screen and
have their own application loop), accessories are designed to be lightweight
pop-over panels or background services — analogous to classic Mac OS desk
accessories.

DeskMate 3.05 ships with 18 ACC files totaling 228,590 bytes (223 KB). The
largest single module is DMHELP.ACC at 31,836 bytes; the smallest is
DMDRWPRT.ACC at 1,638 bytes.

Collectively the 18 ACC files contain **2,141 identified functions** in the
raw disassembly pass.

---

## Loading and Lifecycle {#loading-and-lifecycle}

DESK.EXE manages all ACC loading. Based on header and string analysis:

1. DESK.EXE scans for the Accessories menu entry when the user opens the
   Accessories menu (or when another ACC or PDM invokes an accessory by name).
2. DMACCESS.ACC is the **accessory dispatcher**. It contains references to
   "DMSPELL" and "DMHELP" by name, and its main entry point (`start` at
   0x016AC, 1171 bytes) performs the lookup-and-launch sequence.
3. DESK.EXE reads the DM89 extension header of the target ACC, parses the
   import name table, loads any required `.RES` modules, applies MZ
   relocations, and transfers control to CS:IP.
4. Accessories share DESK.EXE's address space (real-mode DOS overlay model).
   They are not separate processes.
5. On exit the ACC calls INT 21h AH=4Ch and DESK.EXE reclaims the memory via
   INT 21h AH=4Ah (Resize Memory Block), which is present in the startup code
   of nearly every ACC.

The DM89 flags field at 0x1C+0x04 (the byte at absolute offset 0x21) is
0x00 for all ACC files, identifying them as standard application/accessory
modules (not a driver subtype).

---

## Relationship to .RES and .PDM Files {#relationship-to-res-and-pdm}

All three file types share the identical MZ+DM89 on-disk format. The
distinction is functional:

| Aspect | .RES | .ACC | .PDM |
|--------|------|------|------|
| Purpose | Loadable driver/library | Desk accessory | Full application |
| Screen usage | None (no UI) | Popup panel or background | Full screen |
| Typical import | Often none | Usually dmguf or PRGUF | Usually dmguf + others |
| Module descriptor at CS:0 | Common (video drivers) | Not observed | Not observed |
| Compiler | MSC 5.x | MSC 5.x | MSC 5.x |
| Typical size | 1–42 KB | 2–32 KB | 5–70 KB |
| Loaded by | DESK.EXE module loader | DESK.EXE accessory mgr | DESK.EXE app launcher |

The printer ACC group (DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR, DMPDS) is
paired with corresponding `.RES` files (DMPD1.RES, DMPD2.RES, etc.). The ACC
provides the configuration UI; the RES provides the actual print engine called
at runtime.

---

## ACC Binary Format {#acc-binary-format}

ACC files use the standard MZ+DM89 format documented fully in
`/disassembly/raw/res-acc-format-analysis.md`. Key points specific to ACC files:

### Header layout

```
Offset  Size  Field                Notes for ACC files
------  ----  ----------------     -------------------------------------------------------
0x00    2     MZ magic             Always 0x4D5A
0x02    2     last_page_bytes
0x04    2     page_count
0x06    2     reloc_count          Range: 7–29 across all ACCs
0x08    2     header_paragraphs    Always 0x0020 (512 bytes)
0x0A    2     min_extra_para
0x0C    2     max_extra_para
0x0E    2     init_SS
0x10    2     init_SP
0x12    2     checksum
0x14    2     init_IP              Entry offset within CS
0x16    2     init_CS              Entry segment (relative to load point)
0x18    2     reloc_off            0x004C if 1 import, 0x0042 if no imports
0x1A    2     overlay_number       Non-zero; DeskMate-specific metadata
0x1C    4     DM89 magic           "DM89" (0x44 0x4D 0x38 0x39)
0x20    1     dm_version           0x3E ('>') = DM 3.x format
0x21    1     module_subtype       Always 0x00 for ACC files
0x22    1     has_imports          0x01 if import table present, else 0x00
0x23    1     dm_version_echo      Mirrors 0x20 when imports present
0x24    2     reserved             Always 0x0000
0x26    2     primary_code_seg     Usually equals init_CS
0x28    2     init_entry_offset    Usually equals init_IP
0x2A    2     primary_code_seg2    Always equals field at 0x26
0x2C    20    reserved/flags       Mostly zeros
0x3C    4     dw_unknown           Present in files with 5 segments; varies
0x42    10*N  import_name_table    N = (reloc_off - 0x42) / 10; 0 or 1 entry for ACCs
```

### Segment counts

Most ACCs have **5 segments** (code, data, BSS, stack, and one extra). The
larger accessories DMPHONE.ACC and DMSERV.ACC have **6 segments**, consistent
with a separate far-data or extra-code segment. DMHELP.ACC, DMSPELL.ACC,
DMDRWPRT.ACC have **4 segments** (MSC 5.x small model with combined
code+data).

### Relocation counts

Most ACCs use 13 relocations. DMHELP.ACC uses 7, DMSPELL.ACC uses 7, and
DMDRWPRT.ACC uses 7 — these are the smaller modules with fewer far-pointer
references. DMALARM.ACC uses 23, and DMPHONE.ACC uses 29, reflecting their
larger and more complex inter-segment code.

### Entry point variation

The DM89 fields w26/w28 diverge from the standard MZ CS/IP in three files:
DMALARM.ACC, DMHELP.ACC, and DMDRWPRT.ACC. This suggests those files expose
a secondary entry point (possibly an init/teardown routine) in addition to the
standard MZ entry.

### MSC 5.x startup stub

Every ACC includes the standard Microsoft C 5.x startup sequence at or near
the beginning of its load segment:

```asm
MOV  AH, 30h      ; Get DOS version
INT  21h
CMP  AL, 2
JAE  continue
INT  20h           ; Exit if DOS < 2.0
```

This confirms all ACC files were compiled with **Microsoft C 5.x (1987)**.

---

## Import Table Details {#import-table-details}

The import name table lives between offset 0x42 and the MZ relocation table.
Each entry is 10 bytes: a null-terminated ASCII name, zero-padded.

ACC files use at most one import. The two import names observed are:

| Import name | Provider | What it supplies |
|-------------|----------|-----------------|
| `dmguf` / `DMGUF` | DESK.EXE built-in | DeskMate GUI Framework — the full UI API (windows, menus, dialogs, event dispatch) |
| `PRGUF` | PRGUF.RES | Program User Function library — higher-level helper routines used by the printer selector |

Twelve of the 18 ACCs import `dmguf` (or the uppercase variant `DMGUF`).
Six ACCs declare no imports at all — they rely solely on INT E0h to call back
into DESK.EXE's API rather than through a named import linkage.

Import breakdown:

| Import | Files |
|--------|-------|
| `dmguf` (lowercase) | DMACCESS, DMNOTEPD, DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR, DMPDS, DMPHONE |
| `DMGUF` (uppercase) | DMSETUP |
| `PRGUF` | DMPRTSEL |
| (none) | DMALARM, DMCLIP, DMDRWPRT, DMHELP, DMSERV, DMSPELL, DMTODO |

The uppercase/lowercase distinction between `dmguf` (9 files) and `DMGUF`
(DMSETUP only) is notable; the loader likely performs a case-insensitive
comparison, but the difference may indicate DMSETUP was compiled or linked
separately from the rest of the ACC suite.

---

## All 18 ACC Files — Quick Reference {#acc-inventory}

| File | Size (bytes) | Functions | Segments | Relocations | Import | Description |
|------|-------------|-----------|----------|-------------|--------|-------------|
| DMACCESS.ACC | 7,487 | 81 | 5 | 13 | dmguf | Accessory dispatcher / framework |
| DMALARM.ACC | 14,909 | 145 | 5 | 23 | (none) | Alarm clock / timed alerts |
| DMCLIP.ACC | 10,507 | 124 | 5 | 14 | (none) | Clipboard manager |
| DMDRWPRT.ACC | 1,638 | 18 | 4 | 7 | (none) | Draw print support (stub) |
| DMHELP.ACC | 31,836 | 223 | 4 | 7 | (none) | Context-sensitive help viewer |
| DMNOTEPD.ACC | 14,295 | 116 | 5 | 13 | dmguf | Notepad text editor |
| DMPD1.ACC | 6,713 | 79 | 5 | 13 | dmguf | Printer driver 1 (dot-matrix) |
| DMPD2.ACC | 6,685 | 79 | 5 | 13 | dmguf | Printer driver 2 (dot-matrix) |
| DMPDASCI.ACC | 8,035 | 83 | 5 | 13 | dmguf | ASCII / generic printer driver |
| DMPDIBMM.ACC | 9,251 | 84 | 5 | 13 | dmguf | IBM Proprinter driver |
| DMPDLASR.ACC | 6,969 | 80 | 5 | 13 | dmguf | Laser printer (HP PCL) driver |
| DMPDS.ACC | 9,559 | 85 | 5 | 13 | dmguf | Printer driver shared services |
| DMPHONE.ACC | 20,585 | 192 | 6 | 29 | dmguf | Phone dialer / modem |
| DMPRTSEL.ACC | 13,643 | 130 | 5 | 14 | PRGUF | Printer selection UI |
| DMSERV.ACC | 24,187 | 191 | 6 | 15 | (none) | Background services / utilities |
| DMSETUP.ACC | 28,695 | 193 | 5 | 17 | DMGUF | Setup and preferences UI |
| DMSPELL.ACC | 7,510 | 153 | 4 | 7 | (none) | Spell checker |
| DMTODO.ACC | 6,086 | 85 | 5 | 13 | (none) | To-do list |
| **Total** | **228,590** | **2,141** | | | | |

---

## Per-Accessory Descriptions {#per-accessory-descriptions}

### DMACCESS.ACC — Accessory Dispatcher

**Size:** 7,487 bytes | **Functions:** 81 | **Import:** dmguf

The accessory manager and launcher. DMACCESS is loaded first when the user
opens the Accessories menu. Its `start` function (1,171 bytes at 0x016AC) is
the largest in the file and implements the menu dispatch loop. It contains
embedded references to the strings "DMSPELL" and "DMHELP", indicating it
loads those ACCs by name.

INT E0h calls: AH=02h (register accessory), AH=07h (unregister/exit).

Notable DOS calls include AH=25h/35h (set/get interrupt vectors), AH=3Eh
(close file), AH=40h (write file), and AH=4Ah (resize memory block). The
vector manipulation suggests DMACCESS installs at least one interrupt hook
during its residence in memory.

---

### DMALARM.ACC — Alarm Clock

**Size:** 14,909 bytes | **Functions:** 145 | **Import:** none

The alarm subsystem. Reads and writes `ALARM.CFG` for persistent alarm state.
The presence of INT 28h (DOS idle interrupt) confirms it is a TSR-style
background module that wakes on the idle tick to check whether any alarms are
due. INT 5Ch (NetBIOS) and INT E9h (unknown DeskMate interrupt) are also
present.

Key DOS calls include AH=2Ah (get date), AH=2Ch (get time), and AH=0Eh
(select disk), as well as AH=19h (get current drive) — consistent with
resolving `ALARM.CFG` on the current boot drive.

Strings include "Alarm/Calendar Alarms", "Use Digital Sound Alarm", "Quick
Alarm Time:", and "Sound File Name:", confirming it can trigger the DAC sound
system for audio alerts.

INT E0h calls: AH=02h, AH=06h. The 23 relocations (highest among the
non-phone ACCs) and 145 functions reflect its complexity as a resident
background module.

---

### DMCLIP.ACC — Clipboard

**Size:** 10,507 bytes | **Functions:** 124 | **Import:** none

The system clipboard. Stores cut/copied data in `CLIPBORD.DAT` on disk. The
embedded strings "The file CLIPBORD.DAT contains invalid data." and "Duplicate
clip item name." confirm this is an on-disk clipboard rather than memory-only.
The string "The selected entry is too large for the current clipboard."
indicates a capacity limit.

AH=36h (get disk free space) and AH=48h (allocate memory) are used, which
is consistent with checking available space before writing clipboard data.

The start function (2,121 bytes at 0x01EC2) contains multiple indirect call
sites through register and memory operands — this is the main event dispatch
loop with a jump table indexed by clipboard operation type.

INT E0h calls: AH=02h, AH=07h.

---

### DMDRWPRT.ACC — Draw Print Support

**Size:** 1,638 bytes | **Functions:** 18 | **Import:** none

The smallest ACC file. Acts as the print-output bridge for DRAW.PDM. The
single notable string "DRWPRTFILE" suggests it writes a temporary print-
intermediate file that the active printer driver then processes.

Only 2 INT 21h calls (AH=4Ah, AH=4Ch) and 9 INT E0h calls. INT ABh appears
twice — this is an undocumented interrupt that the DMPD1/DMPD2 ACCs also call
once each, likely a DeskMate-internal print-engine dispatch vector.

The 4-segment layout (no separate BSS segment) is consistent with a very
small, nearly pure-code module.

INT E0h calls: AH=02h only.

---

### DMHELP.ACC — Help System

**Size:** 31,836 bytes | **Functions:** 223 | **Import:** none

The largest ACC file and one of the most complex. Provides context-sensitive
help for all DeskMate applications. Locates `.HLP` files by extension and
renders their content in a scrollable viewer panel.

Strings include "Looking for Help ...", ".HLP", "Help requires DeskMate
version 03.03 or later." (version guard), and "Unable to display Help.
A network error has occurred." (network-aware file access).

The 4-segment layout with 7 relocations is the same as DMSPELL — both are
effectively single-segment code blobs with minimal far-pointer usage. Yet
DMHELP is by far the most function-rich ACC (223 functions), containing
substantial text-rendering and navigation logic. The largest function
`sub_06EC9` (2,963 bytes) is likely the help-text rendering/layout engine.

INT E0h calls: AH=00h, AH=02h, AH=06h, AH=07h — the broadest E0h API usage
among no-import ACCs.

---

### DMNOTEPD.ACC — Notepad

**Size:** 14,295 bytes | **Functions:** 116 | **Import:** dmguf

A popup text editor. Stores notes in `DMCORKBD` (the "corkboard" file) on the
current drive. The dialog string "Do you want to create file DMCORKBD on drive"
confirms the file is auto-created on first use.

Contains a reference to "A:\DESKTOP.CFG", suggesting it reads desktop
configuration for font/color preferences.

The `start` function at 0x01B2C is 6,827 bytes — the largest single function
in any ACC file. This almost certainly is the monolithic main event loop,
consistent with MSC 5.x small-model programs that fold their entire
application logic into one large function.

INT E0h calls: AH=00h, AH=02h, AH=07h.

---

### DMPHONE.ACC — Phone Dialer

**Size:** 20,585 bytes | **Functions:** 192 | **Import:** dmguf

The modem-based phone dialer. Maintains a phone list ("Phone List", "Work
phone", "Home phone") and can dial numbers via the serial port (uses INT E2h
for serial/modem communication, 5 calls).

Accesses the Address Book: "Cannot open the Address Book data file." and
"Cannot open the Shared Address Book data file." indicate integration with
ADDRBOOK.PDM's data.

Uses INT 28h (DOS idle) confirming background residence. INT 5Ch (NetBIOS)
appears once, for network-aware address book access. Calls AH=0Eh (select
disk), AH=2Ah (get date), AH=2Ch (get time), and AH=48h (allocate memory).

The largest function `sub_04181` (3,304 bytes) is the main event/dispatch
handler. The 6-segment layout (unique with DMSERV among the larger ACCs)
accommodates the additional serial-port and phone-list data segments.

INT E0h calls: AH=00h, AH=02h, AH=06h, AH=07h.

---

### DMSERV.ACC — Background Services

**Size:** 24,187 bytes | **Functions:** 191 | **Import:** none

The DeskMate background services module. Strings include "Page Setup",
floating-point error messages ("- floating-point error: "), and references to
"DMSPELL" and "DMHELP". The floating-point error handler suggests DMSERV
installs a software FPU exception handler (INT 07h, which appears once — the
80387 "device not available" exception vector).

The `start` function (3,997 bytes at 0x04CDE) is the second-largest start
function across all ACCs, with 8 indirect call sites through register and
memory operands — indicative of a large dispatch table for service requests
from other modules.

The 6-segment layout (shared with DMPHONE) accommodates the service dispatch
table and the large data segment needed for tracking inter-app state.

INT E0h calls: AH=00h, AH=02h, AH=07h. No AH=06h, unlike most other ACCs,
which may indicate DMSERV does not use the standard "register application"
E0h call.

---

### DMSETUP.ACC — Setup and Preferences

**Size:** 28,695 bytes | **Functions:** 193 | **Import:** DMGUF (uppercase)

The DeskMate configuration panel. The second-largest ACC. Covers
communication (modem) setup, printer configuration, and general DeskMate
preferences. Strings include "Setup Communications", "Modems", "Dial Timeout",
"Modem", and "Printer...".

References `DMPRTSEL.CFG` (printer selection config), confirming it orchestrates
the entire printer setup workflow by launching DMPRTSEL.ACC.

The two largest functions — `sub_0643F` (2,520 bytes) and `sub_05A8E`
(2,481 bytes) — are connected in a call chain from `start` (530 bytes at
0x05748). This suggests a two-phase initialization: a first pass sets up the
UI framework, then a second pass enters the main configuration event loop.

Uses INT E2h (5 calls) for serial/modem communication, same as DMPHONE.

INT E0h calls: AH=00h, AH=02h, AH=06h, AH=07h.

---

### DMSPELL.ACC — Spell Checker

**Size:** 7,510 bytes | **Functions:** 153 | **Import:** none

Despite its modest size, DMSPELL contains 153 functions — the highest
function density of any ACC by ratio. This reflects the spell-checking
algorithm, which decomposes into many small string-processing and
dictionary-traversal routines.

Uses AH=45h (duplicate file handle) and AH=68h (commit/flush file) — the
only ACC to call these functions — consistent with maintaining an open handle
to a large dictionary file (SPELL.RES / SPL.RES) across multiple check
operations.

Does not call AH=25h/35h (no interrupt vector manipulation), confirming it
is not a resident module — it is invoked on demand and exits cleanly.

Strings: "DeskMate Spell Checker", "Spelling correct.", "All words are
correctly spelled.", "DMHELP", "SPELL".

INT E0h calls: AH=02h, AH=07h only.

---

### DMTODO.ACC — To-Do List

**Size:** 6,086 bytes | **Functions:** 85 | **Import:** none

A simple task/reminder list accessory. References "DMHELP", "DMSPELL", and
"DESKTOP.CFG" by name, which is the standard trio seen in most user-facing
accessories (help, spell check, and desktop configuration access).

The `start` function (958 bytes at 0x01208) is in the mid-range for ACC entry
points. The main event dispatch function `sub_0043F` (451 bytes) is the
second-largest function in the file.

The string "A:\DESKTOP.CFG" (with hardcoded drive letter) also appears in
DMNOTEPD, suggesting shared startup code that locates the desktop config.

INT E0h calls: AH=02h, AH=07h only.

---

## Printer Driver ACC Group {#printer-driver-acc-group}

Six ACC files form a tightly coupled printer driver subsystem. All six share
an almost identical structure: 5 segments, 13 relocations, 79–85 functions,
and the same set of INT 21h calls (AH=25h, 30h, 35h, 3Eh, 40h, 44h, 4Ah,
4Ch). All import `dmguf`. All reference "PAGE SETUP", "DMSETUP",
"DMPRTSEL.CFG", "DMPD.CFG", and "INSTALL.CFG".

| File | Functions | Description |
|------|-----------|-------------|
| DMPD1.ACC | 79 | Dot-matrix printer driver #1 (Epson-compatible) |
| DMPD2.ACC | 79 | Dot-matrix printer driver #2 (additional Epson model) |
| DMPDASCI.ACC | 83 | Generic ASCII / plain-text printer |
| DMPDIBMM.ACC | 84 | IBM Proprinter (matrix, IBM ESC sequence set) |
| DMPDLASR.ACC | 80 | Laser printer (HP PCL / LaserJet-compatible) |
| DMPDS.ACC | 85 | Printer driver shared services layer |

DMPD1.ACC and DMPD2.ACC are nearly binary-identical (sizes 6,713 vs 6,685,
same function layout, same call graph). They almost certainly represent two
dot-matrix printer models with different escape-sequence tables embedded in
their data segments.

DMPDIBMM.ACC and DMPDLASR.ACC both issue INT 05h (the print-screen interrupt)
— the only two ACC files to do so. Both also call INT ABh once, the same
undocumented print-dispatch vector seen in DMDRWPRT.

DMPDS.ACC (9,559 bytes, 85 functions) is the largest of the printer driver
ACCs and acts as a shared services layer. Its `start` function (3,955 bytes)
is substantially larger than the equivalent entry point in the other printer
ACCs (~1,959–3,863 bytes), consistent with it initializing the shared printing
infrastructure that the other drivers depend on.

All printer driver ACCs work in conjunction with corresponding `.RES` files
(DMPD1.RES, DMPD2.RES, DMPDASCI.RES, DMPDIBMM.RES, DMPDLASR.RES, DMPDS.RES)
which contain the actual low-level print engine code. The ACC provides the
"Page Setup" dialog UI; the RES handles the byte-level printer protocol.

The printer selection UI itself is in **DMPRTSEL.ACC**, which imports `PRGUF`
(not `dmguf`) and uses INT 11h (equipment list) and INT 13h (disk services)
to enumerate available printers and detect hardware configuration.

---

## INT Call Patterns {#int-call-patterns}

The following table summarizes all interrupt calls found across all 18 ACCs.
Counts show total call-site occurrences in the raw disassembly.

| Interrupt | Purpose | Files that use it |
|-----------|---------|-------------------|
| INT 05h | Print screen | DMPDIBMM, DMPDLASR |
| INT 07h | FPU not-available | DMSERV |
| INT 11h | Equipment list | DMPRTSEL |
| INT 13h | Disk services | DMPRTSEL |
| INT 20h | Program terminate (old) | All except DMHELP, DMSPELL, DMDRWPRT |
| INT 21h | DOS API | All |
| INT 28h | DOS idle | DMALARM, DMPHONE |
| INT 5Ch | NetBIOS | DMALARM, DMPHONE |
| INT ABh | Undocumented (print dispatch?) | DMDRWPRT, DMPD1, DMPD2, DMSPELL |
| INT E0h | DeskMate API | All |
| INT E2h | DeskMate serial/modem | DMALARM, DMPHONE, DMSETUP |
| INT E9h | DeskMate unknown | DMALARM |

### INT E0h service usage

INT E0h is the primary DeskMate API vector. Four service sub-functions appear:

| AH value | Service | Used by |
|----------|---------|---------|
| 00h | Register/query (exact semantics TBD) | DMHELP, DMNOTEPD, DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR, DMPDS, DMPHONE, DMPRTSEL, DMSERV, DMSETUP |
| 02h | Common entry (likely "get service pointer") | All 18 ACC files |
| 06h | Common entry (likely "register accessory UI") | DMALARM, DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR, DMPDS, DMPHONE, DMPRTSEL, DMSETUP |
| 07h | Common entry (likely "unregister / exit") | DMACCESS, DMCLIP, DMHELP, DMNOTEPD, DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR, DMPDS, DMPHONE, DMPRTSEL, DMSETUP, DMSPELL, DMTODO |

Every ACC calls AH=02h. The three ACCs that only call AH=02h and AH=07h
(DMACCESS, DMCLIP, DMTODO) are the simplest in terms of DESK.EXE API usage —
they do not call AH=00h or AH=06h, suggesting those functions relate to
features (printer registration, extended UI services) that those accessories
do not need.

---

## Reverse Engineering Priority {#reverse-engineering-priority}

**High priority (core infrastructure):**

- **DMACCESS.ACC** — Understanding ACC dispatch is a prerequisite for
  reconstructing the accessory menu in the C rebuild.
- **DMCLIP.ACC** — Inter-application data exchange; needed to verify
  TEXT/WORKSHEET/FILER clipboard integration.
- **DMHELP.ACC** — Largest ACC; its `.HLP` file format and rendering engine
  are needed for completeness, and it is invoked by every application.

**Medium priority (user-facing):**

- **DMNOTEPD.ACC** — Self-contained and representative; good early
  transpilation target.
- **DMALARM.ACC** — Exercises TSR/resident patterns and the INT 28h idle
  handler; useful for verifying interrupt-hook reconstruction.
- **DMSERV.ACC** — Background services likely provide shared state used by
  multiple applications; understanding it clarifies cross-application
  communication.
- **DMSETUP.ACC** — Configuration storage format (DMPRTSEL.CFG, DMPD.CFG,
  INSTALL.CFG) must be understood to reconstruct preferences persistence.
- **DMTODO.ACC** — Small and self-contained; fast transpilation win.
- **DMSPELL.ACC** — Dictionary file interface (SPELL.RES / SPL.RES).
- **DMPHONE.ACC** — Serial port and modem access patterns.
- **DMPRTSEL.ACC** — Printer enumeration and selection workflow.

**Low priority (hardware-specific drivers):**

- DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR — Printer drivers for specific
  hardware; low value until a working print subsystem is otherwise in place.
- **DMDRWPRT.ACC** — Tiny (1,638 bytes); depends on DRAW.PDM being complete
  first.

---

## Sources

- `/disassembly/raw/res-acc-format-analysis.md` — MZ+DM89 format specification
- `/disassembly/raw/acc/acc-summary.txt` — Automated per-file analysis
  (strings, INT calls, function counts)
- `/disassembly/raw/acc/*-callgraph.txt` — Per-file call graph and function
  listings
- `/research/docs/deskmate-overview.md` — DeskMate version history and
  hardware reference
- `/research/docs/int-e0h-api-reference.md` — INT E0h DeskMate API
  documentation
