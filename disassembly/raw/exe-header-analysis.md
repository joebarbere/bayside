# DeskMate 3.05 MZ EXE Header Analysis

Analysis date: 2026-04-06
Analyst: Claude Code (Opus 4.6)

---

## 1. DESK.EXE (Main Shell)

### File Information
- **Actual file size:** 19,047 bytes
- **Header-computed size:** 19,047 bytes (match: YES)
  - Pages: 38 (0x0026), last page bytes: 103 (0x0067)
  - Calculation: (38 - 1) * 512 + 103 = 19,047

### MZ Header Fields (offset 0x0000 - 0x001B)

| Offset | Field | Raw (hex) | Decoded |
|--------|-------|-----------|---------|
| 0x00 | Signature | 4D 5A | "MZ" -- valid DOS EXE |
| 0x02 | Last page bytes | 0x0067 | 103 |
| 0x04 | Pages in file | 0x0026 | 38 |
| 0x06 | Relocation count | 0x0021 | 33 |
| 0x08 | Header size (para) | 0x0020 | 32 paragraphs = 512 bytes |
| 0x0A | MINALLOC | 0x10EA | 4,330 paragraphs = 69,280 bytes |
| 0x0C | MAXALLOC | 0xFFFE | 65,534 paragraphs = 1,048,544 bytes |
| 0x0E | Initial SS | 0x050A | |
| 0x10 | Initial SP | 0x0800 | 2,048 bytes stack |
| 0x12 | Checksum | 0x0000 | (unused) |
| 0x14 | Initial IP | 0x0010 | |
| 0x16 | Initial CS | 0x0405 | |
| 0x18 | Reloc table offset | 0x003E | 62 |
| 0x1A | Overlay number | 0x4413 | 17,427 (non-standard -- see DM89 tag below) |

### DM89 Signature (DeskMate Custom Header Extension)

At offset 0x001C (immediately after the standard MZ header), DESK.EXE contains:

```
Offset 0x001C: 44 4D 38 39  "DM89"
```

This is a **DeskMate-specific tag** embedded in the MZ header's extended area. Both
DESK.EXE and INSTALL.EXE contain this tag; DMVID.EXE does not. The "DM89" tag likely
identifies the file as a DeskMate-compatible executable that can be loaded or recognized
by the DeskMate shell. The surrounding bytes contain what appear to be additional
DeskMate-specific metadata:

```
0x001A: 13 44          Overlay field = 0x4413 (probably DeskMate metadata, not a real overlay)
0x001C: 44 4D 38 39    "DM89" magic
0x0020: 3E 00          Unknown field (0x003E)
0x0022: 00 00 00 00    Padding/zeroes
0x0026: 00 00
0x0028: 0E 00          Unknown field (0x000E)
0x002A: 05 04          Matches CS segment (0x0405) 
0x002C: 0B 00          Unknown field (0x000B)
0x002E: F5 03          Matches a referenced segment (0x03F5)
```

The overlay number 0x4413 is suspicious -- byte-swapping the two bytes before "DM89"
gives `0x13 0x44`, and 0x44 is ASCII 'D'. This is likely part of the DeskMate header
structure rather than a real overlay indicator.

### Entry Point: 0405:0010 (file offset 0x4260)

```
0405:0010  mov bx, 0x0000       ; BB 00 00
0405:0013  mov cx, 0x03F5       ; B9 F5 03  -- segment value (data segment?)
0405:0016  mov dx, 0x0456       ; BA 56 04  -- segment value 
0405:0019  mov si, es           ; 8C CE     -- save PSP segment
0405:001B  mov di, 0x033B       ; BF 3B 03  -- segment value
0405:001E  mov ds, dx           ; 8E DA     -- set DS
0405:0020  call far 033B:01AF   ; 9A AF 01 3B 03  -- init call
0405:0025  jb  +0x17            ; 72 17     -- error check
0405:0027  mov word [0016], 0x0019  ; set far pointer for callback
           call far [0016]         ; invoke it
           mov word [0012], 0x0009  ; set another far pointer
           call far [0012]         ; invoke it
0405:003B  call near 0x030F     ; E8 FC 02  -- cleanup?
0405:003E  call near 0x00D1     ; E8 90 00  -- more cleanup
0405:0041  mov ax, 0x4C00       ; B8 00 4C  -- DOS terminate, exit code 0
0405:0044  int 0x21             ; CD 21     -- DOS function call
```

