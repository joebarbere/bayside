; ========================================================================
; DMMDP.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMMDP.RES is the MIDI Port driver for DeskMate 3.05.
; It interfaces with a PS/2-style pointing device (mouse) via the
; INT 15h/C2xxh PS/2 pointing device BIOS interface, translating
; mouse movement and button events into DeskMate-compatible input
; events.
;
; The driver first checks BIOS equipment flags at 0040:0010 for a
; PS/2-style mouse (bit 2). If present, it initializes the pointing
; device via INT 15h/C205h (set resolution to 3 = 8 counts/mm),
; then registers with DM89 and goes TSR.
;
; Despite the "MIDI port" name, this driver handles PS/2 mouse input
; rather than MIDI musical instrument communication. The "MDP" likely
; stands for "Mouse/Device Port" in the DeskMate naming convention.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 1,493 bytes
; Load image: 981 bytes (after header)
; DM89 entry point: 002B:00DA
; SS:SP = 003E:0002
;
; Segment Map (3 segments, 6 relocations):
;   seg_0000  688 bytes  CODE/DATA  Mouse input processing, axis scaling,
;                                   button state tracking, callbacks
;   seg_002B  293 bytes  CODE/DATA  Module header ("DMMDP"), DM89
;                                   registration, ISR wrappers, entry
;   seg_003E  BSS                   Runtime state variables
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmmdp_apiDispatch             API entry - routes by function code in AL
;                                           AL=00: Init (zero state, set defaults)
;                                           AL=03: Get mouse parameters
;                                           AL=07: Set X-axis callback
;                                           AL=08: Set Y-axis callback + enable
;                                           AL=0C: Set button callback (far ptr)
;                                           AL=0F: Set both axes simultaneously
; 0000:00BF   dmmdp_scaleAxis               Scale raw axis delta to calibrated range
; 0000:00E8   dmmdp_pollMouse               Main polling: read deltas, detect button changes
; 0000:01A2   dmmdp_initPS2Device           Init PS/2 mouse via INT 15h/C2xxh BIOS calls
; 0000:0212   dmmdp_saveVectors             Save original INT 33h vector, install handler
;
; 002B:006F   dmmdp_irqHandler              Hardware IRQ handler for mouse events
; 002B:0093   dmmdp_int15Callback           INT 15h callback - receives PS/2 data packets
; 002B:00A5   dmmdp_apiCallHandler          Far-call API handler (DM89 dispatch)
; 002B:00DA   dmmdp_tsrEntry                Entry: check PS/2 mouse, register, go TSR
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 15h/C2xxh - PS/2 Pointing Device BIOS Interface
;   AH=C2h, AL=00h: Enable/disable pointing device
;   AH=C2h, AL=01h: Reset pointing device
;   AH=C2h, AL=02h: Set sample rate
;   AH=C2h, AL=03h: Set resolution (BH=resolution code)
;   AH=C2h, AL=05h: Initialize pointing device (BH=data package size)
;   AH=C2h, AL=06h: Get status/set scaling
;   AH=C2h, AL=07h: Set device handler address
;
; BIOS Data Area 0040:0010h - Equipment flags (bit 2 = PS/2 mouse)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Mouse State (seg_0000 data area):
;   [0x03] x_position      - Current X position (word)
;   [0x05] y_position      - Current Y position (word)
;   [0x08] x_min           - X-axis minimum bound
;   [0x0A] x_max           - X-axis maximum bound (default 100)
;   [0x0D] y_min_default   - Y minimum default (8)
;   [0x0F] x_range         - X range value (default 0x64)
;   [0x11] y_range         - Y range value (default 0x64)
;   [0x13] y_max           - Y-axis maximum (default 0x32)
;   [0x1D] sensitivity     - Mouse sensitivity (16)
;   [0x1F] button_state    - Current button status byte
;   [0x21] change_flags    - Button change flags
;   [0x23] callback_off    - Button callback offset
;   [0x25] callback_seg    - Button callback segment
;   [0x27] callback_cs     - Button callback code segment
;   [0x29] raw_buttons     - Raw button byte from PS/2 packet
;   [0x2A] x_enable        - X-axis processing enabled
;   [0x2C] y_enable        - Y-axis processing enabled
;   [0x2E] last_raw_btn    - Last raw button state
;   [0x5C] divider         - Axis scaling divider
;   [0x5E] ps2_irq_flag    - PS/2 IRQ flag byte
;   [0x5F] poll_done       - First poll completed flag
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Mouse driver code (688 bytes)
; seg_002B: TSR entry + ISR wrappers (293 bytes)
; seg_003E: BSS
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmmdp.asm for complete byte-level listing]
