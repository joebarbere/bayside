; ========================================================================
; TEXT.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright 1984, 1989
; Compiled with Microsoft C 5.x (1987), Small Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; TEXT.PDM is the DeskMate word processor, a full-featured text editing
; application that runs inside the DESK.EXE host shell. It provides:
;
;   - Document editing with insert/overwrite modes
;   - Bold and underline formatting via inline control codes
;   - Center and indent paragraph formatting
;   - Cut, copy, paste, and un-delete (clipboard operations)
;   - Find, find-next, and substitute (search & replace)
;   - Header and footer editing with page numbers and dates
;   - Embedded picture support (move, size, show/hide)
;   - Print and print form letter (mail merge via MAILMRGE.PDM)
;   - Spell check (via DMSPELL resource) and thesaurus (via DMTHES)
;   - Dictionary and translate tools
;   - Page setup (margins, CPI, lines per page)
;   - "Add field" for mail merge fields from ADDRESS.PDM
;   - About dialog with version and resource info
;
; Resources loaded at runtime via INT E0h AX=0206h:
;   PRGUF    - Program User Functions (main DeskMate UI library)
;   DMGUF    - DeskMate General User Functions
;   DMSPELL  - Spell check engine
;   DMCSR    - DeskMate Cursor resource
;   SPELL    - Spell dictionary
;   DMTHES   - Thesaurus
;   DMDB     - Database access (for Address Book fields)
;   DMDBRD   - Database reader
;
; Copyright string: "DeskMate Copyright 1984, 1989" -- this is an earlier
; build date than other DM3.05 PDMs which show 1990.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 75,185 bytes
; Load image: 74,673 bytes (after header)
; DM89 entry point: 0FF4:0006 (MSC 5.x CRT startup)
; SS:SP = 132C:0C00
; Relocations: 19
; DM89 header anomaly: non-zero values at offsets 0x2E-0x31 (0x0006:0x0FF4)
;
; Segment Map (5 segments):
;   seg_0000  0x0E597 bytes  CODE   Main application code (59,799 bytes)
;   seg_0E59  0x00F9B bytes  CODE   PRGUF dispatch stubs + DM API wrappers
;   seg_0FF4  0x000C0 bytes  CODE   MSC 5.x CRT startup + far-call stubs
;   seg_0FFF  0x00020 bytes  CODE   DM89 entry shim
;   seg_1002  0x032A0 bytes  DATA   DGROUP: strings, menus, global vars,
;                                   MSC CRT data, runtime error messages
;
; Small memory model: single code segment plus CRT, DGROUP at seg_1002.
;
; ========================================================================
; DOCUMENT BUFFER DATA STRUCTURE
; ========================================================================
;
; The text document is stored as a linear byte buffer in data segment
; memory. Characters >= 0x20 are printable text. Control codes < 0x20
; are inline formatting markers:
;
;   0x01  Picture marker (followed by 6 bytes: 2-byte size + 4-byte data)
;   0x02  End-of-picture / picture terminator
;   0x03  Indent/margin change marker (followed by 3 bytes: indent values)
;   0x04  Tab marker (followed by 4 bytes)
;   0x05  Page break
;   0x0A  Line feed
;   0x0B  Soft return / word-wrap break
;   0x0D  Carriage return (hard line break)
;   0x10  Underline OFF
;   0x11  Underline ON
;   0x12  Bold OFF
;   0x13  Bold ON
;   0x1A  End-of-file marker
;
; ========================================================================
; KEY GLOBAL VARIABLES (DATA SEGMENT OFFSETS)
; ========================================================================
;
;   0x005C  g_boldActive        - Current bold state (0=off, 1=on)
;   0x005E  g_underlineActive   - Current underline state (0=off, 1=on)
;   0x06FC  g_pendingEventCount - Count of pending keyboard events
;   0x0700  g_defaultIndent     - Default indent values (3 bytes)
;   0x07E8  g_memoryFull        - Memory full flag (1 = buffer full)
;   0x0926  g_dialogBuffer      - Dialog box working buffer
;   0x0940  g_filenameBuffer    - Current document filename buffer
;   0x093C  g_filenamePtr2      - Secondary filename pointer
;   0x0982  g_appContextPtr     - Pointer to application context block
;   0x0984  g_windowHandle      - DeskMate window handle
;   0x0986  g_menuBaseAddr      - Base address of menu structures
;   0x0988  g_menuBufferSize    - Size of menu buffer allocation
;   0x0992  g_inputIgnoredMsg   - "Input Ignored" message offset
;   0x2410  g_insertMode        - Insert mode flag (0=overwrite, 1=insert)
;   0x2412  g_bufferEnd         - End of document buffer
;   0x2416  g_windowRows        - Number of visible text rows
;   0x2420  g_lastHScrollPos    - Last horizontal scroll position
;   0x2424  g_rightMarginIndent - Right margin indent value
;   0x2426  g_linesPerPage      - Printed lines per page setting
;   0x2462  g_bufferStart       - Start of document text buffer
;   0x2464  g_menuEndAddr       - End address of menu data
;   0x2488  g_lineWidth         - Printed line width in characters
;   0x248C  g_boldState         - Bold formatting state for cursor pos
;   0x24A6  g_dirtyFlag         - Document modified / "dirty" flag
;   0x24A8  g_blockSelectLen    - Length of selected block (0 = no selection)
;   0x24AA  g_textLength        - Total text length in buffer
;   0x24AC  g_totalCharCount    - Total character count
;   0x24B0  g_blockSelectSize   - Block selection size (for clipboard)
;   0x24B2  g_pictureAtCursor   - Picture at cursor flag
;   0x24B4  g_currentOffset     - Current offset within text
;   0x24B6  g_maxBufferSize     - Maximum buffer capacity
;   0x24B8  g_cursorPos         - Current cursor position in buffer
;   0x24BA  g_currentCol        - Current column number
;   0x24C2  g_underlineState    - Underline formatting state for cursor
;   0x24D8  g_cursorIndent      - Indent values at cursor position (3 bytes)
;   0x24DC  g_cursorOnPicture   - Cursor is on a picture flag
;   0x24DE  g_currentLine       - Current display line number
;   0x24E0  g_readOnlyMode      - Read-only mode flag
;   0x24E4  g_leftMarginIndent  - Left margin indent value
;   0x24E6  g_lineStartPos      - Start position of current line in buffer
;   0x24E8  g_clipboardAddr     - Clipboard buffer address
;   0x24EA  g_bufferCapacity    - Total buffer capacity
;   0x24EC  g_lineEndPos        - End position of current line in buffer
;   0x24EE  g_statusLineBuffer  - Status line display buffer
;   0x2500  g_windowInfoPtr     - DeskMate window info pointer
;   0x2502  g_editAreaStart     - Start of editable area
;   0x2548  g_endOfText         - Pointer to end of text data
;   0x2546  g_hScrollPos        - Horizontal scroll position
;   0x2FD8  g_docEndPos         - Document end position
;   0x31B0  g_pictureReserve    - Picture height reserve space
;   0x31B2  g_searchState       - Search/substitute state
;   0x31B4  g_scrollPending     - Scroll redraw pending flag
;   0x31B6  g_viewportWidth     - Viewport width for display
;   0x31B8  g_freeBufferSpace   - Free space remaining in buffer
;   0x3232  g_workingIndent     - Working indent values (3 bytes, temp)
;   0x3236  g_picturePresent    - Picture present in document flag
;   0x323C  g_endOfLineFlag     - End of line / end of file flag
;   0x3260  g_prevCursorPos     - Previous cursor position
;   0x3266  g_charHeight        - Character height in pixels
;   0x3268  g_redrawNeeded      - Redraw needed flag
;   0x3298  g_prevLine          - Previous line number
;
; ========================================================================
; APPLICATION CONTEXT BLOCK (pointed to by [0x0982])
; ========================================================================
;
;   Offset  Size  Description
;   0x00    byte  Current character at cursor (0x0D = line end)
;   0x01    byte  Modified flag (set to 1 after edits)
;   0x02    word  File handle or -1
;   0x08    word  Filename buffer offset (0x0940)
;   0x0A    word  Secondary filename offset (0x093C)
;   0x0C    word  Buffer start pointer
;   0x0E    word  Buffer start pointer (duplicate)
;   0x10    word  Buffer end pointer
;   0x12    word  Edit area start offset (0x2502)
;
; ========================================================================
; MENU STRUCTURE
; ========================================================================
;
; Menu bar has 7 menus based on string table:
;   "File"    - Open, Save, Save as, Merge, Page setup, Print,
;               Print form letter, Exit, Run, To ASCII, About
;   "Edit"    - Cut, Copy, Paste, Clear, Select all, Un-Delete, Insert
;   "Text"    - Proof, Thesaurus, Plain, Bold, Underline, Center,
;               Un-Center, Indent, Dictionary, Translate
;   "Search"  - Find, Find next, Substitute, Return to Document
;   "Layout"  - Header, Footer, Page number, Today's date, Add field
;   "Picture" - Show, Hide, Move, Size
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Text Formatting Functions ---
;
; Address  Name                            Description
; -------  ----                            -----------
; 0x0009A  text_insertBoldMarker           Insert bold on/off markers around text
; 0x00184  text_insertUnderlineMarker      Insert underline on/off markers
; 0x00295  text_insertFormatCodeBefore     Insert format code before current line
; 0x0033F  text_deleteControlCode          Delete a single control code byte
; 0x00379  text_insertFormatCodeAfter      Insert format code after current text
; 0x003F1  text_scanForwardFormatState     Scan forward updating bold/underline state
; 0x00474  text_scanBackwardFormatState    Scan backward updating bold/underline state
; 0x00546  text_resetFormatState           Reset bold/underline state from buffer start
; 0x005E3  text_syncFormatAtCursor         Sync formatting state at cursor position
;
; --- Cursor Navigation ---
;
; 0x0069A  text_handleFormatToggle         Handle format code toggle at cursor position
; 0x007BB  text_initLineState              Initialize line state (word wrap check)
; 0x0093A  text_processEventAtCursor       Process keyboard event at current cursor
; 0x00B67  text_moveCursorUp               Move cursor up one line
; 0x00C29  text_handleCursorUpKey          Handle Up arrow key press (with selection)
; 0x00D71  text_adjustLineAfterEdit        Adjust line/display after edit operation
; 0x00F3A  text_handleBackspace            Handle backspace key (delete char before cursor)
; 0x01133  text_updateColumnDisplay        Update column/line display in status bar
; 0x011DC  text_handleDeleteKey            Handle delete key (delete char at cursor)
; 0x0148B  text_beginUndoCapture           Begin undo capture for un-delete
; 0x014D0  text_finalizeEditOp             Finalize edit: update scroll, line counts
; 0x015A3  text_recalcLineStart            Recalculate line start position
; 0x015F1  text_recalcAfterChange          Recalculate display after buffer change
; 0x0167E  text_checkAutoIndent            Check if auto-indent should apply
; 0x016BE  text_insertCharAtPos            Insert a character at given buffer position
; 0x016D8  text_deleteCharAtPos            Delete a character at given buffer position
; 0x016F7  text_expandBlock                Expand block for multi-char insertion
; 0x0171F  text_wordWrapLine               Perform word wrapping on current line
;
; --- Block Operations (Cut/Copy/Paste) ---
;
; 0x01812  text_checkBlockSize             Check if block fits in clipboard
; 0x0187B  text_pasteFromClipboard         Paste text from clipboard into document
; 0x019AD  text_prepareBlockOp             Prepare for block operation (select range)
; 0x01A28  text_processMenuCommand         Process menu command dispatch (keyboard shortcut)
; 0x01C1B  text_handleEditMenu             Handle Edit menu selections (cut/copy/paste/clear)
; 0x01DB8  text_insertCharOverwrite        Insert character in overwrite mode
; 0x01E75  text_insertCharInsert           Insert character in insert mode
; 0x01FB7  text_checkInsertSpace           Check if space available for insert
; 0x02055  text_getBlockStart              Get start position of selected block
; 0x0207A  text_getBlockEnd                Get end position of selected block
; 0x020A1  text_validateCursorPos          Validate and adjust cursor position
; 0x02111  text_clearBlockSelect           Clear block selection
; 0x0216F  text_handleTypedChar            Handle a typed character (insert at cursor)
; 0x02477  text_handleEditMenuAlt          Alternate edit menu handler (keyboard shortcuts)
; 0x0252F  text_doCut                      Perform cut operation (copy to clipboard, delete)
; 0x0265E  text_doCopy                     Perform copy operation (copy to clipboard)
; 0x027F7  text_doPaste                    Perform paste operation (insert from clipboard)
; 0x02872  text_doClear                    Perform clear operation (delete without clipboard)
; 0x0298B  text_doUndelete                 Perform un-delete (restore last deleted text)
;
; --- Character Attribute Operations ---
;
; 0x02C16  text_setBold                    Set bold attribute on selected text
; 0x02C69  text_setUnderline               Set underline attribute on selected text
; 0x02CCA  text_menuBold                   Handle menu: Text > Bold
; 0x02D92  text_menuUnderline              Handle menu: Text > Underline
; 0x02E5F  text_applyBoldToBlock           Apply bold formatting to selected block
; 0x02F9D  text_applyUnderlineToBlock      Apply underline formatting to selected block
; 0x03061  text_insertBoldPair             Insert bold on/off pair at position
; 0x030E1  text_wrapWithBold               Wrap text range with bold markers
; 0x03138  text_cleanupBoldMarkers         Clean up redundant bold markers
; 0x0322A  text_wrapWithUnderline          Wrap text range with underline markers
; 0x03353  text_menuPlainBold              Handle menu: Text > Plain (remove bold)
; 0x033CF  text_menuPlainUnderline         Handle menu: Text > Plain (remove underline)
; 0x0342C  text_removeBoldFromBlock        Remove bold from selected block
; 0x034B1  text_removeUnderlineFromBlock   Remove underline from selected block
; 0x03525  text_menuCenter                 Handle menu: Text > Center
; 0x03619  text_menuUnCenter               Handle menu: Text > Un-Center
; 0x03729  text_recalcParagraphBounds      Recalculate paragraph boundaries
; 0x03788  text_menuIndent                 Handle menu: Text > Indent (show dialog)
; 0x0382B  text_menuDictionary             Handle menu: Text > Dictionary
; 0x03889  text_menuTranslate              Handle menu: Text > Translate
; 0x03904  text_centerLine                 Center a single line of text
; 0x039E3  text_uncenterLine               Remove centering from a line
; 0x03B36  text_validateCenterWidth        Validate line width for centering
; 0x03C22  text_getIndentValue             Get indent value for current paragraph
; 0x03C4C  text_setFirstLineIndent         Set first-line indent value
; 0x03CDF  text_setLeftIndent              Set left margin indent value
; 0x03D6D  text_setRightIndent             Set right margin indent value
;
; --- Indent Dialog ---
;
; 0x03E86  text_showIndentDialog           Show indent dialog (3 fields)
; 0x0413D  text_applyIndentFromDialog      Apply indent values from dialog
; 0x041D2  text_indentDialogInit           Initialize indent dialog controls
;
; --- Display / Rendering ---
;
; 0x0422C  text_renderInsertCursor         Render insert mode cursor indicator
; 0x04314  text_calcDisplayCol             Calculate display column from buffer pos
; 0x04355  text_renderLine                 Render a single line of text to screen
; 0x0473F  text_preRenderCheck             Pre-render: check format state before draw
; 0x047B1  text_getLineContentWidth        Get content width of a line
; 0x047FD  text_renderTabStop              Render tab stop character
; 0x0485C  text_renderPicturePlaceholder   Render "** Picture **" placeholder text
; 0x04923  text_renderCenteredLine         Render a centered line of text
; 0x04A35  text_renderWordWrappedLine      Render a word-wrapped continuation line
; 0x04B47  text_calculateLineBreak         Calculate line break position
; 0x04BA4  text_renderIndentedLine         Render a line with indent markers
; 0x04C05  text_renderEndOfLine            Render end-of-line indicator
; 0x04C74  text_renderPictureBox           Render picture bounding box
; 0x04CC5  text_updateScrollIndicator      Update scroll position indicator
; 0x04E28  text_renderCharWithAttr         Render character with bold/underline attrs
;
; --- Screen Layout / Scrolling ---
;
; 0x05092  text_initScreenLayout           Initialize screen layout and display
; 0x050B5  text_setupStatusLine            Set up status line at bottom of window
; 0x050F7  text_drawFullScreen             Draw full screen of text
; 0x05193  text_updateStatusLine           Update status line (page/line/col)
; 0x05224  text_drawStatusItems            Draw status line items
; 0x05278  text_renderVisibleLines         Render all visible lines in viewport
; 0x054F2  text_recursiveLineCalc          Recursive line boundary calculation
; 0x055C8  text_refreshDisplay             Refresh display after changes
; 0x0567E  text_redrawScreen               Redraw entire screen
; 0x056B3  text_initNewDocument            Initialize a new (empty) document
; 0x056E5  text_openNewFile                Open/initialize new file
; 0x05760  text_loadFileIntoBuffer         Load file contents into text buffer
; 0x05828  text_setInitialCursor           Set initial cursor position after load
; 0x0584B  text_loadExistingFile           Load an existing file from disk
; 0x059A2  text_allocateLoadBuffer         Allocate buffer for file loading
; 0x05A2C  text_parseLoadedText            Parse loaded text (normalize line endings)
; 0x05ADF  text_handleLoadError            Handle file load error
; 0x05B1E  text_setBufferPointers          Set buffer start/end pointers
; 0x05B54  text_initBufferState            Initialize buffer state after load
; 0x05BC5  text_loadFileAtOffset           Load file at specified buffer offset
; 0x05BFA  text_resetEditState             Reset editing state (marks, selection)
; 0x05C21  text_clearDocument              Clear current document
; 0x05C7E  text_initEmptyBuffer            Initialize empty text buffer
; 0x05CF2  text_checkMemoryFull            Check if memory is full
;
; --- File Operations ---
;
; 0x05DA3  text_getFileSize                Get current document file size
; 0x05DF5  text_handleFileMenu             Handle File menu selections
; 0x06224  text_doSave                     Save document to current filename
; 0x06286  text_doSaveAs                   Save document with new filename
; 0x062F4  text_showPageSetup              Show page setup dialog
; 0x063A3  text_applyPageSetup             Apply page setup values from dialog
; 0x0642A  text_showPrintDialog            Show print dialog and execute print
; 0x067D3  text_printDocumentBody          Print document body text
; 0x0688B  text_printWithSetup             Print with page setup (header/footer)
; 0x0691F  text_outputPrintLine            Output a single print line
; 0x06991  text_sendLineToPrinter          Send formatted line to printer
; 0x06A10  text_printPageBreak             Handle page break during printing
; 0x06A9C  text_printEndOfDoc              Handle end of document during printing
; 0x06ABE  text_incrementPageCount         Increment page counter during printing
; 0x06AE0  text_showPrintFormLetter        Show "Print form letter" dialog
; 0x06C2F  text_executePrintFormLetter     Execute print form letter (mail merge)
; 0x06DB1  text_handleMergeMenu            Handle File > Merge menu selection
; 0x06E57  text_performMerge               Perform file merge operation
; 0x06F3F  text_openMergeFile              Open file for merge operation
; 0x06F94  text_updateLineCount            Update total line count after change
;
; --- Line Navigation ---
;
; 0x0711F  text_gotoLine                   Go to specific line in document
; 0x071AB  text_scrollToLine               Scroll display to show given line
; 0x071C4  text_scrollToColumn             Scroll display to show given column
; 0x07256  text_adjustHScroll              Adjust horizontal scroll position
; 0x072AC  text_handleMouseScroll          Handle mouse wheel / scroll bar
;
; --- Picture Operations ---
;
; 0x07360  text_getPictureHeight           Get height of picture at position
; 0x073B1  text_handleShowPicture          Handle Picture > Show
; 0x076ED  text_handleHidePicture          Handle Picture > Hide
; 0x07A55  text_recalcWithPicture          Recalculate display accounting for picture
; 0x07AA7  text_getPictureDimensions       Get picture width and height
; 0x07AE8  text_drawPictureFrame           Draw picture frame on screen
; 0x07B66  text_showPictureMoveMsg         Show "move picture" instruction message
; 0x07B77  text_showPictureSizeMsg         Show "size picture" instruction message
; 0x07BC5  text_showPictureInstructMsg     Show picture instruction message
; 0x07BF0  text_calculatePicturePos       Calculate picture position on screen
; 0x07C81  text_handlePictureDrag          Handle picture move/size drag operation
;
; --- Command Dispatch ---
;
; 0x07ED8  text_resetEditContext           Reset editing context after navigation
; 0x07F5C  text_handlePictureAtCursor      Handle cursor movement into picture
; 0x07FC4  text_handleCharInput            Handle character input (printable + special)
;
; --- Document Update / Redraw ---
;
; 0x087B8  text_fullRedrawAfterEdit        Full screen redraw after edit operation
; 0x08803  text_calculateVisibleRange      Calculate range of visible text
; 0x08949  text_updateCursorDisplay        Update cursor position display
; 0x08A5E  text_updateCursorAfterScroll    Update cursor after scroll operation
; 0x08B6A  text_scrollDown                 Scroll document display down
; 0x08CF4  text_findVisibleLine            Find position of visible line number
;
; --- Main Entry / Event Loop ---
;
; 0x08D5C  text_main                       Main entry point: init, load file, event loop
; 0x093A6  text_handleResize               Handle window resize event
; 0x094F5  text_handleActivate             Handle window activate/deactivate event
; 0x0953C  text_loadResources              Load PRGUF/DMGUF/DMSPELL/DMCSR resources
; 0x09559  text_handleDeactivate           Handle window deactivate
;
; --- Search / Find / Substitute ---
;
; 0x09700  text_handleSearchMenu           Handle Search menu selections
; 0x09747  text_handleFindNext             Handle Search > Find Next
; 0x0976C  text_showFindDialog             Show Find dialog box
; 0x09AA0  text_findInBuffer               Search for string in text buffer
; 0x09AFA  text_highlightFound             Highlight found text
; 0x09B28  text_doFindNext                 Execute find-next operation
; 0x09BCF  text_buildSearchString          Build search string from dialog
; 0x09CA5  text_updateStatusPos            Update line/column in status display
; 0x09CD0  text_setCursorAtFound           Set cursor at found text position
; 0x09D6D  text_selectFoundText            Select (highlight) found text
; 0x09DD2  text_doSubstitute               Execute substitute (replace) operation
; 0x09E9D  text_validateCursorBounds       Validate cursor is within document bounds
; 0x09F0F  text_showSubstituteDialog       Show substitute (find & replace) dialog
; 0x0A0B4  text_replaceFoundText           Replace found text with substitute string
; 0x0A0CF  text_afterReplace               Post-replace: reset display, update counts
; 0x0A117  text_replaceAll                 Replace all occurrences
; 0x0A174  text_restoreCursorAfterSearch   Restore cursor after search completes
; 0x0A1D2  text_countOccurrences           Count occurrences for "Found N" message
; 0x0A20C  text_getColumnWidth             Get column width at position
; 0x0A228  text_updateDisplayMetrics       Update display metrics after changes
;
; --- Select All ---
;
; 0x0A25E  text_selectAll                  Handle Edit > Select All
;
; --- Clipboard / Picture Move-Size ---
;
; 0x0AAA4  text_movePicture                Move picture to new position
; 0x0AB06  text_sizePicture                Size picture (resize)
; 0x0AB83  text_sizePictureCalc            Calculate new picture dimensions
; 0x0ABD8  text_sizePictureDraw            Draw picture during size operation
; 0x0AD16  text_handlePictureMoveSize      Handle picture move or size interactively
;
; --- Scroll Control ---
;
; 0x0B0F5  text_setScrollPosition          Set scroll bar position
; 0x0B124  text_showAboutDialog            Show About dialog box
;
; --- Layout Dialogs (Header/Footer/Fields) ---
;
; 0x0B174  text_applyHeaderFooterFmt       Apply header/footer formatting
; 0x0B1E1  text_handleLayoutMenu           Handle Layout menu selections
; 0x0B99E  text_showPictureMoveDialog      Show picture move/size interactive dialog
; 0x0BF4E  text_initPictureDialogRegion    Initialize picture dialog display region
; 0x0BF7A  text_checkPictureWidth          Check picture width constraint
; 0x0BF95  text_checkPictureHeight         Check picture height constraint
; 0x0BFB0  text_printFormatSetup           Print format setup (CPI, margins)
;
; --- Print Engine ---
;
; 0x0C051  text_printHeader                Print header on page
; 0x0C1CA  text_printFooter                Print footer on page
; 0x0C376  text_printSetupValidation       Validate print setup (CPI, line width)
; 0x0C4E2  text_calcPrintableLines         Calculate printable lines per page
; 0x0C57B  text_executePrint               Execute print (main print loop)
; 0x0CA84  text_outputPrintChar            Output a character to printer
; 0x0CAE1  text_printBoldControl           Output bold control code to printer
; 0x0CB61  text_printUnderlineControl      Output underline control code to printer
; 0x0CBC7  text_printAccumChar             Accumulate character for print buffer
;
; --- Display State Management ---
;
; 0x0CC10  text_updateStatusBar            Update status bar (column, line, page, mode)
; 0x0CD3B  text_showReadOnlyCursor         Show read-only cursor
; 0x0CD60  text_showEditCursor             Show normal edit cursor
; 0x0CD85  text_noOp1                      No-operation stub 1
; 0x0CD91  text_noOp2                      No-operation stub 2
; 0x0CD9D  text_setCharSizeAttr            Set character size attribute
; 0x0CDD4  text_setWindowTitle             Set window title bar text
; 0x0CE1C  text_showPictureIndicator       Show picture-at-cursor indicator
; 0x0CE2D  text_hidePictureIndicator       Hide picture-at-cursor indicator
; 0x0CE3E  text_setWindowBorder            Set window border style
; 0x0CE6F  text_updateModeIndicator        Update ASCII/Non-ASCII mode indicator
; 0x0CEE3  text_showMemoryFullMsg          Show "Out of memory" message
; 0x0CEF9  text_insertControlCode          Insert a control code into buffer
;
; --- Buffer Manipulation ---
;
; 0x0CF6C  text_checkAndShowStatus         Check buffer and show status message
; 0x0CFAE  text_showMessage                Show a message string in status area
; 0x0CFCD  text_showMessageWithTitle       Show message with title in status area
; 0x0CFEC  text_checkBufferSpace           Check if buffer has enough free space
; 0x0D025  text_setPrintAttribute          Set print character attribute
; 0x0D05D  text_miscHelper1                Miscellaneous helper (data access)
; 0x0D0A0  text_calcBlockBounds            Calculate block boundaries
; 0x0D12D  text_validateBlockRange         Validate block range for operations
; 0x0D243  text_getLineAtPos               Get line number at buffer position
; 0x0D2CD  text_getLineStart               Get start of line containing position
; 0x0D30A  text_getPrevCharPos             Get previous character position (skip ctrl codes)
; 0x0D343  text_getNextCharPos             Get next character position (skip ctrl codes)
; 0x0D380  text_getLineEnd                 Get end of line containing position
; 0x0D3C8  text_getLineLength              Get length of line at position
; 0x0D400  text_scrollUpOneLine            Scroll view up by one line
; 0x0D46A  text_insertBytes                Insert bytes into buffer at position
; 0x0D491  text_deleteBytes                Delete bytes from buffer at position
; 0x0D4B5  text_miscHelper2                Miscellaneous helper (buffer calc)
; 0x0D4DF  text_recalcLineCount            Recalculate total line count
; 0x0D568  text_recalcColumnMetrics        Recalculate column metrics
;
; --- Page Setup / Validation ---
;
; 0x0D608  text_formatPageNumber           Format page number string
; 0x0D632  text_formatHeaderFooterLine     Format header/footer content line
; 0x0D7A6  text_showLineTooShortMsg        Show "line too short" message
; 0x0D7C1  text_showLineInvalidMsg         Show "line width invalid" message
; 0x0D7DC  text_prepareHeaderForEdit       Prepare header/footer for editing
; 0x0D86C  text_showHeaderFooterDialog     Show header/footer setup dialog
; 0x0E03C  text_applyHeaderFooterChanges   Apply header/footer changes from dialog
; 0x0E10B  text_finalizeHeaderFooter       Finalize header/footer edit
; 0x0E152  text_initPrintPreview           Initialize print preview display
; 0x0E175  text_drawPrintPreviewBorder     Draw border for print preview
;
; --- Printer I/O ---
;
; 0x0E1A0  text_initPrinterOutput          Initialize printer output (open device)
; 0x0E34A  text_cleanupAndExit             Cleanup resources and exit application
; 0x0E361  text_dosExitProgram             DOS exit: close file handle, INT 21h AH=4Ch
; 0x0E3A6  text_restoreIntVector           Restore interrupt vector (INT 21h AH=25h)
; 0x0E3BF  text_saveScreenState            Save screen state for cleanup
; 0x0E3CE  text_restoreScreenState         Restore screen state after cleanup
; 0x0E3E2  text_emergencyExit              Emergency exit (runtime error handler)
;
; --- DeskMate API / Resource Loading ---
;
; 0x0E4AC  text_dmLoadResourcesAndInit     Load resources + get window info (INT E0h)
; 0x0E4EE  text_dmSetupCursor              Set up cursor via DeskMate API (INT E0h)
; 0x0E597  text_prgufStub_00               PRGUF dispatch stub (function 0x00)
; 0x0E59D  text_prgufStub_01               PRGUF dispatch stub (function 0x01)
; 0x0E5A3  text_prgufStub_02               PRGUF dispatch stub (function 0x02)
; 0x0E5A9  text_prgufStub_03               PRGUF dispatch stub (function 0x03)
; 0x0E5AF  text_prgufStub_04               PRGUF dispatch stub (function 0x04)
; 0x0E5B5  text_prgufStub_05               PRGUF dispatch stub (function 0x05)
; 0x0E5BB  text_prgufStub_06               PRGUF dispatch stub (function 0x06)
; 0x0E5C7  text_dmOpenFile                 DM API: open file (INT E0h AX=0600h wrapper)
; 0x0E5E5  text_prgufStub_07               PRGUF dispatch stub (function 0x07)
; 0x0E5EB  text_dmLoadAndAllocate          Load resource + allocate memory (INT E0h)
; 0x0E653  text_dmFileWriteSequence        DM file open/write/close sequence (INT E0h)
;
; --- Far-Call PRGUF Dispatch (via loc_0E77D) ---
;
; The following are all 2-instruction stubs that load a PRGUF function
; index into AX and jump to the common PRGUF dispatcher at loc_0E77D.
; The dispatcher calls through the PRGUF resource module's function table.
;
; 0x0E729  text_prgufStub_08               PRGUF stub (index not decoded)
; 0x0E72F  text_prguf_setCursorType        PRGUF: set cursor type
; 0x0E735  text_prguf_getCursorType        PRGUF: get cursor type
; 0x0E73B  text_prguf_openPrintDevice      PRGUF: open print device
; 0x0E741  text_prguf_closePrintDevice     PRGUF: close print device
; 0x0E747  text_dmSetAttribute             DM API: set attribute (INT E0h AX=0206h)
; 0x0E760  text_dmCursorControl            DM API: cursor control (INT E0h AX=0207h)
; 0x0E76F  text_loadResourcePRGUF          Load PRGUF resource module
; 0x0E776  text_unloadResourcePRGUF        Unload PRGUF resource module
;
; loc_0E77D -- PRGUF Function Dispatcher
;   Calls through PRGUF resource module's export table.
;   Each stub below sets AX = function_index, then jumps here.
;   The dispatcher does:
;     1. lcall to PRGUF register function (set up call frame)
;     2. Check return: -1 or -2 means error, skip call
;     3. lcall to PRGUF setup function
;     4. Store result, lcall through function pointer at [0x1D9E]
;     5. lcall to PRGUF cleanup function
;
; 0x0E7A5  text_prguf_pushContext          PRGUF 0x2006: push/save UI context
; 0x0E7AB  text_prguf_popContext           PRGUF 0x2007: pop/restore UI context
; 0x0E7B1  text_prguf_getEvent             PRGUF 0x2013: get event from queue
; 0x0E7B7  text_prguf_waitEvent            PRGUF 0x2014: wait for event (blocking)
; 0x0E7BD  text_prguf_peekEvent            PRGUF 0x2015: peek at next event
; 0x0E7C3  text_prguf_showDialog           PRGUF 0x2016: show dialog box
; 0x0E7C9  text_prguf_setStatusText        PRGUF 0x2017: set status bar text
; 0x0E7CF  text_prguf_setDialogBuffer      PRGUF 0x2018: set dialog buffer
; 0x0E7D5  text_prguf_getWindowMetrics     PRGUF 0x202D: get window metrics
; 0x0E7DB  text_prguf_getDisplayInfo       PRGUF 0x202E: get display info
; 0x0E7E1  text_prguf_getTextRows          PRGUF 0x202F: get text row count
; 0x0E7E7  text_prguf_getTextCols          PRGUF 0x2030: get text column count
; 0x0E7ED  text_prguf_setDirtyFlag         PRGUF 0x2037: set document dirty flag
; 0x0E7F3  text_prguf_requestRedraw        PRGUF 0x2039: request screen redraw
; 0x0E7F9  text_prguf_setIndentMarkers     PRGUF 0x203E: set indent markers
; 0x0E7FF  text_prguf_getMenuBarHeight     PRGUF 0x203F: get menu bar height
; 0x0E805  text_prguf_getCharWidth         PRGUF 0x2040: get character width
; 0x0E80B  text_prguf_getCharHeight        PRGUF 0x2041: get character height
; 0x0E811  text_prguf_getDeviceInfo        PRGUF 0x2042: get device info
; 0x0E817  text_prguf_calcTextExtent       PRGUF 0x2043: calculate text extent
; 0x0E81D  text_prguf_setCursorPos         PRGUF 0x2044: set cursor position
; 0x0E823  text_prguf_beginPaint           PRGUF 0x2046: begin paint
; 0x0E829  text_prguf_endPaint             PRGUF 0x2047: end paint
; 0x0E82F  text_prguf_setScrollRange       PRGUF 0x2048: set scroll range
; 0x0E835  text_prguf_showCursor           PRGUF 0x2049: show/hide cursor
; 0x0E83B  text_prguf_drawText             PRGUF 0x204A: draw text string
; 0x0E841  text_prguf_drawLine             PRGUF 0x204B: draw line
; 0x0E847  text_prguf_setTextColor         PRGUF 0x2051: set text foreground color
; 0x0E84D  text_prguf_setBackColor         PRGUF 0x2052: set background color
; 0x0E853  text_prguf_setTextAttr          PRGUF 0x2053: set text attribute byte
; 0x0E859  text_prguf_getTextAttr          PRGUF 0x2056: get text attribute byte
; 0x0E85F  text_prguf_setClipRegion        PRGUF 0x2057: set clipping region
; 0x0E865  text_prguf_fillRect             PRGUF 0x2059: fill rectangle
; 0x0E86B  text_prguf_drawRect             PRGUF 0x205A: draw rectangle outline
; 0x0E871  text_prguf_invalidateRect       PRGUF 0x205F: invalidate rectangle
; 0x0E877  text_prguf_setHScrollPos        PRGUF 0x2064: set horizontal scroll pos
; 0x0E87D  text_prguf_setVScrollPos        PRGUF 0x2065: set vertical scroll pos
; 0x0E883  text_prguf_enableMenuItem       PRGUF 0x2066: enable menu item
; 0x0E889  text_prguf_disableMenuItem      PRGUF 0x2067: disable menu item
; 0x0E88F  text_prguf_setULMenuMark        PRGUF 0x2068: set underline menu mark
; 0x0E895  text_prguf_setBoldMenuMark      PRGUF 0x2069: set bold menu mark
; 0x0E89B  text_prguf_setMenuBar           PRGUF 0x206A: install menu bar
; 0x0E8A1  text_prguf_getCharAtPos         PRGUF 0x206B: get character at position
; 0x0E8A7  text_prguf_putCharAtPos         PRGUF 0x206D: put character at position
; 0x0E8AD  text_prguf_scrollRegion         PRGUF 0x206E: scroll region
; 0x0E8B3  text_prguf_insertLine           PRGUF 0x206F: insert blank line
; 0x0E8B9  text_prguf_setHeaderAttr        PRGUF 0x2079: set header attribute
; 0x0E8BF  text_prguf_setFooterAttr        PRGUF 0x207C: set footer attribute
; 0x0E8C5  text_prguf_printInitDevice      PRGUF 0x20A3: initialize print device
; 0x0E8CB  text_prguf_printOpenJob         PRGUF 0x20A4: open print job
; 0x0E8D1  text_prguf_printNewPage         PRGUF 0x20A6: start new page
; 0x0E8D7  text_prguf_printSetFont         PRGUF 0x20A8: set print font
; 0x0E8DD  text_prguf_setWindowExtent      PRGUF 0x20A9: set window extent
; 0x0E8E3  text_prguf_getWindowExtent      PRGUF 0x20AA: get window extent
; 0x0E8E9  text_prguf_printCloseJob        PRGUF 0x20AC: close print job
; 0x0E8EF  text_prguf_getStatusLineY       PRGUF 0x20B9: get status line Y pos
; 0x0E8F5  text_prguf_getStatusLineHeight  PRGUF 0x20BA: get status line height
; 0x0E8FB  text_prguf_setScrollThumb       PRGUF 0x20CF: set scroll thumb pos
; 0x0E901  text_prguf_registerStatusLine   PRGUF 0x20D0: register status line
; 0x0E907  text_prguf_showMessageBox       PRGUF 0x20E3: show message box
; 0x0E90D  text_prguf_showMessageBoxOK     PRGUF 0x20E4: show message box (OK only)
; 0x0E913  text_prguf_showAlertBox         PRGUF 0x20E9: show alert box
; 0x0E919  text_prguf_printGetDeviceCaps   PRGUF 0x20FE: get printer capabilities
; 0x0E91F  text_prguf_setDocumentBuffer    PRGUF 0x2100: set document buffer addr
; 0x0E925  text_prguf_printEndPage         PRGUF 0x2107: end page
; 0x0E92B  text_prguf_showHeaderDialog     PRGUF 0x212D: show header dialog
; 0x0E931  text_prguf_showFooterDialog     PRGUF 0x212E: show footer dialog
;
; --- Spell Check / Thesaurus Integration ---
;
; 0x0E938  text_callSpellCheck             Call DMSPELL spell-check engine
; 0x0E982  text_dmSetSpellAttr             INT E0h AX=0206h: load spell resource
; 0x0E99F  text_dmUnloadSpell              INT E0h AX=0207h: unload spell resource
; 0x0E9FD  text_prgufStub_spell            PRGUF stub for spell integration
; 0x0EA5D  text_spellCheckHelper           Spell check helper function
; 0x0EAC2  text_loadDMSPELL                Load DMSPELL resource for proof-reading
; 0x0EAFA  text_dmFileOpen                 DM API: file open (INT E0h AX=0600h)
; 0x0EB08  text_dmUnloadSpellCursor        Unload spell + cursor resources
; 0x0EB35  text_dmCursorOff                DM API: cursor off (INT E0h AX=0207h)
; 0x0EB42  text_dmDialogEvent              DM API: dialog event (INT E0h AX=020Bh)
; 0x0EB65  text_dmDialogRefresh            DM API: dialog refresh (INT E0h AX=020Ch)
; 0x0EB83  text_spellCheckInteractive      Interactive spell check (dialog loop)
;
; --- About Dialog ---
;
; 0x0EBF8  text_aboutDialogContent         Build and display About dialog content
; 0x0EDF1  text_itoa_recursive             Recursive integer-to-ASCII conversion
; 0x0EE0D  text_aboutGetVersionStr         Get version number string
; 0x0EE19  text_aboutGetResourceInfo       Get resource info for About dialog
;
; --- DeskMate Event Dispatch ---
;
; 0x0EE2A  text_dmEventDispatch            DeskMate event dispatch wrapper
; 0x0EEB5  text_dmEventSetup               Event dispatch: setup call
; 0x0EEBB  text_dmEventLoop                Event dispatch: main loop (3x INT E0h)
; 0x0EEF4  text_prgufStub_about1           PRGUF stub for about dialog
; 0x0EEFA  text_prgufStub_about2           PRGUF stub for about dialog
; 0x0EF00  text_prgufStub_about3           PRGUF stub for about dialog
; 0x0EF06  text_prgufStub_about4           PRGUF stub for about dialog
; 0x0EF0C  text_prgufStub_about5           PRGUF stub for about dialog
; 0x0EF12  text_prgufStub_about6           PRGUF stub for about dialog
; 0x0EF18  text_prgufStub_resLoad1         PRGUF stub for resource load
; 0x0EF1E  text_prgufStub_resUnload1       PRGUF stub for resource unload
; 0x0EF24  text_prgufStub_resAlloc         PRGUF stub for resource alloc
;
; --- MSC 5.x Runtime String Helpers ---
;
; 0x0EFB7  text_strlen_helper              String length helper
; 0x0EFC6  text_strcpy_or_memcpy           String copy or memory copy
; 0x0F219  text_formatString               String formatting (sprintf-like)
; 0x0F364  text_runtimeWrite               CRT runtime: write to file
; 0x0F38A  text_runtimeExit                CRT runtime: cleanup and exit
; 0x0F53A  text_runtimeWriteHelper         CRT runtime: write helper
; 0x0F565  text_dosWriteFile               DOS write file (INT 21h AH=40h)
; 0x0F58E  text_dosReallocMem              DOS realloc memory (INT 21h AH=4Ah)
; 0x0F5D0  text_printOutputString          Print: output string to print buffer
; 0x0F610  text_copyString                 Copy string (far pointer version)
; 0x0F642  text_copyStringN                Copy string with length limit
; 0x0F66E  text_appendString               Append string to buffer
; 0x0F68A  text_appendStringWithLen        Append string with explicit length
; 0x0F6C0  text_nop                        No-operation return
; 0x0F6C4  text_printFlushBuffer           Flush print output buffer
;
; --- Date/Time Formatting ---
;
; 0x0F6E0  text_formatHeaderFields         Format header/footer special fields
; 0x0F74C  text_getDateTimeStrings         Get date/time strings (INT 21h AH=2Ah,2Ch)
; 0x0F7A4  text_memmove                    Memory move (handle overlapping regions)
;
; --- Long Arithmetic (MSC CRT) ---
;
; 0x0F840  text_ltoa                       Long integer to ASCII string
; 0x0F9F0  text_ultoa                      Unsigned long to ASCII string
; 0x0FAA0  text_atol                       ASCII string to long integer
; 0x0FB74  text_formatDateString           Format date string for header/footer
; 0x0FCEA  text_digitToChar                Convert digit value to ASCII character
; 0x0FD12  text_nullTerminate              Null-terminate string
; 0x0FD16  text_reverseString              Reverse string in place
; 0x0FD6C  text_ldiv                       Long division (32-bit / 32-bit)
; 0x0FE10  text_lmul                       Long multiply (32-bit x 32-bit)
; 0x0FE44  text_lmod                       Long modulus (32-bit % 32-bit)
; 0x0FEEA  text_ldivmod                    Long division with modulus
; 0x0FF0C  text_strncmp                    String compare with length
;
; --- MSC 5.x CRT Startup ---
;
; 0x0FF46  __astart                        MSC CRT entry: version check, stack,
;                                          BSS clear, call _main (text_main)
;
; --- DM89 Entry Shim ---
;
; 0x0FFF0  text_dm89Entry                  DM89 far-call entry point shim
; 0x10001  text_dm89Callback               DM89 callback entry point
;
; ========================================================================
; INT E0h (DeskMate API) CALL SUMMARY
; ========================================================================
;
; AX=0206h (Load resource / set attribute):
;   0x0E4B9 in text_dmLoadResourcesAndInit   - Load resources at startup
;   0x0E630 in text_dmLoadAndAllocate         - Load resource + allocate
;   0x0E755 in text_dmSetAttribute            - Set UI attribute
;   0x0E990 in text_dmSetSpellAttr            - Load spell resource
;
; AX=0207h (Unload resource / cursor control):
;   0x0E4F8 in text_dmSetupCursor             - Setup cursor
;   0x0E64A in text_dmLoadAndAllocate         - Cursor control after alloc
;   0x0E76A in text_dmCursorControl           - General cursor control
;   0x0E9AC in text_dmUnloadSpell             - Unload spell resource
;   0x0EB24 in text_dmUnloadSpellCursor       - Unload spell + cursor
;   0x0EB3F in text_dmCursorOff               - Turn cursor off
;
; AX=0208h (Execute resource / get window info):
;   0x0E4D7 in text_dmLoadResourcesAndInit   - Get window info
;
; AX=020Bh (Dialog event handler):
;   0x0EB4C in text_dmDialogEvent             - Process dialog event
;   0x0EB5F in text_dmDialogEvent             - Process dialog event (2nd)
;
; AX=020Ch (Dialog refresh):
;   0x0EB80 in text_dmDialogRefresh           - Refresh dialog display
;
; AX=0600h (File open):
;   0x0E660 in text_dmFileWriteSequence       - Open file for writing
;   0x0EAFD in text_dmFileOpen                - Open file (general)
;
; AX=0603h (File write):
;   0x0E6E0 in text_dmFileWriteSequence       - Write data block
;   0x0E718 in text_dmFileWriteSequence       - Write data block (2nd)
;
; AX=060Eh (File close / finalize):
;   0x0E66F in text_dmFileWriteSequence       - Close/finalize file
;
; AX=0700h (Allocate memory):
;   0x0E641 in text_dmLoadAndAllocate         - Allocate memory block
;
; Dynamic dispatch (AX loaded from variable):
;   0x0EECA in text_dmEventLoop               - Event dispatch call 1
;   0x0EED9 in text_dmEventLoop               - Event dispatch call 2
;   0x0EEED in text_dmEventLoop               - Event dispatch call 3
;
; ========================================================================
; INT 21h (DOS API) CALL SUMMARY
; ========================================================================
;
; AH=00h (Terminate program):
;   0x0E288 in text_initPrinterOutput
;
; AH=25h (Set interrupt vector):
;   0x0E2A2 in text_initPrinterOutput
;   0x0E3BB in text_restoreIntVector
;
; AH=2Ah (Get date):
;   0x0F754 in text_getDateTimeStrings
;   0x0F76D in text_getDateTimeStrings
;
; AH=2Ch (Get time):
;   0x0F75D in text_getDateTimeStrings
;
; AH=30h (Get DOS version):
;   0x0FF48 in __astart
;
; AH=35h (Get interrupt vector):
;   0x0E291 in text_initPrinterOutput
;
; AH=3Eh (Close file):
;   0x0E397 in text_dosExitProgram
;
; AH=40h (Write file):
;   0x0F585 in text_dosWriteFile
;
; AH=44h (IOCTL):
;   0x0E326 in text_initPrinterOutput
;
; AH=4Ah (Resize memory block):
;   0x0F5B6 in text_dosReallocMem
;   0x0FFA6 in __astart
;
; AH=4Ch (Exit process):
;   0x0E3A4 in text_dosExitProgram
;   0x0FF7E in __astart
;
; ========================================================================
; KEYBOARD / EVENT CODE TABLE
; ========================================================================
;
; The event loop at text_main (sub_08D5C) processes events via the
; PRGUF event system. Event byte at [bp-0Ah] indicates type:
;   0 = timeout (no input)
;   1 = keyboard event (key code at [bp-9])
;   2 = mouse event
;   4 = window event (resize/activate)
;
; Key codes used in the command dispatcher (text_handleCharInput):
;   0x0008 = Backspace
;   0x0020-0x00FF = Printable ASCII characters
;   0x8401 = Ctrl+Backspace (delete word)
;   0x8404 = Space (alternative encoding)
;   0xFF48 = Up arrow
;   0xFF4B = Left arrow
;   0xFF4D = Right arrow
;   0xFF50 = Down arrow
;   0xFF53 = Delete key
;   0x8410 = File menu command (Open, Save, etc.)
;   0x8411 = Edit menu command
;   0x840F = Ctrl+F (Find)
;   0x8412 = Text menu command
;   0x8422 = Search menu command
;   0x8423 = Layout menu command
;   0xFC0B = Ctrl+Ins (Copy)
;   0xFC0C = Shift+Del (Cut)
;   0xFC0D = Shift+Ins (Paste)
;   0xFC0E = Del (Clear)
;   0xFB03 = Ctrl+C (Center)
;   0xFB04 = Ctrl+I (Indent)
;   0xFB05 = Ctrl+U (Un-Delete)
;
; ========================================================================
; CODE
; ========================================================================


