; ========================================================================
; DMVEVGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Enhanced Video Driver: VGA (640x480, 16 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVEVGA.RES is the enhanced-mode VGA video driver for DeskMate 3.05.
; Enhanced drivers contain the core drawing primitives (pixel plotting,
; line drawing, rectangle fill, font rendering, clipping) that operate
; on the video framebuffer. The standard driver (DMVSVGA.RES) handles
; mode switching, cursor management, INT 08h timer hooking, and the
; higher-level display list / window management, while calling into
; this enhanced driver for actual pixel-level operations.
;
; The enhanced driver installs itself as a TSR via INT 21h/31h after
; registering with the DeskMate host through INT E0h. It provides a
; dispatch table of 13 drawing functions (0x00-0x0C) that the standard
; driver calls through a far-call interface.
;
; Video framebuffer: segment A000h (VGA planar mode, 4 bit planes)
; Resolution: 640x480 at 16 colors (mode 12h)
; Bytes per scanline: 80 (640/8)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5426 bytes
; Code+data size: 4914 bytes
; DM89 entry point: 011A:00A1
; SS:SP = 0133:0002
;
; DM89 signature: present
; DM89 raw: 444d38393e0c013e00001a0100001a01080019010000000000000000000000000000
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  0x1190 bytes  CODE/DATA  Drawing primitives + sine/cosine table
;   seg_0119  0x0010 bytes  CODE/DATA  Enhanced driver name string segment
;   seg_011A  0x0190 bytes  CODE       TSR startup, dispatch, INT E0h interface
;   seg_0133  0x0002 bytes  STACK      Stack segment
;
; Relocation Table (5 entries):
;   011A:000A -> seg_011A  (self-reference in DM89 header)
;   011A:000E -> seg_011A  (self-reference in DM89 header)
;   011A:00C6 -> seg_0000  (drawing code segment reference)
;   011A:011A -> seg_0119  (enhanced driver name segment)
;   011A:0123 -> seg_0000  (drawing code segment reference)
;
; ========================================================================
; ARCHITECTURE
; ========================================================================
;
; The enhanced driver has two main parts:
;
; 1. Drawing Primitives (seg_0000, 4496 bytes):
;    Raw pixel-level rendering code. Functions accessed via the dispatch
;    table at seg_0000:0020. These operate directly on the VGA framebuffer
;    at segment A000h using planar 4-bit mode. The code uses a register-
;    based calling convention with coordinates in AX/BX/CX/DX and a
;    workspace structure pointed to by BP.
;
; 2. TSR Loader / Dispatcher (seg_011A, 400 bytes):
;    Entry point at 011A:00A1. Registers with DeskMate via INT E0h,
;    then goes resident via INT 21h/31h. The dispatcher at 011A:00E2
;    routes function calls through the seg_0000 dispatch table.
;
; Drawing workspace structure (at ES:[bp_base]):
;   [+0x00] x1            Current X coordinate
;   [+0x02] x2            X2 / width parameter
;   [+0x04] y1            Current Y coordinate
;   [+0x06] y2            Y2 / height parameter
;   [+0x08] clip_x1       Left clipping bound
;   [+0x0A] src_seg       Source bitmap segment
;   [+0x0C] src_off       Source bitmap offset
;   [+0x0E] row_count     Rows remaining to draw
;   [+0x10] font_ptr      Font data pointer
;   [+0x12] pixel_mask    Bit mask for current pixel
;   [+0x14] row_delta     Bytes per row in bitmap
;   [+0x16] byte_offset   Byte offset within scanline
;   [+0x18] di_base       Saved DI register
;   [+0x1A] bit_position  Bit position within byte (0-7)
;   [+0x1C] fill_pattern  Fill pattern byte (AA=checkerboard, FF=solid)
;   [+0x1E] line_count    Total lines processed
;   [+0x20] y_origin      Y origin for coordinate transform
;   [+0x22] x_origin      X origin for coordinate transform
;   [+0x36] clip_min_y    Minimum Y clip bound
;   [+0x38] clip_max_y    Maximum Y clip bound
;   [+0x3C] viewport_w    Viewport width
;   [+0x3E] viewport_min  Viewport minimum bound
;   [+0x40] max_dx        Maximum delta-X for fills
;   [+0x42] max_dy        Maximum delta-Y for fills
;   [+0x44] accum         Accumulator for line drawing
;   [+0x52] font_seg      Font data segment pointer
;   [+0x54] font_off      Font data offset
;   [+0x56] char_code     Current character code
;   [+0x58] char_tbl      Character table pointer
;   [+0x5C] bitmap_seg    Bitmap segment
;   [+0x5E] bitmap_off    Bitmap offset
;   [+0x60] bmp_seg2      Secondary bitmap segment
;   [+0x62] bmp_off2      Secondary bitmap offset
;   [+0x64] dst_ptr       Destination pointer
;   [+0x66] dst_seg       Destination segment
;   [+0x68] clip_left     Left clip boundary (pixels)
;   [+0x6A] clip_top      Top clip boundary (pixels)
;   [+0x6C] clip_right    Right clip boundary (pixels)
;   [+0x6E] clip_bottom   Bottom clip boundary (pixels)
;   [+0x6D] alloc_handle  DOS memory allocation handle
;   [+0x6F] alloc_delta_y Y delta for allocated buffer
;   [+0x71] row_bytes     Bytes per row in source
;   [+0x73] bmp_width     Bitmap width
;   [+0x75] bmp_height    Bitmap height (also row limit)
;   [+0x79] alloc_mode    Memory allocation mode
;   [+0x7B] copy_offset   Copy offset for blit operations
;   [+0x7D] use_local_buf Flag: use local buffer (0) or allocated (1)
;   [+0x7F] buf_seg       Buffer segment
;   [+0x81] total_width   Total width of source
;   [+0x83] progress      Current progress in blit
;   [+0x86] host_seg      DeskMate host segment
;   [+0x87] flags         Driver flags bitfield
;   [+0x89] alloc_paragraphs  Allocated paragraph count
;   [+0xFF] mode_flags    Mode/capability flags
;   [+0x0386] (IVT)       DeskMate host segment (at IVT offset 0x386)
;
; Note: offsets above 0x86 are in the host-provided workspace, not stack.
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; This enhanced driver does not directly access VGA I/O ports (3C0h-3CFh).
; All hardware configuration is handled by the standard driver (DMVSVGA).
; The enhanced driver accesses the VGA framebuffer through memory-mapped
; I/O at segment A000h only.
;
; VGA framebuffer segment: A000h
;   First two bytes of seg_0000 contain: 00 A0 (= 0xA000 little-endian)
;   This is loaded via: mov es, word ptr cs:[0x0000]
;   to set ES to the VGA framebuffer segment for pixel operations.
;
; Bytes per scanline: 80 (0x50) -- VGA 640-pixel-wide mode
;   Visible in the scan line increment: add di, 0x50
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=06h  -- Query DeskMate host capabilities
;   011A:00AD  (entry_point) Check bit 15 of result for mode selection
;
; INT E0h, AH=01h  -- Register enhanced driver with host
;   011A:00C8  CX=seg_0000 (drawing code segment), AX=0x01F0 (capabilities)
;   Returns AL=active display ID (stored at cs:[0x3D])
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex (before drawing)
;   011A:010C  DL=display ID; called before dispatching a draw call
;
; INT E0h, AH=4Dh/05  -- Release display mutex (after drawing)
;   011A:0139  DL=display ID; called after a draw call completes
;
; INT E0h, AH=02h  -- Register font/resource pointer
;   011A:0177  BX=0x31 (font table offset), DX=0x35 (resource ptr)
;   Used during initialization to set up the font data pointer
;
; INT 21h, AH=51h  -- Get current PSP segment
;   011A:00D3  Returns BX=PSP segment (used to calculate resident size)
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   011A:00E0  DX=paragraphs to keep, installs driver as TSR
;
; INT 21h, AH=48h  -- Allocate DOS memory block
;   0000:0B6D  BX=paragraphs requested (0x0960 = ~38KB for bitmap buffer)
;   Used for offscreen bitmap workspace allocation
;
; INT 21h, AH=49h  -- Free DOS memory block
;   0000:0D23  ES=segment of block to free
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
;   0x00   0x0039  dmvevga_setPixel              Set pixel at (AX,BX) with color CX
;   0x01   0x0166  dmvevga_clipRect              Clip rectangle to viewport bounds
;   0x02   0x0200  dmvevga_scrollRegion          Scroll a rectangular region
;   0x03   0x0253  dmvevga_thunk_11h             Far-call thunk to host func 0x11
;   0x04   0x0263  dmvevga_thunk_10h             Far-call thunk to host func 0x10
;   0x05   0x027A  dmvevga_thunk_6Ah             Far-call thunk to host func 0x6A
;   0x06   0x0294  dmvevga_thunk_69h             Far-call thunk to host func 0x69
;   0x07   0x02B3  dmvevga_thunk_64h             Far-call thunk to host func 0x64
;   0x08   0x02CB  dmvevga_thunk_63h             Far-call thunk to host func 0x63
;   0x09   0x02E3  dmvevga_thunk_59h             Far-call thunk to host func 0x59
;   0x0A   0x02FB  dmvevga_thunk_5Bh             Far-call thunk to host func 0x5B
;   0x0B   0x0313  dmvevga_thunk_12h             Far-call thunk to host func 0x12
;   0x0C   0x032B  dmvevga_thunk_13h             Far-call thunk to host func 0x13
;
; --- Additional Thunks (0x0343-0x0427) ---
;
;   0x0343  dmvevga_thunk_65h                    Far-call thunk to host func 0x65
;   0x035B  dmvevga_thunk_66h                    Far-call thunk to host func 0x66
;   0x0373  dmvevga_thunk_6Bh                    Far-call thunk to host func 0x6B
;   0x038B  dmvevga_thunk_27h                    Far-call thunk to host func 0x27
;   0x03A3  dmvevga_thunk_4Ch                    Far-call thunk to host func 0x4C
;   0x03BB  dmvevga_thunk_53h                    Far-call thunk to host func 0x53
;   0x03D3  dmvevga_thunk_38h                    Far-call thunk to host func 0x38
;   0x03EB  dmvevga_thunk_3Eh                    Far-call thunk to host func 0x3E
;   0x0403  dmvevga_thunk_6Dh                    Far-call thunk to host func 0x6D
;   0x040B  dmvevga_thunk_51h                    Far-call thunk to host func 0x51
;   0x0413  dmvevga_thunk_4Eh                    Far-call thunk to host func 0x4E
;
; --- Drawing Primitives ---
;
;   Address  Name                        Size  Description
;   -------  ----                        ----  -----------
;   0000:0000  (data: VGA segment)         2   Video segment word = 0xA000
;   0000:0002  (data: scan offset)         2   Scan line origin offset
;   0000:0004  dmvevga_dispatchEntry       19  Dispatch: load func ptr, far-call
;   0000:0013  dmvevga_hostCallback        12  Callback into host (ES:[0x25])
;   0000:0020  (data: dispatch table)      25  13-entry function offset table
;   0000:0039  dmvevga_setPixel           154  Plot pixel with clipping + pattern
;   0000:00D3  (epilogue)                       Restore regs, return
;   0000:00D9  dmvevga_drawHLineAligned    99  Draw horizontal line (byte-aligned)
;   0000:0100  dmvevga_drawHLineUnaligned 102  Draw horizontal line (unaligned)
;   0000:0166  dmvevga_clipRect            45  Clip rectangle to current viewport
;   0000:0193  dmvevga_drawRect           108  Draw/fill rectangle
;   0000:0200  dmvevga_scrollRegion        59  Scroll rectangular region
;   0000:0253  (thunks start)                  Host far-call thunk region
;   0000:0425  dmvevga_coordToByteOffset   16  Convert X coord to byte offset
;   0000:0430  dmvevga_sineLookup          81  Sine/cosine via lookup table
;   0000:0485  (data: sine table)         170  256-entry sine lookup table
;   0000:053B  dmvevga_initFont            68  Initialize font rendering state
;   0000:057D  dmvevga_renderChar         352  Render single character glyph
;   0000:06E5  dmvevga_beginTextRegion     57  Begin text region (calc metrics)
;   0000:071E  dmvevga_calcTextExtent      13  Calculate text extent from font
;   0000:072B  dmvevga_renderTextLine     130  Render one line of text with clipping
;   0000:07AD  dmvevga_loadFontGlyph       51  Load glyph data from font resource
;   0000:07CB  dmvevga_selectFont          37  Select font by index
;   0000:07F9  dmvevga_drawBitmap         180  Draw bitmap with clipping
;   0000:085B  dmvevga_initBitmapState     14  Init bitmap rendering state
;   0000:0869  dmvevga_allocBitmapBuffer  100  Allocate offscreen bitmap buffer
;   0000:08CD  dmvevga_calcAspectRatio    347  Calculate aspect ratio correction
;   0000:0A28  dmvevga_blitBitmap         119  Blit bitmap from offscreen buffer
;   0000:0A9F  dmvevga_renderGlyphBitmap  663  Render glyph bitmap with fills
;   0000:0D3C  dmvevga_endTextRegion       38  End text region, free resources
;   0000:0D62  dmvevga_setupViewport       93  Set up viewport coordinates
;   0000:0DBF  dmvevga_restoreViewport     42  Restore viewport after rendering
;   0000:0E19  dmvevga_calcPixelSize       24  Calculate pixel size for scaling
;   0000:0E31  (sub_0000_0E31)             61  Setup coordinate transform for print
;   0000:0E6E  (sub_0000_0E6E)            100  Calculate aspect ratio from host params
;   0000:0ED2  (cursor render helpers)          Cursor blink/render support
;   0000:1011  (sub_0000_1011)                  Additional font/glyph helpers
;
; --- TSR / Dispatcher (seg_011A) ---
;
;   011A:0000  dmvevga_dm89Header          64  DM89 module header ("DMVEVGA")
;   011A:0040  dmvevga_dispatchMode         1  Dispatch mode byte ('X'=extended, 'Y'=normal)
;   011A:0043  dmvevga_dispatchSetup       94  Set up dispatch frame, resolve func ptr
;   011A:00A1  entry_point                 65  TSR entry: register with host, go resident
;   011A:00E2  dmvevga_dispatcher          102 Function dispatcher (save/restore context)
;   011A:0149  dmvevga_registerResources    17  Register font/resource pointers with host
;   011A:015A  sub_011A_015A               51  Initialize font table pointer via INT E0h
;
; ========================================================================
; KEY DATA
; ========================================================================
;
; seg_0000:0000  dw 0xA000       ; VGA framebuffer segment
; seg_0000:0020  (dispatch table, 13 word entries):
;   [0] 0x0807  [1] 0x0856  [2] 0x0850  [3] 0x0265  [4] 0x027A
;   [5] 0x0294  [6] 0x0533  [7] 0x0E31  [8] 0x0E6E  [9] 0x0EE4
;   [10] 0x0F61 [11] 0x07A2 [12] 0x0090
;
;   (Note: these are offsets from the far-call thunk table, not direct
;    addresses. The thunks at 0x0253+ each push a return address and
;    a host function number, then perform RETF to the host.)
;
; seg_011A:0031  dd far ptr font_table     ; Far pointer to font data (filled by init)
; seg_011A:0035  dd far ptr resource_ptr   ; Far pointer to resource data
; seg_011A:003D  db display_id             ; Active display ID from INT E0h
; seg_011A:003E  db saved_display_id       ; Saved display ID during dispatch
; seg_011A:0040  db dispatch_mode          ; 'X'=extended (4 params), 'Y'=normal
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The driver uses VGA planar mode (mode 12h, 640x480x16). Each pixel
;   is represented by 4 bits across 4 bit planes. The code manipulates
;   individual planes through the VGA sequencer/graphics controller,
;   but this is done in the standard driver, not here.
;
; - The dispatch_mode byte at cs:[0x40] controls whether the dispatcher
;   passes 2 or 4 coordinate parameters. 'X' (0x58) = extended mode
;   with 4 params; 'Y' (0x59) = normal mode with 2 params.
;
; - The sine lookup table at 0x0485 contains 90 entries (quarter-wave)
;   used for arc/circle drawing. Values are 16-bit fixed-point.
;
; - Memory allocation for offscreen buffers uses INT 21h/48h with a
;   request for 0x0960 paragraphs (~38KB). If that fails, it tries
;   again with a smaller size and uses a local buffer instead.
;
; - All coordinate calculations use 16-bit signed integers. Clipping
;   is performed against the viewport bounds stored in the workspace.
;
; ========================================================================
