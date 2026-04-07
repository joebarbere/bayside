; ========================================================================
; PRGUF.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Program User Functions (core PDM API thunk library)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; PRGUF.RES is the core Program User Functions library for DeskMate 3.05.
; It is the primary API thunk table that every .PDM application calls.
; PRGUF provides a comprehensive set of system services including:
;
;   - File I/O wrappers (open, close, read, write, create, seek, attrib)
;   - Path/directory management (chdir, getcwd, set/get drive, parse paths)
;   - Resource string management (search, add, remove, modify)
;   - Drive enumeration and disk free space queries
;   - INT 24h critical error handler installation
;   - Environment variable lookup (via PSP environment block)
;   - DOS version checking and drive bitmap building
;   - DeskMate host integration (INT E0h registration and dispatch)
;
; The library installs as a TSR via INT 21h/31h after registering with
; the DeskMate host through INT E0h. It exports its function table at
; seg_014C, which contains word-sized offsets into the main code segment
; (seg_0000) for each API function.
;
; String identifiers: "PRGUF", version "1.24L"
; Companion module: "DMCSR" (referenced for string resource loading)
; Label files: DESKMATE.LBL, LABEL.LBL, TASK .LBL
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 7064 bytes
; Code+data size: 6552 bytes
; DM89 entry point: 0155:000C
; SS:SP = 019A:0002
;
; DM89 signature: present
; DM89 raw: 444d38393e000000000000000a0055010d004c010000000000000000000000000101
;
; Segment Map (6 segments, 14 relocations):
;   seg_0000  0x14C0 bytes  CODE       Main PRGUF functions (file I/O, paths, resources)
;   seg_014C  0x0090 bytes  DATA       API function dispatch table (word offsets)
;   seg_0155  0x00E0 bytes  CODE       TSR startup, INT E0h dispatch, entry point
;   seg_0163  0x0368 bytes  DATA       PRGUF name, version, strings, BSS workspace
;   seg_019A  (BSS)         STACK      Stack segment
;   seg_019B  (BSS)         BSS        Uninitialized data
;
; Relocation Table (14 entries):
;   0163:0010 -> seg_0155    0163:0014 -> seg_0155
;   0163:002F -> seg_014C    0000:0003 -> seg_014C
;   0000:0008 -> seg_0000    0155:000D -> seg_0163
;   0155:0037 -> seg_0000    0155:005D -> seg_019B
;   0155:0060 -> seg_0163    0155:006C -> seg_0000
;   0155:006F -> seg_019B    0155:00B4 -> seg_0000
;   0163:0042 -> seg_0155    0155:00D3 -> seg_0163
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Resource String Pool (pointed to by [0x252]):
;   The resource string pool is a linear buffer starting at DGROUP+BSS.
;   [0x252]  g_poolBase     - Base offset of string pool in DS
;   [0x254]  g_poolMax      - Maximum pool size (bytes available)
;   [0x29F]  g_poolUsed     - Current bytes used in pool
;   [0x297]  g_currentDesc  - Pointer to current resource descriptor
;   [0x29B]  g_searchResult - Pointer after successful string search
;   [0x29D]  g_matchResult  - Pointer to matched entry data
;
; Resource Descriptor (passed by caller, in ES segment):
;   [+0x00]  filename_ptr   - Pointer to filename string
;   [+0x02]  env_var_ptr    - Pointer to environment variable name (or NULL)
;   [+0x04]  type_byte      - Resource type (1=file, 3=label)
;   [+0x05]  key_string_ptr - Pointer to search key string
;   [+0x07]  data_ptr       - Pointer to data buffer
;   [+0x09]  data_seg       - Segment of data buffer
;   [+0x0B]  data_size      - Size of data in bytes
;
; Path workspace:
;   [0x0046] g_savedPoolPtr - Saved pool search pointer
;   [0x00D0] g_int24Handler - INT 24h handler routine (installed at 0x00D0)
;   [0x00D2] g_int24Params  - INT 24h parameters area
;   [0x00D8] g_savedDrive   - Saved current drive letter
;   [0x00DA] g_cwdBuffer    - Current working directory buffer (64+ bytes)
;   [0x0129] g_pathBuffer   - Temporary path assembly buffer
;   [0x0179] g_fnameOffset  - Filename component offset in path
;   [0x017B] g_fnameLength  - Filename component length
;   [0x017E] g_mutexId      - DeskMate mutex/resource ID
;   [0x0256] g_resolvedPath - Resolved full path buffer
;
; INT 24h Critical Error Handler:
;   [0x003A] g_int24Vector  - Far pointer to critical error handler
;   [0x003E] g_savedInt24   - Saved original INT 24h vector (seg:off)
;   [0x0042] g_int24Seg     - Segment for INT 24h handler
;
; Drive State:
;   [0x0323] g_dosVersion   - DOS major version (used to branch behavior)
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- File I/O Functions ---
;
;   Address   Name                         Size  Description
;   -------   ----                         ----  -----------
;   0000:0048 prguf_renameFile              28   DOS rename file (INT 21h/56h)
;   0000:007E prguf_deleteFile              20   DOS delete file (INT 21h/41h)
;   0000:0F7B prguf_openFile                54   DOS open file (INT 21h/3Dh), with error handling
;   0000:0FAB prguf_readFile                36   DOS read file (INT 21h/3Fh), with error handling
;   0000:0FEF prguf_writeFile               42   DOS write/verify (INT 21h/40h), checks bytes written
;   0000:1041 prguf_createFile              17   DOS create file (INT 21h/3Ch)
;   0000:1057 prguf_getFileAttrib           19   DOS get file attributes (INT 21h/43h)
;   0000:106F prguf_closeFile               14   DOS close file (INT 21h/3Eh)
;   0000:107D (inline)                      --   DOS dup file handle (INT 21h/45h)
;   0000:108D (inline)                      --   DOS IOCTL / lseek (INT 21h/5Ch)
;
; --- Path/Directory Management ---
;
;   0000:10CD prguf_getCurrentDir            36   Get current directory (INT 21h/47h)
;   0000:10F0 prguf_getDefaultDrive          22   Get default drive letter (INT 21h/19h)
;   0000:1106 (inline)                       --   Set default drive (INT 21h/0Eh)
;   0000:11CB prguf_showErrorDialog          44   Show filename error dialog via INT E0h
;   0000:11FC prguf_validateDrivePath        82   Validate drive letter exists, show error if not
;   0000:127C prguf_parsePath               538   Full path parser: resolve drive, chdir, validate 8.3
;
; --- Drive Enumeration ---
;
;   0000:111E prguf_buildDriveBitmap         26   Detect DOS version, call appropriate enumerator
;   0000:1138 prguf_enumDrives_DOS3          62   Enumerate drives via IOCTL (DOS 3+, INT 21h/44h)
;   0000:1176 prguf_enumDrives_getCount      14   Get drive count via set/get drive
;   0000:1184 prguf_buildDriveMask           28   Build bitmask from drive count
;   0000:11A0 prguf_checkFloppyConfig        28   Check BIOS floppy config at 0070:0000
;   0000:11BC prguf_checkPrinterPorts        12   Check printer ports via INT 11h equipment list
;
; --- Disk Space ---
;
;   0000:1253 prguf_getDiskFreeSpace         36   Get disk free space (INT 21h/36h)
;
; --- INT 24h Critical Error Handler ---
;
;   0000:0094 prguf_installInt24Handler      26   Install custom INT 24h via INT E0h/02h
;   0000:00AF prguf_restoreInt24Handler      15   Restore original INT 24h via INT E0h/02h
;   0000:00BE prguf_setErrorFlag_16          --   Set AX=0x2016, jump to INT E0h far call
;   0000:00C8 prguf_setErrorFlag_E9          --   Set AX=0x20E9, jump to INT E0h far call
;   0000:00F6 prguf_saveInt24Vector          32   Save INT 24h vector, install custom handler
;   0000:0116 prguf_restoreInt24Vector       10   Restore saved INT 24h vector
;   0000:0137 prguf_flushAndRestore          18   Flush disk (INT 21h/0Dh) with INT 24h save/restore
;
; --- DOS Error Handling ---
;
;   0000:014A prguf_handleDosError           89   Handle DOS error: get extended error, check write-protect
;   0000:1494 prguf_getWorkingDir            22   Get current working directory into result buffer
;   0000:14AA prguf_translateError           19   Translate DOS error code via prguf_handleDosError
;
; --- String/Resource Management ---
;
;   0000:01D5 prguf_toUpperCase               5   Convert AL to uppercase (a-z -> A-Z)
;   0000:01EA prguf_strToUpper               26   Convert string to uppercase in-place
;   0000:025E prguf_addResource             168   Add resource string entry to pool
;   0000:0306 prguf_removeResource           64   Remove resource string entry from pool
;   0000:0346 prguf_findResource             70   Find and return pointer to resource data
;   0000:0390 prguf_modifyResource          150   Modify existing resource entry
;   0000:0496 (inline)                       --   Resize resource entry
;   0000:04F6 (inline)                       --   Load resource from file
;   0000:0580 (inline)                       --   Copy resource data into workspace
;
; --- Resource Pool Internals ---
;
;   0000:05B6 prguf_extractFilename          84   Extract filename from full path, copy to pool
;   0000:060A prguf_findByName               12   Find resource by name (search + match)
;   0000:0616 prguf_searchPool               94   Search pool for matching filename entry
;   0000:0674 prguf_matchKey                 62   Match key string within found pool entry
;   0000:06B2 prguf_expandPool               58   Expand pool by shifting data, check bounds
;   0000:06EC prguf_shrinkPool               26   Shrink pool by removing bytes, shift data
;   0000:0706 prguf_resolvePathFromDesc      28   Resolve path from descriptor (env var + filename)
;   0000:0722 prguf_buildPathFromEnv         56   Build path from environment variable prefix
;   0000:075B prguf_strlenAndUpper           27   Get string length while converting to uppercase
;   0000:0776 prguf_uppercaseFilename        29   Uppercase the filename from descriptor
;   0000:0793 prguf_searchEnvBlock           40   Search PSP environment block for variable
;   0000:07BB prguf_assemblePath             58   Assemble final path from components
;   0000:07F5 prguf_openResourceFile        122   Open resource file, read data, verify
;   0000:086E prguf_verifyWriteBack          36   Verify write-back of resource data
;   0000:088B prguf_readResourceData         58   Read resource data from file handle
;   0000:08C4 prguf_writeResourceFile        24   Write resource data to file
;   0000:08D9 prguf_closeResourceFile        20   Close resource file after read/write
;   0000:08EC prguf_createResourceFile       66   Create new resource file and write header
;   0000:0960 prguf_allocatePoolEntry        62   Allocate new pool entry for resource
;   0000:09CC prguf_getKeyLength             26   Get length of null-terminated key string
;   0000:09E5 prguf_copyResourceKey          24   Copy resource key string with size prefix
;
; --- TSR Startup / Dispatch (seg_0155) ---
;
;   0155:000C entry_point                   194   TSR entry: register with host, go resident
;   0155:007E prguf_dispatchHandler          81   INT E0h dispatch: save context, call function, restore
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; None. PRGUF is purely a DOS/DeskMate API library with no direct
; hardware I/O. All operations use DOS INT 21h or DeskMate INT E0h.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=01h  -- Register PRGUF with DeskMate host
;   0155:0039  AX=0x01F0/0x01FF, CX=seg_0000
;
; INT E0h, AH=02h  -- Install/query resource handler
;   0000:00A1  AX=0x0206 (install INT 24h handler)
;   0000:00B9  AX=0x0207 (restore INT 24h handler)
;
; INT E0h, AH=06h  -- Query DeskMate host capabilities
;   0155:0027  AX=0x0600 (get feature flags, check bit 15)
;   0000:017D  AX=0x0602 (check write-protect status)
;
; INT E0h, AH=4Dh  -- Acquire/release display mutex
;   0155:0096  AX=0x4D04 (acquire mutex before dispatch)
;   0155:00C5  AX=0x4D05 (release mutex after dispatch)
;
; INT 21h, AH=0Dh  -- Disk reset (flush buffers)
;   0000:0144  Flush all disk buffers
;
; INT 21h, AH=0Eh  -- Select disk / set default drive
;   0000:1180  Set default drive during enumeration
;   0000:12E0  Set drive during path parsing
;   0000:145E  Restore original drive after path operations
;
; INT 21h, AH=19h  -- Get current default drive
;   0000:10FC  Get current drive letter
;   0000:12A9  Save current drive before path operations
;   0000:12E4  Verify drive change succeeded
;
; INT 21h, AH=25h  -- Set interrupt vector
;   0000:0111  Set INT 24h to custom critical error handler
;
; INT 21h, AH=30h  -- Get DOS version
;   0000:1120  Check if DOS >= 3.0 for IOCTL drive enum
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   0155:007C  Install PRGUF as resident driver
;
; INT 21h, AH=35h  -- Get interrupt vector
;   0000:00FD  Save original INT 24h vector before replacing
;
; INT 21h, AH=36h  -- Get disk free space
;   0000:125D  Query free space on specified drive
;
; INT 21h, AH=3Bh  -- Change directory
;   0000:131B  Change to target directory during path parse
;   0000:13E9  Change to intermediate directory component
;   0000:1456  Restore original directory after parse
;
; INT 21h, AH=3Ch  -- Create file
;   0000:104E  Create new file with normal attributes
;
; INT 21h, AH=3Dh  -- Open file
;   0000:0F88  Open file for read/write access
;
; INT 21h, AH=3Eh  -- Close file
;   0000:1079  Close file handle
;
; INT 21h, AH=3Fh  -- Read file
;   0000:0FBA  Read bytes from file handle
;
; INT 21h, AH=40h  -- Write file
;   0000:1004  Write bytes to file handle
;
; INT 21h, AH=42h  -- Seek (lseek)
;   (via inline code at 0000:108D area)
;
; INT 21h, AH=43h  -- Get/set file attributes
;   0000:1066  Get file attributes (AL=0)
;
; INT 21h, AH=44h  -- IOCTL
;   0000:114D  IOCTL/0Eh: Get logical drive map
;   0000:1165  IOCTL/09h: Check if remote drive
;
; INT 21h, AH=47h  -- Get current directory
;   0000:10E4  Get current directory string
;   0000:12BF  Save current directory before parse
;   0000:1303  Re-read directory after drive change
;   0000:14A1  Get working directory into result buffer
;
; INT 21h, AH=51h  -- Get current PSP segment
;   0000:0797  Get PSP to access environment block
;
; INT 21h, AH=59h  -- Get extended error information
;   0000:0166  Get detailed error info after DOS failure
;
; INT 11h           -- Get equipment list
;   0000:11BD  Check for printer/serial ports
;
; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (5312 bytes, file 0x0200-0x16C0)
; Main PRGUF code segment: all API functions
; ------------------------------------------------------------------------
seg_0000:

  ; Bytes 0x0000-0x000A: Far jump to seg_014C dispatch + initial thunk
  0000:0000  db EA 97 00 4C 01 9A F5 0D 00 00 CB                ; |...L.......| [RELOC->seg_014C]

  ; -------------------------------------------------------------------
  ; prguf_thunkCaller  (0000:000B)
  ; Thunk that saves registers, sets up far call through dispatch table,
  ; then restores registers. Used by inline code stubs.
  ; -------------------------------------------------------------------
  0000:000B  db 57 56 53 51                                     ; "WVSQ" (push di,si,bx,cx)
  0000:000F  db BE 56 02 B9 49 00 2B E1 8B FC FC F3 A4 1E 26 8E ; |.V..I.+.......&.|
  0000:001F  db 5F FE 07 8B F0 03 F6 06 26 8E 06 2F 00 26 8B B4 ; |_.......&../.&..|
  0000:002F  db 0D 00 07 FF D6 8B F4 16 1F BF 56 02 B9 49 00 FC ; |..........V..I..|
  0000:003F  db F3 A4 83 C4                                     ; |....|
  0000:0043  db 49 59 5B 5E 5F                                  ; "IY[^_" (pop cx,bx,si,di)
  0000:0048  db 16 06 1F 07 CB                                  ; retf (end of thunk)

  ; -------------------------------------------------------------------
  ; prguf_renameFile  (0000:004D)
  ; Rename a file using DOS INT 21h/56h.
  ; Params: [bp+6]=old name ptr, [bp+8]=new name ptr
  ; Returns: AX=0 on success, AX=0xFFFF on error
  ; -------------------------------------------------------------------
  0000:004D  db 55 8B EB 57 56 06 1E 07 8B 56 06               ; push bp; mov bp,sp; ...
  0000:0058  db 8B 7E 08 B4 56 CD 21 07 26 C7 06 32 00 00 00 73 ; |.~..V.!.&..2...s|
  0000:0068  db 0E FF 76 04 E8 DB 00 83 C4 02 B8 FF FF EB 04 26 ; |..v............&|
  0000:0078  db A1 32 00 5E 5F 5D C3                            ; mov ax,[0x32]; pop si,di,bp; ret

  ; -------------------------------------------------------------------
  ; prguf_deleteFile  (0000:007E)
  ; Delete a file using DOS INT 21h/41h.
  ; Params: [bp+6]=filename ptr
  ; Returns: AX=0 on success, error otherwise
  ; -------------------------------------------------------------------
  0000:007E  db 55 8B EB 57 56 8B 56 06 B4                     ; push bp; ...
  0000:0088  db 41 CD 21 26 C7 06 32 00 00 00 EB D3             ; |A.!&..2.....|

