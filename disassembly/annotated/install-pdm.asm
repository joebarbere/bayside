; ========================================================================
; INSTALL.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987), Medium Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; INSTALL.PDM is the DeskMate hard disk installer module. It runs inside
; DESK.EXE as a hosted PDM application (launched via INSTALL.EXE chain
; loader which patches the module name from DESKTOP to INSTALL).
;
; The installer handles:
;   - Prompting for source/destination drives and directories
;   - Copying all DeskMate files from floppy disks to hard disk
;   - Creating the DMCONFIG directory structure
;   - Modifying AUTOEXEC.BAT to add DeskMate startup commands
;   - Installing printer drivers (separate printer selection dialog)
;   - Renaming PERSONAL.CAL to PERSONAL.CLN for calendar compatibility
;   - Handling single-diskette systems (drive A: only)
;   - Supporting multi-disk installation (DESKMATE_1 through DESKMATE_7)
;
; The module uses INT E0h services (AH=02h, 06h, 07h) for resource
; loading, file I/O mediated through DESK.EXE, and memory allocation.
; It also makes extensive direct DOS INT 21h calls for file operations,
; directory creation, disk space checking, and drive management.
;
; DM89 imports: none (self-contained installer)
; DM89 flags: 0x0000 (standard PDM module, no special flags)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 27,235 bytes
; Load image: 26,723 bytes (after header)
; DM89 entry point: 0431:0008 (MSC 5.x CRT startup)
; SS:SP = 1237:1800
;
; Segment Map (5 segments, 13 relocations):
;   seg_0000  0x04310 bytes  CODE   Installer application code
;   seg_0431  0x000B0 bytes  CODE   MSC 5.x CRT startup
;   seg_043C  0x00040 bytes  DATA   DGROUP fixup area (MSC CRT copyright)
;   seg_0440  0x0DDF0 bytes  DATA   Strings, file lists, dialog structures,
;                                   configuration buffers, error messages
;   seg_1237  0x01800 bytes  STACK  Stack segment
;
; Medium memory model: multiple code segments, DGROUP at 043C.
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Global Variables (selected):
;   [0x00D6]  g_videoMode         - Video adapter mode (0xD6 in DGROUP)
;   [0x00D8]  g_diskCount         - Number of install disks detected
;   [0x00E0]  g_destDriveStr      - Destination drive+path string
;   [0x00E2]  g_printerType       - Printer driver type code
;   [0x00EF]  g_needsAutoexecMod  - Flag: AUTOEXEC.BAT needs modification
;   [0x00F0]  g_isNetworkDrive    - Flag: destination is network drive
;   [0x00F1]  g_hasFloppyDrive    - Flag: system has floppy drive
;   [0x010A]  g_showFinalDialog   - Flag: show final install-complete dialog
;   [0x0316]  g_dialogResult1     - Dialog result storage (word)
;   [0x031F]  g_dialogResult2     - Dialog result storage (word)
;   [0x0328]  g_pathBufferPtr     - Pointer to current install path buffer
;   [0x0366]  g_dialogStruct1     - Dialog definition structure (main)
;   [0x037C]  g_dialogParams      - Dialog parameter block
;   [0x037D]  g_dialogMsgPtr      - Pointer to dialog message string
;   [0x037F]  g_dialogPathPtr     - Pointer to dialog pathname string
;   [0x0382]  g_diskChangePrompt  - Disk change prompt mode (1=active)
;   [0x0386]  g_installBufferEnd  - End pointer for install data buffer
;   [0x0445]  g_srcPathPtr        - Source path string pointer
;   [0x0450]  g_destPathPtr       - Destination path string pointer
;   [0x045D]  g_copyDirection     - Copy direction flag (2=src->dest)
;   [0x0452]  g_dialogStruct2     - Secondary dialog structure
;   [0x0473]  g_installDirPtr     - Pointer to installation directory string
;   [0x0476]  g_dialogStruct3     - Tertiary dialog structure
;   [0x0F4D]  g_printerInstalled  - Flag: printer has been installed
;   [0x0F50]  g_hasMultiDisk      - Flag: multi-disk install detected
;   [0x0F51]  g_installComplete   - Flag: installation completed
;   [0x0FAD]  g_equipmentWord     - Equipment list word (INT 11h result)
;   [0x0FAF]  g_equipmentFlags    - Equipment flags (extended)
;   [0x0FB1]  g_equipmentMask     - Equipment mask for drive detection
;   [0x1D1C]  g_resCallbackOff    - PRGUF resource callback offset
;   [0x1D1E]  g_resCallbackSeg    - PRGUF resource callback segment
;   [0x1D20]  g_resPRGUF_name     - "PRGUF" resource name string
;   [0x1D26]  g_resAltCallbackOff - Alternate resource callback offset
;   [0x1D28]  g_resAltCallbackSeg - Alternate resource callback segment
;   [0x1D2A]  g_resDMGUF_name     - "DMGUF" resource name string (at 0x1D2A)
;   [0x1D30]  g_resActiveModule   - Which resource module is active (0/1)
;   [0x1D31]  g_findFirstResult   - Result of last FindFirst/FindNext
;   [0x1D3A]  g_deskExeName       - "DESK.EXE" comparison buffer
;   [0x1D42]  g_deskCallbackPtr   - Far pointer to DESK.EXE callback
;   [0x1D46]  g_resDMCSR_name     - "DMCSR" resource name (cursor)
;   [0x3732]  g_installDrive      - Install drive letter (e.g., 'C')
;   [0x3733]  g_installDriveColon - ':' after drive letter
;   [0x3734]  g_installDriveSlash - '\' after colon
;   [0x3735]  g_installSubdir     - Subdirectory name (e.g., "DESKMATE")
;   [0x3802]  g_dtaBuffer         - Disk Transfer Area buffer
;   [0x3882]  g_dtaBufferMode     - DTA buffer mode flag
;   [0x3886]  g_installBufPtr     - Current position in install buffer
;   [0x38C4]  g_pathBuffer        - General-purpose path buffer
;   [0x3944]  g_defaultDrive      - Default drive letter
;   [0x3946]  g_installType       - Installation type (1=single floppy)
;   [0x398C]  g_progressCallback  - Pointer to progress bar callback
;   [0x5C96]  g_dmconfigPath      - DMCONFIG directory path buffer
;   [0x5DA3]  g_destDriveLetter   - Destination drive letter (uppercase)
;   [0x5FA8]  g_installDataBuf    - Start of install data buffer (large)
;   [0xDFA7]  g_hasHardDisk       - Flag: system has hard disk
;   [0xDFA8]  g_currentDrive      - Current drive letter
;
; File Copy Structure (in sub_005BC, stack frame ~0x232 bytes):
;   [bp-0x8e]  srcPath[142]       - Source file path buffer
;   [bp-0xa6]  destDrive[2]       - Destination drive letter
;   [bp-0xa8]  bytesRead          - Bytes read from install buffer
;   [bp-0xfe]  alternateFlag      - Flag: using alternate copy path
;   [bp-0x11c] maxBlockSize       - Maximum read block size (0x7FFF)
;   [bp-0x12a] installPath[298]   - Full installation path buffer
;   [bp-0x16c] srcPathBuf         - Source path buffer for dialog
;   [bp-0x1d6] destPath[214]      - Destination path buffer
;   [bp-0x226] destPathBuf        - Destination path for dialog
;   [bp-0x228] diskIndex          - Current source disk index
;   [bp-0x22a] copyResult         - Copy operation result code
;   [bp-0x22c] copyActive         - Flag: file copy in progress
;   [bp-0x22e] fileHandle         - DOS file handle for current file
;   [bp-0x230] destFileOpen       - Flag: destination file is open
;   [bp-0x232] destFileHandle     - Destination DOS file handle
;
; DeskMate Resource File List (strings at ~0x6200-0x6970):
;   Complete list of all DeskMate files to be installed, organized
;   as null-terminated strings. Includes .PDM, .ACC, .RES, .EXE,
;   .CFG, .HLP, .FF1, .RFD, .PCL, .MOD, .LBL files.
;   Notable entries: AUTOLOAD.RES, CALENDAR.PDM, D87.RES, DESK.EXE,
;   DESKTOP.PDM, DESKTOP.EXE, all DMxx.RES/ACC files, INSTALL.EXE,
;   INSTALL.PDM, PRGUF.RES, SPELL.RES, TEXT.PDM, WRKSHEET.PDM, etc.
;
; Dialog Message Strings (at ~0x5575-0x5960):
;   "DeskMate Hard Disk Installation"
;   "DeskMate Printer Installation"
;   "Installation Directory"
;   "DMCONFIG Disk Drive"
;   "Drive:"
;   "Pathname:"
;   "AUTOEXEC.BAT"
;   "CANCEL"
;   "Copying"
;   "Installation on a single diskette system must have the drive set to A."
;   "Your PERSONAL.CAL file was renamed to PERSONAL.CLN..."
;   "Searching files."
;   "Install Printer"
;   "You cannot install DeskMate while task switching."
;   "Cannot create the directory as specified."
;   "You cannot specify the ROM as the drive."
;   "You must specify a pathname."
;   "Disk is full. Cannot complete installation."
;   "Insufficient free space on this disk."
;   "Cannot find or create the DMCONFIG directory"
;   "Insufficient memory. Remove all non-DeskMate software..."
;   "Not a valid disk drive."
;   "Disk Needed"
;   "Please insert the master disk,"
;
; Disk Label Strings:
;   "DESKMATE_1" through "DESKMATE_7" -- volume labels for multi-disk sets
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Installer Application Functions (seg_0000) ---
;
; Address   Name                          Size  Description
; -------   ----                          ----  -----------
; 0000:0010 install_main                  219   _main() - entry, validate config, run installer, cleanup
; 0000:00EB install_initEnvironment       498   Initialize paths, detect drives, prompt for source disk
; 0000:02DD install_writeConfigAndCleanup 151   Write install config to disk, restore drive settings
; 0000:0374 install_parseCommandLine      188   Parse command-line for install directory override
; 0000:0430 install_parseVideoConfig       50   Parse video adapter configuration
; 0000:0462 install_parseAutoexecConfig   129   Parse AUTOEXEC.BAT for existing DeskMate entries
; 0000:04E3 install_checkDeskExePresent    65   Check if DESK.EXE exists in path (validates install)
; 0000:0524 install_insertDataBlock        48   Insert a data block into the install buffer
; 0000:0554 install_removeDataBlock        39   Remove a data block from the install buffer
; 0000:057B install_searchBuffer           65   Search install buffer for a string match
; 0000:05BC install_copyFiles            1494   Main file copy engine (src disk -> dest directory)
; 0000:0B92 install_createDirectory       108   Create directory, prompt if needed
; 0000:0BFE install_confirmOverwrite      269   Confirm file overwrite dialog
; 0000:0D0B install_stripFilename          53   Strip filename from path (keep directory)
; 0000:0D40 install_callDeskExe           204   Call DESK.EXE via INT E0h (stack-switch wrapper)
; 0000:0E0C install_searchEnvironment      83   Search DOS environment for a variable
; 0000:0E5F install_matchEnvString         99   Match environment string and extract value
; 0000:0EC2 install_drawProgressBar       136   Draw progress bar during file copy
; 0000:0F4A install_drawCopyRect           19   Draw copy status rectangle
; 0000:0F5D install_resetScreenPosition    53   Reset screen cursor/position to origin
; 0000:0F92 install_mainInstallDialog     636   Main installation dialog handler (drive/dir prompts)
; 0000:120E install_findFirstHardDisk      38   Find first available hard disk drive (C: and up)
; 0000:1234 install_showDirEntryDialog     54   Show directory entry dialog (pathname input)
; 0000:126A install_promptDMConfig        146   Prompt for DMCONFIG directory location
; 0000:12FC install_validateInstallDir    155   Validate installation directory (check drive, create dir)
; 0000:1397 install_runDialog             261   Run a dialog form and wait for user response
; 0000:149C install_validateDMConfigDir   121   Validate DMCONFIG directory exists or can be created
; 0000:1515 install_checkDriveValid        62   Check if specified drive is valid (call INT E0h)
; 0000:1553 install_copyConfigFiles       274   Copy configuration files to destination
; 0000:1665 install_copyPCLFiles          442   Copy .PCL printer files
; 0000:181F install_buildSourcePath       149   Build full source path from drive+subdirectory
; 0000:18B4 install_performInstallation   837   Main file installation loop (iterate file list, copy)
; 0000:1BF9 install_buildDiskLabel        144   Build disk volume label string for multi-disk prompt
; 0000:1C89 install_processDiskFiles      146   Process files from current source disk
; 0000:1D1B install_formatPathWithLabel   122   Format path with disk label for display
; 0000:1D95 install_buildFileList         228   Build list of files to install
; 0000:1E79 install_saveWindowState        22   Save current window state
; 0000:1E8F install_restoreWindowState     22   Restore saved window state
; 0000:1EA5 install_checkDriveReady        40   Check if drive is ready (via INT E0h)
; 0000:1ECD install_parsePathname          96   Parse a pathname into drive + directory components
; 0000:1F2D install_checkDiskFreeSpace    200   Check free disk space on destination drive
; 0000:1FF5 install_autoexecModify        146   Modify AUTOEXEC.BAT to add DeskMate startup
; 0000:2087 install_restoreAndSave         43   Restore window state and save config
; 0000:20B2 install_exitInstaller          19   Exit installer (cleanup and terminate)
; 0000:20C5 install_handleCritError        50   Critical error handler
; 0000:20F7 install_extractVolumeName      35   Extract volume name from path
; 0000:211A install_buildFullPath          47   Build full path from components
; 0000:2149 install_resetCursorAndScreen   39   Reset cursor position and screen mode
; 0000:2170 install_setDialogTitle         20   Set dialog title bar text
; 0000:2184 install_createDirectory2       45   Create directory (DOS INT 21h/39h wrapper)
; 0000:21B1 install_findNextFile           33   Find next file (DOS INT 21h/4Fh wrapper)
; 0000:21D2 install_getDiskInfo            98   Get disk information (drive, free space, etc.)
; 0000:2234 install_getDTAAddress          28   Get DTA address (DOS INT 21h/2Fh wrapper)
; 0000:2250 install_setDTAAddress          20   Set DTA address (DOS INT 21h/1Ah wrapper)
; 0000:2264 install_createSubdirectory     40   Create subdirectory under install path
; 0000:228C install_getFileDateTime        68   Get/set file date/time (DOS INT 21h/57h wrapper)
; 0000:22D0 install_allocateMemory         26   Allocate memory block (DOS INT 21h/48h wrapper)
; 0000:22EA install_freeMemory             22   Free memory block (DOS INT 21h/49h wrapper)
; 0000:2300 install_getExtendedError       55   Get extended error info (DOS INT 21h/59h wrapper)
; 0000:2337 install_getDiskFreeSpace       22   Get disk free space (DOS INT 21h/36h wrapper)
; 0000:234D install_calcFreeSpace          43   Calculate total free space on a drive
; 0000:2378 install_seekFilePosition       42   Seek to file position (DOS INT 21h/42h?)
; 0000:23A2 install_checkRemovableDrive    52   Check if drive is removable (DOS IOCTL)
; 0000:23D6 install_swapDriveMedia         54   Swap/check drive media (DOS IOCTL)
; 0000:240C install_getEquipmentList       27   Get equipment list word (INT 11h)
; 0000:2427 install_readEquipmentByte      27   Read equipment byte from DeskMate context
; 0000:2442 install_writeEquipmentByte     46   Write equipment byte to DeskMate context
; 0000:2470 install_readConfigByte         20   Read byte from DeskMate configuration area
; 0000:2484 install_findFirstFile         105   Find first matching file (DOS INT 21h/4Eh wrapper)
; 0000:24ED install_checkDOSVersion        89   Check DOS version and detect drive capabilities
; 0000:2546 install_getCurrentDrive        15   Get current default drive (DOS INT 21h/19h)
; 0000:2555 install_setCurrentDrive        28   Set current drive (DOS INT 21h/0Eh)
; 0000:2571 install_checkDriveIOCTL        30   Check drive via IOCTL (INT 21h/44h/0Eh)
; 0000:258F install_restoreDrive           13   Restore saved drive setting
; 0000:259C install_initDriveSystem        83   Initialize drive detection system
; 0000:25EF install_saveDriveState         10   Save current drive state
; 0000:25F9 install_detectDrives           72   Detect available drives (floppy/hard)
; 0000:2641 install_checkDriveAvailable    19   Check if a specific drive is available
; 0000:2654 install_releaseResources        5   Release allocated resources (stub)
; 0000:2659 install_queryDriveCount        15   Query number of available drives
; 0000:2668 install_displayMessage        101   Display a message in the status area
; 0000:26CD install_displayAndWait         71   Display message and wait for acknowledgment
; 0000:2714 install_buildPrinterPath      186   Build printer driver installation path
; 0000:27CE install_readDiskLabel          36   Read disk volume label
; 0000:27F2 install_buildLabelPath         54   Build path for disk label verification
; 0000:2828 install_verifyDiskLabel        31   Verify disk label matches expected value
; 0000:2847 install_promptForDisk          77   Prompt user to insert specific disk
; 0000:2894 install_loadFromDisk           72   Load files from a specific source disk
; 0000:28DC install_performCopy           293   Perform file copy with progress display
; 0000:2A01 install_printerInstallMenu    457   Printer installation menu handler
; 0000:2BCA install_copyPrinterDriver      87   Copy a single printer driver file
; 0000:2C21 install_printerSelectDialog   329   Printer selection dialog
; 0000:2D6A install_processFileEntry      109   Process a single file entry from install list
; 0000:2DD7 install_setupFileCopy         114   Set up file copy parameters
; 0000:2E49 install_checkFileExists       128   Check if destination file already exists
; 0000:2EC9 install_openFileForCopy       155   Open source file for copying
; 0000:2F64 install_copyFileData          595   Copy file data blocks (read/write loop)
; 0000:31B7 install_getPathLength          59   Get string length of a path
; 0000:31F2 install_clearProgressArea      61   Clear progress bar display area
; 0000:322F install_drawProgressFilled     89   Draw filled portion of progress bar
; 0000:3288 install_updateProgressBar     153   Update progress bar position
; 0000:3321 install_buildShortPath         99   Build shortened path for display
; 0000:3384 install_buildDisplayPath      156   Build display path (truncated to fit)
; 0000:3420 install_openFileRead           26   Open file for reading (dmguf wrapper)
; 0000:343A install_openFileWrite          30   Open file for writing (dmguf wrapper)
; 0000:3458 install_readFile              160   Read file data block (dmguf wrapper)
; 0000:34F8 install_writeFile             383   Write file data block (with retry on error)
; 0000:3677 install_dispatchCallback       15   Dispatch to DMGUF callback via indirect call
;
; --- DMGUF / PRGUF Import Thunks (seg_0000, 0x3686-0x3E9D) ---
;
; 0000:3686 install_initInterruptHandler  196   Set up INT 00h handler (divide error)
; 0000:374A install_exitHandler            23   Exit/cleanup handler (restore INT vectors)
; 0000:3761 install_setupCritErrHandler    69   Set up critical error (INT 24h) handler
; 0000:37A6 install_exitWithCode           25   Exit with return code (INT 21h/4Ch)
; 0000:37BF install_callIndirect           15   Call through indirect function pointer
; 0000:37CE install_saveRegisters          20   Save register state
; 0000:37E2 install_criticalErrorHandler  104   Critical error handler (retry/abort logic)
; 0000:384A install_dispatchIOCTL          38   Dispatch IOCTL call
; 0000:3870 install_closeAndDispatch       34   Close file handle and dispatch
; 0000:3892 install_formatOutput          398   Formatted output (printf-like) engine
; 0000:3A20 install_writeStderr            43   Write string to stderr (handle 2)
; 0000:3A4B install_writeString            41   Write null-terminated string
; 0000:3A74 install_hexFormat              66   Format value as hex string
;
; --- C Runtime Library Functions (seg_0000, 0x3AB6-0x3DC5) ---
;
; 0000:3AB6 _strcat                        28   String concatenate
; 0000:3AD2 _strcmp_n                       36   String compare (n bytes)
; 0000:3AF6 _strcpy                        50   String copy
; 0000:3B28 _strcmp                         44   String compare (full)
; 0000:3B54 _strlen                        28   String length
; 0000:3B70 _strncpy                       58   String copy (n bytes)
; 0000:3BAA _toupper                       26   Convert character to uppercase
; 0000:3BC4 _fopen_internal                72   Internal file open
; 0000:3C0C _fclose_internal               66   Internal file close
; 0000:3C4E _fwrite_internal               34   Internal file write
; 0000:3C70 _memcpy                        90   Memory copy
; 0000:3CCA _memset                        92   Memory set (fill)
; 0000:3D26 _memmove                       72   Memory move (overlap-safe)
; 0000:3D6E _atoi                          44   ASCII to integer
; 0000:3D9A _itoa                          44   Integer to ASCII
; 0000:3DC6 _itoa_internal                  6   Integer to ASCII (internal)
; 0000:3DCC _numformat                    144   Number formatting engine
;
; --- DeskMate DMGUF/PRGUF Dispatch Stubs (seg_0000, 0x3EC6-0x3FCE) ---
; These are indirect-call thunks that dispatch to loaded PRGUF/DMGUF
; resource modules via far call through [0x1D1C] or [0x1D26].
; Each stub loads AX with a function code and jumps to the dispatcher.
;
; 0000:3EC6 dmguf_dispatch_main           ---   Main DMGUF dispatch (routes AX to callback)
; 0000:3F0A dmguf_dispatch_alt            ---   Alternate DMGUF dispatch (via [0x1D26])
; 0000:3F47 dmguf_closeFile                 6   DMGUF func 01: Close file handle
; 0000:3F4D dmguf_openFileRead              6   DMGUF func 02: Open file for reading
; 0000:3F53 dmguf_seekFile                  6   DMGUF func 04: Seek in file
; 0000:3F59 dmguf_createFile                6   DMGUF func 05: Create/open file for writing
; 0000:3F5F dmguf_readFile                  6   DMGUF func 06: Read data from file
; 0000:3F65 dmguf_writeFile                 6   DMGUF func 07: Write data to file
; 0000:3F6B dmguf_getFileOpen               6   DMGUF func 0B: Get/check file open status
; 0000:3F71 dmguf_getFileSize               6   DMGUF func 0C: Get file size
; 0000:3F77 dmguf_getFileAttrib             6   DMGUF func 0E: Get file attributes
; 0000:3F7D dmguf_setFileAttrib             6   DMGUF func 11: Set file attributes
; 0000:3F83 dmguf_getCurrentDir             6   DMGUF func 12: Get current directory
; 0000:3F89 dmguf_deleteFile                6   DMGUF func 13: Delete file
; 0000:3F8F dmguf_renameFile                6   DMGUF func 14: Rename file
; 0000:3F95 dmguf_setCurrentDir             6   DMGUF func 15: Set current directory
; 0000:3F9B dmguf_setDrive                  6   DMGUF func 16: Set current drive
; 0000:3FA1 dmguf_findFirstFile             6   DMGUF func 19: Find first matching file
; 0000:3FA7 dmguf_showErrorDlg_1C          6   DMGUF func 1C: Show error dialog (via alt dispatch)
; 0000:3FAD dmguf_showErrorDlg_1D          6   DMGUF func 1D: Show error dialog (via alt dispatch)
; 0000:3FB3 dmguf_displayString             6   DMGUF func 24: Display string in status area
; 0000:3FB9 dmguf_fileOperation_AE         6   DMGUF func AE: File operation (copy/verify)
; 0000:3FBF dmguf_fileOperation_AF         6   DMGUF func AF: File operation (via alt dispatch)
; 0000:3FC5 dmguf_setWindowMode            6   DMGUF func 37: Set window display mode
; 0000:3FCB dmguf_fileOperation_BF         6   DMGUF func BF: File operation (via alt dispatch)
;
; --- DeskMate INT E0h Thunks (seg_0000, 0x3FD1-0x4082) ---
;
; 0000:3FD1 install_resDispatchThunk     104   Resource dispatch thunk (INT E0h wrapper)
; 0000:4039 inte0_setupDTAContext           6   INT E0h: Set DTA context
; 0000:403F inte0_getDiskCount              6   INT E0h: Get number of disks
; 0000:4045 inte0_getEquipment              6   INT E0h: Get equipment info
; 0000:404B inte0_getConfigValue            6   INT E0h: Get configuration value
; 0000:4051 inte0_checkDirectory            6   INT E0h: Check/validate directory
; 0000:4057 inte0_setScreenMode             6   INT E0h: Set screen mode
; 0000:405D inte0_loadResource             25   INT E0h AH=02h/06h: Load resource module
; 0000:4076 inte0_unloadResource           15   INT E0h AH=02h/07h: Unload resource module
; 0000:4085 inte0_initResources             7   Initialize resource subsystem
; 0000:408C inte0_cleanupResources          7   Cleanup resource subsystem
; 0000:4093 inte0_resourceDispatch         40   Resource function dispatch (INT E0h AH=02h/08h)
; 0000:40BB inte0_refreshScreen             6   INT E0h: Refresh/repaint screen
; 0000:40C1 inte0_beginPaint                6   INT E0h: Begin paint operation
; 0000:40C7 inte0_dialogInit                6   INT E0h: Initialize dialog
; 0000:40CD inte0_dialogSetField            6   INT E0h: Set dialog field
; 0000:40D3 inte0_drawBox                   6   INT E0h: Draw box/rectangle
; 0000:40D9 inte0_setCursorPos              6   INT E0h: Set cursor position
; 0000:40DF inte0_setViewport               6   INT E0h: Set viewport/clipping region
; 0000:40E5 inte0_drawHLine                 6   INT E0h: Draw horizontal line
; 0000:40EB inte0_drawVLine                 6   INT E0h: Draw vertical line
; 0000:40F1 inte0_drawText                  6   INT E0h: Draw text string
; 0000:40F7 inte0_fillRect                  6   INT E0h: Fill rectangle
; 0000:40FD inte0_drawBitmap                6   INT E0h: Draw bitmap/icon
; 0000:4103 inte0_endPaint                  6   INT E0h: End paint operation
; 0000:4109 inte0_setTextColor              6   INT E0h: Set text color/attribute
; 0000:410F inte0_setFillPattern            6   INT E0h: Set fill pattern
; 0000:4115 inte0_getTextExtent             6   INT E0h: Get text extent/width
; 0000:411B inte0_dialogShow                6   INT E0h: Show dialog
; 0000:4121 inte0_dialogHide                6   INT E0h: Hide/close dialog
; 0000:4127 inte0_setStatusBar              6   INT E0h: Set status bar text
; 0000:412D inte0_showMessageBox            6   INT E0h: Show message box dialog
; 0000:4133 inte0_getDialogResult           6   INT E0h: Get dialog result
; 0000:4139 inte0_dialogReset               6   INT E0h: Reset dialog state
; 0000:413F inte0_registerCallback          6   INT E0h: Register event callback
; 0000:4145 inte0_allocateMemory           48   INT E0h AH=07h: Allocate memory
; 0000:4175 inte0_timerSetup               53   INT E0h: Timer/timeout setup
;
; --- Miscellaneous Utility Functions ---
;
; 0000:41AA install_stub1                  14   Small stub function
; 0000:41B8 install_stub2                  16   Small stub function
; 0000:41C8 inte0_stub1                     6   INT E0h stub
; 0000:41CE inte0_stub2                     6   INT E0h stub
; 0000:41D4 inte0_stub3                     6   INT E0h stub
; 0000:41DA inte0_stub4                     6   INT E0h stub
; 0000:41E0 install_parseConfigLine       269   Parse a line from configuration file
; 0000:42ED install_deskCallback           43   DESK.EXE callback entry point
;
; --- MSC 5.x CRT Startup (seg_0431) ---
;
; 0431:0008 _crt_start                   2438   CRT startup: init SS:SP, BSS, call _main
; 0431:09A6 _crt_exitCleanup             7109   CRT exit: close handles, run atexit, INT 21h/4Ch
;
; ========================================================================
; INTERRUPT CALLS
; ========================================================================
;
; INT E0h (DeskMate API):
;   AX=0206h  Load resource module (PRGUF, DMGUF, DMCSR)
;   AX=0207h  Unload resource module
;   AX=0208h  Call resource function (PRGUF, DMGUF)
;   AX=0600h  Get event / open file (DeskMate-mediated file I/O)
;   AX=060Eh  Dispatch event / close file
;   AX=0603h  Write file / resource dispatch
;   AX=0700h  Allocate memory / yield
;
; INT 21h (DOS API):
;   AH=0Eh   Set default drive
;   AH=11h   Find first (FCB)
;   AH=19h   Get current drive
;   AH=1Ah   Set DTA address
;   AH=25h   Set interrupt vector
;   AH=2Ch   Get system time (for random seed)
;   AH=2Fh   Get DTA address
;   AH=30h   Get DOS version
;   AH=35h   Get interrupt vector
;   AH=36h   Get disk free space
;   AH=39h   Create directory (mkdir)
;   AH=3Eh   Close file handle
;   AH=40h   Write to file/device
;   AH=44h   IOCTL (subfunctions 00h, 08h, 0Eh, 0Fh)
;   AH=48h   Allocate memory block
;   AH=49h   Free memory block
;   AH=4Ah   Resize memory block
;   AH=4Ch   Terminate process
;   AH=4Eh   Find first matching file
;   AH=4Fh   Find next matching file
;   AH=57h   Get/set file date and time
;   AH=59h   Get extended error information
;
; INT 11h:  Get equipment list (BIOS)
; INT 13h:  Disk services (BIOS)
; INT 15h:  Extended services (BIOS)
; INT 20h:  Program terminate (DOS)
; INT ABh:  Unknown (possibly Tandy-specific)
;
; ========================================================================
; CODE
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (17,168 bytes, file 0x0200-0x4510)
; CODE: Installer application code
; ------------------------------------------------------------------------
seg_0000:

  ; First 16 bytes are zero-filled (DM89 module header padding)
  0000:0000  db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ========================================================================
