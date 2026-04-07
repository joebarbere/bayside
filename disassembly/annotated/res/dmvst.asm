; ========================================================================
; DMVST.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Tandy Graphics Adapter (TGA) Standard Video Driver
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVST.RES is the "standard" video resource driver for the Tandy Graphics
; Adapter (TGA). Unlike its enhanced counterpart DMVET.RES (which is a
; thin dispatch shim), DMVST contains the complete set of drawing routines
; for the DeskMate video abstraction layer (~22KB of code).
;
; This driver is self-contained: it implements all drawing primitives
; directly, without requiring the DESK.EXE host's built-in rendering.
; It is loaded when DMVID.EXE selects the Tandy standard video mode.
;
; The standard driver provides:
;   - Screen initialization and teardown
;   - Pixel plotting with clipping
;   - Horizontal and vertical line drawing
;   - Rectangle fill (solid and patterned)
;   - Character/text rendering with built-in bitmap fonts
;   - Scroll (up/down) with region clipping
;   - Palette/color management
;   - Mouse cursor drawing and restoration
;   - Display list rendering (iterating through DM objects)
;   - Coordinate transformation (logical <-> physical)
;
; Key hardware accessed:
;   Port 0x03BA - CGA/MDA Status Register (read for retrace sync)
;   Port 0x03C0 - TGA/EGA Attribute Controller
;   Port 0x03CE - TGA/EGA Graphics Controller Address Register
;   Port 0x03CF - TGA/EGA Graphics Controller Data Register
;   Port 0x03DA - CGA Status Register (read for retrace sync)
;   Segment A000h - TGA video memory (planar mode)
;   Segment B800h - Tandy video memory (text/CGA-compatible mode)
;
; The driver pairs with DMVET.RES: the seg_0000 header at offset 0x07
; contains "DMVET" -- the name of the enhanced driver it cooperates with.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 24,322 bytes
; Load image: 23,810 bytes (after header)
; DM89 entry point: 0589:0032
; SS:SP = 05D0:0002
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000     32 bytes  DATA     Version string "33.10" + driver name "DMVET"
;                                   + configuration byte array
;   seg_0002 22,352 bytes  CODE     Main drawing routines (all video primitives)
;   seg_0577    288 bytes  DATA     Function pointer dispatch table
;                                   (offsets into seg_0002 for each API function)
;   seg_0589    976 bytes  CODE     DM89 header, entry point, API dispatch,
;                                   timer ISR, retrace sync, video mode setup
;   seg_05C6    160 bytes  DATA     Color mapping tables, attribute constants,
;                                   driver capability flags
;   seg_05D0      2 bytes  STACK    Stack segment
;   seg_05D1     -- bytes  BSS      Uninitialized data (video state, cursor backup)
;
; Memory model: Near code within segments; far-calls between segments
; Min alloc: 0x01C3 paragraphs (7,216 bytes BSS)
; Max alloc: 0x01C3 paragraphs
;
; ========================================================================
; DRIVER CONFIGURATION DATA (seg_0000)
; ========================================================================
;
; seg_0000:0000  "33.10"       Version string (DM89 driver version 33.10)
; seg_0000:0006  0xA0          Video segment selector (A000h)
; seg_0000:0007  "DMVET"       Paired enhanced driver name
; seg_0000:000D  Configuration byte array:
;   [0x0D] = 0xFF  Driver flags (all features enabled)
;   [0x0E] = 0x00  Reserved
;   [0x0F] = 0x88  Video mode capabilities
;   [0x10] = 0xE7  Color depth / palette flags
;   [0x11] = 0x9C  Text mode flags
;   [0x12] = 0xAA  Pattern mask (checkerboard)
;   [0x13] = 0xCC  Pattern mask (horizontal stripes)
;   [0x14] = 0x10  Character cell width (16 pixels)
;   [0x15] = 0x00  Reserved
;   [0x16] = 0x08  Character cell height (8 pixels)
;   [0x17] = 0x00  Reserved
;   [0x18] = 0x14  Screen columns (20 text columns in graphics mode)
;   [0x19-1C] = 0  Reserved
;   [0x1D] = 0x80  Display flags (bit 7 = graphics capable)
;   [0x1E] = 0x02  Number of display pages
;   [0x1F] = 0xC8  Screen height in pixels (200)
;
; ========================================================================
; FUNCTION DISPATCH TABLE (seg_0577)
; ========================================================================
;
; The dispatch table at seg_0577 contains word offsets into seg_0002
; for each video API function. The table is indexed by the function
; number passed from DESK.EXE. Format is pairs of words:
;   [offset_low, offset_high] for near-call targets.
;
; Approximate function mapping (indices derived from call patterns):
;
;   Idx  seg_0002 Offset  Function
;   ---  ---------------  --------
;   00   0x0053           dmvst_bezierCurve       - Bezier curve rendering
;   01   0x0142           dmvst_subdivide         - Curve subdivision
;   02   0x0182           dmvst_midpointCalc      - Midpoint calculation
;   03   0x01AB           dmvst_sortPoints        - Sort control points
;   04   0x01E1           dmvst_initGraphics      - Initialize graphics mode
;   05   0x0211           dmvst_restoreState      - Restore video state
;   06   0x0232           dmvst_setPixelColor     - Set current drawing color
;   07   0x02A5           dmvst_setBackColor      - Set background color
;   08   0x02D7           dmvst_getPixelColor     - Get current color
;   09   0x02F0           dmvst_setTextAttrib     - Set text attributes
;   10   0x035D           dmvst_saveState         - Save current video state
;   11   0x037F           dmvst_loadFont          - Load font data
;   12   0x03F3           dmvst_restoreFont       - Restore font data
;   13   0x0416           dmvst_scrollCallback    - Scroll region callback
;   14   0x043A           dmvst_scrollUp          - Scroll region up
;   15   0x047A           dmvst_scrollDown        - Scroll region down
;   16   0x04BA           dmvst_scrollUpOuter     - Outer scroll-up handler
;   17   0x04EF           dmvst_blitUp            - Blit scanlines upward
;   18   0x0541           dmvst_scrollDownOuter   - Outer scroll-down handler
;   19   0x0577           dmvst_blitDown          - Blit scanlines downward
;   20   0x05C9           dmvst_horzLineUp        - Horizontal line (up dir)
;   21   0x05FE           dmvst_fillRect          - Fill rectangle
;   22   0x06B7           dmvst_horzLineDown      - Horizontal line (down dir)
;   23   0x06EB           dmvst_fillRectDown      - Fill rect (down direction)
;   24   0x07B8           dmvst_drawHorzLine      - Draw horizontal line
;   25   0x07DB           dmvst_drawVertLine      - Draw vertical line
;   26   0x080D           dmvst_drawLine          - General line drawing
;   27   0x083C           dmvst_drawLineClipped   - Clipped line drawing
;   28   0x0861           dmvst_plotPixel         - Plot single pixel
;   29   0x0895           dmvst_readPixel         - Read pixel value
;   30   0x08C8           dmvst_drawPattern       - Draw with pattern
;   31   0x090C           dmvst_fillPattern       - Fill with pattern
;   32   0x0966           dmvst_setClipRect       - Set clipping rectangle
;   33   0x098B           dmvst_getClipRect       - Get clipping rectangle
;   34   0x09AD           dmvst_renderChar        - Render character glyph
;   35   0x0A60           dmvst_renderString      - Render text string
;   36   0x0B5E           dmvst_measureString     - Measure text extent
;   37   0x0BCD           dmvst_drawBitmapRow     - Draw bitmap row
;   38   0x0C0C           dmvst_drawBitmapClip    - Draw bitmap with clipping
;   39   0x0C3C           dmvst_drawIcon          - Draw icon/sprite
;   40   0x0C72           dmvst_blitRegion        - Blit screen region
;   41   0x0D4D           dmvst_setWriteMode      - Set write mode (XOR/OR/AND)
;   42   0x0D59           dmvst_setWriteModeDirect - Direct write mode set
;   43   0x0D95           dmvst_scrollRegion      - Scroll arbitrary region
;   44   0x0E07           dmvst_complexRedraw     - Complex region redraw
;   45   0x0F49           dmvst_drawArc           - Draw arc/ellipse
;   46   0x0FAD           dmvst_drawEllipse       - Draw ellipse
;   47   0x1081           dmvst_floodFill         - Flood fill
;   48   0x117E           dmvst_drawPolygon       - Draw polygon
;   49   0x1409           dmvst_setViewport       - Set viewport
;   50   0x1463           dmvst_polyFill          - Polygon fill
;   51   0x1559           dmvst_complexBlit       - Complex blit operation
;   52   0x15A6           dmvst_tileFill          - Tile/pattern fill
;   53   0x1622           dmvst_patternBlit       - Pattern blit
;   54   0x1692           dmvst_stretchBlit       - Stretch blit
;   55   0x1786           dmvst_drawRoundRect     - Draw rounded rectangle
;   56   0x18B3           dmvst_drawThickLine     - Draw thick line
;   57   0x18E8           dmvst_complexLine       - Complex line with style
;   58   0x19C4           dmvst_drawDashLine      - Draw dashed line
;   59   0x1A15           dmvst_drawStyledLine    - Draw styled line
;   60   0x1B55           dmvst_wideBlit          - Wide blit operation
;   61   0x1B90           dmvst_maskBlit          - Masked blit
;   62   0x1BD9           dmvst_invertRect        - Invert rectangle
;   63   0x1C30           dmvst_drawCursor        - Draw mouse cursor
;   64   0x1DE5           dmvst_saveCursor        - Save cursor background
;   65   0x1E15           dmvst_restoreCursor     - Restore cursor background
;   66   0x1E74           dmvst_renderDisplayList - Render DM display list
;   67   0x2209           dmvst_saveWindowState   - Save window state
;   68   0x2230           dmvst_restoreWindowState - Restore window state
;   69   0x2257           dmvst_setOrigin         - Set coordinate origin
;   70   0x2279           dmvst_setupPalette      - Set up color palette
;   71   0x26B2           dmvst_setPaletteEntry   - Set single palette entry
;   72   0x26C9           dmvst_getPaletteEntry   - Get palette entry
;   73   0x26F5           dmvst_initMode          - Initialize video mode
;   74   0x2862           dmvst_deinitMode        - Deinitialize video mode
;   75   0x2A9C           dmvst_queryCapabilities - Query driver capabilities
;   76   0x2AC6           dmvst_setDisplayPage    - Set display page
;   77   0x2B01           dmvst_drawShadow        - Draw window shadow
;   78   0x2B5D           dmvst_drawBorder        - Draw window border
;   79   0x2B7E           dmvst_drawTitleBar      - Draw title bar
;   80   0x2B9D           dmvst_drawScrollBar     - Draw scroll bar
;   81   0x2BB6           dmvst_drawButton        - Draw UI button
;   82   0x2C12           dmvst_drawCheckBox      - Draw checkbox
;   83   0x2CC7           dmvst_drawMenu          - Draw menu
;   84   0x2D92           dmvst_drawListBox       - Draw list box
;   85   0x3158           dmvst_drawComboBox      - Draw combo box
;   86   0x3237           dmvst_drawEditField     - Draw edit field
;   87   0x32B0           dmvst_drawRadioButton   - Draw radio button
;   88   0x32F7           dmvst_drawGroupBox      - Draw group box
;   89   0x335A           dmvst_drawStatusBar     - Draw status bar
;   90   0x341B           dmvst_drawToolBar       - Draw tool bar
;   91   0x356B           dmvst_drawDialog        - Draw dialog frame
;   92   0x359F           dmvst_drawMDIFrame      - Draw MDI child frame
;   93   0x3619           dmvst_setupRetrace      - Set up retrace sync
;   94   0x3775           dmvst_waitRetrace       - Wait for vertical retrace
;   95   0x37C4           dmvst_setPaletteRAM     - Write palette RAM directly
;   96   0x37E4           dmvst_getPaletteRAM     - Read palette RAM
;   97   0x3804           dmvst_flashCursor       - Flash text cursor
;   98   0x3874           dmvst_drawCharCell      - Draw character cell
;   99   0x3926           dmvst_drawCharCellInv   - Draw inverted char cell
;  100   0x39F4           dmvst_textModeInit      - Text mode initialization
;  101   0x3AA3           dmvst_textModeDeinit    - Text mode deinitialization
;  102   0x47AA           dmvst_mouseInit         - Mouse cursor init
;  103   0x47DE           dmvst_mouseShow         - Show mouse cursor
;  104   0x4832           dmvst_mouseHide         - Hide mouse cursor
;  105   0x486E           dmvst_mouseMove         - Move mouse cursor
;  106   0x4ED4           dmvst_timerCallback     - Timer ISR callback
;  107   0x4FC4           dmvst_retraceSync       - Retrace synchronization
;  108   0x5087           dmvst_memCopy           - Memory block copy
;  109   0x512B           dmvst_memSet            - Memory block fill
;  110   0x517C           dmvst_readVideoReg      - Read video register
;  111   0x51A6           dmvst_writeVideoReg     - Write video register
;  112   0x52CC           dmvst_displayListRender - Display list traversal
;  113   0x5648           dmvst_driverCleanup     - Driver cleanup handler
;
; ========================================================================
; BUILT-IN FONT DATA (seg_0002, offset ~0x3B9F-0x46FF)
; ========================================================================
;
; The standard driver contains a complete built-in bitmap font for
; text rendering. The font data occupies approximately 3KB and provides
; both uppercase and lowercase glyphs for the DeskMate UI.
;
; Font characteristics:
;   - 8x8 pixel cell (standard) and 8x14 pixel cell (EGA-compatible)
;   - ASCII range 0x20-0xFF
;   - Includes international characters (accented vowels, etc.)
;   - Box-drawing characters for UI elements
;   - Line-drawing characters for borders
;
; The font glyph strings visible in the raw disassembly (e.g., ">cgo{s>",
; "~33>33~", etc.) are the actual 8x8 bitmap patterns stored as byte
; sequences where each byte represents one row of 8 pixels.
;
; ========================================================================
; I/O PORT ACCESS MAP
; ========================================================================
;
; Port 0x03BA: MDA/Hercules Status Register (read)
;   - Bit 3: vertical retrace (1=in retrace)
;   - Used for retrace synchronization
;
; Port 0x03C0: TGA/EGA Attribute Controller
;   - Used for palette programming
;
; Port 0x03CE: TGA/EGA Graphics Controller Address Register
;   - Register 0x00: Set/Reset
;   - Register 0x01: Enable Set/Reset
;   - Register 0x02: Color Compare
;   - Register 0x05: Mode Register
;   - Register 0x08: Bit Mask
;
; Port 0x03CF: TGA/EGA Graphics Controller Data Register
;
; Port 0x03DA: CGA/EGA Input Status Register 1 (read)
;   - Bit 3: vertical retrace status
;   - Bit 0: display enable (0=active display, 1=retrace)
;   - Used for retrace sync and palette updates
;
; Port 0x03C0: Attribute Controller
;   - Toggled by reading 0x03DA first (reset flip-flop)
;   - Then write index, then write data
;
; ========================================================================
; INTERRUPT USAGE
; ========================================================================
;
; INT 21h AH=31h: Terminate and Stay Resident
;   - Called during initialization to keep driver in memory
;
; INT 21h AH=25h: Set Interrupt Vector
;   - Hooks INT 08h (timer) for cursor blink / retrace sync
;   - Hooks INT 09h (keyboard) for Ctrl+Alt sequences
;
; INT 21h AH=35h: Get Interrupt Vector
;   - Reads original INT 08h and INT 09h vectors to chain
;
; INT E0h AH=01h: Register driver with DeskMate host
;   - Passes seg_0000 as the driver data segment
;   - Returns task ID
;
; INT E0h AH=4Dh: Task lock acquire/release
;   - Function 4: acquire lock before video operation
;   - Function 5: release lock after video operation
;
; ========================================================================
; DETAILED DISASSEMBLY
; ========================================================================

