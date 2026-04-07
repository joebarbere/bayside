# PDM File Format Analysis -- Tandy DeskMate 3.05

## Summary

PDM (Program/Desktop Module) files are **standard MZ DOS executables** with an extended
header used by the DESK.EXE host environment. They are NOT a custom executable format.
The extension consists of a 4-byte magic signature `DM89` at offset 0x1C and a
36-byte DeskMate metadata block at offsets 0x20-0x3F, all fitting within the
normally-reserved area of the MZ header. An optional import name table may appear
between offset 0x40 and the standard MZ relocation table.

All 14 PDM files in DeskMate 3.05 were analyzed, along with DESK.EXE itself.


## 1. File Inventory

| File | Size (bytes) | Segments | Relocations | Imports |
|------|-------------|----------|-------------|---------|
| ADDRESS.PDM | 61,025 | 5 | 35 | dmguf, dmdb |
| CALENDAR.PDM | 72,593 | 5 | 25 | (none) |
| DESKTOP.PDM | 72,681 | 4 | 13 | (none) |
| DRAW.PDM | 78,256 | 8 | 32 | (none) |
| FILER.PDM | 40,081 | 5 | 25 | dmguf, dmform, dmdb |
| FORMSET.PDM | 60,163 | 5 | 25 | dmguf, dmform, dmdb |
| HANGMAN.PDM | 27,027 | 4 | 13 | (none) |
| INSTALL.PDM | 27,235 | 4 | 13 | (none) |
| MAILMRGE.PDM | 21,333 | 5 | 19 | (none) |
| PC_LINK.PDM | 72,087 | 3 | 15 | (none) |
| PLAY.PDM | 12,183 | 4 | 14 | dmguf, dmplay, unpack |
| TELECOM.PDM | 35,661 | 4 | 13 | (none) |
| TEXT.PDM | 75,185 | 5 | 19 | (none) |
| WRKSHEET.PDM | 59,590 | 5 | 15 | (none) |


## 2. MZ Header (Standard DOS EXE, Offsets 0x00-0x1B)

All PDM files begin with the standard MZ executable header (`0x4D5A`). The header
occupies 512 bytes (0x200) in every PDM file (`e_cparhdr` = 0x0020 = 32 paragraphs).

### Standard MZ Fields

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 2 | e_magic | `0x5A4D` ("MZ") -- standard DOS EXE signature |
| 0x02 | 2 | e_cblp | Bytes on last page of file |
| 0x04 | 2 | e_cp | Pages in file (512-byte units) |
| 0x06 | 2 | e_crlc | Number of relocation entries |
| 0x08 | 2 | e_cparhdr | Header size in paragraphs (always 0x0020 = 512 bytes) |
| 0x0A | 2 | e_minalloc | Minimum extra paragraphs needed |
| 0x0C | 2 | e_maxalloc | Maximum extra paragraphs needed |
| 0x0E | 2 | e_ss | Initial SS (stack segment, relative to load address) |
| 0x10 | 2 | e_sp | Initial SP (stack pointer) |
| 0x12 | 2 | e_csum | Checksum (often 0x0000, sometimes 0x0342 or 0x0343) |
| 0x14 | 2 | e_ip | Initial IP (instruction pointer) |
| 0x16 | 2 | e_cs | Initial CS (code segment, relative to load address) |
| 0x18 | 2 | e_lfarlc | Offset of relocation table from start of file |
| 0x1A | 2 | e_ovno | Overlay number (repurposed; see below) |

**Key observation:** The `e_cblp` and `e_cp` fields encode the exact file size for
every PDM. The formula `(e_cp - 1) * 512 + e_cblp` equals the file size in all cases.

**The e_ovno field** (offset 0x1A) stores a 2-byte value that is NOT a standard
overlay number. In most PDMs it contains two ASCII digit characters (e.g., `'69'`,
`'36'`, `'20'`). Its purpose is unclear -- it may be a build number, module ID, or
internal version counter. PC_LINK.PDM and PLAY.PDM have non-ASCII values (0x0000
and 0x0106 respectively).

**The e_lfarlc field** (offset 0x18) points to the MZ relocation table. Its value
varies with the number of DeskMate import names:
- 0x0042: no import names (table immediately follows the DM89 extended header)
- 0x0056: 2 import names (0x42 + 2 * 10)
- 0x0060: 3 import names (0x42 + 3 * 10)

