; ========================================================================
; DMVEEGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Enhanced Video Driver: EGA (640x350, 16 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVEEGA.RES is the enhanced-mode EGA video driver for DeskMate 3.05.
; Enhanced drivers contain the core drawing primitives (pixel plotting,
; line drawing, rectangle fill, font rendering, clipping) that operate
; on the video framebuffer. The standard driver (DMVSEGA.RES) handles
; mode switching, cursor management, INT 08h timer hooking, and the
; higher-level display list / window management, while calling into
; this enhanced driver for actual pixel-level operations.
;
; The enhanced driver installs itself as a TSR via INT 21h/31h after
; registering with the DeskMate host through INT E0h. It provides a
; dispatch table of 13 drawing functions (0x00-0x0C) that the standard
; driver calls through a far-call interface.
;
; Video framebuffer: segment A000h (EGA planar mode, 4 bit planes)
; Resolution: 640x350 at 16 colors (mode 10h)
; Bytes per scanline: 80 (640/8)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5330 bytes
; Code+data size: 4818 bytes
; DM89 entry point: 0114:00A1
; SS:SP = 012D:0002
;
; DM89 signature: present
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  0x1130 bytes  CODE/DATA  Drawing primitives + sine/cosine table
;   seg_0113  0x0010 bytes  CODE/DATA  Enhanced driver name string segment
;   seg_0114  0x0190 bytes  CODE       TSR startup, dispatch, INT E0h interface
;   seg_012D  0x0002 bytes  STACK      Stack segment
;
; Relocation Table (5 entries):
;   0114:000A -> seg_0114  (self-reference in DM89 header)
;   0114:000E -> seg_0114  (self-reference in DM89 header)
;   0114:00C6 -> seg_0000  (drawing code segment reference)
;   0114:0119 -> seg_0113  (enhanced driver name segment)
;   0114:0121 -> seg_0000  (drawing code segment reference)
;
; ========================================================================
; ARCHITECTURE
; ========================================================================
;
; The enhanced driver has two main parts:
;
; 1. Drawing Primitives (seg_0000, 4400 bytes):
;    Raw pixel-level rendering code. Functions accessed via the dispatch
;    table at seg_0000:0020. These operate directly on the EGA framebuffer
;    at segment A000h using planar 4-bit mode. The code uses a register-
;    based calling convention with coordinates in AX/BX/CX/DX and a
;    workspace structure pointed to by BP.
;
; 2. TSR Loader / Dispatcher (seg_0114, 400 bytes):
;    Entry point at 0114:00A1. Registers with DeskMate via INT E0h,
;    then goes resident via INT 21h/31h. The dispatcher at 0114:00E2
;    routes function calls through the seg_0000 dispatch table.
;
; Drawing workspace structure: identical layout to DMVEVGA (see that
; file for full workspace offset documentation). Key differences:
;   - Resolution is 640x350 instead of 640x480
;   - Aspect ratio calculation uses 350 (0x15E) vertically
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; EGA Graphics Controller (ports 3CEh/3CFh):
;   0000:0F93  out 3C4h, 02h   ; Sequencer: Map Mask register select
;   0000:0F96  out 3C5h, 0Fh   ; Map Mask = all planes enabled
;   0000:0F99  out 3CEh, 00h   ; Graphics Controller: Set/Reset register
;   0000:0F9C  out 3CFh, 00h   ; Set/Reset value = 0
;   0000:0F9F  out 3CEh, 01h   ; Enable Set/Reset register
;   0000:0FA2  out 3CFh, 00h   ; Enable Set/Reset = disabled
;   0000:0FA5  out 3CEh, 03h   ; Data Rotate register
;   0000:0FA8  out 3CFh, 00h   ; Data Rotate = 0 (no rotation/function)
;   0000:0FAB  out 3CEh, 04h   ; Read Map Select register
;   0000:0FAE  out 3CFh, 00h   ; Read from plane 0
;   0000:0FB1  out 3CEh, 08h   ; Bit Mask register
;   0000:0FB4  out 3CFh, FFh   ; Bit Mask = all bits enabled
;
; These port sequences configure the EGA graphics controller for direct
; framebuffer access, resetting all GC registers to default values
; before performing drawing operations.
;
; EGA framebuffer segment: A000h
;   First two bytes of seg_0000 contain: 00 A0 (= 0xA000 little-endian)
;   This is loaded via: mov es, word ptr cs:[0x0000]
;   to set ES to the EGA framebuffer segment for pixel operations.
;
; Bytes per scanline: 80 (0x50) -- EGA 640-pixel-wide mode
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=06h  -- Query DeskMate host capabilities
;   0114:00AD  (entry_point) Check bit 15 of result for mode selection
;
; INT E0h, AH=01h  -- Register enhanced driver with host
;   0114:00C8  CX=seg_0000 (drawing code segment), AX=0x01F0 (capabilities)
;   Returns AL=active display ID (stored at cs:[0x3D])
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex (before drawing)
;   0114:010C  DL=display ID; called before dispatching a draw call
;
; INT E0h, AH=4Dh/05  -- Release display mutex (after drawing)
;   0114:0139  DL=display ID; called after a draw call completes
;
; INT E0h, AH=02h  -- Register font/resource pointer
;   0114:0177  BX=0x31 (font table offset), DX=0x35 (resource ptr)
;
; INT ABh  -- Load font data
;   0114:0026  (in data block) Load primary font
;   Used to load font bitmaps for text rendering
;
; INT 21h, AH=51h  -- Get current PSP segment
;   0114:00D3  Returns BX=PSP segment (used to calculate resident size)
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   0114:00E0  DX=paragraphs to keep, installs driver as TSR
;
; INT 21h, AH=48h  -- Allocate DOS memory block
;   0000:0B5D  BX=paragraphs requested (0x0960 = ~38KB for bitmap buffer)
;
; INT 21h, AH=49h  -- Free DOS memory block
;   0000:0D23  ES=segment of block to free
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Dispatch Table (seg_0000:0020, 13 entries) ---
;
;   Index  Offset  Name                          Description
;   -----  ------  ----                          -----------
;   0x00   (tbl)   dmveega_setPixel              Set pixel at (AX,BX) with color CX
;   0x01   (tbl)   dmveega_clipRect              Clip rectangle to viewport bounds
;   0x02   (tbl)   dmveega_scrollRegion          Scroll a rectangular region
;   0x03   (tbl)   dmveega_thunk_11h             Far-call thunk to host func 0x11
;   0x04   (tbl)   dmveega_thunk_10h             Far-call thunk to host func 0x10
;   0x05   (tbl)   dmveega_thunk_6Ah             Far-call thunk to host func 0x6A
;   0x06   (tbl)   dmveega_thunk_69h             Far-call thunk to host func 0x69
;   0x07   (tbl)   dmveega_thunk_64h             Far-call thunk to host func 0x64
;   0x08   (tbl)   dmveega_thunk_63h             Far-call thunk to host func 0x63
;   0x09   (tbl)   dmveega_thunk_59h             Far-call thunk to host func 0x59
;   0x0A   (tbl)   dmveega_thunk_5Bh             Far-call thunk to host func 0x5B
;   0x0B   (tbl)   dmveega_thunk_12h             Far-call thunk to host func 0x12
;   0x0C   (tbl)   dmveega_thunk_13h             Far-call thunk to host func 0x13
;
; --- Drawing Primitives (seg_0000) ---
;
;   Address  Name                        Size  Description
;   -------  ----                        ----  -----------
;   0000:0000  (data: EGA segment)         2   Video segment word = 0xA000
;   0000:0002  (data: scan offset)         2   Scan line origin offset
;   0000:0004  dmveega_dispatchEntry       19  Dispatch: load func ptr, far-call
;   0000:0013  dmveega_hostCallback        12  Callback into host (ES:[0x25])
;   0000:0020  (data: dispatch table)      25  13-entry function offset table
;   0000:0039  dmveega_drawPrimitives    ~4K   Pixel ops, line draw, rect fill, clipping
;   0000:0485  (data: sine table)         170  256-entry sine lookup table
;   0000:053B  dmveega_initFont            68  Initialize font rendering state
;   0000:057D  dmveega_renderChar         352  Render single character glyph
;   0000:07F5  dmveega_drawBitmap         180  Draw bitmap with clipping
;   0000:08C4  dmveega_calcAspectRatio    347  Calculate aspect ratio correction
;   0000:0A28  dmveega_blitBitmap         119  Blit bitmap from offscreen buffer
;   0000:0A9F  dmveega_renderGlyphBitmap  663  Render glyph bitmap with fills
;   0000:0D3C  dmveega_endTextRegion       38  End text region, free resources
;   0000:0E31  dmveega_setupPrintCoords    61  Set up coordinate transform for print
;   0000:0E6E  sub_0000_0E6E             100  Calculate aspect ratio from host params
;   0000:0EE4  dmveega_cursorRenderHelper       Cursor blit/render support (data block)
;   0000:0F3F  dmveega_beginTextInit             Begin text initialization
;   0000:0F61  dmveega_shutdownHelper            Shutdown/unregister (data block)
;   0000:0F91  dmveega_configureGC              Configure GC registers for drawing
;   0000:0FF3  dmveega_colorLookup              Color index to physical value lookup
;   0000:1007  dmveega_coordToByteOffset        Convert X coord to byte/bit offset
;   0000:1027  dmveega_drawHLinePixels          Draw horizontal line pixels
;   0000:1070  dmveega_fillRectPixels           Fill rectangular region with pattern
;   0000:1077  dmveega_sineLookup               Sine/cosine via lookup table
;   0000:10BD  dmveega_multiply32               32-bit multiply helper
;
; --- seg_0113 (enhanced driver name string) ---
;
;   0113:0000  (data + code tail)        16  Epilogue bytes + padding
;
; --- TSR / Dispatcher (seg_0114) ---
;
;   0114:0000  dmveega_dm89Header          64  DM89 module header ("DMVEEGA")
;   0114:0021  (data: font table ptrs)          INT ABh targets + font name strings
;   0114:0040  dmveega_dispatchMode         1  Dispatch mode byte ('X' or 'Y')
;   0114:0043  dmveega_dispatchSetup       94  Set up dispatch frame, resolve func ptr
;   0114:00A1  entry_point                 65  TSR entry: register with host, go resident
;   0114:00E2  dmveega_dispatcher          102 Function dispatcher (save/restore context)
;   0114:0149  dmveega_registerResources    17  Register font/resource pointers with host
;   0114:015A  sub_0114_015A               51  Initialize font table pointer via INT E0h
;
; ========================================================================
; KEY DATA
; ========================================================================
;
; seg_0000:0000  dw 0xA000       ; EGA framebuffer segment
; seg_0114:0000  "DMVEEGA"       ; Driver identifier string
; seg_0114:002A  "DMFONT"        ; Primary font resource name
; seg_0114:0036  "DMVSEGA"       ; Standard driver companion name
; seg_0114:003D  db display_id   ; Active display ID from INT E0h
; seg_0114:003E  db saved_id     ; Saved display ID during dispatch
; seg_0114:0040  db mode         ; 'X'=extended, 'Y'=normal dispatch
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The driver uses EGA mode 10h (640x350x16). Pixels are stored across
;   4 bit planes at segment A000h. The code is nearly identical to
;   DMVEVGA.RES but uses EGA-specific resolution and aspect ratio.
;
; - Key differences from DMVEVGA:
;     * Resolution: 640x350 (vs 640x480)
;     * Aspect ratio: uses 350 (0x15E) for vertical dimension
;     * Slightly smaller code segment (4400 vs 4496 bytes)
;     * One INT ABh call (vs two in CGA enhanced)
;
; - The dispatch_mode byte at cs:[0x40] controls whether the dispatcher
;   passes 2 or 4 coordinate parameters. 'X' (0x58) = extended;
;   'Y' (0x59) = normal.
;
; - The GC configuration routine at 0x0F91 sets up identical EGA
;   Graphics Controller registers to the VGA version, since VGA is
;   backward-compatible with EGA register programming.
;
; - Memory allocation for offscreen buffers uses INT 21h/48h with
;   0x0960 paragraphs (~38KB). Same fallback behavior as VGA/CGA.
;
; ========================================================================

; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (4400 bytes, file 0x0200-0x1330)
; Drawing primitives + dispatch table + font/bitmap rendering
; EGA framebuffer operations at segment A000h
; ------------------------------------------------------------------------
seg_0000:

  ; --- Configuration data ---
  0000:0000  db 00 A0                                           ; dw A000h = EGA framebuffer segment
  0000:0002  db 00 00                                           ; dw 0000h = scanline origin offset

  ; --- dmveega_dispatchEntry + hostCallback + dispatch table ---
  ; Identical structure to DMVEVGA/DMVECGA -- see those files for
  ; detailed byte-level annotation of the dispatch mechanism.
  ; [data/code block 0x0004 through 0x0038]

  ; --- Drawing primitives (offset 0x0039 through ~0x0584) ---
  ; Pixel set, line draw, rectangle fill/clip, scroll region,
  ; host thunks, coordinate conversion, sine lookup.
  ; Structurally identical to DMVEVGA but for EGA 640x350 resolution.

  ; [Large data/code block through 0x0E30]

  ; --- sub_0000_0E6E: Calculate aspect ratio from host parameters ---
  ; Reads host display dimensions from IVT[0x386] workspace.
  ; EGA uses 350 (0x15E) for vertical and 640 (0x280) for horizontal.
sub_0000_0E6E:                                               ; 0000:0E6E
  0000:0E6E  50                push     ax
  0000:0E6F  53                push     bx
  0000:0E70  52                push     dx
  0000:0E71  55                push     bp
  0000:0E72  06                push     es
  0000:0E73  33c0              xor      ax, ax
  0000:0E75  8ec0              mov      es, ax               ; ES = 0000 (IVT)
  0000:0E77  268e068603        mov      es, word ptr es:[0x386] ; ES = DeskMate host seg
  0000:0E7C  33d2              xor      dx, dx
  0000:0E7E  bbe803            mov      bx, 0x3e8            ; BX = 1000
  0000:0E81  b85e01            mov      ax, 0x15e            ; AX = 350 (EGA vertical)
  0000:0E84  f7eb              imul     bx                   ; DX:AX = 350 * 1000
  0000:0E86  268b1e0800        mov      bx, word ptr es:[8]  ; BX = host vertical extent
  0000:0E8B  f7f3              div      bx                   ; AX = (350000 / vert_extent)
  0000:0E8D  50                push     ax                   ; save vertical ratio
  0000:0E8E  33d2              xor      dx, dx
  0000:0E90  bbe803            mov      bx, 0x3e8            ; BX = 1000
  0000:0E93  b88002            mov      ax, 0x280            ; AX = 640 (EGA horizontal)
  0000:0E96  f7eb              imul     bx                   ; DX:AX = 640 * 1000
  0000:0E98  268b1e0600        mov      bx, word ptr es:[6]  ; BX = host horizontal extent
  0000:0E9D  f7fb              idiv     bx                   ; AX = (640000 / horiz_extent)
  0000:0E9F  5b                pop      bx                   ; BX = vertical ratio
  0000:0EA0  07                pop      es

  ; Compare old and new aspect ratio, update if different
  0000:0EA1  83ec04            sub      sp, 4
  0000:0EA4  8bec              mov      bp, sp
  0000:0EA6  50                push     ax
  0000:0EA7  53                push     bx
  0000:0EA8  8d4604            lea      ax, [bp + 4]
  0000:0EAB  16                push     ss
  0000:0EAC  50                push     ax
  0000:0EAD  8d4602            lea      ax, [bp + 2]
  0000:0EB0  16                push     ss
  0000:0EB1  50                push     ax
  0000:0EB2  8bec              mov      bp, sp
  0000:0EB4  b80e00            mov      ax, 0xe             ; func 0x0E = set aspect ratio
  0000:0EB7  26ff1e2500        lcall    es:[0x25]           ; call host function
  0000:0EBC  83c408            add      sp, 8
  0000:0EBF  5b                pop      bx
  0000:0EC0  58                pop      ax
  0000:0EC1  8bec              mov      bp, sp
  0000:0EC3  3b4602            cmp      ax, word ptr [bp + 2]
  0000:0EC6  7505              jne      0xecd               ; -> loc_0000_0ECD

  0000:0EC8  3b5e04            cmp      bx, word ptr [bp + 4]
  0000:0ECB  740f              je       0xedc               ; -> loc_0000_0EDC (no change)

loc_0000_0ECD:                                               ; 0000:0ECD
  0000:0ECD  53                push     bx
  0000:0ECE  50                push     ax
  0000:0ECF  8bec              mov      bp, sp
  0000:0ED1  b80d00            mov      ax, 0xd             ; func 0x0D = notify aspect change
  0000:0ED4  26ff1e2500        lcall    es:[0x25]
  0000:0ED9  83c404            add      sp, 4

loc_0000_0EDC:                                               ; 0000:0EDC
  0000:0EDC  83c404            add      sp, 4
  0000:0EDF  5d                pop      bp
  0000:0EE0  5a                pop      dx
  0000:0EE1  5b                pop      bx
  0000:0EE2  58                pop      ax
  0000:0EE3  c3                ret

  ; --- Data blocks: cursor helper, shutdown, GC config ---
  ; (See DMVECGA.RES for equivalent annotated data blocks)
  0000:0EE4  db 53 52 56 57 55                                  ; cursor render helper
  ; [inline data/code blocks through 0x0F90]

  ; --- dmveega_configureGC: configure EGA graphics controller ---
  ; I/O ports: 3C4h/3C5h (Sequencer), 3CEh/3CFh (Graphics Controller)
  ; Resets to default state for direct framebuffer writes.
  0000:0F91  db 90 50 52 BA C4 03 B0 02 EE 42 B0 0F EE BA CE 03 ; out 3C4h,02h; out 3C5h,0Fh
  0000:0FA1  db B0 00 EE 42 B0 00 EE BA CE 03 B0 01 EE B0 00 42 ; out 3CEh,00h; out 3CFh,00h; ...
  0000:0FB1  db EE BA CE 03 B0 03 EE 42 32 C0 EE BA CE 03 B0 04 ; out 3CEh,03h; out 3CFh,00h; ...
  0000:0FC1  db EE B0 00 42 EE BA CE 03 B0 08 EE 42 B0 FF EE 5A ; out 3CEh,08h; out 3CFh,FFh
  0000:0FD1  db 58 C3                                           ; pop dx,ax; ret

  ; --- dmveega_setGCForPixel ---
  0000:0FD3  db E8 1C 00 50 BA CE 03 B0 00 EE 42 58 EE BA       ; set GC for pixel write
  0000:0FE1  db CE 03 B0 01 EE 42 B0 0F EE BA CE 03 B0 08 EE 42 ; enable set/reset, bit mask
  0000:0FF1  db C3                                              ; ret

  ; --- dmveega_colorLookup ---
  0000:0FF3  db 3C 10 73 0E 53 06 BB 00 A0 8E C3 BB 69 6D 26     ; lookup at A000:6D69
  0000:1001  db D7 07 5B C3                                     ; xlat, ret

  ; --- dmveega_coordToByteOffset ---
  0000:1007  db 8B FB D1 E7 D1 E7 03 FB D1 E7 D1 E7             ; Y * 80 calc
  0000:1011  db D1 E7 D1 E7 8B C8 D1 F9 D1 F9 D1 F9 03 F9 8B C8 ; + X/8
  0000:1021  db 83 E1 07 C3                                     ; bit pos, ret

  ; --- dmveega_drawHLinePixels ---
  0000:1027  db 0A DB                                           ; test count
  0000:1029  db 74 4C 53 56 57 0A                               ; jz, push regs
  ; [pixel draw loop -- EGA planar write via GC registers]
  0000:102F  db C9 74 27 FE CB 74 13 26 8A 05 AC 8A E7 8A F8 D3 ; byte loop
  0000:103F  db E8 22 46 1C EE AA FE CB 75 ED AC 8A E7 D3 E8 22 ; write via OUT
  0000:104F  db C5 22 46 1C EE 26 20 05 EB 1B FE CB 74 0D 26 8A ; tail pixel
  0000:105F  db 05 AC 22 46 1C EE AA FE CB 75 F3 AC 22 C5 22 46 ;
  0000:106F  db 1C EE 26 20 05 5F 5E 5B C3                      ; pop, ret

  ; --- dmveega_sineLookup ---
  0000:1077  db 90 55 83 EC 06 8B EC C7 46 00 20 00 C7 46 02     ; quarter-wave lookup
  0000:1087  db 00 00 C7 46 04 00 00 D1 E2 D1 D1 D1 D3 D1 D0 D1
  0000:1097  db 66 02 D1 56 04 3B C6 72 11 77 04 3B DF 72 0B 2B
  0000:10A7  db DF 1B C6 FF 46 02 83 56 04 00 FF 4E 00 75 D8 EB
  0000:10B7  db 00 8B C8 8B D3 8B 46 04 8B 5E 02 83 C4 06 5D C3

  ; --- dmveega_multiply32 ---
  0000:10CD  db 55 83 EC 10 8B EC 89 46 08 89 5E 0A 89 4E 0C 89
  0000:10DD  db 56 0E C7 46 04 00 00 C7 46 06 00 00 8B 5E 0E 8B
  0000:10ED  db 46 0A BA 00 00 F7 E3 89 46 00 89 56 02 8B 46 08
  0000:10FD  db BA 00 00 F7 E3 01 46 02 11 56 04 83 56 06 00 8B
  0000:110D  db 5E 0C 8B 46 0A BA 00 00 F7 E3 01 46 02 11 56 04
  0000:111D  db 83 56 06 00 8B 46 08 BA 00 00 F7 E3 01 46 04 11
  0000:112D  db 56 06 8B 46 06 8B 5E 04 8B 4E 02

; ------------------------------------------------------------------------
; SEGMENT seg_0113  (16 bytes, file 0x1330-0x1340)
; Code epilogue + padding
; ------------------------------------------------------------------------
seg_0113:

  0113:0000  db 8B 56 00 83 C4 10 5D C3 00 00 00 00 00 00 00 00 ; mov dx,[bp]; add sp,10h; ret

; ------------------------------------------------------------------------
; SEGMENT seg_0114  (400 bytes, file 0x1340-0x14D0)
; TSR startup, dispatch, INT E0h interface
; ------------------------------------------------------------------------
seg_0114:

  ; --- DM89 module header ---
  ; "DMVEEGA" at offset 0x0000
sub_0114_0000:                                               ; 0114:0000
  0114:0000  44                inc      sp                   ; 'D'
  0114:0001  4d                dec      bp                   ; 'M'
  0114:0002  56                push     si                   ; 'V'
  0114:0003  45                inc      bp                   ; 'E'
  0114:0004  45                inc      bp                   ; 'E'
  0114:0005  47                inc      di                   ; 'G'
  0114:0006  41                inc      cx                   ; 'A'
  0114:0007  00e2              add      dl, ah
  0114:0009  0014              add      byte ptr [si], dl    ; RELOC->seg_0114
  0114:000B  014901            add      word ptr [bx + di + 1], cx
  0114:000E  1401              adc      al, 1                ; RELOC->seg_0114
  ; [reserved/padding through 0x0020]
  0114:0010  0000              add      byte ptr [bx + si], al
  0114:0012  0000              add      byte ptr [bx + si], al
  0114:0014  0000              add      byte ptr [bx + si], al
  0114:0016  0000              add      byte ptr [bx + si], al
  0114:0018  0000              add      byte ptr [bx + si], al
  0114:001A  0000              add      byte ptr [bx + si], al
  0114:001C  0000              add      byte ptr [bx + si], al
  0114:001E  0000              add      byte ptr [bx + si], al

  ; --- Font table: INT ABh entry ---
  0114:0020  0000              add      byte ptr [bx + si], al
  0114:0022  0313              add      dx, word ptr [bp + di]
  0114:0024  01cd              add      bp, cx
  0114:0026  ab                stosw    word ptr es:[di], ax ; INT ABh: load font
  0114:0027  badc44            mov      dx, 0x44dc
  0114:002A  4d                dec      bp                   ; 'M' ("DMFONT")
  0114:002B  46                inc      si
  0114:002C  4f                dec      di
  0114:002D  4e                dec      si
  0114:002E  54                push     sp
  0114:002F  0000              add      byte ptr [bx + si], al
  0114:0031  cdab              int      0xab                 ; INT ABh: load EGA font
  0114:0033  badc44            mov      dx, 0x44dc
  0114:0036  4d                dec      bp                   ; 'M' ("DMVSEGA")
  0114:0037  56                push     si
  0114:0038  53                push     bx
  0114:0039  45                inc      bp
  0114:003A  47                inc      di
  0114:003B  41                inc      cx
  0114:003C  0000              add      byte ptr [bx + si], al
  0114:003E  0000              add      byte ptr [bx + si], al

  ; --- dmveega_dispatchSetup ---
  0114:0040  005306            add      byte ptr [bp + di + 6], dl ; dispatch mode byte area
  0114:0043  55                push     bp
  0114:0044  83ec0a            sub      sp, 0xa
  0114:0047  8bec              mov      bp, sp
  0114:0049  52                push     dx
  0114:004A  2e8a164000        mov      dl, byte ptr cs:[0x40]
  0114:004F  885609            mov      byte ptr [bp + 9], dl
  0114:0052  2ec41e3100        les      bx, ptr cs:[0x31]
  0114:0057  80fa58            cmp      dl, 0x58
  0114:005A  7506              jne      0x62
  0114:005C  d1e0              shl      ax, 1
  0114:005E  d1e0              shl      ax, 1
  0114:0060  03d8              add      bx, ax

loc_0114_0062:
  0114:0062  5a                pop      dx
  0114:0063  8c4602            mov      word ptr [bp + 2], es
  0114:0066  895e00            mov      word ptr [bp], bx
  0114:0069  8c4e06            mov      word ptr [bp + 6], cs
  0114:006C  bb9400            mov      bx, 0x94
  0114:006F  895e04            mov      word ptr [bp + 4], bx
  0114:0072  50                push     ax
  0114:0073  b80000            mov      ax, 0
  0114:0076  8ec0              mov      es, ax
  0114:0078  26a18603          mov      ax, word ptr es:[0x386]
  0114:007C  8ec0              mov      es, ax
  0114:007E  58                pop      ax
  0114:007F  8b5e0e            mov      bx, word ptr [bp + 0xe]
  0114:0082  52                push     dx
  0114:0083  8a5609            mov      dl, byte ptr [bp + 9]
  0114:0086  80fa58            cmp      dl, 0x58
  0114:0089  7506              jne      0x91

  0114:008B  8b4610            mov      ax, word ptr [bp + 0x10]
  0114:008E  8b6e0a            mov      bp, word ptr [bp + 0xa]

loc_0114_0091:
  0114:0091  5a                pop      dx
  0114:0092  45                inc      bp
  0114:0093  cb                retf

  0114:0094  db 83 C4 0A 2E 80 3E 40 00 58 75 01 4D CB          ; cleanup + retf

  ; --- entry_point: TSR installation ---
entry_point:                                                 ; 0114:00A1
  0114:00A1  0e                push     cs
  0114:00A2  07                pop      es
  0114:00A3  bb0000            mov      bx, 0
  0114:00A6  268c5f20          mov      word ptr es:[bx + 0x20], ds
  0114:00AA  b80006            mov      ax, 0x600
  0114:00AD  cde0              int      0xe0                 ; INT E0h/06h: query host
  0114:00AF  250080            and      ax, 0x8000
  0114:00B2  b8f001            mov      ax, 0x1f0
  0114:00B5  26c606400059      mov      byte ptr es:[0x40], 0x59 ; 'Y' default
  0114:00BB  7508              jne      0xc5
  0114:00BD  b8ff01            mov      ax, 0x1ff
  0114:00C0  26fe0e4000        dec      byte ptr es:[0x40]   ; -> 'X' extended

loc_0114_00C5:
  0114:00C5  b90000            mov      cx, 0                ; RELOC->seg_0000
  0114:00C8  cde0              int      0xe0                 ; INT E0h/01h: register
  0114:00CA  26a23d00          mov      byte ptr es:[0x3d], al
  0114:00CE  e88900            call     0x15a                ; init fonts
  0114:00D1  b451              mov      ah, 0x51
  0114:00D3  cd21              int      0x21                 ; get PSP
  0114:00D5  4b                dec      bx
  0114:00D6  8ec3              mov      es, bx
  0114:00D8  268b160300        mov      dx, word ptr es:[3]
  0114:00DD  b80031            mov      ax, 0x3100
  0114:00E0  cd21              int      0x21                 ; TSR

  ; --- dmveega_dispatcher ---
  0114:00E2  53                push     bx
  0114:00E3  8bdc              mov      bx, sp
  0114:00E5  83e301            and      bx, 1
  0114:00E8  2be3              sub      sp, bx
  0114:00EA  53                push     bx
  0114:00EB  51                push     cx
  0114:00EC  56                push     si
  0114:00ED  57                push     di
  0114:00EE  55                push     bp
  0114:00EF  1e                push     ds
  0114:00F0  06                push     es
  0114:00F1  9c                pushf
  0114:00F2  fc                cld
  0114:00F3  3d0d00            cmp      ax, 0xd
  0114:00F6  7205              jb       0xfd
  0114:00F8  b8ffff            mov      ax, 0xffff
  0114:00FB  eb40              jmp      0x13d

loc_0114_00FD:
  0114:00FD  50                push     ax
  0114:00FE  2ea03d00          mov      al, byte ptr cs:[0x3d]
  0114:0102  3cff              cmp      al, 0xff
  0114:0104  7409              je       0x10f
  0114:0106  52                push     dx
  0114:0107  8ad0              mov      dl, al
  0114:0109  b8044d            mov      ax, 0x4d04           ; acquire mutex
  0114:010C  cde0              int      0xe0
  0114:010E  5a                pop      dx

loc_0114_010F:
  0114:010F  2ea23e00          mov      byte ptr cs:[0x3e], al
  0114:0113  58                pop      ax
  0114:0114  2eff363e00        push     word ptr cs:[0x3e]
  0114:0119  bb1301            mov      bx, 0x113            ; RELOC->seg_0113
  0114:011C  8ec3              mov      es, bx
  0114:011E  0e                push     cs
  0114:011F  5b                pop      bx
  0114:0120  9a04000000        lcall    0, 4                 ; RELOC->seg_0000:0004
  0114:0125  2e8f063e00        pop      word ptr cs:[0x3e]
  0114:012A  50                push     ax
  0114:012B  2ea03e00          mov      al, byte ptr cs:[0x3e]
  0114:012F  3cff              cmp      al, 0xff
  0114:0131  7409              je       0x13c
  0114:0133  52                push     dx
  0114:0134  8ad0              mov      dl, al
  0114:0136  b8054d            mov      ax, 0x4d05           ; release mutex
  0114:0139  cde0              int      0xe0
  0114:013B  5a                pop      dx

loc_0114_013C:
  0114:013C  58                pop      ax

loc_0114_013D:
  0114:013D  9d                popf
  0114:013E  07                pop      es
  0114:013F  1f                pop      ds
  0114:0140  5d                pop      bp
  0114:0141  5f                pop      di
  0114:0142  5e                pop      si
  0114:0143  59                pop      cx
  0114:0144  5b                pop      bx
  0114:0145  03e3              add      sp, bx
  0114:0147  5b                pop      bx
  0114:0148  cb                retf

  ; --- dmveega_registerResources ---
  0114:0149  db 50 06 52 0E 07 BA 35 00 B8 07 02 CD E0 5A 07 58
  0114:0159  db CB

  ; --- sub_0114_015A: init font table ---
sub_0114_015A:
  0114:015A  53                push     bx
  0114:015B  52                push     dx
  0114:015C  26803e400059      cmp      byte ptr es:[0x40], 0x59
  0114:0162  740a              je       0x16e
  0114:0164  bb3500            mov      bx, 0x35
  0114:0167  83c303            add      bx, 3
  0114:016A  26c60744          mov      byte ptr es:[bx], 0x44

loc_0114_016E:
  0114:016E  bb3100            mov      bx, 0x31
  0114:0171  ba3500            mov      dx, 0x35
  0114:0174  b80602            mov      ax, 0x206
  0114:0177  cde0              int      0xe0                 ; INT E0h/02h: register
  0114:0179  48                dec      ax
  0114:017A  0bc0              or       ax, ax
  0114:017C  750c              jne      0x18a
  0114:017E  26ff1e3100        lcall    es:[0x31]
  0114:0183  26891e3100        mov      word ptr es:[0x31], bx
  0114:0188  33c0              xor      ax, ax

loc_0114_018A:
  0114:018A  5a                pop      dx
  0114:018B  5b                pop      bx
  0114:018C  c3                ret
  0114:018D  db 00 00 00                                     ; padding

; ------------------------------------------------------------------------
; SEGMENT seg_012D  (2 bytes, file 0x14D0-0x14D2)
; Stack segment
; ------------------------------------------------------------------------
seg_012D:

  012D:0000  db 00 00                                           ; initial stack