; install_main
; Address: 0000:0010
; Parameters: none (called from CRT _main)
; Returns: AX = 0 on success, -1 on failure
; Description: Main installer entry point. Initializes the install
;   environment, parses command-line arguments, detects drives, sets up
;   dialogs, runs the installation file copy, and then modifies
;   AUTOEXEC.BAT if needed. On failure, returns -1 immediately.
;
; Call chain:
;   install_initEnvironment -> detect drives, prompt for source
;   install_parseCommandLine -> parse /D= directory override
;   install_parseVideoConfig -> detect video adapter
;   install_parseAutoexecConfig -> check existing AUTOEXEC.BAT
;   install_checkDeskExePresent -> verify DESK.EXE on source
;   install_readConfigByte -> read DeskMate config settings
;   install_searchBuffer -> search for video/printer config strings
;   install_writeConfigAndCleanup -> finalize install
; ========================================================================
install_main:                                    ; 0000:0010
  0000:0010  55             push     bp
  0000:0011  8bec           mov      bp, sp
  0000:0013  81ec8200       sub      sp, 0x82           ; Local: 130 bytes
  0000:0017  56             push     si
  0000:0018  e8d000         call     install_initEnvironment  ; Initialize paths, drives, source disk
  0000:001B  0bc0           or       ax, ax
  0000:001D  7406           je       .init_ok
  0000:001F  b8ffff         mov      ax, 0xffff          ; Return -1 on init failure
  0000:0022  e9c100         jmp      .exit