; -------------------------------------------------------------------
; prguf_installInt24Handler  (0000:0094)
; Install custom INT 24h critical error handler via INT E0h/02h.
; Saves ES/BX, sets DS=ES, calls INT E0h with AX=0x0206.
; Returns: AX=0 if already installed, AX=0xFFFF if newly installed.
; -------------------------------------------------------------------
sub_0000_0094:                                  ; prguf_installInt24Handler
  0000:0094  06                push     es
  0000:0095  53                push     bx
  0000:0096  1e                push     ds
  0000:0097  07                pop      es
  0000:0098  ba3400            mov      dx, 0x34                ; offset of handler descriptor
  0000:009B  bb3a00            mov      bx, 0x3a                ; offset of far-call vector
  0000:009E  b80602            mov      ax, 0x206               ; INT E0h fn 02h/06h: install handler
  0000:00A1  cde0              int      0xe0                    ; INT E0h, AH=02h
  0000:00A3  0bc0              or       ax, ax
  0000:00A5  b8ffff            mov      ax, 0xffff
  0000:00A8  7402              je       0xac                    ; -> loc_0000_00AC
  0000:00AA  33c0              xor      ax, ax                  ; already installed, return 0

loc_0000_00AC:
  0000:00AC  5b                pop      bx
  0000:00AD  07                pop      es
  0000:00AE  c3                ret

; -------------------------------------------------------------------
; prguf_restoreInt24Handler  (0000:00AF)
; Restore original INT 24h handler via INT E0h/02h (AX=0x0207).
; -------------------------------------------------------------------
sub_0000_00AF:                                  ; prguf_restoreInt24Handler
  0000:00AF  52                push     dx
  0000:00B0  ba3400            mov      dx, 0x34
  0000:00B3  b80702            mov      ax, 0x207               ; INT E0h fn 02h/07h: restore handler
  0000:00B6  06                push     es
  0000:00B7  1e                push     ds
  0000:00B8  07                pop      es
  0000:00B9  cde0              int      0xe0                    ; INT E0h, AH=02h
  0000:00BB  07                pop      es
  0000:00BC  5a                pop      dx
  0000:00BD  c3                ret

; -------------------------------------------------------------------
; prguf_setErrorFlag_16  (0000:00BE)
; Set error code AX=0x2016, then call through far pointer at [0x3A].
; -------------------------------------------------------------------
sub_0000_00BE:                                  ; prguf_setErrorFlag_16
  0000:00BE  b81620            mov      ax, 0x2016
  0000:00C1  eb14              jmp      0xd7                    ; -> loc_0000_00D7

  ; (0000:00C3) - variant: AX=0x2015
  0000:00C3  db B8 15 20 EB 0F                                  ; |.. ..|

; -------------------------------------------------------------------
; prguf_setErrorFlag_E9  (0000:00C8)
; Set error code AX=0x20E9, then call through far pointer at [0x3A].
; -------------------------------------------------------------------
sub_0000_00C8:                                  ; prguf_setErrorFlag_E9
  0000:00C8  b8e920            mov      ax, 0x20e9
  0000:00CB  eb0a              jmp      0xd7                    ; -> loc_0000_00D7
  0000:00CD  db B8 E3 20 EB 05 B8 E4 20 EB 00                   ; |.. .... ..|

; -------------------------------------------------------------------
; Common far-call dispatcher for error flag functions
; Adjusts BP to skip return address, then calls [0x3A] (INT E0h vector).
; -------------------------------------------------------------------
loc_0000_00D7:
  0000:00D7  55                push     bp
  0000:00D8  8bec              mov      bp, sp
  0000:00DA  83c504            add      bp, 4
  0000:00DD  ff1e3a00          lcall    [0x3a]                  ; far call to DeskMate handler
  0000:00E1  5d                pop      bp
  0000:00E2  c3                ret

  ; (0000:00E3) - AX=0x0605, call INT E0h directly
  0000:00E3  db B8 05 06 EB 00                                  ; |.....|
  0000:00E8  55                push     bp
  0000:00E9  8bec              mov      bp, sp
  0000:00EB  83c504            add      bp, 4
  0000:00EE  06                push     es
  0000:00EF  1e                push     ds
  0000:00F0  07                pop      es
  0000:00F1  cde0              int      0xe0                    ; INT E0h (generic call)
  0000:00F3  07                pop      es
  0000:00F4  5d                pop      bp
  0000:00F5  c3                ret

; -------------------------------------------------------------------
; prguf_saveInt24Vector  (0000:00F6)
; Save current INT 24h vector to [0x3E..0x41], then install custom
; handler from segment [0x42] at offset 0xD0.
; Uses INT 21h/35h (get) and INT 21h/25h (set).
; -------------------------------------------------------------------
sub_0000_00F6:                                  ; prguf_saveInt24Vector
  0000:00F6  06                push     es
  0000:00F7  1e                push     ds
  0000:00F8  06                push     es
  0000:00F9  1f                pop      ds
  0000:00FA  b82435            mov      ax, 0x3524              ; INT 21h/35h: get INT 24h vector
  0000:00FD  cd21              int      0x21
  0000:00FF  891e3e00          mov      word ptr [0x3e], bx     ; save offset
  0000:0103  8c064000          mov      word ptr [0x40], es     ; save segment
  0000:0107  8e1e4200          mov      ds, word ptr [0x42]     ; load handler segment
  0000:010B  bad000            mov      dx, 0xd0                ; handler offset

loc_0000_010E:
  0000:010E  b82425            mov      ax, 0x2524              ; INT 21h/25h: set INT 24h vector
  0000:0111  cd21              int      0x21
  0000:0113  1f                pop      ds
  0000:0114  07                pop      es
  0000:0115  c3                ret

; -------------------------------------------------------------------
; prguf_restoreInt24Vector  (0000:0116)
; Restore saved INT 24h vector from [ES:0x3E].
; -------------------------------------------------------------------
sub_0000_0116:                                  ; prguf_restoreInt24Vector
  0000:0116  06                push     es
  0000:0117  1e                push     ds
  0000:0118  26c5163e00        lds      dx, ptr es:[0x3e]      ; load saved vector
  0000:011D  ebef              jmp      0x10e                   ; -> set vector and return

  ; (0000:011F) - inline: close file handle then flush/restore
  0000:011F  db 55 8B EB E8 D1 FF 8B 5E 06 B4 3E CD 21 B4 0D CD ; |U......^..>.!...|
  0000:012F  db 21 E8 E3 FF 33 C0 5D C3                         ; |!...3.].|

; -------------------------------------------------------------------
; prguf_flushAndRestore  (0000:0137)
; If DOS version <= 2, save INT 24h, flush disk buffers (INT 21h/0Dh),
; then restore INT 24h. Skipped for DOS 3+.
; -------------------------------------------------------------------
sub_0000_0137:                                  ; prguf_flushAndRestore
  0000:0137  26803e230302      cmp      byte ptr es:[0x323], 2  ; check DOS version
  0000:013D  7f0a              jg       0x149                   ; DOS 3+: skip
  0000:013F  e8b4ff            call     0xf6                    ; -> prguf_saveInt24Vector
  0000:0142  b40d              mov      ah, 0xd
  0000:0144  cd21              int      0x21                    ; INT 21h/0Dh: flush all buffers
  0000:0146  e8cdff            call     0x116                   ; -> prguf_restoreInt24Vector

loc_0000_0149:
  0000:0149  c3                ret

; -------------------------------------------------------------------
; prguf_handleDosError  (0000:014A)
; Handle a DOS error: store error code, get extended error info (DOS 3+),
; check for write-protect (error 0x53), prompt user to retry.
; Params: AX=DOS error code, [bp+4]=pointer to result word
; Returns: result word set to error code, 0xFFFF, or 0xFFFE
; -------------------------------------------------------------------
sub_0000_014A:                                  ; prguf_handleDosError
  0000:014A  55                push     bp
  0000:014B  8bec              mov      bp, sp
  0000:014D  53                push     bx
  0000:014E  8b5e04            mov      bx, word ptr [bp + 4]   ; pointer to result
  0000:0151  8907              mov      word ptr [bx], ax       ; store initial error
  0000:0153  26803e230302      cmp      byte ptr es:[0x323], 2  ; DOS version
  0000:0159  742b              je       0x186                   ; DOS 2: skip extended error
  0000:015B  51                push     cx
  0000:015C  52                push     dx
  0000:015D  56                push     si
  0000:015E  57                push     di
  0000:015F  1e                push     ds
  0000:0160  06                push     es
  0000:0161  b459              mov      ah, 0x59
  0000:0163  bb0000            mov      bx, 0
  0000:0166  cd21              int      0x21                    ; INT 21h/59h: Get extended error
  0000:0168  07                pop      es
  0000:0169  1f                pop      ds
  0000:016A  5f                pop      di
  0000:016B  5e                pop      si
  0000:016C  5a                pop      dx
  0000:016D  59                pop      cx
  0000:016E  3d5300            cmp      ax, 0x53                ; error 0x53 = fail on INT 24h
  0000:0171  7528              jne      0x19b                   ; -> not write-protect
  0000:0173  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0176  c707ffff          mov      word ptr [bx], 0xffff   ; set result = -1

loc_0000_017A:                                  ; retry loop for write-protect
  0000:017A  b80206            mov      ax, 0x602
  0000:017D  cde0              int      0xe0                    ; INT E0h/06h: check write-protect
  0000:017F  3d0000            cmp      ax, 0
  0000:0182  740a              je       0x18e                   ; user chose retry: set -2
  0000:0184  eb0f              jmp      0x195                   ; user chose cancel: flush

loc_0000_0186:                                  ; DOS 2 path
  0000:0186  3dffff            cmp      ax, 0xffff
  0000:0189  74ef              je       0x17a                   ; -> retry loop
  0000:018B  eb13              jmp      0x1a0                   ; -> done
  0000:018D  db 90                                              ; |.| (padding)

loc_0000_018E:
  0000:018E  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0191  c707feff          mov      word ptr [bx], 0xfffe   ; result = -2 (retry)

loc_0000_0195:
  0000:0195  e89fff            call     0x137                   ; -> prguf_flushAndRestore
  0000:0198  eb06              jmp      0x1a0                   ; -> done
  0000:019A  db 90                                              ; |.| (padding)

loc_0000_019B:
  0000:019B  8b5e04            mov      bx, word ptr [bp + 4]
  0000:019E  8907              mov      word ptr [bx], ax       ; store actual error code

loc_0000_01A0:
  0000:01A0  5b                pop      bx
  0000:01A1  5d                pop      bp
  0000:01A2  c3                ret

  ; (0000:01A3) inline: getCountryInfo wrapper + uppercase helper
  0000:01A3  db 55 8B EB 8B 56 06 EB 01 55 B0 00 B4 38 CD 21 72 ; |U...V...U...8.!r|
  0000:01B3  db 11 83 FB 2C 75 08 8B DA 8D 5F 11 C6 07 01 2B C0 ; |...,u...._....+.|
  0000:01C3  db EB 03 B8 FF FF 5D C3 55 8B EB 8B 46 06 E8 02 00 ; |.....].U...F....|
  0000:01D3  db 5D C3                                           ; |].|

; -------------------------------------------------------------------
; prguf_toUpperCase  (0000:01D5)
; Convert character in AL to uppercase. Uses far call to DeskMate
; character mapping function at ES:[0x35E].
; Returns: AL = uppercase character
; -------------------------------------------------------------------
sub_0000_01D5:                                  ; prguf_toUpperCase
  0000:01D5  26ff1e5e03        lcall    es:[0x35e]             ; far call to charmap function
  0000:01DA  3c7a              cmp      al, 0x7a               ; 'z'
  0000:01DC  7706              ja       0x1e4                   ; above 'z': no change
  0000:01DE  3c61              cmp      al, 0x61               ; 'a'
  0000:01E0  7202              jb       0x1e4                   ; below 'a': no change
  0000:01E2  245f              and      al, 0x5f               ; clear bit 5 = uppercase

loc_0000_01E4:
  0000:01E4  c3                ret

  ; (0000:01E5) inline wrapper with bp setup
  0000:01E5  db 55 8B EB EB 03                                  ; |U....|

  ; -------------------------------------------------------------------
  ; prguf_strToUpper  (0000:01EA)
  ; Convert null-terminated string at [bp+6] to uppercase in-place.
  ; -------------------------------------------------------------------
  0000:01EA  55                push     bp
  0000:01EB  8bec              mov      bp, sp
  0000:01ED  56                push     si
  0000:01EE  8b7606            mov      si, word ptr [bp + 6]   ; string pointer
  0000:01F1  33c0              xor      ax, ax

loc_0000_01F3:                                  ; loop over each character
  0000:01F3  8a04              mov      al, byte ptr [si]
  0000:01F5  3c00              cmp      al, 0
  0000:01F7  7408              je       0x201                   ; end of string
  0000:01F9  e8d9ff            call     0x1d5                   ; -> prguf_toUpperCase
  0000:01FC  8804              mov      byte ptr [si], al       ; store back
  0000:01FE  46                inc      si
  0000:01FF  ebf2              jmp      0x1f3                   ; -> loop

loc_0000_0201:
  0000:0201  5e                pop      si
  0000:0202  5d                pop      bp
  0000:0203  c3                ret

  ; (0000:0204-025D) inline: case-insensitive compare, string pool init
  0000:0204  db 55 8B EB 1E 8B 46 06 8B 56 08 26 83 3E 5A 03 00 ; |U....F..V.&.>Z..|
  0000:0214  db 74 0E 26 C5 1E 5A 03 8B C2 D7 8B D0 8B 46 06 D7 ; |t.&..Z.......F..|
  0000:0224  db 2B C2 1F 5D C3 55 8B EB 1E 8B 46 08 E8 A2 FF 8B ; |+..].U....F.....|
  0000:0234  db D0 8B 46 06 E8 9A FF EB D1 50 51 56 06 8B 36 52 ; |..F......PQV..6R|
  0000:0244  db 02 C6 04 00 8B 0E 54 02 C7 06 9F 02 00 00 BE 38 ; |......T........8|
  0000:0254  db 02 C6 44 04 00 07 5E 59 58 C3                   ; |..D...^YX.|

  ; -------------------------------------------------------------------
  ; prguf_addResource  (0000:025E)
  ; Add a new resource string entry to the pool.
  ; Two entry points: near at 0x25E (param at bp+4), far at 0x266 (bp+6).
  ; Params: AX=resource descriptor pointer
  ; Returns: AX=0 on success, AX=0xFFFF on failure
  ; -------------------------------------------------------------------
  0000:025E  55                push     bp
  0000:025F  8bec              mov      bp, sp
  0000:0261  8b4604            mov      ax, word ptr [bp + 4]
  0000:0264  eb06              jmp      0x26c                   ; -> common entry
  0000:0266  db 55 8B EB 8B 46 06                               ; |U...F.| (far entry)

