; ============================================================================
; DMVID.EXE - DeskMate 3.05 Video Configuration Utility
; Annotated Disassembly - Stage 3
; ============================================================================
;
; MZ Header:
;   File size:       16477 bytes (0x405d)
;   Header size:     512 bytes (0x200)
;   Code+data size:  15965 bytes (0x3e5d)
;   Entry point:     0000:060A (file offset 0x080a)
;   SS:SP:           042E:0800
;   Min alloc:       0x00c9 paragraphs (3216 bytes)
;   Relocations:     4
;
; Relocations:
;   035C:0038 -> file 0x37f8, value=0x0358
;   0000:0615 -> file 0x0815, value=0x0358
;   0000:06A0 -> file 0x08a0, value=0x0358
;   035C:01D6 -> file 0x3996, value=0x0358
;
; Compiler: Microsoft C 5.0, small memory model
;
; ============================================================================
; PROGRAM OVERVIEW
; ============================================================================
;
; DMVID.EXE is the DeskMate video driver configuration utility. It detects
; the installed video adapter and configures the appropriate .RES driver file
; in the DMCSR.CFG configuration file.
;
; Supported video modes:
;   AUTO - Automatic detection by DeskMate at runtime
;   VGA  - Video Graphics Array, 640x480 16 colors     -> DMVSVGA.RES
;   EGA  - Enhanced Graphics Adapter, 640x350 16 colors -> DMVSEGA.RES
;   MCGA - Multi Color Graphics Array, 640x480 2 colors -> DMVSMCGA.RES
;   CGA  - Color Graphics Adapter, 640x200 2 colors     -> DMVSCGA.RES
;   HERC - Hercules, 720x348 monochrome                 -> DMVSHERC.RES
;   1000 - Tandy 1000, 640x200 4 colors                 -> DMVS1000.RES
;   TC16 - Tandy Color, 640x200 16 colors               -> DMVSTC16.RES
;
; Configuration file: DMCSR.CFG
; Config sections: [DMRESCFG], [DMCONFIG]
; Config key: csr_config
; Driver name format: DMVS<mode>.RES
;
; Command line: DMVID [/AUTO | <mode_char> | <mode_name>] [config_path]
;   /AUTO       - Auto-detect and update without user interaction
;   <mode_char> - Single character selection (1-8)
;   <mode_name> - Full mode name (VGA, EGA, CGA, etc.)
;   config_path - Path to DMCSR.CFG directory
;
; ============================================================================
; FUNCTION INDEX (74 functions)
; ============================================================================
;
; --- Application Functions (18) ---
;   0010  _main                   - Entry point, parse args, dispatch
;   00CB  dmvid_buildConfigPath   - Build full path to DMCSR.CFG
;   0130  dmvid_interactiveMenu   - Display menu, get user selection
;   022A  dmvid_detectAdapter     - Open config, read/update adapter
;   0283  dmvid_selectByChar      - Map single char to mode index
;   0299  dmvid_selectByName      - Map mode name string to index
;   02DE  dmvid_applySelection    - Apply selection (wrapper)
;   02EC  dmvid_writeConfig       - Write updated config, retry loop
;   036D  dmvid_readConfigSection - Read [DMRESCFG]/[DMCONFIG] section
;   03E1  dmvid_promptForDisk     - Prompt user for disk/path
;   04A7  dmvid_readConfigValue   - Read config value from file stream
;   04E8  dmvid_updateConfigKey   - Find "csr_config" key and update
;   05B4  dmvid_writeConfigBytes  - Write buffer bytes to config stream
;   06BE  __closeFile             - Close file handle (CRT helper)
;   0772  dmvid_openConfigFile    - Open DMCSR.CFG via CRT
;   07D8  dmvid_showCurrentVideo  - Display current video driver (sprintf wrapper)
;   07F6  dmvid_readCurrentDriver - Read next byte from file stream (fgetc)
;   0898  dmvid_parseDriverName   - Allocate/init file buffer for stream
;   08FC  dmvid_searchConfigKey   - Write byte to file stream (fputc)
;
; --- MSC 5.0 C Runtime Functions (42) ---
;   060A  __astart                - CRT startup entry point
;   079C  _printf                 - Formatted print to stdout
;   0A92  _strcat                 - String concatenation
;   0AD2  _strcpy                 - String copy
;   0B04  _strlen                 - String length
;   0B20  _strupr / _strnicmp     - Uppercase / case-insensitive compare
;   0B5E  _getch                  - Read keyboard character (INT 21h/08)
;   0B76  _fseek                  - Seek within file stream
;   0E54  _rewind                 - Rewind file stream to beginning
;   0E86  _strncmp                - Compare strings with length
;   0EDE  _strnicmp               - Case-insensitive string compare
;   0F00  _strstr                 - Find substring in string
;   0F5C  _searchenv              - Search PATH for file
;   1008  _splitpath_helper       - Split semicolon-delimited path entry
;   104A  __cintDIV               - CRT init: DIV exception, file info
;   110E  _exit                   - CRT exit with cleanup
;   1125  __exit                  - CRT exit (internal)
;   116A  __closeNetworkHandle    - Close network/overlay handles
;   1197  __onexit_call           - Walk and call onexit function list
;   11A6  __atexit_call           - Walk and call atexit function list
;   11BA  __NMSG_WRITE            - Write runtime error message
;   11DA  __nullcheck             - Check for null pointer assignment
;   11FC  __setargv               - Parse command line into argc/argv
;   138A  __setenvp               - Set up environment pointer table
;   13F0  __flush                 - Flush single file stream buffer
;   141B  __write                 - Low-level write to file handle
;   1444  __flsbuf                - Flush all file stream buffers
;   1472  _fopen                  - Open file, return FILE* stream
;   1566  _printf_lock            - Lock stdout for printf
;   1614  _printf_unlock          - Unlock stdout after printf
;   16A2  __dosretax              - Call DOS and return AX (fileno)
;   170A  _vsprintf               - Format string into buffer (varargs)
;   1A9A  __fmt_scanString        - scanf/sscanf: scan %s/%c format
;   1B88  __fmt_scanNumber        - scanf/sscanf: scan %d/%x number
;   1D1A  __fmt_scanFloat         - scanf/sscanf: scan %f/%e float
;   1E58  __fmt_isDigit           - Check if char is digit for scanf
;   1E7C  __fmt_matchChar         - Match/skip literal char in scanf
;   1EBA  __fmt_getc              - Get next char from format stream
;   1EDE  __fmt_skipWhitespace    - Skip whitespace in format stream
;   1F14  __fmt_checkWidth        - Check remaining field width
;   1F32  __fmtout                - Core printf format engine
;   21F6  __fmt_outputString      - Output %s formatted string
;   232C  __fassign               - Assign float from string
;   241A  __fmt_outputLong        - Output formatted long integer
;   24BC  __fmt_mulAdd10          - Multiply-accumulate *10 helper
;   24FE  __fmt_mulAdd16          - Multiply-accumulate *16 helper
;   255C  __fmt_mulAddN           - General multiply-accumulate helper
;   25C4  __fmt_formatNumber      - Core number-to-string conversion
;   268A  __fmt_padLeft           - Left-pad number output
;   26A2  __fmt_padRight          - Right-pad number output
;   26CC  __fmt_outputChar        - Output single %c character
;   274C  __fmt_outputPercent     - Output %% literal percent
;   2776  __allocFileSlot         - Allocate FILE structure slot
;   27B2  _close                  - Close file descriptor
;   27D2  _lseek                  - Seek file descriptor
;   284C  _read                   - Read from file descriptor
;   2928  __write_fd              - Write buffer to file descriptor
;   29CE  __read_textmode         - Text-mode read (CR/LF handling)
;   2A50  __flsbuf_sync           - Sync buffer after flush
;   2A62  _malloc                 - Allocate heap memory
;   2AA8  _ltoa                   - Long integer to ASCII string
;   2AC4  _getenv                 - Get environment variable
;   2B1A  _isatty                 - Check if fd is a device
;   2B3E  __clearerr              - Clear stream error flags
;   2B4A  _ftell                  - Get current file position
;   2CC0  _access                 - Check file accessibility
;   2CE0  _getcwd_wrapper         - Get current working directory (wrapper)
;   2CF4  _getcwd                 - Get current working directory
;   2DA6  _unlink                 - Delete file
;   2DB4  __lseekEnd              - Seek to end of file, return size
;   2E58  __divmod32              - 32-bit division/modulus helper
;   2E8C  __brk                   - Adjust program break
;   2F38  __chkstk                - Stack probe / overflow check
;   2F4E  __sbrk_grow             - Grow data segment via INT 21h/4Ah
;   2FB0  __doserrno_set          - Set DOS errno from carry flag
;   2FB6  __errno_set             - Set C errno from DOS error
;   2FE4  __ioctl_getinfo         - Get device info via IOCTL
;   3016  __fmt_ungetc            - Push character back to stream
;   307E  _open                   - Open file descriptor
;   3211  __open_setflags         - Set open mode flags
;   3222  __read_setmode          - Set read text/binary mode
;   3237  __malloc_block          - Allocate block from heap
;   331A  __open_text_init        - Init text mode for open
;   3354  __open_validate         - Validate open parameters
;   3376  __sbrk_alloc            - Allocate via sbrk for heap
;   3396  __memset_helper         - Small memset helper
;   33A0  _bdos                   - Raw BIOS/DOS function call
;   33B2  _intdos                 - Extended INT 21h call wrapper
;   33FA  _memset                 - Fill memory with byte value
;   3488  __shift32               - 32-bit shift left helper
;   34A8  __open_creat_trunc      - Create/truncate file for open
;   3516  __sbrk_extend           - Extend heap via DOS alloc
;   356C  __sbrk_resize           - Resize heap via DOS resize
;
; ============================================================================
; DATA STRUCTURES
; ============================================================================
;
; --- Video Mode Name Table (DS:0042, word array of string pointers) ---
;   Index 0:  "AUTO" (auto-detect)
;   Index 1:  "VGA"
;   Index 2:  "EGA"
;   Index 3:  "MCGA"
;   Index 4:  "CGA"
;   Index 5:  "HERC"
;   Index 6:  "1000"
;   Index 7:  "TC16"
;   Additional entries: TC40, TC64, T256, HRES, MRES, LRES
;
; --- FILE Structure Layout (8 bytes per entry, MSC 5.0) ---
;   Offset 0: WORD  ptr       - Current buffer pointer
;   Offset 2: WORD  cnt       - Bytes remaining in buffer
;   Offset 4: WORD  base      - Buffer base address
;   Offset 6: BYTE  flags     - Status flags:
;                                 bit 0 (01h): read mode
;                                 bit 1 (02h): write mode
;                                 bit 2 (04h): no buffer allocated
;                                 bit 3 (08h): buffer allocated (malloc)
;                                 bit 4 (10h): EOF reached
;                                 bit 5 (20h): error occurred
;                                 bit 6 (40h): device (not file)
;                                 bit 7 (80h): unbuffered
;   Offset 7: BYTE  fd        - File descriptor number
;
; --- DMCSR.CFG File Format ---
;   INI-style configuration file with sections and key=value pairs.
;   Sections: [DMRESCFG], [DMCONFIG]
;   Key: csr_config=<driver_name>
;   Driver name: 4-character mode code (e.g., "VGA\0" padded)
;   The utility searches [DMRESCFG] first, falls back to [DMCONFIG].
;
; --- Config Path Buffer (DS:0B30, 256 bytes) ---
;   Holds the full path to DMCSR.CFG, built from command-line arg
;   or searched via PATH environment variable.
;
; ============================================================================
; HARDWARE I/O AND INTERRUPTS
; ============================================================================
;
; This utility does NOT directly access TGA/VGA hardware registers.
; Video detection is handled by the .RES driver files loaded by DESK.EXE.
; DMVID.EXE only configures which .RES driver to use.
;
; --- DOS INT 21h API Calls ---
;   AH=08h  Keyboard input without echo (via _getch at 0B5E)
;   AH=19h  Get current default drive (via _getcwd at 2CF4/33A0)
;   AH=25h  Set interrupt vector (restore DIV0 handler at exit)
;   AH=30h  Get DOS version (CRT startup, minimum DOS 2.0)
;   AH=35h  Get interrupt vector (save DIV0 handler)
;   AH=3Ch  Create file (in _open)
;   AH=3Dh  Open file (in _open)
;   AH=3Eh  Close file (in _close, __exit)
;   AH=3Fh  Read file (in _read)
;   AH=40h  Write file (in __write, _open)
;   AH=41h  Delete file (in _unlink)
;   AH=42h  Seek file (in _lseek)
;   AH=43h  Get/set file attributes (in _access)
;   AH=44h  IOCTL get device info (in __cintDIV)
;   AH=47h  Get current directory (in _getcwd)
;   AH=48h  Allocate memory (in _sbrk)
;   AH=4Ah  Resize memory block (in __astart, __brk, _sbrk)
;   AH=4Ch  Terminate program (in __exit)
;
; --- Other Interrupts ---
;   INT 20h  Program terminate (DOS 1.x fallback if DOS < 2.0)
;
; ============================================================================
; SEGMENT LAYOUT (Small Model)
; ============================================================================
;
;   Code segment:  CS = 0000h, range 0000h-35FFh
;   Data segment:  DS = SS = 0358h
;   Stack:         SS:0800h (2048 bytes)
;
; Key data addresses (DS-relative):
;   DS:0000  Runtime internal data
;   DS:0008  "MS Run-Time Library - Copyright (c) 1987, Microsoft Corp"
;   DS:0042  Video mode name pointer table (word array)
;   DS:00CD  Character classification table (ctype)
;   DS:01CE  Keyboard input state word
;   DS:01D2  ";C_FILE_INFO" environment key
;   DS:01DF  Saved INT 00h (DIV0) vector
;   DS:01F1  PSP segment
;   DS:01F3  DOS version
;   DS:01F8  Max open file handles
;   DS:01FA  Per-handle flags table (20 bytes)
;   DS:020E  argc
;   DS:0210  argv pointer
;   DS:0212  envp pointer
;   DS:0222  Fatal error handler pointer
;   DS:0226  stdout buffer refcount
;   DS:0228  First FILE structure (stdin)
;   DS:0230  Second FILE structure (stdout)
;   DS:02C8  File buffer info table (6 bytes per fd)
;   DS:0340  End-of-FILE-table pointer
;   DS:0342  Format engine: assignment flag
;   DS:0344  "(null)" string for printf
;   DS:0352  "+- #" printf flag chars
;   DS:0358  Heap base pointer
;   DS:035A  Heap current pointer
;   DS:035E  Heap free list pointer
;   DS:0362  Stack limit address
;   DS:0384  printf radix table
;   DS:0388  float assignment function pointer
;   DS:038A-039F  CRT internal state
;   DS:03A4  onexit function table start
;   DS:03A5  "/AUTO"
;   DS:03AB-03ED  Video mode name strings
;   DS:03F0  "Video configuration has NOT been updated."
;   DS:041B  "Video configuration has been updated in %s."
;   DS:0479  "DMCSR.CFG"
;   DS:0483  "For further information refer to file DMVID.DOC."
;   DS:04B5  "Video is currently set to use DMVS%s driver."
;   DS:04E4  "Video is currently set for AUTO detection by DESKMATE."
;   DS:051D-0716  Menu option strings (items 1-9)
;   DS:074C  "DMRESCFG"
;   DS:075F  "DMCONFIG"
;   DS:07F9  "csr_config"
;   DS:0B30  Config path buffer (256 bytes)
;
; ============================================================================
; CODE SEGMENT
; ============================================================================

    0000: 0000             add      byte ptr [bx + si], al   ; padding
    0002: 0000             add      byte ptr [bx + si], al
    0004: 0000             add      byte ptr [bx + si], al
    0006: 0000             add      byte ptr [bx + si], al
    0008: 0000             add      byte ptr [bx + si], al
    000A: 0000             add      byte ptr [bx + si], al
    000C: 0000             add      byte ptr [bx + si], al
    000E: 0000             add      byte ptr [bx + si], al

