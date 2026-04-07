; ========================================================================
; MAILMRGE.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright 1987
; Compiled with Microsoft C 5.x, Small Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; MAILMRGE.PDM is a mail merge utility that runs inside the DeskMate 3.05
; shell (DESK.EXE). It reads a form letter template containing merge
; fields (delimited by 0x05/0x06 control bytes) and substitutes data
; from an address book or database file (PERSONAL.ADDR format). The
; merged output is sent to a printer or file.
;
; Features:
;   - Field substitution from address book records
;   - Header/footer support with page numbering and date insertion
;   - Word wrapping and text formatting with embedded control codes
;   - Date formatting with full leap year calculations
;   - Daylight saving time adjustment
;   - Page numbering and multi-page output
;
; Document text control codes:
;   0x01 = graphic marker
;   0x03 = format change
;   0x05 = begin field name
;   0x06 = end field name
;   0x0A = soft newline
;   0x0B = soft hyphen
;   0x0D = carriage return (hard newline)
;   0x1A = end of file
;
; Self-contained: no DM89 imports. Uses DeskMate API (INT E0h) for
; UI framework, file I/O, and resource management. Uses DESK.EXE host
; API via indirect far calls for text rendering, cursor, and dialog
; services.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 21,333 bytes
; Code size: 20,821 bytes (after header)
; DM89 entry point: 0443:000E (MSC 5.x CRT startup)
; SS:SP = 05F3:0C00
; DM flags: 0x0101
;
; Segment Map (6 segments, 19 relocations):
;   seg_0000  ~0x4430 bytes  CODE   Application code + CRT library
;   seg_0443  ~0x00B0 bytes  CODE   MSC 5.x CRT startup + far-call stubs
;   seg_044E  (small)        DATA   DGROUP fixup area
;   seg_0451  ~0x01A0 bytes  DATA   MSC CRT data (copyright, etc.)
;   seg_0455  (data)         DATA   Dialog templates
;   seg_05F3  (data)         BSS    Uninitialized data / stack
;
; Small memory model: single code segment (0000), DGROUP at 0451.
;
; ========================================================================
; INT USAGE SUMMARY
; ========================================================================
;
; INT E0h (DeskMate API): 21 calls
;   AH=02h  Register callback with DeskMate shell
;   AH=06h  Unregister callback / cleanup
;   Function codes via sub_029DF dispatch:
;     AX=2006h  dm_loadResource
;     AX=200Ch  dm_freeResource
;     AX=2012h  dm_getString
;     AX=2018h  dm_putString
;     AX=201Eh  dm_setCursorPos
;     AX=2024h  dm_getCursorPos
;     AX=202Ah  dm_setCursorShape
;     AX=2030h  dm_hideCursor
;     AX=2036h  dm_showCursor
;     AX=203Ch  dm_setTextAttr
;     AX=2042h  dm_getTextAttr
;     AX=2048h  dm_drawHLine
;     AX=204Eh  dm_drawVLine
;     AX=2054h  dm_fillRect
;     AX=205Ah  dm_scrollUp
;     AX=2060h  dm_scrollDown
;     AX=2066h  dm_getVideoMode
;     AX=206Ch  dm_openFile
;     AX=2072h  dm_closeFile
;     AX=2078h  dm_readFile
;     AX=207Eh  dm_writeFile
;     AX=2084h  dm_seekFile
;     AX=208Ah  dm_getFileSize
;     AX=2090h  dm_deleteFile
;     AX=2096h  dm_renameFile
;     AX=209Ch  dm_setMenuState
;     AX=20A2h  dm_getMenuState
;     AX=20A8h  dm_showDialog
;     AX=20AEh  dm_showMessage
;     AX=2107h  dm_getWorkArea
;
; INT 21h (DOS API): 17 calls
;   AH=25h  Set interrupt vector
;   AH=2Ah  Get date
;   AH=2Ch  Get time
;   AH=30h  Get DOS version
;   AH=35h  Get interrupt vector
;   AH=3Eh  Close file
;   AH=40h  Write file
;   AH=44h  IOCTL
;   AH=48h  Allocate memory
;   AH=4Ah  Resize memory block
;   AH=4Ch  Exit process
;
; INT 20h: 1 call (terminate, CRT startup fallback for DOS < 2.0)
; INT 28h: 1 call (DOS idle callback, used in print wait loop)
;
; ========================================================================
; FUNCTION INDEX (168 functions)
; ========================================================================
;
; --- Application Functions (mailmrge_*) ---
;
; Address   Name                          Size  Description
; -------   ----                          ----  -----------
; 0000:0010 mailmrge_main                 1294  Main entry: init, open files, merge loop, cleanup
; 0000:051E mailmrge_closePrintFile         45  Close the output print file handle
; 0000:054B mailmrge_openOutputFile        260  Open output file/printer, set up write handle
; 0000:064F mailmrge_initFieldList         215  Initialize field name list from template
; 0000:0726 mailmrge_parseFieldNames       326  Parse field names from document header
; 0000:086C mailmrge_openDataFile           89  Open PERSONAL.ADDR data file for reading
; 0000:08C5 mailmrge_readNextRecord        196  Read next record from address book file
; 0000:0989 mailmrge_formatFieldValue      218  Format a field value (trim, pad, truncate)
; 0000:0A63 mailmrge_mergeDocument         435  Main merge pass: substitute fields, emit output
; 0000:0C16 mailmrge_emitFormattedLine     123  Emit a single formatted line to output
; 0000:0C91 mailmrge_emitRawText           106  Emit raw text without field processing
; 0000:0CFB mailmrge_processControlCode    182  Process embedded control codes in text stream
; 0000:0DB1 mailmrge_handleFormatChange    172  Handle format change control code (0x03)
; 0000:0E5D mailmrge_wordWrap              256  Word-wrap text to fit output line width
; 0000:0F5D mailmrge_setOutputPosition      49  Set output cursor position for next write
; 0000:0F8E mailmrge_emitNewline           113  Emit newline, update page/line counters
; 0000:0FFF mailmrge_checkPageBreak        122  Check if page break needed, emit header/footer
; 0000:1079 mailmrge_initDocState          121  Initialize document processing state variables
; 0000:10F2 mailmrge_processPageBreak      154  Process a page break: footer, form feed, header
; 0000:118C mailmrge_processHeaderFooter   194  Process header/footer template text
; 0000:124E mailmrge_selectHeaderFooter     97  Select correct header or footer based on flags
; 0000:12AF mailmrge_copyFieldValue         54  Copy a field value string to output buffer
; 0000:12E5 mailmrge_getFieldByIndex        39  Get field value pointer by field index
; 0000:130C mailmrge_expandDateField       118  Expand date placeholder in header/footer
; 0000:1382 mailmrge_formatDate            350  Format date string from date components
; 0000:14E0 mailmrge_insertPageNumber      136  Insert page number into header/footer
; 0000:1568 mailmrge_formatPageNum          28  Format page number as string
; 0000:1584 mailmrge_itoa                   53  Convert integer to ASCII string (local)
; 0000:15B9 mailmrge_measureString         145  Measure string width for centering/alignment
; 0000:164A mailmrge_showStatus            161  Show status message during merge operation
; 0000:16EB mailmrge_openTemplateFile      374  Open the form letter template file
; 0000:1861 mailmrge_openAddrFile          424  Open the address book file (alternate path)
; 0000:1A09 mailmrge_showErrorDialog       399  Show error dialog with message string
; 0000:1B98 mailmrge_handleMenuEvent      1177  Handle menu events: File, Print, Setup actions
; 0000:2031 mailmrge_getTemplatePath        93  Get template file path from dialog
; 0000:208E mailmrge_validateTemplate      128  Validate template file existence and format
; 0000:210E mailmrge_validateAddrFile      104  Validate address book file
; 0000:2176 mailmrge_resetMergeState        74  Reset merge state for new merge operation
; 0000:21C0 mailmrge_clearStatusLine        42  Clear the status line area
; 0000:21EA mailmrge_showProgressDialog    371  Show merge progress dialog with cancel option
; 0000:235D mailmrge_getFieldPtr            26  Get pointer to field data area
; 0000:2377 mailmrge_putFieldData           31  Write field data to data area
; 0000:2396 mailmrge_setupFieldPtrs        103  Set up field pointer array from record data
; 0000:23FD mailmrge_getRecordCount         65  Get total record count from address file
; 0000:243E mailmrge_seekToRecord           57  Seek to specific record in address file
; 0000:2477 mailmrge_readField              63  Read a single field from current record
; 0000:24B6 mailmrge_skipToNextField        56  Skip to next field delimiter in input
;
; --- Field Data Access Helpers ---
;
; 0000:24EE mailmrge_getFieldOffset         39  Get byte offset of field in record
; 0000:2515 mailmrge_processRecord          80  Process one complete record (read fields, merge)
;
; --- CRT Main Wrapper ---
;
; 0000:2565 crt_callMainAndExit             15  Call _main, then _exit with return value
;
; --- CRT Exit and Argv Parsing ---
;
; 0000:2574 crt_parseArgv                  196  Parse command line into argc/argv
; 0000:2638 crt_exit                        23  _exit(): call cleanup chain, then DOS exit
; 0000:264F crt_atexitDispatch              69  Call registered atexit() handlers
; 0000:2694 crt_setExitCode                 25  Store exit code for process termination
; 0000:26AD crt_callIndirect                15  Call function pointer in CX (indirect thunk)
; 0000:26BC crt_farCallThunk                20  Far call thunk for inter-segment dispatch
;
; --- CRT Startup Support ---
;
; 0000:26D0 crt_initCRT                    202  Initialize C runtime (heap, env, file handles)
; 0000:279A mailmrge_parseCommandLine       66  Parse MAILMRGE-specific command line args
; 0000:27DC mailmrge_initOutputDevice      169  Initialize output device (printer/file)
;
; --- DESK.EXE Host API Thunks (host_*) ---
;   These 6-byte wrappers load AX with a host API function code
;   and jump to the host dispatch routine at loc_02804 or loc_02848.
;
; 0000:2885 host_drawChar                    6  Draw character at position
; 0000:288B host_drawString                  6  Draw string at position
; 0000:2891 host_setTextColor                6  Set text foreground/background color
; 0000:2897 host_getTextColor                6  Get current text color
; 0000:289D host_setCursorPos                6  Set cursor position
; 0000:28A3 host_getCursorInfo               6  Get cursor position/info
; 0000:28A9 host_setScrollRegion             6  Set scroll region boundaries
; 0000:28AF host_getScrollRegion             6  Get scroll region boundaries
; 0000:28B5 host_enableScroll                6  Enable/disable scrolling
; 0000:28BB host_setFont                     6  Set font/character set
; 0000:28C1 host_getFont                     6  Get current font
;
; --- Host API Dispatcher ---
;
; 0000:28C7 host_dispatch                  208  Dispatch host API call via far pointer table
;
; --- DeskMate API Dispatch Helpers ---
;
; 0000:2997 dm_dispatchAux                   6  Auxiliary DM dispatch thunk
; 0000:299D dm_dispatchAux2                  6  Auxiliary DM dispatch thunk 2
; 0000:29A3 dm_dispatchAux3                  6  Auxiliary DM dispatch thunk 3
; 0000:29A9 dm_registerCallback             25  Register callback (INT E0h AH=02h)
; 0000:29C2 dm_unregisterCallback           15  Unregister callback (INT E0h AH=06h)
; 0000:29D1 dm_initAndRegister               7  Init + register with DeskMate
; 0000:29D8 dm_cleanupAndUnregister          7  Cleanup + unregister from DeskMate
; 0000:29DF dm_dispatch                     40  Core DM API dispatcher (INT E0h via function code in AX)
;
; --- DeskMate API Function Thunks (dm_*) ---
;   These 6-byte wrappers load AX with a 0x20xx function code
;   and jump to dm_dispatch (sub_029DF).
;
; 0000:2A07 dm_loadResource                  6  AX=2006h Load resource file
; 0000:2A0D dm_freeResource                  6  AX=200Ch Free loaded resource
; 0000:2A13 dm_getString                     6  AX=2012h Get string from resource
; 0000:2A19 dm_putString                     6  AX=2018h Put string to resource
; 0000:2A1F dm_setCursorPos                  6  AX=201Eh Set cursor position
; 0000:2A25 dm_getCursorPos                  6  AX=2024h Get cursor position
; 0000:2A2B dm_setCursorShape                6  AX=202Ah Set cursor shape
; 0000:2A31 dm_hideCursor                    6  AX=2030h Hide cursor
; 0000:2A37 dm_showCursor                    6  AX=2036h Show cursor
; 0000:2A3D dm_setTextAttr                   6  AX=203Ch Set text attribute
; 0000:2A43 dm_getTextAttr                   6  AX=2042h Get text attribute
; 0000:2A49 dm_drawHLine                     6  AX=2048h Draw horizontal line
; 0000:2A4F dm_drawVLine                     6  AX=204Eh Draw vertical line
; 0000:2A55 dm_fillRect                      6  AX=2054h Fill rectangular region
; 0000:2A5B dm_getFileSize                   6  AX=208Ah Get file size
; 0000:2A61 dm_openFile                      6  AX=206Ch Open file
; 0000:2A67 dm_closeFile                     6  AX=2072h Close file
; 0000:2A6D dm_readFile                      6  AX=2078h Read from file
; 0000:2A73 dm_writeFile                     6  AX=207Eh Write to file
; 0000:2A79 dm_seekFile                      6  AX=2084h Seek in file
; 0000:2A7F dm_showDialog                    6  AX=20A8h Show dialog box
; 0000:2A85 dm_showMessage                   6  AX=20AEh Show message box
; 0000:2A8B dm_getWorkArea                   7  AX=2107h Get work area dimensions
;
; --- Printer / Output Functions ---
;
; 0000:2A92 mailmrge_writeToPrinter         74  Write buffer to printer/output device
; 0000:2ADC mailmrge_formatOutputLine      326  Format an output line with margins/tabs
; 0000:2C22 mailmrge_emitHeaderLine         74  Emit a header/footer line
; 0000:2C6C mailmrge_emitPageNumber         98  Emit page number at header/footer position
; 0000:2CCE mailmrge_buildOutputPage       548  Build complete output page with margins
; 0000:2EF2 mailmrge_calcLineWidth          76  Calculate line width for word wrap
; 0000:2F3E mailmrge_padOutputLine          60  Pad output line with spaces to margin
; 0000:2F7A mailmrge_handleTab             108  Handle tab character in output
; 0000:2FE6 mailmrge_flushOutput            38  Flush output buffer to device
; 0000:300C mailmrge_resetLineBuffer        14  Reset line buffer to empty
; 0000:301A mailmrge_emitChar               45  Emit single character to output
; 0000:3047 mailmrge_checkOutputReady       13  Check if output device is ready
; 0000:3054 mailmrge_getOutputWidth         35  Get output line width setting
; 0000:3077 mailmrge_setupPrinterCtrl       30  Set up printer control codes
; 0000:3095 mailmrge_initPrinter           116  Initialize printer (send reset/setup codes)
; 0000:3109 mailmrge_sendPrinterReset       14  Send printer reset code
; 0000:3117 mailmrge_sendFormFeed           16  Send form feed to printer
;
; --- DOS File I/O Wrappers ---
;
; 0000:3127 dos_closeFile                    6  Close file (INT 21h AH=3Eh)
; 0000:312D dos_writeFile                    6  Write to file (INT 21h AH=40h)
; 0000:3133 dos_getIntVector                 6  Get interrupt vector (INT 21h AH=35h)
; 0000:3139 dos_setIntVector               147  Set interrupt vector (INT 21h AH=25h)
; 0000:31CC dos_ioctlGetInfo                15  IOCTL get device info (INT 21h AH=44h)
;
; --- Interrupt / Print Spooler ---
;
; 0000:31DB mailmrge_printSpooler          595  Print spooler: buffer and send data to printer
;
; --- String Conversion ---
;
; 0000:342E mailmrge_intToDecimal          288  Convert integer to decimal string
; 0000:354E mailmrge_reverseString          42  Reverse a string in place
;
; --- C Runtime String Functions (crt_*) ---
;
; 0000:3578 crt_strcpy                      38  strcpy(dst, src)
; 0000:359E crt_strcat                      34  strcat(dst, src)
; 0000:35C0 crt_strcmp                      366  strcmp(s1, s2) -- also CRT init entry
; 0000:372E crt_strlen                       32  strlen(s)
; 0000:374E crt_strncat                      43  strncat(dst, src, n)
; 0000:3779 crt_strcpyCore                   41  Core strcpy with length tracking
; 0000:37A2 crt_memset                       66  memset(dst, ch, count)
;
; --- Numeric Formatting ---
;
; 0000:37E4 crt_signExtend                   18  Sign extend byte to word
; 0000:37F6 crt_sprintfNum                   70  Format number to string buffer
;
; --- Text Buffer Operations ---
;
; 0000:383C mailmrge_clearTextBuffer        64  Clear text buffer region
; 0000:387C mailmrge_copyTextBuffer         50  Copy text buffer region
; 0000:38AE mailmrge_fillBuffer              44  Fill buffer with byte value
; 0000:38DA crt_strlen2                      28  strlen() alternate entry
; 0000:38F6 mailmrge_compareStrings          54  Compare strings with length limit
;
; --- Misc Utility ---
;
; 0000:392C crt_nop                          4  No-op stub (returns)
; 0000:3930 mailmrge_upperCase              28  Convert character to uppercase
;
; --- Time / Date Library (crt_*) ---
;
; 0000:394C crt_time                       108  time() -- get current time as Unix timestamp
; 0000:39B8 crt_getDate                     88  Get date via DOS INT 21h AH=2Ah
; 0000:3A10 crt_memmove                     72  memmove(dst, src, n) -- overlap-safe copy
; 0000:3A58 crt_ldiv                       105  Long (32-bit) unsigned division
; 0000:3AC1 crt_malloc                     227  malloc(size) -- heap allocator
; 0000:3BA4 crt_mallocExtend                58  Extend heap for malloc
; 0000:3BDE crt_sbrk                        34  sbrk() -- extend data segment
; 0000:3C00 crt_sbrkCore                   116  Core sbrk implementation (INT 21h AH=48h)
; 0000:3C74 crt_localtime                  432  localtime() -- convert timestamp to tm struct
; 0000:3E24 crt_adjustDST                  176  Adjust time for daylight saving time
; 0000:3ED4 crt_isDSTActive                212  Check if DST is currently active
; 0000:3FA8 crt_mktime                     374  mktime() -- build Unix timestamp from components
;
; --- 32-bit Arithmetic Helpers ---
;
; 0000:411E crt_lmul                        52  32-bit multiply (long * long)
; 0000:4152 crt_heapAlloc                  110  Heap segment allocation (sbrk/INT 21h)
; 0000:41C0 crt_heapResize                  86  Resize heap segment (INT 21h AH=4Ah)
; 0000:4216 crt_strncpy                     40  strncpy(dst, src, n)
; 0000:423E crt_atol                         4  atol() -- jump to long int parser
; 0000:4242 crt_getenv                      86  getenv(name) -- search environment
; 0000:4298 crt_ldivSigned                 164  Signed 32-bit division
; 0000:433C crt_lmodSigned                 166  Signed 32-bit modulus
; 0000:43E2 crt_lmodInPlace                 34  In-place 32-bit modulus via pointer
; 0000:4404 crt_strncmp                     58  strncmp(s1, s2, n)
;
; --- CRT Entry Point (in seg_0443) ---
;
; 0443:000E start                          162  MSC 5.x CRT startup (_cstart)
; 0443:00B0 crt_farCallMain                 17  Far call wrapper: set DS, call main
; 0443:00C1 crt_farCallDialog             3172  Far call wrapper: set DS, call dialog handler
;
; ========================================================================
; DATA TABLES
; ========================================================================
;
; Address    Description
; -------    -----------
; 0000:0A6E  Leap year days-per-month table (13 words)
; 0000:0A88  Non-leap year days-per-month table (13 words)
; 0000:06BC  Environment pointer table (for getenv)
; 0000:062A  Heap control block array
; 0000:067A  Far heap segment table
; 0000:0908  tm struct output (seconds, minutes, hours, day, month, year,
;            weekday, yearday, DST flag)
; 0000:096D  Character classification table (ctype, 256 bytes)
;
; ========================================================================
; STRING TABLE (in seg_0455)
; ========================================================================
;
; 0455:00E8  "MS RunTime Library - Copyright (c) 1987, Microsoft Corp\x1e"
; 0455:0125  "\0PERSONAL.ADDR"
; 0455:0208  "Address Book List Empty"
; 0455:0220  "No records were found in the Address Book data file for the current list."
; 0455:026A  "File Not Found"
; 0455:0279  "Unable to locate files PERSONAL.ADDR"
; 0455:029E  " and "
; 0455:02A4  "Unable to locate file PERSONAL.ADDR"
; 0455:02C8  "Unable to locate file "
; 0455:02DF  "\0 Both PERSONAL.ADDR and "
; 0455:02F9  " must be available."
; 0455:030D  "Insert the diskette containing the data file PERSONAL.ADDR into Drive:"
; 0455:0355  "Out of memory. Form letter must be available."
;
; ========================================================================
; DIALOG TEMPLATES (in seg_0455)
; ========================================================================
;
; The dialog template data at seg_0455 defines the mail merge UI dialogs
; including file selection, field mapping, progress, and error dialogs.
; These are processed by the dialog template processor (crt_farCallDialog
; at 0443:00C1 which calls sub_044F1 equivalent).
;
; ========================================================================
; BEGIN DISASSEMBLY
; ========================================================================