loc_0000_026C:
  0000:026C  06                push     es                      ; swap DS/ES for pool access
  0000:026D  1e                push     ds
  0000:026E  07                pop      es
  0000:026F  1f                pop      ds
  0000:0270  a39702            mov      word ptr [0x297], ax    ; save descriptor ptr
  0000:0273  e89403            call     0x60a                   ; -> prguf_findByName
  0000:0276  83feff            cmp      si, -1
  0000:0279  7503              jne      0x27e                   ; found existing: update
  0000:027B  e98200            jmp      0x300                   ; not found: fail

loc_0000_027E:                                  ; update existing entry
  0000:027E  8b369b02          mov      si, word ptr [0x29b]    ; search result ptr
  0000:0282  8b5cfe            mov      bx, word ptr [si - 2]   ; entry data size
  0000:0285  03f3              add      si, bx                  ; point past data
  0000:0287  8bee              mov      bp, si
  0000:0289  3dffff            cmp      ax, 0xffff              ; check if key=-1 (new entry)
  0000:028C  7543              jne      0x2d1                   ; -> existing key match
  0000:028E  56                push     si
  0000:028F  8b1e9702          mov      bx, word ptr [0x297]
  0000:0293  268b7705          mov      si, word ptr es:[bx + 5] ; key string ptr
  0000:0297  1e                push     ds
  0000:0298  06                push     es
  0000:0299  1f                pop      ds
  0000:029A  e82f07            call     0x9cc                   ; -> prguf_getKeyLength
  0000:029D  1f                pop      ds
  0000:029E  2603470b          add      ax, word ptr es:[bx + 0xb] ; + data size
  0000:02A2  050300            add      ax, 3                   ; + header overhead
  0000:02A5  5e                pop      si
  0000:02A6  e80904            call     0x6b2                   ; -> prguf_expandPool
  0000:02A9  3dffff            cmp      ax, 0xffff
  0000:02AC  7452              je       0x300                   ; pool full: fail
  0000:02AE  8bfd              mov      di, bp
  0000:02B0  8b1e9702          mov      bx, word ptr [0x297]
  0000:02B4  268b7705          mov      si, word ptr es:[bx + 5]
  0000:02B8  268b4f0b          mov      cx, word ptr es:[bx + 0xb]
  0000:02BC  268b5f07          mov      bx, word ptr es:[bx + 7]
  0000:02C0  06                push     es
  0000:02C1  1e                push     ds
  0000:02C2  07                pop      es
  0000:02C3  1f                pop      ds
  0000:02C4  e81e07            call     0x9e5                   ; -> prguf_copyResourceKey
  0000:02C7  aa                stosb    byte ptr es:[di], al
  0000:02C8  8bc1              mov      ax, cx
  0000:02CA  ab                stosw    word ptr es:[di], ax    ; store data size
  0000:02CB  8bf3              mov      si, bx
  0000:02CD  f3a4              rep movsb byte ptr es:[di], byte ptr [si] ; copy data
  0000:02CF  eb29              jmp      0x2fa                   ; -> success

loc_0000_02D1:                                  ; matched existing key
  0000:02D1  8b1e9702          mov      bx, word ptr [0x297]
  0000:02D5  268b470b          mov      ax, word ptr es:[bx + 0xb]
  0000:02D9  e8d603            call     0x6b2                   ; -> prguf_expandPool
  0000:02DC  3dffff            cmp      ax, 0xffff
  0000:02DF  741f              je       0x300                   ; pool full: fail
  0000:02E1  8bfe              mov      di, si
  0000:02E3  268b4f0b          mov      cx, word ptr es:[bx + 0xb]
  0000:02E7  268b7707          mov      si, word ptr es:[bx + 7]
  0000:02EB  06                push     es
  0000:02EC  1e                push     ds
  0000:02ED  07                pop      es
  0000:02EE  1f                pop      ds
  0000:02EF  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:02F1  268b369d02        mov      si, word ptr es:[0x29d]
  0000:02F6  260144fe          add      word ptr es:[si - 2], ax ; update size

loc_0000_02FA:                                  ; success path
  0000:02FA  06                push     es
  0000:02FB  1e                push     ds
  0000:02FC  07                pop      es
  0000:02FD  1f                pop      ds
  0000:02FE  33c0              xor      ax, ax                  ; return 0 = success

loc_0000_0300:                                  ; exit (DS/ES swap back)
  0000:0300  06                push     es
  0000:0301  1e                push     ds
  0000:0302  07                pop      es
  0000:0303  1f                pop      ds
  0000:0304  5d                pop      bp
  0000:0305  c3                ret

  ; -------------------------------------------------------------------
  ; prguf_removeResource  (0000:0306)
  ; Remove a resource string entry from the pool.
  ; Params: [bp+6]=resource descriptor pointer
  ; Returns: AX=0 on success, AX=0xFFFF if not found
  ; -------------------------------------------------------------------
  0000:0306  55                push     bp
  0000:0307  8bec              mov      bp, sp
  0000:0309  eb03              jmp      0x30e                   ; -> common entry
  0000:030B  db 55 8B EB                                        ; |U..| (alt entry)

loc_0000_030E:
  0000:030E  56                push     si
  0000:030F  57                push     di
  0000:0310  53                push     bx
  0000:0311  52                push     dx
  0000:0312  8b4606            mov      ax, word ptr [bp + 6]
  0000:0315  06                push     es
  0000:0316  1e                push     ds
  0000:0317  07                pop      es
  0000:0318  1f                pop      ds
  0000:0319  a39702            mov      word ptr [0x297], ax
  0000:031C  e8f702            call     0x616                   ; -> prguf_searchPool
  0000:031F  3dffff            cmp      ax, 0xffff
  0000:0322  7418              je       0x33c                   ; not found: fail
  0000:0324  8b369b02          mov      si, word ptr [0x29b]
  0000:0328  8b0e4600          mov      cx, word ptr [0x46]
  0000:032C  8b44fe            mov      ax, word ptr [si - 2]
  0000:032F  2bf1              sub      si, cx
  0000:0331  03c6              add      ax, si
  0000:0333  8b364600          mov      si, word ptr [0x46]
  0000:0337  e8b203            call     0x6ec                   ; -> prguf_shrinkPool
  0000:033A  33c0              xor      ax, ax                  ; return success

loc_0000_033C:
  0000:033C  06                push     es
  0000:033D  1e                push     ds
  0000:033E  07                pop      es
  0000:033F  1f                pop      ds
  0000:0340  5a                pop      dx
  0000:0341  5b                pop      bx
  0000:0342  5f                pop      di
  0000:0343  5e                pop      si
  0000:0344  5d                pop      bp
  0000:0345  c3                ret

  ; -------------------------------------------------------------------
  ; prguf_findResource  (0000:0346)
  ; Find a resource entry and return pointer to its data.
  ; Params: AX (near) or [bp+6] (far)=descriptor pointer
  ; Returns: descriptor fields [+7],[+9],[+0xB] filled with data ptr/size
  ;          AX=0 on success, AX=0xFFFF if not found
  ; -------------------------------------------------------------------
  0000:0346  55                push     bp
  0000:0347  8bec              mov      bp, sp
  0000:0349  8b4604            mov      ax, word ptr [bp + 4]
  0000:034C  eb06              jmp      0x354
  0000:034E  db 55 8B EB 8B 46 06                               ; |U...F.|

loc_0000_0354:
  0000:0354  06                push     es
  0000:0355  1e                push     ds
  0000:0356  07                pop      es
  0000:0357  1f                pop      ds
  0000:0358  a39702            mov      word ptr [0x297], ax
  0000:035B  e8ac02            call     0x60a                   ; -> prguf_findByName
  0000:035E  3dffff            cmp      ax, 0xffff
  0000:0361  7427              je       0x38a
  0000:0363  56                push     si
  0000:0364  8b1e9702          mov      bx, word ptr [0x297]
  0000:0368  268b7705          mov      si, word ptr es:[bx + 5]
  0000:036C  1e                push     ds
  0000:036D  06                push     es
  0000:036E  1f                pop      ds
  0000:036F  e85a06            call     0x9cc                   ; -> prguf_getKeyLength
  0000:0372  1f                pop      ds
  0000:0373  5e                pop      si
  0000:0374  8bd8              mov      bx, ax
  0000:0376  050300            add      ax, 3
  0000:0379  2bf0              sub      si, ax
  0000:037B  034001            add      ax, word ptr [bx + si + 1]
  0000:037E  e86b03            call     0x6ec                   ; -> prguf_shrinkPool
  0000:0381  8b369b02          mov      si, word ptr [0x29b]
  0000:0385  2944fe            sub      word ptr [si - 2], ax
  0000:0388  33c0              xor      ax, ax

loc_0000_038A:
  0000:038A  06                push     es
  0000:038B  1e                push     ds
  0000:038C  07                pop      es
  0000:038D  1f                pop      ds
  0000:038E  5d                pop      bp
  0000:038F  c3                ret

  ; -------------------------------------------------------------------
  ; prguf_modifyResource  (0000:0390)
  ; Get pointer to existing resource data (modifiable in-place).
  ; Params: [bp+6]=descriptor pointer
  ; Returns: descriptor [+7]=data offset, [+9]=data segment, [+0xB]=size
  ;          AX=0 on success, AX=0xFFFF if not found
  ; -------------------------------------------------------------------
  0000:0390  db 55 8B EB EB 03                                  ; |U....|
  0000:0395  55                push     bp
  0000:0396  8bec              mov      bp, sp
  0000:0398  56                push     si
  0000:0399  57                push     di
  0000:039A  53                push     bx
  0000:039B  52                push     dx
  0000:039C  8b4606            mov      ax, word ptr [bp + 6]
  0000:039F  06                push     es
  0000:03A0  1e                push     ds
  0000:03A1  07                pop      es
  0000:03A2  1f                pop      ds
  0000:03A3  a39702            mov      word ptr [0x297], ax
  0000:03A6  e86102            call     0x60a                   ; -> prguf_findByName
  0000:03A9  3dffff            cmp      ax, 0xffff
  0000:03AC  7415              je       0x3c3
  0000:03AE  8b44fe            mov      ax, word ptr [si - 2]
  0000:03B1  8b3e9702          mov      di, word ptr [0x297]
  0000:03B5  26897507          mov      word ptr es:[di + 7], si    ; data offset
  0000:03B9  268c5d09          mov      word ptr es:[di + 9], ds    ; data segment
  0000:03BD  2689450b          mov      word ptr es:[di + 0xb], ax  ; data size
  0000:03C1  33c0              xor      ax, ax

loc_0000_03C3:
  0000:03C3  06                push     es
  0000:03C4  1e                push     ds
  0000:03C5  07                pop      es
  0000:03C6  1f                pop      ds
  0000:03C7  5a                pop      dx
  0000:03C8  5b                pop      bx
  0000:03C9  5f                pop      di
  0000:03CA  5e                pop      si
  0000:03CB  5d                pop      bp
  0000:03CC  c3                ret

  ; -------------------------------------------------------------------
  ; prguf_loadResource  (0000:03CD)
  ; Load resource from file: find in pool, check type, open file,
  ; read data, allocate pool entry, close file.
  ; Params: [bp+6]=descriptor pointer
  ; Returns: AX=0 on success, AX=0xFFFF on failure
  ; -------------------------------------------------------------------
  0000:03CD  db 55 8B EB EB 03                                  ; |U....|
  0000:03D2  55                push     bp
  0000:03D3  8bec              mov      bp, sp
  0000:03D5  56                push     si
  0000:03D6  57                push     di
  0000:03D7  53                push     bx
  0000:03D8  52                push     dx
  0000:03D9  8b4606            mov      ax, word ptr [bp + 6]
  0000:03DC  06                push     es
  0000:03DD  1e                push     ds
  0000:03DE  07                pop      es
  0000:03DF  1f                pop      ds
  0000:03E0  a39702            mov      word ptr [0x297], ax
  0000:03E3  e83002            call     0x616                   ; -> prguf_searchPool
  0000:03E6  33c0              xor      ax, ax
  0000:03E8  83feff            cmp      si, -1
  0000:03EB  7556              jne      0x443                   ; already in pool: done
  0000:03ED  b80100            mov      ax, 1                   ; flag: new entry
  0000:03F0  8b369702          mov      si, word ptr [0x297]
  0000:03F4  26807c0403        cmp      byte ptr es:[si + 4], 3 ; type 3 = label
  0000:03F9  7415              je       0x410                   ; skip file open for labels
  0000:03FB  e80803            call     0x706                   ; -> prguf_resolvePathFromDesc
  0000:03FE  3dffff            cmp      ax, 0xffff
  0000:0401  7440              je       0x443
  0000:0403  e8ef03            call     0x7f5                   ; -> prguf_openResourceFile
  0000:0406  3dffff            cmp      ax, 0xffff
  0000:0409  7438              je       0x443
  0000:040B  3dfeff            cmp      ax, 0xfffe
  0000:040E  7433              je       0x443

loc_0000_0410:
  0000:0410  8be8              mov      bp, ax
  0000:0412  8b369702          mov      si, word ptr [0x297]
  0000:0416  268b34            mov      si, word ptr es:[si]    ; filename ptr
  0000:0419  1e                push     ds
  0000:041A  06                push     es
  0000:041B  1f                pop      ds
  0000:041C  e8ad05            call     0x9cc                   ; -> prguf_getKeyLength
  0000:041F  1f                pop      ds
  0000:0420  050300            add      ax, 3                   ; key + header
  0000:0423  83fd01            cmp      bp, 1                   ; new entry?
  0000:0426  740c              je       0x434                   ; yes: skip alloc check
  0000:0428  8bd8              mov      bx, ax
  0000:042A  e8bf04            call     0x8ec                   ; -> prguf_createResourceFile
  0000:042D  3dffff            cmp      ax, 0xffff
  0000:0430  745a              je       0x48c
  0000:0432  03c3              add      ax, bx

loc_0000_0434:
  0000:0434  8b1e5402          mov      bx, word ptr [0x254]    ; pool max size
  0000:0438  2b1e9f02          sub      bx, word ptr [0x29f]    ; minus used
  0000:043C  3bc3              cmp      ax, bx
  0000:043E  7205              jb       0x445                   ; fits: proceed
  0000:0440  b8ffff            mov      ax, 0xffff              ; pool full

loc_0000_0443:
  0000:0443  eb47              jmp      0x48c                   ; -> exit

loc_0000_0445:
  0000:0445  e86e01            call     0x5b6                   ; -> prguf_extractFilename
  0000:0448  83fd01            cmp      bp, 1
  0000:044B  7418              je       0x465                   ; new: skip file alloc
  0000:044D  e81005            call     0x960                   ; -> prguf_allocatePoolEntry
  0000:0450  b8ffff            mov      ax, 0xffff
  0000:0453  8b365202          mov      si, word ptr [0x252]
  0000:0457  03369f02          add      si, word ptr [0x29f]
  0000:045B  e86604            call     0x8c4                   ; -> prguf_writeResourceFile
  0000:045E  3dffff            cmp      ax, 0xffff
  0000:0461  7412              je       0x475
  0000:0463  8905              mov      word ptr [di], ax

loc_0000_0465:
  0000:0465  03069f02          add      ax, word ptr [0x29f]
  0000:0469  a39f02            mov      word ptr [0x29f], ax    ; update used
  0000:046C  8b365202          mov      si, word ptr [0x252]
  0000:0470  03f0              add      si, ax
  0000:0472  c60400            mov      byte ptr [si], 0        ; null terminate