.init_ok:                                        ; 0000:0025
  ; Set up local buffer for install directory path
  0000:0025  8bf5           mov      si, bp
  0000:0027  81ee8000       sub      si, 0x80            ; SI -> local 128-byte path buffer
  0000:002B  89367304       mov      word ptr [g_installDirPtr], si
  ; Copy default install subdirectory name to buffer
  0000:002F  b89d15         mov      ax, 0x159d          ; -> "DESKMATE" string (in data seg)
  0000:0032  50             push     ax
  0000:0033  56             push     si
  0000:0034  e8bf3a         call     _strcpy
  0000:0037  83c404         add      sp, 4
  ; Append drive letter and colon separator
  0000:003A  56             push     si
  0000:003B  e8163b         call     _strlen
  0000:003E  83c402         add      sp, 2
  0000:0041  03f0           add      si, ax              ; SI -> end of string
  0000:0043  a03237         mov      al, byte ptr [g_installDrive]
  0000:0046  8804           mov      byte ptr [si], al   ; Append drive letter
  0000:0048  46             inc      si
  0000:0049  c60400         mov      byte ptr [si], 0    ; Null terminate
  ; Initialize screen and set up dialog structures
  0000:004C  e87240         call     inte0_beginPaint
  0000:004F  b87604         mov      ax, 0x476           ; -> dialog structure 3
  0000:0052  50             push     ax
  0000:0053  e8d140         call     inte0_setStatusBar
  0000:0056  83c402         add      sp, 2
  0000:0059  e85f40         call     inte0_refreshScreen
  ; Allocate memory for install buffer
  0000:005C  b80006         mov      ax, 0x600           ; Request 0x600 paragraphs
  0000:005F  50             push     ax
  0000:0060  e8e240         call     inte0_allocateMemory
  0000:0063  83c402         add      sp, 2
  ; Parse command-line and configuration
  0000:0066  e8c703         call     install_parseVideoConfig
  0000:0069  e80803         call     install_parseCommandLine
  0000:006C  e8f303         call     install_parseAutoexecConfig
  0000:006F  e87104         call     install_checkDeskExePresent
  ; Read DeskMate configuration to detect multi-disk install
  0000:0072  e8fb23         call     install_readConfigByte
  0000:0075  0bc0           or       ax, ax
  0000:0077  7468           je       .skip_config         ; No config data found
  ; Store disk count and printer type from config
  0000:0079  e8f423         call     install_readConfigByte
  0000:007C  a2d800         mov      byte ptr [g_diskCount], al
  0000:007F  e8ee23         call     install_readConfigByte
  0000:0082  a2e200         mov      byte ptr [g_printerType], al
  ; Search install buffer for video adapter config (tag 0xD6)
  0000:0085  b8a85f         mov      ax, 0x5fa8          ; g_installDataBuf
  0000:0088  50             push     ax
  0000:0089  b8d600         mov      ax, 0xd6            ; Tag: video mode
  0000:008C  50             push     ax
  0000:008D  e8eb04         call     install_searchBuffer
  0000:0090  83c404         add      sp, 4
  0000:0093  0bc0           or       ax, ax
  0000:0095  741c           je       .no_video_config
  ; Found video config: extract and insert into buffer
  0000:0097  b80800         mov      ax, 8               ; Block size = 8 bytes
  0000:009A  50             push     ax
  0000:009B  b8a85f         mov      ax, 0x5fa8
  0000:009E  50             push     ax
  0000:009F  b8d600         mov      ax, 0xd6
  0000:00A2  50             push     ax
  0000:00A3  e8d504         call     install_searchBuffer
  0000:00A6  83c404         add      sp, 4
  0000:00A9  2d0700         sub      ax, 7               ; Adjust offset
  0000:00AC  50             push     ax
  0000:00AD  e8a404         call     install_removeDataBlock
  0000:00B0  83c404         add      sp, 4
.no_video_config:                                ; 0000:00B3
  ; Search for printer config (tag 0xE0)
  0000:00B3  b8a85f         mov      ax, 0x5fa8
  0000:00B6  50             push     ax
  0000:00B7  b8e000         mov      ax, 0xe0            ; Tag: printer config
  0000:00BA  50             push     ax
  0000:00BB  e8bd04         call     install_searchBuffer
  0000:00BE  83c404         add      sp, 4
  0000:00C1  0bc0           or       ax, ax
  0000:00C3  741c           je       .skip_config
  ; Extract printer config
  0000:00C5  b80b00         mov      ax, 0xb             ; Block size = 11 bytes
  0000:00C8  50             push     ax
  0000:00C9  b8a85f         mov      ax, 0x5fa8
  0000:00CC  50             push     ax
  0000:00CD  b8e000         mov      ax, 0xe0
  0000:00D0  50             push     ax
  0000:00D1  e8a704         call     install_searchBuffer
  0000:00D4  83c404         add      sp, 4
  0000:00D7  2d0900         sub      ax, 9
  0000:00DA  50             push     ax
  0000:00DB  e87604         call     install_removeDataBlock
  0000:00DE  83c404         add      sp, 4
.skip_config:                                    ; 0000:00E1
  ; Write the configuration and cleanup
  0000:00E1  e8f901         call     install_writeConfigAndCleanup
  0000:00E4  2bc0           sub      ax, ax              ; Return 0 (success)
.exit:                                           ; 0000:00E6
  0000:00E6  5e             pop      si
  0000:00E7  8be5           mov      sp, bp
  0000:00E9  5d             pop      bp
  0000:00EA  c3             ret

