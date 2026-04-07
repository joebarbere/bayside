; ========================================================================
; DMMDS.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMMDS.RES is the MIDI/Sound serial port driver for DeskMate 3.05.
; It interfaces with a serial-port-attached MIDI device or sound module,
; handling both MIDI input and serial mouse-like pointing device input
; through a COM port. The driver installs custom ISRs for the serial
; port IRQ and manages bidirectional MIDI data flow.
;
; The driver supports multiple serial port configurations (COM1-COM4)
; with automatic detection of the UART base address from BIOS data
; area or direct I/O port probing. It handles:
;   - MIDI data reception via serial port interrupt
;   - MIDI status byte parsing (3-byte messages)
;   - Button/axis event generation from MIDI controller data
;   - Interrupt-driven I/O with 8259 PIC management
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 2,113 bytes
; Load image: 1,601 bytes (after header)
; DM89 entry point: 004B:0164
; SS:SP = 0065:0002
;
; Segment Map (3 segments, 7 relocations):
;   seg_0000  1,200 bytes  CODE/DATA  Serial MIDI I/O, axis scaling,
;                                     UART init, IRQ management, PIC control
;   seg_004B  401 bytes    CODE/DATA  Module header ("DMMDS"), DM89
;                                     registration, ISR wrappers, entry
;   seg_0065  BSS                     Runtime state, port addresses
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmmds_apiDispatch             API entry - routes by function code in AL
;                                           AL=00: Init (zero state, set defaults)
;                                           AL=03: Get device parameters
;                                           AL=07: Set X-axis callback
;                                           AL=08: Set Y-axis callback + enable
;                                           AL=0C: Set button callback (far ptr)
;                                           AL=0F: Set both axes simultaneously
; 0000:00BF   dmmds_scaleAxis               Scale raw axis delta to calibrated range
; 0000:00E8   dmmds_pollDevice              Poll serial port, decode MIDI, fire events
; 0000:01A9   dmmds_serialISR               Serial port ISR - reads UART, parses MIDI bytes
; 0000:01D1   dmmds_sendEOI                 Send End-Of-Interrupt to 8259 PIC (port 20h)
; 0000:01E1   dmmds_processMidiStatus       Process MIDI status byte, update button flags
; 0000:0258   dmmds_installSerialISR        Install serial port interrupt handler
; 0000:0289   dmmds_detectUART              Detect UART type and configure baud rate
; 0000:02E9   dmmds_initUART                Initialize UART registers for MIDI (31250 baud)
; 0000:0308   dmmds_disableSerialIRQ        Disable serial port IRQ at 8259 PIC
; 0000:0325   dmmds_configMidiChannel       Configure MIDI channel filter and mapping
; 0000:035D   dmmds_resetMidiState          Reset MIDI parser state machine
; 0000:039D   dmmds_startMidiReceive        Start MIDI receive mode on serial port
; 0000:0410   dmmds_waitForByte             Wait for byte with timeout (uses INT 1Ah timer)
; 0000:0445   dmmds_restoreSerialISR        Restore original serial port ISR vector
; 0000:0454   dmmds_probeAndInit            Probe for MIDI device, initialize if found
;
; 004B:0096   dmmds_irqHandler              ISR wrapper with DM89 context save/restore
; 004B:00EF   dmmds_int15Callback           INT 15h callback wrapper
; 004B:0129   dmmds_apiCallHandler          Far-call API handler (DM89 dispatch)
; 004B:0164   dmmds_tsrEntry                Entry: register with DM89, go TSR
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; Serial Port UART (8250/16550) registers (base + offset):
;   Base+0  RBR/THR  - Receive/Transmit holding register
;   Base+1  IER      - Interrupt Enable Register
;   Base+3  LCR      - Line Control Register
;   Base+4  MCR      - Modem Control Register
;   Base+5  LSR      - Line Status Register
;   Base+6  MSR      - Modem Status Register
;
; Port 20h  - 8259 PIC #1 command register (EOI)
; Port 21h  - 8259 PIC #1 mask register (enable/disable IRQs)
;
; MIDI Protocol: 31,250 baud, 8N1
;   Status bytes: 0x80-0xEF (channel messages)
;   Data bytes: 0x00-0x7F
;   3-byte messages: Status + Data1 + Data2
;
; INT 1Ah   - BIOS timer services (used for timeouts)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; MIDI Device State (seg_0000 data area):
;   [0x08]  x_position      - Current X position
;   [0x0A]  y_position      - Current Y position
;   [0x14]  sensitivity_x   - X sensitivity (8)
;   [0x16]  y_range         - Y range (default 0x64)
;   [0x18]  y_max           - Y maximum (default 0x32)
;   [0x22]  sensitivity_y   - Y sensitivity (16)
;   [0x24]  button_state    - Current button state
;   [0x26]  change_flags    - Button change flags
;   [0x28]  callback_off    - Callback offset
;   [0x2A]  callback_seg    - Callback segment
;   [0x2C]  callback_cs     - Callback code segment
;   [0x2E]  last_raw_btn    - Last raw button state
;   [0x2F]  x_enable        - X-axis enabled
;   [0x31]  y_enable        - Y-axis enabled
;   [0x33]  midi_byte_high  - MIDI status/high byte
;   [0x36]  divider         - Axis scaling divider
;   [0x5D]  irq_assignment  - Assigned IRQ number (0xFF = none)
;   [0x5E]  x_invert        - X-axis inversion flag
;   [0x5F]  y_button_state  - Y-axis button mapping
;   [0x60]  midi_channel    - MIDI channel filter
;   [0x62]  midi_parse_state - MIDI parser state (0-3)
;   [0x63]  poll_done       - First poll completed flag
;   [0x64]  port_base_0     - UART base address for port 0
;   [0x66]  port_ier        - IER register address
;   [0x68]  port_data       - Data register address
;   [0x6A]  port_lcr        - LCR register address
;   [0x6C]  port_mcr        - MCR register address
;   [0x6E]  port_msr        - MSR register address
;   [0x70]  irq_mask        - PIC IRQ mask byte
;   [0x71]  irq_vector      - IRQ interrupt vector number
;   [0x72]  midi_reg_map    - MIDI register mapping table (8x2 bytes)
;   [0x76]  status_byte     - Current MIDI status byte
;   [0x77]  change_accum    - Accumulated change flags
;   [0x88]  saved_isr       - Saved original ISR vector (dword)
;   [0x8C]  saved_int33     - Saved INT 33h vector (dword)
;   [0x90]  event_handler   - Event handler function pointer
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Serial MIDI driver code (1,200 bytes)
; seg_004B: TSR entry + ISR wrappers (401 bytes)
; seg_0065: BSS
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmmds.asm for complete byte-level listing]