loc_0000_0475:
  0000:0475  8b369702          mov      si, word ptr [0x297]
  0000:0479  26807c0403        cmp      byte ptr es:[si + 4], 3
  0000:047E  7405              je       0x485                   ; labels: skip close
  0000:0480  50                push     ax
  0000:0481  e85504            call     0x8d9                   ; -> prguf_closeResourceFile
  0000:0484  58                pop      ax

loc_0000_0485:
  0000:0485  3dffff            cmp      ax, 0xffff
  0000:0488  7402              je       0x48c
  0000:048A  33c0              xor      ax, ax                  ; success

loc_0000_048C:
  0000:048C  06                push     es
  0000:048D  1e                push     ds
  0000:048E  07                pop      es
  0000:048F  1f                pop      ds
  0000:0490  5a                pop      dx
  0000:0491  5b                pop      bx
  0000:0492  5f                pop      di
  0000:0493  5e                pop      si
  0000:0494  5d                pop      bp
  0000:0495  c3                ret

  ; (0000:0496-0x05B5) inline: resize resource, store/load resource wrappers
  0000:0496  db 55 8B EB 8B 46 06 06 1E 07 1F A3 97 02 E8 64 01 ; |U...F.........d.|
  0000:04A6  db 83 FE FF 74 25 3D FF FF 74 37 8B 1E 97 02 26 8B ; |...t%=..t7....&.|
  0000:04B6  db 47 0B 8B 5C FE 3B C3 76 17 2B C3 8B 1E 54 02 2B ; |G..\.;.v.+...T.+|
  0000:04C6  db 1E 9F 02 3B C3 72 09 B8 FF FF 06 1E 07 1F EB 20 ; |...;.r......... |
  0000:04D6  db 06 1E 07 1F 26 FF 36 97 02 E8 64 FE 83 C4 02 EB ; |....&.6...d.....|
  0000:04E6  db 04 06 1E 07 1F 26 FF 36 97 02 E8 6B FD 83 C4 02 ; |.....&.6...k....|
  0000:04F6  db 5D C3 55 8B EB 8B 46 06 06 1E 07 1F A3 97 02 E8 ; |].U...F.........|
  0000:0506  db 0E 01 3D FF FF 74 6D E8 F6 01 3D FF FF 74 65 E8 ; |..=..tm...=..te.|
  0000:0516  db DD 02 3D FF FF 74 5D 3D FE FF 75 1D 8B 36 97 02 ; |..=..t]=..u..6..|
  0000:0526  db 26 80 7C 04 01 74 05 B8 FF FF EB 48 E8 43 04 3D ; |&.|..t.....H.C.=|
  0000:0536  db FF FF 74 40 3D FE FF 74 3B E8 CE 03 0B D2 75 1F ; |..t@=..t;.....u.|
  0000:0546  db 50 E8 A2 03 5B 3D FF FF 74 0D 03 D8 8B 36 9B 02 ; |P...[=..t....6..|
  0000:0556  db 8B 44 FE 3B C3 72 08 E8 79 03 B8 FF FF EB 15 E8 ; |.D.;.r..y.......|
  0000:0566  db F8 03 8B 36 9B 02 8B 44 FE E8 3D 03 33 C0 E8 38 ; |...6...D..=.3..8|
  0000:0576  db 03 E8 5F 03 06 1E 07 1F 5D C3                   ; |.._.....].|

  ; (0000:0580-05B5) inline: copy resource data block
  0000:0580  db 56 57 51 53 52                                  ; "VWQSR"
  0000:0585  db A3 97 02 E8 7B 01 3D FF FF 74 20 E8 83 00 3D FF ; |....{.=..t ...=.|
  0000:0595  db FF 74 18 8B FE 83 EF 04 8B 36 97 02 8B 74 05 83 ; |.t.......6...t..|
  0000:05A5  db C6 08 FD B9 09 00 F2 A4 FC 33 C0                ; |.........3.|
  0000:05B0  db 5A 5B 59 5F 5E                                  ; "Z[Y_^"
  0000:05B5  db C3                                              ; |.|

; -------------------------------------------------------------------
; prguf_extractFilename  (0000:05B6)
; Extract the filename component from a full path (after last \ or :),
; copy it to the string pool as a null-terminated entry with 3-byte header.
; -------------------------------------------------------------------
sub_0000_05B6:                                  ; prguf_extractFilename
  0000:05B6  55                push     bp
  0000:05B7  8b369702          mov      si, word ptr [0x297]    ; descriptor ptr
  0000:05BB  268b3c            mov      di, word ptr es:[si]    ; filename string
  0000:05BE  8bef              mov      bp, di
  0000:05C0  b9ffff            mov      cx, 0xffff
  0000:05C3  32c0              xor      al, al
  0000:05C5  f2ae              repne scasb al, byte ptr es:[di] ; find null terminator
  0000:05C7  4f                dec      di
  0000:05C8  4f                dec      di                      ; point to last char

loc_0000_05C9:                                  ; scan backwards for \ or :
  0000:05C9  3bfd              cmp      di, bp
  0000:05CB  7610              jbe      0x5dd                   ; reached start
  0000:05CD  268a05            mov      al, byte ptr es:[di]
  0000:05D0  4f                dec      di
  0000:05D1  3c3a              cmp      al, 0x3a                ; ':'
  0000:05D3  7404              je       0x5d9
  0000:05D5  3c5c              cmp      al, 0x5c                ; '\'
  0000:05D7  75f0              jne      0x5c9

loc_0000_05D9:
  0000:05D9  47                inc      di
  0000:05DA  47                inc      di
  0000:05DB  eb02              jmp      0x5df

loc_0000_05DD:
  0000:05DD  8bfd              mov      di, bp                  ; no path separator: use whole string

loc_0000_05DF:
  0000:05DF  8bf7              mov      si, di
  0000:05E1  8b3e5202          mov      di, word ptr [0x252]    ; pool base
  0000:05E5  033e9f02          add      di, word ptr [0x29f]    ; + used offset
  0000:05E9  b9ffff            mov      cx, 0xffff
  0000:05EC  06                push     es
  0000:05ED  1e                push     ds
  0000:05EE  07                pop      es
  0000:05EF  1f                pop      ds

loc_0000_05F0:                                  ; copy filename to pool
  0000:05F0  41                inc      cx
  0000:05F1  ac                lodsb    al, byte ptr [si]
  0000:05F2  aa                stosb    byte ptr es:[di], al
  0000:05F3  0ac0              or       al, al
  0000:05F5  75f9              jne      0x5f0
  0000:05F7  06                push     es
  0000:05F8  1e                push     ds
  0000:05F9  07                pop      es
  0000:05FA  1f                pop      ds
  0000:05FB  98                cwde                             ; AX = 0 (null byte)
  0000:05FC  8905              mov      word ptr [di], ax       ; zero the size word
  0000:05FE  884502            mov      byte ptr [di + 2], al   ; zero padding byte
  0000:0601  83c103            add      cx, 3                   ; name + null + 3 header bytes
  0000:0604  010e9f02          add      word ptr [0x29f], cx    ; update pool used
  0000:0608  5d                pop      bp
  0000:0609  c3                ret

; -------------------------------------------------------------------
; prguf_findByName  (0000:060A)
; Search pool for filename, then match key within found entry.
; Returns: SI=data pointer (or -1), AX=0/-1
; -------------------------------------------------------------------
sub_0000_060A:                                  ; prguf_findByName
  0000:060A  e80900            call     0x616                   ; -> prguf_searchPool
  0000:060D  3dffff            cmp      ax, 0xffff
  0000:0610  7403              je       0x615
  0000:0612  e85f00            call     0x674                   ; -> prguf_matchKey

loc_0000_0615:
  0000:0615  c3                ret

; -------------------------------------------------------------------
; prguf_searchPool  (0000:0616)
; Linear search through the string pool for a matching filename.
; Pool entries: [name\0][data_size:word][data...][name\0][data_size:word]...
; The pool ends when a null byte is found at the start of an entry.
; Returns: SI = pointer to data area, [0x29B] set, or AX=0xFFFF
; -------------------------------------------------------------------
sub_0000_0616:                                  ; prguf_searchPool
  0000:0616  55                push     bp
  0000:0617  e85c01            call     0x776                   ; -> prguf_uppercaseFilename
  0000:061A  8b3e9702          mov      di, word ptr [0x297]
  0000:061E  268b3d            mov      di, word ptr es:[di]    ; filename to search for
  0000:0621  8bef              mov      bp, di
  0000:0623  32c0              xor      al, al
  0000:0625  b94100            mov      cx, 0x41                ; max 65 chars
  0000:0628  f2ae              repne scasb al, byte ptr es:[di] ; find end of search name

loc_0000_062A:                                  ; scan backwards for path separator
  0000:062A  4f                dec      di
  0000:062B  3bfd              cmp      di, bp
  0000:062D  720b              jb       0x63a
  0000:062F  268a05            mov      al, byte ptr es:[di]
  0000:0632  3c5c              cmp      al, 0x5c                ; '\'
  0000:0634  7404              je       0x63a
  0000:0636  3c3a              cmp      al, 0x3a                ; ':'
  0000:0638  75f0              jne      0x62a

loc_0000_063A:
  0000:063A  47                inc      di
  0000:063B  8bef              mov      bp, di                  ; BP = start of bare filename
  0000:063D  8b365202          mov      si, word ptr [0x252]    ; pool base

loc_0000_0641:                                  ; scan pool entries
  0000:0641  89364600          mov      word ptr [0x46], si     ; save current position
  0000:0645  803c00            cmp      byte ptr [si], 0        ; end of pool?
  0000:0648  7423              je       0x66d                   ; -> not found
  0000:064A  8bfd              mov      di, bp                  ; reset search name ptr

loc_0000_064C:                                  ; compare names byte by byte
  0000:064C  ac                lodsb    al, byte ptr [si]
  0000:064D  ae                scasb    al, byte ptr es:[di]
  0000:064E  7506              jne      0x656                   ; mismatch
  0000:0650  0ac0              or       al, al
  0000:0652  7410              je       0x664                   ; both null: match!
  0000:0654  ebf6              jmp      0x64c

loc_0000_0656:                                  ; skip rest of name
  0000:0656  0ac0              or       al, al
  0000:0658  7403              je       0x65d
  0000:065A  ac                lodsb    al, byte ptr [si]
  0000:065B  ebf9              jmp      0x656

loc_0000_065D:                                  ; skip data area, advance to next entry
  0000:065D  0334              add      si, word ptr [si]       ; skip data size
  0000:065F  83c602            add      si, 2
  0000:0662  ebdd              jmp      0x641                   ; -> next entry

loc_0000_0664:                                  ; found matching name
  0000:0664  83c602            add      si, 2                   ; skip size word placeholder
  0000:0667  89369b02          mov      word ptr [0x29b], si    ; save data pointer
  0000:066B  eb05              jmp      0x672

loc_0000_066D:                                  ; not found
  0000:066D  beffff            mov      si, 0xffff
  0000:0670  8bc6              mov      ax, si

loc_0000_0672:
  0000:0672  5d                pop      bp
  0000:0673  c3                ret

; -------------------------------------------------------------------
; prguf_matchKey  (0000:0674)
; Within a found pool entry, search for a matching key string.
; Pool entry data: [key\0][data_size:word][data...][key\0]...
; Returns: SI=pointer to data, [0x29D] set, or AX=0xFFFF
; -------------------------------------------------------------------
sub_0000_0674:                                  ; prguf_matchKey
  0000:0674  8b4cfe            mov      cx, word ptr [si - 2]   ; total entry data size
  0000:0677  e335              jcxz     0x6ae                   ; empty: not found

loc_0000_0679:
  0000:0679  8b3e9702          mov      di, word ptr [0x297]
  0000:067D  268b7d05          mov      di, word ptr es:[di + 5] ; search key string
  0000:0681  ac                lodsb    al, byte ptr [si]
  0000:0682  ae                scasb    al, byte ptr es:[di]
  0000:0683  7508              jne      0x68d
  0000:0685  0ac0              or       al, al
  0000:0687  741c              je       0x6a5                   ; both null: key match!
  0000:0689  e2f6              loop     0x681
  0000:068B  eb21              jmp      0x6ae                   ; ran out of data

loc_0000_068D:                                  ; skip rest of key
  0000:068D  49                dec      cx
  0000:068E  0ac0              or       al, al
  0000:0690  7403              je       0x695
  0000:0692  ac                lodsb    al, byte ptr [si]
  0000:0693  ebf8              jmp      0x68d

loc_0000_0695:                                  ; skip key's data, try next key
  0000:0695  8b04              mov      ax, word ptr [si]
  0000:0697  2bc8              sub      cx, ax
  0000:0699  83e902            sub      cx, 2
  0000:069C  7610              jbe      0x6ae
  0000:069E  03f0              add      si, ax
  0000:06A0  83c602            add      si, 2
  0000:06A3  ebd4              jmp      0x679

loc_0000_06A5:                                  ; key matched
  0000:06A5  83c602            add      si, 2
  0000:06A8  89369d02          mov      word ptr [0x29d], si    ; save match pointer
  0000:06AC  eb03              jmp      0x6b1

loc_0000_06AE:                                  ; not found
  0000:06AE  b8ffff            mov      ax, 0xffff

loc_0000_06B1:
  0000:06B1  c3                ret

; -------------------------------------------------------------------
; prguf_expandPool  (0000:06B2)
; Expand the pool by AX bytes at position SI (shift existing data right).
; Checks that pool won't exceed max size.
; Returns: AX=0xFFFF if pool full, or AX=bytes expanded
; -------------------------------------------------------------------
sub_0000_06B2:                                  ; prguf_expandPool
  0000:06B2  56                push     si
  0000:06B3  8b369f02          mov      si, word ptr [0x29f]    ; current used
  0000:06B7  03f0              add      si, ax                  ; new used
  0000:06B9  3b365402          cmp      si, word ptr [0x254]    ; vs max
  0000:06BD  7205              jb       0x6c4                   ; fits
  0000:06BF  b8ffff            mov      ax, 0xffff              ; pool full
  0000:06C2  eb26              jmp      0x6ea

loc_0000_06C4:                                  ; shift data right by AX bytes
  0000:06C4  5e                pop      si
  0000:06C5  56                push     si
  0000:06C6  06                push     es
  0000:06C7  1e                push     ds
  0000:06C8  07                pop      es
  0000:06C9  8b3e5202          mov      di, word ptr [0x252]
  0000:06CD  033e9f02          add      di, word ptr [0x29f]    ; end of used area
  0000:06D1  8bcf              mov      cx, di
  0000:06D3  2bce              sub      cx, si                  ; bytes to move
  0000:06D5  41                inc      cx
  0000:06D6  8bf7              mov      si, di
  0000:06D8  03f8              add      di, ax                  ; dest = source + expand
  0000:06DA  fd                std                              ; copy backwards
  0000:06DB  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:06DD  fc                cld
  0000:06DE  07                pop      es
  0000:06DF  01069f02          add      word ptr [0x29f], ax    ; update used
  0000:06E3  8b369b02          mov      si, word ptr [0x29b]
  0000:06E7  0144fe            add      word ptr [si - 2], ax   ; update entry size

loc_0000_06EA:
  0000:06EA  5e                pop      si
  0000:06EB  c3                ret

; -------------------------------------------------------------------
; prguf_shrinkPool  (0000:06EC)
; Shrink pool by AX bytes at position SI (shift data left).
; -------------------------------------------------------------------
sub_0000_06EC:                                  ; prguf_shrinkPool
  0000:06EC  8bfe              mov      di, si
  0000:06EE  03f0              add      si, ax                  ; source = SI + AX
  0000:06F0  8b0e5202          mov      cx, word ptr [0x252]
  0000:06F4  030e9f02          add      cx, word ptr [0x29f]    ; end of used
  0000:06F8  2bce              sub      cx, si
  0000:06FA  41                inc      cx
  0000:06FB  06                push     es
  0000:06FC  1e                push     ds
  0000:06FD  07                pop      es
  0000:06FE  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:0700  07                pop      es
  0000:0701  29069f02          sub      word ptr [0x29f], ax    ; update used
  0000:0705  c3                ret

; -------------------------------------------------------------------
; prguf_resolvePathFromDesc  (0000:0706)
; Resolve file path from descriptor: check env var pointer, build path.
; Sets up g_resolvedPath at [0x256].
; -------------------------------------------------------------------
sub_0000_0706:                                  ; prguf_resolvePathFromDesc
  0000:0706  bf5602            mov      di, 0x256               ; resolved path buffer
  0000:0709  8b369702          mov      si, word ptr [0x297]
  0000:070D  268b7402          mov      si, word ptr es:[si + 2] ; env var ptr
  0000:0711  0bf6              or       si, si
  0000:0713  7409              je       0x71e                   ; no env var
  0000:0715  26803c00          cmp      byte ptr es:[si], 0     ; empty string?
  0000:0719  7403              je       0x71e
  0000:071B  e80400            call     0x722                   ; -> prguf_buildPathFromEnv

loc_0000_071E:
  0000:071E  e89a00            call     0x7bb                   ; -> prguf_assemblePath
  0000:0721  c3                ret

; -------------------------------------------------------------------
; prguf_buildPathFromEnv  (0000:0722)
; Search environment for variable, prepend its value as path prefix.
; -------------------------------------------------------------------
sub_0000_0722:                                  ; prguf_buildPathFromEnv
  0000:0722  8b3e9702          mov      di, word ptr [0x297]
  0000:0726  268b6d02          mov      bp, word ptr es:[di + 2] ; env var name
  0000:072A  8bf5              mov      si, bp
  0000:072C  e82c00            call     0x75b                   ; -> prguf_strlenAndUpper
  0000:072F  06                push     es
  0000:0730  1e                push     ds
  0000:0731  1e                push     ds
  0000:0732  50                push     ax                      ; save length
  0000:0733  e85d00            call     0x793                   ; -> prguf_searchEnvBlock
  0000:0736  bf5602            mov      di, 0x256               ; resolved path buffer
  0000:0739  8bf0              mov      si, ax                  ; env value offset
  0000:073B  58                pop      ax                      ; restore length
  0000:073C  07                pop      es
  0000:073D  83feff            cmp      si, -1
  0000:0740  7416              je       0x758                   ; not found: skip
  0000:0742  03f0              add      si, ax
  0000:0744  46                inc      si                      ; skip '=' character
  0000:0745  e89d02            call     0x9e5                   ; -> prguf_copyResourceKey
  0000:0748  aa                stosb    byte ptr es:[di], al
  0000:0749  4f                dec      di
  0000:074A  26807dff5c        cmp      byte ptr es:[di - 1], 0x5c ; ends with '\'?
  0000:074F  7407              je       0x758                   ; yes: done
  0000:0751  26c6055c          mov      byte ptr es:[di], 0x5c  ; append '\'
  0000:0755  47                inc      di
  0000:0756  33c0              xor      ax, ax

loc_0000_0758:
  0000:0758  1f                pop      ds
  0000:0759  07                pop      es
  0000:075A  c3                ret

; -------------------------------------------------------------------
; prguf_strlenAndUpper  (0000:075B)
; Get string length while converting to uppercase (modifies in place).
; Params: SI=string pointer (in DS, which is swapped to ES)
; Returns: AX=string length
; -------------------------------------------------------------------
sub_0000_075B:                                  ; prguf_strlenAndUpper
  0000:075B  06                push     es
  0000:075C  1e                push     ds
  0000:075D  07                pop      es
  0000:075E  1f                pop      ds
  0000:075F  33c9              xor      cx, cx

loc_0000_0761:
  0000:0761  ac                lodsb    al, byte ptr [si]
  0000:0762  0ac0              or       al, al
  0000:0764  7409              je       0x76f
  0000:0766  41                inc      cx
  0000:0767  e86bfa            call     0x1d5                   ; -> prguf_toUpperCase
  0000:076A  8844ff            mov      byte ptr [si - 1], al
  0000:076D  ebf2              jmp      0x761

loc_0000_076F:
  0000:076F  8bc1              mov      ax, cx
  0000:0771  06                push     es
  0000:0772  1e                push     ds
  0000:0773  07                pop      es
  0000:0774  1f                pop      ds
  0000:0775  c3                ret

; -------------------------------------------------------------------
; prguf_uppercaseFilename  (0000:0776)
; Uppercase the filename string from the current descriptor.
; -------------------------------------------------------------------
sub_0000_0776:                                  ; prguf_uppercaseFilename
  0000:0776  8b3e9702          mov      di, word ptr [0x297]
  0000:077A  268b35            mov      si, word ptr es:[di]    ; filename ptr
  0000:077D  06                push     es
  0000:077E  1e                push     ds
  0000:077F  07                pop      es
  0000:0780  1f                pop      ds

loc_0000_0781:
  0000:0781  ac                lodsb    al, byte ptr [si]
  0000:0782  0ac0              or       al, al
  0000:0784  7408              je       0x78e
  0000:0786  e84cfa            call     0x1d5                   ; -> prguf_toUpperCase
  0000:0789  8844ff            mov      byte ptr [si - 1], al
  0000:078C  ebf3              jmp      0x781

loc_0000_078E:
  0000:078E  06                push     es
  0000:078F  1e                push     ds
  0000:0790  07                pop      es
  0000:0791  1f                pop      ds
  0000:0792  c3                ret

; -------------------------------------------------------------------
; prguf_searchEnvBlock  (0000:0793)
; Search the PSP environment block for a variable matching BP.
; Uses INT 21h/51h to get PSP, reads env segment from PSP:[0x2C].
; Params: DX=length of variable name, BP=variable name pointer
; Returns: AX=offset in env block, or AX=0xFFFF if not found
; -------------------------------------------------------------------
sub_0000_0793:                                  ; prguf_searchEnvBlock
  0000:0793  8bd0              mov      dx, ax
  0000:0795  b451              mov      ah, 0x51
  0000:0797  cd21              int      0x21                    ; INT 21h/51h: Get PSP
  0000:0799  8edb              mov      ds, bx                  ; DS = PSP segment
  0000:079B  a12c00            mov      ax, word ptr [0x2c]     ; environment segment
  0000:079E  8ed8              mov      ds, ax
  0000:07A0  33f6              xor      si, si

loc_0000_07A2:                                  ; compare each env entry
  0000:07A2  8bca              mov      cx, dx
  0000:07A4  8bde              mov      bx, si
  0000:07A6  8bfd              mov      di, bp
  0000:07A8  f3a6              repe cmpsb byte ptr [si], byte ptr es:[di]
  0000:07AA  8bc3              mov      ax, bx
  0000:07AC  740c              je       0x7ba                   ; match: return offset

loc_0000_07AE:                                  ; skip to next env entry
  0000:07AE  ac                lodsb    al, byte ptr [si]
  0000:07AF  0ac0              or       al, al
  0000:07B1  75fb              jne      0x7ae
  0000:07B3  3804              cmp      byte ptr [si], al       ; double null = end
  0000:07B5  75eb              jne      0x7a2
  0000:07B7  b8ffff            mov      ax, 0xffff              ; not found

loc_0000_07BA:
  0000:07BA  c3                ret

; -------------------------------------------------------------------
; prguf_assemblePath  (0000:07BB)
; Assemble final path from filename and optional env prefix.
; Handles drive letter detection (X:) and path separator insertion.
; -------------------------------------------------------------------
sub_0000_07BB:                                  ; prguf_assemblePath
  0000:07BB  8b1e9702          mov      bx, word ptr [0x297]
  0000:07BF  268b37            mov      si, word ptr es:[bx]    ; filename
  0000:07C2  268b5f02          mov      bx, word ptr es:[bx + 2] ; env var ptr
  0000:07C6  0bdb              or       bx, bx
  0000:07C8  7408              je       0x7d2                   ; no env var
  0000:07CA  26803f00          cmp      byte ptr es:[bx], 0     ; empty?
  0000:07CE  7502              jne      0x7d2
  0000:07D0  33db              xor      bx, bx                  ; treat as no env

loc_0000_07D2:
  0000:07D2  06                push     es
  0000:07D3  1e                push     ds
  0000:07D4  07                pop      es
  0000:07D5  1f                pop      ds
  0000:07D6  807c013a          cmp      byte ptr [si + 1], 0x3a ; drive letter present?
  0000:07DA  740d              je       0x7e9                   ; yes: check env override

loc_0000_07DC:                                  ; copy filename chars
  0000:07DC  ac                lodsb    al, byte ptr [si]
  0000:07DD  aa                stosb    byte ptr es:[di], al
  0000:07DE  3c5c              cmp      al, 0x5c                ; '\'
  0000:07E0  7407              je       0x7e9
  0000:07E2  0ac0              or       al, al
  0000:07E4  75f6              jne      0x7dc
  0000:07E6  98                cwde                             ; AX=0
  0000:07E7  eb07              jmp      0x7f0

loc_0000_07E9:
  0000:07E9  0bdb              or       bx, bx
  0000:07EB  74ef              je       0x7dc                   ; no env: copy raw

  ; (remaining path assembly at 0x07ED-0x07F4)
  0000:07ED  8b73ff            mov      si, word ptr [bx - 1]
  0000:07F0  06                push     es                      ; ... continues below
  0000:07F1  1e                push     ds
  0000:07F2  07                pop      es
  0000:07F3  1f                pop      ds
  0000:07F4  c3                ret

; -------------------------------------------------------------------
; prguf_openResourceFile  (0000:07F5)
; Open resource file: resolve path, open for reading, verify contents.
; Returns: AX=file handle on success, 0xFFFF/-2 on failure
; -------------------------------------------------------------------
sub_0000_07F5:                                  ; prguf_openResourceFile
  0000:07F5  db 50 53 52 56 57 55                               ; push ax,bx,dx,si,di,bp
  ; (extensive file open/read/verify code at 0x07F5-0x086D)
  ; Uses prguf_readResourceData and prguf_copyResourceKey internally
  ; Falls through to verification routines
  0000:07F5  db 50                                              ; |P| (remainder is inline data)
  ; ... (see raw file for full inline byte sequence)

; Remaining functions 0x086E through 0x0B73 are inline resource file
; I/O helpers (verify, read, write, create, allocate, copy key, get key length).
; See raw disassembly for full byte sequences.

; -------------------------------------------------------------------
; (0000:0E94 - 0x10CD range contains file I/O wrappers)
; These are compact functions wrapping DOS INT 21h calls with
; the prguf_handleDosError pattern.
; -------------------------------------------------------------------

; -------------------------------------------------------------------
; prguf_openFile  (0000:0F7B)
; Open file with specified access mode.
; Params: [bp+6]=filename, [bp+8]=access mode
; Returns: AX=file handle, or AX=0xFFFF on error
; -------------------------------------------------------------------
sub_0000_0F7B:                                  ; prguf_openFile
  ; (inline bytes at 0x0F7B-0x0FAA)
  ; Uses INT 21h/3Dh, calls prguf_handleDosError on failure

; -------------------------------------------------------------------
; prguf_readFile  (0000:0FAB)
; Read CX bytes from file handle BX into DS:DX.
; Returns: AX=bytes read, or AX=0xFFFF on error
; -------------------------------------------------------------------
sub_0000_0FAB:                                  ; prguf_readFile
  ; (inline bytes at 0x0FAB-0x0FEE)
  ; Uses INT 21h/3Fh

; -------------------------------------------------------------------
; prguf_writeFile  (0000:0FEF)
; Write CX bytes from DS:DX to file handle BX.
; Verifies bytes written match requested count.
; Returns: AX=0 on success, AX=0xFFFF on error
; -------------------------------------------------------------------
sub_0000_0FEF:                                  ; prguf_writeFile
  ; (inline bytes at 0x0FEF-0x1040)
  ; Uses INT 21h/40h, then compares AX:BX with original values
  ; If mismatch, calls function 0x0D to report error

; -------------------------------------------------------------------
; prguf_createFile  (0000:1041)
; Create a new file with normal (0) attributes.
; -------------------------------------------------------------------
sub_0000_1041:                                  ; prguf_createFile
  0000:1041  55                push     bp
  0000:1042  8bec              mov      bp, sp
  0000:1044  57                push     di
  0000:1045  56                push     si
  0000:1046  8b5606            mov      dx, word ptr [bp + 6]
  0000:1049  b90000            mov      cx, 0                   ; normal attributes
  0000:104C  b43c              mov      ah, 0x3c
  0000:104E  cd21              int      0x21                    ; INT 21h/3Ch: Create file
  0000:1050  ebb8              jmp      0x100a                  ; -> common error handler

  ; (0000:1052) inline wrapper: same pattern
  0000:1052  db 55 8B EB EB 03                                  ; |U....|

  ; -------------------------------------------------------------------
  ; prguf_getFileAttrib  (0000:1057)
  ; Get file attributes (read-only, hidden, etc.).
  ; Params: [bp+6]=filename
  ; Returns: CX=attributes, or AX=0xFFFF on error
  ; -------------------------------------------------------------------
  0000:1057  55                push     bp
  0000:1058  8bec              mov      bp, sp
  0000:105A  57                push     di
  0000:105B  56                push     si
  0000:105C  8b5606            mov      dx, word ptr [bp + 6]
  0000:105F  b90000            mov      cx, 0
  0000:1062  b443              mov      ah, 0x43
  0000:1064  32c0              xor      al, al                  ; AL=0: get attributes
  0000:1066  cd21              int      0x21                    ; INT 21h/43h: Get file attributes
  0000:1068  eba0              jmp      0x100a                  ; -> common error handler

  0000:106A  db 55 8B EB EB 03                                  ; |U....|

; -------------------------------------------------------------------
; prguf_closeFile  (0000:106F)
; Close a file handle.
; Params: [bp+6]=file handle
; -------------------------------------------------------------------
sub_0000_106F:                                  ; prguf_closeFile
  0000:106F  55                push     bp
  0000:1070  8bec              mov      bp, sp
  0000:1072  57                push     di
  0000:1073  56                push     si
  0000:1074  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1077  b43e              mov      ah, 0x3e
  0000:1079  cd21              int      0x21                    ; INT 21h/3Eh: Close file
  0000:107B  eb8d              jmp      0x100a                  ; -> common error handler

  ; (0000:107D-10CC) inline: dup handle, IOCTL/lseek wrappers
  0000:107D  db 55 8B EB 57 56 8B 5E 06 B4 45 CD 21 E9 7E FF 55 ; |U..WV.^..E.!.~.U|
  0000:108D  db 8B EB B8 00 5C 83 7E 0C 00 75 06 83 7E 0E 00 74 ; |....\.~..u..~..t|
  0000:109D  db 16 57 56 8B 5E 06 8B 56 08 8B 4E 0A 8B 7E 0C 8B ; |.WV.^..V..N..~..|
  0000:10AD  db 76 0E CD 21 E9 56 FF B8 FF FF 8B 5E 04 C7 07 68 ; |v..!.V.....^...h|
  0000:10BD  db 00 5D C3 55 8B EB B8 01 5C EB CA 55 8B EB EB 03 ; |.].U....\..U....|

