; ========================================================================
; DMTHES.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMTHES.RES is the Thesaurus accessory module for DeskMate 3.05.
; It provides synonym/antonym lookup functionality for the word
; processor (TEXT.PDM), similar to the Dictionary module.
;
; Like DICTARY.RES, this is a stub/loader that displays:
;   "See your store or dealer for more information on obtaining
;    this program."
; indicating the thesaurus was sold separately.
;
; The code structure is nearly identical to DICTARY.RES, with the
; same import pattern (PRGUF, DMGUF, DMCSR) and the same
; lookup/callback API design. The only differences are:
;   - Module name: "DMTHES" (vs "DICTARY")
;   - Display name: "Thesaurus" (vs "Dictionary")
;   - References its own data file ("DMTHES" import)
;   - Different function pointer offsets for thesaurus results
;
; Module name: "DMTHES"
; Display name: "Thesaurus"
;
; DM89 imports: PRGUF, DMGUF, DMCSR, DMTHES (self-reference)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 1,704 bytes
; Load image: 1,192 bytes (after header)
; DM89 entry point: 0000:002B
; SS:SP = 004C:0002
;
; Segment Map (4 segments, 11 relocations):
;   seg_0000  928 bytes  CODE   Thesaurus API (same structure as DICTARY)
;   seg_003A  264 bytes  DATA   Module header "DMTHES", "Thesaurus",
;                               purchase message, imports, video modes
;   seg_004C  BSS               Stack
;   seg_004D  BSS               Runtime state
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; (Same function layout as DICTARY.RES - see dictary.asm for full index.
;  All functions use "dmthes_" prefix instead of "dictary_".)
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Thesaurus API code (928 bytes)
; seg_003A: Module header + strings (264 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmthes.asm for complete byte-level listing]
