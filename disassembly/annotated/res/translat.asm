; ========================================================================
; TRANSLAT.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; TRANSLAT.RES is the Character Set Translation module for DeskMate 3.05.
; It provides character set mapping and translation services for the
; word processor (TEXT.PDM) and potentially other modules that need to
; convert between different character encodings (e.g., OEM/ANSI,
; international character sets, printer-specific encodings).
;
; Like DICTARY.RES and DMTHES.RES, this module is a stub/loader that
; displays the message:
;   "See your store or dealer for more information on obtaining
;    this program."
; indicating the full translation tables were sold separately as an
; add-on for DeskMate 3.05, likely for international language support.
;
; The code structure is nearly identical to DICTARY.RES:
;   - Same file size (1,586 bytes)
;   - Same segment layout (3 segments, 8 relocations)
;   - Same import pattern (PRGUF, DMGUF, DMCSR)
;   - Same callback/dispatch API design
;   - Only the module name and display name differ
;
; Module name: "TRANSLAT"
; Display name: "Translation"
;
; DM89 imports: PRGUF, DMGUF, DMCSR
; Supported video modes: 1000, CGA, DDGA, EGA, HERC, PLAN, TC16, TC4,
;                        VGA, MCGA, LRES, T256, TC40, H
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 1,586 bytes
; Load image: 1,074 bytes (after header)
; DM89 entry point: 0000:0026
; SS:SP = 0044:0002
;
; Segment Map (3 segments, 8 relocations):
;   seg_0000  816 bytes  CODE   Translation API: init, translate,
;                               result dispatch, far-call stubs
;   seg_0033  258 bytes  DATA   Module header "TRANSLAT",
;                               "Translation" display name,
;                               purchase message string,
;                               PRGUF/DMGUF/DMCSR imports,
;                               video mode compatibility table
;   seg_0044  BSS               Runtime state
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0002   translat_init                 Initialize: load imports, open data
; 0000:0026   translat_entryPoint           DM89 entry: set DS, register, call init
; 0000:004B   translat_loadImport           Load a DM89 import by name
; 0000:0073   translat_loadAlternateImport  Load alternate import location
; 0000:0089   translat_setCallbackPtrs      Set up callback function pointers
; 0000:00AE   translat_openDataFile         Open translation data file
; 0000:00F0   translat_closeDataFile        Close translation data file
; 0000:0110   translat_translateStub1       Translate stub (returns -1 if no data)
; 0000:0118   translat_translateStub2       Translate stub (returns -1 if no data)
; 0000:0120   translat_dispatchTranslate    Dispatch translation request
; 0000:015C   translat_dispatchResult       Dispatch result callback
; 0000:0199   translat_registerImports      Register with PRGUF/DMGUF
; 0000:01B2   translat_unregisterImports    Unregister imports on cleanup
; 0000:01CF   translat_callbackHandler      Generic callback handler
; 0000:0203   translat_displayTranslation   Display translation result
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Module State (seg_0033/seg_0044):
;   (Same layout as DICTARY.RES -- see dictary.asm for full documentation.
;    All offsets and field meanings are identical; only module name and
;    display strings differ.)
;
;   [0x0A] host_segment    - DM89 host segment (ES at entry)
;   [0x8A] callback_off    - Callback function offset
;   [0x8C] callback_seg    - Callback function segment
;   [0x8E] import_name_ptr - Import name string pointer
;   [0x94] func_ptr_off    - Function pointer (offset)
;   [0x96] func_ptr_seg    - Function pointer (segment)
;   [0x9E] data_loaded     - Translation data loaded flag (0 or 1)
;   [0xA8] prguf_handle    - PRGUF import handle
;   [0xAC] dmguf_handle    - DMGUF import handle
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Translation API code (816 bytes)
; seg_0033: Module header + strings (258 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/translat.asm for complete byte-level listing]
