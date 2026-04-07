; ========================================================================
; DMPDASCI.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMPDASCI.RES is the ASCII/Daisywheel Printer Driver for DeskMate 3.05.
; It supports letter-quality daisywheel printers and plain ASCII text
; output printers, including:
;
;   - Tandy DWP 210, 220, 230, 410, 510, 520 (Tandy and IBM modes)
;   - IBM Daisywheel Compatible
;   - Diablo 630 and compatibles
;   - ASCII Printer (text only, no graphics)
;   - Tandy Daisy Wheel (Tandy and IBM modes)
;
; Unlike the dot-matrix drivers (DMPD1/2/S), this driver does not
; include bitmap font data since daisywheel printers use physical
; type elements. The seg_0000 data contains printer configuration
; tables (escape sequences, character sets, pitch settings) for
; each supported model.
;
; The driver also references DMFONT for downloadable font support
; and DMPD.CFG / DMCONFIG for printer configuration persistence.
;
; Error handling: displays "Printer Error" / "Printer is offline or
; out of paper." dialog via PRGUF when print failures occur.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 6,848 bytes
; Load image: 6,336 bytes (after header)
; DM89 entry point: 0000:01C7
; SS:SP = 01B7:0002
; Min/Max alloc: 0x0018 paragraphs
;
; Segment Map (5 segments, 15 relocations):
;   seg_0000  400 bytes   DATA   Version "58.31", printer config tables
;                                for 12+ printer models (margins, pitch,
;                                escape codes, model names)
;   seg_0019  5,328 bytes CODE   Print engine: text formatting, escape
;                                sequence generation, character translation,
;                                page layout, proportional spacing
;   seg_0162  1,360 bytes DATA   DM89 header "DMPDASCI", printer name
;                                strings, DMFONT/PRGUF/DMCSR imports,
;                                DMPD.CFG config filename, error messages
;   seg_01B7  BSS                Stack
;   seg_01B8  BSS                Runtime state
;
; ========================================================================
; FUNCTION INDEX (seg_0019 - Print Engine)
; ========================================================================
;
; Address       Name                          Description
; -------       ----                          -----------
; 0019:0031     dmpdasci_loadFontData         Load DMFONT for current model
; 0019:029B     dmpdasci_configPrinter        Configure printer model params
; 0019:02DD     dmpdasci_allocState           Allocate runtime state buffer
; 0019:02F1     dmpdasci_setEscapeMode        Set escape sequence mode
; 0019:034F     dmpdasci_initDriver           Initialize driver, load config
; 0019:053C     dmpdasci_printSetup           Set up page for printing
; 0019:05D7     dmpdasci_sendEscSequence      Send escape sequence to printer
; 0019:0704     dmpdasci_translateChar        Translate character for current model
; 0019:07A6     dmpdasci_printLine            Print one line of text
; 0019:0932     dmpdasci_formatOutput         Format output with attributes
; 0019:0B09     dmpdasci_handleAttribute      Handle bold/italic/underline attrs
; 0019:0C65     dmpdasci_printChar            Print single character via INT 17h
; 0019:0CA6     dmpdasci_printEscape          Print escape code sequence
; 0019:0D3C     dmpdasci_readConfig           Read DMPD.CFG printer config file
; 0019:0EF6     dmpdasci_pageLayout           Calculate page layout geometry
; 0019:0FFB     dmpdasci_handleError          Handle print error (retry/cancel)
; 0019:1028     dmpdasci_printGraphicsLine    Print graphics line (if supported)
; 0019:10EA     dmpdasci_printBitmapRow       Print bitmap row data
; 0019:11DD     dmpdasci_printFormFeed        Send form feed/page eject
; 0019:124D     dmpdasci_matchModel           Match printer model string
; 0019:1301     dmpdasci_dialogPrintError     Display "Printer Error" dialog
; 0019:137E     dmpdasci_sendInitSequence     Send printer init escape sequence
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 17h     - BIOS Printer Services
;   AH=00h   - Print character
;   AH=01h   - Initialize printer
;   AH=02h   - Get printer status
;
; Daisywheel Escape Sequences (varies by model):
;   ESC 'E' / ESC 'F'     - Bold on/off
;   ESC '-' 1 / ESC '-' 0 - Underline on/off
;   Various model-specific sequences for pitch, spacing, etc.
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Printer config tables (400 bytes)
; seg_0019: Print engine code (5,328 bytes)
; seg_0162: Module header + strings (1,360 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmpdasci.asm for complete byte-level listing]