This is **NOT** a standard C runtime startup sequence. It is a **custom DeskMate
loader/shell entry point**. Key observations:

1. Registers BX, CX, DX, DI are loaded with segment values before the first far call
2. The far call to 033B:01AF is likely the DeskMate initialization routine
3. On error (carry flag set), it jumps to an error handler
4. On success, it invokes two callbacks through far pointers stored at [0016] and [0012]
5. Clean exit via INT 21h/4Ch (DOS 2.0+ terminate with return code)

### Version String at 0405:0052 (file offset 0x42A2)

```
"DESKMATE$05.00 900919$"
```

This encodes: DeskMate version 05.00, build date September 19, 1990 (900919).

### Application Strings (file offset ~0x3B1B)

```
"DeskMate\r\nVersion: 03.05.00\r\nCopyright 1984,1990 Tandy Corporation "
"The DeskMate product is already running."
"DeskMate Extended Memory support not loaded."
```

### Segment Layout

| Segment | File Offset | Size (est.) | Role |
|---------|-------------|-------------|------|
| 0x0000 | 0x0200 | ~13,232 | Main code segment (segment 0, largest block) |
| 0x033B | 0x35B0 | ~416 | Initialization/loader code |
| 0x0355 | 0x3750 | ~2,560 | Application logic (error messages, UI strings) |
| 0x03F5 | 0x4150 | ~256 | Data or small code segment |
| 0x0405 | 0x4250 | ~1,296 | Entry point segment + version string |
| 0x0456 | 0x4760 | ~263 | Data/BSS segment (relocation targets) |
| 0x050A | (beyond EOF) | -- | Stack segment (SS, allocated at load time) |

### Relocation Table (33 entries at offset 0x003E)

The 33 relocations patch segment references at load time. They cluster in segments
0x0355, 0x0405, and 0x0456, indicating these segments contain far pointers and
inter-segment references.

### Compiler Identification

**No standard compiler runtime detected.** DESK.EXE does not contain Microsoft C, Borland,
or Watcom runtime signatures. The entry point is not a C runtime startup. The only
copyright string is:

```
"Copyright 1984,1990 Tandy Corporation"
```

**Conclusion:** DESK.EXE was likely written in **assembly language** or built with a
custom toolchain that strips compiler identification. The code structure (custom
entry point, far call dispatching, segment-based module loading) is consistent with
hand-written assembly for a DOS shell/framework. The code may have been written using
MASM (Microsoft Macro Assembler) or TASM.

### Key Application Data

Embedded strings reveal the DeskMate shell's functionality:

- File extensions recognized: `.PDM`, `.COM`, `.EXE`, `.BAT`
- Config files: `AUTOLOAD.CFG`, `DESKTOP.CFG`, `DMCSR.CFG`
- Environment variables: `DMCONFIG=`, `COMSPEC=`, `PATH=`, `DMTASK1=`
- Module files: `DMOLDAPP.MOD`, `.R89`, `.RES`, `.ACC`
- Resource subsystems: `DMCSR`, `DMEMM`, `DMDB`, `DMGUF`
- Error messages for: File Not Found, Not Enough Memory, Disk Error,
  Write Protected, Share Violation, Network Error

---

## 2. DMVID.EXE (Video Driver Configuration)

### File Information
- **Actual file size:** 16,477 bytes
- **Header-computed size:** 16,477 bytes (match: YES)
  - Pages: 33 (0x0021), last page bytes: 93 (0x005D)
  - Calculation: (33 - 1) * 512 + 93 = 16,477

### MZ Header Fields

