; ========================================================================
; DMPDLASR.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPDLASR.RES is the HP LaserJet printer driver for DeskMate 3.05,
; supporting laser printers that understand HP PCL (Printer Command
; Language):
;
;   - HP LaserJet and LaserJet Compatible
;   - Tandy LP 1000 (HP Mode)
;   - Tandy LP 950 (HP Mode)
;
; This driver generates PCL escape sequences for page layout,
; font selection, and raster graphics output. It supports both
; portrait and landscape orientations with multiple pitch settings.
;
; PCL escape sequences found in the binary:
;   (s10H, (s12H, (s16.67H  - Select pitch (10, 12, 16.67 CPI)
;   &k10H, &k.8H             - Line spacing
;   &l.32C                    - Vertical motion index
;   &l1O / &l0O               - Landscape / Portrait orientation
;   &l0E                      - Top margin
;   &a0L                      - Left margin
;   &l51F / &l66F             - Form length (51 or 66 lines)
;   *r1A                      - Start raster graphics
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 19,228 bytes
; Load image: 18,716 bytes (after header)
; DM89 entry point: 0000:180C
; SS:SP = 058C:0002
; Min/Max alloc: 0x00EE paragraphs
;
; Segment Map (5 segments, 11 relocations):
;   seg_0000  0x014C0 bytes  DATA   Version "58.39", font bitmaps,
;                                   "LASERJET" model name, PCL escape
;                                   sequence strings
;   seg_014C  0x03270 bytes  CODE   Print engine (PCL output)
;   seg_0473  0x01190 bytes  DATA   DM89 header "DMPDLASR", model
;                                   names, DMCSR reference
;   seg_058C  BSS                   Stack
;   seg_058D  BSS                   Runtime state (raster buffer)
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 17h     - BIOS Printer Services
;
; HP PCL Escape Sequences:
;   ESC '(' 's' nn 'H'   - Select pitch (characters per inch)
;   ESC '&' 'l' nn 'O'   - Select orientation
;   ESC '&' 'l' nn 'E'   - Set top margin
;   ESC '&' 'l' nn 'F'   - Set form length
;   ESC '&' 'a' nn 'L'   - Set left margin
;   ESC '*' 'r' '1' 'A'  - Start raster graphics
;   ESC '*' 'r' 'B'      - End raster graphics
;   ESC '*' 'b' nn 'W'   - Transfer raster data
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Font/config/PCL data (5,312 bytes)
; seg_014C: Print engine code (12,912 bytes)
; seg_0473: Module header (4,512 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpdlasr.asm for complete byte-level listing]