; -------------------------------------------------------------------
; prguf_getCurrentDir  (0000:10CD)
; Get current directory for a specified drive.
; Params: [bp+6]=drive letter, [bp+8]=buffer pointer
; Buffer receives "\path\..." format.
; -------------------------------------------------------------------
  0000:10CD  55                push     bp
  0000:10CE  8bec              mov      bp, sp
  0000:10D0  57                push     di
  0000:10D1  56                push     si
  0000:10D2  8b7608            mov      si, word ptr [bp + 8]   ; buffer pointer
  0000:10D5  c6045c            mov      byte ptr [si], 0x5c     ; prepend '\'
  0000:10D8  46                inc      si
  0000:10D9  8a5606            mov      dl, byte ptr [bp + 6]   ; drive letter
  0000:10DC  80e2df            and      dl, 0xdf                ; to uppercase
  0000:10DF  80ea40            sub      dl, 0x40                ; 'A'=1, 'B'=2, etc.
  0000:10E2  b447              mov      ah, 0x47
  0000:10E4  cd21              int      0x21                    ; INT 21h/47h: Get current directory
  0000:10E6  7303              jae      0x10eb                  ; success
  0000:10E8  e921ff            jmp      0x100c                  ; -> error handler

loc_0000_10EB:
  0000:10EB  33c0              xor      ax, ax
  0000:10ED  e92bff            jmp      0x101b                  ; -> return success