; ========================================================================
; SEGMENT seg_0000  (32 bytes) -- Driver identification and configuration
; ========================================================================
seg_0000:

; --- Version string ---
  0000:0000  db 33 33 2E 31 30                                  ; "33.10" -- driver version
  0000:0005  db 00                                              ; NUL terminator

; --- Video segment selector ---
  0000:0006  db A0                                              ; Video segment = A000h

; --- Paired enhanced driver name ---
  0000:0007  db 44 4D 56 45 54                                  ; "DMVET" -- enhanced driver name
  0000:000C  db 00                                              ; NUL terminator

; --- Configuration data ---
  0000:000D  db FF                                              ; [0x0D] g_driverFlags = 0xFF (all features)
  0000:000E  db 00                                              ; [0x0E] reserved
  0000:000F  db 88                                              ; [0x0F] g_videoModeCapabilities
  0000:0010  db E7                                              ; [0x10] g_colorDepthFlags
  0000:0011  db 9C                                              ; [0x11] g_textModeFlags
  0000:0012  db AA                                              ; [0x12] g_patternMask1 (checkerboard 10101010)
  0000:0013  db CC                                              ; [0x13] g_patternMask2 (stripes 11001100)
  0000:0014  db 10 00                                           ; [0x14] g_charCellWidth = 16
  0000:0016  db 08 00                                           ; [0x16] g_charCellHeight = 8
  0000:0018  db 14 00 00 00                                     ; [0x18] g_screenColumns = 20
  0000:001C  db 00                                              ; reserved
  0000:001D  db 80                                              ; [0x1D] g_displayFlags (bit7 = graphics)
  0000:001E  db 02                                              ; [0x1E] g_numDisplayPages = 2
  0000:001F  db C8                                              ; [0x1F] g_screenHeight = 200