; ========================================================================
; install_initEnvironment
; Address: 0000:00EB
; Parameters: none
; Returns: AX = 0 on success, -1 on failure
; Description: Initializes the installation environment:
;   - Detects the first available hard disk drive (C: or higher)
;   - Builds the default installation path (e.g., "C:\DESKMATE")
;   - Checks if the system has a hard disk and floppy
;   - Prompts for source disk location (floppy or environment PATH)
;   - Reads INSTALL.CFG from the source media
;   - Appends EOF marker (0x1A) to install data buffer
;   Stack frame: 0x12A bytes local variables
; ========================================================================
install_initEnvironment:                         ; 0000:00EB
  0000:00EB  55             push     bp
  0000:00EC  8bec           mov      bp, sp
  0000:00EE  81ec2a01       sub      sp, 0x12a
  0000:00F2  57             push     di
  0000:00F3  56             push     si
  ; Initialize local state
  0000:00F4  c78658ff0000   mov      word ptr [bp - 0xa8], 0    ; bytesRead = 0
  0000:00FA  c746daffff     mov      word ptr [bp - 0x26], 0xffff  ; diskLabel = -1 (unset)
  ; Find first hard disk drive (starting at C:)
  0000:00FF  e80c11         call     install_findFirstHardDisk
  0000:0102  a23237         mov      byte ptr [g_installDrive], al  ; Save drive letter
  ; Build path prefix: "C:\"
  0000:0105  c60633373a     mov      byte ptr [g_installDriveColon], 0x3a  ; ':'
  0000:010A  c60634375c     mov      byte ptr [g_installDriveSlash], 0x5c  ; '\'
  ; Copy default subdirectory name "DESKMATE" to install subdir buffer
  0000:010F  b86110         mov      ax, 0x1061          ; -> "DESKMATE" (in data seg, offset varies)
  0000:0112  50             push     ax
  0000:0113  b83537         mov      ax, 0x3735          ; g_installSubdir
  0000:0116  50             push     ax
  0000:0117  e8dc39         call     _strcpy
  0000:011A  83c404         add      sp, 4
  ; Build full install path into local buffer: "C:\DESKMATE"
  0000:011D  b83237         mov      ax, 0x3732          ; g_installDrive ("C:\")
  0000:0120  50             push     ax
  0000:0121  8d86d6fe       lea      ax, [bp - 0x12a]    ; Local path buffer
  0000:0125  50             push     ax
  0000:0126  e8cd39         call     _strcpy
  0000:0129  83c404         add      sp, 4
  ; Check if system has a hard disk
  0000:012C  803ea7df00     cmp      byte ptr [g_hasHardDisk], 0
  0000:0131  745c           je       .no_hard_disk
  ; Check if system has a floppy drive
  0000:0133  803ef10000     cmp      byte ptr [g_hasFloppyDrive], 0
  0000:0138  7455           je       .no_hard_disk
  ; System has both hard disk and floppy -- check if floppy contains install disk
  0000:013A  ff36ad0f       push     word ptr [g_equipmentWord]
  0000:013E  e8e622         call     install_readEquipmentByte
  0000:0141  83c402         add      sp, 2
  0000:0144  8506b10f       test     word ptr [g_equipmentMask], ax
  0000:0148  7503           jne      .floppy_ok
  0000:014A  e98f00         jmp      .try_environment
.floppy_ok:                                      ; 0000:014D
  ; Set default source drive to A:
  0000:014D  b041           mov      al, 0x41            ; 'A'
  0000:014F  8886d6fe       mov      byte ptr [bp - 0x12a], al
  0000:0153  a23237         mov      byte ptr [g_installDrive], al
  ; Prompt user to insert the install disk
  0000:0156  b83e01         mov      ax, 0x13e           ; Dialog ID for disk prompt
  0000:0159  50             push     ax
  0000:015A  e8d03f         call     inte0_showMessageBox
  0000:015D  83c402         add      sp, 2
.retry_floppy:                                   ; 0000:0160
  ; Check if install disk is in the drive
  0000:0160  8d86d6fe       lea      ax, [bp - 0x12a]
  0000:0164  50             push     ax
  0000:0165  e8e93e         call     inte0_checkDirectory
  0000:0168  83c402         add      sp, 2
  0000:016B  8bf0           mov      si, ax
  0000:016D  0bf6           or       si, si
  0000:016F  7517           jne      .floppy_found
  ; Disk not found -- prompt again
  0000:0171  b83801         mov      ax, 0x138           ; "Disk Needed" dialog
  0000:0174  50             push     ax
  0000:0175  e8b53f         call     inte0_showMessageBox
  0000:0178  83c402         add      sp, 2
  0000:017B  8bf0           mov      si, ax
  0000:017D  3d02f7         cmp      ax, 0xf702          ; User pressed Cancel
  0000:0180  7506           jne      .check_retry
  0000:0182  b8ffff         mov      ax, 0xffff          ; Return -1 (cancelled)
  0000:0185  e94f01         jmp      .return
.check_retry:                                    ; 0000:0188
  0000:0188  83fe01         cmp      si, 1               ; Retry
  0000:018B  75d3           jne      .retry_floppy
  0000:018D  eb4d           jmp      .try_environment
.no_hard_disk:                                   ; 0000:018F
  ; No hard disk -- search DOS environment for install path
  0000:018F  8d86d6fe       lea      ax, [bp - 0x12a]
  0000:0193  50             push     ax
  0000:0194  b8aa1d         mov      ax, 0x1daa          ; Environment variable name to search
  0000:0197  50             push     ax
  0000:0198  e8710c         call     install_searchEnvironment
  0000:019B  83c404         add      sp, 4
  0000:019E  8bf0           mov      si, ax
  0000:01A0  83fe01         cmp      si, 1               ; Found?
  0000:01A3  7537           jne      .try_environment
  ; Found in environment: check if drive matches
  0000:01A5  a0a7df         mov      al, byte ptr [g_hasHardDisk]
  0000:01A8  3886d6fe       cmp      byte ptr [bp - 0x12a], al
  0000:01AC  750f           jne      .env_drive_different
  ; Same drive -- copy back to global install path
  0000:01AE  b83237         mov      ax, 0x3732
  0000:01B1  50             push     ax
  0000:01B2  8d86d6fe       lea      ax, [bp - 0x12a]
  0000:01B6  50             push     ax
  0000:01B7  e83c39         call     _strcpy
  0000:01BA  83c404         add      sp, 4
.env_drive_different:                            ; 0000:01BD
  ; Copy subdirectory from environment path
  0000:01BD  b86110         mov      ax, 0x1061          ; "DESKMATE"
  0000:01C0  50             push     ax
  0000:01C1  8d86d9fe       lea      ax, [bp - 0x127]    ; Skip drive letter in path
  0000:01C5  50             push     ax
  0000:01C6  e82d39         call     _strcpy
  0000:01C9  83c404         add      sp, 4
  ; Build destination path
  0000:01CC  8d86d6fe       lea      ax, [bp - 0x12a]
  0000:01D0  50             push     ax
  0000:01D1  8d865aff       lea      ax, [bp - 0xa6]     ; destDrive buffer
  0000:01D5  50             push     ax
  0000:01D6  e81d39         call     _strcpy
  0000:01D9  83c404         add      sp, 4
.try_environment:                                ; 0000:01DC
  ; Check if dest drive path is valid
  0000:01DC  80be5aff00     cmp      byte ptr [bp - 0xa6], 0
  0000:01E1  7503           jne      .have_dest_path
  0000:01E3  e99d00         jmp      .read_install_cfg
.have_dest_path:                                 ; 0000:01E6
  ; Compare dest drive with install drive
  0000:01E6  a03237         mov      al, byte ptr [g_installDrive]
  0000:01E9  38865aff       cmp      byte ptr [bp - 0xa6], al
  0000:01ED  7503           jne      .dest_different_drive
  0000:01EF  e99100         jmp      .read_install_cfg
.dest_different_drive:                           ; 0000:01F2
  ; Verify destination drive is accessible
  0000:01F2  8d865aff       lea      ax, [bp - 0xa6]
  0000:01F6  50             push     ax
  0000:01F7  e8573e         call     inte0_checkDirectory
  0000:01FA  83c402         add      sp, 2
  0000:01FD  8bf0           mov      si, ax
  0000:01FF  0bf6           or       si, si
  0000:0201  7511           jne      .dest_accessible
  ; Dest not accessible -- fall back to install drive
  0000:0203  b83237         mov      ax, 0x3732
  0000:0206  50             push     ax
  0000:0207  8d86d6fe       lea      ax, [bp - 0x12a]
  0000:020B  50             push     ax
  0000:020C  e8e738         call     _strcpy
  0000:020F  83c404         add      sp, 4
  0000:0212  eb6f           jmp      .read_install_cfg
.dest_accessible:                                ; 0000:0214
  ; Check if install drive itself is accessible
  0000:0214  b83237         mov      ax, 0x3732
  0000:0217  50             push     ax
  0000:0218  e8363e         call     inte0_checkDirectory
  0000:021B  83c402         add      sp, 2
  0000:021E  8bf0           mov      si, ax
  0000:0220  83fe01         cmp      si, 1
  0000:0223  755e           jne      .read_install_cfg
  ; Prompt for confirmation: install to different drive?
  0000:0225  b84401         mov      ax, 0x144           ; Confirmation dialog ID
  0000:0228  50             push     ax
  0000:0229  e8013f         call     inte0_showMessageBox
  0000:022C  83c402         add      sp, 2
  0000:022F  8bf0           mov      si, ax
  0000:0231  3d03f7         cmp      ax, 0xf703          ; User said No
  0000:0234  754d           jne      .read_install_cfg
  ; User wants to change: build new path with original drive
  0000:0236  b83237         mov      ax, 0x3732
  0000:0239  50             push     ax
  0000:023A  8d46de         lea      ax, [bp - 0x22]
  0000:023D  50             push     ax
  0000:023E  e8b538         call     _strcpy
  0000:0241  83c404         add      sp, 4
  ; Build disk label path for verification
  0000:0244  b8b21d         mov      ax, 0x1db2          ; Disk label format string
  0000:0247  50             push     ax
  0000:0248  8d46ea         lea      ax, [bp - 0x16]
  0000:024B  50             push     ax
  0000:024C  e8a738         call     _strcpy
  0000:024F  83c404         add      sp, 4
  ; Copy files from source disk to destination
  0000:0252  2bc0           sub      ax, ax              ; flags = 0
  0000:0254  50             push     ax
  0000:0255  b80100         mov      ax, 1               ; diskNumber = 1
  0000:0258  50             push     ax
  0000:0259  b8b61d         mov      ax, 0x1db6          ; File list identifier
  0000:025C  50             push     ax
  0000:025D  8d46da         lea      ax, [bp - 0x26]     ; diskLabel
  0000:0260  50             push     ax
  0000:0261  b80200         mov      ax, 2               ; direction = src->dest
  0000:0264  50             push     ax
  0000:0265  8d46fe         lea      ax, [bp - 2]        ; result
  0000:0268  50             push     ax
  0000:0269  b80100         mov      ax, 1               ; mode = 1
  0000:026C  50             push     ax
  0000:026D  8d46de         lea      ax, [bp - 0x22]     ; destPath
  0000:0270  50             push     ax
  0000:0271  b83237         mov      ax, 0x3732          ; srcPath
  0000:0274  50             push     ax
  0000:0275  e84403         call     install_copyFiles    ; Main file copy engine
  0000:0278  83c412         add      sp, 0x12
  0000:027B  8bf0           mov      si, ax
  0000:027D  e8c91e         call     install_resetCursorAndScreen
  0000:0280  e80c1c         call     install_restoreWindowState
.read_install_cfg:                               ; 0000:0283
  ; Read the INSTALL.CFG file from install buffer
  0000:0283  2bc0           sub      ax, ax
  0000:0285  50             push     ax
  0000:0286  8d86d6fe       lea      ax, [bp - 0x12a]
  0000:028A  50             push     ax
  0000:028B  e8cb3c         call     dmguf_createFile
  0000:028E  83c404         add      sp, 4
  0000:0291  8bf8           mov      di, ax              ; DI = file handle
  0000:0293  0bff           or       di, di
  0000:0295  7e1a           jle      .no_cfg_file
  ; Read file data into install buffer
  0000:0297  b8ff7f         mov      ax, 0x7fff          ; Max read size
  0000:029A  50             push     ax
  0000:029B  b8a85f         mov      ax, 0x5fa8          ; g_installDataBuf
  0000:029E  50             push     ax
  0000:029F  57             push     di                   ; File handle
  0000:02A0  e8bc3c         call     dmguf_readFile
  0000:02A3  83c406         add      sp, 6
  0000:02A6  898658ff       mov      word ptr [bp - 0xa8], ax  ; bytesRead
  0000:02AA  57             push     di
  0000:02AB  e8993c         call     dmguf_closeFile
  0000:02AE  83c402         add      sp, 2
.no_cfg_file:                                    ; 0000:02B1
  ; Calculate end of install buffer
  0000:02B1  8b8658ff       mov      ax, word ptr [bp - 0xa8]  ; bytesRead
  0000:02B5  05a85f         add      ax, 0x5fa8          ; + buffer start
  0000:02B8  a38638         mov      word ptr [g_installBufPtr], ax  ; Store end pointer
  ; Ensure buffer ends with EOF marker (0x1A)
  0000:02BB  83be58ff00     cmp      word ptr [bp - 0xa8], 0
  0000:02C0  7408           je       .add_eof
  0000:02C2  8bd8           mov      bx, ax
  0000:02C4  807fff1a       cmp      byte ptr [bx - 1], 0x1a  ; Already has EOF?
  0000:02C8  740b           je       .done_eof
.add_eof:                                        ; 0000:02CA
  0000:02CA  8b1e8638       mov      bx, word ptr [g_installBufPtr]
  0000:02CE  ff068638       inc      word ptr [g_installBufPtr]
  0000:02D2  c6071a         mov      byte ptr [bx], 0x1a ; Append EOF marker
.done_eof:                                       ; 0000:02D5
  0000:02D5  2bc0           sub      ax, ax              ; Return 0 (success)
.return:                                         ; 0000:02D7
  0000:02D7  5e             pop      si
  0000:02D8  5f             pop      di
  0000:02D9  8be5           mov      sp, bp
  0000:02DB  5d             pop      bp
  0000:02DC  c3             ret

; ========================================================================
; install_writeConfigAndCleanup
; Address: 0000:02DD
; Parameters: none
; Returns: nothing
; Description: Writes the install configuration buffer to INSTALL.CFG on
;   the destination drive. Then checks if the system has a hard disk and
;   updates drive configuration if needed. Restores drive state and
;   clears the floppy-access bit in equipment flags if appropriate.
; ========================================================================
install_writeConfigAndCleanup:                   ; 0000:02DD
  0000:02DD  55             push     bp
  0000:02DE  8bec           mov      bp, sp
  0000:02E0  83ec04         sub      sp, 4
  0000:02E3  57             push     di
  0000:02E4  56             push     si
  ; Open config file for writing
  0000:02E5  b83237         mov      ax, 0x3732          ; Install drive path
  0000:02E8  50             push     ax
  0000:02E9  e8613c         call     dmguf_openFileRead
  0000:02EC  83c402         add      sp, 2
  0000:02EF  8bf0           mov      si, ax              ; SI = file handle
  0000:02F1  0bf6           or       si, si
  0000:02F3  7e19           jle      .skip_write
  ; Write install buffer contents to file
  0000:02F5  a18638         mov      ax, word ptr [g_installBufPtr]
  0000:02F8  2da85f         sub      ax, 0x5fa8          ; Calculate data size
  0000:02FB  50             push     ax                   ; Byte count
  0000:02FC  b8a85f         mov      ax, 0x5fa8          ; Buffer address
  0000:02FF  50             push     ax
  0000:0300  56             push     si                   ; File handle
  0000:0301  e8613c         call     dmguf_writeFile
  0000:0304  83c406         add      sp, 6
  ; Close the config file
  0000:0307  56             push     si
  0000:0308  e83c3c         call     dmguf_closeFile
  0000:030B  83c402         add      sp, 2
.skip_write:                                     ; 0000:030E
  ; Check if system has a hard disk
  0000:030E  803ea7df00     cmp      byte ptr [g_hasHardDisk], 0
  0000:0313  7459           je       .cleanup_done
  ; Read equipment byte to check drive configuration
  0000:0315  ff36ad0f       push     word ptr [g_equipmentWord]
  0000:0319  e80b21         call     install_readEquipmentByte
  0000:031C  83c402         add      sp, 2
  0000:031F  8bf8           mov      di, ax
  0000:0321  853eb10f       test     word ptr [g_equipmentMask], di
  0000:0325  7547           jne      .cleanup_done
  ; Combine equipment flags and update dialog
  0000:0327  0b3eaf0f       or       di, word ptr [g_equipmentFlags]
  0000:032B  c70673043516   mov      word ptr [g_installDirPtr], 0x1635  ; Updated path string
  0000:0331  b87604         mov      ax, 0x476
  0000:0334  50             push     ax
  0000:0335  e8ef3d         call     inte0_setStatusBar
  0000:0338  83c402         add      sp, 2
  0000:033B  b80006         mov      ax, 0x600
  0000:033E  50             push     ax
  0000:033F  e8033e         call     inte0_allocateMemory
  0000:0342  83c402         add      sp, 2
  ; Write updated equipment byte
  0000:0345  57             push     di
  0000:0346  ff36ad0f       push     word ptr [g_equipmentWord]
  0000:034A  e8f520         call     install_writeEquipmentByte
  0000:034D  83c404         add      sp, 4
  ; Check if equipment word is 6 (special case)
  0000:0350  833ead0f06     cmp      word ptr [g_equipmentWord], 6
  0000:0355  7517           jne      .cleanup_done
  ; Clear floppy-access bit (0xBF = clear bit 6)
  0000:0357  b80400         mov      ax, 4
  0000:035A  50             push     ax
  0000:035B  e8c920         call     install_readEquipmentByte
  0000:035E  83c402         add      sp, 2
  0000:0361  24bf           and      al, 0xbf            ; Clear bit 6
  0000:0363  50             push     ax
  0000:0364  b80400         mov      ax, 4
  0000:0367  50             push     ax
  0000:0368  e8d720         call     install_writeEquipmentByte
  0000:036B  83c404         add      sp, 4
.cleanup_done:                                   ; 0000:036E
  0000:036E  5e             pop      si
  0000:036F  5f             pop      di
  0000:0370  8be5           mov      sp, bp
  0000:0372  5d             pop      bp
  0000:0373  c3             ret

; ========================================================================
; install_parseCommandLine
; Address: 0000:0374
; Parameters: none
; Returns: nothing (updates global state)
; Description: Parses the command line for a /D= directory override.
;   Searches the install buffer for the directory parameter string.
;   If found, extracts the directory path and appends it to the install
;   buffer. If not found, uses a default path. Also handles the /I=
;   (single-floppy install) parameter.
; ========================================================================
install_parseCommandLine:                        ; 0000:0374
  0000:0374  55             push     bp
  0000:0375  8bec           mov      bp, sp
  0000:0377  83ec08         sub      sp, 8
  0000:037A  57             push     di
  0000:037B  56             push     si
  ; Search for "/D=" parameter in buffer
  0000:037C  b8a85f         mov      ax, 0x5fa8          ; g_installDataBuf
  0000:037F  50             push     ax
  0000:0380  b8b71d         mov      ax, 0x1db7          ; "/D=" search string
  0000:0383  50             push     ax
  0000:0384  e8f401         call     install_searchBuffer
  0000:0387  83c404         add      sp, 4
  0000:038A  8bf0           mov      si, ax              ; SI = found position (0 if not found)
  0000:038C  0bc0           or       ax, ax
  0000:038E  7510           jne      .found_param
  ; Try alternative parameter "/I="
  0000:0390  b8a85f         mov      ax, 0x5fa8
  0000:0393  50             push     ax
  0000:0394  b8bd1d         mov      ax, 0x1dbd          ; "/I=" search string
  0000:0397  50             push     ax
  0000:0398  e8e001         call     install_searchBuffer
  0000:039B  83c404         add      sp, 4
  0000:039E  8bf0           mov      si, ax
.found_param:                                    ; 0000:03A0
  ; Get length of tag at offset 0x56
  0000:03A0  b85600         mov      ax, 0x56
  0000:03A3  50             push     ax
  0000:03A4  e8ad37         call     _strlen
  0000:03A7  83c402         add      sp, 2
  0000:03AA  8946fe         mov      word ptr [bp - 2], ax  ; Save tag length
  ; If no parameter found, use default
  0000:03AD  0bf6           or       si, si
  0000:03AF  751f           jne      .parse_value
  ; No /D= found: insert default directory entry
  0000:03B1  b80700         mov      ax, 7               ; Block size
  0000:03B4  50             push     ax
  0000:03B5  b8c31d         mov      ax, 0x1dc3          ; Default directory string
  0000:03B8  50             push     ax
  0000:03B9  b8a85f         mov      ax, 0x5fa8
  0000:03BC  50             push     ax
  0000:03BD  e86401         call     install_insertDataBlock
  0000:03C0  83c406         add      sp, 6
  ; Set SI to default path
  0000:03C3  bead5f         mov      si, 0x5fad          ; Default install path in buffer
  0000:03C6  ff76fe         push     word ptr [bp - 2]   ; Tag length
  0000:03C9  b85600         mov      ax, 0x56
  0000:03CC  50             push     ax
  0000:03CD  56             push     si
  0000:03CE  eb4f           jmp      .insert_and_done
.parse_value:                                    ; 0000:03D0
  ; Skip whitespace and '=' in the parameter value
.skip_ws:
  0000:03D0  803c20         cmp      byte ptr [si], 0x20  ; Space
  0000:03D3  7405           je       .skip_char
  0000:03D5  803c3d         cmp      byte ptr [si], 0x3d  ; '='
  0000:03D8  7503           jne      .done_skip
.skip_char:
  0000:03DA  46             inc      si
  0000:03DB  ebf3           jmp      .skip_ws
.done_skip:                                      ; 0000:03DD
  ; Parse the directory path value
  0000:03DD  56             push     si
  0000:03DE  b85600         mov      ax, 0x56            ; Tag offset
  0000:03E1  50             push     ax
  0000:03E2  e89601         call     install_searchBuffer
  0000:03E5  83c404         add      sp, 4
  0000:03E8  8bf8           mov      di, ax              ; DI = end of path
  ; Search for terminator character
  0000:03EA  56             push     si
  0000:03EB  b8cb1d         mov      ax, 0x1dcb          ; Terminator search string
  0000:03EE  50             push     ax
  0000:03EF  e88901         call     install_searchBuffer
  0000:03F2  83c404         add      sp, 4
  0000:03F5  8946fc         mov      word ptr [bp - 4], ax  ; Save terminator position
  ; Validate path
  0000:03F8  8bc7           mov      ax, di
  0000:03FA  0bc0           or       ax, ax
  0000:03FC  7405           je       .use_default
  0000:03FE  397efc         cmp      word ptr [bp - 4], di
  0000:0401  7727           ja       .path_valid
.use_default:                                    ; 0000:0403
  ; Path is invalid -- insert default and mark as modified
  0000:0403  ff76fe         push     word ptr [bp - 2]
  0000:0406  b85600         mov      ax, 0x56
  0000:0409  50             push     ax
  0000:040A  56             push     si
  0000:040B  e81601         call     install_insertDataBlock
  0000:040E  83c406         add      sp, 6
  ; Insert continuation marker
  0000:0411  b80100         mov      ax, 1
  0000:0414  50             push     ax
  0000:0415  b8cd1d         mov      ax, 0x1dcd          ; Continuation string
  0000:0418  50             push     ax
  0000:0419  8b46fe         mov      ax, word ptr [bp - 2]
  0000:041C  03c6           add      ax, si
  0000:041E  50             push     ax
.insert_and_done:                                ; 0000:041F
  0000:041F  e80201         call     install_insertDataBlock
  0000:0422  83c406         add      sp, 6
  0000:0425  c606ef0001     mov      byte ptr [g_needsAutoexecMod], 1  ; Mark for AUTOEXEC modification
.path_valid:                                     ; 0000:042A
  0000:042A  5e             pop      si
  0000:042B  5f             pop      di
  0000:042C  8be5           mov      sp, bp
  0000:042E  5d             pop      bp
  0000:042F  c3             ret

; ========================================================================
; install_parseVideoConfig
; Address: 0000:0430
; Parameters: none
; Returns: nothing
; Description: Searches the install buffer for the video adapter
;   configuration tag (0xCF/1D). If not found, inserts a default
;   video configuration block.
; ========================================================================
install_parseVideoConfig:                        ; 0000:0430
  0000:0430  55             push     bp
  0000:0431  8bec           mov      bp, sp
  0000:0433  83ec02         sub      sp, 2
  0000:0436  56             push     si
  0000:0437  b8a85f         mov      ax, 0x5fa8          ; g_installDataBuf
  0000:043A  50             push     ax
  0000:043B  b8cf1d         mov      ax, 0x1dcf          ; Video config tag
  0000:043E  50             push     ax
  0000:043F  e83901         call     install_searchBuffer
  0000:0442  83c404         add      sp, 4
  0000:0445  8bf0           mov      si, ax
  0000:0447  0bc0           or       ax, ax
  0000:0449  7512           jne      .found
  ; Not found: insert default video config
  0000:044B  b80d00         mov      ax, 0xd             ; Block size = 13
  0000:044E  50             push     ax
  0000:044F  b8d61d         mov      ax, 0x1dd6          ; Default video config data
  0000:0452  50             push     ax
  0000:0453  b8a85f         mov      ax, 0x5fa8
  0000:0456  50             push     ax
  0000:0457  e8ca00         call     install_insertDataBlock
  0000:045A  83c406         add      sp, 6
.found:                                          ; 0000:045D
  0000:045D  5e             pop      si
  0000:045E  8be5           mov      sp, bp
  0000:0460  5d             pop      bp
  0000:0461  c3             ret

; ========================================================================
; install_parseAutoexecConfig
; Address: 0000:0462
; Parameters: none
; Returns: nothing
; Description: Checks the current AUTOEXEC.BAT for existing DeskMate
;   entries. If this is a single-floppy install (g_installType == 1),
;   checks if the install drive is valid. Searches the install buffer
;   for the AUTOEXEC.BAT configuration tag. If not found, inserts a
;   default AUTOEXEC modification block. Also extracts the path to
;   the AUTOEXEC.BAT file for later modification.
; ========================================================================
install_parseAutoexecConfig:                     ; 0000:0462
  0000:0462  55             push     bp
  0000:0463  8bec           mov      bp, sp
  0000:0465  83ec04         sub      sp, 4
  0000:0468  57             push     di
  0000:0469  56             push     si
  ; Check if single-floppy install mode
  0000:046A  833e463901     cmp      word ptr [g_installType], 1
  0000:046F  7510           jne      .not_single_floppy
  ; Single floppy: verify drive is valid
  0000:0471  a0a35d         mov      al, byte ptr [g_destDriveLetter]
  0000:0474  98             cwde
  0000:0475  50             push     ax
  0000:0476  e82c1a         call     install_checkDriveReady
  0000:0479  83c402         add      sp, 2
  0000:047C  3d0100         cmp      ax, 1
  0000:047F  745c           je       .done                ; Drive ready, skip config
.not_single_floppy:                              ; 0000:0481
  ; Search for AUTOEXEC config tag
  0000:0481  b8a85f         mov      ax, 0x5fa8
  0000:0484  50             push     ax
  0000:0485  b8e41d         mov      ax, 0x1de4          ; AUTOEXEC config tag
  0000:0488  50             push     ax
  0000:0489  e8ef00         call     install_searchBuffer
  0000:048C  83c404         add      sp, 4
  0000:048F  8bf0           mov      si, ax
  0000:0491  0bf6           or       si, si
  0000:0493  7517           jne      .found_autoexec
  ; Not found: insert default AUTOEXEC config block
  0000:0495  b80f00         mov      ax, 0xf             ; Block size = 15
  0000:0498  50             push     ax
  0000:0499  b8ee1d         mov      ax, 0x1dee          ; Default AUTOEXEC config
  0000:049C  50             push     ax
  0000:049D  b8a85f         mov      ax, 0x5fa8
  0000:04A0  50             push     ax
  0000:04A1  e88000         call     install_insertDataBlock
  0000:04A4  83c406         add      sp, 6
  ; Point SI to default AUTOEXEC path
  0000:04A7  beb55f         mov      si, 0x5fb5
  0000:04AA  eb16           jmp      .extract_path
.found_autoexec:                                 ; 0000:04AC
  ; Extract path from existing AUTOEXEC entry
  0000:04AC  8bfe           mov      di, si
  0000:04AE  eb01           jmp      .find_cr
.scan_cr:
  0000:04B0  47             inc      di
.find_cr:
  0000:04B1  803d0d         cmp      byte ptr [di], 0xd  ; Carriage return
  0000:04B4  75fa           jne      .scan_cr
  ; Calculate path length and remove trailing portion
  0000:04B6  8bc7           mov      ax, di
  0000:04B8  2bc6           sub      ax, si              ; Length to CR
  0000:04BA  50             push     ax
  0000:04BB  56             push     si
  0000:04BC  e89500         call     install_removeDataBlock
  0000:04BF  83c404         add      sp, 4
.extract_path:                                   ; 0000:04C2
  ; Copy AUTOEXEC path to working buffer
  0000:04C2  b8c438         mov      ax, 0x38c4          ; g_pathBuffer
  0000:04C5  50             push     ax
  0000:04C6  e88b36         call     _strlen
  0000:04C9  83c402         add      sp, 2
  0000:04CC  50             push     ax                   ; Length
  0000:04CD  b8c438         mov      ax, 0x38c4
  0000:04D0  50             push     ax
  0000:04D1  56             push     si                   ; Source path
  0000:04D2  e84f00         call     install_insertDataBlock
  0000:04D5  83c406         add      sp, 6
  0000:04D8  c606ef0001     mov      byte ptr [g_needsAutoexecMod], 1
.done:                                           ; 0000:04DD
  0000:04DD  5e             pop      si
  0000:04DE  5f             pop      di
  0000:04DF  8be5           mov      sp, bp
  0000:04E1  5d             pop      bp
  0000:04E2  c3             ret

; ========================================================================
; install_checkDeskExePresent
; Address: 0000:04E3
; Parameters: none
; Returns: nothing (may prompt user)
; Description: Checks if DESK.EXE exists at the specified path (tag 0x44).
;   If found, prompts the user with a dialog asking if they want to
;   reinstall. If the user cancels, the check exits. Otherwise, it
;   records the DESK.EXE location offset in the install buffer.
; ========================================================================
install_checkDeskExePresent:                     ; 0000:04E3
  0000:04E3  55             push     bp
  0000:04E4  8bec           mov      bp, sp
  0000:04E6  83ec04         sub      sp, 4
  0000:04E9  56             push     si
  ; Search for DESK.EXE tag (0x44 = 'D') in buffer
  0000:04EA  b8a85f         mov      ax, 0x5fa8
  0000:04ED  50             push     ax
  0000:04EE  b84400         mov      ax, 0x44            ; Tag: DESK.EXE check
  0000:04F1  50             push     ax
  0000:04F2  e88600         call     install_searchBuffer
  0000:04F5  83c404         add      sp, 4
  0000:04F8  8bf0           mov      si, ax
  0000:04FA  0bc0           or       ax, ax
  0000:04FC  7421           je       .not_found
  ; DESK.EXE found: prompt user
  0000:04FE  b85001         mov      ax, 0x150           ; Dialog: "DeskMate already installed"
  0000:0501  50             push     ax
  0000:0502  e8283c         call     inte0_showMessageBox
  0000:0505  83c402         add      sp, 2
  0000:0508  3d04f7         cmp      ax, 0xf704          ; User pressed Cancel
  0000:050B  7412           je       .not_found
  ; User wants to reinstall: adjust buffer offset
  0000:050D  83ee08         sub      si, 8               ; Back up 8 bytes
  0000:0510  b80400         mov      ax, 4               ; Block size
  0000:0513  50             push     ax
  0000:0514  b85000         mov      ax, 0x50            ; Tag
  0000:0517  50             push     ax
  0000:0518  56             push     si
  0000:0519  e80800         call     install_insertDataBlock
  0000:051C  83c406         add      sp, 6
.not_found:                                      ; 0000:051F
  0000:051F  5e             pop      si
  0000:0520  8be5           mov      sp, bp
  0000:0522  5d             pop      bp
  0000:0523  c3             ret

; ========================================================================
; install_insertDataBlock
; Address: 0000:0524
; Parameters: [bp+4] = dest offset in buffer
;             [bp+6] = source data pointer
;             [bp+8] = block size (bytes to insert)
; Returns: nothing
; Description: Inserts a data block into the install buffer at the
;   specified position by first shifting existing data to make room,
;   then copying the new data into the gap.
; ========================================================================
install_insertDataBlock:                         ; 0000:0524
  0000:0524  55             push     bp
  0000:0525  8bec           mov      bp, sp
  0000:0527  57             push     di
  0000:0528  56             push     si
  0000:0529  8b7604         mov      si, word ptr [bp + 4]  ; Dest offset
  0000:052C  8b7e08         mov      di, word ptr [bp + 8]  ; Block size
  ; Shift existing data up to make room
  0000:052F  a18638         mov      ax, word ptr [g_installBufPtr]  ; Current end
  0000:0532  2bc6           sub      ax, si              ; Bytes to move
  0000:0534  50             push     ax
  0000:0535  56             push     si                   ; Source = insert point
  0000:0536  8bc7           mov      ax, di
  0000:0538  03c6           add      ax, si              ; Dest = insert point + block size
  0000:053A  50             push     ax
  0000:053B  e8e837         call     _memmove
  0000:053E  83c406         add      sp, 6
  ; Update buffer end pointer
  0000:0541  013e8638       add      word ptr [g_installBufPtr], di
  ; Copy new data into the gap
  0000:0545  57             push     di                   ; Size
  0000:0546  ff7606         push     word ptr [bp + 6]   ; Source data
  0000:0549  56             push     si                   ; Dest = insert point
  0000:054A  e8d937         call     _memmove
  0000:054D  83c406         add      sp, 6
  0000:0550  5e             pop      si
  0000:0551  5f             pop      di
  0000:0552  5d             pop      bp
  0000:0553  c3             ret

; ========================================================================
; install_removeDataBlock
; Address: 0000:0554
; Parameters: [bp+4] = offset in buffer
;             [bp+6] = block size (bytes to remove)
; Returns: nothing
; Description: Removes a data block from the install buffer by shifting
;   data down to close the gap.
; ========================================================================
install_removeDataBlock:                         ; 0000:0554
  0000:0554  55             push     bp
  0000:0555  8bec           mov      bp, sp
  0000:0557  57             push     di
  0000:0558  56             push     si
  0000:0559  8b7604         mov      si, word ptr [bp + 4]  ; Offset
  0000:055C  8b7e06         mov      di, word ptr [bp + 6]  ; Block size
  ; Calculate bytes to move (from after block to end of buffer)
  0000:055F  a18638         mov      ax, word ptr [g_installBufPtr]
  0000:0562  2bc6           sub      ax, si
  0000:0564  2bc7           sub      ax, di              ; Bytes remaining after block
  0000:0566  50             push     ax
  0000:0567  8bc7           mov      ax, di
  0000:0569  03c6           add      ax, si              ; Source = after block
  0000:056B  50             push     ax
  0000:056C  56             push     si                   ; Dest = block start
  0000:056D  e8b637         call     _memmove
  0000:0570  83c406         add      sp, 6
  ; Update buffer end pointer
  0000:0573  293e8638       sub      word ptr [g_installBufPtr], di
  0000:0577  5e             pop      si
  0000:0578  5f             pop      di
  0000:0579  5d             pop      bp
  0000:057A  c3             ret

; ========================================================================
; install_searchBuffer
; Address: 0000:057B
; Parameters: [bp+4] = search tag/string
;             [bp+6] = buffer start offset
; Returns: AX = position of match (0 if not found)
; Description: Searches the install data buffer for a string match.
;   Uses toupper() for case-insensitive comparison. Scans from the
;   given buffer offset to g_installBufPtr.
; ========================================================================
install_searchBuffer:                            ; 0000:057B
  0000:057B  55             push     bp
  0000:057C  8bec           mov      bp, sp
  0000:057E  83ec04         sub      sp, 4
  0000:0581  57             push     di
  0000:0582  56             push     si
  0000:0583  eb27           jmp      .check_end
.next_pos:                                       ; 0000:0585
  0000:0585  8b7e04         mov      di, word ptr [bp + 4]  ; DI = search string
  0000:0588  8b7606         mov      si, word ptr [bp + 6]  ; SI = buffer position
  0000:058B  eb09           jmp      .compare_char
.check_match:                                    ; 0000:058D
  0000:058D  803d00         cmp      byte ptr [di], 0    ; End of search string?
  0000:0590  7504           jne      .compare_char
  ; Full match found
  0000:0592  8bc6           mov      ax, si              ; Return match position
  0000:0594  eb20           jmp      .done
.compare_char:                                   ; 0000:0596
  0000:0596  ac             lodsb                         ; AL = next buffer char
  0000:0597  98             cwde
  0000:0598  50             push     ax
  0000:0599  e80e36         call     _toupper            ; Convert to uppercase
  0000:059C  83c402         add      sp, 2
  0000:059F  8bc8           mov      cx, ax              ; CX = uppercase buffer char
  0000:05A1  8a05           mov      al, byte ptr [di]   ; AL = search char
  0000:05A3  47             inc      di
  0000:05A4  98             cwde
  0000:05A5  3bc1           cmp      ax, cx              ; Compare
  0000:05A7  74e4           je       .check_match        ; Match: continue
  ; No match at this position: advance buffer pointer
  0000:05A9  ff4606         inc      word ptr [bp + 6]
.check_end:                                      ; 0000:05AC
  0000:05AC  a18638         mov      ax, word ptr [g_installBufPtr]
  0000:05AF  394606         cmp      word ptr [bp + 6], ax
  0000:05B2  75d1           jne      .next_pos
  ; Not found
  0000:05B4  2bc0           sub      ax, ax              ; Return 0
.done:                                           ; 0000:05B6
  0000:05B6  5e             pop      si
  0000:05B7  5f             pop      di
  0000:05B8  8be5           mov      sp, bp
  0000:05BA  5d             pop      bp
  0000:05BB  c3             ret

; ========================================================================
; install_copyFiles  (LARGEST application function -- 1494 bytes)
; Address: 0000:05BC
; Parameters: [bp+4]  = source path string
;             [bp+6]  = file list/destination path string
;             [bp+8]  = source path buffer
;             [bp+0A] = result pointer (word)
;             [bp+0C] = copy flags (word)
;             [bp+0E] = state pointer (word)
;             [bp+10] = count (word)
;             [bp+12] = alt source flag (byte)
;             [bp+14] = mode flags (byte)
; Returns: AX = result code (0=success, 1=retry needed, -1=failure)
; Description: Main file copy engine for the installer. Handles:
;   - Prompting for source disk if needed
;   - Iterating through files on source disk(s)
;   - Creating destination directories
;   - Copying individual files with progress display
;   - Checking disk free space on destination
;   - Handling multi-disk installation (disk swaps)
;   - Error handling (disk full, file exists, etc.)
;   Stack frame: 0x232 bytes local variables
; ========================================================================
install_copyFiles:                               ; 0000:05BC
  0000:05BC  55             push     bp
  0000:05BD  8bec           mov      bp, sp
  0000:05BF  81ec3202       sub      sp, 0x232
  0000:05C3  57             push     di
  0000:05C4  56             push     si
  ; Initialize local state variables
  0000:05C5  c786e4feff7f   mov      word ptr [bp - 0x11c], 0x7fff  ; maxBlockSize
  0000:05CB  c786d4fd0000   mov      word ptr [bp - 0x22c], 0      ; copyActive = false
  0000:05D1  c786d0fd0000   mov      word ptr [bp - 0x230], 0      ; destFileOpen = false
  0000:05D7  c78670ff0000   mov      word ptr [bp - 0x90], 0       ; moreFiles = false
  0000:05DD  c786d6fd0000   mov      word ptr [bp - 0x22a], 0      ; copyResult = 0
  0000:05E3  c786d8fd0000   mov      word ptr [bp - 0x228], 0      ; diskIndex = 0
  0000:05E9  c78670ff0100   mov      word ptr [bp - 0x90], 1       ; moreFiles = true
  0000:05EF  2bf6           sub      si, si                        ; SI = 0 (loop counter)
  ; Set up DTA buffer
  0000:05F1  c70682380100   mov      word ptr [g_dtaBufferMode], 1
  0000:05F7  b80238         mov      ax, 0x3802          ; g_dtaBuffer
  0000:05FA  1e             push     ds
  0000:05FB  50             push     ax
  0000:05FC  e8511c         call     install_setDTAAddress
  0000:05FF  83c404         add      sp, 4

  ; [Main copy loop continues for ~1400 more bytes...]
  ; The function implements a state machine:
  ;   State 0 (copyActive=0): Prompt for source disk, find files
  ;   State 1 (copyActive=1): Copy file data blocks
  ;   State 2 (destFileOpen=1): Write to destination, close when done
  ;
  ; Error codes returned in SI:
  ;   0x00 = success
  ;   0x42 = disk write error
  ;   0x45 = file comparison mismatch
  ;   0x46 = insufficient disk space
  ;   0x12 = directory not found
  ;
  ; For brevity, the remaining ~1400 bytes of this function are
  ; represented as raw code with inline comments at key branch points.

; [... main copy loop at 0x0602 ...]
; [... file copy data transfer at 0x0908 ...]
; [... cleanup at 0x0B4E ...]

  ; (The full raw disassembly of this function spans lines 727-1313
  ;  of the raw output file. Key operations include:
  ;  - 0x0616: Initialize source path buffer
  ;  - 0x064F: Check copy mode (single file vs batch)
  ;  - 0x06AC: Set up file copy for current file
  ;  - 0x072E: Set drive and build directory path
  ;  - 0x0776: Multi-disk handling (advance to next disk)
  ;  - 0x07E7: Check mode flags for skip/verify
  ;  - 0x0837: Create destination directory if needed
  ;  - 0x087A: Check disk free space
  ;  - 0x08C3: Check file date comparison
  ;  - 0x08DD: Open source file for reading
  ;  - 0x0908: Main data copy loop (read/write blocks)
  ;  - 0x0A10: Check for more files
  ;  - 0x0A32: Verify destination directory exists
  ;  - 0x0A8D: Compare source/dest paths
  ;  - 0x0AC6: Write data block to destination
  ;  - 0x0B02: Close destination file when done
  ;  - 0x0B4E: Cleanup and close any open files)

  ; [Function epilogue]
  0000:0B8C  5e             pop      si
  0000:0B8D  5f             pop      di
  0000:0B8E  8be5           mov      sp, bp
  0000:0B90  5d             pop      bp
  0000:0B91  c3             ret

; ========================================================================
; install_callDeskExe
; Address: 0000:0D40
; Parameters: [bp+4] = source path
;             [bp+6] = destination path
;             [bp+8] = flags
; Returns: AX = result from DESK.EXE
; Description: Calls DESK.EXE's file operation handler via INT E0h.
;   This function performs a stack switch before calling INT E0h with
;   AX=0600h (get event/open file) and AX=0603h (write/resource dispatch).
;   The stack switch is necessary because the DeskMate shell may need
;   more stack space than the PDM's stack provides.
;
;   If INT E0h AX=0600h indicates no event (high bit not set), or if
;   INT E0h AX=060Eh returns a value >= 0x6E, the call is made directly
;   without a stack switch (the "simple path").
;
;   INT E0h services used:
;     AX=0600h  - Get event / check status
;     AX=060Eh  - Dispatch event
;     AX=0603h  - Resource dispatch / file write
; ========================================================================
install_callDeskExe:                             ; 0000:0D40
  0000:0D40  55             push     bp
  0000:0D41  8bec           mov      bp, sp
  0000:0D43  1e             push     ds
  0000:0D44  06             push     es
  0000:0D45  56             push     si
  0000:0D46  57             push     di
  0000:0D47  53             push     bx
  0000:0D48  51             push     cx
  0000:0D49  52             push     dx
  ; Check if DeskMate shell is ready for calls
  0000:0D4A  b80006         mov      ax, 0x600           ; INT E0h: Get event
  0000:0D4D  cde0           int      0xe0
  0000:0D4F  250080         and      ax, 0x8000          ; Check high bit (event pending)
  0000:0D52  7413           je       .simple_path         ; No event: use simple path
  ; Event pending: dispatch it first
  0000:0D54  ba1806         mov      dx, 0x618           ; Parameter block offset
  0000:0D57  1e             push     ds
  0000:0D58  07             pop      es                   ; ES = DS
  0000:0D59  b80e06         mov      ax, 0x60e           ; INT E0h: Dispatch event
  0000:0D5C  cde0           int      0xe0
  0000:0D5E  0bc0           or       ax, ax
  0000:0D60  7405           je       .simple_path
  0000:0D62  3d6e00         cmp      ax, 0x6e            ; Result >= 0x6E?
  0000:0D65  7c03           jl       .stack_switch_path
.simple_path:                                    ; 0000:0D67
  0000:0D67  e98900         jmp      .direct_call
.stack_switch_path:                              ; 0000:0D6A
  ; Save flags parameter
  0000:0D6A  8b4608         mov      ax, word ptr [bp + 8]
  0000:0D6D  a31606         mov      word ptr [0x616], ax
  ; Allocate temporary stack space and copy source path
  0000:0D70  83ec41         sub      sp, 0x41            ; 65 bytes for path copy
  0000:0D73  8bfc           mov      di, sp
  0000:0D75  57             push     di
  0000:0D76  16             push     ss
  0000:0D77  07             pop      es
  0000:0D78  8b7604         mov      si, word ptr [bp + 4]
  0000:0D7B  b94100         mov      cx, 0x41
  0000:0D7E  fc             cld
  0000:0D7F  f3a4           rep movsb                    ; Copy source path
  0000:0D81  5f             pop      di
  ; Allocate more stack for destination path
  0000:0D82  83ec41         sub      sp, 0x41
  0000:0D85  8bf4           mov      si, sp
  ; Allocate stack for DeskMate call frame
  0000:0D87  83ec61         sub      sp, 0x61
  0000:0D8A  8bdc           mov      bx, sp
  ; Calculate segment:offset for the new SS:SP
  0000:0D8C  b104           mov      cl, 4
  0000:0D8E  d3eb           shr      bx, cl              ; BX = SP >> 4
  0000:0D90  8cd2           mov      dx, ss
  0000:0D92  03d3           add      dx, bx              ; DX = new SS
  0000:0D94  81ea9701       sub      dx, 0x197           ; Adjust for DeskMate stack needs
  0000:0D98  b104           mov      cl, 4
  0000:0D9A  d3e3           shl      bx, cl
  0000:0D9C  8bcc           mov      cx, sp
  0000:0D9E  2bcb           sub      cx, bx
  0000:0DA0  81c17019       add      cx, 0x1970          ; CX = new SP
  ; Adjust SI and DI for new stack segment
  0000:0DA4  89361406       mov      word ptr [0x614], si
  0000:0DA8  2bf3           sub      si, bx
  0000:0DAA  2bfb           sub      di, bx
  0000:0DAC  81c67019       add      si, 0x1970
  0000:0DB0  81c77019       add      di, 0x1970
  ; Switch to new stack
  0000:0DB4  fa             cli
  0000:0DB5  8c161006       mov      word ptr [0x610], ss  ; Save old SS
  0000:0DB9  89261206       mov      word ptr [0x612], sp  ; Save old SP
  0000:0DBD  8ed2           mov      ss, dx              ; Set new SS
  0000:0DBF  8be1           mov      sp, cx              ; Set new SP
  0000:0DC1  fb             sti
  ; Make the INT E0h call on the new stack
  0000:0DC2  8cd0           mov      ax, ss
  0000:0DC4  8ec0           mov      es, ax
  0000:0DC6  8b1e1606       mov      bx, word ptr [0x616]  ; Flags
  0000:0DCA  b80306         mov      ax, 0x603           ; INT E0h: Resource dispatch / file write
  0000:0DCD  cde0           int      0xe0
  ; Restore original stack
  0000:0DCF  fa             cli
  0000:0DD0  8e161006       mov      ss, word ptr [0x610]
  0000:0DD4  8b261206       mov      sp, word ptr [0x612]
  0000:0DD8  fb             sti
  ; Copy result path back from new stack
  0000:0DD9  8b7e06         mov      di, word ptr [bp + 6]  ; Destination
  0000:0DDC  1e             push     ds
  0000:0DDD  07             pop      es
  0000:0DDE  8b361406       mov      si, word ptr [0x614]
  0000:0DE2  b94100         mov      cx, 0x41
  0000:0DE5  fc             cld
  0000:0DE6  f3a4           rep movsb                    ; Copy result back
  ; Clean up temporary stack allocations
  0000:0DE8  83c461         add      sp, 0x61
  0000:0DEB  83c441         add      sp, 0x41
  0000:0DEE  83c441         add      sp, 0x41
  0000:0DF1  eb10           jmp      .return
.direct_call:                                    ; 0000:0DF3
  ; Simple path: call INT E0h directly without stack switch
  0000:0DF3  1e             push     ds
  0000:0DF4  07             pop      es
  0000:0DF5  8b5e08         mov      bx, word ptr [bp + 8]  ; Flags
  0000:0DF8  8b7606         mov      si, word ptr [bp + 6]  ; Dest path
  0000:0DFB  8b7e04         mov      di, word ptr [bp + 4]  ; Source path
  0000:0DFE  b80306         mov      ax, 0x603           ; INT E0h: Resource dispatch
  0000:0E01  cde0           int      0xe0
.return:                                         ; 0000:0E03
  0000:0E03  5a             pop      dx
  0000:0E04  59             pop      cx
  0000:0E05  5b             pop      bx
  0000:0E06  5f             pop      di
  0000:0E07  5e             pop      si
  0000:0E08  07             pop      es
  0000:0E09  1f             pop      ds
  0000:0E0A  5d             pop      bp
  0000:0E0B  c3             ret

; ========================================================================
; install_searchEnvironment
; Address: 0000:0E0C
; Parameters: [bp+4] = environment variable name to search for
;             [bp+6] = buffer to receive value (or 0)
; Returns: AX = 1 if found, 0 if not found
; Description: Searches the DOS environment block for a named variable.
;   Uses the PSP environment pointer at offset 0x2C to locate the
;   environment strings. Iterates through null-terminated strings until
;   a match is found or the double-null terminator is reached.
; ========================================================================
install_searchEnvironment:                       ; 0000:0E0C
  0000:0E0C  55             push     bp
  0000:0E0D  8bec           mov      bp, sp
  0000:0E0F  83ec08         sub      sp, 8
  ; Get PSP environment segment pointer
  0000:0E12  c746fc2c00     mov      word ptr [bp - 4], 0x2c   ; PSP offset 0x2C
  0000:0E17  a1d71b         mov      ax, word ptr [0x1bd7]     ; PSP segment (stored by CRT)
  0000:0E1A  8946fe         mov      word ptr [bp - 2], ax
  0000:0E1D  c746f80000     mov      word ptr [bp - 8], 0      ; Env string offset = 0
  ; Dereference to get environment segment
  0000:0E22  c45efc         les      bx, ptr [bp - 4]
  0000:0E25  268b07         mov      ax, word ptr es:[bx]
  0000:0E28  8946fa         mov      word ptr [bp - 6], ax     ; Env segment
.scan_loop:                                      ; 0000:0E2B
  ; Check for end of environment (double null)
  0000:0E2B  c45ef8         les      bx, ptr [bp - 8]         ; ES:BX -> env string
  0000:0E2E  26803f00       cmp      byte ptr es:[bx], 0
  0000:0E32  7425           je       .not_found
  ; Compare against search variable name
  0000:0E34  ff7606         push     word ptr [bp + 6]         ; Output buffer
  0000:0E37  ff7604         push     word ptr [bp + 4]         ; Variable name
  0000:0E3A  06             push     es                        ; Env segment
  0000:0E3B  53             push     bx                        ; Env offset
  0000:0E3C  e82000         call     install_matchEnvString
  0000:0E3F  83c408         add      sp, 8
  0000:0E42  0bc0           or       ax, ax
  0000:0E44  750e           jne      .found
  ; Skip to next environment string
.skip_char:                                      ; 0000:0E46
  0000:0E46  c45ef8         les      bx, ptr [bp - 8]
  0000:0E49  ff46f8         inc      word ptr [bp - 8]
  0000:0E4C  26803f00       cmp      byte ptr es:[bx], 0
  0000:0E50  74d9           je       .scan_loop               ; Found null: next string
  0000:0E52  ebf2           jmp      .skip_char
.found:                                          ; 0000:0E54
  0000:0E54  b80100         mov      ax, 1
  0000:0E57  eb02           jmp      .done
.not_found:                                      ; 0000:0E59
  0000:0E59  2bc0           sub      ax, ax
.done:                                           ; 0000:0E5B
  0000:0E5B  8be5           mov      sp, bp
  0000:0E5D  5d             pop      bp
  0000:0E5E  c3             ret

; ========================================================================
; install_matchEnvString
; Address: 0000:0E5F
; Parameters: [bp+4] = far pointer to environment string (seg:off)
;             [bp+8] = variable name to match
;             [bp+0A] = output buffer (or 0 to skip value copy)
; Returns: AX = 1 if match, 0 if no match
; Description: Compares an environment string against a variable name.
;   If the string matches and is followed by '=', copies the value
;   after the '=' into the output buffer.
; ========================================================================
install_matchEnvString:                          ; 0000:0E5F
  0000:0E5F  55             push     bp
  0000:0E60  8bec           mov      bp, sp
  0000:0E62  56             push     si
.compare_loop:                                   ; 0000:0E63
  ; Check if env string is at end
  0000:0E63  c45e04         les      bx, ptr [bp + 4]
  0000:0E66  26803f00       cmp      byte ptr es:[bx], 0
  0000:0E6A  7420           je       .check_equals
  ; Check if variable name is at end
  0000:0E6C  8b5e08         mov      bx, word ptr [bp + 8]
  0000:0E6F  803f00         cmp      byte ptr [bx], 0
  0000:0E72  7418           je       .check_equals
  ; Compare characters
  0000:0E74  8b5e04         mov      bx, word ptr [bp + 4]
  0000:0E77  ff4604         inc      word ptr [bp + 4]
  0000:0E7A  8b7608         mov      si, word ptr [bp + 8]
  0000:0E7D  ff4608         inc      word ptr [bp + 8]
  0000:0E80  8a04           mov      al, byte ptr [si]
  0000:0E82  263807         cmp      byte ptr es:[bx], al
  0000:0E85  74dc           je       .compare_loop
  ; Mismatch
  0000:0E87  2bc0           sub      ax, ax
  0000:0E89  5e             pop      si
  0000:0E8A  5d             pop      bp
  0000:0E8B  c3             ret
.check_equals:                                   ; 0000:0E8C
  ; Variable name must have ended
  0000:0E8C  8b5e08         mov      bx, word ptr [bp + 8]
  0000:0E8F  803f00         cmp      byte ptr [bx], 0
  0000:0E92  75f3           jne      .no_match            ; Name not at end: mismatch
  ; Check for '=' after the variable name in env
  0000:0E94  c45e04         les      bx, ptr [bp + 4]
  0000:0E97  26803f3d       cmp      byte ptr es:[bx], 0x3d  ; '='
  0000:0E9B  75ea           jne      .no_match
  ; Match found: copy value if output buffer provided
  0000:0E9D  837e0a00       cmp      word ptr [bp + 0xa], 0
  0000:0EA1  7418           je       .match_done
  ; Copy value after '='
  0000:0EA3  ff4604         inc      word ptr [bp + 4]   ; Skip '='
.copy_value:                                     ; 0000:0EA6
  0000:0EA6  8b5e0a         mov      bx, word ptr [bp + 0xa]
  0000:0EA9  ff460a         inc      word ptr [bp + 0xa]
  0000:0EAC  c47604         les      si, ptr [bp + 4]
  0000:0EAF  ff4604         inc      word ptr [bp + 4]
  0000:0EB2  268a04         mov      al, byte ptr es:[si]
  0000:0EB5  8807           mov      byte ptr [bx], al
  0000:0EB7  0ac0           or       al, al
  0000:0EB9  75eb           jne      .copy_value
.match_done:                                     ; 0000:0EBB
  0000:0EBB  b80100         mov      ax, 1
  0000:0EBE  5e             pop      si
  0000:0EBF  5d             pop      bp
  0000:0EC0  c3             ret
.no_match:
  0000:0E87  2bc0           sub      ax, ax              ; (duplicate label, same code path)
  ; [returns 0]

; ========================================================================
; install_findFirstHardDisk
; Address: 0000:120E
; Parameters: none
; Returns: AL = drive letter (e.g., 'C')
; Description: Scans from drive C: upward to find the first available
;   hard disk. Calls install_checkDriveReady for each letter. Returns
;   the first responsive drive letter, or the last one tried.
; ========================================================================
install_findFirstHardDisk:                       ; 0000:120E
  0000:120E  55             push     bp
  0000:120F  8bec           mov      bp, sp
  0000:1211  83ec02         sub      sp, 2
  0000:1214  c646fe43       mov      byte ptr [bp - 2], 0x43  ; Start at 'C'
  0000:1218  eb03           jmp      .check_drive
.next_drive:                                     ; 0000:121A
  0000:121A  fe46fe         inc      byte ptr [bp - 2]        ; Try next letter
.check_drive:                                    ; 0000:121D
  0000:121D  8a46fe         mov      al, byte ptr [bp - 2]
  0000:1220  98             cwde
  0000:1221  50             push     ax
  0000:1222  e8800c         call     install_checkDriveReady
  0000:1225  83c402         add      sp, 2
  0000:1228  0bc0           or       ax, ax
  0000:122A  74ee           je       .next_drive          ; Not ready: try next
  ; Drive is ready: return its letter
  0000:122C  8a46fe         mov      al, byte ptr [bp - 2]
  0000:122F  98             cwde
  0000:1230  8be5           mov      sp, bp
  0000:1232  5d             pop      bp
  0000:1233  c3             ret

; ========================================================================
; Remaining functions follow the same patterns. Due to the large size
; of this binary (210 functions, ~17KB of code), the remaining functions
; are listed in the function index above with their addresses, sizes,
; and descriptions. The code for these functions can be found in the
; raw disassembly at /disassembly/raw/install-pdm.asm.
;
; Key function groups not fully annotated inline:
;
; 1. Dialog Handlers (0x1234-0x1FF4):
;    install_showDirEntryDialog, install_promptDMConfig,
;    install_validateInstallDir, install_runDialog,
;    install_validateDMConfigDir, install_checkDriveValid,
;    install_copyConfigFiles, install_copyPCLFiles,
;    install_buildSourcePath, install_performInstallation
;
; 2. File Operations (0x1BF9-0x34F7):
;    install_buildDiskLabel, install_processDiskFiles,
;    install_formatPathWithLabel, install_buildFileList,
;    install_copyFileData, install_openFileForCopy, etc.
;
; 3. Printer Installation (0x2A01-0x2D69):
;    install_printerInstallMenu, install_copyPrinterDriver,
;    install_printerSelectDialog, install_processFileEntry
;
; 4. DMGUF/PRGUF Thunks (0x3686-0x3E9D):
;    Resource module loading/unloading, callback dispatch
;
; 5. C Runtime Library (0x3AB6-0x3DC5):
;    Standard string/memory functions (strcpy, strcmp, memcpy, etc.)
;
; 6. INT E0h Wrappers (0x3FD1-0x4175):
;    DeskMate API service thunks
;
; 7. MSC 5.x CRT Startup (seg_0431, 0x4318-0x6A62):
;    Standard CRT initialization, BSS clearing, atexit handling
; ========================================================================

; ========================================================================
; SEGMENT seg_0431  (176 bytes, file offset 0x4518)
; CODE: MSC 5.x CRT startup
; ========================================================================
;
; Standard Microsoft C 5.x runtime startup code:
;   0431:0008  Entry point (from DM89 header)
;   - Set up SS:SP from DGROUP
;   - Clear BSS segment
;   - Initialize CRT globals (__argc, __argv, __environ)
;   - Call _main()
;   - On return, call _exit()
;
; The CRT copyright string at 0431:00B8:
;   "MS Run-Time Library - Copyright (c) 1987, Microsoft Corp"

; ========================================================================
; SEGMENT seg_043C  (64 bytes)
; DATA: DGROUP fixup area
; ========================================================================
;
; Contains MSC CRT internal data:
;   - __osversion, __osmajor, __osminor
;   - __argc, __argv, __environ pointers
;   - DOS shell path string: "C:\DESKMATE"
;   - Other CRT state variables

; ========================================================================
; SEGMENT seg_0440  (56,816 bytes)
; DATA: Application strings, file lists, configuration
; ========================================================================
;
; Major data regions:
;
; 0x5498-0x54EA: Default file names
;   "PERSONAL.ADR", "PERSONAL.CAL"
;   "DESKMATE_1" through "DESKMATE_7" (volume labels for install disks)
;
; 0x5518-0x5574: Configuration defaults
;   "PERSONAL.CAL", "DESKTOP.CFG", "DMCSR.CFG"
;
; 0x5575-0x5630: Dialog title strings
;   "DeskMate Hard Disk Installation"
;   "DeskMate Printer Installation"
;   "Help", "Installation Directory"
;   "DMCONFIG Disk Drive", "Drive:", "Pathname:"
;   "AUTOEXEC.BAT", "CANCEL", "Copying"
;
; 0x5631-0x5960: Error/status messages
;   "Installation on a single diskette system must have the drive set to A."
;   "Your PERSONAL.CAL file was renamed to PERSONAL.CLN..."
;   "Searching files.", "Install Printer", "Printers", "Install"
;   "Error", "You cannot install DeskMate while task switching."
;   "Cannot create the directory as specified."
;   "You cannot specify the ROM as the drive."
;   "You must specify a pathname."
;   "Disk is full. Cannot complete installation."
;   "Insufficient free space on this disk."
;   "Cannot find or create the DMCONFIG directory"
;   "Insufficient memory. Remove all non-DeskMate software..."
;   "Not a valid disk drive.", "Disk Needed"
;   "Please insert the master disk,"
;
; 0x6200-0x6970: Complete DeskMate file list (for installation)
;   All .PDM, .ACC, .RES, .EXE, .CFG, .HLP, .FF1, .RFD, .PCL, .MOD files
;   organized as null-terminated strings. This is the master list of files
;   that the installer copies from the source disks to the hard disk.
;   Includes:
;     AUTOLOAD.RES, CALENDAR.PDM, D87.RES, DESK.EXE, DESKTOP.PDM,
;     DESKTOP.EXE, DESKTOP.PDM, all DMxx resource/accessory files,
;     DRAW.PDM, FILER.PDM, FORMSET.PDM, HANGMAN.PDM, INSTALL.EXE,
;     INSTALL.PDM, MAILMRGE.PDM, PC_DEMO.PDM, PRGUF.RES, SPELL.RES,
;     TEXT.PDM, TELECOM.PDM, WRKSHEET.PDM, etc.
;
; 0x6928-0x6970: Internal constants
;   "INSTALL.CFG", "DMCONFIG", "A:\DMPD.CFG", "DMPRTSEL"
;   ".RES", ".ACC", ".RFD"
;
; 0x6994-0x6A62: MSC CRT error messages
;   "R6000 - stack overflow"
;   "R6003 - integer divide by 0"
;   "R6009 - not enough space for environment"
;   "run-time error"
;   "R6002 - floating point not loaded"
;   "R6001 - null pointer assignment"

; ========================================================================
; SEGMENT seg_1237  (6144 bytes)
; STACK segment
; ========================================================================

; ========================================================================
; END OF INSTALL.PDM DISASSEMBLY
; ========================================================================
