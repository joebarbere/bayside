; ========================================================================
; DMPD1.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPD1.RES is the Printer Driver #1 for DeskMate 3.05, supporting the
; Tandy DMP 105/106 dot-matrix printers.
;
; This is a large driver containing:
;   - Printer font bitmaps (the bulk of seg_0000, ~5KB of glyph data)
;     including full ASCII character set, international characters,
;     and graphics line-drawing characters at multiple sizes
;   - Print engine code in seg_012C for formatting pages, handling
;     bold/italic/underline, sending escape sequences
;   - Printer configuration data (margins, pitch, spacing)
;   - DM89 module header and registration in seg_0418
;
; Printer names (from string table):
;   "DMP 105/106" - Tandy DMP 105 and DMP 106 dot-matrix printers
;
; The printer font data occupies the first ~5.6KB and contains bitmap
; representations of characters for direct bit-image printing mode.
; Font data strings like "$BBB$", "<B@@@B<", "DDD|DDD" etc. are
; 7-row bitmap patterns for individual glyphs.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 17,692 bytes
; Load image: 17,180 bytes (after header)
; DM89 entry point: 0000:161B
; SS:SP = 0490:0002
; Min/Max alloc: 0x0052 paragraphs (1,312 bytes extra)
;
; Segment Map (5 segments, 12 relocations):
;   seg_0000  0x012C0 bytes  DATA   Printer font bitmaps (multiple sizes),
;                                   character width tables, escape sequences,
;                                   printer model names "DMP 105/106"
;   seg_012C  0x02EC0 bytes  CODE   Print engine: page layout, character
;                                   rendering, bold/italic/underline, ESC
;                                   sequence generation, INT 17h output
;   seg_0418  0x00780 bytes  DATA   DM89 module header, DMCSR reference,
;                                   printer name strings, configuration
;   seg_0490  BSS                   Stack segment
;   seg_0491  BSS                   Runtime state buffer
;
; ========================================================================
; FUNCTION INDEX (seg_012C - Print Engine)
; ========================================================================
;
; Address       Name                        Description
; -------       ----                        -----------
; 012C:0005     dmpd1_printPageSetup        Set up page parameters (margins, pitch)
; 012C:00BC     dmpd1_printPageTeardown     End page, send form feed
; 012C:0336     dmpd1_initDriver            Initialize driver, load config
; 012C:0355     dmpd1_loadFontData          Load font bitmap data pointer
; 012C:03BB     dmpd1_configPrinter         Configure printer model parameters
; 012C:03FD     dmpd1_allocStateBuffer      Allocate runtime state buffer
; 012C:0411     dmpd1_setGraphicsMode       Enter graphics (bit-image) print mode
;
; (Print engine contains ~50+ additional internal routines for
;  character rendering, escape sequence output, line spacing, etc.
;  See raw disassembly for complete function listing.)
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 17h     - BIOS Printer Services
;   AH=00h   - Print character in AL to printer DX
;   AH=01h   - Initialize printer port DX
;   AH=02h   - Get printer status for port DX
;
; Printer Escape Sequences (DMP 105/106 Tandy mode):
;   ESC 'E'  - Select emphasized (bold) mode
;   ESC 'F'  - Cancel emphasized mode
;   ESC '-' 1 - Select underline mode
;   ESC '-' 0 - Cancel underline mode
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Font Bitmap Format (seg_0000):
;   Each character glyph is stored as 7 bytes (7 rows of 8 pixels).
;   Characters are organized by code page position (0x20-0xFF).
;   Multiple font sizes: standard (7x8), compressed (5x7), graphics.
;
; Printer Config (seg_0418 data area):
;   - Model identification strings
;   - Default margins (left, right, top, bottom)
;   - Characters per inch settings
;   - Graphics resolution parameters
;   - Escape sequence tables for mode switching
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Font bitmap data (4,800 bytes)
; seg_012C: Print engine code (11,968 bytes)
; seg_0418: Module header + config (1,920 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpd1.asm for complete byte-level listing]