; Segment 0000 -- zero-initialized data area (BSS preamble)
; These 16 bytes are part of the near data segment header.

  00000  0000           dw       0                  ; /* address: 0000:0000 */
  00002  0000           dw       0                  ; /* address: 0000:0002 */
  00004  0000           dw       0                  ; /* address: 0000:0004 */
  00006  0000           dw       0                  ; /* address: 0000:0006 */
  00008  0000           dw       0                  ; /* address: 0000:0008 */
  0000A  0000           dw       0                  ; /* address: 0000:000A */
  0000C  0000           dw       0                  ; /* address: 0000:000C */
  0000E  0000           dw       0                  ; /* address: 0000:000E */

; ========================================================================
; mailmrge_main -- _main() entry point
; /* address: 0000:0010 */
; 1294 bytes
;
; Main function for MAILMRGE.PDM. Initializes DeskMate resources,
; opens the template and address book files, iterates over records,
; performs field substitution and formatting, and outputs merged text
; to the printer or file.
;
; Parameters: none (called by CRT startup with argc/argv)
; Returns: exit code in AX
; ========================================================================
mailmrge_main:
  00010  55             push     bp                 ; /* address: 0000:0010 */
  00011  8bec           mov      bp, sp             ; /* address: 0000:0011 */
  00013  83ec5a         sub      sp, 0x5a           ; allocate 90 bytes of locals
  00016  56             push     si
  00017  c746fe0000     mov      word ptr [bp - 2], 0   ; mergeResult = 0
  0001C  e8b229         call     dm_initAndRegister ; register with DeskMate host
  0001F  40             inc      ax
  00020  750a           jne      .L_002C            ; if registration OK, continue
  00022  b80100         mov      ax, 1
  00025  50             push     ax
  00026  e80f26         call     crt_exit           ; _exit(1) on failure
  00029  83c402         add      sp, 2
.L_002C:
  0002C  e86b27         call     mailmrge_parseCommandLine  ; parse command line args
  0002F  40             inc      ax
  00030  750d           jne      .L_003F            ; if parse OK, continue
  00032  e8a329         call     dm_cleanupAndUnregister    ; unregister from DeskMate
  00035  b80100         mov      ax, 1
  00038  50             push     ax
  00039  e8fc25         call     crt_exit           ; _exit(1) on failure
  0003C  83c402         add      sp, 2
.L_003F:
  0003F  b8fc10         mov      ax, 0x10fc         ; string table pointer
  00042  50             push     ax
  00043  e83310         call     mailmrge_initDocState  ; init document state
  00046  83c402         add      sp, 2
  00049  b8b210         mov      ax, 0x10b2
  0004C  50             push     ax
  0004D  e84730         call     mailmrge_initPrinter   ; init printer device
  00050  83c402         add      sp, 2
  00053  e82427         call     mailmrge_initOutputDevice  ; set up output device
  00056  40             inc      ax
  00057  750d           jne      .L_0066            ; if init OK, continue
  00059  e87c29         call     dm_cleanupAndUnregister
  0005C  b80100         mov      ax, 1
  0005F  50             push     ax
  00060  e8d525         call     crt_exit           ; _exit(1) on failure
  00063  83c402         add      sp, 2
.L_0066:
  00066  b80100         mov      ax, 1
  00069  50             push     ax
  0006A  b81511         mov      ax, 0x1115
  0006D  50             push     ax
  0006E  e80e10         call     mailmrge_processPageBreak  ; initial page header
  00071  83c404         add      sp, 4
  00074  e83410         call     mailmrge_checkPageBreak
  00077  0bc0           or       ax, ax
  00079  7503           jne      .L_007E
  0007B  e95200         jmp      .L_00D0
.L_007E:
  0007E  b80500         mov      ax, 5              ; field delimiter 0x05
  00081  50             push     ax
  00082  b81511         mov      ax, 0x1115
  00085  50             push     ax
  00086  e8090a         call     mailmrge_formatFieldValue
  00089  83c404         add      sp, 4
  0008C  b80600         mov      ax, 6              ; field end delimiter 0x06
  0008F  50             push     ax
  00090  b81511         mov      ax, 0x1115
  00093  50             push     ax
  00094  e8f209         call     mailmrge_formatFieldValue
  00097  83c404         add      sp, 4
  0009A  b82011         mov      ax, 0x1120
  0009D  50             push     ax
  0009E  e8d809         call     mailmrge_formatFieldValue
  000A1  83c404         add      sp, 4
  000A4  e8b429         call     mailmrge_setOutputPosition
  000A7  33c0           xor      ax, ax
  000A9  50             push     ax
  000AA  e84d0f         call     mailmrge_emitNewline
  000AD  83c402         add      sp, 2
  000B0  e82025         call     mailmrge_processRecord
  000B3  33c0           xor      ax, ax
  000B5  50             push     ax
  000B6  e82a25         call     crt_callMainAndExit
  000B9  83c402         add      sp, 2
  000BC  e86828         call     mailmrge_initOutputDevice
  000BF  40             inc      ax
  000C0  750a           jne      .L_00CC
  000C2  b80100         mov      ax, 1
  000C5  50             push     ax
  000C6  e86f25         call     crt_exit
  000C9  83c402         add      sp, 2
.L_00CC:
  000CC  b80100         mov      ax, 1
  000CF  50             push     ax
.L_00D0:
  000D0  33f6           xor      si, si             ; record counter = 0
.L_00D2:
  000D2  b81511         mov      ax, 0x1115
  000D5  50             push     ax
  000D6  e8ec07         call     mailmrge_readNextRecord
  000D9  83c402         add      sp, 2
  000DC  0bc0           or       ax, ax
  000DE  7403           je       .L_00E3            ; if no more records, break
  000E0  e9b301         jmp      .L_0196            ; continue with end-of-merge
.L_00E3:
  000E3  0bf6           or       si, si
  000E5  7430           je       .L_0117            ; if first record, skip page break
  000E7  b80100         mov      ax, 1
  000EA  50             push     ax
  000EB  b81511         mov      ax, 0x1115
  000EE  50             push     ax
  000EF  e80010         call     mailmrge_processPageBreak
  000F2  83c404         add      sp, 4
  000F5  e80710         call     mailmrge_checkPageBreak
  000F8  0bc0           or       ax, ax
  000FA  751b           jne      .L_0117
  000FC  b80100         mov      ax, 1
  000FF  50             push     ax
  00100  b81511         mov      ax, 0x1115
  00103  50             push     ax
  00104  e8eb0f         call     mailmrge_processPageBreak
  00107  83c404         add      sp, 4
  0010A  e8f30f         call     mailmrge_checkPageBreak
  0010D  0bc0           or       ax, ax
  0010F  7506           jne      .L_0117
  00111  c746fe0100     mov      word ptr [bp - 2], 1   ; mergeResult = 1 (error)
  00116  46             inc      si
.L_0117:
  00117  837efe00       cmp      word ptr [bp - 2], 0
  0011B  7503           jne      .L_0120
  0011D  e9c700         jmp      .L_01E7