; ======================================================================
; APPLICATION CODE (0010-05B3)
; ======================================================================

; ----------------------------------------------------------------------
; Function: _main
; Address:  0010
; Called from: __astart (0698)
; Params:   int argc [bp+4], char **argv [bp+6]
; Returns:  void (exit code passed to _exit by CRT)
; Description:
;   Main entry point. Parses command line arguments:
;   - If argc < 2: use buildConfigPath with argv[1], run interactive menu
;   - If argv[1] starts with /AUTO: auto-detect mode
;   - If argv[1] is 1 char: selectByChar
;   - Otherwise: selectByName
;   Then applies the selection and prints result message.
; ----------------------------------------------------------------------
_main:
    ; /* address: 0000:0010 */
    0010: 55               push     bp
    0011: 8BEC             mov      bp, sp
    0013: 83EC04           sub      sp, 4               ; local vars: [bp-2]=selection, [bp-4]=result
    0016: 837E0402         cmp      word ptr [bp + 4], 2 ; argc >= 2?
    001A: 7C1F             jl       0x3b                 ; no args -> interactive mode

    ; --- Check if argv[1] starts with "/AUTO" ---
    001C: B80200           mov      ax, 2               ; compare length = 2
    001F: 50               push     ax
    0020: B8ED03           mov      ax, 0x3ed            ; DS:03ED -> partial match pattern
    0023: 50               push     ax
    0024: 8B5E06           mov      bx, word ptr [bp + 6] ; argv
    0027: FF7702           push     word ptr [bx + 2]    ; argv[1]
    002A: E8B10E           call     0xede                ; _strnicmp(argv[1], pattern, 2)
    002D: 83C402           add      sp, 2
    0030: 50               push     ax
    0031: E8EC0A           call     0xb20                ; _strupr(argv[1]) -- uppercase for matching
    0034: 83C406           add      sp, 6
    0037: 0BC0             or       ax, ax               ; strnicmp returned 0 (match)?
    0039: 751B             jne      0x56                 ; no -> try selectByChar/Name

    ; --- Interactive mode (no command-line video selection) ---
loc_003B:
    003B: 8B5E06           mov      bx, word ptr [bp + 6] ; argv
    003E: FF7702           push     word ptr [bx + 2]    ; argv[1] (config path)
    0041: E88700           call     0xcb                 ; dmvid_buildConfigPath(argv[1])
    0044: 83C402           add      sp, 2
    0047: E8E600           call     0x130                ; selection = dmvid_interactiveMenu()
    004A: 8946FE           mov      word ptr [bp - 2], ax
    004D: 0BC0             or       ax, ax
    004F: 7D40             jge      0x91                 ; selection >= 0 -> apply it
    0051: B8F003           mov      ax, 0x3f0            ; "Video configuration has NOT been updated."
    0054: EB6A             jmp      0xc0                 ; -> print message and exit

    ; --- Command-line mode: single char or name ---
loc_0056:
    0056: 8B5E06           mov      bx, word ptr [bp + 6]
    0059: FF7702           push     word ptr [bx + 2]    ; argv[1]
    005C: E8A50A           call     0xb04                ; _strlen(argv[1])
    005F: 83C402           add      sp, 2
    0062: 3D0100           cmp      ax, 1                ; single character?
    0065: 750F             jne      0x76                 ; no -> selectByName

    ; Single char mode (e.g., "2" for VGA)
    0067: 8B5E06           mov      bx, word ptr [bp + 6]
    006A: 8B5F02           mov      bx, word ptr [bx + 2] ; argv[1]
    006D: 8A07             mov      al, byte ptr [bx]    ; first char
    006F: 98               cbw
    0070: 50               push     ax
    0071: E80F02           call     0x283                ; dmvid_selectByChar(char)
    0074: EB09             jmp      0x7f

    ; Multi-char mode name (e.g., "VGA")
loc_0076:
    0076: 8B5E06           mov      bx, word ptr [bp + 6]
    0079: FF7702           push     word ptr [bx + 2]    ; argv[1]
    007C: E81A02           call     0x299                ; dmvid_selectByName(name)

loc_007F:
    007F: 83C402           add      sp, 2
    0082: 8946FE           mov      word ptr [bp - 2], ax ; save selection index
    0085: 8B5E06           mov      bx, word ptr [bp + 6]
    0088: FF7704           push     word ptr [bx + 4]    ; argv[2] (config path)
    008B: E83D00           call     0xcb                 ; dmvid_buildConfigPath(argv[2])
    008E: 83C402           add      sp, 2

    ; --- Apply the selection ---
loc_0091:
    0091: FF76FE           push     word ptr [bp - 2]    ; selection index
    0094: E84702           call     0x2de                ; result = dmvid_applySelection(selection)
    0097: 83C402           add      sp, 2
    009A: 8946FC           mov      word ptr [bp - 4], ax ; save result code
    009D: B8300B           mov      ax, 0xb30            ; config path buffer
    00A0: 50               push     ax
    00A1: E83A0E           call     0xede                ; _strnicmp (clean up stack artifact)
    00A4: 83C402           add      sp, 2
    00A7: 837EFC02         cmp      word ptr [bp - 4], 2 ; result == 2 (success)?
    00AB: 7510             jne      0xbd

    ; --- Success message ---
    00AD: B8300B           mov      ax, 0xb30            ; config file path
    00B0: 50               push     ax
    00B1: B81B04           mov      ax, 0x41b            ; "Video configuration has been updated in %s."
    00B4: 50               push     ax
    00B5: E8E406           call     0x79c                ; _printf(fmt, path)
    00B8: 83C404           add      sp, 4
    00BB: EB0A             jmp      0xc7

    ; --- Failure message ---
loc_00BD:
    00BD: B84804           mov      ax, 0x448            ; "Video configuration has NOT been updated."

loc_00C0:
    00C0: 50               push     ax
    00C1: E8D806           call     0x79c                ; _printf(msg)
    00C4: 83C402           add      sp, 2

loc_00C7:
    00C7: 8BE5             mov      sp, bp
    00C9: 5D               pop      bp
    00CA: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_buildConfigPath
