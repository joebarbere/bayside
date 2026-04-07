; ========================================================================
; DICTARY.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DICTARY.RES is the Dictionary accessory module for DeskMate 3.05.
; It provides word lookup functionality for the spell-check system,
; acting as the interface between the DeskMate host and the dictionary
; data files.
;
; The module is a stub/loader that displays the message:
;   "See your store or dealer for more information on obtaining
;    this program."
; indicating that the full dictionary was sold separately as an
; add-on accessory for DeskMate 3.05.
;
; When loaded, the module:
;   1. Registers with DM89 host via INT E0h
;   2. Attempts to locate PRGUF and DMGUF imports
;   3. Loads DMCSR (cursor/screen driver)
;   4. If the dictionary data is not found, displays the
;      "See your store or dealer..." message
;   5. If present, provides word lookup via far-call API
;
; Module name: "DICTARY"
; Display name: "Dictionary"
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
;   seg_0000  816 bytes  CODE   Dictionary API: init, lookup,
;                               result dispatch, far-call stubs
;   seg_0033  258 bytes  DATA   Module header "DICTARY",
;                               "Dictionary" display name,
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
; 0000:0002   dictary_init                  Initialize: load imports, open dict
; 0000:0026   dictary_entryPoint            DM89 entry: set DS, register, call init
; 0000:004B   dictary_loadImport            Load a DM89 import by name
; 0000:0073   dictary_loadAlternateImport   Load alternate import location
; 0000:0089   dictary_setCallbackPtrs       Set up callback function pointers
; 0000:00AE   dictary_openDictFile          Open dictionary data file
; 0000:00F0   dictary_closeDictFile         Close dictionary data file
; 0000:0110   dictary_lookupStub1           Lookup stub (returns -1 if no dict)
; 0000:0118   dictary_lookupStub2           Lookup stub (returns -1 if no dict)
; 0000:0120   dictary_dispatchLookup        Dispatch word lookup request
; 0000:015C   dictary_dispatchResult        Dispatch result callback
; 0000:0199   dictary_registerImports       Register with PRGUF/DMGUF
; 0000:01B2   dictary_unregisterImports     Unregister imports on cleanup
; 0000:01CF   dictary_callbackHandler       Generic callback handler
; 0000:0203   dictary_displayLookup         Display lookup result
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Module State (seg_0033/seg_0044):
;   [0x0A] host_segment    - DM89 host segment (ES at entry)
;   [0x8A] callback_off    - Callback function offset
;   [0x8C] callback_seg    - Callback function segment
;   [0x8E] import_name_ptr - Import name string pointer
;   [0x94] func_ptr_off    - Function pointer (offset)
;   [0x96] func_ptr_seg    - Function pointer (segment)
;   [0x98] alt_import_name - Alternate import name ptr
;   [0x9E] dict_loaded     - Dictionary loaded flag (0 or 1)
;   [0xA8] prguf_handle    - PRGUF import handle
;   [0xAC] dmguf_handle    - DMGUF import handle
;   [0xB2] result_word     - Last lookup result word
;   [0xB4] version_flags   - Version/capability flags
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Dictionary API code (816 bytes)
; seg_0033: Module header + strings (258 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dictary.asm for complete byte-level listing]