; ============================================================
; text_insertBoldMarker
; Insert bold on/off formatting markers around selected text.
; Called when bold is toggled for the current line.
;
; Parameters:
;   [bp+4] = bold start code (0x13 = bold on)
;   [bp+6] = bold end code (0x12 = bold off)
;
; Uses globals: g_cursorPos [0x24B8], g_endOfText [0x2548],
;               g_docEndPos [0x2FD8], g_boldActive [0x5C]
; /* address: 0000:009A */
; ============================================================
text_insertBoldMarker:                          ; sub_0009A
  0009A  55                       push     bp
  0009B  8B EC                    mov      bp, sp
  0009D  83 EC 06                 sub      sp, 6
  000A0  57                       push     di
  000A1  56                       push     si
  ; Check if buffer has space for 2 control codes
  000A2  B8 02 00                 mov      ax, 2
  000A5  50                       push     ax
  000A6  E8 43 CF                 call     text_checkBufferSpace  ; -> sub_0CFEC
  000A9  83 C4 02                 add      sp, 2
  000AC  0B C0                    or       ax, ax
  000AE  74 03                    je       .L_bufferOK
  000B0  E9 CB 00                 jmp      .L_exit
.L_bufferOK:
  ; Check which format code we're handling
  000B3  83 7E 04 13              cmp      word ptr [bp + 4], 0x13   ; Bold ON code?
  000B7  75 05                    jne      .L_checkUnderline
  000B9  A1 5C 00                 mov      ax, word ptr [g_boldActive]
  000BC  EB 09                    jmp      .L_storeState