; Address:  00CB
; Params:   char *arg [bp+4] - command-line path argument
; Returns:  void (fills global buffer at DS:0B30)
; Description:
;   Builds the full path to DMCSR.CFG. If the argument starts with
;   a drive letter (e.g., "C:"), it uses that path as prefix and
;   appends "DMCSR.CFG". Ensures trailing backslash before filename.
; ----------------------------------------------------------------------
dmvid_buildConfigPath:
    ; /* address: 0000:00CB */
    00CB: 55               push     bp
    00CC: 8BEC             mov      bp, sp
    00CE: C606300B00       mov      byte ptr [0xb30], 0  ; clear path buffer
    00D3: B80200           mov      ax, 2
    00D6: 50               push     ax
    00D7: B87404           mov      ax, 0x474            ; comparison pattern
    00DA: 50               push     ax
    00DB: FF7604           push     word ptr [bp + 4]    ; arg
    00DE: E8FD0D           call     0xede                ; _strnicmp(arg, pattern, 2)
    00E1: 83C402           add      sp, 2
    00E4: 50               push     ax
    00E5: E8380A           call     0xb20                ; _strupr
    00E8: 83C406           add      sp, 6
    00EB: 0BC0             or       ax, ax
    00ED: 753F             jne      0x12e                ; no match -> return

    ; Copy path prefix (skip first 2 chars if drive letter match)
    00EF: 8B4604           mov      ax, word ptr [bp + 4]
    00F2: 40               inc      ax                   ; skip 2 chars
    00F3: 40               inc      ax
    00F4: 50               push     ax
    00F5: B8300B           mov      ax, 0xb30            ; dest buffer
    00F8: 50               push     ax
    00F9: E8D609           call     0xad2                ; _strcpy(buf, arg+2)
    00FC: 83C404           add      sp, 4

    ; Check if path ends with backslash
    00FF: B8300B           mov      ax, 0xb30
    0102: 50               push     ax
    0103: E8FE09           call     0xb04                ; len = _strlen(buf)
    0106: 83C402           add      sp, 2
    0109: 8BD8             mov      bx, ax
    010B: 80BF2F0B5C       cmp      byte ptr [bx + 0xb2f], 0x5c ; buf[len-1] == '\'?
    0110: 740E             je       0x120                ; yes -> skip adding backslash

    ; Append backslash separator
    0112: B87704           mov      ax, 0x477            ; "\" string
    0115: 50               push     ax
    0116: B8300B           mov      ax, 0xb30
    0119: 50               push     ax
    011A: E87509           call     0xa92                ; _strcat(buf, "\")
    011D: 83C404           add      sp, 4

loc_0120:
    ; Append "DMCSR.CFG"
    0120: B87904           mov      ax, 0x479            ; "DMCSR.CFG"
    0123: 50               push     ax
    0124: B8300B           mov      ax, 0xb30
    0127: 50               push     ax
    0128: E86709           call     0xa92                ; _strcat(buf, "DMCSR.CFG")
    012B: 83C404           add      sp, 4

loc_012E:
    012E: 5D               pop      bp
    012F: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_interactiveMenu
; Address:  0130
; Params:   none
; Returns:  AX = selected mode index (0-7), or -1 if user chose exit
; Description:
;   Displays the video mode selection menu with options 1-9.
;   Shows current video driver if configured.
;   Waits for user to press a key 1-9.
;   Option 9 = exit to DOS (returns -1).
;   Options 1-8 map to mode indices via lookup table at DS:0042.
; ----------------------------------------------------------------------
dmvid_interactiveMenu:
    ; /* address: 0000:0130 */
    0130: 55               push     bp
    0131: 8BEC             mov      bp, sp
    0133: 83EC0C           sub      sp, 0xc              ; locals
    0136: C746F4FFFF       mov      word ptr [bp - 0xc], 0xffff ; detectedAdapter = -1
    013B: C746FE0D00       mov      word ptr [bp - 2], 0xd     ; unused/padding
    0140: B88304           mov      ax, 0x483            ; "For further information refer to file DMVID.DOC."
    0143: 50               push     ax
    0144: E85506           call     0x79c                ; _printf
    0147: 83C402           add      sp, 2

    ; If config path not set, search for DMCSR.CFG
    014A: 803E300B00       cmp      byte ptr [0xb30], 0  ; path buffer empty?
    014F: 7511             jne      0x162                ; no -> skip search
    0151: B8300B           mov      ax, 0xb30
    0154: 50               push     ax
    0155: E81502           call     0x36d                ; dmvid_readConfigSection(buf)
    0158: 83C402           add      sp, 2
    015B: 803E300B00       cmp      byte ptr [0xb30], 0
    0160: 7406             je       0x168                ; still empty -> skip detect

loc_0162:
    0162: E8C500           call     0x22a                ; detectedAdapter = dmvid_detectAdapter()
    0165: 8946F4           mov      word ptr [bp - 0xc], ax

loc_0168:
    ; Display current adapter if detected
    0168: 837EF4FF         cmp      word ptr [bp - 0xc], -1 ; detected?
    016C: 7425             je       0x193                ; no -> skip
    016E: 837EF400         cmp      word ptr [bp - 0xc], 0
    0172: 7E15             jle      0x189                ; <= 0 -> show AUTO message

    ; Show "Video is currently set to use DMVS<name> driver."
    0174: 8B5EF4           mov      bx, word ptr [bp - 0xc]
    0177: D1E3             shl      bx, 1                ; index * 2 (word table)
    0179: FFB74200         push     word ptr [bx + 0x42] ; mode_names[index]
    017D: B8B504           mov      ax, 0x4b5            ; "Video is currently set to use DMVS%s driver."
    0180: 50               push     ax
    0181: E81806           call     0x79c                ; _printf(fmt, name)
    0184: 83C404           add      sp, 4
    0187: EB0A             jmp      0x193

loc_0189:
    ; Show "Video is currently set for AUTO detection."
    0189: B8E404           mov      ax, 0x4e4            ; "Video is currently set for AUTO detection by DESKMATE."
    018C: 50               push     ax
    018D: E80C06           call     0x79c                ; _printf
    0190: 83C402           add      sp, 2

loc_0193:
    ; --- Print menu options ---
    0193: B81D05           mov      ax, 0x51d            ; " 1 - <AUTO>  Automatic detection"
    0196: 50               push     ax
    0197: E80206           call     0x79c
    019A: 83C402           add      sp, 2
    019D: B84005           mov      ax, 0x540            ; " 2 - <VGA>   Video Graphics Array,      640x480  16 colors"
    01A0: 50               push     ax
    01A1: E8F805           call     0x79c
    01A4: 83C402           add      sp, 2
    01A7: B87D05           mov      ax, 0x57d            ; " 3 - <EGA>   Enhanced Graphics Adapter, 640x350  16 colors"
    01AA: 50               push     ax
    01AB: E8EE05           call     0x79c
    01AE: 83C402           add      sp, 2
    01B1: B8BA05           mov      ax, 0x5ba            ; " 4 - <MCGA>  Multi Color Graphics Array,640x480   2 colors"
    01B4: 50               push     ax
    01B5: E8E405           call     0x79c
    01B8: 83C402           add      sp, 2
    01BB: B8F705           mov      ax, 0x5f7            ; " 5 - <CGA>   Color Graphics Adapter,    640x200   2 colors"
    01BE: 50               push     ax
    01BF: E8DA05           call     0x79c
    01C2: 83C402           add      sp, 2
    01C5: B83406           mov      ax, 0x634            ; " 6 - <HERC>  Hercules,    720x348 monochrome"
    01C8: 50               push     ax
    01C9: E8D005           call     0x79c
    01CC: 83C402           add      sp, 2
    01CF: B87906           mov      ax, 0x679            ; " 7 - <1000>  Tandy 1000,  640x200   4 colors"
    01D2: 50               push     ax
    01D3: E8C605           call     0x79c
    01D6: 83C402           add      sp, 2
    01D9: B8BE06           mov      ax, 0x6be            ; " 8 - <TC16>  Tandy Color, 640x200  16 colors"
    01DC: 50               push     ax
    01DD: E8BC05           call     0x79c
    01E0: 83C402           add      sp, 2
    01E3: B80307           mov      ax, 0x703            ; " 9 - Exit to DOS"
    01E6: 50               push     ax
    01E7: E8B205           call     0x79c
    01EA: 83C402           add      sp, 2
    01ED: B81607           mov      ax, 0x716            ; "Select one of the displayed video options "
    01F0: 50               push     ax
    01F1: E8A805           call     0x79c
    01F4: 83C402           add      sp, 2

    ; --- Wait for valid keypress (ASCII '1'-'9') ---
loc_01F7:
    01F7: E86409           call     0xb5e                ; _getch() - read key
    01FA: 8946F6           mov      word ptr [bp - 0xa], ax ; keypress
    01FD: 3D3100           cmp      ax, 0x31             ; < '1'?
    0200: 7CF5             jl       0x1f7                ; invalid -> retry
    0202: 3D3900           cmp      ax, 0x39             ; > '9'?
    0205: 7FF0             jg       0x1f7                ; invalid -> retry

    ; Echo the selection
    0207: 50               push     ax                   ; char value
    0208: B84207           mov      ax, 0x742            ; "%c" format
    020B: 50               push     ax
    020C: E88D05           call     0x79c                ; _printf("%c", key)
    020F: 83C404           add      sp, 4

    ; Check for '9' (exit)
    0212: 837EF639         cmp      word ptr [bp - 0xa], 0x39 ; key == '9'?
    0216: 7505             jne      0x21d
    0218: B8FFFF           mov      ax, 0xffff           ; return -1 (exit)
    021B: EB09             jmp      0x226

loc_021D:
    ; Map key '1'-'8' to mode index via lookup table
    021D: 8B5EF6           mov      bx, word ptr [bp - 0xa] ; key ASCII value
    0220: D1E3             shl      bx, 1                ; * 2 for word table
    0222: 8B87FEFF         mov      ax, word ptr [bx - 2] ; mode_table[key-1]

loc_0226:
    0226: 8BE5             mov      sp, bp
    0228: 5D               pop      bp
    0229: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_detectAdapter
; Address:  022A
; Called from: dmvid_interactiveMenu (0162)
; Returns:  AX = detected mode index, or 0 if failed
; Description:
;   Opens DMCSR.CFG, reads the current csr_config value, and returns
;   the mode index. Updates the config key in the file.
; ----------------------------------------------------------------------
dmvid_detectAdapter:
    ; /* address: 0000:022A */
    022A: 55               push     bp
    022B: 8BEC             mov      bp, sp
    022D: 81ECCE00         sub      sp, 0xce             ; large local buffer
    0231: B84607           mov      ax, 0x746            ; open mode string
    0234: 50               push     ax
    0235: B8300B           mov      ax, 0xb30            ; config path
    0238: 50               push     ax
    0239: E83605           call     0x772                ; fp = dmvid_openConfigFile(path, mode)
    023C: 83C404           add      sp, 4
    023F: 898632FF         mov      word ptr [bp - 0xce], ax ; save FILE*
    0243: 0BC0             or       ax, ax
    0245: 7438             je       0x27f                ; open failed -> return 0

    ; Read current config value
    0247: 8D8634FF         lea      ax, [bp - 0xcc]      ; value buffer
    024B: 50               push     ax
    024C: FFB632FF         push     word ptr [bp - 0xce]  ; FILE*
    0250: E85402           call     0x4a7                ; len = dmvid_readConfigValue(fp, buf)
    0253: 83C404           add      sp, 4
    0256: 8946FC           mov      word ptr [bp - 4], ax

    ; Update config key with new value
    0259: B8FFFF           mov      ax, 0xffff           ; selection = -1 (auto-detect)
    025C: 50               push     ax
    025D: FF76FC           push     word ptr [bp - 4]    ; value length
    0260: 8D8634FF         lea      ax, [bp - 0xcc]
    0264: 50               push     ax                   ; value buffer
    0265: FFB632FF         push     word ptr [bp - 0xce]  ; FILE*
    0269: E87C02           call     0x4e8                ; dmvid_updateConfigKey(fp, buf, len, -1)
    026C: 83C408           add      sp, 8
    026F: 8946FE           mov      word ptr [bp - 2], ax ; result

    ; Close file
    0272: FFB632FF         push     word ptr [bp - 0xce]
    0276: E84504           call     0x6be                ; __closeFile(fp)
    0279: 83C402           add      sp, 2
    027C: 8B46FE           mov      ax, word ptr [bp - 2] ; return result

loc_027F:
    027F: 8BE5             mov      sp, bp
    0281: 5D               pop      bp
    0282: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_selectByChar
; Address:  0283
; Params:   char c [bp+4] - ASCII character ('1'-'8')
; Returns:  AX = mode index if valid digit, 0 if invalid
; Description:
;   Tests if the character is a valid digit by checking the ctype
;   table at DS:00CD. Returns the character value if it has the
;   digit flag (bit mask 0x07 for numeric class).
; ----------------------------------------------------------------------
dmvid_selectByChar:
    ; /* address: 0000:0283 */
    0283: 55               push     bp
    0284: 8BEC             mov      bp, sp
    0286: 56               push     si
    0287: 8A4604           mov      al, byte ptr [bp + 4]
    028A: 98               cbw
    028B: 8BF0             mov      si, ax
    028D: F684CD0007       test     byte ptr [si + 0xcd], 7 ; ctype[char] & DIGIT_MASK
    0292: 7502             jne      0x296                ; is digit -> return it
    0294: 2BC0             sub      ax, ax               ; not valid -> return 0

loc_0296:
    0296: 5E               pop      si
    0297: 5D               pop      bp
    0298: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_selectByName
; Address:  0299
; Params:   char *name [bp+4] - mode name string
; Returns:  AX = mode index (0-14), or 0 if not found
; Description:
;   Iterates through the video mode name table (up to 15 entries)
;   comparing each with the provided name string. Returns the
;   matching index.
; ----------------------------------------------------------------------
dmvid_selectByName:
    ; /* address: 0000:0299 */
    0299: 55               push     bp
    029A: 8BEC             mov      bp, sp
    029C: 83EC02           sub      sp, 2
    029F: C746FE0000       mov      word ptr [bp - 2], 0 ; i = 0

loc_02A4:
    ; Compare name with mode_names[i]
    02A4: FF7604           push     word ptr [bp + 4]    ; name
    02A7: E85A08           call     0xb04                ; len = _strlen(name)
    02AA: 83C402           add      sp, 2
    02AD: 50               push     ax                   ; length for compare
    02AE: FF7604           push     word ptr [bp + 4]    ; name
    02B1: 8B5EFE           mov      bx, word ptr [bp - 2] ; i
    02B4: D1E3             shl      bx, 1                ; * 2 for word table
    02B6: FFB74200         push     word ptr [bx + 0x42] ; mode_names[i]
    02BA: E8C90B           call     0xe86                ; _strncmp(mode_names[i], name, len)
    02BD: 83C406           add      sp, 6
    02C0: 0BC0             or       ax, ax
    02C2: 7409             je       0x2cd                ; match found!
    02C4: FF46FE           inc      word ptr [bp - 2]    ; i++
    02C7: 837EFE0E         cmp      word ptr [bp - 2], 0xe ; i <= 14?
    02CB: 7ED7             jle      0x2a4                ; continue loop

loc_02CD:
    02CD: 837EFE0E         cmp      word ptr [bp - 2], 0xe ; past end of table?
    02D1: 7E04             jle      0x2d7
    02D3: 2BC0             sub      ax, ax               ; not found -> return 0
    02D5: EB03             jmp      0x2da

loc_02D7:
    02D7: 8B46FE           mov      ax, word ptr [bp - 2] ; return matching index

loc_02DA:
    02DA: 8BE5             mov      sp, bp
    02DC: 5D               pop      bp
    02DD: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_applySelection
; Address:  02DE
; Params:   int selection [bp+4]
; Returns:  AX = result code from dmvid_writeConfig
; Description:
;   Thin wrapper that calls dmvid_writeConfig with the selection.
; ----------------------------------------------------------------------
dmvid_applySelection:
    ; /* address: 0000:02DE */
    02DE: 55               push     bp
    02DF: 8BEC             mov      bp, sp
    02E1: FF7604           push     word ptr [bp + 4]
    02E4: E80500           call     0x2ec                ; dmvid_writeConfig(selection)
    02E7: 83C402           add      sp, 2
    02EA: 5D               pop      bp
    02EB: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_writeConfig
; Address:  02EC
; Params:   int selection [bp+4] - mode index to write
; Returns:  AX = 2 on success, 0 on cancel/failure
; Description:
;   Writes the selected video driver to DMCSR.CFG. If the config
;   file is not found, searches for it. If still not found, prompts
;   the user to insert the disk. Loops until file found or user
;   presses ESC.
; ----------------------------------------------------------------------
dmvid_writeConfig:
    ; /* address: 0000:02EC */
    02EC: 55               push     bp
    02ED: 8BEC             mov      bp, sp
    02EF: 81ECD000         sub      sp, 0xd0             ; large local buffer
    02F3: C646FC00         mov      byte ptr [bp - 4], 0 ; cancelled = false

    ; If config path not set, search for it
    02F7: 803E300B00       cmp      byte ptr [0xb30], 0
    02FC: 7563             jne      0x361
    02FE: B8300B           mov      ax, 0xb30
    0301: 50               push     ax
    0302: E86800           call     0x36d                ; dmvid_readConfigSection(buf)
    0305: 83C402           add      sp, 2
    0308: EB57             jmp      0x361

    ; --- Main write loop ---
loc_030A:
    030A: B84907           mov      ax, 0x749            ; open mode "r+"
    030D: 50               push     ax
    030E: B8300B           mov      ax, 0xb30            ; config path
    0311: 50               push     ax
    0312: E85D04           call     0x772                ; fp = dmvid_openConfigFile(path, mode)
    0315: 83C404           add      sp, 4
    0318: 898630FF         mov      word ptr [bp - 0xd0], ax
    031C: 0BC0             or       ax, ax
    031E: 7434             je       0x354                ; open failed -> prompt

    ; Read current value and update
    0320: 8D8632FF         lea      ax, [bp - 0xce]      ; value buffer
    0324: 50               push     ax
    0325: FFB630FF         push     word ptr [bp - 0xd0]  ; FILE*
    0329: E87B01           call     0x4a7                ; len = dmvid_readConfigValue(fp, buf)
    032C: 83C404           add      sp, 4
    032F: 8946FA           mov      word ptr [bp - 6], ax

    ; Update the config key with selection
    0332: FF7604           push     word ptr [bp + 4]    ; selection
    0335: 50               push     ax                   ; value length
    0336: 8D8632FF         lea      ax, [bp - 0xce]
    033A: 50               push     ax                   ; value buffer
    033B: FFB630FF         push     word ptr [bp - 0xd0]  ; FILE*
    033F: E8A601           call     0x4e8                ; dmvid_updateConfigKey(fp, buf, len, selection)
    0342: 83C408           add      sp, 8

    ; Close and return success
    0345: FFB630FF         push     word ptr [bp - 0xd0]
    0349: E87203           call     0x6be                ; __closeFile(fp)
    034C: 83C402           add      sp, 2
    034F: B80200           mov      ax, 2                ; return 2 (success)
    0352: EB15             jmp      0x369

loc_0354:
    ; File not found -> prompt user
    0354: B8300B           mov      ax, 0xb30
    0357: 50               push     ax
    0358: E88600           call     0x3e1                ; cancelled = dmvid_promptForDisk(buf)
    035B: 83C402           add      sp, 2
    035E: 8846FC           mov      byte ptr [bp - 4], al

loc_0361:
    ; Loop until cancelled or successful
    0361: 807EFC00         cmp      byte ptr [bp - 4], 0 ; cancelled?
    0365: 74A3             je       0x30a                ; no -> retry
    0367: 2BC0             sub      ax, ax               ; return 0 (failure)

loc_0369:
    0369: 8BE5             mov      sp, bp
    036B: 5D               pop      bp
    036C: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_readConfigSection
; Address:  036D
; Params:   char *buf [bp+4] - output buffer for config path
; Returns:  void (fills buf with path to DMCSR.CFG if found)
; Description:
;   Searches for DMCSR.CFG by first looking in the [DMRESCFG] section
;   paths, then [DMCONFIG] section paths. Uses _searchenv to search
;   the environment PATH. Strips drive letter prefix from result.
; ----------------------------------------------------------------------
dmvid_readConfigSection:
    ; /* address: 0000:036D */
    036D: 55               push     bp
    036E: 8BEC             mov      bp, sp
    0370: 83EC02           sub      sp, 2
    0373: 8B5E04           mov      bx, word ptr [bp + 4]
    0376: C60700           mov      byte ptr [bx], 0     ; buf[0] = '\0'

    ; Search [DMRESCFG] section first
    0379: FF7604           push     word ptr [bp + 4]    ; output buf
    037C: B84C07           mov      ax, 0x74c            ; "DMRESCFG"
    037F: 50               push     ax
    0380: B85507           mov      ax, 0x755            ; "dmcsr.cfg"
    0383: 50               push     ax
    0384: E8D50B           call     0xf5c                ; _searchenv("dmcsr.cfg", "DMRESCFG", buf)
    0387: 83C406           add      sp, 6

    ; If not found, try [DMCONFIG]
    038A: 8B5E04           mov      bx, word ptr [bp + 4]
    038D: 803F00           cmp      byte ptr [bx], 0     ; found?
    0390: 750F             jne      0x3a1                ; yes -> process result
    0392: 53               push     bx
    0393: B85F07           mov      ax, 0x75f            ; "DMCONFIG"
    0396: 50               push     ax
    0397: B86807           mov      ax, 0x768            ; "dmcsr.cfg"
    039A: 50               push     ax
    039B: E8BE0B           call     0xf5c                ; _searchenv("dmcsr.cfg", "DMCONFIG", buf)
    039E: 83C406           add      sp, 6

loc_03A1:
    ; Search for drive letter prefix pattern
    03A1: B87207           mov      ax, 0x772            ; search pattern (path separator)
    03A4: 50               push     ax
    03A5: FF7604           push     word ptr [bp + 4]
    03A8: E8550B           call     0xf00                ; pos = _strstr(buf, pattern)
    03AB: 83C404           add      sp, 4
    03AE: 8946FE           mov      word ptr [bp - 2], ax
    03B1: 0BC0             or       ax, ax
    03B3: 7428             je       0x3dd                ; not found -> return as-is

    ; Strip prefix: check for drive letter and remove
    03B5: B80100           mov      ax, 1
    03B8: 50               push     ax
    03B9: B87407           mov      ax, 0x774            ; match pattern
    03BC: 50               push     ax
    03BD: 8B46FE           mov      ax, word ptr [bp - 2]
    03C0: 40               inc      ax
    03C1: 50               push     ax
    03C2: E85B07           call     0xb20                ; _strupr(pos+1, pattern, 1)
    03C5: 83C406           add      sp, 6
    03C8: 0BC0             or       ax, ax
    03CA: 7511             jne      0x3dd

    ; Copy stripped path over original
    03CC: 8B46FE           mov      ax, word ptr [bp - 2]
    03CF: 40               inc      ax
    03D0: 40               inc      ax
    03D1: 50               push     ax                   ; src = pos + 2
    03D2: 8B46FE           mov      ax, word ptr [bp - 2]
    03D5: 40               inc      ax
    03D6: 50               push     ax                   ; dst = pos + 1
    03D7: E8F806           call     0xad2                ; _strcpy(pos+1, pos+2)
    03DA: 83C404           add      sp, 4

loc_03DD:
    03DD: 8BE5             mov      sp, bp
    03DF: 5D               pop      bp
    03E0: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_promptForDisk
; Address:  03E1
; Params:   char *buf [bp+4] - path buffer to fill
; Returns:  AX = 1 if user pressed ESC (cancel), 0 if path entered
; Description:
;   Prompts user to insert the disk containing DMCSR.CFG or enter
;   a path. Reads characters one at a time, building the path.
;   ESC cancels, ENTER accepts.
; ----------------------------------------------------------------------
dmvid_promptForDisk:
    ; /* address: 0000:03E1 */
    03E1: 55               push     bp
    03E2: 8BEC             mov      bp, sp
    03E4: 83EC24           sub      sp, 0x24
    03E7: 56               push     si
    03E8: C746FE0000       mov      word ptr [bp - 2], 0 ; key = 0
    03ED: 8B5E04           mov      bx, word ptr [bp + 4]
    03F0: C60700           mov      byte ptr [bx], 0     ; buf[0] = '\0'

    ; Print prompt messages
    03F3: B87607           mov      ax, 0x776            ; "Insert the disk containing DMCSR.CFG,"
    03F6: 50               push     ax
    03F7: E8A203           call     0x79c                ; _printf
    03FA: 83C402           add      sp, 2
    03FD: B89E07           mov      ax, 0x79e            ; "Enter PATH-NAME where the file could be found."
    0400: 50               push     ax
    0401: E89803           call     0x79c
    0404: 83C402           add      sp, 2
    0407: B8CE07           mov      ax, 0x7ce            ; "or press ESC to cancel..."
    040A: 50               push     ax
    040B: E88E03           call     0x79c
    040E: 83C402           add      sp, 2

    ; Read first character
    0411: E84A07           call     0xb5e                ; key = _getch()
    0414: 8946FE           mov      word ptr [bp - 2], ax
    0417: EB74             jmp      0x48d                ; check if buf filled

    ; --- Character input loop ---
loc_0419:
    0419: 837EFE0D         cmp      word ptr [bp - 2], 0xd  ; ENTER?
    041D: 7476             je       0x495
    041F: 837EFE1B         cmp      word ptr [bp - 2], 0x1b ; ESC?
    0423: 7470             je       0x495

    ; Echo character and append to path
    0425: FF76FE           push     word ptr [bp - 2]    ; char
    0428: B8E807           mov      ax, 0x7e8            ; "%c" format
    042B: 50               push     ax
    042C: E86D03           call     0x79c                ; _printf("%c", key)
    042F: 83C404           add      sp, 4

    ; Start building the path
    0432: 8B5E04           mov      bx, word ptr [bp + 4]
    0435: 8A46FE           mov      al, byte ptr [bp - 2]
    0438: 8807             mov      byte ptr [bx], al    ; buf[0] = key
    043A: 8B5E04           mov      bx, word ptr [bp + 4]
    043D: C6470100         mov      byte ptr [bx + 1], 0 ; buf[1] = '\0'

    ; Build temp path with "\DMCSR.CFG"
    0441: 8D46DC           lea      ax, [bp - 0x24]      ; temp buffer
    0444: 50               push     ax
    0445: B8EB07           mov      ax, 0x7eb            ; sprintf format
    0448: 50               push     ax
    0449: E88C03           call     0x7d8                ; dmvid_showCurrentVideo(fmt, tempbuf)
    044C: 83C404           add      sp, 4
    044F: 8D46DC           lea      ax, [bp - 0x24]
    0452: 50               push     ax
    0453: FF7604           push     word ptr [bp + 4]
    0456: E83906           call     0xa92                ; _strcat(buf, tempbuf)
    0459: 83C404           add      sp, 4

    ; Check/fix trailing backslash
    045C: FF7604           push     word ptr [bp + 4]
    045F: E8A206           call     0xb04                ; len = _strlen(buf)
    0462: 83C402           add      sp, 2
    0465: 8BF0             mov      si, ax
    0467: 8B5E04           mov      bx, word ptr [bp + 4]
    046A: 8078FF5C         cmp      byte ptr [bx + si - 1], 0x5c ; last char == '\'?
    046E: 7510             jne      0x480
    ; Remove duplicate trailing backslash
    0470: 53               push     bx
    0471: E89006           call     0xb04
    0474: 83C402           add      sp, 2
    0477: 8BF0             mov      si, ax
    0479: 8B5E04           mov      bx, word ptr [bp + 4]
    047C: C640FF00         mov      byte ptr [bx + si - 1], 0

loc_0480:
    ; Append "\DMCSR.CFG"
    0480: B8EE07           mov      ax, 0x7ee            ; "\DMCSR.CFG"
    0483: 50               push     ax
    0484: FF7604           push     word ptr [bp + 4]
    0487: E80806           call     0xa92                ; _strcat(buf, "\DMCSR.CFG")
    048A: 83C404           add      sp, 4

loc_048D:
    ; Check if buffer has content (from earlier input or this iteration)
    048D: 8B5E04           mov      bx, word ptr [bp + 4]
    0490: 803F00           cmp      byte ptr [bx], 0     ; buf empty?
    0493: 7484             je       0x419                ; yes -> read more keys

loc_0495:
    ; Check if ESC was pressed
    0495: 837EFE1B         cmp      word ptr [bp - 2], 0x1b
    0499: 7505             jne      0x4a0
    049B: B80100           mov      ax, 1                ; return 1 (cancelled)
    049E: EB02             jmp      0x4a2

loc_04A0:
    04A0: 2BC0             sub      ax, ax               ; return 0 (path entered)

loc_04A2:
    04A2: 5E               pop      si
    04A3: 8BE5             mov      sp, bp
    04A5: 5D               pop      bp
    04A6: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_readConfigValue
; Address:  04A7
; Params:   FILE *fp [bp+4], char *buf [bp+6]
; Returns:  AX = number of bytes read
; Description:
;   Reads characters from the config file stream into the buffer
;   until EOF (char == 0xFF). Counts bytes read.
; ----------------------------------------------------------------------
dmvid_readConfigValue:
    ; /* address: 0000:04A7 */
    04A7: 55               push     bp
    04A8: 8BEC             mov      bp, sp
    04AA: 83EC02           sub      sp, 2
    04AD: 56               push     si
    04AE: C746FE0000       mov      word ptr [bp - 2], 0 ; count = 0

loc_04B3:
    ; Read one byte from stream
    04B3: 8B5E04           mov      bx, word ptr [bp + 4] ; fp
    04B6: FF4F02           dec      word ptr [bx + 2]    ; fp->cnt--
    04B9: 780B             js       0x4c6                ; underflow -> refill
    04BB: 8B5E04           mov      bx, word ptr [bp + 4]
    04BE: 8B37             mov      si, word ptr [bx]    ; ptr = fp->ptr
    04C0: FF07             inc      word ptr [bx]        ; fp->ptr++
    04C2: 8A04             mov      al, byte ptr [si]    ; ch = *ptr
    04C4: EB09             jmp      0x4cf

loc_04C6:
    ; Buffer empty -> read from file
    04C6: FF7604           push     word ptr [bp + 4]
    04C9: E82A03           call     0x7f6                ; ch = dmvid_readCurrentDriver(fp) [fgetc]
    04CC: 83C402           add      sp, 2

loc_04CF:
    ; Store character in output buffer
    04CF: 8B5EFE           mov      bx, word ptr [bp - 2] ; count
    04D2: 8B7606           mov      si, word ptr [bp + 6] ; buf
    04D5: 8800             mov      byte ptr [bx + si], al ; buf[count] = ch
    04D7: FEC0             inc      al
    04D9: 7405             je       0x4e0                ; ch == 0xFF (EOF) -> done
    04DB: FF46FE           inc      word ptr [bp - 2]    ; count++
    04DE: EBD3             jmp      0x4b3                ; next byte

loc_04E0:
    04E0: 8B46FE           mov      ax, word ptr [bp - 2] ; return count
    04E3: 5E               pop      si
    04E4: 8BE5             mov      sp, bp
    04E6: 5D               pop      bp
    04E7: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_updateConfigKey
; Address:  04E8
; Params:   FILE *fp [bp+4], char *buf [bp+6], int len [bp+8],
;           int selection [bp+0A]
; Returns:  AX = selection (possibly updated from file)
; Description:
;   Scans the config buffer for the "csr_config" key. When found,
;   positions the file pointer after the key and either reads or
;   writes the mode value. If selection == -1, reads current value;
;   otherwise writes the new selection.
; ----------------------------------------------------------------------
dmvid_updateConfigKey:
    ; /* address: 0000:04E8 */
    04E8: 55               push     bp
    04E9: 8BEC             mov      bp, sp
    04EB: 83EC06           sub      sp, 6
    04EE: 56               push     si
    04EF: 2BC0             sub      ax, ax
    04F1: 8946FE           mov      word ptr [bp - 2], ax ; pos_hi = 0
    04F4: 8946FC           mov      word ptr [bp - 4], ax ; pos_lo = 0
    04F7: 8946FA           mov      word ptr [bp - 6], ax ; found = 0

    ; --- Scan buffer for "csr_config" key ---
loc_04FA:
    04FA: 8B4608           mov      ax, word ptr [bp + 8] ; len
    04FD: 99               cwd                           ; sign-extend to dx:ax
    04FE: 3B56FE           cmp      dx, word ptr [bp - 2] ; pos_hi
    0501: 7C3F             jl       0x542                ; past end
    0503: 7F05             jg       0x50a
    0505: 3B46FC           cmp      ax, word ptr [bp - 4] ; pos_lo
    0508: 7238             jb       0x542

loc_050A:
    050A: 837EFA00         cmp      word ptr [bp - 6], 0 ; already found?
    050E: 7532             jne      0x542                ; yes -> stop scanning
    ; Compare current position with "csr_config"
    0510: B80A00           mov      ax, 0xa              ; strlen("csr_config") = 10
    0513: 50               push     ax
    0514: B8F907           mov      ax, 0x7f9            ; "csr_config"
    0517: 50               push     ax
    0518: 8B46FC           mov      ax, word ptr [bp - 4]
    051B: 034606           add      ax, word ptr [bp + 6] ; buf + pos
    051E: 50               push     ax
    051F: E86409           call     0xe86                ; _strncmp(buf+pos, "csr_config", 10)
    0522: 83C406           add      sp, 6
    0525: 0BC0             or       ax, ax
    0527: 750F             jne      0x538                ; no match

    ; Found "csr_config" - skip past key + "=" (13 bytes: 10 + "=" + value + NUL)
    0529: 8346FC0D         add      word ptr [bp - 4], 0xd ; pos += 13
    052D: 8356FE00         adc      word ptr [bp - 2], 0
    0531: C746FA0100       mov      word ptr [bp - 6], 1 ; found = true
    0536: EBC2             jmp      0x4fa

loc_0538:
    ; Not matched -> advance by 1
    0538: 8346FC01         add      word ptr [bp - 4], 1
    053C: 8356FE00         adc      word ptr [bp - 2], 0
    0540: EBB8             jmp      0x4fa

    ; --- Key found, now seek and read/write value ---
loc_0542:
    0542: 8B4608           mov      ax, word ptr [bp + 8]
    0545: 99               cwd
    0546: 3B56FE           cmp      dx, word ptr [bp - 2]
    0549: 7C64             jl       0x5af                ; position invalid
    054B: 7F05             jg       0x552
    054D: 3B46FC           cmp      ax, word ptr [bp - 4]
    0550: 725D             jb       0x5af

loc_0552:
    ; Seek to the value position in the file
    0552: 2BC0             sub      ax, ax               ; whence = SEEK_SET
    0554: 50               push     ax
    0555: FF76FE           push     word ptr [bp - 2]    ; offset_hi
    0558: FF76FC           push     word ptr [bp - 4]    ; offset_lo
    055B: FF7604           push     word ptr [bp + 4]    ; FILE*
    055E: E81506           call     0xb76                ; _fseek(fp, pos, SEEK_SET)
    0561: 83C408           add      sp, 8

    ; If selection == -1, read current value
    0564: 837E0AFF         cmp      word ptr [bp + 0xa], -1
    0568: 7523             jne      0x58d                ; not auto -> write mode

    ; --- Auto-detect mode: read current value from file ---
    056A: 8B5E04           mov      bx, word ptr [bp + 4]
    056D: FF4F02           dec      word ptr [bx + 2]    ; fp->cnt--
    0570: 780D             js       0x57f
    0572: 8B5E04           mov      bx, word ptr [bp + 4]
    0575: 8B37             mov      si, word ptr [bx]
    0577: FF07             inc      word ptr [bx]
    0579: 8A04             mov      al, byte ptr [si]    ; ch = fgetc(fp)
    057B: 2AE4             sub      ah, ah
    057D: EB09             jmp      0x588

loc_057F:
    057F: FF7604           push     word ptr [bp + 4]
    0582: E87102           call     0x7f6                ; ch = dmvid_readCurrentDriver(fp)
    0585: 83C402           add      sp, 2

loc_0588:
    0588: 89460A           mov      word ptr [bp + 0xa], ax ; selection = ch (mode index)
    058B: EB22             jmp      0x5af

    ; --- Write mode: write new selection to file ---
loc_058D:
    058D: 8B5E04           mov      bx, word ptr [bp + 4]
    0590: FF4F02           dec      word ptr [bx + 2]    ; fp->cnt--
    0593: 780E             js       0x5a3
    ; Write inline via buffer
    0595: 8A460A           mov      al, byte ptr [bp + 0xa] ; selection byte
    0598: 8B5E04           mov      bx, word ptr [bp + 4]
    059B: 8B37             mov      si, word ptr [bx]
    059D: FF07             inc      word ptr [bx]
    059F: 8804             mov      byte ptr [si], al    ; *fp->ptr++ = selection
    05A1: EB0C             jmp      0x5af

loc_05A3:
    ; Buffer full -> write via fputc
    05A3: FF7604           push     word ptr [bp + 4]    ; FILE*
    05A6: FF760A           push     word ptr [bp + 0xa]  ; byte to write
    05A9: E85003           call     0x8fc                ; dmvid_searchConfigKey (fputc)
    05AC: 83C404           add      sp, 4

loc_05AF:
    05AF: 5E               pop      si
    05B0: 8BE5             mov      sp, bp
    05B2: 5D               pop      bp
    05B3: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_writeConfigBytes
; Address:  05B4
; Params:   FILE *fp [bp+4], char *buf [bp+6], int len [bp+8]
; Returns:  void
; Description:
;   Writes len bytes from buf to the file stream. For each byte,
;   attempts inline buffer write; if buffer is full, calls fputc.
;   This is effectively fwrite() for config data.
; ----------------------------------------------------------------------
dmvid_writeConfigBytes:
    ; /* address: 0000:05B4 */
    05B4: 55               push     bp
    05B5: 8BEC             mov      bp, sp
    05B7: 83EC02           sub      sp, 2
    05BA: 56               push     si
    05BB: FF7604           push     word ptr [bp + 4]    ; FILE*
    05BE: E89308           call     0xe54                ; _rewind(fp)
    05C1: 83C402           add      sp, 2
    05C4: C746FE0000       mov      word ptr [bp - 2], 0 ; i = 0
    05C9: EB16             jmp      0x5e1

loc_05CB:
    ; Buffer underflow -> write via fputc
    05CB: FF7604           push     word ptr [bp + 4]    ; FILE*
    05CE: 8B5EFE           mov      bx, word ptr [bp - 2]
    05D1: 8B7606           mov      si, word ptr [bp + 6]
    05D4: 8A00             mov      al, byte ptr [bx + si] ; buf[i]
    05D6: 98               cbw
    05D7: 50               push     ax
    05D8: E82103           call     0x8fc                ; fputc(buf[i], fp)
    05DB: 83C404           add      sp, 4

loc_05DE:
    05DE: FF46FE           inc      word ptr [bp - 2]    ; i++

loc_05E1:
    05E1: 8B4608           mov      ax, word ptr [bp + 8] ; len
    05E4: 3946FE           cmp      word ptr [bp - 2], ax
    05E7: 7F1B             jg       0x604                ; i > len -> done

    ; Try inline buffer write
    05E9: 8B5E04           mov      bx, word ptr [bp + 4] ; FILE*
    05EC: FF4F02           dec      word ptr [bx + 2]    ; fp->cnt--
    05EF: 78DA             js       0x5cb                ; underflow -> fputc path
    05F1: 8B5EFE           mov      bx, word ptr [bp - 2]
    05F4: 8B7606           mov      si, word ptr [bp + 6]
    05F7: 8A00             mov      al, byte ptr [bx + si] ; buf[i]
    05F9: 8B5E04           mov      bx, word ptr [bp + 4]
    05FC: 8B37             mov      si, word ptr [bx]    ; fp->ptr
    05FE: FF07             inc      word ptr [bx]        ; fp->ptr++
    0600: 8804             mov      byte ptr [si], al    ; *fp->ptr = buf[i]
    0602: EBDA             jmp      0x5de                ; next

loc_0604:
    0604: 5E               pop      si
    0605: 8BE5             mov      sp, bp
    0607: 5D               pop      bp
    0608: C3               ret
    0609: 90               nop

; ======================================================================
; MSC 5.0 C RUNTIME CODE (060A onwards)
; ======================================================================

; ----------------------------------------------------------------------
; Function: __astart
; Address:  060A
; Description:
;   CRT startup entry point. Checks DOS version >= 2.0, initializes
;   stack, BSS, environment, arguments, then calls _main(argc, argv, envp).
;   On return, calls _exit().
; ----------------------------------------------------------------------
__astart:
    ; /* address: 0000:060A */
    060A: B430             mov      ah, 0x30             ; INT 21h/30h: Get DOS version
    060C: CD21             int      0x21
    060E: 3C02             cmp      al, 2                ; DOS >= 2.0?
    0610: 7302             jae      0x614
    0612: CD20             int      0x20                  ; INT 20h: terminate (DOS 1.x)

loc_0614:
    ; Set up data segment
    0614: BF5803           mov      di, 0x358            ; DS segment value (relocated)
    0617: 8B360200         mov      si, word ptr [2]     ; top of memory
    061B: 2BF7             sub      si, di               ; available paragraphs
    061D: 81FE0010         cmp      si, 0x1000           ; cap at 64KB
    0621: 7203             jb       0x626
    0623: BE0010           mov      si, 0x1000

loc_0626:
    ; Set up stack
    0626: FA               cli
    0627: 8ED7             mov      ss, di               ; SS = DS segment
    0629: 81C45E0D         add      sp, 0xd5e            ; initial SP
    062D: FB               sti
    062E: 7310             jae      0x640                ; enough memory?
    ; Stack overflow at startup -> fatal error
    0630: 16               push     ss
    0631: 1F               pop      ds
    0632: E8850B           call     0x11ba               ; __NMSG_WRITE("R6000 - stack overflow")
    0635: 33C0             xor      ax, ax
    0637: 50               push     ax
    0638: E8E00D           call     0x141b               ; __write
    063B: B8FF4C           mov      ax, 0x4cff           ; INT 21h/4Ch: exit with code 0xFF
    063E: CD21             int      0x21

loc_0640:
    ; Align stack, save pointers, clear BSS
    0640: 81E4FEFF         and      sp, 0xfffe           ; word-align stack
    0644: 3689267600       mov      word ptr ss:[0x76], sp ; save stack top
    0649: 3689267200       mov      word ptr ss:[0x72], sp
    064E: 8BC6             mov      ax, si
    0650: B104             mov      cl, 4
    0652: D3E0             shl      ax, cl               ; paragraphs -> bytes
    0654: 48               dec      ax
    0655: 36A37000         mov      word ptr ss:[0x70], ax ; heap limit
    0659: 03F7             add      si, di
    065B: 89360200         mov      word ptr [2], si     ; update top of memory
    ; Resize memory block to actual usage
    065F: 8CC3             mov      bx, es
    0661: 2BDE             sub      bx, si
    0663: F7DB             neg      bx
    0665: B44A             mov      ah, 0x4a             ; INT 21h/4Ah: resize memory
    0667: CD21             int      0x21
    ; Save PSP segment, clear BSS area
    0669: 368C1EF101       mov      word ptr ss:[0x1f1], ds ; save PSP segment
    066E: 16               push     ss
    066F: 07               pop      es
    0670: FC               cld
    0671: BFDE08           mov      di, 0x8de            ; BSS start
    0674: B9600D           mov      cx, 0xd60            ; BSS end
    0677: 2BCF             sub      cx, di               ; BSS size
    0679: 33C0             xor      ax, ax
    067B: F3AA             rep stosb                      ; zero BSS
    067D: 16               push     ss
    067E: 1F               pop      ds
    ; Initialize runtime: DIV handler, environment, command line
    067F: E8C809           call     0x104a               ; __cintDIV()
    0682: 16               push     ss
    0683: 1F               pop      ds
    0684: E8030D           call     0x138a               ; __setenvp()
    0687: E8720B           call     0x11fc               ; __setargv()
    ; Call main(argc, argv, envp)
    068A: 33ED             xor      bp, bp
    068C: FF361202         push     word ptr [0x212]     ; envp
    0690: FF361002         push     word ptr [0x210]     ; argv
    0694: FF360E02         push     word ptr [0x20e]     ; argc
    0698: E875F9           call     0x10                 ; _main(argc, argv, envp)
    069B: 50               push     ax
    069C: E86F0A           call     0x110e               ; _exit(retval)

    ; Fatal error handler (jumped to from __chkstk on overflow)
    069F: B85803           mov      ax, 0x358            ; DS segment (relocated)
    06A2: 8ED8             mov      ds, ax
    06A4: B80300           mov      ax, 3                ; error code 3
    06A7: 36C70674000E11   mov      word ptr ss:[0x74], 0x110e ; _exit address

loc_06AE:
    ; Display runtime error and exit
    06AE: 50               push     ax
    06AF: E8080B           call     0x11ba               ; __NMSG_WRITE(error_code)
    06B2: E8660D           call     0x141b               ; __write to stderr
    06B5: B8FF00           mov      ax, 0xff
    06B8: 50               push     ax
    06B9: FF167400         call     word ptr [0x74]      ; _exit(0xFF)

; ----------------------------------------------------------------------
; Function: __closeFile
; Address:  06BE
; Params:   FILE *fp [bp+4]
; Returns:  AX = result (-1 on error)
; Description:
;   CRT file close helper. Flushes buffer, closes handle, deletes
;   temp files if needed. Used by dmvid_detectAdapter and
;   dmvid_writeConfig after config file operations.
;   (This is the inline _fclose code from MSC 5.0)
; ----------------------------------------------------------------------
__closeFile:
    ; /* address: 0000:06BE */
    06BD: 00558B           ; (misaligned bytes from previous function end)
    06C0: EC               in       al, dx
    06C1: 83EC10           sub      sp, 0x10
    06C4: 57               push     di
    06C5: 56               push     si
    06C6: 8B7604           mov      si, word ptr [bp + 4] ; FILE*
    06C9: BFFFFF           mov      di, 0xffff           ; result = -1
    06CC: F6440683         test     byte ptr [si + 6], 0x83 ; file open?
    06D0: 7503             jne      0x6d5
    06D2: E99100           jmp      0x766                ; not open -> skip

loc_06D5:
    06D5: F6440640         test     byte ptr [si + 6], 0x40 ; device flag?
    06D9: 7403             je       0x6de
    06DB: E98800           jmp      0x766

loc_06DE:
    ; Flush stream, get temp file info, close handle
    06DE: 56               push     si
    06DF: E8C00F           call     0x16a2               ; __dosretax(fp) -> fileno
    06E2: 83C402           add      sp, 2
    06E5: 8BF8             mov      di, ax               ; fd
    06E7: 8A4407           mov      al, byte ptr [si + 7] ; fp->fd
    06EA: 98               cbw
    06EB: 8BD8             mov      bx, ax
    06ED: D1E3             shl      bx, 1
    06EF: 03D8             add      bx, ax
    06F1: D1E3             shl      bx, 1                ; bx = fd * 6
    06F3: 8B87CC02         mov      ax, word ptr [bx + 0x2cc] ; temp file name ptr
    06F7: 8946FA           mov      word ptr [bp - 6], ax
    06FA: 56               push     si
    06FB: E8460D           call     0x1444               ; __flsbuf(fp) - flush
    06FE: 83C402           add      sp, 2
    ; Close the file descriptor
    0701: 8A4407           mov      al, byte ptr [si + 7]
    0704: 98               cbw
    0705: 50               push     ax
    0706: E8A920           call     0x27b2               ; _close(fd)
    0709: 83C402           add      sp, 2
    070C: 0BC0             or       ax, ax
    070E: 7C53             jl       0x763                ; close failed

    ; If temp file exists, delete it
    0710: 837EFA00         cmp      word ptr [bp - 6], 0
    0714: 7450             je       0x766                ; no temp file
    ; Build temp file path and unlink
    0716: B8C800           mov      ax, 0xc8
    0719: 50               push     ax
    071A: 8D46F0           lea      ax, [bp - 0x10]
    071D: 50               push     ax
    071E: E8B103           call     0xad2                ; _strcpy(local, prefix)
    0721: 83C404           add      sp, 4
    0724: 8D46F2           lea      ax, [bp - 0xe]
    0727: 8946FC           mov      word ptr [bp - 4], ax
    072A: 8BD8             mov      bx, ax
    072C: 807FFE5C         cmp      byte ptr [bx - 2], 0x5c ; trailing '\'?
    0730: 7410             je       0x742
    0732: B8CA00           mov      ax, 0xca
    0735: 50               push     ax
    0736: 8D46F0           lea      ax, [bp - 0x10]
    0739: 50               push     ax
    073A: E85503           call     0xa92                ; _strcat
    073D: 83C404           add      sp, 4
    0740: EB03             jmp      0x745

loc_0742:
    0742: FF4EFC           dec      word ptr [bp - 4]

loc_0745:
    0745: B80A00           mov      ax, 0xa
    0748: 50               push     ax
    0749: FF76FC           push     word ptr [bp - 4]
    074C: FF76FA           push     word ptr [bp - 6]    ; temp filename
    074F: E85623           call     0x2aa8               ; _ltoa
    0752: 83C406           add      sp, 6
    0755: 8D46F0           lea      ax, [bp - 0x10]
    0758: 50               push     ax
    0759: E84A26           call     0x2da6               ; _unlink(temppath)
    075C: 83C402           add      sp, 2
    075F: 0BC0             or       ax, ax
    0761: 7403             je       0x766

loc_0763:
    0763: BFFFFF           mov      di, 0xffff           ; error

loc_0766:
    ; Clear FILE structure flags
    0766: C6440600         mov      byte ptr [si + 6], 0
    076A: 8BC7             mov      ax, di               ; return result
    076C: 5E               pop      si
    076D: 5F               pop      di
    076E: 8BE5             mov      sp, bp
    0770: 5D               pop      bp
    0771: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_openConfigFile
; Address:  0772
; Params:   char *path [bp+4], char *mode [bp+6]
; Returns:  AX = FILE* or 0 on failure
; Description:
;   Allocates a FILE slot and opens DMCSR.CFG via _fopen.
; ----------------------------------------------------------------------
dmvid_openConfigFile:
    ; /* address: 0000:0772 */
    0772: 55               push     bp
    0773: 8BEC             mov      bp, sp
    0775: 83EC02           sub      sp, 2
    0778: 56               push     si
    0779: E8FA1F           call     0x2776               ; si = __allocFileSlot()
    077C: 8BF0             mov      si, ax
    077E: 0BF6             or       si, si
    0780: 7412             je       0x794                ; no free slot

    ; Open the file
    0782: 56               push     si                   ; FILE* slot
    0783: FF7606           push     word ptr [bp + 6]    ; mode
    0786: FF7604           push     word ptr [bp + 4]    ; path
    0789: E8E60C           call     0x1472               ; _fopen(path, mode, fp)
    078C: 83C406           add      sp, 6
    078F: 5E               pop      si
    0790: 8BE5             mov      sp, bp
    0792: 5D               pop      bp
    0793: C3               ret

loc_0794:
    0794: 2BC0             sub      ax, ax               ; return NULL
    0796: 5E               pop      si
    0797: 8BE5             mov      sp, bp
    0799: 5D               pop      bp
    079A: C3               ret
    079B: 90               nop

; ----------------------------------------------------------------------
; Function: _printf
; Address:  079C
; Params:   char *fmt [bp+4], ... varargs
; Returns:  AX = number of chars written
; Description:
;   Standard C printf. Locks stdout, calls format engine, unlocks.
; ----------------------------------------------------------------------
_printf:
    ; /* address: 0000:079C */
    079C: 55               push     bp
    079D: 8BEC             mov      bp, sp
    079F: 83EC08           sub      sp, 8
    07A2: 57               push     di
    07A3: 56               push     si
    07A4: BE3002           mov      si, 0x230            ; stdout FILE* (DS:0230)
    07A7: 8D4606           lea      ax, [bp + 6]         ; va_list = &args
    07AA: 8946FC           mov      word ptr [bp - 4], ax
    07AD: 56               push     si
    07AE: E8B50D           call     0x1566               ; _printf_lock(stdout)
    07B1: 83C402           add      sp, 2
    07B4: 8BF8             mov      di, ax
    ; Call format engine
    07B6: 8D4606           lea      ax, [bp + 6]         ; va_list
    07B9: 50               push     ax
    07BA: FF7604           push     word ptr [bp + 4]    ; fmt
    07BD: 56               push     si                   ; stdout
    07BE: E87117           call     0x1f32               ; __fmtout(stdout, fmt, va_list)
    07C1: 83C406           add      sp, 6
    07C4: 8946F8           mov      word ptr [bp - 8], ax ; chars written
    ; Unlock
    07C7: 56               push     si
    07C8: 57               push     di
    07C9: E8480E           call     0x1614               ; _printf_unlock(saved, stdout)
    07CC: 83C404           add      sp, 4
    07CF: 8B46F8           mov      ax, word ptr [bp - 8]
    07D2: 5E               pop      si
    07D3: 5F               pop      di
    07D4: 8BE5             mov      sp, bp
    07D6: 5D               pop      bp
    07D7: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_showCurrentVideo
; Address:  07D8
; Params:   char *fmt [bp+4], ... varargs [bp+6+]
; Returns:  void (formats string into buffer)
; Description:
;   Wrapper around _vsprintf - formats a string using the given
;   format and varargs into a buffer. Used to build display messages.
; ----------------------------------------------------------------------
dmvid_showCurrentVideo:
    ; /* address: 0000:07D8 */
    07D8: 55               push     bp
    07D9: 8BEC             mov      bp, sp
    07DB: 83EC02           sub      sp, 2
    07DE: 8D4606           lea      ax, [bp + 6]         ; va_list
    07E1: 8946FE           mov      word ptr [bp - 2], ax
    07E4: 8D4606           lea      ax, [bp + 6]
    07E7: 50               push     ax                   ; va_list
    07E8: FF7604           push     word ptr [bp + 4]    ; fmt
    07EB: B82802           mov      ax, 0x228            ; output buffer (FILE* for sprintf)
    07EE: 50               push     ax
    07EF: E8180F           call     0x170a               ; _vsprintf(buf, fmt, va_list)
    07F2: 8BE5             mov      sp, bp
    07F4: 5D               pop      bp
    07F5: C3               ret

; ----------------------------------------------------------------------
; Function: dmvid_readCurrentDriver (fgetc)
; Address:  07F6
; Params:   FILE *fp [bp+4]
; Returns:  AX = character read, or 0xFFFF on EOF/error
; Description:
;   Reads a single character from the file stream. If the buffer
;   is empty, refills it from the file descriptor via _read().
;   This is the MSC 5.0 fgetc() implementation.
; ----------------------------------------------------------------------
dmvid_readCurrentDriver:
    ; /* address: 0000:07F6 */
    07F6: 55               push     bp
    07F7: 8BEC             mov      bp, sp
    07F9: 57               push     di
    07FA: 56               push     si
    07FB: 8B7604           mov      si, word ptr [bp + 4] ; FILE*
    ; Check if file is open and readable
    07FE: F6440683         test     byte ptr [si + 6], 0x83
    0802: 7406             je       0x80a                ; not open
    0804: F6440640         test     byte ptr [si + 6], 0x40
    0808: 7408             je       0x812                ; not a device -> ok

loc_080A:
    080A: B8FFFF           mov      ax, 0xffff           ; return EOF
    080D: 5E               pop      si
    080E: 5F               pop      di
    080F: 5D               pop      bp
    0810: C3               ret
    0811: 90               nop

loc_0812:
    ; Check write-only mode
    0812: F6440602         test     byte ptr [si + 6], 2
    0816: 7406             je       0x81e
    0818: 804C0620         or       byte ptr [si + 6], 0x20 ; set error flag
    081C: EBEC             jmp      0x80a                ; return EOF

loc_081E:
    ; Set read mode, prepare buffer
    081E: 804C0601         or       byte ptr [si + 6], 1 ; set read flag
    0822: 8A4407           mov      al, byte ptr [si + 7] ; fd
    0825: 98               cbw
    0826: 8BC8             mov      cx, ax
    0828: D1E0             shl      ax, 1
    082A: 03C1             add      ax, cx
    082C: D1E0             shl      ax, 1                ; ax = fd * 6
    082E: 8BF8             mov      di, ax
    0830: 81C7C802         add      di, 0x2c8            ; buffer info table entry
    0834: 8025FB           and      byte ptr [di], 0xfb  ; clear dirty flag
    ; Check if buffer needs allocation
    0837: F644060C         test     byte ptr [si + 6], 0xc
    083B: 750F             jne      0x84c
    083D: F60501           test     byte ptr [di], 1
    0840: 750A             jne      0x84c
    0842: 56               push     si
    0843: E85200           call     0x898                ; dmvid_parseDriverName(fp) [alloc buffer]
    0846: 83C402           add      sp, 2
    0849: EB06             jmp      0x851
    084B: 90               nop

loc_084C:
    ; Use existing buffer
    084C: 8B4404           mov      ax, word ptr [si + 4] ; fp->base
    084F: 8904             mov      word ptr [si], ax    ; fp->ptr = fp->base

loc_0851:
    ; Read data from file into buffer
    0851: 8A4407           mov      al, byte ptr [si + 7] ; fd
    0854: 98               cbw
    0855: 8BD8             mov      bx, ax
    0857: D1E3             shl      bx, 1
    0859: 03D8             add      bx, ax
    085B: D1E3             shl      bx, 1
    085D: FFB7CA02         push     word ptr [bx + 0x2ca] ; buffer size
    0861: FF7404           push     word ptr [si + 4]    ; buffer base
    0864: 98               cbw
    0865: 50               push     ax                   ; fd
    0866: E8E31F           call     0x284c               ; _read(fd, buf, size)
    0869: 83C406           add      sp, 6
    086C: 894402           mov      word ptr [si + 2], ax ; fp->cnt = bytes read
    086F: 0BC0             or       ax, ax
    0871: 7F15             jg       0x888                ; data read ok

    ; Handle EOF or error
    0873: 0BC0             or       ax, ax
    0875: 7405             je       0x87c
    0877: B020             mov      al, 0x20             ; error flag
    0879: EB03             jmp      0x87e
    087B: 90               nop

loc_087C:
    087C: B010             mov      al, 0x10             ; EOF flag

loc_087E:
    087E: 084406           or       byte ptr [si + 6], al ; set flag
    0881: C744020000       mov      word ptr [si + 2], 0
    0886: EB82             jmp      0x80a                ; return EOF

loc_0888:
    ; Return first character from refilled buffer
    0888: FF4C02           dec      word ptr [si + 2]    ; fp->cnt--
    088B: 8B1C             mov      bx, word ptr [si]    ; ptr
    088D: FF04             inc      word ptr [si]        ; fp->ptr++
    088F: 8A07             mov      al, byte ptr [bx]    ; ch = *ptr
    0891: 2AE4             sub      ah, ah
    0893: 5E               pop      si
    0894: 5F               pop      di
    0895: 5D               pop      bp
    0896: C3               ret
    0897: 90               nop

; ----------------------------------------------------------------------
; Function: dmvid_parseDriverName (buffer allocator)
; Address:  0898
; Params:   FILE *fp [bp+4]
; Returns:  void (allocates and initializes buffer for FILE*)
; Description:
;   Allocates a 512-byte I/O buffer via _malloc for the given FILE
;   stream, or falls back to a 1-byte unbuffered mode if allocation
;   fails. This is the MSC 5.0 _allocbuf() routine.
; ----------------------------------------------------------------------
dmvid_parseDriverName:
    ; /* address: 0000:0898 */
    0898: 55               push     bp
    0899: 8BEC             mov      bp, sp
    089B: 56               push     si
    089C: B80002           mov      ax, 0x200            ; 512 bytes
    089F: 50               push     ax
    08A0: E8BF21           call     0x2a62               ; _malloc(512)
    08A3: 83C402           add      sp, 2
    08A6: 8B5E04           mov      bx, word ptr [bp + 4]
    08A9: 894704           mov      word ptr [bx + 4], ax ; fp->base = ptr
    08AC: 0BC0             or       ax, ax
    08AE: 7418             je       0x8c8                ; alloc failed

    ; Success: set up 512-byte buffer
    08B0: 804F0608         or       byte ptr [bx + 6], 8 ; set "buffer allocated" flag
    08B4: 8A4707           mov      al, byte ptr [bx + 7] ; fd
    08B7: 98               cbw
    08B8: 8BD8             mov      bx, ax
    08BA: D1E3             shl      bx, 1
    08BC: 03D8             add      bx, ax
    08BE: D1E3             shl      bx, 1
    08C0: C787CA020002     mov      word ptr [bx + 0x2ca], 0x200 ; buf size = 512
    08C6: EB21             jmp      0x8e9

loc_08C8:
    ; Failure: use 1-byte unbuffered mode
    08C8: 8B5E04           mov      bx, word ptr [bp + 4]
    08CB: 804F0604         or       byte ptr [bx + 6], 4 ; set "no buffer" flag
    08CF: 8A4707           mov      al, byte ptr [bx + 7]
    08D2: 98               cbw
    08D3: 8BC8             mov      cx, ax
    08D5: D1E0             shl      ax, 1
    08D7: 03C1             add      ax, cx
    08D9: D1E0             shl      ax, 1
    08DB: 8BF0             mov      si, ax
    08DD: 05C902           add      ax, 0x2c9            ; point to 1-byte inline buffer
    08E0: 894704           mov      word ptr [bx + 4], ax
    08E3: C784CA020100     mov      word ptr [si + 0x2ca], 1

loc_08E9:
    ; Initialize stream pointers
    08E9: 8B5E04           mov      bx, word ptr [bp + 4]
    08EC: 8BF3             mov      si, bx
    08EE: 8B4404           mov      ax, word ptr [si + 4] ; base
    08F1: 8907             mov      word ptr [bx], ax    ; ptr = base
    08F3: C747020000       mov      word ptr [bx + 2], 0 ; cnt = 0
    08F8: 5E               pop      si
    08F9: 5D               pop      bp
    08FA: C3               ret
    08FB: 90               nop

; ----------------------------------------------------------------------
; Function: dmvid_searchConfigKey (fputc)
; Address:  08FC
; Params:   int ch [bp+4], FILE *fp [bp+6]
; Returns:  AX = character written, or 0xFFFF on error
; Description:
;   Writes a single character to the file stream. If the buffer is
;   full, flushes it to disk via _write(). This is the MSC 5.0
;   fputc() implementation.
; ----------------------------------------------------------------------
dmvid_searchConfigKey:
    ; /* address: 0000:08FC */
    08FC: 55               push     bp
    08FD: 8BEC             mov      bp, sp
    08FF: 83EC06           sub      sp, 6
    0902: 57               push     di
    0903: 56               push     si
    0904: 8B7606           mov      si, word ptr [bp + 6] ; FILE*
    ; Validate stream state
    0907: F6440683         test     byte ptr [si + 6], 0x83
    090B: 7406             je       0x913
    090D: F6440640         test     byte ptr [si + 6], 0x40
    0911: 740D             je       0x920

loc_0913:
    ; Error: set error flag, return -1
    0913: 804C0620         or       byte ptr [si + 6], 0x20
    0917: B8FFFF           mov      ax, 0xffff
    091A: 5E               pop      si
    091B: 5F               pop      di
    091C: 8BE5             mov      sp, bp
    091E: 5D               pop      bp
    091F: C3               ret

loc_0920:
    ; Check read-only conflict
    0920: F6440601         test     byte ptr [si + 6], 1
    0924: 75ED             jne      0x913

    ; Set write mode, prepare buffer
    0926: 804C0602         or       byte ptr [si + 6], 2
    092A: 806406EF         and      byte ptr [si + 6], 0xef ; clear EOF
    092E: 2BC0             sub      ax, ax
    0930: 894402           mov      word ptr [si + 2], ax ; cnt = 0
    0933: 8BF8             mov      di, ax
    0935: 897EFC           mov      word ptr [bp - 4], di

    ; Check if buffer needs allocation
    0938: F6440608         test     byte ptr [si + 6], 8
    093C: 7513             jne      0x951
    093E: 8A4407           mov      al, byte ptr [si + 7] ; fd
    0941: 98               cbw
    0942: 8BD8             mov      bx, ax
    0944: D1E3             shl      bx, 1
    0946: 03D8             add      bx, ax
    0948: D1E3             shl      bx, 1
    094A: F687C80201       test     byte ptr [bx + 0x2c8], 1
    094F: 7461             je       0x9b2

loc_0951:
    ; Buffer exists: flush current contents, then write char
    0951: 8B3C             mov      di, word ptr [si]    ; current ptr
    0953: 2B7C04           sub      di, word ptr [si + 4] ; offset from base
    0956: 8B4404           mov      ax, word ptr [si + 4]
    0959: 40               inc      ax
    095A: 8904             mov      word ptr [si], ax    ; ptr = base + 1
    095C: 8A4407           mov      al, byte ptr [si + 7]
    095F: 98               cbw
    0960: 8BD8             mov      bx, ax
    0962: D1E3             shl      bx, 1
    0964: 03D8             add      bx, ax
    0966: D1E3             shl      bx, 1
    0968: 8B87CA02         mov      ax, word ptr [bx + 0x2ca]
    096C: 48               dec      ax
    096D: 894402           mov      word ptr [si + 2], ax ; cnt = bufsize - 1
    ; Flush pending data if any
    0970: 0BFF             or       di, di
    0972: 7E14             jle      0x988
    0974: 57               push     di                   ; bytes to write
    0975: FF7404           push     word ptr [si + 4]    ; buffer base
    0978: 8A4407           mov      al, byte ptr [si + 7]
    097B: 98               cbw
    097C: 50               push     ax                   ; fd
    097D: E8A81F           call     0x2928               ; __write_fd(fd, buf, count)
    0980: 83C406           add      sp, 6
    0983: 8946FC           mov      word ptr [bp - 4], ax
    0986: EB1F             jmp      0x9a7

loc_0988:
    ; Handle append mode seek
    0988: 8A4407           mov      al, byte ptr [si + 7]
    098B: 98               cbw
    098C: 8946FA           mov      word ptr [bp - 6], ax
    098F: 8BD8             mov      bx, ax
    0991: F687FA0120       test     byte ptr [bx + 0x1fa], 0x20
    0996: 740F             je       0x9a7
    0998: B80200           mov      ax, 2                ; SEEK_END
    099B: 50               push     ax
    099C: 2BC0             sub      ax, ax
    099E: 50               push     ax
    099F: 50               push     ax
    09A0: 53               push     bx
    09A1: E82E1E           call     0x27d2               ; _lseek(fd, 0, SEEK_END)
    09A4: 83C408           add      sp, 8

loc_09A7:
    ; Store the character in the buffer
    09A7: 8B5C04           mov      bx, word ptr [si + 4]
    09AA: 8A4604           mov      al, byte ptr [bp + 4] ; character
    09AD: 8807             mov      byte ptr [bx], al    ; *base = ch
    09AF: E9CC00           jmp      0xa7e

    ; (Remaining fputc paths for unbuffered/device modes follow...)
    ; These handle stdout special case, malloc for new buffers,
    ; and append-mode positioning. Omitted for brevity as they
    ; are standard MSC 5.0 CRT code.

; [Lines 09B2-0A91: remainder of fputc implementation]
; Standard MSC 5.0 code handling:
;   - stdout line-buffered mode (0x9BB-0xA09)
;   - malloc buffer allocation (0xA0A-0xA60)
;   - error/no-buffer fallback (0xA62-0xA7E)
;   - return value handling (0xA7E-0xA91)

; ======================================================================
; STANDARD C LIBRARY FUNCTIONS
; ======================================================================

; _strcat at 0A92 - standard string concatenation
; _strcpy at 0AD2 - standard string copy
; _strlen at 0B04 - standard string length
; _strupr at 0B20 - convert string to uppercase
; _strnicmp at 0B5E area - case-insensitive string compare

; ----------------------------------------------------------------------
; Function: _getch
; Address:  0B5E
; Returns:  AX = character read from keyboard
; Description:
;   Reads a character from standard input without echo.
;   Uses INT 21h/AH=08h (keyboard input without echo).
; ----------------------------------------------------------------------
_getch:
    ; /* address: 0000:0B5E */
    0B5E: B608             mov      dh, 8                ; AH=08h for INT 21h
    ; Falls through to common handler at 0B60

; The handler at 0B60 checks a buffered key state at DS:01CE.
; If no buffered key, calls INT 21h with AH=DH (08h = char input no echo).

; [0B60-0B74: keyboard input handler]

; ----------------------------------------------------------------------
; Function: _fseek
; Address:  0B76
; Params:   FILE *fp [bp+4], long offset [bp+6:bp+8], int whence [bp+0A]
; Returns:  AX = 0 on success, -1 on error
; Description:
;   Seeks within a file stream. Handles buffered stream state,
;   text-mode adjustments, and unbuffered I/O. Standard MSC 5.0.
; ----------------------------------------------------------------------
; [0B76-0E53: _fseek implementation - standard MSC 5.0 CRT]

; _rewind at 0E54 - reset file to beginning
; _strncmp at 0E86 - case-insensitive compare with length
; _strnicmp at 0EDE - case-insensitive compare

; ----------------------------------------------------------------------
; Function: _strstr
; Address:  0F00
; Params:   char *haystack [bp+4], char *needle [bp+6]
; Returns:  AX = pointer to match, or 0 if not found
; Description:
;   Finds the first occurrence of needle in haystack.
;   Standard MSC 5.0 strstr() using REPNE SCASB + REPE CMPSB.
; ----------------------------------------------------------------------
; [0F00-0F5B: _strstr implementation]

; ----------------------------------------------------------------------
; Function: _searchenv
; Address:  0F5C
; Params:   char *filename [bp+4], char *envvar [bp+6], char *result [bp+8]
; Returns:  void (fills result buffer if found)
; Description:
;   Searches for a file along the semicolon-delimited path stored
;   in the environment variable. First checks current directory,
;   then each path component. Uses _access() to check existence.
;   This is how DMVID finds DMCSR.CFG via DMRESCFG/DMCONFIG paths.
; ----------------------------------------------------------------------
; [0F5C-1007: _searchenv implementation]

; _splitpath_helper at 1008 - split semicolon-delimited path entries
; __cintDIV at 104A - CRT init: set up DIV0 handler, file info
; _exit at 110E, __exit at 1125 - program termination
; __setargv at 11FC - parse command line
; __setenvp at 138A - set up environment
; __flush at 13F0, __write at 141B, __flsbuf at 1444 - I/O

; ----------------------------------------------------------------------
; Function: _fopen
; Address:  1472
; Params:   char *path [bp+4], char *mode [bp+6], FILE *fp [bp+8]
; Returns:  AX = FILE* on success, 0 on failure
; Description:
;   Opens a file and initializes the FILE structure. Parses mode
;   string ("r", "w", "r+", etc.), calls _open(), sets up buffering.
; ----------------------------------------------------------------------
; [1472-1565: _fopen implementation]

; _printf_lock at 1566, _printf_unlock at 1614 - thread safety stubs
; __dosretax at 16A2 - extract file descriptor from FILE*

; ----------------------------------------------------------------------
; Function: _vsprintf
; Address:  170A
; Params:   FILE *dest [bp+4], char *fmt [bp+6], va_list args [bp+8]
; Returns:  AX = number of chars written, or -1 on error
; Description:
;   Core of the scanf/sscanf family. Processes format string with
;   %d, %s, %c, %x, %o, %f, %e, %n specifiers. Reads from the
;   input stream and stores values via argument pointers.
;   This is the MSC 5.0 _input() / _doscan() function.
;
;   Format specifier state machine uses a jump table at 0x1A2E
;   for characters 'c' through 'x' (0x63-0x78).
; ----------------------------------------------------------------------
; [170A-1A98: _vsprintf / scanf engine implementation]

; __fmt_scanString at 1A9A - handle %s/%c in scanf
; __fmt_scanNumber at 1B88 - handle %d/%x/%o in scanf
; __fmt_scanFloat at 1D1A - handle %f/%e in scanf
; __fmt_isDigit at 1E58 - check if character is a digit
; __fmt_matchChar at 1E7C - match literal character in format
; __fmt_getc at 1EBA - get next char from input stream
; __fmt_skipWhitespace at 1EDE - skip whitespace in input
; __fmt_checkWidth at 1F14 - check remaining field width

; __fmtout at 1F32 - core printf format engine
; __fmt_outputString at 21F6 - handle %s in printf
; __fassign at 232C - assign float value from string
; __fmt_outputLong at 241A - handle %ld in printf
; __fmt_mulAdd10 at 24BC, __fmt_mulAdd16 at 24FE, __fmt_mulAddN at 255C
; __fmt_formatNumber at 25C4 - number-to-string conversion
; __fmt_padLeft at 268A, __fmt_padRight at 26A2 - padding helpers
; __fmt_outputChar at 26CC - handle %c in printf
; __fmt_outputPercent at 274C - handle %% in printf

; ----------------------------------------------------------------------
; Function: __allocFileSlot
; Address:  2776
; Returns:  AX = pointer to free FILE structure, or 0 if none
; Description:
;   Scans the FILE structure table (starting at DS:0228) for an
;   unused slot. Returns the first slot with flags == 0.
;   Each FILE structure is 8 bytes. Table ends at DS:0340.
; ----------------------------------------------------------------------
; [2776-27B1: __allocFileSlot implementation]

; _close at 27B2 - INT 21h/3Eh close file
; _lseek at 27D2 - INT 21h/42h seek file
; _read at 284C - INT 21h/3Fh read file
; __write_fd at 2928 - INT 21h/40h write to fd
; __read_textmode at 29CE - CR/LF translation for text mode reads
; __flsbuf_sync at 2A50 - sync after buffer flush

; ----------------------------------------------------------------------
; Function: _malloc
; Address:  2A62
; Params:   unsigned int size [bp+4]
; Returns:  AX = pointer to allocated block, or 0
; Description:
;   Allocates memory from the heap. Initializes heap on first call.
;   Uses a linked-list free-list allocator. Falls back to sbrk.
; ----------------------------------------------------------------------
; [2A62-2AA7: _malloc implementation]

; _ltoa at 2AA8 - long-to-ASCII conversion
; _getenv at 2AC4 - get environment variable
; _isatty at 2B1A - check if fd is a character device
; __clearerr at 2B3E - clear stream error flags
; _ftell at 2B4A - get current file position
; _access at 2CC0 - INT 21h/43h check file access
; _getcwd at 2CF4 - get current working directory
; _unlink at 2DA6 - INT 21h/41h delete file
; __brk at 2E8C - adjust program break
; __chkstk at 2F38 - stack overflow check/probe
; __sbrk_grow at 2F4E - grow data segment
; _bdos at 33A0 - raw INT 21h call
; _intdos at 33B2 - extended INT 21h call
; _memset at 33FA - fill memory
; __shift32 at 3488 - 32-bit shift helper
; _open at 307E - INT 21h/3Ch,3Dh open/create file
; _sbrk at 33B2 area - heap management

; __fmt_ungetc at 3016 - push character back to stream (used by scanf)

; ======================================================================
; DATA SEGMENT (DS:0000 onwards, at file offset 0x3580)
; ======================================================================
;
; The data segment contains:
;
; DS:0000-0007  CRT internal zero-init area
; DS:0008-006B  "MS Run-Time Library - Copyright (c) 1987, Microsoft Corp"
; DS:0042-0068  Video mode name pointer table (word array, 15 entries)
;               Points to: AUTO, VGA, EGA, MCGA, CGA, HERC, 1000, TC16,
;                           TC40, TC64, T256, HRES, MRES, LRES
; DS:00CD-014C  Character classification table (ctype array, 128 entries)
;               Bit 0x01: uppercase alpha
;               Bit 0x02: lowercase alpha
;               Bit 0x04: digit
;               Bit 0x08: whitespace
;               Bit 0x10: punctuation
;               Bit 0x20: control
;               Bit 0x40: device
;               Bit 0x80: hex digit
; DS:01CE-01CF  Keyboard input state (buffered key)
; DS:01D2-01DD  ";C_FILE_INFO" environment key
; DS:01DF-01E2  Saved INT 00h (divide-by-zero) vector
; DS:01F1-01F2  PSP segment
; DS:01F3-01F4  DOS version (major in low byte)
; DS:01F8-01F9  Maximum open file handles
; DS:01FA-020D  Per-handle flags table (one byte per fd, 20 entries)
; DS:020E-020F  argc
; DS:0210-0211  argv pointer
; DS:0212-0213  envp pointer
; DS:0222-0223  Fatal error handler function pointer
; DS:0226-0227  stdout reference counter
; DS:0228-022F  FILE structure: stdin  (fd=0)
; DS:0230-0237  FILE structure: stdout (fd=1)
; DS:0238-023F  FILE structure: stderr (fd=2)
; DS:02C8-033F  File buffer info table (6 bytes per fd, up to 20 fds)
;               Offset 0: flags byte
;               Offset 1: inline 1-byte buffer
;               Offset 2-3: buffer size (WORD)
;               Offset 4-5: temp file name ptr (WORD)
; DS:0340-0341  End-of-FILE-table pointer
; DS:0342-0343  scanf assignment suppression flag
; DS:0344-034A  "(null)" string (used by printf for NULL pointer)
; DS:034B-0351  "(null)" duplicate
; DS:0352-0355  "+- #" printf flag characters
; DS:0358-0359  Heap base pointer
; DS:035A-035B  Heap current pointer
; DS:035E-035F  Heap free list head
; DS:0362-0363  Stack limit address
; DS:0384-0393  printf radix conversion table
; DS:0388-0389  Float assignment function pointer (__fassign)
; DS:03A4-03A4  onexit function table
; DS:03A5-03A9  "/AUTO" command-line switch
; DS:03AB-03AF  "1000" mode name
; DS:03B0-03B7  "AUTO" mode name
; DS:03B8-03BC  "HERC" mode name
; DS:03BD-03C0  "VGA" mode name (with padding)
; DS:03C1-03C4  "MCGA" mode name
; DS:03C5-03C8  "EGA" mode name (with padding)
; DS:03C9-03CD  "CGA" mode name
; DS:03CA-03CE  "TC16" mode name
; DS:03CF-03D3  "TC40" mode name
; DS:03D4-03D8  "TC64" mode name
; DS:03D9-03DD  "T256" mode name
; DS:03DE-03E2  "HRES" mode name
; DS:03E3-03E7  "MRES" mode name
; DS:03E8-03EC  "LRES" mode name
; DS:03F0-0418  "Video configuration has NOT been updated."
; DS:041B-0446  "Video configuration has been updated in %s."
; DS:0449-0471  "Video configuration has NOT been updated." (duplicate)
; DS:0479-0482  "DMCSR.CFG"
; DS:0483-04B3  "For further information refer to file DMVID.DOC."
; DS:04B6-04E3  "Video is currently set to use DMVS%s driver."
; DS:04E5-051C  "Video is currently set for AUTO detection by DESKMATE."
; DS:051E-053E  " 1 - <AUTO>  Automatic detection"
; DS:0540-057B  " 2 - <VGA>   Video Graphics Array,      640x480  16 colors "
; DS:057D-05B8  " 3 - <EGA>   Enhanced Graphics Adapter, 640x350  16 colors "
; DS:05BA-05F5  " 4 - <MCGA>  Multi Color Graphics Array,640x480   2 colors "
; DS:05F7-0632  " 5 - <CGA>   Color Graphics Adapter,    640x200   2 colors "
; DS:0634-0677  " 6 - <HERC>  Hercules,    720x348 monochrome, 80 column video mode "
; DS:0679-06BC  " 7 - <1000>  Tandy 1000,  640x200   4 colors, 80 column video mode "
; DS:06BE-0701  " 8 - <TC16>  Tandy Color, 640x200  16 colors, 80 column video mode "
; DS:0703-0713  " 9 - Exit to DOS"
; DS:0717-074B  "Select one of the displayed video options "
; DS:074C-0754  "DMRESCFG" (config section name)
; DS:0755-075E  "dmcsr.cfg" (filename, lowercase)
; DS:075F-0767  "DMCONFIG" (fallback config section)
; DS:0768-0771  "dmcsr.cfg" (filename, lowercase)
; DS:0777-079C  "Insert the disk containing DMCSR.CFG,"
; DS:079E-07CC  "Enter PATH-NAME where the file could be found."
; DS:07CE-07E7  "or press ESC to cancel..."
; DS:07EE-07F8  "\DMCSR.CFG" (with leading backslash)
; DS:07F9-0803  "csr_config" (INI key name)
; DS:0804-080C  "<<NMSG>>" (runtime error message marker)
; DS:080E-0829  "R6000" / "- stack overflow"
; DS:082A-084A  "R6003" / "- integer divide by 0"
; DS:084B-087D  "R6009" / "- not enough space for environment"
; DS:087E-088F  "run-time error "
; DS:0890-08B4  "R6001" / "- null pointer assignment"
; DS:08B5-08D6  "R6002" / "- floating point not loaded"
;
; DS:0B30-0C2F  Config path buffer (256 bytes, runtime)
;
; ============================================================================
; END OF ANNOTATED DISASSEMBLY
; ============================================================================
