; ===========================================================================
; DESKTOP.PDM -- Annotated Disassembly
; Bayside Reverse Engineering Project
; ===========================================================================
;
; Module:        DESKTOP.PDM (Desktop UI -- icon launcher, file manager)
; Version:       DeskMate 3.05
; Priority:      P0 (core module)
; Compiler:      Microsoft C 5.x (1987)
; Memory Model:  Medium (far code, near data)
; File size:     72,681 bytes
; Load image:    72,169 bytes
; Entry point:   0E4C:000E (linear 0x0E4CE -> __astart)
; Functions:     521
; Instructions:  23,206
; Strings:       316
; Relocations:   13
;
; INT E0h calls: 19 (7 unique DeskMate API services)
; INT 21h calls: 35 (23 unique DOS functions)
; Other INTs:    12 (INT 11h, 13h, 15h, 20h)
;
; DM89 Header:   CS:IP = 0E4C:000E
; DM89 Imports:  None (self-contained UI module)
;
; Resource deps:  PRGUF.RES (Program User Functions -- main UI library)
;                 DMGUF.RES (DeskMate General User Functions)
;                 DMCSR.RES (DeskMate Cursor resource)
;                 DMSPELL.RES (Spell-check / profanity filter)
;
; ===========================================================================
;
; SUBSYSTEM MAP
; =============
;
; Address Range       Subsystem                  Description
; ------------------- -------------------------- ---------------------------
; 0x00010 - 0x008EA   Icon Grid / Desktop Layout Icon drawing, grid setup,
;                                                 layout engine, scrollbar
; 0x008EA - 0x00DA8   Icon Interaction           Icon selection, click
;                                                 handling, icon redraw
; 0x00DA8 - 0x01403   Icon Data / Config I/O     Icon data read/write,
;                                                 DESKTOP.CFG parsing
; 0x01403 - 0x01BDA   Menu Definition Engine     Menu create/delete/redefine,
;                                                 menu data structures
; 0x01BDA - 0x02428   Format / Diskcopy          Disk format, disk copy ops
; 0x02428 - 0x02B4E   Run Program / EXEC         Program launcher, CPU speed
; 0x02B4E - 0x030AB   File Copy / Config Save    File copy engine, config
;                                                 file write, disk swap
; 0x030AB - 0x03B62   Directory Tree Display     Tree view rendering,
;                                                 directory navigation
; 0x03B62 - 0x040E2   Directory Operations       Create/delete/change dir,
;                                                 format disk, delete dir
; 0x040E2 - 0x05848   Menu System / View Switch  Menu bar interaction,
;                                                 tree<->files<->menus view,
;                                                 file list display engine
; 0x05848 - 0x05F86   About Dialog / Disk Info   About box, disk info,
;                                                 version display
; 0x05F86 - 0x066AF   Drive Selection / Status   Current drive display,
;                                                 drive change, status bar
; 0x066AF - 0x06FDA   Scrollbar / Window Mgmt    Scroll handling, window
;                                                 focus, app switching
; 0x06FDA - 0x071A8   Application Launcher       PDM launch via PRGUF,
;                                                 error display
; 0x071A8 - 0x08870   File List / Sort / Search  File listing (largest fn),
;                                                 sort by name/type/date/size,
;                                                 file info display
; 0x08870 - 0x098EB   Menu Bar Rendering         Menu bar draw, menu
;                                                 highlight, keyboard accel
; 0x098EB - 0x09B7C   String Utilities           String copy, compare,
;                                                 path manipulation
; 0x09B7C - 0x09CE4   Main Entry / Init          desktop_main -- main init
;                                                 and event setup
; 0x09CE4 - 0x0A250   DOS File Operations        find_first/find_next,
;                                                 set_dta, mkdir, rmdir,
;                                                 get_disk_free
; 0x0A250 - 0x0A628   Hardware / Disk I/O        BIOS disk (INT 13h),
;                                                 equipment (INT 11h),
;                                                 cassette (INT 15h),
;                                                 IOCTL, drive geometry
; 0x0A628 - 0x0B792   Event Dispatch / Keyboard  Main event loop, keyboard
;                                                 handler, menu dispatch,
;                                                 File/Dir/Disk/View/Sort/
;                                                 Desktop menu handlers
; 0x0B792 - 0x0BDF8   Status Bar / Info Display  Status bar rendering,
;                                                 filename display, file
;                                                 count/size display
; 0x0BDF8 - 0x0C34F   Startup / Config Load      Config file reader,
;                                                 first-run detection,
;                                                 DESKTOP.CFG parsing
; 0x0C34F - 0x0CA57   Config Save / Drive Init   Config file writer,
;                                                 drive initialization,
;                                                 drive change handler
; 0x0CA57 - 0x0CEFA   View State Machine         View mode state machine
;                                                 (files/tree/menus), modal
;                                                 dialog dispatch
; 0x0CEFA - 0x0D370   Format / Diskcopy DOS      DOS format/diskcopy exec,
;                                                 INT vector save/restore
; 0x0D370 - 0x0DAD4   MSC Runtime Library        Memory management (malloc,
;                                                 realloc), CRT startup
;                                                 support, I/O buffer mgmt
; 0x0DAD4 - 0x0DC3C   MSC Heap / sbrk            sbrk, heap grow, segment
;                                                 allocation
; 0x0DC3C - 0x0DD09   DeskMate Window Callbacks  Window proc registration,
;                                                 callback dispatcher,
;                                                 cursor/attribute mgmt
; 0x0DD09 - 0x0DD99   DMGUF Thunks               2-byte thunks to DMGUF.RES
;                                                 functions (cfg read/write)
; 0x0DD99 - 0x0DE01   DeskMate Resource Alloc    INT E0h resource/memory
;                                                 allocation wrappers
; 0x0DE01 - 0x0DED1   DeskMate File I/O          INT E0h file open/write/
;                                                 close wrappers
; 0x0DED1 - 0x0E10E   PRGUF Thunks               2-3 byte thunks calling
;                                                 PRGUF.RES via loc_0DF49
; 0x0E10E - 0x0E397   About Dialog / Event Disp  About dialog builder,
;                                                 resource version display,
;                                                 INT E0h event dispatch
; 0x0E397 - 0x0E4CE   PRGUF Extended Thunks      Additional PRGUF thunks
;                                                 (AX=21xx series)
; 0x0E4CE - 0x0E5xx   __astart                   MSC 5.x CRT startup
;
; ===========================================================================
;
; PRGUF.RES DISPATCH TABLE
; ========================
;
; DESKTOP.PDM calls PRGUF.RES functions via a thunk table at 0xDF49.
; Each thunk loads AX with a PRGUF function code and jumps to the common
; dispatcher at loc_0DF49, which performs:
;   1. Far call into PRGUF.RES entry point (via relocatable address)
;   2. Error check (AX == -1 or -2 means not loaded)
;   3. Far call into the resolved function pointer at [0x3076]
;
; PRGUF Function Code -> Thunk Address -> Inferred Name
; -------------------------------------------------------
; AX=0204h -> sub_0DED1 (prguf_queryStatus)
; AX=0501h -> sub_0DED7 (prguf_loadApp)
; AX=0502h -> sub_0DEDD (prguf_unloadApp)
; AX=0600h -> sub_0DEE3 (prguf_getAppInfo)
; AX=060Ch -> sub_0DEE9 (prguf_refreshDrive)
; AX=0601h -> sub_0DEEF (prguf_getFileInfo -- via sub_0E34E)
; AX=0604h -> sub_0DEF5 (prguf_setAppState -- via sub_0E34E)
; AX=060Eh -> sub_0DEFB (prguf_getResVersion -- via sub_0E35E)
; AX=000Ch -> sub_0DF01 (prguf_getMenuWidth)
; AX=000Dh -> sub_0DF07 (prguf_getMenuHeight)
; AX=000Eh -> sub_0DF0D (prguf_setMenuData)
; AX=2004h -> sub_0DF71 (prguf_initView)
; AX=2006h -> sub_0DF77 (prguf_endPaint / lock release)    [24 callers]
; AX=2007h -> sub_0DF7D (prguf_beginPaint / lock acquire)  [16 callers]
; AX=2012h -> sub_0DF83 (prguf_getClientRect)
; AX=2013h -> sub_0DF89 (prguf_getScrollInfo)
; AX=2015h -> sub_0DF8F (prguf_setScrollPos)
; AX=2016h -> sub_0DF95 (prguf_showCaret)
; AX=2017h -> sub_0DF9B (prguf_setTimer)
; AX=2018h -> sub_0DFA1 (prguf_killTimer)
; AX=201Bh -> sub_0DFA7 (prguf_getIconSize)
; AX=201Ch -> sub_0DFAD (prguf_setIconPos)
; AX=201Dh -> sub_0DFB3 (prguf_getMenuBarHeight)
; AX=201Eh -> sub_0DFB9 (prguf_getFocus)
; AX=202Bh -> sub_0DFBF (prguf_openAboutDlg)
; AX=202Ch -> sub_0DFC5 (prguf_closeAboutDlg)
; AX=202Dh -> sub_0DFCB (prguf_setWindowTitle)
; AX=202Eh -> sub_0DFD1 (prguf_setWindowAttr)     [22 callers]
; AX=202Fh -> sub_0DFD7 (prguf_getWindowAttr)
; AX=2030h -> sub_0DFDD (prguf_setWindowFlag)
; AX=2032h -> sub_0DFE3 (prguf_getStartupInfo)
; AX=2037h -> sub_0DFE9 (prguf_setFileFilter)
; AX=2039h -> sub_0DFEF (prguf_enableMenu)
; AX=203Eh -> sub_0DFF5 (prguf_getScrollThumb)
; AX=203Fh -> sub_0DFFB (prguf_allocBuffer)        [10 callers]
; AX=2040h -> sub_0E001 (prguf_freeBuffer)
; AX=2041h -> sub_0E007 (prguf_clearBuffer)
; AX=2043h -> sub_0E00D (prguf_getCharWidth)
; AX=2044h -> sub_0E013 (prguf_moveTo)             [14 callers]
; AX=2047h -> sub_0E019 (prguf_setClipRegion)
; AX=2048h -> sub_0E01F (prguf_resetClipRegion)
; AX=2049h -> sub_0E025 (prguf_setTextColor)
; AX=204Ah -> sub_0E02B (prguf_setBgColor)         [19 callers]
; AX=204Bh -> sub_0E031 (prguf_setLineStyle)
; AX=2051h -> sub_0E037 (prguf_drawBorder)
; AX=2052h -> sub_0E03D (prguf_drawText)           [11 callers]
; AX=2053h -> sub_0E043 (prguf_drawTextLen)
; AX=2059h -> sub_0E049 (prguf_drawRect)
; AX=205Ah -> sub_0E04F (prguf_drawLine)
; AX=205Bh -> sub_0E055 (prguf_createWindow)
; AX=205Ch -> sub_0E05B (prguf_createChildWindow)
; AX=205Eh -> sub_0E061 (prguf_destroyChild)
; AX=205Fh -> sub_0E067 (prguf_setFocusChild)
; AX=2061h -> sub_0E06D (prguf_getHScrollPos)
; AX=2062h -> sub_0E073 (prguf_getVScrollPos)
; AX=2063h -> sub_0E079 (prguf_setScrollRange)
; AX=2066h -> sub_0E07F (prguf_scrollWindow)
; AX=2068h -> sub_0E085 (prguf_invalidateRect)
; AX=206Ah -> sub_0E08B (prguf_getActiveMenu)      [11 callers]
; AX=206Bh -> sub_0E091 (prguf_setMenuItemState)
; AX=206Ch -> sub_0E097 (prguf_getMenuItemCount)
; AX=206Dh -> sub_0E09D (prguf_setAccelTable)
; AX=206Eh -> sub_0E0A3 (prguf_setMenuStruct)      [7 callers]
; AX=2070h -> sub_0E0A9 (prguf_showDialog)
; AX=2071h -> sub_0E0AF (prguf_processDialog)
; AX=2072h -> sub_0E0B5 (prguf_showMessage)
; AX=2074h -> sub_0E0BB (prguf_setDriveList)
; AX=2076h -> sub_0E0C1 (prguf_getDialogResult)
; AX=2078h -> sub_0E0C7 (prguf_registerApp)
; AX=2079h -> sub_0E0CD (prguf_setMaxIcons)
; AX=207Ah -> sub_0E0D3 (prguf_getMaxIcons)
;
; DeskMate PRGUF extended thunks (via loc_0DF49 with far-call relocation):
; AX=20D6h -> sub_0E37F (prguf_loadResourceModule)
; AX=20D7h -> sub_0E385 (prguf_unloadResourceModule)
; AX=2102h -> sub_0E38B (prguf_allocMemory)
; AX=210Eh -> sub_0E391 (prguf_getAppHandle)
; AX=210Fh -> sub_0E397 (prguf_releaseAppHandle)
;
; ===========================================================================
;
; DMGUF.RES THUNK TABLE
; ======================
;
; Functions at 0xDD09-0xDD93 are 2-instruction thunks calling DMGUF.RES
; (DeskMate General User Functions) for configuration file I/O.
; Each thunk is just 2 bytes: "mov word ptr [...], val; ret" or similar.
; These are accessed via far call through a stored function pointer.
;
; Address    Name                          Description
; --------   ---------------------------   ---------------------------------
; sub_0DD09  dmguf_openCfgFile             Open configuration file for R/W
; sub_0DD0F  dmguf_readCfgSection          Read a section from .CFG file
; sub_0DD15  dmguf_writeCfgByte            Write single byte to .CFG
; sub_0DD1B  dmguf_writeCfgSection         Write section to .CFG file
; sub_0DD21  dmguf_deleteCfgSection        Delete section from .CFG
; sub_0DD27  dmguf_closeCfgFile            Close configuration file
; sub_0DD2D  dmguf_getCfgString            Get string from .CFG
; sub_0DD33  dmguf_getCurrentDir           Get current directory path
; sub_0DD39  dmguf_setCurrentDir           Set current directory
; sub_0DD3F  dmguf_getDriveLetter          Get current drive letter
; sub_0DD45  dmguf_setDriveLetter          Set current drive letter
; sub_0DD4B  dmguf_selectDrive             Select/activate a drive
; sub_0DD51  dmguf_getDiskType             Get disk type (floppy/hard)
; sub_0DD57  dmguf_getVolumeName           Get volume label
; sub_0DD5D  dmguf_formatPath              Format/normalize a path string
; sub_0DD63  dmguf_getTreeLevel            Get directory tree nesting level
; sub_0DD69  dmguf_getDriveCount           Get number of available drives
; sub_0DD6F  dmguf_getTreeNodeCount        Get dir tree node count
; sub_0DD75  dmguf_setTreeExpanded         Set tree node expanded state
; sub_0DD7B  dmguf_getTreeData             Get tree structure data
; sub_0DD81  dmguf_setFileAttr             Set file attribute bits
; sub_0DD87  dmguf_getFileAttr             Get file attribute bits
; sub_0DD8D  dmguf_getTreePath             Get full path from tree node
; sub_0DD93  dmguf_setTreeSelection        Set selected tree node
;
; ===========================================================================
;
; FUNCTION REFERENCE -- ALL 521 FUNCTIONS
; ========================================
;
; Naming convention: desktop_verbNoun for application functions
;                    prguf_verbNoun for PRGUF.RES thunks
;                    dmguf_verbNoun for DMGUF.RES thunks
;                    dos_verbNoun for DOS INT 21h wrappers
;                    bios_verbNoun for BIOS INT wrappers
;                    msc_verbNoun for MSC runtime functions
;                    dm_verbNoun for INT E0h DeskMate API calls
;
; ===========================================================================

; ===========================================================================
; ICON GRID / DESKTOP LAYOUT SUBSYSTEM (0x00010 - 0x008EA)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_drawDesktopPanel
; Address: 0x00010 (28 insns)
; Called by: desktop_buildIconGrid, desktop_buildFilePanel
; Params: [bp+4] = panel X position, [bp+6] = panel Y position
;         [bp+8] = panel flags (bit 1 = show tree area)
; Returns: void
; Description: Top-level desktop panel drawing function. Sets up the window
;   frame coordinates, draws the background, reads icon label data from
;   the configuration, and renders the icon label text. Calls
;   desktop_drawBackground, desktop_readIconLabels, desktop_drawIconGrid,
;   and desktop_endIconDraw.
; ---------------------------------------------------------------------------
; /* address: 0000:0010 */
desktop_drawDesktopPanel:                       ; was sub_00010
  push     bp
  mov      bp, sp
  sub      sp, 0x78
  mov      ax, 0x604                            ; icon area height constant
  push     ax
  push     word ptr [bp + 6]                    ; Y position
  push     word ptr [bp + 4]                    ; X position
  call     desktop_setWindowFrame               ; -> sub_003F8
  add      sp, 6
  mov      al, byte ptr [bp + 8]               ; flags
  cwde
  push     ax
  call     desktop_drawBackground               ; -> sub_000BE
  add      sp, 2
  lea      ax, [bp - 0x78]                     ; local buffer for icon labels
  push     ax
  call     desktop_readIconLabels               ; -> sub_001EE
  add      sp, 2
  inc      ax
  je       .skip_draw_labels                   ; returns -1 on failure
  lea      ax, [bp - 0x78]
  push     ax
  call     desktop_drawIconLabelBlock            ; -> sub_0004F
  add      sp, 2
.skip_draw_labels:
  call     desktop_endIconDraw                   ; -> sub_0041B
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_drawIconLabelBlock
; Address: 0x0004F (51 insns)
; Called by: desktop_drawDesktopPanel
; Description: Iterates through 4 icon slots, positioning the cursor and
;   drawing the icon name (0x12=18 bytes) and extension (8 bytes) for each.
;   Uses prguf_moveTo and prguf_drawTextLen to render text at grid positions.
;   The icon label data comes from a DMGUF config section.
; ---------------------------------------------------------------------------
; /* address: 0000:004F */
desktop_drawIconLabelBlock:                     ; was sub_0004F
  push     bp
  mov      bp, sp
  sub      sp, 2
  push     di
  push     si
  mov      si, word ptr [bp + 4]               ; pointer to label data
  sub      ax, ax
  push     ax
  mov      ax, 2
  push     ax
  call     prguf_setBgColor                     ; -> sub_0E02B
  add      sp, 4
  cmp      byte ptr [si], 0                    ; empty label block?
  jne      .draw_loop_start
  sub      ax, ax
  jmp      .done
.draw_loop_start:
  sub      di, di                              ; di = icon index (0..3)
.draw_loop:
  mov      bx, di
  shl      bx, 1
  push     word ptr [bx + 0x42]                ; Y position from icon table
  mov      ax, 0xc8                            ; X position constant
  push     ax
  call     prguf_moveTo                         ; -> sub_0E013
  add      sp, 4
  mov      ax, 0x12                            ; 18 chars for icon name
  push     ax
  push     si
  call     prguf_drawTextLen                    ; -> sub_0E043
  add      sp, 4
  add      si, 0x12                            ; advance past name
  mov      bx, di
  shl      bx, 1
  push     word ptr [bx + 0x42]                ; Y position
  mov      ax, 0x834                           ; X position for extension
  push     ax
  call     prguf_moveTo                         ; -> sub_0E013
  add      sp, 4
  mov      ax, 8                               ; 8 chars for extension
  push     ax
  push     si
  call     prguf_drawTextLen                    ; -> sub_0E043
  add      sp, 4
  add      si, 8                               ; advance past extension
  inc      di
  cmp      di, 4                               ; 4 icons per panel
  jl       .draw_loop
.done:
  pop      si
  pop      di
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_drawBackground
; Address: 0x000BE (140 insns)
; Called by: desktop_drawDesktopPanel
; Description: Draws the desktop background including title bar area,
;   grid lines, and icon placeholders. Sets up colors, draws rectangles
;   for the icon grid cells, and draws divider lines. Handles both
;   single-panel mode (flag bit 0) and tree+files mode (flag bit 1).
;   Uses PRGUF drawing primitives extensively.
; ---------------------------------------------------------------------------
; /* address: 0000:00BE */
desktop_drawBackground:                         ; was sub_000BE
  push     bp
  mov      bp, sp
  sub      sp, 4
  push     di
  push     si
  ; ... (140 instructions - draws grid lines, cell backgrounds)
  ; Sets colors via prguf_setBgColor, prguf_setTextColor
  ; Draws rectangles via prguf_drawRect for icon cells
  ; Draws child windows via prguf_createChildWindow for scroll areas
  ; If flag bit 1 set: draws tree panel separators
  pop      si
  pop      di
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_readIconLabels
; Address: 0x001EE (36 insns)
; Called by: desktop_drawDesktopPanel
; Description: Reads icon label text from the DESKTOP.CFG configuration file
;   via DMGUF. Sets up a config read descriptor pointing to section names
;   at 0x31DC/0x31E8/0x31F1, calls dmguf_readCfgSection, then copies the
;   returned data into the provided buffer via far pointer.
; Returns: -1 on failure, 0 on success.
; ---------------------------------------------------------------------------
; /* address: 0000:01EE */
desktop_readIconLabels:                         ; was sub_001EE
  push     bp
  mov      bp, sp
  sub      sp, 0x16
  push     di
  push     si
  mov      word ptr [bp - 0xe], 0x31dc         ; "DESKTOP.CFG" section name
  mov      word ptr [bp - 0xc], 0x31e8         ; config key name
  mov      byte ptr [bp - 0xa], 3              ; data type = string
  mov      word ptr [bp - 9], 0x31f1           ; default value
  lea      ax, [bp - 0xe]
  push     ax
  call     dmguf_readCfgSection                 ; -> sub_0DD0F
  add      sp, 2
  mov      di, ax                              ; handle or result
  cmp      di, -1
  jne      .read_ok
  mov      ax, 0xffff                          ; return -1 = failure
  jmp      .done
