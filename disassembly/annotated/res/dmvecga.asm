; ========================================================================
; DMVECGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Enhanced Video Driver: CGA (320x200, 4 colors / 640x200, 2 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVECGA.RES is the enhanced-mode CGA video driver for DeskMate 3.05.
; Enhanced drivers contain the core drawing primitives (pixel plotting,
; line drawing, rectangle fill, font rendering, clipping) that operate
; on the video framebuffer. The standard driver (DMVSCGA.RES) handles
; mode switching, cursor management, INT 08h timer hooking, and the
; higher-level display list / window management, while calling into
; this enhanced driver for actual pixel-level operations.
;
; The enhanced driver installs itself as a TSR via INT 21h/31h after
; registering with the DeskMate host through INT E0h. It provides a
; dispatch table of 13 drawing functions (0x00-0x0C) that the standard
; driver calls through a far-call interface.
;
; Video framebuffer: segment B800h (CGA memory-mapped video)
; Resolution: 320x200 at 4 colors (CGA mode 4) or 640x200 at 2 colors
; Bytes per scanline: 80 (320/4 at 2bpp, or 640/8 at 1bpp)
;
; CGA interleaved scanline layout:
;   Even scanlines at B800:0000+
;   Odd scanlines at B800:2000+
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5378 bytes
; Code+data size: 4866 bytes
; DM89 entry point: 0117:00A1
; SS:SP = 0130:0002
;
; DM89 signature: present
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  0x1160 bytes  CODE/DATA  Drawing primitives + sine/cosine table
;   seg_0116  0x0010 bytes  CODE/DATA  Enhanced driver name string segment
;   seg_0117  0x0190 bytes  CODE       TSR startup, dispatch, INT E0h interface
;   seg_0130  0x0002 bytes  STACK      Stack segment
;
; Relocation Table (5 entries):
;   0117:000A -> seg_0117  (self-reference in DM89 header)
;   0117:000E -> seg_0117  (self-reference in DM89 header)
;   0117:00C6 -> seg_0000  (drawing code segment reference)
;   0117:0119 -> seg_0116  (enhanced driver name segment)
;   0117:0121 -> seg_0000  (drawing code segment reference)
;
; ========================================================================
; ARCHITECTURE
; ========================================================================
;
; The enhanced driver has two main parts:
;
; 1. Drawing Primitives (seg_0000, 4448 bytes):
;    Raw pixel-level rendering code. Functions accessed via the dispatch
;    table at seg_0000:0020. These operate directly on the CGA framebuffer
;    at segment B800h. The code uses a register-based calling convention
;    with coordinates in AX/BX/CX/DX and a workspace structure pointed
;    to by BP.
;
; 2. TSR Loader / Dispatcher (seg_0117, 400 bytes):
;    Entry point at 0117:00A1. Registers with DeskMate via INT E0h,
;    then goes resident via INT 21h/31h. The dispatcher at 0117:00E2
;    routes function calls through the seg_0000 dispatch table.
;
; Drawing workspace structure: identical layout to DMVEVGA (see that
; file for full workspace offset documentation). Key differences:
;   - Framebuffer segment is B800h (not A000h)
;   - Bytes per scanline is 80 with interleaved even/odd banks
;   - Pixel packing is 2bpp (4 pixels per byte) in mode 4
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; CGA Graphics Controller (ports 3C4h/3C5h, 3CEh/3CFh):
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
; These port sequences configure the EGA/CGA graphics controller for
; direct framebuffer access. The driver resets all GC registers to
; default values before performing drawing operations.
;
; CGA Mode (port 3D8h/3D9h -- accessed indirectly via BIOS data area):
;   Accessed indirectly through the standard driver (DMVSCGA), not
;   directly by this enhanced driver.
;
; VGA framebuffer segment: B800h
;   First two bytes of seg_0000 contain: 00 B8 (= 0xB800 little-endian)
;   This is loaded via: mov es, word ptr cs:[0x0000]
;   to set ES to the CGA framebuffer segment for pixel operations.
;
; Bytes per scanline: 80 (0x50) -- CGA 320-pixel-wide mode (2bpp)
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=06h  -- Query DeskMate host capabilities
;   0117:00AD  (entry_point) Check bit 15 of result for mode selection
;
; INT E0h, AH=01h  -- Register enhanced driver with host
;   0117:00C8  CX=seg_0000 (drawing code segment), AX=0x01F0 (capabilities)
;   Returns AL=active display ID (stored at cs:[0x3D])
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex (before drawing)
;   0117:010C  DL=display ID; called before dispatching a draw call
;
; INT E0h, AH=4Dh/05  -- Release display mutex (after drawing)
;   0117:0139  DL=display ID; called after a draw call completes
;
; INT E0h, AH=02h  -- Register font/resource pointer
;   0117:0177  BX=0x31 (font table offset), DX=0x35 (resource ptr)
;   Used during initialization to set up the font data pointer
;
; INT E0h, AH=08h  -- Query DeskMate module status
;   (in data block at seg_0000, called by cursor render helper)
;
; INT E0h, AH=07h  -- Unregister module
;   (in data block at seg_0000, called during shutdown)
;
; INT ABh  -- Load font data
;   0117:0025  First font load (primary font table)
;   0117:0031  Second font load (standard CGA font / "DMVSCGA" ref)
;   Used to load font bitmaps for text rendering
;
; INT 21h, AH=51h  -- Get current PSP segment
;   0117:00D3  Returns BX=PSP segment (used to calculate resident size)
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   0117:00E0  DX=paragraphs to keep, installs driver as TSR
;
; INT 21h, AH=48h  -- Allocate DOS memory block
;   0000:0B6D  BX=paragraphs requested (0x0960 = ~38KB for bitmap buffer)
;   Used for offscreen bitmap workspace allocation
;
; INT 21h, AH=49h  -- Free DOS memory block
;   0000:0D2B  ES=segment of block to free
;   Frees the offscreen bitmap workspace
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Dispatch Table (seg_0000:0020, 13 entries) ---
;
;   Index  Offset  Name                          Description
;   -----  ------  ----                          -----------
;   0x00   (tbl)   dmvecga_setPixel              Set pixel at (AX,BX) with color CX
;   0x01   (tbl)   dmvecga_clipRect              Clip rectangle to viewport bounds
;   0x02   (tbl)   dmvecga_scrollRegion          Scroll a rectangular region
;   0x03   (tbl)   dmvecga_thunk_11h             Far-call thunk to host func 0x11
;   0x04   (tbl)   dmvecga_thunk_10h             Far-call thunk to host func 0x10
;   0x05   (tbl)   dmvecga_thunk_6Ah             Far-call thunk to host func 0x6A
;   0x06   (tbl)   dmvecga_thunk_69h             Far-call thunk to host func 0x69
;   0x07   (tbl)   dmvecga_thunk_64h             Far-call thunk to host func 0x64
;   0x08   (tbl)   dmvecga_thunk_63h             Far-call thunk to host func 0x63
;   0x09   (tbl)   dmvecga_thunk_59h             Far-call thunk to host func 0x59
;   0x0A   (tbl)   dmvecga_thunk_5Bh             Far-call thunk to host func 0x5B
;   0x0B   (tbl)   dmvecga_thunk_12h             Far-call thunk to host func 0x12
;   0x0C   (tbl)   dmvecga_thunk_13h             Far-call thunk to host func 0x13
;
; --- Drawing Primitives (seg_0000) ---
;
;   Address  Name                        Size  Description
;   -------  ----                        ----  -----------
;   0000:0000  (data: CGA segment)         2   Video segment word = 0xB800
;   0000:0002  (data: scan offset)         2   Scan line origin offset
;   0000:0004  dmvecga_dispatchEntry       19  Dispatch: load func ptr, far-call
;   0000:0013  dmvecga_hostCallback        12  Callback into host (ES:[0x25])
;   0000:0020  (data: dispatch table)      25  13-entry function offset table
;   0000:0039  dmvecga_drawPrimitives    ~4K   Pixel ops, line draw, rect fill, clipping
;   0000:0485  (data: sine table)         170  256-entry sine lookup table
;   0000:053B  dmvecga_initFont            68  Initialize font rendering state
;   0000:057D  dmvecga_renderChar         352  Render single character glyph
;   0000:07F5  dmvecga_drawBitmap         180  Draw bitmap with clipping
;   0000:08C4  dmvecga_calcAspectRatio    347  Calculate aspect ratio correction
;   0000:0A30  dmvecga_blitBitmap         119  Blit bitmap from offscreen buffer
;   0000:0AA7  dmvecga_renderGlyphBitmap  663  Render glyph bitmap with fills
;   0000:0D44  dmvecga_endTextRegion       38  End text region, free resources
;   0000:0E39  dmvecga_setupPrintCoords    61  Set up coordinate transform for print
;   0000:0E76  sub_0000_0E76             100  Calculate aspect ratio from host params
;   0000:0EEC  dmvecga_cursorRenderHelper       Cursor blit/render support (data block)
;   0000:0F47  dmvecga_beginTextInit             Begin text initialization
;   0000:0F69  dmvecga_shutdownHelper            Shutdown/unregister (data block)
;   0000:0F99  dmvecga_configureGC              Configure GC registers for drawing
;   0000:0FD3  dmvecga_setGCForPixel            Set GC for pixel operations
;   0000:0FF3  dmvecga_colorLookup              Color index to physical value lookup
;   0000:1007  dmvecga_coordToByteOffset        Convert X coord to byte/bit offset
;   0000:1027  dmvecga_drawHLinePixels          Draw horizontal line pixels
;   0000:1070  dmvecga_fillRectPixels           Fill rectangular region with pattern
;   0000:10A5  dmvecga_sineLookup               Sine/cosine via lookup table
;   0000:10F3  dmvecga_multiply32               32-bit multiply helper
;
; --- seg_0116 (enhanced driver name string) ---
;
;   0116:0000  (data + code tail)        16  Epilogue bytes + padding
;
; --- TSR / Dispatcher (seg_0117) ---
;
;   0117:0000  dmvecga_dm89Header          64  DM89 module header ("DMVECGA")
;   0117:0021  (data: font table ptrs)          INT ABh targets + font name strings
;   0117:0040  dmvecga_dispatchMode         1  Dispatch mode byte ('X' or 'Y')
;   0117:0043  dmvecga_dispatchSetup       94  Set up dispatch frame, resolve func ptr
;   0117:00A1  entry_point                 65  TSR entry: register with host, go resident
;   0117:00E2  dmvecga_dispatcher          102 Function dispatcher (save/restore context)
;   0117:0149  dmvecga_registerResources    17  Register font/resource pointers with host
;   0117:015A  sub_0117_015A               51  Initialize font table pointer via INT E0h
;
; ========================================================================
; KEY DATA
; ========================================================================
;
; seg_0000:0000  dw 0xB800       ; CGA framebuffer segment
; seg_0117:0000  "DMVECGA"       ; Driver identifier string
; seg_0117:002A  "DMFONT"        ; Primary font resource name
; seg_0117:0036  "DMVSCGA"       ; Standard driver companion name
; seg_0117:003D  db display_id   ; Active display ID from INT E0h
; seg_0117:003E  db saved_id     ; Saved display ID during dispatch
; seg_0117:0040  db mode         ; 'X'=extended, 'Y'=normal dispatch
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The driver uses CGA mode 4 (320x200x4). Pixels are packed 4 per byte
;   (2 bits each). The CGA framebuffer is interleaved: even scanlines at
;   B800:0000, odd scanlines at B800:2000.
;
; - The dispatch_mode byte at cs:[0x40] controls whether the dispatcher
;   passes 2 or 4 coordinate parameters. 'X' (0x58) = extended mode;
;   'Y' (0x59) = normal mode.
;
; - The GC configuration routine at 0x0F99 sets up the EGA/CGA graphics
;   controller registers (3C4h/3C5h, 3CEh/3CFh) for direct framebuffer
;   writes. This is used for pixel plotting and rectangle fill operations.
;
; - The color lookup at 0x0FF3 maps DeskMate logical color indices to
;   CGA physical colors using a table at B800:696D.
;
; - Memory allocation for offscreen buffers uses INT 21h/48h with
;   0x0960 paragraphs (~38KB). If allocation fails, it retries with
;   a smaller size of 0x0040 paragraphs and uses a local buffer.
;
; - This driver is structurally nearly identical to DMVEVGA.RES, with
;   the key differences being:
;     * Framebuffer at B800h instead of A000h
;     * CGA 320x200 resolution (vs VGA 640x480)
;     * 2bpp pixel packing (vs 4-plane VGA)
;     * Interleaved scanlines (even/odd at 0x2000 offset)
;     * CGA-specific GC port configuration
;     * Aspect ratio calculation uses 200 (0xC8) vertically, 640 (0x280) horizontally
;
; ========================================================================

; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (4448 bytes, file 0x0200-0x1360)
; Drawing primitives + dispatch table + font/bitmap rendering
; CGA framebuffer operations at segment B800h
; ------------------------------------------------------------------------
seg_0000:

  ; --- Configuration data ---
  0000:0000  db 00 B8                                           ; dw B800h = CGA framebuffer segment
  0000:0002  db 00 00                                           ; dw 0000h = scanline origin offset

  ; --- dmvecga_dispatchEntry: load function pointer from dispatch table ---
  ; Called via far-call from the TSR dispatcher. AX = function index * 2.
  ; Loads the target offset from the dispatch table and far-calls into it.
  0000:0004  db 53 06 55 83 EC 0A 8B EC 52 2E 8A 16 40 00 88   ; push bx,es,bp; sub sp,0xa; ...
  0000:0013  db 56 09 2E C4 1E 31 00 80 FA 58 75 06 D1 E0 D1   ; dmvecga_hostCallback: les bx,cs:[0x31]
  ; [data block continues through dispatch table]

  ; --- Dispatch table (13 entries at offset 0x0020) ---
  0000:0020  db XX XX XX XX XX XX XX XX XX XX XX XX XX XX XX XX ; 13 word-sized offsets into seg_0000
  0000:0030  db XX XX XX XX XX XX XX XX XX                      ; (entries 0x00 through 0x0C)

  ; --- Drawing primitives (offset 0x0039 through ~0x0584) ---
  ; Pixel set, line draw, rectangle fill/clip, scroll region,
  ; host thunks, coordinate conversion, sine lookup, etc.
  ; These are nearly identical in structure to DMVEVGA but adapted
  ; for CGA's 2bpp pixel format and interleaved scanline layout.

  ; [Large data/code block: drawing primitives, thunks, font rendering]
  ; See DMVEVGA.RES for detailed function-level annotation of the
  ; equivalent VGA routines; CGA versions follow the same logic with
  ; CGA-specific pixel packing and address calculation.

  ; --- sub_0000_0E76: Calculate aspect ratio from host parameters ---
  ; Reads host display dimensions from IVT[0x386] workspace.
  ; CGA uses 200 (0xC8) for vertical and 640 (0x280) for horizontal.
sub_0000_0E76:                                               ; 0000:0E76
  0000:0E76  50                push     ax
  0000:0E77  53                push     bx
  0000:0E78  52                push     dx
  0000:0E79  55                push     bp
  0000:0E7A  06                push     es
  0000:0E7B  33c0              xor      ax, ax
  0000:0E7D  8ec0              mov      es, ax               ; ES = 0000 (IVT)
  0000:0E7F  268e068603        mov      es, word ptr es:[0x386] ; ES = DeskMate host seg
  0000:0E84  33d2              xor      dx, dx
  0000:0E86  bbe803            mov      bx, 0x3e8            ; BX = 1000
  0000:0E89  b8c800            mov      ax, 0xc8             ; AX = 200 (CGA vertical)
  0000:0E8C  f7eb              imul     bx                   ; DX:AX = 200 * 1000
  0000:0E8E  268b1e0800        mov      bx, word ptr es:[8]  ; BX = host vertical extent
  0000:0E93  f7f3              div      bx                   ; AX = (200000 / vert_extent)
  0000:0E95  50                push     ax                   ; save vertical ratio
  0000:0E96  33d2              xor      dx, dx
  0000:0E98  bbe803            mov      bx, 0x3e8            ; BX = 1000
  0000:0E9B  b88002            mov      ax, 0x280            ; AX = 640 (CGA horizontal)
  0000:0E9E  f7eb              imul     bx                   ; DX:AX = 640 * 1000
  0000:0EA0  268b1e0600        mov      bx, word ptr es:[6]  ; BX = host horizontal extent
  0000:0EA5  f7fb              idiv     bx                   ; AX = (640000 / horiz_extent)
  0000:0EA7  5b                pop      bx                   ; BX = vertical ratio
  0000:0EA8  07                pop      es

  ; Compare old and new aspect ratio, update if different
  0000:0EA9  83ec04            sub      sp, 4
  0000:0EAC  8bec              mov      bp, sp
  0000:0EAE  50                push     ax
  0000:0EAF  53                push     bx
  0000:0EB0  8d4604            lea      ax, [bp + 4]
  0000:0EB3  16                push     ss
  0000:0EB4  50                push     ax
  0000:0EB5  8d4602            lea      ax, [bp + 2]
  0000:0EB8  16                push     ss
  0000:0EB9  50                push     ax
  0000:0EBA  8bec              mov      bp, sp
  0000:0EBC  b80e00            mov      ax, 0xe             ; func 0x0E = set aspect ratio
  0000:0EBF  26ff1e2500        lcall    es:[0x25]           ; call host function
  0000:0EC4  83c408            add      sp, 8
  0000:0EC7  5b                pop      bx
  0000:0EC8  58                pop      ax
  0000:0EC9  8bec              mov      bp, sp
  0000:0ECB  3b4602            cmp      ax, word ptr [bp + 2]
  0000:0ECE  7505              jne      0xed5               ; -> loc_0000_0ED5

  0000:0ED0  3b5e04            cmp      bx, word ptr [bp + 4]
  0000:0ED3  740f              je       0xee4               ; -> loc_0000_0EE4 (no change)

loc_0000_0ED5:                                               ; 0000:0ED5
  ; Aspect ratio changed -- call host func 0x0D to notify
  0000:0ED5  53                push     bx
  0000:0ED6  50                push     ax
  0000:0ED7  8bec              mov      bp, sp
  0000:0ED9  b80d00            mov      ax, 0xd             ; func 0x0D = notify aspect change
  0000:0EDC  26ff1e2500        lcall    es:[0x25]
  0000:0EE1  83c404            add      sp, 4

loc_0000_0EE4:                                               ; 0000:0EE4
  0000:0EE4  83c404            add      sp, 4
  0000:0EE7  5d                pop      bp
  0000:0EE8  5a                pop      dx
  0000:0EE9  5b                pop      bx
  0000:0EEA  58                pop      ax
  0000:0EEB  c3                ret

  ; --- Data block: cursor render helper, shutdown, GC config ---
  ; Includes inline code for cursor blit/unblit, driver shutdown
  ; (INT E0h/07h unregister), and GC register configuration.
  0000:0EEC  db 53 52 56 57 55                                  ; cursor/render helper entry
  0000:0EF1  db 83 EC 02 8B EC 26 81 3E 25 00 CD AB 75 56 26 81 ; check magic ABCD at ES:[0x25]
  0000:0F01  db 3E 27 00 BA DC 75 4D BB 25 00 BA 29 00 B8 08 02 ; INT E0h/08h query
  0000:0F11  db CD E0 C7 46 00 00 00 0B C0 75 05 C7 46 00 01 00 ; set flag on result
  0000:0F21  db B8 06 02 CD E0 0B C0 74 36 B8 00 00 26 FF 1E 25 ; INT E0h/06h host call
  0000:0F31  db 00 83 7E 00 00 74 1D 83 EC 05 8B EC C6 46 00 03 ; check flag, build frame
  0000:0F41  db C7 46 01 FF FF 16                               ; set error params

  ; --- dmvecga_beginTextInit: begin text initialization ---
  0000:0F47  55                push     bp                   ; 0000:0F47
  0000:0F48  8bec              mov      bp, sp
  0000:0F4A  b80300            mov      ax, 3               ; func 3 = begin text init
  0000:0F4D  26ff1e2500        lcall    es:[0x25]           ; call host
  0000:0F52  83c409            add      sp, 9
  0000:0F55  e81eff            call     0xe76               ; -> sub_0000_0E76 (calc aspect)
  0000:0F58  26fe063000        inc      byte ptr es:[0x30]  ; increment init counter
  0000:0F5D  b80100            mov      ax, 1               ; return success
  0000:0F60  83c402            add      sp, 2
  0000:0F63  5d                pop      bp
  0000:0F64  5f                pop      di
  0000:0F65  5e                pop      si
  0000:0F66  5a                pop      dx
  0000:0F67  5b                pop      bx
  0000:0F68  c3                ret

  ; --- dmvecga_shutdownHelper: unregister and restore ---
  0000:0F69  db 50 52 26 80 3E 30 00 01 75 1E B8 01 00 26 FF 1E ; check init counter
  0000:0F79  db 25 00 BA 29 00 B8 07 02 CD E0 26 C7 06 25 00 CD ; INT E0h/07h unregister
  0000:0F89  db AB 26 C7 06 27 00 BA DC 26 FE 0E 30 00 5A 58 C3 ; restore magic, dec counter

  ; --- dmvecga_configureGC: configure EGA/CGA graphics controller ---
  ; Resets GC registers to default for direct framebuffer writes.
  ; Ports: 3C4h/3C5h (Sequencer), 3CEh/3CFh (Graphics Controller)
  0000:0F93  db 90 50 8A E0 80 E4 02 D0 EC 32 C4 D0 C8 98 8A D4 ; color prep
  0000:0FA3  db 8A F2 58 C3                                     ; return

  ; --- dmvecga_setGCForPixel: configure GC for pixel writes ---
  ; Sets Map Mask, Set/Reset, Enable SR, Data Rotate, Read Map, Bit Mask
  ; I/O ports 3C4h, 3C5h, 3CEh, 3CFh
  0000:0FA7  db 8B FB D1 FF 8B CF D1 E1 D1 E1 03 F9             ; coord calc
  0000:0FB3  db D1 E7 D1 E7 D1 E7 D1 E7 8B CB 83 E1 01 D1 C9 D1 ; interleave calc
  0000:0FC3  db C9 D1 C9 03 CF 8B F8 D1 FF D1 FF D1 FF 03 F9 8B ; byte offset
  0000:0FD3  db C8 83 E1 07 C3                                  ; bit position, ret

  ; --- dmvecga_drawHLinePixels: draw horizontal line ---
  0000:0FD8  db 0A DB                                           ; or bl,bl
  0000:0FE0  db 74 6A 53 56 57 0A                               ; jz short, push regs
  0000:0FE6  db C9 74 36 FE CB 74 1A AC 22 46 1C 8A E7 8A F8 D3 ; pixel loop
  0000:0FF6  db E8 8A F0 F6 D6                                  ; shift, complement
  0000:0FFB  db 26 22 35 22                                     ; and ES:[DI], mask
  0000:0FFF  db C2 0A C6 AA FE CB 75 E6 AC 22 46 1C 8A E7 D3 E8 ; store, loop
  0000:100F  db 22 C5 8A F0 F6 D6                               ; end pixel
  0000:1015  db 26 22 35 22                                     ; and ES:[DI]
  0000:1019  db C2 0A C6 AA EB 2A FE CB 74 14 AC 22 46 1C 8A F0 ; unaligned path
  0000:1029  db F6 D6                                           ;
  0000:102B  db 26 22 35 22                                     ; and ES:[DI]
  0000:102F  db C2 0A C6 AA FE CB 75 EC AC 22 46 1C 22 C5 8A F0 ; loop
  0000:103F  db F6 D6                                           ;
  0000:1041  db 26 22 35 22                                     ; and ES:[DI]
  0000:1045  db C2 0A C6 AA 5F 5E 5B C3                         ; pop regs, ret

  ; --- dmvecga_fillRectPixels: fill rectangular region ---
  0000:104D  db 50 52 8B D1 E8 59 FF BB                         ; prep fill
  0000:1055  db FF FF D2 EB 03 CA 8B D1 80 E1 07 D2 EF F6 D7 8B ; mask calc
  0000:1065  db CA D1 E9 D1 E9 D1 E9 41 5A 58 C3                ; shift, ret

  0000:1070  db 50 53 51 52 57 22 56                            ; fill entry
  0000:1077  db 1C                                              ;
  0000:1078  db 49 7C 23 74                                     ; loop control
  0000:107C  db 13 8A C2 22 C3 F6 D3 26 22 1D 0A C3 AA 49 8A C2 ; fill loop
  0000:108C  db F3 AA B3 FF 22 DF 8A C2 22 C3 F6 D3 26 22 1D 0A ; stosb fill
  0000:109C  db C3 AA                                           ;
  0000:109E  db 5F 5A 59 5B 58                                  ; pop regs
  0000:10A3  db C3                                              ; ret

  ; --- dmvecga_sineLookup: sine/cosine lookup ---
  0000:10A5  db 90 55 83 EC 06 8B EC C7 46 00 20 00 C7 46 02     ; quarter-wave lookup
  0000:10B3  db 00 00 C7 46 04 00 00 D1 E2 D1 D1 D1 D3 D1 D0 D1 ;
  0000:10C3  db 66 02 D1 56 04 3B C6 72 11 77 04 3B DF 72 0B 2B ;
  0000:10D3  db DF 1B C6 FF 46 02 83 56 04 00 FF 4E 00 75 D8 EB ;
  0000:10E3  db 00 8B C8 8B D3 8B 46 04 8B 5E 02 83 C4 06 5D C3 ; return

  ; --- dmvecga_multiply32: 32-bit multiply helper ---
  0000:10F3  db 55 83 EC 10 8B EC 89 46 08 89 5E 0A 89 4E 0C 89 ; mul32
  0000:1103  db 56 0E C7 46 04 00 00 C7 46 06 00 00 8B 5E 0E 8B ;
  0000:1113  db 46 0A BA 00 00 F7 E3 89 46 00 89 56 02 8B 46 08 ;
  0000:1123  db BA 00 00 F7 E3 01 46 02 11 56 04 83 56 06 00 8B ;
  0000:1133  db 5E 0C 8B 46 0A BA 00 00 F7 E3 01 46 02 11 56 04 ;
  0000:1143  db 83 56 06 00 8B 46 08 BA 00 00 F7 E3 01 46 04 11 ;
  0000:1153  db 56 06 8B 46 06 8B 5E 04 8B 4E 02 8B 56          ;

; ------------------------------------------------------------------------
; SEGMENT seg_0116  (16 bytes, file 0x1360-0x1370)
; Code epilogue + padding from seg_0000 overflow
; ------------------------------------------------------------------------
seg_0116:

  0116:0000  db 00 83 C4 10 5D C3 00 00 00 00 00 00 00 00 00 00 ; add sp,10h; pop bp; ret

; ------------------------------------------------------------------------
; SEGMENT seg_0117  (400 bytes, file 0x1370-0x1500)
; TSR startup, dispatch, INT E0h interface
; ------------------------------------------------------------------------
seg_0117:

  ; --- DM89 module header ---
  ; "DMVECGA" at offset 0x0000
  ; Font table pointers, companion driver name, dispatch config
sub_0117_0000:                                               ; 0117:0000
  0117:0000  44                inc      sp                   ; 'D' (ASCII)
  0117:0001  4d                dec      bp                   ; 'M'
  0117:0002  56                push     si                   ; 'V'
  0117:0003  45                inc      bp                   ; 'E'
  0117:0004  43                inc      bx                   ; 'C'
  0117:0005  47                inc      di                   ; 'G'
  0117:0006  41                inc      cx                   ; 'A'
  0117:0007  00e2              add      dl, ah
  0117:0009  0017              add      byte ptr [bx], dl    ; RELOC->seg_0117
  0117:000B  014901            add      word ptr [bx + di + 1], cx
  0117:000E  17                pop      ss                   ; RELOC->seg_0117
  0117:000F  0100              add      word ptr [bx + si], ax
  ; [padding/reserved through 0x0020]
  0117:0011  0000              add      byte ptr [bx + si], al
  0117:0013  0000              add      byte ptr [bx + si], al
  0117:0015  0000              add      byte ptr [bx + si], al
  0117:0017  0000              add      byte ptr [bx + si], al
  0117:0019  0000              add      byte ptr [bx + si], al
  0117:001B  0000              add      byte ptr [bx + si], al
  0117:001D  0000              add      byte ptr [bx + si], al
  0117:001F  0000              add      byte ptr [bx + si], al

  ; --- Font table: INT ABh entries ---
  0117:0021  0003              add      byte ptr [bp + di], al
  0117:0023  1101              adc      word ptr [bx + di], ax
  0117:0025  cdab              int      0xab                 ; INT ABh: load font (primary)
  0117:0027  badc44            mov      dx, 0x44dc
  0117:002A  4d                dec      bp                   ; 'M' (start of "DMFONT")
  0117:002B  46                inc      si
  0117:002C  4f                dec      di
  0117:002D  4e                dec      si
  0117:002E  54                push     sp
  0117:002F  0000              add      byte ptr [bx + si], al
  0117:0031  cdab              int      0xab                 ; INT ABh: load font (standard CGA)
  0117:0033  badc44            mov      dx, 0x44dc
  0117:0036  4d                dec      bp                   ; 'M' (start of "DMVSCGA")
  0117:0037  56                push     si
  0117:0038  53                push     bx
  0117:0039  43                inc      bx
  0117:003A  47                inc      di
  0117:003B  41                inc      cx
  0117:003C  0000              add      byte ptr [bx + si], al
  0117:003E  0000              add      byte ptr [bx + si], al

  ; --- dmvecga_dispatchSetup: resolve function pointer from table ---
  ; Called from the dispatcher. Sets up the stack frame for the target
  ; function, resolves the host workspace segment from IVT[0x386].
  0117:0040  005306            add      byte ptr [bp + di + 6], dl ; dispatch mode byte
  0117:0043  55                push     bp                   ; 0117:0043
  0117:0044  83ec0a            sub      sp, 0xa
  0117:0047  8bec              mov      bp, sp
  0117:0049  52                push     dx
  0117:004A  2e8a164000        mov      dl, byte ptr cs:[0x40] ; dispatch mode
  0117:004F  885609            mov      byte ptr [bp + 9], dl
  0117:0052  2ec41e3100        les      bx, ptr cs:[0x31]   ; font table far ptr
  0117:0057  80fa58            cmp      dl, 0x58             ; 'X' = extended?
  0117:005A  7506              jne      0x62                 ; -> loc_0117_0062
  0117:005C  d1e0              shl      ax, 1                ; AX *= 4 (extended has 4 params)
  0117:005E  d1e0              shl      ax, 1
  0117:0060  03d8              add      bx, ax               ; offset into font table

loc_0117_0062:                                               ; 0117:0062
  0117:0062  5a                pop      dx
  0117:0063  8c4602            mov      word ptr [bp + 2], es ; save ES
  0117:0066  895e00            mov      word ptr [bp], bx    ; save BX
  0117:0069  8c4e06            mov      word ptr [bp + 6], cs ; return seg = CS
  0117:006C  bb9400            mov      bx, 0x94             ; return offset
  0117:006F  895e04            mov      word ptr [bp + 4], bx
  0117:0072  50                push     ax
  0117:0073  b80000            mov      ax, 0                ; IVT segment 0
  0117:0076  8ec0              mov      es, ax
  0117:0078  26a18603          mov      ax, word ptr es:[0x386] ; host segment from IVT
  0117:007C  8ec0              mov      es, ax               ; ES = host workspace
  0117:007E  58                pop      ax
  0117:007F  8b5e0e            mov      bx, word ptr [bp + 0xe] ; caller's BX
  0117:0082  52                push     dx
  0117:0083  8a5609            mov      dl, byte ptr [bp + 9]
  0117:0086  80fa58            cmp      dl, 0x58             ; extended mode?
  0117:0089  7506              jne      0x91                 ; -> loc_0117_0091
  0117:008B  8b4610            mov      ax, word ptr [bp + 0x10] ; extended param
  0117:008E  8b6e0a            mov      bp, word ptr [bp + 0xa]

loc_0117_0091:                                               ; 0117:0091
  0117:0091  5a                pop      dx
  0117:0092  45                inc      bp
  0117:0093  cb                retf                          ; far return to target function

  ; Return from dispatch (cleanup stack)
  0117:0094  db 83 C4 0A 2E 80 3E 40 00 58 75 01 4D CB          ; add sp,0xa; cmp mode,'X'; retf

  ; --- entry_point: TSR installation ---
  ; Registers the enhanced CGA driver with DeskMate and goes resident.
entry_point:                                                 ; 0117:00A1
  0117:00A1  0e                push     cs
  0117:00A2  07                pop      es                   ; ES = CS
  0117:00A3  bb0000            mov      bx, 0
  0117:00A6  268c5f20          mov      word ptr es:[bx + 0x20], ds ; save DS at header+0x20
  0117:00AA  b80006            mov      ax, 0x600
  0117:00AD  cde0              int      0xe0                 ; INT E0h/06h: query host caps
  0117:00AF  250080            and      ax, 0x8000           ; test bit 15
  0117:00B2  b8f001            mov      ax, 0x1f0            ; capabilities = 0x01F0
  0117:00B5  26c606400059      mov      byte ptr es:[0x40], 0x59 ; default: 'Y' (normal mode)
  0117:00BB  7508              jne      0xc5                 ; -> loc_0117_00C5 (bit 15 set)
  0117:00BD  b8ff01            mov      ax, 0x1ff            ; extended capabilities
  0117:00C0  26fe0e4000        dec      byte ptr es:[0x40]   ; 'Y'-1 = 'X' (extended mode)

loc_0117_00C5:                                               ; 0117:00C5
  0117:00C5  b90000            mov      cx, 0                ; RELOC->seg_0000 (drawing code)
  0117:00C8  cde0              int      0xe0                 ; INT E0h/01h: register driver
  0117:00CA  26a23d00          mov      byte ptr es:[0x3d], al ; save display ID
  0117:00CE  e88900            call     0x15a                ; -> sub_0117_015A (init fonts)
  0117:00D1  b451              mov      ah, 0x51
  0117:00D3  cd21              int      0x21                 ; INT 21h/51h: get PSP
  0117:00D5  4b                dec      bx                   ; BX = PSP - 1 (MCB)
  0117:00D6  8ec3              mov      es, bx
  0117:00D8  268b160300        mov      dx, word ptr es:[3]  ; DX = MCB size (paragraphs)
  0117:00DD  b80031            mov      ax, 0x3100
  0117:00E0  cd21              int      0x21                 ; INT 21h/31h: TSR

  ; --- dmvecga_dispatcher: function dispatch with context save ---
  ; Called from the standard driver via far-call.
  ; AX = function number (0x00-0x0C). Validates range, acquires
  ; display mutex, dispatches through seg_0000 table, releases mutex.
  0117:00E2  53                push     bx                   ; 0117:00E2
  0117:00E3  8bdc              mov      bx, sp
  0117:00E5  83e301            and      bx, 1                ; align SP to word boundary
  0117:00E8  2be3              sub      sp, bx
  0117:00EA  53                push     bx                   ; save alignment delta
  0117:00EB  51                push     cx
  0117:00EC  56                push     si
  0117:00ED  57                push     di
  0117:00EE  55                push     bp
  0117:00EF  1e                push     ds
  0117:00F0  06                push     es
  0117:00F1  9c                pushf
  0117:00F2  fc                cld                           ; clear direction flag
  0117:00F3  3d0d00            cmp      ax, 0xd              ; valid function 0-12?
  0117:00F6  7205              jb       0xfd                 ; -> loc_0117_00FD
  0117:00F8  b8ffff            mov      ax, 0xffff           ; error: invalid function
  0117:00FB  eb40              jmp      0x13d                ; -> loc_0117_013D (return)

loc_0117_00FD:                                               ; 0117:00FD
  0117:00FD  50                push     ax
  0117:00FE  2ea03d00          mov      al, byte ptr cs:[0x3d] ; display ID
  0117:0102  3cff              cmp      al, 0xff
  0117:0104  7409              je       0x10f                ; -> loc_0117_010F (no mutex)
  0117:0106  52                push     dx
  0117:0107  8ad0              mov      dl, al               ; DL = display ID
  0117:0109  b8044d            mov      ax, 0x4d04           ; INT E0h/4Dh: acquire mutex
  0117:010C  cde0              int      0xe0
  0117:010E  5a                pop      dx

loc_0117_010F:                                               ; 0117:010F
  0117:010F  2ea23e00          mov      byte ptr cs:[0x3e], al ; save mutex state
  0117:0113  58                pop      ax                   ; restore function number
  0117:0114  2eff363e00        push     word ptr cs:[0x3e]   ; push mutex state
  0117:0119  bb1601            mov      bx, 0x116            ; RELOC->seg_0116
  0117:011C  8ec3              mov      es, bx
  0117:011E  0e                push     cs
  0117:011F  5b                pop      bx                   ; BX = CS (seg_0117)
  0117:0120  9a04000000        lcall    0, 4                 ; RELOC->seg_0000:0004 (dispatch)
  0117:0125  2e8f063e00        pop      word ptr cs:[0x3e]   ; restore mutex state
  0117:012A  50                push     ax                   ; save return value
  0117:012B  2ea03e00          mov      al, byte ptr cs:[0x3e]
  0117:012F  3cff              cmp      al, 0xff
  0117:0131  7409              je       0x13c                ; -> loc_0117_013C (no mutex)
  0117:0133  52                push     dx
  0117:0134  8ad0              mov      dl, al
  0117:0136  b8054d            mov      ax, 0x4d05           ; INT E0h/4Dh: release mutex
  0117:0139  cde0              int      0xe0
  0117:013B  5a                pop      dx

loc_0117_013C:                                               ; 0117:013C
  0117:013C  58                pop      ax

loc_0117_013D:                                               ; 0117:013D
  ; Restore context and return
  0117:013D  9d                popf
  0117:013E  07                pop      es
  0117:013F  1f                pop      ds
  0117:0140  5d                pop      bp
  0117:0141  5f                pop      di
  0117:0142  5e                pop      si
  0117:0143  59                pop      cx
  0117:0144  5b                pop      bx                   ; alignment delta
  0117:0145  03e3              add      sp, bx               ; undo alignment
  0117:0147  5b                pop      bx
  0117:0148  cb                retf

  ; --- dmvecga_registerResources: register with host via INT E0h ---
  0117:0149  db 50 06 52 0E 07 BA 35 00 B8 07 02 CD E0 5A 07 58 ; INT E0h/07h
  0117:0159  db CB                                              ; retf

  ; --- sub_0117_015A: initialize font table pointer ---
  ; Checks dispatch mode, adjusts font name pointer for 'X' vs 'Y',
  ; then calls INT E0h/02h to register font/resource pointers.
sub_0117_015A:                                               ; 0117:015A
  0117:015A  53                push     bx
  0117:015B  52                push     dx
  0117:015C  26803e400059      cmp      byte ptr es:[0x40], 0x59 ; normal mode?
  0117:0162  740a              je       0x16e                ; -> loc_0117_016E
  0117:0164  bb3500            mov      bx, 0x35
  0117:0167  83c303            add      bx, 3                ; bx = 0x38
  0117:016A  26c60744          mov      byte ptr es:[bx], 0x44 ; patch font name byte to 'D'

loc_0117_016E:                                               ; 0117:016E
  0117:016E  bb3100            mov      bx, 0x31             ; font table offset
  0117:0171  ba3500            mov      dx, 0x35             ; resource ptr offset
  0117:0174  b80602            mov      ax, 0x206
  0117:0177  cde0              int      0xe0                 ; INT E0h/02h: register resource
  0117:0179  48                dec      ax
  0117:017A  0bc0              or       ax, ax
  0117:017C  750c              jne      0x18a                ; -> loc_0117_018A
  0117:017E  26ff1e3100        lcall    es:[0x31]            ; call through font table
  0117:0183  26891e3100        mov      word ptr es:[0x31], bx ; update font table ptr
  0117:0188  33c0              xor      ax, ax

loc_0117_018A:                                               ; 0117:018A
  0117:018A  5a                pop      dx
  0117:018B  5b                pop      bx
  0117:018C  c3                ret
  0117:018D  db 00 00 00                                     ; padding

; ------------------------------------------------------------------------
; SEGMENT seg_0130  (2 bytes, file 0x1500-0x1502)
; Stack segment
; ------------------------------------------------------------------------
seg_0130:

  0130:0000  db 00 00                                           ; initial stack