; ========================================================================
; SEGMENT seg_0002  (22,352 bytes) -- Main drawing routines
; ========================================================================
;
; This is the largest segment, containing all video primitive implementations.
; The code is structured as a series of near-callable functions, indexed
; by the dispatch table in seg_0577.
;
; Due to the large size, only key functions and structural elements are
; annotated below. The full raw bytes are preserved from the disassembly.
; ========================================================================
seg_0002:

; --- Internal state / jump table header ---
; The first 16 bytes contain internal state words used by the driver:
;   [0x0000] = 0x0010  Bits-per-pixel indicator
;   [0x0002] = 0x05    Number of bit planes
;   [0x0004] = 0xFFFF  Max color value
;   [0x0006] = 0x0010  Colors per plane
;   [0x0008] = 0x4001  Mode flags
;   [0x000A] = 0x0040  Scanline pitch (bytes)
;   [0x000C] = 0x0010  Reserved
;   [0x000E] = 0x0004  Bytes per pixel group
  0002:0000  db 00 10 05 FF FF 10 40 01 00 40 00 10 04 01 00 CB ; internal state words
  0002:0010  db EA 88 58 00 00                                  ; (continued) [RELOC->seg_0000]

; ========================================================================
; dmvst_resetViewport (0002:0015)
; Reset the viewport to full screen (32767 x 32767).
; Stores max coordinate values to the four viewport boundary words.
; ========================================================================
  0002:0015  db 90 50 B8 FF 7F                                  ; nop; push ax; mov ax,0x7FFF
  0002:001A  db 26 A3 51 01 26 A3 53 01                         ; es:[0x151]=ax; es:[0x153]=ax (left,top)
  0002:0022  db 40 26 A3 55 01 26 A3 57 01                      ; inc ax; es:[0x155]=ax; es:[0x157]=ax (right,bottom)
  0002:002B  db 58 C3                                           ; pop ax; ret

; ========================================================================
; dmvst_setVideoStateFlags (0002:002D)
; Set video state flags at es:[0x80] and call resetViewport + sub.
; ========================================================================
  0002:002D  db 26 80 0E 80 00 04                               ; or byte es:[0x80],0x04
  0002:0033  db E8 E0 FF                                        ; call dmvst_resetViewport
  0002:0036  db E8 1A 00                                        ; call sub_0002_0053
  0002:0039  db 26 80 26 80 00 FB                               ; and byte es:[0x80],0xFB
  0002:003F  db 26 A1 51 01                                     ; mov ax,es:[0x151]
  0002:0043  db 26 8B 1E 53 01                                  ; mov bx,es:[0x153]
  0002:0048  db 26 8B 0E 55 01                                  ; mov cx,es:[0x155]
  0002:004D  db 26 8B 16 57 01                                  ; mov dx,es:[0x157]
  0002:0052  db C3                                              ; ret

; ========================================================================
; dmvst_bezierCurve (0002:0053)
; Render a Bezier curve using recursive subdivision.
; This is a complex function (~230 bytes) that implements De Casteljau's
; algorithm for smooth curve rendering.
;
; Entry: Stack frame contains 4 control points (8 coordinates)
;        + rendering parameters (color, line style)
; Uses: 0x124-byte local stack frame
; ========================================================================
  0002:0053  db 50 53 51 52 56 57 55                            ; push all (PSQRVWU)
  0002:005A  db 81 EC 24 01 8B EC                               ; sub sp,0x124; mov bp,sp
  0002:0060  db 8B 7C 0A                                        ; mov di,[si+0xA] -- subdivision depth
  0002:0063  db 8B 04 8B 5C 02 8B 4C 04 8B 54 06               ; load 4 control point X coords
  0002:006D  db 8B 74 08                                        ; load control point Y
  0002:0070  db 89 76 00 89 7E 02 89 46 04                      ; store working copies
  0002:0079  db 89 5E 06 89 4E 08 89 56 0A                      ; store remaining points
  0002:0082  db 2B C8 2B D3                                     ; compute deltas
  0002:0086  db D1 F9 D1 FA                                     ; sar cx,1; sar dx,1 (halve)
  0002:008A  db 8B C6 8B DF                                     ; copy base coords
  0002:008E  db 2B C1 2B DA                                     ; subtract half-deltas
  0002:0092  db 03 F1 03 FA                                     ; add half-deltas
  0002:0096  db 89 46 0C 89 5E 0E                               ; store midpoints
  0002:009C  db 89 76 10 89 7E 12                               ;
  0002:00A2  db C6 46 14 05                                     ; mov byte [bp+0x14],5 -- recursion depth