; -------------------------------------------------------------------
; prguf_getDefaultDrive  (0000:10F0)
; Get the current default drive letter.
; Two entry points: one via BX (register), one via BP (stack).
; Returns: AL=drive letter ('A'-'Z'), AX via common exit
; -------------------------------------------------------------------
sub_0000_10F0:                                  ; prguf_getDefaultDrive
  0000:10F0  55                push     bp
  0000:10F1  8beb              mov      bp, bx
  0000:10F3  eb03              jmp      0x10f8
  0000:10F5  55                push     bp
  0000:10F6  8bec              mov      bp, sp

loc_0000_10F8:
  0000:10F8  57                push     di
  0000:10F9  56                push     si
  0000:10FA  b419              mov      ah, 0x19
  0000:10FC  cd21              int      0x21                    ; INT 21h/19h: Get default drive
  0000:10FE  32e4              xor      ah, ah
  0000:1100  0441              add      al, 0x41                ; convert to 'A'-'Z'
  0000:1102  f8                clc                              ; clear carry (success)
  0000:1103  e904ff            jmp      0x100a                  ; -> common return

  ; (0000:1106-111D) inline: set default drive
  0000:1106  db 55 8B EB 57 56 8A 56 06 80 E2 DF 80 EA 41 B4 0E ; |U..WV.V......A..|
  0000:1116  db CD 21 33 C0 5E 5F 5D C3                         ; |.!3.^_].|

; -------------------------------------------------------------------
; prguf_buildDriveBitmap  (0000:111E)
; Check DOS version and enumerate available drives.
; DOS 3+: use IOCTL to detect drives (more accurate).
; DOS 2: use drive count + floppy config + equipment list.
; Returns: AX:DX = 26-bit drive bitmap (bit 0=A, bit 1=B, etc.)
; -------------------------------------------------------------------
sub_0000_111E:                                  ; prguf_buildDriveBitmap
  0000:111E  b430              mov      ah, 0x30
  0000:1120  cd21              int      0x21                    ; INT 21h/30h: Get DOS version
  0000:1122  3c03              cmp      al, 3
  0000:1124  7205              jb       0x112b                  ; DOS 2: old method
  0000:1126  e80f00            call     0x1138                  ; -> prguf_enumDrives_DOS3
  0000:1129  eb0c              jmp      0x1137

loc_0000_112B:                                  ; DOS 2 path
  0000:112B  e84800            call     0x1176                  ; -> prguf_enumDrives_getCount
  0000:112E  e85300            call     0x1184                  ; -> prguf_buildDriveMask
  0000:1131  e86c00            call     0x11a0                  ; -> prguf_checkFloppyConfig
  0000:1134  e88500            call     0x11bc                  ; -> prguf_checkPrinterPorts

loc_0000_1137:
  0000:1137  c3                ret

; -------------------------------------------------------------------
; prguf_enumDrives_DOS3  (0000:1138)
; Enumerate drives A-Z using IOCTL (INT 21h/44h subfunctions 0Eh/09h).
; For each drive, checks if it's a valid local or remote drive.
; Returns: DI:DX = drive bitmap
; -------------------------------------------------------------------
sub_0000_1138:                                  ; prguf_enumDrives_DOS3
  0000:1138  33ff              xor      di, di
  0000:113A  33d2              xor      dx, dx
  0000:113C  b91a00            mov      cx, 0x1a                ; 26 drives (A-Z)
  0000:113F  d1e7              shl      di, 1                   ; shift bitmap left
  0000:1141  9c                pushf
  0000:1142  d1e2              shl      dx, 1
  0000:1144  9d                popf
  0000:1145  7301              jae      0x1148
  0000:1147  42                inc      dx                      ; carry into DX

loc_0000_1148:
  0000:1148  b80e44            mov      ax, 0x440e              ; IOCTL: get logical drive map
  0000:114B  8ad9              mov      bl, cl                  ; drive number
  0000:114D  cd21              int      0x21                    ; INT 21h/44h: IOCTL
  0000:114F  720a              jb       0x115b                  ; error: check further
  0000:1151  0ac0              or       al, al
  0000:1153  741b              je       0x1170                  ; AL=0: valid single drive
  0000:1155  3ac1              cmp      al, cl
  0000:1157  7417              je       0x1170                  ; AL=CL: same drive, valid
  0000:1159  eb16              jmp      0x1171                  ; different: not valid

loc_0000_115B:                                  ; IOCTL error path
  0000:115B  fec8              dec      al
  0000:115D  7411              je       0x1170                  ; error 1: drive exists
  0000:115F  52                push     dx
  0000:1160  b80944            mov      ax, 0x4409              ; IOCTL: check if remote
  0000:1163  8ad9              mov      bl, cl
  0000:1165  cd21              int      0x21                    ; INT 21h/44h: IOCTL
  0000:1167  f7c20010          test     dx, 0x1000              ; bit 12: remote device
  0000:116B  5a                pop      dx
  0000:116C  7502              jne      0x1170                  ; remote: count as valid
  0000:116E  eb01              jmp      0x1171                  ; local non-existent: skip

loc_0000_1170:
  0000:1170  47                inc      di                      ; set bit for this drive

loc_0000_1171:
  0000:1171  e2cc              loop     0x113f                  ; next drive
  0000:1173  8bc7              mov      ax, di
  0000:1175  c3                ret

