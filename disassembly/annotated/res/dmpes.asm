; ========================================================================
; DMPES.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPES.RES is the Epson Standard Print Engine for DeskMate 3.05.
; It provides the graphics rendering pipeline for the DMPDS printer
; driver (Epson LQ-2550, IBM Proprinter X24, Tandy DMP 240/300/2102).
;
; Version: "01.07"
; Companion driver: DMPDS
;
; This engine renders 24-pin graphics strips for high-quality
; dot-matrix output with optional color support. The rendering
; pipeline produces ESC/P compatible bitmap data. Key differences
; from the 9-pin engines (DMPE1/DMPE2):
;   - 24-pin vertical resolution (24 dots per pass vs 9)
;   - Color plane separation for CMYK ribbon
;   - Higher horizontal resolution modes
;
; The fill byte for blank areas is 0x88 (vs 0xFF for IBM mode or
; 0xAA for other modes), as indicated by the initialization code.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 3,186 bytes
; Load image: 2,674 bytes (after header)
; DM89 entry point: 009D:0052
; SS:SP = 00A7:0002
;
; Segment Map (3 segments, 4 relocations):
;   seg_0000  2,512 bytes  CODE   Print rendering engine (24-pin)
;   seg_009D  160 bytes    CODE   DM89 registration "DMPES",
;                                 version "01.07", DMPDS reference
;   seg_00A7  variable     DATA   Module header data
;
; ========================================================================
; FUNCTION INDEX (seg_0000 - Rendering Engine)
; ========================================================================
;
; (Same general function layout as DMPEIBMM but adapted for 24-pin
;  Epson-compatible output. See dmpeibmm.asm for function template.)
;
; Key differences:
;   - 24-pin strip height (3 bytes per column vs 1)
;   - Color plane rendering for CMYK support
;   - ESC/P raster data format
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Rendering engine code (2,512 bytes)
; seg_009D: Module header (160 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpes.asm for complete byte-level listing]
