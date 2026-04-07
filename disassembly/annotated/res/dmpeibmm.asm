; ========================================================================
; DMPEIBMM.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPEIBMM.RES is the IBM Graphics Print Engine for DeskMate 3.05.
; It provides the graphics rendering pipeline for the DMPDIBMM printer
; driver (IBM Graphics Printer, Tandy DMP 130/440 IBM mode).
;
; Version: "01.08"
; Companion driver: DMPDIBMM
;
; This engine renders formatted text and graphics into bitmap strips
; compatible with 9-pin IBM graphics mode printing. It handles:
;   - Character bitmap rendering from embedded font data
;   - Proportional spacing calculations
;   - Margin enforcement and page clipping
;   - Multi-pass bold/emphasized rendering
;   - Line/box/rule drawing for forms
;   - Scaling between screen and print resolutions
;
; The engine is slightly smaller than DMPE1/DMPE2 since the IBM
; graphics mode has fewer resolution options.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 3,090 bytes
; Load image: 2,578 bytes (after header)
; DM89 entry point: 0097:0055
; SS:SP = 00A1:0002
;
; Segment Map (3 segments, 4 relocations):
;   seg_0000  2,416 bytes  CODE   Print rendering engine - character
;                                 bitmap lookup, strip assembly,
;                                 proportional spacing, margin handling
;   seg_0097  160 bytes    CODE   DM89 registration "DMPEIBMM",
;                                 version "01.08", DMPDIBMM reference
;   seg_00A1  variable     DATA   Module header data
;
; ========================================================================
; FUNCTION INDEX (seg_0000 - Rendering Engine)
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmpeibmm_renderLine           Main line render: build bitmap strip
; 0000:039A   dmpeibmm_renderBold           Bold rendering pass (double-strike)
; 0000:0419   dmpeibmm_handleTabStop        Process tab stop positioning
; 0000:0524   dmpeibmm_renderGraphicsBlock  Render graphics block to strip buffer
; 0000:060F   dmpeibmm_processAttribute     Process text attribute (bold/underline)
; 0000:0676   dmpeibmm_calculateWidth       Calculate character advance width
; 0000:071B   dmpeibmm_renderCharBitmap     Render single character from font
; 0000:07B2   dmpeibmm_finalizeLine         Finalize bitmap strip for output
; 0000:0926   dmpeibmm_scaleCoordinate      Scale screen coordinate to print res
;
; 0097:0055   dmpeibmm_tsrEntry             Entry: register with DM89, go TSR
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Rendering engine code (2,416 bytes)
; seg_0097: Module header (160 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpeibmm.asm for complete byte-level listing]
