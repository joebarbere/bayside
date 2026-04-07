; ========================================================================
; DMPD2.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPD2.RES is Printer Driver #2 for DeskMate 3.05, supporting the
; Tandy DMP 200 dot-matrix printer.
;
; Structurally identical to DMPD1.RES (same code size, same segment
; layout, same number of relocations). The only differences are:
;   - Printer model name: "DMP 200    " (vs "DMP 105/106")
;   - Different printer-specific escape sequences and configuration
;   - Different character width/spacing tables for DMP 200 capabilities
;
; The DMP 200 was a wider-carriage variant with additional graphics
; modes and higher resolution bit-image printing.
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
; Min/Max alloc: 0x0052 paragraphs
;
; Segment Map (5 segments, 12 relocations):
;   seg_0000  0x012C0 bytes  DATA   Printer font bitmaps (identical layout to DMPD1)
;   seg_012C  0x02EC0 bytes  CODE   Print engine (shared codebase with DMPD1)
;   seg_0418  0x00780 bytes  DATA   DM89 header, "DMP 200" model strings
;   seg_0490  BSS                   Stack
;   seg_0491  BSS                   Runtime state
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; (Same function layout as DMPD1.RES - see dmpd1.asm for full index)
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 17h     - BIOS Printer Services (same as DMPD1)
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpd2.asm for complete byte-level listing]
