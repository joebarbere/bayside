; ========================================================================
; ADDRESS.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987), Medium Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; ADDRESS.PDM is the address book / phone book application for DeskMate
; 3.05.  It manages contact records containing name, address, city,
; state, ZIP, phone, and notes fields.  Features include:
;   - Full CRUD on contact records (add, edit, delete, undelete)
;   - Alphabetical index tabs (A-Z) for fast navigation
;   - Search / find by any field
;   - Sort records by any combination of fields
;   - Print labels, envelopes, and address lists
;   - Auto-dial phone numbers via COM port (INT 14h / modem)
;   - Calendar/date validation (leap year, day-of-month bounds)
;   - Import/export of comma-delimited records
;
; DM89 imports: dmguf (General User Functions),
;               dmdb (Database engine)
;
; Unlike FILER.PDM which also imports dmform, ADDRESS.PDM does NOT
; import dmform -- it handles its own form rendering through the dmdb
; form subsystem directly.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 61,025 bytes
; Load image: 60,513 bytes (after header)
; DM89 entry point: 0B81:0000 (MSC 5.x CRT startup)
; SS:SP = 1680:1000
;
; Segment Map (6 segments, 35 relocations):
;   seg_0000  0x0B810 bytes  CODE   Address book application code + DMGUF/DMDB thunks
;   seg_0B81  0x000B0 bytes  CODE   MSC 5.x CRT startup + DeskMate host stubs
;   seg_0B8C  0x00310 bytes  CODE   DM89 import far-call dispatcher
;   seg_0BBD  0x00040 bytes  DATA   DGROUP fixup area (MSC CRT copyright)
;   seg_0BC1  0x0ABF0 bytes  DATA   Strings, menus, field definitions,
;                                   record buffers, contact data, dialog
;                                   templates, print config, sort/search state
;   seg_1680  0x01000 bytes  STACK  Stack segment (4096 bytes)
;
; Medium memory model: multiple code segments, DGROUP at 0BBD.
;
; DM flags: 0x0101 (standard PDM module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Address Record Structure (at [0x2482] pointer array):
;   The address book stores contacts as database records via DMDB.
;   Each record contains 10+ fields accessed via field index:
;     Field 0:  Last Name        (string, up to 0x0A chars)
;     Field 1:  First Name       (string, up to 0x0A chars)
;     Field 2:  Address Line 1   (string)
;     Field 3:  Address Line 2   (string)
;     Field 4:  City             (string)
;     Field 5:  State            (string, 2 chars)
;     Field 6:  ZIP Code         (string)
;     Field 7:  Phone 1          (string, formatted)
;     Field 8:  Phone 2          (string, formatted)
;     Field 9:  Notes            (string)
;     Field 10: Category         (string)
;   Fields are accessed at [bx+0], [bx+2], ... [bx+0x2A] offsets
;   from the field pointer array base at [0x2482].
;
; Global Variables (selected):
;   [0x0068]  g_windowTop       - Top row position of main window
;   [0x006C]  g_windowHeight    - Height of main window area
;   [0x0078]  g_displayMode     - Display mode (1=list, 2=detail/card)
;   [0x009C]  g_currentRecIdx   - Current record index (word)
;   [0x009E]  g_menuState       - Menu state / active menu ID
;   [0x00A6]  g_callbackPtr     - Callback function pointer (for CRT dispatch)
;   [0x0228]  g_fieldEditFlag   - Field editing active flag
;   [0x049C]  g_labelConfig1    - Label configuration byte 1 (field count)
;   [0x049D]  g_labelConfig2    - Label configuration word (offset)
;   [0x04B8]  g_envConfig1      - Envelope configuration byte 1
;   [0x04B9]  g_envConfig2      - Envelope configuration word
;   [0x2482]  g_fieldPtrArray   - Pointer to field pointer array base
;   [0x2806]  g_savedSS         - Saved SS for stack switch (in print routines)
;   [0x2808]  g_savedSP         - Saved SP for stack switch
;   [0x280A]  g_printBufPtr     - Print buffer pointer
;   [0x280C]  g_printHandle     - Print file handle
;   [0x280E]  g_eventBlock      - Event parameter block (for INT E0h 060Eh)
;   [0x2814]  g_dmdbFuncPtr     - DMDB dispatch far-call pointer (word:word)
;   [0x2818]  g_dmgufResName    - DMGUF resource name string pointer
;   [0x281E]  g_dmdbRetCode     - DMDB return code storage
;   [0x2820]  g_fileManagerState - File manager dialog state (-2=new, 0=open, 1=selected)
;   [0x2822]  g_cancelFlag      - Cancel flag for dialogs
;   [0x2824]  g_modemState      - Modem/COM port state block (for auto-dial)
;   [0x2866]  g_sortDirection   - Sort direction (0=ascending, 1=descending)
;   [0x287E]  g_daysInMonth     - Days-per-month table (12 words)
;   [0x2866]  g_cumDaysTable    - Cumulative days table for date calculations
;   [0x28B4]  g_retryCounter    - Retry counter for modem operations
;   [0x28BC]  g_dotString       - "." period string for version display
;   [0x28CF]  g_versionStr      - Version/format string
;   [0x2946]  g_dialogFlags     - Dialog configuration flags
;   [0x2961]  g_dialogState     - Dialog internal state byte
;   [0x2964]  g_fileListCount   - Number of files in open dialog list
;   [0x296A]  g_dialogXPos      - Dialog X position (centered)
;   [0x296F]  g_dialogParam     - Dialog parameter word (from caller)
;   [0x2972]  g_dialogYPos      - Dialog Y position (centered)
;   [0x2977]  g_titleStrPtr     - Pointer to dialog title string
;   [0x298F]  g_customBtn1Ptr   - Custom button 1 text pointer
;   [0x2997]  g_customBtn2Ptr   - Custom button 2 text pointer
;   [0x299F]  g_dialogStruct    - Dialog structure (passed to dmdb_openFile etc.)
;   [0x29A2]  g_dialogResult    - Dialog result byte
;   [0x29A6]  g_dialogBtnCount  - Number of buttons in dialog (5 or 6)
;   [0x2F96]  sz_defaultName    - Default filename string
;   [0x2F9F]  sz_untitled       - Untitled/empty string
;   [0x2FA8]  sz_spacePad       - Space padding string
;   [0x2FAE]  sz_noVersion      - No-version fallback string
;   [0x2FB4]  sz_separator      - Separator string for display
;   [0x3092]  g_bssStart        - Start of BSS region (zeroed by CRT)
;   [0x6560]  g_resourceBuf     - Resource name buffer (for DMGUF load)
;   [0x6570]  g_tempResult      - Temporary result storage (word)
;   [0x6600]  g_envSegment      - DeskMate environment segment
;   [0x6604]  g_fileListIndex   - Current file list index
;   [0x6654]  g_currentRecPtr   - Pointer to current record structure
;   [0x6678]  g_titleBuffer     - Title bar text buffer
;   [0x6F64]  g_versionBuf      - Version number buffer
;   [0x6F92]  g_phoneBuf        - Phone number buffer (for auto-dial)
;   [0x6F9C]  g_eventProcessed  - Event processed flag (0=no, 1=yes)
;   [0x70F4]  g_eventType       - Event type byte from dmdb_getEvent
;   [0x70F5]  g_eventCode       - Event code word from dmdb_getEvent
;   [0x70F7]  g_eventParam1     - Event parameter 1
;   [0x70F9]  g_eventParam2     - Event parameter 2
;   [0x70FB]  g_alphaTabIdx     - Current alphabetical tab index (0-25)
;   [0x70FE]  g_memBlockSize    - Memory block size for allocation
;   [0x7140]  g_fileEntryPtr    - File entry pointer in open dialog
;   [0x74BC]  g_printActive     - Print session active flag
;   [0x7A1C]  g_memHandle       - Memory allocation handle
;   [0x7A1E]  g_errorMsgId      - Error message string ID
;   [0x7BB4]  g_importCount     - Import record counter
;   [0x7BD0]  g_initFlag        - Initialization complete flag
;   [0x7BD2]  g_configBlock     - Configuration block address
;   [0x80BC]  g_cmdLinePtr      - Parsed command line pointer
;   [0x8060]  g_maxFieldWidth   - Maximum field display width
;   [0x829E]  g_formHandle      - Form editing session handle
;   [0x82A0]  g_dialogBufBase   - Dialog buffer base address
;   [0x83C2]  g_fileListBuf     - File list buffer base
;   [0x854E]  g_printLabelPtrs  - Print label pointer array
;   [0x8554]  g_fileListPtrs    - File list pointer array (15 words)
;   [0x85A0]  g_workspaceBuf    - General workspace buffer
;   [0xAC2C]  g_hasConfigBlock  - Flag: has configuration block (0 or 1)
;   [0xAC30]  g_bssEnd          - End of BSS region
;
; Modem/Auto-Dial State Block (at [0x2824], 30+ bytes):
;   +0x00   modem command byte (0x10=init, 0x12=connected, 0x14=dial, 0x15=error)
;   +0x03   dial flags byte
;   +0x04   far ptr to phone number string
;   +0x08   connection result code
;
; Date Validation (sub_09B88 and related):
;   The address book includes a full date parser/validator with:
;   - Month range checking (1-12)
;   - Day range checking (1-N, where N = days in month)
;   - Leap year detection (divisible by 4 but not 100, or by 400)
;   - Year normalization (2-digit years get 1900 added; year < 100 + 0x76C)
;   - Days-per-month table at [0x287E] and cumulative days at [0x2866]
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Address Book Application Functions ---
;
; Address   Name                           Size  Description
; -------   ----                           ----  -----------
; 0000:0010 address_main                    801  _main() - init resources, parse cmdline, open file, event loop
; 0000:0331 address_handleMenuCommand       726  Menu command dispatcher (File/Edit/Search/Print/Options)
; 0000:0607 address_handleEditCommand       330  Edit menu handler (cut/copy/paste/undo field ops)
; 0000:0751 address_handleFileCommand       263  File menu handler (new/open/save/close)
; 0000:0858 address_handlePrintCommand      678  Print menu handler (labels/envelopes/list)
; 0000:0AFE address_handleOptionsCommand    260  Options menu handler (preferences, display mode)
; 0000:0C02 address_setupTitleBar            53  Set title bar text and window name
; 0000:0C37 address_closeFormEngine          17  Close DMDB form engine if active
; 0000:0C48 address_handleWindowResize      200  Handle window resize event (recalc layout)
; 0000:0D10 address_getEventCode             29  Get event code from dmdb
; 0000:0D2D address_endTransaction           11  End dmdb transaction
; 0000:0D38 address_callDmdbFunction         77  Call DMDB with function code and params
; 0000:0D85 address_dispatchCallback         15  Dispatch via callback pointer [0xA6]
; 0000:0D94 address_processCallbackEvent    196  Process callback event from host
; 0000:0E58 address_exitCleanup              23  Call _exit() with return code
; 0000:0E6F address_unloadAndExit            69  Unload resources and exit
; 0000:0EB4 address_retFarStub               25  Return far stub (returns -1)
; 0000:0ECD address_farCallDispatch          15  Far-call through CX register
; 0000:0EDC address_farCallEntry             20  Far-call entry point stub
; 0000:0EF0 address_hostCallback            104  DeskMate host callback handler
; 0000:0F58 address_getDataSegment            4  Return current DS (utility)
; 0000:0F5C address_showErrorDialog         435  Show error message dialog box
; 0000:110F address_setMenuBarText           50  Set menu bar title text
; 0000:1141 address_closeActiveSession        7  Close any active editing session
; 0000:1148 address_allocMemBlock            34  Allocate memory block via DeskMate
; 0000:116A address_freeMemBlock             66  Free memory block via DeskMate
; 0000:11AC address_reallocMemBlock          50  Reallocate memory block
; 0000:11DE address_loadImportedResources    63  Load dmguf+dmdb resources via INT E0h
; 0000:121D address_initFieldDisplay         65  Initialize field display attributes
; 0000:125E address_setupRecordView         264  Set up record view with field layout
; 0000:1366 address_mainEventLoop          1730  Main event loop - get/dispatch all events
;                                                (keyboard, menu, form, window, system)
; 0000:1A28 address_handleKeyboardEvent    1064  Handle keyboard input in record editing
; 0000:1E50 address_openExistingFile         95  Open an existing address book file
; 0000:1EAF address_initFileAndView         121  Initialize file and set up view
; 0000:1F28 address_openNewFile             162  Open/create a new address book file
; 0000:1FCA address_printDispatcher         478  Print dispatcher (labels/envelopes/list routing)
; 0000:21A8 address_printMainLoop           348  Print main loop - iterate and print records
; 0000:2304 address_printFinalize            94  Finalize print session
; 0000:2362 address_updateAlphaTabDisplay    86  Update alphabetical tab display
; 0000:23B8 address_initAlphaIndex          254  Initialize alphabetical A-Z index
; 0000:24B6 address_selectAlphaTab           67  Select a specific alpha tab
; 0000:24F9 address_resetAlphaTab            16  Reset alpha tab to default
; 0000:2509 address_buildAlphaIndex         310  Build alphabetical index entries
; 0000:263F address_clearAlphaFilter         16  Clear alphabetical filter
; 0000:264F address_setAlphaFilter           16  Set alphabetical filter
; 0000:265F address_resetFilter              16  Reset current filter
; 0000:266F address_applyFilter              25  Apply current filter to record list
; 0000:2688 address_removeFilter             27  Remove active filter
; 0000:26A3 address_sortAndRefresh          228  Sort records and refresh display
; 0000:2787 address_lookupFieldValue         67  Look up field value by index
; 0000:27CA address_openFileForEdit         178  Open file for editing (with validation)
; 0000:287C address_sendMenuCommand          21  Send a synthetic menu command
; 0000:2891 address_promptSaveChanges        74  Prompt to save unsaved changes
; 0000:28DB address_handleFileSave           56  Handle File > Save command
; 0000:2913 address_handleFileClose         174  Handle File > Close command
; 0000:29C1 address_handleFileNew           165  Handle File > New command
; 0000:2A66 address_checkModified            65  Check if record has been modified
; 0000:2AA7 address_getModifiedFlag          96  Get the modified flag from current record
; 0000:2B07 address_setModifiedFlag          89  Set the modified flag on current record
; 0000:2B60 address_editRecordAdd           607  Add a new contact record
; 0000:2DBF address_editRecordDelete       1077  Delete current contact record
; 0000:31F4 address_editRecordUndelete      287  Undelete last deleted record
; 0000:3313 address_editRecordNavigate      353  Navigate to next/previous record
; 0000:3474 address_searchDialog            122  Open search dialog
; 0000:34EE address_mainEventHandler        424  Main event handler (routes to sub-handlers)
; 0000:3696 address_updateRecordDisplay     321  Update the record display after changes
; 0000:37D7 address_createFormRow           109  Create a form row via dmdb
; 0000:3844 address_refreshAfterEdit        283  Refresh display after record edit
; 0000:395F address_sortDialog              284  Sort dialog handler
; 0000:3A7B address_sortExecute             104  Execute sort operation
; 0000:3AE3 address_handleFieldNavigation   686  Handle field navigation (tab, arrows, home/end)
; 0000:3D91 address_handleFieldSelect       189  Handle field selection in list view
; 0000:3E4E address_stubReturn1              25  Stub: return fixed value 1
; 0000:3E67 address_stubReturn2              25  Stub: return fixed value 2
; 0000:3E80 address_fileOpenDialog          584  File Open dialog handler
; 0000:40C8 address_dispatchRecordAction    128  Dispatch record action (open/create/select)
; 0000:4148 address_openOrCreateFile        173  Open or create an address book .FIL file
; 0000:41F5 address_navigateAndDisplay      547  Navigate to record and update display
; 0000:4418 address_gotoRecordDialog        836  Go To Record dialog handler
; 0000:475C address_handleRecordNav         181  Handle record navigation commands
; 0000:4811 address_callDmdbSimple           87  Simple DMDB call with one parameter
; 0000:4868 address_printLabelsDialog       497  Print Labels dialog handler
; 0000:4A59 address_printEnvelopesDialog    413  Print Envelopes dialog handler
; 0000:4BF6 address_printListDialog         176  Print List dialog handler
; 0000:4CA6 address_printLabelsExecute      710  Print Labels execution engine
; 0000:4F6C address_printEnvelopesExecute   565  Print Envelopes execution engine
; 0000:51A1 address_printListExecute        642  Print List execution engine
; 0000:5423 address_printSetupDialog        340  Print Setup dialog handler
; 0000:5577 address_printPreview            493  Print preview handler
; 0000:5764 address_refreshFieldDisplay     110  Refresh field display attributes
; 0000:57D2 address_updateCardView          101  Update card view after field change
; 0000:5837 address_updateListView          128  Update list view after field change
; 0000:58B7 address_renderContactCard      1337  Render contact card display (all fields)
; 0000:5DF0 address_setFieldHighlight       101  Set field highlight for current selection
; 0000:5E55 address_clearFieldHighlight      55  Clear field highlight
; 0000:5E8C address_handleSearchResult      526  Handle search result display
; 0000:609A address_autoDialPhone          1833  Auto-dial phone number via COM port/modem
; 0000:67C3 address_loadPrintConfig          91  Load print configuration from settings
; 0000:681E address_savePrintConfig          69  Save print configuration to settings
; 0000:6863 address_formatPrintOutput      1392  Format output for printer (labels/env/list)
; 0000:6DD3 address_handlePrintProgress     675  Handle print progress and pagination
; 0000:7076 address_initPrintSession        140  Initialize print session
; 0000:7102 address_printEngine            1798  Main print engine (iterate records, format, output)
; 0000:7808 address_formatLabelFields       772  Format fields for label printing
; 0000:7B0C address_formatSingleField        64  Format a single field for output
; 0000:7B4C address_printSetupUI            657  Print setup UI handler (margins, fonts)
; 0000:7DDD address_printPreviewRender      809  Render print preview display
; 0000:8106 address_printFormatRecord       357  Format a single record for printing
; 0000:826B address_importExportDialog      498  Import/Export dialog handler
; 0000:845D address_importRecords           406  Import records from file
; 0000:85F3 address_exportRecords           329  Export records to file
; 0000:873C address_formatExportRecord      713  Format a record for export
; 0000:8A05 address_parseImportRecord       246  Parse an imported record
; 0000:8AFB address_getFieldCount            38  Get total number of fields defined
; 0000:8B21 address_validateRecord          132  Validate record data integrity
; 0000:8BA5 address_insertImportedRecord    461  Insert an imported record into database
; 0000:8D72 address_clearRecordBuffer        45  Clear the record buffer
; 0000:8D9F address_promptForFilename        70  Prompt user for filename
; 0000:8DE5 address_validateFilename         18  Validate a filename
; 0000:8DF7 address_openImportFile          127  Open import file for reading
; 0000:8E76 address_openExportFile          127  Open export file for writing
; 0000:8EF5 address_fileOperationCore       154  Core file operation (open/create/validate)
; 0000:8F8F address_modemDialSetup          363  Modem dial setup (configure COM port)
;
; --- Resource Loading (dmguf, dmdb) ---
;
; 0000:90FA address_unloadImportedResources 169  Unload all imported resource modules
;
; --- DMGUF Dispatch Thunks (far-call via [0x27E0] / [0x27EA]) ---
;
; The DMGUF thunk table maps small function IDs to far-calls through
; the resolved DMGUF dispatch pointer.  Two dispatch paths exist:
;   loc_09122 = primary DMGUF dispatcher (via [0x27E0])
;   loc_09166 = secondary DMGUF dispatcher (via [0x27EA], for form funcs)
;
; 0000:91A3 dmguf_func_00                    6  DMGUF: func 0x00 (get field value)
; 0000:91A9 dmguf_func_01                    6  DMGUF: func 0x01 (get field list)
; 0000:91AF dmguf_func_02                    6  DMGUF: func 0x02 (get field info)
; 0000:91B5 dmguf_func_07                    6  DMGUF: func 0x07 (commit/flush)
; 0000:91BB dmguf_func_08                   12  DMGUF: func 0x08 + 0x0C (field ops)
; 0000:91C7 dmguf_func_0E                    6  DMGUF: func 0x0E (navigate record)
; 0000:91CD dmguf_func_13                    6  DMGUF: func 0x13 (set field properties)
; 0000:91D3 dmguf_func_1A                    6  DMGUF: func 0x1A (open form) [via secondary]
; 0000:91D9 dmguf_func_1C                    6  DMGUF: func 0x1C
; 0000:91DF dmguf_func_1F                    6  DMGUF: func 0x1F
; 0000:91E5 dmguf_func_20                   12  DMGUF: func 0x20 + 0x22
; 0000:91F1 dmguf_func_24                    6  DMGUF: func 0x24
; 0000:91F7 dmguf_func_26                    6  DMGUF: func 0x26
; 0000:91FD dmguf_func_AE                    6  DMGUF: func 0xAE (open file)
; 0000:9203 dmguf_func_AF                    6  DMGUF: func 0xAF (read record)
; 0000:9209 dmguf_func_B3                   12  DMGUF: func 0xB3 + 0xB4 (set/get form field)
; 0000:9215 dmguf_func_38                    6  DMGUF: func 0x38 (set field format)
;
; --- Resource Loader (sub_0921B) ---
;
; 0000:921B address_loadResourceModule      104  Load resource module (compares name, INT E0h 0206h)
;
; --- File I/O via DeskMate (sub_09283) ---
;
; 0000:9283 address_deskMateFileIO          214  DeskMate-mediated file I/O
;                                                (INT E0h 0600h=poll, 060Eh=dispatch, 0603h=write)
;                                                Switches SS:SP for print buffer operations
;
; --- DMDB Utility Thunks (far-call via [0x27E4/0x27EE]) ---
;
; 0000:9353 (inline)                              DMDB func 0x204
; 0000:9359 dmdb_func_0501                    6  DMDB: func 0x501 (get status)
; 0000:935F dmdb_func_0401                    6  DMDB: func 0x401 (validate field)
; 0000:9365 dmdb_func_0601                    6  DMDB: func 0x601
; 0000:936B dmdb_func_0604                    6  DMDB: func 0x604
; 0000:9371 dmdb_func_060E                   12  DMDB: func 0x60E + func 4
;
; --- Resource Module Loader / Unloader ---
;
; 0000:937D address_loadDmgufModule          25  Load DMGUF resource via INT E0h AX=0206h
; 0000:9396 address_unloadDmgufModule        22  Unload DMGUF via INT E0h AX=0207h
; 0000:93A5 (inline) address_loadAndResolve       Load DMGUF + resolve dispatch pointer
; 0000:93AC address_resolveAndUnload          7  Resolve dispatch + unload DMGUF
;
; --- DMDB Call Dispatcher (sub_093B3) ---
;
; 0000:93B3 address_callDmdbDispatch         40  Call DMDB dispatch with function code
;                                                (push bp, set bp+4, lcall [0x2814], handle errors)
;
; --- DMDB API Thunks (AX = 0x20xx, jump to sub_093B3) ---
;
; 0000:93DB dmdb_beginTransaction             6  DMDB func 0x2006: begin transaction
; 0000:93E1 dmdb_endTransaction              12  DMDB func 0x2007: end transaction
;           (also inline: func 0x200E at 93E7)
; 0000:93ED dmdb_getEvent                     6  DMDB func 0x2013: get/dispatch event
; 0000:93F3 dmdb_peekEvent                    6  DMDB func 0x2014: peek at next event
; 0000:93F9 dmdb_putEvent                     6  DMDB func 0x2015: put event back
; 0000:93FF dmdb_closeSession                 6  DMDB func 0x2016: close editing session
; 0000:9405 dmdb_refreshView                  6  DMDB func 0x2017: refresh view
; 0000:940B dmdb_createFormRow                6  DMDB func 0x201B: create form row
; 0000:9411 dmdb_setFormRow                   6  DMDB func 0x201C: set form row content
; 0000:9417 dmdb_getFormRow                  30  DMDB func 0x201D: get form row content
;           (also inline: 0x2020, 0x2021, 0x2022, 0x2023)
; 0000:9435 dmdb_func_2025                    6  DMDB func 0x2025
; 0000:943B dmdb_func_2028                    6  DMDB func 0x2028
; 0000:9441 dmdb_func_2029                    6  DMDB func 0x2029
; 0000:9447 dmdb_readFileBlock                6  DMDB func 0x202B: read file block
; 0000:944D dmdb_writeFileBlock               6  DMDB func 0x202C: write file block
;           (also inline: 0x202D)
; 0000:9459 dmdb_setActiveWorkspace           6  DMDB func 0x202E: set active workspace handle
; 0000:945F dmdb_getWorkspaceSize             6  DMDB func 0x202F: get workspace size
;           (also inline: 0x2032, 0x203C, 0x203D, 0x203F, 0x2041)
; 0000:9483 dmdb_setFieldMetric               6  DMDB func 0x2044: set field metric
; 0000:9489 dmdb_getRecordMetric              6  DMDB func 0x204A: get record metric
; 0000:948F dmdb_func_204B                    6  DMDB func 0x204B
; 0000:9495 dmdb_func_204C                    6  DMDB func 0x204C
; 0000:949B dmdb_func_2052                    6  DMDB func 0x2052
; 0000:94A1 dmdb_func_2055                    6  DMDB func 0x2055
; 0000:94A7 dmdb_func_2059                    6  DMDB func 0x2059
; 0000:94AD dmdb_func_205A                    6  DMDB func 0x205A
; 0000:94B3 dmdb_func_205C                    6  DMDB func 0x205C
; 0000:94B9 dmdb_func_2061                    6  DMDB func 0x2061
; 0000:94BF dmdb_func_2062                    6  DMDB func 0x2062
; 0000:94C5 dmdb_func_2063                    6  DMDB func 0x2063
; 0000:94CB dmdb_refreshTitleBar              6  DMDB func 0x206A: refresh title bar
; 0000:94D1 dmdb_getRecordPosition            6  DMDB func 0x206E: get record position
; 0000:94D7 dmdb_func_206F                    6  DMDB func 0x206F
; 0000:94DD dmdb_func_2076                    6  DMDB func 0x2076
; 0000:94E3 dmdb_getViewState                 6  DMDB func 0x20A3: get view state
; 0000:94E9 dmdb_setViewState                 6  DMDB func 0x20A4: set view state
; 0000:94EF dmdb_func_20A8                    6  DMDB func 0x20A8
; 0000:94F5 dmdb_setWindowExtent              6  DMDB func 0x20A9: set window extent
; 0000:94FB dmdb_openPrintSession            12  DMDB func 0x20AC: open print session
;           (also inline: 0x20B3)
; 0000:9507 dmdb_setWindowTitle               6  DMDB func 0x20B9: set window title
; 0000:950D dmdb_setWindowName                6  DMDB func 0x20BA: set window name
; 0000:9513 dmdb_initEditSession             12  DMDB func 0x20D0: init editing session
;           (also inline: 0x20DC)
; 0000:951F dmdb_openFile                     6  DMDB func 0x20E3: open file
; 0000:9525 dmdb_closeFile                    6  DMDB func 0x20E4: close file
; 0000:952B dmdb_saveFile                    12  DMDB func 0x20E9: save/flush file
;           (also inline: 0x20EF)
; 0000:9537 dmdb_func_20F7                    6  DMDB func 0x20F7
; 0000:953D dmdb_func_20F8                    6  DMDB func 0x20F8
; 0000:9543 dmdb_func_20FE                    6  DMDB func 0x20FE
; 0000:9549 dmdb_func_20FF                   12  DMDB func 0x20FF
;           (also inline: 0x2100)
; 0000:9555 dmdb_getSchemaInfo                6  DMDB func 0x2105: get schema info
; 0000:955B dmdb_setSchemaInfo               18  DMDB func 0x2107: set schema info
;           (also inline: 0x2131 commitForm, 0x2132 refreshForm)
; 0000:956D dmdb_func_2137                    6  DMDB func 0x2137
; 0000:9573 dmdb_func_2138                    7  DMDB func 0x2138
;
; --- Auto-Dial / Modem Engine ---
;
; 0000:957A address_modemInit               202  Initialize modem session (configure, open COM port)
; 0000:9644 address_modemCheckStatus         77  Check modem status
; 0000:9691 address_modemDial               205  Dial phone number
; 0000:975E address_modemConnect              89  Establish modem connection (lcall 0B8C:02E8)
; 0000:97B7 address_modemProbe               55  Probe modem for response
; 0000:97EE address_modemWaitResponse        80  Wait for modem response code
; 0000:983E address_modemSendCommand        344  Send AT command to modem
;
; --- Date/Calendar Validation ---
;
; 0000:9996 address_formatDate              326  Format a date string
; 0000:9ADC address_validateDateRange        74  Validate date components are in range
; 0000:9B26 address_computeDateValue         98  Compute numeric date value from components
; 0000:9B88 address_parseDate               548  Parse date string into month/day/year
; 0000:9DAC address_getDaysInMonth           76  Get days in month (with leap year check)
; 0000:9DF8 address_intToStringPadded        60  Convert integer to zero-padded string
; 0000:9E34 address_dateToJulian            108  Convert date to Julian day number
; 0000:9EA0 address_setDialTimeout           48  Set modem dial timeout value
;
; --- Modem AT Command Helpers ---
;
; 0000:9ED0 address_atCmd_ATD                20  Build "ATD" (dial) command string
; 0000:9EE4 address_atCmd_ATH                31  Build "ATH" (hangup) command strings
; 0000:9F03 address_atCmd_ATE                20  Build "ATE" (echo) command string
; 0000:9F17 address_atCmd_ATZ                20  Build "ATZ" (reset) command string
; 0000:9F2B address_buildATCommand           41  Generic AT command string builder
;
; --- File Management ---
;
; 0000:9F54 address_initViewState            38  Initialize view state (dmdb funcs)
; 0000:9F7A address_getSystemFlags           14  Get DeskMate system flags
; 0000:9F88 address_resetFileState           45  Reset file state after close
; 0000:9FB5 address_checkWriteProtect        13  Check if file is write-protected
; 0000:9FC2 address_checkDiskSpace           35  Check available disk space
; 0000:9FE5 address_closePrintOutput         30  Close print output file/device
; 0000:A003 address_fileManager             121  File manager entry (create or open)
; 0000:A07C address_fileOpenManager         505  File Open dialog manager
;                                                (list files, select, open/create)
;
; --- String / Display Utilities ---
;
; 0000:A275 address_intToDecString           28  Convert integer to decimal string (recursive)
; 0000:A291 address_copyStringToES           12  Copy null-terminated string (SI->DI, DS->ES)
; 0000:A29D address_getStringLength          17  Get string length (SI-based strlen)
; 0000:A2AE address_detectComPorts          140  Detect available COM ports via BIOS data area
;
; --- DeskMate INT E0h Wrappers ---
;
; 0000:A33A address_intE0h_generic          102  Generic INT E0h wrapper
; 0000:A3A0 address_intE0h_allocMem          64  INT E0h AX=0700h: allocate memory / yield
; 0000:A3E0 address_intE0h_getVersion         6  INT E0h helper
; 0000:A3E6 address_intE0h_callDb            14  INT E0h: call DMDB function
; 0000:A3F4 address_intE0h_callRes           16  INT E0h: call resource function
; 0000:A404 address_intE0h_dispatch          21  INT E0h: dispatch helper
; 0000:A419 address_intE0h_getDirInfo         6  INT E0h: get directory info
; 0000:A41F address_intE0h_setFileList        6  INT E0h: set file listing pointer
; 0000:A425 address_intE0h_getFileVer         6  INT E0h: get file format version
; 0000:A42B address_intE0h_createDialog       6  INT E0h: create dialog box
; 0000:A431 address_intE0h_closeDialog        6  INT E0h: close dialog
; 0000:A437 address_intE0h_dialogResult       6  INT E0h: get dialog result
; 0000:A43D address_intE0h_resolveGuf         6  INT E0h: resolve DMGUF function
; 0000:A443 address_intE0h_resolveDb          6  INT E0h: resolve DMDB function
; 0000:A449 address_intE0h_execResource     154  INT E0h AX=0208h: execute resource function
; 0000:A4E3 address_intE0h_helper            15  INT E0h helper stub
;
; --- MSC 5.x C Runtime Library ---
;
; 0000:A4F2 msc_farCallWithArgs             711  Far-call dispatcher with argument marshaling
; 0000:A7B9 msc_noop_ret                     22  Return 0 stub
; 0000:A7CF msc_noop_ret2                     3  Simple return stub
; 0000:A7D2 msc_serialPortIO                66  Serial port I/O via INT 14h
; 0000:A814 msc_modemStatusCheck             51  Check modem status via INT 14h
; 0000:A847 msc_timerDelay                   20  Timer delay loop
; 0000:A85B msc_resolvePhonePtr              30  Resolve phone number far pointer
; 0000:A879 msc_modemInit                    55  Initialize modem subsystem
; 0000:A8B0 msc_comPortDispatch             146  COM port command dispatcher
; 0000:A942 msc_dialAndConnect              347  Dial and establish connection
; 0000:AA9D msc_hangup                       43  Hang up modem
; 0000:AAC8 msc_serialIO                    470  Low-level serial I/O engine
; 0000:AC9E msc_checkCarrier                 43  Check carrier detect signal
; 0000:ACC9 msc_sendByte                    107  Send byte to COM port
;
; --- String/Memory Operations (MSC runtime) ---
;
; 0000:AD34 msc_memcpy_near                  18  Near memcpy wrapper
; 0000:AD46 msc_memcpy_far                   70  Far memcpy (with segment support)
; 0000:AD8C msc_sprintf                      84  sprintf() - format to buffer
; 0000:ADE0 msc_strcpy                       64  strcpy() - copy string
; 0000:AE20 msc_strcat                       50  strcat() - concatenate strings
; 0000:AE52 msc_strcmp                       15  strcmp() - compare strings
; 0000:AE61 msc_strlen_alt                   29  strlen() - alternate version
; 0000:AE7E msc_strlen                       28  strlen() - get string length
; 0000:AE9A msc_strncpy                      54  strncpy() - copy n chars
; 0000:AED0 msc_strncpy_alt                  40  strncpy() - alternate with args reordered
; 0000:AEF8 msc_atoi                          4  atoi() - ASCII to integer
; 0000:AEFC msc_itoa                          4  itoa() - integer to ASCII
; 0000:AF00 msc_memset                       28  memset() - fill memory
; 0000:AF1C msc_writeToFile                  88  Write buffer to file handle (INT 21h AH=40h)
; 0000:AF74 msc_closeFile                    66  Close file handle (INT 21h AH=3Eh)
; 0000:AFB6 msc_memset_fast                  46  Fast memset (word-aligned)
;
; --- Long Arithmetic (MSC runtime) ---
;
; 0000:AFE4 msc_ldiv                        164  ldiv() - long division
; 0000:B088 msc_lmul                         52  lmul() - long multiply
; 0000:B0BC msc_lmod                        166  lmod() - long modulo
; 0000:B162 msc_lshift                       34  Long left shift
; 0000:B184 msc_ladd                         34  Long add
; 0000:B1A6 msc_julianCalc                  105  Julian calendar calculation helper
;
; --- Printf Engine (MSC runtime) ---
;
; 0000:B20F msc_formatNumber                227  Format number for printf
; 0000:B2F2 msc_formatHelper                 58  Format helper
; 0000:B32C msc_formatPad                    34  Pad output
; 0000:B34E msc_doprintf                    116  Core printf engine
; 0000:B3C2 msc_writeFormatted              374  Write formatted output
; 0000:B538 msc_ultoa                       110  ultoa() - unsigned long to string
; 0000:B5A6 msc_ltoa                         86  ltoa() - long to string
; 0000:B5FC msc_formatInt                   176  Format integer for printf
; 0000:B6AC msc_formatString                212  Format string for printf
; 0000:B780 msc_writeChar                    86  Write single char to output
; 0000:B7D6 msc_divmod10                     58  Division by 10 helper
;
; --- CRT Startup (segment 0B81) ---
;
; 0B81:0000 start                           156  MSC 5.x CRT startup (_cstart)
;                                                - Checks DOS version >= 2.0
;                                                - Sets up SS:SP (1680:1000), DS (0BBD)
;                                                - Resizes memory block (INT 21h AH=4Ah)
;                                                - Zeroes BSS (0x3092..0xAC30)
;                                                - Parses command line (__setargv)
;                                                - Sets up environment (__setenvp)
;                                                - Calls _main() at 0000:0010
;                                                - Handles DeskMate host callbacks
;
; 0B81:009C sub_0B8AC                       708  DM89 main event dispatch / host interface
;                                                - INT E0h AX=0600h (event poll)
;                                                - INT E0h AX=060Dh (check status)
;                                                - INT E0h AX=060Eh (dispatch event)
;                                                - INT E0h AX=4D04h (load PDM)
;                                                - INT E0h AX=4D05h (unload PDM)
;                                                - INT E0h AX=4D06h (task switch)
;
; 0B81:0360 crt_closeFile                     5  Close file handle (DMDB func 0x20E0)
; 0B81:0365 crt_openFile                      5  Open file handle (DMDB func 0x20DF)
; 0B81:036A crt_getWindowHeight               5  Get window height (DMDB func 0x203B)
; 0B81:036F crt_getWindowWidth                5  Get window width (DMDB func 0x203A)
; 0B81:0374 crt_readFileBlock                 5  Read file block (DMDB func 0x202B)
; 0B81:0379 crt_writeFileBlock                5  Write file block (DMDB func 0x202C)
; 0B81:037E crt_refreshForm                   5  Refresh form (DMDB func 0x2132)
; 0B81:0383 crt_commitForm                    5  Commit form (DMDB func 0x2131)
; 0B81:0388 crt_getFormVersion                3  Get form version (DMDB func 0x2111)
; 0B81:038B crt_genericDispatch              30  Generic DMDB far-call dispatcher
;
; 0B81:0397 crt_callFormEngine                   Far-call to form engine entry
; 0B81:03A9 sub_0BBB9                      5940  DM89 import table resolver and dispatch
;                                                (Largest function - resolves dmguf/dmdb imports)
;
; --- DM89 Import Resolver (segment 0B8C, sub_0D2ED) ---
;
; 0B8C:0000 (segment 0B8C)                  ~0x310 bytes  DM89 import far-call dispatcher
;
; 0B81:03A9 sub_0BBB9                      5940  DM89 import resolver
; 0B81:1ADD sub_0D2ED                      1749  DM89 dispatch table builder
; 0B81:21B2 sub_0D9C2                       236  DM89 resource resolver
; 0B81:229E sub_0DAAE                       273  DM89 function table populator
; 0B81:23AF sub_0DBBF                      4258  DM89 far-call stub generator and linker
;                                                (Largest function in binary)
;
; ========================================================================
; INT E0h CALLS (DeskMate API)
; ========================================================================
;
; AX=0206h  Load resource module (dmguf, dmdb)
;           at 0x9260, 0x906E, 0x90C2, 0x938B
; AX=0207h  Unload resource module
;           at 0x927A, 0x90A3, 0x9104, 0x939D
; AX=0208h  Execute resource function (call exported function)
;           at 0x9063, 0x9082, 0x90DA
; AX=0600h  Poll for event (get keyboard/mouse/timer input)
;           at 0x9290 (in address_deskMateFileIO), 0xB906 (CRT)
; AX=0603h  Dispatch / write file data
;           at 0x930D, 0x9345 (in address_deskMateFileIO)
; AX=060Eh  Process / dispatch event to application
;           at 0x929C (in address_deskMateFileIO)
; AX=0700h  Allocate memory / cooperative yield
;           at 0x926E (in address_loadResourceModule)
; AX=4D05h  Unload PDM application
;           at 0xBAC6 (CRT host callback)
;
; ========================================================================
; INT 21h CALLS (DOS API)
; ========================================================================
;
; AH=0Eh  Set default drive (used in file management)
; AH=19h  Get current drive
; AH=25h  Set interrupt vector (CRT startup)
; AH=2Ah  Get date (date validation)
; AH=2Ch  Get time
; AH=30h  Get DOS version (CRT startup, check >= 2.0)
; AH=34h  Get InDOS flag pointer (CRT startup, re-entrancy guard)
; AH=35h  Get interrupt vector (CRT startup)
; AH=3Eh  Close file handle (import/export, print)
; AH=40h  Write to file handle (import/export, print)
; AH=44h  IOCTL (printer status check)
; AH=48h  Allocate memory block (MSC runtime malloc)
; AH=49h  Free memory block (MSC runtime free)
; AH=4Ah  Resize memory block (CRT startup, release excess to DOS)
; AH=4Ch  Exit process (with return code)
; AH=50h  Set PSP (CRT host callback)
; AH=51h  Get PSP (CRT host callback)
;
; ========================================================================
; INT 14h CALLS (RS-232 Serial Communications)
; ========================================================================
;
; The auto-dial feature uses INT 14h (BIOS serial port services):
;   AH=00h  Initialize serial port (set baud rate, parity, etc.)
;   AH=01h  Send character to serial port
;   AH=02h  Receive character from serial port
;   AH=03h  Get serial port status (check carrier detect, etc.)
;
; The modem engine at sub_097EE/sub_0983E/sub_0A8B0 builds AT commands
; (ATZ, ATD, ATH, ATE) and sends them character-by-character, then
; waits for response codes from the modem.
;
; ========================================================================
; INT E2h CALLS (Extended DeskMate Services)
; ========================================================================
;
; ADDRESS.PDM makes 5 INT E2h calls. These appear to be in the DM89
; import resolver (sub_0DBBF) and provide extended memory or DMA
; services. The exact subfunctions are not yet decoded.
;
; ========================================================================
; MENU COMMAND IDS
; ========================================================================
;
; Menu commands are dispatched via the jump table at 0000:0290.
; The command IDs are 16-bit values in the 0xF5xx range:
;
; 0xF500  File > New          - Create new address book
; 0xF501  File > Open         - Open existing address book
; 0xF502  File > Save         - Save current address book
; 0xF503  File > Print        - Print (labels/envelopes/list)
; 0xF504  File > Import       - Import records
; 0xF505  File > Export       - Export records
; 0xF506  (reserved)
; 0xF507  File > Exit         - Exit Address Book
; 0xF508  File > Close        - Close current file
;
; 0xF564  Edit > Cut           (0xF564 range for edit commands)
; 0xF565  Edit > Copy
; 0xF566  Edit > Paste
; 0xF567  Edit > Undo
;
; Sub-event codes (keyboard/form events):
; 0xF50A-0xF510  Navigation (tab, shift-tab, page, home, end)
; 0xF514-0xF51B  Record operations (add, delete, undelete, modify)
;
; Window sub-events from DMDB:
;   0xF500  New/resize event
;   0xF510  Window state change
;
; The jump table at 0x0290 has 44 entries (0x00-0x2B) mapping
; event codes to handler addresses.
;
; ========================================================================
; WINDOW DISPLAY MODES
; ========================================================================
;
; [0x78] g_displayMode values:
;   1 = List view (multiple records in compact format)
;   2 = Card/detail view (single record with all fields)
;
; The mode is set during initialization based on the command line
; parameter: 'L' = list mode (1), other = card mode (2).
;
; ========================================================================
; ALPHABETICAL INDEX TAB SYSTEM
; ========================================================================
;
; The address book provides A-Z index tabs for quick navigation.
; When a user clicks a letter tab, the display filters to show
; only records whose last name starts with that letter.
;
; Key functions:
;   address_initAlphaIndex (0x23B8) - Initialize the 26-letter index
;   address_buildAlphaIndex (0x2509) - Build index entries from DB
;   address_selectAlphaTab (0x24B6) - Select a specific letter
;   address_updateAlphaTabDisplay (0x2362) - Redraw tab bar
;   address_applyFilter (0x266F) - Apply letter filter to records
;   address_removeFilter (0x2688) - Remove filter, show all records
;
; The alpha tab index is stored at [0x70FB] (0-25 for A-Z).
;
; ========================================================================
; AUTO-DIAL SUBSYSTEM
; ========================================================================
;
; The auto-dial feature (sub_0609A, 1833 bytes -- largest app function)
; enables users to dial phone numbers directly from contact cards
; using a Hayes-compatible modem connected to a COM port.
;
; The modem engine:
;   1. Detects available COM ports via BIOS data area (0040:00C2)
;   2. Initializes the serial port (INT 14h AH=00h)
;   3. Sends "ATZ" to reset the modem
;   4. Sends "ATDx<number>" to dial (tone or pulse)
;   5. Monitors carrier detect for connection
;   6. Sends "ATH" to hang up
;
; The modem state block at [0x2824] tracks:
;   - Command state (init/dialing/connected/error)
;   - Far pointer to phone number string
;   - Connection result code
;   - Retry counter
;
; ========================================================================
; PRINT SUBSYSTEM
; ========================================================================
;
; The print subsystem supports three output formats:
;   1. Labels - Formatted mailing labels
;   2. Envelopes - Formatted envelope addressing
;   3. List - Tabular list of all records
;
; Each format has its own dialog (4868, 4A59, 4BF6) and execution
; engine (4CA6, 4F6C, 51A1). The print engine at 0x7102 (1798 bytes)
; iterates through records and calls the format-specific handler.
;
; Print configuration is stored/loaded via:
;   address_loadPrintConfig (0x67C3)
;   address_savePrintConfig (0x681E)
;
; ========================================================================
; DATE VALIDATION
; ========================================================================
;
; The date validation subsystem (sub_09B88, 548 bytes) provides:
;   - Full date string parsing ("MM/DD/YY" or "MM/DD/YYYY")
;   - Month range validation (1-12)
;   - Day range validation (1-N based on month)
;   - Leap year detection (divisible by 4 but not 100, or by 400)
;     - Tests: year % 4 == 0, year % 100 == 0, year % 400 == 0
;   - Two-digit year normalization (0-99 -> 1900-1999, via + 0x76C)
;   - Days-per-month lookup table at [0x287E]
;
; The leap year detection code is at approximately 0x9D3C-0x9D65:
;   idiv 4     -> if remainder != 0, not divisible by 4, check 400
;   idiv 100   -> if remainder != 0, IS a leap year
;   idiv 400   -> if remainder != 0, NOT a leap year
;   If February (month==2): increment days-in-month by 1
;
; ========================================================================
; BEGIN ANNOTATED DISASSEMBLY
; ========================================================================

; ========================================================================
; SEGMENT 0000: Main Application Code
; ========================================================================

; Zero-filled entry (8 words, unused -- reserved by DM89 loader)
  00000  0000           dw       0                       ; 0000:0000  Reserved
  00002  0000           dw       0                       ; 0000:0002
  00004  0000           dw       0                       ; 0000:0004
  00006  0000           dw       0                       ; 0000:0006
  00008  0000           dw       0                       ; 0000:0008
  0000A  0000           dw       0                       ; 0000:000A
  0000C  0000           dw       0                       ; 0000:000C
  0000E  0000           dw       0                       ; 0000:000E

; ========================================================================
; address_main - _main(argc, argv)
; ========================================================================
; Address: 0000:0010 | Size: 801 bytes
; Parameters: [bp+4] = argc (unused)
; Returns: never (calls _exit via address_exitCleanup)
;
; This is the main entry point called from the CRT startup.
; It performs the following initialization sequence:
;   1. Load DMGUF resource module (call 0x93A5 -> address_loadAndResolve)
;   2. Load DMDB resource module (call 0x90B8 -> address_loadDbModule)
;   3. Allocate workspace memory (call 0x954F -> dmdb_func_allocWorkspace)
;   4. Try to load configuration block (call 0x9F17 -> address_atCmd_ATZ)
;   5. Parse command line for display mode ('L' = list)
;   6. Initialize memory, alpha index, record display
;   7. Open file or show file dialog
;   8. Enter main event loop (address_mainEventLoop at 0x1366)
;
; The event loop processes:
;   - Type 1: Keyboard input -> address_handleKeyboardEvent (0x1A28)
;   - Type 2: Form event -> address_mainEventHandler (0x34EE)
;   - Type 3: Menu command -> jump table dispatch
;   - Type 4: System event -> address_handleWindowResize (0x0C48)
;   - Type 6: Window event -> address_updateRecordDisplay (0x3696)
;
address_main:
  00010  55             push     bp                      ; 0000:0010  Standard MSC prologue
  00011  8bec           mov      bp, sp                  ; 0000:0011
  00013  83ec04         sub      sp, 4                   ; 0000:0013  2 local vars

  ; --- Step 1: Load DMGUF resource ---
  00016  e88c93         call     address_loadAndResolve  ; 0000:0016  Load DMGUF + resolve ptrs
  00019  40             inc      ax                      ; 0000:0019  Check for error (-1)
  0001A  750a           jne      .past_dmguf_err         ; 0000:001A
  0001C  b80100         mov      ax, 1                   ; 0000:001C  Exit code 1
  0001F  50             push     ax                      ; 0000:001F
  00020  e8350e         call     address_exitCleanup     ; 0000:0020  Fatal: can't load DMGUF
  00023  83c402         add      sp, 2                   ; 0000:0023
.past_dmguf_err:

  ; --- Step 2: Load DMDB resource ---
  00026  e88f90         call     address_loadDbModule    ; 0000:0026  Load DMDB module
  00029  40             inc      ax                      ; 0000:0029  Check for error (-1)
  0002A  750d           jne      .past_dmdb_err          ; 0000:002A
  0002C  e87d93         call     address_resolveAndUnload ; 0000:002C  Cleanup DMGUF
  0002F  b80100         mov      ax, 1                   ; 0000:002F  Exit code 1
  00032  50             push     ax                      ; 0000:0032
  00033  e8220e         call     address_exitCleanup     ; 0000:0033  Fatal: can't load DMDB
  00036  83c402         add      sp, 2                   ; 0000:0036
.past_dmdb_err:

  ; --- Step 3: Allocate workspace ---
  00039  b84c00         mov      ax, 0x4c                ; 0000:0039  Workspace size = 76 bytes
  0003C  50             push     ax                      ; 0000:003C
  0003D  e80f95         call     dmdb_func_allocWorkspace ; 0000:003D  dmdb func 0x202D-ish
  00040  83c402         add      sp, 2                   ; 0000:0040

  ; --- Step 4: Try to load configuration block ---
  00043  b8d27b         mov      ax, 0x7bd2              ; 0000:0043  Address of g_configBlock
  00046  50             push     ax                      ; 0000:0046
  00047  e8cd9e         call     address_atCmd_ATZ       ; 0000:0047  (Overloaded: also loads config)
  0004A  83c402         add      sp, 2                   ; 0000:004A
  0004D  40             inc      ax                      ; 0000:004D  Check if config found (-1 = no)
  0004E  7524           jne      .has_config             ; 0000:004E

  ; --- No configuration: use defaults ---
  00050  c7062cac0000   mov      word ptr [0xac2c], 0    ; 0000:0050  g_hasConfigBlock = 0
  00056  c70678000100   mov      word ptr [0x78], 1      ; 0000:0056  g_displayMode = 1 (list)
  0005C  c6069c0408     mov      byte ptr [0x49c], 8     ; 0000:005C  Label config: 8 fields
  00061  c7069d04e802   mov      word ptr [0x49d], 0x2e8 ; 0000:0061  Label offset = 744
  00067  c606b80402     mov      byte ptr [0x4b8], 2     ; 0000:0067  Envelope config: 2
  0006C  c706b9046004   mov      word ptr [0x4b9], 0x460 ; 0000:006C  Envelope offset = 1120
  00072  eb4d           jmp      .init_continue          ; 0000:0072

.has_config:
  ; --- Parse command line for display mode ---
  00074  b8922d         mov      ax, 0x2d92              ; 0000:0074  Config string offset
  00077  50             push     ax                      ; 0000:0077
  00078  e8cd10         call     address_allocMemBlock   ; 0000:0078  Allocate for cmdline parse
  0007B  83c402         add      sp, 2                   ; 0000:007B
  0007E  a3bc80         mov      word ptr [0x80bc], ax   ; 0000:007E  g_cmdLinePtr = result
  00081  0bc0           or       ax, ax                  ; 0000:0081
  00083  7508           jne      .has_cmdline            ; 0000:0083
  00085  c70678000100   mov      word ptr [0x78], 1      ; 0000:0085  Default: list mode
  0008B  eb18           jmp      .set_config             ; 0000:008B
.has_cmdline:
  0008D  8b1ebc80       mov      bx, word ptr [0x80bc]   ; 0000:008D  Get cmdline pointer
  00091  c45f07         les      bx, ptr [bx + 7]        ; 0000:0091  Load far ptr to param
  00094  26803f4c       cmp      byte ptr es:[bx], 0x4c  ; 0000:0094  Compare with 'L'
  00098  7505           jne      .not_list_mode          ; 0000:0098
  0009A  b80100         mov      ax, 1                   ; 0000:009A  List mode
  0009D  eb03           jmp      .store_mode             ; 0000:009D
.not_list_mode:
  0009F  b80200         mov      ax, 2                   ; 0000:009F  Card/detail mode
.store_mode:
  000A2  a37800         mov      word ptr [0x78], ax     ; 0000:00A2  g_displayMode = mode
.set_config:
  000A5  c7062cac0100   mov      word ptr [0xac2c], 1    ; 0000:00A5  g_hasConfigBlock = 1
  000AB  c6069c040a     mov      byte ptr [0x49c], 0xa   ; 0000:00AB  Label config: 10 fields
  000B0  c7069d044003   mov      word ptr [0x49d], 0x340 ; 0000:00B0  Label offset = 832
  000B6  c606b80403     mov      byte ptr [0x4b8], 3     ; 0000:00B6  Envelope config: 3
  000BB  c706b9047604   mov      word ptr [0x4b9], 0x476 ; 0000:00BB  Envelope offset = 1142

.init_continue:
  ; --- Initialize state ---
  000C1  c706d07b0000   mov      word ptr [0x7bd0], 0    ; 0000:00C1  g_initFlag = 0
  000C7  b8fe70         mov      ax, 0x70fe              ; 0000:00C7  g_memBlockSize address
  000CA  50             push     ax                      ; 0000:00CA
  000CB  e8e11d         call     address_initFileAndView ; 0000:00CB  Init file system and view
  000CE  83c402         add      sp, 2                   ; 0000:00CE
  000D1  a31c7a         mov      word ptr [0x7a1c], ax   ; 0000:00D1  g_memHandle = result

  ; --- Open file via file manager ---
  000D4  b80600         mov      ax, 6                   ; 0000:00D4  File mode = 6 (open or new)
  000D7  50             push     ax                      ; 0000:00D7
  000D8  e8289f         call     address_fileManager     ; 0000:00D8  Open/create file dialog
  000DB  83c402         add      sp, 2                   ; 0000:00DB
  000DE  8946fc         mov      word ptr [bp - 4], ax   ; 0000:00DE  result = file handle
  000E1  3dffff         cmp      ax, 0xffff              ; 0000:00E1  -1 = cancel/error
  000E4  7412           je       .exit_no_file           ; 0000:00E4
  000E6  3dc6ff         cmp      ax, 0xffc6              ; 0000:00E6  -58 = disk error
  000E9  751d           jne      .file_opened            ; 0000:00E9

  ; --- Disk error: show message and exit ---
  000EB  b8982d         mov      ax, 0x2d98              ; 0000:00EB  Error message string
  000EE  50             push     ax                      ; 0000:00EE
  000EF  e88592         call     dmdb_func_resolveStr    ; 0000:00EF  Resolve string
  000F2  83c402         add      sp, 2                   ; 0000:00F2
  000F5  e8909e         call     address_resetFileState  ; 0000:00F5  Reset state

.exit_no_file:
  000F8  e8ff8f         call     address_unloadImportedResources ; 0000:00F8  Unload DMDB
  000FB  e8ae92         call     address_resolveAndUnload ; 0000:00FB  Unload DMGUF
  000FE  b80100         mov      ax, 1                   ; 0000:00FE  Exit code 1
  00101  50             push     ax                      ; 0000:0101
  00102  e8530d         call     address_exitCleanup     ; 0000:0102  Exit
  00105  83c402         add      sp, 2                   ; 0000:0105

.file_opened:
  ; --- File successfully opened: init display ---
  00108  b80300         mov      ax, 3                   ; 0000:0108  Function code 3
  0010B  50             push     ax                      ; 0000:010B
  0010C  b83300         mov      ax, 0x33                ; 0000:010C  Parameter = 0x33
  0010F  50             push     ax                      ; 0000:010F
  00110  e8250c         call     address_callDmdbFunction ; 0000:0110  Call DMDB setup func
  00113  83c404         add      sp, 4                   ; 0000:0113
  00116  8946fc         mov      word ptr [bp - 4], ax   ; 0000:0116
  00119  0bc0           or       ax, ax                  ; 0000:0119
  0011B  7413           je       .setup_ok               ; 0000:011B

  ; --- Setup failed: cleanup and exit ---
  0011D  e8689e         call     address_resetFileState  ; 0000:011D
  00120  e8d78f         call     address_unloadImportedResources ; 0000:0120
  00123  e88692         call     address_resolveAndUnload ; 0000:0123
  00126  b80100         mov      ax, 1                   ; 0000:0126
  00129  50             push     ax                      ; 0000:0129
  0012A  e82b0d         call     address_exitCleanup     ; 0000:012A
  0012D  83c402         add      sp, 2                   ; 0000:012D

.setup_ok:
  ; --- Set up title bar and window layout ---
  00130  e8cf0a         call     address_setupTitleBar   ; 0000:0130
  00133  e8ab92         call     dmdb_endTransaction     ; 0000:0133  End init transaction
  00136  e82693         call     dmdb_getWorkspaceSize   ; 0000:0136  Get workspace size
  00139  a30066         mov      word ptr [0x6600], ax   ; 0000:0139  g_envSegment = result
  0013C  b82201         mov      ax, 0x122               ; 0000:013C  Min width = 290
  0013F  50             push     ax                      ; 0000:013F
  00140  e83493         call     dmdb_func_getWidth      ; 0000:0140  Get window width
  00143  83c402         add      sp, 2                   ; 0000:0143
  00146  055801         add      ax, 0x158               ; 0000:0146  + 344 = top offset
  00149  50             push     ax                      ; 0000:0149
  0014A  e83093         call     dmdb_func_getMetric     ; 0000:014A  Get vertical metric
  0014D  83c402         add      sp, 2                   ; 0000:014D
  00150  a36800         mov      word ptr [0x68], ax     ; 0000:0150  g_windowTop = result
  00153  b87c15         mov      ax, 0x157c              ; 0000:0153  Max height = 5500
  00156  2b066800       sub      ax, word ptr [0x68]     ; 0000:0156  height = max - top
  0015A  a36c00         mov      word ptr [0x6c], ax     ; 0000:015A  g_windowHeight = height
  0015D  b86600         mov      ax, 0x66                ; 0000:015D  Field width = 102
  00160  50             push     ax                      ; 0000:0160
  00161  e8ef92         call     dmdb_func_getFieldWidth ; 0000:0161
  00164  83c402         add      sp, 2                   ; 0000:0164
  00167  a36080         mov      word ptr [0x8060], ax   ; 0000:0167  g_maxFieldWidth
  0016A  ff369c00       push     word ptr [0x9c]         ; 0000:016A  g_currentRecIdx
  0016E  e87a90         call     dmguf_func_setRecord    ; 0000:016E  Set to current record
  00171  83c402         add      sp, 2                   ; 0000:0171
  00174  b80100         mov      ax, 1                   ; 0000:0174  Enable menu
  00177  50             push     ax                      ; 0000:0177
  00178  2bc0           sub      ax, ax                  ; 0000:0178  Menu ID = 0
  0017A  50             push     ax                      ; 0000:017A
  0017B  e8b393         call     dmdb_func_enableMenu    ; 0000:017B  Enable menu bar
  0017E  83c404         add      sp, 4                   ; 0000:017E
  00181  a39e82         mov      word ptr [0x829e], ax   ; 0000:0181  g_formHandle = result
  00184  e8d710         call     address_setupRecordView ; 0000:0184  Set up record view

  ; --- Enter main display and event loop ---
  00187  2bc0           sub      ax, ax                  ; 0000:0187  Initial alpha tab = 0 (All)
  00189  50             push     ax                      ; 0000:0189
  0018A  e80935         call     address_updateRecordDisplay ; 0000:018A
  0018D  83c402         add      sp, 2                   ; 0000:018D

; ========================================================================
; Main Event Loop
; ========================================================================
; This is the core event loop. It calls dmdb_getEvent to poll for
; events, then dispatches based on event type:
;   1 = keyboard, 2 = form, 3 = menu, 4 = system, 6 = window
;
.event_loop:
  00190  e85b33         call     address_mainEventHandler ; 0000:0190  Process pending events
  00193  b8f470         mov      ax, 0x70f4              ; 0000:0193  g_eventType address
  00196  50             push     ax                      ; 0000:0196
  00197  e85392         call     dmdb_getEvent           ; 0000:0197  Get next event
  0019A  83c402         add      sp, 2                   ; 0000:019A
  0019D  803ef47004     cmp      byte ptr [0x70f4], 4    ; 0000:019D  System event?
  001A2  7503           jne      .check_event_type       ; 0000:01A2
  001A4  e87382         call     address_handleWindowResize_far ; 0000:01A4  Handle system event

.check_event_type:
  001A7  a0f470         mov      al, byte ptr [0x70f4]   ; 0000:01A7  Get event type
  001AA  98             cbw                               ; 0000:01AA  Sign-extend to word
  001AB  3d0100         cmp      ax, 1                   ; 0000:01AB  Keyboard?
  001AE  7503           jne      .not_keyboard           ; 0000:01AE
  001B0  e93801         jmp      .handle_keyboard        ; 0000:01B0  -> keyboard handler

.not_keyboard:
  001B3  3d0200         cmp      ax, 2                   ; 0000:01B3  Form event?
  001B6  7503           jne      .not_form               ; 0000:01B6
  001B8  e94001         jmp      .handle_form            ; 0000:01B8  -> form handler

.not_form:
  001BB  3d0300         cmp      ax, 3                   ; 0000:01BB  Menu command?
  001BE  7410           je       .handle_menu            ; 0000:01BE  -> menu handler
  001C0  3d0600         cmp      ax, 6                   ; 0000:01C0  Window event?
  001C3  7503           jne      .no_event               ; 0000:01C3
  001C5  e95901         jmp      .handle_window          ; 0000:01C5  -> window handler

.no_event:
  001C8  c7069c6f0000   mov      word ptr [0x6f9c], 0    ; 0000:01C8  g_eventProcessed = 0
  001CE  ebc0           jmp      .event_loop             ; 0000:01CE  Back to event loop

; --- Menu command dispatch ---
.handle_menu:
  001D0  c7069c6f0100   mov      word ptr [0x6f9c], 1    ; 0000:01D0  g_eventProcessed = 1
  001D6  a1f570         mov      ax, word ptr [0x70f5]   ; 0000:01D6  g_eventCode
  001D9  2d64f5         sub      ax, 0xf564              ; 0000:01D9  Subtract menu base
  001DC  3d2b00         cmp      ax, 0x2b                ; 0000:01DC  Range check (0-43)
  001DF  7737           ja       .menu_check_special     ; 0000:01DF  Out of range -> special
  001E1  03c0           add      ax, ax                  ; 0000:01E1  Word index (* 2)
  001E3  93             xchg     bx, ax                  ; 0000:01E3
  001E4  2effa79002     jmp      word ptr cs:[bx + 0x290] ; 0000:01E4  Jump table dispatch

  ; Menu command dispatch targets:
  001E9  ff36f570       push     word ptr [0x70f5]       ; 0000:01E9  Push event code
  001ED  e84101         call     address_handleMenuCommand ; 0000:01ED  File/Edit menu
  001F0  eb9b           jmp      .event_loop_return      ; 0000:01F0

  001F2  ff36f570       push     word ptr [0x70f5]       ; 0000:01F2
  001F6  e80e04         call     address_handleEditCommand ; 0000:01F6  Edit command
  001F9  eb92           jmp      .event_loop_return      ; 0000:01F9

  001FB  ff36f570       push     word ptr [0x70f5]       ; 0000:01FB
  001FF  e84f05         call     address_handleFileCommand ; 0000:01FF  File command
  00202  eb89           jmp      .event_loop_return      ; 0000:0202

  00204  ff36f570       push     word ptr [0x70f5]       ; 0000:0204
  00208  e84d06         call     address_handlePrintCommand ; 0000:0208  Print command
  0020B  e97fff         jmp      .event_loop_return      ; 0000:020B

  0020E  ff36f570       push     word ptr [0x70f5]       ; 0000:020E
  00212  e8e908         call     address_handleOptionsCommand ; 0000:0212  Options command
  00215  e975ff         jmp      .event_loop_return      ; 0000:0215

; --- Special menu commands (0xF500-0xF510 range) ---
.menu_check_special:
  00218  c7069c6f0000   mov      word ptr [0x6f9c], 0    ; 0000:0218  g_eventProcessed = 0
  0021E  813ef57000f5   cmp      word ptr [0x70f5], 0xf500 ; 0000:021E  Below menu range?
  00224  7303           jae      .in_range               ; 0000:0224
  00226  e967ff         jmp      .event_loop             ; 0000:0226

; (Continues with window resize handling, keyboard dispatch, etc.)
; The full event loop body extends to address 0x0330.

; ========================================================================
; JUMP TABLE at 0000:0290 (44 entries)
; ========================================================================
; This is a word-sized jump table used by the menu command dispatcher.
; Each entry is a 16-bit offset within segment 0000 that handles
; one of the 44 possible menu command codes (0xF564 through 0xF58F).
;
; Due to the raw disassembly format, these appear as data words
; that have been misinterpreted as instructions. The entries map to:
;   0x01E9, 0x01E9, ... (repeated for File menu commands)
;   0x01F2, 0x01F2, ... (repeated for Edit menu commands)
;   0x0218, ...          (for Search/Sort commands)
;   0x01FB, 0x01FB, ... (for Print commands)
;   0x0204, ...          (for Options commands)
; ========================================================================

; ========================================================================
; (Remaining application functions continue from 0x0331 through 0x90F9)
;
; The function bodies follow the same pattern as FILER.PDM:
;   - Standard MSC prologue: push bp; mov bp,sp; sub sp,N
;   - Local variables on stack at [bp-2], [bp-4], etc.
;   - Parameters at [bp+4], [bp+6], etc.
;   - Calls to DMDB thunks (sub_093xx-sub_095xx) for database operations
;   - Calls to DMGUF thunks (sub_091xx) for UI operations
;   - Standard MSC epilogue: mov sp,bp; pop bp; ret
;
; Key function groups by address range:
;
; Application Core (0x0010-0x0D38):
;   address_main, address_handleMenuCommand,
;   address_handleEditCommand, address_handleFileCommand,
;   address_handlePrintCommand, address_handleOptionsCommand,
;   address_setupTitleBar, address_closeFormEngine,
;   address_handleWindowResize, address_callDmdbFunction
;
; Host Interface (0x0D85-0x0EF0):
;   address_dispatchCallback, address_processCallbackEvent,
;   address_exitCleanup, address_unloadAndExit,
;   address_retFarStub, address_farCallDispatch,
;   address_hostCallback
;
; Error / Dialog (0x0F58-0x125D):
;   address_getDataSegment, address_showErrorDialog,
;   address_setMenuBarText, address_closeActiveSession,
;   address_allocMemBlock, address_freeMemBlock,
;   address_reallocMemBlock, address_loadImportedResources,
;   address_initFieldDisplay
;
; Record View Setup (0x125E-0x1365):
;   address_setupRecordView
;
; Main Event Loop (0x1366-0x1A27):
;   address_mainEventLoop (1730 bytes -- second largest app function)
;   Dispatches all event types, manages form sessions,
;   handles keyboard shortcuts, menu accelerators
;
; Keyboard Handling (0x1A28-0x1E4F):
;   address_handleKeyboardEvent (1064 bytes)
;   Processes key-down, key-up, field navigation,
;   character input, tab/shift-tab between fields
;
; File Operations (0x1E50-0x29C0):
;   address_openExistingFile, address_initFileAndView,
;   address_openNewFile, address_printDispatcher,
;   address_printMainLoop, address_printFinalize,
;   address_updateAlphaTabDisplay, address_initAlphaIndex,
;   address_selectAlphaTab, address_buildAlphaIndex,
;   address_applyFilter, address_sortAndRefresh,
;   address_openFileForEdit, address_promptSaveChanges,
;   address_handleFileSave, address_handleFileClose,
;   address_handleFileNew
;
; Record CRUD (0x2A66-0x3473):
;   address_checkModified, address_getModifiedFlag,
;   address_setModifiedFlag, address_editRecordAdd,
;   address_editRecordDelete, address_editRecordUndelete,
;   address_editRecordNavigate, address_searchDialog
;
; Event Handlers (0x34EE-0x3E4D):
;   address_mainEventHandler, address_updateRecordDisplay,
;   address_createFormRow, address_refreshAfterEdit,
;   address_sortDialog, address_sortExecute,
;   address_handleFieldNavigation, address_handleFieldSelect
;
; File Open/Create (0x3E80-0x4147):
;   address_fileOpenDialog (584 bytes)
;   address_dispatchRecordAction, address_openOrCreateFile
;
; Navigation (0x41F5-0x4867):
;   address_navigateAndDisplay (547 bytes),
;   address_gotoRecordDialog (836 bytes),
;   address_handleRecordNav, address_callDmdbSimple
;
; Print (0x4868-0x5DF0):
;   address_printLabelsDialog, address_printEnvelopesDialog,
;   address_printListDialog, address_printLabelsExecute,
;   address_printEnvelopesExecute, address_printListExecute,
;   address_printSetupDialog, address_printPreview,
;   address_refreshFieldDisplay, address_updateCardView,
;   address_updateListView
;
; Contact Card Renderer (0x58B7-0x5E8B):
;   address_renderContactCard (1337 bytes)
;   Renders the full contact card display with all fields,
;   labels, separators, and formatting. Uses extensive calls
;   to DMDB field metric functions (dmdb_getRecordMetric,
;   dmdb_func_204B, etc.) to position fields correctly.
;
; Search / Highlight (0x5DF0-0x6099):
;   address_setFieldHighlight, address_clearFieldHighlight,
;   address_handleSearchResult
;
; Auto-Dial (0x609A-0x6862):
;   address_autoDialPhone (1833 bytes -- largest app function)
;   Complete modem auto-dial implementation including:
;   COM port detection, AT command protocol, dial/hangup,
;   carrier detect monitoring, error handling
;
; Print Engine (0x6863-0x826A):
;   address_formatPrintOutput, address_handlePrintProgress,
;   address_initPrintSession, address_printEngine,
;   address_formatLabelFields, address_formatSingleField,
;   address_printSetupUI, address_printPreviewRender,
;   address_printFormatRecord
;
; Import/Export (0x826B-0x8F8E):
;   address_importExportDialog, address_importRecords,
;   address_exportRecords, address_formatExportRecord,
;   address_parseImportRecord, address_getFieldCount,
;   address_validateRecord, address_insertImportedRecord,
;   address_clearRecordBuffer, address_promptForFilename,
;   address_openImportFile, address_openExportFile,
;   address_fileOperationCore, address_modemDialSetup
;
; Resource Management (0x90FA-0x9282):
;   address_unloadImportedResources,
;   DMGUF/DMDB dummy stubs, resource load/unload,
;   address_loadResourceModule
;
; DeskMate File I/O (0x9283-0x9352):
;   address_deskMateFileIO -- complex routine that switches
;   stack segments for print buffer operations, calls
;   INT E0h 0600h/060Eh/0603h for file I/O through DESK.EXE
;
; DMDB Thunks (0x9359-0x9578):
;   Complete DMDB function dispatch thunk table.
;   Each thunk loads AX with a function code (0x20xx) and
;   jumps to sub_093B3 (address_callDmdbDispatch).
;
; DMGUF Thunks (0x91A3-0x9215):
;   DMGUF function dispatch thunks.
;   Each thunk loads AX with a function ID (0x00-0xBF) and
;   jumps to the DMGUF dispatcher at loc_09122 or loc_09166.
;
; Modem Engine (0x957A-0x9F87):
;   address_modemInit, address_modemCheckStatus,
;   address_modemDial, address_modemConnect,
;   address_modemProbe, address_modemWaitResponse,
;   address_modemSendCommand, address_formatDate,
;   address_validateDateRange, address_computeDateValue,
;   address_parseDate, address_getDaysInMonth,
;   address_intToStringPadded, address_dateToJulian,
;   address_setDialTimeout, AT command builders
;
; File Manager (0x9F88-0xA274):
;   address_resetFileState, address_checkWriteProtect,
;   address_checkDiskSpace, address_closePrintOutput,
;   address_fileManager, address_fileOpenManager
;
; Utilities (0xA275-0xA4F1):
;   address_intToDecString, address_copyStringToES,
;   address_getStringLength, address_detectComPorts,
;   INT E0h wrappers
;
; MSC Runtime (0xA4F2-0xB7D6):
;   Standard MSC 5.x C runtime library functions including
;   far-call dispatcher, string operations (strcpy, strcat,
;   strcmp, strlen, strncpy), memory operations (memcpy,
;   memset), printf engine, integer conversion (atoi, itoa),
;   long arithmetic (ldiv, lmul, lmod)
;
; See FUNCTION INDEX above for complete address/size listing.
; ========================================================================

; ========================================================================
; SEGMENT 0B81: CRT Startup
; ========================================================================
; MSC 5.x C Runtime startup code (_cstart).
; - Checks DOS version >= 2.0 (INT 21h AH=30h)
; - Sets up SS:SP (1680:1000), DS (0BBD)
; - Resizes memory block (INT 21h AH=4Ah)
; - Zeroes BSS region (0x3092..0xAC30)
; - Parses command line arguments (__setargv)
; - Sets up environment pointers (__setenvp)
; - Installs DeskMate host callbacks:
;   - INT E0h AX=0600h (event poll)
;   - INT E0h AX=060Eh (dispatch event)
;   - INT E0h AX=4D04h (load PDM)
;   - INT E0h AX=4D05h (unload PDM)
;   - INT E0h AX=4D06h (task switch)
; - Calls _main() at 0000:0010
; - On return: calls _exit()
;
; Host callback (at 0B81:024B):
;   Intercepts idle calls to check for DeskMate task switch.
;   When DeskMate requests a switch (via event 0xFF3B), saves/restores
;   PSP (INT 21h AH=51h/50h) and calls through the registered
;   callback function at [cs:001C].
;   Uses INT E0h AX=4D05h (unload PDM) after callback completes.
;
; The CRT host stubs at 0B81:0360-0B81:038B provide thin wrappers
; for DMDB functions needed during startup:
;   0x20E0 = close file, 0x20DF = open file,
;   0x203B = window height, 0x203A = window width,
;   0x202B = read block, 0x202C = write block,
;   0x2132 = refresh form, 0x2131 = commit form,
;   0x2111 = get form version
;
; sub_0B8AC (708 bytes at 0B81:009C) is the main DM89 event dispatch
; and host interface function. It:
;   1. Sets DS to DGROUP (0BBD)
;   2. Loads the file manager entry via lcall 0,0x975E
;   3. Processes host events from DESK.EXE
;   4. Manages the close-file callback chain
;
; sub_0BBB9 (5940 bytes at 0B81:03A9) is the DM89 import table resolver.
; It resolves far-call pointers for the two imported resources
; (dmguf, dmdb) at module load time. This is the second-largest
; function in the binary.
;
; The data immediately after the CRT code includes:
;   0B81:03C8  "MS RunTime Library - Copyright (c) 1987, Microsoft Corp"
;              MSC 5.x copyright string (identifies compiler version)
; ========================================================================

; ========================================================================
; SEGMENT 0B8C: DM89 Import Far-Call Dispatcher
; ========================================================================
; ~0x310 bytes of import resolution and dispatch code.
; This segment contains the DM89 dynamic linker that resolves
; imported functions from dmguf and dmdb resource modules at load time.
; ========================================================================

; ========================================================================
; SEGMENT 0BBD: DGROUP Data
; ========================================================================
; ~0x40 bytes of initialized data, primarily fixup targets for
; the MSC runtime. Contains DGROUP base for DS restoration.
; ========================================================================

; ========================================================================
; SEGMENT 0BC1: Application Data
; ========================================================================
; ~0xABF0 bytes (43,504 bytes) of application data including:
;
; String Resources (readable text extracted from data segment):
;   "Overwrite it?"
;   "Field delimiter:"
;   "Dump Ascii Error"
;   "Align Labels"
;   "Are the labels correctly aligned?"
;   "Printing in progress..."
;   "Print Labels"
;   "The space occupied by the labels exceeds the space of the page."
;   "Please reformat labels."
;   "The size of the page exceeds the capacity of the printer."
;   "Please reformat labels."
;   "Label format must contain non-zero positive values."
;   "You must enter a number between 0 and 6."
;   "Format Error"
;   "Line number where first label starts"
;
; Menu Definitions:
;   Located at approximately 0x0BC1:0D00-0x0BC1:1000.
;   Includes File, Edit, Search, Print, Options menus.
;
; Dialog Templates:
;   Print Labels dialog, Print Envelopes dialog, Print List dialog,
;   Print Setup dialog, Search dialog, Sort dialog,
;   Go To Record dialog, File Open dialog, Import/Export dialog.
;
; Days-per-month Table (at data offset 0x2866-0x2898):
;   12 words: 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
;   (Note: February entry is 28; leap year logic adds 1 dynamically)
;
; Cumulative Days Table (at data offset 0x287E-0x28B0):
;   12 words representing cumulative days to start of each month.
;   Used for Julian date calculation.
; ========================================================================

; ========================================================================
; SEGMENT 1680: Stack
; ========================================================================
; 0x1000 bytes (4096 bytes) of stack space.
; SS:SP initialized to 1680:1000 by CRT startup.
; ========================================================================

; ========================================================================
; END OF ANNOTATED DISASSEMBLY
; ========================================================================
