; ========================================================================
; DMVSVGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Standard Video Driver: VGA (640x480, 16 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVSVGA.RES is the standard-mode VGA video driver for DeskMate 3.05.
; Standard drivers handle mode switching, cursor management, timer-based
; blinking, window/display list management, font loading, and high-level
; drawing operations. They call into the corresponding enhanced driver
; (DMVEVGA.RES) for pixel-level rendering primitives.
;
; The standard driver installs itself as a TSR via INT 21h/31h and hooks
; INT 08h (timer) and INT 09h (keyboard) for cursor blink and keyboard
; state tracking. It provides a large dispatch table of ~100+ functions
; accessible through the DeskMate host API.
;
; Video mode: VGA mode 12h (640x480, 16 colors, planar)
; Framebuffer: segment A000h
; Bytes per scanline: 80
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 23922 bytes
; Code+data size: 23410 bytes
; DM89 entry point: 0570:0032
; SS:SP = 05B7:0002
; Min alloc: 0x01CA paragraphs
; Max alloc: 0x01CA paragraphs
;
; DM89 signature: present
;
; Segment Map (7 segments, 18 relocations):
;   seg_0000  0x0030 bytes  DATA       Version string + config ("33.19", "DMVEVGA")
;   seg_0003  0x55A0 bytes  CODE/DATA  Main driver code + font data + drawing ops
;   seg_055D  0x0130 bytes  DATA       Function pointer table (dispatch vectors)
;   seg_0570  0x03D0 bytes  CODE       TSR startup, dispatch, INT hooks, mode switch
;   seg_05AD  0x00A0 bytes  DATA       Key mapping table + driver descriptor
;   seg_05B7  0x0002 bytes  STACK      Stack segment
;   seg_05B8  (BSS)         BSS        Uninitialized data segment
;
; ========================================================================
; ARCHITECTURE
; ========================================================================
;
; The standard driver is substantially larger than the enhanced driver
; (~22KB vs ~5KB) and contains:
;
; 1. Configuration Data (seg_0000, 48 bytes):
;    Version string "33.19", enhanced driver name "DMVEVGA",
;    and display configuration bytes (resolution, color depth,
;    capabilities flags).
;
; 2. Main Driver Code (seg_0003, ~22KB):
;    The bulk of the driver. Contains:
;    - Coordinate system management (viewports, clipping)
;    - Window management (create, move, resize, scroll)
;    - Text rendering (font selection, string drawing)
;    - Cursor management (show, hide, blink, shape)
;    - Mouse pointer rendering
;    - Bitmap/icon operations
;    - Line drawing (Bresenham's algorithm)
;    - Rectangle fill (solid, patterned)
;    - Character/font bitmap tables (~8KB of font data)
;    - Display list management
;
; 3. Function Dispatch Table (seg_055D, 304 bytes):
;    Array of ~100 word-sized offsets into seg_0003, indexed by
;    function number. The dispatcher uses this table to route
;    calls from the DeskMate host to the appropriate handler.
;
; 4. TSR/Dispatcher Code (seg_0570, 976 bytes):
;    Entry point, INT 08h/09h hooks, mode switching, and the
;    main function dispatcher that saves context, looks up the
;    function in the dispatch table, calls it, and restores context.
;
; 5. Key Mapping / Descriptor (seg_05AD, 160 bytes):
;    Keyboard scan code to DeskMate key code mapping table,
;    plus the driver descriptor block (framebuffer segment A000h,
;    pointer to function table in seg_055D).
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; VGA Attribute Controller (port 3C0h):
;   Read via port 3BAh (input status 1) to reset flip-flop
;   Write via port 3C0h for index+data
;   0570:03AC  in al, 0x3BA    ; Read input status 1 (reset attr flip-flop)
;   0570:03AF  in al, 0x3DA    ; Read input status 1 (alt port)
;   0570:03B2  in al, 0x3C0    ; Read attribute controller
;   0570:03B5  out 0x3C0, al   ; Write attribute controller (palette disable)
;              mov al, 0x00    ; Index 0 + palette address source = 0
;              out dx, al      ; Write to attribute controller
;
; VGA Attribute Controller (palette enable):
;   0570:03BC  in al, 0x3BA    ; Reset flip-flop
;   0570:03BF  in al, 0x3DA    ; Reset flip-flop (alt)
;   0570:03C2  in al, 0x3C0    ; Read current state
;              mov al, 0x20    ; Palette address source bit = enabled
;              out dx, al      ; Re-enable palette display
;
; These port accesses are used to disable/enable the VGA palette during
; screen updates to prevent visible tearing artifacts. The driver reads
; the input status register to reset the attribute controller flip-flop,
; then writes 0x00 to disable palette output (blanking the screen) or
; 0x20 to re-enable it after the update is complete.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register standard driver with DeskMate host
;   0570:0041  CX=seg_0000 (config data), AX=0x01F0
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex
;   0570:00A5  Before dispatching draw calls
;
; INT E0h, AH=4Dh/05  -- Release display mutex
;   0570:00F3  After draw calls complete
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   0570:0052  Install driver as TSR
;
; INT 21h, AH=25h  -- Set interrupt vector
;   0570:019A  Set INT 08h handler (timer tick for cursor blink)
;   0570:01C8  Set INT 09h handler (keyboard state tracking)
;
; INT 21h, AH=35h  -- Get interrupt vector
;   0570:018E  Save original INT 08h vector
;   0570:01BE  Save original INT 09h vector
;
; ========================================================================
; FUNCTION INDEX (selected, ~100+ total)
; ========================================================================
;
; --- TSR / Startup (seg_0570) ---
;
;   Address   Name                           Description
;   -------   ----                           -----------
;   0570:0000 (data: driver name)            "DMVSVGA" + config header
;   0570:0032 entry_point                    TSR entry: register, go resident
;   0570:0055 dmvsvga_dispatchFast           Fast dispatch path (near call)
;   0570:0087 dmvsvga_dispatchFull           Full dispatch with context save
;   0570:00E2 dmvsvga_dispatchEpilogue       Epilogue: release mutex, restore
;   0570:00FC dmvsvga_initDriver             Initialize driver state, set video mode
;   0570:011C dmvsvga_shutdownDriver         Restore video mode, unhook interrupts
;   0570:013C dmvsvga_setVideoMode           Set VGA mode and configure registers
;   0570:0172 dmvsvga_lookupCursorRate       Lookup cursor blink rate from table
;   0570:0185 dmvsvga_hookTimerInt           Hook INT 08h for cursor blink
;   0570:01AD dmvsvga_hookKeyboardInt        Hook INT 09h for key state tracking
;   0570:01DD dmvsvga_acquireMutex           Acquire display mutex via INT E0h
;   0570:01EE dmvsvga_releaseMutex           Release display mutex via INT E0h
;   0570:0205 dmvsvga_timerISR               INT 08h handler (cursor blink logic)
;   0570:0338 dmvsvga_keyboardISR            INT 09h handler (mouse button state)
;   0570:0378 dmvsvga_checkCursorState       Check if cursor needs redraw
;   0570:03AC dmvsvga_disablePalette         Blank screen via VGA attr controller
;   0570:03BC dmvsvga_enablePalette          Unblank screen via VGA attr controller
;
; --- Main Driver Functions (seg_0003, selected) ---
;
;   0003:0000 dmvsvga_resetClipBounds        Reset clip bounds to max viewport
;   0003:0022 dmvsvga_saveClipBounds         Save and set new clip bounds
;   0003:0045 dmvsvga_drawEllipse            Draw ellipse (Bresenham midpoint)
;   0003:0134 dmvsvga_subdivideArc           Recursive arc subdivision
;   0003:0174 dmvsvga_interpolateMidpoint    Midpoint interpolation for curves
;   0003:019D dmvsvga_transformCoords        Transform coordinates through matrix
;   0003:0222 dmvsvga_setDrawColor           Set current drawing foreground color
;   0003:0298 dmvsvga_setBackColor           Set current drawing background color
;   0003:02DE dmvsvga_setTextAttribs         Set text rendering attributes
;   0003:034A dmvsvga_setFont                Select font by ID
;   0003:0371 dmvsvga_getDisplayState        Get current display state variables
;   0003:03C5 dmvsvga_restoreDisplayState    Restore saved display state
;   0003:03E7 dmvsvga_calcFontMetrics        Calculate font metrics (height, width)
;   0003:0407 dmvsvga_saveFontMetrics        Save font metrics to workspace
;   0003:042C dmvsvga_scrollUp               Scroll window contents up
;   0003:046C dmvsvga_scrollDown             Scroll window contents down
;   0003:04AC dmvsvga_beginDraw              Begin draw operation (sync)
;   0003:04E1 dmvsvga_drawLineUp             Draw line upward with clipping
;   0003:0569 dmvsvga_drawLineDown           Draw line downward with clipping
;   0003:05F0 dmvsvga_fillRectUp             Fill rectangle (top-to-bottom)
;   0003:06DD dmvsvga_fillRectDown           Fill rectangle (bottom-to-top)
;   0003:07AA dmvsvga_syncDisplay            Synchronize display after changes
;   0003:07CD dmvsvga_calcScrollParams       Calculate scroll parameters
;   0003:07FF dmvsvga_scrollWithClip         Scroll with clipping bounds
;   0003:082E dmvsvga_refreshIfDirty         Refresh display if dirty flag set
;   0003:0853 dmvsvga_blitCursor             Blit cursor bitmap to screen
;   0003:0887 dmvsvga_eraseCursor            Erase cursor by restoring background
;   0003:08BA dmvsvga_saveBackground         Save screen region under cursor
;   0003:08FE dmvsvga_restoreBackground      Restore screen region from save buffer
;   0003:0958 dmvsvga_setCursorShape         Set cursor shape (index + bitmap)
;   0003:097D dmvsvga_showCursor             Show cursor at current position
;   0003:099F dmvsvga_drawWindow             Draw window frame and contents
;   0003:0A52 dmvsvga_drawWindowContents     Draw window content area
;   0003:0B50 dmvsvga_drawMenuBar            Draw menu bar with items
;   0003:0BBF dmvsvga_drawScrollBar          Draw scroll bar (vertical/horizontal)
;   0003:0BFE dmvsvga_drawButton             Draw pushbutton control
;   0003:0C2E dmvsvga_drawCheckbox           Draw checkbox control
;   0003:0C64 dmvsvga_drawListItem           Draw list box item
;   0003:0D3F dmvsvga_drawTextInput          Draw text input field
;   0003:0D4B dmvsvga_setPixelDirect         Set pixel at (x,y) with color
;   0003:0D87 dmvsvga_drawHLine              Draw horizontal line
;   0003:0DF9 dmvsvga_drawLine               Draw arbitrary line (Bresenham)
;   0003:0F73 dmvsvga_drawPolyline           Draw connected line segments
;   0003:0FD7 dmvsvga_drawRect               Draw rectangle outline
;   0003:10AB dmvsvga_drawIcon               Draw icon bitmap
;   0003:11A8 dmvsvga_renderString           Render text string at position
;   0003:1433 dmvsvga_measureString          Measure text string width
;   0003:148D dmvsvga_loadBitmap             Load bitmap from resource
;   0003:1583 dmvsvga_blitBitmap             Blit bitmap to screen
;   0003:164C dmvsvga_tileFill               Tile-fill a rectangular region
;   0003:16BC dmvsvga_patternFill            Pattern-fill with current brush
;   0003:17B0 dmvsvga_drawArc                Draw circular arc
;   0003:18DD dmvsvga_drawPie                Draw pie/wedge shape
;   0003:1912 dmvsvga_drawFilledEllipse      Draw filled ellipse
;   0003:19EE dmvsvga_drawRoundRect          Draw rounded rectangle
;   0003:1A3F dmvsvga_drawFilledRoundRect    Draw filled rounded rectangle
;   0003:1B7F dmvsvga_drawBezier             Draw Bezier curve
;   0003:1BBA dmvsvga_drawThickLine          Draw line with thickness
;   0003:1C03 dmvsvga_drawDashedLine         Draw dashed/dotted line
;   0003:1C5A dmvsvga_renderComplexText      Render text with formatting
;   0003:1E0F dmvsvga_invertRegion           Invert colors in rectangular region
;   0003:1E3F dmvsvga_xorRegion              XOR colors in rectangular region
;   0003:1E9E dmvsvga_floodFill              Flood fill from point
;   0003:223C dmvsvga_getPixel               Get pixel color at (x,y)
;   0003:2263 dmvsvga_setViewport            Set viewport/clipping rectangle
;   0003:228A dmvsvga_getViewport            Get current viewport bounds
;   0003:22AC dmvsvga_drawBorder             Draw window border/frame
;   0003:2728 dmvsvga_initVideoMode          Initialize video mode registers
;   0003:289C dmvsvga_restoreVideoMode       Restore previous video mode
;
; --- Font/Glyph Data (seg_0003, approx 0x3400-0x5560) ---
;
;   ~8KB of bitmap font data for the system font at various sizes.
;   Contains glyph bitmaps for ASCII characters and box-drawing chars.
;   The font data includes tables for both 8x8 and 8x14 character cells.
;
; ========================================================================
; KEY DATA
; ========================================================================
;
; seg_0000:0000  "33.19"               ; Driver version string
; seg_0000:0007  "DMVEVGA"             ; Enhanced driver name to load
; seg_0000:000F  Configuration bytes:
;   +0x00  0xFF  capabilities flags
;   +0x01  0x00  reserved
;   +0x02  0x88  display type (VGA)
;   +0x03  0xE7  feature flags
;   +0x04  0x9C  mode capabilities
;   +0x05  0xAA  palette type
;   +0x06  0xCC  reserved
;   +0x07  0x10  color depth (16 colors)
;   +0x08  0x00 0x13  X resolution high/low = 640 (0x0280 stored later)
;   +0x0A  0x00 0x08  reserved
;   +0x0C  0x00 0x05  reserved
;   +0x0E  0x00 0x80  Y pixels = 480 (0x01E0 stored later)
;   +0x10  0x02 0xDB  bytes per scanline region
;   +0x12  0x01 0x80  framebuffer offset
;   +0x14  0x5F 0xFF FF  max values
;   +0x17  0x10 0x40  plane config
;   +0x19  0x01 0x00  planes
;   +0x1B  0x40 0x00  page size
;   +0x1D  0x10 0x40  misc
;   +0x1F  0x01       pages
;
; seg_0570:0000  "DMVSVGA"             ; Standard driver name
; seg_0570:000A  dw seg_0570           ; Self-segment reference
; seg_0570:0054  dw cursor_tick_count  ; Cursor blink counter
; seg_0570:0056  db cursor_visible     ; Cursor visibility flag
; seg_0570:0057  dw cursor_timer_val   ; Timer value for blink rate
; seg_0570:005A  dd old_int08h         ; Saved INT 08h vector
; seg_0570:005C  dd (continuation)     ; (segment part)
; seg_0570:03D3  dw display_id         ; Active display ID
;
; seg_05AD (key mapping table):
;   Scancode-to-DeskMate-keycode translation table.
;   Contains entries for function keys F1-F7 (codes 0x63-0x69),
;   and shifted variants (codes 0x23-0x29).
;   Segment byte at +0x84: 0xFE (driver type)
;   Framebuffer segment at +0x85: 0x00A0 (= A000h)
;   Function table pointer at +0x91: seg_055D
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The standard driver references the enhanced driver by name ("DMVEVGA")
;   in seg_0000:0007. DeskMate loads DMVEVGA.RES first, then DMVSVGA.RES.
;
; - The INT 08h timer hook manages cursor blinking. The cursor state is
;   tracked at offsets 0x4F-0x59 in the driver's data area. The timer
;   decrements a counter; when it reaches zero, the cursor visibility
;   is toggled and the cursor is redrawn.
;
; - The INT 09h keyboard hook tracks mouse button state by monitoring
;   the keyboard controller. This allows mouse-driven UI without a
;   dedicated mouse driver.
;
; - VGA palette blanking (ports 3BAh/3C0h) is used during full-screen
;   redraws to prevent visible artifacts. The screen is blanked by
;   clearing bit 5 of the attribute controller index register, then
;   restored by setting it.
;
; - The large function count (~100+ dispatched functions) covers all
;   DeskMate UI primitives: windows, menus, scrollbars, buttons,
;   checkboxes, list items, text fields, and all GDI-like drawing ops.
;
; - Font data embedded in the driver (~8KB) provides bitmap glyphs for
;   the system font. This includes standard ASCII, extended chars, and
;   box-drawing characters used for window borders.
;
; ========================================================================