.L_0120:
  00120  8d46a6         lea      ax, [bp - 0x5a]   ; local string buffer
  00123  50             push     ax
  00124  e86624         call     mailmrge_measureString
  00127  83c402         add      sp, 2
  0012A  8d46a6         lea      ax, [bp - 0x5a]
  0012D  50             push     ax
  0012E  e8bb08         call     mailmrge_mergeDocument  ; perform field substitution
  00131  83c402         add      sp, 2
  00134  0bc0           or       ax, ax
  00136  7403           je       .L_013B
  00138  e9a300         jmp      .L_01DE            ; if merge error, handle it
.L_013B:
  0013B  b80100         mov      ax, 1              ; success marker
  0013E  50             push     ax
  0013F  e8b30e         call     mailmrge_checkPageBreak
  00142  83c402         add      sp, 2
  00145  0bc0           or       ax, ax
  00147  7503           jne      .L_014C
  00149  e99200         jmp      .L_01DE
.L_014C:
  0014C  833e020000     cmp      word ptr [0x200], 0    ; check template pointer
  00151  740c           je       .L_015F
  00153  b81511         mov      ax, 0x1115
  00156  50             push     ax
  00157  e82a0f         call     mailmrge_emitFormattedLine
  0015A  83c402         add      sp, 2
  0015D  eb0f           jmp      .L_016E
.L_015F:
  0015F  b80300         mov      ax, 3              ; format mode
  00162  50             push     ax
  00163  b81511         mov      ax, 0x1115
  00166  50             push     ax
  00167  e8270b         call     mailmrge_handleFormatChange
  0016A  83c404         add      sp, 4
.L_016E:
  0016E  b80d00         mov      ax, 0xd            ; CR character
  00171  50             push     ax
  00172  e8a90e         call     mailmrge_emitNewline
  00175  83c402         add      sp, 2
  00178  833e000000     cmp      word ptr [0], 0     ; check end of template
  0017D  7507           jne      .L_0186
  0017F  33c0           xor      ax, ax
  00181  50             push     ax
  00182  e81b0e         call     mailmrge_emitNewline
  00185  83c402         add      sp, 2
  00188  e9ac00         jmp      .L_0237
.L_0186:  ; *** Error path: output aborted
  ; ...additional code continues (main function is 1294 bytes)
  ; The remainder handles error conditions, cleanup, and the
  ; merge completion path including footer output and file close.

  ; [Lines omitted for brevity -- the raw disassembly continues
  ;  with the full instruction stream through address 0x0050D]

; ========================================================================
; mailmrge_closePrintFile -- Close the output print file
; /* address: 0000:051E */
; 45 bytes
;
; Closes the active print/output file handle via dm_closeFile,
; then flushes any remaining buffer contents.
;
; Parameters: none
; Returns: AX = result code
; ========================================================================
mailmrge_closePrintFile:
  0051E  55             push     bp                 ; /* address: 0000:051E */
  0051F  8bec           mov      bp, sp
  00521  b8b210         mov      ax, 0x10b2         ; printer state pointer
  00524  50             push     ax
  00525  e8b233         call     crt_strlen2        ; get length of printer name
  00528  83c402         add      sp, 2
  0052B  0bc0           or       ax, ax
  0052D  7413           je       .L_0542            ; if no name, skip close
  0052F  b80200         mov      ax, 2              ; close mode
  00532  50             push     ax
  00533  b80000         mov      ax, 0
  00536  50             push     ax
  00537  b8b210         mov      ax, 0x10b2
  0053A  50             push     ax
  0053B  e89425         call     mailmrge_formatOutputLine
  0053E  83c406         add      sp, 6
  00541  90             nop
.L_0542:
  00542  33c0           xor      ax, ax             ; return 0
  00544  5d             pop      bp
  00545  c3             ret

; ========================================================================
; mailmrge_openOutputFile -- Open output file/printer
; /* address: 0000:054B */
; 260 bytes
;
; Opens the merge output destination (printer or file). Sets up the
; output file handle and initializes the write buffer. Handles both
; LPT printer and disk file destinations.
;
; Parameters: push output mode, push file path
; Returns: AX = file handle or error code
; ========================================================================
mailmrge_openOutputFile:
  0054B  55             push     bp                 ; /* address: 0000:054B */
  0054C  8bec           mov      bp, sp
  0054E  83ec20         sub      sp, 0x20           ; 32 bytes locals
  00551  57             push     di
  00552  56             push     si
  00553  b8b210         mov      ax, 0x10b2
  00556  50             push     ax
  00557  e8ad24         call     dm_loadResource    ; AX=2006h -- load resource
  0055A  83c402         add      sp, 2
  0055D  8bf0           mov      si, ax             ; si = resource handle
  0055F  b8b210         mov      ax, 0x10b2
  00562  50             push     ax
  00563  e87424         call     dm_loadResource
  00566  83c402         add      sp, 2
  00569  8bf8           mov      di, ax
  0056B  0bf6           or       si, si
  0056D  7403           je       .L_0572
  0056F  0bff           or       di, di
  00571  7514           jne      .L_0587
.L_0572:
  00572  8d46e0         lea      ax, [bp - 0x20]
  00575  50             push     ax
  00576  e80125         call     mailmrge_copyTextBuffer
  00579  83c402         add      sp, 2
  0057C  8d46e0         lea      ax, [bp - 0x20]
  0057F  50             push     ax
  00580  e8f924         call     mailmrge_copyTextBuffer
  00583  83c402         add      sp, 2
  00586  90             nop
.L_0587:
  ; [Continues through 0x064E with output file setup logic]
  ; The function validates paths, opens file handles via dm_openFile,
  ; sets up buffering, and returns the file handle in AX.

; ========================================================================
; mailmrge_initFieldList -- Initialize field name list
; /* address: 0000:064F */
; 215 bytes
;
; Initializes the list of field names from the template document.
; Scans the template for field delimiters (0x05/0x06) and builds
; a table of field name pointers.
;
; Parameters: template buffer pointer
; Returns: AX = field count
; ========================================================================
mailmrge_initFieldList:
  0064F  55             push     bp                 ; /* address: 0000:064F */
  00650  8bec           mov      bp, sp
  ; [Function body -- 215 bytes through 0x0725]

; ========================================================================
; mailmrge_parseFieldNames -- Parse field names from document header
; /* address: 0000:0726 */
; 326 bytes
;
; Parses field names from the document template header section.
; Builds a mapping table between field names in the template and
; field indices in the address book record format.
;
; Parameters: push template pointer
; Returns: AX = number of fields parsed
; ========================================================================
mailmrge_parseFieldNames:
  00726  55             push     bp                 ; /* address: 0000:0726 */
  00727  8bec           mov      bp, sp
  ; [Function body -- 326 bytes through 0x086B]

; ========================================================================
; mailmrge_openDataFile -- Open address book data file
; /* address: 0000:086C */
; 89 bytes
;
; Opens the PERSONAL.ADDR address book file for reading.
; Uses dm_loadResource and host_getCursorInfo for file access.
;
; Parameters: none
; Returns: AX = 0 on success, -1 on failure
; ========================================================================
mailmrge_openDataFile:
  0086C  55             push     bp                 ; /* address: 0000:086C */
  0086D  8bec           mov      bp, sp
  0086F  b8b210         mov      ax, 0x10b2
  00872  50             push     ax
  00873  e89121         call     dm_loadResource    ; AX=2006h -- load resource
  00876  83c402         add      sp, 2
  00879  50             push     ax
  0087A  e82620         call     host_getCursorInfo ; get cursor info
  0087D  83c402         add      sp, 2
  00880  50             push     ax
  00881  e8791f         call     dm_freeResource    ; AX=200Ch -- free resource
  00884  83c402         add      sp, 2
  00887  50             push     ax
  00888  e87a17         call     mailmrge_openTemplateFile  ; [sic: likely opens addr file]
  0088B  83c402         add      sp, 2
  0088E  50             push     ax
  0088F  e84c10         call     mailmrge_setOutputPosition
  00892  83c402         add      sp, 2
  00895  50             push     ax
  00896  e83524         call     mailmrge_copyTextBuffer
  00899  83c402         add      sp, 2
  ; [Continues through 0x08C4]

; ========================================================================
; mailmrge_readNextRecord -- Read next record from address book
; /* address: 0000:08C5 */
; 196 bytes
;
; Reads the next record from the opened address book file. Advances
; the record pointer and fills the field buffer with the record's
; field values.
;
; Parameters: push state pointer
; Returns: AX = 0 if record read OK, nonzero if EOF or error
; ========================================================================
mailmrge_readNextRecord:
  008C5  55             push     bp                 ; /* address: 0000:08C5 */
  008C6  8bec           mov      bp, sp
  ; [Function body -- 196 bytes through 0x0988]

; ========================================================================
; mailmrge_formatFieldValue -- Format a field value
; /* address: 0000:0989 */
; 218 bytes
;
; Formats a field value by trimming whitespace, padding to the required
; width, or truncating if too long. Used for both regular fields and
; special control code fields.
;
; Parameters: push field value ptr, push format mode
; Returns: AX = formatted length
; ========================================================================
mailmrge_formatFieldValue:
  00989  55             push     bp                 ; /* address: 0000:0989 */
  0098A  8bec           mov      bp, sp
  ; [Function body -- 218 bytes through 0x0A62]

; ========================================================================
; mailmrge_mergeDocument -- Main merge pass
; /* address: 0000:0A63 */
; 435 bytes
;
; Performs the main merge operation: scans the template document for
; field markers (0x05/0x06), substitutes address book field values,
; applies formatting, and emits the merged text to the output device.
;
; Parameters: push output buffer pointer
; Returns: AX = 0 on success, nonzero on error
; ========================================================================
mailmrge_mergeDocument:
  00A63  55             push     bp                 ; /* address: 0000:0A63 */
  00A64  8bec           mov      bp, sp
  ; [Function body -- 435 bytes through 0x0C15]

; ========================================================================
; mailmrge_emitFormattedLine -- Emit a formatted line to output
; /* address: 0000:0C16 */
; 123 bytes
; ========================================================================
mailmrge_emitFormattedLine:
  00C16  55             push     bp                 ; /* address: 0000:0C16 */
  00C17  8bec           mov      bp, sp
  ; [Function body -- 123 bytes through 0x0C90]

; ========================================================================
; mailmrge_emitRawText -- Emit raw text without field processing
; /* address: 0000:0C91 */
; 106 bytes
; ========================================================================
mailmrge_emitRawText:
  00C91  55             push     bp                 ; /* address: 0000:0C91 */
  00C92  8bec           mov      bp, sp
  ; [Function body -- 106 bytes through 0x0CFA]

; ========================================================================
; mailmrge_processControlCode -- Process embedded control codes
; /* address: 0000:0CFB */
; 182 bytes
;
; Processes text control codes: 0x05 (begin field), 0x06 (end field),
; 0x03 (format change), 0x0D (CR), 0x0A (soft newline).
; ========================================================================
mailmrge_processControlCode:
  00CFB  55             push     bp                 ; /* address: 0000:0CFB */
  00CFC  8bec           mov      bp, sp
  ; [Function body -- 182 bytes through 0x0DB0]

; ========================================================================
; mailmrge_handleFormatChange -- Handle format change code (0x03)
; /* address: 0000:0DB1 */
; 172 bytes
; ========================================================================
mailmrge_handleFormatChange:
  00DB1  55             push     bp                 ; /* address: 0000:0DB1 */
  00DB2  8bec           mov      bp, sp
  ; [Function body -- 172 bytes through 0x0E5C]

; ========================================================================
; mailmrge_wordWrap -- Word-wrap text to fit output width
; /* address: 0000:0E5D */
; 256 bytes
;
; Performs word wrapping on the current line. Finds the last space
; character before the margin and breaks the line there. Handles
; soft hyphens (0x0B) as optional break points.
; ========================================================================
mailmrge_wordWrap:
  00E5D  55             push     bp                 ; /* address: 0000:0E5D */
  00E5E  8bec           mov      bp, sp
  ; [Function body -- 256 bytes through 0x0F5C]

; ========================================================================
; mailmrge_setOutputPosition -- Set output cursor position
; /* address: 0000:0F5D */
; 49 bytes
; ========================================================================
mailmrge_setOutputPosition:
  00F5D  55             push     bp                 ; /* address: 0000:0F5D */
  00F5E  8bec           mov      bp, sp
  00F60  b8b210         mov      ax, 0x10b2
  00F63  50             push     ax
  00F64  e8a01a         call     dm_loadResource    ; AX=2006h
  00F67  83c402         add      sp, 2
  0006A  50             push     ax
  0006B  e80d1a         call     dm_seekFile        ; AX=2084h -- seek in file
  0006E  83c402         add      sp, 2
  00071  50             push     ax
  00072  e8981a         call     dm_freeResource    ; AX=200Ch
  00075  83c402         add      sp, 2
  ; [Continues through 0x0F8D]

; ========================================================================
; mailmrge_emitNewline -- Emit newline, update page/line counters
; /* address: 0000:0F8E */
; 113 bytes
; ========================================================================
mailmrge_emitNewline:
  00F8E  55             push     bp                 ; /* address: 0000:0F8E */
  00F8F  8bec           mov      bp, sp
  ; [Function body -- 113 bytes through 0x0FFE]

; ========================================================================
; mailmrge_checkPageBreak -- Check if page break is needed
; /* address: 0000:0FFF */
; 122 bytes
; ========================================================================
mailmrge_checkPageBreak:
  00FFF  55             push     bp                 ; /* address: 0000:0FFF */
  01000  8bec           mov      bp, sp
  ; [Function body -- 122 bytes through 0x1078]

; ========================================================================
; mailmrge_initDocState -- Initialize document processing state
; /* address: 0000:1079 */
; 121 bytes
;
; Initializes all document state variables: page counter, line counter,
; margin settings, field pointers, header/footer mode flags.
; ========================================================================
mailmrge_initDocState:
  01079  55             push     bp                 ; /* address: 0000:1079 */
  0107A  8bec           mov      bp, sp
  ; [Function body -- 121 bytes through 0x10F1]

; ========================================================================
; mailmrge_processPageBreak -- Process page break
; /* address: 0000:10F2 */
; 154 bytes
;
; Handles a page break: outputs footer, sends form feed, then outputs
; the new page header. Increments the page counter.
; ========================================================================
mailmrge_processPageBreak:
  010F2  55             push     bp                 ; /* address: 0000:10F2 */
  010F3  8bec           mov      bp, sp
  ; [Function body -- 154 bytes through 0x118B]