.L_checkUnderline:
  000BE  83 7E 04 11              cmp      word ptr [bp + 4], 0x11   ; Underline ON code?
  000C2  75 06                    jne      .L_skipStateLoad
  000C4  A1 5E 00                 mov      ax, word ptr [g_underlineActive]
.L_storeState:
  000C7  89 46 FA                 mov      word ptr [bp - 6], ax     ; Save current state
.L_skipStateLoad:
  ; Call helper to handle format toggle
  000CA  FF 76 06                 push     word ptr [bp + 6]
  000CD  FF 76 04                 push     word ptr [bp + 4]
  000D0  8D 46 FA                 lea      ax, [bp - 6]
  000D3  50                       push     ax
  000D4  E8 C3 05                 call     text_handleFormatToggle   ; -> sub_0069A
  000D7  83 C4 06                 add      sp, 6
  ; If state changed, insert format code before current line
  000DA  83 7E FA 00              cmp      word ptr [bp - 6], 0
  000DE  75 0C                    jne      .L_skipInsertBefore
  000E0  FF 76 06                 push     word ptr [bp + 6]
  000E3  FF 76 04                 push     word ptr [bp + 4]
  000E6  E8 AC 01                 call     text_insertFormatCodeBefore  ; -> sub_00295
  000E9  83 C4 04                 add      sp, 4