This formula is: `e_lfarlc = 0x42 + (n_imports * 10)`.


## 3. DM89 Signature (Offset 0x1C-0x1F)

```
Offset 0x1C: 44 4D 38 39   "DM89"
```

The 4 bytes at offset 0x1C contain the ASCII string `DM89`. In a standard MZ header,
bytes 0x1C-0x3F are reserved/unused, so Tandy repurposed this space for DeskMate
metadata without breaking DOS compatibility. The `DM89` signature is present in all
14 PDM files and also in DESK.EXE itself. It also appears in several .RES files.

The "89" likely refers to 1989, the year of the DeskMate 3.x format specification.


## 4. DM89 Extended Header (Offsets 0x20-0x3F)

This 32-byte block immediately follows the DM89 signature and provides metadata
that DESK.EXE uses when loading PDM modules.

### Field Map

| Offset | Size | Value (typical) | Field Name | Description |
|--------|------|-----------------|------------|-------------|
| 0x20 | 2 | 0x003E | dm_version | DM format version or minimum host version (constant across all PDMs) |
| 0x22 | 2 | 0x013E (PDM) / 0x0000 (EXE) | dm_type | Module type flag: 0x013E for PDM modules, 0x0000 for DESK.EXE |
| 0x24 | 2 | 0x0000 | dm_reserved1 | Reserved (always zero in all files analyzed) |
| 0x26 | 2 | varies | dm_cs | Code segment (copy of e_cs; authoritative for DM loader) |
| 0x28 | 2 | varies | dm_ip | Instruction pointer (copy of e_ip; authoritative for DM loader) |
| 0x2A | 2 | varies | dm_cs2 | Code segment (redundant copy of dm_cs) |
| 0x2C | 2 | 0x0000 | dm_reserved2 | Reserved |
| 0x2E | 2 | 0x0000 | dm_reserved3 | Reserved (except TEXT.PDM: 0x0006) |
| 0x30 | 2 | 0x0000 | dm_reserved4 | Reserved (except TEXT.PDM: 0x0FF4) |
| 0x32 | 2 | 0x0000 | dm_reserved5 | Reserved |
| 0x34 | 2 | 0x0000 | dm_reserved6 | Reserved |
| 0x36 | 2 | 0x0000 | dm_reserved7 | Reserved |
| 0x38 | 2 | 0x0000 | dm_reserved8 | Reserved |
| 0x3A | 2 | 0x0000 | dm_reserved9 | Reserved |
| 0x3C | 2 | 0x0101 or 0x0000 | dm_flags | Module capability flags |
| 0x3E | 2 | varies | dm_ip2 | Instruction pointer (redundant copy of dm_ip) |

### Critical Finding: dm_cs/dm_ip Override MZ e_cs/e_ip

PC_LINK.PDM proves that the DM loader uses `dm_cs` (0x26) and `dm_ip` (0x28) as
the authoritative entry point, not the standard MZ `e_cs` (0x16) and `e_ip` (0x14):

```
PC_LINK.PDM:
  MZ header:  e_cs=0x0000  e_ip=0xD866  (clearly wrong - points into segment 0)
  DM89 ext:   dm_cs=0x0FD1  dm_ip=0x000E  (correct entry point)
```

For all other PDMs, the MZ and DM89 values agree. This suggests DESK.EXE
preferentially reads the DM89 fields, with the MZ fields as a fallback or
set to matching values for DOS-level compatibility.

### dm_type Field (Offset 0x22)

| Value | Meaning |
|-------|---------|
| 0x013E | PDM module (all 14 PDM files) |
| 0x0000 | Host executable (DESK.EXE) |

This allows DESK.EXE to distinguish its own binary from loadable modules.

### dm_flags Field (Offset 0x3C)

| Value | Files |
|-------|-------|
| 0x0101 | ADDRESS, CALENDAR, DESKTOP, FILER, FORMSET, HANGMAN, MAILMRGE, TELECOM, TEXT, WRKSHEET |
| 0x0000 | DRAW, INSTALL, PC_LINK, PLAY |