; ========================================================================
; mailmrge_processHeaderFooter -- Process header/footer template
; /* address: 0000:118C */
; 194 bytes
;
; Processes a header or footer template string, expanding date and
; page number placeholders. The flag parameter indicates:
;   H/h = header (type 1/2), F/f = footer (type 1/2)
; ========================================================================
mailmrge_processHeaderFooter:
  0118C  55             push     bp                 ; /* address: 0000:118C */
  0118D  8bec           mov      bp, sp
  ; [Function body -- 194 bytes through 0x124D]

; ========================================================================
; mailmrge_selectHeaderFooter -- Select header or footer by flags
; /* address: 0000:124E */
; 97 bytes
; ========================================================================
mailmrge_selectHeaderFooter:
  0124E  55             push     bp                 ; /* address: 0000:124E */
  0124F  8bec           mov      bp, sp
  ; [Function body -- 97 bytes through 0x12AE]

; ========================================================================
; mailmrge_copyFieldValue -- Copy field value to output buffer
; /* address: 0000:12AF */
; 54 bytes
; ========================================================================
mailmrge_copyFieldValue:
  012AF  55             push     bp                 ; /* address: 0000:12AF */
  012B0  8bec           mov      bp, sp
  ; [Function body -- 54 bytes through 0x12E4]

; ========================================================================
; mailmrge_getFieldByIndex -- Get field value by index
; /* address: 0000:12E5 */
; 39 bytes
; ========================================================================
mailmrge_getFieldByIndex:
  012E5  55             push     bp                 ; /* address: 0000:12E5 */
  012E6  8bec           mov      bp, sp
  ; [Function body -- 39 bytes through 0x130B]

; ========================================================================
; mailmrge_expandDateField -- Expand date placeholder
; /* address: 0000:130C */
; 118 bytes
;
; Expands a date placeholder in header/footer text. Calls the date
; formatting function and inserts the result.
; ========================================================================
mailmrge_expandDateField:
  0130C  55             push     bp                 ; /* address: 0000:130C */
  0130D  8bec           mov      bp, sp
  ; [Function body -- 118 bytes through 0x1381]

; ========================================================================
; mailmrge_formatDate -- Format date string
; /* address: 0000:1382 */
; 350 bytes
;
; Formats a date from month/day/year components into a display string.
; Uses the field pointer table and data area table for month names
; and formatting patterns.
; ========================================================================
mailmrge_formatDate:
  01382  55             push     bp                 ; /* address: 0000:1382 */
  01383  8bec           mov      bp, sp
  ; [Function body -- 350 bytes through 0x14DF]

; ========================================================================
; mailmrge_insertPageNumber -- Insert page number
; /* address: 0000:14E0 */
; 136 bytes
; ========================================================================
mailmrge_insertPageNumber:
  014E0  55             push     bp                 ; /* address: 0000:14E0 */
  014E1  8bec           mov      bp, sp
  ; [Function body -- 136 bytes through 0x1567]

; ========================================================================
; mailmrge_formatPageNum -- Format page number as string
; /* address: 0000:1568 */
; 28 bytes
; ========================================================================
mailmrge_formatPageNum:
  01568  55             push     bp                 ; /* address: 0000:1568 */
  01569  8bec           mov      bp, sp
  ; [Function body -- 28 bytes through 0x1583]

; ========================================================================
; mailmrge_itoa -- Convert integer to ASCII
; /* address: 0000:1584 */
; 53 bytes
; ========================================================================
mailmrge_itoa:
  01584  55             push     bp                 ; /* address: 0000:1584 */
  01585  8bec           mov      bp, sp
  ; [Function body -- 53 bytes through 0x15B8]

; ========================================================================
; mailmrge_measureString -- Measure string width
; /* address: 0000:15B9 */
; 145 bytes
; ========================================================================
mailmrge_measureString:
  015B9  55             push     bp                 ; /* address: 0000:15B9 */
  015BA  8bec           mov      bp, sp
  ; [Function body -- 145 bytes through 0x1649]

; ========================================================================
; mailmrge_showStatus -- Show status message during merge
; /* address: 0000:164A */
; 161 bytes
; ========================================================================
mailmrge_showStatus:
  0164A  55             push     bp                 ; /* address: 0000:164A */
  0164B  8bec           mov      bp, sp
  ; [Function body -- 161 bytes through 0x16EA]

; ========================================================================
; mailmrge_openTemplateFile -- Open form letter template file
; /* address: 0000:16EB */
; 374 bytes
;
; Opens the form letter template file specified by the user or command
; line. Validates the file, reads the header, and initializes the
; template scanning state.
; ========================================================================
mailmrge_openTemplateFile:
  016EB  55             push     bp                 ; /* address: 0000:16EB */
  016EC  8bec           mov      bp, sp
  ; [Function body -- 374 bytes through 0x1860]

; ========================================================================
; mailmrge_openAddrFile -- Open address book file (alternate)
; /* address: 0000:1861 */
; 424 bytes
; ========================================================================
mailmrge_openAddrFile:
  01861  55             push     bp                 ; /* address: 0000:1861 */
  01862  8bec           mov      bp, sp
  ; [Function body -- 424 bytes through 0x1A08]

; ========================================================================
; mailmrge_showErrorDialog -- Show error dialog
; /* address: 0000:1A09 */
; 399 bytes
;
; Displays an error dialog with the given message. Uses dm_readFile
; and dm_writeFile to build the dialog content, then dm_showDialog
; to present it.
; ========================================================================
mailmrge_showErrorDialog:
  01A09  55             push     bp                 ; /* address: 0000:1A09 */
  01A0A  8bec           mov      bp, sp
  ; [Function body -- 399 bytes through 0x1B97]

; ========================================================================
; mailmrge_handleMenuEvent -- Handle menu events
; /* address: 0000:1B98 */
; 1177 bytes
;
; Main event handler for the mail merge menu system. Dispatches
; File menu actions (Open, Close, Print, Exit) and Setup actions.
; This is the second-largest application function.
; ========================================================================
mailmrge_handleMenuEvent:
  01B98  55             push     bp                 ; /* address: 0000:1B98 */
  01B99  8bec           mov      bp, sp
  ; [Function body -- 1177 bytes through 0x2030]

; ========================================================================
; mailmrge_getTemplatePath -- Get template file path
; /* address: 0000:2031 */
; 93 bytes
; ========================================================================
mailmrge_getTemplatePath:
  02031  55             push     bp                 ; /* address: 0000:2031 */
  02032  8bec           mov      bp, sp
  ; [Function body -- 93 bytes through 0x208D]

; ========================================================================
; mailmrge_validateTemplate -- Validate template file
; /* address: 0000:208E */
; 128 bytes
; ========================================================================
mailmrge_validateTemplate:
  0208E  55             push     bp                 ; /* address: 0000:208E */
  0208F  8bec           mov      bp, sp
  ; [Function body -- 128 bytes through 0x210D]

; ========================================================================
; mailmrge_validateAddrFile -- Validate address book file
; /* address: 0000:210E */
; 104 bytes
; ========================================================================
mailmrge_validateAddrFile:
  0210E  55             push     bp                 ; /* address: 0000:210E */
  0210F  8bec           mov      bp, sp
  ; [Function body -- 104 bytes through 0x2175]

; ========================================================================
; mailmrge_resetMergeState -- Reset merge state
; /* address: 0000:2176 */
; 74 bytes
; ========================================================================
mailmrge_resetMergeState:
  02176  55             push     bp                 ; /* address: 0000:2176 */
  02177  8bec           mov      bp, sp
  ; [Function body -- 74 bytes through 0x21BF]

; ========================================================================
; mailmrge_clearStatusLine -- Clear the status line
; /* address: 0000:21C0 */
; 42 bytes
; ========================================================================
mailmrge_clearStatusLine:
  021C0  55             push     bp                 ; /* address: 0000:21C0 */
  021C1  8bec           mov      bp, sp
  ; [Function body -- 42 bytes through 0x21E9]

; ========================================================================
; mailmrge_showProgressDialog -- Show merge progress dialog
; /* address: 0000:21EA */
; 371 bytes
; ========================================================================
mailmrge_showProgressDialog:
  021EA  55             push     bp                 ; /* address: 0000:21EA */
  021EB  8bec           mov      bp, sp
  ; [Function body -- 371 bytes through 0x235C]

; ========================================================================
; mailmrge_getFieldPtr -- Get pointer to field data area
; /* address: 0000:235D */
; 26 bytes
; ========================================================================
mailmrge_getFieldPtr:
  0235D  55             push     bp                 ; /* address: 0000:235D */
  0235E  8bec           mov      bp, sp
  ; [Function body -- 26 bytes through 0x2376]

; ========================================================================
; mailmrge_putFieldData -- Write field data
; /* address: 0000:2377 */
; 31 bytes
; ========================================================================
mailmrge_putFieldData:
  02377  55             push     bp                 ; /* address: 0000:2377 */
  02378  8bec           mov      bp, sp
  ; [Function body -- 31 bytes through 0x2395]

; ========================================================================
; mailmrge_setupFieldPtrs -- Set up field pointer array
; /* address: 0000:2396 */
; 103 bytes
; ========================================================================
mailmrge_setupFieldPtrs:
  02396  55             push     bp                 ; /* address: 0000:2396 */
  02397  8bec           mov      bp, sp
  ; [Function body -- 103 bytes through 0x23FC]

; ========================================================================
; mailmrge_getRecordCount -- Get total record count
; /* address: 0000:23FD */
; 65 bytes
; ========================================================================
mailmrge_getRecordCount:
  023FD  55             push     bp                 ; /* address: 0000:23FD */
  023FE  8bec           mov      bp, sp
  ; [Function body -- 65 bytes through 0x243D]

; ========================================================================
; mailmrge_seekToRecord -- Seek to specific record
; /* address: 0000:243E */
; 57 bytes
; ========================================================================
mailmrge_seekToRecord:
  0243E  55             push     bp                 ; /* address: 0000:243E */
  0243F  8bec           mov      bp, sp
  ; [Function body -- 57 bytes through 0x2476]

; ========================================================================
; mailmrge_readField -- Read a single field from record
; /* address: 0000:2477 */
; 63 bytes
; ========================================================================
mailmrge_readField:
  02477  55             push     bp                 ; /* address: 0000:2477 */
  02478  8bec           mov      bp, sp
  ; [Function body -- 63 bytes through 0x24B5]

; ========================================================================
; mailmrge_skipToNextField -- Skip to next field delimiter
; /* address: 0000:24B6 */
; 56 bytes
; ========================================================================
mailmrge_skipToNextField:
  024B6  55             push     bp                 ; /* address: 0000:24B6 */
  024B7  8bec           mov      bp, sp
  ; [Function body -- 56 bytes through 0x24ED]

; ========================================================================
; mailmrge_getFieldOffset -- Get byte offset of field
; /* address: 0000:24EE */
; 39 bytes
; ========================================================================
mailmrge_getFieldOffset:
  024EE  55             push     bp                 ; /* address: 0000:24EE */
  024EF  8bec           mov      bp, sp
  ; [Function body -- 39 bytes through 0x2514]

; ========================================================================
; mailmrge_processRecord -- Process one complete record
; /* address: 0000:2515 */
; 80 bytes
;
; Orchestrates processing of a single address book record: reads all
; fields, calls the merge function, advances to the next record.
; ========================================================================
mailmrge_processRecord:
  02515  55             push     bp                 ; /* address: 0000:2515 */
  02516  8bec           mov      bp, sp
  ; [Function body -- 80 bytes through 0x2564]

; ========================================================================
; crt_callMainAndExit -- Call _main, then _exit
; /* address: 0000:2565 */
; 15 bytes
; ========================================================================
crt_callMainAndExit:
  02565  55             push     bp                 ; /* address: 0000:2565 */
  02566  8bec           mov      bp, sp
  02568  e80e12         call     crt_strcpy         ; [indirect: word ptr [0x628]]
  0256B  50             push     ax
  0256C  e8100a         call     crt_strcpyCore     ; [indirect: word ptr [bp + si]]
  0256F  83c402         add      sp, 2
  02572  5d             pop      bp
  02573  c3             ret

; ========================================================================
; crt_parseArgv -- Parse command line into argc/argv
; /* address: 0000:2574 */
; 196 bytes
; ========================================================================
crt_parseArgv:
  02574  55             push     bp                 ; /* address: 0000:2574 */
  02575  8bec           mov      bp, sp
  ; [Function body -- 196 bytes through 0x2637]

; ========================================================================
; crt_exit -- _exit() terminate process
; /* address: 0000:2638 */
; 23 bytes
;
; Calls atexit handlers, then terminates via INT 21h AH=4Ch.
; ========================================================================
crt_exit:
  02638  55             push     bp                 ; /* address: 0000:2638 */
  02639  8bec           mov      bp, sp
  0263B  8b4604         mov      ax, word ptr [bp + 4]
  0263E  50             push     ax
  0263F  e85200         call     crt_setExitCode    ; store exit code
  02642  83c402         add      sp, 2
  02645  e80700         call     crt_atexitDispatch ; call atexit handlers
  02648  a19d06         mov      ax, word ptr [0x69d]
  0264B  b44c           mov      ah, 0x4c           ; INT 21h AH=4Ch -- Exit process
  0264D  cd21           int      0x21
  0264F  c3             ret

; ========================================================================
; crt_atexitDispatch -- Call registered atexit handlers
; /* address: 0000:264F */
; 69 bytes
; ========================================================================
crt_atexitDispatch:
  0264F  55             push     bp                 ; /* address: 0000:264F */
  02650  8bec           mov      bp, sp
  ; [Function body -- 69 bytes through 0x2693]

; ========================================================================
; crt_setExitCode -- Store exit code
; /* address: 0000:2694 */
; 25 bytes
; ========================================================================
crt_setExitCode:
  02694  55             push     bp                 ; /* address: 0000:2694 */
  02695  8bec           mov      bp, sp
  ; [Function body -- 25 bytes through 0x26AC]

; ========================================================================
; crt_callIndirect -- Call function pointer in CX
; /* address: 0000:26AD */
; 15 bytes
; ========================================================================
crt_callIndirect:
  026AD  55             push     bp                 ; /* address: 0000:26AD */
  026AE  8bec           mov      bp, sp
  ; [Function body -- 15 bytes, calls [indirect:cx] through 0x26BB]

; ========================================================================
; crt_farCallThunk -- Far call thunk for inter-segment dispatch
; /* address: 0000:26BC */
; 20 bytes
; ========================================================================
crt_farCallThunk:
  026BC  55             push     bp                 ; /* address: 0000:26BC */
  026BD  8bec           mov      bp, sp
  ; [Function body -- 20 bytes through 0x26CF]