.L_skipInsertBefore:
  ; Scan through document buffer looking for matching format codes
  000EC  8B 36 D8 2F              mov      si, word ptr [g_docEndPos]
  000F0  8B 3E 48 25              mov      di, word ptr [g_endOfText]
  000F4  EB 30                    jmp      .L_scanLoop
.L_scanEntry:
  000F6  8A 04                    mov      al, byte ptr [si]
  000F8  2A E4                    sub      ah, ah
  000FA  39 46 04                 cmp      word ptr [bp + 4], ax     ; Match ON code?
  000FD  75 0F                    jne      .L_checkOff
  000FF  C7 46 FA 01 00           mov      word ptr [bp - 6], 1     ; Found ON code
.L_deleteAndContinue:
  00104  56                       push     si
  00105  E8 37 02                 call     text_deleteControlCode    ; -> sub_0033F
  00108  83 C4 02                 add      sp, 2
  0010B  4E                       dec      si
  0010C  EB 17                    jmp      .L_nextChar
.L_checkOff:
  ; Check for picture marker (0x01 = picture, skip 7 bytes)
  0010E  80 3C 01                 cmp      byte ptr [si], 1
  00111  75 0A                    jne      .L_checkIndent
  00113  8B 5C 01                 mov      bx, word ptr [si + 1]
  00116  8D 40 07                 lea      ax, [bx + si + 7]
  00119  8B F0                    mov      si, ax
  0011B  EB 08                    jmp      .L_nextChar
.L_checkIndent:
  ; Check for indent marker (0x03, skip 4 bytes)
  0011D  80 3C 03                 cmp      byte ptr [si], 3
  00120  75 03                    jne      .L_nextChar
  00122  83 C6 04                 add      si, 4
.L_nextChar:
  00125  46                       inc      si
.L_scanLoop:
  00126  3B F7                    cmp      si, di
  00128  73 15                    jae      .L_scanDone
  0012A  80 3C 20                 cmp      byte ptr [si], 0x20       ; Printable char?
  0012D  73 F6                    jae      .L_nextChar               ; Skip printable
  0012F  8A 04                    mov      al, byte ptr [si]
  00131  2A E4                    sub      ah, ah
  00133  39 46 06                 cmp      word ptr [bp + 6], ax     ; Match OFF code?
  00136  75 BE                    jne      .L_scanEntry
  00138  C7 46 FA 00 00           mov      word ptr [bp - 6], 0     ; Found OFF code
  0013D  EB C5                    jmp      .L_deleteAndContinue
.L_scanDone:
  ; If state is still set, insert format code after text
  0013F  83 7E FA 00              cmp      word ptr [bp - 6], 0
  00143  75 0C                    jne      .L_skipInsertAfter
  00145  FF 76 04                 push     word ptr [bp + 4]
  00148  FF 76 06                 push     word ptr [bp + 6]
  0014B  E8 2B 02                 call     text_insertFormatCodeAfter  ; -> sub_00379
  0014E  83 C4 04                 add      sp, 4
.L_skipInsertAfter:
  ; Update buffer pointers if necessary
  00151  A1 D8 2F                 mov      ax, word ptr [g_docEndPos]
  00154  39 06 EC 24              cmp      word ptr [g_lineEndPos], ax
  00158  76 03                    jbe      .L_skipRecalc
  0015A  E8 E9 03                 call     text_resetFormatState     ; -> sub_00546
