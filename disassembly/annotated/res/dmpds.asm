; ========================================================================
; DMPDS.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPDS.RES is the Epson/Dot-Matrix Standard printer driver for
; DeskMate 3.05. This is the largest printer driver, supporting a
; wide range of Epson and IBM-compatible 24-pin dot-matrix printers
; with color support:
;
;   - Epson LQ-2550 and compatible
;   - IBM Proprinter X24 / X24 Compatible (AGM Mode)
;   - IBM Proprinter XL24 / XL24 Compatible (AGM Mode)
;   - Tandy DMP 2102, 2103 (AGM Mode)
;   - Tandy DMP 240 (Epson Mode)
;   - Tandy DMP 300, 302 (AGM Mode)
;
; Color printing modes supported:
;   IBM B/W, IBM Gray, IBM 4-Color, IBM 8-Color, IBM 22-Color
;   EPSON B/W, EPSON Gray, EPSON 4-Color, EPSON Color, EPSON 22-Color
;
; The driver contains extensive font bitmap data (~14KB) for 24-pin
; graphics printing at high resolution, plus color dithering patterns
; for simulating additional colors from the 4 CMYK ribbon colors.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 29,455 bytes
; Load image: 28,943 bytes (after header)
; DM89 entry point: 0000:3BD2
; SS:SP = 0AB8:0002
; Min/Max alloc: 0x039A paragraphs (14,880 bytes extra)
;
; Segment Map (5 segments, 12 relocations):
;   seg_0000  0x03860 bytes  DATA   Version "58.47", printer font bitmaps
;                                   (24-pin high-res), color dither patterns,
;                                   character width tables, printer config
;   seg_0386  0x035F0 bytes  CODE   Print engine: 24-pin graphics, color
;                                   mixing, page layout, ESC/P commands
;   seg_06E5  0x03D30 bytes  DATA   DM89 header "DMPDS", printer name
;                                   strings, DMCSR reference, config data
;   seg_0AB8  BSS                   Stack
;   seg_0AB9  BSS                   Runtime state (large: color buffers)
;
; ========================================================================
; FUNCTION INDEX (seg_0386 - Print Engine)
; ========================================================================
;
; Address       Name                        Description
; -------       ----                        -----------
; 0386:0003     dmpds_printPageSetup        Set up page (24-pin graphics mode)
; 0386:00BC     dmpds_printPageTeardown     End page, form feed
; 0386:0266     dmpds_printBitmapLine       Print one bitmap line (24-pin)
; 0386:034D     dmpds_initDriver            Initialize driver, load config
; 0386:036C     dmpds_loadFontData          Load 24-pin font bitmap data
; 0386:0555     dmpds_configPrinter         Configure printer model params
; 0386:0597     dmpds_allocStateBuffer      Allocate large state buffer
; 0386:05AB     dmpds_setGraphicsMode       Enter 24-pin graphics mode
; 0386:0608     dmpds_renderCharacter       Render character in 24-pin bitmap
; 0386:06F7     dmpds_sendGraphicsData      Send graphics data block to printer
; 0386:0760     dmpds_colorMixSetup         Set up color mixing/dithering
; 0386:0797     dmpds_selectColorRibbon     Select ribbon color (CMYK)
; 0386:082F     dmpds_sendEscpCommand       Send ESC/P printer command
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 17h     - BIOS Printer Services
;
; ESC/P Printer Commands (Epson standard):
;   ESC '@'     - Initialize printer
;   ESC '*' n   - Select bit-image graphics mode
;   ESC 'r' n   - Select color (0=black, 1=magenta, 2=cyan, 3=yellow)
;   ESC 'k' n   - Select typeface
;   CR/LF       - Carriage return, line feed
;   FF          - Form feed
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Font/config data (14,432 bytes)
; seg_0386: Print engine code (13,808 bytes)
; seg_06E5: Module header + strings (15,664 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpds.asm for complete byte-level listing]
