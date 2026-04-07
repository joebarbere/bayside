; ========================================================================
; DMPDIBMM.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPDIBMM.RES is the IBM Graphics Printer driver for DeskMate 3.05,
; supporting IBM-compatible 9-pin dot-matrix printers in IBM graphics
; mode:
;
;   - IBM Graphics Printer and compatibles
;   - Tandy DMP 130 IBM mode
;   - Tandy DMP 440 IBM mode
;
; This driver uses the IBM-specific escape sequences for graphics
; printing (ESC 'K', ESC 'L', ESC 'Y', ESC 'Z' for different
; density modes) rather than the Epson ESC/P command set.
;
; Contains the same font bitmap data layout as DMPD1/DMPD2 (9-pin
; compatible glyphs) but with IBM-specific control codes.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 18,886 bytes
; Load image: 18,374 bytes (after header)
; DM89 entry point: 0000:15A9
; SS:SP = 050B:0002
; Min/Max alloc: 0x008D paragraphs
;
; Segment Map (5 segments, 12 relocations):
;   seg_0000  0x01250 bytes  DATA   Version "58.36", font bitmaps,
;                                   "IBM GRAPHIC", "DMP 130 IBM",
;                                   "DMP 440 IBM" model names
;   seg_0125  0x033C0 bytes  CODE   Print engine (IBM graphics mode)
;   seg_0461  0x00AA0 bytes  DATA   DM89 header "DMPDIBMM", model
;                                   names, DMCSR reference
;   seg_050B  BSS                   Stack
;   seg_050C  BSS                   Runtime state
;
; ========================================================================
; FUNCTION INDEX (seg_0125 - Print Engine)
; ========================================================================
;
; (Same general function layout as DMPD1 print engine, adapted for
;  IBM graphics escape sequences. See dmpd1.asm for function template.)
;
; Key differences from Epson drivers:
;   - Uses IBM graphics density modes (ESC K/L/Y/Z) instead of ESC *
;   - Different line spacing commands
;   - IBM-specific page formatting
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 17h     - BIOS Printer Services
;
; IBM Graphics Escape Sequences:
;   ESC 'K' n1 n2  - Single-density graphics (480 dots/line)
;   ESC 'L' n1 n2  - Double-density graphics (960 dots/line)
;   ESC 'Y' n1 n2  - Hi-speed double-density
;   ESC 'Z' n1 n2  - Quadruple-density
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Font/config data (4,688 bytes)
; seg_0125: Print engine code (13,248 bytes)
; seg_0461: Module header + strings (2,720 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpdibmm.asm for complete byte-level listing]