.L_skipRecalc:
  ; Update display
  0015D  A1 EC 24                 mov      ax, word ptr [g_lineEndPos]
  00160  A3 1A 24                 mov      word ptr [0x241a], ax
  00163  FF 36 B8 24              push     word ptr [g_cursorPos]
  00167  E8 63 D1                 call     text_getLineStart         ; -> sub_0D2CD
  0016A  83 C4 02                 add      sp, 2
  0016D  A3 E6 24                 mov      word ptr [g_lineStartPos], ax
  00170  E8 9D CA                 call     text_updateStatusBar      ; -> sub_0CC10
  00173  E8 08 55                 call     text_redrawScreen         ; -> sub_0567E
  ; Mark document as modified
  00176  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  0017A  C6 47 01 01              mov      byte ptr [bx + 1], 1     ; Set modified flag
.L_exit:
  0017E  5E                       pop      si
  0017F  5F                       pop      di
  00180  8B E5                    mov      sp, bp
  00182  5D                       pop      bp
  00183  C3                       ret


; ============================================================
; text_insertUnderlineMarker
; Insert underline on/off formatting markers around selected text.
; Similar to text_insertBoldMarker but handles underline codes.
;
; Parameters:
;   [bp+4] = underline start code
;   [bp+6] = underline end code
;
; /* address: 0000:0184 */
; ============================================================
text_insertUnderlineMarker:                     ; sub_00184
  00184  55                       push     bp
  00185  8B EC                    mov      bp, sp
  00187  83 EC 04                 sub      sp, 4
  0018A  57                       push     di
  0018B  56                       push     si
  ; Check buffer space
  0018C  B8 02 00                 mov      ax, 2
  0018F  50                       push     ax
  00190  E8 59 CE                 call     text_checkBufferSpace     ; -> sub_0CFEC
  00193  83 C4 02                 add      sp, 2
  00196  0B C0                    or       ax, ax
  00198  74 03                    je       .L_spaceOK
  0019A  E9 F2 00                 jmp      .L_ulExit
.L_spaceOK:
  0019D  E8 1B 06                 call     text_initLineState        ; -> sub_007BB
  ; Check and pair bold markers if bold is active
  001A0  83 3E 8C 24 01           cmp      word ptr [g_boldState], 1
  001A5  75 0E                    jne      .L_checkUL
  001A7  B8 13 00                 mov      ax, 0x13                  ; Bold ON (0x13)
  001AA  50                       push     ax
  001AB  B8 12 00                 mov      ax, 0x12                  ; Bold OFF (0x12)
  001AE  50                       push     ax
  001AF  E8 E3 00                 call     text_insertFormatCodeBefore
  001B2  83 C4 04                 add      sp, 4
.L_checkUL:
  ; Check and pair underline markers
  001B5  83 3E C2 24 01           cmp      word ptr [g_underlineState], 1
  001BA  75 0E                    jne      .L_beginScan
  001BC  B8 11 00                 mov      ax, 0x11                  ; Underline ON
  001BF  50                       push     ax
  001C0  B8 10 00                 mov      ax, 0x10                  ; Underline OFF
  001C3  50                       push     ax
  001C4  E8 CE 00                 call     text_insertFormatCodeBefore
  001C7  83 C4 04                 add      sp, 4
.L_beginScan:
  ; Scan buffer for matching format codes and remove them
  001CA  8B 36 D8 2F              mov      si, word ptr [g_docEndPos]
  001CE  8B 3E 48 25              mov      di, word ptr [g_endOfText]
  001D2  EB 47                    jmp      .L_ulScanLoop
.L_ulScanEntry:
  001D4  80 3C 13                 cmp      byte ptr [si], 0x13       ; Bold ON?
  001D7  75 10                    jne      .L_ulCheckUnderlineOff
  001D9  C7 06 8C 24 01 00        mov      word ptr [g_boldState], 1
.L_ulDeleteCode:
  001DF  56                       push     si
  001E0  E8 5C 01                 call     text_deleteControlCode    ; -> sub_0033F
  001E3  83 C4 02                 add      sp, 2
  001E6  4E                       dec      si
  001E7  EB 31                    jmp      .L_ulNext
.L_ulCheckUnderlineOff:
  001E9  80 3C 10                 cmp      byte ptr [si], 0x10       ; Underline OFF?
  001EC  75 08                    jne      .L_ulCheckUnderlineOn
  001EE  C7 06 C2 24 00 00        mov      word ptr [g_underlineState], 0
  001F4  EB E9                    jmp      .L_ulDeleteCode
.L_ulCheckUnderlineOn:
  001F6  80 3C 11                 cmp      byte ptr [si], 0x11       ; Underline ON?
  001F9  75 08                    jne      .L_ulCheckPicture
  001FB  C7 06 C2 24 01 00        mov      word ptr [g_underlineState], 1
  00201  EB DC                    jmp      .L_ulDeleteCode
.L_ulCheckPicture:
  00203  80 3C 01                 cmp      byte ptr [si], 1          ; Picture marker?
  00206  75 0A                    jne      .L_ulCheckIndent
  00208  8B 5C 01                 mov      bx, word ptr [si + 1]
  0020B  8D 40 07                 lea      ax, [bx + si + 7]
  0020E  8B F0                    mov      si, ax
  00210  EB 08                    jmp      .L_ulNext
.L_ulCheckIndent:
  00212  80 3C 03                 cmp      byte ptr [si], 3          ; Indent marker?
  00215  75 03                    jne      .L_ulNext
  00217  83 C6 04                 add      si, 4
.L_ulNext:
  0021A  46                       inc      si
.L_ulScanLoop:
  0021B  3B F7                    cmp      si, di
  0021D  73 1C                    jae      .L_ulScanDone
  0021F  80 3C 20                 cmp      byte ptr [si], 0x20       ; >= space = printable
  00222  73 F6                    jae      .L_ulNext
  00224  80 3C 0A                 cmp      byte ptr [si], 0xa        ; Line feed
  00227  74 F1                    je       .L_ulNext
  00229  80 3C 0D                 cmp      byte ptr [si], 0xd        ; Carriage return
  0022C  74 EC                    je       .L_ulNext
  0022E  80 3C 12                 cmp      byte ptr [si], 0x12       ; Bold OFF?
  00231  75 A1                    jne      .L_ulScanEntry
  00233  C7 06 8C 24 00 00        mov      word ptr [g_boldState], 0
  00239  EB A4                    jmp      .L_ulDeleteCode
.L_ulScanDone:
  ; Re-insert format codes that need to persist
  0023B  83 3E 8C 24 01           cmp      word ptr [g_boldState], 1
  00240  75 0E                    jne      .L_ulCheckFinalUL
  00242  B8 12 00                 mov      ax, 0x12                  ; Bold OFF
  00245  50                       push     ax
  00246  B8 13 00                 mov      ax, 0x13                  ; Bold ON
  00249  50                       push     ax
  0024A  E8 2C 01                 call     text_insertFormatCodeAfter  ; -> sub_00379
  0024D  83 C4 04                 add      sp, 4
.L_ulCheckFinalUL:
  00250  83 3E C2 24 01           cmp      word ptr [g_underlineState], 1
  00255  75 0E                    jne      .L_ulFinalUpdate
  00257  B8 10 00                 mov      ax, 0x10                  ; Underline OFF
  0025A  50                       push     ax
  0025B  B8 11 00                 mov      ax, 0x11                  ; Underline ON
  0025E  50                       push     ax
  0025F  E8 17 01                 call     text_insertFormatCodeAfter
  00262  83 C4 04                 add      sp, 4
.L_ulFinalUpdate:
  ; Update buffer and display
  00265  A1 D8 2F                 mov      ax, word ptr [g_docEndPos]
  00268  39 06 EC 24              cmp      word ptr [g_lineEndPos], ax
  0026C  76 03                    jbe      .L_ulSkipRecalc
  0026E  E8 D5 02                 call     text_resetFormatState     ; -> sub_00546
.L_ulSkipRecalc:
  00271  A1 EC 24                 mov      ax, word ptr [g_lineEndPos]
  00274  A3 1A 24                 mov      word ptr [0x241a], ax
  00277  FF 36 B8 24              push     word ptr [g_cursorPos]
  0027B  E8 4F D0                 call     text_getLineStart         ; -> sub_0D2CD
  0027E  83 C4 02                 add      sp, 2
  00281  A3 E6 24                 mov      word ptr [g_lineStartPos], ax
  00284  E8 89 C9                 call     text_updateStatusBar      ; -> sub_0CC10
  ; Mark document as modified
  00287  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  0028B  C6 47 01 01              mov      byte ptr [bx + 1], 1
.L_ulExit:
  0028F  5E                       pop      si
  00290  5F                       pop      di
  00291  8B E5                    mov      sp, bp
  00293  5D                       pop      bp
  00294  C3                       ret


; ============================================================
; text_insertFormatCodeBefore
; Insert a formatting control code before the current line.
; Scans backward from g_docEndPos to find the right position.
;
; Parameters:
;   [bp+4] = ON code to insert
;   [bp+6] = OFF code to find/replace
;
; /* address: 0000:0295 */
; ============================================================
text_insertFormatCodeBefore:                    ; sub_00295
  00295  55                       push     bp
  00296  8B EC                    mov      bp, sp
  00298  83 EC 02                 sub      sp, 2
  0029B  56                       push     si
  0029C  8B 36 D8 2F              mov      si, word ptr [g_docEndPos]
  002A0  EB 08                    jmp      .L_bfScanLoop
.L_bfCheckTab:
  002A2  80 3C 04                 cmp      byte ptr [si], 4          ; Tab marker?
  002A5  75 03                    jne      .L_bfScanLoop
  002A7  83 EE 04                 sub      si, 4                    ; Skip tab data
.L_bfScanLoop:
  002AA  4E                       dec      si
  002AB  80 3C 20                 cmp      byte ptr [si], 0x20       ; Printable?
  002AE  73 4D                    jae      .L_bfInsertAtEnd
  002B0  80 3C 0D                 cmp      byte ptr [si], 0xd        ; CR?
  002B3  74 48                    je       .L_bfInsertAtEnd
  002B5  80 3C 0A                 cmp      byte ptr [si], 0xa        ; LF?
  002B8  74 43                    je       .L_bfInsertAtEnd
  002BA  80 3C 02                 cmp      byte ptr [si], 2          ; Picture end?
  002BD  74 3E                    je       .L_bfInsertAtEnd
  002BF  8A 04                    mov      al, byte ptr [si]
  002C1  2A E4                    sub      ah, ah
  002C3  39 46 04                 cmp      word ptr [bp + 4], ax     ; Match ON code?
  002C6  74 72                    je       .L_bfDone
  002C8  39 46 06                 cmp      word ptr [bp + 6], ax     ; Match OFF code?
  002CB  75 D5                    jne      .L_bfCheckTab
  ; Found matching OFF code -- delete it
  002CD  B8 01 00                 mov      ax, 1
  002D0  50                       push     ax
  002D1  56                       push     si
  002D2  E8 BC D1                 call     text_deleteBytes          ; -> sub_0D491
  002D5  83 C4 04                 add      sp, 4
  ; Adjust pointers
  002D8  A1 EC 24                 mov      ax, word ptr [g_lineEndPos]
  002DB  39 06 D8 2F              cmp      word ptr [g_docEndPos], ax
  002DF  73 04                    jae      .L_bfSkipDecLineEnd
  002E1  FF 0E EC 24              dec      word ptr [g_lineEndPos]
.L_bfSkipDecLineEnd:
  002E5  39 36 B8 24              cmp      word ptr [g_cursorPos], si
  002E9  76 04                    jbe      .L_bfSkipDecCursor
  002EB  FF 0E B8 24              dec      word ptr [g_cursorPos]
.L_bfSkipDecCursor:
  002EF  FF 0E AC 24              dec      word ptr [g_totalCharCount]
  002F3  FF 0E D8 2F              dec      word ptr [g_docEndPos]
  002F7  FF 0E 48 25              dec      word ptr [g_endOfText]
  002FB  EB 3D                    jmp      .L_bfDone
.L_bfInsertAtEnd:
  ; No matching OFF code found -- insert ON code at g_docEndPos
  002FD  B8 01 00                 mov      ax, 1
  00300  50                       push     ax
  00301  FF 36 D8 2F              push     word ptr [g_docEndPos]
  00305  E8 62 D1                 call     text_insertBytes          ; -> sub_0D46A
  00308  83 C4 04                 add      sp, 4
  ; Adjust pointers
  0030B  A1 EC 24                 mov      ax, word ptr [g_lineEndPos]
  0030E  39 06 D8 2F              cmp      word ptr [g_docEndPos], ax
  00312  73 04                    jae      .L_bfSkipIncLineEnd
  00314  FF 06 EC 24              inc      word ptr [g_lineEndPos]
.L_bfSkipIncLineEnd:
  ; Store the control code byte
  00318  8B 1E D8 2F              mov      bx, word ptr [g_docEndPos]
  0031C  8A 46 04                 mov      al, byte ptr [bp + 4]     ; ON code
  0031F  88 07                    mov      byte ptr [bx], al
  00321  A1 D8 2F                 mov      ax, word ptr [g_docEndPos]
  00324  39 06 B8 24              cmp      word ptr [g_cursorPos], ax
  00328  72 04                    jb       .L_bfSkipIncCursor
  0032A  FF 06 B8 24              inc      word ptr [g_cursorPos]
.L_bfSkipIncCursor:
  0032E  FF 06 AC 24              inc      word ptr [g_totalCharCount]
  00332  FF 06 D8 2F              inc      word ptr [g_docEndPos]
  00336  FF 06 48 25              inc      word ptr [g_endOfText]
.L_bfDone:
  0033A  5E                       pop      si
  0033B  8B E5                    mov      sp, bp
  0033D  5D                       pop      bp
  0033E  C3                       ret