The 0x0101 value may indicate support for DeskMate's multitasking/task-switching
capability. The four files with 0x0000 are either special-purpose (INSTALL, PLAY)
or have unique architectures (DRAW with its many resource dependencies, PC_LINK
with its different build).


## 5. Import Name Table (Offsets 0x40 to e_lfarlc)

### Structure

```
Offset 0x40:  WORD    dm_cs_copy     ; Copy of CS segment value
Offset 0x42:  BYTE[10] import[0]     ; First import name (null-padded to 10 bytes)
Offset 0x4C:  BYTE[10] import[1]     ; Second import name (if present)
Offset 0x56:  BYTE[10] import[2]     ; Third import name (if present)
...
              (MZ relocation table follows immediately)
```

Each import entry is exactly **10 bytes**: a null-terminated ASCII name padded with
zeros to fill the 10-byte slot.

### Import Names Found

| PDM | Imports |
|-----|---------|
| ADDRESS.PDM | `dmguf`, `dmdb` |
| FILER.PDM | `dmguf`, `dmform`, `dmdb` |
| FORMSET.PDM | `dmguf`, `dmform`, `dmdb` |
| PLAY.PDM | `dmguf`, `dmplay`, `unpack` |
| (all others) | (no import table) |

### Import Name Meanings

| Name | Full Name | Purpose |
|------|-----------|---------|
| `dmguf` | DM Graphical User Framework | Core GUI library (window management, controls, menus) |
| `dmdb` | DM Database | Database engine for .FIL files |
| `dmform` | DM Form | Form layout/design engine |
| `dmplay` | DM Play | Tutorial playback engine |
| `unpack` | Unpack | Data decompression library |

The import names correspond to .RES (resource/driver) files that DESK.EXE loads
alongside the PDM. For example, `dmguf` maps to DMGUF.RES, and `dmdb` maps to
DMDB.RES. PDMs without explicit import entries still access DM services -- they
do so through the standard PRGUF (Program User Framework) interface that all
PDMs link against.


## 6. MZ Relocation Table

The standard MZ relocation table follows immediately after the import name table.
Its offset is stored in `e_lfarlc` (0x18), and it contains `e_crlc` (0x06)
entries, each 4 bytes (offset:segment pair).

### Relocation Categories

Analysis of the relocation entries reveals three distinct purposes:

#### A. C Runtime Startup Relocations (7 entries in CS segment)

Every PDM has exactly 7 relocations targeting the CS (code) segment at consistent
relative offsets. These patch segment references in the Microsoft C runtime startup
code. The offsets vary slightly between PDMs based on the entry point IP value,
but the pattern is always:

```
CS:IP+0x0B  - SS segment for stack setup (mov di, XXXX)
CS:IP+0x2B  - Near-null segment reference (data segment init)
CS:IP+0x33  - Near-null segment reference (data segment init)
CS:IP+0x7E  - Near-null segment reference (BSS init)
CS:IP+0x86  - Near-null segment reference (BSS init)
CS:IP+0x89  - DS segment for C runtime (mov ax, XXXX / mov ds, ax)
CS:IP+0x9A  - Near-null segment reference (heap init)
```

#### B. MSC Runtime Error Handler Relocations (4 entries in segment 0000)

Exactly 4 relocations in segment 0000 at high offsets (near the end of the data
segment). These patch the MSC 5.x runtime error message table:

```
seg0000:XXXX  - R6000 stack overflow handler
seg0000:XXXX  - R6003 integer divide by zero handler  
seg0000:XXXX  - R6009 environment space handler
seg0000:XXXX  - R6002 floating point not loaded handler
```

#### C. Application-Specific Relocations

Additional relocations reference application code and imported resource segments.
PDMs with imports have extra relocations for the imported module entry points.


## 7. Memory Model and Segment Layout

All PDMs use the **Microsoft C small or medium memory model** with the following
segment arrangement:

```
Load Address + 0x0000:  Segment 0 (DATA + BSS + application code)
                        Contains: application functions, string constants,
                        global variables, menu definitions, UI strings
                        Size: varies (8 KB to 69 KB)

Load Address + CS:      C Runtime Code Segment  
                        Contains: MSC 5.x startup code, runtime library
                        functions (string ops, file I/O, memory management)
                        Fixed-size init block: ~0xB0 bytes
                        "MS Run-Time Library" string follows init code

Load Address + CS+N:    Additional runtime library segments
                        Contains: more MSC library routines, depending on
                        which functions the application uses
                        Number varies: 1-5 additional segments

Load Address + SS:      Stack Segment
                        Contains: uninitialized stack space
                        Size determined by e_sp (0x0800 to 0x1C00 bytes)
```

