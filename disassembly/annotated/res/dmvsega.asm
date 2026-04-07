; ========================================================================
; DMVSEGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Standard Video Driver: EGA (640x350, 16 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVSEGA.RES is the standard-mode EGA video driver for DeskMate 3.05.
; Standard drivers handle mode switching, cursor management, timer-based
; blinking, window/display list management, font loading, and high-level
; drawing operations. They call into the corresponding enhanced driver
; (DMVEEGA.RES) for pixel-level rendering primitives.
;
; The standard driver installs itself as a TSR via INT 21h/31h and hooks
; INT 08h (timer) and INT 09h (keyboard) for cursor blink and keyboard
; state tracking. It provides a large dispatch table of ~100+ functions
; accessible through the DeskMate host API.
;
; Video mode: EGA mode 10h (640x350, 16 colors, planar)
; Framebuffer: segment A000h
; Bytes per scanline: 80
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 24082 bytes
; Code+data size: 23570 bytes
; DM89 entry point: 057A:0032
; SS:SP = 05C1:0002
; Min alloc: 0x00C3 paragraphs
; Max alloc: 0x04C3 paragraphs
;
; DM89 signature: present
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000  0x0060 bytes  DATA       Version string + config ("33.18", "DMVEEGA")
;   seg_0006  0x5620 bytes  CODE/DATA  Main driver code + font data + drawing ops
;   seg_0568  0x0120 bytes  DATA       Function pointer table (dispatch vectors)
;   seg_057A  0x03D0 bytes  CODE       TSR startup, dispatch, INT hooks, mode switch
;   seg_05B7  0x00A0 bytes  DATA       Key mapping table + driver descriptor
;   seg_05C1  0x0002 bytes  STACK      Stack segment
;   seg_05C2  (BSS)         BSS        Uninitialized data segment
;
; ========================================================================
; ARCHITECTURE
; ========================================================================
;
; The standard EGA driver follows the same architecture as DMVSVGA:
;
; 1. Configuration Data (seg_0000, 96 bytes):
;    Version string "33.18", enhanced driver name "DMVEEGA",
;    and EGA-specific display configuration with color palette mapping
;    tables (3 palette maps at offsets 0x0F, 0x1F, 0x2F for different
;    EGA modes).
;
;    Key config values:
;      0x0006: A0 = framebuffer segment high byte (A000h)
;      0x004F: 80 02 = 640 horizontal resolution
;      0x0051: 5E 01 = 350 vertical resolution
;
; 2. Main Driver Code (seg_0006, ~22KB):
;    Functionally identical to DMVSVGA seg_0003 but with EGA-specific
;    video mode handling and palette register programming.
;
; 3. Function Dispatch Table (seg_0568, 288 bytes):
;    ~100+ word-sized offsets into seg_0006.
;
; 4. TSR/Dispatcher Code (seg_057A, 976 bytes):
;    Same structure as DMVSVGA. Entry point at 057A:0032.
;
; 5. Key Mapping / Descriptor (seg_05B7, 160 bytes):
;    Same structure as DMVSVGA/DMVSCGA.
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; EGA Attribute Controller (port 3C0h):
;   057A:03AC  in al, 0x3BA    ; Read input status 1 (MDA) to reset flip-flop
;   057A:03AF  in al, 0x3DA    ; Read input status 1 (CGA) to reset flip-flop
;   057A:03B2  in al, 0x3C0    ; Read attribute controller
;              mov al, 0x00    ; Index 0 + palette disable
;              out dx, al      ; Disable palette display (blank screen)
;
; EGA Attribute Controller (palette enable):
;   057A:03BC  in al, 0x3BA    ; Reset flip-flop
;   057A:03BF  in al, 0x3DA    ; Reset flip-flop
;   057A:03C2  in al, 0x3C0    ; Read current state
;              mov al, 0x20    ; Palette address source = enabled
;              out dx, al      ; Re-enable palette display
;
; Note: The EGA attribute controller uses the same port programming as
; VGA (3C0h with flip-flop reset via 3BAh/3DAh). The EGA standard
; driver's palette disable/enable code is identical to DMVSVGA.
;
; EGA framebuffer segment: A000h
;   Configured in seg_0000 at offset 0x0006 (byte 0xA0)
;   and in the descriptor block at seg_05B7:0082 (word 0xA000).
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register standard driver with DeskMate host
;   057A:0041  CX=seg_0000 (config data), AX=0x01F0
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex
;   057A:00A5  Before dispatching draw calls
;
; INT E0h, AH=4Dh/05  -- Release display mutex
;   057A:00F3  After draw calls complete
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   057A:0052  Install driver as TSR
;
; INT 21h, AH=25h  -- Set interrupt vector
;   057A:019C  Set INT 08h handler (timer tick for cursor blink)
;   057A:01CC  Set INT 09h handler (keyboard state tracking)
;
; INT 21h, AH=35h  -- Get interrupt vector
;   057A:018C  Save original INT 08h vector
;   057A:01BC  Save original INT 09h vector
;
; ========================================================================
; FUNCTION INDEX (selected, ~100+ total)
; ========================================================================
;
; --- TSR / Startup (seg_057A) ---
;
;   Address   Name                           Description
;   -------   ----                           -----------
;   057A:0000 (data: driver name)            "DMVSEGA" + config header
;   057A:0032 entry_point                    TSR entry: register, go resident
;   057A:0055 dmvsega_dispatchFast           Fast dispatch path (near call)
;   057A:0087 dmvsega_dispatchFull           Full dispatch with context save
;   057A:00E2 dmvsega_dispatchEpilogue       Epilogue: release mutex, restore
;   057A:00FC dmvsega_initDriver             Initialize driver state, set video mode
;   057A:011C dmvsega_shutdownDriver         Restore video mode, unhook interrupts
;   057A:013C dmvsega_setVideoMode           Set EGA mode and configure registers
;   057A:0155 dmvsega_lookupCursorRate       Lookup cursor blink rate from table
;   057A:0185 dmvsega_hookTimerInt           Hook INT 08h for cursor blink
;   057A:01AD dmvsega_hookKeyboardInt        Hook INT 09h for key state tracking
;   057A:01DD dmvsega_acquireMutex           Acquire display mutex via INT E0h
;   057A:01EE dmvsega_releaseMutex           Release display mutex via INT E0h
;   057A:0205 dmvsega_timerISR               INT 08h handler (cursor blink logic)
;   057A:0338 dmvsega_keyboardISR            INT 09h handler (mouse button state)
;   057A:0378 dmvsega_checkCursorState       Check if cursor needs redraw
;   057A:03AC dmvsega_disablePalette         Blank screen via EGA attr controller
;   057A:03BC dmvsega_enablePalette          Unblank screen via EGA attr controller
;
; --- Configuration (seg_0000) ---
;
;   0000:0000 (version)                     "33.18"
;   0000:0007 (companion)                   "DMVEEGA"
;   0000:000F (palette maps)                3 x 16-byte EGA palette tables
;   0000:004F (resolution)                  640x350
;
; --- Main Driver Functions (seg_0006) ---
;
;   Functionally equivalent to DMVSVGA seg_0003.
;   See DMVSVGA.RES for detailed function descriptions.
;
; ========================================================================
; NOTES
; ========================================================================
;
; - Version "33.18" matches DMVSTC16 and is one minor version behind
;   DMVSVGA ("33.19"), suggesting EGA and Tandy drivers were frozen
;   before the final VGA driver revision.
;
; - The palette disable/enable routines at 057A:03AC and 057A:03BC are
;   identical to the VGA version (DMVSVGA). Both EGA and VGA use the
;   attribute controller at port 3C0h for palette blanking.
;
; - The config segment (seg_0000) is larger than CGA (96 vs 48 bytes)
;   because it includes 3 palette mapping tables (16 bytes each) for
;   different EGA display modes. These map DeskMate logical colors to
;   EGA palette register values.
;
; - The TSR segment is 976 bytes, matching VGA and Tandy standard
;   drivers. CGA is slightly larger at 1056 bytes due to additional
;   mode detection logic (INT 10h/12h).
;
; - The driver descriptor at seg_05B7:0082 contains A0 00 confirming
;   framebuffer at segment A000h, with seg_0568 as the dispatch table.
;
; ========================================================================

; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (96 bytes, file 0x0200-0x0260)
; Version string + display configuration + palette maps
; ------------------------------------------------------------------------
seg_0000:

  0000:0000  db 33 33 2E 31 38                                  ; "33.18" (version)
  0000:0005  db 00                                                ; NUL
  0000:0006  db A0                                              ; framebuffer seg high byte (A0xx)
  0000:0007  db 44 4D 56 45 45 47 41                            ; "DMVEEGA" (companion)
  0000:000E  db 00                                                ; NUL
  ; EGA palette mapping tables and display config:
  0000:000F  db FF 00 88 E7 9C AA CC 10 00 0E 00 00 01 04 05 02 ; palette map 1
  0000:001F  db 03 06 07 08 09 0C 0D 0A 0B 0E 0F 10 01 00 04 05 ; palette map 2
  0000:002F  db 03 02 06 07 09 08 0C 0D 0B 0A 0E 0F 01 00 05 04 ; palette map 3
  0000:003F  db 02 03 06 07 09 08 0D 0C 0A 0B 0E 0F 03 00 00 00 ; config tail
  0000:004F  db 00 80 02 5E 01 40 23 40 00 10 04 01 00 01 00 03 ; 640x350, char metrics
  0000:005F  db 01                                              ; capabilities

; ------------------------------------------------------------------------
; SEGMENT seg_0006  (22048 bytes, file 0x0260-0x5880)
; Main driver code + font data + drawing operations
; ------------------------------------------------------------------------
seg_0006:

  ; --- Entry/reset clip bounds ---
  0006:0000  db 03 00 CB EA 94 57 00 00 90 50 B8 FF 7F 26 A3 51 ; [RELOC->seg_0000]
  0006:0010  db 01 26 A3 53 01 40 26 A3 55 01 26 A3 57 01 58 C3 ; resetClipBounds
  ; [~22KB of driver code and font data]

; ------------------------------------------------------------------------
; SEGMENT seg_0568  (288 bytes, file 0x5880-0x59A0)
; Function dispatch table -- word offsets into seg_0006
; ------------------------------------------------------------------------
seg_0568:

  ; ~144 function entries (288 bytes / 2 bytes each)

; ------------------------------------------------------------------------
; SEGMENT seg_057A  (976 bytes, file 0x59A0-0x5D70)
; TSR startup, dispatch, INT 08h/09h hooks, mode switching
; ------------------------------------------------------------------------
seg_057A:

  ; --- Driver name and config header ---
  057A:0000  db 44 4D 56 53 45 47 41                            ; "DMVSEGA"
  057A:0007  db 00                                                ; NUL
  057A:0008  db 25 00 7A 05 00 00 00 00 00 00 00 00 00 00 00 00 ; [RELOC->seg_057A]
  057A:0018  db 00 00 00 00 00 00 00 00 00 00 03 12 21 C7 06 00 ; config
  057A:0028  db 00 C2 05 BB 55 00 B8 59 00 CB                   ; [RELOC->seg_05C2]

  ; --- entry_point: TSR installation ---
entry_point:                                                 ; 057A:0032
  057A:0032  0e                push     cs
  057A:0033  07                pop      es
  057A:0034  bb0000            mov      bx, 0
  057A:0037  268c5f20          mov      word ptr es:[bx + 0x20], ds
  057A:003B  b90000            mov      cx, 0                ; RELOC->seg_0000
  057A:003E  b8f001            mov      ax, 0x1f0
  057A:0041  cde0              int      0xe0                 ; INT E0h/01h: register
  057A:0043  26a3d303          mov      word ptr es:[0x3d3], ax ; save display ID
  057A:0047  8b160200          mov      dx, word ptr [2]
  057A:004B  8cd8              mov      ax, ds
  057A:004D  2bd0              sub      dx, ax
  057A:004F  b80031            mov      ax, 0x3100
  057A:0052  cd21              int      0x21                 ; INT 21h/31h: TSR

  ; --- dmvsega_dispatchFast ---
  057A:0054  90                nop
  057A:0055  d1e0              shl      ax, 1
  057A:0057  732e              jae      0x87
  057A:0059  2ea35d04          mov      word ptr cs:[0x45d], ax
  057A:005D  8b460f            mov      ax, word ptr [bp + 0xf]
  057A:0060  8b6e09            mov      bp, word ptr [bp + 9]
  057A:0063  53                push     bx
  057A:0064  06                push     es
  057A:0065  bb7a05            mov      bx, 0x57a            ; RELOC->seg_057A
  057A:0068  8ec3              mov      es, bx
  057A:006A  268e066104        mov      es, word ptr es:[0x461]
  057A:006F  bb0000            mov      bx, 0
  057A:0072  2e031e5d04        add      bx, word ptr cs:[0x45d]
  057A:0077  268b1f            mov      bx, word ptr es:[bx]
  057A:007A  2e891e5f04        mov      word ptr cs:[0x45f], bx
  057A:007F  07                pop      es
  057A:0080  5b                pop      bx
  057A:0081  2eff165f04        call     word ptr cs:[0x45f]
  057A:0086  cb                retf

  ; --- dmvsega_dispatchFull ---
loc_057A_0087:                                               ; 057A:0087
  057A:0087  ff760f            push     word ptr [bp + 0xf]
  057A:008A  53                push     bx
  057A:008B  06                push     es
  057A:008C  ff7609            push     word ptr [bp + 9]
  057A:008F  83ec0e            sub      sp, 0xe
  057A:0092  8bec              mov      bp, sp
  057A:0094  89460a            mov      word ptr [bp + 0xa], ax
  057A:0097  2ea1d303          mov      ax, word ptr cs:[0x3d3]
  057A:009B  3cff              cmp      al, 0xff
  057A:009D  7409              je       0xa8
  057A:009F  52                push     dx
  057A:00A0  8ad0              mov      dl, al
  057A:00A2  b8044d            mov      ax, 0x4d04           ; acquire mutex
  057A:00A5  cde0              int      0xe0
  057A:00A7  5a                pop      dx

loc_057A_00A8:                                               ; 057A:00A8
  057A:00A8  89460c            mov      word ptr [bp + 0xc], ax
  057A:00AB  bb7a05            mov      bx, 0x57a            ; RELOC->seg_057A
  057A:00AE  8ec3              mov      es, bx
  057A:00B0  c746020000        mov      word ptr [bp + 2], 0 ; RELOC->seg_0000
  057A:00B5  2e8e066104        mov      es, word ptr cs:[0x461]
  057A:00BA  bb0000            mov      bx, 0
  057A:00BD  035e0a            add      bx, word ptr [bp + 0xa]
  057A:00C0  268b1f            mov      bx, word ptr es:[bx]
  057A:00C3  895e00            mov      word ptr [bp], bx
  057A:00C6  8c4e08            mov      word ptr [bp + 8], cs
  057A:00C9  b8e200            mov      ax, 0xe2
  057A:00CC  894606            mov      word ptr [bp + 6], ax
  057A:00CF  bb6200            mov      bx, 0x62
  057A:00D2  895e04            mov      word ptr [bp + 4], bx
  057A:00D5  8b4614            mov      ax, word ptr [bp + 0x14]
  057A:00D8  8e4610            mov      es, word ptr [bp + 0x10]
  057A:00DB  8b5e12            mov      bx, word ptr [bp + 0x12]
  057A:00DE  8b6e0e            mov      bp, word ptr [bp + 0xe]
  057A:00E1  cb                retf

  ; --- dmvsega_dispatchEpilogue ---
  057A:00E2  db 50
  057A:00E3  55                push     bp
  057A:00E4  8bec              mov      bp, sp
  057A:00E6  8b4606            mov      ax, word ptr [bp + 6]
  057A:00E9  3cff              cmp      al, 0xff
  057A:00EB  7409              je       0xf6
  057A:00ED  52                push     dx
  057A:00EE  8ad0              mov      dl, al
  057A:00F0  b8054d            mov      ax, 0x4d05           ; release mutex
  057A:00F3  cde0              int      0xe0
  057A:00F5  5a                pop      dx

loc_057A_00F6:                                               ; 057A:00F6
  057A:00F6  5d                pop      bp
  057A:00F7  58                pop      ax
  057A:00F8  83c40c            add      sp, 0xc
  057A:00FB  cb                retf

  ; --- dmvsega_initDriver ---
  057A:00FC  db 53 2E 8C 1E 59 04 2E 8C 06 5B 04 E8 D3 00 9A 80
  057A:010C  db 26 00 00 E8 E1 00 E8 6C 00 5B B8 03 00 C3       ; [RELOC->seg_0000]

  ; --- dmvsega_shutdownDriver / setVideoMode ---
  057A:011C  db F6 06 53 00 01 75 0C 3C 00 74 1C E8 1A 00 E8 82 00 EB
  057A:012C  db 14 3C 00 75 0D 53 E8 A8 00 9A D4 26 00 00 E8 B6 ; [RELOC->seg_0000]
  057A:013C  db 00 5B E8 01 00 C3

  ; --- dmvsega_lookupCursorRate ---
  057A:0142  db 50 56 80 26 53 00 FE 0A C0 74
  057A:014C  db 05 80 0E 53 00 01 B4 03 F6 E4 BE D5 03 03 F0 2E
  057A:015C  db 8B 04 FA A3 57 00 A3 54 00 2E 8A 44 02 A2 59 00
  057A:016C  db A2 56 00 FB 5E 58 C3

  ; --- dmvsega_lookupByIndex ---
  057A:0173  db 53 32 FF 8A D8 81 C3 ED 03
  057A:017C  db 2E 8A 07 5B C3

  ; --- dmvsega_hookTimerInt ---
  057A:0181  db 53 52 1E 06 F6 06 53 00 01 74 03 E8
  057A:018C  db 1E 00 B4 35 B0 08 CD 21 89 1E 0A 00 8C 06 0C 00
  057A:019C  db B4 25 B0 08 BA 05 02 0E 1F CD 21 07 1F 5A 5B C3

  ; --- dmvsega_hookKeyboardInt ---
  057A:01AC  db C3 50 53 52 1E 06 F6 06 53 00 02 75 1E 80 0E 53
  057A:01BC  db 00 02 B4 35 B0 09 CD 21 89 1E 5A 00 8C 06 5C 00
  057A:01CC  db B4 25 B0 09 BA 38 03 0E 1F CD 21 07 1F 5A 5B 58 C3

  ; --- dmvsega_acquireMutex / releaseMutex ---
  057A:01DC  db C3 50 2E A1 D3 03 3C FF 74 09 52 8A D0 B8 04 4D
  057A:01EC  db CD E0 5A 8A D8 58 C3 50 8A C3 3C FF 74 09 52 8A
  057A:01FC  db D0 B8 05 4D CD E0 5A 58 C3

  ; --- dmvsega_timerISR: INT 08h handler ---
  057A:0205  db 50 53 56 1E 06 FB B8
  057A:020C  db 00 00 8E D8 A1 86 03 8E D8 2E 8E 06 59 04 9C FA
  057A:021C  db 26 FF 1E 0A 00 26 80 3E 0F 00 00 74 03 E9 06 01
  ; [cursor blink logic with relocations into seg_0000]
  057A:032C  db A2 89 00 E8 C1 FE 07 1F 5E 5B 58 CF

  ; --- dmvsega_keyboardISR ---
  057A:0338  db 50 53 51 06 1E
  057A:033C  db 2E 8E 06 59 04 B8 40 00 8E D8 8B 1E 1A 00 8B
  057A:034C  db 0E 1C 00 9C 26 FF 1E 5A 00 39 1E 1A 00 75 06 39
  057A:035C  db 0E 1C 00 74 0F E8 12 00 0B C0 74 08 89 1E 1A 00
  057A:036C  db 89 0E 1C 00 1F 07 59 5B 58 CF

  ; --- dmvsega_checkCursorState ---
  057A:0376  db 53 1E 33 C0 2E 8E
  057A:037C  db 1E 59 04 F6 06 53 00 01 74 24 83 3E 54 00 00 75
  057A:038C  db 0D 80 3E 56 00 00 75 06 E8 29 00 B8 FF FF 8B 1E
  057A:039C  db 57 00 89 1E 54 00 8A 1E 59 00 88 1E 56 00 1F 5B C3

  ; --- dmvsega_disablePalette: blank screen via EGA attr controller ---
  ; Reads input status to reset flip-flop, then writes 0x00 to 3C0h
  ; to disable palette output (blanks the screen).
  057A:03AC  db 50 52 BA BA 03 EC BA DA 03 EC BA C0 03 B0 00     ; in 3BAh; in 3DAh; out 3C0h,00h
  057A:03BC  db EE 5A 58 C3                                     ; ret

  ; --- dmvsega_enablePalette: unblank screen via EGA attr controller ---
  ; Same flip-flop reset, then writes 0x20 to 3C0h to re-enable palette.
  057A:03C0  db 50 52 BA BA 03 EC BA DA 03 EC BA C0              ; in 3BAh; in 3DAh
  057A:03CC  db 03 B0 20 EE                                     ; out 3C0h,20h

; ------------------------------------------------------------------------
; SEGMENT seg_05B7  (160 bytes, file 0x5D70-0x5E10)
; Key mapping table + driver descriptor
; ------------------------------------------------------------------------
seg_05B7:

  05B7:0000  db 5A 58 C3 00 00 00 00 00 55 15 00 AA 2A 00 55 55 ; blink rates
  05B7:0010  db 00 00 80 00 00 00 01 00 00 02 00 00 04 19 FF FF ; fill patterns
  ; [key mapping table continues]
  05B7:0080  db 26 E4 25 E3 24 23 FE 00 A0 00 00 00 00 00 00 00 ; descriptor: seg A000h
  05B7:0090  db 00 68 05 00 00 00 00 00 00 00 00 00 00 00 00 00 ; [RELOC->seg_0568]

; ------------------------------------------------------------------------
; SEGMENT seg_05C1  (2 bytes, file 0x5E10-0x5E12)
; Stack segment
; ------------------------------------------------------------------------
seg_05C1:

  05C1:0000  db 00 00                                           ; initial stack
