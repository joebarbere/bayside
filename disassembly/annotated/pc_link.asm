; ========================================================================
; PC_LINK.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1984, 1988-1990
; Compiled with Microsoft C 5.x (1988), Medium Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; PC_LINK.PDM is the Tandy PC-Link online service client that runs
; inside the DeskMate 3.05 shell (DESK.EXE). PC-Link was a Tandy-
; specific online service (similar to CompuServe/Prodigy/GEnie) that
; provided access to Quantum Computer Services (later America Online)
; network. The service offered email, chat, file downloads, news,
; shopping, and other online content through a page/menu navigation
; interface.
;
; The module is the largest communications PDM in DeskMate 3.05 at
; 72,087 bytes (compared to TELECOM.PDM at 35,661 bytes). It handles:
;   - Modem initialization and dialing (via PROTOCOL.RES)
;   - User login and authentication with the PC-Link service
;   - Page/menu navigation of online content
;   - File download management (directory listing, selection, transfer)
;   - Email composition and reading
;   - Real-time chat
;   - Session management (connect, disconnect, timeout handling)
;   - Account information display
;   - Local file management for downloads
;
; The program dynamically loads two resource modules at runtime:
;   - PROTOCOL.RES: Serial port communication and file transfer protocol
;   - DMGUF.RES: DeskMate General User Functions (via PRGUF dispatch)
;
; Unlike TELECOM.PDM, PC_LINK.PDM has a significantly more complex
; architecture with 538 functions organized around a page-based navigation
; system. The online service presents content as a tree of pages/menus
; that the user navigates, with the module handling protocol-level
; communication with the Quantum network backend.
;
; Key features:
;   - Modem auto-dial with configurable access numbers
;   - Login/password authentication
;   - Hierarchical page/menu navigation system
;   - File download with directory browsing
;   - Email (read/compose/send)
;   - Real-time chat rooms
;   - Account information and billing display
;   - Network command protocol (packet-based communication)
;   - Session timeout and keepalive handling
;   - Error recovery and reconnection
;   - DeskMate menu bar integration (File, Network, etc.)
;   - Support for multiple video adapters (CGA, EGA, VGA, TGA, Hercules)
;
; INT E0h services used (20 calls total, 3 service classes):
;   AX=0206h: Load resource module (PROTOCOL, PRGUF, DMGUF)
;   AX=0207h: Unload resource module
;   AX=0208h: Execute resource module function (call dispatch)
;   AX=0600h: DeskMate file open / event poll
;   AX=0603h: DeskMate file write / resource dispatch
;   AX=060Eh: DeskMate file close / event dispatch
;   AX=0700h: Memory allocation / yield / timer tick
;
; INT 21h services used (18 unique AH values, 43 calls total):
;   AH=06h: Direct console I/O
;   AH=1Ah: Set DTA (Disk Transfer Area)
;   AH=25h: Set interrupt vector
;   AH=2Ah: Get date
;   AH=2Ch: Get time
;   AH=30h: Get DOS version
;   AH=35h: Get interrupt vector
;   AH=3Ah: Remove directory
;   AH=3Bh: Change directory
;   AH=3Dh: Open file
;   AH=3Eh: Close file
;   AH=40h: Write file
;   AH=42h: Seek file
;   AH=44h: IOCTL (device check)
;   AH=48h: Allocate memory
;   AH=49h: Free memory
;   AH=4Ah: Resize memory block
;   AH=4Ch: Exit process
;
; Other interrupts:
;   INT 11h: Equipment list (1 call) -- detect hardware configuration
;   INT 12h: Memory size (1 call) -- get conventional memory size
;   INT 14h: Serial port services (1 call) -- BIOS-level RS-232
;   INT 15h: System services (1 call) -- extended services / wait
;   INT 1Ah: Time of day (2 calls) -- get tick count for timing
;   INT 20h: Terminate program (1 call) -- DOS 1.x exit
;   INT ABh: Unknown (1 call) -- possibly DeskMate-specific hook
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 72,087 bytes
; Load image: 71,575 bytes (after header)
; DM89 entry point: 0FD1:000E (MSC 5.x CRT startup)
; SS:SP = 129D:07D0
;
; Segment Map (5 segments, 15 relocations):
;   seg_0000  0xFD10 bytes  CODE   Main application code (64,784 bytes)
;   seg_0FD1  0x000A bytes  CODE   MSC 5.x CRT startup stub (entry point)
;   seg_0FD2  0x0004 bytes  DATA   DGROUP fixup area
;   seg_0FD6  0x2CC7 bytes  DATA   CRT data, dispatch tables, menu structures,
;                                  string constants, page templates, config data
;   seg_129D  0x07D0 bytes  STACK  Stack segment (2,000 bytes)
;
; Medium memory model: multiple code segments (0000 + 0FD1), DGROUP at 0FD2.
;
; The DM89 overlay header provides the true CS:IP entry override, bypassing
; the broken MZ entry point. The CRT startup at 0FD1:000E checks DOS version,
; sets up SS:SP, resizes the memory block, zeroes BSS, and calls _main().
;
; ========================================================================
; RESOURCE MODULE INTERACTION
; ========================================================================
;
; PC_LINK.PDM loads resource modules dynamically via INT E0h:
;
; 1. PROTOCOL.RES (at DS:0x1428 / DS:0x142C)
;    - Provides serial port communication and file transfer protocol
;    - Loaded via INT E0h AX=0206h with name at DS:0x142C
;    - Called via far pointer at DS:0x1428 (dispatch block)
;    - Flag at DS:0x144A indicates which variant is active (0 or 1)
;    - Default stub at CS:0xCEA1 returns 0xFFFF when not loaded
;
; 2. DMGUF.RES (at DS:0x1436 / DS:0x143A and DS:0x1440 / DS:0x1444)
;    - DeskMate General User Functions
;    - Primary dispatch: loaded via INT E0h AX=0206h, name at DS:0x143A
;    - Secondary dispatch: loaded via INT E0h AX=0206h, name at DS:0x1444
;    - Called through far pointer at DS:0x1436 / DS:0x1440
;    - The module tests AX=0208h first; if result <= 0, tries alternate name
;    - Flag at DS:0x144A selects primary vs secondary dispatch
;    - Default stub at CS:0xCFFF/0xD003 returns 0xFFFF when not loaded
;
; 3. PRGUF.RES (at DS:0x146A / DS:0x146E)
;    - Program User Functions (core DeskMate UI library)
;    - Loaded via INT E0h AX=0206h with name at DS:0x146E ("PRGUF")
;    - Called through far pointer at DS:0x146A
;    - Provides all DeskMate UI services: windows, menus, dialogs, text,
;      cursor control, event handling, file I/O, and graphics primitives
;
; The dispatch mechanism uses far call pointers stored at fixed DS offsets.
; Stubs return 0xFFFF before any resource is loaded.
;
; ========================================================================
; DMGUF DISPATCH TABLE (DeskMate General User Functions)
; ========================================================================
;
; The block of 6-byte thunks at 0xCEA5-0xCF2E are DMGUF function
; wrappers. Each sets AX to a function code (0x80-0x96 format) and
; jumps to the generic DMGUF dispatcher at sub_0CF2F. The function
; codes are indices into DMGUF.RES's internal dispatch table.
;
; These provide DeskMate-specific services for: resource loading,
; session management, network protocol handling, and display formatting.
;
; ========================================================================
; PRGUF DISPATCH TABLE (Program User Functions)
; ========================================================================
;
; The large block of 6-byte thunks at 0xD29C-0xD3C8 are PRGUF function
; wrappers. Each sets AX to a function code (0x20xx format) and jumps
; to the generic PRGUF dispatcher at sub_0D274. The 0x20xx code selects
; the PRGUF function to call within PRGUF.RES.
;
; PRGUF dispatch (sub_0D274) calls through the far pointer at DS:0x146A
; and handles return codes 0xFFFF and 0xFFFE as errors. Before calling,
; it invokes a pre-dispatch hook (lcall 0:0xD747); after, a post-dispatch
; hook (lcall 0:0xD776 / lcall 0:0xD7A0). These hooks manage cursor
; state and screen update bracketing.
;
; A secondary set of thunks at 0xD007-0xD0EE dispatches functions through
; the DMGUF far pointer at DS:0x1436 (primary) or DS:0x1440 (secondary),
; with function codes 0x00-0x17 plus 0xAE and 0xB0. These handle low-
; level network communication primitives.
;
; ========================================================================
; NETWORK PROTOCOL
; ========================================================================
;
; PC-Link communicates with the Quantum Computer Services network using
; a packet-based protocol. The module contains:
;
;   - Packet assembly/disassembly (sub_0D3FE, 505 bytes -- the "printf"
;     equivalent for building network command packets)
;   - Response parsing and dispatch (sub_045DF, 1840 bytes -- the main
;     response handler with a large switch on message type codes)
;   - Page rendering engine (sub_069E0 and related -- interprets page
;     description data received from the network into screen display)
;   - File transfer protocol (sub_0B515, 852 bytes -- handles file
;     download handshaking, block transfer, and local file writing)
;
; Network commands use a "command string" format assembled by sub_0D3FE,
; which formats binary data, strings, and numeric values into a protocol-
; compatible byte stream. The response parser (sub_045DF) uses numeric
; command codes to dispatch to specific handlers.
;
; ========================================================================
; PAGE/MENU NAVIGATION SYSTEM
; ========================================================================
;
; The online service presents content as a hierarchy of pages and menus.
; The navigation system manages:
;
;   - Current page/menu state (maintained in global variables)
;   - Page stack for back-navigation (linked list at DS:0xA0)
;   - Menu item selection and dispatch
;   - Page rendering from network data
;   - Scroll position tracking within pages
;   - Keyword/search navigation
;
; The page rendering engine (sub_077AB and sub_07107) interprets page
; description data containing text, menu items, graphics positioning,
; and hyperlinks. Each page has a type code that determines its layout
; and interaction model.
;
; ========================================================================
; DATA AREA MAP
; ========================================================================
;
; Address   Size    Description
; -------   ----    -----------
; 0x0094    2       Page stack sequence counter
; 0x0096    2       Page allocation counter
; 0x0098    2       Memory allocation failure flag (1=out of memory)
; 0x009A    2       Reserved
; 0x009C    2       Session state flag (0=disconnected)
; 0x009E    2       Current page pointer (head of active page)
; 0x00A0    2       Page stack top pointer (linked list head)
; 0x00D6    2       Primary display buffer pointer
; 0x00D8    2       Secondary display buffer pointer
; 0x1428    4       PROTOCOL.RES dispatch far pointer (offset:segment)
; 0x142C    var     PROTOCOL.RES resource name string
; 0x1436    4       DMGUF primary dispatch far pointer
; 0x143A    var     DMGUF primary resource name string
; 0x1440    4       DMGUF secondary dispatch far pointer
; 0x1444    var     DMGUF secondary resource name string
; 0x144A    1       Active resource variant flag (0=secondary, 1=primary)
; 0x144D    2       Saved return address (DMGUF dispatch frame)
; 0x144F    2       Saved return address (DMGUF dispatch frame)
; 0x1454    8       Resource name comparison buffer (uppercase)
; 0x146A    4       PRGUF.RES dispatch far pointer
; 0x146E    var     PRGUF.RES resource name string ("PRGUF")
; 0x1474    2       PRGUF dispatch state / last result
; 0x148F    var     Network command format strings
; 0x15C2    2       CRT: heap limit (max offset)
; 0x15C4    2       CRT: initial SP value
; 0x15C6    2       CRT: exit function pointer (dispatch at shutdown)
; 0x15C8    2       CRT: saved SP for stack check
; 0x1639    2       CRT: PSP segment (DS at entry)
; 0x163B    2       CRT: DOS version (AH=30h result)
; 0x1642    var     CRT: file handle table (per-handle flags)
; 0x1656    2       CRT: argv[0] pointer (program name)
; 0x1658    2       CRT: argv pointer
; 0x165A    2       CRT: argc (argument count)
; 0x1978    var     CRT: BSS area (zeroed at startup)
; 0x1980    4       CRT: far call vector (environment parser)
; 0x1982    2       CRT: environment parser flag
; 0x1984    4       CRT: environment data pointer
; 0x1988    4       CRT: secondary environment pointer
; 0x1A78    var     Network buffer / working storage (zeroed by BSS init)
; 0x1AB2    2       Indirect call table entry (sub_0A763 dispatch)
; 0x1AD6    2       Indirect call table entry
; 0x1B28    2       Indirect call table entry
; 0x1B30    1       Connection mode byte (3 = active session)
; 0x1E80    1       Color mode flag (from DeskMate config)
; 0x1E81    1       Video attribute byte
; 0x1E82    2       Indirect call table entry
; 0x2031    var     Network command template string "1"
; 0x2280    var     DeskMate configuration block
; 0x2281    1       Config: color scheme byte
; 0x228E    1       Config: color mode byte
; 0x228F    1       Config: video adapter byte
; 0x2382    2       Primary buffer size (from DMGUF config)
; 0x24EE    var     Network packet assembly buffer
; 0x26B0    1       Config: adapter parameter
; 0x26B6    1       Config: video mode byte
; 0x26D0    1       Config: display parameter
; 0x26D8    var     Display settings string
; 0x26FE    var     Network packet pointer table (15 entries, cleared)
; 0x2B20    2       Indirect call table entry
; 0x2B2C    2       Indirect call table entry (sub_0A763 dispatch)
; 0x2C2C    1       Color scheme copy (from config byte 0x2281)
; 0x2CAE    var     End of BSS / start of stack growth area
;
; ========================================================================
; VIDEO ADAPTER SUPPORT
; ========================================================================
;
; The data segment at 0FD6:1586 contains video adapter name strings:
;   "1000" "CGA" "DDGA" "EGA" "HERC" "PLANT" "C16" "TC40"
;   "VGA" "MCGA" "LREST" "25TC" "T40H"
;
; These correspond to the DeskMate video driver modules (DMVE*.RES)
; and are used to select the appropriate display rendering mode.
; The adapter byte at DS:0x228F is compared against this table.
;
; ========================================================================
; STRING TABLE (embedded in data segment)
; ========================================================================
;
; The data segment contains numerous string constants used for:
;   - UI labels: "Select to download menu", "Select to download"
;   - Error messages: "Insufficient Memory to continue",
;     "File exists.  Overwrite ?", "Account Reset Failed",
;     "Accessory load failed", "Error reinitializing EVENT handlers"
;   - Dialog titles: "About", "Version", "Resources", "CANCEL"
;   - Format strings: "%02x.%02x", "%sDB0%d.PCL", "%sdb0%d.pcl"
;   - Network commands: "Enter Network Commands"
;   - Menu items: "PC-Link", "PC_LINK.PDM"
;   - Copyright: "Copyright 1988-1990",
;     "Quantum Computer Services, Inc."
;   - Status messages: "R3000\r\n- stack overflow\r\n",
;     "R3003\r\n- integer divide by 0\r\n",
;     "R3009\r\n- not enough space for environment\r\n"
;   - Modem strings: "I can't find your modem. Do you want to
;     check your modem and try again?"
;   - Configuration: "PCLINK MODEM", "SEARCH", "MANUAL DIAL"
;   - Resource names: "PROTOCOL", "PRGUF", "DMGUF", "DMCSR",
;     "DMSPELL", "RES"
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Page/Menu Management System (Segment 0000) ---
;
; Address   Name                            Size   Description
; -------   ----                            ----   -----------
; 0000:0010 pclink_unpackColor              40     Unpack 3-byte color into AX:DX (DWORD)
; 0000:0038 pclink_allocPageNode            203    Allocate and initialize a page node (0x2A bytes)
; 0000:0103 pclink_createPageEntry          58     Create page entry with type byte + link to stack
; 0000:013D pclink_destroyPageStack         293    Destroy all nodes in the page stack (free memory)
; 0000:0262 pclink_destroySubPage           43     Destroy a sub-page by temporarily swapping stack top
; 0000:028D pclink_getPageNodeByIndex       218    Get Nth child node from a page's linked list
; 0000:0367 pclink_findNodeByPosition       51     Find node at given position in linked list
;
; --- Main Application Dispatcher ---
;
; 0000:039A pclink_mainDispatch             622    Main message dispatcher (switch on message codes)
;                                                   0x2441 = init video mode
;                                                   0x2442 = process event loop iteration
;                                                   0x2459 = shutdown cleanup
;                                                   0x245A = full shutdown (destroy all pages)
;                                                   0x4466 = 'Df' open/create session
;                                                   0x444B = 'DK' keyboard event
;                                                   0x454B = 'EK' extended keyboard event
;                                                   0x4553 = 'ES' session event
;                                                   0x4D4B = 'MK' menu keyboard event
;                                                   0x4D53 = 'MS' menu selection event
;                                                   0x4F44 = 'OD' open document
;                                                   0x5A4B = 'ZK' close/exit event
;                                                   0x694B = 'iK' input keyboard event
; 0000:0608 pclink_handleOpenDocument       41     Handle 'OD' (Open Document) message
; 0000:0631 pclink_handleMenuSelection      210    Handle 'MS' (Menu Selection) -- parse path string
; 0000:0703 pclink_handleSessionEvent       51     Handle 'ES' (Session Event) -- update connection
; 0000:0736 pclink_setMenuItemValue         96     Set a menu item's value in the current menu bar
; 0000:0796 pclink_handleExtKeyEvent        157    Handle 'EK' (Extended Keyboard) event
;
; --- Session Management ---
;
; 0000:0833 pclink_openSession              233    Open a new PC-Link session (init + connect)
; 0000:091C pclink_checkSessionAlive        88     Check if session is alive (heartbeat)
; 0000:0974 pclink_checkSessionTimeout      81     Check for session timeout condition
; 0000:09C5 pclink_processNetworkEvent      845    Main network event processor (receive + dispatch)
;                                                   Handles incoming data, timeout, menu events,
;                                                   page navigation, and state transitions
; 0000:0D12 pclink_allocNetworkBuffer       113    Allocate a network communication buffer
; 0000:0D83 pclink_initNetworkState         199    Initialize network state (buffers + flags)
; 0000:0E4A pclink_handleDisconnect         170    Handle disconnection event (cleanup + UI update)
; 0000:0EF4 pclink_handleReconnect          145    Handle reconnection attempt
; 0000:0F85 pclink_handleSessionError       194    Handle session error (display error + cleanup)
;
; --- Data Node Operations ---
;
; 0000:1047 pclink_getNodeType1             66     Get node type code (variant 1)
; 0000:1089 pclink_getNodeType2             66     Get node type code (variant 2)
; 0000:10CB pclink_traverseNodeTree         105    Recursively traverse node tree
; 0000:1134 pclink_refreshPageDisplay       112    Refresh current page display
;
; --- UI Event Handling ---
;
; 0000:11A4 pclink_handleMenuBarEvent       195    Handle menu bar event (dispatch to submenu)
; 0000:1267 pclink_callNetworkCommand       16     Call network command dispatcher
; 0000:1277 pclink_handleSubMenuItem        119    Handle sub-menu item selection
; 0000:12EE pclink_checkMenuState           20     Check menu enable/disable state
; 0000:1302 pclink_getMenuItemCount         32     Get number of items in current menu
; 0000:1322 pclink_getActiveMenuItem        27     Get currently active/highlighted menu item
; 0000:133D pclink_handleMenuAction         50     Handle a specific menu action (dispatch)
;
; --- Page Navigation ---
;
; 0000:136F pclink_navigateToPage           248    Navigate to a new page (push current, load new)
; 0000:1467 pclink_clearPageBuffer          51     Clear the page display buffer
; 0000:149A pclink_renderCurrentPage        162    Render the current page to the display
; 0000:153C pclink_exitAndCleanup           89     Exit current mode and cleanup resources
; 0000:1595 pclink_validateSession          23     Validate that session is still connected
; 0000:15AC pclink_allocSessionBuffer       123    Allocate buffer for session data
; 0000:1627 pclink_getConnectionState       26     Get current connection state byte
; 0000:1641 pclink_sendDisconnectCmd        72     Send disconnect command to server
; 0000:1689 pclink_handleBackNavigation     63     Handle "go back" navigation (pop page stack)
; 0000:16C8 pclink_handleKeywordSearch      113    Handle keyword/search navigation
; 0000:1739 pclink_processNavigation        382    Process navigation request (connect + load page)
; 0000:18B7 pclink_sendNavigationCmd        158    Send navigation command to server
;
; --- Dialog and Form Handling ---
;
; 0000:1955 pclink_showInputDialog          648    Show input dialog (multi-field form entry)
; 0000:1BDD pclink_displayFormField         188    Display one form field in a dialog
; 0000:1C99 pclink_handleFormKeyEvent       163    Handle keyboard event within a form dialog
; 0000:1D3C pclink_validateFormInput        146    Validate form input before submission
; 0000:1DCE pclink_submitFormData           166    Submit form data to server
; 0000:1E74 pclink_cancelFormEntry          89     Cancel form entry (discard input)
; 0000:1ECD pclink_showErrorMessage         224    Show error message dialog
; 0000:1FAD pclink_showConfirmDialog        189    Show confirmation dialog (Yes/No)
; 0000:206A pclink_handleDialogResult       97     Handle dialog result (OK/Cancel dispatch)
; 0000:20CB pclink_allocDialogBuffer        113    Allocate buffer for dialog data
;
; --- Window/Display Management ---
;
; 0000:213C pclink_setupWindow              287    Set up a display window (create + configure)
; 0000:225B pclink_getWindowMetrics         106    Get window dimensions and position
; 0000:22C5 pclink_saveWindowState          40     Save current window state
; 0000:22ED pclink_handleWindowResize       94     Handle window resize event
; 0000:234B pclink_updateStatusBar          142    Update the status bar display
; 0000:23D9 pclink_handleWindowClose        95     Handle window close event
; 0000:2438 pclink_restoreDisplay           104    Restore display after dialog/overlay
; 0000:24A0 pclink_getDisplayMode           20     Get current display mode code
; 0000:24B4 pclink_switchDisplayMode        88     Switch between display modes
; 0000:250C pclink_showPageTitle            69     Show page title in title bar
; 0000:2551 pclink_updatePageDisplay        103    Update page display (render + refresh)
; 0000:25B8 pclink_getColorAttribute        32     Get color attribute for current mode
; 0000:25D8 pclink_setDisplayColors         114    Set display color attributes (3 regions)
;
; --- Network Communication ---
;
; 0000:264A pclink_initNetworkModule        104    Initialize network module (load resources)
; 0000:26B2 pclink_sendCommand              137    Send a command string to the server
; 0000:273B pclink_sendRawData              27     Send raw data bytes to server
; 0000:2756 pclink_sendAndWait              99     Send command and wait for response
; 0000:27B9 pclink_handleServerResponse     52     Handle a server response packet
; 0000:27ED pclink_processIncomingData      97     Process incoming data from serial port
; 0000:284E pclink_dispatchNetworkCmd       116    Dispatch received network command by code
;
; --- Modem/Connection Control ---
;
; 0000:28C2 pclink_modemDialSequence        376    Execute modem dial sequence (init + dial + wait)
; 0000:2A3A pclink_handleDialError          255    Handle dial error (retry/abort dialog)
; 0000:2B39 pclink_retryConnection          56     Retry connection after failure
; 0000:2B71 pclink_getModemStatus           55     Get current modem status flags
;
; --- Session Protocol Layer ---
;
; 0000:2BA8 pclink_processServerPacket      128    Process a server data packet
; 0000:2C28 pclink_closeConnection          27     Close the network connection
; 0000:2C43 pclink_cleanupConnection        36     Cleanup connection state + free resources
; 0000:2C67 pclink_sendSessionCmd           107    Send a session-level command
; 0000:2CD2 pclink_handleLoginSequence      226    Handle login/authentication sequence
; 0000:2DB4 pclink_handleLoginResponse      270    Handle login response from server
; 0000:2EC2 pclink_processPageData          460    Process page data received from server
; 0000:308E pclink_processMenuData          381    Process menu data for current page
; 0000:320B pclink_processContentBlock      369    Process content block (text/graphics)
; 0000:337C pclink_processInfoBlock         132    Process information block
; 0000:3400 pclink_processStatusUpdate      98     Process status update message
; 0000:3462 pclink_processFileListData      91     Process file listing data
; 0000:34BD pclink_processAccountInfo       97     Process account information block
; 0000:351E pclink_processSearchResults     373    Process search/keyword results
; 0000:3693 pclink_processEmailData         329    Process email message data
; 0000:37DC pclink_processDownloadData      203    Process file download data
; 0000:38A7 pclink_processChatData          263    Process chat room data
; 0000:39AE pclink_updateTimestamp          77     Update timestamp display
; 0000:39FB pclink_handleServerNotice       177    Handle server notice/broadcast message
; 0000:3AAC pclink_renderPageContent        179    Render page content to display buffer
; 0000:3B5F pclink_appendToDisplay          60     Append text to display buffer
; 0000:3B9B pclink_insertDisplayLine        137    Insert a line into display at position
; 0000:3C24 pclink_formatDisplayLine        131    Format a display line with attributes
; 0000:3CA7 pclink_flushDisplayBuffer       399    Flush pending display updates to screen
;
; --- Display Formatting ---
;
; 0000:3E36 pclink_getTextWidth             29     Get text width in current font
; 0000:3E53 pclink_updateCursorDisplay      49     Update cursor position display
; 0000:3E84 pclink_handleFileTransfer       169    Handle file transfer initiation
; 0000:3F2D pclink_startDownload            35     Start file download sequence
; 0000:3F50 pclink_processDownloadBlock     143    Process one download data block
; 0000:3FDF pclink_cleanupTransfer          15     Cleanup after file transfer
;
; --- Event Loop and Processing ---
;
; 0000:3FEE pclink_processEventQueue        309    Process the event queue (main loop body)
; 0000:4123 pclink_processTimerEvent        135    Process timer event (keepalive/timeout)
; 0000:41AA pclink_processKeyEvent          399    Process keyboard event during session
; 0000:4339 pclink_processSpecialKey        204    Process special key (function keys, etc.)
; 0000:4405 pclink_sendKeystroke            66     Send keystroke to server
; 0000:4447 pclink_handleEscapeKey          50     Handle Escape key press
; 0000:4479 pclink_handleFunctionKeys       170    Handle function key presses (F1-F10)
; 0000:4523 pclink_handleHelpKey            105    Handle Help key (F1)
; 0000:458C pclink_setDisplayMode           83     Set display mode for current page type
;
; --- Main Response Handler ---
;
; 0000:45DF pclink_mainResponseHandler      1840   Main server response handler (large switch)
;                                                   Dispatches on response type code to:
;                                                   - Page content handlers
;                                                   - Menu data handlers
;                                                   - File transfer handlers
;                                                   - Chat/email handlers
;                                                   - Account/billing handlers
;                                                   - Error/status handlers
;
; --- File Management ---
;
; 0000:4D0F pclink_initFileManager          52     Initialize file management subsystem
; 0000:4D43 pclink_setupFileDialog          148    Set up file selection dialog
; 0000:4DD7 pclink_openFileForDownload      83     Open a local file for download writing
; 0000:4E2A pclink_writeDownloadData        216    Write downloaded data to local file
; 0000:4F02 pclink_closeDownloadFile        50     Close download file
; 0000:4F34 pclink_selectDownloadDir        125    Select download directory
; 0000:4FB1 pclink_displayDirectoryList     307    Display directory listing
; 0000:50E4 pclink_getDirectoryInfo         39     Get directory information
; 0000:510B pclink_refreshFileList          92     Refresh file list display
; 0000:5167 pclink_updateDialogField        17     Update a dialog field value
; 0000:5178 pclink_showFileInfo             78     Show file information dialog
; 0000:51C6 pclink_startFileTransfer        26     Start a file transfer operation
; 0000:51E0 pclink_fileTransferMain         772    File transfer main loop
;
; --- Serial Port Interface ---
;
; 0000:54E4 pclink_serialPortInit           512    Initialize serial port (5 config params)
; 0000:56E4 pclink_serialPortStatus         88     Get serial port status
; 0000:573C pclink_serialPortConfig         106    Configure serial port parameters
; 0000:57A6 pclink_serialPortOpen           178    Open serial port for communication
; 0000:5858 pclink_serialPortWrite          361    Write data to serial port
; 0000:59C1 pclink_getPortHandle            115    Get serial port file handle
; 0000:5A34 pclink_getPortConfig            115    Get serial port configuration
; 0000:5AA7 pclink_sendModemCommand         381    Send AT command to modem
; 0000:5C24 pclink_waitForModemResponse     91     Wait for modem response
; 0000:5C7F pclink_processModemResponse     366    Process modem response string
; 0000:5DED pclink_dialPhoneNumber          522    Dial phone number via modem
; 0000:5FF7 pclink_hangupModem              77     Hang up modem (drop DTR)
; 0000:6044 pclink_getCarrierState          104    Get carrier detect state
; 0000:60AC pclink_checkModemReady          69     Check if modem is ready
; 0000:60F1 pclink_configureModem           124    Configure modem parameters
;
; --- Resource Module Interface ---
;
; 0000:616D pclink_initResources            43     Initialize resource modules (load DMGUF+PRGUF)
; 0000:6198 pclink_configureSession         242    Configure session parameters (9 DMGUF calls)
; 0000:628A pclink_setupProtocol            239    Set up protocol layer (PROTOCOL.RES)
; 0000:6379 pclink_getProtocolVersion       21     Get protocol version info
; 0000:638E pclink_getModuleHandle          8      Get current module handle
; 0000:6396 pclink_enableMenuItems          23     Enable/disable menu items
; 0000:63AD pclink_setWindowTitle           22     Set window title string
; 0000:63C3 pclink_initDisplay              181    Initialize display (video mode + colors)
; 0000:6478 pclink_setupDisplayBuffer       64     Set up display buffer (allocate + init)
; 0000:64B8 pclink_loadAccessoryFile        216    Load accessory/config file
;
; --- Screen Rendering Engine ---
;
; 0000:6590 pclink_nop                      6      No-operation stub
; 0000:6596 pclink_clearStatusLine          33     Clear the status line display
; 0000:65B7 pclink_renderTextPage           452    Render a text-mode page to display
; 0000:677B pclink_renderPageSection        172    Render one section of a page
; 0000:6827 pclink_renderFormattedText      161    Render formatted text with attributes
; 0000:68C8 pclink_setupPageWindow          280    Set up window for page display
; 0000:69E0 pclink_renderMenuPage           338    Render a menu-type page
; 0000:6B32 pclink_renderSimpleMenu         93     Render simple menu (no graphics)
; 0000:6B8F pclink_renderDetailMenu         301    Render detailed menu with descriptions
; 0000:6CBC pclink_renderCompactMenu        135    Render compact menu display
; 0000:6D43 pclink_renderPageHeader         964    Render page header and title area
;
; --- Page Layout and Graphics ---
;
; 0000:7107 pclink_layoutPage               379    Calculate page layout (positions + sizes)
; 0000:7282 pclink_drawMenuItem             166    Draw a single menu item (text + highlight)
; 0000:7328 pclink_drawMenuList             306    Draw list of menu items
; 0000:745A pclink_drawMenuSeparator        31     Draw menu separator line
; 0000:7479 pclink_drawMenuItemLine         232    Draw one menu item line with formatting
; 0000:7561 pclink_formatMenuText           212    Format menu text with truncation/padding
; 0000:7635 pclink_drawPageBorder           240    Draw page border and frame
; 0000:7725 pclink_getPageWidth             87     Get page width in characters
; 0000:777C pclink_getPageHeight            47     Get page height in lines
; 0000:77AB pclink_renderPageBody           803    Render page body content (text + graphics)
; 0000:7ACE pclink_renderScrollableArea     254    Render scrollable text area
; 0000:7BCC pclink_checkVideoAdapter        15     Check current video adapter type
; 0000:7BDB pclink_adjustForAdapter         83     Adjust layout for video adapter capabilities
; 0000:7C2E pclink_getMenuItemCount2        60     Get menu item count (alternate)
; 0000:7C6A pclink_scrollUp                 31     Scroll display up one line
; 0000:7C89 pclink_scrollDown               32     Scroll display down one line
; 0000:7CA9 pclink_handleScrollEvent        272    Handle scroll event (up/down/page)
; 0000:7DB9 pclink_drawScrollBar            256    Draw scroll bar indicator
; 0000:7EB9 pclink_updateScrollPosition     148    Update scroll position after navigation
; 0000:7F4D pclink_handlePageUp             130    Handle Page Up key
; 0000:7FCF pclink_handlePageDown           110    Handle Page Down key
; 0000:803D pclink_handleHomeEnd            161    Handle Home/End key
; 0000:80DE pclink_handleArrowKey           55     Handle arrow key navigation
;
; --- Selection and Input ---
;
; 0000:8115 pclink_getSelectionIndex        52     Get current selection index
; 0000:8149 pclink_setSelectionIndex        83     Set current selection index
; 0000:819C pclink_highlightSelection       66     Highlight/unhighlight a menu selection
; 0000:81DE pclink_moveSelection            170    Move selection up/down
; 0000:8288 pclink_handleSelectionEnter     216    Handle Enter key on current selection
; 0000:8360 pclink_handleSelectionAction    415    Handle action on selected item
; 0000:84FF pclink_getSelectedItemInfo      197    Get information about selected item
; 0000:85C4 pclink_isItemSelectable         32     Check if an item is selectable
; 0000:85E4 pclink_activateSelectedItem     138    Activate the selected menu item
; 0000:866E pclink_deactivateSelection      100    Deactivate current selection (unhighlight)
; 0000:86D2 pclink_refreshSelectionArea     106    Refresh the selection display area
; 0000:873C pclink_updateSelectionUI        76     Update selection UI elements
;
; --- Chat/Email Module ---
;
; 0000:8788 pclink_chatEmailDispatch        190    Chat/email function dispatcher
; 0000:8846 pclink_initChatMode             63     Initialize chat mode
; 0000:8885 pclink_getChatInputBuffer       95     Get chat input buffer
; 0000:88E4 pclink_displayChatMessage       167    Display incoming chat message
; 0000:898B pclink_handleChatInput          35     Handle chat input event
; 0000:89AE pclink_processChatCommand       391    Process chat command/message
; 0000:8B35 pclink_sendChatMessage          151    Send chat message to server
; 0000:8BCC pclink_handleEmailView          349    Handle email message viewing
; 0000:8D29 pclink_handleEmailCompose       381    Handle email composition
; 0000:8EA6 pclink_processEmailCommand      313    Process email command
; 0000:8FDF pclink_handleEmailAction        142    Handle email action (send/reply/forward)
; 0000:906D pclink_formatEmailHeader        132    Format email header for display
; 0000:90F1 pclink_formatEmailField         54     Format one email header field
; 0000:9127 pclink_formatFieldValue         110    Format a field value with truncation
; 0000:9195 pclink_renderEmailBody          101    Render email body text
; 0000:91FA pclink_cleanupEmailState        91     Cleanup email state after close
;
; --- Account/Billing ---
;
; 0000:9255 pclink_displayAccountInfo       68     Display account information
; 0000:9299 pclink_handleAccountAction      95     Handle account action (reset, etc.)
; 0000:92F8 pclink_processAccountData       161    Process account data from server
; 0000:9399 pclink_displayBillingInfo       38     Display billing information
; 0000:93BF pclink_processResetAccount      59     Process account reset sequence
; 0000:93FA pclink_updateAccountDisplay     26     Update account info display
; 0000:9414 pclink_handleAccountError       62     Handle account operation error
; 0000:9452 pclink_formatAccountData        320    Format account data for display
;
; --- Connection Setup ---
;
; 0000:9592 pclink_setupConnection          144    Set up connection (modem + login)
; 0000:9622 pclink_queryServerStatus        59     Query server status
; 0000:965D pclink_reconnectServer          41     Reconnect to server
; 0000:9686 pclink_setConnectionFlag        29     Set a connection state flag
; 0000:96A3 pclink_allocConnectionBuffer    47     Allocate connection data buffer
; 0000:96D2 pclink_initConnectionParams     88     Initialize connection parameters
;
; --- Configuration / Settings ---
;
; 0000:972A pclink_loadConfiguration        489    Load configuration from file/defaults
; 0000:9913 pclink_saveConfiguration        102    Save configuration to file
; 0000:9979 pclink_handleSettingsMenu       54     Handle Settings menu selection
; 0000:99AF pclink_applySettings            67     Apply settings changes
; 0000:99F2 pclink_loadModemConfig          108    Load modem configuration
; 0000:9A5E pclink_validateConfig           96     Validate configuration data
; 0000:9ABE pclink_parseConfigFile          321    Parse configuration file
;
; --- Low-Level I/O Helpers ---
;
; 0000:9BFF pclink_readByte                 45     Read one byte from buffer
; 0000:9C2C pclink_copyString               29     Copy a string (near pointer)
; 0000:9C49 pclink_readWord                 54     Read one word (16-bit) from buffer
; 0000:9C7F pclink_peekByte                 40     Peek at next byte without consuming
; 0000:9CA7 pclink_skipBytes                26     Skip N bytes in buffer
; 0000:9CC1 pclink_compareMem               58     Compare memory blocks
; 0000:9CFB pclink_getBiosEquipment         16     Get BIOS equipment list (INT 11h)
; 0000:9D0B pclink_initTimerTicks           100    Initialize timer tick counter (INT 1Ah)
; 0000:9D6F pclink_disableInterrupts        4      CLI (disable interrupts)
; 0000:9D73 pclink_enableInterrupts         4      STI (enable interrupts)
; 0000:9D77 pclink_sendSerialBIOS           13     Send byte via BIOS INT 14h
; 0000:9D84 pclink_getTimerTicks            66     Get timer ticks (INT 1Ah, 3 variants)
; 0000:9DC6 pclink_getConventionalMemory    21     Get conventional memory size (INT 12h)
; 0000:9DDB pclink_checkDosVersion          37     Check DOS version (INT 21h AH=30h)
;
; --- File I/O Layer ---
;
; 0000:9E00 pclink_fileOperations           716    File operations dispatcher (open/read/write/seek)
; 0000:A0CC pclink_handleFileError          156    Handle file I/O error
; 0000:A168 pclink_main                     1005   _main() -- C entry point, init + event loop
;                                                   Parses argc/argv, loads config, connects,
;                                                   runs main event loop, cleanup on exit
; 0000:A555 pclink_initApplication          135    Initialize application (load resources + config)
; 0000:A5DC pclink_checkMemoryAvail         48     Check available memory
; 0000:A60C pclink_loadDatabaseFile         284    Load database file (config/address data)
; 0000:A728 pclink_checkDatabaseFormat      59     Check database file format
; 0000:A763 pclink_indirectDispatch         138    Indirect function dispatch via table
;                                                   Uses [0x1AB2], [0x1AD6], [0x1B28],
;                                                   [0x1E82], [0x2B20], [0x2B2C]
; 0000:A7ED pclink_restoreInterrupts        11     Restore interrupt vectors (exit cleanup)
; 0000:A7F8 pclink_shutdownCleanup          523    Shutdown cleanup (close files, free memory)
;
; --- String/Buffer Utilities ---
;
; 0000:AA03 pclink_clearBuffer              93     Clear a buffer (fill with zeros)
; 0000:AA60 pclink_setStringField           43     Set a string field in a record
; 0000:AA8B pclink_selectFieldHandler       13     Select field handler by type
; 0000:AA98 pclink_updateFieldDisplay       146    Update a field's display
; 0000:AB2A pclink_resetFieldState          45     Reset field state to defaults
; 0000:AB57 pclink_handleFieldInput         55     Handle input into a field
; 0000:AB8E pclink_fieldHandler1            9      Field handler type 1 entry
; 0000:AB97 pclink_fieldHandler2            9      Field handler type 2 entry
; 0000:ABA0 pclink_fieldHandler3            9      Field handler type 3 entry
; 0000:ABA9 pclink_fieldHandler4            9      Field handler type 4 entry
; 0000:ABB2 pclink_fieldHandler5            9      Field handler type 5 entry
; 0000:ABBB pclink_fieldHandler6            9      Field handler type 6 entry
; 0000:ABC4 pclink_getFieldBuffer           6      Get pointer to field buffer
; 0000:ABCA pclink_fieldHandler7            9      Field handler type 7 entry
; 0000:ABD3 pclink_fieldHandler8            9      Field handler type 8 entry
; 0000:ABDC pclink_fieldHandler9            9      Field handler type 9 entry
; 0000:ABE5 pclink_fieldHandler10           9      Field handler type 10 entry
; 0000:ABEE pclink_fieldHandler11           9      Field handler type 11 entry
; 0000:ABF7 pclink_fieldDispatcher          12     Field type dispatcher (type -> handler)
; 0000:AC03 pclink_fieldTypeA               73     Field type A operations
; 0000:AC4C pclink_fieldTypeB               73     Field type B operations
; 0000:AC95 pclink_fieldTypeC               73     Field type C operations
; 0000:ACDE pclink_fieldTypeD               73     Field type D operations
;
; --- Address/Pointer Helpers ---
;
; 0000:AD27 pclink_getPtr1                  15     Get pointer from table slot 1
; 0000:AD36 pclink_getPtr2                  15     Get pointer from table slot 2
; 0000:AD45 pclink_getPtr3                  15     Get pointer from table slot 3
; 0000:AD54 pclink_getPtr4                  15     Get pointer from table slot 4
; 0000:AD63 pclink_getPtr5                  16     Get pointer from table slot 5
; 0000:AD73 pclink_getPtr6                  15     Get pointer from table slot 6
; 0000:AD82 pclink_initVideoMode            62     Initialize video mode (adapter detect)
; 0000:ADC0 pclink_loadAccessory            67     Load a desk accessory module
; 0000:AE03 pclink_loadAccessoryByName      97     Load accessory by name string
; 0000:AE64 pclink_aboutDialog              463    Show "About PC-Link" dialog
;
; --- Download Manager ---
;
; 0000:B033 pclink_getDownloadPath          49     Get download directory path
; 0000:B064 pclink_getDownloadName          45     Get download file name
; 0000:B091 pclink_getDownloadStatus        35     Get download status code
; 0000:B0B4 pclink_getDownloadSize          36     Get download file size
; 0000:B0D8 pclink_downloadManager          908    Download file manager (main loop)
;                                                   Handles directory selection, file
;                                                   selection, transfer, and completion
; 0000:B464 pclink_formatFileSize           177    Format file size for display
; 0000:B515 pclink_transferProtocol         852    File transfer protocol handler
;                                                   Block-level transfer with handshaking,
;                                                   error detection, and retry logic
; 0000:B869 pclink_processTransferBlock     273    Process one transfer block
; 0000:B97A pclink_updateFileRecord         282    Update file record in database
; 0000:BA94 pclink_deleteFileRecord         52     Delete a file record
; 0000:BAC8 pclink_fileRecordManager        729    File record management (CRUD operations)
;
; --- Memory Management ---
;
; 0000:BDA1 pclink_allocMemory              17     Allocate memory block
; 0000:BDB2 pclink_handleMemoryError        160    Handle memory allocation error
; 0000:BE52 pclink_memoryOperations         285    Memory block operations (alloc/free/resize)
; 0000:BF6F pclink_freeMemory               70     Free a memory block
; 0000:BFB5 pclink_getMemoryInfo            54     Get memory block information
; 0000:BFEB pclink_memoryBlockOps           304    Low-level memory block operations
;
; --- Display Primitives ---
;
; 0000:C11B pclink_drawTextBlock            572    Draw a block of text with attributes
; 0000:C357 pclink_drawFormattedText        659    Draw formatted text (rich text rendering)
; 0000:C5EA pclink_getCharAttribute         111    Get character and attribute at position
; 0000:C659 pclink_writeChar                102    Write character at current position
; 0000:C6BF pclink_writeCharWithAttr        160    Write character with specific attribute
; 0000:C75F pclink_drawString               354    Draw string at position with attributes
; 0000:C8C1 pclink_textDisplayEngine        710    Text display engine (main text renderer)
;                                                   Handles word wrap, scrolling, attributes,
;                                                   line breaks, and special characters
;
; --- Buffer Management ---
;
; 0000:CB87 pclink_getBufferSize            65     Get current buffer size
; 0000:CBC8 pclink_getBufferCapacity        65     Get buffer capacity
; 0000:CC09 pclink_getBufferFree            45     Get free space in buffer
; 0000:CC36 pclink_getBufferUsed            40     Get used space in buffer
; 0000:CC5E pclink_getBufferPointer         46     Get pointer to buffer data
; 0000:CC8C pclink_parseControlCode         131    Parse control code in data stream
;
; --- Number/String Formatting ---
;
; 0000:CD0F pclink_formatDecimal            226    Format number as decimal string
; 0000:CDF1 pclink_formatDecimalHelper      58     Helper for decimal formatting
; 0000:CE2B pclink_appendDigit              34     Append digit to format buffer
; 0000:CE4D pclink_divideBy10               31     Divide value by 10 (for digit extraction)
;
; --- DMGUF Dispatch Thunks (DeskMate General User Functions) ---
;
; Each thunk sets AX to a function code (0x80-0x96) and jumps to
; dmguf_dispatch (sub_0CF2F). These provide network-level services.
;
; 0000:CE6C pclink_loadProtocolRes          27     Load PROTOCOL.RES (INT E0h AX=0206h)
; 0000:CE87 pclink_unloadProtocolRes        30     Unload PROTOCOL.RES (INT E0h AX=0207h)
; 0000:CEA5 dmguf_func80                    6      DMGUF func 0x80 - General dispatch
; 0000:CEAB dmguf_func81                    6      DMGUF func 0x81
; 0000:CEB1 dmguf_func82                    12     DMGUF func 0x82
; 0000:CEBD dmguf_func84                    12     DMGUF func 0x84
; 0000:CEC9 dmguf_func86                    6      DMGUF func 0x86
; 0000:CECF dmguf_func87                    6      DMGUF func 0x87
; 0000:CED5 dmguf_func88                    6      DMGUF func 0x88
; 0000:CEDB dmguf_func89                    18     DMGUF func 0x89 (with 0x8A, 0x8B)
; 0000:CEED dmguf_func8C                    6      DMGUF func 0x8C
; 0000:CEF3 dmguf_func8D                    6      DMGUF func 0x8D
; 0000:CEF9 dmguf_func8E                    6      DMGUF func 0x8E
; 0000:CEFF dmguf_func8F                    6      DMGUF func 0x8F
; 0000:CF05 dmguf_func90                    6      DMGUF func 0x90
; 0000:CF0B dmguf_func91                    24     DMGUF func 0x91 (with 0x92, 0x93, 0x94)
; 0000:CF23 dmguf_func95                    6      DMGUF func 0x95
; 0000:CF29 dmguf_func96                    6      DMGUF func 0x96
; 0000:CF2F dmguf_dispatch                  12     DMGUF generic dispatch (far call to [0x1428])
;
; --- Resource Loading (DMGUF + PRGUF combined) ---
;
; 0000:CF3B pclink_loadDmgufModule          60     Load DMGUF resource via INT E0h AX=0208h+0206h
; 0000:CF77 pclink_unloadDmgufModule        279    Unload DMGUF resource (primary or secondary)
;                                                   Also loads secondary via INT E0h AX=0206h
;                                                   at 0xCF9D-0xCFFE (inline alternate path)
;
; --- PRGUF Low-Level Dispatch ---
;
; Thunks at 0xD007-0xD0EE dispatch through DMGUF far pointer [0x1436]
; (primary) or [0x1440] (secondary). Function codes 0x00-0x17, 0xAE, 0xB0:
;
; 0000:D007 dmguf_netDispatch               59     Network dispatch entry (primary/[0x1436])
; 0000:D04B dmguf_altNetDispatch            61     Alternate network dispatch (secondary/[0x1440])
; 0000:D08E dmguf_netFunc01                 12     Net func 0x01 (send byte)
; 0000:D09A dmguf_netFunc04                 6      Net func 0x04 (receive data)
; 0000:D0A0 dmguf_netFunc05                 6      Net func 0x05 (check status)
; 0000:D0A6 dmguf_netFunc06                 6      Net func 0x06 (configure port)
; 0000:D0AC dmguf_netFunc07                 18     Net func 0x07 (flow control) + 0x08, 0x11
; 0000:D0BE dmguf_netFunc12                 6      Net func 0x12 (get config)
; 0000:D0C4 dmguf_netFunc13                 6      Net func 0x13 (set config)
; 0000:D0CA dmguf_netFunc14                 18     Net func 0x14 (carrier detect) + 0x15, 0x16
; 0000:D0DC dmguf_netFunc17                 18     Net func 0x17 (disconnect) + 0xAE, 0xB0
;
; --- DM89 Module Entry and Services ---
;
; 0000:D0EE pclink_moduleEntryDispatch      104    Module entry point dispatcher (DM89 format)
;                                                   Routes to PRGUF/DMGUF load by resource name
; 0000:D156 pclink_parseResourceName        208    Parse resource name from command string
; 0000:D226 pclink_getDeskMateConfig        24     Get DeskMate configuration block
; 0000:D23E pclink_loadPrgufModule          25     Load PRGUF.RES (INT E0h AX=0206h)
; 0000:D257 pclink_unloadPrgufModule        15     Unload PRGUF.RES (INT E0h AX=0207h)
; 0000:D266 pclink_initPrgufAndDmguf        7      Initialize both PRGUF and DMGUF
; 0000:D26D pclink_cleanupPrgufAndDmguf     7      Cleanup both DMGUF and PRGUF
;
; --- PRGUF Dispatch Thunks (Program User Functions) ---
;
; Each thunk sets AX = 0x20xx and jumps to prguf_dispatch (sub_0D274).
; The 0x20xx code selects the PRGUF function to call.
;
; 0000:D274 prguf_dispatch                  40     PRGUF generic dispatch (far call via [0x146A])
;                                                   with pre/post hooks at 0xD747/0xD776/0xD7A0
; 0000:D29C prguf_openFile                  6      PRGUF func 0x2004 - Open file
; 0000:D2A2 prguf_endUpdate                 6      PRGUF func 0x2006 - End screen update
; 0000:D2A8 prguf_beginUpdate               6      PRGUF func 0x2007 - Begin screen update
; 0000:D2AE prguf_writeFile                 6      PRGUF func 0x2014 - Write to file
; 0000:D2B4 prguf_readFile                  6      PRGUF func 0x2016 - Read from file
; 0000:D2BA prguf_setTimer                  6      PRGUF func 0x2017 - Set timer
; 0000:D2C0 prguf_showMenuBar               6      PRGUF func 0x2018 - Show menu bar
; 0000:D2C6 prguf_getEvent                  6      PRGUF func 0x201B - Get event from queue
; 0000:D2CC prguf_sendEvent                 6      PRGUF func 0x201C - Send event
; 0000:D2D2 prguf_showWaitCursor            6      PRGUF func 0x201D - Show wait cursor
; 0000:D2D8 prguf_hideWaitCursor            12     PRGUF func 0x201E - Hide wait cursor (+0x201F)
; 0000:D2E4 prguf_createDialog              6      PRGUF func 0x2028 - Create dialog
; 0000:D2EA prguf_setDialogField            6      PRGUF func 0x202E - Set dialog field
; 0000:D2F0 prguf_getDialogField            6      PRGUF func 0x202F - Get dialog field
; 0000:D2F6 prguf_getInputField             6      PRGUF func 0x2031 - Get input field value
; 0000:D2FC prguf_setForeColor              6      PRGUF func 0x2037 - Set foreground color
; 0000:D302 prguf_refreshScreen             6      PRGUF func 0x2039 - Refresh screen
; 0000:D308 prguf_setCursorPos              6      PRGUF func 0x2044 - Set cursor position
; 0000:D30E prguf_getCursorPos              6      PRGUF func 0x2046 - Get cursor position
; 0000:D314 prguf_showCursor                6      PRGUF func 0x2047 - Show cursor
; 0000:D31A prguf_setColor                  6      PRGUF func 0x204A - Set color pair
; 0000:D320 prguf_printString               6      PRGUF func 0x2052 - Print string
; 0000:D326 prguf_printChar                 6      PRGUF func 0x2053 - Print character
; 0000:D32C prguf_drawHLine                 6      PRGUF func 0x2055 - Draw horizontal line
; 0000:D332 prguf_drawMenuItem              6      PRGUF func 0x205F - Draw menu item
; 0000:D338 prguf_setViewport               6      PRGUF func 0x206A - Set viewport
; 0000:D33E prguf_setViewportClip           6      PRGUF func 0x206B - Set viewport clip
; 0000:D344 prguf_drawMenuItemHighlight     6      PRGUF func 0x206D - Draw menu highlight
; 0000:D34A prguf_funcAD                    6      PRGUF func 0x20AD
; 0000:D350 prguf_funcAE                    6      PRGUF func 0x20AE
; 0000:D356 prguf_funcAF                    6      PRGUF func 0x20AF
; 0000:D35C prguf_funcB0                    6      PRGUF func 0x20B0
; 0000:D362 prguf_funcB2                    6      PRGUF func 0x20B2
; 0000:D368 prguf_funcB3                    6      PRGUF func 0x20B3
; 0000:D36E prguf_funcB8                    6      PRGUF func 0x20B8
; 0000:D374 prguf_funcB9                    6      PRGUF func 0x20B9
; 0000:D37A prguf_funcBA                    6      PRGUF func 0x20BA
; 0000:D380 prguf_funcC9                    6      PRGUF func 0x20C9
; 0000:D386 prguf_funcCA                    6      PRGUF func 0x20CA
; 0000:D38C prguf_funcD5                    6      PRGUF func 0x20D5
; 0000:D392 prguf_funcDD                    6      PRGUF func 0x20DD
; 0000:D398 prguf_funcDE                    6      PRGUF func 0x20DE
; 0000:D39E prguf_funcDF                    6      PRGUF func 0x20DF
; 0000:D3A4 prguf_funcE0                    6      PRGUF func 0x20E0
; 0000:D3AA prguf_funcE3                    6      PRGUF func 0x20E3
; 0000:D3B0 prguf_funcE4                    6      PRGUF func 0x20E4
; 0000:D3B6 prguf_funcE9                    6      PRGUF func 0x20E9
; 0000:D3BC prguf_funcF3                    6      PRGUF func 0x20F3
; 0000:D3C2 prguf_funcF5                    6      PRGUF func 0x20F5
; 0000:D3C8 prguf_func2100                  6      PRGUF func 0x2100
;
; --- Timing and Delay ---
;
; 0000:D3CE prguf_delayTicks                48     Delay for N timer ticks (INT 21h AH=2Ch loop)
;
; --- Network Command Assembly ---
;
; 0000:D3FE pclink_buildCommandPacket       505    Build a network command packet
;                                                   Assembles formatted data, strings, and
;                                                   numeric values into protocol-compatible stream.
;                                                   Uses format template strings from DS:0x148F.
;
; --- String/Conversion Utilities ---
;
; 0000:D5F7 pclink_recursiveDigit           28     Recursive digit extraction (for formatting)
; 0000:D613 pclink_copyFormatString          12    Copy format string to buffer
; 0000:D61F pclink_getFormatLength          17     Get format string length
; 0000:D630 pclink_parseHexByte             102    Parse hex byte from string
; 0000:D696 pclink_parseDecimal             64     Parse decimal number from string
; 0000:D6D6 pclink_skipWhitespace           14     Skip whitespace in string
; 0000:D6E4 pclink_getChar                  6      Get next character from input
; 0000:D6EA pclink_putChar                  6      Put character to output
; 0000:D6F0 pclink_getWord                  6      Get next word (16-bit) from input
; 0000:D6F6 pclink_putWord                  6      Put word to output
; 0000:D6FC pclink_getByte                  6      Get next byte from input
; 0000:D702 pclink_putByte                  6      Put byte to output
; 0000:D708 pclink_getFlag                  6      Get flag/status byte
; 0000:D70E pclink_loadPrgufEntry           6      Load PRGUF entry point
; 0000:D714 pclink_loadDmgufEntry           6      Load DMGUF entry point
; 0000:D71A pclink_lookupResourceName       269    Look up resource name in table
; 0000:D827 pclink_callResourceFunc         42     Call a resource function by index
;
; --- DM89 Entry / CRT Startup (Segment 0FD1) ---
;
; 0000:D851 pclink_intE0hDispatch           199    INT E0h generic dispatch (AX from [bp+4])
;                                                   Pushes ES, sets ES=DS, calls INT E0h
; 0FD1:0000 (data -- DM89 header / string table)
; 0FD1:000E start                           2584   MSC 5.x CRT startup sequence:
;                                                   1. Check DOS version >= 2.0 (INT 20h exit if not)
;                                                   2. Set SS = 0FD2 (DGROUP), compute SP
;                                                   3. Resize memory block (INT 21h AH=4Ah)
;                                                   4. Save PSP segment at SS:0x1639
;                                                   5. Zero BSS (0x1A78 to 0x2CB0)
;                                                   6. Parse environment for "PC_LINK.PDM="
;                                                   7. Initialize file handle table (INT 21h AH=44h IOCTL)
;                                                   8. Save INT 00h vector, install divide-by-zero handler
;                                                   9. Parse command line into argc/argv
;                                                   10. Call pclink_main(argc, argv, envp)
;                                                   11. On return, call exit handlers
;
; --- CRT Library Functions ---
;
; 0FD1:0726 sub_10736                       96     CRT: format error message and write to stderr
; 0FD1:0786 sub_10796                       157    CRT: write string to stderr (INT 21h AH=40h)
; 0FD1:0823 sub_10833                       2612   CRT: printf/sprintf implementation
;                                                   Full printf with %d, %x, %s, %c, %02x, etc.
;                                                   Called from pclink_applySettings and elsewhere
; 0FD1:1257 sub_11267                       264    CRT: memory copy / block operations
; 0FD1:135F sub_1136F                       1064   CRT: string operations library
;                                                   strlen, strcpy, strcat, strcmp, memcpy, etc.
;
; ========================================================================
; DATA SEGMENT (Segment 0FD6) -- Notable String Constants
; ========================================================================
;
; Offset    Content
; ------    -------
; 0x0065    "Select to download menu\0"
; 0x008B    "Select to download menu\0" (second instance with item count)
; 0x00B2    "\r\0KN\0\x7f\0\x7f\0"  (menu navigation template)
; 0x00C4    "Insufficient Memory to continue\0"
; 0x00E4    (padding/null area)
; 0x00FC    "\n*?\0\\\0\\*.*\0"  (wildcard pattern for file listing)
; 0x0105    "disk ;(`)+^`{|[]<>,~\"\0"  (invalid filename characters)
; 0x011E    "File exists.  Overwrite ?\0"
; 0x0139    "*.*\0"  (wildcard)
; 0x013F    "Directory List\0" (repeated several times with "*.*")
; 0x014D    "Directory List*.*\0"
; 0x017D    "Directory List*.*\0" (with subdirectory variant)
; 0x0192    "Subdirectory List\0"
; 0x01A4    "Kk%s\0" (keyboard shortcut format)
; 0x01AA    "Reset Account Info\0"
; 0x01BC    "Account Reset Failed\0"
; 0x01D2    "Accessory load failed\0"
; 0x01E9    "Error reinitializing EVENT handlers\0"
; 0x020D    "x01\0" (hex format)
; 0x0211    "Register  \0"
; 0x021D    "0" + padding (format template)
; 0x0289    (padding area)
; 0x028F    "@@@@@\0" (field mask)
; 0x0296    "%02x.%02x\0"  (version format string)
; 0x02A1    "PC-Link\0"
; 0x02AA    "PC_LINK.PDM\0"
; 0x02B4    "Copyright 1988-1990\0"
; 0x02C8    "Quantum Computer Services, Inc.\0"
; 0x02EA    "\xFF\xFF\xFF\xFF\xFF\xFF" (sentinel)
; 0x02EF    "CANCEL\0"
; 0x1327    (menu structure data)
; 0x135B    "Enter Network Commands\0"
; 0x1373    "56666666666666666\0" (format mask)
; 0x137F    "PCLINK MODEM\0"
; 0x138B    "SEARCH\0"
; 0x1392    "I can't find your modem. Do you want to check your modem and try again?\0"
; 0x13DC    "%c:%s\0" (path format)
; 0x13E2    "\\db0?.pcl\0" (database filename pattern)
; 0x13EE    "%s%s\0"
; 0x13F2    (padding)
; 0x13F8    "%sDB0%d.PCL\0" (database filename format)
; 0x1403    "%sdb0%d.pcl\0" (lowercase variant)
; 0x140F    "db0%d.pcl\0"
; 0x1419    "%sdb0%d.pcl\0"
; 0x1425    (padding)
; 0x1433    (null + padding)
; 0x1437    "\xCD\xAB" (signature bytes)
; 0x1439    "\xBA\xDC" (signature bytes -- 0xABCD 0xDCBA markers)
; 0x143A    "PROTOCOL\0"
; 0x1444    (alternate protocol name)
; 0x1446    "\xCD\xAB\xBA\xDC" (second resource block signature)
; 0x144A    "PRGUF\0"
; 0x1452    "\xCD\xAB\xBA\xDC" (DMGUF block signature)
; 0x1455    "DMGUF\0"
; 0x1464    "DMSPELL\0"
; 0x146A    (far pointer storage)
; 0x146E    "PRGUF\0"
; 0x1473    "\0\0PRGUF\0"
; 0x147B    "\xCD\xAB\xBA\xDC" (DMCSR block signature)
; 0x147F    "DMCSR\0"
; 0x1485    "About\0"
; 0x148B    "Version \0"
; 0x1495    "Resources\0"
; 0x149E    "DESK.EXE      \0"
; 0x14AD    " CANCEL\0"
; 0x14AF    "DeskMate Copyright 1984, 1990\0"
; 0x14D4    "Tandy Corporation, All Rights Reserved\0"
; 0x14FF    (relocation data / structure offsets)
; 0x1586    "1000" "CGA" "DDGA" "EGA" "HERC" "PLANT" "C16" "TC40" (video modes)
; 0x15B9    "LREST" "25TC" "T40H\0"
; 0x15C1    (CRT runtime data area)
; 0x1909    (padding to BSS)
; 0x1947    (BSS init template -- baud rate table)
; 0x1959    "\xFF\xFF\x1E\x00\x3B\0Z\0x\0\x97..." (modem init sequence)
; 0x199B    "\xB8\xFB\x2E" "RES\0"  (resource extension)
; 0x19A4    "1988\0"  (copyright year)
; 0x19AA    "   \0"  (padding)
; 0x19AE    "<<NMSG>>\0" (network message marker)
; 0x19B8    "R3000\r\n- stack overflow\r\n\0"
; 0x19D4    "R3003\r\n- integer divide by 0\r\n\0"
; 0x19F5    "R3009\r\n- not enough space for environment\r\n\0"
; 0x1A28    "\xFF\0run-time error \0"
; 0x1A39    "\x02\0R3002\r\n- floating point not loaded\r\n\0"
; 0x1A5F    "\x01\0R3001\r\n- null pointer assignment\r\n\0"
; 0x1A84    "\xFF\xFF\xFF"  (sentinel / end of error table)
;
; ========================================================================
; END OF HEADER
; ========================================================================