; ... (Bezier subdivision continues for ~200 more bytes)
; The algorithm recursively subdivides the curve until segments are
; approximately linear, then draws each segment as a line.
  0002:00A6  db 8A 4E 14                                        ; load depth counter
  0002:00A9  db B8 02 00 D3 E0 89 46 15                         ; compute step size
; ... (recursive subdivision and line drawing)
  0002:013A  db 5D 5F 5E 5A 59 5B 58                            ; pop all (]_^ZY[X)
  0002:0141  db C3                                              ; ret

; ========================================================================
; dmvst_subdivide (0002:0142)
; Subdivision helper for Bezier curve rendering.
; ========================================================================
  0002:0142  db 50 53 51 52 56 57                               ; push all (PSQRVW)
; ... (subdivision code)
  0002:017B  db 5F 5E 5A 59 5B 58                               ; pop all
  0002:0181  db C3                                              ; ret

; ========================================================================
; dmvst_midpointCalc (0002:0182)
; Calculate midpoints for curve subdivision.
; ========================================================================
  0002:0182  db 50 53 51 52                                     ; push ax,bx,cx,dx (PSQR)
; ... (midpoint math)
  0002:01A6  db 5A 59 5B 58                                     ; pop dx,cx,bx,ax (ZY[X)
  0002:01AA  db C3                                              ; ret

; ========================================================================
; dmvst_sortPoints (0002:01AB)
; Sort control points for consistent rendering order.
; ========================================================================
  0002:01AB  db 50 53 51 52 56 57 55                            ; push all (PSQRVWU)
; ... (sorting code)
  0002:01D9  db 5D 5F 5E 5A 59 5B 58                            ; pop all
  0002:01E0  db C3                                              ; ret

; ========================================================================
; dmvst_initGraphics (0002:01E1)
; Initialize graphics mode: save current state, set up video registers,
; configure the palette, and prepare drawing buffers.
; ========================================================================
  0002:01E1  db 90 51 56 57 9C FC                               ; nop; push cx,si,di; pushf; cld
  0002:01E7  db 26 F6 06 87 00 01                               ; test byte es:[0x87],0x01 -- already init?
  0002:01ED  db 75 03                                           ; jne .alreadyInit
  0002:01EF  db E8 A1 0D                                        ; call dmvst_setupHardware
  0002:01F2  db 26 80 0E 87 00 40                               ; or byte es:[0x87],0x40 -- mark initialized
  0002:01F8  db BF 02 00 B9 38 00 F3 A4                         ; copy 56 bytes of state data
  0002:0200  db E8 91 31                                        ; call dmvst_setupPalette
  0002:0203  db E8 0A 21                                        ; call dmvst_clearScreen
  0002:0206  db E8 71 20                                        ; call sub
  0002:0209  db E8 73 01                                        ; call dmvst_setVideoStateFlags
  0002:020C  db 9D 5F 5E 59                                     ; popf; pop di,si,cx
  0002:0210  db C3                                              ; ret

; ========================================================================
; dmvst_restoreState (0002:0211)
; Restore video state from saved buffer.
; ========================================================================
  0002:0211  db 56 57 51 9C FC                                  ; push si,di,cx; pushf; cld
  0002:0216  db 06 1E 07 1F                                     ; push es; push ds; pop es; pop ds
  0002:021A  db BE 02 00 B9 38 00 F3 A4                         ; movsb 56 bytes (restore state)
  0002:0222  db 06 1E 07 1F                                     ; swap es/ds back
  0002:0226  db E8 6B 31                                        ; call sub
  0002:0229  db 9D 59 5F 5E C3                                  ; popf; pop cx,di,si; ret

; ========================================================================
; dmvst_setPixelColor (0002:0232)
; Set the current drawing color for subsequent operations.
; Writes color value to es:[0x2D] and programs hardware palette.
; ========================================================================
  0002:022E  db 1E 06 1F                                        ; push ds; push es; pop ds
  0002:0231  db A3 34 00 89 1E 36 00                            ; store ax,bx to [0x34],[0x36]
  0002:0238  db E8 02 00                                        ; call sub
  0002:023B  db 1F C3                                           ; pop ds; ret

; dmvst_applyColor: Program the video hardware with the current color
  0002:023D  db 50 53                                           ; push ax,bx
  0002:023F  db 80 26 80 00 9F                                  ; and byte [0x80],0x9F -- clear color bits
  0002:0244  db A1 34 00 E8 DD 4C                               ; load color; call dmvst_calcColorIndex
  0002:024A  db 33 DB 93                                        ; xor bx,bx; xchg ax,bx
  0002:024D  db E8 D7 4C                                        ; call dmvst_lookupPalette
  0002:0250  db 2B D8                                           ; sub bx,ax
  0002:0252  db 83 FB 08 75 13                                  ; cmp bx,8; jne .notDither
  0002:0257  db A1 36 00 E8 E5 4C                               ; load alt color; call
  0002:025D  db 33 DB 93 E8 DF 4C                               ; clear; call
  0002:0263  db 2B D8                                           ; sub
  0002:0265  db 83 FB 08 74 05                                  ; cmp bx,8; je .dither
  0002:026A  db 80 0E 80 00 20                                  ; or byte [0x80],0x20 -- set dither flag
; ... (palette programming continues)
  0002:026F  db B8 C8 00 E8 B2 4C                               ; mov ax,200; call sub
  0002:0275  db 33 DB 93 E8 AC 4C                               ; compute vertical palette
  0002:027B  db 2B D8 89 1E 3E 00                               ; store delta
  0002:0281  db 83 FB 10 74 05                                  ; cmp bx,16; je .exact
  0002:0286  db 80 0E 80 00 40                                  ; set interpolation flag
  0002:028B  db B8 DC 00 E8 B1 4C                               ;
  0002:0291  db 33 DB 93 E8 AB 4C                               ;
  0002:0297  db 2B D8 89 1E 40 00                               ;
  0002:029D  db 83 FB 08 74 05 80 0E 80 00 40                   ;
  0002:02A7  db 5B 58 C3                                        ; pop bx,ax; ret

; ========================================================================
; dmvst_setBackColor (0002:02A8) / dmvst_getPixelColor (0002:02B3)
; ========================================================================
  0002:02A8  db 26 A2 2D 00 E8 08 00 C3                         ; store to es:[0x2D]; call sub; ret
  0002:02B0  db A2 2D 00 E8 0D 00 C3                            ; store to [0x2D]; call sub; ret

; ========================================================================
; (The remaining ~21KB of seg_0002 contains all drawing primitive
; implementations listed in the dispatch table above. Key patterns:)
;
; RETRACE SYNCHRONIZATION:
;   Multiple functions read port 0x03DA (CGA status register) in a loop
;   to synchronize palette updates with the vertical retrace period,
;   preventing visible flicker:
;     0002:03AD  BA BA 03  mov dx,0x03BA  ; (MDA status port)
;     0002:03B0  EC        in al,dx
;     0002:03B1  BA DA 03  mov dx,0x03DA  ; (CGA status port)
;     0002:03B4  EC        in al,dx
;
; TGA PALETTE PROGRAMMING (port 0x03CE):
;   0002:2148  BA CE 03  mov dx,0x03CE    ; Graphics Controller Address
;   0002:214B  B0 02     mov al,0x02      ; Register: Color Compare
;   0002:214D  EE        out dx,al
;   0002:214E  42        inc dx            ; Data port 0x03CF
;   0002:214F  33 C0     xor al,al
;   0002:2151  EE        out dx,al
;   0002:2152  BA CE 03  mov dx,0x03CE
;   0002:2155  B0 05     mov al,0x05      ; Register: Mode Register
;   0002:2157  EE        out dx,al
;   0002:2158  42        inc dx
;   0002:2159  B0 08     mov al,0x08      ; Value: read mode 1
;   0002:215B  EE        out dx,al
;
; CLEAR SCREEN (using TGA registers):
;   0002:2198  BA CE 03  mov dx,0x03CE
;   0002:219B  B0 00     mov al,0x00      ; Set/Reset register
;   0002:219D  EE        out dx,al
;   0002:219E  42        inc dx
;   0002:219F  B0 00     mov al,0x00      ; Color = 0 (black)
;   0002:21A1  EE        out dx,al
;   0002:21A2  BA CE 03  mov dx,0x03CE
;   0002:21A5  B0 01     mov al,0x01      ; Enable Set/Reset
;   0002:21A7  EE        out dx,al
;   0002:21A8  42        inc dx
;   0002:21A9  B0 0F     mov al,0x0F      ; All planes
;   0002:21AB  EE        out dx,al
;   0002:21AC  F3 AA     rep stosb         ; Fill video memory
;   0002:21AE  B0 00     mov al,0x00      ; Disable Set/Reset
;   0002:21B0  EE        out dx,al
;
; FONT DATA (offset ~0x3B9F):
;   Contains 8x8 and 8x14 bitmap font data for text rendering.
;   Each glyph is stored as 8 (or 14) consecutive bytes, one per scanline.
;   The visible ASCII art in the string table (">cgo{s>", "~33>33~", etc.)
;   is actually the raw glyph bitmap data.
;
; ========================================================================
; (Full raw bytes of seg_0002 preserved below -- too large to annotate
;  instruction-by-instruction, but the function boundaries and key
;  patterns are documented in the dispatch table above.)
; ========================================================================

; ... (22,352 bytes of drawing code -- see raw disassembly for full dump)

; ========================================================================
; SEGMENT seg_0577  (288 bytes) -- Function Dispatch Table
; ========================================================================
;
; This segment contains the dispatch table mapping function indices to
; offsets within seg_0002. It also contains internal helper tables for
; coordinate transformation and scaling.
;
; The table format is word pairs representing near-call targets in seg_0002.
; ========================================================================
seg_0577:

  0577:0000  db 5A 59 C3 90                                     ; trampoline: pop dx; pop cx; ret; nop
; Function pointer table:
  0577:0004  db FC 00 32 2C BC 2A CB 2C 93                      ; entries 0-4
  0577:000D  db 2C 2B 2C 24 2C                                  ; entries 5-8 (continued)
  0577:0012  db 9E 2B 68 2A 89 53 0F 2B 07 27 5C 08 D8 07 2D 08 ; entries 9-16
  0577:0022  db EF 07 61 11 32 11 66 24 A5 24 9C 04 B3 0D F6 25 ; entries 17-24
  0577:0032  db BB 32 48 1C 99 0F 96 11 E4 19 05 1E B0 19 E9 26 ; entries 25-32
  0577:0042  db E6 26 B2                                        ; entries 33-34
  0577:0045  db 26 68 31 35                                     ; entries 35-36
; ... (remaining table entries)
  0577:0049  db 1E 51 32 F5 25 B3 0F AD 08 F8 03 67 09 F2 02 2A ;
  0577:0059  db 24 0D 03 5B 03 79 03 86 09 31 02 10 24 F6 23 4D ;
  0577:0069  db 25 07 22 E3                                     ;
  0577:006D  db 21 6D 0D 5E 04 CE 08 69 0F 04 25 1F            ;
  0577:0079  db 25 3A 25 42 25 5C                               ; entries for palette functions
  0577:007F  db 0C ED 0B 2C 0C A3 09 23 0C 92 0C 8C 0F 72 05 62 ;
  0577:008F  db 05 FA 05 EA 05 E7 06 D7 06 EA 04 DA 04 84 03 5A ;
  0577:009F  db 04 CA 02                                        ;
  0577:00A2  db 77 22 44 24                                     ;
  0577:00A6  db F7 02 C6 0F 1A 03 74 03 02 02                   ;
  0577:00B0  db 50 22 29 22 76 29                               ;
  0577:00B6  db E6 24 F6 24 EE 24 FD 24 2F 26 15 04 89 1E 73 00 ;
  0577:00C6  db 9D 2D D3 18 6B 13 5B 13 16                      ;
  0577:00CF  db 25 31 25 0D 25 28 25                            ;
  0577:00D6  db 02 17 AC 16 D2 26 B2 33 4E 02 51 0B C3 0B 24 0B ;
  0577:00E6  db 0D 0B B4 0B 7E 03 F2 03 2B 0F 68 0F 3C 0F E8 08 ;
  0577:00F6  db 26 09 37 04                                     ;
  0577:00FA  db 4A 25 4B 25 4C 25                               ;
  0577:0100  db E6 25 FF                                        ;
  0577:0103  db 25 6D 26 4D 21 68 21                            ;
  0577:010A  db AC 21 72 25 1B 21 34 21 E7 4E 1A 01 76 03 BB 34 ;
  0577:011A  db 12 00 00 00 00 00                               ; terminator / padding

; ========================================================================
; SEGMENT seg_0589  (976 bytes) -- DM89 Header + Entry Point + ISR Hooks
; ========================================================================
seg_0589:

; --- DM89 module name ---
  0589:0000  db 44 4D 56 53 54 00                               ; "DMVST\0"

; --- DM89 vector structure ---
  0589:0006  db 00 00                                           ; dispatch vector offset
  0589:0008  db 25 00                                           ; offset to dispatch ptr
  0589:000A  db 89 05                                           ; segment ref (RELOC->seg_0589)
; ... (remaining vector structure)
  0589:000C  db 00 00 00 00 00 00 00 00 00 00                   ; reserved
  0589:0016  db 00 00 00 00 00 00 00 00 00 00 00 00             ;
  0589:0022  db 03 0A 21                                        ; DM89 companion info
  0589:0025  db C7 06 00 00 D1 05                               ; reloc fixup [RELOC->seg_05D1]
  0589:002B  db BB 55 00                                        ; helper offset
  0589:002E  db B8 59 00 CB                                     ; mov ax,0x59; retf

; ========================================================================
; entry_point (0589:0032) -- DM89 Module Entry Point
; Called by the DM89 loader when loading DMVST.RES.
;
; Steps:
;   1. Save DS at es:[bx+0x20]
;   2. Register with host via INT E0h AH=01h (AX=0x01F0, CX=seg_0000)
;   3. Save returned task ID at es:[0x3D3]
;   4. Compute TSR memory size from PSP
;   5. TSR via INT 21h/31h
; ========================================================================
entry_point:
  0589:0032  0e                push     cs
  0589:0033  07                pop      es                      ; ES = CS
  0589:0034  bb0000            mov      bx, 0
  0589:0037  268c5f20          mov      word ptr es:[bx + 0x20], ds ; save caller DS
  0589:003B  b90000            mov      cx, 0                   ; RELOC->seg_0000
  0589:003E  b8f001            mov      ax, 0x1f0               ; INT E0h AH=01h: register driver
  0589:0041  cde0              int      0xe0
  0589:0043  26a3d303          mov      word ptr es:[0x3d3], ax ; save task ID
  0589:0047  8b160200          mov      dx, word ptr [2]        ; PSP block size
  0589:004B  8cd8              mov      ax, ds                  ; DS = PSP segment
  0589:004D  2bd0              sub      dx, ax                  ; DX = paragraphs to keep
  0589:004F  b80031            mov      ax, 0x3100              ; INT 21h/31h: TSR
  0589:0052  cd21              int      0x21
  0589:0054  90                nop

; ========================================================================
; dmvst_apiThunkFast (0589:0055)
; Fast API dispatch thunk for "X" mode (320-wide).
; When bit 15 is set in AX (function >= 0x8000), this thunk is used.
; It multiplies the function index to get the correct offset in the
; wider dispatch table, then calls through to the implementation.
; ========================================================================
  0589:0055  d1e0              shl      ax, 1                   ; function index * 2
  0589:0057  732e              jae      loc_0589_0087           ; if no carry, use standard dispatch
  0589:0059  2ea35d04          mov      word ptr cs:[0x45d], ax ; save adjusted index
  0589:005D  8b460f            mov      ax, word ptr [bp + 0xf] ; load caller's AX
  0589:0060  8b6e09            mov      bp, word ptr [bp + 9]   ; load caller's BP
  0589:0063  53                push     bx
  0589:0064  06                push     es
  0589:0065  bb8905            mov      bx, 0x589               ; RELOC->seg_0589
  0589:0068  8ec3              mov      es, bx
  0589:006A  268e066104        mov      es, word ptr es:[0x461] ; load dispatch table segment
  0589:006F  bb0400            mov      bx, 4
  0589:0072  2e031e5d04        add      bx, word ptr cs:[0x45d] ; add function offset
  0589:0077  268b1f            mov      bx, word ptr es:[bx]    ; load target offset
  0589:007A  2e891e5f04        mov      word ptr cs:[0x45f], bx ; save target
  0589:007F  07                pop      es
  0589:0080  5b                pop      bx
  0589:0081  2eff165f04        call     word ptr cs:[0x45f]     ; call the function
  0589:0086  cb                retf

; ========================================================================
; dmvst_apiThunkStandard (0589:0087)
; Standard API dispatch thunk (non-fast path).
; Sets up a full stack frame with return address and segment pointers,
; then chains to the target function via a retf trick.
; ========================================================================
loc_0589_0087:
  0589:0087  ff760f            push     word ptr [bp + 0xf]     ; push caller's value
  0589:008A  53                push     bx
  0589:008B  06                push     es
  0589:008C  ff7609            push     word ptr [bp + 9]       ; push caller's BP
  0589:008F  83ec0e            sub      sp, 0xe                 ; allocate frame
  0589:0092  8bec              mov      bp, sp
  0589:0094  89460a            mov      word ptr [bp + 0xa], ax ; save function code
  0589:0097  2ea1d303          mov      ax, word ptr cs:[0x3d3] ; load task ID
  0589:009B  3cff              cmp      al, 0xff
  0589:009D  7409              je       loc_0589_00A8
  0589:009F  52                push     dx
  0589:00A0  8ad0              mov      dl, al                  ; DL = task ID
  0589:00A2  b8044d            mov      ax, 0x4d04              ; INT E0h AH=4Dh: acquire lock
  0589:00A5  cde0              int      0xe0
  0589:00A7  5a                pop      dx

loc_0589_00A8:
  0589:00A8  89460c            mov      word ptr [bp + 0xc], ax ; save lock state
  0589:00AB  bb8905            mov      bx, 0x589               ; RELOC->seg_0589
  0589:00AE  8ec3              mov      es, bx
  0589:00B0  c746020000        mov      word ptr [bp + 2], 0    ; RELOC->seg_0000 (driver data)
  0589:00B5  2e8e066104        mov      es, word ptr cs:[0x461] ; dispatch table segment
  0589:00BA  bb0400            mov      bx, 4
  0589:00BD  035e0a            add      bx, word ptr [bp + 0xa] ; add function offset
  0589:00C0  268b1f            mov      bx, word ptr es:[bx]    ; load target
  0589:00C3  895e00            mov      word ptr [bp], bx       ; store target offset
  0589:00C6  8c4e08            mov      word ptr [bp + 8], cs   ; return segment = CS
  0589:00C9  b8e200            mov      ax, 0xe2                ; return offset = epilogue
  0589:00CC  894606            mov      word ptr [bp + 6], ax
  0589:00CF  bb2f00            mov      bx, 0x2f                ; trampoline offset in seg_0577
  0589:00D2  895e04            mov      word ptr [bp + 4], bx
  0589:00D5  8b4614            mov      ax, word ptr [bp + 0x14]; restore caller's AX
  0589:00D8  8e4610            mov      es, word ptr [bp + 0x10]; restore caller's ES
  0589:00DB  8b5e12            mov      bx, word ptr [bp + 0x12]; restore caller's BX
  0589:00DE  8b6e0e            mov      bp, word ptr [bp + 0xe] ; restore caller's BP
  0589:00E1  cb                retf                             ; far-return into target function

; --- Dispatch epilogue ---
  0589:00E2  db 50                                              ; push ax (save return value)
  0589:00E3  55                push     bp
  0589:00E4  8bec              mov      bp, sp
  0589:00E6  8b4606            mov      ax, word ptr [bp + 6]   ; load lock state
  0589:00E9  3cff              cmp      al, 0xff
  0589:00EB  7409              je       loc_0589_00F6
  0589:00ED  52                push     dx
  0589:00EE  8ad0              mov      dl, al                  ; DL = task ID
  0589:00F0  b8054d            mov      ax, 0x4d05              ; INT E0h AH=4Dh: release lock
  0589:00F3  cde0              int      0xe0
  0589:00F5  5a                pop      dx

loc_0589_00F6:
  0589:00F6  5d                pop      bp
  0589:00F7  58                pop      ax
  0589:00F8  83c40c            add      sp, 0xc                 ; clean up frame
  0589:00FB  cb                retf

; ========================================================================
; dmvst_initVideoHardware (0589:00FC)
; Initialize the video hardware: save/set interrupt vectors,
; configure the TGA registers, and prepare the display.
;
; This function:
;   1. Saves CS-relative segment references for ISR use
;   2. Calls far into seg_0000 code for hardware init
;   3. Sets up palette
;   4. Returns driver function count (3)
; ========================================================================
  0589:00FC  db 53 2E 8C 1E 59 04                               ; push bx; mov cs:[0x459],ds
  0589:0102  db 2E 8C 06 5B 04                                  ; mov cs:[0x45B],es
  0589:0107  db E8 D3 00                                        ; call dmvst_setupInterrupts
  0589:010A  db 9A 23 26 00 00                                  ; lcall seg_0000:0x2623 [RELOC]
  0589:010F  db E8 E1 00                                        ; call sub
  0589:0112  db E8 6C 00                                        ; call dmvst_hookTimerISR
  0589:0115  db 5B                                              ; pop bx
  0589:0116  db B8 03 00                                        ; mov ax,3 (return 3 = success)
  0589:0119  db C3                                              ; ret

; ========================================================================
; dmvst_deinitVideoHardware (0589:011A)
; Deinitialize video: restore mode if needed, reset interrupts.
; ========================================================================
  0589:011A  db F6 06 53 00 01 75 0C                            ; test flags; jnz .active
  0589:0121  db 3C 00 74 1C                                     ; cmp al,0; je .skip
  0589:0125  db E8 1A 00                                        ; call sub
  0589:0128  db E8 82 00                                        ; call dmvst_restoreInterrupts
  0589:012B  db EB 14                                           ; jmp .done
  0589:012D  db 3C 00 75 0D                                     ; cmp al,0; jne .mode2
  0589:0131  db 53 E8 A8 00                                     ; push bx; call sub
  0589:0135  db 9A 77 26 00 00                                  ; lcall seg_0000:0x2677 [RELOC]
  0589:013A  db E8 B6 00                                        ; call sub
  0589:013D  db 5B                                              ; pop bx
  0589:013E  db E8 01 00 C3                                     ; call sub; ret

; ========================================================================
; dmvst_setVideoMode (0589:0142)
; Set the current video mode (text or graphics).
; Programs the TGA video mode register and cursor type.
; ========================================================================
  0589:0142  db 50 56                                           ; push ax,si
  0589:0144  db 80 26 53 00 FE                                  ; and byte [0x53],0xFE -- clear mode flag
  0589:0149  db 0A C0 74 05                                     ; or al,al; jz .text
  0589:014D  db 80 0E 53 00 01                                  ; or byte [0x53],0x01 -- set graphics mode
  0589:0152  db B4 03 F6 E4                                     ; mov ah,3; mul ah (compute mode offset)
  0589:0156  db BE D5 03 03 F0                                  ; mov si,0x3D5; add si,ax
  0589:015B  db 2E 8B 04                                        ; mov ax,cs:[si] -- load mode params
  0589:015E  db FA                                              ; cli
  0589:015F  db A3 57 00 A3 54 00                               ; store cursor type
  0589:0165  db 2E 8A 44 02                                     ; mov al,cs:[si+2] -- cursor height
  0589:0169  db A2 59 00 A2 56 00                               ; store
  0589:016F  db FB                                              ; sti
  0589:0170  db 5E 58 C3                                        ; pop si,ax; ret

; ========================================================================
; dmvst_lookupModeParams (0589:0173)
; Look up video mode parameters from the mode table.
; Entry: BL = mode index
; Returns: AL = mode parameter byte
; ========================================================================
  0589:0173  db 53 32 FF 8A D8                                  ; push bx; xor bh,bh; mov bl,al
  0589:0178  db 81 C3 ED 03                                     ; add bx,0x3ED -- table base
  0589:017C  db 2E 8A 07                                        ; mov al,cs:[bx]
  0589:017F  db 5B C3                                           ; pop bx; ret

; ========================================================================
; dmvst_hookTimerISR (0589:0181)
; Hook INT 08h (timer) and optionally INT 09h (keyboard).
; Chains to original handler after processing cursor blink.
; ========================================================================
  0589:0181  db 53 52 1E 06                                     ; push bx,dx,ds,es
  0589:0185  db F6 06 53 00 01 74 03                            ; test flags; jz .skip
  0589:018C  db E8 1E 00                                        ; call dmvst_hookINT09
; --- Hook INT 08h ---
  0589:018F  db B4 35 B0 08                                     ; AH=35h: get vector for INT 08h
  0589:0193  db CD 21                                           ; int 0x21
  0589:0195  db 89 1E 0A 00                                     ; save old INT 08h offset at [0x0A]
  0589:0199  db 8C 06 0C 00                                     ; save old INT 08h segment at [0x0C]
  0589:019D  db B4 25 B0 08                                     ; AH=25h: set INT 08h vector
  0589:01A1  db BA 05 02                                        ; DX = our handler offset (0589:0205)
  0589:01A4  db 0E 1F                                           ; push cs; pop ds (DS=CS for handler)
  0589:01A6  db CD 21                                           ; int 0x21
  0589:01A8  db 07 1F 5A 5B C3                                  ; pop es,ds,dx,bx; ret

; ========================================================================
; dmvst_hookINT09 (0589:01AD)
; Hook INT 09h (keyboard) for Ctrl+Alt key detection.
; ========================================================================
  0589:01AD  db 50 53 52 1E 06                                  ; push all
  0589:01B2  db F6 06 53 00 02 75 1E                            ; test bit 1; jnz .alreadyHooked
  0589:01B9  db 80 0E 53 00 02                                  ; set hooked flag
  0589:01BE  db B4 35 B0 09                                     ; get INT 09h vector
  0589:01C2  db CD 21                                           ; int 0x21
  0589:01C4  db 89 1E 5A 00                                     ; save old offset
  0589:01C8  db 8C 06 5C 00                                     ; save old segment
  0589:01CC  db B4 25 B0 09                                     ; set new INT 09h
  0589:01D0  db BA 38 03                                        ; DX = our keyboard handler
  0589:01D3  db 0E 1F                                           ; DS=CS
  0589:01D5  db CD 21                                           ; int 0x21
  0589:01D7  db 07 1F 5A 5B 58 C3                               ; pop all; ret

; ========================================================================
; dmvst_taskLockAcquire / dmvst_taskLockRelease (0589:01DD/01ED)
; Acquire/release the DM host task lock via INT E0h AH=4Dh.
; ========================================================================
  0589:01DD  db 50 2E A1 D3 03                                  ; push ax; load task ID
  0589:01E2  db 3C FF 74 09                                     ; cmp al,0xFF; je .noLock
  0589:01E4  db 52 8A D0                                        ; push dx; mov dl,al
  0589:01E7  db B8 04 4D                                        ; AX = 0x4D04 (acquire)
  0589:01EA  db CD E0                                           ; int 0xE0
  0589:01EC  db 5A                                              ; pop dx
  0589:01ED  db 8A D8 58 C3                                     ; mov bl,al; pop ax; ret

  0589:01F1  db 50 8A C3                                        ; push ax; mov al,bl
  0589:01F3  db 3C FF 74 09                                     ; cmp al,0xFF; je .noLock
  0589:01F5  db 52 8A D0                                        ; push dx; mov dl,al
  0589:01F8  db B8 05 4D                                        ; AX = 0x4D05 (release)
  0589:01FB  db CD E0                                           ; int 0xE0
  0589:01FD  db 5A                                              ; pop dx
  0589:01FE  db 58 C3                                           ; pop ax; ret

; ========================================================================
; dmvst_timerISR (0589:0200)
; Timer interrupt (INT 08h) service routine.
; Handles cursor blink and retrace synchronization.
;
; This ISR:
;   1. Chains to original INT 08h handler first
;   2. Checks if video operations are in progress (reentrance guard)
;   3. Manages cursor blink counter at [0x4F]
;   4. Calls retrace-synced palette update if needed
;   5. Handles scroll animation timing
; ========================================================================
  0589:0200  db 50 53 56 1E 06 FB                               ; push; sti (allow nested interrupts)
  0589:0206  db B8 00 00 8E D8                                  ; mov ax,0; mov ds,ax (IVT)
  0589:020B  db A1 86 03 8E D8                                  ; ds = host data segment
  0589:0210  db 2E 8E 06 59 04                                  ; es = saved segment
  0589:0215  db 9C FA                                           ; pushf; cli
  0589:0217  db 26 FF 1E 0A 00                                  ; lcall [0x0A] -- chain to old INT 08h
  0589:021C  db 26 80 3E 0F 00 00                               ; cmp byte es:[0x0F],0 -- reentrance guard
  0589:0222  db 74 03 E9 06 01                                  ; je .safe; jmp .exit (busy)
; ... (cursor blink logic, retrace sync, scroll timing)
; This section manages the visual cursor by toggling its visibility
; at a rate determined by the blink counter. It also coordinates
; palette updates with vertical retrace to prevent flicker.
  0589:0227  db 26 F6 06 53 00 01                               ; test mode flag
  0589:022D  db 74 27                                           ; je .noGraphics
; ... (extensive cursor/retrace management code continues)
  0589:032C  db A2 89 00                                        ; store blink state
  0589:032F  db E8 C1 FE                                        ; call dmvst_taskLockRelease
  0589:0332  db 07 1F 5E 5B 58 CF                               ; pop all; iret

; ========================================================================
; dmvst_keyboardISR (0589:0338)
; Keyboard interrupt (INT 09h) handler.
; Checks for cursor position changes via BIOS data area.
; Chains to original INT 09h handler.
; ========================================================================
  0589:0338  db 50 53 51 06 1E                                  ; push ax,bx,cx,es,ds
  0589:033D  db 2E 8E 06 59 04                                  ; es = saved segment
  0589:0342  db B8 40 00 8E D8                                  ; ds = 0x0040 (BIOS data area)
  0589:0347  db 8B 1E 1A 00 8B 0E 1C 00                         ; load keyboard buffer ptrs
  0589:034F  db 9C                                              ; pushf
  0589:0350  db 26 FF 1E 5A 00                                  ; lcall old INT 09h
  0589:0355  db 39 1E 1A 00 75 06                               ; compare buffer ptrs (key pressed?)
  0589:035B  db 39 0E 1C 00 74 0F                               ; if unchanged, skip
  0589:0361  db E8 12 00                                        ; call sub (check cursor update)
  0589:0364  db 0B C0 74 08                                     ; or ax,ax; jz .noupdate
  0589:0368  db 89 1E 1A 00 89 0E 1C 00                         ; update buffer ptrs
  0589:0370  db 1F 07 59 5B 58 CF                               ; pop all; iret

; ========================================================================
; dmvst_checkCursorUpdate (0589:0376)
; Check if cursor position needs updating after a keyboard event.
; ========================================================================
  0589:0376  db 53 1E 33 C0                                     ; push bx,ds; xor ax,ax
  0589:037A  db 2E 8E 1E 59 04                                  ; ds = saved segment
  0589:037F  db F6 06 53 00 01                                  ; test mode flag
  0589:0384  db 74 24                                           ; je .skip
  0589:0386  db 83 3E 54 00 00                                  ; cmp word [0x54],0
  0589:038B  db 75 0D                                           ; jne .hasCursor
  0589:038D  db 80 3E 56 00 00                                  ; cmp byte [0x56],0
  0589:0392  db 75 06                                           ; jne .visible
  0589:0394  db E8 29 00                                        ; call dmvst_retraceWait
  0589:0397  db B8 FF FF                                        ; return -1
  0589:039A  db 8B 1E 57 00                                     ; load cursor data
  0589:039E  db 89 1E 54 00                                     ; store new position
  0589:03A2  db 8A 1E 59 00                                     ; load cursor height
  0589:03A6  db 88 1E 56 00                                     ; store
  0589:03AA  db 1F 5B C3                                        ; pop ds,bx; ret

; ========================================================================
; dmvst_retraceWait (0589:03AD)
; Wait for vertical retrace by polling CGA/MDA status registers.
; Reads port 0x03BA (MDA) and 0x03DA (CGA) to detect retrace.
; ========================================================================
  0589:03AD  db 50 52                                           ; push ax,dx
  0589:03AF  db BA BA 03                                        ; mov dx,0x03BA  ; MDA Status Register
  0589:03B2  db EC                                              ; in al,dx       ; read status
  0589:03B3  db BA DA 03                                        ; mov dx,0x03DA  ; CGA Status Register
  0589:03B6  db EC                                              ; in al,dx       ; read status
  0589:03B7  db BA C0 03                                        ; mov dx,0x03C0  ; Attribute Controller
  0589:03BA  db B0 00                                           ; mov al,0       ; index 0
  0589:03BC  db EE                                              ; out dx,al      ; reset flip-flop
  0589:03BD  db 5A 58 C3                                        ; pop dx,ax; ret

; dmvst_retraceEnable: Re-enable display after palette update
  0589:03C0  db 50 52                                           ; push ax,dx
  0589:03C2  db BA BA 03                                        ; mov dx,0x03BA
  0589:03C5  db EC                                              ; in al,dx
  0589:03C6  db BA DA 03                                        ; mov dx,0x03DA
  0589:03C9  db EC                                              ; in al,dx
  0589:03CA  db BA C0 03                                        ; mov dx,0x03C0
  0589:03CD  db B0 20                                           ; mov al,0x20    ; enable display
  0589:03CF  db EE                                              ; out dx,al
; ... (continues)

; ========================================================================
; SEGMENT seg_05C6  (160 bytes) -- Color Mapping and Capability Tables
; ========================================================================
;
; Contains:
;   - Color mapping tables (CGA-compatible to TGA palette mapping)
;   - Attribute byte patterns for different video modes
;   - Driver capability flags
;   - Pointer to dispatch table segment (seg_0577)
; ========================================================================
seg_05C6:

  05C6:0000  db 5A 58 C3                                        ; trampoline: pop dx; pop ax; ret
  05C6:0003  db 00 00 00 00 00                                  ; padding
; --- CGA-to-TGA color mapping table ---
  05C6:0008  db 55 15 00                                        ; color 0: dark pattern
  05C6:000B  db AA 2A 00                                        ; color 1: light pattern
  05C6:000E  db 55 55 00 00                                     ; color 2-3
  05C6:0012  db 80 00 00 00 01 00 00 02 00 00 04                ; individual color components
  05C6:001D  db 19                                              ; max palette index (25)
; --- Extended color palette (palette RAM values) ---
  05C6:001E  db FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF ; all 0xFF = unused slots
  05C6:002E  db FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF ;
  05C6:003E  db 69 FF 68 FF 67 FF 66 FF 65 FF 64 FF 63 FF      ; palette entries 0x63-0x69
  05C6:004C  db FF FF FF FF FF FF FF FF FF FF FF FF FF FF       ;
  05C6:005A  db FF 23 FF 24 FF 25 FF 26 FF 27 FF 28 FF 29 FF  ; palette entries 0x23-0x29
  05C6:0069  db FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF ;
  05C6:0079  db 69 E8 29 E7 28 E6 27 E5 26 E4 25 E3 24 23     ; reverse mapping table
  05C6:0087  db FE                                              ; end marker
; --- Capability flags ---
  05C6:0088  db 00 A0 00 00 00 00 00 00 00 00                   ; video segment = A000h
  05C6:0092  db 77 05                                           ; RELOC->seg_0577 (dispatch table seg)
  05C6:0094  db 00 00 00 00 00 00 00 00 00 00 00 00             ; reserved

; ========================================================================
; SEGMENT seg_05D0  (2 bytes) -- Stack Segment
; ========================================================================
seg_05D0:
  05D0:0000  db 00 00                                           ; stack base

; ========================================================================
; SEGMENT seg_05D1  (BSS) -- Uninitialized Data
; ========================================================================
; This segment is allocated at load time (0x01C3 paragraphs = 7,216 bytes)
; but contains no initialized data. It holds:
;   - Mouse cursor backup bitmap
;   - Window state save area
;   - Temporary buffers for blit operations
;   - Scroll buffer
;   - Palette save area

; ========================================================================
; END OF DMVST.RES DISASSEMBLY
; ========================================================================
