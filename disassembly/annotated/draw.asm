; ========================================================================
; DRAW.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987), Medium Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DRAW.PDM is the vector graphics editor for DeskMate 3.05. It provides
; shape creation (lines, rectangles, rounded rectangles, circles, ellipses,
; arcs, polygons, freehand curves, text), selection/transformation (move,
; resize, rotate, flip, duplicate, group/ungroup), color/pattern fills,
; zoom levels, grid snap, printing, and .FIG file I/O.
;
; The application is the largest PDM module at 78,256 bytes with 554
; functions across 9 segments. It uses the MSC 5.x medium memory model
; with multiple code segments and DGROUP for data.
;
; Resource imports: PRGUF (Program User Functions -- DeskMate UI library),
;                   DMGUF (DeskMate General User Functions)
;
; Hardware: INT 33h (mouse driver, 3 calls),
;           INT 34h-3Dh (8087 FP emulation via MSC runtime, ~270 calls),
;           INT ABh (unknown, 3 calls),
;           INT CCh (unknown, 2 calls)
;
; The INT 34h-3Dh calls are 8087 floating-point emulation interrupts
; installed by the MSC 5.x math library. Each INT maps to a specific
; FPU opcode: INT 34h = ESC opcodes, INT 35h = FWAIT + ESC,
; INT 37h = segment override + ESC, INT 38h = FIADD/FISUB/etc,
; INT 39h = FLD/FST/FSTP/etc, INT 3Ah = FADD/FSUB/FMUL/FDIV,
; INT 3Bh = FLD/FST with memory, INT 3Ch = misc FPU, INT 3Dh = FILD/FIST.
; DRAW uses FP math extensively for coordinate transforms, circle/arc
; geometry, and zoom scaling.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 78,256 bytes
; Load image: 77,744 bytes (after header)
; DM89 entry point: 10F3:0000 (MSC 5.x CRT startup)
; SS:SP = 1DD2:1000
;
; Segment Map (9 segments, 32 relocations):
;   seg_0000  0x0EAD0 bytes  CODE   Draw application code (main segment)
;                                    Shape creation, selection, transforms,
;                                    rendering, menus, dialogs, file I/O,
;                                    PRGUF/DMGUF thunks
;   seg_0EAD  0x02460 bytes  CODE   Secondary code: DM89 dispatcher stubs,
;                                    resource loading, event dispatch,
;                                    FP emulation interrupt handlers,
;                                    print support, .FIG file format I/O
;   seg_10F3  0x00A00 bytes  CODE   MSC 5.x CRT startup, _main() wrapper,
;                                    DM89 module lifecycle (register/unregister),
;                                    INT E0h API calls (0600h, 060Dh, 4D06h,
;                                    4D04h, 4D05h)
;   seg_10FD  0x002B0 bytes  CODE   MSC math library: 8087 emulation
;                                    installation, FIARITH helpers
;   seg_1128  0x00160 bytes  DATA   FPU emulation state segment
;                                    (8087 emulator scratch area)
;   seg_113E  0x00040 bytes  DATA   DGROUP fixup area (MSC CRT copyright
;                                    string: "MS Run-Time Library -
;                                    Copyright (c) 1987, Microsoft Corp.")
;   seg_1142  0x018F0 bytes  DATA   Strings, menus, shape definitions,
;                                    color/pattern tables, .FIG header
;                                    templates, dialog definitions,
;                                    font tables, tool state
;   seg_12D1  0x0B010 bytes  DATA   BSS / initialized data: shape list,
;                                    undo buffer, selection state, zoom
;                                    state, grid settings, filename buffer,
;                                    coordinate buffers, print config
;   seg_1DD2  0x01000 bytes  STACK  Stack segment (4096 bytes)
;
; Medium memory model: multiple code segments, DGROUP at 113E.
;
; DM flags: 0x0000 (standard PDM module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Global Variables (selected, DGROUP-relative offsets in seg_1142/12D1):
;
; --- Drawing State ---
;   [0x08E9]  g_currentTool       - Current tool index (byte)
;                                    0=line, 1=rect, 2=rrect, 3=circle,
;                                    4=ellipse, 5=arc, 6=polygon,
;                                    7=freehand, 8=text, 9=eraser
;   [0x093C]  g_eventBuffer       - Event/message buffer (struct, multi-byte)
;   [0x093D]  g_eventCode         - Event code word (within event buffer)
;   [0x093F]  g_mouseX            - Current mouse X position (word)
;   [0x0941]  g_mouseY            - Current mouse Y position (word)
;   [0x094B]  g_drawMode          - Current draw mode (byte)
;                                    4 = shape creation active
;   [0x094C]  g_editMode          - Edit mode flag (byte)
;   [0x094E]  g_patternIndex      - Current fill pattern index (byte)
;   [0x0950]  g_patternTable      - Fill pattern table (byte array)
;   [0x0976]  g_lineColor         - Current line/border color (byte)
;   [0x098E]  g_fillColorIdx      - Current fill color index (word)
;   [0x0990]  g_colorPalette      - Color palette mapping table
;   [0x09AE]  g_shapeCount        - Number of shapes in current drawing (word)
;   [0x09D8]  g_selectionLocked   - Selection locked flag (byte)
;   [0x09EC]  g_modifiedFlag      - Drawing modified (unsaved changes) flag
;
; --- Shape List ---
;   [0x1C58]  g_currentShapeFunc  - Current shape render function ID (word)
;   [0x1C5A]  g_shapeListIdx      - Current shape list index (word)
;   [0x1C62]  g_shapeListBase     - Shape list base address / PRGUF context
;   [0x1C6E]  g_shapeDataPtr      - Pointer to current shape data block
;   [0x1C70]  g_shapeTablePtr     - Pointer to shape function dispatch table
;   [0xBD2E]  g_anchorX           - Anchor X for current shape operation (word)
;   [0xBD3A]  g_anchorY           - Anchor Y for current shape operation (word)
;   [0xC094]  g_snapActive        - Grid snap active flag (byte)
;   [0xC12E]  g_shapeArrayPtr     - Pointer to shape coordinate array
;
; --- File I/O ---
;   [0x1BF4]  g_fileHandle        - Current .FIG file handle (word)
;
; --- Resource Management ---
;   [0x14BF]  g_savedInt00Vec     - Saved INT 00h vector (dword)
;   [0x14D1]  g_pspSegment        - PSP segment (word)
;   [0x14D3]  g_dosVersion        - DOS version (word)
;   [0x14DA]  g_fileFlags         - File handle flags array (5 bytes)
;   [0x14EE]  g_crtArgC           - argc from CRT startup
;   [0x14F0]  g_crtArgV           - argv from CRT startup
;   [0x14F2]  g_crtEnvP           - envp from CRT startup
;   [0x14FC]  g_prgufCallback     - PRGUF callback function pointer (dword)
;   [0x1500]  g_prgufName         - "PRGUF\0" resource name string
;   [0x1506]  g_dmgufCallback     - DMGUF callback function pointer (dword)
;   [0x150A]  g_dmgufName         - "DMGUF\0" resource name string
;   [0x1510]  g_prgufLoaded       - PRGUF loaded flag (byte)
;   [0x1513]  g_dispatchRetAddr   - DM89 dispatch return address (word)
;   [0x1515]  g_dispatchParam     - DM89 dispatch parameter (word)
;   [0x151C]  g_dmeformName       - "DMEFORM\0" resource name
;   [0x1528]  g_printHandle       - Print session handle (word)
;   [0x1530]  g_dmcursorCallback  - DMCURSOR callback pointer (dword)
;   [0x1534]  g_dmcursorName      - "DMCSR\0" resource name
;
; --- FP Emulation (seg_1128) ---
;   [0x000E]  g_fpuStackLimit     - FPU emulation stack limit
;   [0x0010]  g_fpuStackTop       - FPU emulation stack top pointer
;   [0x0014]  g_fpuStatusWord     - FPU emulation status word
;   [0x0092]  g_fpuFramePtr       - FPU emulation frame pointer
;
; --- DM89 Event Dispatch (seg_10F3) ---
;   [0x163A]  g_dm89Handle1       - DM89 registered handle 1 (word)
;   [0x163C]  g_dm89Handle2       - DM89 registered handle 2 (word)
;
; ========================================================================
; SHAPE STRUCTURE (.FIG vector format element)
; ========================================================================
;
; Each shape in the drawing is stored as a variable-length record in the
; shape list. The shape header is accessed via g_shapeListBase + index:
;
; Shape Record (accessed via PRGUF calls):
;   +0x00  shapeId        (word)  Shape type identifier
;   +0x02  x1             (word)  Bounding box left / start X
;   +0x04  y1_or_extra    (word)  Varies by shape type
;   +0x06  y1             (word)  Bounding box top / start Y
;   +0x08  x2_or_extra    (word)  Varies by shape type
;   +0x0A  x2             (word)  Bounding box right / end X
;   +0x0C  y2_or_extra    (word)  Varies by shape type
;   +0x0E  y2             (word)  Bounding box bottom / end Y
;   +0x10  flags          (word)  Shape flags (selected, grouped, etc.)
;   +0x12  pointCount     (word)  Number of points (for polygons/freehand)
;   +0x14  pointData      (var)   Array of (x,y) coordinate pairs
;
; Shape types (g_currentTool values, compared at sub_02ECA):
;   0 = Line          sub_09B7B handler
;   1 = Rectangle     sub_09C6B handler
;   2 = Rounded Rect  sub_09D82 handler
;   3 = Circle        sub_06856 handler (via sub_02ECA dispatch)
;   4 = Ellipse       sub_0A214 handler
;   5 = Arc           (sub_02ECA case 5 -> sub_02F7A)
;   6 = Polygon       sub_0691F handler
;   7 = Freehand      sub_0A2C9 handler
;   8 = Text          sub_0A5E4 handler
;   9 = Eraser        sub_09ECF handler
;
; The bounding box coordinates use the 4-byte pattern:
;   +0x02 = leftX or startX
;   +0x06 = topY or startY
;   +0x0A = rightX or endX
;   +0x0E = bottomY or endY
; This is confirmed by the min/max calculations in sub_0004B which
; iterates shape points and computes bounding box extents.
;
; ========================================================================
; .FIG FILE FORMAT
; ========================================================================
;
; The .FIG file stores vector drawings. Based on the file I/O functions
; (sub_05364 = save, sub_05DAF = load, sub_06013 = merge/import):
;
; FIG Header:
;   +0x00  magic         (byte)   0x4C ('L' for line-art / vector)
;   +0x01  colorByte     (byte)   Default color/palette index
;   +0x02  startX        (word)   Initial X coordinate
;   +0x04  startY        (word)   Initial Y coordinate
;   +0x06  ...           (var)    Additional header fields
;
; Shape records follow the header, each preceded by a shape type byte
; (0x4C confirmed at sub_09BB1: "mov byte ptr [bp-0x1c], 0x4c").
;
; File operations use DOS INT 21h AH=3Eh (close), AH=40h (write) for
; direct file I/O, and DeskMate INT E0h AX=0600h/0603h/060Eh for
; mediated file access (printing, resource loading).
;
; ========================================================================
; MENU STRUCTURE
; ========================================================================
;
; DeskMate menu commands use the pattern 0xF5xx (menu class 0xF5):
;   0xF500 = File > New
;   0xF501 = File > Open
;   0xF502 = File > Save
;   0xF503 = File > Save As
;   0xF504 = File > Print
;   0xF505 = File > Print Setup
;   0xF506 = File > Merge (import shapes from another .FIG)
;   0xF507 = Edit > Select All
;   0xF508 = Edit > Cut
;   0xF509 = Edit > Copy
;   0xF50A = Edit > Paste
;   0xF50B = Edit > Clear/Delete
;   0xF50C = Edit > Duplicate
;   0xF50D = Edit > Undo
;   0xF50E = Edit > Group
;   0xF50F = Edit > Ungroup
;   0xF510 = Edit > Bring to Front
;   0xF511 = Edit > Send to Back
;   0xF512 = Edit > Flip Horizontal
;   0xF513 = Edit > Flip Vertical
;   0xF514 = Edit > Rotate
;   0xF515 = Style > Line Width
;   0xF516 = Style > Line Style
;   0xF517 = Style > Fill Pattern
;   0xF518 = Style > Line Color
;   0xF519 = Style > Fill Color
;   0xF51A = Options > Grid Settings / Snap / Zoom
;   0xF51B-0xF522 = Additional options
;   0xF5C8 = (reserved/internal)
;   0xF5C9-0xF5CB = Additional internal commands
;
; Event codes (non-menu, from sub_03282):
;   0x8400 = Window activate / repaint
;   0x8413 = Window scroll
;   0x8414 = Window resize
;   0xFF75 = Keyboard shortcut (tool switch)
;   0xFF76 = Keyboard shortcut (alternate)
;   0xFB01 = Mouse down (shape creation start)
;   0xFB02 = Mouse move (shape drag / rubber-band)
;   0xFB03 = Mouse up (shape creation complete)
;   0xFB05 = Mouse double-click (shape edit)
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Shape Bounding Box / Coordinate Utilities ---
;
; Address   Name                              Size  Description
; -------   ----                              ----  -----------
; 0000:0010 draw_lookupShapeFunc                59  Lookup shape render function from ID table
; 0000:004B draw_calcBoundingBox              1067  Calculate bounding box for all shapes in drawing
;                                                   Iterates shape list, computes min/max X/Y per
;                                                   axis type (0=minY, 1=maxY, 2=minX, 3=maxX),
;                                                   then builds clip rectangles and calls PRGUF
;                                                   render function for each shape
;
; --- Main Application / Event Loop ---
;
; 0000:0476 draw_main                          490  _main() - init drawing state, enter event loop,
;                                                   dispatch events by type (0=null, 1=menu cmd,
;                                                   2=keyboard, 3=timer, 4=quit, 6=window event),
;                                                   handle shape creation via sub_006CA
; 0000:0660 draw_initResources                 106  Initialize DM89 resources (call PRGUF init)
; 0000:06CA draw_hitTestShape                  294  Hit-test: check if mouse click (x,y) hits a shape,
;                                                   returns shape index or 0
;
; --- Shape Rendering ---
;
; 0000:07F0 draw_renderAllShapes               471  Render all shapes in current view, iterate shape
;                                                   list and call per-shape render functions
; 0000:09C7 draw_renderShapeClipped            137  Render a single shape with clipping
; 0000:0A50 draw_renderShapeUnclipped          112  Render a single shape without clipping
; 0000:0AC0 draw_renderSelectionHandles        252  Draw selection handles (resize grips) around
;                                                   the currently selected shape
; 0000:0BBC draw_renderRubberBand              209  Draw rubber-band outline during shape creation
;                                                   (XOR drawing mode)
;
; --- File Menu Commands ---
;
; 0000:0C8D draw_handleFileMenu                282  File menu dispatcher (New, Open, Save, Save As,
;                                                   Print, Merge)
; 0000:0DA7 draw_fileNew                       197  File > New: prompt save, clear drawing
; 0000:0E6C draw_fileOpen                      390  File > Open: prompt save, show file dialog,
;                                                   load .FIG file
; 0000:0FF2 draw_getFilenameExtension          122  Extract file extension, validate .FIG
; 0000:106C draw_fileSave                      234  File > Save: write current drawing to .FIG
; 0000:1156 draw_fileSaveAs                    427  File > Save As: prompt for filename, save
; 0000:1301 draw_buildFilenameDisplay          130  Build display string with filename and path
; 0000:1383 draw_buildTitleWithFilename         88  Build window title with current filename
; 0000:13DB draw_formatFilename                116  Format filename for display (truncate path)
; 0000:144F draw_setWindowTitle                125  Set the Draw window title bar text
; 0000:14CC draw_filePrint                     253  File > Print: print current drawing
; 0000:15C9 draw_filePrintSetup                680  File > Print Setup: configure printer
; 0000:1871 draw_readPrintConfig               175  Read print configuration from settings
; 0000:1920 draw_writePrintConfig              174  Write print configuration to settings
;
; --- Style Dialogs ---
;
; 0000:19CE draw_styleLineWidth                645  Style > Line Width dialog
; 0000:1C53 draw_buildLineWidthSample          287  Build line width preview sample
; 0000:1D72 draw_styleLineStyle                717  Style > Line Style dialog (solid, dashed, dotted)
; 0000:203F draw_getLineStyleName               50  Get display name for line style
; 0000:2071 draw_styleFillPattern              718  Style > Fill Pattern dialog
; 0000:233F draw_applyCurrentStyle              47  Apply current style to selected shape
; 0000:236E draw_styleLineColor                597  Style > Line Color dialog
; 0000:25C3 draw_applyColorToShape             201  Apply color attributes to selected shape
; 0000:268C draw_styleFillColor                317  Style > Fill Color dialog
; 0000:27C9 draw_updateShapeStyle               68  Update shape style (color + pattern + line)
; 0000:280D draw_setColorPalette               233  Set color palette for current video mode
;
; --- Main Event Handler (largest function) ---
;
; 0000:28F6 draw_mainEventHandler             1492  Master event handler: process DM89 events,
;                                                   DeskMate menu dispatch, keyboard shortcuts,
;                                                   window management, tool switching, undo state.
;                                                   Calls: initWindow, loadResources, readConfig,
;                                                   dispatchMenuCmd, handleKeyEvent,
;                                                   handleWindowEvent, processShapeEvent
;                                                   This is the core of the application -- the
;                                                   main DM89 callback registered with DESK.EXE.
;
; --- Menu Command Dispatcher ---
;
; 0000:2ECA draw_dispatchShapeEvent            269  Dispatch mouse event to shape-specific handler
;                                                   based on current tool (0-9). Uses jump table
;                                                   at cs:0x2F64 to route to:
;                                                     tool 0 -> sub_09B7B (draw_createLine)
;                                                     tool 1 -> sub_09C6B (draw_createRectangle)
;                                                     tool 2 -> sub_09D82 (draw_createRoundedRect)
;                                                     tool 3 -> sub_06856 (draw_createCircle)
;                                                     tool 4 -> sub_0A214 (draw_createEllipse)
;                                                     tool 5 -> (arc handler)
;                                                     tool 6 -> sub_0691F (draw_createPolygon)
;                                                     tool 7 -> sub_0A2C9 (draw_createFreehand)
;                                                     tool 8 -> sub_0A5E4 (draw_createText)
;                                                     tool 9 -> sub_09ECF (draw_eraseShape)
;                                                   0xFB01 = start, 0xFB02 = drag, 0xFB03 = end,
;                                                   0xFB05 = double-click (edit properties)
;
; 0000:2FD7 draw_dispatchMenuCommand           683  Menu command dispatcher: routes 0xF5xx commands
;                                                   via jump table at cs:0x31B0 to individual
;                                                   command handlers:
;                                                     F500 -> sub_07B9E (new)
;                                                     F501 -> sub_07CF9 (open)
;                                                     F502 -> sub_07F42 (save)
;                                                     F503 -> sub_08044 (save as)
;                                                     F504 -> sub_08143 (print)
;                                                     F505 -> sub_0858C (print setup)
;                                                     F506 -> sub_08738 (merge)
;                                                     F507 -> sub_08812 (select all)
;                                                     F508 -> sub_088EC (cut)
;                                                     F509 -> sub_00C8D (loop: file menu?)
;                                                     F50A -> sub_08B16 (paste)
;                                                     F50B -> sub_08BAB (clear/delete)
;                                                     F50C -> sub_08C39 (duplicate)
;                                                     F50D -> sub_08F51 (undo)
;                                                     F50E -> sub_06D53 (group)
;                                                     F50F -> sub_014CC (print -- overlap?)
;                                                     F510 -> sub_015C9 (print setup -- overlap?)
;                                                     (remaining F511-F522 map to additional
;                                                      style/option handlers)
;                                                   0xF51A routes to sub_04938 (options/grid dialog)
;
; --- Window Event Handler ---
;
; 0000:3282 draw_handleWindowEvent            1799  Window event handler: repaint (0x8400),
;                                                   scroll (0x8413), resize (0x8414),
;                                                   keyboard shortcuts (0xFF75, 0xFF76),
;                                                   tool selection. Calls draw_renderCanvas
;                                                   (sub_04142) when drawMode==4.
;                                                   Sub-dispatches to draw_updateView (sub_0673E),
;                                                   draw_resetZoom (sub_03989), and many PRGUF
;                                                   thunks for window metric updates.
;
; 0000:3989 draw_resetZoom                     121  Reset zoom level and recalculate view
; 0000:3A02 draw_initWindowLayout              249  Initialize window layout, menu bar, tool palette
; 0000:3AFB draw_readConfigFile                545  Read DRAW configuration from DESKTOP.CFG
;
; --- Dialog Support ---
;
; 0000:3D1C draw_showAboutDialog                21  Show About Draw dialog
; 0000:3D31 draw_handleDialogEvent              78  Generic dialog event handler
; 0000:3D7F draw_validateDialogInput            73  Validate dialog input fields
; 0000:3DC8 draw_formatCoordString              71  Format coordinate value as string
; 0000:3E0F draw_formatDimensionString          50  Format dimension (width/height) as string
; 0000:3E41 draw_parseCoordString               74  Parse coordinate string to integer
; 0000:3E8B draw_parseColorString               74  Parse color name/index string
; 0000:3ED5 draw_getWindowMetrics               84  Get current window dimensions and position
; 0000:3F29 draw_setWindowMetrics              145  Set window dimensions/position
; 0000:3FBA draw_setupToolPalette              220  Initialize the tool palette sidebar
; 0000:4096 draw_setToolActive                  56  Set active tool in palette (visual highlight)
; 0000:40CE draw_updateStatusBar                53  Update status bar with coordinates/tool name
; 0000:4103 draw_refreshStatusDisplay           63  Refresh the status display area
;
; --- Canvas Rendering ---
;
; 0000:4142 draw_renderCanvas                  828  Full canvas render: iterate all shapes, draw
;                                                   grid if enabled, draw selection handles,
;                                                   update scroll bars. Core rendering function.
; 0000:447E draw_drawGrid                      109  Draw grid overlay on canvas
; 0000:44EB draw_drawRulers                    142  Draw X/Y rulers along canvas edges
; 0000:4579 draw_setForegroundColor             54  Set foreground drawing color
; 0000:45AF draw_setBackgroundColor             50  Set background drawing color
; 0000:45E1 draw_setupViewport                 208  Set up viewport/clipping for current zoom
; 0000:46B1 draw_mapScreenToWorld              188  Map screen coordinates to world/drawing coords
; 0000:476D draw_mapWorldToScreen              312  Map world coordinates to screen coordinates
; 0000:48A5 draw_scaleXCoord                    30  Scale X coordinate by zoom factor
; 0000:48C3 draw_scaleYCoord                    26  Scale Y coordinate by zoom factor
; 0000:48DD draw_unscaleCoord                   91  Inverse zoom scale (screen -> world)
;
; --- Grid/Snap/Zoom Options ---
;
; 0000:4938 draw_optionsDialog                 871  Options dialog: grid spacing, snap toggle,
;                                                   zoom level selection
; 0000:4C9F draw_zoomDialog                    237  Zoom level selection sub-dialog
; 0000:4D8C draw_setZoomLevel                  145  Apply new zoom level
; 0000:4E1D draw_gridDialog                     87  Grid settings sub-dialog
; 0000:4E74 draw_snapSettings                  176  Snap-to-grid settings
; 0000:4F24 draw_parseGridSpacing              144  Parse grid spacing value from dialog
; 0000:4FB4 draw_formatGridValues              321  Format grid spacing values for display
; 0000:50F5 draw_applyGridSettings             112  Apply grid settings to drawing
; 0000:5165 draw_validateGridValues            105  Validate grid spacing input
; 0000:51CE draw_setSnapMode                   123  Set snap-to-grid mode
;
; --- Memory Management ---
;
; 0000:5249 draw_freeMemBlock                   76  Free a memory block (DOS INT 21h AH=49h wrapper)
; 0000:5295 draw_getDataSegment                  7  Return current DS value (utility stub)
; 0000:529C draw_allocLargeBlock                90  Allocate large memory block (INT 21h AH=48h)
; 0000:52F6 draw_freeDosMemory                  17  Free DOS memory block (INT 21h AH=49h)
; 0000:5307 draw_getDSValue                      7  Another DS getter (used in different context)
; 0000:530E draw_allocSmallBlock                67  Allocate small memory block
; 0000:5351 draw_queryAvailableMemory           19  Query available DOS memory (INT 21h AH=48h, BX=FFFF)
;
; --- .FIG File I/O ---
;
; 0000:5364 draw_saveFigFile                   601  Save drawing to .FIG file: serialize all shapes,
;                                                   write header, iterate shape list, write each
;                                                   shape record with coordinates and attributes
; 0000:55BD draw_writeShapeHeader              105  Write shape header to file
; 0000:5626 draw_writeShapeCoords              126  Write shape coordinates to file
; 0000:56A4 draw_writeShapeAttributes           85  Write shape color/pattern attributes to file
; 0000:56F9 draw_writeShapeList                403  Write complete shape list to file
; 0000:588C draw_writeShapeData               1049  Write individual shape data by type (switch on
;                                                   shape type, write type-specific fields):
;                                                     calls sub_063D4 (write line data)
;                                                     calls sub_0936A (write polygon data)
;                                                     calls sub_05CA5-05D87 (type-specific writers)
; 0000:5CA5 draw_writeLineData                  52  Write line-specific data
; 0000:5CD9 draw_writeRectData                  42  Write rectangle data
; 0000:5D03 draw_writeRoundRectData             40  Write rounded rectangle data
; 0000:5D2B draw_writeCircleData                40  Write circle data
; 0000:5D53 draw_writeEllipseData               52  Write ellipse data
; 0000:5D87 draw_writeArcData                   40  Write arc data
; 0000:5DAF draw_loadFigFile                   572  Load .FIG file: read header, parse shape records,
;                                                   build shape list, set view state
; 0000:5FEB draw_readShapeAttribs               40  Read shape attributes from file
; 0000:6013 draw_mergeFigFile                  487  Merge shapes from another .FIG file into current
;                                                   drawing (File > Merge)
; 0000:61FA draw_readShapeCount                 53  Read shape count from .FIG file header
; 0000:622F draw_readShapeList                 421  Read shape list from file
; 0000:63D4 draw_readShapeData                  68  Read individual shape data record
;
; --- Shape Transform Operations ---
;
; 0000:6418 draw_transformSetup                133  Set up transform matrix for rotation/flip
; 0000:649D draw_flipHorizontal                208  Flip selected shape(s) horizontally
; 0000:656D draw_flipVertical                  208  Flip selected shape(s) vertically
; 0000:663D draw_getFlipCenterH                 64  Calculate horizontal flip center point
; 0000:667D draw_getFlipCenterV                 57  Calculate vertical flip center point
; 0000:66B6 draw_getShapeCenter                 46  Get center point of shape bounding box
; 0000:66E4 draw_rotateShape                    90  Rotate shape by specified angle
; 0000:673E draw_updateAfterTransform          136  Update display after shape transformation
; 0000:67C6 draw_applyTransformToPoints_H       52  Apply horizontal transform to shape points
; 0000:67FA draw_applyTransformToPoints_V       52  Apply vertical transform to shape points
; 0000:682E draw_scaleTransformCoord            40  Scale a coordinate through transform matrix
;
; --- Selection / Group Operations ---
;
; 0000:6856 draw_createCircle                  201  Circle creation handler (tool 3)
; 0000:691F draw_createPolygon                 163  Polygon creation handler (tool 6)
; 0000:69C2 draw_moveShape                     315  Move selected shape by delta (dx, dy)
; 0000:6AFD draw_recursiveSelect               249  Recursive group selection (select all in group)
; 0000:6BF6 draw_handleShapeDrag               311  Handle shape drag (move/resize based on handle)
; 0000:6D2D draw_getShapeBounds                 38  Get shape bounding rectangle
; 0000:6D53 draw_groupShapes                   326  Group selected shapes into compound shape
; 0000:6E99 draw_updateShapePosition           254  Update shape position after move/resize
; 0000:6F97 draw_setShapeModified               33  Mark shape as modified (set dirty flag)
; 0000:6FB8 draw_notifyShapeChange              16  Notify system of shape change
; 0000:6FC8 draw_invalidateShape                26  Invalidate shape region (trigger repaint)
;
; --- Shape Geometry Helpers ---
;
; 0000:6FE2 draw_calcShapeExtent                90  Calculate shape extent (width, height)
; 0000:7074 draw_snapToGrid                     66  Snap coordinate to nearest grid point
; 0000:70AE draw_createCirclePoints             50  Generate points for circle approximation
; 0000:7140 draw_generateArcPoints              81  Generate points for arc segment
; 0000:7191 draw_generateEllipsePoints         751  Generate points for ellipse (FP math heavy)
; 0000:7480 draw_bezierCurve                  1043  Bezier curve point generation (FP math)
; 0000:78C4 draw_distancePointToLine            31  Calculate distance from point to line segment
; 0000:79D8 draw_pointInRect                    99  Test if point is inside rectangle
; 0000:7AA3 draw_normalizeRect                 123  Normalize rectangle (ensure x1<x2, y1<y2)
;
; --- Command Handlers (routed from draw_dispatchMenuCommand) ---
;
; 0000:7B9E draw_cmdNew                        (var) Handle File > New
; 0000:7CF9 draw_cmdOpen                       (var) Handle File > Open
; 0000:7F42 draw_cmdSave                       (var) Handle File > Save
; 0000:8044 draw_cmdSaveAs                     (var) Handle File > Save As
; 0000:8143 draw_cmdPrint                      (var) Handle File > Print
; 0000:858C draw_cmdPrintSetup                 (var) Handle File > Print Setup
; 0000:8738 draw_cmdMerge                      (var) Handle File > Merge
; 0000:8719 draw_promptSaveChanges             (var) Prompt user to save unsaved changes
; 0000:8812 draw_cmdSelectAll                  (var) Handle Edit > Select All
; 0000:88EC draw_cmdCut                        (var) Handle Edit > Cut
; 0000:8B16 draw_cmdPaste                      (var) Handle Edit > Paste
; 0000:8BAB draw_cmdClear                      (var) Handle Edit > Clear/Delete
; 0000:8BF1 draw_cmdConfirmDelete              (var) Confirm deletion dialog
; 0000:8C39 draw_cmdDuplicate                  (var) Handle Edit > Duplicate
; 0000:8F51 draw_cmdUndo                       (var) Handle Edit > Undo
;
; --- Drawing Primitives (PRGUF/DMGUF wrappers for GDI-like calls) ---
;
; 0000:9143 draw_drawLinePrimitive             (var) Draw a line from (x1,y1) to (x2,y2)
; 0000:91A4 draw_drawRectPrimitive             (var) Draw a rectangle outline
; 0000:9215 draw_drawFilledRect                (var) Draw a filled rectangle
; 0000:9286 draw_drawEllipsePrimitive          (var) Draw an ellipse
; 0000:936A draw_drawPolygonPrimitive          (var) Draw a polygon (polyline)
; 0000:9489 draw_drawTextPrimitive             (var) Draw text string at position
;
; --- Per-Tool Shape Creation Handlers ---
;
; 0000:9873 draw_beginShapeCreation            (var) Begin interactive shape creation
; 0000:9B7B draw_createLine                    (var) Line tool: mouse down/drag/up handler
; 0000:9C6B draw_createRectangle               (var) Rectangle tool handler
; 0000:9D82 draw_createRoundedRect             (var) Rounded rectangle tool handler
; 0000:9DBD draw_createFreehandStroke          (var) Freehand stroke point accumulator
; 0000:9ECF draw_eraseShape                    (var) Eraser tool handler
; 0000:A214 draw_createEllipse                 (var) Ellipse tool handler
; 0000:A2C9 draw_createFreehand                (var) Freehand drawing tool handler
; 0000:A5E4 draw_createText                    (var) Text tool handler (place text, enter string)
;
; --- Text Editing Support ---
;
; 0000:A490 draw_getTextMetrics                (var) Get text width/height for current font
; 0000:A48F draw_setTextFont                   (var) Set current text font
; 0000:A4C1 draw_getCharWidth                  (var) Get character width in current font
; 0000:A507 draw_measureString                 (var) Measure string width in pixels
; 0000:A631 draw_setTextAttributes             (var) Set text attributes (bold, italic, size)
;
; --- Undo/Redo Support ---
;
; 0000:AB30 draw_pushUndoState                 (var) Push current state to undo stack
; 0000:AB94 draw_popUndoState                  (var) Pop state from undo stack (for undo)
; 0000:AC04 draw_getEvent                      844  Get next DM89 event from event queue
;
; --- Color/Pattern Tables ---
;
; 0000:B20C draw_getColorTable                 (var) Get pointer to color table for video mode
; 0000:B12B draw_getPatternTable               (var) Get pointer to fill pattern table
; 0000:B2F5 draw_setColorEntry                 (var) Set color table entry
; 0000:B3F5 draw_getColorEntry                 (var) Get color table entry
; 0000:B490 draw_setPatternEntry               (var) Set fill pattern
; 0000:B4B2 draw_getPatternEntry               (var) Get fill pattern
; 0000:B5D3 draw_initColorDefaults             (var) Initialize default color palette
;
; --- Shape List Management ---
;
; 0000:B6A2 draw_compactShapeList             1001  Compact shape list (remove deleted shapes,
;                                                   reindex, defragment memory)
;
; --- CRT Runtime / Module Support (seg_0EAD) ---
;
; 0000:BAD4 draw_dm89Entry                     (thk) DM89 module entry: call CRT startup,
;                                                    initialize C runtime, call main()
; 0000:BAF2 draw_dm89Retf_init                 (thk) RETF stub: __cinit() far-call return
; 0000:BAF3 draw_dm89Retf_cinit                (thk) RETF stub: calls sub_0D0DA (__ctermsub)
; 0000:BAF7 draw_dm89Retf_exit                 (thk) RETF stub: calls sub_0D2DB (_exit)
; 0000:BAFB draw_dm89Retf_abort                (thk) RETF stub: calls sub_0BAFF (_cexit)
; 0000:BAFF draw_cexit                          15  C exit: call __ctermsub, _exit(0xFF), then
;                                                   indirect call through [0x145E] (atexit handler)
; 0000:BB0E draw_crtStartup                   195  MSC 5.x CRT startup: get DOS version, save
;                                                   INT 00h vector, install div-by-zero handler,
;                                                   parse command line, set up environment,
;                                                   detect file handle modes (IOCTL)
; 0000:BBD2 draw_crtExit                       (var) CRT exit handler: call atexit chain,
;                                                    close files, restore INT 00h
; 0000:BBE9 draw_crtCallAtExit                 (var) Process atexit() registered functions
;
; --- DM89 Resource Import Dispatch ---
;
; 0000:BC6A draw_dm89Dispatch                  467  DM89 module dispatch: set up DGROUP, build
;                                                   argc/argv, call main(argc, argv, envp)
; 0000:BD9E draw_prgufDispatch                 (thk) PRGUF far-call entry: check if PRGUF loaded,
;                                                    dispatch function through saved callback
; 0000:BDB6 draw_prgufCallThrough              (thk) PRGUF call-through: save return addr, push
;                                                    params, indirect call via [0x14FC]
;
; --- Resource Loading/Unloading ---
;
; 0000:BCD2 draw_loadPrgufResource             (var) Load PRGUF resource: INT E0h AX=0208h,
;                                                    check version, load via AX=0206h
; 0000:BD0E draw_unloadPrgufResource           (var) Unload PRGUF: INT E0h AX=0207h, reset
;                                                    callback to default stub
; 0000:BD34 draw_loadDmgufResource             (var) Load DMGUF resource: INT E0h AX=0206h,
;                                                    store callback, execute AX=0208h
; 0000:BD76 draw_unloadDmgufResource           (var) Unload DMGUF: INT E0h AX=0207h, reset
;                                                    callback to default stub
;
; --- DMEFORM Resource (Print Form Manager) ---
;
; 0000:BE97 draw_loadDmeformResource           104  Load DMEFORM resource for print forms:
;                                                   INT E0h AX=0206h, INT E0h AX=0700h (yield),
;                                                   INT E0h AX=0207h if already loaded
; 0000:BEFF draw_setupPrintSession             208  Set up print session: INT E0h AX=0600h (open),
;                                                   INT E0h AX=060Eh (dispatch), write data via
;                                                   INT E0h AX=0603h
; 0000:BFCF draw_writePrintData                 14  Write data to print stream
; 0000:BFDD draw_closePrintStream               21  Close print stream
;
; --- DMCURSOR Resource ---
;
; 0000:C016 draw_loadCursorResource             25  Load DMCSR (cursor) resource: INT E0h AX=0206h
; 0000:C02F draw_unloadCursorResource           29  Unload DMCSR: INT E0h AX=0207h
;
; --- PRGUF Thunk Table ---
;
; These are near-call thunks that dispatch to PRGUF functions via the
; far-call callback pointer at [0x14FC]. Each thunk loads a function
; code into AX and jumps to the PRGUF dispatcher (draw_prgufDispatch).
; The PRGUF function codes map to the DeskMate UI library API.
;
; Address   Name                          Func  Description
; -------   ----                          ----  -----------
; 0000:C03E prguf_beginPaint              003E  Begin paint/draw session
; 0000:C045 prguf_endPaint                0045  End paint/draw session
; 0000:C074 prguf_getViewport             0074  Get current viewport rect
; 0000:C07A prguf_setViewport             007A  Set viewport rect
; 0000:C080 prguf_getWindowRect           0080  Get window client rect
; 0000:C086 prguf_setWindowRect           0086  Set window client rect
; 0000:C092 prguf_enableMenuItem          0092  Enable/disable menu item
; 0000:C098 prguf_checkMenuItem           0098  Check/uncheck menu item
; 0000:C09E prguf_setMenuItemText         009E  Set menu item text
; 0000:C0AA prguf_getStringResource       00AA  Get string from resource table
; 0000:C0B0 prguf_putStringResource       00B0  Put/store string to resource
; 0000:C0B6 prguf_loadStringResource      00B6  Load string resource by ID
; 0000:C0BC prguf_freeResource            00BC  Free a loaded resource
; 0000:C0C2 prguf_getResourceSize         00C2  Get size of resource
; 0000:C0DA prguf_createDialog            00DA  Create/show dialog box
; 0000:C0E0 prguf_setDialogField          00E0  Set dialog field value
; 0000:C104 prguf_showMessageBox          0104  Show message box dialog
; 0000:C10A prguf_getInputString          010A  Get string input from user
; 0000:C11C prguf_showAboutBox            011C  Show About dialog
; 0000:C164 prguf_openPrinter             0164  Open printer for output
; 0000:C16A prguf_closePrinter            016A  Close printer
; 0000:C17C prguf_setPrintFont            017C  Set printer font
; 0000:C182 prguf_setPrintMargin          0182  Set print margins
; 0000:C188 prguf_getPrintStatus          0188  Get printer status
; 0000:C194 prguf_drawLine                0194  Draw line primitive
; 0000:C19A prguf_drawRect                019A  Draw rectangle primitive
; 0000:C1A0 prguf_fillRect                01A0  Fill rectangle primitive
; 0000:C1A6 prguf_drawEllipse             01A6  Draw ellipse primitive
; 0000:C1B2 prguf_setLineWidth            01B2  Set line width for drawing
; 0000:C1B8 prguf_setLineStyle            01B8  Set line style (solid/dash/dot)
; 0000:C1BE prguf_setFillPattern          01BE  Set fill pattern
; 0000:C1F4 prguf_drawText                01F4  Draw text string
; 0000:C206 prguf_setTextAlignment        0206  Set text alignment
; 0000:C21E prguf_getSystemMetric         021E  Get system metric (screen size etc)
; 0000:C24E prguf_setForeColor            024E  Set foreground color
; 0000:C254 prguf_setBackColor            0254  Set background color
; 0000:C278 prguf_getDialogValue          0278  Get dialog control value
; 0000:C27E prguf_setDialogValue          027E  Set dialog control value
; 0000:C29C prguf_allocBuffer             029C  Allocate work buffer
; 0000:C2A8 prguf_getControlRect          02A8  Get dialog control rectangle
; 0000:C2C0 prguf_scrollWindow            02C0  Scroll window contents
; 0000:C2C6 prguf_invalidateRect          02C6  Invalidate rectangle (trigger repaint)
; 0000:C2CC prguf_validateRect            02CC  Validate rectangle (skip repaint)
; 0000:C30A prguf_setScrollRange          030A  Set scroll bar range
; 0000:C572 prguf_updateWindow            0572  Force immediate window update
;
; --- DMGUF Thunk Table ---
;
; These thunks dispatch to DMGUF functions via the far-call callback
; pointer at [0x1506]. DMGUF provides drawing primitives, coordinate
; transforms, shape management, and geometry functions.
;
; Address   Name                          Func  Description
; -------   ----                          ----  -----------
; 0000:C561 dmguf_dispatch               (entry) DMGUF far-call dispatcher
; 0000:C6B0 dmguf_func_wrapper1            (var) DMGUF wrapper (secondary entry)
; 0000:C6C0 dmguf_drawShapePrimitive        6C0  Draw shape using DMGUF primitives
; 0000:C71E dmguf_transformShape             71E  Apply transform to shape
; 0000:C82E dmguf_renderShape                82E  Full shape render with attributes (836 bytes,
;                                                 largest DMGUF thunk -- handles all shape
;                                                 types with clipping, transforms, fill/stroke)
; 0000:CB72 dmguf_getShapeMetric             B72  Get shape metric (dimensions, bounds)
; 0000:CC09 dmguf_setShapeProperty           C09  Set shape drawing property
; 0000:CC9F dmguf_calcShapeArea              C9F  Calculate shape area/extent
; 0000:CCDC dmguf_setDrawMode                CDC  Set drawing mode (XOR/normal)
; 0000:CCFD dmguf_moveTo                     CFD  Move current position to (x,y)
; 0000:CD19 dmguf_lineTo                     D19  Draw line to (x,y)
; 0000:CD3C dmguf_closePath                  D3C  Close current path
; 0000:CD4B dmguf_beginPath                  D4B  Begin new path
; 0000:CD5E dmguf_setClipRect                D5E  Set clipping rectangle
; 0000:CD89 dmguf_saveContext                D89  Save graphics context
; 0000:CD9A dmguf_setForeColor               D9A  Set foreground color
; 0000:CDAD dmguf_setBackColor               DAD  Set background color
; 0000:CDC0 dmguf_setFillPattern             DC0  Set fill pattern
; 0000:CDC6 dmguf_setLineWidth               DC6  Set line width
; 0000:CDDE dmguf_setLineStyle               DDE  Set line style
; 0000:CDEF dmguf_getTextExtent              DEF  Get text string extent
; 0000:CDFD dmguf_getDeviceCaps              DFD  Get device capabilities
; 0000:CE05 dmguf_getScreenSize              E05  Get screen dimensions
; 0000:CE0D dmguf_setCoordSystem             E0D  Set coordinate system/mapping
; 0000:CE25 dmguf_pushClipRect               E25  Push clipping rectangle
; 0000:CE2D dmguf_popClipRect                E2D  Pop clipping rectangle
; 0000:CE35 dmguf_drawRectOutline            E35  Draw rectangle outline
; 0000:CE3D dmguf_drawRectFilled             E3D  Draw filled rectangle
; 0000:CE45 dmguf_drawEllipseOutline         E45  Draw ellipse outline
; 0000:CE4D dmguf_drawEllipseFilled          E4D  Draw filled ellipse
; 0000:CE55 dmguf_drawPolyline               E55  Draw polyline
; 0000:CE5D dmguf_drawPolygonFilled          E5D  Draw filled polygon
; 0000:CE65 dmguf_drawArc                    E65  Draw arc
; 0000:CE6E dmguf_drawBezier                 E6E  Draw Bezier curve
; 0000:CE82 dmguf_setDrawAttributes          E82  Set comprehensive draw attributes
; 0000:CE98 dmguf_pushPopClip                E98  Push/pop clip region helper
; 0000:CEE8 dmguf_allocShapeMemory           EE8  Allocate memory for shape data
; 0000:CEFF dmguf_freeShapeMemory            EFF  Free shape memory
; 0000:CF15 dmguf_setLinePattern             F15  Set line dash/dot pattern
; 0000:CF36 dmguf_setWriteMode               F36  Set pixel write mode (XOR, OR, COPY)
;
; --- Mouse / FP Emulation Integration (seg_0EAD region) ---
;
; 0000:CF89 draw_disableMouseCursor            (6) Disable mouse cursor
; 0000:CF8F draw_enableMouseCursor             (6) Enable mouse cursor
; 0000:CF95 draw_setMouseBounds               283  Set mouse movement boundaries
;                                                   (INT 33h AX=0007 set horizontal range,
;                                                    INT 33h AX=0008 set vertical range)
;
; --- Memory / DOS Services ---
;
; 0000:D0B0 draw_resizeMemBlock                42  Resize DOS memory block (INT 21h AH=4Ah)
; 0000:D0DA draw_ctermsub                      38  __ctermsub: call registered termination
;                                                   handlers, indirect call via [0x16A0]
; 0000:D100 draw_cinit                         34  __cinit: call CRT initialization functions
; 0000:D122 draw_envInit                      398  Environment initialization: parse PSP command
;                                                   line, build argc/argv/envp arrays
; 0000:D2B0 draw_stdoutWrite                   43  Write to stdout (INT 21h AH=40h, BX=2)
; 0000:D2DB draw_exit                          41  _exit(): close files, call _cexit, INT 21h
;                                                   AH=4Ch
; 0000:D304 draw_sbrk                          66  _sbrk(): expand heap (INT 21h AH=4Ah resize)
; 0000:D346 draw_strcmp                         18  strcmp() -- string comparison
; 0000:D358 draw_strcpy                         73  strcpy() -- string copy
; 0000:D3A1 draw_strcat                        227  strcat() -- string concatenation (with variant)
; 0000:D484 draw_strlen                         58  strlen() -- string length
; 0000:D4BE draw_strchr                         34  strchr() -- find character in string
; 0000:D4E0 draw_itoa                          116  _itoa(): integer to ASCII conversion
; 0000:D554 draw_xtoa                          110  Internal: hex/decimal conversion helper
; 0000:D5C2 draw_reverseString                  86  Reverse string in-place (for itoa output)
; 0000:D618 draw_atoi                           50  atoi(): ASCII to integer conversion
; 0000:D64A draw_isDigit                        32  isdigit() -- test if character is '0'-'9'
; 0000:D66A draw_toupper                        64  toupper() -- convert to uppercase
; 0000:D6AA draw_sprintf                        84  Mini sprintf() -- format integer to buffer
; 0000:D6FE draw_absval                         28  abs() -- absolute value
; 0000:D71A draw_memcpy                        122  memcpy() / memmove()
; 0000:D794 draw_memset                         72  memset() -- fill memory with byte value
; 0000:D7DC draw_ldiv                          142  Long division (32-bit / 16-bit)
; 0000:D86A draw_stderrWriteChar                22  Write character to stderr (INT 21h AH=40h, BX=2)
; 0000:D880 draw_stderrWriteString              16  Write string to stderr
; 0000:D890 draw_dosErrorHandler               164  DOS critical error handler
; 0000:D934 draw_heapAlloc                      52  Heap allocation (malloc wrapper)
; 0000:D968 draw_heapFree                      187  Heap free (free wrapper)
;
; --- Print Support ---
;
; 0000:DA23 draw_printDrawing                  195  Main print handler: set up print session,
;                                                   iterate shapes, render to printer
; 0000:DAE6 draw_printSetupMargins              62  Set print margins for page layout
; 0000:DB24 draw_printMainLoop                 283  Print main loop: render each shape to printer,
;                                                   handle page breaks, scaling
; 0000:DC3F draw_printScaleCoords              100  Scale coordinates for print resolution
; 0000:DCA3 draw_printAdjustAspect              22  Adjust aspect ratio for printer DPI
; 0000:DCB9 draw_printMapToPage                 68  Map drawing coords to printed page
; 0000:DCFD draw_printRenderHeader              95  Print file header/title on page
; 0000:DD5C draw_printRenderFooter              29  Print footer / page number
; 0000:DD79 draw_printSetFont                   20  Set printer font for text shapes
; 0000:DD8D draw_printSetLineAttrs              57  Set printer line attributes
; 0000:DDC6 draw_printSetFillAttrs              44  Set printer fill attributes
; 0000:DDF2 draw_printOutputPrimitive          115  Output a GDI primitive to printer
; 0000:DE65 draw_printRenderShape              705  Render a single shape to printer (largest
;                                                   print function -- handles all shape types)
; 0000:E126 draw_printCalcBounds                61  Calculate print bounds for shape
; 0000:E163 draw_printPageSetup                 39  Set up page dimensions
; 0000:E18A draw_printGetResolution             19  Get printer resolution (DPI)
; 0000:E19D draw_printInit                      48  Initialize print subsystem
; 0000:E1CD draw_printStartJob                  70  Start print job
; 0000:E213 draw_printEndJob                    35  End print job
; 0000:E236 draw_printNewPage                   25  Start new page
; 0000:E24F draw_printEject                     51  Eject page / form feed
; 0000:E282 draw_printGetPageSize               86  Get page size in printer units
; 0000:E2D8 draw_printGetMargins                84  Get current margins
; 0000:E32C draw_printSetOrientation            30  Set print orientation (portrait/landscape)
; 0000:E34A draw_printSelectDevice              67  Select printer device
; 0000:E38D draw_printConfigDialog             306  Print configuration dialog handler
; 0000:E4BF draw_printPreview                   41  Print preview handler
; 0000:E4E8 draw_printPageLayout               269  Print page layout calculator
; 0000:E5F5 draw_printScaleToFit                38  Scale drawing to fit page
; 0000:E61B draw_printTiledOutput              182  Tiled print output (for large drawings)
; 0000:E6D1 draw_printDispatcher                77  Print mode dispatcher
; 0000:E71E draw_printGetDeviceCaps             40  Get printer device capabilities
;
; --- DMEFORM Print Forms ---
;
; 0000:E746 draw_loadDmeform                    33  Load DMEFORM resource for forms
; 0000:E767 draw_unloadDmeform                  18  Unload DMEFORM resource
; 0000:E779 draw_openPrintForm                  35  Open a print form
; 0000:E79C draw_closePrintForm                 18  Close a print form
; 0000:E7AE draw_initPrintForm                  33  Initialize print form fields
; 0000:E7CF draw_setPrintFormData               33  Set data in print form field
; 0000:E7F0 draw_dmcursorLoad                    5  Load DMCSR stub
; 0000:E7F5 draw_dmcursorUnload                  5  Unload DMCSR stub
; 0000:E7FA draw_handlePrintEvent               35  Handle print form event
; 0000:E81D draw_printFormEventLoop             92  Print form event loop
; 0000:E879 draw_printFormDispatch              12  Print form event dispatcher
; 0000:E885 draw_printFormStub1                  6  Print form stub 1
; 0000:E88B draw_printFormStub2                 13  Print form stub 2
; 0000:E898 draw_printFormHandler              252  Print form master handler
;
; --- INT E0h DeskMate API Wrappers ---
;
; 0000:E994 draw_intE0h_generic                 33  Generic INT E0h caller
; 0000:E9B5 draw_intE0h_0003                    10  INT E0h AX=0003 (core service)
;
; 0000:E9BF draw_intE0h_stub0                    5  INT E0h stub (returns immediately)
; 0000:E9C4 draw_intE0h_stub1                    5  INT E0h stub
; 0000:E9C9 draw_intE0h_stub2                    5  INT E0h stub
; 0000:E9CE draw_intE0h_stub3                    5  INT E0h stub
; 0000:E9D3 draw_intE0h_stub4                    5  INT E0h stub
; 0000:E9D8 draw_intE0h_stub5                    5  INT E0h stub
; 0000:E9DD draw_intE0h_stub6                    5  INT E0h stub
; 0000:E9E2 draw_intE0h_stub7                    5  INT E0h stub
; 0000:E9E7 draw_intE0h_stub8                    5  INT E0h stub
; 0000:E9EC draw_intE0h_stub9                   10  INT E0h stub (extended)
; 0000:E9F6 draw_intE0h_stubA                    5  INT E0h stub
; 0000:E9FB draw_intE0h_stubB                    5  INT E0h stub
; 0000:EA00 draw_intE0h_stubC                    5  INT E0h stub
; 0000:EA05 draw_intE0h_stubD                    5  INT E0h stub
; 0000:EA0A draw_intE0h_stubE                    5  INT E0h stub
; 0000:EA0F draw_intE0h_stubF                    5  INT E0h stub
;
; --- PRGUF Far-Call Dispatch Stubs ---
;
; These 6-byte stubs load a function index and jump to the PRGUF or
; DMGUF dispatch entry. Pattern: mov ax, <funcId>; jmp dispatcher
;
; 0000:EA14 prguf_far_call_stub0               12  PRGUF far-call stub (func 0)
; 0000:EA20 prguf_far_call_stub1                6  PRGUF far-call stub
; 0000:EA26 prguf_far_call_stub2                6  PRGUF far-call stub
; 0000:EA2C prguf_far_call_stub3                6  PRGUF far-call stub
; 0000:EA32 prguf_far_call_stub4               18  PRGUF far-call stub (extended)
; 0000:EA44 prguf_far_call_stub5                6  PRGUF far-call stub
; 0000:EA4A prguf_far_call_stub6                6  PRGUF far-call stub
; 0000:EA50 prguf_far_call_stub7                6  PRGUF far-call stub
; 0000:EA56 prguf_far_call_stub8               12  PRGUF far-call stub
; 0000:EA62 prguf_far_call_stub9               18  PRGUF far-call stub
; 0000:EA74 prguf_far_call_stubA                6  PRGUF far-call stub
; 0000:EA7A prguf_far_call_stubB                6  PRGUF far-call stub
; 0000:EA80 prguf_far_call_stubC                6  PRGUF far-call stub
; 0000:EA86 prguf_far_call_stubD                6  PRGUF far-call stub
; 0000:EA8C prguf_far_call_stubE                6  PRGUF far-call stub
; 0000:EA92 prguf_far_call_stubF                6  PRGUF far-call stub
; 0000:EA98 prguf_far_call_stub10               6  PRGUF far-call stub
;
; --- DM89 Event Dispatch / FP Helpers ---
;
; 0000:EA9E draw_dm89EventDispatch             331  DM89 event dispatch: route events to
;                                                   application handlers via jump table at
;                                                   cs:[bx + 0x10]. Handles INT vector
;                                                   installation (INT 02h save/restore),
;                                                   FP emulation initialization.
; 0000:EBE9 draw_installFpEmulation             41  Install 8087 FP emulation (save INT 34h-3Dh
;                                                   vectors, install emulation handlers)
; 0000:EC12 draw_saveFpVectors                  72  Save FP interrupt vectors (INT 21h AH=35h
;                                                   for INT 34h through INT 3Dh, store at [0x1C])
; 0000:EC5A draw_restoreFpVectors               22  Restore original FP interrupt vectors
; 0000:EC70 draw_fpEmulatorEntry                16  FP emulator entry point (shared)
; 0000:EC80 draw_fpStackOverflow                 6  FP stack overflow handler
; 0000:EC86 draw_fpExecuteOpcode              516  FP opcode executor: decode and execute
;                                                   8087 instruction through emulation
; 0000:EE8A draw_fpArithOp                    217  FP arithmetic operation handler
; 0000:EF63 draw_fpLoadStore                   88  FP load/store operation handler
; 0000:EFBB draw_fpGetOperand                    8  Get FP operand from memory
; 0000:EFC3 draw_fpConvert                     170  FP format conversion
; 0000:F06D draw_fpSpecialOp                   230  FP special operations (FABS, FCHS, etc.)
; 0000:F153 draw_fpMathKernel                1140  FP math kernel: multiply, divide, sqrt,
;                                                   trig functions (sin, cos, atan2). This is
;                                                   the core of the 8087 software emulation.
; 0000:F5C7 draw_fpDispatchType1                63  FP dispatch type 1 (ESC opcode)
; 0000:F606 draw_fpDispatchType2               299  FP dispatch type 2 (FWAIT + ESC)
; 0000:F731 draw_fpCheckStack                   85  Check FP stack for overflow/underflow
; 0000:F786 draw_fpPushValue                    11  Push value onto FP stack
; 0000:F791 draw_fpPopValue                    214  Pop value from FP stack
; 0000:F867 draw_fpNormalize                    12  Normalize FP result
; 0000:F873 draw_fpLoadConst_0                   5  Load FP constant 0.0
; 0000:F878 draw_fpLoadConst_1                   7  Load FP constant 1.0
; 0000:F87F draw_fpLoadConst_pi                  9  Load FP constant pi
; 0000:F888 draw_fpLoadConst_log2               7  Load FP constant log2(10)
; 0000:F88F draw_fpCompare                     105  FP comparison operation
; 0000:F8F8 draw_fpSetFlags                      4  Set FP condition flags
; 0000:F8FC draw_fpRoundToInt                   19  Round FP value to integer
; 0000:F90F draw_fpAbsoluteValue                 8  FP absolute value
; 0000:F917 draw_fpMultiply                    882  FP multiplication (software)
; 0000:FC89 draw_fpDivide                     2010  FP division (software, largest FP function)
;
; --- FP Support Continued ---
;
; 10463 draw_fpSqrt                            197  FP square root
; 10528 draw_fpTrigHelper                      100  FP trigonometric helper
; 1058C draw_fpSinCosHelper                     19  Sin/cos calculation helper
; 1059F draw_fpAtanHelper                       67  Arctangent helper
; 105E2 draw_fpExpHelper                        39  Exponential helper
; 10609 draw_fpScaleHelper                      87  Scale/normalize helper
; 10660 draw_fpIntToFloat                      106  Convert integer to float
; 106CA draw_fpFormatOutput                   1024  Format FP result for output
; 10ACA draw_fpInit                             18  Initialize FP emulator state
; 10ADC draw_fpReset                            24  Reset FP emulator
; 10AF4 draw_fpGetStatus                        64  Get FP status word
; 10B34 draw_fpSetControl                      152  Set FP control word
; 10BCC draw_fpClearException                   25  Clear FP exception flags
; 10BE5 draw_fpCheckException                   95  Check for FP exceptions
; 10C44 draw_fpStoreResult                     157  Store FP result to memory
; 10CE1 draw_fpStoreInteger                     47  Store FP as integer
; 10D10 draw_fpLoadInteger                     110  Load integer as FP
; 10D7E draw_fpStorePackedBCD                   72  Store FP as packed BCD
; 10DC6 draw_fpLoadBCD                         166  Load packed BCD as FP
; 10E6C draw_fpExtendedOp                       78  Extended FP operation handler
;
; --- INT Vector / NMI Handling ---
;
; 10EBA draw_saveIntVectors                     47  Save INT 02h (NMI) and INT 23h (Ctrl-C)
;                                                   vectors, install Draw's own handlers
; 10EE9 draw_restoreIntVectors                  71  Restore original INT 02h/23h vectors
;                                                   (recursive: calls itself for second vector)
;
; --- CRT Startup (seg_10F3) ---
;
; 10F30 start                                  804  CRT entry point / _start:
;                                                   - Check DOS version >= 2.0
;                                                   - Set up SS:SP
;                                                   - Call __cinit (CRT initialization)
;                                                   - On failure: call _exit(0xFF)
;                                                   - Get InDOS flag (INT 21h AH=34h)
;                                                   - INT E0h AX=0600h (DM event poll)
;                                                   - INT E0h AX=060Dh (DM version check)
;                                                   - INT E0h AX=4D06h (shell register)
;                                                   - Set up PSP, resize memory block
;                                                   - INT E0h AX=4D04h (register module 1)
;                                                   - INT E0h AX=4D05h (register module 2)
;                                                   - Call main() via DM89 dispatch
;
; --- DM89 Function Stubs (seg_10F3) ---
;
; 11254 draw_dm89Stub_20E0                       5  DM89 stub: AX=20E0h (unregister module)
; 11259 draw_dm89Stub_20DF                       5  DM89 stub: AX=20DFh (shutdown notification)
; 1125E draw_dm89Stub_203B                       5  DM89 stub: AX=203Bh (deactivate)
; 11263 draw_dm89Stub_203A                       5  DM89 stub: AX=203Ah (activate)
; 11268 draw_dm89Stub_2111                       3  DM89 stub: AX=2111h (init complete)
;
; --- DM89 Far-Call Dispatcher (seg_10F3) ---
;
; 1126B draw_dm89FarCallDispatch              2259  Far-call dispatcher: resolve DM89 function
;                                                   codes, dispatch to registered callbacks.
;                                                   Uses indirect calls through dispatch tables.
;
; --- MSC Math Library (seg_10F3 tail / seg_10FD) ---
;
; 11B3E draw_mathInit                          793  MSC math library initialization
; 11E57 draw_mathLongMul                      2121  Long multiplication (32x32 -> 64 bit)
; 126A0 draw_mathLongDiv                       598  Long division (64 / 32 -> 32 bit)
; 128F6 draw_mathEntryPoint                   1722  Math library entry point (called from CRT)
;
; ========================================================================
; INT E0h API CALL SUMMARY
; ========================================================================
;
; DRAW.PDM makes 33 INT E0h calls across these service classes:
;
; AH=00h: Core services
;   AX=0003  (1 call) at 0000:5258 -- core service, possibly font init
;
; AH=02h: Resource & UI services
;   AX=0206  (8 calls) -- Load resource module (PRGUF, DMGUF, DMEFORM,
;                          DMCSR, and print form resources)
;   AX=0207  (6 calls) -- Unload resource module
;   AX=0208  (4 calls) -- Execute resource function (PRGUF callback)
;
; AH=06h: Window / Event / File services
;   AX=0600  (2 calls) -- Get event / open file
;   AX=0603  (2 calls) -- File write / resource dispatch
;   AX=060D  (1 call)  -- Version check
;   AX=060E  (2 calls) -- Process/dispatch event
;
; AH=07h: Memory / Timer services
;   AX=0700  (1 call)  -- Allocate memory / yield / timer tick
;
; AH=4Dh: Shell / Host management
;   AX=4D04  (1 call)  -- Register module handle 1
;   AX=4D05  (1 call)  -- Register module handle 2
;   AX=4D06  (1 call)  -- Shell registration
;
; ========================================================================
; INT 33h MOUSE CALLS
; ========================================================================
;
; DRAW.PDM makes 3 INT 33h (mouse driver) calls:
;
;   AX=0003 at 0000:5232 -- Get mouse position and button status
;                            (used during interactive shape creation)
;   AX=0007 at 0000:CEBA -- Set horizontal mouse range (clamp to canvas)
;   AX=0008 at 0000:CEDD -- Set vertical mouse range (clamp to canvas)
;
; ========================================================================
; INT 34h-3Dh FLOATING POINT EMULATION
; ========================================================================
;
; DRAW.PDM contains 270 calls to INT 34h-3Dh for 8087 FP emulation:
;
;   INT 34h:   7 calls  (ESC opcodes)
;   INT 35h:  17 calls  (FWAIT + ESC)
;   INT 37h:   5 calls  (segment override + ESC)
;   INT 38h:  20 calls  (FIADD, FISUB, FICOMP, etc.)
;   INT 39h: 118 calls  (FLD, FST, FSTP, etc. -- most common)
;   INT 3Ah:  21 calls  (FADD, FSUB, FMUL, FDIV)
;   INT 3Bh:  40 calls  (FLD/FST with memory operands)
;   INT 3Ch:   3 calls  (misc FPU: FINIT, FLDCW, etc.)
;   INT 3Dh:  39 calls  (FILD, FIST, FISTP -- integer conversion)
;
; The MSC 5.x runtime installs these interrupt handlers at program start
; (draw_saveFpVectors / draw_installFpEmulation). Each INT instruction
; is followed by an encoded 8087 opcode that the emulator decodes and
; executes in software. This enables DRAW.PDM to run on machines without
; an 8087 math coprocessor.
;
; FP is used for:
;   - Circle/ellipse geometry (center + radius -> point generation)
;   - Arc angle calculations (start/end angles, sweep)
;   - Bezier curve evaluation (cubic Bezier control points)
;   - Zoom scaling (arbitrary zoom factors)
;   - Print coordinate mapping (DPI scaling)
;   - Rotation transforms (sin/cos of rotation angle)
;
; ========================================================================
; NEGATIVE-OFFSET CALL RESOLUTION
; ========================================================================
;
; Calls to sub_FFFFxxxx in the callgraph represent near calls to thunk
; stubs at the top of the code segment. These are PRGUF/DMGUF dispatch
; thunks that use relative negative offsets (wrapping around 16-bit
; address space). The actual targets are within the same segment:
;
;   sub_FFFFA48F -> 0000:A48F  draw_setTextFont
;   sub_FFFFA490 -> 0000:A490  draw_getTextMetrics
;   sub_FFFFA4C1 -> 0000:A4C1  draw_getCharWidth
;   sub_FFFFA507 -> 0000:A507  draw_measureString
;   sub_FFFFA631 -> 0000:A631  draw_setTextAttributes
;   sub_FFFFAB30 -> 0000:AB30  draw_pushUndoState
;   sub_FFFFAB94 -> 0000:AB94  draw_popUndoState
;   sub_FFFFAC04 -> 0000:AC04  draw_getEvent
;   sub_FFFFB12B -> 0000:B12B  draw_getPatternTable
;   sub_FFFFB20C -> 0000:B20C  draw_getColorTable
;   sub_FFFFB2F5 -> 0000:B2F5  draw_setColorEntry
;   sub_FFFFB3F5 -> 0000:B3F5  draw_getColorEntry
;   sub_FFFFB490 -> 0000:B490  draw_setPatternEntry
;   sub_FFFFB4B2 -> 0000:B4B2  draw_getPatternEntry
;   sub_FFFFBBD2 -> 0000:BBD2  draw_crtExit
;   sub_FFFFBD34 -> 0000:BD34  draw_loadDmgufResource
;   sub_FFFFBE2B -> (within draw_dm89EventDispatch region)
;   sub_FFFFBE31 -> (within draw_dm89EventDispatch region)
;   sub_FFFFBE37 -> (within draw_dm89EventDispatch region)
;   sub_FFFFBE3D -> (within draw_dm89EventDispatch region)
;   sub_FFFFBE4F -> (within draw_dm89EventDispatch region)
;   sub_FFFFBE55 -> (within draw_dm89EventDispatch region)
;   sub_FFFFBE5B -> (within draw_dm89EventDispatch region)
;   sub_FFFFBE8B -> (within draw_dm89EventDispatch region)
;   sub_FFFFBEFF -> 0000:BEFF  draw_setupPrintSession
;   sub_FFFFC03E -> 0000:C03E  prguf_beginPaint
;   sub_FFFFC045 -> 0000:C045  prguf_endPaint
;   sub_FFFFC074 -> 0000:C074  prguf_getViewport
;   sub_FFFFC07A -> 0000:C07A  prguf_setViewport
;   sub_FFFFC080 -> 0000:C080  prguf_getWindowRect
;   sub_FFFFC086 -> 0000:C086  prguf_setWindowRect
;   sub_FFFFC092 -> 0000:C092  prguf_enableMenuItem
;   sub_FFFFC098 -> 0000:C098  prguf_checkMenuItem
;   sub_FFFFC09E -> 0000:C09E  prguf_setMenuItemText
;   sub_FFFFC0AA -> 0000:C0AA  prguf_getStringResource
;   sub_FFFFC0B0 -> 0000:C0B0  prguf_putStringResource
;   sub_FFFFC0B6 -> 0000:C0B6  prguf_loadStringResource
;   sub_FFFFC0BC -> 0000:C0BC  prguf_freeResource
;   sub_FFFFC0C2 -> 0000:C0C2  prguf_getResourceSize
;   sub_FFFFC0DA -> 0000:C0DA  prguf_createDialog
;   sub_FFFFC0E0 -> 0000:C0E0  prguf_setDialogField
;   sub_FFFFC104 -> 0000:C104  prguf_showMessageBox
;   sub_FFFFC10A -> 0000:C10A  prguf_getInputString
;   sub_FFFFC11C -> 0000:C11C  prguf_showAboutBox
;   sub_FFFFC164 -> 0000:C164  prguf_openPrinter
;   sub_FFFFC16A -> 0000:C16A  prguf_closePrinter
;   sub_FFFFC17C -> 0000:C17C  prguf_setPrintFont
;   sub_FFFFC182 -> 0000:C182  prguf_setPrintMargin
;   sub_FFFFC188 -> 0000:C188  prguf_getPrintStatus
;   sub_FFFFC194 -> 0000:C194  prguf_drawLine
;   sub_FFFFC19A -> 0000:C19A  prguf_drawRect
;   sub_FFFFC1A0 -> 0000:C1A0  prguf_fillRect
;   sub_FFFFC1A6 -> 0000:C1A6  prguf_drawEllipse
;   sub_FFFFC1B2 -> 0000:C1B2  prguf_setLineWidth
;   sub_FFFFC1B8 -> 0000:C1B8  prguf_setLineStyle
;   sub_FFFFC1BE -> 0000:C1BE  prguf_setFillPattern
;   sub_FFFFC1F4 -> 0000:C1F4  prguf_drawText
;   sub_FFFFC206 -> 0000:C206  prguf_setTextAlignment
;   sub_FFFFC21E -> 0000:C21E  prguf_getSystemMetric
;   sub_FFFFC24E -> 0000:C24E  prguf_setForeColor
;   sub_FFFFC254 -> 0000:C254  prguf_setBackColor
;   sub_FFFFC278 -> 0000:C278  prguf_getDialogValue
;   sub_FFFFC27E -> 0000:C27E  prguf_setDialogValue
;   sub_FFFFC29C -> 0000:C29C  prguf_allocBuffer
;   sub_FFFFC2A8 -> 0000:C2A8  prguf_getControlRect
;   sub_FFFFC2C0 -> 0000:C2C0  prguf_scrollWindow
;   sub_FFFFC2C6 -> 0000:C2C6  prguf_invalidateRect
;   sub_FFFFC2CC -> 0000:C2CC  prguf_validateRect
;   sub_FFFFC30A -> 0000:C30A  prguf_setScrollRange
;   sub_FFFFC572 -> 0000:C572  prguf_updateWindow
;   sub_FFFFD346 -> 0000:D346  draw_strcmp
;   sub_FFFFD500 -> 0000:D500  (within draw_itoa region)
;   sub_FFFFD618 -> 0000:D618  draw_atoi
;   sub_FFFFD666 -> 0000:D666  (within draw_toupper region)
;   sub_FFFFD6FE -> 0000:D6FE  draw_absval
;   sub_FFFFE24F -> 0000:E24F  draw_printEject
;   sub_FFFFE7FA -> 0000:E7FA  draw_handlePrintEvent
;   sub_FFFFE7FF -> (within draw_handlePrintEvent)
;   sub_FFFFE804 -> (within draw_handlePrintEvent)
;   sub_FFFFE81D -> 0000:E81D  draw_printFormEventLoop
;   sub_FFFFE855 -> (within draw_printFormHandler region)
;   sub_FFFFE873 -> (within draw_printFormHandler region)
;   sub_FFFFE891 -> (within draw_printFormHandler region)
;   sub_FFFFE9B5 -> 0000:E9B5  draw_intE0h_0003
;   sub_FFFFE9BF -> 0000:E9BF  draw_intE0h_stub0
;   sub_FFFFEA20 -> 0000:EA20  prguf_far_call_stub1
;   sub_FFFFEA38 -> 0000:EA38  (within prguf_far_call_stub4)
;   sub_FFFFEA3E -> 0000:EA3E  (within prguf_far_call_stub4)
;   sub_FFFFEA44 -> 0000:EA44  prguf_far_call_stub5
;   sub_FFFFEA4A -> 0000:EA4A  prguf_far_call_stub6
;   sub_FFFFEA74 -> 0000:EA74  prguf_far_call_stubA
;   sub_FFFFEA7A -> 0000:EA7A  prguf_far_call_stubB
;
; ========================================================================
; END OF ANNOTATION HEADER
; ========================================================================
;
; The raw disassembly follows below with inline annotations for key
; functions. For the complete raw disassembly of all 35,548 lines,
; see disassembly/raw/draw.asm. This annotated version documents the
; function boundaries, calling conventions, data structures, and
; behavioral descriptions needed for Stage 4 transpilation.
;
; ========================================================================
; seg_0000: MAIN CODE SEGMENT
; ========================================================================

; ========================================================================
; draw_lookupShapeFunc - Lookup shape render function from ID table
; Address: 0000:0010  Size: 59 bytes
; Parameters: [bp+4] = pointer to shape ID word
; Returns: AX = function pointer from dispatch table
; Description: Given a shape ID, walks the shape function dispatch table
;   at [0x1C70]+2 (skipping header), comparing IDs until match found.
;   Stores matched function code in [0x1C58] and calls PRGUF far stub.
; ========================================================================
draw_lookupShapeFunc:                           ; 0000:0010
    push    bp
    mov     bp, sp
    sub     sp, 4
    mov     bx, [bp+4]                         ; bx = param: pointer to shape record
    mov     ax, [bx]                            ; ax = shape ID (first word of record)
    mov     [bp-2], ax                          ; local: shapeId
    mov     ax, [0x1C70]                        ; ax = g_shapeTablePtr (dispatch table base)
    mov     [bp-4], ax                          ; local: tablePtr
    add     word ptr [bp-4], 2                  ; skip table header (2 bytes)
.lookup_loop:                                   ; 0000:002E
    mov     bx, [bp-4]                          ; bx = current table entry ptr
    mov     ax, [bp-2]                          ; ax = shapeId to find
    cmp     [bx], ax                            ; compare table entry ID with target
    jne     .lookup_next                        ; not found, advance to next entry
    ; Found matching shape ID
    mov     ax, [bx+2]                          ; ax = function code from table entry
    mov     [0x1C58], ax                        ; g_currentShapeFunc = matched function
    push    ax
    mov     ax, 0x1C62                          ; ax = g_shapeListBase offset
    push    ds
    push    ax
    call    prguf_far_call_stub1                ; PRGUF: call shape render function
    mov     sp, bp
    pop     bp
    ret

.lookup_next:                                   ; 0000:002A
    add     word ptr [bp-4], 4                  ; advance by 4 bytes (2-word entries)
    jmp     .lookup_loop

; ========================================================================
; draw_calcBoundingBox - Calculate bounding box for shapes
; Address: 0000:004B  Size: 1067 bytes
; Parameters: (implicit: uses g_shapeDataPtr, g_shapeTablePtr globals)
; Returns: (updates bounding box via PRGUF render calls)
; Description: Iterates all shapes in the drawing, computing the overall
;   bounding box. For each shape, reads coordinate fields at offsets
;   +0x02 (x1), +0x06 (y1), +0x0A (x2), +0x0E (y2). The axis type
;   byte at [0x08E9] selects which comparison to use:
;     0 = track minimum of y1 and y2 (top edge)
;     1 = track maximum of y1 and y2 (bottom edge)
;     2 = track minimum of x1 and x2 (left edge)
;     3 = track maximum of x1 and x2 (right edge)
;   After computing bounds, makes a second pass to build clip rectangles
;   and call PRGUF render for each shape.
; ========================================================================
draw_calcBoundingBox:                           ; 0000:004B
    push    bp
    mov     bp, sp
    sub     sp, 0x2E
    push    si
    mov     al, [0x08E9]                        ; al = g_currentTool (axis type selector)
    cbw                                         ; sign-extend to word
    mov     [bp-4], ax                          ; local: axisType
    mov     byte ptr [0x1C63], 0                ; clear shape list flag
    ; Initialize bounding box accumulators to zero
    mov     word ptr [bp-0x1E], 0               ; local: clipLeft = 0
    mov     word ptr [bp-0x16], 0               ; local: clipRight = 0
    mov     word ptr [bp-0x1A], 0               ; local: clipTop = 0
    mov     word ptr [bp-0x12], 0               ; local: clipBottom = 0
    ; Get shape data pointer
    mov     ax, [0x1C6E]                        ; ax = g_shapeDataPtr
    mov     [bp-0x24], ax                       ; local: dataPtr
    add     word ptr [bp-0x24], 0x12            ; skip shape data header (18 bytes)
    mov     bx, [bp-0x24]
    mov     ax, [bx]                            ; ax = shape count
    mov     [bp-0x2E], ax                       ; local: shapeCount
    cmp     ax, 1
    jg      .has_shapes                         ; need at least 2 entries
    jmp     .done_bbox                          ; skip if 0 or 1

.has_shapes:                                    ; 0000:008C
    add     word ptr [bp-0x24], 2               ; advance past count word
    mov     ax, [bp-0x24]
    mov     [bp-0x2C], ax                       ; local: savedDataPtr
    mov     word ptr [bp-0x2A], 0               ; local: foundFirst = false
    mov     word ptr [bp-0x28], 0               ; local: shapeIdx = 0
    ; --- PASS 1: Find min/max coordinates ---
    ; (iterates shapes, comparing coords based on axisType)
    ; ... (continues for ~200 instructions)
    ; --- PASS 2: Build clip rects and render ---
    ; ... (continues for ~200 instructions)

.done_bbox:                                     ; 0000:0471
    ; Finalize bounding box, apply to view
    pop     si
    mov     sp, bp
    pop     bp
    ret

; ========================================================================
; draw_main - _main() entry point
; Address: 0000:0476  Size: 490 bytes
; Parameters: [bp+4] = argc equivalent (mouse X), [bp+6] = argv equiv (mouse Y)
; Returns: (does not return normally -- event loop)
; Description: Main application function called from DM89 dispatch.
;   1. Saves anchor coordinates to g_anchorX/g_anchorY
;   2. Sets g_modifiedFlag and g_editActiveFlag
;   3. Calls draw_initResources to set up DM89 context
;   4. Enters event loop: calls draw_getEvent, dispatches based on
;      event type byte at [0x093C]:
;        0 = null event (redraw if needed)
;        1 = menu command -> draw_dispatchMenuCommand
;        2 = keyboard event -> process keystroke
;        3 = timer event -> redraw if needed
;        4 = quit -> set exit flag
;        6 = window event -> handle resize/scroll
;      If shape creation in progress, calls draw_hitTestShape to check
;      if click is on existing shape.
; ========================================================================
draw_main:                                      ; 0000:0476
    push    bp
    mov     bp, sp
    sub     sp, 0x34
    push    di
    push    si
    mov     word ptr [bp-0x20], 0               ; local: exitFlag = 0
    mov     byte ptr [bp-0x1E], 0               ; local: quitRequested = false
    mov     byte ptr [bp-0x22], 0               ; local: saveNeeded = false
    mov     si, [bp+4]                          ; si = param1 (mouse X / argc)
    mov     di, [bp+6]                          ; di = param2 (mouse Y / argv)
    mov     [0xBD2E], si                        ; g_anchorX = si
    mov     [0xBD3A], di                        ; g_anchorY = di
    mov     byte ptr [0x1C42], 1                ; set active flag
    mov     byte ptr [0x09EC], 1                ; g_modifiedFlag = 1
    call    draw_initResources                  ; initialize DM89 resources
    ; Store initial shape position in shape array
    mov     bx, [0x1C5A]                        ; bx = g_shapeListIdx
    shl     bx, 1
    shl     bx, 1                               ; bx *= 4 (4 bytes per entry)
    add     bx, [0xC12E]                        ; bx += g_shapeArrayPtr
    mov     ax, [bp+4]
    mov     [bx], ax                            ; shapeArray[idx].x = param1
    mov     bx, [0x1C5A]
    shl     bx, 1
    shl     bx, 1
    add     bx, [0xC12E]
    mov     ax, [bp+6]
    mov     [bx+2], ax                          ; shapeArray[idx].y = param2
    ; --- Main Event Loop ---
.event_loop:                                    ; 0000:04C9
    cmp     byte ptr [bp-0x1E], 0               ; check quitRequested
    je      .get_event
    jmp     .exit_main                          ; exit if quit requested
.get_event:
    call    draw_getEvent                       ; get next DM89 event
    mov     si, [0x093F]                        ; si = g_mouseX (from event)
    mov     di, [0x0941]                        ; di = g_mouseY (from event)
    mov     al, [0x093C]                        ; al = event type byte
    cbw
    or      ax, ax
    jne     .not_null_event
    jmp     .handle_timer                       ; type 0: null/idle -> redraw check
.not_null_event:
    cmp     ax, 1
    jne     .not_menu_event
    jmp     .handle_menu                        ; type 1: menu command
.not_menu_event:
    cmp     ax, 2
    je      .handle_keyboard                    ; type 2: keyboard input
    cmp     ax, 3
    jne     .check_quit
    jmp     .handle_timer                       ; type 3: timer
.check_quit:
    cmp     ax, 4
    je      .handle_quit                        ; type 4: quit request
    cmp     ax, 6
    jne     .check_shape                        ; type 6: window event
    jmp     .handle_window
.handle_quit:                                   ; 0000:050C
    mov     byte ptr [bp-0x1E], 1               ; quitRequested = true
    mov     byte ptr [bp-0x22], 1               ; saveNeeded = true
.check_shape:                                   ; 0000:0514
    cmp     word ptr [bp-0x20], 0               ; check if shape creation active
    je      .event_loop                         ; if not, loop back
    push    di                                  ; push mouseY
    push    si                                  ; push mouseX
    call    draw_hitTestShape                   ; hit test at (si, di)
    add     sp, 4
    cmp     ax, 1                               ; did we hit a shape?
    jne     .no_hit
    ; Hit a shape: begin drag/edit operation
    mov     al, [0x0976]                        ; al = g_lineColor
    cbw
    push    ax
    mov     bx, [0x098E]                        ; bx = g_fillColorIdx
    mov     al, [bx+0x0990]                     ; al = g_colorPalette[fillIdx]
    cbw
    push    ax
    mov     ax, 1
    push    ax
    ; ... (continues with shape manipulation setup)

.handle_menu:                                   ; 0000:058B
    ; Dispatch menu command from event code
    ; ... (routes to draw_dispatchMenuCommand)

.handle_keyboard:                               ; 0000:0560
    ; Handle keyboard input (tool shortcuts, etc.)
    ; ...

.handle_timer:                                  ; 0000:05AA
    ; Timer/idle: check if redraw needed
    ; ...

.handle_window:                                 ; 0000:05B1
    ; Window event: resize, scroll, etc.
    ; ...

.exit_main:                                     ; 0000:0620
    ; Clean up and return to DM89 shell
    pop     si
    pop     di
    mov     sp, bp
    pop     bp
    ret

; ========================================================================
; draw_initResources - Initialize DM89 resources
; Address: 0000:0660  Size: 106 bytes
; Description: Initialize the DM89 resource context for Draw. Calls
;   draw_strcmp and draw_itoa to set up resource name strings.
; ========================================================================
draw_initResources:                             ; 0000:0660
    push    bp
    mov     bp, sp
    ; ... (calls draw_strcmp, draw_itoa for resource setup)
    pop     bp
    ret

; ========================================================================
; draw_hitTestShape - Hit test: check if point hits a shape
; Address: 0000:06CA  Size: 294 bytes
; Parameters: [bp+4] = x coordinate, [bp+6] = y coordinate
; Returns: AX = 1 if hit, 0 if miss
; Description: Iterates the shape list from front to back, checking if
;   the given (x,y) point falls within any shape's bounding box or
;   within tolerance of its outline (for lines/curves).
; ========================================================================
draw_hitTestShape:                              ; 0000:06CA
    push    bp
    mov     bp, sp
    ; ... (294 bytes of hit testing logic)
    pop     bp
    ret

; ========================================================================
; draw_mainEventHandler - Master event handler
; Address: 0000:28F6  Size: 1492 bytes
; Description: The core DM89 callback function registered with DESK.EXE.
;   This is the largest application function. It handles:
;   1. Window initialization (prguf_beginPaint, prguf_getPrintStatus,
;      prguf_getInputString, prguf_allocBuffer)
;   2. Configuration loading (read .FIG extension association,
;      check for "T" = Tandy mode, "M" = mono mode in config string)
;   3. Menu setup (enable/disable items based on state)
;   4. Event dispatch to sub-handlers
;   5. Drawing state management (undo, selection, tool state)
;
;   Config string parsing (at 0000:293E):
;     Reads config buffer at [0x093C], checks first byte != 0,
;     then checks [0x093D] == 0x54 ('T') for Tandy mode,
;     then [0x093D] == 0x4D ('M') for mono mode.
; ========================================================================
draw_mainEventHandler:                          ; 0000:28F6
    push    bp
    mov     bp, sp
    sub     sp, 0x36
    push    si
    mov     word ptr [bp-0x20], 0               ; local: initDone = false
    mov     byte ptr [0xC094], 0                ; g_snapActive = false (initial)
    mov     word ptr [bp-0x22], 1               ; local: firstTime = true
    ; Begin paint session
    call    prguf_beginPaint                    ; 0000:C03E
    call    prguf_getPrintStatus                ; 0000:C188
    call    prguf_getInputString                ; 0000:C10A
    mov     [0x1BF4], ax                        ; g_fileHandle = result
    ; Allocate work buffer (712 bytes = 0x2C8)
    mov     ax, 0x2C8
    push    ax
    call    prguf_allocBuffer                   ; 0000:C29C
    add     sp, 2
    ; Load DMGUF resource
    call    draw_loadDmgufResource              ; 0000:BD34
    inc     ax
    jne     .dmguf_ok
    ; DMGUF load failed: clean up and exit
    call    prguf_endPaint                      ; 0000:C045
    sub     ax, ax
    push    ax
    call    draw_crtExit                        ; 0000:BBD2
    add     sp, 2
.dmguf_ok:                                      ; 0000:2934
    ; Read config string
    mov     ax, 0x093C                          ; offset of g_eventBuffer
    push    ax
    call    prguf_putStringResource             ; 0000:C0B0
    add     sp, 2
    cmp     byte ptr [0x093C], 0                ; empty config?
    je      .no_config
    cmp     word ptr [0x093D], 0x54             ; 'T' = Tandy mode?
    jne     .no_config
    ; Tandy mode detected: re-read config
    mov     ax, 0x093C
    push    ax
    call    prguf_getStringResource             ; 0000:C0AA
    add     sp, 2
    mov     ax, 0x093C
    push    ax
    call    prguf_putStringResource
    add     sp, 2
    cmp     byte ptr [0x093C], 0
    je      .no_config
    cmp     word ptr [0x093D], 0x4D             ; 'M' = mono mode?
    jne     .no_config
    ; Mono mode detected
    mov     ax, 0x093C
    push    ax
    call    prguf_getStringResource
    add     sp, 2
    mov     word ptr [bp-0x20], 1               ; initDone = true (mono path)
.no_config:                                     ; 0000:2995
    ; ... (continues with menu setup, event loop registration,
    ;      tool palette initialization, grid/zoom defaults,
    ;      then enters the main DM89 event dispatch loop)
    ; ... (1492 bytes total)
    pop     si
    mov     sp, bp
    pop     bp
    ret

; ========================================================================
; draw_dispatchShapeEvent - Dispatch mouse event to shape handler
; Address: 0000:2ECA  Size: 269 bytes
; Parameters: [bp+4] = event code (0xFB01=down, 0xFB02=drag,
;             0xFB03=up, 0xFB05=dblclick)
;             [bp+6] = mouse X, [bp+8] = mouse Y
; Returns: (void)
; Description: Routes mouse events to the active tool's shape creation
;   handler. Event codes 0xFB01-0xFB05 are DM89 mouse events.
;   Uses jump table at cs:0x2F64 indexed by g_currentTool (0-9).
; ========================================================================
draw_dispatchShapeEvent:                        ; 0000:2ECA
    push    bp
    mov     bp, sp
    mov     ax, [bp+4]                          ; ax = event code
    cmp     ax, 0xFB01                          ; mouse down?
    jne     .not_fb01
    jmp     .handle_fb01
.not_fb01:
    cmp     ax, 0xFB02                          ; mouse drag?
    jne     .not_fb02
    jmp     .handle_fb02
.not_fb02:
    cmp     ax, 0xFB03                          ; mouse up?
    je      .handle_fb03
    cmp     ax, 0xFB05                          ; double-click?
    jne     .exit_dispatch
    jmp     .handle_fb05
.exit_dispatch:
    pop     bp
    ret

.handle_fb03:                                   ; 0000:2EEF
    ; Mouse up: finalize shape creation
    cmp     byte ptr [0x094C], 0                ; g_editMode == 0?
    jne     .dispatch_tool
    cmp     byte ptr [0xBD34], 0                ; check if shape valid
    je      .dispatch_tool
    jmp     .exit_dispatch                      ; skip if invalid

.dispatch_tool:                                 ; 0000:2F00
    mov     al, [0x094B]                        ; al = g_drawMode / current mode
    cbw
    cmp     ax, 9                               ; valid tool index? (0-9)
    jbe     .valid_tool
    jmp     .exit_dispatch
.valid_tool:
    add     ax, ax                              ; ax *= 2 (word-size jump table entries)
    xchg    bx, ax
    jmp     word ptr cs:[bx+0x2F64]             ; jump through tool dispatch table
    ; --- Tool dispatch targets ---
    ; 0x2F14: push params, call draw_createLine (sub_09B7B)
    ; 0x2F22: push params, call draw_createRectangle (sub_09C6B)
    ; 0x2F2D: push params, call draw_createRoundedRect (sub_09D82)
    ; 0x2F36: push params, call draw_createCircle (sub_06856)
    ; 0x2F3F: push params, call draw_createEllipse (sub_0A214)
    ; ... (remaining tools)

.handle_fb01:                                   ; 0000:2F8E
    ; Mouse down: begin shape creation
    ; ...
.handle_fb02:                                   ; 0000:2FA2
    ; Mouse drag: update rubber-band
    ; ...
.handle_fb05:                                   ; 0000:2F7A
    ; Double-click: edit shape properties
    ; ...

; ========================================================================
; draw_dispatchMenuCommand - Menu command dispatcher
; Address: 0000:2FD7  Size: 683 bytes
; Parameters: [bp+4] = menu command code (0xF5xx)
; Returns: (void)
; Description: Routes DeskMate menu commands to handler functions.
;   Commands in range 0xF500-0xF519 use jump table at cs:0x31B0.
;   Special case: 0xF51A goes to draw_optionsDialog.
; ========================================================================
draw_dispatchMenuCommand:                       ; 0000:2FD7
    push    bp
    mov     bp, sp
    mov     ax, [bp+4]                          ; ax = menu command code
    cmp     ax, 0xF51A                          ; Options > Grid/Snap/Zoom?
    jne     .not_options
    jmp     .handle_options                     ; -> sub_04938
.not_options:
    jle     .in_range                           ; F500-F519 range
    jmp     .out_of_range                       ; F51B+ handled separately
.in_range:
    sub     ax, 0xF500                          ; normalize to 0-based index
    cmp     ax, 0x19                            ; valid index? (0-25)
    jbe     .valid_cmd
    jmp     .exit_menu
.valid_cmd:
    add     ax, ax                              ; word-size entries
    xchg    bx, ax
    jmp     word ptr cs:[bx+0x31B0]             ; jump through menu table
    ; Jump table targets (cs:0x31B0):
    ;   F500: call sub_07B9E (draw_cmdNew)
    ;   F501: call sub_07CF9 (draw_cmdOpen)
    ;   F502: call sub_07F42 (draw_cmdSave)
    ;   F503: call sub_08044 (draw_cmdSaveAs)
    ;   F504: call sub_08143 (draw_cmdPrint)
    ;   F505: call sub_0858C (draw_cmdPrintSetup)
    ;   F506: call sub_08738 (draw_cmdMerge) + call sub_04103 (refreshStatus)
    ;   F507: call sub_08812 (draw_cmdSelectAll) + refreshStatus
    ;   F508: call sub_088EC (draw_cmdCut)
    ;   F509: call sub_00C8D (draw_handleFileMenu) in loop until F53F
    ;   F50A: call sub_08B16 (draw_cmdPaste)
    ;   F50B: call sub_08BAB (draw_cmdClear)
    ;   F50C: call sub_08C39 (draw_cmdDuplicate)
    ;   F50D: call sub_08F51 (draw_cmdUndo)
    ;   F50E: call sub_06D53 (draw_groupShapes)
    ;   F50F: call sub_014CC (draw_filePrint)
    ;   F510: call sub_015C9 (draw_filePrintSetup)
    ;   ... (remaining entries)

.handle_options:                                ; 0000:310C
    ; Route to draw_optionsDialog
    ; ...

.out_of_range:                                  ; 0000:31E4
    ; Handle extended menu commands (F51B+)
    ; ...

.exit_menu:                                     ; 0000:3280
    pop     bp
    ret

; ========================================================================
; draw_handleWindowEvent - Window event handler
; Address: 0000:3282  Size: 1799 bytes
; Parameters: [bp+4] = event code
; Description: Handles window-level events: repaint (0x8400), scroll
;   (0x8413), resize (0x8414), keyboard shortcuts (0xFF75/0xFF76).
;   When drawMode==4, calls draw_renderCanvas for full redraw.
; ========================================================================
draw_handleWindowEvent:                         ; 0000:3282
    push    bp
    mov     bp, sp
    sub     sp, 6
    push    si
    cmp     byte ptr [0x094B], 4                ; g_drawMode == 4 (creation)?
    jne     .skip_render
    push    word ptr [bp+4]
    call    draw_renderCanvas                   ; full canvas render
    add     sp, 2
.skip_render:
    cmp     byte ptr [0x09D8], 0                ; g_selectionLocked?
    jne     .check_events
    ; Dispatch window event by code
    mov     ax, [bp+4]
    cmp     ax, 0x8400                          ; repaint?
    jne     .not_repaint
    jmp     .handle_repaint
.not_repaint:
    cmp     ax, 0x8413                          ; scroll?
    jne     .not_scroll
    jmp     .handle_scroll
.not_scroll:
    cmp     ax, 0x8414                          ; resize?
    jne     .not_resize
    jmp     .handle_resize
.not_resize:
    cmp     ax, 0xFF75                          ; keyboard shortcut 1?
    je      .handle_key75
    cmp     ax, 0xFF76                          ; keyboard shortcut 2?
    jne     .check_events
    ; ... (1799 bytes total)

.handle_repaint:
    ; Full window repaint
    ; ...
.handle_scroll:
    ; Handle scroll bar position change
    ; ...
.handle_resize:
    ; Handle window resize
    ; ...
.handle_key75:
    ; Handle tool keyboard shortcut
    ; ...
.check_events:
    ; ...
    pop     si
    mov     sp, bp
    pop     bp
    ret

; ========================================================================
; draw_saveFigFile - Save drawing to .FIG file
; Address: 0000:5364  Size: 601 bytes
; Description: Saves the current drawing to a .FIG file. Checks shape
;   count (g_shapeCount at [0x09AE]), calls draw_initResources, then
;   iterates shape list via PRGUF calls to serialize each shape with
;   its coordinates, attributes, and type-specific data.
; ========================================================================
draw_saveFigFile:                               ; 0000:5364
    push    bp
    mov     bp, sp
    sub     sp, 0x40
    mov     ax, [0x09AE]                        ; ax = g_shapeCount
    mov     [bp-0x3E], ax                       ; local: savedCount
    or      ax, ax
    jne     .has_shapes
    jmp     .save_done                          ; nothing to save
.has_shapes:
    call    draw_initResources                  ; set up DM89 context
    push    word ptr [bp-0x3E]                  ; push shape count
    mov     ax, 0x1C62                          ; g_shapeListBase
    push    ds
    push    ax
    call    prguf_far_call_stub1                ; PRGUF: begin file write
    add     sp, 6
    mov     [bp-2], ax                          ; local: writeHandle
    ; ... (continues with shape serialization loop)
.save_done:
    mov     sp, bp
    pop     bp
    ret

; ========================================================================
; draw_loadFigFile - Load .FIG file
; Address: 0000:5DAF  Size: 572 bytes
; Description: Loads a .FIG vector drawing file. Similar structure to
;   draw_saveFigFile but reads shapes and builds the in-memory shape list.
; ========================================================================
draw_loadFigFile:                               ; 0000:5DAF
    push    bp
    mov     bp, sp
    sub     sp, 0x3E
    mov     ax, [0x09AE]                        ; ax = g_shapeCount
    mov     [bp-0x3E], ax
    or      ax, ax
    jne     .has_existing
    jmp     .load_done
.has_existing:
    call    draw_initResources
    ; ... (continues with file read and shape parsing)
.load_done:
    mov     sp, bp
    pop     bp
    ret

; ========================================================================
; draw_createLine - Line tool handler
; Address: 0000:9B7B  Size: (var)
; Parameters: [bp+4] = mouse X, [bp+6] = mouse Y
; Description: Handles mouse events for the line drawing tool.
;   On mouse down: records start point, sets shape header byte to 0x4C
;   ('L' for line), reads current color from g_patternTable.
;   On mouse drag: updates endpoint, draws rubber-band line.
;   On mouse up: finalizes line shape in shape list.
; ========================================================================
draw_createLine:                                ; 0000:9B7B
    push    bp
    mov     bp, sp
    sub     sp, 0x1E
    mov     word ptr [bp-8], 0                  ; local: dragState = 0
    mov     word ptr [bp-6], 0                  ; local: rubberBandActive = 0
    mov     ax, [bp+4]                          ; ax = mouse X
    mov     [bp-4], ax                          ; local: startX
    mov     ax, [bp+6]                          ; ax = mouse Y
    mov     [bp-2], ax                          ; local: startY
    ; Begin shape creation
    sub     ax, ax
    push    ax                                  ; param4 = 0
    push    ax                                  ; param3 = 0
    mov     ax, 1
    push    ax                                  ; param2 = 1 (line type)
    lea     ax, [bp-4]                          ; &startX
    push    ax                                  ; param1 = pointer to start coords
    call    draw_beginShapeCreation             ; begin interactive creation
    add     sp, 8
    cmp     ax, 1                               ; success?
    je      .creation_ok
    jmp     .line_done
.creation_ok:
    ; Set shape header
    mov     byte ptr [bp-0x1C], 0x4C            ; shape type = 'L' (line)
    ; Get current pattern color
    mov     al, [0x094E]                        ; al = g_patternIndex
    cbw
    mov     bx, ax
    mov     al, [bx+0x0950]                     ; al = g_patternTable[patternIndex]
    mov     [bp-0x1B], al                       ; local: colorByte
    ; Store start coordinates
    mov     ax, [bp+4]
    ; ... (continues with endpoint tracking and finalization)
.line_done:
    mov     sp, bp
    pop     bp
    ret

; ========================================================================
; CRT STARTUP AND DM89 MODULE LIFECYCLE
; ========================================================================

; ========================================================================
; draw_crtStartup - MSC 5.x CRT startup
; Address: 0000:BB0E  Size: 195 bytes
; Description: Standard MSC 5.x C runtime startup code:
;   1. Get DOS version (INT 21h AH=30h)
;   2. Save INT 00h vector (INT 21h AH=35h, AL=00h)
;   3. Install divide-by-zero handler (INT 21h AH=25h, AL=00h)
;   4. Parse environment segment (PSP:[2Ch])
;   5. Look for module name in environment (scan for "C;" prefix)
;   6. Set up file handle flags via IOCTL (INT 21h AH=44h)
;   7. Initialize atexit chain pointers
;   8. Call __cinit / __ctermsub registration
; ========================================================================
draw_crtStartup:                                ; 0000:BB0E
    mov     ah, 0x30
    int     0x21                                ; Get DOS version
    mov     [0x14D3], ax                        ; g_dosVersion = AX
    push    es
    mov     ax, 0x3500                          ; Get INT 00h vector
    int     0x21
    mov     [0x14BF], bx                        ; save offset
    mov     [0x14C1], es                        ; save segment
    pop     ds
    mov     ax, 0x2500                          ; Set INT 00h vector
    mov     dx, 0x88                            ; new handler offset
    int     0x21
    push    ss
    pop     ds                                  ; restore DS = DGROUP
    ; Parse environment and command line
    ; ... (continues for 195 bytes total)
    ret

; ========================================================================
; start - CRT entry point (seg_10F3:0000)
; Address: 10F3:0000  Size: 804 bytes
; Description: The DM89 entry point. Standard MSC 5.x _start:
;   1. Check DOS version >= 2.0 (INT 21h AH=30h)
;   2. Set up SS:SP from segment 113E
;   3. Call __cinit via far-call (lcall 0, 0xBAF3)
;   4. On failure: _exit(0xFF) via INT 21h AH=4Ch
;   5. Resize memory block (INT 21h AH=4Ah)
;   6. Get InDOS flag (INT 21h AH=34h)
;   7. Register with DeskMate:
;      - INT E0h AX=0600h (get event / check DM resident)
;      - INT E0h AX=060Dh (check DM version >= 0x4411)
;      - INT E0h AX=4D06h (register as shell module)
;   8. Set up DM89 dispatch tables
;   9. Register module handles:
;      - INT E0h AX=4D04h (register handle 1)
;      - INT E0h AX=4D05h (register handle 2)
;   10. Enter DM89 event dispatch loop
; ========================================================================
start:                                          ; 10F3:0000
    mov     ah, 0x30
    int     0x21                                ; Get DOS version
    cmp     al, 2                               ; DOS >= 2.0?
    jae     .dos_ok
    int     0x20                                ; Terminate if DOS 1.x
.dos_ok:
    mov     di, 0x113E                          ; DGROUP segment
    mov     si, [2]                             ; top of memory from PSP
    sub     si, di                              ; available paragraphs
    cmp     si, 0x1000                          ; need 64KB?
    jb      .stack_ok
    mov     si, 0x1000                          ; cap at 64KB
.stack_ok:
    cli
    mov     ss, di                              ; SS = DGROUP
    add     sp, 0xC13E                          ; set stack pointer
    sti
    jae     .init_ok
    ; Stack setup failed
    push    ss
    pop     ds
    lcall   0, 0xBAF3                           ; call __cinit (far)
    xor     ax, ax
    push    ax
    lcall   0, 0xBAF7                           ; call _exit(0) (far)
    mov     ax, 0x4CFF                          ; EXIT with error code 0xFF
    int     0x21
.init_ok:
    and     sp, 0xFFFE                          ; align stack
    mov     ss:[0x1460], sp                     ; save initial SP
    ; ... (continues with DeskMate registration and event loop setup)

; ========================================================================
; draw_dm89FarCallDispatch - DM89 far-call dispatcher
; Address: 10F3:033B  Size: 2259 bytes
; Description: The DM89 far-call dispatcher. Resolves function codes
;   passed in AX and dispatches to registered callback functions via
;   indirect calls through dispatch tables. This is the standard MSC
;   5.x DM89 module dispatcher pattern used by all PDM modules.
; ========================================================================
draw_dm89FarCallDispatch:                       ; 10F3:033B
    push    bp
    mov     bp, sp
    add     bp, 4                               ; adjust for return address
    lcall   [0x1530]                            ; call through dispatch table
    pop     bp
    ret

; ========================================================================
; DATA SEGMENT NOTES (seg_113E / seg_1142)
; ========================================================================
;
; The DGROUP fixup area at seg_113E contains the MSC CRT copyright:
;   "MS Run-Time Library - Copyright (c) 1987, Microsoft Corp."
;   (visible at file offset 0x113E8 in raw disassembly)
;
; The data segment at seg_1142 contains:
;   - Menu definition structures (DM89 menu descriptors)
;   - String resources (tool names, dialog labels, error messages)
;   - Shape type dispatch tables
;   - Color palette definitions (16 colors for TGA/CGA/EGA/VGA modes)
;   - Fill pattern bitmaps (8x8 pixel patterns for shape fills)
;   - Line style definitions (solid, dashed, dotted, dash-dot)
;   - .FIG file header template
;   - Dialog control definitions
;   - Font metric tables
;   - Print configuration defaults
;
; The BSS segment at seg_12D1 contains:
;   - Shape list array (dynamically sized)
;   - Undo buffer (stores previous shape states)
;   - Selection state (selected shape indices, group membership)
;   - Zoom/scroll state (zoom level, scroll position)
;   - Grid settings (spacing, snap enable, visibility)
;   - Current filename buffer
;   - Coordinate transform buffers
;   - Rubber-band state (XOR drawing coordinates)
;   - Print job state
;   - Clipboard buffer (for cut/copy/paste)
;
; ========================================================================
; END OF ANNOTATED DISASSEMBLY
; ========================================================================
