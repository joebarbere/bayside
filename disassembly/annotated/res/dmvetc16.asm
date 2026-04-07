; ========================================================================
; DMVETC16.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Tandy Graphics Adapter (TGA) 16-Color Enhanced Video Driver
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVETC16.RES is the "enhanced" video resource driver for the Tandy
; Graphics Adapter (TGA) in 16-color mode (320x200x16 or 640x200x16).
; It is loaded by DESK.EXE when the user selects the Tandy 16-color
; enhanced video mode via DMVID.EXE.
;
; Architecture: Like all enhanced video drivers (DMVE*), this is a thin
; dispatch shim. It does NOT contain the actual drawing routines. Instead:
;   1. Registers a function dispatch table (seg_0000) with DESK.EXE
;      via INT E0h AH=01h during initialization.
;   2. DESK.EXE calls back into the driver through the dispatch mechanism
;      for video operations (draw pixel, draw line, fill rect, etc.).
;   3. The seg_0000 code implements Tandy 16-color rendering using
;      direct TGA hardware register access.
;
; This contrasts with the "standard" driver (DMVSTC16.RES) which contains
; its own complete set of drawing routines (~23KB).
;
; Compared to DMVET.RES (4-color), this driver adds:
;   - 16-color pixel masking tables at 0x10E8 (16 entries of 8 bytes)
;   - Additional color expansion logic in renderCharacter
;   - Slightly larger seg_0000 (4544 vs 4384 bytes)
;
; Key hardware accessed:
;   Port 0x03C4 - TGA/EGA Sequencer Address Register
;   Port 0x03C5 - TGA/EGA Sequencer Data Register
;   Port 0x03CE - TGA/EGA Graphics Controller Address Register
;   Port 0x03CF - TGA/EGA Graphics Controller Data Register
;   Segment A000h implied via [0x0386] IVT entry (Tandy video segment)
;
; DM89 Module Information:
;   Module name at seg_011D:0000 = "DMVETC16"
;   Font companion name at seg_011D:002A = "DMFONT"
;   Standard companion name at seg_011D:0035 = "DMVSTC16" (INT ABh hook)
;   Version: "33.10" (matches DMVET family)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5,474 bytes
; Load image: 4,962 bytes (after header)
; DM89 entry point: 011D:00A2
; SS:SP = 0136:0002
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  4,544 bytes  CODE/DATA  Video rendering routines + dispatch table
;   seg_011C     16 bytes  CODE       Epilogue stub (pop regs; ret)
;   seg_011D    400 bytes  CODE       DM89 header, dispatch thunk, entry point
;   seg_0136      2 bytes  STACK      Stack segment
;
; DM89 flags: Enhanced video driver (paired with standard driver)
;
; ========================================================================
; VIDEO DISPATCH TABLE
; ========================================================================
;
; The dispatch table at seg_0000:0020 contains word offsets into seg_0000
; for each video function. The entry at [0x0000] selects the video segment
; (0x00A0 = segment A000h for TGA 16-color planar mode).
;
;   Index  Offset  Function
;   -----  ------  --------
;   0x00   0x0007  dmvetc16_initVideoSegment     - Initialize video mode segment
;   0x01   0x07FC  dmvetc16_apiThunk_11h         - Far-call thunk: function 0x11
;   0x02   0x07B9  dmvetc16_apiThunk_10h         - Far-call thunk: function 0x10
;   0x03   0x0855  dmvetc16_apiThunk_6Ah         - Unused slot (returns)
;   0x04   0x064F  dmvetc16_apiThunk_unused2     - Unused slot (returns)
;   0x05   0x0264  dmvetc16_apiThunk_unused3     - Unused slot (returns)
;   0x06   0x0279  dmvetc16_apiThunk_unused4     - Unused slot (returns)
;   0x07   0x0293  dmvetc16_initDriverContext    - Init driver context from params
;   0x08   0x0532  dmvetc16_apiThunk_12h         - Far-call thunk: function 0x12
;   0x09   0x0E30  dmvetc16_adjustResolution     - Adjust display resolution
;   0x0A   0x0EE3  dmvetc16_setupVideoMode       - Set up video mode + INT ABh hook
;   0x0B   0x0F60  dmvetc16_teardownVideoMode    - Tear down video mode, unhook
;   0x0C   0x07A1  dmvetc16_setColors            - Set color palette entries
;
; ========================================================================
; I/O PORT ACCESS MAP
; ========================================================================
;
; Port 0x03C4: TGA/EGA Sequencer Address Register
;   - Written with register index (0x02 = Map Mask)
; Port 0x03C5: TGA/EGA Sequencer Data Register
;   - Written with data for selected sequencer register (0x0F = all planes)
; Port 0x03CE: TGA/EGA Graphics Controller Address Register
;   - Register 0x00: Set/Reset value
;   - Register 0x01: Enable Set/Reset
;   - Register 0x03: Data Rotate / Function Select
;   - Register 0x04: Read Map Select
;   - Register 0x08: Bit Mask
; Port 0x03CF: TGA/EGA Graphics Controller Data Register
;   - Data for the register selected via 0x03CE
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- seg_0000: Video Rendering Functions ---
;
; Address    Name                              Size  Description
; -------    ----                              ----  -----------
; 0000:0000  (data: video segment word)          2   Video segment selector (0x00A0)
; 0000:0002  (data: unused)                      5   Padding / reserved
; 0000:0007  dmvetc16_dispatchViaTable          22   Dispatch: load offset from table, far-call
; 0000:0013  dmvetc16_hostFarCall               13   Far-call into host via es:[0x25]
; 0000:0020  (data: dispatch table)             25   13-word function offset table
; 0000:0039  dmvetc16_drawBitmapRow           154   Draw a bitmap row with clipping
; 0000:00D6  (epilogue)                          6   pop di,si,dx,cx,bx,ax
; 0000:00DC  dmvetc16_drawBitmapAligned        137   Draw aligned bitmap (byte-boundary)
; 0000:0165  dmvetc16_clipToWindow              45   Clip coordinates to window bounds
; 0000:0199  dmvetc16_clipRect                 102   Full rectangle clip against window
; 0000:01FF  dmvetc16_transformCoords           54   Transform coords to screen space
; 0000:0234  dmvetc16_getScreenMetrics          26   Get screen offset calculations
; 0000:024F  dmvetc16_apiThunk_3Fh_6Ah         28   Far-call thunk: host function 0x6A (via 0x42)
; 0000:026B  dmvetc16_apiThunk_3Fh_69h         28   Far-call thunk: host function 0x69
; 0000:02AF  dmvetc16_apiThunk_3Fh_64h         28   Far-call thunk: host function 0x64
; 0000:02CB  dmvetc16_apiThunk_3Fh_63h         28   Far-call thunk: host function 0x63
; 0000:02E7  dmvetc16_apiThunk_3Fh_59h         28   Far-call thunk: host function 0x59
; 0000:0303  dmvetc16_apiThunk_3Fh_5Bh         28   Far-call thunk: host function 0x5B
; 0000:031F  dmvetc16_apiThunk_3Fh_12h         28   Far-call thunk: host function 0x12
; 0000:033B  dmvetc16_apiThunk_3Fh_13h         28   Far-call thunk: host function 0x13
; 0000:0357  dmvetc16_apiThunk_3Fh_65h         28   Far-call thunk: host function 0x65
; 0000:0373  dmvetc16_apiThunk_3Fh_66h         28   Far-call thunk: host function 0x66
; 0000:038F  dmvetc16_apiThunk_3Fh_6Bh         28   Far-call thunk: host function 0x6B
; 0000:03AB  dmvetc16_apiThunk_3Fh_27h         28   Far-call thunk: host function 0x27
; 0000:03C7  dmvetc16_apiThunk_3Fh_4Ch         28   Far-call thunk: host function 0x4C
; 0000:03E3  dmvetc16_apiThunk_3Fh_53h         28   Far-call thunk: host function 0x53
; 0000:03FF  dmvetc16_apiThunk_3Fh_38h         28   Far-call thunk: host function 0x38
; 0000:041B  dmvetc16_apiThunk_3Fh_3Eh         28   Far-call thunk: host function 0x3E
; 0000:0437  dmvetc16_apiThunk_3Fh_6Dh         28   Far-call thunk: host function 0x6D
; 0000:0453  dmvetc16_apiThunk_3Fh_51h         28   Far-call thunk: host function 0x51
; 0000:046F  dmvetc16_apiThunk_3Fh_4Eh         28   Far-call thunk: host function 0x4E
; 0000:047C  (data: trig/scaling table)        182   Trigonometric / Bresenham lookup table
; 0000:0532  dmvetc16_initDriverContext         74   Parse init params, set up driver context
; 0000:057B  dmvetc16_renderCharacter          593   Render a character glyph to screen
; 0000:07A1  dmvetc16_setColorPair              30   Set foreground/background color pair
; 0000:07BF  dmvetc16_setColorDirect            18   Set color directly from parameter
; 0000:07D1  dmvetc16_lookupColor               31   Look up color in palette table
; 0000:07F0  dmvetc16_applyColorAndDraw         30   Apply color setting and call draw
; 0000:080E  dmvetc16_dispatchRenderOp          38   Dispatch render op (char/bitmap/rect)
; 0000:0834  dmvetc16_drawMultiItem             30   Draw multiple items from list
; 0000:0852  dmvetc16_setupDrawContext         123   Set up draw context from DM params
; 0000:08CC  dmvetc16_computeCharMetrics        89   Compute character cell metrics
; 0000:0985  dmvetc16_scaledMultiply            30   Scaled 32-bit multiply for positioning
; 0000:099F  dmvetc16_computeScrollOffset      155   Compute scroll offset with bounds
; 0000:0A27  dmvetc16_drawFontGlyph            118   Draw a single font glyph (character)
; 0000:0A9E  dmvetc16_fullRedraw               666   Full screen redraw / repaint
; 0000:0D3C  dmvetc16_unloadResources           46   Unload resources, free memory
; 0000:0D6A  dmvetc16_computeWindowBounds      200   Compute window bounds for redraw
; 0000:0E30  dmvetc16_scaleCoordinates          60   Scale pixel coords to logical coords
; 0000:0E6D  dmvetc16_adjustResolution         118   Adjust resolution (query host metrics)
; 0000:0EE3  dmvetc16_setupVideoMode           125   Set up video mode, program TGA regs
; 0000:0F60  dmvetc16_teardownVideoMode         48   Tear down video mode, restore INT ABh
; 0000:0F90  dmvetc16_expandPixelColor          19   Expand 4-bit color to pixel fill pattern
; 0000:0FA3  dmvetc16_calcScanlineOffset        32   Calc video memory offset from Y coord
; 0000:0FC8  dmvetc16_fastBlit                  80   Fast blit: copy bitmap with masking
; 0000:1061  (unused / alignment)                1   NOP padding
; 0000:1083  dmvetc16_mul32                     64   32x16 multiply yielding 32-bit result
; 0000:10C3  dmvetc16_mulAccum64                99   64-bit multiply-accumulate
; 0000:10E8  (data: pixel mask table)          128   16-color pixel mask lookup (16x8 bytes)
; 0000:1108  dmvetc16_bresenhamSetup            80   Set up Bresenham line params
; 0000:1158  dmvetc16_mulAccum64_ext            99   Extended multiply-accumulate
;
; --- seg_011C: Epilogue Stub ---
;
; 011C:0000  (epilogue stub)                   16   pop bp; ret + padding
;
; --- seg_011D: DM89 Header + Entry Point ---
;
; 011D:0000  dmvetc16_dm89Header               34   DM89 module header: "DMVETC16\0"
; 011D:0022  (data: driver flags)               1   Enhanced mode flag byte
; 011D:002A  (data: "DMFONT" font name)        13   Font module name for INT ABh pairing
; 011D:0035  (data: INT ABh vector)             7   Saved INT ABh vector (for DMVSTC16 hookup)
; 011D:003E  (data: task lock byte)             1   Current task lock status
; 011D:003F  (data: saved task lock)            1   Saved task lock value
; 011D:0041  (data: mode flag byte)             1   Mode flag: 'Y'=640-wide, 'X'=320-wide
; 011D:0044  dmvetc16_apiRouteThunk            78   Far-call dispatch thunk
; 011D:0092  (thunk epilogue)                  13   Thunk return stub
; 011D:00A2  entry_point                       63   Module entry point (DM89 init)
; 011D:00E3  dmvetc16_apiDispatch             107   API dispatch: save regs, route call
; 011D:014A  (data: cleanup thunk)             16   Cleanup far-call thunk
; 011D:015B  dmvetc16_hookINTAB                51   Hook INT ABh for DMVSTC16 cooperation
;
; ========================================================================
; DETAILED DISASSEMBLY
; ========================================================================