.read_ok:
  ; Copy far pointer data into caller's buffer
  mov      ax, word ptr [bp - 7]
  mov      dx, word ptr [bp - 5]
  mov      word ptr [bp - 0x12], ax
  mov      word ptr [bp - 0x10], dx
  sub      si, si
  jmp      .copy_check
.copy_loop:
  les      bx, ptr [bp - 0x12]
  mov      al, byte ptr es:[bx + si]
  mov      bx, word ptr [bp + 4]
  mov      byte ptr [bx + si], al
  inc      si
.copy_check:
  cmp      word ptr [bp - 3], si
  jg       .copy_loop
.done:
  pop      si
  pop      di
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_buildFilePanel
; Address: 0x00246 (76 insns)
; Called by: desktop_buildIconGrid, desktop_buildFilePanel_alt
; Description: Builds the file list panel view. Similar to drawDesktopPanel
;   but uses a different layout constant (0x37 vs 0x1C for row height) and
;   draws the file column headers. Handles tree panel visibility toggle.
;   If flag bit 1 set, calls desktop_readTreeLabels first.
; ---------------------------------------------------------------------------
; /* address: 0000:0246 */
desktop_buildFilePanel:                         ; was sub_00246
  push     bp
  mov      bp, sp
  ; ... (76 instructions)
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_readTreeLabels
; Address: 0x002F7 (36 insns)
; Called by: desktop_buildFilePanel
; Description: Reads tree structure labels from DESKTOP.CFG. Similar to
;   desktop_readIconLabels but reads from a different config section.
;   Stores result into the global tree label buffer at 0x5F5A.
; ---------------------------------------------------------------------------
; /* address: 0000:02F7 */
desktop_readTreeLabels:                         ; was sub_002F7
  push     bp
  mov      bp, sp
  sub      sp, 0x16
  push     di
  push     si
  mov      byte ptr [0x5f5a], 0                ; clear tree label buffer
  ; ... reads from config sections 0x31F9/0x3205/0x320E
  call     dmguf_readCfgSection                 ; -> sub_0DD0F
  ; ... copies far pointer data to 0x5F5A buffer
  pop      si
  pop      di
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_drawTreeLabels
; Address: 0x00352 (66 insns)
; Called by: desktop_buildFilePanel
; Description: Renders tree structure labels onto the desktop panel. Word-wraps
;   text at 0x1D (29) character boundaries, splitting on spaces. Renders
;   up to 5 lines of text using prguf_moveTo and prguf_drawText.
;   Line spacing is 0xDC (220) units, starting at Y offset 0x64.
; ---------------------------------------------------------------------------
; /* address: 0000:0352 */
desktop_drawTreeLabels:                         ; was sub_00352
  push     bp
  mov      bp, sp
  sub      sp, 0x26
  push     di
  push     si
  ; ... (66 instructions - text word-wrap and render)
  pop      si
  pop      di
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_setWindowFrame
; Address: 0x003F8 (13 insns)
; Called by: desktop_drawDesktopPanel, desktop_buildFilePanel,
;           desktop_drawIconArea
; Description: Stores window frame coordinates into global variables at
;   0x5E74-0x5E7A. Sets X, Y, width (fixed 0xBB8 = 3000), and height.
;   Then calls desktop_applyWindowFrame to configure the PRGUF rendering
;   surface.
; ---------------------------------------------------------------------------
; /* address: 0000:03F8 */
desktop_setWindowFrame:                         ; was sub_003F8
  push     bp
  mov      bp, sp
  call     prguf_beginPaint
  mov      ax, word ptr [bp + 4]               ; X position
  mov      word ptr [0x5e74], ax
  mov      ax, word ptr [bp + 6]               ; Y position
  mov      word ptr [0x5e76], ax
  mov      word ptr [0x5e78], 0xbb8            ; width = 3000
  mov      ax, word ptr [bp + 8]               ; height
  mov      word ptr [0x5e7a], ax
  call     desktop_applyWindowFrame              ; -> sub_008B9
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_endIconDraw
; Address: 0x0041B (3 insns)
; Called by: desktop_drawDesktopPanel, desktop_buildFilePanel
; Description: Finalizes icon drawing by restoring the PRGUF rendering state.
;   Calls desktop_restoreWindowFrame then prguf_endPaint.
; ---------------------------------------------------------------------------
; /* address: 0000:041B */
desktop_endIconDraw:                            ; was sub_0041B
  call     desktop_restoreWindowFrame            ; -> sub_008D4
  call     prguf_endPaint                        ; -> sub_0DF77
  ret

