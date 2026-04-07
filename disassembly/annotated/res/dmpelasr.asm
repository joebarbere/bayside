; ========================================================================
; DMPELASR.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPELASR.RES is the LaserJet Print Engine for DeskMate 3.05.
; It provides the graphics rendering pipeline for the DMPDLASR printer
; driver (HP LaserJet, Tandy LP 950/1000).
;
; This engine renders at higher resolution than the dot-matrix engines,
; generating 300 DPI raster data suitable for PCL raster transfer
; commands. It includes the same font bitmap library as the dot-matrix
; engines but at higher resolution for crisp laser output.
;
; The engine handles:
;   - High-resolution character rendering (300 DPI)
;   - Full-page raster image assembly
;   - PCL-compatible raster strip formatting
;   - Landscape and portrait rendering paths
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5,330 bytes
; Load image: 4,818 bytes (after header)
; DM89 entry point: 0123:0055
; SS:SP = 012D:0002
;
; Segment Map (3 segments, 4 relocations):
;   seg_0000  0x01230 bytes  DATA   Font bitmaps (laser resolution)
;   seg_0123  0x000A0 bytes  CODE   DM89 registration, entry, dispatch
;   seg_012D  variable       DATA   Module header, DMPDLASR reference
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; 0123:0055   dmpelasr_tsrEntry            Entry: register with DM89, go TSR
; 0123:0047   dmpelasr_engineDispatch      Rendering engine API dispatcher
; 0123:006F   dmpelasr_renderCallback      Render callback from DMPDLASR
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Font bitmap data (4,656 bytes)
; seg_0123: Engine dispatch code (160 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpelasr.asm for complete byte-level listing]