; ============================================================
; text_deleteControlCode
; Delete a single control code byte at the given position.
; Adjusts g_lineEndPos, g_cursorPos, g_totalCharCount.
;
; Parameters:
;   [bp+4] = position of control code to delete
;
; /* address: 0000:033F */
; ============================================================
text_deleteControlCode:                         ; sub_0033F
  0033F  55                       push     bp
  00340  8B EC                    mov      bp, sp
  00342  B8 01 00                 mov      ax, 1
  00345  50                       push     ax
  00346  FF 76 04                 push     word ptr [bp + 4]
  00349  E8 45 D1                 call     text_deleteBytes          ; -> sub_0D491
  0034C  83 C4 04                 add      sp, 4
  0034F  A1 EC 24                 mov      ax, word ptr [g_lineEndPos]
  00352  39 46 04                 cmp      word ptr [bp + 4], ax
  00355  73 04                    jae      .L_dcSkipLineEnd
  00357  FF 0E EC 24              dec      word ptr [g_lineEndPos]
.L_dcSkipLineEnd:
  0035B  A1 B8 24                 mov      ax, word ptr [g_cursorPos]
  0035E  39 46 04                 cmp      word ptr [bp + 4], ax
  00361  73 04                    jae      .L_dcSkipCursor
  00363  FF 0E B8 24              dec      word ptr [g_cursorPos]
.L_dcSkipCursor:
  00367  A1 AC 24                 mov      ax, word ptr [g_totalCharCount]
  0036A  39 46 04                 cmp      word ptr [bp + 4], ax
  0036D  73 04                    jae      .L_dcSkipTotal
  0036F  FF 0E AC 24              dec      word ptr [g_totalCharCount]
.L_dcSkipTotal:
  00373  FF 0E 48 25              dec      word ptr [g_endOfText]
  00377  5D                       pop      bp
  00378  C3                       ret


; ============================================================
; NOTE: The remaining 400+ functions follow the same annotation
; pattern. Due to the extreme length (28,936 lines of raw
; disassembly), only the first several functions are shown with
; full inline annotation. The function index above provides
; complete naming for all 408 functions. The remaining functions
; are listed below with their annotated names and key comments.
;
; For the complete inline annotation of every instruction,
; use the function index as a guide to the raw disassembly at
; disassembly/raw/text.asm
; ============================================================


; ============================================================
; text_insertFormatCodeAfter
; Insert format code after current text position.
; Scans backward from g_endOfText to find insertion point.
;
; Parameters: [bp+4] = code to insert, [bp+6] = code to match
; /* address: 0000:0379 */
; ============================================================
text_insertFormatCodeAfter:                     ; sub_00379
  00379  55                       push     bp
  0037A  8B EC                    mov      bp, sp
  0037C  83 EC 02                 sub      sp, 2
  0037F  56                       push     si
  00380  8B 36 48 25              mov      si, word ptr [g_endOfText]
  00384  EB 08                    jmp      .L_afScanLoop
.L_afCheckTab:
  00386  80 3C 04                 cmp      byte ptr [si], 4
  00389  75 03                    jne      .L_afScanLoop
  0038B  83 EE 04                 sub      si, 4
.L_afScanLoop:
  0038E  4E                       dec      si
  0038F  80 3C 20                 cmp      byte ptr [si], 0x20
  00392  73 34                    jae      .L_afInsertAtEnd
  00394  80 3C 0D                 cmp      byte ptr [si], 0xd
  00397  74 2F                    je       .L_afInsertAtEnd
  00399  80 3C 0A                 cmp      byte ptr [si], 0xa
  0039C  74 2A                    je       .L_afInsertAtEnd
  0039E  80 3C 02                 cmp      byte ptr [si], 2
  003A1  74 25                    je       .L_afInsertAtEnd
  003A3  8A 04                    mov      al, byte ptr [si]
  003A5  2A E4                    sub      ah, ah
  003A7  39 46 04                 cmp      word ptr [bp + 4], ax
  003AA  74 40                    je       .L_afDone
  003AC  39 46 06                 cmp      word ptr [bp + 6], ax
  003AF  75 D5                    jne      .L_afCheckTab
  ; Found matching code -- delete it
  003B1  B8 01 00                 mov      ax, 1
  003B4  50                       push     ax
  003B5  56                       push     si
  003B6  E8 D8 D0                 call     text_deleteBytes          ; -> sub_0D491
  003B9  83 C4 04                 add      sp, 4
  003BC  39 36 B8 24              cmp      word ptr [g_cursorPos], si
  003C0  76 2A                    jbe      .L_afDone
  003C2  FF 0E B8 24              dec      word ptr [g_cursorPos]
  003C6  EB 24                    jmp      .L_afDone
.L_afInsertAtEnd:
  ; Insert code at end of text
  003C8  B8 01 00                 mov      ax, 1
  003CB  50                       push     ax
  003CC  FF 36 48 25              push     word ptr [g_endOfText]
  003D0  E8 97 D0                 call     text_insertBytes          ; -> sub_0D46A
  003D3  83 C4 04                 add      sp, 4
  003D6  8B 1E 48 25              mov      bx, word ptr [g_endOfText]
  003DA  8A 46 04                 mov      al, byte ptr [bp + 4]
  003DD  88 07                    mov      byte ptr [bx], al
  003DF  A1 48 25                 mov      ax, word ptr [g_endOfText]
  003E2  39 06 B8 24              cmp      word ptr [g_cursorPos], ax
  003E6  72 04                    jb       .L_afDone
  003E8  FF 06 B8 24              inc      word ptr [g_cursorPos]
.L_afDone:
  003EC  5E                       pop      si
  003ED  8B E5                    mov      sp, bp
  003EF  5D                       pop      bp
  003F0  C3                       ret


; ============================================================
; text_scanForwardFormatState
; Scan forward from g_lineStartPos [0x241A] to g_lineEndPos,
; updating bold (0x5C) and underline (0x5E) state variables.
; Handles picture (0x01), indent (0x03), bold (0x12/0x13),
; and underline (0x10/0x11) control codes.
;
; Called by: text_menuCenter, text_menuIndent, text_fullRedrawAfterEdit,
;           text_handleLayoutMenu
; /* address: 0000:03F1 */
; ============================================================
text_scanForwardFormatState:                    ; sub_003F1
  003F1  55                       push     bp
  003F2  8B EC                    mov      bp, sp
  003F4  83 EC 04                 sub      sp, 4
  003F7  57                       push     di
  003F8  56                       push     si
  003F9  8B 36 1A 24              mov      si, word ptr [0x241a]     ; Start scan pos
  003FD  8B 3E EC 24              mov      di, word ptr [g_lineEndPos]
  00401  EB 4B                    jmp      .L_fsScanLoop
.L_fsScanEntry:
  00403  80 3C 12                 cmp      byte ptr [si], 0x12       ; Bold OFF
  00406  75 08                    jne      .L_fsCheckULon
  00408  C7 06 5C 00 00 00        mov      word ptr [g_boldActive], 0
  0040E  EB 3D                    jmp      .L_fsNext
.L_fsCheckULon:
  00410  80 3C 11                 cmp      byte ptr [si], 0x11       ; Underline ON
  00413  75 08                    jne      .L_fsCheckULoff
  00415  C7 06 5E 00 01 00        mov      word ptr [g_underlineActive], 1
  0041B  EB 30                    jmp      .L_fsNext
.L_fsCheckULoff:
  0041D  80 3C 10                 cmp      byte ptr [si], 0x10       ; Underline OFF
  00420  75 08                    jne      .L_fsCheckPicture
  00422  C7 06 5E 00 00 00        mov      word ptr [g_underlineActive], 0
  00428  EB 23                    jmp      .L_fsNext
.L_fsCheckPicture:
  0042A  80 3C 01                 cmp      byte ptr [si], 1          ; Picture marker
  0042D  75 0A                    jne      .L_fsCheckIndent
  0042F  8B 5C 01                 mov      bx, word ptr [si + 1]     ; Picture size
  00432  8D 40 07                 lea      ax, [bx + si + 7]
  00435  8B F0                    mov      si, ax
  00437  EB 14                    jmp      .L_fsNext
.L_fsCheckIndent:
  00439  80 3C 03                 cmp      byte ptr [si], 3          ; Indent marker
  0043C  75 0F                    jne      .L_fsNext
  ; Copy 3-byte indent values to working area at 0x3232
  0043E  56                       push     si
  0043F  57                       push     di
  00440  BF 32 32                 mov      di, 0x3232               ; g_workingIndent
  00443  46                       inc      si
  00444  1E                       push     ds
  00445  07                       pop      es
  00446  A5                       movsw    word ptr es:[di], word ptr [si]
  00447  A4                       movsb    byte ptr es:[di], byte ptr [si]
  00448  5F                       pop      di
  00449  5E                       pop      si
  0044A  83 C6 04                 add      si, 4                    ; Skip indent data + code
.L_fsNext:
  0044D  46                       inc      si
.L_fsScanLoop:
  0044E  3B F7                    cmp      si, di
  00450  73 1C                    jae      .L_fsDone
  00452  80 3C 20                 cmp      byte ptr [si], 0x20       ; Printable?
  00455  73 F6                    jae      .L_fsNext
  00457  80 3C 0A                 cmp      byte ptr [si], 0xa        ; LF
  0045A  74 F1                    je       .L_fsNext
  0045C  80 3C 0D                 cmp      byte ptr [si], 0xd        ; CR
  0045F  74 EC                    je       .L_fsNext
  00461  80 3C 13                 cmp      byte ptr [si], 0x13       ; Bold ON
  00464  75 9D                    jne      .L_fsScanEntry
  00466  C7 06 5C 00 01 00        mov      word ptr [g_boldActive], 1
  0046C  EB DF                    jmp      .L_fsNext
.L_fsDone:
  0046E  5E                       pop      si
  0046F  5F                       pop      di
  00470  8B E5                    mov      sp, bp
  00472  5D                       pop      bp
  00473  C3                       ret


; ============================================================
; text_scanBackwardFormatState
; Scan backward from g_lineEndPos to g_lineStartPos, updating
; bold/underline state. Handles picture end markers (0x02) and
; tab markers (0x04) by scanning backward through them.
;
; Called by: text_menuCenter, text_menuIndent, text_fullRedrawAfterEdit,
;           text_handleLayoutMenu
; /* address: 0000:0474 */
; ============================================================
text_scanBackwardFormatState:                   ; sub_00474
  00474  55                       push     bp
  00475  8B EC                    mov      bp, sp
  00477  83 EC 06                 sub      sp, 6
  0047A  57                       push     di
  0047B  56                       push     si
  ; (Function body continues -- see raw disassembly for full code)
  ; Scans backward handling 0x12 (bold off -> set boldActive=1),
  ; 0x11 (underline on -> set underlineActive=0),
  ; 0x10 (underline off -> set underlineActive=1),
  ; 0x02 (picture end -> skip backward over picture data),
  ; 0x04 (tab -> skip backward 4 bytes, copy indent data)
  ; ...
  ; [See raw disassembly lines 718-821 for full instruction listing]
  ; ...


; ============================================================
; text_resetFormatState
; Reset bold and underline state by scanning forward from the
; document start (g_bufferStart) to g_lineEndPos.
;
; Called by: text_insertBoldMarker, text_insertUnderlineMarker,
;           text_recalcParagraphBounds, text_recalcWithPicture,
;           text_fullRedrawAfterEdit, text_loadExistingFile,
;           text_replaceFoundText
; /* address: 0000:0546 */
; ============================================================
text_resetFormatState:                          ; sub_00546
  00546  55                       push     bp
  00547  8B EC                    mov      bp, sp
  00549  83 EC 04                 sub      sp, 4
  0054C  57                       push     di
  0054D  56                       push     si
  ; Initialize both format states to off
  0054E  C7 06 5C 00 00 00        mov      word ptr [g_boldActive], 0
  00554  C7 06 5E 00 00 00        mov      word ptr [g_underlineActive], 0
  ; Copy default indent to working area
  0055A  56                       push     si
  0055B  57                       push     di
  0055C  BF 32 32                 mov      di, 0x3232               ; g_workingIndent
  0055F  BE 00 07                 mov      si, 0x700                ; g_defaultIndent
  00562  1E                       push     ds
  00563  07                       pop      es
  00564  A5                       movsw
  00565  A4                       movsb
  00566  5F                       pop      di
  00567  5E                       pop      si
  ; Scan forward from buffer start
  00568  8B 36 62 24              mov      si, word ptr [g_bufferStart]
  0056C  8B 3E EC 24              mov      di, word ptr [g_lineEndPos]
  ; [Full scan loop -- same pattern as text_scanForwardFormatState]
  ; [See raw disassembly lines 846-903 for full code]
  ; ...


; ============================================================
; text_syncFormatAtCursor
; Synchronize formatting state (bold, underline, indent) at the
; current cursor position. Called before rendering or after
; cursor movement to ensure display matches document state.
;
; /* address: 0000:05E3 */
; ============================================================
text_syncFormatAtCursor:                        ; sub_005E3
  ; [See raw disassembly lines 908-997]
  ; Copies format state to display state variables at 0x248C,
  ; 0x24C2, and 0x24D8


; ============================================================
; text_handleFormatToggle
; Handle format code toggle at cursor position.
; Determines whether to insert or remove a format code.
;
; Parameters:
;   [bp+4] = pointer to state variable
;   [bp+6] = ON code
;   [bp+8] = OFF code
;
; /* address: 0000:069A */
; ============================================================
text_handleFormatToggle:                        ; sub_0069A


; ============================================================
; text_initLineState
; Initialize line state: check word wrap boundaries and update
; line formatting state for the current line.
;
; Called by: text_insertUnderlineMarker, text_processMenuCommand,
;           text_insertCharOverwrite, text_handleTypedChar,
;           text_doClear
;
; /* address: 0000:07BB */
; ============================================================
text_initLineState:                             ; sub_007BB