; ========================================================================
; SEGMENT seg_0000  (4544 bytes) -- Video rendering code + data tables
; ========================================================================
seg_0000:

; --- Video segment selector ---
; The first word selects the video memory segment:
; 0x00A0 -> segment A000h (for TGA 16-color planar mode)
  0000:0000  db 00 A0                                             ; g_videoSegment = 0xA000

; --- Internal dispatch mechanism ---
; Bytes 0002-0006: shift AX left 1 (index*2), load SI
  0000:0002  db 00 00 D1 E0 8B F0                                 ; shl ax,1; mov si,ax

; dmvetc16_dispatchViaTable: Load function offset from table, call via far return
  0000:0007  db 53 BB 1E 00 2E 8B 18 07                           ; push bx; mov bx,0x1E; cs:mov bx,[bx]; pop es
  0000:000F  db FF D3 CB                                          ; call bx; retf

; dmvetc16_hostFarCall: Call into DESK.EXE host via es:[0x25]
  0000:0013  db 55 83 C5 04 26 FF 1E 25 00 5D C3                  ; push bp; add bp,4; lcall es:[0x25]; pop bp; ret

; --- Dispatch offset table ---
; 13 entries (word offsets into seg_0000) for video functions.
; See VIDEO DISPATCH TABLE in header for index mapping.
;                idx0  idx1  idx2  idx3  idx4  idx5  idx6  idx7
;                idx8  idx9  idxA  idxB  idxC
  0000:0020  db B9 07                                             ; [0] -> 0x07B9
  0000:0022  db 55 08                                             ; [1] -> 0x0855
  0000:0024  db 4F 02                                             ; [2] -> 0x024F
  0000:0026  db 64 02                                             ; [3] -> 0x0264
  0000:0028  db 79 02                                             ; [4] -> 0x0279
  0000:002A  db 93 02                                             ; [5] -> 0x0293
  0000:002C  db 32 05                                             ; [6] -> 0x0532 (initDriverContext)
  0000:002E  db 30 0E                                             ; [7] -> 0x0E30 (scaleCoordinates)
  0000:0030  db 6D 0E                                             ; [8] -> 0x0E6D (adjustResolution)
  0000:0032  db E3 0E                                             ; [9] -> 0x0EE3 (setupVideoMode)
  0000:0034  db 60 0F                                             ; [A] -> 0x0F60 (teardownVideoMode)
  0000:0036  db A1 07                                             ; [B] -> 0x07A1 (setColors)
  0000:0038  db 90                                                ; padding (NOP)