| Offset | Field | Raw (hex) | Decoded |
|--------|-------|-----------|---------|
| 0x00 | Signature | 4D 5A | "MZ" -- valid DOS EXE |
| 0x02 | Last page bytes | 0x005D | 93 |
| 0x04 | Pages in file | 0x0021 | 33 |
| 0x06 | Relocation count | 0x0004 | 4 |
| 0x08 | Header size (para) | 0x0020 | 32 paragraphs = 512 bytes |
| 0x0A | MINALLOC | 0x00C9 | 201 paragraphs = 3,216 bytes |
| 0x0C | MAXALLOC | 0xFFFF | 65,535 paragraphs = 1,048,560 bytes |
| 0x0E | Initial SS | 0x042E | |
| 0x10 | Initial SP | 0x0800 | 2,048 bytes stack |
| 0x12 | Checksum | 0xEFAC | (rare to see non-zero) |
| 0x14 | Initial IP | 0x060A | |
| 0x16 | Initial CS | 0x0000 | Code starts at base of load image |
| 0x18 | Reloc table offset | 0x001E | 30 |
| 0x1A | Overlay number | 0x0000 | No overlay / not a DeskMate PDM |

### DM89 Signature

**NOT PRESENT.** DMVID.EXE is a standard DOS EXE, not a DeskMate-hosted application.
This makes sense -- it runs standalone from the DOS command line to configure the
video driver before DeskMate starts.

### Entry Point: 0000:060A (file offset 0x080A)

```
0000:060A  mov ah, 0x30         ; B4 30     -- DOS: Get DOS version
0000:060C  int 0x21             ; CD 21
0000:060E  cmp al, 0x02         ; 3C 02     -- Require DOS 2.0+
0000:0610  jae 0x0614           ; 73 02     -- OK if >= 2
0000:0612  int 0x20             ; CD 20     -- DOS 1.x terminate (fallback)
0000:0614  mov di, 0x0358       ; BF 58 03  -- near top of BSS/heap
0000:0617  mov si, [0002]       ; 8B 36 02 00 -- PSP: memory top paragraph
0000:061B  sub di, si           ; 2B F7     -- calc available memory
0000:061D  cmp si, 0x1000       ; 81 FE 00 10 -- need at least 64KB?
0000:0621  jb  +3               ; 72 03
0000:0623  mov si, 0x1000       ; BE 00 10  -- cap at 64KB
0000:0626  cli                  ; FA        -- disable interrupts
0000:0627  mov ss, di           ; 8E D7     -- set stack segment
0000:0629  add sp, 0x0D5E       ; 81 C4 5E 0D -- set stack pointer
0000:062D  sti                  ; FB        -- re-enable interrupts
0000:062E  jae 0x0640           ; 73 10     -- branch on memory OK
0000:0630  push ss / pop ds     ; 16 1F     -- DS = SS
0000:0632  call near 0x11BA     ; E8 85 0B  -- error: not enough memory
0000:0635  xor ax, ax           ; 33 C0
0000:0637  push ax              ; 50
0000:0638  call near 0x141B     ; E8 E0 0D  -- _exit(0)
0000:063B  mov ax, 0x4CFF       ; B8 FF 4C  -- DOS terminate, exit code 255
0000:063E  int 0x21             ; CD 21
```

This is a **Microsoft C 5.x small-model startup sequence** (`__astart` or `__cstart`).
The pattern is unmistakable:

1. Check DOS version (require 2.0+), use INT 20h fallback for DOS 1.x
2. Calculate available memory from PSP
3. Set up stack segment (CLI/STI bracketed SS:SP write)
4. On insufficient memory, call error handler then exit
5. Later in the startup (not shown): zero BSS, parse command line, call `main()`

### Compiler Identification: Microsoft C 5.x (1987)

**Confirmed** by the embedded string:

```
"MS Run-Time Library - Copyright (c) 1987, Microsoft Corp"
```

This is the **Microsoft C 5.0 runtime library** copyright string, placing the compiler
vintage at 1987. The runtime error messages confirm this:

| Code | Message |
|------|---------|
| R6000 | stack overflow |
| R6001 | null pointer assignment |
| R6002 | floating point not loaded |
| R6003 | integer divide by 0 |
| R6009 | not enough space for environment |

Additional runtime indicators:
- `_C_FILE_INFO` environment variable handling (MSC file handle inheritance)
- `(null)` string (printf NULL pointer handling)
- `<<NMSG>>` marker (near message table for runtime errors)