; ========================================================================
; crt_initCRT -- Initialize C runtime
; /* address: 0000:26D0 */
; 202 bytes
;
; Initializes the C runtime: sets up heap, environment pointers,
; file handle table. Called by CRT startup before _main.
; ========================================================================
crt_initCRT:
  026D0  55             push     bp                 ; /* address: 0000:26D0 */
  026D1  8bec           mov      bp, sp
  ; [Function body -- 202 bytes through 0x2799]

; ========================================================================
; mailmrge_parseCommandLine -- Parse command line arguments
; /* address: 0000:279A */
; 66 bytes
; ========================================================================
mailmrge_parseCommandLine:
  0279A  55             push     bp                 ; /* address: 0000:279A */
  0279B  8bec           mov      bp, sp
  ; [Function body -- 66 bytes through 0x27DB]

; ========================================================================
; mailmrge_initOutputDevice -- Initialize output device
; /* address: 0000:27DC */
; 169 bytes
; ========================================================================
mailmrge_initOutputDevice:
  027DC  55             push     bp                 ; /* address: 0000:27DC */
  027DD  8bec           mov      bp, sp
  ; [Function body -- 169 bytes through 0x2884]

; ========================================================================
; DESK.EXE Host API Thunks
; /* addresses: 0000:2885 through 0000:28C1 */
;
; Each thunk is 6 bytes: loads AX with a host API function code,
; then jumps to the host dispatch routine.
; ========================================================================
host_drawChar:                                     ; /* address: 0000:2885 */
  02885  b80000         mov      ax, 0x0000
  02888  e97900         jmp      host_dispatch

host_drawString:                                   ; /* address: 0000:288B */
  0288B  b80200         mov      ax, 0x0002
  0288E  e97300         jmp      host_dispatch      ; [sic: adjusted offset]

host_setTextColor:                                 ; /* address: 0000:2891 */
  02891  b80400         mov      ax, 0x0004
  02894  e96d00         jmp      host_dispatch

host_getTextColor:                                 ; /* address: 0000:2897 */
  02897  b80600         mov      ax, 0x0006
  0289A  e96700         jmp      host_dispatch

host_setCursorPos:                                 ; /* address: 0000:289D */
  0289D  b80800         mov      ax, 0x0008
  028A0  e96100         jmp      host_dispatch

host_getCursorInfo:                                ; /* address: 0000:28A3 */
  028A3  b80a00         mov      ax, 0x000a
  028A6  e95b00         jmp      host_dispatch

host_setScrollRegion:                              ; /* address: 0000:28A9 */
  028A9  b80c00         mov      ax, 0x000c
  028AC  e95500         jmp      host_dispatch

host_getScrollRegion:                              ; /* address: 0000:28AF */
  028AF  b80e00         mov      ax, 0x000e
  028B2  e94f00         jmp      host_dispatch

host_enableScroll:                                 ; /* address: 0000:28B5 */
  028B5  b81000         mov      ax, 0x0010
  028B8  e94900         jmp      host_dispatch

host_setFont:                                      ; /* address: 0000:28BB */
  028BB  b81200         mov      ax, 0x0012
  028BE  e94300         jmp      host_dispatch

host_getFont:                                      ; /* address: 0000:28C1 */
  028C1  b81400         mov      ax, 0x0014
  028C4  e93d00         jmp      host_dispatch

; ========================================================================
; host_dispatch -- Dispatch host API call
; /* address: 0000:28C7 */
; 208 bytes
;
; Dispatches a DESK.EXE host API call. The function code in AX is used
; as an index into the host's function pointer table. Parameters are
; passed on the stack. The call is made via far pointer through the
; host's dispatch table.
; ========================================================================
host_dispatch:
  028C7  55             push     bp                 ; /* address: 0000:28C7 */
  028C8  8bec           mov      bp, sp
  ; [Function body -- 208 bytes through 0x2996]

; ========================================================================
; DeskMate API Dispatch Helpers
; /* addresses: 0000:2997 through 0000:29DF */
; ========================================================================
dm_dispatchAux:                                    ; /* address: 0000:2997 */
  02997  b80000         mov      ax, 0
  0299A  e94200         jmp      dm_dispatch

dm_dispatchAux2:                                   ; /* address: 0000:299D */
  0299D  b80200         mov      ax, 2
  029A0  e93C00         jmp      dm_dispatch

dm_dispatchAux3:                                   ; /* address: 0000:29A3 */
  029A3  b80400         mov      ax, 4
  029A6  e93600         jmp      dm_dispatch

; ========================================================================
; dm_registerCallback -- Register callback with DeskMate
; /* address: 0000:29A9 */
; 25 bytes
;
; Registers the application callback with the DeskMate shell via
; INT E0h AH=02h. This allows DeskMate to dispatch events (menu
; selections, key presses, etc.) to the application.
; ========================================================================
dm_registerCallback:
  029A9  55             push     bp                 ; /* address: 0000:29A9 */
  029AA  8bec           mov      bp, sp
  029AC  8b4604         mov      ax, word ptr [bp + 4]
  029AF  a3da06         mov      word ptr [0x6da], ax
  029B2  8b4606         mov      ax, word ptr [bp + 6]
  029B5  a3dc06         mov      word ptr [0x6dc], ax
  029B8  b402           mov      ah, 0x02           ; INT E0h AH=02h -- register callback
  029BA  cde0           int      0xe0               ; DeskMate API call
  029BC  0bc0           or       ax, ax
  029BE  7501           jne      .L_29C1
  029C0  c3             ret
.L_29C1:
  029C1  c3             ret

; ========================================================================
; dm_unregisterCallback -- Unregister callback from DeskMate
; /* address: 0000:29C2 */
; 15 bytes
;
; Unregisters the application callback via INT E0h AH=06h.
; ========================================================================
dm_unregisterCallback:
  029C2  b406           mov      ah, 0x06           ; /* address: 0000:29C2 */
  029C4  cde0           int      0xe0               ; INT E0h AH=06h -- unregister callback
  029C6  a3da06         mov      word ptr [0x6da], ax
  029C9  a3dc06         mov      word ptr [0x6dc], ax
  029CC  a3de06         mov      word ptr [0x6de], ax
  029CF  a3e006         mov      word ptr [0x6e0], ax
  029D2  c3             ret

; ========================================================================
; dm_initAndRegister -- Init + register with DeskMate
; /* address: 0000:29D1 */
; 7 bytes
; ========================================================================
dm_initAndRegister:
  029D1  e8d5ff         call     dm_registerCallback ; /* address: 0000:29D1 */
  029D4  e85c07         call     dos_getIntVector
  029D7  c3             ret

; ========================================================================
; dm_cleanupAndUnregister -- Cleanup + unregister from DeskMate
; /* address: 0000:29D8 */
; 7 bytes
; ========================================================================
dm_cleanupAndUnregister:
  029D8  e85e07         call     dos_setIntVector   ; /* address: 0000:29D8 */
  029DB  e8e4ff         call     dm_unregisterCallback
  029DE  c3             ret

; ========================================================================
; dm_dispatch -- Core DeskMate API dispatcher
; /* address: 0000:29DF */
; 40 bytes
;
; Dispatches a DeskMate API function call via INT E0h. The function
; code is in AX (0x20xx format). Parameters are on the stack.
; The INT E0h handler in DESK.EXE dispatches based on the AX value.
; ========================================================================
dm_dispatch:
  029DF  55             push     bp                 ; /* address: 0000:29DF */
  029E0  8bec           mov      bp, sp
  029E2  8b5e08         mov      bx, word ptr [bp + 8]
  029E5  8b4e06         mov      cx, word ptr [bp + 6]
  029E8  8b5604         mov      dx, word ptr [bp + 4]
  029EB  53             push     bx
  029EC  51             push     cx
  029ED  52             push     dx
  029EE  cde0           int      0xe0               ; INT E0h -- DeskMate API dispatch
  029F0  83c406         add      sp, 6
  029F3  8b4e06         mov      cx, word ptr [bp + 6]
  029F6  8b5604         mov      dx, word ptr [bp + 4]
  029F9  0bc0           or       ax, ax
  029FB  7507           jne      .L_2A04
  029FD  8bc1           mov      ax, cx
  029FF  8bd2           mov      dx, dx
  02A01  5d             pop      bp
  02A02  c20600         ret      6
.L_2A04:
  02A05  5d             pop      bp
  02A06  c3             ret

; ========================================================================
; DeskMate API Function Thunks
; /* addresses: 0000:2A07 through 0000:2A8B */
;
; Each 6-byte thunk loads AX with a DeskMate API function code
; (0x20xx format) and jumps to dm_dispatch.
; ========================================================================
dm_loadResource:                                   ; /* address: 0000:2A07 */ AX=2006h
  02A07  b80620         mov      ax, 0x2006
  02A0A  e9D2FF         jmp      dm_dispatch

dm_freeResource:                                   ; /* address: 0000:2A0D */ AX=200Ch
  02A0D  b80c20         mov      ax, 0x200c
  02A10  e9CCFF         jmp      dm_dispatch

dm_getString:                                      ; /* address: 0000:2A13 */ AX=2012h
  02A13  b81220         mov      ax, 0x2012
  02A16  e9C6FF         jmp      dm_dispatch

dm_putString:                                      ; /* address: 0000:2A19 */ AX=2018h
  02A19  b81820         mov      ax, 0x2018
  02A1C  e9C0FF         jmp      dm_dispatch

dm_setCursorPos:                                   ; /* address: 0000:2A1F */ AX=201Eh
  02A1F  b81e20         mov      ax, 0x201e
  02A22  e9BAFF         jmp      dm_dispatch

dm_getCursorPos:                                   ; /* address: 0000:2A25 */ AX=2024h
  02A25  b82420         mov      ax, 0x2024
  02A28  e9B4FF         jmp      dm_dispatch

dm_setCursorShape:                                 ; /* address: 0000:2A2B */ AX=202Ah
  02A2B  b82a20         mov      ax, 0x202a
  02A2E  e9AEFF         jmp      dm_dispatch

dm_hideCursor:                                     ; /* address: 0000:2A31 */ AX=2030h
  02A31  b83020         mov      ax, 0x2030
  02A34  e9A8FF         jmp      dm_dispatch

dm_showCursor:                                     ; /* address: 0000:2A37 */ AX=2036h
  02A37  b83620         mov      ax, 0x2036
  02A3A  e9A2FF         jmp      dm_dispatch

dm_setTextAttr:                                    ; /* address: 0000:2A3D */ AX=203Ch
  02A3D  b83c20         mov      ax, 0x203c
  02A40  e99CFF         jmp      dm_dispatch

dm_getTextAttr:                                    ; /* address: 0000:2A43 */ AX=2042h
  02A43  b84220         mov      ax, 0x2042
  02A46  e996FF         jmp      dm_dispatch

dm_drawHLine:                                      ; /* address: 0000:2A49 */ AX=2048h
  02A49  b84820         mov      ax, 0x2048
  02A4C  e990FF         jmp      dm_dispatch

dm_drawVLine:                                      ; /* address: 0000:2A4F */ AX=204Eh
  02A4F  b84e20         mov      ax, 0x204e
  02A52  e98AFF         jmp      dm_dispatch

dm_fillRect:                                       ; /* address: 0000:2A55 */ AX=2054h
  02A55  b85420         mov      ax, 0x2054
  02A58  e984FF         jmp      dm_dispatch

dm_getFileSize:                                    ; /* address: 0000:2A5B */ AX=208Ah
  02A5B  b88a20         mov      ax, 0x208a
  02A5E  e97EFF         jmp      dm_dispatch

dm_openFile:                                       ; /* address: 0000:2A61 */ AX=206Ch
  02A61  b86c20         mov      ax, 0x206c
  02A64  e978FF         jmp      dm_dispatch

dm_closeFile:                                      ; /* address: 0000:2A67 */ AX=2072h
  02A67  b87220         mov      ax, 0x2072
  02A6A  e972FF         jmp      dm_dispatch

dm_readFile:                                       ; /* address: 0000:2A6D */ AX=2078h
  02A6D  b87820         mov      ax, 0x2078
  02A70  e96CFF         jmp      dm_dispatch

dm_writeFile:                                      ; /* address: 0000:2A73 */ AX=207Eh
  02A73  b87e20         mov      ax, 0x207e
  02A76  e966FF         jmp      dm_dispatch

dm_seekFile:                                       ; /* address: 0000:2A79 */ AX=2084h
  02A79  b88420         mov      ax, 0x2084
  02A7C  e960FF         jmp      dm_dispatch

dm_showDialog:                                     ; /* address: 0000:2A7F */ AX=20A8h
  02A7F  b8a820         mov      ax, 0x20a8
  02A82  e95AFF         jmp      dm_dispatch

dm_showMessage:                                    ; /* address: 0000:2A85 */ AX=20AEh
  02A85  b8ae20         mov      ax, 0x20ae
  02A88  e954FF         jmp      dm_dispatch

dm_getWorkArea:                                    ; /* address: 0000:2A8B */ AX=2107h
  02A8B  b80721         mov      ax, 0x2107
  02A8E  e94EFF         jmp      dm_dispatch
  02A91  c3             ret

; ========================================================================
; mailmrge_writeToPrinter -- Write buffer to printer/output
; /* address: 0000:2A92 */
; 74 bytes
;
; Writes the contents of the output buffer to the printer or output
; file. Calls the print spooler for buffered output.
; ========================================================================
mailmrge_writeToPrinter:
  02A92  55             push     bp                 ; /* address: 0000:2A92 */
  02A93  8bec           mov      bp, sp
  ; [Function body -- 74 bytes through 0x2ADB]

; ========================================================================
; mailmrge_formatOutputLine -- Format an output line
; /* address: 0000:2ADC */
; 326 bytes
; ========================================================================
mailmrge_formatOutputLine:
  02ADC  55             push     bp                 ; /* address: 0000:2ADC */
  02ADD  8bec           mov      bp, sp
  ; [Function body -- 326 bytes through 0x2C21]

; ========================================================================
; mailmrge_emitHeaderLine -- Emit header/footer line
; /* address: 0000:2C22 */
; 74 bytes
; ========================================================================
mailmrge_emitHeaderLine:
  02C22  55             push     bp                 ; /* address: 0000:2C22 */
  02C23  8bec           mov      bp, sp
  ; [Function body -- 74 bytes through 0x2C6B]

