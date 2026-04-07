; ========================================================================
; WRKSHEET.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987), Medium Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; WRKSHEET.PDM is the spreadsheet application for DeskMate 3.05.
; It provides a full-featured spreadsheet with cell editing, formula
; evaluation (including all standard math functions), cell formatting,
; row/column operations, printing, and file I/O in .WKS format.
;
; The spreadsheet grid supports up to 99 rows and 26 columns (A-Z).
; Cells can contain numeric values, text labels, or formulas.
; Formulas support arithmetic operators (+, -, *, /), parentheses,
; cell references (e.g. A1, B2), ranges (A1:B5), and built-in
; functions: ABS, ATN, COS, EXP, INT, LOG, SGN, SIN, SQR, TAN,
; CMT (comment), MAX, MIN, SUM, AVG, RMT (remote).
;
; The application uses a software floating-point library (custom
; 4-byte packed BCD/binary format) for all numeric operations.
; No x87 FPU instructions are used. The formula parser and evaluator
; are entirely self-contained within segment 0000.
;
; DM89 imports: PRGUF (Program User Functions -- DeskMate UI library)
;               DMGUF (optional, loaded conditionally)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 59,590 bytes
; Load image: 59,078 bytes (after header)
; DM89 entry point: 0CC5:0000 (MSC 5.x CRT startup)
; SS:SP = 0EAC:1B58
;
; Segment Map (6 segments, 15 relocations):
;   seg_0000  0x0CC50 bytes  CODE   Worksheet application code + PRGUF thunks
;                                    + formula parser/evaluator + FP math library
;   seg_0CC5  0x000A0 bytes  CODE   MSC 5.x CRT startup + DeskMate host stubs
;   seg_0CCF  0x00040 bytes  DATA   DGROUP fixup area (MSC CRT copyright string)
;   seg_0CD3  0x01390 bytes  DATA   String tables, menu definitions, format strings,
;                                    function name table, dialog templates
;   seg_0E0C  0x00A00 bytes  DATA   Formula work area, cell buffers, print config
;   seg_0EAC  0x01B58 bytes  STACK  Stack segment
;
; Medium memory model: multiple code segments, DGROUP at 0CCF.
;
; DM flags: 0x0101 (standard PDM module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Global Variables (selected, offsets relative to DGROUP seg_0CCF):
;   [0x008D]  g_menuEnable_file     - Menu enable flag: File menu items
;   [0x0098]  g_menuEnable_edit     - Menu enable flag: Edit menu items
;   [0x00A3]  g_menuEnable_save     - Menu enable flag: Save/Save As
;   [0x00AE]  g_menuEnable_print    - Menu enable flag: Print
;   [0x00B9]  g_menuEnable_cols     - Menu enable flag: Column operations
;   [0x00C4]  g_menuEnable_rows     - Menu enable flag: Row operations
;   [0x00CF]  g_menuEnable_formula  - Menu enable flag: Formula bar
;   [0x00DA]  g_menuEnable_format   - Menu enable flag: Format menu
;   [0x00E5]  g_menuEnable_options  - Menu enable flag: Options menu
;   [0x00F0]  g_menuEnable_search   - Menu enable flag: Search
;   [0x00FB]  g_menuEnable_goto     - Menu enable flag: Go To
;   [0x0106]  g_menuEnable_recalc   - Menu enable flag: Recalculate
;   [0x0111]  g_colorMode           - Color mode flag (1=color, 0=mono)
;   [0x0127]  g_menuEnable_colWidth - Menu enable flag: Column Width
;   [0x0132]  g_menuEnable_insert   - Menu enable flag: Insert
;   [0x013D]  g_menuEnable_delete   - Menu enable flag: Delete
;   [0x0148]  g_menuEnable_clear    - Menu enable flag: Clear
;   [0x0153]  g_menuEnable_selectAll - Menu enable flag: Select All
;   [0x015E]  g_menuEnable_find     - Menu enable flag: Find
;   [0x0169]  g_menuEnable_findLabel - Menu enable flag: Find Label
;   [0x0174]  g_menuEnable_sort     - Menu enable flag: Sort
;   [0x017F]  g_menuEnable_exit     - Menu enable flag: Exit
;   [0x018A]  g_menuEnable_about    - Menu enable flag: About
;   [0x0195]  g_menuEnable_input    - Menu enable flag: Input/Edit mode
;   [0x0197]  g_stringId_WKS        - String resource ID for ".WKS" extension
;   [0x01A0]  g_menuEnable_run      - Menu enable flag: Run
;   [0x01A2]  g_stringId_untitled   - String resource ID for untitled
;   [0x01AB]  g_menuEnable_startText - Menu enable flag: Start Text
;   [0x01B6]  g_menuEnable_pageSetup - Menu enable flag: Page Setup
;   [0x01C1]  g_menuEnable_cellRef  - Menu enable flag: Cell Reference
;   [0x01CC]  g_menuEnable_merge    - Menu enable flag: Merge
;   [0x01CE]  g_stringId_filter     - String resource ID for file filter
;   [0x0B42]  g_heapSize            - Heap size (top of memory)
;   [0x0B44]  g_stackBase           - Stack base pointer
;   [0x0B46]  g_exitFunc            - Exit function pointer (set to _exit)
;   [0x0B48]  g_stackTop            - Stack top pointer
;   [0x0BB9]  g_envSegment          - Environment segment (PSP)
;   [0x0BE4]  g_prgufEntry_lo       - PRGUF far-call entry point (offset)
;   [0x0BE6]  g_prgufEntry_hi       - PRGUF far-call entry point (segment)
;   [0x0BE8]  g_prgufName           - PRGUF resource name string
;   [0x0BEE]  g_dmgufEntry_lo       - DMGUF far-call entry point (offset)
;   [0x0BF0]  g_dmgufEntry_hi       - DMGUF far-call entry point (segment)
;   [0x0BF2]  g_dmgufName           - DMGUF resource name string
;   [0x0BF8]  g_activeResource      - Active resource flag (1=PRGUF, 0=DMGUF)
;   [0x0BFB]  g_savedReturn_lo      - Saved return address (low)
;   [0x0BFD]  g_savedReturn_hi      - Saved return address (high)
;   [0x0C02]  g_resourceNameCmp     - 8-byte resource name comparison buffer
;   [0x0C04]  g_loadResName_prguf   - Resource name for PRGUF load
;   [0x0C0A]  g_dmgufDispatch       - DMGUF dispatch far pointer
;   [0x0C0E]  g_dmgufResName        - DMGUF resource name string
;   [0x0C14]  g_dispatchResult      - Last dispatch result code
;   [0x0C1C]  g_dotSeparator        - "." string for version formatting
;   [0x0C2F]  g_versionPrefix       - Version prefix string
;   [0x0CA6]  g_dialogActive        - Dialog active flag
;   [0x0CC1]  g_cellEditActive      - Cell editing in progress flag
;   [0x0CC4]  g_sheetCount          - Number of sheets/worksheets
;   [0x0CCA]  g_titleBarWidth1      - Title bar width parameter 1
;   [0x0CCF]  g_sheetNamePtr        - Pointer to current sheet name
;   [0x0CD2]  g_titleBarWidth2      - Title bar width parameter 2
;   [0x0CD7]  g_windowTitlePtr      - Window title string pointer
;   [0x0CFF]  g_filePathBuf         - File path buffer for open/save
;   [0x0D02]  g_fileOpenMode        - File open mode (0=new, 5/6=existing)
;   [0x0D06]  g_fileArgIndex        - File argument index from command line
;   [0x0D62]  g_fpDispatchTable     - FP math dispatch table (function ptrs)
;   [0x0DD8]  g_fpCallbackPtr_lo    - FP callback far pointer (offset)
;   [0x0DDA]  g_fpCallbackPtr_hi    - FP callback far pointer (segment)
;   [0x0DDC]  g_fpTempBuf           - FP temporary buffer (8 bytes)
;   [0x0DEA]  g_fpWorkArea          - FP work area start
;   [0x0F5A]  g_fpAccumPtr          - Pointer to FP accumulator
;   [0x1044]  g_fpSignFlag          - FP sign flag for current operation
;   [0x1045]  g_fpScratch1          - FP scratch buffer 1 (8 bytes)
;   [0x104D]  g_fpScratch2          - FP scratch buffer 2 (8 bytes)
;   [0x1055]  g_fpScratch3          - FP scratch buffer 3 (8 bytes)
;   [0x10A0]  g_fpFlags             - FP operation flags
;   [0x10A2]  g_fpSignSave          - FP saved sign byte
;   [0x1130]  g_fpDivSign1          - FP division sign byte 1
;   [0x1131]  g_fpDivSign2          - FP division sign byte 2
;   [0x1184]  g_fpZeroBuf           - FP zero constant buffer (8 bytes)
;   [0x1278]  g_fpErrorHandler      - FP error handler far pointer
;   [0x13D8]  g_fpOverflowFlag      - FP overflow/error flag
;   [0x1424]  g_cellAccumBuf        - Cell value accumulator buffer
;   [0x1818]  g_spacePadStr         - Space padding string for display
;   [0x181E]  g_emptyVersionStr     - Empty version string
;   [0x1824]  g_sheetNameSuffix     - Sheet name suffix string
;   [0x19D6]  g_bssStart            - Start of BSS area (zeroed at startup)
;   [0x19F0]  g_currentRow          - Current row number (1-based)
;   [0x19F6]  g_lastResult          - Last operation result / version code
;   [0x19FC]  g_sheetIndex          - Current sheet/entry index
;   [0x19FE]  g_filenameBuf         - Filename buffer for current file
;   [0x1A2C]  g_statusLineBuf       - Status line display buffer
;   [0x1A46]  g_cellValueBuf        - Cell value string buffer
;   [0x1A4A]  g_displayRows         - Number of displayable rows
;   [0x1A50]  g_windowNameBuf       - Window name buffer
;   [0x1A8A]  g_cellArrayBase       - Base pointer for cell array
;   [0x1A8C]  g_cellDataBuf         - Cell data buffer pointer
;   [0x1A8E]  g_workspaceSize       - Workspace memory size
;   [0x1A90]  g_cellMemBase         - Cell memory base address
;   [0x1A92]  g_visibleColumns      - Number of visible columns (default 0x14=20)
;   [0x1A94]  g_versionStrBuf       - Version string buffer
;   [0x1AAA]  g_totalMemory         - Total available memory
;   [0x1AAC]  g_currentCol          - Current column number (1-based)
;   [0x1AAE]  g_formulaInputBuf     - Formula input buffer
;   [0x1AE0]  g_cellDisplayBuf      - Cell display formatting buffer
;   [0x1B06]  g_sheetListPtr        - Pointer into sheet list
;   [0x1B0E]  g_cellRefBuf          - Cell reference string buffer
;   [0x1B5C]  g_scrollOffsetX       - Horizontal scroll offset
;   [0x1B61]  g_mergeEnabled        - Merge feature enabled flag
;   [0x1BB0]  g_currentColAbs       - Current column (absolute, for grid)
;   [0x1BB8]  g_editMode            - Edit mode (-1=none, 4=cell edit)
;   [0x1BBC]  g_sheetListBuf        - Sheet list display buffer
;   [0x1BBA]  g_scrollOffsetY       - Vertical scroll offset
;   [0x1D74]  g_lastMemTop          - Last known memory top
;   [0x1D76]  g_totalRows           - Total rows in current sheet
;   [0x1D78]  g_gridDirty           - Grid needs redraw flag
;   [0x1D7A]  g_calcWorkspace       - Calculated workspace size
;   [0x1D7E]  g_prevCellIndex       - Previously selected cell index (-1=none)
;   [0x1D90]  g_sheetPtrArray       - Array of 15 sheet entry pointers
;   [0x1DB8]  g_stateFlags          - Bit-packed state flags:
;                                      bit 0: grid valid
;                                      bit 1: file modified
;                                      bit 2: cell has data
;                                      bit 4: needs title refresh
;                                      bit 7: column width changed
;                                      bit 8: new file loaded
;                                      bit 13: recalc pending
;   [0x1DBA]  g_maxVisibleCol       - Maximum visible column number (default 7)
;   [0x1DC0]  g_savedRowForNav      - Saved row for navigation
;   [0x1DD0]  g_bssEnd              - End of BSS area
;
; Cell Structure (pointed to by cell array entries):
;   +0x00   cell data pointer (word)
;   +0x02   cell flags/type (byte):
;            bit 4: cell is protected/locked
;            bits 0-3: cell type (0=empty, 1=number, 2=text, 3=formula, 4=error)
;   +0x04   cell format code (word)
;   +0x06   cell value (4 bytes, packed FP format)
;   +0x0A   cell display string pointer (word)
;   +0x0C   cell formula string pointer (word)
;
; Cell Array Entry (10 bytes per cell, stored in g_cellArrayBase):
;   +0x00   pointer to cell data block (word)
;   +0x02   pointer to edit buffer (word)
;   +0x04   edit buffer size (word)
;   +0x06   display width (word)
;   +0x08   column index (word, 1=active)
;
; Floating-Point Format (4 bytes, custom packed binary):
;   The FP library uses an 8-byte IEEE-like format internally
;   but stores cell values in a 4-byte packed representation:
;   bytes [0-1]: mantissa low
;   bytes [2-3]: exponent + sign (bit 15=sign, bits 7-14=exponent)
;   The exponent is biased by 0x3800 relative to IEEE 754 double.
;
; Formula Token Types (byte codes in compiled formula):
;   0x0A   cell reference (row:col packed as ah:al + offset)
;   0x1A   row range start
;   0x1B   column range start
;   0x1F   range sum/function
;   0x19+  function codes (ABS=0x10, SIN=0x11, COS=0x12, etc.)
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Worksheet Application Functions (segment 0000) ---
;
; Address   Name                           Size  Description
; -------   ----                           ----  -----------
; 0000:0010 wrksheet_initResources          133  Initialize resources, load PRGUF, set up menus
; 0000:0095 wrksheet_main                   288  _main() - init, open file, main event loop
; 0000:01B5 wrksheet_initCellArray          245  Initialize cell array with 5 edit fields
; 0000:02AA wrksheet_initWorkspace          189  Set up workspace, memory, columns, display
; 0000:0367 wrksheet_dispatchEvent          427  Main event dispatcher (key/menu/mouse/window)
; 0000:0512 wrksheet_handleMenuCommand      892  Menu command dispatcher (File/Edit/Cells/Search/Options)
; 0000:088E wrksheet_handleNewFile          167  Handle File > New command
; 0000:0935 wrksheet_handleKeyInput         446  Handle keyboard input in cell editing mode
; 0000:0AF3 wrksheet_handleDeleteKey         17  Handle Del key (clear cell contents)
; 0000:0B04 wrksheet_handleDeleteCommand    226  Handle Edit > Delete (clear cell/range)
; 0000:0BE6 wrksheet_handleEditEnter        265  Handle Enter key in cell edit mode
; 0000:0CEF wrksheet_handleCopyCommand      268  Handle Edit > Copy command
; 0000:0DFB wrksheet_handleCutCommand       259  Handle Edit > Cut command
; 0000:0EFE wrksheet_handlePasteCommand     222  Handle Edit > Paste command
; 0000:0FDC wrksheet_handleFillDown         222  Handle Edit > Fill Down command
; 0000:10BA wrksheet_handleFillRight        180  Handle Edit > Fill Right command
; 0000:116E wrksheet_handleSearchCommand    136  Handle Search > Find command
; 0000:11F6 wrksheet_handleGotoCommand      204  Handle Search > Go To command
; 0000:12C2 wrksheet_handleSortCommand      582  Handle Options > Sort command
; 0000:1508 wrksheet_handleFileError        110  Handle file operation error, show message
; 0000:1576 wrksheet_parseColumnLetter      106  Parse column letter (A-Z) from string
; 0000:15E0 wrksheet_handleFormatCommand    325  Handle Format > Cell Format command
; 0000:1725 wrksheet_initWindowMetrics       53  Initialize window size metrics
; 0000:175A wrksheet_refreshDisplay          56  Refresh display: update view, scroll, title
; 0000:1792 wrksheet_handleResize           156  Handle window resize event
; 0000:182E wrksheet_handlePrintCommand     305  Handle File > Print command
; 0000:195F wrksheet_printMainLoop          256  Main print loop - iterate rows and print
; 0000:1A5F wrksheet_printRowData           175  Print a single row of cell data
; 0000:1B0E wrksheet_printHeader             58  Print column header line
; 0000:1B48 wrksheet_printCellValue          50  Print a single cell value
; 0000:1B7A wrksheet_printFormattedCell     120  Print a formatted cell with width
; 0000:1BF2 wrksheet_printSetupDialog       422  Print Setup dialog handler
; 0000:1D98 wrksheet_formatCellRef          204  Format a cell reference (e.g. "A1", "B12")
; 0000:1E64 wrksheet_editCellFormula        544  Cell formula editor (parse and compile)
; 0000:2084 wrksheet_convertCellToFP         32  Convert cell value bytes to FP format
; 0000:20A4 wrksheet_evalCellFormula        671  Evaluate a compiled cell formula
; 0000:2343 wrksheet_resizeGrid             116  Resize grid dimensions (add/remove rows/cols)
; 0000:23B7 wrksheet_recalcSheet            123  Recalculate all cells in the sheet
; 0000:2432 wrksheet_handleScrollEvent      200  Handle scroll bar / arrow key navigation
; 0000:24FA wrksheet_getCellDataPtr         139  Get pointer to cell data for row:col
; 0000:2585 wrksheet_getCellDataRange        93  Get cell data pointer with range check
; 0000:25E2 wrksheet_readCellValue          110  Read cell value into buffer
; 0000:2650 wrksheet_writeCellText          119  Write text string to a cell
; 0000:26C7 wrksheet_writeCellFormula       282  Write formula string to a cell
; 0000:27E1 wrksheet_printSetMargins         77  Set print margins
; 0000:282E wrksheet_clearCellRange          44  Clear a range of cells
; 0000:285A wrksheet_fileOpenDialog        1148  File Open dialog handler
; 0000:2CD6 wrksheet_fileSaveDialog        1480  File Save / Save As dialog handler
; 0000:329E wrksheet_handleInputDialog      129  Handle input dialog (generic text input)
; 0000:331F wrksheet_handleOptionsDialog    945  Handle Options menu dialog
; 0000:36D0 wrksheet_printSetPageLen        150  Set print page length
; 0000:3766 wrksheet_getMaxRow               35  Get maximum row number in current sheet
; 0000:3789 wrksheet_handleMergeCommand     123  Handle File > Merge command
; 0000:3804 wrksheet_allocCellBlock          81  Allocate a new cell data block
; 0000:3855 wrksheet_handleCellEdit         742  Handle direct cell editing (keystroke entry)
; 0000:3B3B wrksheet_drawStatusBar          735  Draw the formula/status bar
; 0000:3E1A wrksheet_handleSaveCheck         97  Check if file needs saving before close
; 0000:3E7B wrksheet_handleFileIO           586  File I/O dispatcher (open, save, close)
; 0000:40C5 wrksheet_readWKSFile            397  Read .WKS file format into cell grid
; 0000:4252 wrksheet_setCellFormat_fill     116  Set cell format: fill pattern
; 0000:42C6 wrksheet_setCellFormat_align    139  Set cell format: alignment
; 0000:4351 wrksheet_buildColumnDisplay     533  Build column header display strings
; 0000:4566 wrksheet_formatNumberString      89  Format a number for display
; 0000:45BF wrksheet_handleColWidthDialog   381  Handle Column Width dialog
; 0000:473C wrksheet_handleInsertDelete     692  Handle Insert/Delete row/column operations
; 0000:49F0 wrksheet_moveBlockData          918  Move block of cell data (for insert/delete)
; 0000:4D86 wrksheet_adjustReferences       381  Adjust cell references after insert/delete
; 0000:4F03 wrksheet_recalcAfterEdit         51  Recalculate cells affected by edit
; 0000:4F36 wrksheet_evalFormulaTree         97  Evaluate formula expression tree (top-level)
; 0000:4F97 wrksheet_evalFunction            65  Evaluate a built-in function (SIN, COS, etc.)
; 0000:4FD8 wrksheet_evalConstant            33  Load a numeric constant
; 0000:4FF9 wrksheet_evalNegate              39  Negate a value (unary minus)
; 0000:5020 wrksheet_evalPushValue           34  Push a value onto eval stack
; 0000:5042 wrksheet_evalArithmetic          95  Evaluate arithmetic (+, -, *, /)
; 0000:50A1 wrksheet_evalComparison         142  Evaluate comparison (<, >, =, <=, >=, <>)
; 0000:512F wrksheet_evalExponent            30  Evaluate exponentiation (^)
; 0000:514D wrksheet_evalMultiply            22  Evaluate multiply operator
; 0000:5163 wrksheet_evalBuiltinFunc         97  Evaluate built-in math function
; 0000:51C4 wrksheet_evalDivide              22  Evaluate divide operator
; 0000:51DA wrksheet_evalModulo              78  Evaluate modulo operator
; 0000:5228 wrksheet_evalTrue                14  Push TRUE constant
; 0000:5236 wrksheet_evalNot                 23  Evaluate logical NOT
; 0000:524D wrksheet_evalPercent             55  Evaluate percent operator (divide by 100)
; 0000:5284 wrksheet_evalParenExpr           19  Evaluate parenthesized expression
; 0000:5297 wrksheet_evalCellDeref           14  Dereference a cell reference
; 0000:52A5 wrksheet_evalRangeFunc           97  Evaluate range function (SUM, AVG, etc.)
; 0000:5306 wrksheet_evalConditional         81  Evaluate conditional expression
; 0000:5357 wrksheet_compileFormula         163  Compile formula string to bytecode
; 0000:53FA wrksheet_copyCellString          46  Copy cell string to buffer
; 0000:5428 wrksheet_appendCellChar          36  Append character to cell buffer
; 0000:544C wrksheet_formatCellForDisplay   140  Format cell value for display string
; 0000:54D8 wrksheet_updateCellDisplay      131  Update cell display after value change
; 0000:555B wrksheet_getCellType             20  Get cell type code
; 0000:556F wrksheet_setCellValue           204  Set cell value (number, text, or formula)
; 0000:563B wrksheet_setCellNumeric         295  Set a numeric value in a cell
; 0000:5762 wrksheet_setCellString          230  Set a string value in a cell
; 0000:5848 wrksheet_allocCellContents      523  Allocate memory for cell contents
; 0000:5A53 wrksheet_freeCellContents       116  Free cell contents memory
; 0000:5AC7 wrksheet_clearCellValue         129  Clear a cell's value to empty
; 0000:5B48 wrksheet_validateCellRef        160  Validate a cell reference is in bounds
; 0000:5BE8 wrksheet_getCellByRef            62  Get cell pointer from row:col reference
; 0000:5C26 wrksheet_getCellRange           117  Get cell pointer range (start:end)
; 0000:5C9B wrksheet_fileOperation          122  Execute file operation (open/save/close)
; 0000:5D15 wrksheet_getClipboardData        89  Get data from clipboard
; 0000:5D6E wrksheet_getColumnCount          70  Get current column count
; 0000:5DB4 wrksheet_adjustColumnView        53  Adjust column view after scroll
; 0000:5DE9 wrksheet_drawGridFrame           52  Draw the spreadsheet grid frame/borders
; 0000:5E1D wrksheet_setMenuStates          147  Set all menu item enable/disable states
; 0000:5EB0 wrksheet_updateTitleBar         519  Update title bar, status line, grid display
; 0000:60B7 wrksheet_drawCellIndicator       72  Draw current cell position indicator
; 0000:60FF wrksheet_drawCellContents       141  Draw cell contents in the formula bar
; 0000:618C wrksheet_moveCursorTo            90  Move cursor to specified row:col
; 0000:61E6 wrksheet_moveCursorHome          87  Move cursor to home position (A1)
; 0000:623D wrksheet_redrawStatusArea        73  Redraw the status/info display area
; 0000:6286 wrksheet_getDataSegment          33  Return current DS (utility)
; 0000:62A7 wrksheet_openWKSFile            252  Open a .WKS worksheet file
; 0000:63A3 wrksheet_saveWKSFile            222  Save current worksheet as .WKS file
; 0000:6481 wrksheet_saveAsWKSFile          337  Save As dialog for .WKS file
; 0000:65D2 wrksheet_createNewFile          546  Create a new empty worksheet file
; 0000:67F4 wrksheet_closeFileCleanup       239  Close file and clean up resources
; 0000:68E3 wrksheet_closeAndPrompt         173  Close file with save prompt
; 0000:6990 wrksheet_handleNavigateKey      402  Handle navigation key (arrows, PgUp/PgDn, etc.)
; 0000:6B22 wrksheet_renderCellGrid        1244  Render the visible cell grid area
; 0000:6FFE wrksheet_formatDisplayCell       86  Format a single cell for grid display
; 0000:7054 wrksheet_handleRecalcCommand    176  Handle recalculate command
; 0000:7104 wrksheet_recalcAllCells         271  Recalculate all formula cells
; 0000:7213 wrksheet_handleAboutDialog      118  Handle Help > About dialog
; 0000:7289 wrksheet_triggerRecalc           15  Trigger recalculation of sheet
; 0000:7298 wrksheet_renderSingleCell       148  Render a single cell in the grid
; 0000:732C wrksheet_copyCellRange          142  Copy a range of cells to clipboard
; 0000:73BA wrksheet_getVisibleCols          23  Get number of visible columns
; 0000:73D1 wrksheet_setGridDimensions       97  Set grid display dimensions
; 0000:7432 wrksheet_checkRecalcNeeded       45  Check if recalculation is needed
; 0000:745F wrksheet_parseFormulaInput      143  Parse formula input string
; 0000:74EE wrksheet_validateFormula         58  Validate a formula expression
; 0000:7528 wrksheet_drawCell                46  Draw a single cell at given position
; 0000:7556 wrksheet_drawFormattedCell      414  Draw a formatted cell with value
; 0000:76F4 wrksheet_enterEditMode          342  Enter cell edit mode
; 0000:784A wrksheet_exitEditMode            61  Exit cell edit mode
; 0000:7887 wrksheet_checkMemory            162  Check available memory, allocate if needed
; 0000:7929 wrksheet_copyRange              108  Copy cell range data
; 0000:7995 wrksheet_lookupCell              98  Look up cell data at row:col
; 0000:79F7 wrksheet_callWithParams         226  Generic function call dispatcher (with params)
; 0000:7AD9 wrksheet_setCellAndRedraw        85  Set cell value and redraw
; 0000:7B2E wrksheet_cellRefToString         73  Convert cell ref to "A1" format string
; 0000:7B77 wrksheet_showMessageBox          44  Show a message box dialog
; 0000:7BA3 wrksheet_handleFormulaBar        62  Handle formula bar interaction
; 0000:7BE1 wrksheet_handleSearchFind       145  Handle Search > Find Label/Number
; 0000:7C72 wrksheet_handleFormulaKeys      614  Handle formula editing keystrokes
; 0000:7ED8 wrksheet_editFormulaInPlace     814  Edit formula in place (cell editor)
; 0000:8206 wrksheet_commitCellEdit          52  Commit cell edit and update grid
; 0000:823A wrksheet_drawGridContents      1620  Draw all visible cell contents in grid
; 0000:888E wrksheet_scrollAndRedraw        295  Scroll grid and redraw visible area
; 0000:89B5 wrksheet_printCallback          150  Print callback for grid rendering
; 0000:8A4B wrksheet_writeWKSFormat         342  Write .WKS file format to disk
; 0000:8BA1 wrksheet_writeWKSHeader         166  Write .WKS file header block
; 0000:8C47 wrksheet_getMaxColumn            76  Get maximum column with data
; 0000:8C93 wrksheet_getMaxRow2              69  Get maximum row with data (alternate)
; 0000:8CD8 wrksheet_saveCurrentState        92  Save current cursor/scroll state
; 0000:8D34 wrksheet_restoreAndRedraw       156  Restore state and redraw grid
; 0000:8DD0 wrksheet_rebuildGridView        502  Rebuild entire grid view from data
; 0000:8FC6 wrksheet_writeFileBlock          51  Write a data block to file
; 0000:8FF9 wrksheet_closeFileHandle         78  Close file handle (via DOS INT 21h wrapper)
;
; --- MSC 5.x C Runtime Stubs (inlined) ---
;
; 0000:9047 wrksheet_dosFileClose            15  Close file via indirect call
; 0000:9056 wrksheet_dosFileWrite           196  Write to file via INT 21h AH=40h
; 0000:911A wrksheet_dosExit                 23  Exit process via INT 21h AH=4Ch
; 0000:9131 wrksheet_dosOpenAndWrite         69  Open file and write data
; 0000:9176 wrksheet_dosSetVector            25  Set interrupt vector via INT 21h AH=25h
; 0000:918F wrksheet_dosCallIndirect         15  Call function via indirect far pointer
; 0000:919E wrksheet_dosGetVector            20  Get interrupt vector via INT 21h AH=35h
; 0000:91B2 wrksheet_crtSetargv             268  Parse command line arguments (__setargv)
;
; --- DeskMate Resource Loading and PRGUF/DMGUF Dispatch ---
;
; 0000:92BE wrksheet_unloadDmguf            169  Unload DMGUF resource via INT E0h AX=0207h
;
; (Inline code at 0x921A-0x92BD handles PRGUF/DMGUF resource load/unload:
;  0x921A: Execute PRGUF resource (INT E0h AX=0208h)
;  0x9232: Load PRGUF/DMGUF (INT E0h AX=0206h)
;  0x9243: Try DMGUF if PRGUF fails (INT E0h AX=0208h)
;  0x9256: Unload active resource (INT E0h AX=0207h)
;  0x927C: Load DMGUF resource (INT E0h AX=0206h))
;
; --- PRGUF Far-Call Dispatch Engine ---
;
; The PRGUF dispatch engine is a pair of trampolines at 0x92E6 and 0x932A.
; Each thunk loads AX with a function code and jumps to the appropriate
; dispatcher. The dispatcher saves/restores the return address, sets up
; ES=DS, and performs an indirect far call through [0xBE4] (PRGUF) or
; [0xBEE] (DMGUF). Function codes 0x01-0x38 go to PRGUF dispatcher
; (loc_092E6), codes 0xA9-0xBF go to DMGUF dispatcher (loc_0932A).
;
; 0000:92E6 (entry)     prguf_dispatch    PRGUF far-call dispatcher
; 0000:932A (entry)     dmguf_dispatch    DMGUF far-call dispatcher
;
; --- PRGUF Thunks (via prguf_dispatch at 0x92E6) ---
;
; 0000:9367 prguf_getCellValue               6  PRGUF func 0x01: get cell value
; 0000:936D prguf_setCellValue               6  PRGUF func 0x02: set cell value
; 0000:9373 prguf_getCellFormat              6  PRGUF func 0x04: get cell format
; 0000:9379 prguf_setCellFormat              6  PRGUF func 0x05: set cell format
; 0000:937F prguf_getCellInfo                6  PRGUF func 0x06: get cell info/attribute
;          +prguf_getCellExtInfo             6  PRGUF func 0x22: get extended cell info
;
; --- DMGUF Thunks (via dmguf_dispatch at 0x932A) ---
;
; 0000:938B dmguf_openFile                   6  DMGUF func 0xA9: open file
;          +dmguf_writeFile                  6  DMGUF func 0xAB: write file
; 0000:9397 dmguf_readFile                   6  DMGUF func 0xAC: read file
; 0000:939D dmguf_closeFile                  6  DMGUF func 0xAD: close file
; 0000:93A3 dmguf_setFileMode                6  DMGUF func 0xB1: set file mode
;          +dmguf_getFileStatus              6  DMGUF func 0xB3: get file status
; 0000:93AF dmguf_commitFile                 6  DMGUF func 0xB5: commit/flush file
;
; --- Resource Name Matching and Load/Unload (sub_093B5) ---
;
; 0000:93B5 wrksheet_loadImportedRes         94  Compare resource name, load PRGUF if match
;                                                Compares 8-byte name at [0xC02] with DS:SI,
;                                                loads resource via INT E0h AX=0206h,
;                                                yields via INT E0h AX=0700h,
;                                                unloads via INT E0h AX=0207h if loaded.
;
; 0000:9413 wrksheet_getReturnCode           10  Get return code from last operation
;
; --- PRGUF API Call Thunks (each: load AX, jmp sub_09465) ---
;
; 0000:941D prguf_validateField               6  PRGUF func 0x0501: validate field
; 0000:9423 prguf_getFieldInfo                6  PRGUF func 0x0401: get field info
; 0000:9429 prguf_setFieldInfo                6  PRGUF func 0x0402: set field info
;
; --- PRGUF Module Load/Unload Dispatcher ---
;
; 0000:942F wrksheet_loadPrgufModule         25  Load PRGUF module via INT E0h AX=0206h
; 0000:9448 wrksheet_unloadPrgufModule       22  Unload PRGUF module via INT E0h AX=0207h
; 0000:945E wrksheet_shutdownPrguf            7  Shutdown: unload PRGUF and cleanup
; 0000:9465 wrksheet_genericDispatch         40  Generic PRGUF/DMGUF dispatch (load AX, lcall)
;
; --- DeskMate Form Engine Thunks (each: load AX=20xxh, jmp sub_09465) ---
;
; 0000:948D dm_beginTransaction               6  DM form func 0x2006: begin transaction
; 0000:9493 dm_endTransaction                 6  DM form func 0x2007: end transaction
; 0000:9499 dm_getEvent                       6  DM form func 0x2013: get/dispatch event
; 0000:949F dm_putEvent                       6  DM form func 0x2015: put event back
; 0000:94A5 dm_closeSession                   6  DM form func 0x2016: close editing session
; 0000:94AB dm_refreshView                    6  DM form func 0x2017: refresh view
; 0000:94B1 dm_updateView                     6  DM form func 0x2018: update view display
; 0000:94B7 dm_setFormRow                     6  DM form func 0x201C: set form row content
; 0000:94BD dm_getFormRow                     6  DM form func 0x201D: get form row content
; 0000:94C3 dm_deleteFormRow                  6  DM form func 0x201F: delete form row
; 0000:94C9 dm_setRowMode_input               6  DM form func 0x2020: set row to input mode
; 0000:94CF dm_setRowMode_display             6  DM form func 0x2021: set row to display mode
; 0000:94D5 dm_setRowMode_reset               6  DM form func 0x2022: reset row mode
; 0000:94DB dm_setRowMode_locked              6  DM form func 0x2023: lock row (read-only)
; 0000:94E1 dm_setActiveWorkspace             6  DM form func 0x202E: set active workspace
; 0000:94E7 dm_getWorkspaceSize               6  DM form func 0x202F: get workspace size
; 0000:94ED dm_getCellMetric                  6  DM form func 0x2037: get cell metric
; 0000:94F3 dm_getCellPosition                6  DM form func 0x2039: get cell position
; 0000:94F9 dm_getWindowMetric                6  DM form func 0x203F: get window metric
; 0000:94FF dm_getFieldMetric                 6  DM form func 0x2041: get field metric
; 0000:9505 dm_setGridSize                    6  DM form func 0x2044: set grid size
; 0000:950B dm_getGridOffset                  6  DM form func 0x2049: get grid offset
; 0000:9511 dm_getRecordMetric                6  DM form func 0x204A: get record metric
; 0000:9517 dm_scrollGrid                     6  DM form func 0x2051: scroll grid
; 0000:951D dm_setCellContent                 6  DM form func 0x2052: set cell content
; 0000:9523 dm_getCellContent                 6  DM form func 0x2053: get cell content
; 0000:9529 dm_getCellState                   6  DM form func 0x2055: get cell state
; 0000:952F dm_setColumnFormat                6  DM form func 0x2066: set column format
; 0000:9535 dm_getColumnFormat                6  DM form func 0x2067: get column format
; 0000:953B dm_setColumnWidth                 6  DM form func 0x2068: set column width
; 0000:9541 dm_getColumnWidth                 6  DM form func 0x2069: get column width
; 0000:9547 dm_refreshTitleBar                6  DM form func 0x206A: refresh title bar
; 0000:954D dm_setWindowExtent                6  DM form func 0x206B: set window extent
; 0000:9553 dm_getRecordPosition              6  DM form func 0x206D: get record position
; 0000:9559 dm_setCellScrollMode              6  DM form func 0x206F: set cell scroll mode
;          +dm_getViewState                   6  DM form func 0x20A3: get view state
;          +dm_setViewState                   6  DM form func 0x20A4: set view state
;          +dm_setViewConfig                  6  DM form func 0x20A6: set view config
;          +dm_setWindowPos                   6  DM form func 0x20A9: set window position
;          +dm_getWindowPos                   6  DM form func 0x20AA: get window position
;          +dm_openPrintSession               6  DM form func 0x20AC: open print session
;
; 0000:9583 dm_setWindowTitle                 6  DM form func 0x20B9: set window title
; 0000:9589 dm_setWindowName                  6  DM form func 0x20BA: set window name
;          +dm_setWindowFlags                 6  DM form func 0x20BD: set window flags
;
; 0000:9595 dm_openFile                       6  DM form func 0x20E3: open file
; 0000:959B dm_closeFile                      6  DM form func 0x20E4: close file
; 0000:95A1 dm_saveFile                       6  DM form func 0x20E9: save/flush file
;          +dm_createFile                     6  DM form func 0x2100: create new file
;
; 0000:95AD dm_initSheet                      6  DM form func 0x2134: init sheet/grid
; 0000:95B3 wrksheet_checkPrintReady         63  Check if printer is ready (load resource)
;
; --- Formula Parser/Evaluator Engine ---
;
; 0000:95F2 wrksheet_formulaDispatch        559  Formula dispatch: parse, evaluate, display result
;                                                Handles sheet structure (names, versions),
;                                                calls into FP math library for arithmetic
;
; --- FP Math Helper Functions ---
;
; 0000:9821 fp_intToString                   28  Convert integer to decimal string (recursive)
; 0000:983D fp_copyString                    12  Copy null-terminated string (si->di)
; 0000:9849 fp_getStringLength               17  Get string length
; 0000:985A fp_paramHelper                   14  Parameter extraction helper
; 0000:9868 fp_getSheetFlags                  6  Get sheet configuration flags
; 0000:986E fp_setSheetEntry                  6  Set sheet entry pointer
; 0000:9874 fp_getVersion                     6  Get sheet version code
; 0000:987A fp_getVersionFull                 6  Get full version information
; 0000:9880 fp_initSheet                      6  Initialize sheet data
; 0000:9886 fp_nop                            1  No-operation (alignment)
; 0000:9887 fp_yield                          5  Cooperative yield (unused?)
; 0000:988C fp_setGridParams                  6  Set grid parameters
; 0000:9892 fp_savePrgufState                 6  Save PRGUF module state
; 0000:9898 fp_restorePrgufState              6  Restore PRGUF module state
; 0000:989E fp_resolveResource                6  Resolve resource function pointer
;
; --- Floating-Point Arithmetic Library ---
;
; 0000:98A4 fp_openFormulaContext              6  Open formula evaluation context
; 0000:98AA fp_closeFormulaContext           269  Close formula context, write results
; 0000:99B7 fp_parseNumericLiteral           42  Parse numeric literal from formula string
; 0000:99E1 fp_callResourceFunc             161  Call resource function with INT E0h
; 0000:9A82 fp_loadCellValue                128  Load a cell value into FP accumulator
; 0000:9B02 fp_checkOverflow                  7  Check for FP overflow
; 0000:9B09 fp_storeResult                  200  Store FP result to cell
; 0000:9BD1 fp_convertToDisplay              78  Convert FP value to display string
; 0000:9C1F fp_storeToCellBuf              157  Store FP value to cell buffer
; 0000:9CBC fp_dispatchOperation             55  Dispatch FP operation (add/sub/mul/div)
; 0000:9CF3 fp_evalTokenStream               60  Evaluate formula token stream
; 0000:9D2F fp_evalExpression               262  Evaluate expression with operator precedence
; 0000:9E35 fp_evalAdd                       24  Evaluate addition operator
; 0000:9E4D fp_evalSubtract                  24  Evaluate subtraction operator
; 0000:9E65 fp_evalMultiply2                 24  Evaluate multiplication operator
; 0000:9E7D fp_evalDivide2                   24  Evaluate division operator
; 0000:9E95 fp_evalPower                     24  Evaluate power/exponent operator
; 0000:9EAD fp_pushOperand                   46  Push operand onto evaluation stack
; 0000:9EDB fp_compareResult                 15  Compare FP result (set flags)
; 0000:9EEA fp_checkZero                      5  Check if FP value is zero
; 0000:9EEF fp_evalFunctionCall             182  Evaluate function call (SUM, AVG, etc.)
; 0000:9FA5 fp_evalAbsoluteRef               24  Evaluate absolute cell reference
; 0000:9FBD fp_getTokenByte                  33  Get next token byte from formula stream
; 0000:9FDE fp_opAdd                          9  FP operation: add
; 0000:9FE7 fp_opSubtract                    18  FP operation: subtract
; 0000:9FF9 fp_opMultiply                     9  FP operation: multiply
; 0000:A002 fp_opDivide                       9  FP operation: divide
; 0000:A00B fp_opPower                        9  FP operation: power
; 0000:A014 fp_opNegate                       9  FP operation: negate
; 0000:A01D fp_opCompare                     27  FP operation: compare
; 0000:A038 fp_opStore                       18  FP operation: store result
; 0000:A04A fp_handleError                  173  Handle FP error (overflow/underflow/div0)
; 0000:A0F7 fp_registerCallback              42  Register FP error callback handler
; 0000:A121 fp_copyDwordToTemp               22  Copy 4 bytes (dword) to temp buffer
; 0000:A137 fp_copyQwordToTemp               24  Copy 8 bytes (qword) to temp buffer
; 0000:A14F fp_pushStackFrame                15  Push FP stack frame
; 0000:A15E fp_unpackToIEEE                 128  Unpack 4-byte cell format to 8-byte IEEE-like
; 0000:A1DE fp_unpackToAccum                180  Unpack cell value to FP accumulator
; 0000:A292 fp_clearAccum                     8  Clear FP accumulator to zero
; 0000:A29A fp_addValues                     58  Add two FP values
; 0000:A2D4 fp_subtractValues                23  Subtract two FP values
; 0000:A2EB fp_multiplyCheck                 13  Check for multiply-by-zero shortcut
; 0000:A2F8 fp_addHelper                      5  Addition helper (operand routing)
; 0000:A2FD fp_subtractHelper                 5  Subtraction helper (operand routing)
; 0000:A302 fp_multiplyHelper                 5  Multiply helper (operand routing)
; 0000:A307 fp_divideValues                  32  Divide two FP values
; 0000:A327 fp_addRouted                      5  Routed addition
; 0000:A32C fp_divideRouted                  31  Routed division
; 0000:A34B fp_normalizeMantissa             53  Normalize FP mantissa
; 0000:A380 fp_addMantissa                  125  Add FP mantissas with alignment
; 0000:A3FD fp_checkResultSign               74  Check and set result sign
; 0000:A447 fp_initMultiply                  33  Initialize multiplication state
; 0000:A468 fp_multiplyMantissa              71  Multiply FP mantissas
; 0000:A4AF fp_multiplyShift                139  Shift and accumulate during multiply
; 0000:A53A fp_divideMantissa               161  Divide FP mantissas
; 0000:A5DB fp_roundResult                  302  Round FP result to precision
; 0000:A709 fp_setZero                       46  Set FP value to zero
; 0000:A737 fp_power                        345  Calculate power (x^y)
; 0000:A890 fp_returnZero                     4  Return zero value
; 0000:A894 fp_powerHelper                  149  Power function helper (recursive)
; 0000:A929 fp_copyValue                     35  Copy FP value (8 bytes si->di)
; 0000:A94C fp_swapValues                   308  Swap two FP values
; 0000:AA80 fp_absValue                      86  Absolute value of FP number
; 0000:AAD6 fp_integerPart                  126  Extract integer part of FP number
; 0000:AB54 fp_normalizeAndPack              99  Normalize and pack FP result
; 0000:ABB7 fp_shiftRight                   207  Shift FP mantissa right
; 0000:AC86 fp_shiftLeft                    132  Shift FP mantissa left
; 0000:AD0A fp_formatNumber                 479  Format FP number as string
; 0000:AEE9 fp_getSign                       24  Get sign of FP value
; 0000:AF01 fp_parseNumber                  184  Parse number string to FP value
; 0000:AFB9 fp_handleParseError              40  Handle number parse error
; 0000:AFE1 fp_sqrtValue                    212  Calculate square root
; 0000:B0B5 fp_transcendental               407  Transcendental function engine (sin/cos/etc.)
; 0000:B24C fp_taylorSeries                 261  Taylor series expansion for trig
; 0000:B351 fp_sinValue                      70  Calculate sine
; 0000:B397 fp_checkSmallAngle              25  Check for small angle approximation
; 0000:B3B0 fp_cosValue                     128  Calculate cosine
; 0000:B430 fp_expValue                     306  Calculate e^x (exponential)
; 0000:B562 fp_log2Value                     86  Calculate log base 2
; 0000:B5B8 fp_logValue                      84  Calculate natural log (ln)
; 0000:B60C fp_atnValue                      34  Calculate arctangent
; 0000:B62E fp_tanValue                      67  Calculate tangent
; 0000:B671 fp_printNumber                  306  Print FP number (for file output)
; 0000:B7A3 fp_printInteger                  41  Print integer part of number
; 0000:B7CC fp_printDecimal                 269  Print decimal part of number
; 0000:B8D9 fp_printExponent                 38  Print exponent part (scientific notation)
; 0000:B8FF fp_printFormatted               182  Print formatted number with precision
; 0000:B9B5 fp_printDispatch                 77  Print format dispatcher
; 0000:BA02 fp_outputDigit                   40  Output a single digit character
; 0000:BA2A fp_outputString                  70  Output a string to print buffer
; 0000:BA70 fp_getDigit                      19  Get next digit from mantissa
; 0000:BA83 fp_multiplyBy10                  20  Multiply FP value by 10
; 0000:BA97 fp_checkNegative                 10  Check if FP value is negative
; 0000:BAA1 fp_checkPositive                 10  Check if FP value is positive
; 0000:BAAB fp_setNegative                   16  Set FP value to negative
; 0000:BABB fp_setPositive                   16  Set FP value to positive
; 0000:BACB fp_copyToAccum                   25  Copy FP value to accumulator
; 0000:BAE4 fp_clearFlag                      4  Clear operation flag
; 0000:BAE8 fp_pushState                     11  Push FP state to stack
; 0000:BAF3 fp_popState                      11  Pop FP state from stack
; 0000:BAFE fp_incPrecision                   5  Increment precision counter
; 0000:BB03 fp_decPrecision                   4  Decrement precision counter
; 0000:BB07 fp_getExponent                   14  Get exponent from FP value
; 0000:BB15 fp_checkExponent                  5  Check exponent range
; 0000:BB1A fp_adjustExponent                18  Adjust exponent for operation
; 0000:BB2C fp_normalizeResult               69  Normalize FP result
; 0000:BB71 fp_compareMagnitude              54  Compare magnitude of two FP values
; 0000:BBA7 fp_divideByPower10               54  Divide by power of 10
; 0000:BBDD fp_multiplyByPower10             17  Multiply by power of 10
; 0000:BBEE fp_adjustScale                    9  Adjust scale factor
; 0000:BBF7 fp_formatDigits                  28  Format digit string
; 0000:BC13 fp_formatExponent                17  Format exponent string
; 0000:BC24 fp_finalizeFormat                48  Finalize number format string
; 0000:BC54 fp_checkOverflow2                 6  Check for overflow (alternate)
; 0000:BC5A fp_handleOverflow                15  Handle overflow condition
; 0000:BC69 fp_recursiveNorm                 46  Recursive normalization
; 0000:BC97 fp_roundAndPack                  42  Round and pack final result
; 0000:BCC1 fp_digitBuffer                   41  Digit buffer management
; 0000:BCEA fp_formatOutput                  92  Format output string
; 0000:BD46 fp_decimalToString              256  Convert decimal FP to string
; 0000:BE46 fp_longDivision                 358  Long division for string conversion
; 0000:BFAC fp_longMultiply                  36  Long multiply for string conversion
; 0000:BFD0 fp_openFileForWrite              38  Open file for writing
; 0000:BFF6 fp_flushAndClose                 34  Flush buffer and close file
; 0000:C018 fp_bufferWrite                  398  Buffered file write
; 0000:C1A6 fp_flushBuffer                   43  Flush write buffer to disk
; 0000:C1D1 fp_writeChar                     41  Write single character to buffer
; 0000:C1FA fp_allocBuffer                   66  Allocate file I/O buffer
;
; --- MSC 5.x C Runtime Library ---
;
; 0000:C23C msc_getenv                       18  Get environment variable
; 0000:C24E msc_malloc                       70  malloc() - allocate memory
; 0000:C294 msc_chkstk                       64  Stack overflow check (__chkstk)
; 0000:C2D4 msc_strcpy                       50  strcpy() - copy string
; 0000:C306 msc_strcmp                        68  strcmp() - compare strings (extended)
; 0000:C34A msc_strncmp_4                     4  strncmp() - compare first 4 chars
; 0000:C34E msc_strncmp                       64  strncmp() - compare n chars
; 0000:C38E msc_strlen                       28  strlen() - get string length
; 0000:C3AA msc_strncpy                      10  strncpy() - copy n chars (short)
; 0000:C3B4 msc_sprintf                     122  sprintf() - format string to buffer
; 0000:C42E msc_atoi                         42  atoi() - ASCII to integer
; 0000:C458 msc_itoa                         66  itoa() - integer to ASCII
; 0000:C49A msc_memcpy                       72  memcpy() - copy memory block
; 0000:C4E2 msc_memset                       46  memset() - fill memory
; 0000:C510 msc_free                         19  free() - deallocate memory
; 0000:C523 msc_printf_engine               227  Core printf formatting engine
; 0000:C606 msc_writeFormatted               58  Write formatted output
; 0000:C640 msc_outputChar                   34  Output single character (printf)
; 0000:C662 msc_formatNumber                212  Format number for printf
; 0000:C736 msc_formatString                110  Format string for printf
; 0000:C7A4 msc_padOutput                    86  Pad output with spaces/zeros
; 0000:C7FA msc_divmod10                    164  Division by 10 helper
; 0000:C89E msc_negate32                     52  Negate 32-bit value
; 0000:C8D2 msc_toupper                      39  toupper() with locale check
; 0000:C8F9 msc_tolower                      19  tolower() with locale check
; 0000:C90C msc_farCallDispatch             124  Far-call dispatcher with argument marshaling
; 0000:C988 msc_ldiv                        232  ldiv() - long division
; 0000:CA70 msc_lmod                         34  Long modulo
; 0000:CA92 msc_lmul                         53  lmul() - long multiply
; 0000:CAC7 msc_lshift                      102  Long left shift
; 0000:CB2D msc_lshift_helper                22  Shift helper
; 0000:CB43 msc_ladd                          9  Long add
; 0000:CB4C msc_lsub                         16  Long subtract
; 0000:CB5C msc_lcmp                         23  Long compare
; 0000:CB73 msc_ultoa                        58  ultoa() - unsigned long to string
; 0000:CBAD msc_ltoa                         44  ltoa() - long to string
; 0000:CBD9 msc_strtol                      119  strtol() - string to long
;
; --- CRT Startup (segment 0CC5) ---
;
; 0CC5:0000 start                           590  MSC 5.x CRT startup (_cstart)
;                                                - Checks DOS version >= 2.0
;                                                - Sets up SS:SP to seg_0CCF:1DCE
;                                                - Resizes memory block (INT 21h AH=4Ah)
;                                                - Zeroes BSS (0x19D6..0x1DD0)
;                                                - Parses command line (__setargv)
;                                                - Sets up environment (__setenvp)
;                                                - Sets exit func [0xB46] = _exit (0x911A)
;                                                - Calls sub_0CE9E (DM89 import resolver)
;
; CRT copyright string at 0CC5:00AA:
;   "MS Run-Time Library - Copyright (c) 1987, Microsoft Corp\x1e"
;
; 0CC5:009C (data)  DM89 import table:
;   Menu structure definition entries (30 entries):
;   Each entry: { menu_id(word), type(word), count(word), flags(byte),
;                 submenu_code(word) }
;   Menu IDs reference the string table in seg_0CD3.
;
; --- DM89 Import Table Resolver (sub_0CE9E, 6184 bytes) ---
;
; 0CC5:024E sub_0CE9E                      6184  DM89 import table resolver and dispatch.
;                                                This is the largest "function" in the binary
;                                                but is actually a data table containing DM89
;                                                import records. The disassembler interprets
;                                                the table entries as instructions. Each entry
;                                                is a packed record defining a menu item or
;                                                UI element with its string ID, type, position,
;                                                hotkey, and callback function code.
;
; ========================================================================
; STRING TABLE (segment 0CD3, selected entries decoded from raw bytes)
; ========================================================================
;
; The string table in seg_0CD3 contains all UI text. Strings are extracted
; from the raw disassembly where the disassembler has misinterpreted
; null-terminated ASCII as instructions. Key strings include:
;
; Offset  String
; ------  ------
; 0x02BC  "ST_0" (status text 0)
; 0x02C1  "ST_1"
; 0x02C6  "ST_2"
; 0x02CB  "ST_3"
; 0x02D0  "ST_4"
; 0x02D5  "ST_5"
; 0x02D8  "ST_6"
; 0x02DD  Menu item codes table (byte pairs):
;         0x1C=File, 0x21=Edit, 0x26=Cells, 0x2B=Search,
;         0x30=Options, 0x35=Print, 0x3A=Window, 0x41=BS (Backspace),
;         0x42=Tab, 0x10=ABS, 0x11=ATN, 0x12=ATN, 0x13=SQR,
;         0x14=COS, 0x15=EXP, 0x16=INT, 0x17=LOG, 0x18=SGN,
;         0x19=SIN, 0x1A=RMT, 0x1B=CMT, 0x1C=MAX, 0x1D=MIN,
;         0x1E=SUM, 0x1F=AVG
; 0x032D  "New"
; 0x0331  "Open..."
; 0x033E  "Save"
; 0x0343  "Save as..."
; 0x034E  "Merge..."
; 0x0358  "Page setup..."
; 0x0367  "Print..."
; 0x0371  "Exit          Esc"
; 0x0383  "Run..."
; 0x038B  "About..."
; 0x0395  "Cut          Shift+Del"
; 0x03AD  "Copy          Ctrl+Ins"
; 0x03C5  "Paste         Shift+Ins"
; 0x03DE  "Clear         Del"
; 0x03F1  "Select all"
; 0x03FC  "Column width..."
; 0x040E  "Insert column"
; 0x041C  "Delete column"
; 0x042A  "Insert row"
; 0x0435  "Delete row"
; 0x0440  "Calculate          Ctrl+C"
; 0x045B  "Formula...     Ctrl+F"
; 0x0471  "Start text     Ctrl+T"
; 0x0487  "End text       Ctrl+Q"
; 0x049D  "Find label..."
; 0x04AC  "Find number..."
; 0x04BB  "Find cell..."
; 0x04C8  "Find next          Ctrl+N"
; 0x04E3  "File"
; 0x04E8  "Edit"
; 0x04ED  "Pad"
; 0x04F1  "Cells"
; 0x04F7  "Search"
; 0x04FE  "Label :"
; 0x0507  "Find Label"
; 0x0512  "OK"
; 0x0515  "CANCEL"
; 0x051C  "Find Number"
; 0x0528  "Find Cell"
; 0x0533  "Column :"
; 0x053C  "Row :"
; 0x0542  "Edit Input"
; 0x054D  "Field Name :"
; 0x055A  "Field Value :"
; 0x0568  "Formula :"
; 0x0572  "Operators : +, -, *, /, !"
; 0x058C  "Functions:ABS,ATN,AVG,CMT,COS,EXP,INT,LOG,MAX,MIN,RMT,SGN,SIN,SQR,SUM,TAN"
; 0x05D9  "Formula Row      Column"
;
; ========================================================================
; INT E0h CALLS (DeskMate API)
; ========================================================================
;
; WRKSHEET.PDM makes 14 INT E0h calls using two service classes:
;
; AX=0206h  Load resource module (PRGUF or DMGUF)
;           Called in: wrksheet_loadPrgufModule (0x942F),
;                     wrksheet_loadImportedRes (0x93B5, 0x93F7),
;                     inline at 0x9232, 0x9286
;
; AX=0207h  Unload resource module
;           Called in: wrksheet_unloadPrgufModule (0x9448, 0x9452),
;                     wrksheet_unloadDmguf (0x92BE, 0x92C8),
;                     wrksheet_loadImportedRes (0x9411, 0x9414),
;                     inline at 0x9267
;
; AX=0208h  Execute resource function (call exported function)
;           Called in: inline at 0x9227, 0x9249, 0x929E, 0x92A7
;
; AX=0700h  Yield / cooperative multitasking tick
;           Called in: wrksheet_loadImportedRes (0x940B)
;
; Note: WRKSHEET.PDM does NOT use AH=06h (DeskMate file I/O). All file
; operations are performed directly via INT 21h (AH=3Eh close, AH=40h
; write) or through the PRGUF/DMGUF resource modules.
;
; ========================================================================
; INT 21h CALLS (DOS API)
; ========================================================================
;
; AH=25h  Set interrupt vector (CRT startup)
; AH=30h  Get DOS version (CRT startup)
; AH=35h  Get interrupt vector (CRT startup)
; AH=3Eh  Close file handle (wrksheet_dosFileClose)
; AH=40h  Write file (wrksheet_dosFileWrite)
; AH=44h  IOCTL - get device info (printer check)
; AH=48h  Allocate memory (CRT startup)
; AH=4Ah  Resize memory block (CRT startup)
; AH=4Ch  Exit process (wrksheet_dosExit)
;
; ========================================================================
; ARCHITECTURAL NOTES
; ========================================================================
;
; 1. Memory Model:
;    WRKSHEET.PDM uses MSC 5.x medium memory model with multiple code
;    segments but a single DGROUP for data. The main application code
;    is in seg_0000 (0x0CC50 bytes = ~51 KB). All application functions,
;    the formula evaluator, the FP math library, the PRGUF thunks, and
;    the C runtime are in this single code segment.
;
; 2. Formula Evaluation:
;    Formulas are compiled from infix notation to a bytecode token stream
;    (sub_05357 wrksheet_compileFormula). The evaluator (sub_04F36
;    wrksheet_evalFormulaTree) walks the token stream using a recursive
;    descent parser with operator precedence. Each operator and function
;    is handled by a dedicated thunk function.
;
; 3. Floating-Point Library:
;    The FP library (0x9A82-0xBFAC) is entirely software-based and uses
;    a custom 4-byte packed format for cell storage. Internally it uses
;    an 8-byte IEEE-like representation for calculations. The exponent
;    bias is 0x3800. Functions include all four arithmetic operations,
;    power, square root, trigonometric functions (via Taylor series),
;    logarithm, and exponential. The library handles overflow, underflow,
;    and division-by-zero gracefully.
;
; 4. Cell Storage:
;    Cells are stored in a flat array pointed to by g_cellArrayBase.
;    Each cell entry is 10 bytes (see Cell Array Entry structure above).
;    The worksheet supports 26 columns (A-Z) and up to 99 rows.
;    Cell contents are allocated dynamically via msc_malloc.
;
; 5. PRGUF/DMGUF Dual Resource System:
;    The application can use either PRGUF or DMGUF as its UI resource
;    library. It first tries to execute via PRGUF (INT E0h AX=0208h);
;    if that fails, it falls back to DMGUF. The g_activeResource flag
;    at [0xBF8] tracks which is currently loaded (1=PRGUF, 0=DMGUF).
;    The dispatch thunks at 0x92E6 (PRGUF) and 0x932A (DMGUF) route
;    calls to the appropriate resource based on the function code range.
;
; 6. Grid Rendering:
;    The grid is rendered by wrksheet_renderCellGrid (0x6B22, 1244 bytes)
;    and wrksheet_drawGridContents (0x823A, 1620 bytes). These are the
;    two largest application functions. The grid drawing code handles
;    column headers, row numbers, cell values with formatting, cursor
;    highlighting, and scroll position tracking.
;
; 7. File Format:
;    .WKS files are read/written by wrksheet_readWKSFile (0x40C5) and
;    wrksheet_writeWKSFormat (0x8A4B). The format stores cell data in
;    a row-major order with type tags, format codes, and values in the
;    custom 4-byte FP packed format.
;
; ========================================================================
; END OF ANNOTATION HEADER
; ========================================================================

; ========================================================================
; SEGMENT 0000 -- Main Application Code (0x0CC50 bytes)
; ========================================================================

; ---- wrksheet_initResources (sub_00010) ----
; Initialize all application resources: load PRGUF, set up menu structure,
; configure string IDs, set window size and title.
; Called from: wrksheet_main
; Parameters: none
; Returns: none
wrksheet_initResources:                         ; 0000:0010
  00010  55             push     bp
  00011  8bec           mov      bp, sp
  00013  83ec02         sub      sp, 2
  00016  56             push     si
  00017  be3075         mov      si, 0x7530             ; si = 30000 (memory request size)
  0001A  e83a94         call     wrksheet_loadPrgufModule ; Load PRGUF resource module
  0001D  40             inc      ax                      ; Check return: -1 = error
  0001E  750a           jne      .init_check_dmguf
  00020  b80100         mov      ax, 1                   ; Error code 1
  00023  50             push     ax
  00024  e8f390         call     wrksheet_handleFileError ; Show error and exit
  00027  83c402         add      sp, 2
.init_check_dmguf:
  0002A  e84f92         call     wrksheet_loadDmgufModule ; Load DMGUF resource module
  0002D  40             inc      ax
  0002E  750d           jne      .init_set_menu
  00030  e82b94         call     wrksheet_shutdownPrguf   ; Cleanup if DMGUF load fails
  00033  b80100         mov      ax, 1
  00036  50             push     ax
  00037  e8e090         call     wrksheet_handleFileError
  0003A  83c402         add      sp, 2
.init_set_menu:
  0003D  b84200         mov      ax, 0x42               ; Menu structure ID = 66
  00040  50             push     ax
  00041  e86395         call     dm_createFile           ; Create/init file structure
  00044  83c402         add      sp, 2
  00047  e84994         call     dm_beginTransaction     ; Begin UI transaction
  0004A  e8fa94         call     dm_refreshTitleBar      ; Refresh title bar
  0004D  a1e603         mov      ax, word ptr [0x3e6]    ; Get .WKS extension string ID
  00050  a39701         mov      word ptr [0x197], ax    ; g_stringId_WKS = extension ID
  00053  a1fc03         mov      ax, word ptr [0x3fc]    ; Get untitled string ID
  00056  a3a201         mov      word ptr [0x1a2], ax    ; g_stringId_untitled
  00059  a14004         mov      ax, word ptr [0x440]    ; Get filter string ID
  0005C  a3ce01         mov      word ptr [0x1ce], ax    ; g_stringId_filter
  0005F  b88600         mov      ax, 0x86               ; Window flags = 0x86
  00062  50             push     ax
  00063  e82995         call     dm_setWindowFlags       ; Set window configuration flags
  00066  83c402         add      sp, 2
  00069  b87000         mov      ax, 0x70               ; Window width = 112
  0006C  50             push     ax
  0006D  b85e00         mov      ax, 0x5e               ; Window height = 94
  00070  50             push     ax
  00071  e8fd94         call     dm_setWindowPos         ; Set window position/size
  00074  83c404         add      sp, 4
  00077  c7067e1dffff   mov      word ptr [0x1d7e], 0xffff ; g_prevCellIndex = -1 (none)
  0007D  ff36e805       push     word ptr [0x5e8]        ; Push initial filename string ptr
  00081  e8ff94         call     dm_setWindowTitle       ; Set window title
  00084  83c402         add      sp, 2
  00087  2bc0           sub      ax, ax                  ; AX = 0
  00089  50             push     ax
  0008A  e87e94         call     dm_getGridOffset        ; Get initial grid offset
  0008D  83c402         add      sp, 2
  00090  5e             pop      si
  00091  8be5           mov      sp, bp
  00093  5d             pop      bp
  00094  c3             ret

; ---- wrksheet_main (sub_00095) ----
; _main() entry point called by CRT startup. Initializes resources,
; opens file from command line (if given), enters the main event loop.
; Parameters: argc [bp+4], argv [bp+6]
; Returns: does not return (calls _exit)
wrksheet_main:                                  ; 0000:0095
  00095  55             push     bp
  00096  8bec           mov      bp, sp
  00098  83ec0e         sub      sp, 0xe
  0009B  e872ff         call     wrksheet_initResources   ; Initialize all resources
  0009E  b80100         mov      ax, 1
  000A1  50             push     ax
  000A2  e80502         call     wrksheet_initWorkspace   ; Set up workspace (mode=1=new)
  000A5  83c402         add      sp, 2
  000A8  c606a30000     mov      byte ptr [0xa3], 0       ; g_menuEnable_save = 0 (disabled)
  000AD  837e0401       cmp      word ptr [bp + 4], 1     ; argc > 1?
  000B1  7e51           jle      .main_no_file            ; No file argument -> new sheet
  ; --- File argument provided: open it ---
  000B3  8b5e06         mov      bx, word ptr [bp + 6]    ; bx = argv
  000B6  ff7702         push     word ptr [bx + 2]        ; Push argv[1] (filename)
  000B9  b8fe19         mov      ax, 0x19fe              ; g_filenameBuf address
  000BC  50             push     ax
  000BD  e814c2         call     msc_strcpy               ; Copy filename to buffer
  000C0  83c404         add      sp, 4
  000C3  b80100         mov      ax, 1                    ; Open mode = 1
  000C6  50             push     ax
  000C7  b802f5         mov      ax, 0xf502              ; File command code = Open
  000CA  50             push     ax
  000CB  b8fe19         mov      ax, 0x19fe              ; Filename buffer
  000CE  50             push     ax
  000CF  e8042c         call     wrksheet_fileSaveDialog  ; Execute file open
  000D2  83c406         add      sp, 6
  000D5  40             inc      ax                       ; Check result: -1 = error
  000D6  7405           je       .main_open_failed
  000D8  c606a30001     mov      byte ptr [0xa3], 1       ; g_menuEnable_save = 1 (enabled)
.main_open_failed:
  000DD  b8fe19         mov      ax, 0x19fe              ; Window name = filename
  000E0  50             push     ax
  000E1  e8a594         call     dm_setWindowName         ; Set window name to filename
  000E4  83c402         add      sp, 2
  000E7  b87000         mov      ax, 0x70
  000EA  50             push     ax
  000EB  b85e00         mov      ax, 0x5e
  000EE  50             push     ax
  000EF  e88594         call     dm_getWindowPos          ; Get current window size
  000F2  83c404         add      sp, 4
  000F5  e84f8b         call     wrksheet_handleSaveCheck ; Check if save needed
  000F8  b8ffff         mov      ax, 0xffff              ; Navigation code = -1 (end)
  000FB  50             push     ax
  000FC  e88f87         call     wrksheet_scrollAndRedraw ; Scroll to end and redraw
  000FF  83c402         add      sp, 2
  00102  eb1c           jmp      .main_enter_loop
.main_no_file:
  ; --- No file argument: create new sheet ---
  00104  b8ffff         mov      ax, 0xffff
  00107  50             push     ax
  00108  e8c58c         call     wrksheet_rebuildGridView ; Build empty grid
  0010B  83c402         add      sp, 2
  0010E  c606fe1900     mov      byte ptr [0x19fe], 0     ; g_filenameBuf = "" (empty)
  00113  b8fe19         mov      ax, 0x19fe
  00116  50             push     ax
  00117  e86f94         call     dm_setWindowName         ; Set window name (empty)
  0011A  83c402         add      sp, 2
  0011D  e8e680         call     wrksheet_commitCellEdit  ; Initialize edit state
.main_enter_loop:
  ; --- Set initial state flags ---
  00120  800eb81d04     or       byte ptr [0x1db8], 4     ; g_stateFlags |= 0x04 (cell has data)
  00125  c646f801       mov      byte ptr [bp - 8], 1     ; Event type = 1 (init)
  00129  800eb81d10     or       byte ptr [0x1db8], 0x10  ; g_stateFlags |= 0x10 (needs title)
  0012E  800eb91d01     or       byte ptr [0x1db9], 1     ; State high byte flags
  00133  ff36b01b       push     word ptr [0x1bb0]        ; g_currentColAbs
  00137  ff36f019       push     word ptr [0x19f0]        ; g_currentRow
  0013B  e89372         call     wrksheet_setGridDimensions ; Set grid dimensions
  0013E  83c404         add      sp, 4
  00141  e8ee72         call     wrksheet_checkRecalcNeeded ; Check if recalc needed
  00144  e8695d         call     wrksheet_updateTitleBar  ; Update title bar display
  00147  e84393         call     dm_beginTransaction      ; Begin UI transaction

  ; ========== MAIN EVENT LOOP ==========
.main_loop:
  0014A  f706b81d0020   test     word ptr [0x1db8], 0x2000 ; Recalc pending?
  00150  7408           je       .main_get_event
  00152  8026b91ddf     and      byte ptr [0x1db9], 0xdf  ; Clear recalc-in-progress bit
  00157  e83393         call     dm_beginTransaction      ; Begin transaction for recalc
.main_get_event:
  0015A  8d46f8         lea      ax, [bp - 8]             ; Event buffer on stack
  0015D  50             push     ax
  0015E  e83893         call     dm_getEvent              ; Get next event from DeskMate
  00161  83c402         add      sp, 2
  ; --- Check for close event (type=2, code=0xFB04) ---
  00164  807ef802       cmp      byte ptr [bp - 8], 2     ; Event type == 2 (system)?
  00168  750c           jne      .main_not_close
  0016A  817ef904fb     cmp      word ptr [bp - 7], 0xfb04 ; Close event code?
  0016F  7505           jne      .main_not_close
  00171  b80100         mov      ax, 1                    ; Close requested
  00174  eb02           jmp      .main_check_close
.main_not_close:
  00176  2bc0           sub      ax, ax                   ; Not a close event
.main_check_close:
  00178  0bc0           or       ax, ax
  0017A  7508           jne      .main_handle_close
  0017C  800eb91d20     or       byte ptr [0x1db9], 0x20  ; Flag: process event
  00181  e80f93         call     dm_beginTransaction
.main_handle_close:
  ; --- Check grid validity ---
  00184  f606b81d01     test     byte ptr [0x1db8], 1     ; Grid valid?
  00189  7503           jne      .main_dispatch
  0018B  e8a472         call     wrksheet_checkRecalcNeeded ; Recalc if needed
.main_dispatch:
  0018E  8d46f8         lea      ax, [bp - 8]             ; Event buffer
  00191  50             push     ax
  00192  e8d201         call     wrksheet_dispatchEvent   ; Dispatch event to handler
  00195  83c402         add      sp, 2
  00198  e8155d         call     wrksheet_updateTitleBar  ; Update display
  0019B  ff36b01b       push     word ptr [0x1bb0]        ; g_currentColAbs
  0019F  ff36f019       push     word ptr [0x19f0]        ; g_currentRow
  001A3  e82b72         call     wrksheet_setGridDimensions ; Refresh grid dims
  001A6  83c404         add      sp, 4
  001A9  f606b81d01     test     byte ptr [0x1db8], 1     ; Grid valid?
  001AE  759a           jne      .main_loop               ; Yes -> continue loop
  001B0  e87f72         call     wrksheet_checkRecalcNeeded ; No -> check recalc
  001B3  eb95           jmp      .main_loop               ; Continue event loop

; ---- wrksheet_initCellArray (sub_001B5) ----
; Initialize the cell array with 5 edit field entries.
; Each entry defines: base pointer, edit buffer pointer, buffer size,
; display width, and active flag. Fields are spaced at offsets
; 0x00, 0x1E, 0xC8, 0x10E, and 0x154 from the cell memory base.
; Parameters: none (uses globals)
; Returns: none
wrksheet_initCellArray:                         ; 0000:01B5
  001B5  55             push     bp
  001B6  8bec           mov      bp, sp
  001B8  83ec04         sub      sp, 4
  001BB  56             push     si
  001BC  8b368a1a       mov      si, word ptr [0x1a8a]    ; si = g_cellArrayBase
  001C0  a1901a         mov      ax, word ptr [0x1a90]    ; ax = g_cellMemBase
  ; --- Field 0: Main cell edit (offset +0x00, size 6, width 0x0A, active) ---
  001C3  8904           mov      word ptr [si], ax
  001C5  8bd8           mov      bx, ax
  001C7  c7076464       mov      word ptr [bx], 0x6464    ; Magic: 'dd' (data descriptor)
  001CB  8b1c           mov      bx, word ptr [si]
  001CD  c747040000     mov      word ptr [bx + 4], 0     ; Format = 0
  001D2  8b04           mov      ax, word ptr [si]
  001D4  050600         add      ax, 6
  001D7  894402         mov      word ptr [si + 2], ax    ; Edit buf = base + 6
  001DA  c744040600     mov      word ptr [si + 4], 6     ; Buf size = 6
  001DF  c744060a00     mov      word ptr [si + 6], 0xa   ; Display width = 10
  001E4  c744080100     mov      word ptr [si + 8], 1     ; Active = 1
  001E9  83c60a         add      si, 0xa                  ; Next entry (10 bytes)
  ; --- Field 1: Formula bar (offset +0x1E, size 0x0E, width 2, active) ---
  001EC  a1901a         mov      ax, word ptr [0x1a90]
  001EF  051e00         add      ax, 0x1e
  001F2  8904           mov      word ptr [si], ax
  ; [... repeating pattern for fields 1-4, each with different offsets and sizes ...]
  ; Field 1: base+0x1E, size=0x0E, width=2
  ; Field 2: base+0xC8, size=0x0E, width=2
  ; Field 3: base+0x10E, size=0x0E, width=2
  ; Field 4: base+0x154, size=0x08, width=0
  ; [Fields 1-4 initialization follows same pattern as Field 0]
  002A5  5e             pop      si
  002A6  8be5           mov      sp, bp
  002A8  5d             pop      bp
  002A9  c3             ret

; ---- wrksheet_initWorkspace (sub_002AA) ----
; Set up the worksheet workspace: check memory, configure display
; parameters, initialize cell array, set default row/column counts.
; Parameters: mode [bp+4] (1=new, 0=reopen)
; Returns: none
wrksheet_initWorkspace:                         ; 0000:02AA
  002AA  55             push     bp
  002AB  8bec           mov      bp, sp
  002AD  83ec2c         sub      sp, 0x2c
  002B0  837e0400       cmp      word ptr [bp + 4], 0     ; mode == 0?
  002B4  7410           je       .init_ws_skip_memcheck
  002B6  e8ce75         call     wrksheet_checkMemory     ; Check available memory
  002B9  40             inc      ax
  002BA  750a           jne      .init_ws_skip_memcheck
  002BC  b80100         mov      ax, 1
  002BF  50             push     ax
  002C0  e84512         call     wrksheet_handleFileError ; Out of memory error
  002C3  83c402         add      sp, 2
.init_ws_skip_memcheck:
  002C6  c706b81bffff   mov      word ptr [0x1bb8], 0xffff ; g_editMode = -1 (no edit)
  002CC  8d46de         lea      ax, [bp - 0x22]
  002CF  50             push     ax
  002D0  e8b290         call     prguf_getFieldInfo       ; Get field info from resource
  002D3  83c402         add      sp, 2
  002D6  8a46e7         mov      al, byte ptr [bp - 0x19] ; Display rows from field info
  002D9  a24a1a         mov      byte ptr [0x1a4a], al    ; g_displayRows
  002DC  a1aa1a         mov      ax, word ptr [0x1aaa]    ; g_totalMemory
  002DF  2b06901a       sub      ax, word ptr [0x1a90]    ; Subtract cell base
  002E3  2d3800         sub      ax, 0x38                 ; Subtract overhead (56 bytes)
  002E6  a37a1d         mov      word ptr [0x1d7a], ax    ; g_calcWorkspace = available
  002E9  a38e1a         mov      word ptr [0x1a8e], ax    ; g_workspaceSize = available
  002EC  b80100         mov      ax, 1
  002EF  50             push     ax
  002F0  e82a5b         call     wrksheet_setMenuStates   ; Enable all menus
  002F3  83c402         add      sp, 2
  ; --- Get window dimensions ---
  002F6  8d46d8         lea      ax, [bp - 0x28]
  002F9  16             push     ss
  002FA  50             push     ax
  002FB  8d46d4         lea      ax, [bp - 0x2c]
  002FE  16             push     ss
  002FF  50             push     ax
  00300  8d46dc         lea      ax, [bp - 0x24]
  00303  16             push     ss
  00304  50             push     ax
  00305  e81b91         call     prguf_getFieldInfo       ; Get window field info
  00308  83c40c         add      sp, 0xc
  0030B  837edc03       cmp      word ptr [bp - 0x24], 3  ; Color mode = 3?
  0030F  7504           jne      .init_ws_mono
  00311  b001           mov      al, 1                    ; Color mode
  00313  eb02           jmp      .init_ws_set_color
.init_ws_mono:
  00315  2ac0           sub      al, al                   ; Monochrome mode
.init_ws_set_color:
  00317  a21101         mov      byte ptr [0x111], al     ; g_colorMode
  ; --- Set default dimensions ---
  0031A  c606cc0100     mov      byte ptr [0x1cc], 0      ; g_menuEnable_merge = 0
  0031F  b80100         mov      ax, 1
  00322  a3761d         mov      word ptr [0x1d76], ax    ; g_totalRows = 1
  00325  a3ac1a         mov      word ptr [0x1aac], ax    ; g_currentCol = 1
  00328  a3b01b         mov      word ptr [0x1bb0], ax    ; g_currentColAbs = 1
  0032B  a3f019         mov      word ptr [0x19f0], ax    ; g_currentRow = 1
  0032E  c706921a1400   mov      word ptr [0x1a92], 0x14  ; g_visibleColumns = 20
  00334  c706ba1d0700   mov      word ptr [0x1dba], 7     ; g_maxVisibleCol = 7
  0033A  b86400         mov      ax, 0x64                 ; 100
  0033D  50             push     ax
  0033E  b80a00         mov      ax, 0xa                  ; 10
  00341  50             push     ax
  00342  ff368c1a       push     word ptr [0x1a8c]        ; g_cellDataBuf
  00346  e899c1         call     msc_memset               ; Clear 100 bytes of cell data
  00349  83c406         add      sp, 6
  0034C  e866fe         call     wrksheet_initCellArray   ; Initialize cell array
  0034F  2bc0           sub      ax, ax
  00351  a35c1b         mov      word ptr [0x1b5c], ax    ; g_scrollOffsetX = 0
  00354  a3ba1b         mov      word ptr [0x1bba], ax    ; g_scrollOffsetY = 0
  00357  a1aa1a         mov      ax, word ptr [0x1aaa]    ; g_totalMemory
  0035A  a3741d         mov      word ptr [0x1d74], ax    ; g_lastMemTop = total
  0035D  c706b81d0000   mov      word ptr [0x1db8], 0     ; g_stateFlags = 0 (clear all)
  00363  8be5           mov      sp, bp
  00365  5d             pop      bp
  00366  c3             ret

; ---- wrksheet_dispatchEvent (sub_00367) ----
; Main event dispatcher. Routes events by type:
;   Type 1: Keyboard input (scan code + character)
;   Type 2: Mouse/scroll event
;   Type 3: Menu command
;   Type 4: System command (close/activate)
;   Type 6: Window event (resize, scroll, focus)
; Parameters: eventPtr [bp+4] -> event structure
; Returns: none
wrksheet_dispatchEvent:                         ; 0000:0367
  00367  55             push     bp
  00368  8bec           mov      bp, sp
  0036A  83ec18         sub      sp, 0x18
  0036D  8b5e04         mov      bx, word ptr [bp + 4]    ; bx = event pointer
  00370  8a07           mov      al, byte ptr [bx]        ; al = event type
  00372  98             cbw                                ; Sign-extend to AX
  00373  3d0100         cmp      ax, 1                    ; Type 1 = keyboard?
  00376  7503           jne      .dispatch_check_mouse
  00378  e9fe00         jmp      .dispatch_keyboard
.dispatch_check_mouse:
  0037B  3d0200         cmp      ax, 2                    ; Type 2 = mouse/scroll?
  0037E  7503           jne      .dispatch_check_menu
  00380  e98301         jmp      .dispatch_mouse
.dispatch_check_menu:
  00383  3d0300         cmp      ax, 3                    ; Type 3 = menu command?
  00386  7503           jne      .dispatch_check_system
  00388  e97001         jmp      .dispatch_menu
.dispatch_check_system:
  0038B  3d0400         cmp      ax, 4                    ; Type 4 = system?
  0038E  7503           jne      .dispatch_check_window
  00390  e9e000         jmp      .dispatch_system
.dispatch_check_window:
  00393  3d0600         cmp      ax, 6                    ; Type 6 = window event?
  00396  7403           je       .dispatch_window
  00398  e97301         jmp      .dispatch_done
  ; --- Window event dispatch ---
.dispatch_window:
  0039B  8b4701         mov      ax, word ptr [bx + 1]    ; Window sub-event code
  0039E  3d0100         cmp      ax, 1                    ; Subcode 1 = focus/activate
  003A1  7471           je       .dispatch_win_focus
  003A3  3d0300         cmp      ax, 3                    ; Subcode 3 = scroll
  003A6  7472           je       .dispatch_win_scroll
  003A8  3d0400         cmp      ax, 4                    ; Subcode 4 = resize
  003AB  7403           je       .dispatch_win_resize
  003AD  e95e01         jmp      .dispatch_done
.dispatch_win_resize:
  ; --- Handle window resize ---
  003B0  f606b81d01     test     byte ptr [0x1db8], 1     ; Grid valid?
  003B5  740a           je       .resize_skip_exit_edit
  003B7  b80100         mov      ax, 1
  003BA  50             push     ax
  003BB  e83673         call     wrksheet_enterEditMode   ; Exit current edit mode
  003BE  83c402         add      sp, 2
.resize_skip_exit_edit:
  003C1  b87000         mov      ax, 0x70                 ; New width
  003C4  50             push     ax
  003C5  b85e00         mov      ax, 0x5e                 ; New height
  003C8  50             push     ax
  003C9  e8ab91         call     dm_getWindowPos          ; Get new window position
  003CC  83c404         add      sp, 4
  003CF  e84b90         call     prguf_validateField      ; Re-validate field layout
  003D2  8946ee         mov      word ptr [bp - 0x12], ax
  003D5  40             inc      ax
  003D6  750a           jne      .resize_ok
  003D8  b80100         mov      ax, 1
  003DB  50             push     ax
  003DC  e82911         call     wrksheet_handleFileError
  003DF  e9bd00         jmp      .dispatch_done_via_49f
.resize_ok:
  003E2  b87000         mov      ax, 0x70
  003E5  50             push     ax
  003E6  b85e00         mov      ax, 0x5e
  003E9  50             push     ax
  003EA  e88491         call     dm_setWindowPos          ; Confirm new window size
  003ED  83c404         add      sp, 4
  003F0  8d46f6         lea      ax, [bp - 0xa]
  003F3  16             push     ss
  003F4  50             push     ax
  003F5  8d46ee         lea      ax, [bp - 0x12]
  003F8  16             push     ss
  003F9  50             push     ax
  003FA  8d46fc         lea      ax, [bp - 4]
  003FD  16             push     ss
  003FE  50             push     ax
  003FF  e82190         call     prguf_getFieldInfo       ; Get updated field info
  00402  83c40c         add      sp, 0xc
  00405  837efc03       cmp      word ptr [bp - 4], 3     ; Color mode?
  00409  7504           jne      .resize_mono
  0040B  b001           mov      al, 1
  0040D  eb02           jmp      .resize_set_color
.resize_mono:
  0040F  2ac0           sub      al, al
.resize_set_color:
  00411  a21101         mov      byte ptr [0x111], al     ; Update g_colorMode
.dispatch_win_focus:
  00414  e84313         call     wrksheet_refreshDisplay  ; Refresh entire display
  00417  e9f400         jmp      .dispatch_done
  ; --- Handle scroll event ---
.dispatch_win_scroll:
  0041A  c746e80000     mov      word ptr [bp - 0x18], 0  ; Was in edit mode = false
  0041F  f606b81d01     test     byte ptr [0x1db8], 1
  00424  7405           je       .scroll_begin
  00426  c746e80100     mov      word ptr [bp - 0x18], 1  ; Was in edit mode = true
.scroll_begin:
  0042B  e85f90         call     dm_beginTransaction
  0042E  8b5e04         mov      bx, word ptr [bp + 4]
  00431  ff7703         push     word ptr [bx + 3]        ; Scroll amount
  00434  e87e8f         call     wrksheet_loadImportedRes ; Process scroll
  00437  83c402         add      sp, 2
  0043A  e85690         call     dm_endTransaction
  0043D  8d46f6         lea      ax, [bp - 0xa]
  00440  16             push     ss
  00441  50             push     ax
  00442  8d46ee         lea      ax, [bp - 0x12]
  00445  16             push     ss
  00446  50             push     ax
  00447  8d46fc         lea      ax, [bp - 4]
  0044A  16             push     ss
  0044B  50             push     ax
  0044C  e8d48f         call     prguf_getFieldInfo
  0044F  83c40c         add      sp, 0xc
  00452  837efc03       cmp      word ptr [bp - 4], 3
  00456  7504           jne      .scroll_mono
  00458  b001           mov      al, 1
  0045A  eb02           jmp      .scroll_set_color
.scroll_mono:
  0045C  2ac0           sub      al, al
.scroll_set_color:
  0045E  a21101         mov      byte ptr [0x111], al
  00461  e8f612         call     wrksheet_refreshDisplay
  00464  837ee800       cmp      word ptr [bp - 0x18], 0  ; Was in edit mode?
  00468  7503           jne      .scroll_restore_edit
  0046A  e9a100         jmp      .dispatch_done
.scroll_restore_edit:
  0046D  e82213         call     wrksheet_handleResize    ; Restore edit mode
  00470  e99b00         jmp      .dispatch_done
  ; --- System command ---
.dispatch_system:
  00473  e82f90         call     dm_closeSession          ; Handle system close
  00476  e99500         jmp      .dispatch_done
  ; --- Keyboard input ---
.dispatch_keyboard:
  00479  8b5e04         mov      bx, word ptr [bp + 4]
  0047C  8b4701         mov      ax, word ptr [bx + 1]    ; Key code
  0047F  3d53ff         cmp      ax, 0xff53               ; Shift+Del = Cut
  00482  7420           je       .dispatch_delete_cmd
  00484  3d0900         cmp      ax, 9                    ; Tab key
  00487  7503           jne      .dispatch_check_enter
  00489  e98200         jmp      .dispatch_done
.dispatch_check_enter:
  0048C  3d0d00         cmp      ax, 0xd                  ; Enter key
  0048F  747d           je       .dispatch_done
  00491  3d1b00         cmp      ax, 0x1b                 ; Escape key
  00494  7478           je       .dispatch_done
  00496  3dff00         cmp      ax, 0xff                 ; Extended key?
  00499  760e           jbe      .dispatch_char_key
  0049B  50             push     ax                       ; Extended key -> navigation
  0049C  e8f164         call     wrksheet_handleNavigateKey
.dispatch_done_via_49f:
  0049F  83c402         add      sp, 2
  004A2  eb6a           jmp      .dispatch_done
.dispatch_delete_cmd:
  004A4  e85d06         call     wrksheet_handleDeleteCommand ; Handle Del key
  004A7  eb65           jmp      .dispatch_done
.dispatch_char_key:
  ; --- Regular character key ---
  004A9  f606b81d01     test     byte ptr [0x1db8], 1     ; In edit mode?
  004AE  740a           je       .dispatch_not_editing
  004B0  b80100         mov      ax, 1
  004B3  50             push     ax
  004B4  e83d72         call     wrksheet_enterEditMode   ; End current edit
  004B7  83c402         add      sp, 2
.dispatch_not_editing:
  004BA  833eb81b04     cmp      word ptr [0x1bb8], 4     ; g_editMode == 4 (cell edit)?
  004BF  7525           jne      .dispatch_not_cell_edit
  004C1  8b5e04         mov      bx, word ptr [bp + 4]
  004C4  837f0120       cmp      word ptr [bx + 1], 0x20  ; Space key?
  004C8  7407           je       .dispatch_cell_space
  004CA  817f010484     cmp      word ptr [bx + 1], 0x8404 ; Special edit key?
  004CF  7515           jne      .dispatch_not_cell_edit
.dispatch_cell_space:
  004D1  e88133         call     wrksheet_handleCellEdit  ; Process cell edit key
  004D4  2bc0           sub      ax, ax
  004D6  50             push     ax
  004D7  e81a72         call     wrksheet_enterEditMode
  004DA  83c402         add      sp, 2
  004DD  0bc0           or       ax, ax
  004DF  742d           je       .dispatch_done
  004E1  e82277         call     wrksheet_commitCellEdit
  004E4  eb28           jmp      .dispatch_done
.dispatch_not_cell_edit:
  004E6  833eb81b04     cmp      word ptr [0x1bb8], 4
  004EB  7421           je       .dispatch_done
  004ED  ff7604         push     word ptr [bp + 4]
  004F0  e8ac8f         call     dm_putEvent              ; Forward event to form engine
  004F3  83c402         add      sp, 2
  004F6  e87977         call     wrksheet_handleFormulaKeys ; Handle in formula bar
  004F9  eb13           jmp      .dispatch_done
  ; --- Menu command ---
.dispatch_menu:
  004FB  8b5e04         mov      bx, word ptr [bp + 4]
  004FE  ff7701         push     word ptr [bx + 1]        ; Menu command code
  00501  e80e00         call     wrksheet_handleMenuCommand
  00504  eb99           jmp      .dispatch_done_via_49f
  ; --- Mouse/scroll event ---
.dispatch_mouse:
  00506  ff7604         push     word ptr [bp + 4]        ; Event pointer
  00509  e8261f         call     wrksheet_handleScrollEvent
  0050C  eb91           jmp      .dispatch_done_via_49f
.dispatch_done:
  0050E  8be5           mov      sp, bp
  00510  5d             pop      bp
  00511  c3             ret

; ---- wrksheet_handleMenuCommand (sub_00512) ----
; Menu command dispatcher. Routes by menu command code (0xF501..0xF51E).
; Handles: File (New/Open/Save/SaveAs/Merge/PageSetup/Print/Exit/Run/About),
;          Edit (Cut/Copy/Paste/Clear/SelectAll),
;          Cells (ColWidth/InsCol/DelCol/InsRow/DelRow/Calculate/Formula/
;                 StartText/EndText),
;          Search (FindLabel/FindNumber/FindCell/FindNext).
; Parameters: commandCode [bp+4]
; Returns: none
wrksheet_handleMenuCommand:                     ; 0000:0512
  00512  55             push     bp
  00513  8bec           mov      bp, sp
  00515  83ec22         sub      sp, 0x22
  00518  57             push     di
  00519  56             push     si
  0051A  8b4604         mov      ax, word ptr [bp + 4]    ; Command code
  0051D  2d01f5         sub      ax, 0xf501              ; Normalize to 0-based index
  00520  3d1d00         cmp      ax, 0x1d                ; Max 29 commands
  00523  7603           jbe      .menu_in_range
  00525  e96003         jmp      .menu_done               ; Out of range -> ignore
.menu_in_range:
  00528  03c0           add      ax, ax                   ; Word index
  0052A  93             xchg     bx, ax
  0052B  2effa74c08     jmp      word ptr cs:[bx + 0x84c] ; Jump table dispatch
  ; --- File > New (first entry in jump table) ---
  00530  e85a8f         call     dm_beginTransaction
  00533  f606b81d01     test     byte ptr [0x1db8], 1     ; In edit mode?
  00538  740a           je       .new_check_modified
  0053A  b80100         mov      ax, 1
  0053D  50             push     ax
  0053E  e8b371         call     wrksheet_enterEditMode   ; Exit edit mode
  00541  83c402         add      sp, 2
.new_check_modified:
  00544  f606b81d02     test     byte ptr [0x1db8], 2     ; File modified?
  00549  742e           je       .new_do_open
  0054B  e8618e         call     wrksheet_promptSave      ; Prompt "Save changes?"
  0054E  8bf0           mov      si, ax
  00550  3d03f7         cmp      ax, 0xf703              ; "No" -> discard changes
  00553  750f           jne      .new_check_cancel
  00555  2bc0           sub      ax, ax
  00557  50             push     ax
  00558  b80100         mov      ax, 1
  0055B  50             push     ax
  0055C  e8fb22         call     wrksheet_fileOpenDialog  ; Open dialog
  0055F  83c404         add      sp, 4
  00562  8bf0           mov      si, ax
.new_check_cancel:
  00564  8bc6           mov      ax, si
  00566  3d02f7         cmp      ax, 0xf702              ; "Cancel"?
  00569  7405           je       .new_cancel
  0056B  83feff         cmp      si, -1                   ; Error?
  0056E  7509           jne      .new_do_open
.new_cancel:
  00570  e8208f         call     dm_endTransaction
.new_update:
  00573  e87358         call     wrksheet_drawGridFrame   ; Redraw grid frame
  00576  e90f03         jmp      .menu_done
.new_do_open:
  00579  e81203         call     wrksheet_handleNewFile   ; Create new empty file
  0057C  e90903         jmp      .menu_done
  ; [... remaining menu command handlers follow similar patterns ...]
  ; Each handler: begin transaction, check edit state, execute command,
  ; end transaction, update display. Commands dispatch to appropriate
  ; handler functions (wrksheet_handleCopyCommand, wrksheet_handleCutCommand,
  ; wrksheet_handlePasteCommand, wrksheet_handleInsertDelete, etc.)
  ;
  ; The full jump table at cs:[0x84C] maps command indices 0-29 to
  ; the handler code blocks within this function.

  ; [Remaining handlers omitted for brevity - they follow the same
  ;  structural pattern as the New handler above]

.menu_done:
  0088A  5e             pop      si
  0088B  5f             pop      di
  0088C  8be5           mov      sp, bp
  0088E  5d             pop      bp                       ; NOTE: this overlaps with sub_0088E
  0088F  c3             ret                               ; The raw disasm shows sub_0088E
                                                          ; starting at the same offset as the
                                                          ; epilogue of sub_00512.

; ========================================================================
; REMAINING APPLICATION FUNCTIONS (0x088E - 0x91B2)
; ========================================================================
;
; The remaining ~350 application functions follow the same patterns
; documented in the function index above. Key function groups:
;
; Cell Operations (0x088E-0x12C2):
;   wrksheet_handleNewFile, wrksheet_handleKeyInput,
;   wrksheet_handleDeleteCommand, wrksheet_handleEditEnter,
;   wrksheet_handleCopyCommand, wrksheet_handleCutCommand,
;   wrksheet_handlePasteCommand, wrksheet_handleFillDown,
;   wrksheet_handleFillRight, wrksheet_handleSearchCommand,
;   wrksheet_handleGotoCommand, wrksheet_handleSortCommand
;
; File I/O (0x1508-0x182E):
;   wrksheet_handleFileError, wrksheet_parseColumnLetter,
;   wrksheet_handleFormatCommand, wrksheet_initWindowMetrics,
;   wrksheet_refreshDisplay, wrksheet_handleResize,
;   wrksheet_handlePrintCommand
;
; Print System (0x195F-0x1BF2):
;   wrksheet_printMainLoop, wrksheet_printRowData,
;   wrksheet_printHeader, wrksheet_printCellValue,
;   wrksheet_printFormattedCell, wrksheet_printSetupDialog
;
; Formula Editor (0x1D98-0x2343):
;   wrksheet_formatCellRef, wrksheet_editCellFormula,
;   wrksheet_convertCellToFP, wrksheet_evalCellFormula,
;   wrksheet_resizeGrid, wrksheet_recalcSheet
;
; Navigation and Display (0x2432-0x3766):
;   wrksheet_handleScrollEvent, wrksheet_getCellDataPtr,
;   wrksheet_readCellValue, wrksheet_writeCellText,
;   wrksheet_writeCellFormula, wrksheet_printSetMargins,
;   wrksheet_clearCellRange, wrksheet_fileOpenDialog,
;   wrksheet_fileSaveDialog, wrksheet_handleInputDialog,
;   wrksheet_handleOptionsDialog, wrksheet_printSetPageLen,
;   wrksheet_getMaxRow
;
; Cell Edit and Display (0x3789-0x5B48):
;   wrksheet_handleMergeCommand, wrksheet_allocCellBlock,
;   wrksheet_handleCellEdit, wrksheet_drawStatusBar,
;   wrksheet_handleSaveCheck, wrksheet_handleFileIO,
;   wrksheet_readWKSFile, wrksheet_setCellFormat_fill,
;   wrksheet_setCellFormat_align, wrksheet_buildColumnDisplay,
;   wrksheet_formatNumberString, wrksheet_handleColWidthDialog,
;   wrksheet_handleInsertDelete, wrksheet_moveBlockData,
;   wrksheet_adjustReferences, wrksheet_recalcAfterEdit,
;   wrksheet_evalFormulaTree, wrksheet_evalFunction, ...
;   wrksheet_compileFormula, wrksheet_setCellValue,
;   wrksheet_setCellNumeric, wrksheet_setCellString,
;   wrksheet_allocCellContents, wrksheet_freeCellContents,
;   wrksheet_clearCellValue, wrksheet_validateCellRef
;
; Grid Rendering (0x5BE8-0x6990):
;   wrksheet_getCellByRef, wrksheet_getCellRange,
;   wrksheet_fileOperation, wrksheet_getClipboardData,
;   wrksheet_getColumnCount, wrksheet_adjustColumnView,
;   wrksheet_drawGridFrame, wrksheet_setMenuStates,
;   wrksheet_updateTitleBar, wrksheet_drawCellIndicator,
;   wrksheet_drawCellContents, wrksheet_moveCursorTo,
;   wrksheet_moveCursorHome, wrksheet_redrawStatusArea,
;   wrksheet_getDataSegment, wrksheet_openWKSFile,
;   wrksheet_saveWKSFile, wrksheet_saveAsWKSFile,
;   wrksheet_createNewFile, wrksheet_closeFileCleanup,
;   wrksheet_closeAndPrompt, wrksheet_handleNavigateKey
;
; Grid Drawing Engine (0x6B22-0x8FF9):
;   wrksheet_renderCellGrid (1244 bytes - draws all visible cells),
;   wrksheet_formatDisplayCell, wrksheet_handleRecalcCommand,
;   wrksheet_recalcAllCells, wrksheet_handleAboutDialog,
;   wrksheet_renderSingleCell, wrksheet_copyCellRange,
;   wrksheet_getVisibleCols, wrksheet_setGridDimensions,
;   wrksheet_checkRecalcNeeded, wrksheet_parseFormulaInput,
;   wrksheet_validateFormula, wrksheet_drawCell,
;   wrksheet_drawFormattedCell, wrksheet_enterEditMode,
;   wrksheet_exitEditMode, wrksheet_checkMemory,
;   wrksheet_copyRange, wrksheet_lookupCell,
;   wrksheet_callWithParams, wrksheet_setCellAndRedraw,
;   wrksheet_cellRefToString, wrksheet_showMessageBox,
;   wrksheet_handleFormulaBar, wrksheet_handleSearchFind,
;   wrksheet_handleFormulaKeys, wrksheet_editFormulaInPlace,
;   wrksheet_commitCellEdit, wrksheet_drawGridContents,
;   wrksheet_scrollAndRedraw, wrksheet_printCallback,
;   wrksheet_writeWKSFormat, wrksheet_writeWKSHeader,
;   wrksheet_getMaxColumn, wrksheet_getMaxRow2,
;   wrksheet_saveCurrentState, wrksheet_restoreAndRedraw,
;   wrksheet_rebuildGridView, wrksheet_writeFileBlock,
;   wrksheet_closeFileHandle

; ========================================================================
; PRGUF/DMGUF DISPATCH ENGINE (0x921A - 0x93B5)
; ========================================================================
;
; This section contains the resource management and dispatch engine
; for the PRGUF and DMGUF resource modules. The engine handles:
; - Loading resources via INT E0h AX=0206h
; - Executing resource functions via INT E0h AX=0208h
; - Unloading resources via INT E0h AX=0207h
; - Far-call dispatch through function pointer tables
; - Dual-resource fallback (PRGUF -> DMGUF)
;
; The PRGUF dispatch trampoline at loc_092E6 validates the function code
; (must be in range 0x01-0x38 unless PRGUF is active) and performs
; an indirect far call through [0xBE4]. The DMGUF dispatch trampoline
; at loc_0932A validates codes (rejects 0xBE and 0xBF if DMGUF not
; loaded) and calls through [0xBEE].

; ========================================================================
; PRGUF/DMGUF THUNK TABLE (0x9367 - 0x95B3)
; ========================================================================
;
; Each thunk is a 6-byte function: load AX with function code, jump to
; dispatcher. See the function index above for complete listing.

; ========================================================================
; FORMULA PARSER AND EVALUATOR ENGINE (0x95F2 - 0x9A82)
; ========================================================================
;
; The formula engine handles:
; - Parsing spreadsheet formulas from user input
; - Managing sheet metadata (name, version, cell count)
; - Building the sheet entry list for the title/status display
; - Dispatching formula evaluation to the FP math library
;
; Key data structures used:
; - g_sheetPtrArray [0x1D90]: array of 15 pointers to sheet entries
; - g_sheetListBuf [0x1BBC]: formatted display strings for sheets
; - g_versionStrBuf [0x1A94]: version string (e.g. "1.0")

; ========================================================================
; FLOATING-POINT MATH LIBRARY (0x9A82 - 0xBFAC)
; ========================================================================
;
; Complete software floating-point library for spreadsheet calculations.
; Uses an 8-byte internal format (similar to IEEE 754 double but with
; a different exponent bias of 0x3800). Cell values are stored in a
; compressed 4-byte format and expanded for calculations.
;
; The library provides:
; - Basic arithmetic: add, subtract, multiply, divide
; - Power/exponentiation
; - Square root
; - Trigonometric: sin, cos, tan, arctan
; - Logarithmic: log (natural), log10
; - Exponential: exp (e^x)
; - Comparison operators
; - Number formatting (fixed-point, scientific notation)
; - Number parsing (string to FP)
;
; All functions operate on values pointed to by SI (source) and DI
; (destination). The FP accumulator is pointed to by g_fpAccumPtr
; at [0x0F5A].

; ========================================================================
; MSC 5.x C RUNTIME LIBRARY (0xC23C - 0xCBD9+)
; ========================================================================
;
; Standard C library functions compiled from MSC 5.x. Includes:
; string operations (strcpy, strcmp, strlen, strncpy, strncmp),
; memory operations (memcpy, memset, malloc, free),
; number conversion (atoi, itoa, sprintf),
; and long arithmetic (ldiv, lmul, lshift, ladd).

; ========================================================================
; CRT STARTUP (segment 0CC5, 0x0CC50 - 0xCCE7)
; ========================================================================
;
; MSC 5.x CRT startup sequence. See function index for details.
; The startup code at 0CC5:0000 initializes SS:SP, resizes the memory
; block, zeroes BSS, parses the command line, and calls the DM89
; import resolver before transferring control to wrksheet_main.

; ========================================================================
; DM89 IMPORT TABLE (segment 0CC5, 0xCCF8 - 0xCE9E+)
; ========================================================================
;
; The DM89 import table at 0CC5:009C defines the menu structure and
; UI elements. It is interpreted by the DM89 import resolver (sub_0CE9E).
; The table entries are packed records, not executable code, though the
; disassembler attempts to decode them as instructions.
;
; Notable menu item entries decoded from the table:
; - Menu bar: File, Edit, Cells, Search, Options
; - File menu: New, Open, Save, Save As, Merge, Page Setup, Print, Exit
; - Edit menu: Cut (Shift+Del), Copy (Ctrl+Ins), Paste (Shift+Ins),
;              Clear (Del), Select All
; - Cells menu: Column Width, Insert Column, Delete Column,
;               Insert Row, Delete Row
; - Search menu: Find Label, Find Number, Find Cell, Find Next (Ctrl+N)
; - Options menu: Calculate (Ctrl+C), Formula (Ctrl+F),
;                 Start Text (Ctrl+T), End Text (Ctrl+Q)

; ========================================================================
; STRING TABLE (segment 0CD3, 0xCCF8 - 0xD300+)
; ========================================================================
;
; All UI strings for the worksheet application. See the STRING TABLE
; section in the header for decoded strings. The disassembler misinterprets
; these null-terminated ASCII strings as machine instructions.

; ========================================================================
; END OF ANNOTATED DISASSEMBLY
; ========================================================================