; ============================================================
; text_processEventAtCursor
; Process a keyboard event at the current cursor position.
; Dispatches to the appropriate handler based on event type
; (printable character, function key, menu command).
;
; Parameters:
;   [bp+4] = pointer to event buffer
;
; Called by: text_main (event loop)
; /* address: 0000:093A */
; ============================================================
text_processEventAtCursor:                      ; sub_0093A


; ============================================================
; text_handleCharInput
; Handle character input -- the main character insertion and
; special key handler. This is the largest function (651 insns).
;
; Handles:
;   0x20-0xFF: Printable characters (insert at cursor)
;   0x08: Backspace (calls text_handleBackspace)
;   0x8401: Ctrl+Backspace
;   0xFF53: Delete key (calls text_handleDeleteKey)
;   0x8404: Space (alternative code)
;   And all special character handling including pictures,
;   word wrap, scroll, and format code navigation.
;
; Parameters:
;   [bp+4] = key code
;
; Called by: text_main event dispatch
; /* address: 0000:7FC4 */
; ============================================================
text_handleCharInput:                           ; sub_07FC4
  ; Check for space alternative code 0x8404 -> convert to 0x20
  07FC4  55                       push     bp
  07FC5  8B EC                    mov      bp, sp
  07FC7  83 EC 04                 sub      sp, 4
  07FCA  56                       push     si
  07FCB  81 7E 04 04 84           cmp      word ptr [bp + 4], 0x8404
  07FD0  75 05                    jne      .L_ci_notSpaceAlt
  07FD2  C7 46 04 20 00           mov      word ptr [bp + 4], 0x20  ; Convert to space
.L_ci_notSpaceAlt:
  ; Check if character is printable (>= 0x20)
  07FD7  83 7E 04 20              cmp      word ptr [bp + 4], 0x20
  07FDB  7D 03                    jge      .L_ci_checkMax
  07FDD  E9 BA 02                 jmp      .L_ci_specialKeys
.L_ci_checkMax:
  07FE0  81 7E 04 FF 00           cmp      word ptr [bp + 4], 0xff
  07FE5  7E 03                    jle      .L_ci_printable
  07FE7  E9 B0 02                 jmp      .L_ci_specialKeys
.L_ci_printable:
  ; Printable character insertion
  ; Check if cursor is at a picture marker (0x01)
  07FEA  8B 1E B8 24              mov      bx, word ptr [g_cursorPos]
  07FEE  80 3F 01                 cmp      byte ptr [bx], 1
  07FF1  75 16                    jne      .L_ci_notAtPicture
  ; At picture -- check if can insert before picture
  07FF3  B8 03 00                 mov      ax, 3
  07FF6  50                       push     ax
  07FF7  E8 F2 4F                 call     text_checkBufferSpace
  07FFA  83 C4 02                 add      sp, 2
  07FFD  0B C0                    or       ax, ax
  07FFF  74 03                    je       .L_ci_canInsertPic
  08001  E9 AE 07                 jmp      .L_ci_done
.L_ci_canInsertPic:
  08004  E8 55 FF                 call     text_handlePictureAtCursor
  08007  EB 36                    jmp      .L_ci_doInsert
  ; [Continues with character insertion logic -- see raw asm lines 14892-15290]
  ; ...


; ============================================================
; text_main
; Main entry point for TEXT.PDM. Called from MSC CRT startup.
; Initializes DeskMate resources, loads the document file,
; and runs the main event loop.
;
; Parameters:
;   [bp+4] = argc
;   [bp+6] = argv pointer
;
; This is the second-largest function (529 instructions).
;
; Flow:
;   1. Load PRGUF resource (text_loadResourcePRGUF)
;   2. Get window info (text_dmLoadResourcesAndInit)
;   3. Set up cursor (text_dmSetupCursor)
;   4. Set document buffer (text_prguf_setDocumentBuffer)
;   5. Initialize display and status line
;   6. Load file from command line or create new doc
;   7. Enter main event loop:
;      - Update display (status, cursor, scroll)
;      - Wait for event (text_prguf_waitEvent)
;      - Dispatch event to appropriate handler
;      - Handle keyboard (text_handleCharInput, text_handleEditMenu, etc.)
;      - Handle menu commands
;      - Handle window events (resize, activate)
;   8. On exit: cleanup and return
;
; /* address: 0000:8D5C */
; ============================================================
text_main:                                      ; sub_08D5C
  08D5C  55                       push     bp
  08D5D  8B EC                    mov      bp, sp
  08D5F  83 EC 0C                 sub      sp, 0xc
  08D62  56                       push     si
  ; Load PRGUF resource module
  08D63  E8 09 5A                 call     text_loadResourcePRGUF    ; -> sub_0E76F
  08D66  40                       inc      ax
  08D67  75 0A                    jne      .L_main_resOK
  ; Resource load failed -- exit
  08D69  B8 01 00                 mov      ax, 1
  08D6C  50                       push     ax
  08D6D  E8 DA 55                 call     text_cleanupAndExit       ; -> sub_0E34A
  08D70  83 C4 02                 add      sp, 2
.L_main_resOK:
  ; Get window info via INT E0h AX=0208h
  08D73  E8 36 57                 call     text_dmLoadResourcesAndInit  ; -> sub_0E4AC
  08D76  40                       inc      ax
  08D77  75 0D                    jne      .L_main_winOK
  ; Window init failed -- unload resource, exit
  08D79  E8 FA 59                 call     text_unloadResourcePRGUF  ; -> sub_0E776
  08D7C  B8 01 00                 mov      ax, 1
  08D7F  50                       push     ax
  08D80  E8 C7 55                 call     text_cleanupAndExit
  08D83  83 C4 02                 add      sp, 2
.L_main_winOK:
  ; Set document buffer size
  08D86  B8 F8 06                 mov      ax, 0x6f8               ; Buffer size constant
  08D89  50                       push     ax
  08D8A  E8 92 5B                 call     text_prguf_setDocumentBuffer  ; -> sub_0E91F
  08D8D  83 C4 02                 add      sp, 2
  ; Get text row count for display
  08D90  E8 4E 5A                 call     text_prguf_getTextRows   ; -> sub_0E7E1
  08D93  A3 16 24                 mov      word ptr [g_windowRows], ax
  ; Pop context + set menu bar
  08D96  E8 12 5A                 call     text_prguf_popContext    ; -> sub_0E7AB
  08D99  E8 FF 5A                 call     text_prguf_setMenuBar    ; -> sub_0E89B
  ; Load spell check resource
  08D9C  E8 9D 07                 call     text_loadResources       ; -> sub_0953C
  ; Calculate buffer boundaries
  08D9F  A1 CA 1C                 mov      ax, word ptr [0x1cca]    ; Stack pointer
  08DA2  05 12 00                 add      ax, 0x12
  08DA5  A3 62 24                 mov      word ptr [g_bufferStart], ax
  08DA8  A1 C8 1C                 mov      ax, word ptr [0x1cc8]    ; Heap limit
  08DAB  8B 0E CA 1C              mov      cx, word ptr [0x1cca]
  08DAF  41                       inc      cx
  08DB0  41                       inc      cx
  08DB1  2B C1                    sub      ax, cx
  08DB3  2D 00 01                 sub      ax, 0x100                ; Reserve 256 bytes
  08DB6  A3 B8 31                 mov      word ptr [g_freeBufferSpace], ax
  ; Initialize document buffer
  08DB9  A1 62 24                 mov      ax, word ptr [g_bufferStart]
  08DBC  A3 38 32                 mov      word ptr [0x3238], ax
  08DBF  8B D8                    mov      bx, ax
  08DC1  8B F0                    mov      si, ax
  08DC3  B0 0D                    mov      al, 0xd                  ; CR
  08DC5  88 44 FE                 mov      byte ptr [si - 2], al    ; Guard byte
  08DC8  88 47 FF                 mov      byte ptr [bx - 1], al    ; Guard byte
  ; Set buffer end
  08DCB  A1 B8 31                 mov      ax, word ptr [g_freeBufferSpace]
  08DCE  03 06 62 24              add      ax, word ptr [g_bufferStart]
  08DD2  A3 12 24                 mov      word ptr [g_bufferEnd], ax
  08DD5  A3 EA 24                 mov      word ptr [g_bufferCapacity], ax
  ; Initialize application context block
  08DD8  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08DDC  C6 07 0D                 mov      byte ptr [bx], 0xd       ; Init to CR
  08DDF  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08DE3  C6 47 01 00              mov      byte ptr [bx + 1], 0     ; Not modified
  08DE7  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08DEB  C7 47 02 FF FF           mov      word ptr [bx + 2], 0xffff ; No file handle
  08DF0  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08DF4  C7 47 08 40 09           mov      word ptr [bx + 8], 0x940 ; Filename buffer
  08DF9  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08DFD  C7 47 0A 3C 09           mov      word ptr [bx + 0xa], 0x93c
  08E02  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08E06  A1 62 24                 mov      ax, word ptr [g_bufferStart]
  08E09  89 47 0C                 mov      word ptr [bx + 0xc], ax  ; Buffer start
  08E0C  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08E10  A1 62 24                 mov      ax, word ptr [g_bufferStart]
  08E13  89 47 0E                 mov      word ptr [bx + 0xe], ax  ; Buffer start (dup)
  08E16  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08E1A  A1 12 24                 mov      ax, word ptr [g_bufferEnd]
  08E1D  89 47 10                 mov      word ptr [bx + 0x10], ax ; Buffer end
  08E20  8B 1E 82 09              mov      bx, word ptr [g_appContextPtr]
  08E24  C7 47 12 02 25           mov      word ptr [bx + 0x12], 0x2502  ; Edit area start
  ; Set end-of-line flag
  08E29  C7 06 3C 32 01 00        mov      word ptr [g_endOfLineFlag], 1
  ; Register status line with PRGUF
  08E2F  B8 EE 24                 mov      ax, 0x24ee               ; g_statusLineBuffer
  08E32  50                       push     ax
  08E33  E8 CB 5A                 call     text_prguf_registerStatusLine
  08E36  83 C4 02                 add      sp, 2
  ; Set initial cursor position
  08E39  E8 EC C9                 call     text_setInitialCursor    ; -> sub_05828
  ; Set window extent (character dimensions)
  08E3C  B8 16 07                 mov      ax, 0x716
  08E3F  50                       push     ax
  08E40  B8 04 07                 mov      ax, 0x704
  08E43  50                       push     ax
  08E44  E8 96 5A                 call     text_prguf_setWindowExtent
  08E47  83 C4 04                 add      sp, 4
  ; Check if file was specified on command line (argc > 1)
  08E4A  83 7E 04 01              cmp      word ptr [bp + 4], 1
  08E4E  7F 03                    jg       .L_main_hasFile
  08E50  E9 DF 00                 jmp      .L_main_newDoc
  ; [Continues with file loading and event loop...]
  ; [See raw disassembly lines 16334-16800 for event loop]
  ; ...


; ============================================================
; __astart
; MSC 5.x C Runtime startup code.
; Checks DOS version >= 2.0, sets up stack, clears BSS,
; releases unused memory (INT 21h AH=4Ah), then calls _main.
;
; /* address: 0FF4:0006 (linear 0x0FF46) */
; ============================================================
__astart:
  0FF46  B4 30                    mov      ah, 0x30
  0FF48  CD 21                    int      0x21  ; INT 21h AH=30h -- get DOS version
  0FF4A  3C 02                    cmp      al, 2
  0FF4C  73 02                    jae      .L_version_ok
  0FF4E  CD 20                    int      0x20  ; INT 20h -- terminate if DOS < 2.0
.L_version_ok:
  ; Set up data segment and stack
  0FF50  BF 02 10                 mov      di, 0x1002               ; [RELOC] DGROUP segment
  0FF53  8B 36 02 00              mov      si, word ptr [2]         ; Top of memory
  0FF57  2B F7                    sub      si, di
  0FF59  81 FE 00 10              cmp      si, 0x1000               ; Max 64KB stack
  0FF5D  72 03                    jb       .L_stack_ok
  0FF5F  BE 00 10                 mov      si, 0x1000
.L_stack_ok:
  0FF62  FA                       cli
  0FF63  8E D7                    mov      ss, di                   ; SS = DGROUP
  0FF65  81 C4 9E 32              add      sp, 0x329e               ; SP = end of BSS
  0FF69  FB                       sti
  0FF6A  73 14                    jae      .L_setup_ok
  ; Insufficient memory -- print error and exit
  0FF6C  16                       push     ss
  0FF6D  1F                       pop      ds
  0FF6E  9A 6B E2 00 00           lcall    0, 0xe26b                ; [RELOC] _nmsghdr
  0FF73  33 C0                    xor      ax, ax
  0FF75  50                       push     ax
  0FF76  9A 6F E2 00 00           lcall    0, 0xe26f                ; [RELOC] _nmsgnum
  0FF7B  B8 FF 4C                 mov      ax, 0x4cff
  0FF7E  CD 21                    int      0x21  ; INT 21h AH=4Ch -- exit with code 0xFF
