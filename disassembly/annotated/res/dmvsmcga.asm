; ========================================================================
; DMVSMCGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Standard Video Driver: MCGA (640x480, 2 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVSMCGA.RES is the standard-mode MCGA video driver for DeskMate 3.05.
; It handles mode switching, cursor management, timer/keyboard hooking,
; and high-level drawing operations for MCGA displays. It calls into
; DMVEMCGA.RES for pixel-level rendering.
;
; MCGA (Multi-Color Graphics Array) is found in IBM PS/2 Model 25/30.
; DeskMate uses it in 640x480 monochrome mode (mode 11h).
;
; Video mode: MCGA mode 11h (640x480, monochrome)
; Framebuffer: segment A000h
; Bytes per scanline: 80
; Memory layout: Linear
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 22754 bytes
; Code+data size: 22242 bytes
; DM89 entry point: 0527:0032
; SS:SP = 056E:0002
; Min alloc: 0x01C1 paragraphs
; Max alloc: 0x01C1 paragraphs
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000  0x0020 bytes  DATA       Version string + config ("33.14", "DMVEMCGA")
;   seg_0002  0x5130 bytes  CODE/DATA  Main driver code + font data
;   seg_0515  0x0120 bytes  DATA       Function pointer table
;   seg_0527  0x03D0 bytes  CODE       TSR startup, dispatch, INT hooks
;   seg_0564  0x00A0 bytes  DATA       Key mapping + driver descriptor
;   seg_056E  0x0002 bytes  STACK      Stack segment
;   seg_056F  (BSS)         BSS        Uninitialized data
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; MCGA/VGA Attribute Controller (ports 3BAh, 3DAh, 3C0h):
;   0527:03AC  in al, 0x3BA    ; Read input status 1 (reset attr flip-flop)
;              in al, 0x3DA    ; Read input status 1 (alternate port)
;              in al, 0x3C0    ; Read attribute controller state
;              mov al, 0x00    ; Clear palette address source
;              out dx, al      ; Disable palette (blank screen)
;
;   0527:03BC  in al, 0x3BA    ; Reset flip-flop
;              in al, 0x3DA    ; Reset flip-flop (alt)
;              in al, 0x3C0    ; Read state
;              mov al, 0x20    ; Set palette address source
;              out dx, al      ; Enable palette (unblank screen)
;
; The MCGA standard driver uses the same VGA-style attribute controller
; blanking as DMVSVGA.RES. This is because MCGA shares VGA-compatible
; register programming for the attribute controller, even though it
; does not support all VGA modes.
;
; Port 3BAh: Monochrome input status register 1
; Port 3DAh: Color input status register 1
; Port 3C0h: Attribute controller index/data register
;
; Both status ports are read to ensure the flip-flop is reset regardless
; of whether the system is in monochrome or color I/O address mode.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register driver
;   0527:0041
;
; INT E0h, AH=4Dh  -- Display mutex
;   0527:00A5, 0527:00F3
;
; INT 21h, AH=31h  -- TSR
;   0527:0052
;
; INT 21h, AH=25h  -- Set INT 08h/09h
;   0527:019A, 0527:01C8
;
; INT 21h, AH=35h  -- Get INT 08h/09h
;   0527:018E, 0527:01BE
;
; ========================================================================
; FUNCTION INDEX (selected)
; ========================================================================
;
; Structurally matches DMVSVGA.RES with MCGA-specific adaptations:
;
; --- TSR (seg_0527) ---
;   0527:0000 (data: "DMVSMCGA")       Driver name + config
;   0527:0032 entry_point               TSR entry
;   0527:0205 dmvsmcga_timerISR         INT 08h handler
;   0527:0338 dmvsmcga_keyboardISR      INT 09h handler
;   0527:03AC dmvsmcga_disablePalette   Blank via attribute controller
;   0527:03BC dmvsmcga_enablePalette    Unblank via attribute controller
;
; --- Main Driver (seg_0002) ---
;   ~100+ UI/drawing functions adapted for MCGA monochrome
;   Font data includes monochrome glyph bitmaps
;
; ========================================================================
; KEY DATA
; ========================================================================
;
; seg_0000:0000  "33.14"               ; Driver version (oldest of all drivers)
; seg_0000:0007  "DMVEMCGA"            ; Enhanced driver name
; seg_0564+0x85  dw 0x00A0             ; Framebuffer segment (A000h)
;
; ========================================================================
; NOTES
; ========================================================================
;
; - Version "33.14" makes this the oldest-versioned driver in the set,
;   suggesting MCGA support was developed earliest (consistent with
;   IBM PS/2 being the original target platform).
;
; - Min alloc equals max alloc (0x01C1 = ~7KB), indicating fixed memory
;   usage with no dynamic allocation capability.
;
; - The attribute controller blanking sequence is identical to DMVSVGA,
;   confirming MCGA's VGA-compatible register interface for the attribute
;   controller, even in monochrome mode.
;
; - The dispatch function table offsets in seg_0515 differ slightly from
;   DMVSVGA's table (seg_055D) due to the monochrome-specific code paths
;   and different font data sizes.
;
; ========================================================================