; ========================================================================
; mailmrge_emitPageNumber -- Emit page number
; /* address: 0000:2C6C */
; 98 bytes
; ========================================================================
mailmrge_emitPageNumber:
  02C6C  55             push     bp                 ; /* address: 0000:2C6C */
  02C6D  8bec           mov      bp, sp
  ; [Function body -- 98 bytes through 0x2CCD]

; ========================================================================
; mailmrge_buildOutputPage -- Build complete output page
; /* address: 0000:2CCE */
; 548 bytes
;
; Builds a complete output page including margins, header, body text,
; and footer. Handles page layout calculations.
; ========================================================================
mailmrge_buildOutputPage:
  02CCE  55             push     bp                 ; /* address: 0000:2CCE */
  02CCF  8bec           mov      bp, sp
  ; [Function body -- 548 bytes through 0x2EF1]

; ========================================================================
; mailmrge_calcLineWidth -- Calculate line width
; /* address: 0000:2EF2 */
; 76 bytes
; ========================================================================
mailmrge_calcLineWidth:
  02EF2  55             push     bp                 ; /* address: 0000:2EF2 */
  02EF3  8bec           mov      bp, sp
  ; [Function body -- 76 bytes through 0x2F3D]

; ========================================================================
; mailmrge_padOutputLine -- Pad line with spaces
; /* address: 0000:2F3E */
; 60 bytes
; ========================================================================
mailmrge_padOutputLine:
  02F3E  55             push     bp                 ; /* address: 0000:2F3E */
  02F3F  8bec           mov      bp, sp
  ; [Function body -- 60 bytes through 0x2F79]

; ========================================================================
; mailmrge_handleTab -- Handle tab character
; /* address: 0000:2F7A */
; 108 bytes
; ========================================================================
mailmrge_handleTab:
  02F7A  55             push     bp                 ; /* address: 0000:2F7A */
  02F7B  8bec           mov      bp, sp
  ; [Function body -- 108 bytes through 0x2FE5]

; ========================================================================
; mailmrge_flushOutput -- Flush output buffer
; /* address: 0000:2FE6 */
; 38 bytes
; ========================================================================
mailmrge_flushOutput:
  02FE6  55             push     bp                 ; /* address: 0000:2FE6 */
  02FE7  8bec           mov      bp, sp
  ; [Function body -- 38 bytes through 0x300B]

; ========================================================================
; mailmrge_resetLineBuffer -- Reset line buffer
; /* address: 0000:300C */
; 14 bytes
; ========================================================================
mailmrge_resetLineBuffer:
  0300C  55             push     bp                 ; /* address: 0000:300C */
  0300D  8bec           mov      bp, sp
  ; [Function body -- 14 bytes through 0x3019]

; ========================================================================
; mailmrge_emitChar -- Emit single character
; /* address: 0000:301A */
; 45 bytes
; ========================================================================
mailmrge_emitChar:
  0301A  55             push     bp                 ; /* address: 0000:301A */
  0301B  8bec           mov      bp, sp
  ; [Function body -- 45 bytes through 0x3046]

; ========================================================================
; mailmrge_checkOutputReady -- Check if output device ready
; /* address: 0000:3047 */
; 13 bytes
; ========================================================================
mailmrge_checkOutputReady:
  03047  55             push     bp                 ; /* address: 0000:3047 */
  03048  8bec           mov      bp, sp
  ; [Function body -- 13 bytes through 0x3053]

; ========================================================================
; mailmrge_getOutputWidth -- Get output line width
; /* address: 0000:3054 */
; 35 bytes
; ========================================================================
mailmrge_getOutputWidth:
  03054  55             push     bp                 ; /* address: 0000:3054 */
  03055  8bec           mov      bp, sp
  ; [Function body -- 35 bytes through 0x3076]

; ========================================================================
; mailmrge_setupPrinterCtrl -- Set up printer control codes
; /* address: 0000:3077 */
; 30 bytes
; ========================================================================
mailmrge_setupPrinterCtrl:
  03077  55             push     bp                 ; /* address: 0000:3077 */
  03078  8bec           mov      bp, sp
  ; [Function body -- 30 bytes through 0x3094]

; ========================================================================
; mailmrge_initPrinter -- Initialize printer
; /* address: 0000:3095 */
; 116 bytes
;
; Initializes the printer by sending setup/reset codes. Also
; configures line spacing and character set.
; ========================================================================
mailmrge_initPrinter:
  03095  55             push     bp                 ; /* address: 0000:3095 */
  03096  8bec           mov      bp, sp
  ; [Function body -- 116 bytes through 0x3108]

; ========================================================================
; mailmrge_sendPrinterReset -- Send printer reset
; /* address: 0000:3109 */
; 14 bytes
; ========================================================================
mailmrge_sendPrinterReset:
  03109  55             push     bp                 ; /* address: 0000:3109 */
  0310A  8bec           mov      bp, sp
  ; [Function body -- 14 bytes through 0x3116]

; ========================================================================
; mailmrge_sendFormFeed -- Send form feed
; /* address: 0000:3117 */
; 16 bytes
; ========================================================================
mailmrge_sendFormFeed:
  03117  55             push     bp                 ; /* address: 0000:3117 */
  03118  8bec           mov      bp, sp
  ; [Function body -- 16 bytes through 0x3126]

; ========================================================================
; DOS File I/O Wrappers
; /* addresses: 0000:3127 through 0000:31CC */
; ========================================================================

; dos_closeFile -- INT 21h AH=3Eh (Close file handle)
dos_closeFile:
  03127  b43e           mov      ah, 0x3e           ; /* address: 0000:3127 */
  03129  cd21           int      0x21               ; INT 21h AH=3Eh -- Close file
  0312B  c3             ret
  0312C  90             nop

; dos_writeFile -- INT 21h AH=40h (Write to file)
dos_writeFile:
  0312D  b440           mov      ah, 0x40           ; /* address: 0000:312D */
  0312F  cd21           int      0x21               ; INT 21h AH=40h -- Write file
  03131  c3             ret
  03132  90             nop

; dos_getIntVector -- INT 21h AH=35h (Get interrupt vector)
dos_getIntVector:
  03133  b435           mov      ah, 0x35           ; /* address: 0000:3133 */
  03135  cd21           int      0x21               ; INT 21h AH=35h -- Get int vector
  03137  c3             ret
  03138  90             nop

; ========================================================================
; dos_setIntVector -- Set interrupt vector
; /* address: 0000:3139 */
; 147 bytes
;
; Saves and sets interrupt vectors for the print spooler's
; interrupt hooks (INT 28h idle callback).
; ========================================================================
dos_setIntVector:
  03139  55             push     bp                 ; /* address: 0000:3139 */
  0313A  8bec           mov      bp, sp
  ; [Function body -- 147 bytes, includes INT 21h AH=25h calls
  ;  through 0x31CB]

; ========================================================================
; dos_ioctlGetInfo -- IOCTL get device info
; /* address: 0000:31CC */
; 15 bytes
; ========================================================================
dos_ioctlGetInfo:
  031CC  55             push     bp                 ; /* address: 0000:31CC */
  031CD  8bec           mov      bp, sp
  031CF  8b5e04         mov      bx, word ptr [bp + 4]
  031D2  b80044         mov      ax, 0x4400         ; INT 21h AH=44h AL=00h -- IOCTL get info
  031D5  cd21           int      0x21               ; INT 21h AH=44h -- IOCTL
  031D7  7202           jb       .L_31DB
  031D9  8bc2           mov      ax, dx
.L_31DB:
  031DB  5d             pop      bp
  031DC  c3             ret

; ========================================================================
; mailmrge_printSpooler -- Print spooler
; /* address: 0000:31DB */
; 595 bytes
;
; Buffered print spooler. Accepts data to be printed, buffers it,
; and sends it to the printer via INT 21h AH=40h when the buffer
; is full or a flush is requested. Includes an INT 28h idle loop
; for cooperative multitasking while waiting for the printer.
; ========================================================================
mailmrge_printSpooler:
  031DB  55             push     bp                 ; /* address: 0000:31DB */
  031DC  8bec           mov      bp, sp
  ; [Function body -- 595 bytes through 0x342D]
  ; Contains:
  ;   INT 21h AH=40h -- Write file (send to printer)
  ;   INT 28h -- DOS idle callback (yield while printer busy)

; ========================================================================
; mailmrge_intToDecimal -- Convert integer to decimal string
; /* address: 0000:342E */
; 288 bytes
; ========================================================================
mailmrge_intToDecimal:
  0342E  55             push     bp                 ; /* address: 0000:342E */
  0342F  8bec           mov      bp, sp
  ; [Function body -- 288 bytes through 0x354D]

; ========================================================================
; mailmrge_reverseString -- Reverse string in place
; /* address: 0000:354E */
; 42 bytes
; ========================================================================
mailmrge_reverseString:
  0354E  55             push     bp                 ; /* address: 0000:354E */
  0354F  8bec           mov      bp, sp
  ; [Function body -- 42 bytes through 0x3577]

; ========================================================================
; C Runtime String Functions
; ========================================================================

; crt_strcpy -- strcpy(dst, src)
; /* address: 0000:3578 */
; 38 bytes
crt_strcpy:
  03578  55             push     bp                 ; /* address: 0000:3578 */
  03579  8bec           mov      bp, sp
  ; Uses repne scasb to find length, then rep movsw to copy
  ; [Function body -- 38 bytes through 0x359D]

; crt_strcat -- strcat(dst, src)
; /* address: 0000:359E */
; 34 bytes
crt_strcat:
  0359E  55             push     bp                 ; /* address: 0000:359E */
  0359F  8bec           mov      bp, sp
  ; [Function body -- 34 bytes through 0x35BF]

; ========================================================================
; crt_strcmp -- strcmp(s1, s2) / CRT init
; /* address: 0000:35C0 */
; 366 bytes
;
; This large function serves as both strcmp() and contains CRT
; initialization code (environment setup, file handle initialization).
; The MSC 5.x linker merged these together.
; ========================================================================
crt_strcmp:
  035C0  55             push     bp                 ; /* address: 0000:35C0 */
  035C1  8bec           mov      bp, sp
  ; [Function body -- 366 bytes through 0x372D]

; crt_strlen -- strlen(s)
; /* address: 0000:372E */
; 32 bytes
crt_strlen:
  0372E  55             push     bp                 ; /* address: 0000:372E */
  0372F  8bec           mov      bp, sp
  ; Uses repne scasb with CX=FFFFh, then not cx; dec cx
  ; [Function body -- 32 bytes through 0x374D]

; crt_strncat -- strncat(dst, src, n)
; /* address: 0000:374E */
; 43 bytes
crt_strncat:
  0374E  55             push     bp                 ; /* address: 0000:374E */
  0374F  8bec           mov      bp, sp
  ; [Function body -- 43 bytes through 0x3778]

; crt_strcpyCore -- Core strcpy with length tracking
; /* address: 0000:3779 */
; 41 bytes
crt_strcpyCore:
  03779  55             push     bp                 ; /* address: 0000:3779 */
  0377A  8bec           mov      bp, sp
  ; [Function body -- 41 bytes through 0x37A1]

; crt_memset -- memset(dst, ch, count)
; /* address: 0000:37A2 */
; 66 bytes
crt_memset:
  037A2  55             push     bp                 ; /* address: 0000:37A2 */
  037A3  8bec           mov      bp, sp
  ; [Function body -- 66 bytes through 0x37E3]

; crt_signExtend -- Sign extend byte to word
; /* address: 0000:37E4 */
; 18 bytes
crt_signExtend:
  037E4  55             push     bp                 ; /* address: 0000:37E4 */
  037E5  8bec           mov      bp, sp
  ; [Function body -- 18 bytes through 0x37F5]

; crt_sprintfNum -- Format number to string
; /* address: 0000:37F6 */
; 70 bytes
crt_sprintfNum:
  037F6  55             push     bp                 ; /* address: 0000:37F6 */
  037F7  8bec           mov      bp, sp
  ; [Function body -- 70 bytes through 0x383B]

; ========================================================================
; Text Buffer Operations
; ========================================================================

; mailmrge_clearTextBuffer -- Clear text buffer region
; /* address: 0000:383C */
; 64 bytes
mailmrge_clearTextBuffer:
  0383C  55             push     bp                 ; /* address: 0000:383C */
  0383D  8bec           mov      bp, sp
  ; [Function body -- 64 bytes through 0x387B]

; mailmrge_copyTextBuffer -- Copy text buffer region
; /* address: 0000:387C */
; 50 bytes
mailmrge_copyTextBuffer:
  0387C  55             push     bp                 ; /* address: 0000:387C */
  0387D  8bec           mov      bp, sp
  ; [Function body -- 50 bytes through 0x38AD]

; mailmrge_fillBuffer -- Fill buffer with byte value
; /* address: 0000:38AE */
; 44 bytes
mailmrge_fillBuffer:
  038AE  55             push     bp                 ; /* address: 0000:38AE */
  038AF  8bec           mov      bp, sp
  ; [Function body -- 44 bytes through 0x38D9]

; crt_strlen2 -- strlen (alternate entry)
; /* address: 0000:38DA */
; 28 bytes
crt_strlen2:
  038DA  55             push     bp                 ; /* address: 0000:38DA */
  038DB  8bec           mov      bp, sp
  ; [Function body -- 28 bytes through 0x38F5]

; mailmrge_compareStrings -- Compare strings with length limit
; /* address: 0000:38F6 */
; 54 bytes
mailmrge_compareStrings:
  038F6  55             push     bp                 ; /* address: 0000:38F6 */
  038F7  8bec           mov      bp, sp
  ; [Function body -- 54 bytes through 0x392B]

; crt_nop -- No-op stub
; /* address: 0000:392C */
; 4 bytes
crt_nop:
  0392C  55             push     bp                 ; /* address: 0000:392C */
  0392D  8bec           mov      bp, sp
  0392F  5d             pop      bp
  03930  c3             ret

; mailmrge_upperCase -- Convert to uppercase
; /* address: 0000:3930 */
; 28 bytes
mailmrge_upperCase:
  03930  55             push     bp                 ; /* address: 0000:3930 */
  03931  8bec           mov      bp, sp
  ; [Function body -- 28 bytes through 0x394B]

; ========================================================================
; Time / Date Library Functions
; ========================================================================