### Memory Model

**Small model** (CS=0000, single code segment, single data segment):
- CS:IP starts at 0000:060A -- code in the base segment
- Only 4 relocations (minimal inter-segment references)
- Stack at segment 0x042E (separate from code/data)

### Segment Layout

| Segment | File Offset | Role |
|---------|-------------|------|
| 0x0000 | 0x0200 | CODE segment (_TEXT) -- all code including CRT |
| 0x0358 | 0x3780 | Near the end of code, transition to DATA |
| 0x035C | 0x37C0 | DATA segment (_DATA) -- strings, initialized data |
| 0x042E | 0x44E0 | STACK segment (beyond EOF, allocated at load time) |

### Relocation Table (4 entries at offset 0x001E)

| # | Location | File Offset | Notes |
|---|----------|-------------|-------|
| 0 | 035C:0038 | 0x37F8 | In data segment |
| 1 | 0000:0615 | 0x0815 | In startup code |
| 2 | 0000:06A0 | 0x08A0 | In startup code |
| 3 | 035C:01D6 | 0x3996 | In data segment |

The minimal relocation count (4) is consistent with Microsoft C small model, where
nearly all references are near (within segment).

### Application Functionality

DMVID.EXE is a **standalone video configuration utility**. Key strings reveal:

**Supported video adapters:**
| Menu | ID String | Description |
|------|-----------|-------------|
| 1 | AUTO | Automatic detection |
| 2 | VGA | Video Graphics Array, 640x480 16 colors |
| 3 | EGA | Enhanced Graphics Adapter, 640x350 16 colors |
| 4 | MCGA | Multi Color Graphics Array, 640x480 2 colors |
| 5 | CGA | Color Graphics Adapter, 640x200 2 colors |
| 6 | HERC | Hercules, 720x348 monochrome |
| 7 | 1000 | Tandy 1000, 640x200 4 colors |
| 8 | TC16 | Tandy Color, 640x200 16 colors |

Additional internal driver codes: `TC40`, `TC64`, `T256`, `HRES`, `MRES`, `LRES`

**Configuration file:** `DMCSR.CFG` (read/written)
**Config system:** Uses `DMRESCFG` and `DMCONFIG` environment variables

---

## 3. INSTALL.EXE (Installer Stub)

### File Information
- **Actual file size:** 828 bytes
- **Header-computed size:** 828 bytes (match: YES)
  - Pages: 2 (0x0002), last page bytes: 316 (0x013C)
  - Calculation: (2 - 1) * 512 + 316 = 828

### MZ Header Fields

| Offset | Field | Raw (hex) | Decoded |
|--------|-------|-----------|---------|
| 0x00 | Signature | 4D 5A | "MZ" -- valid DOS EXE |
| 0x02 | Last page bytes | 0x013C | 316 |
| 0x04 | Pages in file | 0x0002 | 2 |
| 0x06 | Relocation count | 0x0002 | 2 |
| 0x08 | Header size (para) | 0x0020 | 32 paragraphs = 512 bytes |
| 0x0A | MINALLOC | 0x0079 | 121 paragraphs = 1,936 bytes |
| 0x0C | MAXALLOC | 0x0079 | 121 paragraphs = 1,936 bytes (exact!) |
| 0x0E | Initial SS | 0x0018 | |
| 0x10 | Initial SP | 0x0800 | 2,048 bytes stack |
| 0x12 | Checksum | 0x0000 | (unused) |
| 0x14 | Initial IP | 0x000C | |
| 0x16 | Initial CS | 0x0000 | |
| 0x18 | Reloc table offset | 0x003C | 60 |
| 0x1A | Overlay number | 0x0001 | 1 |

### DM89 Signature

**PRESENT** at offset 0x001C:

```
0x001C: 44 4D 38 39    "DM89"
0x0020: 3C 00          Unknown (0x003C)
```

INSTALL.EXE carries the DM89 tag, identifying it as a DeskMate-aware executable.

### MINALLOC == MAXALLOC

