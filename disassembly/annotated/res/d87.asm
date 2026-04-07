; ========================================================================
; D87.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; D87.RES is the 8087 Floating-Point Coprocessor Support Module for
; DeskMate 3.05. It provides floating-point emulation or coprocessor
; detection services for applications that need math operations
; (primarily the Worksheet spreadsheet, WRKSHEET.PDM).
;
; This is a very small module (856 bytes total, 344 bytes of code+data)
; that acts as a compatibility shim. It:
;   1. Registers with the DM89 host via INT E0h
;   2. Checks for the presence of an 8087/80287 coprocessor
;   3. If no coprocessor is found, loads the DMCSR cursor/screen
;      driver and may display a compatibility message
;   4. Terminates and stays resident (TSR) to provide the "D87"
;      service name to other modules that query for FP support
;
; The module name "D87" follows the naming convention of the Intel
; 8087 coprocessor. DeskMate applications can check for this module
; to determine whether floating-point operations are available.
;
; Module name: "D87"
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
; File size: 856 bytes
; Load image: 344 bytes (after header)
; DM89 entry point: 0000:0000
; SS:SP = 0016:0002
;
; Segment Map (3 segments, 3 relocations):
;   seg_0000  240 bytes  CODE   Entry, 8087 detection, DMCSR load,
;                               import registration
;   seg_000F  104 bytes  DATA   Module header "D87", import names
;                               (PRGUF, DMGUF, DMCSR), video mode
;                               compatibility table
;   seg_0016  BSS               Stack + runtime state
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   d87_entryPoint                DM89 entry: set DS, register, detect FPU
; 0000:003B   d87_detect8087                Detect 8087 coprocessor presence
; 0000:0068   d87_loadImport                Load a DM89 import by name
; 0000:0090   d87_loadDMCSR                 Load DMCSR cursor/screen driver
; 0000:00A0   d87_unloadImport              Unload a DM89 import
; 0000:00B4   d87_registerModule            Register with PRGUF/DMGUF
; 0000:00C6   d87_queryHostInfo             Query DM89 host information
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Module State (seg_000F data area):
;   [0x00] module_header    - DM89 module header "D87"
;   [0x0A] host_segment     - DM89 host segment (ES at entry)
;   [0x20] dispatch_table   - Function dispatch table
;   [0x40] prguf_name       - "PRGUF" import name
;   [0x46] dmguf_name       - "DMGUF" import name
;   [0x4C] dmcsr_name       - "DMCSR" import name
;   [0x52] video_modes      - Video mode compatibility strings
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; 8087 Coprocessor Detection:
;   FNINIT            - Initialize 8087 (no-wait form)
;   FNSTCW [mem]      - Store 8087 control word to memory
;   Check if control word == 0x03FF (default after FNINIT)
;   to confirm 8087 presence
;
; INT 21h/31h - TSR (terminate and stay resident)
;
; INT E0h - DM89 Host API
;   AH=01h - Register module
;   AH=02h, AL=06h - Load import by name
;   AH=02h, AL=07h - Unload import
;   AH=06h, AL=00h - Query host information
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Entry + FPU detection code (240 bytes)
; seg_000F: Module header + strings (104 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/d87.asm for complete byte-level listing]