### Segment Counts by PDM

| PDM | Total Segments | Data Segment Size | Runtime Size |
|-----|---------------|-------------------|-------------|
| PLAY.PDM | 4 | ~8 KB | ~4 KB |
| HANGMAN.PDM | 4 | ~17 KB | ~9 KB |
| INSTALL.PDM | 4 | ~17 KB | ~10 KB |
| MAILMRGE.PDM | 5 | ~17 KB | ~3 KB |
| TELECOM.PDM | 4 | ~29 KB | ~6 KB |
| FILER.PDM | 5 | ~33 KB | ~6 KB |
| WRKSHEET.PDM | 5 | ~52 KB | ~7 KB |
| FORMSET.PDM | 5 | ~53 KB | ~7 KB |
| ADDRESS.PDM | 5 | ~47 KB | ~13 KB |
| DESKTOP.PDM | 4 | ~59 KB | ~14 KB |
| CALENDAR.PDM | 5 | ~59 KB | ~14 KB |
| TEXT.PDM | 5 | ~65 KB | ~9 KB |
| PC_LINK.PDM | 3 | special | ~72 KB |
| DRAW.PDM | 8 | ~69 KB | ~8 KB |


## 8. Compiler Identification

### Microsoft C 5.x (1987)

All PDMs (except PC_LINK.PDM) contain the string:

```
MS Run-Time Library - Copyright (c) 1987, Microsoft Corp
```

This identifies the compiler as **Microsoft C 5.0 or 5.1** (released 1987).

PC_LINK.PDM contains a slightly different version:

```
MS Run-Time Library - Copyright (c) 1988, Microsoft Corp
```

This indicates PC_LINK was compiled with **Microsoft C 5.1** (the 1988 update).

### Runtime Error Messages (MSC 5.x Signature)

Every PDM includes the standard MSC 5.x runtime error message table, marked by
the `<<NMSG>>` sentinel string:

```
R6000 - stack overflow
R6001 - null pointer assignment
R6002 - floating point not loaded
R6003 - integer divide by 0
R6009 - not enough space for environment
```

The `<<NMSG>>` marker and `R6xxx` error format are unique to MSC 5.x and
serve as a definitive compiler fingerprint.

### C Runtime Startup Sequence

The entry point code (at CS:IP) is the standard MSC 5.x `crt0.asm` startup:

```asm
; DOS version check
    mov  ah, 30h        ; DOS Get Version
    int  21h
    cmp  al, 02h        ; Require DOS 2.0+
    jae  .dos_ok
    int  20h            ; Terminate if DOS 1.x
.dos_ok:
; Stack setup  
    mov  di, XXXX       ; SS value (relocated)
    mov  si, [0002]     ; Top of memory from PSP
    sub  si, di
    cmp  si, 1000h      ; Cap stack at 64KB
    jb   .stack_ok
    mov  si, 1000h
.stack_ok:
    cli
    mov  ss, di
    ; ... (SP setup, interrupts re-enabled)
    
; BSS initialization (clear uninitialized data)
    ; ... (rep stosb to zero BSS segment)
    
; Call _main
    ; ... (far call to main() in segment 0)
```

### ;C_FILE_INFO Environment Variable

The string `;C_FILE_INFO` appears in most PDMs. This is an MSC runtime feature
for inheriting open file handles across exec() calls -- a standard MSC 5.x
mechanism.


## 9. DeskMate Runtime API Modules

PDMs reference the following DeskMate service modules, loaded by DESK.EXE as
.RES (resource) files or .ACC (accessory) files:

### Core Services (referenced by nearly all PDMs)

| Module | File | Description |
|--------|------|-------------|
| PRGUF | PRGUF.RES | Program User Framework -- base API for all PDMs |
| DMGUF | DMGUF.RES | Graphical User Framework -- windows, menus, dialogs |
| DMCSR | DMCSR.RES | Cursor management |
| DMSPELL | DMSPELL.ACC | Spell checker |