Notably, MINALLOC and MAXALLOC are both 0x0079 (121 paragraphs = 1,936 bytes). This
means INSTALL.EXE requests **exactly** 1,936 bytes of additional memory beyond the
load image -- no more, no less. This is unusual for a normal DOS program and suggests
it is designed to leave maximum free memory for the program it will chain-load.

### Entry Point: 0000:000C (file offset 0x020C)

```
0000:000C  mov ax, 0x000A       ; B8 0A 00  -- segment 0x000A (relocated)
0000:000F  mov ds, ax           ; 8E D8     -- set DS to data segment
0000:0011  mov es, ax           ; 8E C0     -- set ES to data segment
0000:0013  mov dx, 0x0004       ; BA 04 00  -- offset of filename string
0000:0016  mov ax, 0x3D00       ; B8 00 3D  -- DOS: Open file (read-only)
0000:0019  int 0x21             ; CD 21
0000:001B  jb  error            ; 72 E3     -- jump if open failed
0000:001D  mov bx, ax           ; 8B D8     -- save file handle
0000:001F  mov cx, 0x003C       ; B9 3C 00  -- read 60 bytes
0000:0022  mov dx, 0x009C       ; BA 9C 00  -- into buffer at DS:009C
0000:0025  mov ah, 0x3F         ; B4 3F     -- DOS: Read file
0000:0027  int 0x21             ; CD 21
0000:0029  jb  error            ; 72 D5     -- jump if read failed
0000:002B  mov ah, 0x3E         ; B4 3E     -- DOS: Close file
0000:002D  int 0x21             ; CD 21
0000:002F  cmp word [00B4], 0x25 ; check field in loaded header
           jbe error            ; must be > 0x25 (37)
0000:0036  cmp word [00B8], "DM" ; 81 3E B8 00 44 4D -- check for "DM" signature
0000:003C  jne error
0000:003E  cmp word [00BA], "89" ; 81 3E BA 00 38 39 -- check for "89" signature
0000:0044  jne error
0000:0046  cmp word [0002], ... ; check PSP memory size
0000:004D  jne error
0000:004F  mov dx, 0x0004       ; filename offset
0000:0052  mov bx, 0x0027       ; parameter block offset
0000:0055  mov ax, 0x4B01       ; DOS: Load program (load but don't execute)
0000:0058  int 0x21             ; CD 21
0000:005A  jb  error
```

This is a **chain loader / bootstrap stub**. The logic is:

1. Open a file (whose name is at DS:0004)
2. Read 60 bytes of its MZ header into a buffer
3. Verify the file contains the "DM89" signature at the expected offset
4. Use DOS function 4Bh subfunction 01h (EXEC - Load) to load the program
5. Transfer control to the loaded program

### Embedded Strings

```
"DDESK.EXE"          -- the file it loads (note leading 'D' may be a length prefix)
"MOLDAPP.MOD"        -- likely "DMOLDAPP.MOD"
"INSTALL"            -- program self-identification
"Please change to the drive containing the DESKMATE 1 disk"
"before running install."
```

### Purpose

INSTALL.EXE is a **tiny bootstrap** that:
1. Validates that DESK.EXE is a legitimate DeskMate executable (checks for DM89 tag)
2. Uses DOS EXEC function 4Bh/01h to load DESK.EXE into memory
3. Transfers execution to the DeskMate shell

The MINALLOC=MAXALLOC design ensures INSTALL.EXE occupies minimal memory so that
DESK.EXE has maximum memory available when it is loaded.

### Segment Layout

| Segment | File Offset | Role |
|---------|-------------|------|
| 0x0000 | 0x0200 | CODE -- entry point and loader logic |
| 0x000A | 0x02A0 | DATA -- filename strings, parameter block |
| 0x0018 | 0x0380 | STACK (beyond EOF, allocated at load time) |

### Relocation Table (2 entries at offset 0x003C)

| # | Location | Notes |
|---|----------|-------|
| 0 | 000A:002B | In data segment |
| 1 | 0000:000D | In code segment (the `mov ax, 0x000A` -- patches segment value) |

---

## Cross-File Comparison