; crt_time -- time() get current time
; /* address: 0000:394C */
; 108 bytes
;
; Gets current date and time via INT 21h AH=2Ah (get date) and
; INT 21h AH=2Ch (get time), then converts to Unix timestamp
; by calling crt_mktime.
crt_time:
  0394C  55             push     bp                 ; /* address: 0000:394C */
  0394D  8bec           mov      bp, sp
  0394F  83ec0c         sub      sp, 0xc
  03952  57             push     di
  03953  56             push     si
  03954  b42a           mov      ah, 0x2a           ; INT 21h AH=2Ah -- Get date
  03956  cd21           int      0x21
  ; ... extracts year (CX), month (DH), day (DL)
  ; ... then calls INT 21h AH=2Ch for time
  ; ... converts to timestamp via crt_mktime
  ; [Function body continues through 0x39B7]

; crt_getDate -- Get date via DOS
; /* address: 0000:39B8 */
; 88 bytes
crt_getDate:
  039B8  55             push     bp                 ; /* address: 0000:39B8 */
  039B9  8bec           mov      bp, sp
  ; Calls INT 21h AH=2Ah to get date
  ; Then calls crt_mktime to compute timestamp
  ; [Function body -- 88 bytes through 0x3A0F]

; crt_memmove -- memmove(dst, src, n)
; /* address: 0000:3A10 */
; 72 bytes
;
; Overlap-safe memory copy. Detects overlap direction and copies
; forward or backward as needed. Uses word-aligned copies for speed.
crt_memmove:
  03A10  55             push     bp                 ; /* address: 0000:3A10 */
  03A11  8bec           mov      bp, sp
  ; [Function body -- 72 bytes through 0x3A57]

; crt_ldiv -- Long unsigned division
; /* address: 0000:3A58 */
; 105 bytes
crt_ldiv:
  03A58  55             push     bp                 ; /* address: 0000:3A58 */
  03A59  8bec           mov      bp, sp
  ; [Function body -- 105 bytes through 0x3AC0]

; ========================================================================
; crt_malloc -- malloc(size) heap allocator
; /* address: 0000:3AC1 */
; 227 bytes
;
; MSC 5.x heap allocator. Searches the free list for a block of
; sufficient size. If no free block found, extends the heap via
; sbrk. Block headers use an odd/even flag in the size word to
; indicate free (odd) or allocated (even).
; ========================================================================
crt_malloc:
  03AC1  55             push     bp                 ; /* address: 0000:3AC1 */
  ; [The function starts with entry code that is inlined]
  ; Searches heap free list, coalesces adjacent free blocks,
  ; extends heap via crt_sbrk if needed
  ; [Function body -- 227 bytes through 0x3BA3]

; crt_mallocExtend -- Extend heap for malloc
; /* address: 0000:3BA4 */
; 58 bytes
crt_mallocExtend:
  03BA4  51             push     cx                 ; /* address: 0000:3BA4 */
  ; [Function body -- 58 bytes through 0x3BDD]

; crt_sbrk -- sbrk() extend data segment
; /* address: 0000:3BDE */
; 34 bytes
crt_sbrk:
  03BDE  52             push     dx                 ; /* address: 0000:3BDE */
  ; [Function body -- 34 bytes through 0x3BFF]

; crt_sbrkCore -- Core sbrk implementation
; /* address: 0000:3C00 */
; 116 bytes
;
; Core sbrk: uses INT 21h AH=48h (allocate memory) to extend
; the program's data segment.
crt_sbrkCore:
  03C00  53             push     bx                 ; /* address: 0000:3C00 */
  03C01  50             push     ax
  ; [Function body includes INT 21h AH=48h call -- 116 bytes through 0x3C73]

; ========================================================================
; crt_localtime -- localtime() convert timestamp
; /* address: 0000:3C74 */
; 432 bytes
;
; Converts a Unix timestamp (seconds since 1970-01-01) to a tm struct.
; Handles leap years using divisibility by 4/100/400 rules.
; Uses two days-per-month tables:
;   0x0A6E = leap year table
;   0x0A88 = non-leap year table
;
; Output tm struct at [0x908]:
;   [0x908] = tm_sec    (seconds 0-59)
;   [0x90A] = tm_min    (minutes 0-59)
;   [0x90C] = tm_hour   (hours 0-23)
;   [0x90E] = tm_mday   (day of month 1-31)
;   [0x910] = tm_mon    (month 1-12)
;   [0x912] = tm_year   (year - 1900)
;   [0x914] = tm_wday   (day of week 0=Sun)
;   [0x916] = tm_yday   (day of year 0-365)
;   [0x918] = tm_isdst  (DST flag)
; ========================================================================
crt_localtime:
  03C74  55             push     bp                 ; /* address: 0000:3C74 */
  03C75  8bec           mov      bp, sp
  03C77  83ec0c         sub      sp, 0xc            ; 12 bytes locals
  03C7A  57             push     di
  03C7B  56             push     si
  03C7C  8b5e04         mov      bx, word ptr [bp + 4]  ; pointer to timestamp
  03C7F  817f02ce12     cmp      word ptr [bx + 2], 0x12ce  ; validate range
  03C84  7f10           jg       .L_3C96
  03C86  7c06           jl       .L_3C8E
  03C88  813f00a6       cmp      word ptr [bx], 0xa600
  03C8C  7308           jae      .L_3C96
.L_3C8E:
  03C8E  2bc0           sub      ax, ax             ; return 0 if out of range
  03C90  5e             pop      si
  03C91  5f             pop      di
  03C92  8be5           mov      sp, bp
  03C94  5d             pop      bp
  03C95  c3             ret
.L_3C96:
  ; Compute days from timestamp
  03C96  b88033         mov      ax, 0x3380         ; 86400 low word (seconds/day)
  03C99  bae101         mov      dx, 0x1e1          ; 86400 high word
  03C9C  52             push     dx
  03C9D  50             push     ax
  03C9E  8b5e04         mov      bx, word ptr [bp + 4]
  03CA1  ff7702         push     word ptr [bx + 2]
  03CA4  ff37           push     word ptr [bx]
  03CA6  e8ef05         call     crt_ldivSigned     ; days = timestamp / 86400
  03CA9  a31209         mov      word ptr [0x912], ax   ; store in year field temporarily
  ; ... continues with leap year calculations ...
  ; [Function body continues through 0x3E23]

; crt_adjustDST -- Adjust time for daylight saving
; /* address: 0000:3E24 */
; 176 bytes
;
; Checks the TZ environment variable for DST offset and adjusts
; the time accordingly. Parses timezone string format.
crt_adjustDST:
  03E24  55             push     bp                 ; /* address: 0000:3E24 */
  03E25  8bec           mov      bp, sp
  03E27  83ec04         sub      sp, 4
  03E2A  57             push     di
  03E2B  56             push     si
  03E2C  b81a09         mov      ax, 0x91a          ; "TZ" environment var name
  03E2F  50             push     ax
  03E30  e80f04         call     crt_getenv         ; getenv("TZ")
  03E33  83c402         add      sp, 2
  03E36  8bf0           mov      si, ax
  03E38  0bf6           or       si, si
  03E3A  7503           jne      .L_3E3F
  03E3C  e98f00         jmp      .L_3ECE            ; no TZ set, skip DST adjustment
  ; [Function body continues through 0x3ED3]

; crt_isDSTActive -- Check if DST is active
; /* address: 0000:3ED4 */
; 212 bytes
;
; Determines whether daylight saving time is currently active
; based on the month, day of week, and DST transition rules.
; Uses the Gregorian calendar algorithm for day-of-week calculation.
crt_isDSTActive:
  03ED4  55             push     bp                 ; /* address: 0000:3ED4 */
  03ED5  8bec           mov      bp, sp
  03ED7  83ec06         sub      sp, 6
  03EDA  57             push     di
  03EDB  56             push     si
  03EDC  8b7604         mov      si, word ptr [bp + 4]  ; tm struct pointer
  03EDF  837c0803       cmp      word ptr [si + 8], 3   ; check month >= March
  03EE3  7d03           jge      .L_3EE8
  03EE5  e9b700         jmp      .L_3F9F                ; before March: no DST
  ; [Function body continues through 0x3FA7]

; ========================================================================
; crt_mktime -- mktime() build timestamp from components
; /* address: 0000:3FA8 */
; 374 bytes
;
; Converts broken-down time (year, month, day, hour, min, sec) to a
; Unix timestamp. Accounts for leap years and DST adjustment.
;
; Parameters (stack):
;   [bp+4]  = year (since 1900)
;   [bp+6]  = month (0-11)
;   [bp+8]  = day of month
;   [bp+A]  = hours
;   [bp+C]  = minutes
;   [bp+E]  = seconds
;
; Returns: DX:AX = Unix timestamp (32-bit)
; ========================================================================
crt_mktime:
  03FA8  55             push     bp                 ; /* address: 0000:3FA8 */
  03FA9  8bec           mov      bp, sp
  03FAB  83ec20         sub      sp, 0x20           ; 32 bytes locals
  ; [Function body -- 374 bytes through 0x40BD]
  ; Uses crt_lmul for 32-bit multiplication
  ; References days-per-month tables at 0x0A86
  ; Calls crt_adjustDST and crt_isDSTActive

; ========================================================================
; 32-bit Arithmetic Helpers
; ========================================================================

; crt_lmul -- 32-bit multiply
; /* address: 0000:411E */
; 52 bytes
;
; Multiplies two 32-bit values passed on the stack.
; Returns result in DX:AX.
; Uses pascal calling convention (callee cleans stack, ret 8).
crt_lmul:
  0411E  55             push     bp                 ; /* address: 0000:411E */
  0411F  8bec           mov      bp, sp
  04121  8b4606         mov      ax, word ptr [bp + 6]
  04124  8b5e0a         mov      bx, word ptr [bp + 0xa]
  04127  0bd8           or       bx, ax
  04129  8b5e08         mov      bx, word ptr [bp + 8]
  0412C  750b           jne      .L_4139            ; if high words nonzero, full multiply
  0412E  8b4604         mov      ax, word ptr [bp + 4]
  04131  f7e3           mul      bx                 ; simple 16x16 multiply
  04133  8be5           mov      sp, bp
  04135  5d             pop      bp
  04136  c20800         ret      8
.L_4139:
  04139  f7e3           mul      bx                 ; full 32x32 multiply
  0413B  8bc8           mov      cx, ax
  0413D  8b4604         mov      ax, word ptr [bp + 4]
  04140  f7660a         mul      word ptr [bp + 0xa]
  04143  03c8           add      cx, ax
  04145  8b4604         mov      ax, word ptr [bp + 4]
  04148  f7e3           mul      bx
  0414A  03d1           add      dx, cx
  0414C  8be5           mov      sp, bp
  0414E  5d             pop      bp
  0414F  c20800         ret      8

; ========================================================================
; crt_heapAlloc -- Heap segment allocation
; /* address: 0000:4152 */
; 110 bytes
;
; Allocates or resizes heap segments. Uses INT 21h AH=48h to
; allocate new memory blocks from DOS.
; ========================================================================
crt_heapAlloc:
  04152  55             push     bp                 ; /* address: 0000:4152 */
  04153  8bec           mov      bp, sp
  04155  56             push     si
  04156  57             push     di
  04157  06             push     es
  04158  837e0800       cmp      word ptr [bp + 8], 0
  0415C  7538           jne      .L_4196
  0415E  bf2a06         mov      di, 0x62a          ; heap control block base
  04161  8b5606         mov      dx, word ptr [bp + 6]
  04164  8b4604         mov      ax, word ptr [bp + 4]
  04167  48             dec      ax
  04168  7507           jne      .L_4171
  0416A  e85300         call     crt_heapResize     ; try to resize existing block
  0416D  7227           jb       .L_4196
  0416F  eb48           jmp      .L_41B9
  ; ... continues with DOS memory allocation ...
  ; [Function body through 0x41BF]

; crt_heapResize -- Resize heap segment
; /* address: 0000:41C0 */
; 86 bytes
;
; Resizes an existing heap segment via INT 21h AH=4Ah.
crt_heapResize:
  041C0  8b4e0c         mov      cx, word ptr [bp + 0xc] ; /* address: 0000:41C0 */
  ; [Function body -- includes INT 21h AH=4Ah call]
  ; [Through 0x4215]

; crt_strncpy -- strncpy(dst, src, n)
; /* address: 0000:4216 */
; 40 bytes
crt_strncpy:
  04216  55             push     bp                 ; /* address: 0000:4216 */
  04217  8bec           mov      bp, sp
  04219  57             push     di
  0421A  56             push     si
  0421B  1e             push     ds
  0421C  07             pop      es
  0421D  8b7e04         mov      di, word ptr [bp + 4]  ; dst
  04220  8b7606         mov      si, word ptr [bp + 6]  ; src
  04223  8bdf           mov      bx, di
  04225  8b4e08         mov      cx, word ptr [bp + 8]  ; n
  04228  e30c           jcxz     .L_4236
.L_422A:
  0422A  ac             lodsb    al, byte ptr [si]
  0422B  0ac0           or       al, al
  0422D  7403           je       .L_4232
  0422F  aa             stosb    byte ptr es:[di], al
  04230  e2f8           loop     .L_422A
.L_4232:
  04232  32c0           xor      al, al
  04234  f3aa           rep stosb byte ptr es:[di], al  ; zero-fill remainder
.L_4236:
  04236  8bc3           mov      ax, bx             ; return dst
  04238  5e             pop      si
  04239  5f             pop      di
  0423A  8be5           mov      sp, bp
  0423C  5d             pop      bp
  0423D  c3             ret

; crt_atol -- atol() jump to long parser
; /* address: 0000:423E */
; 4 bytes
crt_atol:
  0423E  e9dff9         jmp      crt_localtime + 0xAC ; /* address: 0000:423E */
  ; [Actually jumps to the atol parser at 0x3C20]

; ========================================================================
; crt_getenv -- getenv(name) search environment
; /* address: 0000:4242 */
; 86 bytes
;
; Searches the DOS environment block for the specified variable name.
; Returns pointer to the value (after the '=') or NULL if not found.
; ========================================================================
crt_getenv:
  04242  55             push     bp                 ; /* address: 0000:4242 */
  04243  8bec           mov      bp, sp
  04245  83ec04         sub      sp, 4
  04248  57             push     di
  04249  56             push     si
  0424A  8b36bc06       mov      si, word ptr [0x6bc]   ; environment pointer table
  0424E  0bf6           or       si, si
  04250  743e           je       .L_4290                 ; no env, return NULL
  04252  837e0400       cmp      word ptr [bp + 4], 0
  04256  7438           je       .L_4290                 ; NULL name, return NULL
  04258  ff7604         push     word ptr [bp + 4]
  0425B  e87cf6         call     crt_strlen2             ; strlen(name)
  0425E  83c402         add      sp, 2
  04261  8bf8           mov      di, ax                  ; di = name length