### Application Services (referenced by specific PDMs)

| Module | File | Used By | Description |
|--------|------|---------|-------------|
| DMDB | DMDB.RES | ADDRESS, CALENDAR, FILER, FORMSET, MAILMRGE, TEXT | Database engine |
| DMDBRD | DMDBRD.RES | ADDRESS, CALENDAR, FILER, FORMSET, MAILMRGE, TEXT | Database record display |
| DMDBBLD | DMDBBLD.RES | FILER, FORMSET | Database index builder |
| DMFORM | DMFORM.RES | FILER, FORMSET | Form layout engine |
| DMPGSET | DMPGSET.RES | CALENDAR, DRAW, FILER, FORMSET, TEXT, WRKSHEET | Page setup dialog |
| DMCONFIG | -- | ADDRESS, CALENDAR, DESKTOP, HANGMAN, INSTALL, MAILMRGE, PC_LINK | Configuration reader (DESKTOP.CFG) |
| DMTHES | -- | TEXT | Thesaurus |
| DMVE | DMVE*.RES | DRAW | Vector graphics engine |
| DMFONT | -- | DRAW | Font rendering |
| DMSSM | DMSSM.RES | DRAW | Screen/sprite management |
| DMEFORM | -- | DRAW | Extended form handling |
| DMDRWPRT | DMDRWPRT.ACC | DRAW | Print from Draw |
| DMPLAY | DMPLAY.RES | PLAY | Tutorial playback |
| DMUNPACK | DMUNPACK.RES | PLAY | Data decompression |
| DMPDASCI | DMPDASCI.ACC | ADDRESS | ASCII printer driver |

### Video Adapter Identification Table

Every PDM contains an identical block of encoded video adapter strings used for
hardware detection. These appear to be lookup keys for selecting the correct
video driver .RES file:

```
1000CGA         -> DMVD1000.RES + DMVS1000.RES (Tandy 1000 CGA mode)
DDGAEGA         -> ? (DGA/EGA mode)
HERCPLANTC16TC4 -> DMVDHERC.RES (Hercules/Plantronics/Tandy Color 16/4)
VGA             -> DMVDVGA.RES (VGA mode)
MCGAEGA         -> DMVDMCGA.RES + DMVDEGA.RES (MCGA/EGA mode)
LREST256TC40H   -> ? (Low-res/256-color/Tandy Color 40/Hercules)
```