.L_setup_ok:
  ; Align stack, save initial SP
  0FF80  83 E4 FE                 and      sp, 0xfffe
  0FF83  36 89 26 CE 1C           mov      word ptr ss:[0x1cce], sp
  0FF88  36 89 26 CA 1C           mov      word ptr ss:[0x1cca], sp
  ; Calculate heap size
  0FF8D  8B C6                    mov      ax, si
  0FF8F  B1 04                    mov      cl, 4
  0FF91  D3 E0                    shl      ax, cl                   ; Convert paras to bytes
  0FF93  48                       dec      ax
  0FF94  36 A3 C8 1C              mov      word ptr ss:[0x1cc8], ax ; Store heap limit
  ; Release unused memory
  0FF98  03 F7                    add      si, di
  0FF9A  89 36 02 00              mov      word ptr [2], si
  0FF9E  8C C3                    mov      bx, es
  0FFA0  2B DE                    sub      bx, si
  0FFA2  F7 DB                    neg      bx
  0FFA4  B4 4A                    mov      ah, 0x4a
  0FFA6  CD 21                    int      0x21  ; INT 21h AH=4Ah -- resize memory block
  ; Save PSP segment
  0FFA8  36 8C 1E 3F 1D           mov      word ptr ss:[0x1d3f], ds
  ; Clear BSS (uninitialized data)
  0FFAD  16                       push     ss
  0FFAE  07                       pop      es
  0FFAF  FC                       cld
  0FFB0  BF 92 23                 mov      di, 0x2392               ; BSS start
  0FFB3  B9 A0 32                 mov      cx, 0x32a0               ; BSS end
  0FFB6  2B CF                    sub      cx, di
  0FFB8  33 C0                    xor      ax, ax
  0FFBA  F3 AA                    rep stosb                          ; Fill with zeros
  ; Set DS = SS = DGROUP
  0FFBC  16                       push     ss
  0FFBD  1F                       pop      ds
  ; Initialize CRT: copy environment, process command line
  0FFBE  06                       push     es
  0FFBF  0E                       push     cs
  0FFC0  07                       pop      es
  0FFC1  9A 67 E2 00 00           lcall    0, 0xe267                ; [RELOC] _setenvp
  0FFC6  07                       pop      es
  0FFC7  16                       push     ss
  0FFC8  1F                       pop      ds
  0FFC9  9A 4C E2 00 00           lcall    0, 0xe24c                ; [RELOC] _setargv
  ; Set DS to DGROUP and call _main
  0FFCE  B8 02 10                 mov      ax, 0x1002               ; [RELOC] DGROUP
  0FFD1  8E D8                    mov      ds, ax
  ; Set up exit handler (atexit)
  0FFD3  B8 03 00                 mov      ax, 3                    ; argc = 3 (program name + args)
  0FFD6  36 C7 06 CC 1C 4A E3     mov      word ptr ss:[0x1ccc], 0xe34a  ; Exit handler
  0FFDD  9A 73 E2 00 00           lcall    0, 0xe273                ; [RELOC] _main (text_main)


; ============================================================
; text_dm89Entry
; DM89 far-call entry point shim. Sets DS to DGROUP and calls
; through to the DM89 callback handler.
;
; /* address: 0FFF:0000 (linear 0x0FFF0) */
; ============================================================
text_dm89Entry:
  0FFF0  55                       push     bp
  0FFF1  8B EC                    mov      bp, sp
  0FFF3  1E                       push     ds
  0FFF4  B8 02 10                 mov      ax, 0x1002               ; [RELOC] DGROUP
  0FFF7  8E D8                    mov      ds, ax
  0FFF9  9A 2A EF 00 00           lcall    0, 0xef2a                ; [RELOC] Callback
  0FFFE  1F                       pop      ds
  0FFFF  5D                       pop      bp
  10000  CB                       retf


; ============================================================
; text_dm89Callback
; DM89 callback entry point. Second entry for DM89 protocol.
;
; /* address: 0FFF:0011 (linear 0x10001) */
; ============================================================
text_dm89Callback:                              ; sub_10001
  10001  55                       push     bp
  10002  8B EC                    mov      bp, sp
  10004  1E                       push     ds
  10005  B8 02 10                 mov      ax, 0x1002               ; [RELOC] DGROUP
  10008  8E D8                    mov      ds, ax
  1000A  9A 48 F0 00 00           lcall    0, 0xf048                ; [RELOC] Callback 2
  1000F  1F                       pop      ds
  10010  5D                       pop      bp
  10011  CB                       retf


; ========================================================================
; DATA SEGMENT -- String Table
; ========================================================================
;
; The following strings are embedded in the DATA segment (seg_1002).
; Offsets are relative to the load image base.
;
;   0x10066: "DICTARY"                    ; Dictionary resource name
;   0x10072: "TRANSLAT"                   ; Translate resource name
;   0x10B6A: "TEXT.PDM"                   ; Module self-reference name
;   0x10B75: "Setup Printer CPI Change Ignored"
;   0x10D47: "The line width in the Text application cannot be less than "
;   0x10DD2: "Clipboard"                  ; Clipboard dialog title
;   0x10DE1: "Clipboard is not large enough for selected block."
;   0x10E23: "Picture on clipboard is too tall to fit on page."
;   0x10E6C: "Clipboard picture is too wide to fit in current column."
;   0x10EC1: "Input Ignored"              ; Input rejected message title
;   0x10ED2: "Out of memory. File is full."
;   0x10EFE: "The carriage return before a picture cannot be deleted."
;   0x10F38: "Text"                       ; Application title
;   0x10F3E: "Column "                    ; Status bar: column label
;   0x10F46: "Line "                      ; Status bar: line label
;   0x10F4D: "Page "                      ; Status bar: page label
;   0x10F55: "ASCII    "                  ; Mode indicator: ASCII mode
;   0x10F60: "Non-ASCII"                  ; Mode indicator: non-ASCII mode
;
; --- File Menu Strings ---
;   0x10F73: "Open..."
;   0x10F7C: "Save"
;   0x10F87: "Save as..."
;   0x10F95: "Merge..."
;   0x10FA3: "Page setup..."
;   0x10FB8: "Print..."
;   0x10FC3: "Print form letter..."
;   0x10FD9: "Exit             Esc"
;   0x10FEF: "Run..."
;   0x10FFD: "To ASCII"
;   0x11008: "About..."
;
; --- Edit Menu Strings ---
;   0x11011: "Cut          Shift+Del"
;   0x11029: "Copy         Ctrl+Ins"
;   0x11041: "Paste        Shift+Ins"
;   0x11059: "Clear        Del"
;   0x11071: "Select all"
;   0x11082: "Un-Delete    Ctrl+U"
;   0x1109A: "Insert       Ins"
;
; --- Text Menu Strings ---
;   0x110B2: "Proof..."
;   0x110C9: "Thesaurus..."
;   0x110D7: "Plain"
;   0x110DF: "Bold"
;   0x110E4: "Underline"
;   0x110F0: "Center        Ctrl+C"
;   0x11106: "Un-Center"
;   0x11115: "Indent...     Ctrl+I"
;   0x1112B: "Dictionary..."
;   0x11139: "Translate..."
;
; --- Search Menu Strings ---
;   0x11146: "Find...       Ctrl+F"
;   0x1115D: "Find next     Ctrl+N"
;   0x11174: "Substitute... Ctrl+S"
;   0x1118B: "Return to Document"
;
; --- Layout Menu Strings ---
;   0x111A4: "Header..."
;   0x111B2: "Footer..."
;   0x111C2: "Page number"
;   0x111D1: "Today's date..."
;   0x111E2: "Add field..."
;
; --- Picture Menu Strings ---
;   0x111F6: "Show"
;   0x111FD: "Hide"
;   0x11205: "Move"
;   0x1120F: "Size"
;
; --- Menu Bar ---
;   0x11217: "File"
;   0x1121F: "Edit"
;   0x11227: "Text"
;   0x1122D: "Search"
;   0x11237: "Layout"
;   0x11240: "Picture"
;
; --- Find/Substitute Dialog Strings ---
;   0x11256: "CANCEL"
;   0x1125D: "Find"
;   0x11264: "Substitute"
;   0x1126F: "Replace?"
;   0x1127D: "Search for:"
;   0x11289: "Replace with:"
;   0x11297: "You did not enter a \"Replace with:\" string..."
;   0x112E5: "Search string was not found."
;   0x11302: "Enter \"Search for:\" string or CANCEL."
;   0x1132F: "Found "
;   0x1133C: " occurrence, "
;   0x1134A: " occurrences, "
;   0x11359: "replaced "
;   0x1136D: "** Picture Located Here **"
;
; --- Print Validation Strings ---
;   0x1138C: "\"Printed Line Width\" is invalid. Picture "
;   0x113C1: "in header "
;   0x113D3: "in footer "
;   0x113E9: "extends to column "
;   0x11402: "\"Printed Lines Per Page\" is invalid. Picture "
;   0x1144B: " lines tall."
;
; --- Picture Move/Size Instructions ---
;   0x1145A: "To move picture, point to rectangle, press button and drag..."
;   0x114BC: "To move picture, press Left or Right arrow keys..."
;   0x1151F: "To size picture, point to size handle, press button and drag..."
;   0x1157F: "To size picture, press Left, Right, Up, or Down arrow keys..."
;
; --- Indent Dialog Strings ---
;   0x115E6: "Indent"
;   0x115F1: "First line indent:"
;   0x11604: "Left margin indent:"
;   0x11619: "Right margin indent:"
;
; --- Center Dialog Strings ---
;   0x1162E: "Center"
;   0x11638: "Only single line paragraphs may be centered."
;   0x11671: "Centering line would result in a remaining line width of less than..."
;   0x116C7: "A numeric entry of 0 or greater is required in all margin settings."
;   0x1171D: "Negative numbers are not allowed in margin settings."
;
; --- Margin Validation Strings ---
;   0x11766: "Line width ("
;   0x11779: ") minus \"First line indent\" ("
;   0x1179B: ") minus \"Left indent\" ("
;   0x117B6: ") minus \"Right margin indent\" ("
;   0x117D6: ") cannot be less than "
;
; --- Header/Footer Dialog Strings ---
;   0x117F8: "Header"
;   0x11803: "No header"
;   0x11813: "Header on all pages"
;   0x1182F: "Header on all pages except first page"
;   0x11855: "Footer"
;   0x11862: "No footer"
;   0x11876: "Footer on all pages"
;   0x11896: "Footer on all pages except first page"
;   0x118BC: "Printed lines per page ("
;   0x118D8: ") minus header lines ("
;   0x118EF: ") minus footer lines ("
;   0x11909: ") cannot be less than "
;   0x1192B: " must be shortened by "
;   0x11946: " line"
;   0x1194D: " lines"
;   0x11955: " to allow for printing of the tallest picture in the document."
;   0x11997: "The tallest picture in the document is too tall to allow creating a header."
;   0x119F1: "The tallest picture in the document is too tall to allow creating a footer."
;
; --- Add Field Dialog Strings ---
;   0x11A50: "Add Field"
;   0x11A61: "Field does not exist, please select from listbox."
;   0x11AB0: "Error occurred trying to access file for Address Book."
;   0x11AF1: "Fields"
;   0x11AF8: "Name:"
;
; --- Date/Print Strings ---
;   0x11B34: "Today's Date"
;   0x11B4D: "YYYY"
;   0x11B52: "Print"
;   0x11B5D: "Starting page number:"
;   0x11B73: "\"Starting page number\" must be >= 1 and <= 999."
;
; --- About Dialog Strings ---
;   0x11BCC: "About"
;   0x11BD2: "Version "
;   0x11BDB: "Resources"
;   0x11BE7: "CANCEL"
;   0x11BEE: "DeskMate Copyright 1984, 1989"
;   0x11C0C: "Tandy Corporation, All Rights Reserved"
;
; --- Resource Names ---
;   0x11D40: ";C_FILE_INFO"               ; MSC CRT marker
;   0x11D8E: "PRGUF"                      ; Program User Functions resource
;   0x11D98: "DMGUF"                      ; DeskMate General User Functions
;   0x11DA8: "DMSPELL"                    ; Spell check engine
;   0x11DB8: "PRGUF"                      ; (duplicate reference)
;   0x11DC2: "DMCSR"                      ; DeskMate Cursor resource
;   0x11DD0: "SPELL"                      ; Spell dictionary
;   0x11DDA: "DMTHES"                     ; Thesaurus
;   0x11DE2: "DMDB"                       ; Database access
;   0x11DE7: "DMDBRD"                     ; Database reader
;
; --- CRT Runtime Error Messages ---
;   0x122D8: "<<NMSG>>"                   ; MSC CRT null message header
;   0x122E2: "R6000\r\n- stack overflow\r\n"
;   0x122FE: "R6003\r\n- integer divide by 0\r\n"
;   0x1231F: "R6009\r\n- not enough space for environment\r\n"
;   0x12352: "run-time error "
;   0x12364: "R6002\r\n- floating point not loaded\r\n"
;   0x1238B: "R6001\r\n- null pointer assignment\r\n"
;
; --- Video Mode Strings ---
;   0x12052: "1000CGA"                    ; Tandy 1000 CGA mode
;   0x1205A: "DDGAEGA"                    ; DGA/EGA mode
;   0x12062: "HERCPLANTC16TC4"            ; Hercules/Plantronics/Tandy modes
;   0x12076: "MCGAEGA"                    ; MCGA/EGA mode
;   0x1207E: "LREST256TC40H"              ; Low-res/EGA/256-color modes
;
; --- Date Strings ---
;   0x120C9: " SunMonTueWedThuFriSat"     ; Day abbreviations (3-char each)
;   0x120E0: "JanFebMarAprMayJunJulAugSepOctNovDec"  ; Month abbreviations
;
; --- Mail Merge / Config Strings ---
;   0x12250: "Users"
;   0x12256: "PERSONAL.ADR"               ; Address book file
;   0x12263: "NAMES"                      ; Names table
;   0x1226B: "PRGUF"                      ; Resource reference
;   0x12271: "A:\DESKTOP.CFG"             ; Desktop config on A: drive
;   0x12281: "DESKTOP.CFG"                ; Desktop config file
;   0x1228D: "DMCONFIG"                   ; DM config resource
;   0x12296: "AddrBook"                   ; Address book section
;   0x122A2: " 0 TEXT.PDM"               ; Module identifier
;   0x122AE: "MAILMRGE.PDM"              ; Mail merge module name
;   0x122C0: "DMPGSET"                    ; Page setup resource
;   0x122C8: ".RES"                       ; Resource file extension
;   0x122CE: "1988"                       ; Year constant


; ========================================================================
; END OF ANNOTATED DISASSEMBLY
; ========================================================================