; ========================================================================
; dmvetc16_drawBitmapRow (0000:0039)
; Draw a bitmap row with clipping to the current window.
; Saves all registers, performs clipping, then blits pixels.
; This is the core pixel-row rendering function.
; ========================================================================
  0000:0039  db 50 53 51 52 56 57                               ; push ax,bx,cx,dx,si,di (PSQRVW)
  0000:003F  db 89 46 00 89 5E 02 89 4E 04 89 56 06 E8 45 01 73 ; store params; call clipRect; jnc ok
  0000:004F  db 03 E9 83 00 89 46 08 89 56 0E 80 7E 1C FF 74 11 ; clipped out -> skip
  0000:005F  db C6 46 1C AA 53 2B 5E 02 F6 C3 01 5B 74 03 D0 4E ; set mask=0xAA; check alignment
  0000:006F  db 1C 8B D0 83 E2 07 03 D1 4A D1 FA D1 FA D1 FA 42 ; compute byte offset from pixel X
  0000:007F  db 89 56 16 03 C8 F6 D9 80 E1 07 B6 FF D2 E6 8A D6 ; build right-edge mask
  0000:008F  db 89 56 12 E8 0F 0F 89 7E 18 83 E7 FC 8B 56 00 2B ; call calcScanlineOffset
  0000:009F  db C2 89 46 1A B1 03 D3 F8 03 F0 8B 46 04 48 D3 F8 ; convert to byte count
  0000:00AF  db 40 89 46 14 2B 5E 02 74 04 F7 E3 03 F0 8B 5E 16 ; multiply by pitch; adjust SI
  0000:00BF  db 8A 6E 12 8A 4E 00 80 E1 07 83 66 1A 07 75 05 E8 ; extract bit offset within byte
  0000:00CF  db 0C 00 EB 03 E8 29 00                              ; call aligned or unaligned blit
  0000:00D6  db 5F 5E 5A 59 5B 58                               ; pop di,si,dx,cx,bx,ax (_^ZY[X)
  0000:00DC  db C3                                               ; ret

; ========================================================================
; dmvetc16_drawBitmapAligned (0000:00DC)
; Draw aligned bitmap (byte-boundary) for TGA 16-color mode.
; Uses TGA palette programming for each scanline.
; ========================================================================
  0000:00DC  db 53 52 8A 86 23 04 E8 AB 0E B7 00 FF 4E 0E 7C    ; push bx,dx; load color; call setTGAPalette
  0000:00EB  db 0F E8 D4 0E D0 4E 1C 03 76 14 81 C7 40 01 EB EC ; dec row count; advance scanline (+0x140 = 320 bytes)
  0000:00FB  db 5A 5B C3                                          ; pop dx,bx; ret

; ========================================================================
; dmvetc16_drawBitmapUnaligned (0000:00FD)
; Draw unaligned bitmap with bit shifting for TGA 16-color.
; ========================================================================
  0000:00FD  db 53 52 8A 86 23 04 E8 89 0E 51 8A 46 08          ; push; load color; call; push cx; load
  0000:010A  db 24 07 2A C1 3C 00 7D 02 04 08 8A C8 B4 FF D2 EC ; compute shift amount; create mask
  0000:011A  db 59 88 66 1A 8A 46 08 24 07 3A C8 7E 01 46 FF 4E ; pop cx; compare shift
  0000:012A  db 0E 7C 33 32 FF 0A C9 74 11 3A C8 7E 0D 8A 7C FF ; dec row; loop control
  0000:013A  db 22 7E 1A 50 E8 81 0E 58 EB 10 50 FF 34 8A 04 22 ; mask & write pixel
  0000:014A  db 46 1A 88 04 E8 71 0E 8F 04 58 D0 4E 1C 03 76 14 ; AND with bit mask; advance
  0000:015A  db 81 C7 40 01 EB C8 5A 5B C3                       ; next scanline (+0x140); loop; ret

; ========================================================================
; dmvetc16_clipToWindow (0000:0165)
; Clip coordinates to the current window bounds.
; ========================================================================
  0000:0165  db 50 53 51 52                                      ; push ax,bx,cx,dx (PSQR)
  0000:0169  db 8B C7 E8 6E 01 50 8B C3 E8 7D 01 8B D8 8B C1 E8 ; transform and clip
  0000:0179  db 61 01 8B C8 8B C2 E8 6F 01 8B D0 58 2B C8 41 2B ; compute clipped dimensions
  0000:0189  db D3 43 E8 05 00                                    ; call clipRect
  0000:018E  db 5A 59 5B 58                                      ; pop dx,cx,bx,ax (ZY[X)
  0000:0192  db C3                                               ; ret

; ========================================================================
; dmvetc16_clipRect (0000:0193)
; Full rectangle clip against window bounds.
; Returns: CF=1 if completely clipped, CF=0 if visible.
; ========================================================================
  0000:0193  db 0B C9 7E 5C 0B D2                               ; or cx,cx; jle clipped; or dx,dx
  0000:0199  db 7E 58 56 57                                      ; jle clipped; push si,di
  0000:019D  db 1E BE 00 00 8E DE 8E 1E 86 03 03 C8 70 4A 03 D3 ; ds=0; es=IVT[0x386]; add cx -> check overflow
  0000:01AD  db 70 4B 8B 36 68 00 8B 3E 6A 00 3B CE 7E 35 3B D7 ; load window bounds; compare
  0000:01BD  db 7E 31 3B C6 7D 02 8B C6 3B DF 7D 02 8B DF 03 36 ; clamp to window edges
  0000:01CD  db 6C 00 03 3E 6E 00 3B C6 7D 19 3B DF 7D 15 3B CE ; check against max bounds
  0000:01DD  db 7C 02 8B CE 3B D7 7C 02 8B D7 2B C8 2B D3 1F 5F ; compute final clipped rect
  0000:01ED  db 5E F8 C3 1F 5F 5E F9 C3 B9 FF 7F EB B1 BA FF 7F ; CF=0 visible or CF=1 clipped
  0000:01FD  db EB B0                                            ; jump back

; ========================================================================
; dmvetc16_transformCoords (0000:01FF)
; Transform coordinates to screen space.
; ========================================================================
  0000:01FF  db 50 53 51 52 56 57                               ; push all (PSQRVW)
  0000:0205  db 1E 06 E8 2B 00 8B 75 0C 8E 5D 0E 2E 8E 06 00 00 ; push ds,es; call getScreenMetrics
  0000:0215  db 3B 5E 36 7D                                      ; cmp bx,[bp+0x36]; jge
  0000:0219  db 03 89 5E 36 03 DA                                ; update min bound
  0000:021F  db 3B 5E 38 7E                                      ; cmp bx,[bp+0x38]; jle
  0000:0223  db 03 89 5E 38 2B DA E8 0D FE 07 1F                ; update max bound; call; pop es,ds
  0000:022E  db 5F 5E 5A 59 5B 58                               ; pop all (_^ZY[X)
  0000:0234  db C3                                               ; ret

; ========================================================================
; dmvetc16_getScreenMetrics (0000:0234)
; Get screen metrics from host parameters.
; ========================================================================
  0000:0234  db 8B 55 04 8B 4D 02 8B 45 0A 8B D8 03 5E 22 2B    ; load params from host structure
  0000:0243  db 9E 81 00 8B                                      ; subtract base offset
  0000:0247  db 46 20 2B 45                                      ; ax = [bp+0x20] - [di+?]
  0000:024B  db 08 C3                                            ; ret

; ========================================================================
; API Thunk functions (0000:024D - 0000:046F)
; Each thunk pushes a return address and function code,
; then does a far-call into DESK.EXE host via B8 42 00 (AX=0x42)
; for the enhanced 16-color mode thunks.
; NOTE: These use function code 0x42 (vs 0x3F in 4-color DMVET)
; ========================================================================
  0000:024D  db 90                                               ; NOP alignment
  0000:024E  db 06 0E 2E FF 36 60 02 50 06 B8 42 00 50          ; push es,cs; push [0x260]; push ax=0x42
  0000:025B  db B8 11 00 CB 62 02 07 C3                          ; ax=0x11; retf; pop es; ret (thunk for fn 0x11)
  0000:0263  db 06 0E 2E FF 36 75 02 50                          ; thunk for fn 0x10
  0000:026B  db 06 B8 42 00 50 B8 10 00 CB 77 02 07 C3          ; ax=0x10; retf
  0000:0278  db 56 8B 76 00 06 0E 2E FF 36 8E 02 50 06 B8 42 00 ; push si; load; thunk for fn 0x6A
  0000:0288  db 50 B8 6A 00 CB 90 02 07 5E C3                    ; ax=0x6A; retf; pop si; ret
  0000:0292  db 56 57 8B 7E 00 8B 76 02 06 0E 2E FF 36 AC 02 50 ; push si,di; thunk for fn 0x69
  0000:02A2  db 06 B8 42 00 50 B8 69 00 CB AE 02 07 5F 5E C3    ; ax=0x69; retf; pop di,si; ret
  0000:02B1  db 06 0E 2E FF 36 C3 02 50 06 B8 42 00 50 B8 64 00 ; thunk for fn 0x64
  0000:02C1  db CB C5 02 07 C3                                   ; retf; pop es; ret
  0000:02C6  db 06 0E 2E FF 36 D8 02 50 06 B8 42 00 50 B8 63 00 ; thunk for fn 0x63
  0000:02D6  db CB DA 02 07 C3                                   ; retf
  0000:02DB  db 06 0E 2E FF 36 ED 02 50 06 B8 42 00 50 B8 59 00 ; thunk for fn 0x59
  0000:02EB  db CB EF 02 07 C3                                   ; retf
  0000:02F0  db 06 0E 2E FF 36 02 03 50 06 B8 42 00 50 B8 5B 00 ; thunk for fn 0x5B
  0000:0300  db CB 04 03 07 C3                                   ; retf
  0000:0305  db 06 0E 2E FF 36 17 03 50 06 B8 42 00 50 B8 12 00 ; thunk for fn 0x12
  0000:0315  db CB 19 03 07 C3                                   ; retf
  0000:031A  db 06 0E 2E FF 36 2C 03 50 06 B8 42 00 50 B8 13 00 ; thunk for fn 0x13
  0000:032A  db CB 2E 03 07 C3                                   ; retf
  0000:032F  db 06 0E 2E FF 36 41 03 50 06 B8 42 00 50 B8 65 00 ; thunk for fn 0x65
  0000:033F  db CB 43 03 07 C3                                   ; retf
  0000:0344  db 06 0E 2E FF 36 56 03 50 06 B8 42 00 50 B8 66 00 ; thunk for fn 0x66
  0000:0354  db CB 58 03 07 C3                                   ; retf
  0000:0359  db 06 0E 2E FF 36 6B 03 50 06 B8 42 00 50 B8 6B 00 ; thunk for fn 0x6B
  0000:0369  db CB 6D 03 07 C3                                   ; retf
  0000:036E  db 06 0E 2E FF 36 80 03 50 06 B8 42 00 50 B8 27 00 ; thunk for fn 0x27
  0000:037E  db CB 82 03 07 C3                                   ; retf
  0000:0383  db 06 0E 2E FF 36 95 03 50 06 B8 42 00 50 B8 4C 00 ; thunk for fn 0x4C
  0000:0393  db CB 97 03 07 C3                                   ; retf
  0000:0398  db 06 0E 2E FF 36 AA 03 50 06 B8 42 00 50 B8 53 00 ; thunk for fn 0x53
  0000:03A8  db CB AC 03 07 C3                                   ; retf
  0000:03AD  db 06 0E 2E FF 36 BF 03 50 06 B8 42 00 50 B8 38 00 ; thunk for fn 0x38
  0000:03BD  db CB C1 03 07 C3                                   ; retf
  0000:03C2  db 06 0E 2E FF 36 D4 03 50 06 B8 42 00 50 B8 3E 00 ; thunk for fn 0x3E
  0000:03D2  db CB D6 03 07 C3                                   ; retf
  0000:03D7  db 06 0E 2E FF 36 E9 03 50 06 B8 42 00 50 B8 6D 00 ; thunk for fn 0x6D
  0000:03E7  db CB EB 03 07 C3                                   ; retf
  0000:03EC  db 06 0E 2E FF 36 FE 03 50 06 B8 42 00 50 B8 51 00 ; thunk for fn 0x51
  0000:03FC  db CB 00 04 07 C3                                   ; retf
  0000:0401  db 06 0E 2E FF 36 13 04 50 06 B8 42 00 50 B8 4E 00 ; thunk for fn 0x4E
  0000:0411  db CB 15 04 07 C3                                   ; retf

; ========================================================================
; dmvetc16_angleLookup (0000:0416)
; Angle/trigonometric lookup utility for Bresenham line drawing.
; ========================================================================
  0000:0416  db 53 83 C3 5A E8 02 00 5B C3                       ; push bx; add bx,0x5A; call; pop bx; ret
  0000:041F  db 83 FB 5A 74 57 0B C0                              ; cmp bx,0x5A; je; or ax,ax

; ========================================================================
; dmvetc16_arctan (0000:0426)
; Compute arctangent for line angle calculation.
; ========================================================================
  0000:0426  db 74 53 53 51 52 57                               ; jz skip; push bx,cx,dx,di
  0000:042C  db 99 8B FA 33 C2 2B C2 93 99 B9 68 01 F7 F9 8B C2 ; cwd; compute angle via division
  0000:043C  db 0B C0 7D 03 05 68 01 3D B4 00 76 02 F7 D7 3D B4 ; normalize to 0-360 range
  0000:044C  db 00 76 03 2D B4 00 3D 5A 00 72 07 74 16 F7 D8 05 ; check quadrant; adjust
  0000:045C  db B4 00 93 D1 E3 2E 8B 9F 7D 04 F7 E3 D1 C0 83 D2 ; table lookup; multiply
  0000:046C  db 00 8B DA 8B C3 33 DF 2B DF 8B C3                 ; compute final result
  0000:0476  db 5F 5A 59 5B                                      ; pop di,dx,cx,bx (_ZY[)
  0000:047A  db C3                                               ; ret

; --- Trigonometric / Scaling lookup table (0000:047C) ---
; 91-entry sine/cosine table used by Bresenham and rotation code.
  0000:047C  db 00 00 77 04 EF 08 65 0D DB 11 4F 16 C2 1A 32    ; sin(0)..sin(14)
  0000:048B  db 1F A0 23 0C 28 74 2C D8 30 39 35 96 39 EE 3D 41 ; sin(15)..sin(28)
  0000:049B  db 42 90 46 D8 4A 1B 4F 58 53 8E 57 BE 5B E6 5F 06 ; sin(29)..sin(42)
  0000:04AB  db 64 1F                                            ; sin(43)..
  0000:04AD  db 68 30 6C 39 70 38 74 2F 78                       ; continued trig table
  0000:04B6  db 1C 7C 00 80 D9 83 A8 87 6D 8B 27 8F D5 92 79 96 ; scaling factors
  0000:04C6  db 10 9A 9B 9D 1B A1 8D A4 F3 A7 4C AB 97 AE D5 B1 ; continued
  0000:04D6  db 04 B5 26 B8 39 BB 3E BE 34 C1 1B C4 F3 C6 BB C9 ; continued
  0000:04E6  db 73 CC 1B CF B3 D1 3B D4 B3 D6 19 D9 6F DB B3 DD ; continued
  0000:04F6  db E7 DF 08 E2 19 E4 17 E6 03 E8 DE E9 A6 EB 5B ED ; continued
  0000:0506  db FF EE 8F F0 0D F2 78 F3 D0 F4 15 F6 46 F7 65 F8 ; continued
  0000:0516  db 70 F9 67 FA 4B FB 1C FC D9 FC 82 FD 17 FE 98 FE ; continued
  0000:0526  db 06 FF 60 FF A6 FF D8 FF F6 FF 90                 ; sin(90) = 0xFFFF; NOP pad

; ========================================================================
; dmvetc16_initDriverContext (0000:0532)
; Parse initialization parameters from the host and set up the driver's
; internal context structure.
; ========================================================================
  0000:0532  db 53 51 52 56 57                                  ; push bx,cx,dx,si,di (SQRVW)
  0000:0537  db 1E 33 C0 C5 76 00 8A 6C 01 8A 0C 80 F9 55 75 2E ; push ds; xor ax,ax; lds si; check param type
  0000:0547  db 80 FD 66 74 05 80 FD 46 75 1F E8 28 00 89 7C 02 ; 0x55='U' mode; 0x66='f'/0x46='F' font mode
  0000:0557  db 89 5C 06 89 4C 0A 89 54 0E 33 DB 89 5C 04 89 5C ; store parameters into context
  0000:0567  db 08 89 5C 0C 89 5C 10 EB 05 E8 3F FD 33 C0 1F    ; clear remaining fields; call; xor ax,ax; pop ds
  0000:0576  db 5F 5E 5A 59 5B                                  ; pop di,si,dx,cx,bx (_^ZY[)
  0000:057B  db C3                                               ; ret

; ========================================================================
; dmvetc16_renderCharacter (0000:057B)
; Render a character glyph to screen in 16-color mode.
; This is a large function (~593 bytes) that handles font rendering,
; including character metrics, clipping, and pixel output.
; ========================================================================
  0000:057B  db 56 55 83 EC 46 8B EC 8B 44 36 89 46 3C 8B 44    ; push si,bp; allocate locals
  0000:058A  db 38 8B 7C 3A 8B 5C 3C 8B 4C 5C 8B 54 5E 80 7C 01 ; load character params
  0000:059A  db 66 74 1E 06 C4 7C 14 26 8B 45 22 89 46 3C 26 8B ; check font type; load glyph data
  0000:05AA  db 45 24 26 8B 5D 28 26 8B 7D 26 8B 4C 20 8B 54 22 ; load dimensions and position
  0000:05BA  db 07 89 46 36 89 5E 3A 89 7E 38 89 4E 32 89 56 34 ; store into local frame
  0000:05CA  db 89 4E 2A 89                                      ; continued
  0000:05CE  db 56 2C 41 42                                      ; continued -- "V,AB" is coincidence of opcodes
  0000:05D2  db 89 4E 2E 89 56 30 80 7C 01 66 74 11 8B 7C 14 8B ; store more params; check font type
  0000:05E2  db 54 16 8B 5C 26 8B 44 28 8B 4C 24 EB 0D 8D 7C 14 ; load glyph address
  0000:05F2  db 1E 5A 8D 5C 64 1E 58 8B 4C 60 0B C9 75 06 B8 FF ; check if valid; return -1 if not
  0000:0602  db FF E9 CB 00 89 7E 12 89 56 14 89 7E 00 89 56 02 ; store glyph pointers
  0000:0612  db 89 5E 0C 89 46 0E 51 C7 46 10 01 00 C7 46 40 00 ; init drawing state
  0000:0622  db 00 C7 46 44 00 00 C7 46 42 00 00 C7 46 3E FF FF ; clear accumulators
  0000:0632  db 8D 7E 1A 89 7E 16 16 8F 46 18 8D 7E 08 89 7E 04 ; set up stack frame pointers
  0000:0642  db 16 8F 46 06                                      ; store segment

; --- Character rendering loop ---
  0000:0646  db 49 7C 50 56                                      ; dec cx; jl done; push si
  0000:064A  db 1E C5 76 0C AC FF 46 0C 1F 5E 32 E4 89 46 1E 83 ; lds si; lodsb; inc ptr; pop ds,si
  0000:065A  db C5 12 B8 09 00 26 FF 1E 25 00 83 ED 12 3D FF FF ; add bp,0x12; call host fn 0x09; sub bp
  0000:066A  db 74 38 83 7E 3E FF 75 06 8B 46 24 89 46 3E 8B 46 ; check result; update bounds
  0000:067A  db 20 01 46 44 8B                                   ; add to accumulator
  0000:067F  db 46 26 2B 46 28 3B 46 40 7E                       ; compute advance width
  0000:0688  db 03 89 46 40 8B                                   ; update max width
  0000:068D  db 46 28 3B 46 42 7E                                ; compare minimum
  0000:0693  db B2 89 46 42 EB AD                                 ; update min; loop back

; --- Post-rendering cleanup ---
  0000:0699  db 8F 46 10 E8 80 00 73 09 FF 76                    ; pop; call computeWindowBounds; jnc
  0000:06A3  db 10 8F 46 10 E8 39 00 8B 46 40 8B 5E 42 03 C3 8B ; call unloadResources
  0000:06B3  db 4E 44 80 7C 01 66 74 0B 89 44 18 89 5C 1A 89 4C ; store character metrics back
  0000:06C3  db 1C EB 09 89 44 54 89 5C 56 89 4C 58 33 C0 8B 7E ; return 0 on success
  0000:06D3  db 2A 8B 5E 2C 8B 4E 2E 8B 56 30 83 C4 46 5D 5E C3 ; restore regs; deallocate; ret

; --- Supporting subroutines for renderCharacter ---
  0000:06E3  db 8B 46 36 8B 5E 38 E8 29 07 F7 66 10 89 46 44 8B ; compute character advance
  0000:06F3  db F8 8B 4E 32 89 4E 2A 03 CF 89 4E 2E 53 8B C3 D1 ; update position
  0000:0703  db E8 D1 E8 D1 E8 89 46 40 8B 4E 34 03 C8 89 4E 30 ; divide by 8; compute column
  0000:0713  db 2B D8 89                                          ; subtract
  0000:0716  db 5E 42 5B 2B                                      ; store; pop bx
  0000:071A  db CB 89 4E 2C C3 8B                                ; retf; store; ret
  0000:0720  db 46 22 2B 46 24 2B 46 20 7E                       ; compute scroll delta
  0000:0729  db 03 01 46 44 8B 46 44 8B 5E 3A 8B 4E 32 E8 DD FC ; update; call clipRect
  0000:0739  db 03 C1 3B C1 7D 01 91 89 4E 2A 89 46 2E 8B 46 44 ; clamp positions
  0000:0749  db 8B 56 34 E8 D0 FC 03 C2 3B C2 7D 01 92 89 56 2C ; more clamping
  0000:0759  db 89 46 30 8B 46 40 0B C0 74 0F E8 B9 FC 29 46 2A ; check if zero; adjust
  0000:0769  db 8B 46 40 E8 A7 FC 01 46 30 8B 46 42 E8 A7 FC 01 ; compute final offsets
  0000:0779  db 46 2E 0B C0 79 09 8B 46 2E 87 46 2A 89 46 2E 8B ; handle negative case
  0000:0789  db 46 42 E8 88 FC 29 46 2C 0B C0 79 09 8B 46 30 87 ; more negative handling
  0000:0799  db 46 2C 89 46 30 F8 C3                              ; store; clc; ret

; ========================================================================
; dmvetc16_setColorPair (0000:079F)
; Set foreground/background color pair from host parameters.
; ========================================================================
  0000:079F  db 50 57 1E C5 7E 00 8B 46 04                       ; push ax,di; lds di,[bp]
  0000:07A8  db E8 29 00 3D FF FF 74 03 E8 14 00 1F 5F 58 C3    ; call lookupColor; apply; pop

; ========================================================================
; dmvetc16_setColorDirect (0000:07BF)
; Set color directly from parameter.
; ========================================================================
  0000:07BF  db 50 57 1E C5 7E 00 8B 46 04 E8 04 00 1F 5F 58 C3 ; push; lds; call; pop; ret

; ========================================================================
; dmvetc16_lookupColor (0000:07D1)
; Look up a color index in the palette table.
; ========================================================================
  0000:07D1  db 56 8B F0 D1 E6 03 75 0E E8 45 00 5E C3          ; push si; si=index*2; call; pop si; ret

; ========================================================================
; (0000:07DE) Search palette table for matching color
; ========================================================================
  0000:07DE  db 53 51 8B 5D 0E 8B 1F 8B CB D1 E3 4B D1 E3 03 5D ; push; walk table; search
  0000:07EE  db 0E 3B 47 02 74 0B 83 EB 04 49 75 F5 B8 00 00 EB ; compare entries; loop
  0000:07FE  db 02 8B 07 59 5B C3                                ; return found entry

; ========================================================================
; dmvetc16_applyColorAndDraw (0000:0804)
; Apply color setting and dispatch to appropriate drawing function.
; ========================================================================
  0000:0804  db 50 56 57 E8 E1 06 0B C0 74 09 8B 76 00 8B        ; push; call; test; load params
  0000:0812  db 7E 02 8B 46 04 E8 07 00 E8 4B 07 5F 5E 58 C3    ; call draw; call cleanup; pop; ret

; ========================================================================
; dmvetc16_dispatchRenderOp (0000:0821)
; Dispatch a render operation based on the operation type byte.
; ========================================================================
  0000:0821  db 51 8A 6C 01 8A 0C 80 F9 4F 75 05 E8 18 00 EB 14 ; push cx; check op type 'O'=0x4F
  0000:0831  db 80 F9 55 75 0A 80 FD 66 75 05 E8 F1 01 EB 05 50 ; check 'U'=0x55 or 'f'=0x66
  0000:0841  db E8 8B FA 58 59 C3                                ; call; pop cx; ret

; ========================================================================
; dmvetc16_drawMultiItem (0000:0847)
; Draw multiple items from a list structure.
; ========================================================================
  0000:0847  db 50 51 56 83 C6 12 8B 0C 83 C6 02                 ; push; add si,0x12; load count
  0000:0852  db 8B 04 E8 7A FF E2 F6 5E 59 58 C3                 ; load item; call; loop; pop; ret

; ========================================================================
; dmvetc16_setupDrawContext (0000:085D)
; Set up the drawing context from DeskMate host parameters.
; ========================================================================
  0000:085D  db 56 1E C5 76 00 E8 03 00 1F 5E C3                 ; push si,ds; lds si; call; pop ds,si; ret
  0000:0868  db 51 55 1E B9 2D 04 8B 6C 10 03                    ; push cx,bp; ds; cx=0x042D; load ptr
  0000:0872  db CD 83 7C 18 00 74 04 D1 E5 03 CD 41 83 E1 FE 2B ; adjust stack; align; sub
  0000:0882  db E1 8B EC 51 06 16 07 1E 56 8D BE DD 03 B9 40 00  ; setup copy loop; 0x40 words
  0000:0892  db C5 34 F3 A4 5E 1F 83 C6 04 B9 0E 00 F3 A4 33 C0 ; rep movsb; clear
  0000:08A2  db 39 44 06 74 06 8B 86 29 04 D1 E0 AB 1E 56 8B 8E ; check; multiply; stosw
  0000:08B2  db 29 04 C5 34 F3 A4 5E 1F 83 C6 04 1E 8B 8E 2B 04 ; copy more data
  0000:08C2  db D1 E1 C5 34 F3 A4 1F 07 E8 D9 01 59 03 E1 1F 5D ; rep movsb; call; cleanup
  0000:08D2  db 59 C3                                             ; pop cx; ret

; ========================================================================
; dmvetc16_computeCharMetrics (0000:08CC)
; Compute character cell metrics (width, height, baseline offset).
; Used by renderCharacter to position glyphs correctly.
; ========================================================================
  0000:08CC  db 50 53 51 52 57 55                               ; push all (PSQRWU)
  0000:08D2  db 83 EC 0A 8B EC 8B 44 3C B1 B4 F6 F1 8A DC 32 FF ; allocate locals; compute metrics
  0000:08E2  db 89 5E 08 8B                                      ; store
  0000:08E6  db 44 0A 2B 44                                      ; compute delta
  0000:08EA  db 02 E8 32 FB 89 46 06 8B 44 0E 2B 44 06 E8 1D FB ; call scale; store
  0000:08FA  db 01 46 06 8B 44 54 E8 1D FB 89 46 04 8B 44 54 E8 ; add offset; call scale again
  0000:090A  db 0B FB 01 46 04 56 8B 46 06 F7 64 38 8B CA 8B D0 ; add; push; multiply
  0000:091A  db 33 DB 33 C0 8B 7E 04 33 F6 E8 E4 07 0B C0 74 05 ; call mulAccum; check result
  0000:092A  db BB 01 00 EB 13 83 FB 00 7F 05 BB 01 00 EB 09 81 ; clamp minimum to 1
  0000:093A  db FB E7 03 7E 03 BB E7 03 5E 89 5C 38 8B 5E 08 8B ; clamp maximum to 999
  0000:094A  db 44 0A 2B 44                                      ; compute delta
  0000:094E  db 02 E8 C5 FA 89 46 02 8B 44 0E 2B 44 06 E8 C2 FA ; call scale; store
  0000:095E  db 01 46 02 8B 44 58 E8 B0 FA 89 46 00 8B 44 58 E8 ; add; call scale again
  0000:096E  db B0 FA 01 46 00 8B 46 02 F7 66 04 8B CA 8B D0 8B ; multiply; move result
  0000:097E  db 44 3A 33 DB E8 D3 07                              ; call mulAccum

; ========================================================================
; dmvetc16_scaledMultiply (0000:0985)
; Scaled 32-bit multiply for character/coordinate positioning.
; ========================================================================
  0000:0985  db 56 50 53 51 52 33                               ; push; setup
  0000:098B  db C0 8B 5E 06 33 C9 8B 56 00 E8 C1 07 8B F1 8B FA ; call mulAccum64; get result
  0000:099B  db 5A 59 5B 58                                      ; pop dx,cx,bx,ax
  0000:099F  db E8 68 07 3D 00 00 7F 05 B8 01 00 EB 08 3D 10 27 ; clamp result 1..10000
  0000:09AF  db 7E 03 B8 10 27 8B 7E 06 8B 4E 04 5E 89 44 3A 8B ; store back
  0000:09BF  db 54 06 52 8B 54 02 8B 5C 3C 8B 44 56 E8 52 FA 0B ; compute scroll offset
  0000:09CF  db C0 74 1E 9C 79 02 F7 D8 F7 E7 F7 F1 8B 54 0A 9D ; check; negate if needed; divide
  0000:09DF  db 79 0D F7 D8 5A 8B 54 0E 89 54 5E 52 8B 54 02 2B ; handle negative
  0000:09EF  db D0 89 54 5C 5A 8B 44 56 E8 1D FA 0B C0 74 1C 9C ; compute remainder
  0000:09FF  db 79 02 F7 D8 F7 E7 F7 F1 8B 54 06 9D 79 0B F7 D8 ; handle negative
  0000:0A0F  db 8B 54 0A 89 54 5C 8B 54 0E 03 D0 89 54 5E 83 C4 ; store final values
  0000:0A1F  db 0A 5D 5F 5A 59 5B 58                             ; deallocate; pop all
  0000:0A26  db C3                                               ; ret

; ========================================================================
; dmvetc16_drawFontGlyph (0000:0A27)
; Draw a single font glyph (character) to the screen.
; ========================================================================
  0000:0A27  db 50 53 51 52 57 55                               ; push all (PSQRWU)
  0000:0A2D  db 1E B9 2D 04 83 E9 65 41 8B 44 12 D1 E0 03 C8 41 ; compute glyph data address
  0000:0A3D  db 83 E1 FE 2B E1 8B EC 51 26 80 3E 30 00 00 74 46 ; align stack; check active flag
  0000:0A4D  db 8B 7C 02 8B 5C 06 8B 4C 0A 8B 54 0E E8 09 F7 72 ; load coords; call clip
  0000:0A5D  db 35 8B 44 3C B1 5A F6 F1 80 FC 00 75 03 E8 5F FE ; check char code; call render
  0000:0A6D  db E8 0C FB 3D FF FF 74 1E 89 7C 02 89 5C 06 89 4C ; check result; update coords
  0000:0A7D  db 0A 89 54 0E 56 06 16 07 8D BE C9 03 8B 4C 12 F3 ; copy glyph bitmap; rep movsw
  0000:0A8D  db A5 07 5E E8 0B 00 59 03 E1 1F                    ; pop es; call; pop cx; pop ds
  0000:0A97  db 5D 5F 5A 59 5B 58                               ; pop all (]_ZY[X)
  0000:0A9D  db C3                                               ; ret

; ========================================================================
; dmvetc16_fullRedraw (0000:0A9E)
; Full screen redraw / repaint operation.
; This is the largest function (~666 bytes), handling complete screen
; repaint including scrolling, memory allocation, and glyph rendering.
; ========================================================================
  0000:0A9E  db 50 53 51 52 56 57                               ; push all (PSQRVW)
  0000:0AA4  db 1E E8 A7 F7 26 80 3E 30 00 00 75 03 E9 7E 02 B0 ; push ds; call; check active; skip if inactive
  0000:0AB4  db FF F7 86 FF 03 40 00 74 02 B0 AA 88 46 1C 8D 9E ; set mask; check flag
  0000:0AC4  db 2D 04 89 9E C7 03 03 9E 29 04 89 9E C5 03 C7 46 ; compute buffer addresses
  0000:0AD4  db 1E 00 00 C7 46 36 FF 7F C7 46 38 00 80 8B 86 27 ; init min/max tracking
  0000:0AE4  db 04 E8 09 F8 89 46 2A 89 46 22 8B 86 25 04 89 46 ; compute initial position
  0000:0AF4  db 24 E8 E4 F7 89 46 20 89 46 28 16 58 8D B6 DD 03 ; store; push ss; load buffer ptr
  0000:0B04  db 89 76 52 89 46 54 89 76 60 89 46 62 16 8F 46 66 ; set up render buffers
  0000:0B14  db 8D 76 68 89 76 64 83 C5 60 B8 0A 00 26 FF 1E 25 ; call host function 0x0A
  0000:0B24  db 00 83 ED 60 32 E4 F7 86 FF 03 10 00 74 14 36 8A ; check flags; adjust position
  0000:0B34  db 44 02                                            ; load byte
  0000:0B36  db 29 46 2A 29 46 22                                ; sub [bp+0x2A]; sub [bp+0x22]
  0000:0B3C  db 8B 46 2A E8 D9 F7 89 86 27 04 F7 86 FF 03 20 00 ; update; call; check more flags
  0000:0B4C  db 74 14 36 8A 44 03 01 46 2A 01 46 22 8B 46 2A E8 ; conditional adjustment
  0000:0B5C  db BD F7 89 86 27 04 BB 60 09 B4 48 CD 21 73 0B 83 ; call; try alloc 0x960 paras (DOS INT 21h/48h)
  0000:0B6C  db FB 40 7E 1C B4 48 CD 21 72 16 D1 E3 D1 E3 D1 E3 ; if fail, try smaller; shift left 4
  0000:0B7C  db D1 E3 89 9E 87 00 C7 46 7D 00 00 89 46 7F EB 11 ; store allocation size
  0000:0B8C  db 8D 86 89 00 89 46 7D 16 8F 46 7F C7 86 87 00 20 ; use internal buffer if alloc failed
  0000:0B9C  db 03 FF 8E 29 04 7D 03 E9 66 01 8B B6 C7 03 FF 86 ; dec counter; jump if done
  0000:0BAC  db C7 03 36 8A 04 32 E4 89 46 56 C7 86 83 00 00 00 ; load char; clear counter
  0000:0BBC  db 83 C5 52 B8 0B 00 26 FF 1E 25 00 83 ED 52 1E 57 ; call host fn 0x0B; push ds,di

; --- Remaining fullRedraw body (glyph rendering loop, memory management) ---
  0000:0BCC  db 89 46 5C 89 56 5E 8E DA 8B F8 83 7D 0E 00 5F 1F ; store ptr; check if end
  0000:0BDC  db 74 03 E9 E3 00 1E 57 C5 7E 5C 8B 5D 08 89 5E 79 ; branch based on data
  0000:0BEC  db 8B 1D 89 5E 71 8B 45 02 8B 5D 04 5F 1F 89 46 73 ; load more glyph data
  0000:0BFC  db 89 5E 75 89 9E 81 00 50 53 52 93 83 C3 07 D1 EB ; store; push; compute offset
  0000:0C0C  db D1 EB D1 EB F7 E3 72 06 3B 86 87 00 76 0B 33 D2 ; divide; check bounds
  0000:0C1C  db 8B 86 87 00 F7 F3 89                              ; divide; store
  0000:0C23  db 46 75 5A 5B 58                                   ; store; pop dx,bx,ax
  0000:0C28  db 8D 76 71 89 76 58 16 8F 46 5A 1E 57 C5 7E 5C 8B ; set up source/dest pointers
  0000:0C38  db 5D 04 8B 4D 0A 5F 1F 2B D9 2B 9E 83 00 89 5E 7B ; compute copy count
  0000:0C48  db FF 76 7B 57 1E C5 7E 5C 8B 5D 0A 03 9E 83 00 8E ; push; load source
  0000:0C58  db 5E 5A 8B 7E 58 89 5E 7B E8 D2 F5 1F 5F E8 2B F5 ; copy glyph data; call
  0000:0C68  db 73 05 83 C4 02 EB 35 8F 46 7B 83 C5 52 B8 0C 00 ; if carry, skip; call host fn 0x0C
  0000:0C78  db 26 FF 1E 25 00 83 ED 52 3D FF FF 75 09 E8 38 01 ; check result
  0000:0C88  db EB 52 90 E9 92 00 C5 7E 5C 8B 5D 0A 03 9E 83 00 ; continue or skip
  0000:0C98  db 89 5E 7B 8E 5E 5A 8B 7E 58 E8 5B F5 8B 86 83 00 ; copy; update pointers
  0000:0CA8  db 03 46 75 89 86 83 00 3B 86 81 00 73 27 03 46 75 ; advance position
  0000:0CB8  db 2B 86 81 00 7E 03 29 46 75 E9 6E FF C5 7E 5C 83 ; check bounds; loop back
  0000:0CC8  db 7D 0E FF 75 05 E8 F0 00 EB 0A 8B 45 04 89 86 81 ; check end marker
  0000:0CD8  db 00 E8 23 F5 C5 7E 5C 8B 46 1E 03 45 06 89 46 1E ; call; update position
  0000:0CE8  db 8B 9E 05 04 E8 28 F7 03 86 25 04 E8 E6 F5 89 46 ; compute next line position
  0000:0CF8  db 20 8B 46 1E E8 21 F7 03 86 27 04 E8 EB F5 89 46 ; update; call scale
  0000:0D08  db 22 E9 91 FE 8B                                   ; loop back to main render loop
  0000:0D0D  db 46 20 2B 46 28                                   ; compute vertical delta

; ========================================================================
; dmvetc16_unloadResources (0000:0D12)
; Unload resources and free allocated memory.
; ========================================================================
  0000:0D12  db 89 46 2C F7 86 FF 03 02 00 74 03 E8 1C 00 83 7E ; store; check flags; call
  0000:0D22  db 7D 00 75 0B 50 06 8E 46 7F B4 49 CD 21 07 58 E8 ; if allocated, free with INT 21h/49h
  0000:0D32  db 30 F5 1F                                          ; call; pop ds
  0000:0D35  db 5F 5E 5A 59 5B 58                               ; pop all (_^ZY[X)
  0000:0D3B  db C3                                               ; ret

; ========================================================================
; dmvetc16_computeWindowBounds (0000:0D3C)
; Compute window bounds for redraw, including font metrics.
; ========================================================================
  0000:0D3C  db 1E 16 1F 8D BE A9 03 E8 29 F6 B8 00 00 F7 86    ; push ds; load buffer; call
  0000:0D4B  db FF 03 40 00 74 03 B8 05 00 8A 9E 23 04 E8 3E F6 ; check flag; load font color
  0000:0D5B  db 8B 9E 05 04 B8 01 00 E8 BB F6 89 46 6D B8 01 00 ; call; store metrics
  0000:0D6B  db E8 A9 F6 89 46 6F 8D 76 68 36 8A 44 01 98 E8 A4 ; call; compute bounds
  0000:0D7B  db F6 01 46 28 01 46 20 36 8A 44 01 98 E8 8D F6    ; update position
  0000:0D8A  db 29 46 2A 29 46 22 36                              ; subtract offsets
  0000:0D91  db 8A 1C 32 FF 8B FB 8B 46 28 8B 5E 2A 8B 4E 20 8B ; load; compute char bounds
  0000:0DA1  db 56 22 E8 B4 F5 4F 74 0E 2B 46 6D 03              ; call; dec; jz done; adjust
  0000:0DAD  db 5E 6F 2B 4E 6D                                   ; adjust cx
  0000:0DB2  db 03 56 6F EB EC                                   ; add; loop
  0000:0DB7  db 8D B6 A9 03 E8 C6 F5 1F C3                       ; restore; pop ds; ret

; ========================================================================
; dmvetc16_adjustResolutionHelper (0000:0DC0)
; Helper for resolution adjustment - programs font metrics.
; ========================================================================
  0000:0DC0  db 16 1F 8D BE A9 03 E8 A6 F5 8B 86 01 04 8B 9E 03 ; load; call; compute
  0000:0DD0  db 04 E8 42 00 E8 01 F6 1E C5 7E 5C 89 45 06 1F 8B ; call; store in host structure
  0000:0DE0  db CB D1 EB D1 EB 2B CB 8B 46 22 E8 2E F5 8B D8 2B ; shift; compute; call
  0000:0DF0  db D9 8B 46 20 E8 0F F5 E8 B4 F5 B0 00 8A A6 23 04 ; call; call; load color
  0000:0E00  db E8 EA F5 B0 20 E8 FA F5 8B 46 56 E8 B5 F5 8D B6 ; call setColor; call setChar; render
  0000:0E10  db A9 03 E8 6F F5 C3                                 ; call; ret

; ========================================================================
; dmvetc16_scaleCoordinates (0000:0E16)
; Scale pixel coordinates to logical coordinates.
; Converts between physical pixel positions and the abstract
; coordinate system used by DeskMate applications.
; ========================================================================
  0000:0E16  db 51 52 B9 E8 03 F7 E1 05 24 00 B9 48             ; push cx,dx; multiply by 1000; add 36
  0000:0E22  db 00 F7 F1 93 F7 E3 B9 DC 00 F7 F1 5A 59 C3      ; divide by 72; multiply; divide by 220; pop; ret

; ========================================================================
; dmvetc16_scaleCoordinates_entrypoint (0000:0E30)
; Entry point wrapper for coordinate scaling.
; ========================================================================
  0000:0E30  db 50 53 52 55 56                                  ; push ax,bx,dx,bp,si (PSRUV)
  0000:0E35  db 1E C5 76 00 33 D2 BB E8 03 B8 C8 00 F7 EB 8B 5C ; push ds; scale Y: 200*1000/height
  0000:0E45  db 06 F7 FB 50 33 D2 BB E8 03 B8 80 02 F7 EB 8B 5C ; scale X: 640*1000/width
  0000:0E55  db 04 F7 FB 50 8B EC B8 0D 00 26 FF 1E 25 00 83 C4 ; call host fn 0x0D
  0000:0E65  db 04 1F                                            ; add sp,4; pop ds
  0000:0E67  db 5E 5D 5A 5B 58                                  ; pop si,bp,dx,bx,ax (^]Z[X)
  0000:0E6C  db C3                                               ; ret

; ========================================================================
; dmvetc16_adjustResolution (0000:0E6D)
; Query host for display metrics and adjust internal resolution.
; Reads the DeskMate host data segment via IVT[0x0386] to get the
; physical screen dimensions, then computes scaling factors.
; ========================================================================
sub_0000_0E6D:
  0000:0E6D  50                push     ax
  0000:0E6E  53                push     bx
  0000:0E6F  52                push     dx
  0000:0E70  55                push     bp
  0000:0E71  06                push     es
  0000:0E72  33c0              xor      ax, ax                   ; AX = 0
  0000:0E74  8ec0              mov      es, ax                   ; ES = 0 (IVT)
  0000:0E76  268e068603        mov      es, word ptr es:[0x386]  ; ES = DM host data segment
  0000:0E7B  33d2              xor      dx, dx
  0000:0E7D  bbe803            mov      bx, 0x3e8               ; BX = 1000
  0000:0E80  b8c800            mov      ax, 0xc8                ; AX = 200 (screen height)
  0000:0E83  f7eb              imul     bx                       ; DX:AX = 200 * 1000
  0000:0E85  268b1e0800        mov      bx, word ptr es:[8]      ; BX = host height value
  0000:0E8A  f7f3              div      bx                       ; AX = 200000 / host_height
  0000:0E8C  50                push     ax                       ; save Y scale factor
  0000:0E8D  33d2              xor      dx, dx
  0000:0E8F  bbe803            mov      bx, 0x3e8               ; BX = 1000
  0000:0E92  b88002            mov      ax, 0x280               ; AX = 640 (screen width)
  0000:0E95  f7eb              imul     bx                       ; DX:AX = 640 * 1000
  0000:0E97  268b1e0600        mov      bx, word ptr es:[6]      ; BX = host width value
  0000:0E9C  f7fb              idiv     bx                       ; AX = 640000 / host_width
  0000:0E9E  5b                pop      bx                       ; BX = Y scale factor
  0000:0E9F  07                pop      es
  0000:0EA0  83ec04            sub      sp, 4                    ; allocate 4 bytes on stack
  0000:0EA3  8bec              mov      bp, sp
  0000:0EA5  50                push     ax
  0000:0EA6  53                push     bx
  0000:0EA7  8d4604            lea      ax, [bp + 4]
  0000:0EAA  16                push     ss
  0000:0EAB  50                push     ax
  0000:0EAC  8d4602            lea      ax, [bp + 2]
  0000:0EAF  16                push     ss
  0000:0EB0  50                push     ax
  0000:0EB1  8bec              mov      bp, sp
  0000:0EB3  b80e00            mov      ax, 0xe                  ; function 0x0E: set resolution
  0000:0EB6  26ff1e2500        lcall    es:[0x25]                ; call host
  0000:0EBB  83c408            add      sp, 8
  0000:0EBE  5b                pop      bx
  0000:0EBF  58                pop      ax
  0000:0EC0  8bec              mov      bp, sp
  0000:0EC2  3b4602            cmp      ax, word ptr [bp + 2]    ; compare with returned X
  0000:0EC5  7505              jne      0xecc                    ; if different, update
  0000:0EC7  3b5e04            cmp      bx, word ptr [bp + 4]    ; compare with returned Y
  0000:0ECA  740f              je       0xedb                    ; if same, skip update

loc_0000_0ECC:
  0000:0ECC  53                push     bx
  0000:0ECD  50                push     ax
  0000:0ECE  8bec              mov      bp, sp
  0000:0ED0  b80d00            mov      ax, 0xd                  ; function 0x0D: update resolution
  0000:0ED3  26ff1e2500        lcall    es:[0x25]                ; call host
  0000:0ED8  83c404            add      sp, 4

loc_0000_0EDB:
  0000:0EDB  83c404            add      sp, 4                    ; deallocate stack frame
  0000:0EDE  5d                pop      bp
  0000:0EDF  5a                pop      dx
  0000:0EE0  5b                pop      bx
  0000:0EE1  58                pop      ax
  0000:0EE2  c3                ret

; ========================================================================
; dmvetc16_setupVideoMode (0000:0EE3)
; Set up video mode, program TGA registers, hook INT ABh.
; This is called when the video driver is first activated.
;
; Steps:
;   1. Check if INT ABh vectors already have the magic 0xABCD/0xDCBA
;   2. Hook INT ABh via INT E0h AH=02h (for DMVSTC16 cooperation)
;   3. Call host function 0x00 to initialize video
;   4. If successful, push font setup parameters and call host fn 0x03
;   5. Call adjustResolution to configure display scaling
;   6. Increment active driver count at es:[0x30]
; ========================================================================
  0000:0EE3  db 53 52 56 57 55                                  ; push bx,dx,si,di,bp (SRVWU)
  0000:0EE8  db 83 EC 02 8B EC 26 81 3E 25 00 CD AB 75 56 26 81 ; allocate; check es:[0x25]=0xABCD
  0000:0EF8  db 3E 27 00 BA DC 75 4D BB 25 00 BA 29 00 B8 08 02 ; check es:[0x27]=0xDCBA; INT E0h AH=02h/08h
  0000:0F08  db CD E0 C7 46 00 00 00 0B C0 75 05 C7 46 00 01 00 ; store result; if AX!=0, set flag
  0000:0F18  db B8 06 02 CD E0 0B C0 74 36 B8 00 00 26 FF 1E 25 ; INT E0h AH=06h/02h; call host fn 0x00
  0000:0F28  db 00 83 7E 00 00 74 1D 83 EC 05 8B EC C6 46 00 03 ; check flag; push font setup params
  0000:0F38  db C7 46 01 FF FF 16                                ; set params for host fn 0x03

; --- Inline: call host function 0x03 (set font) ---
  0000:0F3E  55                push     bp
  0000:0F3F  8bec              mov      bp, sp
  0000:0F41  b80300            mov      ax, 3                    ; function 0x03: set font
  0000:0F44  26ff1e2500        lcall    es:[0x25]                ; call host
  0000:0F49  83c409            add      sp, 9                    ; deallocate font params
  0000:0F4C  e81eff            call     0xe6d                    ; call adjustResolution
  0000:0F4F  26fe063000        inc      byte ptr es:[0x30]       ; increment active driver count
  0000:0F54  b80100            mov      ax, 1                    ; return 1 (success)
  0000:0F57  83c402            add      sp, 2                    ; deallocate local
  0000:0F5A  5d                pop      bp
  0000:0F5B  5f                pop      di
  0000:0F5C  5e                pop      si
  0000:0F5D  5a                pop      dx
  0000:0F5E  5b                pop      bx
  0000:0F5F  c3                ret

; ========================================================================
; dmvetc16_teardownVideoMode (0000:0F60)
; Tear down video mode, restore INT ABh vectors.
;
; Steps:
;   1. Check if driver count es:[0x30] == 1
;   2. Call host function 0x01 to release video mode
;   3. Unhook INT ABh via INT E0h AH=02h/07h
;   4. Restore original INT ABh signature (0xABCD / 0xDCBA)
;   5. Decrement active driver count
; ========================================================================
  0000:0F60  db 50 52 26 80 3E 30 00 01 75 1E B8 01 00 26 FF 1E ; push; check count==1; call host fn 0x01
  0000:0F70  db 25 00 BA 29 00 B8 07 02 CD E0 26 C7 06 25 00 CD ; INT E0h AH=02h/07h (unhook)
  0000:0F80  db AB 26 C7 06 27 00 BA DC 26 FE 0E 30 00 5A 58 C3 ; restore 0xABCD/0xDCBA; dec count; pop; ret

; ========================================================================
; dmvetc16_expandPixelColor (0000:0F90)
; Expand a 4-bit color index to a pixel fill pattern for TGA 16-color mode.
; In 16-color TGA mode, each pixel is 4 bits (one nibble). This function
; takes a color index in AL and expands it to fill both nibbles of a byte,
; creating a solid-color byte value for fast fill operations.
;
; Entry: AL = 4-bit color index (0x0-0xF)
; Exit:  AL = expanded color byte (e.g., 0x05 -> 0x55)
;        AH = copy of AL, DL = copy, DH = copy
; ========================================================================
  0000:0F90  db 90                                               ; NOP alignment
  0000:0F91  db 50 8A E0 D0 E4 D0 E4 D0 E4 D0 E4 0A E0 8A D4  ; push ax; ah=al; shl ah,4 (x4); or al,ah
  0000:0F9F  db 8A F4 58 C3                                      ; dh=ah; pop ax; ret

; ========================================================================
; dmvetc16_calcScanlineOffset (0000:0FA3)
; Calculate video memory offset from a Y coordinate.
; For TGA 16-color mode: offset = Y * 320 (0x140 bytes per scanline)
;
; Entry: DI = Y coordinate
; Exit:  DI = byte offset into video memory
;        CX = bit position within byte (for sub-byte pixel addressing)
; ========================================================================
  0000:0FA3  db 8B FB D1 E7 D1 E7 03 FB D1 E7 D1 E7             ; di = di*2*2 + di = di*5; then *4*4
  0000:0FAF  db D1 E7 D1 E7 D1 E7 D1 E7                         ; di = di * 256 = Y * 320
  0000:0FB7  db 8B C8 D1 F9 03 F9 8B C8                          ; cx = ax; cx/2 + di; cx = bit pos
  0000:0FBF  db 83 E1 01 C3                                      ; cx &= 1; ret

; ========================================================================
; dmvetc16_fastBlit (0000:0FC3)
; Character blit routine for TGA 16-color mode.
; Handles both aligned (full-byte) and partial-byte character rendering
; using 4-bit-per-pixel mask lookups from the pixel mask table at 0x10E8.
;
; Each entry in the mask table at 0x10E8 provides precomputed AND/OR
; masks for the 16 possible 4-bit color values, enabling fast pixel
; output without per-pixel branching.
; ========================================================================
  0000:0FC3  db 0A DB 74 FB                                      ; or bl,bl; jz return
  0000:0FC7  db 53 51 56 57 0A                                   ; push bx,cx,si,di; or
  0000:0FCC  db C9 75 03 E9 8F 00 FE CB 74 46 AC 8A E7 8A F8 D3 ; check cx; dec bl; load byte; shift
  0000:0FDC  db E8 22 46 1C 53 51 8A D8 81 E3 F0 00 D0 EB D0 EB ; mask; push; extract high nibble
  0000:0FEC  db D0 EB 2E 8B 9F E9 10 93 8B C8 F7 D1              ; lookup in mask table at 0x10E9

; --- Pixel mask application ---
; The 16-color pixel mask table at 0x10E8 contains 16 entries.
; Each entry is 8 bytes providing precomputed bitmasks for the
; AND/OR pixel composition operations.
  0000:0FF8  db 26 23 0D 23                                      ; es: and cx,[di]; and ax,...
  0000:0FFC  db C2 0B C1 AB 83 E3 0F D0 E3 2E 8B 87 E9 10 8B C8 ; or; stosw; mask low nibble; lookup
  0000:100C  db F7 D1                                            ; not cx (invert mask)
  0000:100E  db 26 23 0D 23                                      ; es: and cx,[di]; and ax,...
  0000:1012  db C2 0B C1 AB 59 5B FE CB 75 BA AC 8A E7 D3 E8 22 ; or; stosw; pop; dec; loop; load; shift
  0000:1022  db C5 22 46 1C 53 51 8A D8 81 E3 F0 00 D0 EB D0 EB ; mask with foreground; extract nibble
  0000:1032  db D0 EB 2E 8B 9F E9 10 93 8B C8 F7 D1              ; lookup in mask table
  0000:103E  db 26 23 0D 23                                      ; apply mask
  0000:1042  db C2 0B C1 AB 83 E3 0F D0 E3 2E 8B 87 E9 10 8B C8 ; continued
  0000:1052  db F7 D1                                            ; not cx
  0000:1054  db 26 23 0D 23                                      ; apply mask
  0000:1058  db C2 0B C1 AB 59 5B E9 82 00 FE CB 74 40 AC 22 46 ; continued; handle remaining cases
  0000:1068  db 1C 53 51 8A D8 81 E3 F0 00 D0 EB D0 EB D0 EB 2E ; extract nibble; lookup
  0000:1078  db 8B 9F E9 10 93 8B C8 F7 D1                       ; mask table access
  0000:1081  db 26 23 0D 23                                      ; apply mask
  0000:1085  db C2 0B C1 AB 83 E3 0F D0 E3 2E 8B 87 E9 10 8B C8 ; continued
  0000:1095  db F7 D1                                            ; not cx
  0000:1097  db 26 23 0D 23                                      ; apply mask
  0000:109B  db C2 0B C1 AB 59 5B FE CB 75 C0 AC 22 C5 22 46 1C ; continued; loop
  0000:10AB  db 53 51 8A D8 81 E3 F0 00 D0 EB D0 EB D0 EB 2E 8B ; final nibble case
  0000:10BB  db 9F E9 10 93 8B C8 F7 D1                           ; lookup
  0000:10C3  db 26 23 0D 23                                      ; apply mask
  0000:10C7  db C2 0B C1 AB 83 E3 0F D0 E3 2E 8B 87 E9 10 8B C8 ; continued
  0000:10D7  db F7 D1                                            ; not cx
  0000:10D9  db 26 23 0D 23                                      ; apply mask
  0000:10DD  db C2 0B C1 AB                                      ; or; stosw
  0000:10E1  db 59 5B 5F 5E 59 5B                               ; pop cx,bx,di,si,cx,bx (Y[_^Y[)
  0000:10E7  db C3                                               ; ret

; --- 16-color pixel mask table (0000:10E8) ---
; 16 entries x 8 bytes = 128 bytes.
; Each entry maps a 4-bit color value (0x0-0xF) to precomputed
; AND/OR bitmask pairs for fast pixel composition.
  0000:10E8  db 00 00 00 0F 00 F0 00 FF 0F 00 0F 0F 0F F0 0F    ; masks for colors 0-7
  0000:10F7  db FF F0 00 F0 0F F0 F0 F0 FF FF 00 FF 0F FF F0 FF ; masks for colors 8-15
  0000:1107  db FF                                               ; end marker

; ========================================================================
; dmvetc16_bresenhamSetup (0000:1108)
; Set up Bresenham line drawing parameters.
; ========================================================================
  0000:1108  db 90 55 83 EC 06 8B EC C7 46 00 20 00 C7 46 02     ; NOP; push bp; allocate; init counter=32
  0000:1117  db 00 00 C7 46 04 00 00 D1 E2 D1 D1 D1 D3 D1 D0 D1 ; init accumulators; shift loop
  0000:1127  db 66 02 D1 56 04 3B C6 72 11 77 04 3B DF 72 0B 2B ; compare; adjust
  0000:1137  db DF 1B C6 FF 46 02 83 56 04 00 FF 4E 00 75 D8 EB ; decrement; loop
  0000:1147  db 00 8B C8 8B D3 8B 46 04 8B 5E 02 83 C4 06 5D C3 ; result; deallocate; ret

; ========================================================================
; dmvetc16_mulAccum64 (0000:1158)
; 64-bit multiply-accumulate for coordinate calculations.
; ========================================================================
  0000:1158  db 55 83 EC 10 8B EC 89 46 08 89 5E 0A 89 4E 0C 89 ; push bp; allocate; store params
  0000:1168  db 56 0E C7 46 04 00 00 C7 46 06 00 00 8B 5E 0E 8B ; init accumulators
  0000:1178  db 46 0A BA 00 00 F7 E3 89 46 00 89 56 02 8B 46 08 ; multiply low parts
  0000:1188  db BA 00 00 F7 E3 01 46 02 11 56 04 83 56 06 00 8B ; add cross products
  0000:1198  db 5E 0C 8B 46 0A BA 00 00 F7 E3 01 46 02 11 56 04 ; more cross products
  0000:11A8  db 83 56 06 00 8B 46 08 BA 00 00 F7 E3 01 46 04 11 ; high part
  0000:11B8  db 56 06 8B 46 06 8B 5E 04                          ; load 64-bit result

; ========================================================================
; SEGMENT seg_011C  (16 bytes) -- Epilogue Stub
; ========================================================================
seg_011C:

; This segment contains only the tail end of mulAccum64's return:
; loads the remaining result registers and returns.
  011C:0000  db 8B 4E 02 8B 56 00 83 C4 10 5D C3 00 00 00 00 00 ; mov cx,[bp+2]; mov dx,[bp]; add sp,16; pop bp; ret

; ========================================================================
; SEGMENT seg_011D  (400 bytes) -- DM89 Header + Entry Point
; ========================================================================
seg_011D:

; ========================================================================
; dmvetc16_dm89Header (011D:0000)
; DM89 module header. The first 8 bytes are the module name "DMVETC16",
; followed by version, self-reference relocations, and companion names.
; ========================================================================
sub_011D_0000:
  011D:0000  44                inc      sp                       ; 'D'
  011D:0001  4d                dec      bp                       ; 'M'
  011D:0002  56                push     si                       ; 'V'
  011D:0003  45                inc      bp                       ; 'E'
  011D:0004  54                push     sp                       ; 'T'
  011D:0005  43                inc      bx                       ; 'C'
  011D:0006  3136e300          xor      word ptr [0xe3], si      ; '1', '6', version "33.10" continuation
  011D:000A  1d014a            sbb      ax, 0x4a01               ; RELOC -> seg_011D (self-reference)
  011D:000D  011d              add      word ptr [di], bx        ; RELOC -> seg_011D (self-reference)
  011D:000F  0100              add      word ptr [bx + si], ax
  011D:0011  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; reserved (16 bytes zeroed)

; --- Companion module linkage ---
  011D:0021  db 00                                               ; flags byte
  011D:0022  db 03                                               ; companion count = 3
  011D:0023  db 0E                                               ; offset to first companion entry
  011D:0024  01cd              add      bp, cx                   ; (data, not code)
  011D:0026  ab                stosw    word ptr es:[di], ax     ; 0xABCD signature
  011D:0027  badc44            mov      dx, 0x44dc               ; 0xDCBA signature (reversed)

; --- "DMFONT" companion name ---
  011D:002A  4d                dec      bp                       ; 'D' (actually 'M' due to encoding)
  011D:002B  46                inc      si                       ; 'F' -> "DMFONT\0"
  011D:002C  4f                dec      di                       ; 'O'
  011D:002D  4e                dec      si                       ; 'N'
  011D:002E  54                push     sp                       ; 'T'
  011D:002F  0000              add      byte ptr [bx + si], al   ; NUL terminator

; --- INT ABh vector for standard driver pairing ---
  011D:0031  cdab              int      0xab                     ; INT ABh: rendezvous call
  011D:0033  badc44            mov      dx, 0x44dc               ; signature 0xDCBA

; --- "DMVSTC16" standard companion name ---
  011D:0036  4d                dec      bp                       ; 'D' -> "DMVSTC16"
  011D:0037  56                push     si                       ; 'V'
  011D:0038  53                push     bx                       ; 'S'
  011D:0039  54                push     sp                       ; 'T'
  011D:003A  43                inc      bx                       ; 'C'
  011D:003B  31360000          xor      word ptr [0], si         ; '1', '6'
  011D:003F  0000              add      byte ptr [bx + si], al   ; NUL pad

; --- Mode flag and thunk data ---
  011D:0041  db 00                                               ; mode flag: 'Y'=640-wide, 'X'=320-wide

; ========================================================================
; dmvetc16_apiRouteThunk (011D:0044)
; Far-call dispatch thunk. Routes API calls from the host into the
; correct seg_0000 drawing function. Handles both normal (0x42) and
; extended (0x58='X') dispatch modes.
; ========================================================================
  011D:0044  db 00 53 06                                         ; (data: dispatch index prelude)
  011D:0047  55                push     bp
  011D:0048  83ec0a            sub      sp, 0xa                  ; allocate 10-byte stack frame
  011D:004B  8bec              mov      bp, sp
  011D:004D  52                push     dx
  011D:004E  2e8a164100        mov      dl, byte ptr cs:[0x41]   ; load mode flag
  011D:0053  885609            mov      byte ptr [bp + 9], dl    ; save to local
  011D:0056  2ec41e3100        les      bx, ptr cs:[0x31]        ; load INT ABh vector (standard driver)
  011D:005B  80fa58            cmp      dl, 0x58                 ; is mode 'X' (320-wide)?
  011D:005E  7506              jne      0x66                     ; if not, skip index adjustment

  011D:0060  d1e0              shl      ax, 1                    ; AX *= 4 (extended index)
  011D:0062  d1e0              shl      ax, 1
  011D:0064  03d8              add      bx, ax                   ; adjust table pointer

loc_011D_0066:
  011D:0066  5a                pop      dx
  011D:0067  8c4602            mov      word ptr [bp + 2], es    ; save ES (host segment)
  011D:006A  895e00            mov      word ptr [bp], bx        ; save BX (function pointer)
  011D:006D  8c4e06            mov      word ptr [bp + 6], cs    ; save CS for return
  011D:0070  bb9500            mov      bx, 0x95                 ; offset of thunk epilogue
  011D:0073  895e04            mov      word ptr [bp + 4], bx    ; set return address
  011D:0076  50                push     ax
  011D:0077  b80000            mov      ax, 0                    ; AX = 0
  011D:007A  8ec0              mov      es, ax                   ; ES = 0 (IVT)
  011D:007C  26a18603          mov      ax, word ptr es:[0x386]  ; AX = DM host data segment
  011D:0080  8ec0              mov      es, ax                   ; ES = host data segment
  011D:0082  58                pop      ax
  011D:0083  8b5e0e            mov      bx, word ptr [bp + 0xe]  ; load caller's BX
  011D:0086  52                push     dx
  011D:0087  8a5609            mov      dl, byte ptr [bp + 9]    ; reload mode flag
  011D:008A  80fa58            cmp      dl, 0x58                 ; check for 'X' mode
  011D:008D  7506              jne      0x95                     ; skip if not extended

  011D:008F  8b4610            mov      ax, word ptr [bp + 0x10] ; load extended AX parameter
  011D:0092  8b6e0a            mov      bp, word ptr [bp + 0xa]  ; load extended BP parameter

loc_011D_0095:
  011D:0095  5a                pop      dx
  011D:0096  45                inc      bp                       ; adjust BP (skip saved frame)
  011D:0097  cb                retf                              ; far return into drawing function

; --- Thunk epilogue (011D:0095) ---
; After the drawing function returns, control comes here.
; Adjusts stack and checks mode flag before returning to caller.
  011D:0098  db 83 C4 0A 2E 80 3E 41 00 58 75 01 4D CB          ; add sp,10; cmp cs:[0x41],'X'; pop ax; jne; dec bp; retf

; ========================================================================
; entry_point (011D:00A2)
; Module entry point -- called by DESK.EXE when loading this DM89 module.
;
; Steps:
;   1. Save DS into module header for relocation
;   2. Query hardware capabilities via INT E0h AH=06h
;   3. Set mode flag ('Y' for 640-wide or 'X' for 320-wide)
;   4. Register dispatch table (seg_0000) via INT E0h AH=01h
;   5. Hook INT ABh for standard driver cooperation
;   6. Get PSP and terminate-and-stay-resident (INT 21h/31h)
; ========================================================================
entry_point:
  011D:00A2  0e                push     cs
  011D:00A3  07                pop      es                       ; ES = CS
  011D:00A4  bb0000            mov      bx, 0
  011D:00A7  268c5f20          mov      word ptr es:[bx + 0x20], ds  ; save DS in module header
  011D:00AB  b80006            mov      ax, 0x600
  011D:00AE  cde0              int      0xe0                     ; INT E0h, AH=06h: query capabilities
  011D:00B0  250080            and      ax, 0x8000               ; test bit 15
  011D:00B3  b8f001            mov      ax, 0x1f0                ; AX = function range (0x01F0)
  011D:00B6  26c606410059      mov      byte ptr es:[0x41], 0x59 ; mode = 'Y' (640-wide default)
  011D:00BC  7508              jne      0xc6                     ; if bit 15 set, keep 640-wide

  011D:00BE  b8ff01            mov      ax, 0x1ff                ; extended function range (320-wide)
  011D:00C1  26fe0e4100        dec      byte ptr es:[0x41]       ; mode = 'X' (320-wide)

loc_011D_00C6:
  011D:00C6  b90000            mov      cx, 0                    ; RELOC -> seg_0000 (dispatch table)
  011D:00C9  cde0              int      0xe0                     ; INT E0h, AH=01h: register driver
  011D:00CB  26a23e00          mov      byte ptr es:[0x3e], al   ; save registration result
  011D:00CF  e88900            call     0x15b                    ; call hookINTAB
  011D:00D2  b451              mov      ah, 0x51
  011D:00D4  cd21              int      0x21                     ; INT 21h/51h: Get PSP segment
  011D:00D6  4b                dec      bx                       ; BX = PSP - 1 (MCB)
  011D:00D7  8ec3              mov      es, bx
  011D:00D9  268b160300        mov      dx, word ptr es:[3]      ; DX = MCB allocation size
  011D:00DE  b80031            mov      ax, 0x3100
  011D:00E1  cd21              int      0x21                     ; INT 21h/31h: TSR (terminate and stay resident)

; ========================================================================
; dmvetc16_apiDispatch (011D:00E3)
; API dispatch function. Called by the host for each video operation.
; Saves all registers, acquires task lock via INT E0h AH=4Dh,
; routes the call into seg_0000, then releases the lock.
; ========================================================================
  011D:00E3  53                push     bx                       ; save BX
  011D:00E4  8bdc              mov      bx, sp
  011D:00E6  83e301            and      bx, 1                    ; check stack alignment
  011D:00E9  2be3              sub      sp, bx                   ; align to word boundary
  011D:00EB  53                push     bx                       ; save alignment adjustment
  011D:00EC  51                push     cx
  011D:00ED  56                push     si
  011D:00EE  57                push     di
  011D:00EF  55                push     bp
  011D:00F0  1e                push     ds
  011D:00F1  06                push     es
  011D:00F2  9c                pushf
  011D:00F3  fc                cld                               ; clear direction flag

  011D:00F4  3d0d00            cmp      ax, 0xd                  ; function index < 13?
  011D:00F7  7205              jb       0xfe                     ; yes -> dispatch
  011D:00F9  b8ffff            mov      ax, 0xffff               ; return -1 (invalid function)
  011D:00FC  eb40              jmp      0x13e                    ; jump to cleanup

loc_011D_00FE:
  011D:00FE  50                push     ax                       ; save function index
  011D:00FF  2ea03e00          mov      al, byte ptr cs:[0x3e]   ; load task lock ID
  011D:0103  3cff              cmp      al, 0xff                 ; 0xFF = no lock needed
  011D:0105  7409              je       0x110                    ; skip lock acquisition

  011D:0107  52                push     dx
  011D:0108  8ad0              mov      dl, al                   ; DL = lock ID
  011D:010A  b8044d            mov      ax, 0x4d04               ; INT E0h AH=4Dh: acquire task lock
  011D:010D  cde0              int      0xe0
  011D:010F  5a                pop      dx

loc_011D_0110:
  011D:0110  2ea23f00          mov      byte ptr cs:[0x3f], al   ; save current lock state
  011D:0114  58                pop      ax                       ; restore function index
  011D:0115  2eff363f00        push     word ptr cs:[0x3f]       ; push saved lock state
  011D:011A  bb1c01            mov      bx, 0x11c               ; RELOC -> seg_011C (epilogue segment)
  011D:011D  8ec3              mov      es, bx                   ; ES = epilogue segment
  011D:011F  0e                push     cs
  011D:0120  5b                pop      bx                       ; BX = CS (this segment)
  011D:0121  9a04000000        lcall    0, 4                     ; far call into seg_0000 dispatch
  011D:0126  2e8f063f00        pop      word ptr cs:[0x3f]       ; restore saved lock state
  011D:012B  50                push     ax                       ; save result
  011D:012C  2ea03f00          mov      al, byte ptr cs:[0x3f]   ; load lock state
  011D:0130  3cff              cmp      al, 0xff                 ; 0xFF = no lock held
  011D:0132  7409              je       0x13d                    ; skip release

  011D:0134  52                push     dx
  011D:0135  8ad0              mov      dl, al                   ; DL = lock ID
  011D:0137  b8054d            mov      ax, 0x4d05               ; INT E0h AH=4Dh: release task lock
  011D:013A  cde0              int      0xe0
  011D:013C  5a                pop      dx

loc_011D_013D:
  011D:013D  58                pop      ax                       ; restore result

loc_011D_013E:
  011D:013E  9d                popf                              ; restore all registers
  011D:013F  07                pop      es
  011D:0140  1f                pop      ds
  011D:0141  5d                pop      bp
  011D:0142  5f                pop      di
  011D:0143  5e                pop      si
  011D:0144  59                pop      cx
  011D:0145  5b                pop      bx
  011D:0146  03e3              add      sp, bx                   ; undo alignment adjustment
  011D:0148  5b                pop      bx                       ; restore original BX
  011D:0149  cb                retf                              ; return to host

; --- Cleanup thunk (011D:014A) ---
; Called during teardown to unhook INT ABh.
  011D:014A  db 50 06 52 0E 07 BA 35 00 B8 07 02 CD E0 5A 07 58 ; push; unhook INT ABh; INT E0h AH=02h/07h
  011D:015A  db CB                                               ; retf

; ========================================================================
; dmvetc16_hookINTAB (011D:015B)
; Hook INT ABh to establish cooperation with the standard driver
; (DMVSTC16.RES). The enhanced driver hooks INT ABh so that when
; the standard driver is loaded, it can find the enhanced driver's
; dispatch table.
;
; If mode is not 'Y' (640-wide), modifies the companion name by
; changing byte at offset 0x38 to 'D' (altering "DMVSTC16" lookup).
; ========================================================================
sub_011D_015B:
  011D:015B  53                push     bx
  011D:015C  52                push     dx
  011D:015D  26803e410059      cmp      byte ptr es:[0x41], 0x59 ; mode == 'Y' (640-wide)?
  011D:0163  740a              je       0x16f                    ; yes -> skip name modification

  011D:0165  bb3500            mov      bx, 0x35                 ; offset of companion name
  011D:0168  83c303            add      bx, 3                    ; point to 4th byte ("T" in "DMVSTC16")
  011D:016B  26c60744          mov      byte ptr es:[bx], 0x44   ; change to 'D' (makes "DMVDTC16"?)

loc_011D_016F:
  011D:016F  bb3100            mov      bx, 0x31                 ; offset of INT ABh vector storage
  011D:0172  ba3500            mov      dx, 0x35                 ; offset of companion name
  011D:0175  b80602            mov      ax, 0x206                ; INT E0h AH=02h, AL=06h: hook INT ABh
  011D:0178  cde0              int      0xe0
  011D:017A  48                dec      ax                       ; check result (1 = success)
  011D:017B  0bc0              or       ax, ax
  011D:017D  750c              jne      0x18b                    ; if failed, skip

  011D:017F  26ff1e3100        lcall    es:[0x31]                ; call through INT ABh (notify standard)
  011D:0184  26891e3100        mov      word ptr es:[0x31], bx   ; save returned vector
  011D:0189  33c0              xor      ax, ax                   ; return 0

loc_011D_018B:
  011D:018B  5a                pop      dx
  011D:018C  5b                pop      bx
  011D:018D  c3                ret

  011D:018E  db 00 00                                            ; padding

; ========================================================================
; SEGMENT seg_0136  (2 bytes) -- Stack
; ========================================================================
seg_0136:

  0136:0000  db 00 00                                            ; stack space (minimal, host provides stack)
