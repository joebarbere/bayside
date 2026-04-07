; ========================================================================
; DMVSTC16.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Standard Video Driver: Tandy 16-Color (320x200, 16 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVSTC16.RES is the standard-mode Tandy 16-color video driver for
; DeskMate 3.05. Standard drivers handle mode switching, cursor management,
; timer-based blinking, window/display list management, font loading, and
; high-level drawing operations. They call into the corresponding enhanced
; driver (DMVETC16.RES) for pixel-level rendering primitives.
;
; The standard driver installs itself as a TSR via INT 21h/31h and hooks
; INT 08h (timer) and INT 09h (keyboard) for cursor blink and keyboard
; state tracking. It provides a large dispatch table of ~100+ functions
; accessible through the DeskMate host API.
;
; Video mode: Tandy 16-color mode (320x200, 16 colors)
; Framebuffer: segment A000h (Tandy video RAM)
; Bytes per scanline: variable (depends on mode, typically 160 for 320x200x16)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 23138 bytes
; Code+data size: 22626 bytes
; DM89 entry point: 053F:0032
; SS:SP = 0586:0002
; Min alloc: 0x00C3 paragraphs
; Max alloc: 0x04C3 paragraphs
;
; DM89 signature: present
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000  0x0020 bytes  DATA       Version string + config ("33.18", "DMVETC16")
;   seg_0002  0x52B0 bytes  CODE/DATA  Main driver code + font data + drawing ops
;   seg_052D  0x0120 bytes  DATA       Function pointer table (dispatch vectors)
;   seg_053F  0x03D0 bytes  CODE       TSR startup, dispatch, INT hooks, mode switch
;   seg_057C  0x00A0 bytes  DATA       Key mapping table + driver descriptor
;   seg_0586  0x0002 bytes  STACK      Stack segment
;   seg_0587  (BSS)         BSS        Uninitialized data segment
;
; ========================================================================
; ARCHITECTURE
; ========================================================================
;
; The Tandy 16-color standard driver follows the same architecture as
; DMVSVGA and DMVSEGA:
;
; 1. Configuration Data (seg_0000, 32 bytes):
;    Version string "33.18", enhanced driver name "DMVETC16",
;    and Tandy-specific display configuration.
;
;    Key config values:
;      0x0006: A0 = framebuffer segment high byte (A000h)
;      0x0010: 80 02 C8 00 = 640x200 logical resolution
;              (320x200 physical, doubled horizontally)
;
; 2. Main Driver Code (seg_0002, ~21KB):
;    Functionally equivalent to DMVSVGA/DMVSEGA but with Tandy-specific
;    video mode handling, pixel addressing (4bpp packed), and port access
;    through the BIOS data area.
;
; 3. Function Dispatch Table (seg_052D, 288 bytes):
;    ~100+ word-sized offsets into seg_0002.
;
; 4. TSR/Dispatcher Code (seg_053F, 976 bytes):
;    Same structure as DMVSEGA/DMVSVGA. Entry point at 053F:0032.
;
; 5. Key Mapping / Descriptor (seg_057C, 160 bytes):
;    Same structure as other standard drivers.
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; Tandy Video Mode Register (port from BIOS data area):
;   053F:03AC  push dx
;              push ax
;              push ds
;              mov ax, 0x0040
;              mov ds, ax               ; DS = BIOS data area
;              mov al, [0x0065]         ; Read current mode byte
;              and al, 0xF7            ; Clear bit 3 (video enable)
;              pop ds
;              mov dx, 0x03D8
;              out dx, al               ; Write to mode register
;   053F:03BC  (same but OR 0x08 to enable video)
;
; The Tandy standard driver accesses the video mode register indirectly
; through the BIOS data area at 0040:0065, identical to the CGA driver.
; This is because the Tandy 1000 series uses CGA-compatible register
; addresses for basic mode control.
;
; Port 3D8h (CGA/Tandy Mode Control Register):
;   Bit 3 = Video signal enable (1=on, 0=blank)
;   053F:03AC-03BB  dmvstc16_disablePalette  Blank screen
;   053F:03BC-03CF  dmvstc16_enablePalette   Unblank screen
;
; BIOS Data Area (0040:0065):
;   Contains the current CGA/Tandy mode register value. Read to
;   determine the current state before modifying bit 3 for blanking.
;
; Note: Unlike the EGA/VGA drivers which use the Attribute Controller
; (port 3C0h) for palette blanking, the Tandy driver uses the CGA-
; compatible mode control register at port 3D8h, reading the current
; value from the BIOS data area to preserve other mode bits.
;
; Tandy framebuffer segment: A000h
;   The Tandy 1000 maps video RAM at segment A000h for 16-color modes
;   (unlike CGA which uses B800h). This is configured in seg_0000
;   at offset 0x0006 and in the descriptor at seg_057C.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register standard driver with DeskMate host
;   053F:0041  CX=seg_0000 (config data), AX=0x01F0
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex
;   053F:00A5  Before dispatching draw calls
;
; INT E0h, AH=4Dh/05  -- Release display mutex
;   053F:00F3  After draw calls complete
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   053F:0052  Install driver as TSR
;
; INT 21h, AH=25h  -- Set interrupt vector
;   053F:019C  Set INT 08h handler (timer tick for cursor blink)
;   053F:01CC  Set INT 09h handler (keyboard state tracking)
;
; INT 21h, AH=35h  -- Get interrupt vector
;   053F:018C  Save original INT 08h vector
;   053F:01BC  Save original INT 09h vector
;
; ========================================================================
; FUNCTION INDEX (selected, ~100+ total)
; ========================================================================
;
; --- TSR / Startup (seg_053F) ---
;
;   Address   Name                           Description
;   -------   ----                           -----------
;   053F:0000 (data: driver name)            "DMVSTC16" + config header
;   053F:0032 entry_point                    TSR entry: register, go resident
;   053F:0055 dmvstc16_dispatchFast          Fast dispatch path (near call)
;   053F:0087 dmvstc16_dispatchFull          Full dispatch with context save
;   053F:00E2 dmvstc16_dispatchEpilogue      Epilogue: release mutex, restore
;   053F:00FC dmvstc16_initDriver            Initialize driver state, set video mode
;   053F:011C dmvstc16_shutdownDriver        Restore video mode, unhook interrupts
;   053F:013C dmvstc16_setVideoMode          Set Tandy 16-color mode
;   053F:0155 dmvstc16_lookupCursorRate      Lookup cursor blink rate from table
;   053F:0185 dmvstc16_hookTimerInt          Hook INT 08h for cursor blink
;   053F:01AD dmvstc16_hookKeyboardInt       Hook INT 09h for key state tracking
;   053F:01DD dmvstc16_acquireMutex          Acquire display mutex via INT E0h
;   053F:01EE dmvstc16_releaseMutex          Release display mutex via INT E0h
;   053F:0205 dmvstc16_timerISR              INT 08h handler (cursor blink logic)
;   053F:0338 dmvstc16_keyboardISR           INT 09h handler (mouse button state)
;   053F:0378 dmvstc16_checkCursorState      Check if cursor needs redraw
;   053F:03AC dmvstc16_disablePalette        Blank screen via mode register
;   053F:03BC dmvstc16_enablePalette         Unblank screen via mode register
;
; --- Configuration (seg_0000) ---
;
;   0000:0000 (version)                     "33.18"
;   0000:0007 (companion)                   "DMVETC16"
;   0000:0010 (config)                      Display resolution + capabilities
;
; --- Main Driver Functions (seg_0002) ---
;
;   Functionally equivalent to DMVSVGA/DMVSEGA seg_0003/seg_0006.
;   See DMVSVGA.RES for detailed function descriptions.
;
; ========================================================================
; NOTES
; ========================================================================
;
; - Version "33.18" matches DMVSEGA, confirming these were developed
;   in parallel and frozen before the final VGA revision ("33.19").
;
; - The Tandy driver uses A000h for its framebuffer, same as EGA/VGA,
;   because the Tandy 1000 maps its 16-color video memory there.
;   This differs from CGA which uses B800h.
;
; - The companion enhanced driver is "DMVETC16" (8 characters, the
;   longest enhanced driver name). This handles the Tandy-specific
;   4bpp packed pixel format at the hardware level.
;
; - The disablePalette/enablePalette routines use the CGA-compatible
;   port 3D8h (via BIOS data area 0040:0065), same as DMVSCGA.
;   This is because the Tandy 1000's video subsystem is CGA-register-
;   compatible for basic mode control, even in 16-color modes.
;
; - The config segment is only 32 bytes (smallest of all standard
;   drivers), containing just the version, companion name, and basic
;   resolution/capability data without the extended palette maps
;   that the EGA driver includes.
;
; - The TSR segment is 976 bytes, matching EGA and VGA standard drivers.
;
; ========================================================================

; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (32 bytes, file 0x0200-0x0220)
; Version string + display configuration
; ------------------------------------------------------------------------
seg_0000:

  0000:0000  db 33 33 2E 31 38                                  ; "33.18" (version)
  0000:0005  db 00                                                ; NUL
  0000:0006  db A0                                              ; framebuffer seg high byte (A0xx)
  0000:0007  db 44 4D 56 45 54 43 31 36                         ; "DMVETC16" (companion)
  0000:000F  db 00                                                ; NUL
  0000:0010  db FF 00 88 E7 9C AA CC 10 00 08 00 06 00 00 00 00 ; display config

; ------------------------------------------------------------------------
; SEGMENT seg_0002  (21168 bytes, file 0x0220-0x54D0)
; Main driver code + font data + drawing operations
; ------------------------------------------------------------------------
seg_0002:

  ; --- Entry/reset clip bounds ---
  0002:0000  db 80 02 C8 00 10 05 10 00 10 02 02 00 CB EA E4 53 ; resolution data
  0002:0010  db 00 00 90 50 B8 FF 7F 26 A3 51 01 26 A3 53 01 40 ; [RELOC->seg_0000]
  0002:0020  db 26 A3 55 01 26 A3 57 01 58 C3 26 80 0E 80 00 04 ; resetClipBounds
  ; [~21KB of driver code and font data follows]

; ------------------------------------------------------------------------
; SEGMENT seg_052D  (288 bytes, file 0x54D0-0x55F0)
; Function dispatch table -- word offsets into seg_0002
; ------------------------------------------------------------------------
seg_052D:

  ; ~144 function entries

; ------------------------------------------------------------------------
; SEGMENT seg_053F  (976 bytes, file 0x55F0-0x59C0)
; TSR startup, dispatch, INT 08h/09h hooks, mode switching
; ------------------------------------------------------------------------
seg_053F:

  ; --- Driver name and config header ---
  053F:0000  db 44 4D 56 53 54 43 31 36 25                      ; "DMVSTC16%"
  053F:0009  db 00                                                ; NUL
  053F:000A  db 3F 05 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; [RELOC->seg_053F]
  053F:001A  db 00 00 00 00 00 00 00 00 03 12 21 C7 06 00 00 87 ; [RELOC->seg_0587]
  053F:002A  db 05 BB 55 00 B8 59 00 CB                         ; config data

  ; --- entry_point: TSR installation ---
entry_point:                                                 ; 053F:0032
  053F:0032  0e                push     cs
  053F:0033  07                pop      es
  053F:0034  bb0000            mov      bx, 0
  053F:0037  268c5f20          mov      word ptr es:[bx + 0x20], ds
  053F:003B  b90000            mov      cx, 0                ; RELOC->seg_0000
  053F:003E  b8f001            mov      ax, 0x1f0
  053F:0041  cde0              int      0xe0                 ; INT E0h/01h: register
  053F:0043  26a3d703          mov      word ptr es:[0x3d7], ax ; save display ID
  053F:0047  8b160200          mov      dx, word ptr [2]
  053F:004B  8cd8              mov      ax, ds
  053F:004D  2bd0              sub      dx, ax
  053F:004F  b80031            mov      ax, 0x3100
  053F:0052  cd21              int      0x21                 ; INT 21h/31h: TSR

  ; --- dmvstc16_dispatchFast ---
  053F:0054  90                nop
  053F:0055  d1e0              shl      ax, 1
  053F:0057  732e              jae      0x87
  053F:0059  2ea36104          mov      word ptr cs:[0x461], ax
  053F:005D  8b460f            mov      ax, word ptr [bp + 0xf]
  053F:0060  8b6e09            mov      bp, word ptr [bp + 9]
  053F:0063  53                push     bx
  053F:0064  06                push     es
  053F:0065  bb3f05            mov      bx, 0x53f            ; RELOC->seg_053F
  053F:0068  8ec3              mov      es, bx
  053F:006A  268e066504        mov      es, word ptr es:[0x465]
  053F:006F  bb0000            mov      bx, 0
  053F:0072  2e031e6104        add      bx, word ptr cs:[0x461]
  053F:0077  268b1f            mov      bx, word ptr es:[bx]
  053F:007A  2e891e6304        mov      word ptr cs:[0x463], bx
  053F:007F  07                pop      es
  053F:0080  5b                pop      bx
  053F:0081  2eff166304        call     word ptr cs:[0x463]
  053F:0086  cb                retf

  ; --- dmvstc16_dispatchFull ---
loc_053F_0087:                                               ; 053F:0087
  053F:0087  ff760f            push     word ptr [bp + 0xf]
  053F:008A  53                push     bx
  053F:008B  06                push     es
  053F:008C  ff7609            push     word ptr [bp + 9]
  053F:008F  83ec0e            sub      sp, 0xe
  053F:0092  8bec              mov      bp, sp
  053F:0094  89460a            mov      word ptr [bp + 0xa], ax
  053F:0097  2ea1d703          mov      ax, word ptr cs:[0x3d7]
  053F:009B  3cff              cmp      al, 0xff
  053F:009D  7409              je       0xa8
  053F:009F  52                push     dx
  053F:00A0  8ad0              mov      dl, al
  053F:00A2  b8044d            mov      ax, 0x4d04           ; acquire mutex
  053F:00A5  cde0              int      0xe0
  053F:00A7  5a                pop      dx

loc_053F_00A8:                                               ; 053F:00A8
  053F:00A8  89460c            mov      word ptr [bp + 0xc], ax
  053F:00AB  bb3f05            mov      bx, 0x53f            ; RELOC->seg_053F
  053F:00AE  8ec3              mov      es, bx
  053F:00B0  c746020000        mov      word ptr [bp + 2], 0 ; RELOC->seg_0000
  053F:00B5  2e8e066504        mov      es, word ptr cs:[0x465]
  053F:00BA  bb0000            mov      bx, 0
  053F:00BD  035e0a            add      bx, word ptr [bp + 0xa]
  053F:00C0  268b1f            mov      bx, word ptr es:[bx]
  053F:00C3  895e00            mov      word ptr [bp], bx
  053F:00C6  8c4e08            mov      word ptr [bp + 8], cs
  053F:00C9  b8e200            mov      ax, 0xe2
  053F:00CC  894606            mov      word ptr [bp + 6], ax
  053F:00CF  bb2c00            mov      bx, 0x2c
  053F:00D2  895e04            mov      word ptr [bp + 4], bx
  053F:00D5  8b4614            mov      ax, word ptr [bp + 0x14]
  053F:00D8  8e4610            mov      es, word ptr [bp + 0x10]
  053F:00DB  8b5e12            mov      bx, word ptr [bp + 0x12]
  053F:00DE  8b6e0e            mov      bp, word ptr [bp + 0xe]
  053F:00E1  cb                retf

  ; --- dmvstc16_dispatchEpilogue ---
  053F:00E2  db 50
  053F:00E3  55                push     bp
  053F:00E4  8bec              mov      bp, sp
  053F:00E6  8b4606            mov      ax, word ptr [bp + 6]
  053F:00E9  3cff              cmp      al, 0xff
  053F:00EB  7409              je       0xf6
  053F:00ED  52                push     dx
  053F:00EE  8ad0              mov      dl, al
  053F:00F0  b8054d            mov      ax, 0x4d05           ; release mutex
  053F:00F3  cde0              int      0xe0
  053F:00F5  5a                pop      dx

loc_053F_00F6:                                               ; 053F:00F6
  053F:00F6  5d                pop      bp
  053F:00F7  58                pop      ax
  053F:00F8  83c40c            add      sp, 0xc
  053F:00FB  cb                retf

  ; --- dmvstc16_initDriver ---
  053F:00FC  db 53 2E 8C 1E 5D 04 2E 8C 06 5F 04 E8 D3 00 9A 91
  053F:010C  db 23 00 00 E8 E1 00 E8 6C 00 5B B8 03 00 C3       ; [RELOC->seg_0000]

  ; --- dmvstc16_shutdownDriver / setVideoMode ---
  053F:011C  db F6 06 53 00 01 75 0C 3C 00 74 1C E8 1A 00 E8 82 00 EB
  053F:012C  db 14 3C 00 75 0D 53 E8 A8 00 9A E5 23 00 00 E8 B6 ; [RELOC->seg_0000]
  053F:013C  db 00 5B E8 01 00 C3

  ; --- dmvstc16_lookupCursorRate ---
  053F:0142  db 50 56 80 26 53 00 FE 0A C0 74
  053F:014C  db 05 80 0E 53 00 01 B4 03 F6 E4 BE D9 03 03 F0 2E
  053F:015C  db 8B 04 FA A3 57 00 A3 54 00 2E 8A 44 02 A2 59 00
  053F:016C  db A2 56 00 FB 5E 58 C3

  ; --- dmvstc16_lookupByIndex ---
  053F:0173  db 53 32 FF 8A D8 81 C3 F1 03
  053F:017C  db 2E 8A 07 5B C3

  ; --- dmvstc16_hookTimerInt ---
  053F:0181  db 53 52 1E 06 F6 06 53 00 01 74 03 E8
  053F:018C  db 1E 00 B4 35 B0 08 CD 21 89 1E 0A 00 8C 06 0C 00
  053F:019C  db B4 25 B0 08 BA 05 02 0E 1F CD 21 07 1F 5A 5B C3

  ; --- dmvstc16_hookKeyboardInt ---
  053F:01AC  db C3 50 53 52 1E 06 F6 06 53 00 02 75 1E 80 0E 53
  053F:01BC  db 00 02 B4 35 B0 09 CD 21 89 1E 5A 00 8C 06 5C 00
  053F:01CC  db B4 25 B0 09 BA 38 03 0E 1F CD 21 07 1F 5A 5B 58 C3

  ; --- dmvstc16_acquireMutex / releaseMutex ---
  053F:01DC  db C3 50 2E A1 D7 03 3C FF 74 09 52 8A D0 B8 04 4D
  053F:01EC  db CD E0 5A 8A D8 58 C3 50 8A C3 3C FF 74 09 52 8A
  053F:01FC  db D0 B8 05 4D CD E0 5A 58 C3

  ; --- dmvstc16_timerISR: INT 08h handler ---
  053F:0205  db 50 53 56 1E 06 FB B8
  053F:020C  db 00 00 8E D8 A1 86 03 8E D8 2E 8E 06 5D 04 9C FA
  053F:021C  db 26 FF 1E 0A 00 26 80 3E 0F 00 00 74 03 E9 06 01
  ; [cursor blink logic with relocations into seg_0000]
  053F:032C  db A2 89 00 E8 C1 FE 07 1F 5E 5B 58 CF

  ; --- dmvstc16_keyboardISR ---
  053F:0338  db 50 53 51 06 1E
  053F:033C  db 2E 8E 06 5D 04 B8 40 00 8E D8 8B 1E 1A 00 8B
  053F:034C  db 0E 1C 00 9C 26 FF 1E 5A 00 39 1E 1A 00 75 06 39
  053F:035C  db 0E 1C 00 74 0F E8 12 00 0B C0 74 08 89 1E 1A 00
  053F:036C  db 89 0E 1C 00 1F 07 59 5B 58 CF

  ; --- dmvstc16_checkCursorState ---
  053F:0376  db 53 1E 33 C0 2E 8E
  053F:037C  db 1E 5D 04 F6 06 53 00 01 74 24 83 3E 54 00 00 75
  053F:038C  db 0D 80 3E 56 00 00 75 06 E8 2B 00 B8 FF FF 8B 1E
  053F:039C  db 57 00 89 1E 54 00 8A 1E 59 00 88 1E 56 00 1F 5B C3

  ; --- dmvstc16_disablePalette: blank screen via Tandy mode register ---
  ; Reads mode byte from BIOS data area (0040:0065), clears bit 3,
  ; writes to port 3D8h to disable video output.
  053F:03AC  db 50 52 1E B8 40 00 8E D8 A0 65 00 24 F7 1F BA     ; push; DS=0040; al=[0065]&F7h
  053F:03BC  db D8 03 EE 5A 58 C3                               ; out 3D8h, al; ret

  ; --- dmvstc16_enablePalette: unblank screen via Tandy mode register ---
  ; Same as above but sets bit 3 (OR 0x08) to enable video output.
  053F:03C2  db 50 52 1E B8 40 00 8E D8 A0 65                   ; push; DS=0040; al=[0065]
  053F:03CC  db 00 0C 08 1F                                     ; or al,08h; pop ds

; ------------------------------------------------------------------------
; SEGMENT seg_057C  (160 bytes, file 0x59C0-0x5A60)
; Key mapping table + driver descriptor
; ------------------------------------------------------------------------
seg_057C:

  057C:0000  db BA D8 03 EE 5A 58 C3 00 00 00 00 00 55 15 00 AA ; out dx,al; ret; blink rates
  057C:0010  db 2A 00 55 55 00 00 80 00 00 00 01 00 00 02 00 00 ; fill patterns
  ; [key mapping table continues]
  057C:0080  db 28 E6 27 E5 26 E4 25 E3 24 23 FE 00 A0 00 00 00 ; descriptor: seg A000h
  057C:0090  db 00 00 00 00 00 2D 05 00 00 00 00 00 00 00 00 00 ; [RELOC->seg_052D]

; ------------------------------------------------------------------------
; SEGMENT seg_0586  (2 bytes, file 0x5A60-0x5A62)
; Stack segment
; ------------------------------------------------------------------------
seg_0586:

  0586:0000  db 00 00                                           ; initial stack
