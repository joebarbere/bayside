; ========================================================================
; DMMDJ.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMMDJ.RES is the MIDI/Joystick input driver for DeskMate 3.05.
; It reads the game port (I/O port 201h) to capture joystick position
; data and button states, then translates these into MIDI-compatible
; events that the DeskMate sound system can process.
;
; The driver installs as a TSR via INT 21h/31h after verifying that
; a joystick is present (by reading port 201h and checking for
; active axis bits). If no joystick is detected, it exits with
; error code 0xFF.
;
; Hardware: IBM Game Port at I/O port 201h
;   - Bits 0-1: Joystick 1 button states
;   - Bits 2-3: Joystick 2 button states (active low)
;   - Analog axes read via timing loop on port 201h
;
; Installs IRQ 8 (INT 08h) and INT 33h handlers to poll the joystick
; at regular intervals and deliver position/button change events.
;
; Copyright: "TANDY DMMDJ.RES VERSION 03.00.00 COPYRIGHT 1987, 1988, 1989
;             TANDY CORP. ALL RIGHTS RESERVED."
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 1,540 bytes
; Load image: 1,028 bytes (after header)
; DM89 entry point: 0030:00CC
; SS:SP = 0041:0002
;
; Segment Map (3 segments, 6 relocations):
;   seg_0000  768 bytes  CODE/DATA  Joystick polling, axis calibration,
;                                   button event generation, IRQ handlers
;   seg_0030  260 bytes  CODE/DATA  Module header ("DMMDJ"), DM89
;                                   registration, INT 08h/33h ISR wrappers
;   seg_0041  BSS                   Runtime state variables
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmmdj_apiDispatch             API entry - routes by function code in AL
;                                           AL=00: Init (zero state, set defaults)
;                                           AL=01: Set calibration center
;                                           AL=03: Get joystick parameters
;                                           AL=07: Set X-axis callback
;                                           AL=08: Set Y-axis callback + enable
;                                           AL=0C: Set button callback (far ptr)
;                                           AL=0F: Enable polling flag
; 0000:00AA   dmmdj_pollJoystick            Main polling routine - reads port 201h,
;                                           detects button changes, fires callbacks
; 0000:0168   dmmdj_scaleAxis               Scale raw axis value to calibrated range
; 0000:019E   dmmdj_readAndCalibrate        Read all axes, calibrate, fire initial events
; 0000:01CC   dmmdj_readAxes                Read raw axis values from port 201h timing loop
; 0000:0206   dmmdj_readAxisPair            Read single axis pair (4 axes per joystick)
; 0000:0232   dmmdj_readTimerCount          Read timer chip count (port 40h/43h)
; 0000:024A   dmmdj_installISRs             Install INT 08h and INT 33h handlers
; 0000:0260   dmmdj_saveOriginalISRs        Save original INT 08h/33h vectors
;
; 0030:006D   dmmdj_int08Handler            Timer tick ISR - polls joystick periodically
; 0030:00A1   dmmdj_int33Handler            INT 33h ISR - joystick API entry point
; 0030:00CC   dmmdj_tsrEntry                Entry point: detect joystick, register, TSR
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; Port 201h  - Game Port (joystick)
;              Read: Bit 0-3 = axis timing (set by write, cleared by RC)
;                    Bit 4-5 = button 1/2 of joystick 1 (active low)
;                    Bit 6-7 = button 1/2 of joystick 2 (active low)
;              Write: Triggers one-shot timers for all 4 axes
;
; Port 40h   - PIT Channel 0 counter (read for timing)
; Port 43h   - PIT command register (latch counter)
;
; INT 08h    - Timer tick (hooked to poll joystick)
; INT 33h    - Joystick API (hooked for DeskMate calls)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Joystick State (seg_0000 data area):
;   [0x00] joy1_x_raw     - Raw X axis reading, joystick 1
;   [0x02] joy1_y_raw     - Raw Y axis reading, joystick 1
;   [0x04] joy1_x_param   - X axis parameter (BX from func 03)
;   [0x06] joy1_y_param   - Y axis parameter (CX from func 03)
;   [0x08] joy1_z_param   - Z axis parameter (DX from func 03)
;   [0x0A] x_callback_off - X-axis event callback offset
;   [0x0C] y_callback_off - Y-axis event callback offset
;   [0x0E] x2_callback    - Secondary X callback offset
;   [0x10] y2_callback    - Secondary Y callback offset
;   [0x12] btn_callback_off - Button callback offset
;   [0x14] btn_change_flags - Button change flags (bits: 1=press, 2=release)
;   [0x16] btn_callback_seg - Button callback segment
;   [0x18] btn_callback_cs  - Button callback code segment
;   [0x1A] last_button_state - Previous button state byte
;   [0x1B] current_button   - Current raw button reading
;   [0x1C] x_center        - X-axis center calibration
;   [0x1E] y_center        - Y-axis center calibration
;   [0x20] x_deadzone      - X-axis dead zone size
;   [0x22] y_center2       - Y-axis center (alt calibration)
;   [0x24] x2_center       - Secondary X center
;   [0x26] y2_deadzone     - Secondary Y dead zone
;   [0x28] poll_lock       - Reentrance lock byte (spinlock)
;   [0x29] poll_enabled    - Polling enabled flag (0=off, 1=on)
;   [0x3E] first_poll_done - Set after first successful poll
;   [0x43] saved_int08     - Saved original INT 08h vector (dword)
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Joystick driver code (768 bytes)
; seg_0030: TSR entry + ISR wrappers (260 bytes)
; seg_0041: BSS
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmmdj.asm for complete byte-level listing]
