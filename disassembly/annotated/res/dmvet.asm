; ========================================================================
; DMVET.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Tandy Graphics Adapter (TGA) Enhanced Video Driver
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVET.RES is the "enhanced" video resource driver for the Tandy Graphics
; Adapter (TGA). It is loaded by DESK.EXE when the user selects the Tandy
; 4-color (320x200x4) enhanced video mode via DMVID.EXE.
;
; Architecture: The enhanced video driver (DMVE*) is a thin dispatch shim.
; It does NOT contain the actual drawing routines. Instead, it:
;   1. Registers a function dispatch table (seg_0000) with DESK.EXE
;      via INT E0h AH=01h during initialization.
;   2. DESK.EXE calls back into the driver through the dispatch mechanism
;      for video operations (draw pixel, draw line, fill rect, etc.).
;   3. The seg_0000 code implements the Tandy-specific rendering using
;      direct TGA hardware register access.
;
; This contrasts with the "standard" driver (DMVST.RES) which contains
; its own complete set of drawing routines (~22KB).
;
; The enhanced driver provides higher performance by hooking directly into
; the host's video abstraction layer, while the standard driver is
; self-contained for compatibility.
;
; Key hardware accessed:
;   Port 0x03C4 - TGA/EGA Sequencer Address Register
;   Port 0x03C5 - TGA/EGA Sequencer Data Register
;   Port 0x03CE - TGA/EGA Graphics Controller Address Register
;   Port 0x03CF - TGA/EGA Graphics Controller Data Register
;   Segment B800h implied via [0x0386] IVT entry (Tandy video segment)
;
; DM89 Module Information:
;   Paired with: DMVST.RES (standard counterpart)
;   Module name at seg_0113:0000 = "DMVET"
;   Font companion name at seg_0113:0022 = "DMFONT"
;   Standard companion name at seg_0113:0031 = INT ABh hook -> "DMVST"
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5,314 bytes
; Load image: 4,802 bytes (after header)
; DM89 entry point: 0113:009F
; SS:SP = 012C:0002
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  4,384 bytes  CODE/DATA  Video rendering routines + dispatch table
;   seg_0112     16 bytes  CODE       Epilogue stub (pop bp; ret)
;   seg_0113    400 bytes  CODE       DM89 header, dispatch thunk, entry point
;   seg_012C      2 bytes  STACK      Stack segment
;
; DM89 flags: Enhanced video driver (paired with standard driver)
;
; ========================================================================
; VIDEO DISPATCH TABLE
; ========================================================================
;
; The dispatch table at seg_0000:0020 contains word offsets into seg_0000
; for each video function. The entry at [0x0000] selects the video segment
; (0x00A0 = segment A000h for TGA mode). Function indices 0-12:
;
;   Index  Offset  Function
;   -----  ------  --------
;   0x00   0x0007  dmvet_initVideoSegment    - Initialize video mode segment
;   0x01   0x07FD  dmvet_apiThunk_11h        - Far-call thunk: function 0x11
;   0x02   0x07BA  dmvet_apiThunk_10h        - Far-call thunk: function 0x10
;   0x03   0x0250  dmvet_apiThunk_unused1    - Unused slot (returns)
;   0x04   0x0265  dmvet_apiThunk_unused2    - Unused slot (returns)
;   0x05   0x027A  dmvet_apiThunk_unused3    - Unused slot (returns)
;   0x06   0x0294  dmvet_apiThunk_unused4    - Unused slot (returns)
;   0x07   0x0533  dmvet_initDriverContext   - Init driver context from params
;   0x08   0x031E  dmvet_apiThunk_12h        - Far-call thunk: function 0x12
;   0x09   0x0E6E  dmvet_adjustResolution    - Adjust display resolution
;   0x0A   0x0EE4  dmvet_setupVideoMode      - Set up video mode + INT ABh hook
;   0x0B   0x0F61  dmvet_teardownVideoMode   - Tear down video mode, unhook
;   0x0C   0x07A2  dmvet_setColors           - Set color palette entries
;
; Each "apiThunk" pushes a return address and function code, then does a
; far-call into the DESK.EXE host via the IVT pointer at [0x0386].
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
; Address    Name                           Size  Description
; -------    ----                           ----  -----------
; 0000:0000  (data: video segment word)       2   Video segment selector (0x00A0)
; 0000:0002  (data: unused)                   5   Padding / reserved
; 0000:0007  dmvet_dispatchViaTable          22   Dispatch: load offset from table, far-call
; 0000:0013  dmvet_hostFarCall               13   Far-call into host via es:[0x25]
; 0000:0020  (data: dispatch table)          25   12-word function offset table
; 0000:0039  dmvet_drawBitmapRow           154   Draw a bitmap row with clipping
; 0000:00D3  (epilogue)                       6   pop di,si,dx,cx,bx,ax
; 0000:00D9  dmvet_drawBitmapAligned        141   Draw aligned bitmap (byte-boundary)
; 0000:0166  dmvet_clipToWindow              45   Clip coordinates to window bounds
; 0000:0193  dmvet_clipRect                 109   Full rectangle clip against window
; 0000:0200  dmvet_transformCoords           54   Transform coords to screen space
; 0000:0236  dmvet_getScreenMetrics          26   Get screen offset calculations
; 0000:0250  dmvet_apiThunk_3Fh_6Ah         45   Far-call thunk: host function 0x6A
; 0000:027D  dmvet_apiThunk_3Fh_69h         45   Far-call thunk: host function 0x69
; 0000:02B0  dmvet_apiThunk_3Fh_64h         28   Far-call thunk: host function 0x64
; 0000:02CC  dmvet_apiThunk_3Fh_63h         28   Far-call thunk: host function 0x63
; 0000:02E8  dmvet_apiThunk_3Fh_59h         28   Far-call thunk: host function 0x59
; 0000:0304  dmvet_apiThunk_3Fh_5Bh         28   Far-call thunk: host function 0x5B
; 0000:0320  dmvet_apiThunk_3Fh_12h         28   Far-call thunk: host function 0x12
; 0000:033C  dmvet_apiThunk_3Fh_13h         28   Far-call thunk: host function 0x13
; 0000:0358  dmvet_apiThunk_3Fh_65h         28   Far-call thunk: host function 0x65
; 0000:0374  dmvet_apiThunk_3Fh_66h         28   Far-call thunk: host function 0x66
; 0000:0390  dmvet_apiThunk_3Fh_6Bh         28   Far-call thunk: host function 0x6B
; 0000:03AC  dmvet_apiThunk_3Fh_27h         28   Far-call thunk: host function 0x27
; 0000:03C8  dmvet_apiThunk_3Fh_4Ch         28   Far-call thunk: host function 0x4C
; 0000:03E4  dmvet_apiThunk_3Fh_53h         28   Far-call thunk: host function 0x53
; 0000:0400  dmvet_apiThunk_3Fh_38h         28   Far-call thunk: host function 0x38
; 0000:041C  dmvet_apiThunk_3Fh_3Eh         28   Far-call thunk: host function 0x3E
; 0000:0438  dmvet_apiThunk_3Fh_6Dh         28   Far-call thunk: host function 0x6D
; 0000:0454  dmvet_apiThunk_3Fh_51h         28   Far-call thunk: host function 0x51
; 0000:0470  dmvet_apiThunk_3Fh_4Eh         28   Far-call thunk: host function 0x4E
; 0000:047D  (data: trig/scaling table)     182   Trigonometric / Bresenham lookup table
; 0000:0533  dmvet_initDriverContext         74   Parse init params, set up driver context
; 0000:057D  dmvet_renderCharacter         593   Render a character glyph to screen
; 0000:07A2  dmvet_setColorPair             30   Set foreground/background color pair
; 0000:07C0  dmvet_setColorDirect           18   Set color directly from parameter
; 0000:07D2  dmvet_lookupColor              31   Look up color in palette table
; 0000:07F1  dmvet_applyColorAndDraw        30   Apply color setting and call draw
; 0000:080F  dmvet_dispatchRenderOp         38   Dispatch render op (char/bitmap/rect)
; 0000:0835  dmvet_drawMultiItem            30   Draw multiple items from list
; 0000:0853  dmvet_setupDrawContext         123   Set up draw context from DM params
; 0000:08CD  dmvet_computeCharMetrics       89   Compute character cell metrics
; 0000:0986  dmvet_scaledMultiply           30   Scaled 32-bit multiply for positioning
; 0000:09A0  dmvet_computeScrollOffset     155   Compute scroll offset with bounds
; 0000:0A28  dmvet_drawFontGlyph           118   Draw a single font glyph (character)
; 0000:0A9F  dmvet_fullRedraw              666   Full screen redraw / repaint
; 0000:0D3D  dmvet_unloadResources          46   Unload resources, free memory
; 0000:0D6B  dmvet_computeWindowBounds     200   Compute window bounds for redraw
; 0000:0E31  dmvet_scaleCoordinates         60   Scale pixel coords to logical coords
; 0000:0E6E  sub_0000_0E6E                 118   Adjust resolution (query host metrics)
; 0000:0EE4  dmvet_setupVideoMode          125   Set up video mode, program TGA regs
; 0000:0F61  dmvet_teardownVideoMode        48   Tear down video mode, restore INT ABh
; 0000:0F91  dmvet_programTGARegisters      65   Program TGA graphics controller regs
; 0000:0FD2  dmvet_setTGAPalette            31   Set TGA palette (GC regs 0,1,8)
; 0000:0FF1  dmvet_calcScanlineOffset       32   Calc video memory offset from Y coord
; 0000:1011  dmvet_fastBlit                 80   Fast blit: copy bitmap with masking
; 0000:1061  dmvet_bresenhamSetup           34   Set up Bresenham line params
; 0000:1083  dmvet_mul32                    64   32x16 multiply yielding 32-bit result
; 0000:10B7  dmvet_mulAccum64               99   64-bit multiply-accumulate
;
; --- seg_0112: Epilogue Stub ---
;
; 0112:0000  (epilogue stub)                16   pop bp; ret + padding
;
; --- seg_0113: DM89 Header + Entry Point ---
;
; 0113:0000  dmvet_dm89Header              34   DM89 module header: "DMVET\0"
; 0113:0022  (data: "DMFONT" font name)    13   Font module name for INT ABh pairing
; 0113:0031  (data: INT ABh vector)         7   Saved INT ABh vector (for DMVST hookup)
; 0113:003E  (data: mode flag byte)         1   Mode flag: 'Y'=640-wide, 'X'=320-wide
; 0113:003F  (data: thunk code)            83   Far-call dispatch thunk
; 0113:0092  (data: thunk epilogue)        13   Thunk return stub
; 0113:009F  entry_point                   63   Module entry point (DM89 init)
; 0113:00E0  dmvet_apiDispatch            107   API dispatch: save regs, route call
; 0113:014B  (data: cleanup thunk)         13   Cleanup far-call thunk
; 0113:0158  dmvet_hookINTAB               51   Hook INT ABh for DMVST cooperation
;
; ========================================================================
; DETAILED DISASSEMBLY
; ========================================================================

; ========================================================================
; SEGMENT seg_0000  (4384 bytes) -- Video rendering code + data tables
; ========================================================================
seg_0000:

; --- Video segment selector ---
; The first word selects the video memory segment:
; 0x00A0 -> segment A000h (for TGA 640x200x4 planar mode)
  0000:0000  db 00 A0                                             ; g_videoSegment = 0xA000

; --- Internal dispatch mechanism ---
; Bytes 0002-0006: reserved/padding
  0000:0002  db 00 00 D1 E0 8B F0                                 ; shl ax,1; mov si,ax

; dmvet_dispatchViaTable: Load function offset from table, call via far return
; Entry: AX = function index
; The table at [0x001E] holds seg:off pairs; this loads the offset and
; does an intersegment call back to the host.
  0000:0007  db 53 BB 1E 00 2E 8B 18 07                           ; push bx; mov bx,0x1E; cs:mov bx,[bx]; pop es
  0000:000F  db FF D3 CB                                          ; call bx; retf

; dmvet_hostFarCall: Call into DESK.EXE host via es:[0x25]
; This is the standard DM89 far-call mechanism -- the host stores a
; far pointer at ES:[0x0025] that the driver calls for services.
  0000:0013  db 55 83 C5 04 26 FF 1E 25 00 5D C3                  ; push bp; add bp,4; lcall es:[0x25]; pop bp; ret

; --- Dispatch offset table ---
; 12 entries (word offsets into seg_0000) for video functions.
; See VIDEO DISPATCH TABLE in header for index mapping.
;                idx0  idx1  idx2  idx3  idx4  idx5  idx6  idx7
;                idx8  idx9  idxA  idxB  idxC
  0000:0020  db FD 07                                             ; [0] -> 0x07FD
  0000:0022  db BA 07                                             ; [1] -> 0x07BA
  0000:0024  db 56 08                                             ; [2] -> 0x0856
  0000:0026  db 50 02                                             ; [3] -> 0x0250
  0000:0028  db 65 02                                             ; [4] -> 0x0265
  0000:002A  db 7A 02                                             ; [5] -> 0x027A
  0000:002C  db 94 02                                             ; [6] -> 0x0294
  0000:002E  db 33 05                                             ; [7] -> 0x0533 (initDriverContext)
  0000:0030  db 31 0E                                             ; [8] -> 0x0E31 (scaleCoordinates)
  0000:0032  db 6E 0E                                             ; [9] -> 0x0E6E (adjustResolution)
  0000:0034  db E4 0E                                             ; [A] -> 0x0EE4 (setupVideoMode)
  0000:0036  db 61 0F                                             ; [B] -> 0x0F61 (teardownVideoMode)
  0000:0038  db A2 07                                             ; [C] -> 0x07A2 (setColors)
  0000:003A  db 90                                                ; padding (NOP)

