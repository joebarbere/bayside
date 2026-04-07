; ========================================================================
; DMVS1000.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Standard Video Driver: Tandy 1000 (640x200, 4 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVS1000.RES is the standard-mode Tandy 1000 video driver for DeskMate.
; It handles mode switching, cursor management, timer/keyboard hooking,
; and high-level drawing operations for the Tandy Graphics Adapter (TGA).
; It calls into DMVE1000.RES for pixel-level rendering.
;
; Video mode: Tandy 1000 640x200, 4 colors
; Framebuffer: segment B800h
; Bytes per scanline: 160
; Memory interleave: 2-way
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 21922 bytes
; Code+data size: 21410 bytes
; DM89 entry point: 04F3:0032
; SS:SP = 053A:0002
; Min alloc: 0x0176 paragraphs
; Max alloc: 0x0976 paragraphs
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000  0x0020 bytes  DATA       Version string + config ("33.15", "DMVE1000")
;   seg_0002  0x4DF0 bytes  CODE/DATA  Main driver code + font data
;   seg_04E1  0x0120 bytes  DATA       Function pointer table
;   seg_04F3  0x03D0 bytes  CODE       TSR startup, dispatch, INT hooks
;   seg_0530  0x00A0 bytes  DATA       Key mapping + driver descriptor
;   seg_053A  0x0002 bytes  STACK      Stack segment
;   seg_053B  (BSS)         BSS        Uninitialized data
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; Tandy Video Mode Register (port 3D8h):
;   04F3:03AC  Read BIOS data area at 0040:0065 to get current mode byte
;              and al, 0xF7    ; Clear bit 3 (video output enable)
;   04F3:03BC  mov dx, 0x03D8  ; Tandy/CGA mode control register
;              out dx, al      ; Disable video output (screen blank)
;
;   04F3:03C6  Read BIOS data area at 0040:0065 to get current mode byte
;              or al, 0x08     ; Set bit 3 (video output enable)
;   04F3:03CC  mov dx, 0x03D8  ; Tandy/CGA mode control register
;              out dx, al      ; Enable video output (unblank)
;
; The Tandy/CGA mode control register (3D8h) controls:
;   Bit 0: 80-column text mode
;   Bit 1: Graphics mode
;   Bit 2: B/W mode
;   Bit 3: Video output enable (0=blank, 1=display)
;   Bit 4: 640x200 mode
;   Bit 5: Blink enable
;
; The driver reads the current mode byte from BIOS data area (0040:0065)
; to preserve the current mode settings while toggling only bit 3 for
; screen blanking.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register driver
;   04F3:0041
;
; INT E0h, AH=4Dh  -- Display mutex
;   04F3:00A5, 04F3:00F3
;
; INT 21h, AH=31h  -- TSR
;   04F3:0052
;
; INT 21h, AH=25h  -- Set INT 08h/09h
;   04F3:019A, 04F3:01C8
;
; INT 21h, AH=35h  -- Get INT 08h/09h
;   04F3:018E, 04F3:01BE
;
; ========================================================================
; FUNCTION INDEX (selected)
; ========================================================================
;
; Structurally matches DMVSVGA.RES with Tandy-specific adaptations:
;
; --- TSR (seg_04F3) ---
;   04F3:0000 (data: "DMVS1000")       Driver name + config
;   04F3:0032 entry_point               TSR entry
;   04F3:0205 dmvs1000_timerISR         INT 08h handler
;   04F3:0338 dmvs1000_keyboardISR      INT 09h handler
;   04F3:03AC dmvs1000_disableDisplay   Blank via port 3D8h bit 3 clear
;   04F3:03C6 dmvs1000_enableDisplay    Unblank via port 3D8h bit 3 set
;
; --- Main Driver (seg_0002) ---
;   ~100+ UI/drawing functions adapted for Tandy 1000 addressing
;
; ========================================================================
; KEY DATA
; ========================================================================
;
; seg_0000:0000  "33.15"               ; Driver version
; seg_0000:0007  "DMVE1000"            ; Enhanced driver name
; seg_0530+0x85  dw 0x00B8             ; Framebuffer segment (B800h)
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The Tandy 1000 standard driver reads the BIOS data area at 0040:0065
;   to get the current CGA/Tandy mode control register value before
;   modifying bit 3 for blanking. This is more robust than the VGA
;   approach of directly manipulating the attribute controller.
;
; - The max alloc (0x0976 = ~38KB) suggests the driver uses significant
;   memory for font data and offscreen buffers.
;
; - Version "33.15" indicates this is an earlier build than VGA ("33.19")
;   or Hercules ("33.30"), possibly reflecting the development timeline.
;
; ========================================================================
