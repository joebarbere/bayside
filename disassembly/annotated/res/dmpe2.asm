; ========================================================================
; DMPE2.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPE2.RES is Print Engine #2 for DeskMate 3.05. It provides the
; graphics rendering pipeline for printer driver DMPD2 (DMP 200).
;
; Structurally identical to DMPE1.RES (same file size, same segment
; layout, same code). The only difference is the DM89 module header
; which references DMPD2 instead of DMPD1 as its companion driver.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5,138 bytes (identical to DMPE1)
; Load image: 4,626 bytes
; DM89 entry point: 0117:0052
; SS:SP = 0121:0002
;
; Segment Map (3 segments, 4 relocations):
;   seg_0000  0x01170 bytes  DATA   Font bitmaps (identical to DMPE1)
;   seg_0117  0x000A0 bytes  CODE   DM89 registration + dispatch
;   seg_0121  variable       DATA   Module header, DMPD2 reference
;
; ========================================================================
; (See dmpe1.asm for full function index - identical code)
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpe2.asm for complete byte-level listing]
