; ========================================================================
; DMPE1.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPE1.RES is Print Engine #1 for DeskMate 3.05. It provides the
; graphics rendering pipeline for printer driver DMPD1 (DMP 105/106).
;
; The print engine converts screen-resolution graphics and formatted
; text into printer-resolution bitmap data suitable for 9-pin dot-matrix
; output. It handles:
;   - Scaling screen coordinates to printer resolution
;   - Character rendering from font bitmap data
;   - Line/box drawing for forms and tables
;   - Margin and page boundary enforcement
;   - Multi-pass printing for bold/emphasized effects
;
; The engine uses a frame buffer approach, building each print line
; as a bitmap strip before sending it to the printer via the
; corresponding DMPD driver.
;
; The font bitmap data (seg_0000, ~4.4KB) contains the same glyph
; library as DMPD1 -- standard ASCII, international chars, and
; line-drawing characters suitable for 9-pin output.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5,138 bytes
; Load image: 4,626 bytes (after header)
; DM89 entry point: 0117:0052
; SS:SP = 0121:0002
;
; Segment Map (3 segments, 4 relocations):
;   seg_0000  0x01170 bytes  DATA   Font bitmaps for 9-pin rendering
;   seg_0117  0x000A0 bytes  CODE   DM89 registration, entry point,
;                                   engine dispatch
;   seg_0121  variable       DATA   Module header, DMPD1 reference
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0117:0052   dmpe1_tsrEntry               Entry: register with DM89, go TSR
; 0117:0044   dmpe1_engineDispatch         Graphics engine API dispatcher
; 0117:006C   dmpe1_renderCallback         Render callback from DMPD1
;
; (Internal rendering functions are embedded in the font data segment
;  as inline routines called via the dispatch table.)
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; No direct hardware I/O -- this module renders to memory buffers
; that DMPD1 then sends to the printer via INT 17h.
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Font bitmap data (4,464 bytes)
; seg_0117: Engine dispatch code (160 bytes)
; seg_0121: Module header
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpe1.asm for complete byte-level listing]
