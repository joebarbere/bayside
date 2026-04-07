; ========================================================================
; DMVSCGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Standard Video Driver: CGA (320x200, 4 colors / 640x200, 2 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVSCGA.RES is the standard-mode CGA video driver for DeskMate 3.05.
; Standard drivers handle mode switching, cursor management, timer-based
; blinking, window/display list management, font loading, and high-level
; drawing operations. They call into the corresponding enhanced driver
; (DMVECGA.RES) for pixel-level rendering primitives.
;
; The standard driver installs itself as a TSR via INT 21h/31h and hooks
; INT 08h (timer) and INT 09h (keyboard) for cursor blink and keyboard
; state tracking. It provides a large dispatch table of ~100+ functions
; accessible through the DeskMate host API.
;
; Video mode: CGA mode 4 (320x200, 4 colors) or mode 6 (640x200, 2 colors)
; Framebuffer: segment B800h (interleaved even/odd scanlines)
; Bytes per scanline: 80
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 23746 bytes
; Code+data size: 23234 bytes
; DM89 entry point: 0560:0032
; SS:SP = 05AC:0002
; Min alloc: 0x00AB paragraphs
; Max alloc: 0x04AB paragraphs
;
; DM89 signature: present
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000  0x0030 bytes  DATA       Version string + config ("33.17", "DMVECGA")
;   seg_0003  0x54A0 bytes  CODE/DATA  Main driver code + font data + drawing ops
;   seg_054D  0x0130 bytes  DATA       Function pointer table (dispatch vectors)
;   seg_0560  0x0420 bytes  CODE       TSR startup, dispatch, INT hooks, mode switch
;   seg_05A2  0x00A0 bytes  DATA       Key mapping table + driver descriptor
;   seg_05AC  0x0002 bytes  STACK      Stack segment
;   seg_05AD  (BSS)         BSS        Uninitialized data segment
;
; ========================================================================
; ARCHITECTURE
; ========================================================================
;
; The standard driver is substantially larger than the enhanced driver
; (~22KB vs ~5KB) and contains:
;
; 1. Configuration Data (seg_0000, 48 bytes):
;    Version string "33.17", enhanced driver name "DMVECGA",
;    and display configuration bytes (resolution, color depth,
;    capabilities flags).
;
;    Config at 0000:000F:
;      FF 00 88 E7 9C AA CC 10 00 08 00 01 00 00 00 00
;      80 02 C8 00 10 05 10 00 02 02 02 01 10 00 02 02 02
;    Key values:
;      0x0017: 08 = 8 pixels char width
;      0x001F: 80 02 = 0x0280 = 640 horizontal resolution
;      0x0021: C8 00 = 0x00C8 = 200 vertical resolution
;
; 2. Main Driver Code (seg_0003, ~21KB):
;    The bulk of the driver. Contains:
;    - Coordinate system management (viewports, clipping)
;    - Window management (create, move, resize, scroll)
;    - Text rendering (font selection, string drawing)
;    - Cursor management (show, hide, blink, shape)
;    - Mouse pointer rendering
;    - Bitmap/icon operations
;    - Line drawing (Bresenham's algorithm)
;    - Rectangle fill (solid, patterned)
;    - Character/font bitmap tables (~8KB of font data, starting ~0x38D5)
;    - Display list management
;
; 3. Function Dispatch Table (seg_054D, 304 bytes):
;    Array of ~100 word-sized offsets into seg_0003, indexed by
;    function number. The dispatcher uses this table to route
;    calls from the DeskMate host to the appropriate handler.
;
; 4. TSR/Dispatcher Code (seg_0560, 1056 bytes):
;    Entry point, INT 08h/09h hooks, mode switching, and the
;    main function dispatcher that saves context, looks up the
;    function in the dispatch table, calls it, and restores context.
;
; 5. Key Mapping / Descriptor (seg_05A2, 160 bytes):
;    Keyboard scan code to DeskMate key code mapping table,
;    plus the driver descriptor block (framebuffer segment B800h,
;    pointer to function table in seg_054D).
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; CGA Mode Control Register (port 3D8h):
;   0560:03C8  in al, 0x3BA    ; Read input status (MDA port)
;   0560:03D8  in al, 0x3DA    ; Read input status (CGA port)
;   0560:03E8  mov al, [0040:0065] ; Read BIOS CGA mode byte
;              and al, 0xF7    ; Clear bit 3 (video enable)
;              out 0x3D8, al   ; Write mode reg (disable video)
;
; The disablePalette equivalent for CGA reads the current mode from
; the BIOS data area at 0040:0065 and clears the video enable bit
; (bit 3) to blank the display during updates.
;
; CGA Mode Control Register (palette enable):
;   0560:03F8  in al, 0x3BA    ; Read input status (MDA port)
;   0560:0408  in al, 0x3DA    ; Read input status (CGA port)
;   0560:0418  mov al, [0040:0065] ; Read BIOS CGA mode byte
;              or al, 0x08     ; Set bit 3 (video enable)
;              out 0x3D8, al   ; Write mode reg (enable video)
;
; CGA port 3D8h (Mode Control):
;   Bit 3 = Video signal enable (1=on, 0=blank)
;   0560:03C8-03E7  dmvscga_disablePalette  Blank screen
;   0560:03F8-0418  dmvscga_enablePalette   Unblank screen
;
; Alternate check for MDA/Hercules (port 3BAh):
;   The driver checks the status register on both 3BAh (MDA) and
;   3DAh (CGA) to handle dual-monitor configurations. The flag at
;   byte [0x53] bit 2 indicates which port set to use.
;
; BIOS Data Area (0040:0065):
;   The CGA current mode byte. Read to determine the current video
;   mode register value before modifying bit 3 for blanking.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register standard driver with DeskMate host
;   0560:0041  CX=seg_0000 (config data), AX=0x01F0
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex
;   0560:00A5  Before dispatching draw calls
;
; INT E0h, AH=4Dh/05  -- Release display mutex
;   0560:00F3  After draw calls complete
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   0560:0052  Install driver as TSR
;
; INT 21h, AH=25h  -- Set interrupt vector
;   0560:01B8  Set INT 08h handler (timer tick for cursor blink)
;   0560:01E8  Set INT 09h handler (keyboard state tracking)
;
; INT 21h, AH=35h  -- Get interrupt vector
;   0560:01A8  Save original INT 08h vector
;   0560:01D8  Save original INT 09h vector
;
; INT 10h, AH=12h  -- EGA/VGA alternate select (video subsystem config)
;   0560:0128  BL=10h: return EGA info (detect CGA vs EGA monitor)
;
; ========================================================================
; FUNCTION INDEX (selected, ~100+ total)
; ========================================================================
;
; --- TSR / Startup (seg_0560) ---
;
;   Address   Name                           Description
;   -------   ----                           -----------
;   0560:0000 (data: driver name)            "DMVSCGA" + config header
;   0560:0032 entry_point                    TSR entry: register, go resident
;   0560:0055 dmvscga_dispatchFast           Fast dispatch path (near call)
;   0560:0087 dmvscga_dispatchFull           Full dispatch with context save
;   0560:00E2 dmvscga_dispatchEpilogue       Epilogue: release mutex, restore
;   0560:00FC dmvscga_initDriver             Initialize driver state, set video mode
;   0560:011C dmvscga_shutdownDriver         Restore video mode, unhook interrupts
;   0560:013C dmvscga_setVideoMode           Set CGA mode and configure registers
;   0560:0155 dmvscga_lookupCursorRate       Lookup cursor blink rate from table
;   0560:018E dmvscga_hookTimerInt           Hook INT 08h for cursor blink
;   0560:01AD dmvscga_hookKeyboardInt        Hook INT 09h for key state tracking
;   0560:01DD dmvscga_acquireMutex           Acquire display mutex via INT E0h
;   0560:01EE dmvscga_releaseMutex           Release display mutex via INT E0h
;   0560:0220 dmvscga_timerISR               INT 08h handler (cursor blink logic)
;   0560:0353 dmvscga_keyboardISR            INT 09h handler (mouse button state)
;   0560:0393 dmvscga_checkCursorState       Check if cursor needs redraw
;   0560:03C8 dmvscga_disablePalette         Blank screen via CGA mode register
;   0560:03F8 dmvscga_enablePalette          Unblank screen via CGA mode register
;
; --- Configuration / Version (seg_0000) ---
;
;   0000:0000 (data: version)               "33.17" (driver version)
;   0000:0007 (data: companion)             "DMVECGA" (enhanced driver name)
;   0000:000F (data: config)                Display capabilities + resolution
;
; --- Main Driver Functions (seg_0003, selected) ---
;
;   Most functions in seg_0003 are identical in purpose to DMVSVGA
;   (see that file for detailed function descriptions). Key CGA-specific
;   differences are in pixel addressing (interleaved scanlines),
;   color depth (2bpp vs 4-plane), and mode register access.
;
;   0003:0000 dmvscga_resetClipBounds        Reset clip bounds to max viewport
;   0003:0045 dmvscga_drawEllipse            Draw ellipse (Bresenham midpoint)
;   0003:019D dmvscga_transformCoords        Transform coordinates
;   0003:0222 dmvscga_setDrawColor           Set drawing foreground color
;   0003:042C dmvscga_scrollUp               Scroll window contents up
;   0003:046C dmvscga_scrollDown             Scroll window contents down
;   0003:0853 dmvscga_blitCursor             Blit cursor bitmap to screen
;   0003:099F dmvscga_drawWindow             Draw window frame and contents
;   0003:38D5 (data: font bitmaps)           ~8KB of CGA character font data
;   0003:44F6 dmvscga_fontRenderEntry        Font rendering entry point
;   0003:452A dmvscga_characterBlit          Character blit operation
;   0003:4598 dmvscga_scrollHelper           Scroll region helper
;   0003:45EA dmvscga_displayListUpdate      Display list update
;   0003:4660 (data: dispatch offsets)       Additional dispatch sub-table
;
; --- Dispatch Table (seg_054D) ---
;
;   seg_054D contains ~100+ word-sized offsets into seg_0003.
;   These map function numbers to handler addresses.
;
; --- Key Mapping (seg_05A2) ---
;
;   seg_05A2:0000  Cursor blink rate table + key scan code mapping
;   seg_05A2:0082  FE 00 B8 00 00  -- framebuffer config: seg B800h
;   seg_05A2:008F  4D 05           -- dispatch table segment (seg_054D)
;
; ========================================================================
; NOTES
; ========================================================================
;
; - Version "33.17" indicates this is an earlier version than the EGA/VGA
;   standard drivers (which are "33.18" and "33.19" respectively).
;
; - The CGA driver has a slightly larger TSR segment (1056 bytes vs 976
;   for EGA/VGA) due to additional CGA-specific mode handling code,
;   including INT 10h/12h detection of CGA vs EGA display type.
;
; - The disablePalette/enablePalette routines differ from the VGA version:
;   CGA uses the mode control register at port 3D8h (bit 3 = video enable)
;   rather than the VGA attribute controller at port 3C0h.
;
; - The driver reads the BIOS data area (0040:0065) to get the current
;   CGA mode register value, preserving all other bits while toggling
;   the video enable bit for screen blanking.
;
; - The key mapping table at seg_05A2 includes scan code translations
;   for both standard and extended keyboard layouts.
;
; - Font data occupies approximately 8KB starting at seg_0003:38D5,
;   containing bitmap definitions for the CGA character set.
;
; ========================================================================

; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (48 bytes, file 0x0200-0x0230)
; Version string + display configuration
; ------------------------------------------------------------------------
seg_0000:

  0000:0000  db 33 33 2E 31 37                                  ; "33.17" (version)
  0000:0005  db 00                                                ; NUL terminator
  0000:0006  db B8                                              ; framebuffer seg high byte (B8xx)
  0000:0007  db 44 4D 56 45 43 47 41                            ; "DMVECGA" (companion enhanced driver)
  0000:000E  db 00                                                ; NUL terminator
  0000:000F  db FF 00 88 E7 9C AA CC 10 00 08 00 01 00 00 00 00 ; display config flags
  0000:001F  db 80 02 C8 00 10 05 10 00 02 02 02 01 10 00 02 02 ; 640x200, char metrics
  0000:002F  db 02                                              ; capabilities tail

; ------------------------------------------------------------------------
; SEGMENT seg_0003  (21664 bytes, file 0x0230-0x56D0)
; Main driver code + font data + drawing operations
; (Mostly data blocks -- disassembler could not decode inline code)
; ------------------------------------------------------------------------
seg_0003:

  ; --- Entry/reset clip bounds ---
  0003:0000  db 00 CB EA F3 55 00 00 90 50 B8 FF 7F 26 A3 51 01 ; [RELOC->seg_0000]
  0003:0010  db 26 A3 53 01 40 26 A3 55 01 26 A3 57 01 58 C3 26 ; resetClipBounds
  0003:0020  db 80 0E 80 00 04 E8 E0 FF E8 1A 00 26 80 26 80 00 ; saveClipBounds
  0003:0030  db FB 26 A1 51 01 26 8B 1E 53 01 26 8B 0E 55 01 26 ;
  0003:0040  db 8B 16 57 01 C3                                  ; ret

  ; --- Ellipse drawing (Bresenham midpoint) ---
  0003:0045  db 50 53 51 52 56 57 55                            ; drawEllipse entry
  ; [~21KB of driver code and font data follows]
  ; See DMVSVGA.RES for equivalent annotated functions.
  ; The CGA standard driver implements the same ~100+ function API
  ; with CGA-specific pixel addressing and color handling.

; ------------------------------------------------------------------------
; SEGMENT seg_054D  (304 bytes, file 0x56D0-0x5800)
; Function dispatch table -- word offsets into seg_0003
; ------------------------------------------------------------------------
seg_054D:

  ; Each word is an offset into seg_0003 for the corresponding function.
  ; Function 0 = first word, function 1 = second word, etc.
  ; [304 bytes = ~152 function entries]

; ------------------------------------------------------------------------
; SEGMENT seg_0560  (1056 bytes, file 0x5800-0x5C20)
; TSR startup, dispatch, INT 08h/09h hooks, mode switching
; ------------------------------------------------------------------------
seg_0560:

  ; --- Driver name and config header ---
  0560:0000  db 44 4D 56 53 43 47 41                            ; "DMVSCGA"
  0560:0007  db 00                                                ; NUL
  0560:0008  db 25 00 60 05 00 00 00 00 00 00 00 00 00 00 00 00 ; [RELOC->seg_0560]
  0560:0018  db 00 00 00 00 00 00 00 00 00 00 03 11 21 C7 06 00 ; config data
  0560:0028  db 00 AD 05 BB 55 00 B8 59 00 CB                   ; [RELOC->seg_05AD]

  ; --- entry_point: TSR installation ---
entry_point:                                                 ; 0560:0032
  0560:0032  0e                push     cs
  0560:0033  07                pop      es
  0560:0034  bb0000            mov      bx, 0
  0560:0037  268c5f20          mov      word ptr es:[bx + 0x20], ds
  0560:003B  b90000            mov      cx, 0                ; RELOC->seg_0000
  0560:003E  b8f001            mov      ax, 0x1f0
  0560:0041  cde0              int      0xe0                 ; INT E0h/01h: register driver
  0560:0043  26a32104          mov      word ptr es:[0x421], ax ; save registration result
  0560:0047  8b160200          mov      dx, word ptr [2]     ; PSP top of memory
  0560:004B  8cd8              mov      ax, ds
  0560:004D  2bd0              sub      dx, ax               ; DX = paragraphs to keep
  0560:004F  b80031            mov      ax, 0x3100
  0560:0052  cd21              int      0x21                 ; INT 21h/31h: TSR

  ; --- dmvscga_dispatchFast: fast path dispatcher ---
  0560:0054  90                nop
  0560:0055  d1e0              shl      ax, 1                ; AX *= 2 (word index)
  0560:0057  732e              jae      0x87                 ; -> full dispatch
  0560:0059  2ea3ab04          mov      word ptr cs:[0x4ab], ax ; save func index
  0560:005D  8b460f            mov      ax, word ptr [bp + 0xf]
  0560:0060  8b6e09            mov      bp, word ptr [bp + 9]
  0560:0063  53                push     bx
  0560:0064  06                push     es
  0560:0065  bb6005            mov      bx, 0x560            ; RELOC->seg_0560
  0560:0068  8ec3              mov      es, bx
  0560:006A  268e06af04        mov      es, word ptr es:[0x4af]
  0560:006F  bb0f00            mov      bx, 0xf
  0560:0072  2e031eab04        add      bx, word ptr cs:[0x4ab]
  0560:0077  268b1f            mov      bx, word ptr es:[bx]
  0560:007A  2e891ead04        mov      word ptr cs:[0x4ad], bx
  0560:007F  07                pop      es
  0560:0080  5b                pop      bx
  0560:0081  2eff16ad04        call     word ptr cs:[0x4ad]  ; near call to handler
  0560:0086  cb                retf

  ; --- dmvscga_dispatchFull: full dispatch with context save ---
loc_0560_0087:                                               ; 0560:0087
  0560:0087  ff760f            push     word ptr [bp + 0xf]
  0560:008A  53                push     bx
  0560:008B  06                push     es
  0560:008C  ff7609            push     word ptr [bp + 9]
  0560:008F  83ec0e            sub      sp, 0xe
  0560:0092  8bec              mov      bp, sp
  0560:0094  89460a            mov      word ptr [bp + 0xa], ax
  0560:0097  2ea12104          mov      ax, word ptr cs:[0x421] ; display ID
  0560:009B  3cff              cmp      al, 0xff
  0560:009D  7409              je       0xa8
  0560:009F  52                push     dx
  0560:00A0  8ad0              mov      dl, al
  0560:00A2  b8044d            mov      ax, 0x4d04           ; acquire mutex
  0560:00A5  cde0              int      0xe0
  0560:00A7  5a                pop      dx

loc_0560_00A8:                                               ; 0560:00A8
  0560:00A8  89460c            mov      word ptr [bp + 0xc], ax
  0560:00AB  bb6005            mov      bx, 0x560            ; RELOC->seg_0560
  0560:00AE  8ec3              mov      es, bx
  0560:00B0  c746020000        mov      word ptr [bp + 2], 0 ; RELOC->seg_0000
  0560:00B5  2e8e06af04        mov      es, word ptr cs:[0x4af]
  0560:00BA  bb0f00            mov      bx, 0xf
  0560:00BD  035e0a            add      bx, word ptr [bp + 0xa]
  0560:00C0  268b1f            mov      bx, word ptr es:[bx]
  0560:00C3  895e00            mov      word ptr [bp], bx    ; handler offset
  0560:00C6  8c4e08            mov      word ptr [bp + 8], cs
  0560:00C9  b8e200            mov      ax, 0xe2             ; epilogue offset
  0560:00CC  894606            mov      word ptr [bp + 6], ax
  0560:00CF  bb3100            mov      bx, 0x31
  0560:00D2  895e04            mov      word ptr [bp + 4], bx
  0560:00D5  8b4614            mov      ax, word ptr [bp + 0x14]
  0560:00D8  8e4610            mov      es, word ptr [bp + 0x10]
  0560:00DB  8b5e12            mov      bx, word ptr [bp + 0x12]
  0560:00DE  8b6e0e            mov      bp, word ptr [bp + 0xe]
  0560:00E1  cb                retf                          ; chain to handler

  ; --- dmvscga_dispatchEpilogue: release mutex and return ---
  0560:00E2  db 50                                              ; push ax
  0560:00E3  55                push     bp
  0560:00E4  8bec              mov      bp, sp
  0560:00E6  8b4606            mov      ax, word ptr [bp + 6]
  0560:00E9  3cff              cmp      al, 0xff
  0560:00EB  7409              je       0xf6
  0560:00ED  52                push     dx
  0560:00EE  8ad0              mov      dl, al
  0560:00F0  b8054d            mov      ax, 0x4d05           ; release mutex
  0560:00F3  cde0              int      0xe0
  0560:00F5  5a                pop      dx

loc_0560_00F6:                                               ; 0560:00F6
  0560:00F6  5d                pop      bp
  0560:00F7  58                pop      ax
  0560:00F8  83c40c            add      sp, 0xc
  0560:00FB  cb                retf

  ; --- dmvscga_initDriver: initialize and set video mode ---
  ; Saves DS/ES segments, calls mode setup, hooks interrupts.
  0560:00FC  db 53 2E 8C 1E A7 04 2E 8C 06 A9 04 E8 EE 00 9A D9 ; save segs, call init
  0560:010C  db 25 00 00 E8 FC 00 E8 87 00 5B B8 03 00 C3       ; [RELOC->seg_0000]

  ; --- dmvscga_shutdownDriver / setVideoMode ---
  ; Includes INT 10h/12h call to detect display type.
  0560:011C  db F6 06 53 00 01 75 27 3C 00                      ; check mode flag
  0560:0123  db 74 37 50 53 51                                  ; setVideoMode entry
  0560:0128  db 80 26 53 00 FB B4 12 B3 10 CD 10 80 FB 10 74 05 ; INT 10h/12h: EGA info
  0560:0138  db 80 0E 53 00 04 59 5B 58 E8 1A 00 E8 82 00 EB 14 ; set flag, hook INTs
  0560:0148  db 3C 00 75 0D 53 E8 A8 00 9A 2D 26 00 00 E8 B6 00 ; [RELOC->seg_0000]
  0560:0158  db 5B E8 01 00 C3                                  ; ret

  ; --- dmvscga_lookupCursorRate ---
  0560:015D  db 50 56 80 26 53 00 FE 0A C0 74 05                ; check flag
  0560:0168  db 80 0E 53 00 01 B4 03 F6 E4 BE 23 04 03 F0 2E 8B ; calc rate
  0560:0178  db 04 FA A3 57 00 A3 54 00 2E 8A 44 02 A2 59 00 A2 ; store values
  0560:0188  db 56 00 FB 5E 58 C3                               ; ret

  ; --- dmvscga_lookupByIndex ---
  0560:018E  db 53 32 FF 8A D8 81 C3 3B 04 2E                   ; index lookup
  0560:0198  db 8A 07 5B C3                                     ; ret

  ; --- dmvscga_hookTimerInt: hook INT 08h ---
  0560:019C  db 53 52 1E 06 F6 06 53 00 01 74 03 E8             ; check if already hooked
  0560:01A8  db 1E 00 B4 35 B0 08 CD 21 89 1E 0A 00 8C 06 0C 00 ; INT 21h/35h: get vec
  0560:01B8  db B4 25 B0 08 BA 20 02 0E 1F CD 21 07 1F 5A 5B C3 ; INT 21h/25h: set vec

  ; --- dmvscga_hookKeyboardInt: hook INT 09h ---
  0560:01C8  db 50 53 52 1E 06 F6 06 53 00 02 75 1E 80 0E 53 00 ; check flag
  0560:01D8  db 02 B4 35 B0 09 CD 21 89 1E 5A 00 8C 06 5C 00 B4 ; INT 21h/35h: get vec
  0560:01E8  db 25 B0 09 BA 53 03 0E 1F CD 21 07 1F 5A 5B 58 C3 ; INT 21h/25h: set vec

  ; --- dmvscga_acquireMutex ---
  0560:01F8  db 50 2E A1 21 04 3C FF 74 09 52 8A D0 B8 04 4D CD ; INT E0h/4Dh
  0560:0208  db E0 5A 8A D8 58 C3                               ;

  ; --- dmvscga_releaseMutex ---
  0560:020E  db 50 8A C3 3C FF 74 09 52 8A D0                   ; INT E0h/4Dh
  0560:0218  db B8 05 4D CD E0 5A 58 C3                         ;

  ; --- dmvscga_timerISR: INT 08h handler ---
  ; Chains to original INT 08h, then checks cursor blink state.
  ; If cursor needs updating, calls into drawing code to blit/erase.
  0560:0220  db 50 53 56 1E 06 FB B8 00                         ; push regs
  0560:0228  db 00 8E D8 A1 86 03 8E D8 2E 8E 06 A7 04 9C FA 26 ; load host seg
  0560:0238  db FF 1E 0A 00 26 80 3E 0F 00 00 74 03 E9 06 01 26 ; chain original INT 08h
  ; [cursor blink logic continues through 0x0352]
  ; Calls into seg_0003 drawing functions via relocations:
  ;   [RELOC->seg_0000] at 0560:02DB, 0560:02E9, 0560:02EE
  ;   [RELOC->seg_0000] at 0560:030C, 0560:0335, 0560:033E, 0560:0343
  0560:0348  db 07 1F 5E 5B 58 CF                               ; pop, IRET

  ; --- dmvscga_keyboardISR: INT 09h handler ---
  0560:0353  db 50 53 51 06 1E                                  ; push regs
  0560:0358  db 2E 8E 06 A7 04 B8 40 00 8E D8 8B 1E 1A 00 8B 0E ; BIOS data area
  0560:0368  db 1C 00 9C 26 FF 1E 5A 00 39 1E 1A 00 75 06 39 0E ; chain original INT 09h
  0560:0378  db 1C 00 74 0F E8 12 00 0B C0 74 08 89 1E 1A 00 89 ; check buffer change
  0560:0388  db 0E 1C 00 1F 07 59 5B 58 CF                      ; pop, IRET

  ; --- dmvscga_checkCursorState ---
  0560:0393  db 53 1E 33 C0 2E 8E 1E                            ; check state
  0560:039A  db A7 04 F6 06 53 00 01 74 24 83 3E 54 00 00 75 0D ;
  0560:03AA  db 80 3E 56 00 00 75 06 E8 43 00 B8 FF FF 8B 1E 57 ;
  0560:03BA  db 00 89 1E 54 00 8A 1E 59 00 88 1E 56 00 1F 5B C3 ;

  ; --- dmvscga_disablePalette: blank CGA screen ---
  ; Reads CGA status ports, then clears bit 3 of mode register.
  ; For CGA-only systems, uses port 3D8h.
  ; For systems with bit 2 flag set, also checks MDA port 3BAh.
  0560:03C8  db 50 52 26 F6 06 53 00 04 74 10 BA BA 03 EC BA DA ; check adapter type
  0560:03D8  db 03 EC BA C0 03 B0 00 EE EB 10                   ; out 3C0h,00h (EGA path)
  0560:03E2  db 1E B8 40 00 8E D8                               ; or CGA path:
  0560:03E8  db A0 65 00 24 F7 1F BA D8 03 EE 5A 58 C3          ; [0040:0065] & F7h -> 3D8h

  ; --- dmvscga_enablePalette: unblank CGA screen ---
  0560:03F8  db 50 52 F6                                        ;
  0560:03FB  db 06 53 00 04 74 10 BA BA 03 EC BA DA 03 EC BA C0 ;
  0560:0408  db 03 B0 20 EE EB 10 1E B8 40 00 8E D8 A0 65 00 0C ; out 3D8h, [0040:0065]|08h
  0560:0418  db 08 1F BA D8 03 EE 5A 58                         ;

; ------------------------------------------------------------------------
; SEGMENT seg_05A2  (160 bytes, file 0x5C20-0x5CC0)
; Key mapping table + driver descriptor
; ------------------------------------------------------------------------
seg_05A2:

  05A2:0000  db C3 00 00 00 00 00 55 15 00 AA 2A 00 55 55 00 00 ; cursor blink rates
  05A2:0010  db 80 00 00 00 01 00 00 02 00 00 04 19 FF FF FF FF ; fill patterns
  ; [key scan code mapping table continues]
  05A2:0080  db FF FF 69 FF 68 FF                               ; key codes
  05A2:0082  db FE 00 B8 00 00 00 00 00 00                      ; descriptor: seg B800h
  05A2:008F  db 4D 05 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; [RELOC->seg_054D]

; ------------------------------------------------------------------------
; SEGMENT seg_05AC  (2 bytes, file 0x5CC0-0x5CC2)
; Stack segment
; ------------------------------------------------------------------------
seg_05AC:

  05AC:0000  db 00 00                                           ; initial stack