; -------------------------------------------------------------------
; prguf_enumDrives_getCount  (0000:1176)
; Get drive count using INT 21h/0Eh (select disk returns last drive #).
; -------------------------------------------------------------------
sub_0000_1176:                                  ; prguf_enumDrives_getCount
  0000:1176  e877ff            call     0x10f0                  ; -> prguf_getDefaultDrive
  0000:1179  86d0              xchg     al, dl
  0000:117B  80ea41            sub      dl, 0x41
  0000:117E  b40e              mov      ah, 0xe
  0000:1180  cd21              int      0x21                    ; INT 21h/0Eh: returns AL=last drive
  0000:1182  98                cwde
  0000:1183  c3                ret

; -------------------------------------------------------------------
; prguf_buildDriveMask  (0000:1184)
; Build a bitmask with bits 0..N-1 set, where N=drive count in AX.
; Returns: AX:DX = bitmask
; -------------------------------------------------------------------
sub_0000_1184:                                  ; prguf_buildDriveMask
  0000:1184  8bc8              mov      cx, ax
  0000:1186  33d2              xor      dx, dx
  0000:1188  33c0              xor      ax, ax
  0000:118A  80f910            cmp      cl, 0x10
  0000:118D  760b              jbe      0x119a
  0000:118F  83e910            sub      cx, 0x10
  0000:1192  d1e2              shl      dx, 1
  0000:1194  42                inc      dx
  0000:1195  e2fb              loop     0x1192
  0000:1197  b91000            mov      cx, 0x10

loc_0000_119A:
  0000:119A  d1e0              shl      ax, 1
  0000:119C  40                inc      ax
  0000:119D  e2fb              loop     0x119a
  0000:119F  c3                ret

; -------------------------------------------------------------------
; prguf_checkFloppyConfig  (0000:11A0)
; Read BIOS floppy configuration byte at 0070:0000.
; If only one physical floppy, clear bit 1 (drive B) from bitmap.
; -------------------------------------------------------------------
sub_0000_11A0:                                  ; prguf_checkFloppyConfig
  0000:11A0  06                push     es
  0000:11A1  b97000            mov      cx, 0x70
  0000:11A4  8ec1              mov      es, cx
  0000:11A6  268a0e0000        mov      cl, byte ptr es:[0]     ; floppy config byte
  0000:11AB  07                pop      es
  0000:11AC  d0e1              shl      cl, 1                   ; check high bit
  0000:11AE  720b              jb       0x11bb                  ; set: multiple floppies
  0000:11B0  d0e9              shr      cl, 1
  0000:11B2  fec9              dec      cl
  0000:11B4  bb0100            mov      bx, 1
  0000:11B7  d3e3              shl      bx, cl
  0000:11B9  33c3              xor      ax, bx                  ; toggle floppy bit

loc_0000_11BB:
  0000:11BB  c3                ret

; -------------------------------------------------------------------
; prguf_checkPrinterPorts  (0000:11BC)
; Check INT 11h equipment list for serial/parallel ports.
; If no serial ports, clear bit 1 of AX (legacy behavior).
; -------------------------------------------------------------------
sub_0000_11BC:                                  ; prguf_checkPrinterPorts
  0000:11BC  50                push     ax
  0000:11BD  cd11              int      0x11                    ; INT 11h: Get equipment list
  0000:11BF  5b                pop      bx
  0000:11C0  25c000            and      ax, 0xc0                ; bits 6-7: serial port count
  0000:11C3  7503              jne      0x11c8                  ; has serial ports: keep
  0000:11C5  83e3fd            and      bx, 0xfffd              ; clear bit 1

loc_0000_11C8:
  0000:11C8  8bc3              mov      ax, bx
  0000:11CA  c3                ret

; -------------------------------------------------------------------
; prguf_showErrorDialog  (0000:11CB)
; Display a filename error dialog box using the INT E0h error system.
; Installs/restores error handlers around the call.
; Params: [bp+4]=error string ID, [bp+6]=title string ID
; -------------------------------------------------------------------
sub_0000_11CB:                                  ; prguf_showErrorDialog
  0000:11CB  55                push     bp
  0000:11CC  8bec              mov      bp, sp
  0000:11CE  52                push     dx
  0000:11CF  56                push     si
  0000:11D0  1e                push     ds
  0000:11D1  06                push     es
  0000:11D2  1f                pop      ds
  0000:11D3  e8beee            call     0x94                    ; -> prguf_installInt24Handler
  0000:11D6  e8e5ee            call     0xbe                    ; -> prguf_setErrorFlag_16
  0000:11D9  bed200            mov      si, 0xd2                ; INT 24h params area
  0000:11DC  8b4604            mov      ax, word ptr [bp + 4]
  0000:11DF  894401            mov      word ptr [si + 1], ax   ; error string
  0000:11E2  8b4606            mov      ax, word ptr [bp + 6]
  0000:11E5  894403            mov      word ptr [si + 3], ax   ; title string
  0000:11E8  56                push     si
  0000:11E9  e8dcee            call     0xc8                    ; -> prguf_setErrorFlag_E9
  0000:11EC  83c402            add      sp, 2
  0000:11EF  e8bdee            call     0xaf                    ; -> prguf_restoreInt24Handler
  0000:11F2  1f                pop      ds
  0000:11F3  5e                pop      si
  0000:11F4  5a                pop      dx
  0000:11F5  5d                pop      bp
  0000:11F6  c3                ret

  ; (0000:11F7) inline wrapper
  0000:11F7  db 55 8B EB EB 03                                  ; |U....|

; -------------------------------------------------------------------
; prguf_validateDrivePath  (0000:11FC)
; Validate that a drive letter in the path is accessible.
; Builds drive bitmap, checks if drive bit is set.
; Shows "Invalid drive" / "Filename Error" dialog if not.
; Params: [bp+6]=path pointer (string with drive letter)
; Returns: AX=1 if valid, AX=0 if invalid (dialog shown)
; -------------------------------------------------------------------
  0000:11FC  55                push     bp
  0000:11FD  8bec              mov      bp, sp
  0000:11FF  56                push     si
  0000:1200  57                push     di
  0000:1201  52                push     dx
  0000:1202  e819ff            call     0x111e                  ; -> prguf_buildDriveBitmap
  0000:1205  50                push     ax                      ; save low bitmap
  0000:1206  52                push     dx                      ; save high bitmap
  0000:1207  8b5e06            mov      bx, word ptr [bp + 6]   ; path pointer
  0000:120A  8b07              mov      ax, word ptr [bx]       ; first 2 chars
  0000:120C  1e                push     ds
  0000:120D  06                push     es
  0000:120E  1f                pop      ds
  0000:120F  e8c3ef            call     0x1d5                   ; -> prguf_toUpperCase
  0000:1212  1f                pop      ds
  0000:1213  2c41              sub      al, 0x41                ; convert to 0-based
  0000:1215  8ac8              mov      cl, al
  0000:1217  5a                pop      dx
  0000:1218  58                pop      ax
  0000:1219  80f90f            cmp      cl, 0xf                 ; drive 0-15?
  0000:121C  7f05              jg       0x1223                  ; high drives use DX
  0000:121E  d3e8              shr      ax, cl                  ; shift bitmap
  0000:1220  eb08              jmp      0x122a
  0000:1222  db 90                                              ; |.| (padding)

loc_0000_1223:
  0000:1223  80e910            sub      cl, 0x10
  0000:1226  d3ea              shr      dx, cl
  0000:1228  8bc2              mov      ax, dx

loc_0000_122A:
  0000:122A  250100            and      ax, 1                   ; test drive bit
  0000:122D  3d0100            cmp      ax, 1
  0000:1230  7414              je       0x1246                  ; valid: return 1
  0000:1232  b8b500            mov      ax, 0xb5                ; "Invalid drive" string ID
  0000:1235  50                push     ax
  0000:1236  b8a200            mov      ax, 0xa2                ; "Filename Error" string ID
  0000:1239  50                push     ax
  0000:123A  e88eff            call     0x11cb                  ; -> prguf_showErrorDialog
  0000:123D  83c404            add      sp, 4
  0000:1240  b80000            mov      ax, 0                   ; invalid: return 0
  0000:1243  eb04              jmp      0x1249
  0000:1245  db 90                                              ; |.| (padding)

loc_0000_1246:
  0000:1246  b80100            mov      ax, 1                   ; valid

loc_0000_1249:
  0000:1249  5a                pop      dx
  0000:124A  5f                pop      di
  0000:124B  5e                pop      si
  0000:124C  5d                pop      bp
  0000:124D  c3                ret

  ; (0000:124E) inline wrapper
  0000:124E  db 55 8B EB EB 03                                  ; |U....|

; -------------------------------------------------------------------
; prguf_getDiskFreeSpace  (0000:1253)
; Get free disk space for a drive.
; Params: [bp+4]=result pointer, [bp+6]=drive number (1=A, 2=B...)
; Returns: DX:AX = free bytes, or AX=0xFFFF if invalid drive
; -------------------------------------------------------------------
  0000:1253  55                push     bp
  0000:1254  8bec              mov      bp, sp
  0000:1256  53                push     bx
  0000:1257  51                push     cx
  0000:1258  8a5606            mov      dl, byte ptr [bp + 6]   ; drive number
  0000:125B  b436              mov      ah, 0x36
  0000:125D  cd21              int      0x21                    ; INT 21h/36h: Get disk free space
  0000:125F  3dffff            cmp      ax, 0xffff
  0000:1262  750b              jne      0x126f                  ; valid result
  0000:1264  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1267  c7070000          mov      word ptr [bx], 0        ; zero result on error
  0000:126B  8bd0              mov      dx, ax
  0000:126D  eb04              jmp      0x1273

loc_0000_126F:
  0000:126F  f7e1              mul      cx                      ; sectors * bytes/sector
  0000:1271  f7e3              mul      bx                      ; * clusters

loc_0000_1273:
  0000:1273  59                pop      cx
  0000:1274  5b                pop      bx
  0000:1275  5d                pop      bp
  0000:1276  c3                ret

  ; (0000:1277) inline wrapper
  0000:1277  db 55 8B EB EB 03                                  ; |U....|

; -------------------------------------------------------------------
; prguf_parsePath  (0000:127C)
; Full path parser: validate drive, change directory, parse 8.3 filename.
; Saves/restores current drive and directory around operations.
; Validates: drive exists, directory exists, filename <= 8.3 format,
; path length <= 66 chars.
; Error codes stored at [bp+4]: 0x6A=invalid drive, 0x6C=name too long,
; 0x6D=extension too long, 0x6F=name empty, 0x70=path too long, 5=access
; Params: [bp+6]=source path, [bp+8]=result buffer
; Returns: AX=0 success, AX=0xFFFF with error code at [bp+4]
; -------------------------------------------------------------------
  0000:127C  55                push     bp
  0000:127D  8bec              mov      bp, sp
  0000:127F  e874ee            call     0xf6                    ; -> prguf_saveInt24Vector
  0000:1282  53                push     bx
  0000:1283  51                push     cx
  0000:1284  52                push     dx
  0000:1285  57                push     di
  0000:1286  1e                push     ds
  0000:1287  06                push     es
  0000:1288  1f                pop      ds
  0000:1289  07                pop      es
  0000:128A  8b7606            mov      si, word ptr [bp + 6]   ; source path
  0000:128D  8bfe              mov      di, si
  0000:128F  32c0              xor      al, al
  0000:1291  b94100            mov      cx, 0x41                ; max 65 chars
  0000:1294  f8                clc
  0000:1295  f2ae              repne scasb al, byte ptr es:[di]
  0000:1297  8bc7              mov      ax, di
  0000:1299  2bc6              sub      ax, si
  0000:129B  48                dec      ax
  0000:129C  a37b01            mov      word ptr [0x17b], ax    ; save path length
  0000:129F  89367901          mov      word ptr [0x179], si    ; save path start
  0000:12A3  8b7e08            mov      di, word ptr [bp + 8]   ; result buffer
  0000:12A6  57                push     di
  ; Save current drive
  0000:12A7  b419              mov      ah, 0x19
  0000:12A9  cd21              int      0x21                    ; INT 21h/19h: Get default drive
  0000:12AB  a2d800            mov      byte ptr [0xd8], al     ; save drive number
  0000:12AE  0441              add      al, 0x41                ; convert to letter
  0000:12B0  aa                stosb    byte ptr es:[di], al    ; store in result: "X"
  0000:12B1  b03a              mov      al, 0x3a
  0000:12B3  aa                stosb    byte ptr es:[di], al    ; ":"
  0000:12B4  b05c              mov      al, 0x5c
  0000:12B6  aa                stosb    byte ptr es:[di], al    ; "\"
  0000:12B7  5f                pop      di
  ; Save current directory
  0000:12B8  beda00            mov      si, 0xda                ; CWD buffer
  0000:12BB  b447              mov      ah, 0x47
  0000:12BD  b200              mov      dl, 0                   ; current drive
  0000:12BF  cd21              int      0x21                    ; INT 21h/47h: Get current directory
  ; Parse drive letter from source path
  0000:12C1  8b367901          mov      si, word ptr [0x179]
  0000:12C5  8b0e7b01          mov      cx, word ptr [0x17b]
  0000:12C9  83f902            cmp      cx, 2
  0000:12CC  7c43              jl       0x1311                  ; no drive letter
  0000:12CE  26807c013a        cmp      byte ptr es:[si + 1], 0x3a
  0000:12D3  753c              jne      0x1311                  ; no colon: no drive
  0000:12D5  268a14            mov      dl, byte ptr es:[si]    ; drive letter
  0000:12D8  80ca20            or       dl, 0x20                ; to lowercase
  0000:12DB  80ea61            sub      dl, 0x61                ; to 0-based
  0000:12DE  b40e              mov      ah, 0xe
  0000:12E0  cd21              int      0x21                    ; INT 21h/0Eh: Set default drive
  0000:12E2  b419              mov      ah, 0x19
  0000:12E4  cd21              int      0x21                    ; INT 21h/19h: Verify drive change
  0000:12E6  3ad0              cmp      dl, al
  0000:12E8  7406              je       0x12f0                  ; success
  0000:12EA  b86a00            mov      ax, 0x6a                ; error: invalid drive (0x6A)
  0000:12ED  e95701            jmp      0x1447                  ; -> error exit

loc_0000_12F0:
  0000:12F0  0441              add      al, 0x41
  0000:12F2  268805            mov      byte ptr es:[di], al    ; update drive in result
  0000:12F5  83c602            add      si, 2                   ; skip "X:" in source
  0000:12F8  83e902            sub      cx, 2
  0000:12FB  56                push     si
  0000:12FC  beda00            mov      si, 0xda
  0000:12FF  b200              mov      dl, 0
  0000:1301  b447              mov      ah, 0x47
  0000:1303  cd21              int      0x21                    ; INT 21h/47h: Get current directory
  0000:1305  5e                pop      si
  0000:1306  7309              jae      0x1311                  ; success
  0000:1308  e89f01            call     0x14aa                  ; -> prguf_translateError
  0000:130B  7304              jae      0x1311
  0000:130D  50                push     ax
  0000:130E  e94701            jmp      0x1458                  ; -> restore and exit

loc_0000_1311:                                  ; change to source directory
  0000:1311  56                push     si
  0000:1312  1e                push     ds
  0000:1313  06                push     es
  0000:1314  1f                pop      ds
  0000:1315  07                pop      es
  0000:1316  b43b              mov      ah, 0x3b
  0000:1318  8b5606            mov      dx, word ptr [bp + 6]
  0000:131B  cd21              int      0x21                    ; INT 21h/3Bh: Change directory
  0000:131D  1e                push     ds
  0000:131E  06                push     es
  0000:131F  1f                pop      ds
  0000:1320  07                pop      es
  0000:1321  5e                pop      si
  0000:1322  7203              jb       0x1327                  ; chdir failed
  0000:1324  eb0a              jmp      0x1330                  ; success
  0000:1326  db 90                                              ; |.| (padding)

loc_0000_1327:                                  ; chdir error: try partial path
  0000:1327  e88001            call     0x14aa                  ; -> prguf_translateError
  0000:132A  730e              jae      0x133a
  0000:132C  50                push     ax
  0000:132D  e92801            jmp      0x1458                  ; -> restore

loc_0000_1330:                                  ; chdir succeeded: get resulting cwd
  0000:1330  e86101            call     0x1494                  ; -> prguf_getWorkingDir
  0000:1333  7202              jb       0x1337
  0000:1335  33c0              xor      ax, ax                  ; success

loc_0000_1337:
  0000:1337  e91601            jmp      0x1450                  ; -> exit

loc_0000_133A:                                  ; parse path components
  0000:133A  8bfe              mov      di, si
  0000:133C  b05c              mov      al, 0x5c                ; '\'

loc_0000_133E:                                  ; find last backslash
  0000:133E  893e7901          mov      word ptr [0x179], di
  0000:1342  890e7b01          mov      word ptr [0x17b], cx
  0000:1346  e304              jcxz     0x134c
  0000:1348  f2ae              repne scasb al, byte ptr es:[di]
  0000:134A  74f2              je       0x133e

loc_0000_134C:                                  ; check for '.' (extension separator)
  0000:134C  8b3e7901          mov      di, word ptr [0x179]
  0000:1350  b02e              mov      al, 0x2e                ; '.'
  0000:1352  8b0e7b01          mov      cx, word ptr [0x17b]
  0000:1356  41                inc      cx
  0000:1357  f2ae              repne scasb al, byte ptr es:[di]
  0000:1359  83f900            cmp      cx, 0
  0000:135C  7f0a              jg       0x1368                  ; has extension
  0000:135E  833e7b0108        cmp      word ptr [0x17b], 8
  0000:1363  7f50              jg       0x13b5                  ; name > 8 chars: error
  0000:1365  eb5f              jmp      0x13c6                  ; no ext, name <= 8: ok
  0000:1367  db 90                                              ; |.| (padding)

loc_0000_1368:                                  ; has extension: validate ".." special case
  0000:1368  8b3e7901          mov      di, word ptr [0x179]
  0000:136C  26803d2e          cmp      byte ptr es:[di], 0x2e  ; starts with '.'?
  0000:1370  7521              jne      0x1393                  ; no: normal name
  0000:1372  26807d012e        cmp      byte ptr es:[di + 1], 0x2e ; ".."?
  0000:1377  751a              jne      0x1393
  ; Handle ".." (parent directory)
  0000:1379  bfd900            mov      di, 0xd9
  0000:137C  b000              mov      al, 0
  0000:137E  b90300            mov      cx, 3
  0000:1381  f2ae              repne scasb al, byte ptr es:[di]
  0000:1383  83f900            cmp      cx, 0
  0000:1386  7403              je       0x138b                  ; at root: error
  0000:1388  eb68              jmp      0x13f2
  0000:138A  db 90                                              ; |.| (padding)

loc_0000_138B:                                  ; ".." at root = just copy ".."
  0000:138B  b90200            mov      cx, 2
  0000:138E  bf2901            mov      di, 0x129               ; temp path buffer
  0000:1391  eb44              jmp      0x13d7

loc_0000_1393:                                  ; validate extension length
  0000:1393  8b3e7901          mov      di, word ptr [0x179]
  0000:1397  b02e              mov      al, 0x2e
  0000:1399  8b0e7b01          mov      cx, word ptr [0x17b]
  0000:139D  41                inc      cx
  0000:139E  f2ae              repne scasb al, byte ptr es:[di]
  0000:13A0  83f905            cmp      cx, 5
  0000:13A3  7e06              jle      0x13ab                  ; ext <= 4 chars (with '.') ok
  0000:13A5  b86d00            mov      ax, 0x6d                ; error: extension too long
  0000:13A8  e99c00            jmp      0x1447                  ; -> error exit

loc_0000_13AB:                                  ; validate name length (before '.')
  0000:13AB  a17b01            mov      ax, word ptr [0x17b]
  0000:13AE  2bc1              sub      ax, cx                  ; name part length
  0000:13B0  3d0800            cmp      ax, 8
  0000:13B3  7e06              jle      0x13bb                  ; <= 8: ok

loc_0000_13B5:                                  ; name too long
  0000:13B5  b86c00            mov      ax, 0x6c                ; error: name too long
  0000:13B8  e98c00            jmp      0x1447

loc_0000_13BB:                                  ; check name not empty
  0000:13BB  3d0100            cmp      ax, 1
  0000:13BE  7d06              jge      0x13c6                  ; at least 1 char: ok
  0000:13C0  b86f00            mov      ax, 0x6f                ; error: empty name
  0000:13C3  e98100            jmp      0x1447

loc_0000_13C6:                                  ; build directory path in temp buffer
  0000:13C6  bf2901            mov      di, 0x129               ; temp path buffer
  0000:13C9  8b0e7901          mov      cx, word ptr [0x179]
  0000:13CD  2bce              sub      cx, si                  ; directory part length
  0000:13CF  7427              je       0x13f8                  ; no directory: just filename
  0000:13D1  83f901            cmp      cx, 1
  0000:13D4  7401              je       0x13d7                  ; single char (like '\')
  0000:13D6  49                dec      cx                      ; exclude trailing '\'

loc_0000_13D7:                                  ; copy directory to temp, chdir
  0000:13D7  1e                push     ds
  0000:13D8  06                push     es
  0000:13D9  1f                pop      ds
  0000:13DA  07                pop      es
  0000:13DB  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:13DD  32c0              xor      al, al
  0000:13DF  aa                stosb    byte ptr es:[di], al    ; null terminate
  0000:13E0  1e                push     ds
  0000:13E1  06                push     es
  0000:13E2  1f                pop      ds
  0000:13E3  07                pop      es
  0000:13E4  ba2901            mov      dx, 0x129
  0000:13E7  b43b              mov      ah, 0x3b
  0000:13E9  cd21              int      0x21                    ; INT 21h/3Bh: Change directory
  0000:13EB  730b              jae      0x13f8                  ; success
  0000:13ED  e8ba00            call     0x14aa                  ; -> prguf_translateError
  0000:13F0  725e              jb       0x1450                  ; error: exit

loc_0000_13F2:                                  ; access denied or other error
  0000:13F2  b80500            mov      ax, 5                   ; error: access denied
  0000:13F5  eb50              jmp      0x1447
  0000:13F7  db 90                                              ; |.| (padding)

loc_0000_13F8:                                  ; get final CWD after directory changes
  0000:13F8  e89900            call     0x1494                  ; -> prguf_getWorkingDir
  0000:13FB  7253              jb       0x1450                  ; error: exit
  0000:13FD  8bfe              mov      di, si                  ; DI = filename component start
  0000:13FF  26803d00          cmp      byte ptr es:[di], 0     ; empty filename?
  0000:1403  7425              je       0x142a                  ; yes: directory only
  0000:1405  32c0              xor      al, al
  0000:1407  b94200            mov      cx, 0x42                ; max 66 chars total
  0000:140A  f2ae              repne scasb al, byte ptr es:[di]
  0000:140C  e311              jcxz     0x141f                  ; path too long
  0000:140E  8b1e7b01          mov      bx, word ptr [0x17b]    ; filename length
  0000:1412  0bdb              or       bx, bx
  0000:1414  742d              je       0x1443                  ; empty: just return
  0000:1416  43                inc      bx
  0000:1417  43                inc      bx
  0000:1418  83c303            add      bx, 3
  0000:141B  3bd9              cmp      bx, cx
  0000:141D  7e06              jle      0x1425                  ; fits in max

loc_0000_141F:                                  ; path too long
  0000:141F  b87000            mov      ax, 0x70                ; error: path too long
  0000:1422  eb23              jmp      0x1447
  0000:1424  db 90                                              ; |.| (padding)

loc_0000_1425:                                  ; append backslash before filename
  0000:1425  26c645ff5c        mov      byte ptr es:[di - 1], 0x5c

loc_0000_142A:                                  ; append filename to result
  0000:142A  33c0              xor      ax, ax
  0000:142C  8b367901          mov      si, word ptr [0x179]    ; filename start
  0000:1430  26803c2e          cmp      byte ptr es:[si], 0x2e  ; starts with '.'?
  0000:1434  741a              je       0x1450                  ; "." or "..": just cwd
  0000:1436  8b0e7b01          mov      cx, word ptr [0x17b]    ; filename length
  0000:143A  1e                push     ds
  0000:143B  06                push     es
  0000:143C  1f                pop      ds
  0000:143D  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:143F  32c0              xor      al, al
  0000:1441  aa                stosb    byte ptr es:[di], al    ; null terminate
  0000:1442  1f                pop      ds

loc_0000_1443:                                  ; success
  0000:1443  33c0              xor      ax, ax
  0000:1445  eb09              jmp      0x1450

loc_0000_1447:                                  ; error: store code and return -1
  0000:1447  8b5e04            mov      bx, word ptr [bp + 4]
  0000:144A  268907            mov      word ptr es:[bx], ax    ; store error code
  0000:144D  b8ffff            mov      ax, 0xffff

loc_0000_1450:                                  ; restore original drive and directory
  0000:1450  50                push     ax
  0000:1451  bad900            mov      dx, 0xd9                ; saved CWD buffer (with '\')
  0000:1454  b43b              mov      ah, 0x3b
  0000:1456  cd21              int      0x21                    ; INT 21h/3Bh: Restore directory

loc_0000_1458:                                  ; restore original drive
  0000:1458  8a16d800          mov      dl, byte ptr [0xd8]     ; saved drive number
  0000:145C  b40e              mov      ah, 0xe
  0000:145E  cd21              int      0x21                    ; INT 21h/0Eh: Restore drive
  0000:1460  58                pop      ax
  0000:1461  3d0000            cmp      ax, 0
  0000:1464  7d03              jge      0x1469                  ; success or positive
  0000:1466  eb1d              jmp      0x1485                  ; error: skip uppercase
  0000:1468  db 90                                              ; |.| (padding)

loc_0000_1469:                                  ; uppercase the result path
  0000:1469  8b7e08            mov      di, word ptr [bp + 8]

loc_0000_146C:
  0000:146C  26803d00          cmp      byte ptr es:[di], 0     ; end of string?
  0000:1470  7413              je       0x1485
  0000:1472  26803d61          cmp      byte ptr es:[di], 0x61  ; 'a'
  0000:1476  720a              jb       0x1482
  0000:1478  26803d7a          cmp      byte ptr es:[di], 0x7a  ; 'z'
  0000:147C  7704              ja       0x1482
  0000:147E  2680255f          and      byte ptr es:[di], 0x5f  ; to uppercase

loc_0000_1482:
  0000:1482  47                inc      di
  0000:1483  ebe7              jmp      0x146c

loc_0000_1485:                                  ; epilogue: restore segments and INT 24h
  0000:1485  1e                push     ds
  0000:1486  06                push     es
  0000:1487  1f                pop      ds
  0000:1488  07                pop      es
  0000:1489  5f                pop      di
  0000:148A  5a                pop      dx
  0000:148B  59                pop      cx
  0000:148C  5b                pop      bx
  0000:148D  50                push     ax
  0000:148E  e885ec            call     0x116                   ; -> prguf_restoreInt24Vector
  0000:1491  58                pop      ax
  0000:1492  5d                pop      bp
  0000:1493  c3                ret

; -------------------------------------------------------------------
; prguf_getWorkingDir  (0000:1494)
; Get current working directory into result buffer at [bp+8]+3.
; -------------------------------------------------------------------
sub_0000_1494:                                  ; prguf_getWorkingDir
  0000:1494  1e                push     ds
  0000:1495  06                push     es
  0000:1496  1f                pop      ds
  0000:1497  b200              mov      dl, 0                   ; current drive
  0000:1499  8b7608            mov      si, word ptr [bp + 8]
  0000:149C  83c603            add      si, 3                   ; skip "X:\"
  0000:149F  b447              mov      ah, 0x47
  0000:14A1  cd21              int      0x21                    ; INT 21h/47h: Get current directory
  0000:14A3  1f                pop      ds
  0000:14A4  7303              jae      0x14a9                  ; success
  0000:14A6  e80100            call     0x14aa                  ; -> prguf_translateError

loc_0000_14A9:
  0000:14A9  c3                ret

; -------------------------------------------------------------------
; prguf_translateError  (0000:14AA)
; Translate a DOS error into the PRGUF error format.
; Calls prguf_handleDosError, sets carry flag on error.
; -------------------------------------------------------------------
sub_0000_14AA:                                  ; prguf_translateError
  0000:14AA  53                push     bx
  0000:14AB  1e                push     ds
  0000:14AC  06                push     es
  0000:14AD  1f                pop      ds
  0000:14AE  07                pop      es
  0000:14AF  ff7604            push     word ptr [bp + 4]       ; error result ptr
  0000:14B2  e895ec            call     0x14a                   ; -> prguf_handleDosError
  0000:14B5  83c402            add      sp, 2
  0000:14B8  b8ffff            mov      ax, 0xffff
  0000:14BB  8b5e04            mov      bx, word ptr [bp + 4]
  0000:14BE  833f00            cmp      word ptr [bx], 0

; ------------------------------------------------------------------------
; SEGMENT seg_014C  (144 bytes, file 0x16C0-0x1750)
; API function dispatch table: array of word offsets into seg_0000.
; Each entry is a 2-byte near pointer to a PRGUF function.
; The table is indexed by function number from the DeskMate host.
; ------------------------------------------------------------------------
seg_014C:

  014C:0000  db 00                                              ; |.|
  014C:0001  7d03              jge      0x14c6                  ; (continuation of translateError)
  014C:0003  f9                stc                              ; set carry = error
  014C:0004  eb01              jmp      0x14c7

loc_014C_0006:
  014C:0006  f8                clc                              ; clear carry = success

loc_014C_0007:
  014C:0007  1e                push     ds
  014C:0008  06                push     es
  014C:0009  1f                pop      ds
  014C:000A  07                pop      es
  014C:000B  5b                pop      bx
  014C:000C  c3                ret

  ; Function dispatch table (word offsets into seg_0000):
  ; Index 0x00-0x25, each a word-sized pointer to a handler function.
  014C:000D  db 52 10 6A 10 3C 10 7D 10 76 0F EA 0F A6 0F C1 0F ; |R.j.<.}.v.......|
  014C:001D  db 1F 01 8C 10 C0 10 CD 03 90 03 66 02 96 04 4E 03 ; |..........f...N.|
  014C:002D  db F8 04 47 0F F0 10 7F 00 C8 10 4D 00 06 11 4E 12 ; |..G.......M...N.|
  014C:003D  db 00 00 1E 11 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  014C:004D  db 00 00 00 00 A3 01 CA 01 E5 01 04 02 29 02 00 00 ; |............)...|
  014C:005D  db 00 00 00 00 00 00 00 00 00 00 00 00 77 12 00 00 ; |............w...|
  014C:006D  db F7 11 00 00 00 00 00 00 00 00 00 00 00 00 0B 03 ; |................|
  014C:007D  db 94 0E 77 12 17 0F E0 0E 3C 0F 05 0F 00 00 00 00 ; |..w.....<.......|
  014C:008D  db 26 10 31                                        ; |&.1|

; ------------------------------------------------------------------------
; SEGMENT seg_0155  (224 bytes, file 0x1750-0x1830)
; TSR startup code and INT E0h dispatch handler.
; Entry point at 0155:000C.
; ------------------------------------------------------------------------
seg_0155:


; -------------------------------------------------------------------
; sub_0155_0000  (data block, not code)
; DM89 module header: "PRGUF" name, version, and internal pointers.
; This data is referenced by the DeskMate host for module identification.
; -------------------------------------------------------------------
sub_0155_0000:
  0155:0000  105c0a            adc      byte ptr [si + 0xa], bl ; (data, not real instructions)
  0155:0003  ee                out      dx, al
  0155:0004  09790b            or       word ptr [bx + di + 0xb], di
  0155:0007  bb3412            mov      bx, 0x1234
  0155:000A  0000              add      byte ptr [bx + si], al

; -------------------------------------------------------------------
; entry_point  (0155:000C)
; TSR entry point. Registers PRGUF with DeskMate host via INT E0h,
; calculates resident size, computes string pool size, then goes
; resident via INT 21h/31h.
; -------------------------------------------------------------------
entry_point:
  0155:000C  b86301            mov      ax, 0x163               ; RELOC->seg_0163 (data segment)
  0155:000F  8ed8              mov      ds, ax
  0155:0011  2e8c1e0a00        mov      word ptr cs:[0xa], ds   ; save DS in header
  0155:0016  06                push     es
  0155:0017  53                push     bx
  0155:0018  57                push     di
  0155:0019  56                push     si
  0155:001A  bb0600            mov      bx, 6                   ; offset in header
  0155:001D  8cc0              mov      ax, es
  0155:001F  894720            mov      word ptr [bx + 0x20], ax ; store caller segment
  0155:0022  1e                push     ds
  0155:0023  07                pop      es
  ; Query DeskMate host capabilities
  0155:0024  b80006            mov      ax, 0x600
  0155:0027  cde0              int      0xe0                    ; INT E0h/06h: get host flags
  0155:0029  250080            and      ax, 0x8000              ; test bit 15
  0155:002C  7405              je       0x33                    ; bit clear: use 0x01FF
  0155:002E  b8f001            mov      ax, 0x1f0               ; bit set: use 0x01F0
  0155:0031  eb03              jmp      0x36

loc_0155_0033:
  0155:0033  b8ff01            mov      ax, 0x1ff

loc_0155_0036:
  ; Register with host
  0155:0036  b90000            mov      cx, 0                   ; RELOC->seg_0000 (code segment)
  0155:0039  cde0              int      0xe0                    ; INT E0h/01h: register module
  0155:003B  a27e01            mov      byte ptr [0x17e], al    ; save mutex ID
  0155:003E  5e                pop      si
  0155:003F  5f                pop      di
  0155:0040  5b                pop      bx
  0155:0041  07                pop      es
  ; Calculate string pool size
  0155:0042  b80000            mov      ax, 0                   ; (relocation placeholder)
  0155:0045  b9e803            mov      cx, 0x3e8               ; 1000
  0155:0048  f7e1              mul      cx
  0155:004A  8bc8              mov      cx, ax
  0155:004C  b8581b            mov      ax, 0x1b58              ; 7000 bytes total
  0155:004F  2bc1              sub      ax, cx
  0155:0051  a35402            mov      word ptr [0x254], ax    ; pool max size
  0155:0054  050f00            add      ax, 0xf
  0155:0057  b104              mov      cl, 4
  0155:0059  d3e8              shr      ax, cl                  ; convert to paragraphs
  0155:005B  50                push     ax
  0155:005C  b89b01            mov      ax, 0x19b               ; RELOC->seg_019B (BSS end)
  0155:005F  2d6301            sub      ax, 0x163               ; RELOC->seg_0163 (DGROUP start)
  0155:0062  b104              mov      cl, 4
  0155:0064  d3e0              shl      ax, cl                  ; DGROUP size in bytes
  0155:0066  a35202            mov      word ptr [0x252], ax    ; pool base offset
  ; Initialize the pool
  0155:0069  9a05000000        lcall    0, 5                    ; -> sub_0155_0000 | RELOC->seg_0000
  ; Calculate TSR size and go resident
  0155:006E  b89b01            mov      ax, 0x19b               ; RELOC->seg_019B
  0155:0071  2b062600          sub      ax, word ptr [0x26]
  0155:0075  5a                pop      dx
  0155:0076  03d0              add      dx, ax                  ; total resident paragraphs
  0155:0078  33c0              xor      ax, ax
  0155:007A  b431              mov      ah, 0x31
  0155:007C  cd21              int      0x21                    ; INT 21h/31h: TSR

; -------------------------------------------------------------------
; prguf_dispatchHandler  (0155:007E)
; INT E0h dispatch handler. Called by DeskMate host for each PRGUF
; function invocation. Saves DS, loads data segment, acquires mutex,
; dispatches to function table in seg_014C, releases mutex.
; -------------------------------------------------------------------
  0155:007E  55                push     bp
  0155:007F  1e                push     ds
  0155:0080  8bec              mov      bp, sp
  0155:0082  4c                dec      sp                      ; local variable space
  0155:0083  2e8e1e0a00        mov      ds, word ptr cs:[0xa]   ; restore DGROUP DS
  0155:0088  50                push     ax
  ; Acquire display mutex
  0155:0089  a07e01            mov      al, byte ptr [0x17e]    ; mutex ID
  0155:008C  3cff              cmp      al, 0xff                ; no mutex?
  0155:008E  7409              je       0x99
  0155:0090  52                push     dx
  0155:0091  8ad0              mov      dl, al
  0155:0093  b8044d            mov      ax, 0x4d04
  0155:0096  cde0              int      0xe0                    ; INT E0h/4Dh: acquire mutex
  0155:0098  5a                pop      dx

loc_0155_0099:
  0155:0099  8846ff            mov      byte ptr [bp - 1], al   ; save mutex state
  0155:009C  58                pop      ax
  ; Map function number
  0155:009D  3dae00            cmp      ax, 0xae
  0155:00A0  7407              je       0xa9
  0155:00A2  3db000            cmp      ax, 0xb0
  0155:00A5  7407              je       0xae
  0155:00A7  eb08              jmp      0xb1

loc_0155_00A9:                                  ; map 0xAE -> 0x39
  0155:00A9  b83900            mov      ax, 0x39
  0155:00AC  eb03              jmp      0xb1

loc_0155_00AE:                                  ; map 0xB0 -> 0x30
  0155:00AE  2d8000            sub      ax, 0x80

loc_0155_00B1:                                  ; dispatch through function table
  0155:00B1  9a0b000000        lcall    0, 0xb                  ; -> seg_0000 thunk | RELOC->seg_0000
  ; Release display mutex
  0155:00B6  52                push     dx
  0155:00B7  50                push     ax
  0155:00B8  8a46ff            mov      al, byte ptr [bp - 1]
  0155:00BB  3cff              cmp      al, 0xff
  0155:00BD  7409              je       0xc8
  0155:00BF  52                push     dx
  0155:00C0  8ad0              mov      dl, al
  0155:00C2  b8054d            mov      ax, 0x4d05
  0155:00C5  cde0              int      0xe0                    ; INT E0h/4Dh: release mutex
  0155:00C7  5a                pop      dx

loc_0155_00C8:
  0155:00C8  58                pop      ax
  0155:00C9  5a                pop      dx
  0155:00CA  8be5              mov      sp, bp
  0155:00CC  1f                pop      ds
  0155:00CD  5d                pop      bp
  0155:00CE  cb                retf

  ; (0155:00CF-00DF) alternate entry / initialization code
  0155:00CF  db CB 1E 50 B8 63 01 8E D8 58 32 C0 80 3E 23 03 02 ; |..P.c...X2..>#..| [RELOC->seg_0163]
  0155:00DF  db 74                                              ; |t|

; ------------------------------------------------------------------------
; SEGMENT seg_0163  (872 bytes, file 0x1830-0x1B98)
; Data segment: module name, version string, label file references,
; error message strings, and BSS workspace area.
; ------------------------------------------------------------------------
seg_0163:

  ; DM89 header continuation
  0163:0000  db 02 B0 03 1F CF 00                               ; |......|
  0163:0006  db 50 52 47 55 46                                  ; "PRGUF"
  0163:000B  db 00                                                ; NUL
  0163:000C  db 00 00 7E 00 55 01 CF 00 55 01 00 00 00 00 00 00 ; |..~.U...U.......| [RELOC->seg_0155]
  0163:001C  db 00 00 00 00 00 00 00 00 00 00 00 00 03 18 01    ; |...............|
  0163:002B  db 31 2E 32 34 4C                                  ; "1.24L" (version)
  0163:0030  db 01 00 00 00                                     ; |....|
  0163:0034  db 44 4D 43 53 52                                  ; "DMCSR" (companion module)
  0163:0039  db 00                                                ; NUL
  0163:003A  db 00 00 00 00 00 00 00 00 55 01 00 00 00 00 01 91 ; |........U.......| [RELOC->seg_0155]
  0163:004A  db 00 32 03 00                                     ; |.2..|
  ; Label file references
  0163:004E  db 44 45 53 4B 4D 41 54 45 2E 4C 42 4C             ; "DESKMATE.LBL"
  0163:005A  db 00                                                ; NUL
  0163:005B  db 4C 41 42 45 4C 2E 4C 42 4C                      ; "LABEL.LBL"
  0163:0064  db 00                                                ; NUL
  0163:0065  db 4C 41 42 45 4C 53                               ; "LABELS"
  0163:006B  db 00                                                ; NUL
  0163:006C  db 54 41 53 4B 20 2E 4C 42 4C                      ; "TASK .LBL"
  0163:0075  db 00                                                ; NUL
  0163:0076  db 2E 50 44 4D                                     ; ".PDM"
  0163:007A  db 00                                                ; NUL
  0163:007B  db 00                                              ; |.|
  ; UI strings for file creation dialog
  0163:007C  db 43 72 65 61 74 69 6E 67 20 66 69 6C 65 20       ; "Creating file "
  0163:008A  db 00                                                ; NUL
  0163:008B  db 00 00 00 00 00 00                               ; |......|
  0163:0091  db 43 72 65 61 74 65 20 46 69 6C 65                ; "Create File"
  0163:009C  db 00                                                ; NUL
  0163:009D  db 00 00 00 00 00                                  ; |.....|
  ; Error strings
  0163:00A2  db 46 69 6C 65 6E 61 6D 65 20 45 72 72 6F 72       ; "Filename Error"
  0163:00B0  db 00                                                ; NUL
  0163:00B1  db 00 00 00 00                                     ; |....|
  0163:00B5  db 49 6E 76 61 6C 69 64 20 64 72 69 76 65          ; "Invalid drive"
  0163:00C2  db 00                                                ; NUL
  ; BSS workspace (zeroed at load time)
  0163:00C3  db 00 00 00 00 00 00 00 00 00 00 00 00 00 54 00 00 ; |.............T..|
  0163:00D3  db 00 00 00 00 00 00 5C 00 00 00 00 00 00 00 00 00 ; |......\.........|
  ; (remainder is BSS zeroes through 0163:0367)
  0163:00E3  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  ; ... (continued zero-filled BSS area)
