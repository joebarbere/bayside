; ========================================================================
; DMDBRD.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMDBRD.RES is the database read engine for DeskMate 3.05.
; It provides all read-only database operations for .FIL files used by
; Filer, FormSet, and Address Book. This is the largest and most complex
; of the four database RES modules, containing a full Microsoft C runtime,
; heap allocator, and extensive B-tree index traversal logic.
;
; The module manages up to 6 concurrent database "slots" (indexed 0-5),
; where each slot corresponds to a database file open for reading.
; Database records are identified by record_id, with:
;   slot_index = record_id / 100
;   Slot table base = 0xA8 + (slot_index * 16)
;   Database handle at [slot_base + 0xB0]
;
; Read operations include:
;   - Record lookup by ID (exact match and range queries)
;   - Index traversal (B-tree walk for sorted access)
;   - Field extraction from records
;   - Column definition retrieval
;   - Database open/close with file handle management
;   - Record caching via buffer pool
;
; The B-tree index uses 4 "pages" per tree level, with 0x29 (41) entries
; per page. Each index entry is 6 bytes: offset(2) + key_offset(2) +
; record_id(2). The index block size is 0xF6 (246) bytes per page.
;
; Buffer management uses a slot-based system with configurable pool sizes:
;   0x4830 bytes available -> 6 slots, 0x1800 byte buffers (2 quality)
;   0x3680 bytes available -> 4 slots, 0x1000 byte buffers (2 quality)
;   < 0x3680 bytes        -> 2 slots, 0x800 byte buffers  (0 quality)
;
; DM89 imports: Registered as "DMDBRD" via INT E0h AH=02h
;               References "DMDBUPD" and "DMDBBLD" as companion modules
;               Uses "DESKMATE$" device driver signature for host detection
;
; Key host API calls:
;   INT E0h AH=01h  - Register API dispatch (AX=01FFh or 01F0h)
;   INT E0h AH=02h  - Register module name "DMDBRD"
;   INT E0h AH=06h  - Query memory/system info (bit 15 = mode flag)
;   INT E0h AH=4Dh  - PSP save (AX=4D04h) / restore (AX=4D05h)
;
; Cross-module interaction:
;   DMDBRD.RES calls into DMDBUPD and DMDBBLD indirectly through
;   far-call thunks stored at [0x128] (lcall [0x128]).
;   Column definition strings: "cname", "owner", "type", "uniq"
;   Internal column codes: C00H, C00N, N00R, N00V, C00[, N00DBCOLS
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 21,955 bytes
; Load image: 21,443 bytes (after header)
; DM89 entry point: 04C2:018C (CRT startup)
; SS:SP = 053D:0800
;
; Segment Map (5 segments, 21 relocations):
;   seg_0000  19,488 bytes  CODE/DATA  Database engine (129 functions)
;   seg_04C2     608 bytes  CODE       CRT startup, TSR, API dispatch loop
;   seg_04E8      64 bytes  DATA       MSC copyright string
;   seg_04EC   1,283 bytes  DATA       String table, column defs, globals
;   seg_053D     BSS        BSS        Stack + uninitialized data
;
; DM flags: 0x0101 (standard RES module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Database Slot Table (6 slots, 16 bytes each, base at 0xA8):
;   +0x00  (word) slot field 0
;   +0x02  (word) slot field 1
;   +0x04  (word) slot field 2
;   +0x06  (word) buffer segment/pointer
;   +0x08  (word) database handle / file descriptor
;   +0x0A  (word) record list head pointer
;   +0x0C  (word) slot field 6
;   +0x0E  (word) error/status code
;
; Buffer Cache Entry (11 bytes each, array at 0x206):
;   +0x00  (word) cache entry id 0 (file handle or -1 if free)
;   +0x02  (word) cache entry id 1 (record block or -1 if free)
;   +0x04  (word) cache entry id 2 (secondary key)
;   +0x06  (word) buffer pointer (segment of cached data)
;   +0x08  (byte) cache state ('F'=free, 'L'=locked, 'I'=in-use,
;                               'D'=dirty, 'N'=new, 'S'=shared)
;   +0x09  (word) access counter / LRU timestamp
;
; Index B-Tree Node (used in search traversal):
;   Page size = 0xF6 (246) bytes per level
;   Entry size = 6 bytes per entry
;   Entries per page = 0x29 (41)
;   4 tree levels maximum
;   Per entry:
;     +0x28  (word) left child key
;     +0x2A  (word) right child key
;     +0x2C  (word) record_id
;
; Record Header (at index node data pointer):
;   +0x00  (byte) record type/flags (bit 7 = deleted)
;   +0x01  (byte) record length low byte
;   +0x02..  record data (field values)
;
; Database Control Block (pointed to by buffer pointer):
;   +0x0C  (byte[5]) index column references
;   +0x11  (word) root index page
;   +0x13  (byte) database flags
;   +0x14  (byte) index type flag (0=primary, nonzero=secondary)
;   +0x15  (word) column definition list pointer
;   +0x17  (word) next record pointer (linked list)
;   +0x19  (word) secondary index pointer
;   +0x1E  (word) B-tree overflow link
;   +0x2C  (word) record data (at index entry level)
;   +0x2E  (word) status flags
;
; Global Variables (in seg_04EC / seg_0000 data area):
;   [0x009F]  (byte) INT E0h registration token (0xFF if unregistered)
;   [0x010E]  (byte) saved PSP token for re-entrant calls
;   [0x010F]  (word) main dispatch function pointer (malloc'd buffer)
;   [0x0113]  (word) secondary dispatch parameter pointer
;   [0x0115]  (word) work buffer pointer (0x400 bytes)
;   [0x0117]  (byte) quality level (0, 1, or 2)
;   [0x0128]  (dword) far-call thunk address for cross-module calls
;   [0x0200]  (word) extended buffer pointer
;   [0x0202]  (word) extended buffer size
;   [0x0204]  (word) free memory list head
;   [0x0206]  (11*N bytes) buffer cache entry table
;   [0x024A]  (word) number of active buffer cache slots (2, 4, or 6)
;   [0x0248]  (word) page buffer pool pointer
;   [0x0258]  (word) saved PSP segment (for TSR re-entry)
;   [0x025A]  (word) caller's PSP segment
;   [0x032A]  (word) monotonic access counter (for LRU tracking)
;   [0x0338]  (word) callback function pointer (for CRT error handler)
;
; Error Codes (return values):
;   0x0000  Success
;   0xFFC5  (-59)  Invalid sentinel / magic mismatch (0xABCD check)
;   0xFFCF  (-49)  Continue / retry (loop sentinel in dispatch)
;   0xFFD3  (-45)  Null handle / no database open
;   0xFFD9  (-39)  Record not modified (clean)
;   0xFFDC  (-36)  No records / database empty
;   0xFFDE  (-34)  Record count exceeds limit
;   0xFFE2  (-30)  Invalid record ID / slot not found
;   0xFFE3  (-29)  Record locked / in use
;   0xFFF0  (-16)  Memory allocation failed
;   0xFFF1  (-15)  Invalid column reference
;   0xFFF4  (-12)  Index read failure / block not found
;   0xFFF5  (-11)  Record not found (search exhausted)
;   0xFFF7  (-9)   End of index (forward)
;   0xFFF8  (-8)   End of index (backward)
;   0xFFF9  (-7)   Column definition error
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Memory Management (CRT heap) ---
; sub_0000_002D  dmdbrd_initBufferPool      Probe available memory, allocate pools
; sub_0000_0213  dmdbrd_initCacheTable       Initialize buffer cache entries (2/4/6 slots)
; sub_0000_3CC6  dmdbrd_heapAlloc            Allocate memory from internal heap
; sub_0000_3D81  dmdbrd_heapFree             Free heap-allocated memory
; sub_0000_4930  dmdbrd_markBlockUsed        Mark memory block header as in-use
; sub_0000_4942  dmdbrd_malloc               C runtime malloc() wrapper
; sub_0000_49B5  dmdbrd_mallocCore           Core heap allocator (first-fit)
; sub_0000_4A98  dmdbrd_heapExtend           Extend heap by allocating new DOS segment
; sub_0000_4AD2  dmdbrd_heapGrow             Grow heap arena via INT 21h/4Ah
; sub_0000_4AF4  dmdbrd_sbrk                 Request memory from DOS (sbrk equivalent)
; sub_0000_4B68  dmdbrd_sbrkDispatch         Dispatch sbrk by mode (near/far heap)
; sub_0000_4BD6  dmdbrd_findArena            Find arena entry for given segment
; sub_0000_48EE  dmdbrd_heapResize           Resize heap block via INT 21h/4Ah
; sub_0000_4988  dmdbrd_free                 C runtime free() -> jumps to free core
;
; --- Slot / Record ID Management ---
; sub_0000_01D8  dmdbrd_findRecordById       Find record node by record_id in slot chain
; sub_0000_025C  dmdbrd_validateSlot         Validate slot index (0-5) and check handle
;
; --- Database Open / Close ---
; sub_0000_1615  dmdbrd_openDatabase         Open .FIL database file for a slot
; sub_0000_1646  dmdbrd_openDatabaseStep2    Secondary open step (index loading)
; sub_0000_18C3  dmdbrd_closeAllDatabases    Close all 6 database slots
; sub_0000_185C  dmdbrd_closeDatabaseSlot    Close a single database slot
; sub_0000_187F  dmdbrd_closeSlotResources   Release slot resources (buffers, handles)
; sub_0000_188D  dmdbrd_closeSlotFiles       Close file handles for slot
; sub_0000_18A4  dmdbrd_closeSlotIndexes     Close index structures for slot
; sub_0000_18C3  dmdbrd_shutdownAll          Shutdown all databases on module unload
; sub_0000_18CA  dmdbrd_releaseResources     Release allocated resources (chain walk)
; sub_0000_18D8  dmdbrd_freeSlotChain        Free linked list of records in a slot
; sub_0000_18F6  dmdbrd_freeFileEntry        Free a file entry node
; sub_0000_1913  dmdbrd_freeSubchain1        Free sub-chain type 1
; sub_0000_1929  dmdbrd_freeSubchain2        Free sub-chain type 2
; sub_0000_1947  dmdbrd_freeSubchain3        Free sub-chain type 3
; sub_0000_1964  dmdbrd_freeNode             Free a linked list node
; sub_0000_1973  dmdbrd_freeRecordTree       Free entire record tree recursively
;
; --- Index / B-Tree Operations ---
; sub_0000_1C9E  dmdbrd_getIndexRoot         Get root page of B-tree index
; sub_0000_1CB7  dmdbrd_readIndexPage        Read one B-tree page from disk
; sub_0000_1CC6  dmdbrd_traverseIndex        Traverse B-tree from root to leaf
; sub_0000_1D66  dmdbrd_loadIndexBlock       Load an index block into memory
; sub_0000_1F44  dmdbrd_readRecord           Read a complete record from database
; sub_0000_223F  dmdbrd_readRecordByKey      Read record by index key (main query)
; sub_0000_2A5C  dmdbrd_readRecordDirect     Read record directly by file offset
; sub_0000_2B07  dmdbrd_readRecordData       Read raw record data bytes
; sub_0000_2C1F  dmdbrd_closeFileHandle      Close a file descriptor
; sub_0000_2C6C  dmdbrd_readRecordFields     Read and parse record field data
; sub_0000_2D2D  dmdbrd_parseRecordBuffer    Parse record from buffer into fields
;
; --- Record Search (Sequential and Indexed) ---
; sub_0000_0294  dmdbrd_dispatchQuery        Main query dispatcher (handles cmd 0x0B-0x11)
; sub_0000_05FD  dmdbrd_searchByColumn       Search database by column value
; sub_0000_07C2  dmdbrd_searchWithIndex      Search using B-tree index (binary search)
; sub_0000_0974  dmdbrd_searchIndexForward    Search index forward (cmd 0x0B)
; sub_0000_0B41  dmdbrd_searchIndexBackward   Search index backward (cmd 0x0C)
; sub_0000_0D1D  dmdbrd_searchContinue       Continue search from current position
; sub_0000_0EA6  dmdbrd_compareRecord        Compare record field against search value
; sub_0000_0FB0  dmdbrd_compareFieldValue    Compare a single field value
; sub_0000_104A  dmdbrd_findFirstEntry       Find first non-empty entry in index page
; sub_0000_1079  dmdbrd_searchForwardScan    Forward sequential scan through records
; sub_0000_127B  dmdbrd_executeQuery         Execute a database query (filter+sort)
; sub_0000_13FF  dmdbrd_sortResultSet        Sort query result set
; sub_0000_1486  dmdbrd_scanSequential       Sequential scan without index
;
; --- Field / Column Operations ---
; sub_0000_15D6  dmdbrd_copyFieldData        Copy field data between buffers
; sub_0000_15F1  dmdbrd_getFieldLength       Get length of a field value
; sub_0000_160E  dmdbrd_getFieldOffset       Get offset of field within record
; sub_0000_1634  dmdbrd_countFields          Count number of fields in record
;
; --- Buffer Cache Operations ---
; sub_0000_3A87  dmdbrd_setCacheState        Set cache entry state byte (L/I/F/D/N/S)
; sub_0000_3ACB  dmdbrd_lookupCacheEntry     Look up cached data for a block
; sub_0000_3B1D  dmdbrd_readBlock            Read block into cache (allocate if needed)
; sub_0000_3B83  dmdbrd_readBlockChain       Follow directory chain reading blocks
; sub_0000_3C28  dmdbrd_resetAccessCounters  Reset LRU counters when they overflow
; sub_0000_3C8E  dmdbrd_findCacheSlot        Find cache slot for given handle+block pair
; sub_0000_390E  dmdbrd_allocateCacheSlot    Allocate a new cache slot (evict LRU)
; sub_0000_33AC  dmdbrd_flushDirtyBlocks     Flush dirty cache entries to disk
;
; --- File I/O Wrappers ---
; sub_0000_34BE  dmdbrd_openFile             Open file and read header
; sub_0000_3474  dmdbrd_readFileHeader       Read and validate file header bytes
; sub_0000_3591  dmdbrd_readFileBlock        Read a data block from file
; sub_0000_3604  dmdbrd_readBlockDirect      Read block at specific file offset
; sub_0000_365D  dmdbrd_seekAndRead          Seek to position and read data
; sub_0000_3702  dmdbrd_writeBlock           Write a data block to file
; sub_0000_3724  dmdbrd_seekToOffset         Seek file to specific offset
; sub_0000_3745  dmdbrd_readBytes            Read N bytes from current position
; sub_0000_3798  dmdbrd_buildFilePath        Build full file path from components
; sub_0000_37C8  dmdbrd_buildFullPath        Build full path with drive + directory
; sub_0000_3866  dmdbrd_validateDatabase     Validate database file integrity
; sub_0000_30E0  dmdbrd_readIndexTree        Read entire index tree structure
; sub_0000_3051  dmdbrd_readIndexHeader      Read index file header
; sub_0000_2FF8  dmdbrd_readColumnDefs       Read column definition table
; sub_0000_2FD6  dmdbrd_writeBackBlock       Write modified block back to file
; sub_0000_2F57  dmdbrd_closeRecordChain     Close and free a record's resource chain
; sub_0000_2ED6  dmdbrd_freeSlotBuffers      Free all buffers for a slot
; sub_0000_2E95  dmdbrd_freeFieldChain       Free linked list of field nodes
; sub_0000_2E35  dmdbrd_freeRecordNode       Free a single record node and its fields
; sub_0000_2DE6  dmdbrd_extractRecordData    Extract record data from block buffer
;
; --- String / Data Utilities ---
; sub_0000_41B6  dmdbrd_readFieldString      Read field as string from record data
; sub_0000_41E3  dmdbrd_readFieldNumeric     Read field as numeric from record data
; sub_0000_41F9  dmdbrd_readBlockData        Read data section of a block
; sub_0000_411E  dmdbrd_readBlockSection     Read a section within a block
; sub_0000_414A  dmdbrd_readBlockFields      Read field definitions from block
; sub_0000_417B  dmdbrd_seekInBlock          Seek to position within a block
; sub_0000_425F  dmdbrd_stringLength         Calculate string length (strlen)
; sub_0000_427E  dmdbrd_openSlotFile         Open the file for a slot's database
; sub_0000_42C8  dmdbrd_seekToRecord         Seek to record position in file
; sub_0000_4302  dmdbrd_readRecordHeader     Read record header bytes
; sub_0000_4324  dmdbrd_copyString           Copy string (strcpy)
; sub_0000_432C  dmdbrd_appendString         Append string (strcat-like)
; sub_0000_4334  dmdbrd_compareStrings       Compare strings (strcmp-like)
; sub_0000_435B  dmdbrd_fillMemory           Fill memory block (memset)
; sub_0000_4375  dmdbrd_copyMemory           Copy memory block (memcpy)
; sub_0000_438C  dmdbrd_getCurrentDrive      Get current drive letter
; sub_0000_439C  dmdbrd_dosFileOpen          DOS file open (INT 21h/3Dh)
; sub_0000_43AB  dmdbrd_dosFileCreate        DOS file create (INT 21h/3Ch)
; sub_0000_43D3  dmdbrd_dosFileClose         DOS file close (INT 21h/3Eh)
; sub_0000_4409  dmdbrd_dosFileRead          DOS file read (INT 21h/3Fh)
; sub_0000_441F  dmdbrd_dosFileWrite         DOS file write (INT 21h/40h)
; sub_0000_4563  dmdbrd_dosFileSeek          DOS file seek (INT 21h/42h)
; sub_0000_45D9  dmdbrd_getFileSize          Get file size via seek-to-end
; sub_0000_45F9  dmdbrd_dosDeleteFile        DOS delete file (INT 21h/41h)
; sub_0000_498C  dmdbrd_toupper              Convert character to uppercase
; sub_0000_49A6  dmdbrd_shiftLeft            Shift DX:AX left by CL bits
;
; --- Expression / Filter Evaluation ---
; sub_0000_3E06  dmdbrd_evaluateFilter       Evaluate filter expression on record
; sub_0000_3E40  dmdbrd_getRecordField       Get a specific field from record buffer
; sub_0000_3E58  dmdbrd_getNextIndexEntry    Get next entry in index traversal
; sub_0000_3EAA  dmdbrd_getFirstIndexEntry   Get first entry for index start
; sub_0000_3ED2  dmdbrd_getLastIndexEntry    Get last entry for index end
; sub_0000_3F01  dmdbrd_lookupColumn         Look up column by type code
; sub_0000_3F27  dmdbrd_compareNumeric       Compare two numeric values
; sub_0000_3F61  dmdbrd_compareString        Compare two string values
; sub_0000_3F9F  dmdbrd_parseFieldValue      Parse field value from raw data
;
; --- CRT / Checksum ---
; sub_0000_46C4  dmdbrd_crtErrorHandler      CRT runtime error handler
; sub_0000_46EA  dmdbrd_checksumVerify       Verify 66-byte checksum (XOR 0x55)
; sub_0000_489A  dmdbrd_lookupErrorMsg       Look up runtime error message by code
; sub_0000_48C5  dmdbrd_printErrorMsg        Print error message to stderr (fd 2)
; sub_0000_4B14  dmdbrd_atol                 Convert string to long (atol)
;
; --- Entry Point / TSR / Dispatch ---
; entry_point     (04C2:018C)  CRT startup (DOS version check, resize, BSS zero)
; sub_04C2_0000   (04C2:0000)  Cross-segment jump target / memory return
; sub_04C2_002B   (04C2:002B)  API init: save SS:SP, INT E0h register, far-call init
; sub_04C2_0072   (04C2:0072)  Re-entrant API entry: save/restore SS:SP + PSP swap
; sub_04C2_00BB   (04C2:00BB)  Re-entrant flag check + nested call entry
; sub_04C2_0136   (04C2:0136)  Main dispatch loop: call function ptr, loop on 0xFFCF
; sub_04C2_024D   (04C2:024D)  Get PSP allocation size for TSR
;
; ========================================================================
; CODE / DATA
; ========================================================================

; ========================================================================
; SEGMENT seg_0000  (19,488 bytes, file 0x0200-0x4E20)
; Database engine: 129 functions, all read operations
; ========================================================================
seg_0000:

; --- First 16 bytes: zero-filled data area (global state) ---
  0000:0000  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|

; --- Inline validation check (not a full function) ---
; Tests [0x117] (quality level) >= 2, increments [0x252], checks if == 1
; Returns 0xFFC7 or 0xFFC6 on failure, 0 on success
  0000:0010  db 80 3E 17 01 02 7D 13 FF 06 52 02 83 3E 52 02 01 ; |.>...}...R..>R..|
  0000:0020  db 75 04 B8 C7 FF C3 B8 C6 FF C3 2B C0 C3          ; |u.........+..|

; ========================================================================
; dmdbrd_initBufferPool (0000:002D)
; Probes available memory in decreasing block sizes (0x4830, 0x3680,
; 0x1EC0) to determine how many buffer cache slots to allocate.
; Allocates via dmdbrd_malloc and marks blocks as used.
; Sets quality level [0x117] and slot count [0x24A].
; Returns: AX = largest block size found, or 0 on failure
; ========================================================================
dmdbrd_initBufferPool:  ; sub_0000_002D
  0000:002D  55                push     bp
  0000:002E  8bec              mov      bp, sp
  0000:0030  83ec04            sub      sp, 4           ; local: [bp-2]=block_size, [bp-4]=ptr
  0000:0033  eb2e              jmp      .try_largest    ; -> try 0x4830 first

.try_1EC0:  ; loc_0000_0035
  0000:0035  817efec01e        cmp      word ptr [bp - 2], 0x1ec0
  0000:003A  7504              jne      .try_3680
  0000:003C  2bc0              sub      ax, ax          ; all sizes exhausted -> return 0
  0000:003E  eb73              jmp      .return

.try_3680:  ; loc_0000_0040
  0000:0040  817efe8036        cmp      word ptr [bp - 2], 0x3680
  0000:0045  7507              jne      .check_3680b
  0000:0047  c746fec01e        mov      word ptr [bp - 2], 0x1ec0  ; try smaller
  0000:004C  eb1a              jmp      .try_alloc

.check_3680b:  ; loc_0000_004E
  0000:004E  817efe8036        cmp      word ptr [bp - 2], 0x3680
  0000:0053  7507              jne      .check_4830

.set_3680:  ; loc_0000_0055
  0000:0055  c746fe8036        mov      word ptr [bp - 2], 0x3680
  0000:005A  eb0c              jmp      .try_alloc

.check_4830:  ; loc_0000_005C
  0000:005C  817efe3048        cmp      word ptr [bp - 2], 0x4830
  0000:0061  74f2              je       .set_3680

.try_largest:  ; loc_0000_0063
  0000:0063  c746fe3048        mov      word ptr [bp - 2], 0x4830  ; start with largest

.try_alloc:  ; loc_0000_0068
  0000:0068  ff76fe            push     word ptr [bp - 2]
  0000:006B  e8d448            call     dmdbrd_malloc   ; -> sub_0000_4942
  0000:006E  83c402            add      sp, 2
  0000:0071  8946fc            mov      word ptr [bp - 4], ax
  0000:0074  0bc0              or       ax, ax
  0000:0076  74bd              je       .try_1EC0       ; allocation failed, try smaller
  0000:0078  50                push     ax
  0000:0079  e8b448            call     dmdbrd_markBlockUsed  ; -> sub_0000_4930
  0000:007C  83c402            add      sp, 2
  0000:007F  817efe2958        cmp      word ptr [bp - 2], 0x5829
  0000:0084  751c              jne      .probe_up

.found:  ; loc_0000_0086
  0000:0086  8b46fe            mov      ax, word ptr [bp - 2]  ; return allocated size
  0000:0089  eb28              jmp      .return

.try_next_up:  ; loc_0000_008B
  0000:008B  ff76fe            push     word ptr [bp - 2]
  0000:008E  e8b148            call     dmdbrd_malloc
  0000:0091  83c402            add      sp, 2
  0000:0094  8946fc            mov      word ptr [bp - 4], ax
  0000:0097  0bc0              or       ax, ax
  0000:0099  7412              je       .shrink_back    ; can't allocate more
  0000:009B  50                push     ax
  0000:009C  e89148            call     dmdbrd_markBlockUsed
  0000:009F  83c402            add      sp, 2

.probe_up:  ; loc_0000_00A2
  0000:00A2  8346fe10          add      word ptr [bp - 2], 0x10  ; try 16 more bytes
  0000:00A6  817efe3048        cmp      word ptr [bp - 2], 0x4830
  0000:00AB  7cde              jl       .try_next_up

.shrink_back:  ; loc_0000_00AD
  0000:00AD  836efe10          sub      word ptr [bp - 2], 0x10
  0000:00B1  ebd3              jmp      .found

.return:  ; loc_0000_00B3
  0000:00B3  8be5              mov      sp, bp
  0000:00B5  5d                pop      bp
  0000:00B6  c3                ret

; ========================================================================
; dmdbrd_initSystem (0000:00B7)
; Called after initBufferPool to configure the system based on available
; memory. Sets quality level [0x117], slot count [0x24A], and allocates
; the 4 core buffers: work buffer (0x400), dispatch table (0xBCB),
; page buffer pool, and extended buffer.
; Calls dmdbrd_initCacheTable to initialize cache entries.
; Returns: AX = 0 on success, 0xFFF0 on memory failure
; ========================================================================
dmdbrd_initSystem:  ; at 0000:00B7
  0000:00B7  55                push     bp
  0000:00B8  8bec              mov      bp, sp
  0000:00BA  83ec04            sub      sp, 4           ; [bp-4]=total_mem, [bp-2]=page_size
  0000:00BD  e86dff            call     dmdbrd_initBufferPool
  0000:00C0  8946fc            mov      word ptr [bp - 4], ax
  0000:00C3  0bc0              or       ax, ax
  0000:00C5  7506              jne      .got_memory

.no_memory:  ; loc_0000_00C7
  0000:00C7  b8f0ff            mov      ax, 0xfff0      ; -16: memory alloc failed
  0000:00CA  e9b300            jmp      .done

.got_memory:  ; loc_0000_00CD
  ; Determine configuration based on available memory
  0000:00CD  817efc3048        cmp      word ptr [bp - 4], 0x4830  ; 18,480 bytes?
  0000:00D2  7512              jne      .check_3680
  0000:00D4  c746fe0018        mov      word ptr [bp - 2], 0x1800  ; page_size = 6144
  0000:00D9  c7064a020600      mov      word ptr [0x24a], 6        ; 6 cache slots

.set_quality_2:  ; loc_0000_00DF
  0000:00DF  c606170102        mov      byte ptr [0x117], 2        ; quality = 2 (best)
  0000:00E4  eb3d              jmp      .calc_extended

.check_3680:  ; loc_0000_00E6
  0000:00E6  817efc8036        cmp      word ptr [bp - 4], 0x3680  ; 13,952 bytes?
  0000:00EB  7c0d              jl       .check_small
  0000:00ED  c746fe0010        mov      word ptr [bp - 2], 0x1000  ; page_size = 4096
  0000:00F2  c7064a020400      mov      word ptr [0x24a], 4        ; 4 cache slots
  0000:00F8  ebe5              jmp      .set_quality_2

.check_small:  ; loc_0000_00FA
  0000:00FA  817efc8036        cmp      word ptr [bp - 4], 0x3680
  0000:00FF  7c12              jl       .use_minimum
  0000:0101  c746fe0010        mov      word ptr [bp - 2], 0x1000
  0000:0106  c7064a020400      mov      word ptr [0x24a], 4
  0000:010C  c606170101        mov      byte ptr [0x117], 1        ; quality = 1 (medium)
  0000:0111  eb10              jmp      .calc_extended

.use_minimum:  ; loc_0000_0113
  0000:0113  c746fe0008        mov      word ptr [bp - 2], 0x800   ; page_size = 2048
  0000:0118  c7064a020200      mov      word ptr [0x24a], 2        ; 2 cache slots
  0000:011E  c606170100        mov      byte ptr [0x117], 0        ; quality = 0 (minimum)

.calc_extended:  ; loc_0000_0123
  ; extended_size = total_mem - page_size - 0x100B
  0000:0123  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0126  2b46fe            sub      ax, word ptr [bp - 2]
  0000:0129  2d0b10            sub      ax, 0x100b
  0000:012C  a30202            mov      word ptr [0x202], ax       ; extended buffer size

  ; Allocate work buffer (0x400 = 1024 bytes)
  0000:012F  b80004            mov      ax, 0x400
  0000:0132  50                push     ax
  0000:0133  e80c48            call     dmdbrd_malloc
  0000:0136  83c402            add      sp, 2
  0000:0139  a31501            mov      word ptr [0x115], ax       ; work buffer ptr
  0000:013C  0bc0              or       ax, ax
  0000:013E  7487              je       .no_memory

  ; Allocate dispatch/function table (0xBCB = 3019 bytes)
  0000:0140  b8cb0b            mov      ax, 0xbcb
  0000:0143  50                push     ax
  0000:0144  e8fb47            call     dmdbrd_malloc
  0000:0147  83c402            add      sp, 2
  0000:014A  a30f01            mov      word ptr [0x10f], ax       ; dispatch table ptr
  0000:014D  0bc0              or       ax, ax
  0000:014F  7503              jne      .alloc_page_buf
  0000:0151  e973ff            jmp      .no_memory

.alloc_page_buf:  ; loc_0000_0154
  ; Allocate page buffer pool
  0000:0154  ff76fe            push     word ptr [bp - 2]
  0000:0157  e8e847            call     dmdbrd_malloc
  0000:015A  83c402            add      sp, 2
  0000:015D  a34802            mov      word ptr [0x248], ax       ; page buffer pool
  0000:0160  0bc0              or       ax, ax
  0000:0162  7503              jne      .alloc_extended
  0000:0164  e960ff            jmp      .no_memory

.alloc_extended:  ; loc_0000_0167
  ; Allocate extended buffer
  0000:0167  ff360202          push     word ptr [0x202]
  0000:016B  e8d447            call     dmdbrd_malloc
  0000:016E  83c402            add      sp, 2
  0000:0171  a30002            mov      word ptr [0x200], ax       ; extended buffer ptr
  0000:0174  0bc0              or       ax, ax
  0000:0176  7503              jne      .init_cache
  0000:0178  e94cff            jmp      .no_memory

.init_cache:  ; loc_0000_017B
  0000:017B  e89500            call     dmdbrd_initCacheTable
  0000:017E  2bc0              sub      ax, ax          ; return 0 (success)

.done:  ; loc_0000_0180
  0000:0180  8be5              mov      sp, bp
  0000:0182  5d                pop      bp
  0000:0183  c3                ret

; ========================================================================
; dmdbrd_cleanupSlots (0000:0184)
; Far-callable function that iterates all 6 slots, checks each database
; handle at [slot_base + 0xB0]. For open databases, calls
; dmdbrd_dosFileOpen to verify the handle, then dmdbrd_openDatabase
; if the handle is stale. Called during re-entrant API entry.
; Returns: AX = 0 (always succeeds)
; ========================================================================
dmdbrd_cleanupSlots:  ; at 0000:0184
  0000:0184  55                push     bp
  0000:0185  8bec              mov      bp, sp
  0000:0187  83ec04            sub      sp, 4
  0000:018A  57                push     di
  0000:018B  56                push     si
  0000:018C  2bf6              sub      si, si          ; si = slot_index = 0

.loop:  ; loc_0000_018E
  0000:018E  8bde              mov      bx, si
  0000:0190  b104              mov      cl, 4
  0000:0192  d3e3              shl      bx, cl          ; bx = slot_index * 16
  0000:0194  8bbfb000          mov      di, word ptr [bx + 0xb0]  ; di = db_handle
  0000:0198  0bff              or       di, di
  0000:019A  7c1a              jl       .next_slot      ; handle < 0 -> slot unused
  ; Try to validate handle via dosFileOpen
  0000:019C  57                push     di
  0000:019D  b81101            mov      ax, 0x111
  0000:01A0  50                push     ax
  0000:01A1  e8f841            call     dmdbrd_dosFileOpen  ; -> sub_0000_439C
  0000:01A4  83c404            add      sp, 4
  0000:01A7  0bc0              or       ax, ax
  0000:01A9  7d0b              jge      .next_slot      ; handle still valid
  ; Handle is stale, re-open the database
  0000:01AB  57                push     di
  0000:01AC  b81101            mov      ax, 0x111
  0000:01AF  50                push     ax
  0000:01B0  e86214            call     dmdbrd_openDatabase  ; -> sub_0000_1615
  0000:01B3  83c404            add      sp, 4

.next_slot:  ; loc_0000_01B6
  0000:01B6  46                inc      si
  0000:01B7  83fe06            cmp      si, 6
  0000:01BA  7cd2              jl       .loop
  0000:01BC  e80417            call     dmdbrd_closeAllDatabases  ; -> sub_0000_18C3
  0000:01BF  2bc0              sub      ax, ax
  0000:01C1  5e                pop      si
  0000:01C2  5f                pop      di
  0000:01C3  8be5              mov      sp, bp
  0000:01C5  5d                pop      bp
  0000:01C6  cb                retf

  ; --- Inline far-call stub (0000:01C7) ---
  ; Calls dmdbrd_initBufferPool, returns 0xFFF0 on failure, else
  ; calls sub_0000_18CA and returns 0. Used during module init.
  0000:01C7  db E8 ED FE 0B C0 7D 04 B8 F0 FF CB E8 E1 18 2B C0
  0000:01D7  db CB

; ========================================================================
; dmdbrd_findRecordById (0000:01D8)
; Given a record_id, computes the slot index (id / 100), then walks the
; linked list of records in that slot to find the matching record node.
; Parameters: [bp+4] = record_id (word)
; Returns: AX = pointer to record node, or 0 if not found
; ========================================================================
dmdbrd_findRecordById:  ; sub_0000_01D8
  0000:01D8  55                push     bp
  0000:01D9  8bec              mov      bp, sp
  0000:01DB  83ec04            sub      sp, 4
  0000:01DE  57                push     di
  0000:01DF  56                push     si
  0000:01E0  8b4604            mov      ax, word ptr [bp + 4]  ; record_id
  0000:01E3  99                cdq
  0000:01E4  b96400            mov      cx, 0x64        ; 100
  0000:01E7  f7f9              idiv     cx              ; ax = slot_index
  0000:01E9  8bf8              mov      di, ax
  0000:01EB  b104              mov      cl, 4
  0000:01ED  d3e7              shl      di, cl          ; di = slot_index * 16
  0000:01EF  81c7a800          add      di, 0xa8        ; di = slot table entry
  0000:01F3  8b750a            mov      si, word ptr [di + 0xa]  ; si = record list head

.walk:  ; loc_0000_01FB
  0000:01FB  0bf6              or       si, si
  0000:01FD  740c              je       .not_found
  0000:01FF  8b4604            mov      ax, word ptr [bp + 4]
  0000:0202  394402            cmp      word ptr [si + 2], ax  ; compare record_id
  0000:0205  75f1              jne      .next           ; -> loc_0000_01F8
  0000:0207  8bc6              mov      ax, si          ; found -> return pointer
  0000:0209  eb02              jmp      .done

.next:  ; loc_0000_01F8
  0000:01F8  8b7417            mov      si, word ptr [si + 0x17]  ; next in chain

  jmp      .walk                                        ; (implicit from flow)

.not_found:  ; loc_0000_020B
  0000:020B  2bc0              sub      ax, ax          ; return 0

.done:  ; loc_0000_020D
  0000:020D  5e                pop      si
  0000:020E  5f                pop      di
  0000:020F  8be5              mov      sp, bp
  0000:0211  5d                pop      bp
  0000:0212  c3                ret

; ========================================================================
; dmdbrd_initCacheTable (0000:0213)
; Initializes the buffer cache entry table at [0x206].
; Each entry is 11 bytes. Number of entries = [0x24A] (2, 4, or 6).
; Each entry gets: handle=-1, block=-1, key=0, offset=0,
;   buffer_ptr = [0x248] + (index * 1024), state='F' (free)
; ========================================================================
dmdbrd_initCacheTable:  ; sub_0000_0213
  0000:0213  55                push     bp
  0000:0214  8bec              mov      bp, sp
  0000:0216  83ec04            sub      sp, 4
  0000:0219  57                push     di
  0000:021A  56                push     si
  0000:021B  2bf6              sub      si, si          ; si = entry index

.loop:  ; loc_0000_024C
  0000:024C  8bc6              mov      ax, si
  0000:024E  3b064a02          cmp      ax, word ptr [0x24a]  ; num_slots
  0000:0252  72cb              jb       .init_entry     ; -> loc_0000_021F
  0000:0254  2bc0              sub      ax, ax
  0000:0256  5e                pop      si
  0000:0257  5f                pop      di
  0000:0258  8be5              mov      sp, bp
  0000:025A  5d                pop      bp
  0000:025B  c3                ret

.init_entry:  ; loc_0000_021F
  0000:021F  b80b00            mov      ax, 0xb         ; 11 bytes per entry
  0000:0222  f7ee              imul     si
  0000:0224  8bf8              mov      di, ax
  0000:0226  81c70602          add      di, 0x206       ; di -> cache entry
  0000:022A  b8ffff            mov      ax, 0xffff
  0000:022D  8905              mov      word ptr [di], ax        ; handle = -1
  0000:022F  894502            mov      word ptr [di + 2], ax    ; block = -1
  0000:0232  2bc0              sub      ax, ax
  0000:0234  894509            mov      word ptr [di + 9], ax    ; access_counter = 0
  0000:0237  894504            mov      word ptr [di + 4], ax    ; key = 0
  ; buffer_ptr = page_pool_base + (index << 10)
  0000:023A  8bc6              mov      ax, si
  0000:023C  b10a              mov      cl, 0xa         ; * 1024
  0000:023E  d3e0              shl      ax, cl
  0000:0240  03064802          add      ax, word ptr [0x248]
  0000:0244  894506            mov      word ptr [di + 6], ax    ; buffer_ptr
  0000:0247  c6450846          mov      byte ptr [di + 8], 0x46  ; state = 'F' (free)
  0000:024B  46                inc      si
  jmp      .loop                                        ; (implicit: falls to 024C)

; ========================================================================
; dmdbrd_validateSlot (0000:025C)
; Validates a record_id by checking its slot_index is 0-5 and the
; database handle at [slot_base + 0xB0] is non-negative.
; Parameters: [bp+4] = record_id (word)
; Returns: AX = 0 if valid, 1 if invalid
; ========================================================================
dmdbrd_validateSlot:  ; sub_0000_025C
  0000:025C  55                push     bp
  0000:025D  8bec              mov      bp, sp
  0000:025F  83ec02            sub      sp, 2
  0000:0262  56                push     si
  0000:0263  8b7604            mov      si, word ptr [bp + 4]  ; record_id
  0000:0266  8bc6              mov      ax, si
  0000:0268  99                cdq
  0000:0269  b96400            mov      cx, 0x64
  0000:026C  f7f9              idiv     cx              ; ax = slot_index
  0000:026E  8946fe            mov      word ptr [bp - 2], ax
  0000:0271  0bc0              or       ax, ax
  0000:0273  7c12              jl       .invalid        ; slot < 0
  0000:0275  3d0600            cmp      ax, 6
  0000:0278  7d0d              jge      .invalid        ; slot >= 6
  0000:027A  8bd8              mov      bx, ax
  0000:027C  b104              mov      cl, 4
  0000:027E  d3e3              shl      bx, cl
  0000:0280  83bfb00000        cmp      word ptr [bx + 0xb0], 0  ; db_handle
  0000:0285  7d05              jge      .valid

.invalid:  ; loc_0000_0287
  0000:0287  b80100            mov      ax, 1
  0000:028A  eb02              jmp      .done

.valid:  ; loc_0000_028C
  0000:028C  2bc0              sub      ax, ax

.done:  ; loc_0000_028E
  0000:028E  5e                pop      si
  0000:028F  8be5              mov      sp, bp
  0000:0291  5d                pop      bp
  0000:0292  c3                ret

; [padding byte]
  0000:0293  db 90

; ========================================================================
; dmdbrd_dispatchQuery (0000:0294)
; Main query dispatcher. Accepts a command code in [bp+4] and routes
; to the appropriate search/read function. Commands:
;   0x0B = search forward (first match)
;   0x0C = search forward (next match)
;   0x0D = search backward (first match)
;   0x0E = search backward (next match)
;   0x11 = search by column value
; Parameters:
;   [bp+4] = command code
;   [bp+6] = database context pointer
;   [bp+8] = query parameters pointer
; Returns: AX = result code (0=success, negative=error)
; ========================================================================
; This is a very large function (0x0294 - 0x05FC, ~872 bytes).
; It validates the slot, opens the file, calls sub-functions based on
; the command, and handles retry logic with index continuation.
; Due to size, only the dispatcher skeleton is annotated here.
; See raw disassembly for full instruction-by-instruction listing.
; ========================================================================
dmdbrd_dispatchQuery:  ; sub_0000_0294 (inline, not labeled as sub in raw)
  0000:0294  55                push     bp
  0000:0295  8bec              mov      bp, sp
  0000:0297  81ecc200          sub      sp, 0xc2        ; 194 bytes of locals
  0000:029B  56                push     si
  ; ... validates slot via dmdbrd_validateSlot
  ; ... reads file header via dmdbrd_openFile (sub_0000_34BE)
  ; ... dispatches based on [bp+4]:
  ;   0x0B, 0x0C -> dmdbrd_executeQuery (sub_0000_127B) then
  ;                 dmdbrd_searchWithIndex (sub_0000_07C2)
  ;   0x0D, 0x0E -> dmdbrd_executeQuery then
  ;                 dmdbrd_searchByColumn (sub_0000_05FD) then
  ;                 dmdbrd_searchContinue (sub_0000_0D1D)
  ;   0x11       -> dmdbrd_searchByColumn (sub_0000_05FD)
  ; ... manages cache states via dmdbrd_setCacheState (0x4C='L', 0x49='I')
  ; ... handles error propagation and retry logic
  ; Full body spans 0x0294 - 0x05FC in raw disassembly
  ;
  ; [See raw disassembly for complete instruction listing]
  ; [0000:0294 through 0000:05FC -- 872 bytes]

; ========================================================================
; dmdbrd_searchByColumn (0000:05FD)
; Search database by column value. Reads index entries and compares
; against the target column value. Handles both primary and secondary
; index lookups.
; Parameters:
;   [bp+4] = search context pointer
;   [bp+6] = column code
;   [bp+8] = database context pointer
; Returns: AX = 0 on match found, negative on error
; ========================================================================
; [Function spans 0x05FD - 0x07C1, 452 bytes]
; Key operations:
;   - Computes slot from record_id / 100
;   - Reads database handle from slot table
;   - Looks up column in B-tree via dmdbrd_readBlock
;   - Iterates index entries comparing field values
;   - Returns position info in search context struct
; [See raw disassembly for complete listing]

; ========================================================================
; dmdbrd_searchWithIndex (0000:07C2)
; Performs binary search within a B-tree index page to find a record
; matching the search criteria. Dispatches to sub_0000_0974 (forward)
; or sub_0000_0B41 (backward) depending on the command code [bp+0xC].
; Parameters:
;   [bp+4] = search context
;   [bp+6] = record context
;   [bp+8] = database context
;   [bp+0xA] = column info
;   [bp+0xC] = command (0x0B=forward, other=backward)
; Returns: AX = 0 on match, negative on error
; ========================================================================
; [Function spans 0x07C2 - 0x0973, 434 bytes]
; Implements classic binary search (lo..hi, mid=(lo+hi)/2)
; with dmdbrd_compareRecord to determine ordering.

; ========================================================================
; dmdbrd_searchIndexForward (0000:0974)
; Forward index scan: walks B-tree pages following next-page links,
; reading and comparing each entry against the search value.
; [Function spans 0x0974 - 0x0B40, 460 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_searchIndexBackward (0000:0B41)
; Backward index scan: walks B-tree pages in reverse order.
; [Function spans 0x0B41 - 0x0D1C, 476 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_searchContinue (0000:0D1D)
; Continue a search from the current position, advancing to the next
; matching record. Used for sequential iteration through result sets.
; [Function spans 0x0D1D - 0x0EA5, 393 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_compareRecord (0000:0EA6)
; Compare a record's field value against the search target.
; Reads the field from the record data buffer and delegates to
; dmdbrd_compareFieldValue for type-appropriate comparison.
; [Function spans 0x0EA6 - 0x0FAF, 266 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_compareFieldValue (0000:0FB0)
; Compare a single field value, handling both string and numeric types.
; Uses dmdbrd_parseFieldValue (sub_0000_3F9F) to extract values,
; then calls dmdbrd_compareNumeric or dmdbrd_compareString.
; [Function spans 0x0FB0 - 0x1049, 154 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_findFirstEntry (0000:104A)
; Find the first non-empty entry in an index page.
; Scans entries starting at offset 0x28, looking for non-zero record_id.
; [Function spans 0x104A - 0x1078, 47 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_searchForwardScan (0000:1079)
; Forward sequential scan through index, reading blocks and comparing.
; [Function spans 0x1079 - 0x127A, 514 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_executeQuery (0000:127B)
; Execute a database query with filter and sort criteria.
; This is the high-level query function called by the dispatch handler.
; [Function spans 0x127B - 0x13FE, 388 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_sortResultSet (0000:13FF)
; Sort the result set of a query. Uses insertion sort with
; dmdbrd_copyFieldData to swap entries.
; [Function spans 0x13FF - 0x1485, 135 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_scanSequential (0000:1486)
; Sequential scan without index: iterates all records in a slot,
; testing each against the query filter.
; [Function spans 0x1486 - 0x15D5, 336 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_copyFieldData (0000:15D6)
; Copy field data between buffers. Used during sort operations.
; [Function spans 0x15D6 - 0x1614, 63 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_openDatabase (0000:1615)
; Open a .FIL database file and initialize its slot.
; [Function spans 0x1615 - 0x1645, varies with sub-calls]
; ========================================================================

; ========================================================================
; dmdbrd_closeAllDatabases (0000:18C3)
; Close all 6 database slots, freeing resources.
; ========================================================================

; ========================================================================
; dmdbrd_freeRecordTree (0000:1973)
; Recursively free an entire record tree including all field chains.
; Handles column definitions, checksums, and callback invocations.
; [Function spans 0x1973 - 0x1C9D, 811 bytes -- largest internal fn]
; ========================================================================

; ========================================================================
; dmdbrd_loadIndexBlock (0000:1D66)
; Load an index block into memory. Allocates memory for index data,
; reads the block from disk, and populates the index structure.
; [Function spans 0x1D66 - 0x1F43, 478 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_readRecord (0000:1F44)
; Read a complete record from the database. This is the core read
; operation that loads record data from disk into the buffer cache.
; [Function spans 0x1F44 - 0x223E, 763 bytes]
; ========================================================================

; ========================================================================
; dmdbrd_readRecordByKey (0000:223F)
; Read a record by its index key. This is the main query entry point
; for key-based lookups. Handles column resolution, index traversal,
; and record loading.
; [Function spans 0x223F - 0x2A5B, 2076 bytes -- second largest fn]
; ========================================================================

; ========================================================================
; Remaining functions from 0x2A5C through 0x4BD5 follow similar patterns.
; Each is documented in the FUNCTION INDEX above with its purpose.
; For complete instruction-level detail, refer to the raw disassembly at:
;   /Users/joe/Documents/GitHub/bayside/disassembly/raw/res/dmdbrd.asm
;
; Key function groups in this range:
;
; --- Record I/O (0x2A5C - 0x2F56) ---
; dmdbrd_readRecordDirect, dmdbrd_readRecordData, dmdbrd_closeFileHandle,
; dmdbrd_readRecordFields, dmdbrd_parseRecordBuffer, dmdbrd_extractRecordData,
; dmdbrd_freeSlotBuffers, dmdbrd_freeFieldChain, dmdbrd_freeRecordNode,
; dmdbrd_closeRecordChain
;
; --- File I/O (0x2F57 - 0x3865) ---
; dmdbrd_writeBackBlock, dmdbrd_readColumnDefs, dmdbrd_readIndexHeader,
; dmdbrd_readIndexTree, dmdbrd_flushDirtyBlocks, dmdbrd_openFile,
; dmdbrd_readFileHeader, dmdbrd_readFileBlock, dmdbrd_readBlockDirect,
; dmdbrd_seekAndRead, dmdbrd_writeBlock, dmdbrd_seekToOffset,
; dmdbrd_readBytes, dmdbrd_buildFilePath, dmdbrd_buildFullPath,
; dmdbrd_validateDatabase
;
; --- Cache Management (0x3866 - 0x3CC5) ---
; dmdbrd_setCacheState, dmdbrd_lookupCacheEntry, dmdbrd_readBlock,
; dmdbrd_readBlockChain, dmdbrd_resetAccessCounters, dmdbrd_findCacheSlot,
; dmdbrd_allocateCacheSlot
;
; --- Heap Allocation (0x3CC6 - 0x3E05) ---
; dmdbrd_heapAlloc, dmdbrd_heapFree
;
; --- Expression / Filter (0x3E06 - 0x3F9E) ---
; dmdbrd_evaluateFilter, dmdbrd_getRecordField, dmdbrd_getNextIndexEntry,
; dmdbrd_getFirstIndexEntry, dmdbrd_getLastIndexEntry, dmdbrd_lookupColumn,
; dmdbrd_compareNumeric, dmdbrd_compareString, dmdbrd_parseFieldValue
;
; --- String / Data Utilities (0x3F9F - 0x45F8) ---
; Various string operations, DOS file I/O wrappers, character conversion
;
; --- Character tables and data (0x19B2 - 0x1B03) ---
; ASCII/EBCDIC translation table for international character support:
;   0x19B2: " !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ..."
;   0x1A12: "CUEAAAACEEEIIIAAEAAOOOUUYOU$$$$$AIOUNN" (accented char mapping)
;
; --- Jump/dispatch tables (0x462B - 0x469A) ---
; Word-offset tables used by the main dispatch mechanism at 0x46AB.
; These map command codes to function entry points within seg_0000.
; ========================================================================

; ========================================================================
; dmdbrd_checksumVerify (0000:46EA)
; Verifies a 66-byte (0x42) XOR checksum over the first bytes of
; the data segment. Expected result after XOR with 0x55 = 0.
; If checksum fails, calls dmdbrd_crtErrorHandler and returns 1.
; Returns: AX = 0 if checksum passes, 1 if failed
; ========================================================================
dmdbrd_checksumVerify:  ; sub_0000_46EA
  0000:46EA  56                push     si
  0000:46EB  33f6              xor      si, si
  0000:46ED  b94200            mov      cx, 0x42        ; 66 bytes
  0000:46F0  32e4              xor      ah, ah
  0000:46F2  fc                cld
.xor_loop:
  0000:46F3  ac                lodsb    al, byte ptr [si]
  0000:46F4  32e0              xor      ah, al
  0000:46F6  e2fb              loop     .xor_loop
  0000:46F8  80f455            xor      ah, 0x55
  0000:46FB  740d              je       .ok
  0000:46FD  e8c4ff            call     dmdbrd_crtErrorHandler
  0000:4700  b80100            mov      ax, 1
  0000:4703  50                push     ax
  0000:4704  e8be01            call     dmdbrd_printErrorMsg
  0000:4707  b80100            mov      ax, 1           ; return 1 = failed
.ok:  ; loc_0000_470A
  0000:470A  5e                pop      si
  0000:470B  c3                ret

; ========================================================================
; CRT command-line parsing code (0000:470C - 0x4899)
; Standard Microsoft C 5.x command-line parser. Processes the PSP
; command tail at offset 0x81, handling quoted strings and escape
; characters. Builds argc/argv on the stack.
; Not relevant to database operations -- standard CRT boilerplate.
; ========================================================================
  ; [0x470C - 0x4899: CRT command-line parser, see raw disassembly]

; ========================================================================
; dmdbrd_malloc / heap allocator (0000:4930 - 0x4BD5)
; Standard Microsoft C 5.x heap allocator. Implements first-fit
; allocation with coalescing of free blocks. Supports near and far
; heap through the arena mechanism.
; See function index for individual function descriptions.
; ========================================================================

; ========================================================================
; SEGMENT seg_04C2  (608 bytes, file 0x4E20-0x5080)
; CRT startup, TSR registration, API dispatch loop, PSP management
; ========================================================================
seg_04C2:

; ========================================================================
; sub_04C2_0000 - Cross-segment utility / memory management return point
; This label is a jump target for many far calls that end with
; a memory management operation across segments.
; ========================================================================
  04C2:0000  7504              jne      .store_dx
  04C2:0002  89168802          mov      word ptr [0x288], dx
.store_dx:  ; loc_04C2_0006
  04C2:0006  92                xchg     dx, ax
  04C2:0007  8704              xchg     word ptr [si], ax
  04C2:0009  8bd1              mov      dx, cx
  04C2:000B  c3                ret

; --- INT E0h interrupt handler (04C2:000C) ---
; Handles re-entrant calls from the DeskMate host.
; Pushes DS, loads seg_04E8 as DS, checks [0x10A] for version,
; returns via IRET.
  04C2:000C  db 1E 50 B8 E8 04 8E D8 58 32 C0 80 3E 0A 01 02 74
  04C2:001C  db 02 B0 03 1F CF 00 00 00 00 00 00 00 00 00 00

; ========================================================================
; dmdbrd_apiInit (04C2:002B)
; API initialization entry point. Called once during TSR setup.
; Saves SS:SP to CS:[0x22]/CS:[0x24], queries DeskMate host via
; INT E0h AH=06h for system capabilities, then registers the
; module's API dispatch function via INT E0h AH=01h.
; ========================================================================
dmdbrd_apiInit:  ; at 04C2:002B
  04C2:002B  55                push     bp
  04C2:002C  8bec              mov      bp, sp
  ; Save caller's SS:SP to code segment for re-entry
  04C2:002E  2e8c162400        mov      word ptr cs:[0x24], ss
  04C2:0033  2e89262200        mov      word ptr cs:[0x22], sp
  ; Set up PSP tracking
  04C2:0038  bb6202            mov      bx, 0x262
  04C2:003B  a1ff02            mov      ax, word ptr [0x2ff]
  04C2:003E  894720            mov      word ptr [bx + 0x20], ax
  ; Query host system info
  04C2:0041  b80006            mov      ax, 0x600       ; INT E0h AH=06h: query
  04C2:0044  cde0              int      0xe0
  04C2:0046  250080            and      ax, 0x8000      ; test bit 15 (mode flag)
  04C2:0049  7405              je       .standard_mode
  04C2:004B  b8f001            mov      ax, 0x1f0       ; protected mode API vector
  04C2:004E  eb03              jmp      .register
.standard_mode:  ; loc_04C2_0050
  04C2:0050  b8ff01            mov      ax, 0x1ff       ; standard mode API vector
.register:  ; loc_04C2_0053
  ; Register API dispatch function
  04C2:0053  b90000            mov      cx, 0           ; RELOC -> seg_0000 (dispatch segment)
  04C2:0056  1e                push     ds
  04C2:0057  07                pop      es
  04C2:0058  cde0              int      0xe0            ; INT E0h AH=01h: register
  04C2:005A  a29f00            mov      byte ptr [0x9f], al  ; save registration token
  04C2:005D  eb00              jmp      .init_db

.init_db:  ; loc_04C2_005F
  ; Far-call to dmdbrd_initSystem (0000:01C7 inline stub)
  04C2:005F  9ac7010000        lcall    0, 0x1c7        ; RELOC -> seg_0000
  04C2:0064  50                push     ax              ; save init result
  ; Get PSP size for TSR calculation
  04C2:0065  e8e501            call     dmdbrd_getPspSize  ; -> sub_04C2_024D
  04C2:0068  43                inc      bx              ; round up
  04C2:0069  891e5802          mov      word ptr [0x258], bx  ; save PSP segment
  04C2:006D  58                pop      ax              ; restore init result
  ; Terminate and Stay Resident
  04C2:006E  b431              mov      ah, 0x31
  04C2:0070  cd21              int      0x21            ; INT 21h/31h: TSR

; ========================================================================
; dmdbrd_apiEntry (04C2:0072)
; Re-entrant API entry point. Called by the DeskMate host when a
; database operation is requested. Saves caller's SS:SP, switches
; to the module's stack, swaps PSP, executes the operation via
; far-call to dmdbrd_cleanupSlots (0000:0184), then restores state.
; ========================================================================
dmdbrd_apiEntry:  ; at 04C2:0072
  04C2:0072  2e8c162800        mov      word ptr cs:[0x28], ss  ; save caller SS
  04C2:0077  2e89262600        mov      word ptr cs:[0x26], sp  ; save caller SP
  04C2:007C  fa                cli
  04C2:007D  2e8e162400        mov      ss, word ptr cs:[0x24]  ; load module SS
  04C2:0082  2e8b262200        mov      sp, word ptr cs:[0x22]  ; load module SP
  04C2:0087  fb                sti
  ; Swap PSP to module's PSP
  04C2:0088  1e                push     ds
  04C2:0089  2e8e1e2400        mov      ds, word ptr cs:[0x24]
  04C2:008E  b451              mov      ah, 0x51
  04C2:0090  cd21              int      0x21            ; Get current PSP -> BX
  04C2:0092  891e5a02          mov      word ptr [0x25a], bx  ; save caller's PSP
  04C2:0096  8b1e5802          mov      bx, word ptr [0x258]
  04C2:009A  b450              mov      ah, 0x50
  04C2:009C  cd21              int      0x21            ; Set PSP to module's
  ; Far-call to cleanupSlots in seg_0000
  04C2:009E  9a84010000        lcall    0, 0x184        ; RELOC -> seg_0000
  04C2:00A3  50                push     ax              ; save result
  ; Restore caller's PSP
  04C2:00A4  8b1e5a02          mov      bx, word ptr [0x25a]
  04C2:00A8  b450              mov      ah, 0x50
  04C2:00AA  cd21              int      0x21            ; Set PSP back
  04C2:00AC  58                pop      ax
  04C2:00AD  1f                pop      ds
  ; Restore caller's SS:SP
  04C2:00AE  fa                cli
  04C2:00AF  2e8e162800        mov      ss, word ptr cs:[0x28]
  04C2:00B4  2e8b262600        mov      sp, word ptr cs:[0x26]
  04C2:00B9  fb                sti
  04C2:00BA  cb                retf

; --- Re-entrant nested call handler (04C2:00BB - 04C2:0135) ---
; Handles nested/recursive API calls. Checks re-entrancy flag at
; CS:[0x2A], returns 0xFFCE if already in a call.
; Otherwise saves registers, copies parameters, swaps PSP, and
; dispatches. See raw disassembly for full listing.
  04C2:00BB  db FA 2E 80 3E 2A 00 00 74 05 FB B8 CE FF CB 2E FE
  04C2:00CB  db 06 2A 00 FB 2E 8C 16 28 00 2E 89 26 26 00 FA 2E
  04C2:00DB  db 8E 16 24 00 2E 8B 26 22 00 FB 1E 55 56 57 8B F3
  04C2:00EB  db 83 EC 08 8B FC 8C C1 8E D9 8C D0 8E C0 B9 08 00
  04C2:00FB  db FC F3 A4 8E D8 B4 51 CD 21 89 1E 5A 02 8B 1E 58
  04C2:010B  db 02 B4 50 CD 21 E8 23 00 83 C4 08 50 8B 1E 5A 02
  04C2:011B  db B4 50 CD
  04C2:011E  db 21 58 5F 5E 5D
  04C2:0123  db 1F FA 2E 8E 16 28 00 2E 8B 26 26 00 FB 2E FE 0E
  04C2:0133  db 2A 00 CB

; ========================================================================
; dmdbrd_dispatchLoop (04C2:0136)
; Main dispatch loop. Reads the function pointer from [0x10F],
; pushes it onto the stack, and performs an indirect far-call through
; the caller's function table. If the return code is 0xFFCF (retry),
; it saves/restores the PSP token and loops. Otherwise, it returns
; the result.
; Parameters: [bp+4] = far pointer to caller's dispatch table
; Returns: AX = final result code
; ========================================================================
dmdbrd_dispatchLoop:  ; at 04C2:0136
  04C2:0136  55                push     bp
  04C2:0137  8bec              mov      bp, sp
  04C2:0139  56                push     si
  04C2:013A  be0f01            mov      si, 0x10f       ; -> function table pointer
  04C2:013D  8b34              mov      si, word ptr [si]  ; si = actual table ptr
  ; Push DS and function table as parameters for the far-call
  04C2:013F  1e                push     ds
  04C2:0140  56                push     si
  ; Load caller's dispatch table via LES
  04C2:0141  c45e04            les      bx, ptr [bp + 4]
  ; Call first function in dispatch table (init/query handler)
  04C2:0144  26ff1f            lcall    es:[bx]
  04C2:0147  83c404            add      sp, 4
  04C2:014A  0bc0              or       ax, ax
  04C2:014C  7c3a              jl       .error          ; negative = error
  04C2:014E  7436              je       .done           ; zero = complete

.retry_loop:  ; loc_04C2_0150
  ; Save PSP token before dispatch
  04C2:0150  a09f00            mov      al, byte ptr [0x9f]
  04C2:0153  3cff              cmp      al, 0xff
  04C2:0155  7409              je       .no_psp_save
  04C2:0157  52                push     dx
  04C2:0158  8ad0              mov      dl, al
  04C2:015A  b8044d            mov      ax, 0x4d04      ; INT E0h AH=4Dh: save PSP
  04C2:015D  cde0              int      0xe0
  04C2:015F  5a                pop      dx
.no_psp_save:  ; loc_04C2_0160
  04C2:0160  a20e01            mov      byte ptr [0x10e], al
  ; Far-call to the read operation handler in seg_0000
  04C2:0163  9a9e160000        lcall    0, 0x169e       ; RELOC -> seg_0000
  04C2:0168  8904              mov      word ptr [si], ax  ; store result
  ; Restore PSP token
  04C2:016A  a00e01            mov      al, byte ptr [0x10e]
  04C2:016D  3cff              cmp      al, 0xff
  04C2:016F  7409              je       .no_psp_restore
  04C2:0171  52                push     dx
  04C2:0172  8ad0              mov      dl, al
  04C2:0174  b8054d            mov      ax, 0x4d05      ; INT E0h AH=4Dh: restore PSP
  04C2:0177  cde0              int      0xe0
  04C2:0179  5a                pop      dx
.no_psp_restore:  ; loc_04C2_017A
  ; Call second function in dispatch table (continue/next)
  04C2:017A  c45e04            les      bx, ptr [bp + 4]
  04C2:017D  26ff5f04          lcall    es:[bx + 4]
  04C2:0181  3dcfff            cmp      ax, 0xffcf      ; retry sentinel?
  04C2:0184  74ca              je       .retry_loop     ; yes -> loop

.done:  ; loc_04C2_0186
  04C2:0186  8b04              mov      ax, word ptr [si]  ; return stored result

.error:  ; loc_04C2_0188
  04C2:0188  5e                pop      si
  04C2:0189  5d                pop      bp
  04C2:018A  c3                ret
  04C2:018B  db 00

; ========================================================================
; entry_point (04C2:018C)
; Standard Microsoft C 5.x CRT startup for a TSR module.
; 1. Check DOS version >= 2.0
; 2. Compute available memory, set SS:SP
; 3. Resize memory block (INT 21h/4Ah)
; 4. Zero BSS segment (0x544 to 0x550)
; 5. Initialize CRT internals
; 6. Check for "DESKMATE$" device driver (INT 21h/35h on vector E0h)
; 7. If DeskMate found, call dmdbrd_apiInit to register and go TSR
; ========================================================================
entry_point:
  04C2:018C  b430              mov      ah, 0x30
  04C2:018E  cd21              int      0x21            ; Get DOS version
  04C2:0190  3c02              cmp      al, 2
  04C2:0192  7302              jae      .dos_ok
  04C2:0194  cd20              int      0x20            ; Exit if DOS < 2.0

.dos_ok:  ; loc_04C2_0196
  04C2:0196  bfe804            mov      di, 0x4e8       ; RELOC -> seg_04E8 (SS segment)
  04C2:0199  8b360200          mov      si, word ptr [2] ; top of memory
  04C2:019D  2bf7              sub      si, di          ; available paragraphs
  04C2:019F  81fe0010          cmp      si, 0x1000      ; cap at 64KB
  04C2:01A3  7203              jb       .set_stack
  04C2:01A5  be0010            mov      si, 0x1000

.set_stack:  ; loc_04C2_01A8
  04C2:01A8  fa                cli
  04C2:01A9  8ed7              mov      ss, di          ; SS = seg_04E8
  04C2:01AB  81c44e05          add      sp, 0x54e       ; SP = initial stack
  04C2:01AF  fb                sti
  04C2:01B0  7314              jae      .enough_memory
  ; Not enough memory -- print error and exit
  04C2:01B2  16                push     ss
  04C2:01B3  1f                pop      ds
  04C2:01B4  9a631b0000        lcall    0, 0x1b63       ; RELOC -> seg_0000 (error handler)
  04C2:01B9  33c0              xor      ax, ax
  04C2:01BB  50                push     ax
  04C2:01BC  9a671b0000        lcall    0, 0x1b67       ; RELOC -> seg_0000 (exit handler)
  04C2:01C1  b8ff4c            mov      ax, 0x4cff
  04C2:01C4  cd21              int      0x21            ; Exit with error code 255

.enough_memory:  ; loc_04C2_01C6
  04C2:01C6  83e4fe            and      sp, 0xfffe      ; align stack
  ; Store heap boundaries
  04C2:01C9  3689268e02        mov      word ptr ss:[0x28e], sp
  04C2:01CE  3689268a02        mov      word ptr ss:[0x28a], sp
  04C2:01D3  8bc6              mov      ax, si
  04C2:01D5  b104              mov      cl, 4
  04C2:01D7  d3e0              shl      ax, cl          ; convert paragraphs to bytes
  04C2:01D9  48                dec      ax
  04C2:01DA  36a38802          mov      word ptr ss:[0x288], ax  ; heap limit
  04C2:01DE  03f7              add      si, di
  04C2:01E0  89360200          mov      word ptr [2], si
  ; Resize memory block to actual needed size
  04C2:01E4  8cc3              mov      bx, es
  04C2:01E6  2bde              sub      bx, si
  04C2:01E8  f7db              neg      bx
  04C2:01EA  b44a              mov      ah, 0x4a
  04C2:01EC  cd21              int      0x21            ; Resize memory block
  ; Save DS (PSP) segment
  04C2:01EE  368c1eff02        mov      word ptr ss:[0x2ff], ds
  ; Zero BSS
  04C2:01F3  16                push     ss
  04C2:01F4  07                pop      es
  04C2:01F5  fc                cld
  04C2:01F6  bf4405            mov      di, 0x544       ; BSS start
  04C2:01F9  b95005            mov      cx, 0x550       ; BSS end
  04C2:01FC  2bcf              sub      cx, di          ; BSS size
  04C2:01FE  33c0              xor      ax, ax
  04C2:0200  f3aa              rep stosb                 ; zero fill BSS
  ; Set DS = SS (small model)
  04C2:0202  16                push     ss
  04C2:0203  1f                pop      ds
  ; Initialize CRT internals
  04C2:0204  06                push     es
  04C2:0205  0e                push     cs
  04C2:0206  07                pop      es
  04C2:0207  9a5f1b0000        lcall    0, 0x1b5f       ; RELOC -> seg_0000 (CRT init 1)
  04C2:020C  07                pop      es
  04C2:020D  16                push     ss
  04C2:020E  1f                pop      ds
  04C2:020F  9a441b0000        lcall    0, 0x1b44       ; RELOC -> seg_0000 (CRT init 2)
  ; Set up seg_04E8 as secondary data segment
  04C2:0214  b8e804            mov      ax, 0x4e8       ; RELOC -> seg_04E8
  04C2:0217  8ed8              mov      ds, ax
  04C2:0219  b80300            mov      ax, 3
  04C2:021C  36c7068c02421c    mov      word ptr ss:[0x28c], 0x1c42
  04C2:0223  9a6b1b0000        lcall    0, 0x1b6b       ; RELOC -> seg_0000 (CRT init 3)
  ; Check for DESKMATE$ device driver
  04C2:0228  06                push     es
  04C2:0229  57                push     di
  04C2:022A  56                push     si
  04C2:022B  b8e035            mov      ax, 0x35e0      ; Get INT E0h vector
  04C2:022E  cd21              int      0x21
  04C2:0230  8cc0              mov      ax, es
  04C2:0232  0bc0              or       ax, ax
  04C2:0234  7412              je       .no_deskmate    ; no INT E0h handler
  04C2:0236  83c303            add      bx, 3           ; skip 3 bytes in handler
  04C2:0239  8bfb              mov      di, bx
  04C2:023B  be2e03            mov      si, 0x32e       ; -> "DESKMATE$" in our data
  04C2:023E  b90900            mov      cx, 9
  04C2:0241  f3a6              repe cmpsb               ; compare signatures
  04C2:0243  7503              jne      .no_deskmate
  04C2:0245  f8                clc                      ; found -> clear carry
  04C2:0246  eb01              jmp      .check_done
.no_deskmate:  ; loc_04C2_0248
  04C2:0248  f9                stc                      ; not found -> set carry
.check_done:  ; loc_04C2_0249
  04C2:0249  5e                pop      si
  04C2:024A  5f                pop      di
  04C2:024B  07                pop      es
  04C2:024C  c3                ret

; ========================================================================
; dmdbrd_getPspSize (04C2:024D)
; Get PSP allocation size in paragraphs for TSR keep calculation.
; Reads the MCB (Memory Control Block) at PSP-1 to get block size.
; Returns: AX = DX = size in paragraphs, BX = PSP-1
; ========================================================================
dmdbrd_getPspSize:  ; sub_04C2_024D
  04C2:024D  b451              mov      ah, 0x51
  04C2:024F  cd21              int      0x21            ; Get PSP -> BX
  04C2:0251  4b                dec      bx              ; BX = MCB segment
  04C2:0252  8ec3              mov      es, bx
  04C2:0254  268b160300        mov      dx, word ptr es:[3]  ; MCB size field
  04C2:0259  8bc2              mov      ax, dx
  04C2:025B  c3                ret
  04C2:025C  db 00 00 00 00                             ; padding

; ========================================================================
; SEGMENT seg_04E8  (64 bytes, file 0x5080-0x50C0)
; Microsoft C Runtime copyright string
; ========================================================================
seg_04E8:
  04E8:0000  db 00 00 00 00 00 00 00 00
  04E8:0008  db "MS Run-Time Library - Copyright (c) 1987, Microsoft Corp"

; ========================================================================
; SEGMENT seg_04EC  (1,283 bytes, file 0x50C0-0x55C3)
; Initialized data: column definitions, module strings, CRT tables
; ========================================================================
seg_04EC:

; --- Column definition strings ---
  04EC:0000  db 1E 00                                   ; max columns = 30
  04EC:0002  db "cname", 00                             ; column name
  04EC:0008  db "owner", 00                             ; owner name
  04EC:000E  db "pos", 00, "len", 00                    ; position, length
  04EC:0016  db "type", 00                              ; field type
  04EC:001B  db "uniq", 00                              ; unique flag

; --- Internal column type codes ---
  04EC:0020  db 42 00 00 00 50 00                       ; B=0x42, P=0x50
  04EC:0026  db "C00H", 00                              ; character, head
  04EC:002B  db 00 00 50 00
  04EC:002F  db "C00N", 00                              ; character, name
  04EC:0034  db 00 00 04 00
  04EC:0038  db "N00R", 00                              ; numeric, record
  04EC:003D  db 00 00 04 00
  04EC:0041  db "N00V", 00                              ; numeric, version
  04EC:0046  db 00 00 01 00
  04EC:004A  db "C00[", 00                              ; character, bracket
  04EC:004F  db 00 00 01 00
  04EC:0053  db "N00DBCOLS", 00                         ; numeric, db columns

; --- Slot table + dispatch data (04EC:005D - 04EC:00F3) ---
; Contains the initial slot table with relocation to seg_04C2,
; API entry point addresses, and slot initialization data.
; 6 slot entries (16 bytes each) initialized to -1 / 0.
  04EC:005D  db C2 04 ...                               ; [RELOC -> seg_04C2]
  ; [See raw disassembly for byte-level detail]

; --- Cross-module name references ---
  04EC:00F4  db "DMDBUPD", 00                           ; companion update module
  04EC:00FC  db "DMDBBLD", 00                           ; companion build module

; --- Module's own global state block (04EC:0104 - 04EC:0221) ---
  ; Contains relocation to seg_0000, initial pointers,
  ; and zero-filled space for runtime state.

; --- Module name for registration ---
  04EC:0222  db "DMDBRD", 00

; --- API registration block (04EC:0229 - 04EC:0297) ---
; Contains far pointers to dmdbrd_apiEntry and dmdbrd_apiInit,
; relocation entries, and module flags.

; --- CRT runtime data (04EC:02A0 - 04EC:0500) ---
  04EC:02A0  db ";C_FILE_INFO", 00                      ; CRT file handle table name
  04EC:02EE  db "DESKMATE$", 00                         ; device driver signature
  04EC:0313  db "         (((((                  H"     ; ctype table (128 bytes)
  04EC:0422  db "=<>!|^", 00                            ; comparison operators
  04EC:042A  db "<<NMSG>>", 00                          ; CRT message header
  04EC:0434  db "R6000\r\n- stack overflow\r\n", 00
  04EC:0450  db "R6003\r\n- integer divide by 0\r\n", 00
  04EC:0471  db "R6009\r\n- not enough space for environment\r\n", 00
  04EC:04A4  db "run-time error ", 00
  04EC:04B6  db "R6002\r\n- floating point not loaded\r\n", 00
  04EC:04DD  db "R6001\r\n- null pointer assignment\r\n", 00
  04EC:0500  db FF FF FF                                ; end sentinel

; ========================================================================
; SEGMENT seg_053D  (BSS)
; Uninitialized data: stack space and runtime variables
; ========================================================================
; [Not shown -- zeroed at startup by CRT code]