These strings match the DMVD*.RES and DMVS*.RES video driver files found in
the DeskMate installation (visible in INSTALL.PDM's file lists).


## 10. Copyright and Version Strings

### DeskMate Copyright

Most PDMs contain one of two copyright notices:

```
DeskMate Copyright 1984, 1989    (TEXT.PDM -- earlier build)
DeskMate Copyright 1984, 1990    (all others)
```

The "1984" refers to the original DeskMate 1.0 release; "1989" or "1990"
indicates the DeskMate 3.05 build date.

### Version Display

Applications display their version via a common "About" dialog pattern:

```
About
Version [version_string]
Resources
DESK.EXE      
 CANCEL 
DeskMate Copyright 1984, 1990
Tandy Corporation, All Rights Reserved
```


## 11. Complete Header Layout Summary

```
Offset  Size  Field              Standard MZ?  DM89 Extension?
------  ----  -----------------  ------------  ---------------
0x00    2     e_magic ("MZ")     Yes           --
0x02    2     e_cblp             Yes           --
0x04    2     e_cp               Yes           --
0x06    2     e_crlc             Yes           --
0x08    2     e_cparhdr (=0x20)  Yes           --
0x0A    2     e_minalloc         Yes           --
0x0C    2     e_maxalloc         Yes           --
0x0E    2     e_ss               Yes           --
0x10    2     e_sp               Yes           --
0x12    2     e_csum             Yes           --
0x14    2     e_ip               Yes           --
0x16    2     e_cs               Yes           --
0x18    2     e_lfarlc           Yes           (adjusted for imports)
0x1A    2     e_ovno             Yes           (repurposed: build/module ID)
0x1C    4     "DM89"             --            Yes (magic signature)
0x20    2     dm_version (003E)  --            Yes
0x22    2     dm_type            --            Yes (013E=PDM, 0000=EXE)
0x24    2     dm_reserved1       --            Yes (always 0)
0x26    2     dm_cs              --            Yes (authoritative CS)
0x28    2     dm_ip              --            Yes (authoritative IP)
0x2A    2     dm_cs2             --            Yes (CS copy)
0x2C-3B 16    dm_reserved        --            Yes (mostly zeros)
0x3C    2     dm_flags           --            Yes (0101=multitask, 0000=single)
0x3E    2     dm_ip2             --            Yes (IP copy)
0x40    2     dm_cs_copy         --            Yes (CS segment value)
0x42    10*N  import_names[]     --            Yes (0-3 entries observed)
varies  4*M   reloc_table[]      Yes           --
...     ...   (zero-padded)      --            --
0x200   ...   LOAD IMAGE START   Yes           --
```


## 12. Implications for Disassembly

### Loading a PDM in Ghidra/IDA

1. PDM files can be loaded as standard MZ executables
2. Set the base address to 0x0000:0x0000 (segment 0 is at the load point)
3. For PC_LINK.PDM, manually override CS:IP to 0x0FD1:0x000E (the DM89 values)
4. Mark segment 0 as the primary data+code segment
5. Mark the CS segment as the C runtime startup segment
6. The entry point code is MSC 5.x `crt0.asm` -- follow the far call to find `main()`

### Identifying main()

In the C runtime startup at CS:IP, after stack/BSS initialization, look for:

```asm
    call far XXXX:YYYY    ; This is the call to _main()
```

The target address is in segment 0, typically at a low offset. This is the
application's `main()` function.

### Segment 0 Organization

Segment 0 contains both code and data interleaved (typical of MSC small model):
- Application code (functions) at lower offsets
- Initialized data (strings, tables) at higher offsets  
- BSS (uninitialized data) at the highest offsets before CS

### Resource Module Interfaces

PDMs that import `dmguf`, `dmdb`, etc. make far calls into those loaded .RES
modules. The call targets are resolved by DESK.EXE at load time -- look for
far calls with segment values that don't match any segment in the PDM's own
relocation table. These are DeskMate API calls.


## 13. Comparison: PDM vs DESK.EXE

| Feature | PDM Files | DESK.EXE |
|---------|-----------|----------|
| MZ signature | Yes | Yes |
| DM89 at 0x1C | Yes | Yes |
| dm_type (0x22) | 0x013E | 0x0000 |
| Header size | 512 bytes | 512 bytes |
| Import table | 0-3 entries | None |
| C runtime | MSC 5.x (1987) | MSC 5.x |
| Can run standalone | Yes (DOS-level) | Yes |
| Needs DESK.EXE host | For DM API access | Is the host |
| File size | 12-78 KB | 19 KB |

DESK.EXE is relatively small (19 KB) because it is primarily a loader and API
dispatcher. The actual application logic lives in the PDM files and .RES modules.


## 14. Open Questions

1. **dm_flags at 0x3C**: What do the individual bits mean? 0x0101 might encode
   two separate byte-flags (both set to 0x01). Hypothesis: multitasking capability
   and/or cooperative yield support.

2. **e_ovno field**: The ASCII-encoded numbers ('69', '36', '20', etc.) don't
   obviously correlate with file size, relocation count, or segment count. They
   may be internal build numbers or module priority values.

3. **DM API calling convention**: How exactly do PDMs call into the PRGUF/DMGUF
   framework? The import names suggest dynamic linking, but the mechanism (far
   call tables, interrupt vectors, or something else) needs further analysis of
   DESK.EXE's loader code.

4. **TEXT.PDM anomaly**: TEXT.PDM has non-zero values at offsets 0x2E-0x31 in the
   DM89 header (0x0006:0x0FF4), which duplicates its CS:IP. No other PDM does
   this. It may indicate an alternate entry point or additional startup hook.

5. **PC_LINK.PDM anomaly**: Why is PC_LINK's MZ e_cs:e_ip corrupted? Possible
   explanations: build tool bug, intentional obfuscation, or an older toolchain
   version (it uses the 1988 MSC copyright vs 1987 for others).


---

*Analysis performed: 2026-04-06*
*Target: DeskMate 3.05 (14 PDM files + DESK.EXE)*
*All files from: /Users/joe/Documents/GitHub/bayside/archive/deskmate-3.05/extracted/*