| Property | DESK.EXE | DMVID.EXE | INSTALL.EXE |
|----------|----------|-----------|-------------|
| File size | 19,047 | 16,477 | 828 |
| Load module size | 18,535 | 15,965 | 316 |
| Header size | 512 | 512 | 512 |
| Relocations | 33 | 4 | 2 |
| Stack size (SP) | 2,048 | 2,048 | 2,048 |
| DM89 tag | Yes | No | Yes |
| Compiler | Custom/ASM | Microsoft C 5.0 | Custom/ASM |
| Memory model | Multi-segment | Small | Tiny (3 segments) |
| MINALLOC | 69,280 bytes | 3,216 bytes | 1,936 bytes |
| MAXALLOC | ~1 MB | ~1 MB | 1,936 bytes (exact) |
| Entry pattern | Custom loader | MSC 5.x CRT | Chain loader |

## Key Findings

### 1. DM89 Header Extension Format

The DM89 tag is a DeskMate-specific identification marker embedded at offset 0x001C
in the MZ header (the space between the standard 28-byte MZ header and the relocation
table). INSTALL.EXE explicitly validates this tag before loading an EXE, confirming
it is a required signature for DeskMate executables.

Preliminary DM89 header structure (offset from file start):

```
0x001C: "DM89"     (4 bytes) Magic signature
0x0020: ????       (2 bytes) Unknown -- matches reloc table offset in both files
0x0022: 00 00 00 00 (4 bytes) Padding or reserved
0x0026: 00 00      (2 bytes) Padding or reserved
0x0028: ????       (2 bytes) Unknown -- 0x000E in DESK.EXE, 0x0000 in INSTALL.EXE
0x002A: ????       (2 bytes) Unknown -- 0x0405 in DESK.EXE (matches CS), 0x0000 in INSTALL.EXE
0x002C: ????       (2 bytes) Unknown -- 0x000B in DESK.EXE, 0x0000 in INSTALL.EXE
0x002E: ????       (2 bytes) Unknown -- 0x03F5 in DESK.EXE (matches a segment ref)
```

### 2. DESK.EXE Architecture

DESK.EXE is the DeskMate host shell. It is NOT compiled from C -- it uses a custom
multi-segment architecture with far call dispatching. The entry point initializes
multiple segments and invokes callbacks through far pointers, consistent with a
plugin/module loading framework. This is the host that loads .PDM applications.

Key infrastructure identified:
- Module loader (loads .PDM, .RES, .ACC files)
- Error handling system with user-facing messages
- Configuration file parser (AUTOLOAD.CFG, DESKTOP.CFG, DMCSR.CFG)
- Environment variable interface (DMCONFIG, COMSPEC, PATH, DMTASK1)
- Resource subsystem identifiers: DMCSR, DMEMM, DMDB, DMGUF

### 3. DMVID.EXE is a Standard C Program

DMVID.EXE is the only file built with a standard compiler (Microsoft C 5.0, 1987).
It is a standalone DOS utility for configuring the video adapter before DeskMate
launches. It supports 8 video modes including Tandy-specific modes. This is the
easiest target for C transpilation since it was originally compiled from C.

### 4. INSTALL.EXE is a Minimal Bootstrap

INSTALL.EXE is a tiny (316 bytes of code) chain loader that validates the DM89
signature in DESK.EXE and then loads it using DOS EXEC. It deliberately constrains
its own memory allocation to maximize space for the loaded program.

---

## Recommended Next Steps

1. **DMVID.EXE** -- Best candidate for first full disassembly and C transpilation.
   Being Microsoft C 5.0 small model, Ghidra should produce good results. The C
   runtime library functions will be recognizable. Target: identify `main()` and
   all application functions.

2. **DESK.EXE** -- Requires manual analysis. Map out the far call dispatch table,
   the module loading mechanism, and the DM89 header validation. Start with the
   segment at 0x033B (the first far call target from the entry point).

3. **DM89 Format** -- Analyze .PDM files to determine if they also use the DM89
   header extension. Compare the header structures to build a complete specification.

4. **INSTALL.EXE** -- Fully document as a reference for the DM89 validation
   algorithm. Its small size makes complete annotation straightforward.
