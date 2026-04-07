; ========================================================================
; AUTOLOAD.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; AUTOLOAD.RES is the Startup Configuration Manager for DeskMate 3.05.
; It manages the AUTOLOAD.CFG file which stores the list of modules
; (.PDM applications and .RES drivers) that should be automatically
; loaded when DeskMate starts.
;
; When the user selects "Create Startup" from the desktop, this module:
;   1. Reads the current module configuration from the DM89 host
;   2. Locates the DESK.EXE boot drive by parsing the COMSPEC
;      environment variable from the PSP environment block
;   3. Prompts the user to insert the correct disk (for floppy systems)
;      using dialog boxes with disk swap prompts
;   4. Writes AUTOLOAD.CFG to the target drive containing a list
;      of 17-byte module entries (module name + flags + drive byte)
;   5. Supports up to 10 module entries in the config file
;
; The module handles both floppy-based and hard-disk-based systems:
;   - For floppy systems (<=2 drives), prompts for disk insertion
;   - For hard disk systems, writes directly to the boot drive
;   - Uses INT 15h/70xxh (Tandy-specific) for drive status tracking
;   - Uses INT 21h/4408h IOCTL to detect removable media
;
; The AUTOLOAD.CFG file format uses 17-byte (0x11) records per module:
;   +0x00  module_name[11]  - Module filename (space-padded)
;   +0x0B  drive_byte       - Source drive (0=current, 1=A, 2=B, 3=C)
;   +0x0C  flags[5]         - Module flags
;
; Module name: "AUTOLOAD"
;
; DM89 imports: PRGUF, DMGUF, DMCSR
; Supported video modes: 1000, CGA, DDGA, EGA, HERC, PLAN, TC16, TC4,
;                        VGA, MCGA, LRES, T256, TC40, H
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 4,244 bytes
; Load image: 3,732 bytes (after header)
; DM89 entry point: 0000:0027
; SS:SP = 00F0:0002
; Min alloc: 0x0000, Max alloc: 0x0001 paragraphs
;
; Segment Map (3 segments, 8 relocations):
;   seg_0000  3,088 bytes  CODE   Startup config engine: module list
;                                 management, AUTOLOAD.CFG file I/O,
;                                 COMSPEC parsing, disk swap dialogs,
;                                 drive detection, DM89 API wrappers,
;                                 file open/read/write/close/seek/delete
;   seg_00C1  644 bytes    DATA   Dialog strings ("Create Startup",
;                                 disk swap prompts), "AUTOLOAD" module
;                                 name, "X:\AUTOLOAD.CFG" path template,
;                                 "COMSPEC=" search key, "X:\DESK.EXE"
;                                 path, PRGUF/DMGUF/DMCSR imports,
;                                 video mode compatibility table,
;                                 module entry array (up to 10 entries)
;   seg_00F0  BSS                 Stack + runtime state
;
; ========================================================================
; FUNCTION INDEX (seg_0000 - Startup Config Engine)
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   autoload_initImports          Load PRGUF import, init DMGUF
; 0000:0027   autoload_entryPoint           DM89 entry: set DS, register, TSR
; 0000:0069   autoload_dispatchHandler      Far-call handler: save regs, dispatch
; 0000:0093   autoload_mainLogic            Main: read config, manage module list
; 0000:0227   autoload_buildCfgPath         Build AUTOLOAD.CFG path from COMSPEC drive
; 0000:0251   autoload_parseCOMSPEC         Parse COMSPEC= from PSP environment block
; 0000:02C6   autoload_promptDeskDisk       Prompt user to insert DESK.EXE disk
; 0000:031C   autoload_openCfgFile          Open AUTOLOAD.CFG, handle disk prompts
; 0000:0406   autoload_createCfgFile        Create new AUTOLOAD.CFG file
; 0000:0498   autoload_readCfgEntries       Read module entries from AUTOLOAD.CFG
; 0000:04E0   autoload_writeCfgFile         Write module entries to AUTOLOAD.CFG
; 0000:0566   autoload_closeCfgFile         Close AUTOLOAD.CFG file handle
; 0000:05A2   autoload_deleteFile           Delete file by handle
; 0000:05AF   autoload_deleteCfgFile        Delete AUTOLOAD.CFG from disk
; 0000:05C7   autoload_detectFloppyDrives   Detect floppy drive count and type
; 0000:0627   autoload_getFloppyCount       Get floppy count from BIOS equipment (INT 11h)
; 0000:0631   autoload_loadPRGUF            Load PRGUF import via INT E0h/0206h
; 0000:064F   autoload_unloadPRGUF          Unload PRGUF import via INT E0h/0207h
; 0000:066A   autoload_checkTandyDrive      Check Tandy drive status (INT 15h/70h)
; 0000:069B   autoload_checkHostVersion     Check DM89 host version and INT 15h hook
; 0000:06B5   autoload_hookINT15            Hook INT 15h vector for drive detection
; 0000:06DA   autoload_restoreINT15         Restore original INT 15h vector
; 0000:0714   autoload_updateDriveStatus    Update Tandy drive status word
; 0000:073D   autoload_findModuleInList     Search module list for matching entry
; 0000:0781   autoload_strlen               Calculate string length (scan for NUL)
; 0000:079C   autoload_strcpy               Copy string (NUL-terminated)
; 0000:07AB   autoload_strcmp                Compare two strings
; 0000:0826   autoload_loadDMGUF            Load DMGUF import, set up dispatch ptrs
; 0000:0890   autoload_prgufDispatch        PRGUF far-call dispatch (file operations)
; 0000:08D4   autoload_dmgufDispatch        DMGUF far-call dispatch (GUI operations)
; 0000:0911   autoload_fileClose            File close (PRGUF func 1)
; 0000:0917   autoload_fileOpen             File open (PRGUF func 2)
; 0000:091D   autoload_fileSeek             File seek (PRGUF func 4)
; 0000:0923   autoload_fileRead             File read (PRGUF func 5)
; 0000:0929   autoload_fileWrite            File write (PRGUF func 6)
; 0000:092F   autoload_fileTruncate         File truncate/set size (PRGUF func 7)
; 0000:0935   autoload_fileDelete           File delete (PRGUF func 8)
; 0000:093B   autoload_fileGetInfo          File get info (PRGUF func 19)
; 0000:0941   autoload_getDriveMap          Get drive map (PRGUF func 25)
; 0000:0947   autoload_guiFunc1C            DMGUF function 0x1C
; 0000:094D   autoload_guiFunc1D            DMGUF function 0x1D
; 0000:0953   autoload_guiFunc1E            DMGUF function 0x1E
; 0000:0959   autoload_guiFunc1F            DMGUF function 0x1F
; 0000:095F   autoload_guiFunc20            DMGUF function 0x20
; 0000:0965   autoload_guiFunc21            DMGUF function 0x21
; 0000:096B   autoload_checkDiskReady       Check disk ready (PRGUF func 56)
; 0000:0971   autoload_callWithStack        Call DM89 API with stack swap for safety
; 0000:0A5F   autoload_dm89Query            Query DM89 host info (INT E0h/0600h)
; 0000:0A65   autoload_dm89GetDir           Get current directory (INT E0h/0601h)
; 0000:0A6B   autoload_dm89FileExists       Check file exists (INT E0h/0604h)
; 0000:0A71   autoload_registerPRGUF        Register PRGUF import (INT E0h/0206h)
; 0000:0A8A   autoload_unregisterDMCSR      Unregister DMCSR (INT E0h/0207h)
; 0000:0AA7   autoload_showDialog           Display dialog box via DMGUF
; 0000:0ADB   autoload_showDiskSwapDialog   Show disk swap dialog (func 0x20E9)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; AUTOLOAD.CFG Record (17 bytes per entry, max 10 entries):
;   +0x00  module_name[11]  - Space-padded module filename
;   +0x0B  drive_byte       - Source drive index
;   +0x0C  flags[5]         - Module-specific flags
;
; Module State (seg_00C1 data area):
;   [0x0116] dialog_struct      - Dialog definition structure
;   [0x0119] dialog_text_off    - Offset of dialog text string
;   [0x011B] tandy_drive_flag   - Tandy drive present (0 or 1)
;   [0x011C] module_entries[]   - Array of module entries (17 bytes each)
;   [0x01C6] current_entry      - Current module entry buffer (17 bytes)
;   [0x01D1] drive_type_code    - Drive type code (0=none, 1-3)
;   [0x01D7] prguf_loaded       - PRGUF loaded flag
;   [0x01D8] cfg_path           - "X:\AUTOLOAD.CFG" (X replaced at runtime)
;   [0x01E8] comspec_key        - "COMSPEC=" search string
;   [0x01F1] desk_path          - "X:\DESK.EXE" (X replaced at runtime)
;   [0x0202] prguf_name         - "PRGUF" import name
;   [0x020C] dmguf_name         - "DMGUF" import name
;   [0x0224] prguf_name2        - "PRGUF" (for DMCSR load)
;   [0x022E] dmcsr_name         - "DMCSR" import name
;   [0x02D8] drive_status_word  - Current drive status bitmap
;   [0x02DA] entry_count        - Number of entries in module list
;   [0x02DC] drive_mask_lo      - Drive bitmask (low bits)
;   [0x02DE] drive_mask_hi      - Drive bitmask (high bits)
;   [0x02E0] drive_count        - Number of drives detected
;   [0x02E2] file_handle        - Open file handle for AUTOLOAD.CFG
;   [0x02E4] old_int15_off      - Saved INT 15h vector (offset)
;   [0x02E6] old_int15_seg      - Saved INT 15h vector (segment)
;   [0x02E8] int15_hooked       - INT 15h hook installed flag
;   [0x02E9] disk_swap_flag     - Disk swap in progress flag
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 11h - BIOS Equipment List
;   Returns AX with equipment flags, bits 7:6 = floppy drive count
;
; INT 15h/70xxh - Tandy Drive Status (Tandy-specific)
;   AH=70h, AL=00h, BX=3Fh - Get drive status
;   AH=70h, AL=01h          - Set drive status
;
; INT 21h/25h - Set interrupt vector (for INT 15h hook)
; INT 21h/30h - Get DOS version
; INT 21h/31h - TSR (terminate and stay resident)
; INT 21h/35h - Get interrupt vector (save INT 15h)
; INT 21h/4408h - IOCTL: check removable media
; INT 21h/51h - Get current PSP segment
;
; INT E0h - DM89 Host API
;   AH=01h - Register module
;   AH=02h, AL=06h - Load import by name
;   AH=02h, AL=07h - Unload import
;   AH=06h, AL=00h - Query host information
;   AH=06h, AL=01h - Get current directory
;   AH=06h, AL=03h - Call DMCSR function
;   AH=06h, AL=04h - Check file exists
;   AH=06h, AL=0Eh - Get import version
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Startup config engine code (3,088 bytes)
; seg_00C1: Dialog strings + module data (644 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/autoload.asm for complete byte-level listing]