; ---------------------------------------------------------------------------
; desktop_drawTitleBar
; Address: 0x00422 (35 insns)
; Called by: desktop_drawBackground, desktop_buildFilePanel
; Description: Draws the desktop title bar at the top of the panel. Sets
;   background color, line style, draws a filled rectangle for the title
;   area, then draws a separator window.
; ---------------------------------------------------------------------------
; /* address: 0000:0422 */
desktop_drawTitleBar:                           ; was sub_00422
  ; ... (35 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setHeaderColors
; Address: 0x0046C (28 insns)
; Called by: desktop_drawBackground, desktop_buildFilePanel,
;           desktop_drawIconArea
; Description: Sets text and background colors for the panel header based
;   on the flags parameter. If flag bit 0 is set: inverted colors (selected).
;   Otherwise: normal header colors.
; ---------------------------------------------------------------------------
; /* address: 0000:046C */
desktop_setHeaderColors:                        ; was sub_0046C
  push     bp
  mov      bp, sp
  test     byte ptr [bp + 4], 1                ; check selection flag
  je       .normal_colors
  ; inverted: push 8, call prguf_setTextColor, set bg color 0/2
  pop      bp
  ret
.normal_colors:
  ; normal: push 3, push 2, call prguf_setBgColor, set text color 0
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_drawIconArea
; Address: 0x004A7 (120 insns)
; Called by: desktop_buildIconGrid, desktop_buildFilePanel_alt
; Description: Draws the main icon area including the icon grid frame, program
;   launch text, scrollbar area. Sets window frame with height 0x63B,
;   draws child windows and grid separators. If flag bit 1 set (tree visible),
;   reads drive info and draws additional panel structure.
; ---------------------------------------------------------------------------
; /* address: 0000:04A7 */
desktop_drawIconArea:                           ; was sub_004A7
  push     bp
  mov      bp, sp
  sub      sp, 6
  push     di
  push     si
  ; ... (120 instructions)
  pop      si
  pop      di
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_drawIconGrid
; Address: 0x005C9 (165 insns)
; Called by: desktop_drawIconArea
; Description: Draws the individual icon cells in the grid. Each cell contains
;   an icon bitmap and a text label. Iterates through the icon data structure,
;   drawing borders, backgrounds, and text for each icon. Handles icon
;   selection highlighting and the cursor position within the grid.
;   Uses prguf_drawBorder, prguf_drawRect, prguf_drawText, prguf_moveTo.
; ---------------------------------------------------------------------------
; /* address: 0000:05C9 */
desktop_drawIconGrid:                           ; was sub_005C9
  push     bp
  mov      bp, sp
  ; ... (165 instructions)
  pop      si
  pop      di
  mov      sp, bp
  pop      bp
  ret

; ---------------------------------------------------------------------------
; desktop_getDriveLabel
; Address: 0x00770 (12 insns)
; Called by: desktop_drawIconArea
; Description: Gets the current drive label text by calling sub_0D540 which
;   reads the drive name via DOS.
; ---------------------------------------------------------------------------
; /* address: 0000:0770 */
desktop_getDriveLabel:                          ; was sub_00770
  ; ... (12 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawIconBitmap
; Address: 0x0078F (64 insns)
; Called by: desktop_drawIconGrid
; Description: Draws a single icon bitmap at the specified grid position.
;   The icon data format is a fixed-size bitmap block.
; ---------------------------------------------------------------------------
; /* address: 0000:078F */
desktop_drawIconBitmap:                         ; was sub_0078F
  ; ... (64 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawIconLabel
; Address: 0x00815 (20 insns)
; Called by: desktop_drawIconGrid
; Description: Draws the text label underneath an icon. Positions cursor
;   with prguf_moveTo and renders with prguf_drawTextLen.
; ---------------------------------------------------------------------------
; /* address: 0000:0815 */
desktop_drawIconLabel:                          ; was sub_00815
  ; ... (20 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawIconBorder
; Address: 0x0083A (37 insns)
; Called by: desktop_drawIconGrid, desktop_drawIconBorder (recursive)
; Description: Draws a decorative border around an icon cell. Recursive:
;   draws inner and outer borders for a 3D appearance.
;   Uses prguf_drawBorder.
; ---------------------------------------------------------------------------
; /* address: 0000:083A */
desktop_drawIconBorder:                         ; was sub_0083A
  ; ... (37 instructions - recursive border draw)
  ret

; ---------------------------------------------------------------------------
; desktop_fillIconBackground
; Address: 0x00889 (14 insns)
; Called by: desktop_drawIconGrid
; Description: Fills the background area of an icon cell.
; ---------------------------------------------------------------------------
; /* address: 0000:0889 */
desktop_fillIconBackground:                     ; was sub_00889
  ; ... (14 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_applyWindowFrame
; Address: 0x008B9 (11 insns)
; Called by: desktop_setWindowFrame
; Description: Applies the stored window frame coordinates (0x5E74-0x5E7A)
;   to the PRGUF rendering surface. Calls prguf_setWindowTitle,
;   prguf_setWindowAttr, prguf_getWindowAttr (chain of PRGUF configuration).
; ---------------------------------------------------------------------------
; /* address: 0000:08B9 */
desktop_applyWindowFrame:                       ; was sub_008B9
  ; ... (11 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_restoreWindowFrame
; Address: 0x008D4 (7 insns)
; Called by: desktop_endIconDraw, desktop_drawIconArea
; Description: Restores the previous window frame state after icon drawing.
;   Calls prguf_setWindowAttr and prguf_setWindowFlag.
; ---------------------------------------------------------------------------
; /* address: 0000:08D4 */
desktop_restoreWindowFrame:                     ; was sub_008D4
  ; ... (7 instructions)
  ret

; ===========================================================================
; ICON INTERACTION SUBSYSTEM (0x008EA - 0x00DA8)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleIconClick
; Address: 0x008EA (66 insns)
; Called by: desktop_handleMenuDef, desktop_handleDirChange,
;           desktop_handleMenuAction, desktop_handleInstall, desktop_launchApp
; Description: Handles a click/selection event on a desktop icon. Determines
;   which icon was clicked based on grid coordinates, updates the selection
;   state, and triggers the appropriate action (launch app, show menu, etc.).
;   Calls desktop_buildIconGrid, desktop_findIconAt, desktop_renderIcon,
;   desktop_drawMenuBar.
; ---------------------------------------------------------------------------
; /* address: 0000:08EA */
desktop_handleIconClick:                        ; was sub_008EA
  ; ... (66 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleIconDblClick
; Address: 0x00987 (72 insns)
; Called by: desktop_launchApp
; Description: Handles a double-click on a desktop icon. Attempts to launch
;   the associated program. Calls desktop_buildIconGrid, desktop_renderIcon,
;   desktop_getIconProgram, and related functions.
; ---------------------------------------------------------------------------
; /* address: 0000:0987 */
desktop_handleIconDblClick:                     ; was sub_00987
  ; ... (72 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_buildIconGrid
; Address: 0x00A3D (92 insns)
; Called by: desktop_handleIconClick, desktop_handleIconDblClick
; Description: Builds/rebuilds the icon grid data structure. Reads icon
;   definitions from the config, allocates display buffers, and sets up
;   the grid layout. Core function for icon management.
; ---------------------------------------------------------------------------
; /* address: 0000:0A3D */
desktop_buildIconGrid:                          ; was sub_00A3D
  ; ... (92 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_findIconAt
; Address: 0x00B14 (54 insns)
; Called by: desktop_handleIconClick
; Description: Finds which icon (if any) is at the given grid coordinates.
;   Searches the icon data array and returns the icon index or -1.
; ---------------------------------------------------------------------------
; /* address: 0000:0B14 */
desktop_findIconAt:                             ; was sub_00B14
  ; ... (54 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_updateIconState
; Address: 0x00B90 (57 insns)
; Called by: desktop_repaintIcons, desktop_handleMenuDef, desktop_handleDirExit,
;           desktop_handleDirChange, desktop_initDrive
; Description: Updates the visual state of an icon after a state change
;   (selection, deselection, rename). Redraws the icon at its grid position.
; ---------------------------------------------------------------------------
; /* address: 0000:0B90 */
desktop_updateIconState:                        ; was sub_00B90
  ; ... (57 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_repaintIcons
; Address: 0x00C27 (13 insns)
; Called by: desktop_handleFormatDisk
; Description: Repaints all icons after a disk format or similar operation
;   that may have changed file status.
; ---------------------------------------------------------------------------
; /* address: 0000:0C27 */
desktop_repaintIcons:                           ; was sub_00C27
  ; ... (13 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_clearIconArea
; Address: 0x00C45 (65 insns)
; Called by: desktop_buildIconGrid, desktop_findIconAt, desktop_updateIconState,
;           desktop_buildFilePanel_alt, desktop_renderIcon, desktop_drawMenuBar,
;           desktop_setMenuFocus
; Description: Clears the icon drawing area, preparing it for a redraw.
;   Uses prguf_allocBuffer, prguf_clearBuffer.
; ---------------------------------------------------------------------------
; /* address: 0000:0C45 */
desktop_clearIconArea:                          ; was sub_00C45
  ; ... (65 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_buildFilePanel_alt
; Address: 0x00CE5 (84 insns)
; Called by: desktop_handleViewSwitch, desktop_handleMenuCommand
; Description: Alternative file panel builder called during view switches.
;   Similar to desktop_buildFilePanel but handles the transition state
;   (from icon view to file list view or vice versa).
; ---------------------------------------------------------------------------
; /* address: 0000:0CE5 */
desktop_buildFilePanel_alt:                     ; was sub_00CE5
  ; ... (84 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderIcon
; Address: 0x00DA8 (260 insns)
; Called by: desktop_handleIconClick, desktop_handleIconDblClick,
;           desktop_buildIconGrid, desktop_buildFilePanel_alt
; Description: Main icon rendering function. Draws a complete icon including
;   bitmap, label, selection highlight, and drag handle. This is one of the
;   larger functions (260 insns) because it handles all icon display states:
;   normal, selected, dragging, disabled.
;   Uses extensive PRGUF calls: prguf_moveTo, prguf_drawText, prguf_drawRect,
;   prguf_setTextColor, prguf_setBgColor, prguf_setLineStyle.
; ---------------------------------------------------------------------------
; /* address: 0000:0DA8 */
desktop_renderIcon:                             ; was sub_00DA8
  ; ... (260 instructions)
  ret

; ===========================================================================
; ICON DATA / CONFIG I/O SUBSYSTEM (0x00DA8 - 0x01403)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_getIconProgram
; Address: 0x0107A (35 insns)
; Called by: desktop_handleIconDblClick, desktop_findIconAt
; Description: Retrieves the program name (.PDM filename) associated with
;   an icon index. Looks up the icon data structure.
; ---------------------------------------------------------------------------
; /* address: 0000:107A */
desktop_getIconProgram:                         ; was sub_0107A
  ; ... (35 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setModuleInfo
; Address: 0x010CE (14 insns)
; Called by: desktop_initStartup
; Description: Stores module identification data during startup.
; ---------------------------------------------------------------------------
; /* address: 0000:10CE */
desktop_setModuleInfo:                          ; was sub_010CE
  ; ... (14 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getMenuItemCount
; Address: 0x010F4 (29 insns)
; Called by: desktop_handleMenuCreate, desktop_handleMenuDef,
;           desktop_loadConfig, desktop_handleMenuRedefine
; Description: Gets the count of menu items in the current menu definition.
;   Calls msc_strlen (sub_0D744).
; ---------------------------------------------------------------------------
; /* address: 0000:10F4 */
desktop_getMenuItemCount:                       ; was sub_010F4
  ; ... (29 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_validateMenuTitle
; Address: 0x01132 (11 insns)
; Called by: desktop_repaintIcons, desktop_handleMenuCreate, desktop_loadConfig
; Description: Validates a menu title string for illegal characters.
; ---------------------------------------------------------------------------
; /* address: 0000:1132 */
desktop_validateMenuTitle:                      ; was sub_01132
  ; ... (11 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setAppInfo
; Address: 0x0114B (27 insns)
; Called by: desktop_handleMenuCommand, desktop_handleMenuOp,
;           desktop_setMenuFocus, desktop_setMenuFocusAlt
; Description: Sets application information for the currently selected icon
;   or menu item.
; ---------------------------------------------------------------------------
; /* address: 0000:114B */
desktop_setAppInfo:                             ; was sub_0114B
  ; ... (27 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getConfigValue
; Address: 0x01183 (32 insns)
; Called by: desktop_handleMenuDef, desktop_handleMenuRedefine,
;           desktop_loadConfig, desktop_handleMenuRedefine_alt
; Description: Reads a specific value from the DESKTOP.CFG configuration.
;   Calls dmguf_getCfgString (sub_0D47C).
; ---------------------------------------------------------------------------
; /* address: 0000:1183 */
desktop_getConfigValue:                         ; was sub_01183
  ; ... (32 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_checkConfigFlag
; Address: 0x011C7 (10 insns)
; Called by: desktop_handleMenuDef, desktop_loadConfig
; Description: Checks a boolean flag in the configuration data.
; ---------------------------------------------------------------------------
; /* address: 0000:11C7 */
desktop_checkConfigFlag:                        ; was sub_011C7
  ; ... (10 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getConfigString
; Address: 0x011D9 (25 insns)
; Called by: desktop_setConfigString, desktop_loadConfig
; Description: Reads a string value from config into a buffer.
; ---------------------------------------------------------------------------
; /* address: 0000:11D9 */
desktop_getConfigString:                        ; was sub_011D9
  ; ... (25 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setConfigString
; Address: 0x01208 (34 insns)
; Called by: desktop_processMenuDef
; Description: Writes a string value to the config. Calls
;   desktop_getConfigString, desktop_validatePath, desktop_pathCompare.
; ---------------------------------------------------------------------------
; /* address: 0000:1208 */
desktop_setConfigString:                        ; was sub_01208
  ; ... (34 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_addMenuItem
; Address: 0x01255 (51 insns)
; Called by: desktop_processMenuDef
; Description: Adds a new menu item to the menu definition data structure.
;   Calls prguf_launchApp (sub_06FDA), msc_strcpy, msc_strlen.
; ---------------------------------------------------------------------------
; /* address: 0000:1255 */
desktop_addMenuItem:                            ; was sub_01255
  ; ... (51 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_validatePath
; Address: 0x012C6 (16 insns)
; Called by: desktop_setConfigString, desktop_addMenuItem
; Description: Validates that a path string is well-formed.
; ---------------------------------------------------------------------------
; /* address: 0000:12C6 */
desktop_validatePath:                           ; was sub_012C6
  ; ... (16 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_readMenuConfig
; Address: 0x012E5 (78 insns)
; Called by: desktop_writeConfigSection
; Description: Reads menu configuration data from the DESKTOP.CFG file.
;   Parses the menu definition entries (title, program, data file, etc.).
; ---------------------------------------------------------------------------
; /* address: 0000:12E5 */
desktop_readMenuConfig:                         ; was sub_012E5
  ; ... (78 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_parseMenuEntry
; Address: 0x013A1 (44 insns)
; Called by: desktop_readMenuConfig
; Description: Parses a single menu entry from config data. Reads the menu
;   title, program name, extension, and directory fields.
; ---------------------------------------------------------------------------
; /* address: 0000:13A1 */
desktop_parseMenuEntry:                         ; was sub_013A1
  ; ... (44 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_writeMenuEntry
; Address: 0x01403 (28 insns)
; Called by: desktop_readMenuConfig
; Description: Writes a menu entry back to the config data structure.
; ---------------------------------------------------------------------------
; /* address: 0000:1403 */
desktop_writeMenuEntry:                         ; was sub_01403
  ; ... (28 instructions)
  ret

; ===========================================================================
; MENU DEFINITION ENGINE (0x0143E - 0x01BDA)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleMenuCreate
; Address: 0x0143E (61 insns)
; Called by: (no callers recorded -- top-level menu handler)
; Description: Handles the "Create Menu" dialog. Shows the menu creation
;   dialog box where the user enters a menu title, program name, data file
;   extension, startup directory, and CPU clock speed. Validates input
;   and creates the menu definition.
;   Related strings: "Create Menu", "Menu title:", "Program name:",
;   "Data file extension:", "Start-up directory:", "CPU clock speed:"
; ---------------------------------------------------------------------------
; /* address: 0000:143E */
desktop_handleMenuCreate:                       ; was sub_0143E
  ; ... (61 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuDef
; Address: 0x014DB (128 insns)
; Called by: (no callers recorded -- top-level menu handler)
; Description: Handles menu definition operations (create, modify, delete).
;   Dispatches based on the menu item selected. Larger handler that manages
;   the full menu definition workflow.
; ---------------------------------------------------------------------------
; /* address: 0000:14DB */
desktop_handleMenuDef:                          ; was sub_014DB
  ; ... (128 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_readMenuTitle
; Address: 0x01620 (79 insns)
; Called by: desktop_handleMenuDef, desktop_handleInstall
; Description: Reads and validates a menu title from user input or config.
; ---------------------------------------------------------------------------
; /* address: 0000:1620 */
desktop_readMenuTitle:                          ; was sub_01620
  ; ... (79 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_formatMenuTitle
; Address: 0x016E9 (40 insns)
; Called by: desktop_readMenuTitle, desktop_handleMenuAction
; Description: Formats a menu title string (trims, uppercases, validates).
; ---------------------------------------------------------------------------
; /* address: 0000:16E9 */
desktop_formatMenuTitle:                        ; was sub_016E9
  ; ... (40 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_processMenuDef
; Address: 0x01743 (314 insns)
; Called by: desktop_handleMenuCreate, desktop_handleMenuDef,
;           desktop_handleMenuRedefine
; Description: Core menu definition processor. This is the 4th largest
;   function (314 insns). Handles the complete menu definition workflow:
;   validates title, program name, data extension, directory; checks for
;   duplicate titles; creates or modifies the menu entry; updates the
;   config file. Shows error dialogs for invalid input.
;   Related error strings: "Menu must be given a title",
;   "Invalid data file extension", "Invalid program name",
;   "Duplicate menu title"
; ---------------------------------------------------------------------------
; /* address: 0000:1743 */
desktop_processMenuDef:                         ; was sub_01743
  ; ... (314 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuRedefine
; Address: 0x01AA2 (120 insns)
; Called by: desktop_processMenuDef
; Description: Handles the "Redefine Menu" operation. Loads existing menu
;   definition, allows user to modify it, saves changes. Checks for
;   valid program names and handles special app types (learn, month, etc.).
; ---------------------------------------------------------------------------
; /* address: 0000:1AA2 */
desktop_handleMenuRedefine:                     ; was sub_01AA2
  ; ... (120 instructions)
  ret

; ===========================================================================
; FORMAT / DISKCOPY SUBSYSTEM (0x01BDA - 0x02428)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleFormatDisk
; Address: 0x01BDA (148 insns)
; Called by: (no callers recorded -- top-level menu handler)
; Description: Handles the "Format Disk" operation. Shows the format dialog
;   with drive selection, density options, volume label, and install OS
;   checkbox. Detects disk types (3.5"/5.25", HD/DD) and constructs
;   FORMAT.COM command line arguments.
;   Related strings: "Format Disk", "Drive:", "Install operating system",
;   "Options:", "High Density", "Double Sided", "Volume Label",
;   "3.5 ", "5.25", "1.2 ", "1.44"
;   Calls: bios_resetDisk, desktop_getDiskCapacity, FORMAT.COM execution
; ---------------------------------------------------------------------------
; /* address: 0000:1BDA */
desktop_handleFormatDisk:                       ; was sub_01BDA
  ; ... (148 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDirExit
; Address: 0x01D4D (29 insns)
; Called by: desktop_handleFormatDisk, desktop_handleInstall
; Description: Handles cleanup when exiting a directory operation context.
; ---------------------------------------------------------------------------
; /* address: 0000:1D4D */
desktop_handleDirExit:                          ; was sub_01D4D
  ; ... (29 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDirChange
; Address: 0x01D94 (55 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the "Change Directory" operation.
;   Shows the change directory dialog and processes the path input.
; ---------------------------------------------------------------------------
; /* address: 0000:1D94 */
desktop_handleDirChange:                        ; was sub_01D94
  ; ... (55 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuAction
; Address: 0x01E18 (231 insns)
; Called by: desktop_handleMenuCreate, desktop_handleInstall,
;           desktop_handleRunFile
; Description: Handles a menu action (launching a program from a menu
;   definition). Validates the program path, checks for non-DeskMate
;   programs, and initiates the launch sequence. Shows error dialogs
;   for invalid configurations.
;   Related strings: "You cannot run two non-DeskMate programs simultaneously"
; ---------------------------------------------------------------------------
; /* address: 0000:1E18 */
desktop_handleMenuAction:                       ; was sub_01E18
  ; ... (231 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_validateProgramFile
; Address: 0x02074 (122 insns)
; Called by: desktop_handleMenuAction
; Description: Validates that a program file exists and is a valid PDM or
;   executable. Checks file extension, existence, and compatibility.
; ---------------------------------------------------------------------------
; /* address: 0000:2074 */
desktop_validateProgramFile:                    ; was sub_02074
  ; ... (122 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleInstall
; Address: 0x021A2 (143 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the "Install" menu operation. Allows installing a new
;   application from a floppy disk. Shows the install dialog, detects
;   available .PDM files, creates a menu entry, and copies files.
;   Related strings: "Install", "Please replace the disk containing the
;   application you wish to install", "New application was not added..."
; ---------------------------------------------------------------------------
; /* address: 0000:21A2 */
desktop_handleInstall:                          ; was sub_021A2
  ; ... (143 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleSaveConfig
; Address: 0x0230B (120 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Saves the current desktop configuration to DESKTOP.CFG.
;   Writes menu definitions, icon positions, view state, drive letter,
;   and other settings. Uses both DMGUF config write and DeskMate INT E0h
;   file I/O.
;   Related strings: "Creating configuration file"
; ---------------------------------------------------------------------------
; /* address: 0000:230B */
desktop_handleSaveConfig:                       ; was sub_0230B
  ; ... (120 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleRunFile
; Address: 0x02428 (63 insns)
; Called by: desktop_handleSaveConfig
; Description: Handles the "Run" file menu operation. Shows the Run dialog,
;   processes program name and data file inputs, checks CPU speed setting.
;   Related strings: "Run File", "Program:", "Data file:",
;   "CPU clock speed:", "Normal", "Fast"
; ---------------------------------------------------------------------------
; /* address: 0000:2428 */
desktop_handleRunFile:                          ; was sub_02428
  ; ... (63 instructions)
  ret

; ===========================================================================
; FILE COPY / CONFIG SAVE SUBSYSTEM (0x024BA - 0x030AB)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleDesktopMenu
; Address: 0x024BA (34 insns)
; Called by: desktop_buildIconGrid
; Description: Handles selections from the "Desktop" menu. Dispatches to
;   sub-handlers for Get Info, Run, Copy, Delete, Rename, etc.
; ---------------------------------------------------------------------------
; /* address: 0000:24BA */
desktop_handleDesktopMenu:                      ; was sub_024BA
  ; ... (34 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleGetInfo
; Address: 0x0250A (121 insns)
; Called by: desktop_handleDesktopMenu
; Description: Shows the "File Info" dialog. Displays filename, size, date
;   modified. Uses PRGUF dialog primitives.
;   Related strings: "File Info", "Filename:", "Size:", "Bytes", "Modified:"
; ---------------------------------------------------------------------------
; /* address: 0000:250A */
desktop_handleGetInfo:                          ; was sub_0250A
  ; ... (121 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleVolumeLabel
; Address: 0x0261A (42 insns)
; Called by: desktop_handleDesktopMenu
; Description: Gets and displays the volume label for the current drive.
;   Calls sub_0D540 (DOS get volume info) and dmguf_getVolumeName.
; ---------------------------------------------------------------------------
; /* address: 0000:261A */
desktop_handleVolumeLabel:                      ; was sub_0261A
  ; ... (42 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleExit
; Address: 0x02682 (39 insns)
; Called by: desktop_handleDesktopMenu
; Description: Handles the "Exit" menu item. Reads the exit confirmation
;   prompt from config.
;   Related strings: "DeskMate", "Press Enter to confirm exit."
; ---------------------------------------------------------------------------
; /* address: 0000:2682 */
desktop_handleExit:                             ; was sub_02682
  ; ... (39 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleAbout
; Address: 0x026E5 (175 insns)
; Called by: desktop_handleDesktopMenu
; Description: Handles the "About..." menu item. Displays the About dialog
;   showing DeskMate version, copyright, and loaded resource module versions.
;   Related strings: "About", "Version 3.68", "DeskMate Copyright 1984, 1990",
;   "Tandy Corporation, All Rights Reserved"
; ---------------------------------------------------------------------------
; /* address: 0000:26E5 */
desktop_handleAbout:                            ; was sub_026E5
  ; ... (175 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_buildAboutText
; Address: 0x028A8 (42 insns)
; Called by: desktop_handleAbout
; Description: Builds the text content for the About dialog box.
; ---------------------------------------------------------------------------
; /* address: 0000:28A8 */
desktop_buildAboutText:                         ; was sub_028A8
  ; ... (42 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_formatVersion
; Address: 0x02909 (43 insns)
; Called by: desktop_buildAboutText
; Description: Formats a version number string (e.g., "3.68").
; ---------------------------------------------------------------------------
; /* address: 0000:2909 */
desktop_formatVersion:                          ; was sub_02909
  ; ... (43 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getAboutResource
; Address: 0x0296A (30 insns)
; Called by: desktop_buildAboutText
; Description: Gets resource module name for About dialog display.
; ---------------------------------------------------------------------------
; /* address: 0000:296A */
desktop_getAboutResource:                       ; was sub_0296A
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleUpdateScreen
; Address: 0x029AC (79 insns)
; Called by: desktop_buildFilePanel_alt
; Description: Handles "Update Screen" (Ctrl+U). Redraws the entire desktop
;   with fresh data. Used after external file operations.
; ---------------------------------------------------------------------------
; /* address: 0000:29AC */
desktop_handleUpdateScreen:                     ; was sub_029AC
  ; ... (79 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_readTreeConfig
; Address: 0x02A6E (31 insns)
; Called by: desktop_readDesktopConfig
; Description: Reads directory tree configuration data from DESKTOP.CFG.
; ---------------------------------------------------------------------------
; /* address: 0000:2A6E */
desktop_readTreeConfig:                         ; was sub_02A6E
  ; ... (31 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_writeTreeConfig
; Address: 0x02AB7 (24 insns)
; Called by: (no callers recorded -- standalone handler)
; Description: Writes directory tree state to DESKTOP.CFG.
; ---------------------------------------------------------------------------
; /* address: 0000:2AB7 */
desktop_writeTreeConfig:                        ; was sub_02AB7
  ; ... (24 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_readDesktopConfig
; Address: 0x02AEE (41 insns)
; Called by: desktop_initStartup
; Description: Reads the full desktop configuration from DESKTOP.CFG.
;   Reads tree state, resource settings, cursor state.
; ---------------------------------------------------------------------------
; /* address: 0000:2AEE */
desktop_readDesktopConfig:                      ; was sub_02AEE
  ; ... (41 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleFileCopy
; Address: 0x02B4E (187 insns)
; Called by: desktop_initStartup, desktop_handleCopyCommand
; Description: Core file copy engine. Handles single and multi-file copy
;   operations, including disk swap prompts for floppy-to-floppy copies.
;   Detects whether source and destination are on the same device, checks
;   free space, and performs the actual copy. Shows progress and error
;   dialogs.
;   Related strings: "Copy File", "Copy from:", "Copy to:",
;   "Put 'Copy from' diskette in drive", "Put 'Copy to' diskette in drive",
;   "Will not fit", "Error"
; ---------------------------------------------------------------------------
; /* address: 0000:2B4E */
desktop_handleFileCopy:                         ; was sub_02B4E
  ; ... (187 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_writeConfigSection
; Address: 0x02D4C (46 insns)
; Called by: desktop_handleFileCopy
; Description: Writes a section of config data during copy operations.
; ---------------------------------------------------------------------------
; /* address: 0000:2D4C */
desktop_writeConfigSection:                     ; was sub_02D4C
  ; ... (46 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_closeConfig
; Address: 0x02DCB (30 insns)
; Called by: desktop_handleFileCopy, desktop_initStartup,
;           desktop_saveConfig
; Description: Closes an open configuration file handle.
; ---------------------------------------------------------------------------
; /* address: 0000:2DCB */
desktop_closeConfig:                            ; was sub_02DCB
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_checkConfigExists
; Address: 0x02E12 (30 insns)
; Called by: desktop_handleFileCopy, desktop_handleFileCopyCmd,
;           desktop_initStartup
; Description: Checks whether DESKTOP.CFG exists on the current drive.
; ---------------------------------------------------------------------------
; /* address: 0000:2E12 */
desktop_checkConfigExists:                      ; was sub_02E12
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_checkDiskReady
; Address: 0x02E58 (33 insns)
; Called by: desktop_handleFileCopyCmd
; Description: Checks if a disk is ready in the specified drive.
;   Calls bios_resetDisk, bios_readSector, dmguf_writeCfgSection.
; ---------------------------------------------------------------------------
; /* address: 0000:2E58 */
desktop_checkDiskReady:                         ; was sub_02E58
  ; ... (33 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_flushConfig
; Address: 0x02EB5 (4 insns)
; Called by: desktop_handleFileCopy, desktop_writeConfigSection
; Description: Flushes configuration data by calling sound shutdown,
;   config save, and config close functions.
; ---------------------------------------------------------------------------
; /* address: 0000:2EB5 */
desktop_flushConfig:                            ; was sub_02EB5
  ; ... (4 instructions)
  ret

; ===========================================================================
; DIRECTORY TREE / STATUS BAR DRAWING (0x02EC0 - 0x03B62)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_drawStatusBar
; Address: 0x02EC0 (123 insns)
; Called by: desktop_readMenuTitle, desktop_processMenuDef,
;           desktop_handleFormatDisk, desktop_handleMenuAction,
;           (+ 10 more callers)
; Description: Draws the status bar at the bottom of the desktop window.
;   Shows current drive, directory path, free space, and status messages.
;   This is one of the most heavily called functions (14 callers).
;   Related strings: " Current Drive: ", "No Label"
; ---------------------------------------------------------------------------
; /* address: 0000:2EC0 */
desktop_drawStatusBar:                          ; was sub_02EC0
  ; ... (123 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawFileHeader
; Address: 0x03022 (30 insns)
; Called by: desktop_processMenuDef, desktop_handleFormatDisk,
;           desktop_handleMenuAction, desktop_handleRunApp
; Description: Draws the file list column header line.
;   Related strings: "Filename Ext.   Size    Date     Time   Program"
; ---------------------------------------------------------------------------
; /* address: 0000:3022 */
desktop_drawFileHeader:                         ; was sub_03022
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawTreeHeader
; Address: 0x03061 (33 insns)
; Called by: desktop_processMenuDef, desktop_handleMenuAction,
;           desktop_handleFileSort
; Description: Draws the directory tree header area.
; ---------------------------------------------------------------------------
; /* address: 0000:3061 */
desktop_drawTreeHeader:                         ; was sub_03061
  ; ... (33 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getStatusBarWidth
; Address: 0x030AB (42 insns)
; Called by: desktop_drawStatusBar
; Description: Calculates the width of the status bar text area.
; ---------------------------------------------------------------------------
; /* address: 0000:30AB */
desktop_getStatusBarWidth:                      ; was sub_030AB
  ; ... (42 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawColumnLines
; Address: 0x03119 (30 insns)
; Called by: desktop_processMenuDef, desktop_drawStatusBar,
;           desktop_handleCreateDir, (+ 7 more)
; Description: Draws vertical column separator lines in the file list view.
; ---------------------------------------------------------------------------
; /* address: 0000:3119 */
desktop_drawColumnLines:                        ; was sub_03119
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawScrollbar
; Address: 0x0315F (35 insns)
; Called by: desktop_drawStatusBar
; Description: Draws the scrollbar in the file list panel.
; ---------------------------------------------------------------------------
; /* address: 0000:315F */
desktop_drawScrollbar:                          ; was sub_0315F
  ; ... (35 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getTreeDepth
; Address: 0x031B6 (71 insns)
; Called by: desktop_buildTreeView
; Description: Calculates the visual depth/nesting of the directory tree.
; ---------------------------------------------------------------------------
; /* address: 0000:31B6 */
desktop_getTreeDepth:                           ; was sub_031B6
  ; ... (71 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawTreeNode
; Address: 0x0325F (11 insns)
; Called by: desktop_processMenuDef, desktop_buildTreeView,
;           desktop_expandTreeNode
; Description: Draws a single tree node (directory name with indentation).
; ---------------------------------------------------------------------------
; /* address: 0000:325F */
desktop_drawTreeNode:                           ; was sub_0325F
  ; ... (11 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderTreeNode
; Address: 0x03277 (44 insns)
; Called by: desktop_drawTreeNode, desktop_refreshTreeView
; Description: Renders a tree node with its connecting lines and icon.
;   Handles expanded/collapsed state indicators.
; ---------------------------------------------------------------------------
; /* address: 0000:3277 */
desktop_renderTreeNode:                         ; was sub_03277
  ; ... (44 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_populateFileList
; Address: 0x032E6 (117 insns)
; Called by: desktop_renderTreeNode
; Description: Populates the file list for the current directory. Calls
;   dos_findFirst, dos_findNext to enumerate files, then sorts and
;   displays them.
; ---------------------------------------------------------------------------
; /* address: 0000:32E6 */
desktop_populateFileList:                       ; was sub_032E6
  ; ... (117 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_addFileEntry
; Address: 0x03409 (80 insns)
; Called by: desktop_populateFileList
; Description: Adds a single file entry to the display list. Formats the
;   filename, extension, size, date, and time fields.
; ---------------------------------------------------------------------------
; /* address: 0000:3409 */
desktop_addFileEntry:                           ; was sub_03409
  ; ... (80 instructions)
  ret

; ===========================================================================
; DIRECTORY OPERATIONS (0x03B62 - 0x040E2)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleCreateDir
; Address: 0x03B62 (148 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the "Create Directory" dialog. Prompts for path,
;   validates, calls DOS mkdir (INT 21h AH=39h).
;   Related strings: "Create Directory", "Path:"
; ---------------------------------------------------------------------------
; /* address: 0000:3B62 */
desktop_handleCreateDir:                        ; was sub_03B62
  ; ... (148 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDeleteDir
; Address: 0x03CD2 (112 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the "Delete Directory" dialog. Prompts for path,
;   validates, calls DOS rmdir (INT 21h AH=3Ah).
;   Related strings: "Delete Directory", "Path:",
;   "Cannot remove current or root directory",
;   "Directory is not empty or access is denied"
; ---------------------------------------------------------------------------
; /* address: 0000:3CD2 */
desktop_handleDeleteDir:                        ; was sub_03CD2
  ; ... (112 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleChangeDir
; Address: 0x03DEB (202 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the "Change Directory" dialog. Prompts for path,
;   validates, changes the current directory, refreshes the file display.
;   Related strings: "Change Directory", "Path:"
; ---------------------------------------------------------------------------
; /* address: 0000:3DEB */
desktop_handleChangeDir:                        ; was sub_03DEB
  ; ... (202 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDeleteDirConfirm
; Address: 0x03FE8 (106 insns)
; Called by: desktop_handleDeleteDir
; Description: Confirmation handler for directory deletion. Validates the
;   directory is empty and deletable, then performs the deletion.
; ---------------------------------------------------------------------------
; /* address: 0000:3FE8 */
desktop_handleDeleteDirConfirm:                 ; was sub_03FE8
  ; ... (106 instructions)
  ret

; ===========================================================================
; MENU SYSTEM / VIEW SWITCH (0x040E2 - 0x05848)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_initMenuView
; Address: 0x040E2 (70 insns)
; Called by: desktop_handleViewTree
; Description: Initializes the menu view (Ctrl+M). Sets up the menu list
;   display with available menu definitions.
; ---------------------------------------------------------------------------
; /* address: 0000:40E2 */
desktop_initMenuView:                           ; was sub_040E2
  ; ... (70 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_refreshTreeView
; Address: 0x04193 (61 insns)
; Called by: desktop_initMenuView, desktop_switchMenuView
; Description: Refreshes the directory tree view display.
; ---------------------------------------------------------------------------
; /* address: 0000:4193 */
desktop_refreshTreeView:                        ; was sub_04193
  ; ... (61 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setViewState
; Address: 0x04224 (36 insns)
; Called by: desktop_handleViewTree, desktop_switchMenuView
; Description: Sets the current view state (menus, tree, files).
; ---------------------------------------------------------------------------
; /* address: 0000:4224 */
desktop_setViewState:                           ; was sub_04224
  ; ... (36 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawMenuList
; Address: 0x04288 (58 insns)
; Called by: desktop_initMenuView, desktop_switchMenuView
; Description: Draws the list of available menus in the menu view.
;   Uses prguf_drawLine, prguf_setLineStyle, prguf_setIconPos.
; ---------------------------------------------------------------------------
; /* address: 0000:4288 */
desktop_drawMenuList:                           ; was sub_04288
  ; ... (58 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setMenuCursor
; Address: 0x04311 (13 insns)
; Called by: desktop_handleViewTree, desktop_switchMenuView
; Description: Sets the cursor position in the menu list.
; ---------------------------------------------------------------------------
; /* address: 0000:4311 */
desktop_setMenuCursor:                          ; was sub_04311
  ; ... (13 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuSelect
; Address: 0x04330 (196 insns)
; Called by: desktop_handleViewTree
; Description: Handles selection of a menu item in the menu view.
;   Processes keyboard input (Enter, arrows, Escape) to navigate and
;   activate menu items.
; ---------------------------------------------------------------------------
; /* address: 0000:4330 */
desktop_handleMenuSelect:                       ; was sub_04330
  ; ... (196 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleFileListInput
; Address: 0x04B1D (408 insns)
; Called by: desktop_handleViewStateFiles
; Description: Main file list input handler. This is the 2nd largest function
;   (408 insns). Processes all keyboard and mouse input in the file list view:
;   - Arrow keys: navigate file list
;   - Enter: open/run selected file
;   - Delete: delete selected file
;   - Tab: switch between panels
;   - Escape: return to tree view
;   Manages file selection, highlighting, scrolling, and dispatches to
;   file operations (copy, delete, rename, run).
;   Related strings: "Press <Esc> to return to tree"
; ---------------------------------------------------------------------------
; /* address: 0000:4B1D */
desktop_handleFileListInput:                    ; was sub_04B1D
  ; ... (408 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleFileAction
; Address: 0x04F63 (65 insns)
; Called by: desktop_handleFileListInput
; Description: Handles the action triggered on a file (Enter key or
;   double-click). Determines if the file is an executable and launches it,
;   or associates it with the appropriate PDM application.
; ---------------------------------------------------------------------------
; /* address: 0000:4F63 */
desktop_handleFileAction:                       ; was sub_04F63
  ; ... (65 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_scrollFileList
; Address: 0x05009 (41 insns)
; Called by: desktop_handleFileListInput, desktop_handleDisplayMenu
; Description: Scrolls the file list display by one page or line.
; ---------------------------------------------------------------------------
; /* address: 0000:5009 */
desktop_scrollFileList:                         ; was sub_05009
  ; ... (41 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderFileEntry
; Address: 0x050FC (173 insns)
; Called by: desktop_setFileListParams, desktop_highlightFile,
;           desktop_scrollFileName
; Description: Renders a single file entry line in the file list view.
;   Formats and displays filename, extension, size, date, time, and
;   associated program columns.
; ---------------------------------------------------------------------------
; /* address: 0000:50FC */
desktop_renderFileEntry:                        ; was sub_050FC
  ; ... (173 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_formatFileSize
; Address: 0x052BA (48 insns)
; Called by: desktop_handleFileAction, desktop_scrollFileList
; Description: Formats a file size value into a human-readable string with
;   right-alignment and comma separators.
; ---------------------------------------------------------------------------
; /* address: 0000:52BA */
desktop_formatFileSize:                         ; was sub_052BA
  ; ... (48 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_formatDateTime
; Address: 0x05335 (31 insns)
; Called by: desktop_setFileListParams, desktop_renderFileEntry,
;           desktop_formatFileSize
; Description: Formats a DOS date/time value into displayable text.
; ---------------------------------------------------------------------------
; /* address: 0000:5335 */
desktop_formatDateTime:                         ; was sub_05335
  ; ... (31 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getFileExtension
; Address: 0x05380 (37 insns)
; Called by: desktop_formatDateTime
; Description: Extracts the file extension from a filename.
; ---------------------------------------------------------------------------
; /* address: 0000:5380 */
desktop_getFileExtension:                       ; was sub_05380
  ; ... (37 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_highlightFile
; Address: 0x05489 (56 insns)
; Called by: desktop_handleFileListInput
; Description: Highlights the currently selected file in the file list.
;   Draws the selection bar with inverted colors.
; ---------------------------------------------------------------------------
; /* address: 0000:5489 */
desktop_highlightFile:                          ; was sub_05489
  ; ... (56 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_scrollFileName
; Address: 0x0550B (48 insns)
; Called by: desktop_handleFileListInput
; Description: Scrolls a long filename horizontally when it doesn't fit
;   in the column width.
; ---------------------------------------------------------------------------
; /* address: 0000:550B */
desktop_scrollFileName:                         ; was sub_0550B
  ; ... (48 instructions)
  ret

; ===========================================================================
; ABOUT DIALOG / DISK INFO (0x05848 - 0x05F86)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleRunApp
; Address: 0x05848 (387 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles launching an application (Run menu item). This is the
;   3rd largest function (387 insns). Detects DOS version, formats the
;   command line, sets up the EXEC parameter block, and launches the program.
;   Handles both DeskMate .PDM programs and external DOS executables.
;   Checks available memory, formats COM/EXE command tails.
;   Calls: dos_getVersion, sub_0A250 (custom DOS call), bios_resetDisk
; ---------------------------------------------------------------------------
; /* address: 0000:5848 */
desktop_handleRunApp:                           ; was sub_05848
  ; ... (387 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDiskInfo
; Address: 0x05C80 (166 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the "Disk Info" dialog. Shows volume name, free space,
;   total size for the selected disk drive.
;   Related strings: "Disk Info", "Volume name:", "Free space on drive",
;   "bytes"
; ---------------------------------------------------------------------------
; /* address: 0000:5C80 */
desktop_handleDiskInfo:                         ; was sub_05C80
  ; ... (166 instructions)
  ret

; ===========================================================================
; DRIVE SELECTION / STATUS (0x05E0F - 0x066AF)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_changeDrive
; Address: 0x05E0F (38 insns)
; Called by: desktop_handleInstall, desktop_getDriveStatus,
;           desktop_handleChangeDir, desktop_scanDriveList,
;           desktop_initDriveConfig, desktop_initDrive
; Description: Changes the current drive. Calls dos_getCurrentDisk,
;   bios_readBootSector to verify the drive, and updates the internal
;   drive state.
; ---------------------------------------------------------------------------
; /* address: 0000:5E0F */
desktop_changeDrive:                            ; was sub_05E0F
  ; ... (38 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_detectDiskType
; Address: 0x05E65 (35 insns)
; Called by: desktop_handleSaveConfig, desktop_handleFileCopy,
;           desktop_handleFileCopyCmd
; Description: Detects the disk type (floppy, hard disk) and media format
;   of the specified drive. Uses IOCTL and BIOS disk calls.
; ---------------------------------------------------------------------------
; /* address: 0000:5E65 */
desktop_detectDiskType:                         ; was sub_05E65
  ; ... (35 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getDiskFormat
; Address: 0x05EDA (23 insns)
; Called by: desktop_handleFileListInput, desktop_handleRunApp,
;           desktop_handleDiskInfo, desktop_changeDrive,
;           desktop_detectDiskType, (+ 4 more)
; Description: Gets the disk format (capacity, sectors, heads) for a drive.
; ---------------------------------------------------------------------------
; /* address: 0000:5EDA */
desktop_getDiskFormat:                          ; was sub_05EDA
  ; ... (23 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getDriveStatus
; Address: 0x05F0E (30 insns)
; Called by: desktop_handleCreateDir, desktop_handleDeleteDir,
;           desktop_handleChangeDir, desktop_handleSortView,
;           desktop_handleDeleteFile
; Description: Gets the current drive ready status. Checks if a disk is
;   present and readable.
; ---------------------------------------------------------------------------
; /* address: 0000:5F0E */
desktop_getDriveStatus:                         ; was sub_05F0E
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDriveSelect
; Address: 0x05F86 (138 insns)
; Called by: desktop_handleViewStateFiles
; Description: Handles drive selection in the desktop UI. Shows the drive
;   list, allows the user to select a different drive, and refreshes the
;   file display for the selected drive.
; ---------------------------------------------------------------------------
; /* address: 0000:5F86 */
desktop_handleDriveSelect:                      ; was sub_05F86
  ; ... (138 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setCurrentDriveDisplay
; Address: 0x0616D (93 insns)
; Called by: desktop_handleChangeDirAlt, desktop_handleSortFiles,
;           desktop_handleViewStateFiles, desktop_switchMenuView
; Description: Updates the current drive display in the status bar area.
;   Shows the drive letter, volume label, and refreshes the file tree.
; ---------------------------------------------------------------------------
; /* address: 0000:616D */
desktop_setCurrentDriveDisplay:                 ; was sub_0616D
  ; ... (93 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleSortFiles
; Address: 0x06265 (260 insns)
; Called by: desktop_handleViewStateFiles
; Description: Handles the "Sort by" menu operations: sort by Name, Type,
;   Date, or Size. Resorts the current file list and refreshes the display.
;   Related strings: "Name", "Type", "Date", "Size"
; ---------------------------------------------------------------------------
; /* address: 0000:6265 */
desktop_handleSortFiles:                        ; was sub_06265
  ; ... (260 instructions)
  ret

; ===========================================================================
; SCROLLBAR / WINDOW MANAGEMENT (0x066AF - 0x06FDA)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleScroll
; Address: 0x066AF (57 insns)
; Called by: desktop_updateIconState
; Description: Handles scroll events in the file list or tree view.
; ---------------------------------------------------------------------------
; /* address: 0000:66AF */
desktop_handleScroll:                           ; was sub_066AF
  ; ... (57 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleKeyboard
; Address: 0x06646 (48 insns)
; Called by: desktop_handleMenuCreate, desktop_handleMenuDef,
;           desktop_handleMenuAction, desktop_handleInstall,
;           desktop_handleMenuBarKey, desktop_handleFileCopyCmd,
;           desktop_handleMenuCommand, desktop_handleMenuOp (+ 2 more)
; Description: Processes keyboard input events and dispatches to the
;   appropriate handler. One of the most called functions (10 callers).
; ---------------------------------------------------------------------------
; /* address: 0000:6646 */
desktop_handleKeyboard:                         ; was sub_06646
  ; ... (48 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setMenuFocusState
; Address: 0x0677B (38 insns)
; Called by: desktop_handleMenuCommand, desktop_handleFileInfo,
;           desktop_drawStatusLine, desktop_switchMenuView
; Description: Sets the focus/highlight state of menu items in the menu bar.
; ---------------------------------------------------------------------------
; /* address: 0000:677B */
desktop_setMenuFocusState:                      ; was sub_0677B
  ; ... (38 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_showMessageDlg
; Address: 0x067D4 (12 insns)
; Called by: desktop_handleMenuRedefine, desktop_handleInstall,
;           desktop_handleFileCopy, desktop_launchApp,
;           desktop_buildTreeInfo, desktop_handleFileInfo
; Description: Shows a message dialog box with prguf_endPaint and
;   prguf_showMessage. Wrapper around PRGUF dialog services.
; ---------------------------------------------------------------------------
; /* address: 0000:67D4 */
desktop_showMessageDlg:                         ; was sub_067D4
  ; ... (12 instructions)
  ret

; ===========================================================================
; APPLICATION LAUNCHER (0x06900 - 0x071A8)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_playSound
; Address: 0x06900 (112 insns)
; Called by: (no callers recorded -- standalone handler)
; Description: Plays a sound effect via INT 15h (cassette I/O / extended
;   memory services) and INT 15h-based sound generation. Uses custom
;   frequency and duration parameters.
; ---------------------------------------------------------------------------
; /* address: 0000:6900 */
desktop_playSound:                              ; was sub_06900
  ; ... (112 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_playTone
; Address: 0x06A0F (246 insns)
; Called by: (no callers recorded -- standalone handler)
; Description: Plays a musical tone. Programs the sound hardware via INT 15h.
;   Handles timing, pitch, and volume control.
; ---------------------------------------------------------------------------
; /* address: 0000:6A0F */
desktop_playTone:                               ; was sub_06A0F
  ; ... (246 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getDiskCapacity
; Address: 0x06C86 (163 insns)
; Called by: desktop_handleFormatDisk
; Description: Determines disk capacity by probing INT 15h and checking
;   disk geometry. Used to determine format options for floppy disks.
; ---------------------------------------------------------------------------
; /* address: 0000:6C86 */
desktop_getDiskCapacity:                        ; was sub_06C86
  ; ... (163 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_shutdownSound
; Address: 0x06E11 (32 insns)
; Called by: desktop_handleFormatDisk
; Description: Shuts down sound output via INT 15h.
; ---------------------------------------------------------------------------
; /* address: 0000:6E11 */
desktop_shutdownSound:                          ; was sub_06E11
  ; ... (32 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_soundCleanup
; Address: 0x06E6C (11 insns)
; Called by: desktop_flushConfig
; Description: Final sound cleanup, disabling sound hardware.
; ---------------------------------------------------------------------------
; /* address: 0000:6E6C */
desktop_soundCleanup:                           ; was sub_06E6C
  ; ... (11 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_checkSoundHardware
; Address: 0x06E85 (6 insns)
; Called by: desktop_initStartup
; Description: Checks if Tandy sound hardware (SN76496 or DAC) is present.
; ---------------------------------------------------------------------------
; /* address: 0000:6E85 */
desktop_checkSoundHardware:                     ; was sub_06E85
  ; ... (6 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_initSoundDriver
; Address: 0x06E93 (125 insns)
; Called by: desktop_playSound, desktop_playTone
; Description: Initializes the sound driver subsystem. Configures the
;   SN76496 or Tandy DAC for audio output.
; ---------------------------------------------------------------------------
; /* address: 0000:6E93 */
desktop_initSoundDriver:                        ; was sub_06E93
  ; ... (125 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_launchApp
; Address: 0x06FDA (39 insns)
; Called by: desktop_addMenuItem, desktop_handleMenuRedefine,
;           desktop_handleCreateDir, desktop_handleDeleteDir,
;           desktop_handleChangeDir, desktop_refreshTreeView,
;           desktop_handleFileListInput, desktop_handleRunApp, (+ 15 more)
; Description: Launches a PDM application via PRGUF. This is one of the
;   most-called functions (23 callers). Sets up the launch parameters and
;   calls desktop_showMessageDlg to display the result.
; ---------------------------------------------------------------------------
; /* address: 0000:6FDA */
desktop_launchApp:                              ; was sub_06FDA
  ; ... (39 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_validateFilePath
; Address: 0x07037 (31 insns)
; Called by: desktop_handleCreateDir, desktop_handleChangeDir,
;           desktop_handleDeleteDirConfirm, desktop_handleFileList,
;           desktop_handleDeleteFile, desktop_handleRenameFile
; Description: Validates a file path for correctness.
; ---------------------------------------------------------------------------
; /* address: 0000:7037 */
desktop_validateFilePath:                       ; was sub_07037
  ; ... (31 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setMenuDimensions
; Address: 0x0707C (43 insns)
; Called by: desktop_handleMenuSelect, desktop_handleSortFiles,
;           desktop_handleMenuCommand
; Description: Sets menu bar dimensions (width, height) via PRGUF calls.
; ---------------------------------------------------------------------------
; /* address: 0000:707C */
desktop_setMenuDimensions:                      ; was sub_0707C
  ; ... (43 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_updateMenuBar
; Address: 0x070EC (57 insns)
; Called by: desktop_handleMenuSelect, desktop_handleFileListInput,
;           desktop_handleSortFiles, desktop_drawMenuBar,
;           desktop_handleMenuCommand, desktop_handleAppSwitch
; Description: Updates the menu bar display after a state change.
; ---------------------------------------------------------------------------
; /* address: 0000:70EC */
desktop_updateMenuBar:                          ; was sub_070EC
  ; ... (57 instructions)
  ret

; ===========================================================================
; FILE LIST / SORT / SEARCH -- LARGEST FUNCTION (0x071A8 - 0x08870)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleFileList
; Address: 0x071A8 (792 insns) *** LARGEST FUNCTION ***
; Called by: desktop_handleFileSort
; Description: The complete file list display and interaction engine. This is
;   the largest function in DESKTOP.PDM at 792 instructions. It handles:
;   - Directory scanning (dos_findFirst, dos_findNext)
;   - File entry formatting (name, ext, size, date, time)
;   - Sorting (by name, type, date, size)
;   - Display rendering with column alignment
;   - File selection and navigation
;   - Special file handling (directories, hidden files)
;   - Free space display (dos_getDiskFree)
;   - Date/time formatting (dos_getFileDateTime)
;   - Path construction for nested directories
;   Calls 37 other functions, making it the central hub of the file manager.
; ---------------------------------------------------------------------------
; /* address: 0000:71A8 */
desktop_handleFileList:                         ; was sub_071A8
  ; ... (792 instructions - file list engine)
  ret

; ---------------------------------------------------------------------------
; desktop_buildTreeInfo
; Address: 0x07A50 (77 insns)
; Called by: desktop_handleFileList
; Description: Builds tree structure information for the current directory.
; ---------------------------------------------------------------------------
; /* address: 0000:7A50 */
desktop_buildTreeInfo:                          ; was sub_07A50
  ; ... (77 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getTreeCacheEntry
; Address: 0x07B0C (15 insns)
; Called by: desktop_handleFileList
; Description: Retrieves a cached tree structure entry.
; ---------------------------------------------------------------------------
; /* address: 0000:7B0C */
desktop_getTreeCacheEntry:                      ; was sub_07B0C
  ; ... (15 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_buildTreeView
; Address: 0x07B2C (69 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Builds the directory tree view display.
; ---------------------------------------------------------------------------
; /* address: 0000:7B2C */
desktop_buildTreeView:                          ; was sub_07B2C
  ; ... (69 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_traverseTree
; Address: 0x07BD4 (40 insns)
; Called by: desktop_buildTreeView, desktop_traverseTree (recursive)
; Description: Recursively traverses the directory tree structure.
; ---------------------------------------------------------------------------
; /* address: 0000:7BD4 */
desktop_traverseTree:                           ; was sub_07BD4
  ; ... (40 instructions - recursive)
  ret

; ---------------------------------------------------------------------------
; desktop_formatCountryDate
; Address: 0x07C29 (109 insns)
; Called by: desktop_addFileEntry, desktop_buildTreeView
; Description: Formats a date according to the country-specific format
;   (calls dos_getCountryInfo via INT 21h AH=38h).
; ---------------------------------------------------------------------------
; /* address: 0000:7C29 */
desktop_formatCountryDate:                      ; was sub_07C29
  ; ... (109 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_formatCountryTime
; Address: 0x07D14 (79 insns)
; Called by: desktop_addFileEntry, desktop_buildTreeView
; Description: Formats a time according to the country-specific format.
; ---------------------------------------------------------------------------
; /* address: 0000:7D14 */
desktop_formatCountryTime:                      ; was sub_07D14
  ; ... (79 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleSortView
; Address: 0x07E5F (157 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the View > Sort By submenu. Allows sorting the file
;   list by different criteria and refreshes the display.
; ---------------------------------------------------------------------------
; /* address: 0000:7E5F */
desktop_handleSortView:                         ; was sub_07E5F
  ; ... (157 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDeleteFile
; Address: 0x07DC3 (62 insns)
; Called by: desktop_handleAppRelaunch
; Description: Handles the "Delete File" operation.
;   Related strings: "Delete File", "Filename:"
; ---------------------------------------------------------------------------
; /* address: 0000:7DC3 */
desktop_handleDeleteFile:                       ; was sub_07DC3
  ; ... (62 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleRenameFile
; Address: 0x080E0 (239 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles the "Rename File" operation. Shows rename dialog
;   with From: field, validates new name, performs the rename.
;   Related strings: "Rename File", "From:"
; ---------------------------------------------------------------------------
; /* address: 0000:80E0 */
desktop_handleRenameFile:                       ; was sub_080E0
  ; ... (239 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleFileSort
; Address: 0x0835C (246 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Handles file sorting operations. Implements the sort
;   algorithms for name, type, date, and size ordering.
;   Calls desktop_handleFileList as its core engine.
; ---------------------------------------------------------------------------
; /* address: 0000:835C */
desktop_handleFileSort:                         ; was sub_0835C
  ; ... (246 instructions)
  ret

; ===========================================================================
; MENU BAR RENDERING (0x08870 - 0x098EB)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_drawMenuBar
; Address: 0x08870 (237 insns)
; Called by: desktop_handleDirChange, desktop_handleMenuAction
; Description: Draws the complete menu bar with all menu titles:
;   DeskMate, File, Directory, Disk, View, Sort by, Desktop.
;   Handles highlighting of the active menu, keyboard accelerators,
;   and menu enable/disable states.
;   Related strings: "DeskMate", "File", "Directory", "Disk", "View",
;   "Sort by", "Desktop"
; ---------------------------------------------------------------------------
; /* address: 0000:8870 */
desktop_drawMenuBar:                            ; was sub_08870
  ; ... (237 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawMenuBarItem
; Address: 0x08B7C (33 insns)
; Called by: desktop_validateProgramFile, desktop_drawMenuBar,
;           desktop_initMenuBarItem, desktop_drawStatusLine
; Description: Draws a single item in the menu bar with proper formatting.
; ---------------------------------------------------------------------------
; /* address: 0000:8B7C */
desktop_drawMenuBarItem:                        ; was sub_08B7C
  ; ... (33 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_highlightMenuBar
; Address: 0x08CB5 (22 insns)
; Called by: desktop_drawMenuBar
; Description: Highlights the active menu item in the menu bar.
;   Calls desktop_launchApp for menu activation.
; ---------------------------------------------------------------------------
; /* address: 0000:8CB5 */
desktop_highlightMenuBar:                       ; was sub_08CB5
  ; ... (22 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_drawMenuDropdown
; Address: 0x08D36 (61 insns)
; Called by: desktop_handleIconClick, desktop_drawMenuBar,
;           desktop_drawMenuBarItem
; Description: Draws a dropdown menu panel beneath a menu bar item.
; ---------------------------------------------------------------------------
; /* address: 0000:8D36 */
desktop_drawMenuDropdown:                       ; was sub_08D36
  ; ... (61 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderMenuContent
; Address: 0x08DC8 (85 insns)
; Called by: desktop_drawMenuDropdown, desktop_renderMenuCopy,
;           desktop_renderMenuDelete, desktop_renderMenuRename,
;           desktop_renderMenuRun, desktop_renderMenuGetInfo,
;           desktop_renderMenuRedefine, desktop_renderMenuDisplay
; Description: Core menu content renderer. Draws the menu item text, keyboard
;   shortcuts, separator lines, and enable/disable indicators within a
;   dropdown menu. Called by 8+ menu-specific renderers.
; ---------------------------------------------------------------------------
; /* address: 0000:8DC8 */
desktop_renderMenuContent:                      ; was sub_08DC8
  ; ... (85 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuBarEvent
; Address: 0x08E9E (73 insns)
; Called by: desktop_readMenuTitle, desktop_processMenuDef,
;           desktop_handleFormatDisk, desktop_handleMenuAction,
;           desktop_buildTreeView, desktop_refreshTreeView,
;           desktop_getPathComponent
; Description: Handles events within the menu bar area (clicks, keyboard).
;   Dispatches to the appropriate menu handler.
; ---------------------------------------------------------------------------
; /* address: 0000:8E9E */
desktop_handleMenuBarEvent:                     ; was sub_08E9E
  ; ... (73 instructions)
  ret

; ===========================================================================
; STRING UTILITIES (0x098EB - 0x09B7C)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_copyString
; Address: 0x098EB (12 insns)
; Called by: desktop_buildIconGrid, desktop_findIconAt, desktop_renderIcon
; Description: Copies a string from source to destination (near pointers).
; ---------------------------------------------------------------------------
; /* address: 0000:98EB */
desktop_copyString:                             ; was sub_098EB
  ; ... (12 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_getAppType
; Address: 0x09907 (6 insns)
; Called by: desktop_updateIconState, desktop_handleMenuDef,
;           desktop_handleDirExit, desktop_handleDirChange, desktop_restoreIconView
; Description: Gets the application type code for a given program.
; ---------------------------------------------------------------------------
; /* address: 0000:9907 */
desktop_getAppType:                             ; was sub_09907
  ; ... (6 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_validateFileName
; Address: 0x099A3 (46 insns)
; Called by: desktop_renderTreeNode, desktop_handleMenuBarKey,
;           desktop_handleFileList, desktop_handleMenuBarEvent
; Description: Validates a filename against DOS naming rules.
; ---------------------------------------------------------------------------
; /* address: 0000:99A3 */
desktop_validateFileName:                       ; was sub_099A3
  ; ... (46 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_upperCase
; Address: 0x09A0F (5 insns)
; Called by: desktop_getIconProgram, desktop_readMenuTitle,
;           desktop_processMenuDef, desktop_handleFormatDisk,
;           desktop_handleMenuAction, desktop_renderTreeNode, (+ 4 more)
; Description: Converts a character to uppercase.
; ---------------------------------------------------------------------------
; /* address: 0000:9A0F */
desktop_upperCase:                              ; was sub_09A0F
  ; ... (5 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_strcpy
; Address: 0x09A17 (21 insns)
; Called by: desktop_readMenuTitle, desktop_processMenuDef,
;           desktop_handleFormatDisk, desktop_handleMenuAction, (+ 9 more)
; Description: String copy with length tracking. Copies source to dest,
;   calling desktop_copyChar for each character.
; ---------------------------------------------------------------------------
; /* address: 0000:9A17 */
desktop_strcpy:                                 ; was sub_09A17
  ; ... (21 instructions)
  ret

; ===========================================================================
; MAIN ENTRY / INITIALIZATION (0x09B7C)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_main
; Address: 0x09B7C (135 insns)
; Called by: (no callers -- this is main(), called from MSC startup)
; Description: Main entry point for DESKTOP.PDM application logic. This is
;   the program's main() function called after MSC CRT startup. It:
;   1. Registers with PRGUF via prguf_loadResourceModule (sub_0DF3B)
;   2. Registers the app with prguf_registerApp
;   3. Loads UI attribute (dm_set_attribute via sub_0DBFA)
;   4. Checks disk status (desktop_checkConfigExists)
;   5. Calls desktop_initStartup to load config / first-run wizard
;   6. Calls desktop_checkDiskReady
;   7. Gets max icon count via prguf_getMaxIcons
;   8. Initializes file list via desktop_getMenuBarState
;   9. Initializes prguf_getActiveMenu
;   10. Initializes tree view
;   11. Sets up the desktop icon grid and status display
;   12. Calls desktop_handleViewStateFiles to enter the main view
;   13. Enters the main event loop (desktop_handleMenuCommand)
;   14. On exit, saves config (desktop_saveConfig)
;   15. Unregisters from PRGUF via prguf_unloadResourceModule (sub_0DF42)
;
;   This function is the backbone of the entire DESKTOP.PDM module.
; ---------------------------------------------------------------------------
; /* address: 0000:9B7C */
desktop_main:                                   ; was sub_09B7C
  push     bp
  mov      bp, sp
  sub      sp, 0x46
  push     si
  mov      word ptr [bp - 0x46], 0             ; init local state
  call     prguf_loadResourceModule              ; -> sub_0DF3B: register with PRGUF
  mov      ax, 0x294e                          ; app registration block
  push     ax
  call     prguf_registerApp                     ; -> sub_0E0C7
  add      sp, 2
  call     dm_setWindowAttribute                 ; -> sub_0DBFA: set UI attributes via INT E0h
  inc      ax
  jne      .attr_ok
  mov      ax, 2
  push     ax
  call     desktop_handleExitError               ; -> sub_0C90D: show error, exit
  add      sp, 2
.attr_ok:
  call     desktop_checkConfigExists             ; -> sub_02E12
  mov      byte ptr [0x4620], al               ; store config existence flag
  mov      ax, 0x3367                          ; config file path/params
  push     ax
  call     desktop_initStartup                   ; -> sub_0BDF8: load config / first-run
  add      sp, 2
  or       ax, ax
  jne      .startup_ok
  mov      ax, 3
  push     ax
  call     desktop_handleExitError               ; -> sub_0C90D
  add      sp, 2
.startup_ok:
  call     desktop_checkDiskReady                ; -> sub_02E58
  call     prguf_getMaxIcons                     ; -> sub_0E0D3
  mov      si, ax                              ; max icon count
  cmp      si, 2
  jge      .icons_ok
  mov      si, 2
  mov      ax, si
  push     ax
  call     prguf_setMaxIcons                     ; -> sub_0E0CD
  add      sp, si                              ; (note: uses si as sp adjust)
.icons_ok:
  call     desktop_getMenuBarState               ; -> sub_09960
  call     prguf_getActiveMenu                   ; -> sub_0E08B
  call     desktop_initTreeView                  ; -> sub_0672F
  call     desktop_initSortState                 ; -> sub_09842
  call     desktop_detectDiskType                ; -> sub_05E65
  mov      byte ptr [0x48da], al               ; store disk type
  mov      ax, 0x5ee2                          ; menu structure pointer
  push     ax
  call     desktop_getDriveStatus                ; -> sub_03960
  add      sp, 2
  mov      ax, 0x18c6                          ; accelerator table
  push     ax
  call     prguf_setAccelTable                   ; -> sub_0E09D
  add      sp, 2
  mov      ax, 0x5ee2
  push     ax
  call     prguf_setMenuStruct                   ; -> sub_0E0A3
  add      sp, 2
  ; Set timer for auto-refresh
  mov      ax, 0x4be
  push     ax
  call     prguf_setTimer                        ; -> sub_0DF9B
  add      sp, 2
  call     prguf_initView                        ; -> sub_0DF71
  call     prguf_beginPaint                      ; -> sub_0DF7D
  ; Handle initial view mode
  call     desktop_initTreeData                  ; -> sub_047DB
  cmp      byte ptr [0x3bc1], 0                ; check initial view mode
  je       .skip_files_init
  call     desktop_handleViewStateFiles          ; -> sub_0CA57: enter file view
  cmp      byte ptr [0x3aea], 0
  je       .skip_files_init
  ; Initial file list display
  mov      ax, 0x3e80
  push     ax
  sub      ax, ax
  push     ax
  call     desktop_drawStatusLine                ; -> sub_0B792
  add      sp, 4
  ; Set up menu structure again
  mov      ax, 0x5ee2
  push     ax
  call     desktop_getDriveStatus                ; -> sub_03960
  add      sp, 2
  mov      ax, 0x18c6
  push     ax
  call     prguf_setAccelTable                   ; -> sub_0E09D
  add      sp, 2
  mov      ax, 0x5ee2
  push     ax
  call     prguf_setMenuStruct                   ; -> sub_0E0A3
  add      sp, 2
.skip_files_init:
  cmp      byte ptr [0x3aea], 0
  je       .skip_app_init
  call     desktop_expandTreeNode                ; -> sub_0B3F1
  call     desktop_handleKeyboard                ; -> sub_06646: process keyboard
  sub      ax, ax
  push     ax
  call     desktop_launchApp                     ; -> sub_0B2A6: initial app launch
  add      sp, 2
  ; Set menu data
  mov      ax, 0x3e7e
  push     ds
  push     ax
  call     prguf_setMenuData                     ; -> sub_0DF0D
  add      sp, 4
  mov      byte ptr [0x3e7e], 0
  call     desktop_handleMenuCommand             ; -> sub_0A628: main event loop
.skip_app_init:
  ; Setup complete, enter main loop
  sub      ax, ax
  push     ax
  push     ax
  call     prguf_setMenuData                     ; -> sub_0DF0D
  add      sp, 4
  ; Check if view mode changed
  mov      al, byte ptr [0x4a02]
  cmp      byte ptr [0x3bc1], al
  jne      .config_changed
  mov      al, byte ptr [0x5ba]
  cmp      byte ptr [0x5b9], al
  je       .no_change
.config_changed:
  mov      byte ptr [0x5e6f], 1                ; mark config dirty
.no_change:
  call     desktop_saveTreeConfig                ; -> sub_0C260
  cmp      byte ptr [0x5e6f], 0
  je       .skip_save
  call     desktop_saveConfig                    ; -> sub_0C34F: save DESKTOP.CFG
.skip_save:
  ; Handle pending file operations
  cmp      word ptr [0x5e72], 0
  je       .no_pending
  mov      byte ptr [0x5bd0], 1
  push     word ptr [0x5e72]
  call     desktop_handleFileOp                  ; -> sub_0382C
  add      sp, 2
.no_pending:
  call     prguf_endPaint                        ; -> sub_0DF77: release paint lock
  call     prguf_killTimer                       ; -> sub_0DFA1: stop timer
  call     dm_setCursorCallback                  ; -> sub_0DC3C: restore cursor
  cmp      byte ptr [0x543], 0
  je       .skip_attr_restore
  call     dm_getWindowInfo                      ; -> sub_0DB98: restore window state
.skip_attr_restore:
  call     prguf_unloadResourceModule            ; -> sub_0DF42: unregister from PRGUF
  pop      si
  mov      sp, bp
  pop      bp
  ret

; ===========================================================================
; DOS FILE OPERATIONS (0x09CE4 - 0x0A250)
; ===========================================================================

; ---------------------------------------------------------------------------
; dos_clearSearchState
; Address: 0x09CE4 (2 insns)
; Called by: dos_findFirst, dos_findFirstExt, dos_findNext
; Description: Clears the DOS file search state variable at [0x3057].
; ---------------------------------------------------------------------------
; /* address: 0000:9CE4 */
dos_clearSearchState:                           ; was sub_09CE4
  mov      word ptr [0x3057], 0
  ret

; ---------------------------------------------------------------------------
; dos_initSearchState
; Address: 0x09CEB (4 insns)
; Called by: dos_findFirst, dos_findFirstExt, dos_findNext,
;           dos_findVolumeLabel, dos_mkdir, dos_rmdir
; Description: Initializes DOS search state, clearing multiple state vars.
; ---------------------------------------------------------------------------
; /* address: 0000:9CEB */
dos_initSearchState:                            ; was sub_09CEB
  mov      word ptr [0x3057], 0
  mov      word ptr [0x4a06], 0
  mov      word ptr [0x3b6c], 0
  ret

; ---------------------------------------------------------------------------
; dos_findFirst
; Address: 0x09DF3 (26 insns)
; Called by: desktop_populateFileList, desktop_checkDirFiles,
;           desktop_handleCreateDir, desktop_handleFileList
; Description: Wrapper for DOS INT 21h AH=4Eh (Find First Matching File).
;   Sets up the DTA and performs the search.
; ---------------------------------------------------------------------------
; /* address: 0000:9DF3 */
dos_findFirst:                                  ; was sub_09DF3
  ; ... calls dos_clearSearchState, dos_initSearchState
  ; INT 21h AH=4Eh
  ret

; ---------------------------------------------------------------------------
; dos_findFirstExt
; Address: 0x09E26 (26 insns)
; Called by: desktop_handleFileList, desktop_handleDeleteFile
; Description: Extended Find First with additional attribute matching.
; ---------------------------------------------------------------------------
; /* address: 0000:9E26 */
dos_findFirstExt:                               ; was sub_09E26
  ; INT 21h AH=4Eh
  ret

; ---------------------------------------------------------------------------
; dos_findNext
; Address: 0x09E59 (20 insns)
; Called by: desktop_populateFileList, desktop_handleFileList,
;           desktop_handleDeleteFile
; Description: Wrapper for DOS INT 21h AH=4Fh (Find Next Matching File).
; ---------------------------------------------------------------------------
; /* address: 0000:9E59 */
dos_findNext:                                   ; was sub_09E59
  ; INT 21h AH=4Fh
  ret

; ---------------------------------------------------------------------------
; dos_parseFCB
; Address: 0x09E80 (46 insns)
; Called by: desktop_populateFileList, desktop_checkDirFiles,
;           desktop_handleFileList, desktop_handleDeleteFile
; Description: Parses a file control block (FCB) from the DTA data.
; ---------------------------------------------------------------------------
; /* address: 0000:9E80 */
dos_parseFCB:                                   ; was sub_09E80
  ; ... (46 instructions)
  ret

; ---------------------------------------------------------------------------
; dos_getDTA
; Address: 0x09EE2 (17 insns)
; Description: Gets the current DTA (Disk Transfer Area) address via
;   INT 21h AH=2Fh.
; ---------------------------------------------------------------------------
; /* address: 0000:9EE2 */
dos_getDTA:                                     ; was sub_09EE2
  ; INT 21h AH=2Fh
  ret

; ---------------------------------------------------------------------------
; dos_setDTA
; Address: 0x09EFE (14 insns)
; Called by: desktop_populateFileList, desktop_checkDirFiles,
;           desktop_scanDriveList, desktop_handleFileList,
;           desktop_handleDeleteFile
; Description: Sets the DTA address via INT 21h AH=1Ah.
; ---------------------------------------------------------------------------
; /* address: 0000:9EFE */
dos_setDTA:                                     ; was sub_09EFE
  ; INT 21h AH=1Ah
  ret

; ---------------------------------------------------------------------------
; dos_findVolumeLabel
; Address: 0x09F12 (51 insns)
; Called by: desktop_scanDriveList
; Description: Finds the volume label on a disk using INT 21h AH=11h
;   (Find First via FCB) and INT 21h AH=2Fh (Get DTA).
; ---------------------------------------------------------------------------
; /* address: 0000:9F12 */
dos_findVolumeLabel:                            ; was sub_09F12
  ; INT 21h AH=11h, AH=2Fh
  ret

; ---------------------------------------------------------------------------
; dos_mkdir
; Address: 0x09F77 (35 insns)
; Called by: desktop_handleCreateDir
; Description: Creates a directory via INT 21h AH=39h.
;   On error, calls INT 21h AH=59h (Get Extended Error).
; ---------------------------------------------------------------------------
; /* address: 0000:9F77 */
dos_mkdir:                                      ; was sub_09F77
  ; INT 21h AH=39h, AH=59h
  ret

; ---------------------------------------------------------------------------
; dos_rmdir
; Address: 0x09FB4 (30 insns)
; Called by: desktop_handleDeleteDirConfirm
; Description: Removes a directory via INT 21h AH=3Ah.
;   On error, calls INT 21h AH=59h (Get Extended Error).
; ---------------------------------------------------------------------------
; /* address: 0000:9FB4 */
dos_rmdir:                                      ; was sub_09FB4
  ; INT 21h AH=3Ah, AH=59h
  ret

; ---------------------------------------------------------------------------
; dos_getDiskFree
; Address: 0x09FEB (24 insns)
; Called by: desktop_handleCreateDir, desktop_handleDiskFreeSpace,
;           desktop_handleFileList
; Description: Gets disk free space via INT 21h AH=36h.
; ---------------------------------------------------------------------------
; /* address: 0000:9FEB */
dos_getDiskFree:                                ; was sub_09FEB
  ; INT 21h AH=36h
  ret

; ---------------------------------------------------------------------------
; dos_getFileDateTime
; Address: 0x0A016 (22 insns)
; Called by: desktop_handleFileList
; Description: Gets file date/time via INT 21h AH=57h.
; ---------------------------------------------------------------------------
; /* address: 0000:A016 */
dos_getFileDateTime:                            ; was sub_0A016
  ; INT 21h AH=57h
  ret

; ---------------------------------------------------------------------------
; dos_getCountryInfo
; Address: 0x0A040 (8 insns)
; Called by: desktop_formatCountryDate, desktop_formatCountryTime
; Description: Gets country-specific formatting info via INT 21h AH=38h.
; ---------------------------------------------------------------------------
; /* address: 0000:A040 */
dos_getCountryInfo:                             ; was sub_0A040
  ; INT 21h AH=38h
  ret

; ---------------------------------------------------------------------------
; dos_printString
; Address: 0x0A04E (8 insns)
; Description: Prints a $-terminated string via INT 21h AH=09h.
; ---------------------------------------------------------------------------
; /* address: 0000:A04E */
dos_printString:                                ; was sub_0A04E
  ; INT 21h AH=09h
  ret

; ---------------------------------------------------------------------------
; dos_getCurrentDisk
; Address: 0x0A05C (5 insns)
; Called by: desktop_handleInstall, desktop_changeDrive, desktop_getDriveStatus,
;           desktop_getDriveStatus, desktop_scanDriveList,
;           desktop_initDriveConfig, desktop_initDrive, (+ 1 more)
; Description: Gets current default drive via INT 21h AH=19h.
; ---------------------------------------------------------------------------
; /* address: 0000:A05C */
dos_getCurrentDisk:                             ; was sub_0A05C
  ; INT 21h AH=19h
  ret

; ---------------------------------------------------------------------------
; dos_ioctl
; Address: 0x0A065 (19 insns)
; Called by: desktop_handleFileCopy, desktop_detectDiskType
; Description: Performs device I/O control via INT 21h AH=44h (IOCTL).
; ---------------------------------------------------------------------------
; /* address: 0000:A065 */
dos_ioctl:                                      ; was sub_0A065
  ; INT 21h AH=44h
  ret

; ===========================================================================
; HARDWARE / DISK I/O (0x0A087 - 0x0A250)
; ===========================================================================

; ---------------------------------------------------------------------------
; bios_getEquipment
; Address: 0x0A087 (15 insns)
; Called by: desktop_handleRunFile
; Description: Gets BIOS equipment list via INT 11h. Used to detect
;   hardware configuration (floppy drives, coprocessor, etc.).
; ---------------------------------------------------------------------------
; /* address: 0000:A087 */
bios_getEquipment:                              ; was sub_0A087
  ; INT 11h
  ret

; ---------------------------------------------------------------------------
; bios_readBootSector
; Address: 0x0A0A5 (13 insns)
; Called by: desktop_changeDrive
; Description: Reads the boot sector via INT 13h (BIOS disk services).
;   Used to verify drive readiness and detect media type.
; ---------------------------------------------------------------------------
; /* address: 0000:A0A5 */
bios_readBootSector:                            ; was sub_0A0A5
  ; INT 13h
  ret

; ---------------------------------------------------------------------------
; bios_getEquipmentAlt
; Address: 0x0A0B8 (5 insns)
; Called by: bios_ioctlDiskInfo
; Description: Alternative equipment check via INT 11h.
; ---------------------------------------------------------------------------
; /* address: 0000:A0B8 */
bios_getEquipmentAlt:                           ; was sub_0A0B8
  ; INT 11h
  ret

; ---------------------------------------------------------------------------
; bios_ioctlDiskInfo
; Address: 0x0A0C2 (52 insns)
; Description: Gets disk geometry information via IOCTL (INT 21h AH=44h)
;   and BIOS disk services (INT 13h). Detects floppy disk parameters.
; ---------------------------------------------------------------------------
; /* address: 0000:A0C2 */
bios_ioctlDiskInfo:                             ; was sub_0A0C2
  ; INT 21h AH=44h, INT 13h x2
  ret

; ---------------------------------------------------------------------------
; bios_formatTrack
; Address: 0x0A11F (23 insns)
; Called by: desktop_handleDiskFormat
; Description: Formats a disk track via INT 13h.
; ---------------------------------------------------------------------------
; /* address: 0000:A11F */
bios_formatTrack:                               ; was sub_0A11F
  ; INT 13h
  ret

; ---------------------------------------------------------------------------
; bios_resetDisk
; Address: 0x0A1BB (15 insns)
; Called by: desktop_handleFormatDisk, desktop_handleFileCopy,
;           desktop_checkDiskReady, desktop_handleRunApp,
;           desktop_detectDiskType, desktop_initStartup
; Description: Resets the disk system via INT 13h AH=00h.
; ---------------------------------------------------------------------------
; /* address: 0000:A1BB */
bios_resetDisk:                                 ; was sub_0A1BB
  ; INT 13h
  ret

; ---------------------------------------------------------------------------
; bios_setDARate
; Address: 0x0A1D6 (16 insns)
; Called by: desktop_checkDiskReady, desktop_playSound, desktop_playTone,
;           desktop_getDiskCapacity, desktop_shutdownSound, desktop_soundCleanup,
;           desktop_checkSoundHardware, desktop_initSoundDriver
; Description: Sets disk data rate or Tandy audio parameter via INT 15h.
;   The INT 15h call is used for both cassette I/O (on Tandy systems) and
;   extended memory services, depending on the AH subfuction.
; ---------------------------------------------------------------------------
; /* address: 0000:A1D6 */
bios_setDARate:                                 ; was sub_0A1D6
  ; INT 15h
  ret

; ---------------------------------------------------------------------------
; bios_cassetteIO
; Address: 0x0A1F1 (23 insns)
; Called by: desktop_playSound, desktop_getDiskCapacity,
;           desktop_soundCleanup, desktop_initSoundDriver
; Description: Tandy cassette / audio I/O via INT 15h.
;   Multiple INT 15h calls with different subfunctions.
; ---------------------------------------------------------------------------
; /* address: 0000:A1F1 */
bios_cassetteIO:                                ; was sub_0A1F1
  ; INT 15h x2
  ret

; ---------------------------------------------------------------------------
; bios_extendedWait
; Address: 0x0A221 (18 insns)
; Called by: desktop_initStartup
; Description: Extended wait / delay via INT 15h.
; ---------------------------------------------------------------------------
; /* address: 0000:A221 */
bios_extendedWait:                              ; was sub_0A221
  ; INT 15h
  ret

; ---------------------------------------------------------------------------
; dos_getVersion
; Address: 0x0A241 (9 insns)
; Called by: desktop_handleRunApp
; Description: Gets DOS version via INT 21h AH=30h.
; ---------------------------------------------------------------------------
; /* address: 0000:A241 */
dos_getVersion:                                 ; was sub_0A241
  ; INT 21h AH=30h
  ret

; ===========================================================================
; EVENT DISPATCH / KEYBOARD (0x0A628 - 0x0B792)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleMenuCommand
; Address: 0x0A628 (187 insns)
; Called by: desktop_main
; Description: Main event loop / menu command dispatcher. This is the central
;   event processing function, called from desktop_main. Processes events
;   from the PRGUF event loop and dispatches to menu handlers:
;   - File menu: Get Info, Run, Copy, Delete, Rename
;   - Directory menu: Create, Change, Delete
;   - Disk menu: Format, Diskcopy, Disk Info
;   - View menu: Menus, Tree, Files
;   - Sort menu: Name, Type, Date, Size
;   - Desktop menu: Remove, Move, Install, Create Quick Load
;   Handles Ctrl+U (update screen), Esc (exit), and function keys.
; ---------------------------------------------------------------------------
; /* address: 0000:A628 */
desktop_handleMenuCommand:                      ; was sub_0A628
  ; ... (187 instructions - main event dispatcher)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuOp
; Address: 0x0A803 (204 insns)
; Called by: desktop_handleMenuCommand
; Description: Handles a specific menu operation after selection. Dispatches
;   to the appropriate handler function based on the menu item ID.
;   This is the second-level dispatch after desktop_handleMenuCommand
;   determines which menu was selected.
; ---------------------------------------------------------------------------
; /* address: 0000:A803 */
desktop_handleMenuOp:                           ; was sub_0A803
  ; ... (204 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleCopyMenu
; Address: 0x0AA0F (26 insns)
; Called by: desktop_handleMenuOp
; Description: Handles the "Copy..." menu item selection.
; ---------------------------------------------------------------------------
; /* address: 0000:AA0F */
desktop_handleCopyMenu:                         ; was sub_0AA0F
  ; ... (26 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDeleteMenu
; Address: 0x0AB2E (30 insns)
; Called by: desktop_handleMenuCommand, desktop_handleAppSwitch
; Description: Handles the "Delete..." menu item selection.
; ---------------------------------------------------------------------------
; /* address: 0000:AB2E */
desktop_handleDeleteMenu:                       ; was sub_0AB2E
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleFileInfo
; Address: 0x0AF17 (51 insns)
; Called by: (no callers recorded -- standalone handler)
; Description: Handles the "Get Info..." menu item. Shows file information.
; ---------------------------------------------------------------------------
; /* address: 0000:AF17 */
desktop_handleFileInfo:                         ; was sub_0AF17
  ; ... (51 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderMenuCopy
; Address: 0x0B048 (36 insns)
; Called by: desktop_handleMenuOp
; Description: Renders the Copy submenu content.
; ---------------------------------------------------------------------------
; /* address: 0000:B048 */
desktop_renderMenuCopy:                         ; was sub_0B048
  ; ... (36 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderMenuDelete
; Address: 0x0B0D9 (33 insns)
; Called by: desktop_handleMenuOp
; Description: Renders the Delete submenu content.
; ---------------------------------------------------------------------------
; /* address: 0000:B0D9 */
desktop_renderMenuDelete:                       ; was sub_0B0D9
  ; ... (33 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderMenuRename
; Address: 0x0B164 (37 insns)
; Called by: desktop_handleMenuOp
; Description: Renders the Rename submenu content.
; ---------------------------------------------------------------------------
; /* address: 0000:B164 */
desktop_renderMenuRename:                       ; was sub_0B164
  ; ... (37 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_renderMenuRun
; Address: 0x0B206 (37 insns)
; Called by: desktop_handleMenuOp
; Description: Renders the Run submenu content.
; ---------------------------------------------------------------------------
; /* address: 0000:B206 */
desktop_renderMenuRun:                          ; was sub_0B206
  ; ... (37 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_launchAppFromMenu
; Address: 0x0B2A6 (97 insns)
; Called by: desktop_handleMenuAction, desktop_handleInstall,
;           desktop_highlightMenuBar, desktop_main, desktop_handleMenuCommand,
;           desktop_handleMenuOp, desktop_handleDeleteMenu
; Description: Launches an application based on the currently selected menu
;   item. Resolves the .PDM filename, sets up parameters, and calls the
;   PRGUF launcher.
; ---------------------------------------------------------------------------
; /* address: 0000:B2A6 */
desktop_launchAppFromMenu:                      ; was sub_0B2A6
  ; ... (97 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuBarKey
; Address: 0x0B3AE (26 insns)
; Called by: desktop_handleMenuCreate, desktop_handleMenuDef,
;           desktop_handleMenuCommand, desktop_handleFileInfo
; Description: Handles a keyboard event within the menu bar area.
; ---------------------------------------------------------------------------
; /* address: 0000:B3AE */
desktop_handleMenuBarKey:                       ; was sub_0B3AE
  ; ... (26 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_expandTreeNode
; Address: 0x0B3F1 (52 insns)
; Called by: desktop_main, desktop_handleMenuBarKey
; Description: Expands a directory tree node, showing its children.
; ---------------------------------------------------------------------------
; /* address: 0000:B3F1 */
desktop_expandTreeNode:                         ; was sub_0B3F1
  ; ... (52 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setMenuFocus
; Address: 0x0B4FB (27 insns)
; Called by: desktop_setMenuFocusPair
; Description: Sets focus to a specific menu item.
; ---------------------------------------------------------------------------
; /* address: 0000:B4FB */
desktop_setMenuFocus:                           ; was sub_0B4FB
  ; ... (27 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_setMenuFocusAlt
; Address: 0x0B536 (84 insns)
; Called by: desktop_setMenuFocusPair
; Description: Alternative menu focus setter with additional state management.
; ---------------------------------------------------------------------------
; /* address: 0000:B536 */
desktop_setMenuFocusAlt:                        ; was sub_0B536
  ; ... (84 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleAppRelaunch
; Address: 0x0B711 (55 insns)
; Called by: desktop_handleMenuCommand, desktop_handleAppSwitch,
;           desktop_handleDeleteSort
; Description: Handles re-launching an application that was previously active.
; ---------------------------------------------------------------------------
; /* address: 0000:B711 */
desktop_handleAppRelaunch:                      ; was sub_0B711
  ; ... (55 instructions)
  ret

; ===========================================================================
; STATUS BAR / INFO DISPLAY (0x0B792 - 0x0BDF8)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_drawStatusLine
; Address: 0x0B792 (284 insns)
; Called by: desktop_handleMenuSelect, desktop_handleFileListInput,
;           desktop_drawMenuBar, desktop_main, desktop_handleMenuCommand
; Description: Draws the status/info line at the bottom of the screen.
;   Shows file count, total size, program associations, and help text.
;   This is a large function (284 insns) that handles multiple status
;   display modes.
; ---------------------------------------------------------------------------
; /* address: 0000:B792 */
desktop_drawStatusLine:                         ; was sub_0B792
  ; ... (284 instructions)
  ret

; ===========================================================================
; STARTUP / CONFIG LOAD (0x0BDF8 - 0x0C34F)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_initStartup
; Address: 0x0BDF8 (135 insns)
; Called by: desktop_main
; Description: Performs startup initialization for DESKTOP.PDM. This is the
;   critical first-run and config-loading function:
;   1. Clears state flags (0x5E6F, 0x5EBF, etc.)
;   2. Gets startup info via prguf_getStartupInfo
;   3. Reads initial module info
;   4. Reads command line parameters (checks for 'o' = old config,
;      'v' = verbose mode)
;   5. Loads DESKTOP.CFG via desktop_readDesktopConfig
;   6. Checks for first-run condition
;   7. If first run: shows "Is this the first time you have run DeskMate?"
;   8. Detects disk readiness and sound hardware
;   9. Loads tree configuration via desktop_loadTreeConfig
;   10. If no config exists, creates one via desktop_loadConfig
;   Related strings: "DeskTop", "Is this the first time you have run DeskMate?",
;   "Creating configuration file", "Cannot create the configuration file"
; ---------------------------------------------------------------------------
; /* address: 0000:BDF8 */
desktop_initStartup:                            ; was sub_0BDF8
  ; ... (135 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_loadConfigWrite
; Address: 0x0BF76 (19 insns)
; Called by: desktop_flushConfig, desktop_initStartup
; Description: Triggers a config write (save) operation when config is dirty.
; ---------------------------------------------------------------------------
; /* address: 0000:BF76 */
desktop_loadConfigWrite:                        ; was sub_0BF76
  ; ... (19 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_loadConfig
; Address: 0x0BF9E (229 insns)
; Called by: desktop_initStartup, desktop_loadConfigWrite
; Description: Loads the complete DESKTOP.CFG configuration file. Parses
;   all configuration sections including:
;   - View mode (files/tree/menus)
;   - Sort order
;   - Current drive and directory
;   - Icon positions and labels
;   - Menu definitions (up to the menu count limit)
;   - Network/TEN settings (TENSTAT.CFG, USER.CFG)
;   This is a large function (229 insns) that drives the entire config
;   restore process.
;   Related strings: "DESKTOP.CFG", "DMCONFIG", various section names
; ---------------------------------------------------------------------------
; /* address: 0000:BF9E */
desktop_loadConfig:                             ; was sub_0BF9E
  ; ... (229 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_main_stub
; Address: 0x0C22F (4 insns)
; Called by: __astart
; Description: MSC runtime stub that calls desktop_main. This is the C main()
;   function wrapper that the CRT startup code calls.
; ---------------------------------------------------------------------------
; /* address: 0000:C22F */
msc_main_stub:                                  ; was sub_0C22F
  ; calls desktop_main (sub_09B7C)
  ret

; ---------------------------------------------------------------------------
; desktop_initDriveConfig
; Address: 0x0C234 (18 insns)
; Called by: desktop_loadConfig
; Description: Initializes drive configuration from the loaded config data.
; ---------------------------------------------------------------------------
; /* address: 0000:C234 */
desktop_initDriveConfig:                        ; was sub_0C234
  ; ... (18 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_saveTreeConfig
; Address: 0x0C260 (31 insns)
; Called by: desktop_main, desktop_loadConfig
; Description: Saves directory tree state to the configuration.
; ---------------------------------------------------------------------------
; /* address: 0000:C260 */
desktop_saveTreeConfig:                         ; was sub_0C260
  ; ... (31 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_loadTreeConfig
; Address: 0x0C2B5 (65 insns)
; Called by: desktop_flushConfig, desktop_initStartup
; Description: Loads directory tree configuration from DESKTOP.CFG.
;   Reads tree expanded/collapsed states and directory paths.
;   Related strings: "TREE.CFG"
; ---------------------------------------------------------------------------
; /* address: 0000:C2B5 */
desktop_loadTreeConfig:                         ; was sub_0C2B5
  ; ... (65 instructions)
  ret

; ===========================================================================
; CONFIG SAVE / DRIVE INIT (0x0C34F - 0x0CA57)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_saveConfig
; Address: 0x0C34F (246 insns)
; Called by: desktop_processMenuDef, desktop_handleFormatDisk,
;           desktop_handleInstall, desktop_handleSaveConfig,
;           desktop_main, desktop_initStartup
; Description: Saves the complete DESKTOP.CFG configuration file. Writes
;   all sections: view mode, sort order, drive, directory, icons, menus,
;   network settings. This is the inverse of desktop_loadConfig.
;   Handles drive changes and tree structure updates during save.
; ---------------------------------------------------------------------------
; /* address: 0000:C34F */
desktop_saveConfig:                             ; was sub_0C34F
  ; ... (246 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_initDrive
; Address: 0x0C624 (116 insns)
; Called by: desktop_handleChangeDir, desktop_handleDeleteDirConfirm,
;           desktop_handleSortViewCmd, desktop_handleSortFiles,
;           desktop_launchAppFromMenu, desktop_loadConfig
; Description: Initializes a drive for use -- reads its directory structure,
;   sets up the tree view data, and refreshes the display.
; ---------------------------------------------------------------------------
; /* address: 0000:C624 */
desktop_initDrive:                              ; was sub_0C624
  ; ... (116 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_initDriveAlt
; Address: 0x0C74C (54 insns)
; Called by: desktop_saveConfig
; Description: Alternative drive initialization for config save context.
; ---------------------------------------------------------------------------
; /* address: 0000:C74C */
desktop_initDriveAlt:                           ; was sub_0C74C
  ; ... (54 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleMenuRedefine_alt
; Address: 0x0C7C6 (71 insns)
; Called by: desktop_handleRunFile
; Description: Alternative menu redefine handler for the Run File context.
; ---------------------------------------------------------------------------
; /* address: 0000:C7C6 */
desktop_handleMenuRedefine_alt:                 ; was sub_0C7C6
  ; ... (71 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_refreshAfterOp
; Address: 0x0C873 (19 insns)
; Called by: desktop_handleMenuCreate, desktop_handleMenuDef,
;           desktop_handleFormatDisk, desktop_handleDirExit,
;           desktop_handleDirChange, desktop_handleMenuAction,
;           desktop_handleInstall, desktop_handleSaveConfig
; Description: Refreshes the desktop display after a file/directory operation.
;   Re-launches the app viewer and calls desktop_handleCopyCommand.
; ---------------------------------------------------------------------------
; /* address: 0000:C873 */
desktop_refreshAfterOp:                         ; was sub_0C873
  ; ... (19 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleCopyCommand
; Address: 0x0C897 (22 insns)
; Called by: desktop_saveConfig, desktop_refreshAfterOp
; Description: Handles the file copy command dispatch.
; ---------------------------------------------------------------------------
; /* address: 0000:C897 */
desktop_handleCopyCommand:                      ; was sub_0C897
  ; ... (22 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDiskFormat
; Address: 0x0C8C3 (36 insns)
; Called by: (no callers recorded -- standalone handler)
; Description: Handles disk format via BIOS INT 13h.
; ---------------------------------------------------------------------------
; /* address: 0000:C8C3 */
desktop_handleDiskFormat:                       ; was sub_0C8C3
  ; ... (36 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleExitError
; Address: 0x0C90D (32 insns)
; Called by: desktop_main
; Description: Handles fatal exit errors. Shows an error message and
;   terminates the application cleanly.
; ---------------------------------------------------------------------------
; /* address: 0000:C90D */
desktop_handleExitError:                        ; was sub_0C90D
  ; ... (32 instructions)
  ret

; ===========================================================================
; VIEW STATE MACHINE (0x0C952 - 0x0CEFA)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_handleViewTree
; Address: 0x0C952 (93 insns)
; Called by: desktop_handleViewStateFiles
; Description: Handles the View > Tree (Ctrl+T) mode. Switches the display
;   to the directory tree view.
; ---------------------------------------------------------------------------
; /* address: 0000:C952 */
desktop_handleViewTree:                         ; was sub_0C952
  ; ... (93 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleViewStateFiles
; Address: 0x0CA57 (170 insns)
; Called by: desktop_main
; Description: Handles the View state machine for the Files view (Ctrl+F).
;   This is the main view mode dispatcher that implements the three-mode
;   state machine:
;     State 1: File list view (desktop_handleFileListInput)
;     State 2: Tree view (desktop_handleViewTree)
;     State 3: Sort/filter view (desktop_handleSortFiles)
;   Manages transitions between states based on keyboard input (Tab, Esc,
;   Ctrl+M/T/F).
; ---------------------------------------------------------------------------
; /* address: 0000:CA57 */
desktop_handleViewStateFiles:                   ; was sub_0CA57
  ; ... (170 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDisplayMenu
; Address: 0x0CC1F (16 insns)
; Called by: desktop_handleViewStateFiles
; Description: Handles the Display menu operation -- refreshes the file
;   list display with current filter settings.
; ---------------------------------------------------------------------------
; /* address: 0000:CC1F */
desktop_handleDisplayMenu:                      ; was sub_0CC1F
  ; ... (16 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleAppSwitch
; Address: 0x0CC4E (96 insns)
; Called by: desktop_handleViewTree, desktop_handleViewStateFiles
; Description: Handles switching between applications. Manages the app
;   task-switching mechanism when multiple PDMs are loaded.
;   Related strings: "Cannot switch to alternate task",
;   "Two non-DeskMate applications may not run at the same time"
; ---------------------------------------------------------------------------
; /* address: 0000:CC4E */
desktop_handleAppSwitch:                        ; was sub_0CC4E
  ; ... (96 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_handleDeleteSort
; Address: 0x0CD3B (26 insns)
; Called by: desktop_handleMenuSelect, desktop_handleFileListInput,
;           desktop_handleSortFiles, desktop_handleAppSwitch
; Description: Handles delete operation in the sort view context.
; ---------------------------------------------------------------------------
; /* address: 0000:CD3B */
desktop_handleDeleteSort:                       ; was sub_0CD3B
  ; ... (26 instructions)
  ret

; ---------------------------------------------------------------------------
; desktop_switchMenuView
; Address: 0x0CD86 (130 insns)
; Called by: desktop_handleViewTree, desktop_handleViewStateFiles,
;           desktop_handleAppSwitch, desktop_handleDeleteSort
; Description: Switches between menu view and file view modes. Manages
;   the complete view transition including tree refresh, menu bar update,
;   and status line update.
; ---------------------------------------------------------------------------
; /* address: 0000:CD86 */
desktop_switchMenuView:                         ; was sub_0CD86
  ; ... (130 instructions)
  ret

; ===========================================================================
; FORMAT / DISKCOPY DOS OPERATIONS (0x0CEFA - 0x0D370)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_execFormatCmd
; Address: 0x0CEFA (118 insns)
; Called by: desktop_handleDeleteDir
; Description: Executes FORMAT.COM or DISKCOPY.COM as a child process.
;   Saves/restores interrupt vectors (INT 21h AH=35h/25h), sets up the
;   execution environment, and shells out to the external DOS command.
;   Related strings: "FORMAT.COM", "DISKCOPY.COM", " /T:40 /N:9",
;   " /T:80 /N:9", " /F:360", " /F:720", "COMSPEC", " /V:"
; ---------------------------------------------------------------------------
; /* address: 0000:CEFA */
desktop_execFormatCmd:                          ; was sub_0CEFA
  ; ... (118 instructions - INT 21h AH=00h, 35h, 25h, 44h)
  ret

; ---------------------------------------------------------------------------
; desktop_setupExecBlock
; Address: 0x0D046 (9 insns)
; Called by: desktop_handleExitError
; Description: Sets up the DOS EXEC parameter block for running an
;   external program.
; ---------------------------------------------------------------------------
; /* address: 0000:D046 */
desktop_setupExecBlock:                         ; was sub_0D046
  ; ... (9 instructions)
  ret

; ===========================================================================
; MSC 5.x RUNTIME LIBRARY (0x0D370 - 0x0DAD4)
; ===========================================================================
;
; The following functions are part of the Microsoft C 5.x runtime library
; linked into DESKTOP.PDM. They provide memory management (malloc/free/
; realloc), string operations (strcpy, strlen, strcmp, memcpy), I/O
; buffering, and math support.
;
; Identification: The string "MS Run-Time Library - Copyright (c) 1987,
; Microsoft Corp" appears at 0x0E8A2, confirming MSC 5.x (1987).
; Runtime error messages appear at 0x1191A-0x119E5:
;   R6000 - stack overflow
;   R6001 - null pointer assignment
;   R6002 - floating point not loaded
;   R6003 - integer divide by 0
;   R6009 - not enough space for environment
; ===========================================================================

; ---------------------------------------------------------------------------
; msc_realloc
; Address: 0x0D370 (29 insns)
; Called by: msc_initHeap
; Description: MSC runtime realloc() -- reallocates a memory block.
;   Uses INT 21h AH=4Ah (resize memory block).
; ---------------------------------------------------------------------------
; /* address: 0000:D370 */
msc_realloc:                                    ; was sub_0D370
  ; INT 21h AH=4Ah
  ret

; ---------------------------------------------------------------------------
; msc_strcpy
; Address: 0x0D40A (30 insns)
; Called by: (18 callers -- heavily used utility)
; Description: MSC runtime strcpy() -- copies a null-terminated string.
; ---------------------------------------------------------------------------
; /* address: 0000:D40A */
msc_strcpy:                                     ; was sub_0D40A
  ; ... (30 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_strcat
; Address: 0x0D44A (26 insns)
; Called by: (32 callers -- most heavily called function)
; Description: MSC runtime strcat() -- concatenates two strings.
;   This is the single most-called function in the entire module
;   with 32 callers.
; ---------------------------------------------------------------------------
; /* address: 0000:D44A */
msc_strcat:                                     ; was sub_0D44A
  ; ... (26 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_strcmp
; Address: 0x0D47C (21 insns)
; Called by: (20 callers)
; Description: MSC runtime strcmp() -- compares two strings.
; ---------------------------------------------------------------------------
; /* address: 0000:D47C */
msc_strcmp:                                     ; was sub_0D47C
  ; ... (21 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_strlen
; Address: 0x0D4A8 (15 insns)
; Called by: (21 callers)
; Description: MSC runtime strlen() -- returns string length.
; ---------------------------------------------------------------------------
; /* address: 0000:D4A8 */
msc_strlen:                                     ; was sub_0D4A8
  ; ... (15 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_memcpy
; Address: 0x0D4C4 (24 insns)
; Called by: desktop_addFileEntry, desktop_getFileExtension,
;           desktop_playTone, desktop_getDiskCapacity,
;           desktop_shutdownSound, desktop_handleFileList
; Description: MSC runtime memcpy() -- copies a block of memory.
; ---------------------------------------------------------------------------
; /* address: 0000:D4C4 */
msc_memcpy:                                     ; was sub_0D4C4
  ; ... (24 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_memset
; Address: 0x0D526 (12 insns)
; Called by: desktop_handleRunApp, desktop_handleDiskInfo,
;           desktop_changeDrive, desktop_getDiskFormat,
;           desktop_getDriveType, desktop_buildTreeInfo,
;           desktop_getChainInfo, desktop_handleDiskFormatOp
; Description: MSC runtime memset() -- fills a block of memory.
; ---------------------------------------------------------------------------
; /* address: 0000:D526 */
msc_memset:                                     ; was sub_0D526
  ; ... (12 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_itoa
; Address: 0x0D540 (32 insns)
; Called by: desktop_getDriveLabel, desktop_handleVolumeLabel
; Description: MSC runtime itoa() / number-to-string conversion.
; ---------------------------------------------------------------------------
; /* address: 0000:D540 */
msc_itoa:                                       ; was sub_0D540
  ; INT 21h (DOS)
  ret

; ---------------------------------------------------------------------------
; msc_memcmp
; Address: 0x0D588 (17 insns)
; Called by: desktop_readTreeConfig, desktop_initTreeData,
;           desktop_loadConfig
; Description: MSC runtime memcmp() -- compares two memory blocks.
; ---------------------------------------------------------------------------
; /* address: 0000:D588 */
msc_memcmp:                                     ; was sub_0D588
  ; ... (17 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_toupper
; Address: 0x0D5A6 (24 insns)
; Called by: desktop_handleMenuSelect, desktop_getFileExtension,
;           desktop_getDiskCapacity, desktop_handleRenameFile,
;           desktop_handleMenuOp
; Description: MSC runtime toupper() -- converts char to uppercase.
; ---------------------------------------------------------------------------
; /* address: 0000:D5A6 */
msc_toupper:                                    ; was sub_0D5A6
  ; ... (24 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_stricmp
; Address: 0x0D5D0 (19 insns)
; Called by: desktop_processMenuDef, desktop_handleRunApp,
;           desktop_handleDiskInfo, desktop_handleFileList,
;           desktop_getChainInfo
; Description: MSC runtime stricmp() -- case-insensitive string compare.
; ---------------------------------------------------------------------------
; /* address: 0000:D5D0 */
msc_stricmp:                                    ; was sub_0D5D0
  ; ... (19 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_strncpy
; Address: 0x0D5F2 (45 insns)
; Called by: desktop_handleFileOp, desktop_handleFileList
; Description: MSC runtime strncpy() -- copies up to n characters.
; ---------------------------------------------------------------------------
; /* address: 0000:D5F2 */
msc_strncpy:                                    ; was sub_0D5F2
  ; ... (45 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_strchr
; Address: 0x0D64C (52 insns)
; Called by: desktop_handleInstall
; Description: MSC runtime strchr() -- finds first occurrence of a character.
; ---------------------------------------------------------------------------
; /* address: 0000:D64C */
msc_strchr:                                     ; was sub_0D64C
  ; ... (52 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_sprintf
; Address: 0x0D6F0 (19 insns)
; Called by: desktop_parseMenuEntry, desktop_writeMenuEntry,
;           desktop_handleAbout, msc_formatOutput, msc_formatOutput2
; Description: MSC runtime sprintf() -- formatted string output.
; ---------------------------------------------------------------------------
; /* address: 0000:D6F0 */
msc_sprintf:                                    ; was sub_0D6F0
  ; ... (19 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_strncmp
; Address: 0x0D718 (23 insns)
; Called by: desktop_handleFormatDisk, desktop_handleInstall,
;           desktop_handleAbout, desktop_getTreeDepth, desktop_getDriveStatus,
;           desktop_scanDriveList, desktop_handleRenameFile, (+ 3 more)
; Description: MSC runtime strncmp() -- compares up to n characters.
; ---------------------------------------------------------------------------
; /* address: 0000:D718 */
msc_strncmp:                                    ; was sub_0D718
  ; ... (23 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_strfill
; Address: 0x0D744 (23 insns)
; Called by: desktop_getMenuItemCount, desktop_addFileEntry,
;           desktop_handleMenuBarEvent, desktop_getMenuBarState,
;           desktop_drawStatusLine, desktop_loadConfig,
;           desktop_loadTreeConfig, desktop_saveConfig
; Description: MSC runtime -- fills a string buffer with a character.
;   Similar to memset but operates on near string pointers.
; ---------------------------------------------------------------------------
; /* address: 0000:D744 */
msc_strfill:                                    ; was sub_0D744
  ; ... (23 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_atoi
; Address: 0x0D772 (73 insns)
; Called by: desktop_traverseTree, desktop_traverseTreeAlt
; Description: MSC runtime atoi() -- converts string to integer.
; ---------------------------------------------------------------------------
; /* address: 0000:D772 */
msc_atoi:                                       ; was sub_0D772
  ; ... (73 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_ltoa
; Address: 0x0D818 (14 insns)
; Called by: desktop_traverseTree, desktop_traverseTreeAlt
; Description: MSC runtime ltoa() -- converts long integer to string.
; ---------------------------------------------------------------------------
; /* address: 0000:D818 */
msc_ltoa:                                       ; was sub_0D818
  ; ... (14 instructions)
  ret

; ---------------------------------------------------------------------------
; msc_sbrk
; Address: 0x0DAD4 (53 insns)
; Description: MSC runtime sbrk() -- extends the program's data segment.
;   Uses INT 21h AH=FFh (a non-standard DOS call, likely intercepted by
;   DESK.EXE to manage PDM memory within the DeskMate heap).
; ---------------------------------------------------------------------------
; /* address: 0000:DAD4 */
msc_sbrk:                                       ; was sub_0DAD4
  ; INT 21h AH=FFh (DeskMate-intercepted memory allocation)
  ret

; ---------------------------------------------------------------------------
; msc_heapGrow
; Address: 0x0DB42 (39 insns)
; Called by: msc_sbrk
; Description: MSC runtime heap growth -- expands the heap using
;   INT 21h AH=4Ah (resize memory block).
; ---------------------------------------------------------------------------
; /* address: 0000:DB42 */
msc_heapGrow:                                   ; was sub_0DB42
  ; INT 21h AH=4Ah
  ret

; ===========================================================================
; DESKMATE WINDOW CALLBACKS (0x0DB98 - 0x0DD09)
; ===========================================================================

; ---------------------------------------------------------------------------
; dm_getWindowInfo
; Address: 0x0DB98 (27 insns)
; Called by: desktop_main
; Description: Gets window information via INT E0h AX=0208h. Queries the
;   DeskMate shell for the current window dimensions and attributes.
;   Also calls INT E0h AX=0206h to set the window attribute.
;   Two INT E0h AX=0208h calls: first tries one window handle (0x3046/0x3042),
;   then falls back to another (0x3050).
; ---------------------------------------------------------------------------
; /* address: 0000:DB98 */
dm_getWindowInfo:                               ; was sub_0DB98
  push     es
  push     bx
  push     ds
  pop      es
  mov      ax, 0x208                           ; INT E0h AX=0208h (get window info)
  mov      dx, 0x3046                          ; window info buffer
  mov      bx, 0x3042                          ; window handle
  int      0xe0                                ; DeskMate API: get window info
  or       ax, ax
  jle      .try_alt_window
  ; ... sets window attribute flag, calls INT E0h AX=0206h
  pop      bx
  pop      es
  ret

; ---------------------------------------------------------------------------
; dm_setWindowAttribute
; Address: 0x0DBFA (28 insns)
; Called by: desktop_readDesktopConfig, desktop_main
; Description: Sets window UI attributes via INT E0h AX=0206h.
;   Also reads window info via INT E0h AX=0208h to determine window state.
; ---------------------------------------------------------------------------
; /* address: 0000:DBFA */
dm_setWindowAttribute:                          ; was sub_0DBFA
  push     es
  push     bx
  push     ds
  pop      es
  mov      dx, 0x3050                          ; attribute descriptor
  mov      bx, 0x304c                          ; attribute value
  mov      ax, 0x206                           ; INT E0h AX=0206h (set attribute)
  int      0xe0                                ; DeskMate API: set attribute
  ; ... checks result, reads window info, sets flag at 0x3056
  pop      bx
  pop      es
  ret

; ---------------------------------------------------------------------------
; dm_setCursorCallback
; Address: 0x0DC3C (69 insns)
; Called by: desktop_main, desktop_handleExitError
; Description: Sets the cursor callback function via INT E0h AX=0207h.
;   Registers a callback function that DESK.EXE calls to manage cursor
;   display within the DESKTOP.PDM window. Stores callback addresses
;   at 0x304C/0x3042.
; ---------------------------------------------------------------------------
; /* address: 0000:DC3C */
dm_setCursorCallback:                           ; was sub_0DC3C
  push     dx
  mov      dx, 0x3050                          ; callback descriptor
  mov      ax, 0x207                           ; INT E0h AX=0207h (cursor control)
  push     es
  push     ds
  pop      es
  int      0xe0                                ; DeskMate API: set cursor callback
  pop      es
  ; Store dummy callback pointers (0xDC5C = "mov ax,-1; retf")
  mov      ax, 0xdc5c
  mov      word ptr [0x304c], ax
  mov      word ptr [0x3042], ax
  mov      ax, cs
  mov      word ptr [0x304e], ax
  mov      word ptr [0x3044], ax
  pop      dx
  ret

; ===========================================================================
; DMGUF THUNKS (0x0DD09 - 0x0DD93)
; ===========================================================================
;
; Each of these is a 2-instruction function (typically mov + ret or similar)
; that serves as a thunk/stub to call into DMGUF.RES. The actual dispatch
; goes through a far call mechanism similar to the PRGUF thunks.
; See the DMGUF.RES THUNK TABLE at the top of this file for the complete
; mapping of addresses to function names.
; ===========================================================================

; ===========================================================================
; DESKMATE RESOURCE ALLOCATION (0x0DD99 - 0x0DE01)
; ===========================================================================

; ---------------------------------------------------------------------------
; dm_allocWindowResources
; Address: 0x0DD99 (57 insns)
; Called by: desktop_readDesktopConfig, desktop_handleMenuCommand,
;           desktop_handleAppRelease, desktop_handleDeleteSort
; Description: Allocates window resources via INT E0h. Calls three DeskMate
;   API services:
;   - INT E0h AX=0206h (set/load resource attribute)
;   - INT E0h AX=0700h (allocate memory)
;   - INT E0h AX=0207h (set cursor control)
;   This allocates memory for a window buffer and registers the cursor
;   handler for the allocated window.
; ---------------------------------------------------------------------------
; /* address: 0000:DD99 */
dm_allocWindowResources:                        ; was sub_0DD99
  ; ... (57 instructions - INT E0h x3)
  ret

; ===========================================================================
; DESKMATE FILE I/O (0x0DE01 - 0x0DED1)
; ===========================================================================

; ---------------------------------------------------------------------------
; dm_writeConfigFile
; Address: 0x0DE01 (98 insns)
; Called by: desktop_handleSaveConfig, desktop_handleFileCopy
; Description: Writes configuration data to a file via DeskMate-mediated
;   file I/O. Uses the standard DeskMate file I/O triplet:
;   1. INT E0h AX=0600h -- Open file (dm_file_open)
;   2. INT E0h AX=060Eh -- Initialize file handle (svc_060E)
;   3. INT E0h AX=0603h -- Write data (dm_file_write) x2
;   The function performs stack-based buffer management with CLI/STI
;   for atomic stack switching during the write. Handles both DeskMate-
;   mediated writes (via INT E0h AX=0603h) and direct writes as fallback.
; ---------------------------------------------------------------------------
; /* address: 0000:DE01 */
dm_writeConfigFile:                             ; was sub_0DE01
  push     bp
  mov      bp, sp
  push     ds
  push     es
  push     si
  push     di
  push     bx
  push     cx
  push     dx
  mov      ax, 0x600                           ; INT E0h AX=0600h
  int      0xe0                                ; DeskMate API: file open
  and      ax, 0x8000                          ; check success bit
  je       .fallback_write
  mov      dx, 0x3070
  push     ds
  pop      es
  mov      ax, 0x60e                           ; INT E0h AX=060Eh
  int      0xe0                                ; DeskMate API: init file handle
  ; ... (rest of function handles write and fallback)
  ret

; ===========================================================================
; PRGUF THUNKS (0x0DED1 - 0x0E10E)
; ===========================================================================
;
; Each of these functions is a 2-3 instruction thunk that loads a PRGUF
; function code into AX and jumps to the common dispatcher at loc_0DF49.
; The dispatcher resolves the PRGUF.RES entry point via a relocatable
; far call and dispatches to the appropriate PRGUF function.
;
; See the PRGUF.RES DISPATCH TABLE at the top of this file for the
; complete mapping of AX codes to function names.
; ===========================================================================

; ===========================================================================
; ABOUT DIALOG / EVENT DISPATCH (0x0E10E - 0x0E397)
; ===========================================================================

; ---------------------------------------------------------------------------
; desktop_showAboutDialog
; Address: 0x0E10E (193 insns)
; Called by: (no callers recorded -- top-level handler)
; Description: Shows the About DeskMate dialog. This is a large function
;   (193 insns) that:
;   1. Clears a dialog data buffer (15 entries x 2 bytes at 0x5EC0)
;   2. Queries loaded resource modules via prguf_getAppInfo (AX=0600h)
;   3. Builds version strings (e.g., "3.68") using desktop_intToStr
;   4. Enumerates all loaded resource modules (DESK.EXE, plus up to 15
;      .RES modules) and formats their version numbers
;   5. Creates a dialog window via prguf_createWindow
;   6. Enters a modal event loop, calling prguf_processDialog until
;      the user clicks CANCEL (result = 0xF5CA)
;   7. Closes the dialog and restores the paint state
;
;   Related strings: "About", "Version ", "Resources", "DESK.EXE      ",
;   " CANCEL ", "DeskMate Copyright 1984, 1990",
;   "Tandy Corporation, All Rights Reserved"
; ---------------------------------------------------------------------------
; /* address: 0000:E10E */
desktop_showAboutDialog:                        ; was sub_0E10E
  push     bp
  mov      bp, sp
  push     si
  push     di
  push     cx
  push     bx
  push     dx
  push     es
  push     ds
  pushf
  cld
  push     ds
  pop      es
  ; Clear dialog line pointer array (15 slots)
  mov      cx, 0xf
  lea      di, [0x5ec0]
  sub      ax, ax
  repne stosw
  mov      word ptr [0x38e8], 0                ; resource entry count
  ; Get host app info
  call     prguf_getAppInfo                     ; -> sub_0DEE3 (AX=0600h)
  and      ax, 0x8000
  jne      .has_app_info
  jmp      .build_dialog                       ; no app info, skip resource list
.has_app_info:
  ; Build version string buffer at 0x5A12
  lea      di, [0x5a12]
  mov      word ptr [0x5ec0], di               ; first line pointer
  lea      si, [0x309b]                        ; "Version " prefix
  call     desktop_copyStringSI                  ; -> sub_0E323
  call     prguf_getResVersion                   ; -> sub_0E379 (AX=060Dh)
  mov      word ptr [0x38c0], ax               ; store version word
  ; Format version: high byte = major, low byte = minor
  xchg     al, ah
  xor      ah, ah
  lea      bx, [0x3bac]                        ; version string buffer
  call     desktop_intToStr                      ; -> sub_0E307 (recursive int->str)
  mov      byte ptr [bx], 0x2e                 ; insert '.'
  inc      bx
  mov      ax, word ptr [0x38c0]
  xor      ah, ah
  call     desktop_intToStr                      ; -> sub_0E307
  ; ... (continues building resource version list)
  ; ... (modal dialog event loop)
  ret

; ---------------------------------------------------------------------------
; desktop_intToStr
; Address: 0x0E307 (15 insns)
; Called by: desktop_showAboutDialog, desktop_intToStr (recursive)
; Description: Converts an integer to a decimal string. Recursive algorithm:
;   divides by 10, recurses for quotient, then stores remainder + '0'.
;   Writes result to buffer pointed to by BX.
; ---------------------------------------------------------------------------
; /* address: 0000:E307 */
desktop_intToStr:                               ; was sub_0E307
  push     dx
  push     ax
  sub      dx, dx
  mov      cx, 0xa                             ; divisor = 10
  idiv     cx                                  ; ax = quotient, dx = remainder
  or       ax, ax
  je       .store_digit
  call     desktop_intToStr                      ; recurse for higher digits
.store_digit:
  add      dl, 0x30                            ; remainder + '0'
  mov      byte ptr [bx], dl
  inc      bx
  mov      byte ptr [bx], 0                   ; null terminate
  pop      ax
  pop      dx
  ret

; ---------------------------------------------------------------------------
; desktop_copyStringSI
; Address: 0x0E323 (7 insns)
; Called by: desktop_showAboutDialog (multiple calls)
; Description: Copies a null-terminated string from DS:SI to ES:DI.
;   Simple LODSB/STOSB loop. Used extensively by the About dialog builder
;   to concatenate strings into the dialog buffer.
; ---------------------------------------------------------------------------
; /* address: 0000:E323 */
desktop_copyStringSI:                           ; was sub_0E323
  lodsb
  or       al, al
  je       .done
  stosb
  jmp      desktop_copyStringSI
.done:
  mov      byte ptr [di], 0                    ; null terminate dest
  ret

; ---------------------------------------------------------------------------
; desktop_strlenSI
; Address: 0x0E32F (49 insns -- includes INT E0h dispatch stubs)
; Called by: desktop_showAboutDialog
; Description: Counts the length of a null-terminated string at DS:SI.
;   Returns length in AX.
;
;   NOTE: The code at 0x0E340-0x0E372 contains three INT E0h dispatch
;   stubs (loc_0E340, loc_0E34E, loc_0E35E) that are NOT part of this
;   function but are located in the same code region. These are the
;   generic DeskMate API dispatch wrappers that all PRGUF and service
;   thunks jump to.
; ---------------------------------------------------------------------------
; /* address: 0000:E32F */
desktop_strlenSI:                               ; was sub_0E32F
  push     si
  push     dx
  sub      dx, dx
.count_loop:
  lodsb
  or       al, al
  je       .done
  inc      dx
  jmp      .count_loop
.done:
  mov      ax, dx
  pop      dx
  pop      si
  ret

; ---------------------------------------------------------------------------
; dm_dispatchAPI_simple
; Address: 0x0E340 (unlabeled -- loc_0E340)
; Description: DeskMate INT E0h dispatch wrapper (no extra parameters).
;   Called by PRGUF thunks that pass only AX. Sets ES=DS, executes
;   INT E0h, restores ES.
; ---------------------------------------------------------------------------
; /* address: 0000:E340 */
; loc_0E340:                                    ; INT E0h dispatch (AX only)
;   push     bp
;   mov      bp, sp
;   add      bp, 4
;   push     es
;   push     ds
;   pop      es
;   int      0xe0                              ; DeskMate API call
;   pop      es
;   pop      bp
;   ret

; ---------------------------------------------------------------------------
; dm_dispatchAPI_withDI
; Address: 0x0E34E (unlabeled -- loc_0E34E)
; Description: DeskMate INT E0h dispatch wrapper with DI parameter.
;   Sets DI from [bp+4], ES=DS, executes INT E0h.
; ---------------------------------------------------------------------------
; /* address: 0000:E34E */
; loc_0E34E:                                    ; INT E0h dispatch (AX + DI)

; ---------------------------------------------------------------------------
; dm_dispatchAPI_withDXBX
; Address: 0x0E35E (unlabeled -- loc_0E35E)
; Description: DeskMate INT E0h dispatch wrapper with DX and BX parameters.
;   Sets DX from [bp+4], BX from [bp+6], ES=DS, executes INT E0h.
; ---------------------------------------------------------------------------
; /* address: 0000:E35E */
; loc_0E35E:                                    ; INT E0h dispatch (AX + DX + BX)

; ===========================================================================
; PRGUF EXTENDED THUNKS (0x0E373 - 0x0E397)
; ===========================================================================

; ---------------------------------------------------------------------------
; prguf_searchApp
; Address: 0x0E373 (2 insns)
; Called by: desktop_showAboutDialog
; Description: PRGUF thunk for AX=060Ah -- search/enumerate loaded apps.
; ---------------------------------------------------------------------------
; /* address: 0000:E373 */
prguf_searchApp:                                ; was sub_0E373
  mov      ax, 0x60a
  jmp      dm_dispatchAPI_simple                ; -> loc_0E340

; ---------------------------------------------------------------------------
; prguf_getResVersion
; Address: 0x0E379 (2 insns)
; Called by: desktop_showAboutDialog
; Description: PRGUF thunk for AX=060Dh -- get resource module version.
; ---------------------------------------------------------------------------
; /* address: 0000:E379 */
prguf_getResVersion:                            ; was sub_0E379
  mov      ax, 0x60d
  jmp      dm_dispatchAPI_simple                ; -> loc_0E340

; ---------------------------------------------------------------------------
; prguf_loadResourceModule
; Address: 0x0E37F (2 insns)
; Called by: desktop_registerWithPRGUF (sub_0DF3B)
; Description: Loads PRGUF resource module via AX=20D6h. Called during
;   startup to register DESKTOP.PDM with the PRGUF host services.
; ---------------------------------------------------------------------------
; /* address: 0000:E37F */
prguf_loadResourceModuleThunk:                  ; was sub_0E37F
  mov      ax, 0x20d6
  jmp      loc_0DF49                           ; PRGUF dispatcher

; ---------------------------------------------------------------------------
; prguf_unloadResourceModule
; Address: 0x0E385 (2 insns)
; Called by: desktop_unregisterFromPRGUF (sub_0DF42)
; Description: Unloads PRGUF resource module via AX=20D7h. Called during
;   shutdown to deregister DESKTOP.PDM.
; ---------------------------------------------------------------------------
; /* address: 0000:E385 */
prguf_unloadResourceModuleThunk:                ; was sub_0E385
  mov      ax, 0x20d7
  jmp      loc_0DF49

; ---------------------------------------------------------------------------
; prguf_allocMemoryThunk
; Address: 0x0E38B (2 insns)
; Called by: dm_allocWindowResources
; Description: Allocates memory via PRGUF AX=2102h.
; ---------------------------------------------------------------------------
; /* address: 0000:E38B */
prguf_allocMemoryThunk:                         ; was sub_0E38B
  mov      ax, 0x2102
  jmp      loc_0DF49

; ---------------------------------------------------------------------------
; prguf_getAppHandleThunk
; Address: 0x0E391 (2 insns)
; Called by: desktop_handleMenuCommandExt (sub_0E0D9)
; Description: Gets application handle via PRGUF AX=210Eh.
; ---------------------------------------------------------------------------
; /* address: 0000:E391 */
prguf_getAppHandleThunk:                        ; was sub_0E391
  mov      ax, 0x210e
  jmp      loc_0DF49

; ---------------------------------------------------------------------------
; prguf_releaseAppHandleThunk
; Address: 0x0E397 (2 insns)
; Called by: desktop_handleMenuCommandExt (sub_0E0D9)
; Description: Releases application handle via PRGUF AX=210Fh.
; ---------------------------------------------------------------------------
; /* address: 0000:E397 */
prguf_releaseAppHandleThunk:                    ; was sub_0E397
  mov      ax, 0x210f
  jmp      loc_0DF49

; ===========================================================================
; MSC 5.x CRT STARTUP (0x0E4CE)
; ===========================================================================

; ---------------------------------------------------------------------------
; __astart
; Address: 0x0E4CE (158 insns)
; Description: Microsoft C 5.x runtime startup code. This is the MZ entry
;   point that DOS loads and jumps to. It performs:
;   1. Checks DOS version >= 2.0 (INT 21h AH=30h)
;   2. If version < 2.0: terminates via INT 20h
;   3. Initializes SS:SP from relocation data
;   4. Sets up the C runtime environment (PSP, environment block, heap)
;   5. Calls msc_main_stub (sub_0C22F) which calls desktop_main (sub_09B7C)
;   6. On return: exits via INT 21h AH=4Ch
;
;   Runtime error handler at 0x0E4F6/0x0E4FE handles startup failures
;   with exit code 0xFF.
; ---------------------------------------------------------------------------
; /* address: 0E4C:000E */
__astart:
  mov      ah, 0x30
  int      0x21                                ; INT 21h AH=30h: get DOS version
  cmp      al, 2
  jae      .dos_ok
  int      0x20                                ; INT 20h: terminate (DOS 1.x)
.dos_ok:
  mov      di, 0xe57                           ; [RELOC] -- segment value
  mov      si, word ptr [2]                    ; top of available memory (from PSP)
  sub      si, di                              ; available paragraphs
  cmp      si, 0x1000                          ; cap at 64KB
  jb       .size_ok
  mov      si, 0x1000
.size_ok:
  cli
  mov      ss, di                              ; set stack segment
  add      sp, 0x5ffe                          ; set stack pointer
  sti
  ; ... (continues with heap setup, environment init, calls msc_main_stub)
  ; On return:
  ; mov      ax, 0x4cff
  ; int      0x21                              ; INT 21h AH=4Ch: exit with code 0xFF

; ===========================================================================
; GLOBAL VARIABLE MAP (partial)
; ===========================================================================
;
; Address    Type    Name                      Description
; --------   ------  ------------------------  ---------------------------------
; 0x0543     byte    g_altDriveFlag            Alternate drive selection flag
; 0x05B5     byte    g_firstRunFlag1           First run indicator 1
; 0x05B6     byte    g_firstRunFlag2           First run indicator 2
; 0x05B9     byte    g_prevSortOrder           Previous sort order
; 0x05BA     byte    g_sortOrder               Current sort order
; 0x05BD0    byte    g_configDirty             Config needs saving flag
; 0x16C0     byte    g_configLoaded            Config file loaded flag
; 0x16C1     byte    g_configValid             Config data valid flag
; 0x16C2     byte    g_configSaving            Config save in progress
; 0x2E56     byte    g_hasTreeView             Tree view available
; 0x2E6E     byte    g_driveListActive         Drive list mode active
; 0x2E6F     byte    g_currentSortField        Current sort field ID
; 0x2E70     word    g_heapTopPara             Top of heap (paragraphs)
; 0x2932     word    g_desktopTitleY           Desktop title Y position
; 0x2934     word    g_filePanelTitleY         File panel title Y position
; 0x294E     ---     g_appRegistrationBlock    PRGUF app registration data
; 0x3042     word    g_callbackAddrLow         Cursor callback addr (low)
; 0x3044     word    g_callbackAddrHigh        Cursor callback addr (high)
; 0x3046     ---     g_windowInfoBuf           Window info buffer (0x0208h)
; 0x304C     word    g_attrValueLow            Attribute value (low)
; 0x304E     word    g_attrValueHigh           Attribute value (high)
; 0x3050     ---     g_windowDescriptor        Window descriptor for INT E0h
; 0x3056     byte    g_windowVisible           Window visible flag
; 0x3057     word    g_searchState             DOS file search state
; 0x306E     word    g_writeCount              Config write byte count
; 0x3076     dword   g_prguFuncPtr             PRGUF function pointer (far)
; 0x307A     ---     g_cursorDescriptor        Cursor callback descriptor
; 0x3080     word    g_prguResult              PRGUF call result
; 0x3088     ---     g_versionDelimiter        Version string delimiter "."
; 0x309B     ---     g_versionPrefix           "Version " prefix string
; 0x3130     byte    g_resourceCount           Loaded resource count
; 0x313B     word    g_dialogWidth             About dialog width
; 0x3367     ---     g_configFilePath          Config file path data
; 0x3388     ---     g_spaceDelimiter          Space delimiter string
; 0x38C0     word    g_tempResult              Temporary result value
; 0x38E8     word    g_resourceEntryCount      Resource enumeration count
; 0x3AEA     byte    g_appInitialized          App fully initialized flag
; 0x3BAC     ---     g_versionStrBuf           Version string format buffer
; 0x3BC0     byte    g_startupMode             Startup mode byte
; 0x3BC1     byte    g_viewMode                Current view mode (0/1/2)
; 0x3C6C     word    g_configDataPtr           Pointer to config data buffer
; 0x3C6E     byte    g_menuViewActive          Menu view active flag
; 0x3C70     word    g_aboutResourcePtr        About dialog resource pointer
; 0x3C79     byte    g_networkEnabled          Network/TEN enabled flag
; 0x3E7E     ---     g_menuDataBuf             Menu data buffer (passed to PRGUF)
; 0x4620     byte    g_configExistsFlag        DESKTOP.CFG exists on disk
; 0x4895     byte    g_viewState               View state machine state (1/2/3)
; 0x48DA     byte    g_diskType                Detected disk type
; 0x49F6     byte    g_treeLoaded              Directory tree data loaded
; 0x49FC     byte    g_networkLoginOk          Network login status
; 0x4A02     byte    g_savedViewMode           Saved view mode for restore
; 0x4A06     word    g_searchExtState          Extended search state
; 0x5A12     ---     g_aboutDialogBuf          About dialog text buffer
; 0x5BD0     byte    g_configDirtyFlag         Config dirty (needs save)
; 0x5E6F     byte    g_configModified          Config modified since load
; 0x5E70     word    g_soundCapability         Sound hardware capability
; 0x5E72     word    g_pendingFileOp           Pending file operation code
; 0x5E74     word    g_windowFrameX            Window frame X coordinate
; 0x5E76     word    g_windowFrameY            Window frame Y coordinate
; 0x5E78     word    g_windowFrameW            Window frame width
; 0x5E7A     word    g_windowFrameH            Window frame height
; 0x5EBC     word    g_availableMemory         Available memory (paragraphs)
; 0x5EBF     byte    g_startupComplete         Startup initialization complete
; 0x5EC0     ---     g_aboutLinePointers       About dialog line ptr array [15]
; 0x5EE2     ---     g_menuStructure           Menu structure data (PRGUF)
; 0x5F30     word    g_savedWindowAttr         Saved window attribute
; 0x5F36     ---     g_driveListBuf            Drive list display buffer
; 0x5F5A     ---     g_treeLabels              Tree label text buffer
;
; ===========================================================================
; APPLICATION ICON TABLE
; ===========================================================================
;
; The following icon-to-PDM mappings are defined in the data segment,
; with display names and associated .PDM filenames:
;
; Icon Name       Display Name    PDM File         Addr
; --------------- --------------- ---------------- ------
; autoconfig      Teach Me        PLAY.PDM         0xEBD2
; learn           (learn mode)    PLAY.PDM         0xEC07
; month           MONTH           CALENDAR.PDM     0xEC3C
; text            TEXT            TEXT.PDM          0xEC70
; filer           FILER           FILER.PDM        0xECA6
; address         ADDRESS         ADDRESS.PDM      0xECDB
; worksheet       WORKSHEET       WRKSHEET.PDM     0xED10
; corkboard       CORKBOARD       (internal)       0xED45
; draw            DRAW            DRAW.PDM         0xED79
; telecom         TELECOM         TELECOM.PDM      0xEDAF
; calendar        CALENDAR        CALENDAR.PDM     0xEDE4
; phone           PHONE           (internal)       0xEE19
; programs        PROGRAMS        (submenu)        0xEE4D
; pclink          PC-LINK         PC_LINK.PDM      0xEE83
; others          OTHERS          (submenu)        0xEEB8
; to do           TO DO           (internal)       0xEEED
; hangman         HANGMAN         HANGMAN.PDM      0xEF21
; form setup      FORM SETUP      FORMSET.PDM      0xEF57
;
; Special names used in the About/Info dialogs:
; "QUICK LOAD"     0x10DC6
; "TEACH ME!"      0x10DD1
; "INFO CNTR"      0x10E8C     -> INFOCNTR.PDM
; "ORGANIZER"      0x10E97
;
; Video mode identifiers (used for display detection):
; "1000CGA"        0x116F2     Tandy 1000 CGA mode
; "DDGAEGA"        0x116FA     DGA/EGA mode
; "HERCPLANTC16TC4" 0x11702    Hercules/Plantronics/TC16/TC4
; "MCGAEGA"        0x11716     MCGA/EGA mode
; "LREST256TC40H"  0x1171E     Low-res/256-color/TC40H modes
;
; ===========================================================================
; MENU STRUCTURE
; ===========================================================================
;
; The DeskMate desktop has 7 top-level menus:
;
; Menu #   Title        Items
; ------   ----------   ------------------------------------------------
; 1        DeskMate     (not user-accessible -- shell control)
; 2        File         Get Info, Run, Copy, Delete, Rename,
;                       Update Screen (Ctrl+U), Exit (Esc), About
; 3        Directory    Create, Change, Delete
; 4        Disk         Format, Diskcopy, Disk Info
; 5        View         Menus (Ctrl+M), Tree (Ctrl+T), Files (Ctrl+F)
; 6        Sort by      Name, Type, Date, Size
; 7        Desktop      Create, Delete, Redefine, Display,
;                       Remove, Move, Install, Create Quick Load
;
; ===========================================================================
; ERROR MESSAGE TABLE
; ===========================================================================
;
; The following error messages are stored in the data segment. Each is
; associated with an error code returned by DOS or DeskMate operations:
;
; Code  Address   Message
; ----  --------  -------------------------------------------------------
;  --   0x10549   "Error"
;  --   0x10552   "Menu must be given a title."
;  --   0x10573   "Invalid data file extension."
;  --   0x105A0   "Invalid directory name."
;  --   0x105BF   "Invalid file or directory name."
;  --   0x105EC   "Invalid program name."
;  --   0x10611   "Invalid disk drive specified."
;  --   0x1063E   "File was not found."
;  --   0x1065D   "Invalid file name."
;  --   0x10679   "Path was not found."
;  --   0x10697   "Invalid directory or file already exists."
;  --   0x106C8   "Access is denied for this function."
;  --   0x106EC   "Cannot remove current or root directory."
;  --   0x10724   "Disk is full."
;  --   0x1073D   "Invalid directory."
;  --   0x10755   "Directory already exists."
;  --   0x1076F   "Directory is not empty or access is denied."
;  --   0x1079C   "Cannot create directory."
;  --   0x107BD   "Insufficient memory."
;  --   0x107D3   "Cannot write file."
;  --   0x107F4   "Filename within path."
;  --   0x1081A   "Wildcard character within path."
;  --   0x10844   "Filenames are the same."
;  --   0x10869   "Invalid character in directory or filename."
;  --   0x108A8   "Invalid extension."
;  --   0x108C7   "Devices are not the same."
;  --   0x108EC   "Invalid path."
;  --   0x10907   "Cannot switch to alternate task."
;  --   0x10934   "Two non-DeskMate applications may not run at the same time."
;  --   0x10975   "File is in use."
;  --   0x1098D   "Cannot delete this file."
;  --   0x109AD   "Duplicate menu title."
;  --   0x109D4   "Could not sign in - DeskMate will exit."
;  --   0x10A04   "File already exists."
;  --   0x10A1B   "Could not find new application on floppy disk."
;  --   0x10A54   "Pathname is too long."
;  --   0x10A72   "Disk is not in the drive."
;  --   0x10A95   "New application was not added to the Desktop. Maximum..."
;
; ===========================================================================
; END OF ANNOTATED DISASSEMBLY
; ===========================================================================