; ========================================================================
; dmvet_drawBitmapRow (0000:0039)
; Draw a bitmap row with clipping to the current window.
; Saves all registers, performs clipping, then blits pixels.
; This is the core pixel-row rendering function used by character
; and bitmap drawing routines.
; ========================================================================
  0000:0039  db 50 53 51 52 56 57                               ; push ax,bx,cx,dx,si,di (PSQRVW)
  0000:003F  db 89 46 00 89 5E 02 89 4E 04 89 56 06 E8 46 01 73 ; store params; call clipRect; jnc ok
  0000:004F  db 03 E9 80 00 89 46 08 89 56 0E 80 7E 1C FF 74 11 ; clipped out -> skip
  0000:005F  db C6 46 1C AA 53 2B 5E 02 F6 C3 01 5B 74 03 D0 4E ; set mask=0xAA; check alignment
  0000:006F  db 1C 8B D0 83 E2 07 03 D1 4A D1 FA D1 FA D1 FA 42 ; compute byte offset from pixel X
  0000:007F  db 89 56 16 03 C8 F6 D9 80 E1 07 B6 FF D2 E6 8A D6 ; build right-edge mask
  0000:008F  db 89 56 12 E8 5A 0F 89 7E 18 8B 56 00 2B C2 89 46 ; call calcScanlineOffset
  0000:009F  db 1A B1 03 D3 F8 03 F0 8B 46 04 48 D3 F8 40 89 46 ; convert to byte count
  0000:00AF  db 14 2B 5E 02 74 04 F7 E3 03 F0 8B 5E 16 8A 6E 12 ; multiply by pitch; adjust SI
  0000:00BF  db 8A 4E 00 80 E1 07 83 66 1A 07 75 05 E8 0C 00 EB ; extract bit offset within byte
  0000:00CF  db 03 E8 2B 00                                      ; call aligned or unaligned blit
  0000:00D3  db 5F 5E 5A 59 5B 58                               ; pop di,si,dx,cx,bx,ax (_^ZY[X)
  0000:00D9  db C3                                               ; ret

; ========================================================================
; dmvet_drawBitmapAligned (0000:00D9)
; Draw a bitmap when source is byte-aligned (no bit shifting needed).
; Handles the "aligned" fast-path for character rendering.
; ========================================================================
  0000:00D9  db 53 52 8A 86 23 04 E8 F0 0E B7 00 FF 4E 0E 7C    ; push bx,dx; load color; call setTGAPalette
  0000:00E8  db 0E E8 22 0F D0 4E 1C 03 76 14 83 C7 50 EB ED E8 ; dec row count; advance scanline
  0000:00F8  db 97 0E 5A 5B C3                                   ; call palette restore; pop; ret

; ========================================================================
; dmvet_drawBitmapUnaligned (0000:00FD)
; Draw a bitmap when source is NOT byte-aligned (requires bit shifting).
; Uses EGA/TGA bit mask register to handle sub-byte positioning.
; ========================================================================
  0000:00FD  db 53 52 8A 86 23 04 E8 CC 0E 51 8A                 ; push; load color; call; push cx
  0000:0108  db 46 08 24 07 2A C1 3C 00 7D 02 04 08 8A C8 B4 FF ; compute shift amount
  0000:0118  db D2 EC 59 88 66 1A 8A 46 08 24 07 3A C8 7E 01 46 ; shift mask; compare
  0000:0128  db FF 4E 0E 7C 32 32 FF 0A C9 74 11 3A C8 7E 0D 8A ; dec row; loop control
  0000:0138  db 7C FF 22 7E 1A 50 E8 CD 0E 58 EB 10 50 FF 34 8A ; mask & write pixel
  0000:0148  db 04 22 46 1A 88 04 E8 BD 0E 8F 04 58 D0 4E 1C 03 ; AND with bit mask; advance
  0000:0158  db 76 14 83 C7 50 EB C9 E8 2F 0E 5A 5B C3           ; next scanline; loop; ret

; ========================================================================
; dmvet_clipToWindow (0000:0166)
; Clip AX,BX,CX,DX coordinates to current window boundaries.
; Calls dmvet_clipRect and adjusts the rectangle.
; Entry: AX=left, BX=top, CX=right, DX=bottom (in screen coords)
; ========================================================================
  0000:0166  db 50 53 51 52                                      ; push ax,bx,cx,dx (PSQR)
  0000:016A  db 8B C7 E8 6E 01 50 8B C3 E8 7D 01 8B D8 8B C1 E8 ; transform each coord
  0000:017A  db 61 01 8B C8 8B C2 E8 6F 01 8B D0 58 2B C8 41 2B ; via scaleCoordinates
  0000:018A  db D3 43 E8 05 00                                   ; call clipRect
  0000:018F  db 5A 59 5B 58                                      ; pop dx,cx,bx,ax (ZY[X)
  0000:0193  db C3                                               ; ret

; ========================================================================
; dmvet_clipRect (0000:0193)
; Clip a rectangle (AX,BX,CX,DX) against the screen window.
; The window bounds are stored in the DM driver context at ES:[0x68..0x6E].
; Returns: CF=1 if completely clipped (invisible), CF=0 if visible.
;   AX,BX = clipped top-left; CX,DX = clipped width,height
; ========================================================================
  0000:0193  db 0B C9 7E 5C 0B D2                               ; or cx,cx; jle .skip; or dx,dx
  0000:0199  db 7E 58 56 57                                      ; jle .skip; push si,di (~XVW)
  0000:019D  db 1E BE 00 00 8E DE                                ; push ds; mov si,0; mov ds,si
  0000:01A3  db 8E 1E 86 03                                      ; mov ds,[0x0386] -- load DM host segment
  0000:01A7  db 03 C8 70 4A                                      ; add cx,ax; jo .clipped
  0000:01AB  db 03 D3 70 4B                                      ; add dx,bx; jo .clipped
  0000:01AF  db 8B 36 68 00 8B 3E 6A 00                          ; mov si,[0x68]; mov di,[0x6A] -- window left, top
  0000:01B7  db 3B CE 7E 35                                      ; cmp cx,si; jle .clipped
  0000:01BB  db 3B D7 7E 31                                      ; cmp dx,di; jle .clipped
  0000:01BF  db 3B C6 7D 02 8B C6                                ; cmp ax,si; jge .ok1; mov ax,si (clamp left)
  0000:01C5  db 3B DF 7D 02 8B DF                                ; cmp bx,di; jge .ok2; mov bx,di (clamp top)
  0000:01CB  db 03 36 6C 00                                      ; add si,[0x6C] -- window right
  0000:01CF  db 03 3E 6E 00                                      ; add di,[0x6E] -- window bottom
  0000:01D3  db 3B C6 7D 19                                      ; cmp ax,si; jge .clipped
  0000:01D7  db 3B DF 7D 15                                      ; cmp bx,di; jge .clipped
  0000:01DB  db 3B CE 7C 02 8B CE                                ; cmp cx,si; jl .ok3; mov cx,si (clamp right)
  0000:01E1  db 3B D7 7C 02 8B D7                                ; cmp dx,di; jl .ok4; mov dx,di (clamp bottom)
  0000:01E7  db 2B C8 2B D3                                      ; sub cx,ax; sub dx,bx (compute width, height)
  0000:01EB  db 1F 5F 5E F8 C3                                   ; pop ds,di,si; clc; ret (visible)
  0000:01F0  db 1F 5F 5E F9 C3                                   ; pop ds,di,si; stc; ret (clipped out)
  0000:01F5  db B9 FF 7F EB B1                                   ; mov cx,0x7FFF; jmp (overflow path)
  0000:01FA  db BA FF 7F EB B0                                   ; mov dx,0x7FFF; jmp (overflow path)

; ========================================================================
; dmvet_transformCoords (0000:0200)
; Transform logical coordinates to screen coordinates.
; Applies origin offset and scale factors from the driver context.
; Saves all registers. Called during line/rectangle drawing.
; ========================================================================
  0000:0200  db 50 53 51 52 56 57                               ; push all (PSQRVW)
  0000:0206  db 1E 06 E8 2B 00                                  ; push ds,es; call getScreenMetrics
  0000:020B  db 8B 75 0C 8E 5D 0E                                ; load context seg/off
  0000:0211  db 2E 8E 06 00 00                                   ; mov es, cs:[0x0000] -- video segment
  0000:0216  db 3B 5E 36 7D 03 89 5E 36                          ; clamp to max X
  0000:021E  db 03 DA                                            ; add bx,dx
  0000:0220  db 3B 5E 38 7E 03 89 5E 38                          ; clamp to max Y
  0000:0228  db 2B DA E8 0C FE                                   ; sub bx,dx; call clipRect
  0000:022D  db 07 1F                                            ; pop es,ds
  0000:022F  db 5F 5E 5A 59 5B 58                               ; pop all (_^ZY[X)
  0000:0235  db C3                                               ; ret

; dmvet_getScreenMetrics: Calculate screen offset parameters
  0000:0236  db 8B 55 04 8B 4D 02 8B 45 0A 8B D8 03 5E 22 2B    ; load metrics from context
  0000:0245  db 9E 81 00 8B                                      ; subtract origin
  0000:0249  db 46 20 2B 45 08 C3 90                             ; compute offset; ret; nop

; ========================================================================
; Host API Thunks (0000:0250 - 0000:0470)
; Each thunk pushes parameters and far-calls into DESK.EXE host via
; the IVT vector at cs:[return_addr]. The pattern is:
;   push es; push cs; push word cs:[saved_vector]; push es
;   mov ax, 0x003F; push ax; mov ax, function_code; retf
; Then on return: pop es; ret
; ========================================================================

; dmvet_apiThunk_3Fh_6Ah: Far-call host function 0x6A (with SI param)
  0000:0250  db 06 0E 2E FF 36 61 02 50 06 B8 3F 00 50 B8 11 00 ; push; far-call via host
  0000:0260  db CB 63 02 07 C3                                   ; retf; pop es; ret

; dmvet_apiThunk_3Fh_69h: Far-call host function 0x69 (with SI, DI params)
  0000:0265  db 06 0E 2E FF 36 76 02 50                          ; push; far-call
  0000:026D  db 06 B8 3F 00 50 B8 10 00 CB 78 02 07 C3          ; retf; pop; ret

; dmvet_apiThunk_3Fh_6Ah_v2: Far-call host function 0x6A (SI param variant)
  0000:027A  db 56 8B 76 00 06 0E 2E FF 36 8F 02 50 06 B8 3F 00 ; push si; load param
  0000:028A  db 50 B8 6A 00 CB 91 02 07 5E C3                   ; far-call 0x6A; pop; ret

; dmvet_apiThunk_3Fh_69h_v2: Far-call host function 0x69 (SI, DI params)
  0000:0294  db 56 57 8B 7E 00 8B 76 02 06                      ; push si,di; load params
  0000:029D  db 0E 2E FF 36 AD 02 50 06 B8 3F 00 50 B8 69 00 CB ; far-call 0x69
  0000:02AD  db AF 02 07 5F 5E C3                                ; pop; ret

; dmvet_apiThunk_3Fh_64h: Far-call host function 0x64
  0000:02B3  db 06 0E 2E FF 36 C4 02 50 06 B8 3F 00 50 B8 64 00 ; far-call 0x64
  0000:02C3  db CB C6 02 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_63h: Far-call host function 0x63
  0000:02C8  db 06 0E 2E FF 36 D9 02 50 06 B8 3F 00 50 B8 63 00 ; far-call 0x63
  0000:02D8  db CB DB 02 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_59h: Far-call host function 0x59
  0000:02DD  db 06 0E 2E FF 36 EE 02 50 06 B8 3F 00 50 B8 59 00 ; far-call 0x59
  0000:02ED  db CB F0 02 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_5Bh: Far-call host function 0x5B
  0000:02F2  db 06 0E 2E FF 36 03 03 50 06 B8 3F 00 50 B8 5B 00 ; far-call 0x5B
  0000:0302  db CB 05 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_12h: Far-call host function 0x12
  0000:0307  db 06 0E 2E FF 36 18 03 50 06 B8 3F 00 50 B8 12 00 ; far-call 0x12
  0000:0317  db CB 1A 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_13h: Far-call host function 0x13
  0000:031C  db 06 0E 2E FF 36 2D 03 50 06 B8 3F 00 50 B8 13 00 ; far-call 0x13
  0000:032C  db CB 2F 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_65h: Far-call host function 0x65
  0000:0331  db 06 0E 2E FF 36 42 03 50 06 B8 3F 00 50 B8 65 00 ; far-call 0x65
  0000:0341  db CB 44 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_66h: Far-call host function 0x66
  0000:0346  db 06 0E 2E FF 36 57 03 50 06 B8 3F 00 50 B8 66 00 ; far-call 0x66
  0000:0356  db CB 59 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_6Bh: Far-call host function 0x6B
  0000:035B  db 06 0E 2E FF 36 6C 03 50 06 B8 3F 00 50 B8 6B 00 ; far-call 0x6B
  0000:036B  db CB 6E 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_27h: Far-call host function 0x27
  0000:0370  db 06 0E 2E FF 36 81 03 50 06 B8 3F 00 50 B8 27 00 ; far-call 0x27
  0000:0380  db CB 83 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_4Ch: Far-call host function 0x4C
  0000:0385  db 06 0E 2E FF 36 96 03 50 06 B8 3F 00 50 B8 4C 00 ; far-call 0x4C
  0000:0395  db CB 98 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_53h: Far-call host function 0x53
  0000:039A  db 06 0E 2E FF 36 AB 03 50 06 B8 3F 00 50 B8 53 00 ; far-call 0x53
  0000:03AA  db CB AD 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_38h: Far-call host function 0x38
  0000:03AF  db 06 0E 2E FF 36 C0 03 50 06 B8 3F 00 50 B8 38 00 ; far-call 0x38
  0000:03BF  db CB C2 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_3Eh: Far-call host function 0x3E
  0000:03C4  db 06 0E 2E FF 36 D5 03 50 06 B8 3F 00 50 B8 3E 00 ; far-call 0x3E
  0000:03D4  db CB D7 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_6Dh: Far-call host function 0x6D
  0000:03D9  db 06 0E 2E FF 36 EA 03 50 06 B8 3F 00 50 B8 6D 00 ; far-call 0x6D
  0000:03E9  db CB EC 03 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_51h: Far-call host function 0x51
  0000:03EE  db 06 0E 2E FF 36 FF 03 50 06 B8 3F 00 50 B8 51 00 ; far-call 0x51
  0000:03FE  db CB 01 04 07 C3                                   ; retf; pop; ret

; dmvet_apiThunk_3Fh_4Eh: Far-call host function 0x4E
  0000:0403  db 06 0E 2E FF 36 14 04 50 06 B8 3F 00 50 B8 4E 00 ; far-call 0x4E
  0000:0413  db CB 16 04 07 C3                                   ; retf; pop; ret

; ========================================================================
; dmvet_bresenhamHelper (0000:0418)
; Helper for Bresenham line drawing algorithm.
; Adjusts slope accumulator based on octant. Used by line routines.
; ========================================================================
  0000:0418  db 53 83 C3 5A E8 02 00 5B C3                      ; push bx; add bx,0x5A; call; pop; ret
  0000:0421  db 83 FB 5A 74 57 0B C0                             ; cmp bx,0x5A; je .end; or ax,ax

; ========================================================================
; Trigonometric / Bresenham Lookup Table (0000:0428 - 0000:0532)
; Used for line drawing with Bresenham's algorithm. Contains sine/cosine
; approximation data for 8 octant directions.
; ========================================================================
  0000:0428  db 74 53 53 51 52 57                               ; "tSSQRW" -- code fragment at table entry
  0000:042E  db 99 8B FA 33 C2 2B C2 93 99 B9 68 01 F7 F9 8B C2 ; Bresenham slope computation
  0000:043E  db 0B C0 7D 03 05 68 01 3D B4 00 76 02 F7 D7 3D B4 ; octant normalization
  0000:044E  db 00 76 03 2D B4 00 3D 5A 00 72 07 74 16 F7 D8 05 ; angle clamping
  0000:045E  db B4 00 93 D1 E3 2E 8B 9F 7E 04 F7 E3 D1 C0 83 D2 ; table lookup + multiply
  0000:046E  db 00 8B DA 8B C3 33 DF 2B DF 8B C3                ; result in AX:DX
  0000:0479  db 5F 5A 59 5B                                      ; pop di,dx,cx,bx (_ZY[)
  0000:047D  db C3                                               ; ret

; --- Sine/cosine lookup table data ---
; 90 entries (180 bytes), representing scaled sin/cos values for angles 0-89
; Used for rotation and line drawing with sub-pixel accuracy
  0000:047E  db 00 00 77 04 EF 08 65 0D DB 11 4F 16 C2 1A 32    ; sin values 0-7
  0000:048D  db 1F A0 23 0C 28 74 2C D8 30 39 35 96 39 EE 3D 41 ; sin values 8-15
  0000:049D  db 42 90 46 D8 4A 1B 4F 58 53 8E 57 BE 5B E6 5F 06 ; sin values 16-23
  0000:04AD  db 64 1F                                            ; sin values 24-25

; --- Additional trig/scaling data ---
  0000:04AF  db 68 30 6C 39 70 38 74 2F 78                      ; "h0l9p8t/x" -- interleaved data
  0000:04B8  db 1C 7C 00 80 D9 83 A8 87 6D 8B 27 8F D5 92 79 96 ; cosine lookup table
  0000:04C8  db 10 9A 9B 9D 1B A1 8D A4 F3 A7 4C AB 97 AE D5 B1 ; (continues)
  0000:04D8  db 04 B5 26 B8 39 BB 3E BE 34 C1 1B C4 F3 C6 BB C9 ;
  0000:04E8  db 73 CC 1B CF B3 D1 3B D4 B3 D6 19 D9 6F DB B3 DD ;
  0000:04F8  db E7 DF 08 E2 19 E4 17 E6 03 E8 DE E9 A6 EB 5B ED ;
  0000:0508  db FF EE 8F F0 0D F2 78 F3 D0 F4 15 F6 46 F7 65 F8 ;
  0000:0518  db 70 F9 67 FA 4B FB 1C FC D9 FC 82 FD 17 FE 98 FE ;
  0000:0528  db 06 FF 60 FF A6 FF D8 FF F6 FF 90                ;

; ========================================================================
; dmvet_initDriverContext (0000:0533)
; Initialize the video driver context from parameters passed by the host.
; Parses the font/character init structure and sets up glyph rendering.
;
; Entry: DS:SI -> parameter block from host
;   Byte [SI+1] = mode flag ('f'=0x66 for standard, 'F'=0x46 for enhanced)
;   Byte [SI+0] = command code (0x55='U' for init)
; ========================================================================
  0000:0533  db 53 51 52 56 57                                  ; push bx,cx,dx,si,di (SQRVW)
  0000:0538  db 1E 33 C0 C5 76 00                               ; push ds; xor ax,ax; lds si,[bp]
  0000:053E  db 8A 6C 01 8A 0C                                  ; mov ch,[si+1]; mov cl,[si] -- mode, command
  0000:0543  db 80 F9 55 75 2E                                  ; cmp cl,0x55; jne .notInit -- 'U'=init
  0000:0548  db 80 FD 66 74 05 80 FD 46 75 1F                   ; cmp ch,'f'; je .initStd; cmp ch,'F'; jne .skip
  0000:0552  db E8 28 00                                        ; call dmvet_parseInitParams
  0000:0555  db 89 7C 02 89 5C 06 89 4C 0A 89 54 0E            ; store results to context
  0000:0561  db 33 DB 89 5C 04 89 5C 08 89 5C 0C 89 5C 10      ; zero out secondary fields
  0000:056F  db EB 05                                           ; jmp .done
  0000:0571  db E8 3F FD                                        ; call dmvet_clipRect (error path)
  0000:0574  db 33 C0 1F                                        ; xor ax,ax; pop ds
  0000:0577  db 5F 5E 5A 59 5B                                  ; pop di,si,dx,cx,bx (_^ZY[)
  0000:057C  db C3                                               ; ret

; ========================================================================
; dmvet_renderCharacter (0000:057D)
; Render a character glyph to the screen.
; This is a complex function that handles:
;   - Font glyph lookup from the character code
;   - Proportional vs. fixed-width rendering
;   - Character cell positioning and clipping
;   - Glyph bitmap transfer to video memory via TGA registers
;
; Uses local stack frame of 70 bytes for intermediate calculations.
; Entry: Character data in driver context; ES = video memory segment
; ========================================================================
  0000:057D  db 56 55 83 EC 46 8B EC                            ; push si,bp; sub sp,0x46; mov bp,sp
  0000:0584  db 8B 44 36 89 46 3C                               ; load font metrics from context
  0000:058A  db 8B 44 38 8B 7C 3A 8B 5C 3C                     ; load glyph dimensions
  0000:0593  db 8B 4C 5C 8B 54 5E                               ; load cursor pos
  0000:0599  db 80 7C 01 66 74 1E                               ; cmp byte [si+1],'f'; je .standard
  0000:059F  db 06 C4 7C 14                                     ; push es; les di,[si+0x14]
  0000:05A3  db 26 8B 45 22 89 46 3C                            ; load from enhanced struct
  0000:05AA  db 26 8B 45 24 26 8B 5D 28 26 8B 7D 26            ; load glyph data pointers
  0000:05B6  db 8B 4C 20 8B 54 22                               ; load width/height
  0000:05BC  db 07                                              ; pop es
  0000:05BD  db 89 46 36 89 5E 3A 89 7E 38                      ; store cell metrics
  0000:05C6  db 89 4E 32 89 56 34                               ; store position
  0000:05CC  db 89 4E 2A 89 56 2C                               ;

; (Character rendering continues with glyph bitmap processing)
  0000:05D0  db 56 2C 41 42                                     ; (internal computation data)
  0000:05D4  db 89 4E 2E 89 56 30                               ; store more cell data
  0000:05DA  db 80 7C 01 66 74 11                               ; cmp byte [si+1],'f'; je .useStdPtrs
  0000:05E0  db 8B 7C 14 8B 54 16 8B 5C 26 8B 44 28 8B 4C 24   ; load enhanced font pointers
  0000:05EF  db EB 0D                                           ; jmp .continue
  0000:05F1  db 8D 7C 14 1E 5A 8D 5C 64 1E 58 8B 4C 60         ; load standard font pointers
  0000:05FE  db 0B C9 75 06                                     ; or cx,cx; jnz .hasGlyph
  0000:0602  db B8 FF FF E9 CB 00                               ; mov ax,0xFFFF; jmp .noGlyph (return -1)
  0000:0608  db 89 7E 12 89 56 14 89 7E 00 89 56 02            ; store font bitmap ptrs
  0000:0614  db 89 5E 0C 89 46 0E                               ; store glyph width info
  0000:061A  db 51                                              ; push cx
  0000:061B  db C7 46 10 01 00                                  ; mov word [bp+0x10],1
  0000:0620  db C7 46 40 00 00 C7 46 44 00 00                   ; init accumulators
  0000:062A  db C7 46 42 00 00 C7 46 3E FF FF                   ; init max/min trackers
  0000:0634  db 8D 7E 1A 89 7E 16                               ; lea di,[bp+0x1A]; store ptr
  0000:063A  db 16 8F 46 18                                     ; push ss; pop [bp+0x18]
  0000:063E  db 8D 7E 08 89 7E 04                               ;
  0000:0644  db 16 8F 46 06                                     ;

; --- Character cell rendering loop ---
; Iterates through the glyph bitmap rows, calling host function 0x09
; for each character cell.
  0000:0648  db 49 7C 50 56                                     ; dec cx; jl .done; push si (I|PV)
  0000:064C  db 1E C5 76 0C AC FF 46 0C 1F 5E                   ; push ds; lds si,[bp+0x0C]; lodsb; pop si
  0000:0656  db 32 E4 89 46 1E                                  ; xor ah,ah; mov [bp+0x1E],ax -- char code
  0000:065B  db 83 C5 12                                        ; add bp,0x12
  0000:065E  db B8 09 00                                        ; mov ax,9 -- host function 0x09 (get glyph)
  0000:0661  db 26 FF 1E 25 00                                  ; lcall es:[0x25]
  0000:0666  db 83 ED 12                                        ; sub bp,0x12
  0000:0669  db 3D FF FF 74 38                                  ; cmp ax,0xFFFF; je .noGlyph
  0000:066E  db 83 7E 3E FF 75 06                               ; cmp word [bp+0x3E],-1; jne .notFirst
  0000:0674  db 8B 46 24 89 46 3E                               ; first glyph: save bearing
  0000:067A  db 8B 46 20 01 46 44                               ; add cell advance to total width
  0000:0680  db 8B 46 26 2B 46 28 3B 46 40 7E 03 89 46 40      ; track max ascent
  0000:068E  db 8B 46 28 3B 46 42 7E B2 89 46 42               ; track max descent
  0000:0699  db EB AD                                           ; loop back

; --- Post-glyph-loop processing ---
  0000:069B  db 8F 46 10                                        ; pop [bp+0x10]
  0000:069E  db E8 80 00                                        ; call computeWindowBounds
  0000:06A1  db 73 09                                           ; jnc .visible
  0000:06A3  db FF 76 10 8F 46 10                               ; restore counter
  0000:06A9  db E8 39 00                                        ; call sub
  0000:06AC  db 8B 46 40 8B 5E 42                               ; load accumulated metrics
  0000:06B2  db 03 C3                                           ; add ax,bx
  0000:06B4  db 8B 4E 44                                        ; load total width
  0000:06B7  db 80 7C 01 66 74 0B                               ; cmp byte [si+1],'f'; je .std
  0000:06BD  db 89 44 18 89 5C 1A 89 4C 1C                      ; store to enhanced context
  0000:06C6  db EB 09                                           ; jmp .done
  0000:06C8  db 89 44 54 89 5C 56 89 4C 58                      ; store to standard context
  0000:06D1  db 33 C0                                           ; xor ax,ax (success)
  0000:06D3  db 8B 7E 2A 8B 5E 2C 8B 4E 2E 8B 56 30           ; restore cursor position
  0000:06DF  db 83 C4 46 5D 5E C3                               ; cleanup stack; pop bp,si; ret

; ========================================================================
; (Continuation: character rendering helpers 0000:06E5 - 0000:08CB)
; These handle font metrics computation, line advancement, and the
; actual glyph-to-screen bitmap transfer.
; ========================================================================
  0000:06E5  db 8B 46 36 8B 5E 38 E8 29 07 F7 66 10 89 46 44 8B ; compute char advance
  0000:06F5  db F8 8B 4E 32 89 4E 2A 03 CF 89 4E 2E 53 8B C3 D1 ; update cursor X
  0000:0705  db E8 D1 E8 D1 E8 89 46 40 8B 4E 34 03 C8 89 4E 30 ; compute Y advance
  0000:0715  db 2B D8 89                                        ;
  0000:0718  db 5E 42 5B 2B CB 89 4E 2C C3                      ; store; ret

; dmvet_adjustGlyphBounds: Adjust glyph bounding box for kerning
  0000:0721  db 8B 46 22 2B 46 24 2B 46 20 7E 03 01 46 44      ; compute bearing adjustment
  0000:072F  db 8B 46 44 8B 5E 3A 8B 4E 32                      ; load accumulated values
  0000:0738  db E8 DD FC 03 C1 3B C1 7D 01 91                   ; call clipRect variant; clamp
  0000:0742  db 89 4E 2A 89 46 2E                               ; store clipped X
  0000:0748  db 8B 46 44 8B 56 34                               ; load Y metrics
  0000:074E  db E8 D0 FC 03 C2 3B C2 7D 01 92                   ; clip Y
  0000:0758  db 89 56 2C 89 46 30                               ; store clipped Y
  0000:075E  db 8B 46 40 0B C0 74 0F                            ; check max ascent
  0000:0765  db E8 B9 FC 29 46 2A                               ; adjust origin
  0000:076B  db 8B 46 40 E8 A7 FC 01 46 30                      ; adjust Y
  0000:0774  db 8B 46 42 E8 A7 FC 01 46 2E                      ; adjust for descent
  0000:077D  db 0B C0 79 09                                     ; test; jns .ok
  0000:0781  db 8B 46 2E 87 46 2A 89 46 2E                      ; swap if negative extent
  0000:078A  db 8B 46 42 E8 88 FC 29 46 2C                      ; adjust bottom
  0000:0793  db 0B C0 79 09                                     ;
  0000:0797  db 8B 46 30 87 46 2C 89 46 30                      ; swap if needed
  0000:07A0  db F8 C3                                           ; clc; ret (success)

; ========================================================================
; dmvet_setColorPair (0000:07A2)
; Set foreground and background colors from the driver context.
; Reads color values from context and calls the host via es:[0x25].
; ========================================================================
  0000:07A2  db 50 57 1E C5 7E 00                               ; push ax,di; push ds; lds di,[bp]
  0000:07A8  db 8B 46 04 E8 29 00                               ; load color; call lookupColor
  0000:07AE  db 3D FF FF 74 03                                  ; cmp ax,-1; je .noColor
  0000:07B3  db E8 14 00                                        ; call setColorDirect
  0000:07B6  db 1F 5F 58 C3                                     ; pop ds,di,ax; ret

; ========================================================================
; dmvet_setColorDirect (0000:07C0)
; Set color directly: call the host to apply the given palette entry.
; ========================================================================
  0000:07BA  db 50 57 1E C5 7E 00                               ; push ax,di; push ds; lds di,[bp]
  0000:07C0  db 8B 46 04 E8 04 00                               ; load color; call lookupColor
  0000:07C6  db 1F 5F 58 C3                                     ; pop ds,di,ax; ret

; ========================================================================
; dmvet_lookupColor (0000:07CA)
; Look up a color index in the palette table.
; Entry: AX = color value to look up
; Returns: AX = mapped color index, or -1 if not found
; ========================================================================
  0000:07CA  db 56 8B F0 D1 E6 03 75 0E                         ; push si; mov si,ax; shl si,1; add si,[di+0xE]
  0000:07D2  db E8 45 00 5E C3                                  ; call sub; pop si; ret

  0000:07D7  db 53 51                                           ; push bx,cx
  0000:07D9  db 8B 5D 0E 8B 1F 8B CB D1 E3 4B D1 E3 03 5D 0E  ; search palette table
  0000:07E8  db 3B 47 02 74 0B                                  ; cmp with target
  0000:07ED  db 83 EB 04 49 75 F5                               ; loop through entries
  0000:07F3  db B8 00 00 EB 02                                  ; not found: return 0
  0000:07F8  db 8B 07                                           ; found: load entry
  0000:07FA  db 59 5B C3                                        ; pop cx,bx; ret

; ========================================================================
; dmvet_applyColorAndDraw (0000:07FD)
; Apply a color setting and trigger a draw operation.
; ========================================================================
  0000:07FD  db 50 56 57 E8 E1 06                               ; push ax,si,di; call setupVideoMode
  0000:0803  db 0B C0 74 09                                     ; or ax,ax; jz .skip
  0000:0807  db 8B 76 00 8B 7E 02 8B 46 04                      ; load params
  0000:0810  db E8 07 00                                        ; call renderOp
  0000:0813  db E8 4B 07 5F 5E 58 C3                            ; call finalize; pop; ret

; ========================================================================
; dmvet_dispatchRenderOp (0000:081B)
; Dispatch a rendering operation based on the command code in context.
; Handles: 'O' (0x4F) = outline/rect, 'U' (0x55) + 'f'/'F' = glyph
; ========================================================================
  0000:081B  db 51 8A 6C 01 8A 0C                               ; push cx; load mode, command
  0000:0821  db 80 F9 4F 75 05                                  ; cmp cl,'O'; jne .notOutline
  0000:0826  db E8 18 00 EB 14                                  ; call drawOutline; jmp .done
  0000:082B  db 80 F9 55 75 0A                                  ; cmp cl,'U'; jne .notGlyph
  0000:0830  db 80 FD 66 75 05                                  ; cmp ch,'f'; jne .enhanced
  0000:0835  db E8 F1 01 EB 05                                  ; call drawStdGlyph; jmp .done
  0000:083A  db 50 E8 8B FA 58                                  ; push ax; call clipRect; pop ax
  0000:083F  db 59 C3                                           ; pop cx; ret

; ========================================================================
; dmvet_drawMultiItem (0000:0841)
; Draw multiple items from a linked list structure.
; Iterates through items at [SI+12], calling render for each.
; ========================================================================
  0000:0841  db 50 51 56 83 C6 12                               ; push ax,cx,si; add si,18
  0000:0847  db 8B 0C 83 C6 02                                  ; load count; advance ptr
  0000:084C  db 8B 04 E8 7A FF                                  ; load item; call lookupColor
  0000:0851  db E2 F6                                           ; loop
  0000:0853  db 5E 59 58 C3                                     ; pop si,cx,ax; ret

; ========================================================================
; dmvet_setupDrawContext (0000:0857)
; Set up the drawing context from DM host parameters.
; Copies font data, palette info, and window metrics from the host
; data structure into the driver's local work area.
; ========================================================================
  0000:0857  db 56 1E C5 76 00 E8 03 00                         ; push si,ds; lds si,[bp]; call sub
  0000:085F  db 1F 5E C3                                        ; pop ds,si; ret
  0000:0862  db 51 55 1E                                        ; push cx,bp,ds
  0000:0865  db B9 2D 04                                        ; mov cx,0x042D -- context size
  0000:0868  db 8B 6C 10 03 CD                                  ; load and adjust stack ptr
  0000:086D  db 83 7C 18 00 74 04                               ; check for double-height flag
  0000:0873  db D1 E5 03 CD                                     ; if set, multiply pitch
  0000:0877  db 41 83 E1 FE                                     ; inc cx; word-align
  0000:087B  db 2B E1 8B EC 51                                  ; adjust stack; push count
  0000:0880  db 06 16 07 1E 56                                  ; set up seg regs; push si
  0000:0885  db 8D BE DD 03                                     ; lea di,[bp+0x3DD] -- dest
  0000:0889  db B9 40 00                                        ; mov cx,0x40 -- copy 64 words
  0000:088C  db C5 34 F3 A4                                     ; lds si,[si]; rep movsb -- copy font data
  0000:0890  db 5E 1F 83 C6 04                                  ; pop si; pop ds; add si,4
  0000:0895  db B9 0E 00 F3 A4                                  ; mov cx,14; rep movsb -- copy palette data
  0000:089A  db 33 C0 39 44 06 74 06                             ; check mode field
  0000:08A1  db 8B 86 29 04 D1 E0 AB                            ; copy scaled value
  0000:08A8  db 1E 56                                           ; push ds,si
  0000:08AA  db 8B 8E 29 04                                     ; load width param
  0000:08AE  db C5 34 F3 A4                                     ; lds si,[si]; rep movsb -- copy font bitmap
  0000:08B2  db 5E 1F 83 C6 04                                  ; pop si; pop ds; add si,4
  0000:08B7  db 1E 8B 8E 2B 04                                  ; push ds; load glyph count
  0000:08BC  db D1 E1                                           ; shl cx,1 -- word count
  0000:08BE  db C5 34 F3 A4                                     ; lds si,[si]; rep movsb -- copy glyph ptrs
  0000:08C2  db 1F 07                                           ; pop ds,es
  0000:08C4  db E8 D9 01                                        ; call dmvet_drawFontGlyph
  0000:08C7  db 59 03 E1                                        ; pop cx; add sp,cx -- deallocate
  0000:08CA  db 1F 5D 59 C3                                     ; pop ds,bp,cx; ret

; ========================================================================
; dmvet_computeCharMetrics (0000:08CD)
; Compute character cell metrics (advance width, ascent, descent)
; for scroll and cursor positioning calculations.
; Uses the font data loaded during setupDrawContext.
; ========================================================================
  0000:08CD  db 50 53 51 52 57 55                               ; push ax,bx,cx,dx,di,bp (PSQRWU)
  0000:08D3  db 83 EC 0A 8B EC                                  ; sub sp,0xA; mov bp,sp
  0000:08D8  db 8B 44 3C B1 B4 F6 F1 8A DC 32 FF               ; load cell height; compute rows
  0000:08E3  db 89 5E 08                                        ; store row count
  0000:08E6  db 8B 44 0A 2B 44 02                               ; load/compute X offset
  0000:08EC  db E8 32 FB                                        ; call clipRect variant
  0000:08EF  db 89 46 06                                        ; store
  0000:08F2  db 8B 44 0E 2B 44 06                               ; load/compute Y offset
  0000:08F8  db E8 1D FB                                        ; call
  0000:08FB  db 01 46 06                                        ; add to accumulator
  0000:08FE  db 8B 44 54 E8 1D FB                               ; load enhanced field
  0000:0904  db 89 46 04                                        ;
  0000:0907  db 8B 44 54 E8 0B FB 01 46 04                      ; another metric computation
  0000:0910  db 56                                              ; push si
  0000:0911  db 8B 46 06 F7 64 38                               ; compute scaled value
  0000:0917  db 8B CA 8B D0                                     ;
  0000:091B  db 33 DB 33 C0 8B 7E 04 33 F6                      ; zero accumulators
  0000:0924  db E8 3A 07                                        ; call 64-bit math routine
  0000:0927  db 0B C0 74 05                                     ; or ax,ax; jz .zero
  0000:092B  db BB 01 00 EB 13                                  ; mov bx,1; jmp .store
  0000:0930  db 83 FB 00 7F 05                                  ; cmp bx,0; jg .positive
  0000:0935  db BB 01 00 EB 09                                  ; clamp to 1
  0000:093A  db 81 FB E7 03 7E 03                               ; cmp bx,0x3E7; jle .ok
  0000:0940  db BB E7 03                                        ; clamp to 999
  0000:0943  db 5E 89 5C 38                                     ; pop si; store cell advance
  0000:0947  db 8B 5E 08                                        ; load row count
; ... (continues with Y metric computation, mirror of X)
  0000:094A  db 8B 44 0A 2B 44 02                               ;
  0000:0950  db E8 C5 FA 89 46 02                               ;
  0000:0956  db 8B 44 0E 2B 44 06 E8 C2 FA                      ;
  0000:095F  db 01 46 02                                        ;
  0000:0962  db 8B 44 58 E8 B0 FA 89 46 00                      ;
  0000:096B  db 8B 44 58 E8 B0 FA 01 46 00                      ;
  0000:0974  db 8B 46 02 F7 66 04                               ;
  0000:097A  db 8B CA 8B D0 8B 44 3A 33 DB                      ;
  0000:0983  db E8 29 07                                        ;

; dmvet_scaledMultiply: Perform scaled 32x16 multiply
  0000:0986  db 56 50 53 51 52 33 C0                            ; push all; xor ax,ax
  0000:098D  db 8B 5E 06 33 C9 8B 56 00                         ;
  0000:0995  db E8 17 07                                        ; call 64-bit multiply
  0000:0998  db 8B F1 8B FA                                     ;
  0000:099C  db 5A 59 5B 58                                     ; pop all (ZY[X)
  0000:09A0  db E8 BE 06                                        ; call compare
  0000:09A3  db 3D 00 00 7F 05                                  ; cmp ax,0; jg .positive
  0000:09A8  db B8 01 00 EB 08                                  ; clamp to 1
  0000:09AD  db 3D 10 27 7E 03                                  ; cmp ax,10000; jle .ok
  0000:09B2  db B8 10 27                                        ; clamp to 10000
  0000:09B5  db 8B 7E 06 8B 4E 04 5E                            ; restore; pop si
  0000:09BC  db 89 44 3A                                        ; store result

; ========================================================================
; dmvet_computeScrollOffset (0000:09BF)
; Compute the scroll offset for the current window position.
; Handles both horizontal and vertical scroll with bounds checking.
; Adjusts character cell positions relative to the visible viewport.
; ========================================================================
  0000:09BF  db 8B 54 06 52                                     ; load scroll param; push
  0000:09C3  db 8B 54 02 8B 5C 3C 8B 44 56                      ; load viewport metrics
  0000:09CC  db E8 52 FA                                        ; call clipRect
  0000:09CF  db 0B C0 74 1E                                     ; or ax,ax; jz .noScroll
  0000:09D3  db 9C 79 02 F7 D8                                  ; pushf; test sign; negate if needed
  0000:09D8  db F7 E7 F7 F1                                     ; mul; div -- scale factor
  0000:09DC  db 8B 54 0A 9D                                     ; load; popf
  0000:09E0  db 79 0D F7 D8                                     ; jns .pos; negate
  0000:09E4  db 5A 8B 54 0E                                     ; pop dx; load alternate
  0000:09E8  db 89 54 5E 52 8B 54 02                            ; store; push; reload
  0000:09EF  db 2B D0 89 54 5C                                  ; adjust offset
  0000:09F4  db 5A                                              ; pop dx
  0000:09F5  db 8B 44 56 E8 1D FA                               ; load; call
  0000:09FB  db 0B C0 74 1C                                     ;
  0000:09FF  db 9C 79 02 F7 D8                                  ; (mirror of horizontal calc)
  0000:0A04  db F7 E7 F7 F1                                     ;
  0000:0A08  db 8B 54 06 9D                                     ;
  0000:0A0C  db 79 0B F7 D8                                     ;
  0000:0A10  db 8B 54 0A 89 54 5C                               ; store adjusted scroll
  0000:0A16  db 8B 54 0E 03 D0 89 54 5E                         ;
  0000:0A1E  db 83 C4 0A                                        ; add sp,0xA (deallocate locals)
  0000:0A21  db 5D 5F 5A 59 5B 58                               ; pop bp,di,dx,cx,bx,ax
  0000:0A27  db C3                                               ; ret

; ========================================================================
; dmvet_drawFontGlyph (0000:0A28)
; Draw a single font glyph into the current drawing context.
; Handles both standard and enhanced font formats.
; Manages the iteration over font bitmap rows and the transfer
; of each row to the TGA video buffer.
; ========================================================================
  0000:0A28  db 50 53 51 52 57 55                               ; push all (PSQRWU)
  0000:0A2E  db 1E B9 2D 04                                     ; push ds; mov cx,0x042D
  0000:0A32  db 83 E9 65 41                                     ; sub cx,0x65; inc cx -- adjusted size
  0000:0A36  db 8B 44 12 D1 E0 03 C8 41 83 E1 FE               ; compute stack frame size
  0000:0A41  db 2B E1 8B EC 51                                  ; sub sp,cx; mov bp,sp; push cx
  0000:0A46  db 26 80 3E 30 00 00 74 46                          ; cmp byte es:[0x30],0; je .skip
  0000:0A4E  db 8B 7C 02 8B 5C 06 8B 4C 0A 8B 54 0E            ; load glyph rect coords
  0000:0A5A  db E8 09 F7                                        ; call transformCoords
  0000:0A5D  db 72 35                                           ; jc .clipped
  0000:0A5F  db 8B 44 3C B1 5A F6 F1                            ; divide cell height by pitch
  0000:0A66  db 80 FC 00 75 03                                  ; cmp ah,0; jne .notZero
  0000:0A6B  db E8 5F FE                                        ; call computeCharMetrics
  0000:0A6E  db E8 0C FB                                        ; call sub
  0000:0A71  db 3D FF FF 74 1E                                  ; cmp ax,-1; je .fail
  0000:0A76  db 89 7C 02 89 5C 06 89 4C 0A 89 54 0E            ; store updated coords
  0000:0A82  db 56 06 16 07                                     ; push si; set up segs
  0000:0A86  db 8D BE C9 03                                     ; lea di,[bp+0x3C9]
  0000:0A8A  db 8B 4C 12                                        ; load font bitmap size
  0000:0A8D  db F3 A5                                           ; rep movsw -- copy font bitmap
  0000:0A8F  db 07 5E                                           ; pop es,si
  0000:0A91  db E8 0B 00                                        ; call finalize
  0000:0A94  db 59 03 E1 1F                                     ; pop cx; add sp,cx; pop ds
  0000:0A98  db 5D 5F 5A 59 5B 58                               ; pop all (]_ZY[X)
  0000:0A9E  db C3                                               ; ret

; ========================================================================
; dmvet_fullRedraw (0000:0A9F)
; Perform a full screen redraw / repaint of the DeskMate window.
; This is the main rendering entry point called by the host when the
; screen needs to be refreshed. It:
;   1. Checks if the display is active (es:[0x30] != 0)
;   2. Sets up the drawing flags and context pointers
;   3. Iterates through all visible objects calling host function 0x0A
;      (get next display object) and 0x0B (render object)
;   4. Handles memory allocation for off-screen buffers if needed
;   5. Computes final window metrics and stores them
; ========================================================================
  0000:0A9F  db 50 53 51 52 56 57                               ; push all (PSQRVW)
  0000:0AA5  db 1E E8 A7 F7                                     ; push ds; call transformCoords
  0000:0AA9  db 26 80 3E 30 00 00 75 03 E9 7E 02               ; if display inactive, skip
  0000:0AB4  db B0 FF                                           ; mov al,0xFF (default mask)
  0000:0AB6  db F7 86 FF 03 40 00 74 02 B0 AA                   ; check flag; set mask if needed
  0000:0AC0  db 88 46 1C                                        ; store mask
  0000:0AC3  db 8D 9E 2D 04 89 9E C7 03                         ; set up context pointers
  0000:0ACB  db 03 9E 29 04 89 9E C5 03                         ;
  0000:0AD3  db C7 46 1E 00 00                                  ; zero object counter
  0000:0AD8  db C7 46 36 FF 7F C7 46 38 00 80                   ; init min/max trackers
  0000:0AE2  db 8B 86 27 04 E8 09 F8                            ; load X origin; call transform
  0000:0AE9  db 89 46 2A 89 46 22                               ; store X bounds
  0000:0AEF  db 8B 86 25 04 89 46 24                            ; load Y origin
  0000:0AF5  db E8 E4 F7 89 46 20 89 46 28                      ; transform; store Y bounds
  0000:0AFD  db 16 58                                           ; push ss; pop ax
  0000:0AFF  db 8D B6 DD 03 89 76 52 89 46 54                   ; set up font bitmap pointers
  0000:0B09  db 89 76 60 89 46 62                               ;
  0000:0B0F  db 16 8F 46 66                                     ; store SS for segment
  0000:0B13  db 8D 76 68 89 76 64                               ; lea font table ptr
  0000:0B19  db 83 C5 60                                        ; add bp,0x60 -- advance to params area
  0000:0B1C  db B8 0A 00                                        ; mov ax,0x0A -- host fn: get next object
  0000:0B1F  db 26 FF 1E 25 00                                  ; lcall es:[0x25]
  0000:0B24  db 83 ED 60                                        ; sub bp,0x60
  0000:0B27  db 32 E4                                           ; xor ah,ah
  0000:0B29  db F7 86 FF 03 10 00 74 14                          ; test flag; jz .noAdjust
  0000:0B31  db 36 8A 44 02                                     ;
  0000:0B35  db 29 46 2A 29 46 22                               ; adjust X bounds
  0000:0B3B  db 8B 46 2A E8 D9 F7                               ; transform
  0000:0B41  db 89 86 27 04                                     ; store
  0000:0B45  db F7 86 FF 03 20 00 74 14                          ; test another flag
  0000:0B4D  db 36 8A 44 03                                     ;
  0000:0B51  db 01 46 2A 01 46 22                               ; adjust X
  0000:0B57  db 8B 46 2A E8 BD F7                               ; transform
  0000:0B5D  db 89 86 27 04                                     ; store

; --- Memory allocation for off-screen buffer ---
  0000:0B61  db BB 60 09                                        ; mov bx,0x0960 -- buffer size (38,400 bytes)
  0000:0B64  db B4 48                                           ; mov ah,0x48 -- DOS: Allocate Memory
  0000:0B66  db CD 21                                           ; int 0x21
  0000:0B68  db 73 0B                                           ; jnc .allocated
  0000:0B6A  db 83 FB 40 7E 1C                                  ; cmp bx,0x40; jle .tooSmall
  0000:0B6F  db B4 48 CD 21                                     ; retry with available
  0000:0B73  db 72 16                                           ; jc .fail
  0000:0B75  db D1 E3 D1 E3 D1 E3 D1 E3                        ; shl bx,4 (convert paras to bytes)
  0000:0B7D  db 89 9E 87 00                                     ; store buffer size
  0000:0B81  db C7 46 7D 00 00                                  ; clear buffer ptr low word
  0000:0B86  db 89 46 7F                                        ; store segment
  0000:0B89  db EB 11                                           ; jmp .continue
  0000:0B8B  db 8D 86 89 00                                     ; .tooSmall: use internal buffer
  0000:0B8F  db 89 46 7D                                        ; store ptr
  0000:0B92  db 16 8F 46 7F                                     ; store SS as segment
  0000:0B96  db C7 86 87 00 20 03                               ; set buffer size = 800

; --- Main rendering loop ---
  0000:0B9C  db FF 8E 29 04                                     ; dec object count
  0000:0BA0  db 7D 03 E9 66 01                                  ; jge .continue; jmp .done
  0000:0BA5  db 8B B6 C7 03 FF 86 C7 03                         ; load/advance object ptr
  0000:0BAD  db 36 8A 04 32 E4                                  ; load object type; zero-extend
  0000:0BB2  db 89 46 56                                        ; store type code
  0000:0BB5  db C7 86 83 00 00 00                               ; clear accumulator
  0000:0BBB  db 83 C5 52                                        ; add bp,0x52
  0000:0BBE  db B8 0B 00                                        ; mov ax,0x0B -- host fn: render object
  0000:0BC1  db 26 FF 1E 25 00                                  ; lcall es:[0x25]
  0000:0BC6  db 83 ED 52                                        ; sub bp,0x52
  0000:0BC9  db 1E 57                                           ; push ds,di
  0000:0BCB  db 89 46 5C 89 56 5E                               ; store result seg:off
  0000:0BD1  db 8E DA 8B F8                                     ; mov ds,dx; mov di,ax
  0000:0BD5  db 83 7D 0E 00                                     ; cmp word [di+0xE],0
  0000:0BD9  db 5F 1F                                           ; pop di,ds
  0000:0BDB  db 74 03 E9 E3 00                                  ; je .skip; jmp .nextSection

; --- Process object data ---
  0000:0BE0  db 1E 57                                           ; push ds,di
  0000:0BE2  db C5 7E 5C                                        ; lds di,[bp+0x5C]
  0000:0BE5  db 8B 5D 08 89 5E 79                               ; load dimensions
  0000:0BEB  db 8B 1D 89 5E 71                                  ; load stride
  0000:0BF1  db 8B 45 02 8B 5D 04                               ; load pos
  0000:0BF7  db 5F 1F                                           ; pop di,ds
  0000:0BF9  db 89 46 73 89 5E 75                               ; store position
  0000:0BFF  db 89 9E 81 00                                     ; store stride
  0000:0C03  db 50 53 52 93                                     ; push ax,bx,dx; xchg ax,bx
  0000:0C07  db 83 C3 07 D1 EB D1 EB D1 EB                      ; round up to byte boundary
  0000:0C10  db F7 E3                                           ; mul -- compute buffer size
  0000:0C12  db 72 06                                           ; jc .overflow
  0000:0C14  db 3B 86 87 00 76 0B                               ; cmp with buffer; jbe .fits
  0000:0C1A  db 33 D2                                           ; xor dx,dx
  0000:0C1C  db 8B 86 87 00                                     ; load buffer size
  0000:0C20  db F7 F3                                           ; div -- clamp to buffer
  0000:0C22  db 89 46 75                                        ; store clamped height
  0000:0C25  db 5A 5B 58                                        ; pop dx,bx,ax

; --- Set up scan pointers and render ---
  0000:0C28  db 8D 76 71 89 76 58                               ; lea si,[bp+0x71]; store
  0000:0C2E  db 16 8F 46 5A                                     ; push ss; pop segment
  0000:0C32  db 1E 57                                           ; push ds,di
  0000:0C34  db C5 7E 5C                                        ; lds di,[bp+0x5C]
  0000:0C37  db 8B 5D 04 8B 4D 0A                               ; load dimensions
  0000:0C3D  db 5F 1F                                           ; pop di,ds
  0000:0C3F  db 2B D9                                           ; sub bx,cx
  0000:0C41  db 2B 9E 83 00                                     ; sub bx,[bp+0x83]
  0000:0C45  db 89 5E 7B                                        ; store remaining lines
  0000:0C48  db FF 76 7B                                        ; push remaining
  0000:0C4B  db 57 1E                                           ; push di,ds
  0000:0C4D  db C5 7E 5C                                        ; lds di,[bp+0x5C]
  0000:0C50  db 8B 5D 0A 03 9E 83 00                            ; load start + offset
  0000:0C57  db 8E 5E 5A                                        ; mov ds,[bp+0x5A]
  0000:0C5A  db 8B 7E 58                                        ; mov di,[bp+0x58]
  0000:0C5D  db 89 5E 7B                                        ; store
  0000:0C60  db E8 D2 F5                                        ; call clipToWindow
  0000:0C63  db 1F 5F                                           ; pop ds,di
  0000:0C65  db E8 2B F5                                        ; call clipRect
  0000:0C68  db 73 05                                           ; jnc .visible
  0000:0C6A  db 83 C4 02 EB 35                                  ; add sp,2; jmp .skip

  0000:0C6F  db 8F 46 7B                                        ; pop [bp+0x7B]
  0000:0C72  db 83 C5 52                                        ; add bp,0x52
  0000:0C75  db B8 0C 00                                        ; mov ax,0x0C -- host fn: next scan
  0000:0C78  db 26 FF 1E 25 00                                  ; lcall es:[0x25]
  0000:0C7D  db 83 ED 52                                        ; sub bp,0x52
  0000:0C80  db 3D FF FF 75 09                                  ; cmp ax,-1; jne .ok
  0000:0C85  db E8 38 01                                        ; call unloadResources
  0000:0C88  db EB 52 90                                        ; jmp .exit
  0000:0C8B  db E9 92 00                                        ; jmp .endLoop

; --- Continue rendering scan lines ---
  0000:0C8E  db C5 7E 5C                                        ; lds di,[bp+0x5C]
  0000:0C91  db 8B 5D 0A 03 9E 83 00                            ; load adjusted scanline
  0000:0C98  db 89 5E 7B                                        ; store
  0000:0C9B  db 8E 5E 5A 8B 7E 58                               ; set up video ptrs
  0000:0CA1  db E8 5B F5                                        ; call sub
  0000:0CA4  db 8B 86 83 00 03 46 75                             ; advance by rendered height
  0000:0CAB  db 89 86 83 00                                     ;
  0000:0CAF  db 3B 86 81 00 73 27                               ; check if done
  0000:0CB5  db 03 46 75 2B 86 81 00                            ; compute remaining
  0000:0CBC  db 7E 03 29 46 75                                  ; clamp
  0000:0CC1  db E9 6E FF                                        ; jmp .renderLoop

  0000:0CC4  db C5 7E 5C 83 7D 0E FF                            ; check end marker
  0000:0CCB  db 75 05 E8 F0 00 EB 0A                            ; jne .more; call unload
  0000:0CD2  db 8B 45 04 89 86 81 00                            ; update total rendered
  0000:0CD9  db E8 23 F5                                        ; call clipRect

; --- Update window metrics after rendering ---
  0000:0CDC  db C5 7E 5C                                        ; lds di,[bp+0x5C]
  0000:0CDF  db 8B 46 1E 03 45 06 89 46 1E                      ; advance object counter
  0000:0CE8  db 8B 9E 05 04 E8 28 F7                            ; load; call transform
  0000:0CEF  db 03 86 25 04 E8 E6 F5                            ; add offset; call
  0000:0CF6  db 89 46 20                                        ; store
  0000:0CF9  db 8B 46 1E E8 21 F7                               ; transform object position
  0000:0CFF  db 03 86 27 04 E8 EB F5                            ; add origin offset
  0000:0D06  db 89 46 22                                        ; store
  0000:0D09  db E9 91 FE                                        ; jmp .mainLoop

; ========================================================================
; dmvet_finalizeRedraw (0000:0D0C)
; Compute final window bounds and update scroll parameters.
; Called at the end of fullRedraw to store the resulting metrics.
; ========================================================================
  0000:0D0C  db 8B 46 20 2B 46 28                               ; compute width from bounds
  0000:0D12  db 89 46 2C                                        ; store
  0000:0D15  db F7 86 FF 03 02 00 74 03                          ; test flag; jz .noFree
  0000:0D1D  db E8 1C 00                                        ; call freeBuffer

; --- Free off-screen buffer ---
  0000:0D20  db 83 7E 7D 00 75 0B                               ; cmp [bp+0x7D],0; jne .internal
  0000:0D26  db 50 06 8E 46 7F B4 49 CD 21 07 58               ; push ax; mov es,[seg]; DOS free; pop
  0000:0D31  db E8 30 F5                                        ; call clipRect
  0000:0D34  db 1F                                              ; pop ds
  0000:0D35  db 5F 5E 5A 59 5B 58                               ; pop all
  0000:0D3B  db C3                                               ; ret

; ========================================================================
; dmvet_unloadResources (0000:0D3D)
; Unload resources and set up palette after a mode change.
; Programs the TGA palette registers and color mapping.
; ========================================================================
  0000:0D3D  db 1E 16 1F                                        ; push ds; push ss; pop ds
  0000:0D40  db 8D BE A9 03                                     ; lea di,[bp+0x3A9]
  0000:0D44  db E8 29 F6                                        ; call sub
  0000:0D47  db B8 00 00                                        ; mov ax,0
  0000:0D4A  db F7 86 FF 03 40 00 74 03                          ; test flag; jz .noMask
  0000:0D52  db B8 05 00                                        ; mov ax,5 (mask value)
  0000:0D55  db 8A 9E 23 04                                     ; load color attribute
  0000:0D59  db E8 3E F6                                        ; call palette setup
  0000:0D5C  db 8B 9E 05 04                                     ; load scale factor
  0000:0D60  db B8 01 00 E8 BB F6                               ; call scaled compute
  0000:0D66  db 89 46 6D                                        ; store
  0000:0D69  db B8 01 00 E8 A9 F6                               ; call again
  0000:0D6F  db 89 46 6F                                        ; store
  0000:0D72  db 8D 76 68                                        ; lea si,[bp+0x68]
  0000:0D75  db 36 8A 44 01 98                                  ; load byte; cbw
  0000:0D7A  db E8 A4 F6                                        ; call transform
  0000:0D7D  db 01 46 28 01 46 20                               ; add to bounds
  0000:0D83  db 36 8A 44 01 98 E8 8D F6                         ; load; call transform
  0000:0D8B  db 29 46 2A 29 46 22                               ; subtract from bounds
  0000:0D91  db 36 8A 1C 32 FF                                  ; load byte; zero-extend
  0000:0D96  db 8B FB                                           ; mov di,bx
  0000:0D98  db 8B 46 28 8B 5E 2A 8B 4E 20 8B 56 22            ; load window rect
  0000:0DA4  db E8 B4 F5                                        ; call clipRect
  0000:0DA7  db 4F 74 0E                                        ; dec di; jz .done
  0000:0DA9  db 2B 46 6D 03 5E 6F 2B 4E 6D 03 56 6F            ; adjust by character cell
  0000:0DB5  db EB EC                                           ; jmp .loop
  0000:0DB7  db 8D B6 A9 03 E8 C6 F5                            ; lea; call
  0000:0DBE  db 1F C3                                           ; pop ds; ret

; ========================================================================
; dmvet_computeWindowBounds (0000:0DC0)
; Compute the window bounds for character rendering.
; Sets up the logical-to-physical coordinate mapping for the current
; window state, including scroll position.
; ========================================================================
  0000:0DC0  db 16 1F 8D BE A9 03 E8 A6 F5                      ; push ss; pop ds; call sub
  0000:0DC9  db 8B 86 01 04 8B 9E 03 04                         ; load resolution
  0000:0DD1  db E8 42 00                                        ; call scaleCoordinates
  0000:0DD4  db E8 01 F6                                        ; call sub
  0000:0DD7  db 1E C5 7E 5C                                     ; push ds; lds di,[bp+0x5C]
  0000:0DDB  db 89 45 06 1F                                     ; store; pop ds
  0000:0DDF  db 8B CB D1 EB D1 EB 2B CB                         ; compute half-cell offset
  0000:0DE7  db 8B 46 22 E8 2E F5                               ; transform X
  0000:0DED  db 8B D8 2B D9                                     ; compute delta
  0000:0DF1  db 8B 46 20 E8 0F F5                               ; transform Y
  0000:0DF7  db E8 B4 F5                                        ; call sub
  0000:0DFA  db B0 00 8A A6 23 04                               ; load attribute
  0000:0E00  db E8 EA F5                                        ; call palette apply
  0000:0E03  db B0 20 E8 FA F5                                  ; load space char; call
  0000:0E08  db 8B 46 56 E8 B5 F5                               ; load type; call
  0000:0E0E  db 8D B6 A9 03 E8 6F F5                            ; lea; call finalize
  0000:0E15  db C3                                               ; ret

; ========================================================================
; dmvet_scaleCoordinates (0000:0E16)
; Scale pixel coordinates to DeskMate logical coordinates.
; Uses the formula: logical = (pixel * 1000) / screen_dimension
; Entry: AX = value1, BX = value2
; Returns: AX = scaled_X, BX = scaled_Y
; ========================================================================
  0000:0E16  db 51 52                                           ; push cx,dx
  0000:0E18  db B9 E8 03                                        ; mov cx,1000
  0000:0E1B  db F7 E1                                           ; mul cx -- AX * 1000
  0000:0E1D  db 05 24 00                                        ; add ax,36 -- rounding adjustment
  0000:0E20  db B9 48 00                                        ; mov cx,72 -- screen width divisor
  0000:0E23  db F7 F1                                           ; div cx
  0000:0E25  db 93                                              ; xchg ax,bx
  0000:0E26  db F7 E3                                           ; mul bx
  0000:0E28  db B9 DC 00                                        ; mov cx,220 -- screen height divisor
  0000:0E2B  db F7 F1                                           ; div cx
  0000:0E2D  db 5A 59 C3                                        ; pop dx,cx; ret

; ========================================================================
; dmvet_adjustDisplayMetrics (0000:0E31)
; Adjust display metrics (width/height in pixels) using the DM host's
; physical display dimensions.
; Pushes coordinates on stack and calls host function 0x0D (set metrics).
; ========================================================================
  0000:0E31  db 50 53 52 55 56                                  ; push ax,bx,dx,bp,si (PSRUV)
  0000:0E36  db 1E C5 76 00                                     ; push ds; lds si,[bp]
  0000:0E3A  db 33 D2 BB E8 03                                  ; xor dx,dx; mov bx,1000
  0000:0E3F  db B8 C8 00                                        ; mov ax,200 -- vertical pixels
  0000:0E42  db F7 EB                                           ; imul bx -- 200*1000
  0000:0E44  db 8B 5C 06 F7 FB                                  ; mov bx,[si+6]; idiv bx -- /logical_height
  0000:0E49  db 50                                              ; push ax (Y scale factor)
  0000:0E4A  db 33 D2 BB E8 03                                  ; xor dx,dx; mov bx,1000
  0000:0E4F  db B8 80 02                                        ; mov ax,640 -- horizontal pixels
  0000:0E52  db F7 EB                                           ; imul bx -- 640*1000
  0000:0E54  db 8B 5C 04 F7 FB                                  ; mov bx,[si+4]; idiv bx -- /logical_width
  0000:0E59  db 50                                              ; push ax (X scale factor)
  0000:0E5A  db 8B EC                                           ; mov bp,sp
  0000:0E5C  db B8 0D 00                                        ; mov ax,0x0D -- host fn: set display metrics
  0000:0E5F  db 26 FF 1E 25 00                                  ; lcall es:[0x25]
  0000:0E64  db 83 C4 04                                        ; add sp,4
  0000:0E67  db 1F                                              ; pop ds
  0000:0E68  db 5E 5D 5A 5B 58                                  ; pop si,bp,dx,bx,ax (^]Z[X)
  0000:0E6D  db C3                                               ; ret

; ========================================================================
; sub_0000_0E6E -- dmvet_adjustResolution
; Query the host's physical display dimensions and compute scale factors.
; Reads from IVT vector 0x0386 (DM host data segment) fields:
;   [0x06] = physical display width
;   [0x08] = physical display height
; Computes: (200*1000)/height and (640*1000)/width as scale factors.
; Then calls host function 0x0E (adjust resolution) and 0x0D (set metrics).
; ========================================================================
sub_0000_0E6E:
  0000:0E6E  50                push     ax
  0000:0E6F  53                push     bx
  0000:0E70  52                push     dx
  0000:0E71  55                push     bp
  0000:0E72  06                push     es
  0000:0E73  33c0              xor      ax, ax
  0000:0E75  8ec0              mov      es, ax              ; ES = 0000 (IVT base)
  0000:0E77  268e068603        mov      es, word ptr es:[0x386] ; ES = DM host data segment
  0000:0E7C  33d2              xor      dx, dx
  0000:0E7E  bbe803            mov      bx, 0x3e8           ; BX = 1000
  0000:0E81  b8c800            mov      ax, 0xc8            ; AX = 200 (vertical pixels)
  0000:0E84  f7eb              imul     bx                  ; DX:AX = 200 * 1000 = 200,000
  0000:0E86  268b1e0800        mov      bx, word ptr es:[8] ; BX = physical display height
  0000:0E8B  f7f3              div      bx                  ; AX = 200000 / height = Y scale
  0000:0E8D  50                push     ax                  ; save Y scale factor
  0000:0E8E  33d2              xor      dx, dx
  0000:0E90  bbe803            mov      bx, 0x3e8           ; BX = 1000
  0000:0E93  b88002            mov      ax, 0x280           ; AX = 640 (horizontal pixels)
  0000:0E96  f7eb              imul     bx                  ; DX:AX = 640 * 1000 = 640,000
  0000:0E98  268b1e0600        mov      bx, word ptr es:[6] ; BX = physical display width
  0000:0E9D  f7fb              idiv     bx                  ; AX = 640000 / width = X scale
  0000:0E9F  5b                pop      bx                  ; BX = Y scale factor
  0000:0EA0  07                pop      es
  0000:0EA1  83ec04            sub      sp, 4               ; allocate local frame
  0000:0EA4  8bec              mov      bp, sp
  0000:0EA6  50                push     ax                  ; push X scale
  0000:0EA7  53                push     bx                  ; push Y scale
  0000:0EA8  8d4604            lea      ax, [bp + 4]        ; pointer to old values
  0000:0EAB  16                push     ss
  0000:0EAC  50                push     ax
  0000:0EAD  8d4602            lea      ax, [bp + 2]        ; pointer to new values
  0000:0EB0  16                push     ss
  0000:0EB1  50                push     ax
  0000:0EB2  8bec              mov      bp, sp
  0000:0EB4  b80e00            mov      ax, 0xe             ; host function 0x0E: adjust resolution
  0000:0EB7  26ff1e2500        lcall    es:[0x25]           ; far-call into host
  0000:0EBC  83c408            add      sp, 8               ; clean up params
  0000:0EBF  5b                pop      bx                  ; restore Y scale
  0000:0EC0  58                pop      ax                  ; restore X scale
  0000:0EC1  8bec              mov      bp, sp
  0000:0EC3  3b4602            cmp      ax, word ptr [bp + 2] ; compare with host's value
  0000:0EC6  7505              jne      loc_0000_0ECD       ; if different, update
  0000:0EC8  3b5e04            cmp      bx, word ptr [bp + 4]
  0000:0ECB  740f              je       loc_0000_0EDC       ; if same, skip update

loc_0000_0ECD:
  ; Host returned different scale factors -- call function 0x0D to update
  0000:0ECD  53                push     bx
  0000:0ECE  50                push     ax
  0000:0ECF  8bec              mov      bp, sp
  0000:0ED1  b80d00            mov      ax, 0xd             ; host function 0x0D: set display metrics
  0000:0ED4  26ff1e2500        lcall    es:[0x25]
  0000:0ED9  83c404            add      sp, 4

loc_0000_0EDC:
  0000:0EDC  83c404            add      sp, 4               ; clean up local frame
  0000:0EDF  5d                pop      bp
  0000:0EE0  5a                pop      dx
  0000:0EE1  5b                pop      bx
  0000:0EE2  58                pop      ax
  0000:0EE3  c3                ret

; ========================================================================
; dmvet_setupVideoMode (0000:0EE4)
; Set up the TGA enhanced video mode.
; Steps:
;   1. Check if INT ABh vector contains the expected signature (0xABCD/0xDCBA)
;      which indicates DMVST is already loaded.
;   2. If signature found, register with DMVST via INT ABh (AX=0x0208).
;   3. Query host capabilities via INT E0h AH=06h.
;   4. If successful, call host function 0x00 to initialize display.
;   5. If the display needs a new resolution, push resolution params
;      and call host function 0x03 (set video mode).
;   6. Call dmvet_adjustResolution to sync scale factors.
;   7. Increment the video driver reference count at es:[0x30].
; Returns: AX=1 (success)
; ========================================================================
  0000:0EE4  db 53 52 56 57 55                                  ; push bx,dx,si,di,bp (SRVWU)
  0000:0EE9  db 83 EC 02 8B EC                                  ; sub sp,2; mov bp,sp
  0000:0EEE  db 26 81 3E 25 00 CD AB                            ; cmp word es:[0x25],0xABCD -- check INT ABh sig
  0000:0EF5  db 75 56                                           ; jne .noVST -- DMVST not loaded
  0000:0EF7  db 26 81 3E 27 00 BA DC                            ; cmp word es:[0x27],0xDCBA -- 2nd sig word
  0000:0EFE  db 75 4D                                           ; jne .noVST
  0000:0F00  db BB 25 00 BA 29 00                               ; bx -> sig ptr, dx -> sig ptr
  0000:0F06  db B8 08 02                                        ; AX = 0x0208 -- register with DMVST
  0000:0F09  db CD E0                                           ; int 0xE0 -- INT E0h AH=02h
  0000:0F0B  db C7 46 00 00 00                                  ; clear local flag
  0000:0F10  db 0B C0 75 05                                     ; or ax,ax; jnz .ok
  0000:0F14  db C7 46 00 01 00                                  ; set flag=1 (newly registered)
  0000:0F19  db B8 06 02                                        ; AX = 0x0206 -- INT E0h AH=06h (get caps)
  0000:0F1C  db CD E0                                           ; int 0xE0
  0000:0F1E  db 0B C0 74 36                                     ; or ax,ax; jz .fail
  0000:0F20  db B8 00 00                                        ; AX = 0 -- host fn 0x00: init display
  0000:0F23  db 26 FF 1E 25 00                                  ; lcall es:[0x25]
  0000:0F28  db 83 7E 00 00 74 1D                               ; cmp [bp+0],0; je .noModeChange
  0000:0F2E  db 83 EC 05 8B EC                                  ; sub sp,5; mov bp,sp
  0000:0F33  db C6 46 00 03                                     ; mov byte [bp],3 -- mode 3 (320x200)
  0000:0F37  db C7 46 01 FF FF                                  ; mov word [bp+1],0xFFFF
  0000:0F3C  db 16                                              ; push ss

; --- Call host function 0x03 to set video mode ---
  0000:0F3F  55                push     bp
  0000:0F40  8bec              mov      bp, sp
  0000:0F42  b80300            mov      ax, 3               ; host function 0x03: set video mode
  0000:0F45  26ff1e2500        lcall    es:[0x25]
  0000:0F4A  83c409            add      sp, 9               ; clean up 5 + 4 bytes
  0000:0F4D  e81eff            call     sub_0000_0E6E       ; call adjustResolution
  0000:0F50  26fe063000        inc      byte ptr es:[0x30]  ; increment video driver ref count
  0000:0F55  b80100            mov      ax, 1               ; return success
  0000:0F58  83c402            add      sp, 2               ; clean up local
  0000:0F5B  5d                pop      bp
  0000:0F5C  5f                pop      di
  0000:0F5D  5e                pop      si
  0000:0F5E  5a                pop      dx
  0000:0F5F  5b                pop      bx
  0000:0F60  c3                ret

; ========================================================================
; dmvet_teardownVideoMode (0000:0F61)
; Tear down the enhanced video mode.
; Steps:
;   1. Check if reference count es:[0x30] == 1 (last user).
;   2. If so, call host function 0x01 (deinitialize display).
;   3. Unregister from DMVST via INT E0h AH=07h, AX=0x0207.
;   4. Restore the original INT ABh signature at es:[0x25] and es:[0x27].
;   5. Decrement the reference count at es:[0x30].
; ========================================================================
  0000:0F61  db 50 52                                           ; push ax,dx
  0000:0F63  db 26 80 3E 30 00 01                               ; cmp byte es:[0x30],1 -- last user?
  0000:0F69  db 75 1E                                           ; jne .notLast
  0000:0F6B  db B8 01 00                                        ; AX = 1 -- host fn 0x01: deinit display
  0000:0F6E  db 26 FF 1E 25 00                                  ; lcall es:[0x25]
  0000:0F73  db BA 29 00                                        ; DX = offset 0x29
  0000:0F76  db B8 07 02                                        ; AX = 0x0207 -- INT E0h: unregister
  0000:0F79  db CD E0                                           ; int 0xE0
  0000:0F7B  db 26 C7 06 25 00 CD AB                            ; mov word es:[0x25],0xABCD -- restore sig
  0000:0F82  db 26 C7 06 27 00 BA DC                            ; mov word es:[0x27],0xDCBA -- restore sig
  0000:0F89  db 26 FE 0E 30 00                                  ; dec byte es:[0x30] -- decrement ref count
  0000:0F8E  db 5A 58 C3                                        ; pop dx,ax; ret

; ========================================================================
; dmvet_programTGARegisters (0000:0F91)
; Program the TGA/EGA graphics controller registers for DeskMate drawing.
; Sets up the planar graphics mode for 4-color/16-color rendering.
;
; Register programming sequence:
;   Sequencer (port 0x03C4):
;     Register 0x02 (Map Mask) = 0x0F (all 4 planes enabled)
;   Graphics Controller (port 0x03CE):
;     Register 0x00 (Set/Reset) = 0x00
;     Register 0x01 (Enable Set/Reset) = 0x00
;     Register 0x03 (Data Rotate) = 0x00 (no rotation, no function)
;     Register 0x04 (Read Map Select) = 0x00 (plane 0)
;     Register 0x08 (Bit Mask) = 0xFF (all bits writable)
; ========================================================================
  0000:0F91  db 90                                              ; nop (alignment)
  0000:0F92  db 50 52                                           ; push ax,dx
; --- Sequencer: Map Mask = 0x0F (enable all planes) ---
  0000:0F94  db BA C4 03                                        ; mov dx,0x03C4  ; port: Sequencer Address
  0000:0F97  db B0 02                                           ; mov al,0x02    ; register: Map Mask
  0000:0F99  db EE                                              ; out dx,al
  0000:0F9A  db 42                                              ; inc dx         ; port: 0x03C5 Sequencer Data
  0000:0F9B  db B0 0F                                           ; mov al,0x0F    ; value: all planes on
  0000:0F9D  db EE                                              ; out dx,al
; --- Graphics Controller: Set/Reset = 0x00 ---
  0000:0F9E  db BA CE 03                                        ; mov dx,0x03CE  ; port: GC Address
  0000:0FA1  db B0 00                                           ; mov al,0x00    ; register: Set/Reset
  0000:0FA3  db EE                                              ; out dx,al
  0000:0FA4  db 42                                              ; inc dx         ; port: 0x03CF GC Data
  0000:0FA5  db B0 00                                           ; mov al,0x00    ; value: 0
  0000:0FA7  db EE                                              ; out dx,al
; --- Graphics Controller: Enable Set/Reset = 0x00 ---
  0000:0FA8  db BA CE 03                                        ; mov dx,0x03CE
  0000:0FAB  db B0 01                                           ; register: Enable Set/Reset
  0000:0FAD  db EE                                              ; out dx,al
  0000:0FAE  db B0 00                                           ; value: 0 (disabled)
  0000:0FB0  db 42                                              ; inc dx
  0000:0FB1  db EE                                              ; out dx,al
; --- Graphics Controller: Data Rotate = 0x00 ---
  0000:0FB2  db BA CE 03                                        ; mov dx,0x03CE
  0000:0FB5  db B0 03                                           ; register: Data Rotate
  0000:0FB7  db EE                                              ; out dx,al
  0000:0FB8  db 42                                              ; inc dx
  0000:0FB9  db 32 C0                                           ; xor al,al      ; value: 0 (no rotate/fn)
  0000:0FBB  db EE                                              ; out dx,al
; --- Graphics Controller: Read Map Select = 0x00 ---
  0000:0FBC  db BA CE 03                                        ; mov dx,0x03CE
  0000:0FBF  db B0 04                                           ; register: Read Map Select
  0000:0FC1  db EE                                              ; out dx,al
  0000:0FC2  db B0 00                                           ; value: plane 0
  0000:0FC4  db 42                                              ; inc dx
  0000:0FC5  db EE                                              ; out dx,al
; --- Graphics Controller: Bit Mask = 0xFF ---
  0000:0FC6  db BA CE 03                                        ; mov dx,0x03CE
  0000:0FC9  db B0 08                                           ; register: Bit Mask
  0000:0FCB  db EE                                              ; out dx,al
  0000:0FCC  db 42                                              ; inc dx
  0000:0FCD  db B0 FF                                           ; value: 0xFF (all bits)
  0000:0FCF  db EE                                              ; out dx,al
  0000:0FD0  db 5A 58 C3                                        ; pop dx,ax; ret

; ========================================================================
; dmvet_setTGAPalette (0000:0FD2)
; Set TGA palette registers for the current drawing color.
; Programs GC registers 0 (Set/Reset), 1 (Enable Set/Reset), and 8 (Bit Mask).
; Entry: AX = color value to set
; ========================================================================
  0000:0FD2  db 50                                              ; push ax
; --- Set/Reset = color value ---
  0000:0FD3  db BA CE 03                                        ; mov dx,0x03CE
  0000:0FD6  db B0 00                                           ; register: Set/Reset
  0000:0FD8  db EE                                              ; out dx,al
  0000:0FD9  db 42                                              ; inc dx
  0000:0FDA  db 58                                              ; pop ax (restore color)
  0000:0FDB  db EE                                              ; out dx,al (write color to Set/Reset data)
; --- Enable Set/Reset = 0x0F (all planes) ---
  0000:0FDC  db BA CE 03                                        ; mov dx,0x03CE
  0000:0FDF  db B0 01                                           ; register: Enable Set/Reset
  0000:0FE1  db EE                                              ; out dx,al
  0000:0FE2  db 42                                              ; inc dx
  0000:0FE3  db B0 0F                                           ; value: 0x0F (all planes enabled)
  0000:0FE5  db EE                                              ; out dx,al
; --- Bit Mask = AX (passed via caller) ---
  0000:0FE6  db BA CE 03                                        ; mov dx,0x03CE
  0000:0FE9  db B0 08                                           ; register: Bit Mask
  0000:0FEB  db EE                                              ; out dx,al
  0000:0FEC  db 42                                              ; inc dx
  0000:0FED  db C3                                              ; ret (caller writes mask data)

; ========================================================================
; dmvet_calcScanlineOffset (0000:0FF1)
; Calculate the video memory byte offset for a given Y coordinate.
; Formula: offset = Y * 80 (for 640-pixel-wide display, 8 pixels/byte)
;   then X byte offset = X / 8
;   bit offset within byte = X mod 8
;
; Entry: DI = Y coordinate
; Returns: DI = byte offset, CX = bit shift within byte
; ========================================================================
  0000:0FF1  db 8B FB                                           ; mov di,bx (Y coord)
  0000:0FF3  db D1 E7 D1 E7 03 FB                               ; shl di,2; add di,bx (di = Y*5)
  0000:0FF9  db D1 E7 D1 E7 D1 E7 D1 E7                        ; shl di,4 (di = Y*80)
  0000:1001  db 8B C8 D1 F9 D1 F9 D1 F9                         ; mov cx,ax; sar cx,3 (X/8)
  0000:1009  db 03 F9                                           ; add di,cx (byte offset)
  0000:100B  db 8B C8 83 E1 07                                  ; mov cx,ax; and cx,7 (bit within byte)
  0000:1010  db C3                                               ; ret

; ========================================================================
; dmvet_fastBlit (0000:1011)
; Fast blit: copy a bitmap with bit masking to video memory.
; Handles the inner loop of character rendering, transferring glyph
; bitmap rows to the TGA frame buffer via the GC bit mask register.
;
; Entry: SI -> source bitmap, ES:DI -> video memory
;        CL = bit shift, CH = right-edge mask
; Two paths: masked (with bit shifting) and direct (byte-aligned).
; ========================================================================
  0000:1011  db 0A DB 74 4C                                     ; or bl,bl; jz .done
  0000:1015  db 53 56 57                                        ; push bx,si,di
  0000:1018  db 0A C9 74 27                                     ; or cl,cl; jz .noShift
; --- Shifted path (non-byte-aligned) ---
  0000:101C  db FE CB 74 13                                     ; dec bl; jz .lastByte
  0000:101E  db 26 8A 05                                        ; mov al,es:[di] -- latch read
  0000:1021  db AC                                              ; lodsb -- load glyph byte
  0000:1022  db 8A E7                                           ; mov ah,bh -- save mask
  0000:1024  db 8A F8                                           ; mov bh,al
  0000:1026  db D3 E8                                           ; shr ax,cl -- shift glyph
  0000:1028  db 22 46 1C                                        ; and al,[bp+0x1C] -- apply mask
  0000:102B  db EE                                              ; out dx,al -- write to GC bit mask
  0000:102C  db AA                                              ; stosb -- write to video memory
  0000:102D  db FE CB                                           ; dec bl
  0000:102F  db 75 ED                                           ; jne .loop
; --- Last byte of row ---
  0000:1031  db AC                                              ; lodsb
  0000:1032  db 8A E7                                           ; mov ah,bh
  0000:1034  db D3 E8                                           ; shr ax,cl
  0000:1036  db 22 C5                                           ; and al,ch -- right-edge mask
  0000:1038  db 22 46 1C                                        ; and al,[bp+0x1C]
  0000:103B  db EE                                              ; out dx,al
  0000:103C  db 26 20 05                                        ; and es:[di],al -- merge with existing
  0000:103F  db EB 1B                                           ; jmp .done
; --- Direct path (byte-aligned) ---
  0000:1041  db FE CB 74 0D                                     ; dec bl; jz .lastDirect
  0000:1045  db 26 8A 05                                        ; mov al,es:[di] -- latch read
  0000:1048  db AC                                              ; lodsb
  0000:1049  db 22 46 1C                                        ; and al,[bp+0x1C]
  0000:104C  db EE                                              ; out dx,al
  0000:104D  db AA                                              ; stosb
  0000:104E  db FE CB                                           ; dec bl
  0000:1050  db 75 F3                                           ; jne .loop
  0000:1052  db AC                                              ; lodsb
  0000:1053  db 22 C5                                           ; and al,ch
  0000:1055  db 22 46 1C                                        ; and al,[bp+0x1C]
  0000:1058  db EE                                              ; out dx,al
  0000:1059  db 26 20 05                                        ; and es:[di],al
  0000:105C  db 5F 5E 5B C3                                     ; pop di,si,bx; ret
  0000:1060  db 90                                              ; nop (alignment)

; ========================================================================
; dmvet_bresenhamSetup (0000:1061)
; Set up Bresenham line-drawing parameters from two endpoints.
; Used for computing the DX, DY, step direction, and error term.
; Entry: Stack frame with x1,y1,x2,y2
; ========================================================================
  0000:1061  db 55 83 EC 06 8B EC                               ; push bp; sub sp,6; mov bp,sp
  0000:1067  db C7 46 00 20 00                                  ; mov word [bp],0x20 -- iteration count
  0000:106C  db C7 46 02 00 00 C7 46 04 00 00                   ; clear accumulators
  0000:1076  db D1 E2 D1 D1 D1 D3 D1 D0                        ; shift operations for fixed-point
  0000:107E  db D1 66 02 D1 56 04                               ; shift intermediate values
  0000:1084  db 3B C6 72 11                                     ; compare; jb .swap
  0000:1088  db 77 04 3B DF 72 0B                               ; above; compare; jb .swap
  0000:108E  db 2B DF 1B C6                                     ; subtract
  0000:1092  db FF 46 02 83 56 04 00                             ; increment; add with carry
  0000:1099  db FF 4E 00 75 D8                                  ; dec counter; jnz .loop
  0000:109E  db EB 00                                           ; jmp .done (NOP jmp)
  0000:10A0  db 8B C8 8B D3                                     ; mov cx,ax; mov dx,bx
  0000:10A4  db 8B 46 04 8B 5E 02                               ; load results
  0000:10AA  db 83 C4 06 5D C3                                  ; clean up stack; pop bp; ret

; ========================================================================
; dmvet_mul32 (0000:10B7)
; 32x16 bit unsigned multiply yielding 32-bit result.
; Entry: AX:BX = multiplicand (32-bit), CX = multiplier (16-bit)
;        DX = initial high word
; Returns: AX:BX:CX:DX = 64-bit product
; ========================================================================
  0000:10AF  db 55 83 EC 10 8B EC                               ; push bp; sub sp,0x10; mov bp,sp
  0000:10B5  db 89 46 08 89 5E 0A 89 4E 0C 89 56 0E            ; save all operands
  0000:10C1  db C7 46 04 00 00 C7 46 06 00 00                   ; clear result high words
  0000:10CB  db 8B 5E 0E 8B 46 0A BA 00 00 F7 E3               ; mul low*low
  0000:10D6  db 89 46 00 89 56 02                               ; store partial result
  0000:10DC  db 8B 46 08 BA 00 00 F7 E3                         ; mul high*low
  0000:10E4  db 01 46 02 11 56 04 83 56 06 00                   ; accumulate
  0000:10EE  db 8B 5E 0C 8B 46 0A BA 00 00 F7 E3               ; mul low*high
  0000:10F9  db 01 46 02 11 56 04 83 56 06 00                   ; accumulate
  0000:1103  db 8B 46 08 BA 00 00 F7 E3                         ; mul high*high
  0000:110B  db 01 46 04 11 56 06                               ; accumulate
  0000:1111  db 8B 46 06 8B 5E 04 8B 4E 02 8B 56 00            ; load 64-bit result
  0000:111D  db 83 C4 10                                        ; clean up stack
  ; (falls through to seg_0112 epilogue)

; ========================================================================
; SEGMENT seg_0112  (16 bytes) -- Epilogue stub
; ========================================================================
seg_0112:

  0112:0000  db 5D C3                                           ; pop bp; ret
  0112:0002  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00      ; padding

; ========================================================================
; SEGMENT seg_0113  (400 bytes) -- DM89 Header + Entry Point + Dispatch
; ========================================================================
seg_0113:

; ========================================================================
; dmvet_dm89Header (0113:0000)
; DM89 module header structure. Contains the module name "DMVET",
; font companion name "DMFONT", standard companion reference via INT ABh,
; and the dispatch thunk code.
;
; Layout:
;   +0x00: "DMVET\0"    -- module name (6 bytes)
;   +0x06: DM89 vector data (self-referencing relocations)
;   +0x22: DM89 companion reference area
;   +0x31: INT ABh far pointer (for DMVST cooperation)
;   +0x3B: Saved DM host task ID
;   +0x3C: Saved task ID scratch
;   +0x3E: Mode flag byte ('Y' = 640-wide, 'X' = 320-wide)
;   +0x3F: Thunk entry code
; ========================================================================
sub_0113_0000:
  ; This is actually DATA, not code. The disassembler mis-decoded it.
  ; Bytes 0x00-0x05: "DMVET\0"
  0113:0000  db 44 4D 56 45 54 00                               ; "DMVET\0"
  ; Bytes 0x06-0x21: DM89 vector structure (relocatable pointers)
  0113:0006  db 00 E0                                           ; DM89 dispatch vector
  0113:0008  db 00 13 01                                        ; self-segment ref (RELOC->seg_0113)
  0113:000B  db 47 01                                           ; offset into cleanup thunk
  0113:000D  db 13 01                                           ; segment ref (RELOC->seg_0113)
  0113:000F  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; reserved (all zeros)
  0113:001F  db 00 00 00                                        ;
  ; Bytes 0x22-0x30: Companion references
  0113:0022  db 03 13 01                                        ; -> font module dispatch
  0113:0025  db CD AB BA DC                                     ; INT ABh signature: 0xABCD, 0xDCBA
  ; This is the check pattern for DMVST cooperation.
  ; DMVST stores 0xABCD at the dispatch vector when it's loaded;
  ; DMVET checks for this to know if it can hook in.
  0113:0029  db 44 4D 46 4F 4E 54 00                            ; "DMFONT\0" -- font module name
  ; Bytes 0x31-0x3A: INT ABh saved vector + companion name
  0113:0030  db 00                                              ; NUL terminator
  0113:0031  db CD AB BA DC                                     ; signature copy for DMVST
  0113:0035  db 44 4D 56 53 54 00                               ; "DMVST\0" -- standard driver name
  ; Byte 0x3B: saved task ID from host
  0113:003B  db 00                                              ;
  ; Byte 0x3C: scratch byte for task ID
  0113:003C  db 00                                              ;
  ; Bytes 0x3D-0x3E: padding + mode flag
  0113:003D  db 00                                              ;
  0113:003E  db 53                                              ; mode flag (initial: 'S' = 0x53)

; ========================================================================
; dmvet_thunkEntry (0113:003F)
; Far-call dispatch thunk. This is the entry point called by DESK.EXE
; when it wants to invoke a video driver function.
;
; The thunk:
;   1. Aligns the stack to word boundary (required by some operations)
;   2. Saves all registers
;   3. Loads the target function offset from the DM89 vector at cs:[0x31]
;   4. If mode flag (cs:[0x3E]) == 'X' (320-wide), adjusts the function
;      index by multiplying by 4 (for the wider dispatch table)
;   5. Sets up ES from IVT[0x0386] (DM host data segment)
;   6. Restores caller's registers and performs the far return to the
;      actual function implementation
; ========================================================================
  0113:003F  db 00 53 06                                        ; (data before thunk)
  0113:0042  db 55 83 EC 0A 8B EC                               ; push bp; sub sp,0xA; mov bp,sp
  0113:0048  db 52                                              ; push dx
  0113:0049  db 2E 8A 16 3E 00                                  ; mov dl, cs:[0x3E] -- load mode flag
  0113:004E  db 88 56 09                                        ; mov [bp+9],dl -- save on stack
  0113:0051  db 2E C4 1E 31 00                                  ; les bx, cs:[0x31] -- load dispatch vector
  0113:0056  db 80 FA 58                                        ; cmp dl,0x58 -- 'X' = 320-wide mode?
  0113:0059  db 75 06                                           ; jne .normalMode
  0113:005B  db D1 E0 D1 E0                                     ; shl ax,2 -- multiply index by 4
  0113:005F  db 03 D8                                           ; add bx,ax

loc_0113_0060:
  0113:0060  5a                pop      dx
  0113:0061  8c4602            mov      word ptr [bp + 2], es   ; save ES (dispatch table seg)
  0113:0064  895e00            mov      word ptr [bp], bx       ; save offset
  0113:0067  8c4e06            mov      word ptr [bp + 6], cs   ; set return segment = CS
  0113:006A  bb9200            mov      bx, 0x92                ; return offset = thunk epilogue
  0113:006D  895e04            mov      word ptr [bp + 4], bx
  0113:0070  50                push     ax
  0113:0071  b80000            mov      ax, 0
  0113:0074  8ec0              mov      es, ax                  ; ES = 0 (IVT base)
  0113:0076  26a18603          mov      ax, word ptr es:[0x386] ; AX = DM host data segment
  0113:007A  8ec0              mov      es, ax                  ; ES = host data segment
  0113:007C  58                pop      ax
  0113:007D  8b5e0e            mov      bx, word ptr [bp + 0xe] ; restore caller's BX
  0113:0080  52                push     dx
  0113:0081  8a5609            mov      dl, byte ptr [bp + 9]   ; reload mode flag
  0113:0084  80fa58            cmp      dl, 0x58                ; 'X' mode?
  0113:0087  7506              jne      loc_0113_008F
  0113:0089  8b4610            mov      ax, word ptr [bp + 0x10] ; load extra param for X mode
  0113:008C  8b6e0a            mov      bp, word ptr [bp + 0xa] ; restore caller's BP

loc_0113_008F:
  0113:008F  5a                pop      dx
  0113:0090  45                inc      bp                      ; adjust BP (DM89 convention)
  0113:0091  cb                retf                             ; far-return into the function

; --- Thunk epilogue ---
; After the function returns, control comes here to clean up.
  0113:0092  db 83 C4 0A                                        ; add sp,0xA -- clean up thunk frame
  0113:0095  db 2E 80 3E 3E 00 58                               ; cmp cs:[0x3E],0x58 -- 'X' mode?
  0113:009B  db 75 01                                           ; jne .done
  0113:009D  db 4D                                              ; dec bp (adjust back)
  0113:009E  db CB                                              ; retf

; ========================================================================
; entry_point (0113:009F) -- DM89 Module Entry Point
; Called by DESK.EXE / DM89 loader when loading DMVET.RES.
;
; Steps:
;   1. Save DS (caller's data segment) at es:[bx+0x20]
;   2. Query host capabilities via INT E0h AH=06h
;   3. Check bit 15 of result (display type):
;      - If set: 640-wide mode, set flag='Y' (0x59), AX=0x01F0
;      - If clear: 320-wide mode, set flag='X' (0x58), AX=0x01FF
;   4. Register the seg_0000 dispatch table via INT E0h AH=01h
;   5. Save the returned task ID at es:[0x3B]
;   6. Hook INT ABh for DMVST cooperation
;   7. Get PSP address via INT 21h/51h
;   8. Terminate-and-stay-resident via INT 21h/31h
; ========================================================================
entry_point:
  0113:009F  0e                push     cs
  0113:00A0  07                pop      es                      ; ES = CS (our segment)
  0113:00A1  bb0000            mov      bx, 0
  0113:00A4  268c5f20          mov      word ptr es:[bx + 0x20], ds ; save caller's DS
  0113:00A8  b80006            mov      ax, 0x600               ; INT E0h AH=06h: query capabilities
  0113:00AB  cde0              int      0xe0
  0113:00AD  250080            and      ax, 0x8000              ; test bit 15 (display width type)
  0113:00B0  b8f001            mov      ax, 0x1f0               ; assume 640-wide
  0113:00B3  26c6063e0059      mov      byte ptr es:[0x3e], 0x59 ; flag = 'Y' (640-wide)
  0113:00B9  7508              jne      loc_0113_00C3           ; if bit 15 set, use 640 mode
  0113:00BB  b8ff01            mov      ax, 0x1ff               ; 320-wide mode
  0113:00BE  26fe0e3e00        dec      byte ptr es:[0x3e]      ; flag = 'X' (0x58 = 'Y'-1)

loc_0113_00C3:
  ; AX = 0x01F0 (640-wide) or 0x01FF (320-wide)
  ; Register dispatch table with host
  0113:00C3  b90000            mov      cx, 0                   ; RELOC->seg_0000 (dispatch table segment)
  0113:00C6  cde0              int      0xe0                    ; INT E0h AH=01h: register driver
  0113:00C8  26a23b00          mov      byte ptr es:[0x3b], al  ; save task ID
  0113:00CC  e88900            call     sub_0113_0158           ; hook INT ABh
  0113:00CF  b451              mov      ah, 0x51
  0113:00D1  cd21              int      0x21                    ; INT 21h/51h: get PSP segment -> BX
  0113:00D3  4b                dec      bx                      ; BX = PSP-1 (MCB)
  0113:00D4  8ec3              mov      es, bx
  0113:00D6  268b160300        mov      dx, word ptr es:[3]     ; DX = MCB block size (paragraphs)
  0113:00DB  b80031            mov      ax, 0x3100              ; INT 21h/31h: TSR
  0113:00DE  cd21              int      0x21                    ; terminate and stay resident

; ========================================================================
; dmvet_apiDispatch (0113:00E0)
; API dispatch handler. Called via the DM89 far-call mechanism when
; DESK.EXE invokes a video driver function.
;
; This function:
;   1. Aligns the stack to word boundary
;   2. Saves all registers (BX, CX, SI, DI, BP, DS, ES, flags)
;   3. Validates the function number (must be < 0x0D)
;   4. Acquires the DM host task lock via INT E0h AH=4Dh (function 4)
;   5. Dispatches to the thunk at sub_0113_0000 which routes to seg_0000
;   6. Releases the task lock via INT E0h AH=4Dh (function 5)
;   7. Restores all registers and returns
; ========================================================================
  0113:00E0  53                push     bx
  0113:00E1  8bdc              mov      bx, sp
  0113:00E3  83e301            and      bx, 1               ; check stack alignment
  0113:00E6  2be3              sub      sp, bx              ; align to word boundary
  0113:00E8  53                push     bx                  ; save alignment adjustment
  0113:00E9  51                push     cx
  0113:00EA  56                push     si
  0113:00EB  57                push     di
  0113:00EC  55                push     bp
  0113:00ED  1e                push     ds
  0113:00EE  06                push     es
  0113:00EF  9c                pushf
  0113:00F0  fc                cld                          ; clear direction flag
  0113:00F1  3d0d00            cmp      ax, 0xd             ; validate function number
  0113:00F4  7205              jb       loc_0113_00FB       ; if valid, continue
  0113:00F6  b8ffff            mov      ax, 0xffff          ; invalid function: return -1
  0113:00F9  eb40              jmp      loc_0113_013B

loc_0113_00FB:
  ; Valid function -- acquire task lock
  0113:00FB  50                push     ax                  ; save function number
  0113:00FC  2ea03b00          mov      al, byte ptr cs:[0x3b] ; load task ID
  0113:0100  3cff              cmp      al, 0xff            ; 0xFF = no task lock needed
  0113:0102  7409              je       loc_0113_010D
  0113:0104  52                push     dx
  0113:0105  8ad0              mov      dl, al              ; DL = task ID
  0113:0107  b8044d            mov      ax, 0x4d04          ; INT E0h AH=4Dh, AL=04 (acquire lock)
  0113:010A  cde0              int      0xe0
  0113:010C  5a                pop      dx

loc_0113_010D:
  ; Save returned lock state, then dispatch the function
  0113:010D  2ea23c00          mov      byte ptr cs:[0x3c], al ; save lock state
  0113:0111  58                pop      ax                  ; restore function number
  0113:0112  2eff363c00        push     word ptr cs:[0x3c]  ; push lock state
  0113:0117  bb1201            mov      bx, 0x112           ; RELOC->seg_0112 (trampoline seg)
  0113:011A  8ec3              mov      es, bx
  0113:011C  0e                push     cs
  0113:011D  5b                pop      bx                  ; BX = CS (our segment)
  0113:011E  9a04000000        lcall    0:4                 ; far-call into seg_0000 via thunk
  ;                                     RELOC->seg_0000 (actual dispatch)
  0113:0123  2e8f063c00        pop      word ptr cs:[0x3c]  ; restore lock state
  0113:0128  50                push     ax                  ; save return value
  ; Release task lock
  0113:0129  2ea03c00          mov      al, byte ptr cs:[0x3c]
  0113:012D  3cff              cmp      al, 0xff
  0113:012F  7409              je       loc_0113_013A
  0113:0131  52                push     dx
  0113:0132  8ad0              mov      dl, al
  0113:0134  b8054d            mov      ax, 0x4d05          ; INT E0h AH=4Dh, AL=05 (release lock)
  0113:0137  cde0              int      0xe0
  0113:0139  5a                pop      dx

loc_0113_013A:
  0113:013A  58                pop      ax                  ; restore return value

loc_0113_013B:
  ; Restore all registers and return
  0113:013B  9d                popf
  0113:013C  07                pop      es
  0113:013D  1f                pop      ds
  0113:013E  5d                pop      bp
  0113:013F  5f                pop      di
  0113:0140  5e                pop      si
  0113:0141  59                pop      cx
  0113:0142  5b                pop      bx                  ; restore alignment
  0113:0143  03e3              add      sp, bx              ; undo alignment
  0113:0145  5b                pop      bx
  0113:0146  cb                retf

; --- Cleanup thunk: called during teardown ---
  0113:0147  db 50 06 52 0E 07 BA 35 00 B8 07 02 CD E0 5A 07 58 ; cleanup: INT E0h AH=07h (unregister)
  0113:0157  db CB                                              ; retf

; ========================================================================
; sub_0113_0158 -- dmvet_hookINTAB
; Hook INT ABh to establish cooperation between DMVET and DMVST.
;
; INT ABh is used as a rendezvous point between the enhanced and standard
; Tandy video drivers. The enhanced driver stores its dispatch vector at
; cs:[0x31] via INT E0h AH=02h, and the standard driver can call through
; this vector to access the enhanced rendering functions.
;
; If mode flag is NOT 'Y' (640-wide), patches the vector entry to
; include a 'D' marker byte at cs:[0x38] for compatibility.
; ========================================================================
sub_0113_0158:
  0113:0158  53                push     bx
  0113:0159  52                push     dx
  0113:015A  26803e3e0059      cmp      byte ptr es:[0x3e], 0x59 ; mode == 'Y'?
  0113:0160  740a              je       loc_0113_016C
  0113:0162  bb3500            mov      bx, 0x35
  0113:0165  83c303            add      bx, 3                   ; BX = 0x38
  0113:0168  26c60744          mov      byte ptr es:[bx], 0x44  ; patch: write 'D' marker

loc_0113_016C:
  ; Register via INT E0h AH=02h
  0113:016C  bb3100            mov      bx, 0x31                ; offset of INT ABh vector
  0113:016F  ba3500            mov      dx, 0x35                ; offset of companion name
  0113:0172  b80602            mov      ax, 0x206               ; INT E0h AH=02h, AL=06 (hook INT ABh)
  0113:0175  cde0              int      0xe0
  0113:0177  48                dec      ax
  0113:0178  0bc0              or       ax, ax
  0113:017A  750c              jne      loc_0113_0188           ; if failed, skip
  ; Success: save the returned vector
  0113:017C  26ff1e3100        lcall    es:[0x31]               ; call through to get old vector
  0113:0181  26891e3100        mov      word ptr es:[0x31], bx  ; store new vector offset
  0113:0186  33c0              xor      ax, ax                  ; return 0 (success)

loc_0113_0188:
  0113:0188  5a                pop      dx
  0113:0189  5b                pop      bx
  0113:018A  c3                ret
  0113:018B  db 00 00 00 00 00                                  ; padding

; ========================================================================
; SEGMENT seg_012C  (2 bytes) -- Stack segment
; ========================================================================
seg_012C:
  012C:0000  db 00 00                                           ; stack base (2 bytes)

; ========================================================================
; END OF DMVET.RES DISASSEMBLY
; ========================================================================