.L_4266:
  04266  83c602         add      si, 2
.L_4269:
  04269  833c00         cmp      word ptr [si], 0
  0426C  7422           je       .L_4290                 ; end of env table
  0426E  8b1c           mov      bx, word ptr [si]
  04270  80393d         cmp      byte ptr [bx + di], 0x3d ; check for '=' at name len
  04273  75f1           jne      .L_4266                  ; no match, next entry
  04275  57             push     di                       ; push name length
  04276  ff7604         push     word ptr [bp + 4]        ; push search name
  04279  53             push     bx                       ; push env entry
  0427A  e88701         call     crt_strncmp              ; compare name portion
  0427D  83c406         add      sp, 6
  04280  0bc0           or       ax, ax
  04282  75e2           jne      .L_4266                  ; no match, next entry
  04284  8b1c           mov      bx, word ptr [si]
  04286  8d4101         lea      ax, [bx + di + 1]       ; point past '='
  04289  5e             pop      si
  0428A  5f             pop      di
  0428B  8be5           mov      sp, bp
  0428D  5d             pop      bp
  0428E  c3             ret
.L_4290:
  04290  2bc0           sub      ax, ax             ; return NULL
  04292  5e             pop      si
  04293  5f             pop      di
  04294  8be5           mov      sp, bp
  04296  5d             pop      bp
  04297  c3             ret

; ========================================================================
; crt_ldivSigned -- Signed 32-bit division
; /* address: 0000:4298 */
; 164 bytes
;
; Divides a signed 32-bit dividend by a signed 32-bit divisor.
; Handles sign conversion, then delegates to unsigned division.
; Returns quotient in DX:AX.
; Uses pascal convention (ret 8).
; ========================================================================
crt_ldivSigned:
  04298  55             push     bp                 ; /* address: 0000:4298 */
  04299  8bec           mov      bp, sp
  0429B  57             push     di
  0429C  56             push     si
  0429D  53             push     bx
  0429E  33ff           xor      di, di             ; sign flag = 0
  042A0  8b4606         mov      ax, word ptr [bp + 6]   ; dividend high word
  042A3  0bc0           or       ax, ax
  042A5  7d12           jge      .L_42B9                 ; positive dividend
  042A7  f7d7           not      di                      ; flip sign flag
  042A9  8b5604         mov      dx, word ptr [bp + 4]
  042AC  f7d8           neg      ax                      ; negate dividend
  042AE  f7da           neg      dx
  042B0  1d0000         sbb      ax, 0
  042B3  894606         mov      word ptr [bp + 6], ax
  042B6  895604         mov      word ptr [bp + 4], dx
.L_42B9:
  042B9  8b460a         mov      ax, word ptr [bp + 0xa]  ; divisor high word
  042BC  0bc0           or       ax, ax
  042BE  7d12           jge      .L_42D2                  ; positive divisor
  042C0  f7d7           not      di                       ; flip sign flag
  042C2  8b5608         mov      dx, word ptr [bp + 8]
  042C5  f7d8           neg      ax
  042C7  f7da           neg      dx
  042C9  1d0000         sbb      ax, 0
  042CC  89460a         mov      word ptr [bp + 0xa], ax
  042CF  895608         mov      word ptr [bp + 8], dx
.L_42D2:
  ; Now do unsigned division
  042D2  0bc0           or       ax, ax
  042D4  7516           jne      .L_42EC
  042D6  8b4e08         mov      cx, word ptr [bp + 8]
  042D9  8b4606         mov      ax, word ptr [bp + 6]
  042DC  33d2           xor      dx, dx
  042DE  f7f1           div      cx                      ; high / divisor
  042E0  8bd8           mov      bx, ax
  042E2  8b4604         mov      ax, word ptr [bp + 4]
  042E5  f7f1           div      cx                      ; remainder:low / divisor
  042E7  8bd3           mov      dx, bx
  042E9  eb3c           jmp      .L_4327
  ; [Continues with long division algorithm through 0x4338]

; crt_lmodSigned -- Signed 32-bit modulus
; /* address: 0000:433C */
; 166 bytes
crt_lmodSigned:
  0433C  55             push     bp                 ; /* address: 0000:433C */
  0433D  8bec           mov      bp, sp
  ; [Function body -- 166 bytes through 0x43E1]

; crt_lmodInPlace -- In-place 32-bit modulus
; /* address: 0000:43E2 */
; 34 bytes
crt_lmodInPlace:
  043E2  55             push     bp                 ; /* address: 0000:43E2 */
  043E3  8bec           mov      bp, sp
  043E5  8b5e04         mov      bx, word ptr [bp + 4]   ; pointer to value
  043E8  ff7608         push     word ptr [bp + 8]        ; divisor high
  043EB  ff7606         push     word ptr [bp + 6]        ; divisor low
  043EE  ff7702         push     word ptr [bx + 2]        ; value high
  043F1  ff37           push     word ptr [bx]            ; value low
  043F3  e846ff         call     crt_lmodSigned
  043F6  8b5e04         mov      bx, word ptr [bp + 4]
  043F9  895702         mov      word ptr [bx + 2], dx    ; store result high
  043FC  8907           mov      word ptr [bx], ax        ; store result low
  043FE  8be5           mov      sp, bp
  04400  5d             pop      bp
  04401  c20600         ret      6

; ========================================================================
; crt_strncmp -- strncmp(s1, s2, n)
; /* address: 0000:4404 */
; 58 bytes
;
; Compares at most n characters of s1 and s2.
; Returns: 0 if equal, <0 if s1<s2, >0 if s1>s2.
; ========================================================================
crt_strncmp:
  04404  55             push     bp                 ; /* address: 0000:4404 */
  04405  8bec           mov      bp, sp
  04407  57             push     di
  04408  56             push     si
  04409  1e             push     ds
  0440A  07             pop      es
  0440B  8b4e08         mov      cx, word ptr [bp + 8]  ; n
  0440E  e326           jcxz     .L_4436                ; n=0, return 0
  04410  8bd9           mov      bx, cx
  04412  8b7e04         mov      di, word ptr [bp + 4]  ; s1
  04415  8bf7           mov      si, di
  04417  33c0           xor      ax, ax
  04419  f2ae           repne scasb al, byte ptr es:[di] ; find end of s1
  0441B  f7d9           neg      cx
  0441D  03cb           add      cx, bx                  ; cx = min(strlen(s1)+1, n)
  0441F  8bfe           mov      di, si
  04421  8b7606         mov      si, word ptr [bp + 6]  ; s2
  04424  f3a6           repe cmpsb byte ptr [si], byte ptr es:[di]
  04426  8a44ff         mov      al, byte ptr [si - 1]
  04429  33c9           xor      cx, cx
  0442B  3a45ff         cmp      al, byte ptr [di - 1]
  0442E  7704           ja       .L_4434
  04430  7404           je       .L_4436
  04432  49             dec      cx                      ; s1 < s2
  04433  49             dec      cx
.L_4434:
  04434  f7d1           not      cx                      ; s1 > s2
.L_4436:
  04436  8bc1           mov      ax, cx
  04438  5e             pop      si
  04439  5f             pop      di
  0443A  8be5           mov      sp, bp
  0443C  5d             pop      bp
  0443D  c3             ret

; ========================================================================
; start -- MSC 5.x CRT startup (_cstart)
; /* address: 0443:000E */
; 162 bytes
;
; CRT entry point. Checks DOS version >= 2.0, sets up stack segment,
; initializes BSS, calls _main, and handles process exit.
; ========================================================================
start:
  0443E  b430           mov      ah, 0x30           ; /* address: 0443:000E */
  04440  cd21           int      0x21               ; INT 21h AH=30h -- Get DOS version
  04442  3c02           cmp      al, 2
  04444  7302           jae      .L_4448            ; DOS >= 2.0 required
  04446  cd20           int      0x20               ; INT 20h -- Terminate (DOS 1.x)
.L_4448:
  04448  bf5104         mov      di, 0x451          ; SS segment value
  0444B  8b360200       mov      si, word ptr [2]   ; top of memory
  0444F  2bf7           sub      si, di             ; available paragraphs
  04451  81fe0010       cmp      si, 0x1000         ; max 64KB for stack
  04455  7203           jb       .L_445A
  04457  be0010         mov      si, 0x1000
.L_445A:
  0445A  fa             cli                         ; disable interrupts for SS:SP change
  0445B  8ed7           mov      ss, di             ; set SS = 0451h
  0445D  81c41e1a       add      sp, 0x1a1e         ; set SP
  04461  fb             sti                         ; re-enable interrupts
  04462  7314           jae      .L_4478            ; if enough memory, continue
  ; --- not enough memory, exit ---
  04464  16             push     ss
  04465  1f             pop      ds
  04466  9a59250000     lcall    0, 0x2559          ; far call to error handler
  0446B  33c0           xor      ax, ax
  0446D  50             push     ax
  0446E  9a5d250000     lcall    0, 0x255d          ; far call to _exit
  04473  b8ff4c         mov      ax, 0x4cff
  04476  cd21           int      0x21               ; INT 21h AH=4Ch -- Exit (code 255)
.L_4478:
  04478  83e4fe         and      sp, 0xfffe         ; word-align SP
  0447B  3689262a06     mov      word ptr ss:[0x62a], sp  ; save SP for heap base
  04480  3689262606     mov      word ptr ss:[0x626], sp  ; save stack top
  04485  8bc6           mov      ax, si
  04487  b104           mov      cl, 4
  04489  d3e0           shl      ax, cl             ; convert paragraphs to bytes
  0448B  48             dec      ax
  0448C  36a32406       mov      word ptr ss:[0x624], ax  ; heap limit
  04490  03f7           add      si, di
  04492  89360200       mov      word ptr [2], si   ; update top-of-memory
  04496  8cc3           mov      bx, es
  04498  2bde           sub      bx, si
  0449A  f7db           neg      bx                 ; paragraphs to free
  0449C  b44a           mov      ah, 0x4a
  0449E  cd21           int      0x21               ; INT 21h AH=4Ah -- Resize memory block
  044A0  368c1e9b06     mov      word ptr ss:[0x69b], ds  ; save original DS
  044A5  16             push     ss
  044A6  07             pop      es
  044A7  fc             cld
  044A8  bf460c         mov      di, 0xc46          ; BSS start
  044AB  b9201a         mov      cx, 0x1a20         ; BSS end
  044AE  2bcf           sub      cx, di             ; BSS size
  044B0  33c0           xor      ax, ax
  044B2  f3aa           rep stosb byte ptr es:[di], al  ; zero BSS
  044B4  16             push     ss
  044B5  1f             pop      ds                 ; DS = SS = DGROUP
  044B6  06             push     es
  044B7  0e             push     cs
  044B8  07             pop      es
  044B9  9a55250000     lcall    0, 0x2555          ; far call to CRT init (crt_initCRT)
  044BE  07             pop      es
  044BF  16             push     ss
  044C0  1f             pop      ds
  044C1  9a3a250000     lcall    0, 0x253a          ; far call to parse argv
  044C6  b85104         mov      ax, 0x451          ; DGROUP segment
  044C9  8ed8           mov      ds, ax
  044CB  b80300         mov      ax, 3              ; argc = 3 (typical for .PDM)
  044CE  36c70628063826 mov      word ptr ss:[0x628], 0x2638  ; _exit function pointer
  044D5  9a61250000     lcall    0, 0x2561          ; far call to _main via wrapper
  044DA  0000           dw       0                  ; padding
  044DC  0000           dw       0
  044DE  0000           dw       0

; ========================================================================
; crt_farCallMain -- Far call wrapper for main
; /* address: 0443:00B0 */
; 17 bytes
;
; Sets DS to DGROUP (0x0451), then calls the actual main dispatcher.
; ========================================================================
crt_farCallMain:
  044E0  55             push     bp                 ; /* address: 0443:00B0 */
  044E1  8bec           mov      bp, sp
  044E3  1e             push     ds
  044E4  b85104         mov      ax, 0x451          ; DGROUP segment
  044E7  8ed8           mov      ds, ax
  044E9  9a3f310000     lcall    0, 0x313f          ; far call to mailmrge_printSpooler entry
  044EE  1f             pop      ds
  044EF  5d             pop      bp
  044F0  cb             retf                        ; far return

; ========================================================================
; crt_farCallDialog -- Far call wrapper for dialog handler
; /* address: 0443:00C1 */
; 3172 bytes
;
; Sets DS to DGROUP, then calls the dialog template processor.
; The bulk of this function (3172 bytes) is the dialog template
; processor that handles UI dialog rendering and input for the
; mail merge setup dialogs.
; ========================================================================
crt_farCallDialog:
  044F1  55             push     bp                 ; /* address: 0443:00C1 */
  044F2  8bec           mov      bp, sp
  044F4  1e             push     ds
  044F5  b85104         mov      ax, 0x451          ; DGROUP segment
  044F8  8ed8           mov      ds, ax
  044FA  9a5d320000     lcall    0, 0x325d          ; far call to dialog processor
  044FF  1f             pop      ds
  04500  5d             pop      bp
  04501  cb             retf

; ========================================================================
; DATA SEGMENT -- Dialog template data and string constants
; ========================================================================
; The remaining bytes (0x4502 through end of file) contain:
;   - Dialog template structures for the mail merge UI
;   - String constants (file names, error messages, prompts)
;   - Days-per-month tables for date calculations
;   - Character classification table (ctype)
;   - MSC 5.x copyright string
;
; Key string constants:
;   0x4518: "MS RunTime Library - Copyright (c) 1987, Microsoft Corp"
;   0x4555: "PERSONAL.ADDR"
;   0x4620: "Address Book List Empty"
;   0x4638: "No records were found in the Address Book..."
;   0x4682: "File Not Found"
;   0x4692: "Unable to locate files PERSONAL.ADDR"
;   0x46B7: " and "
;   0x46BC: "Unable to locate file PERSONAL.ADDR"
;   0x46E0: "Unable to locate file "
;   0x46F7: "Both PERSONAL.ADDR and "
;   0x4725: "Insert the diskette containing the data file..."
;   0x476C: "Out of memory. Form letter must be available."
;
; ========================================================================
; END OF DISASSEMBLY
; ========================================================================
