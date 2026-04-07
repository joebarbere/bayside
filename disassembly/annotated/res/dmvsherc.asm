; ========================================================================
; DMVSHERC.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Standard Video Driver: Hercules (720x348, monochrome)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVSHERC.RES is the standard-mode Hercules video driver for DeskMate 3.05.
; It handles mode switching, cursor management, timer hooking, and high-level
; drawing operations for the Hercules Graphics Card. It calls into the
; enhanced driver (DMVEHERC.RES) for pixel-level rendering.
;
; Video mode: Hercules graphics mode (720x348, monochrome)
; Framebuffer: segment B000h
; Bytes per scanline: 90
; Memory interleave: 4-way
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 25682 bytes
; Code+data size: 25170 bytes
; DM89 entry point: 05DF:0032
; SS:SP = 0625:0002
; Min alloc: 0x0161 paragraphs
; Max alloc: 0x1161 paragraphs
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000  0x0020 bytes  DATA       Version string + config ("33.30", "DMVEHERC")
;   seg_0002  0x5CB0 bytes  CODE/DATA  Main driver code + font data
;   seg_05CD  0x0120 bytes  DATA       Function pointer table (dispatch vectors)
;   seg_05DF  0x03C0 bytes  CODE       TSR startup, dispatch, INT hooks
;   seg_061B  0x00A0 bytes  DATA       Key mapping table + driver descriptor
;   seg_0625  0x0002 bytes  STACK      Stack segment
;   seg_0626  (BSS)         BSS        Uninitialized data
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; Hercules Configuration Port (3B8h):
;   05DF:03AC  mov dx, 0x03B8   ; Hercules configuration register
;              mov al, 0x02     ; Graphics mode, page 0
;              out dx, al       ; Set Hercules to graphics mode
;
;   05DF:03BC  mov dx, 0x03B8   ; Hercules configuration register
;              mov al, 0x0A     ; Graphics mode + screen enable + page 0
;              out dx, al       ; Enable graphics display
;
; The Hercules configuration register (3B8h) controls:
;   Bit 0: Reserved
;   Bit 1: Graphics mode enable (0=text, 1=graphics)
;   Bit 2: Reserved
;   Bit 3: Screen enable (0=blank, 1=display)
;   Bit 4-7: Reserved
;
; Port 3B8h values used:
;   0x02 = Graphics mode, screen off (for blanking during updates)
;   0x0A = Graphics mode, screen on (normal display)
;
; Note: No CRTC programming (ports 3B4h/3B5h) is visible in this code
; because the Hercules CRTC is configured at mode-switch time only.
; The status register at 3BAh is not used here either.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register driver with host
;   05DF:0041  CX=seg_0000, AX=0x01F0
;
; INT E0h, AH=4Dh/04 / 05  -- Acquire/release display mutex
;   05DF:00A5, 05DF:00F3
;
; INT 21h, AH=31h  -- TSR
;   05DF:0052
;
; INT 21h, AH=25h  -- Set INT 08h/09h vectors
;   05DF:019A, 05DF:01C8
;
; INT 21h, AH=35h  -- Get INT 08h/09h vectors
;   05DF:018E, 05DF:01BE
;
; ========================================================================
; FUNCTION INDEX (selected)
; ========================================================================
;
; The structure mirrors DMVSVGA.RES exactly. Key differences:
;
; - seg_0000 config: version "33.30", enhanced driver name "DMVEHERC"
; - Framebuffer descriptor: B000h (vs A000h for VGA)
; - Port I/O uses 3B8h (Hercules) instead of 3C0h/3BAh/3DAh (VGA)
; - Resolution constants: 720x348 instead of 640x480
; - Bytes per scanline: 90 instead of 80
; - Font data sized for monochrome display
; - The dispatch table in seg_05CD uses different offsets into seg_0002
;   to account for the interleaved addressing code
;
; --- TSR / Startup (seg_05DF) ---
;   05DF:0000 (data: "DMVSHERC")       Driver name + config header
;   05DF:0032 entry_point               TSR entry
;   05DF:0055 dmvsherc_dispatchFast     Fast dispatch path
;   05DF:0087 dmvsherc_dispatchFull     Full dispatch with context save
;   05DF:00FC dmvsherc_initDriver       Init driver, set Hercules graphics mode
;   05DF:013C dmvsherc_setVideoMode     Program Hercules mode register
;   05DF:0205 dmvsherc_timerISR         INT 08h handler (cursor blink)
;   05DF:0338 dmvsherc_keyboardISR      INT 09h handler
;   05DF:03AC dmvsherc_disableDisplay   Blank screen: out 3B8h, 0x02
;   05DF:03BC dmvsherc_enableDisplay    Unblank screen: out 3B8h, 0x0A
;
; --- Main Driver Functions (seg_0002) ---
;   (Same function set as DMVSVGA.RES adapted for Hercules addressing)
;   Includes ~100+ UI/drawing functions with Hercules-specific scan
;   line interleave handling.
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The Hercules driver is slightly larger than the VGA driver (25KB vs
;   24KB) due to the additional complexity of interleaved addressing.
;
; - Screen blanking uses the Hercules configuration register (3B8h)
;   rather than the VGA attribute controller. Writing 0x02 (graphics
;   mode, screen off) blanks the display; 0x0A (graphics + screen on)
;   restores it.
;
; - The max alloc field (0x1161 paragraphs = ~70KB) is much larger than
;   min alloc (0x0161 = ~5.5KB), suggesting the driver can use additional
;   memory for offscreen buffering if available.
;
; - Font data in this driver is optimized for monochrome display, with
;   single-bit glyph bitmaps and monochrome box-drawing characters.
;
; ========================================================================
