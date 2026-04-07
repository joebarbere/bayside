; ========================================================================
; DMDBBLD.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMDBBLD.RES is the database build engine for DeskMate 3.05.
; It provides database creation, field definition, and B-tree index
; building operations for .FIL database files. It works in conjunction
; with DMDBRD.RES (database read) and DMDBUPD.RES (database update).
;
; DMDBBLD creates new database files on disk (INT 21h/3Ch), defines
; field schemas, adds fields to existing databases, and builds or
; rebuilds B-tree indexes. It is the structural counterpart to
; DMDBRD (read operations) and DMDBUPD (insert/update/delete operations).
;
; The module is a simple TSR RES driver that registers itself via
; INT E0h and stays resident. Like DMDBUPD, it uses two sets of
; far-call thunk tables to dispatch into DMDBRD (for cache/buffer
; operations) and a second target module (likely for index operations).
;
; Command dispatch (CX-based, at entry point far-call from host):
;   CX=0x01  Create database       -> dmdbbld_createDatabase  (sub_04E3)
;   CX=0x04  Define field           -> dmdbbld_defineField     (sub_0086)
;   CX=0x05  Add field to database  -> dmdbbld_addField        (sub_017A)
;   CX=0x08  Modify field schema    -> dmdbbld_modifySchema    (sub_091A)
;   CX=0x16  Rebuild database       -> dmdbbld_rebuildDatabase (sub_01F0)
;   CX=0x17  Build index            -> dmdbbld_buildIndex      (sub_0B69)
;   CX=0x18  Write index entry      -> dmdbbld_writeIndexEntry (sub_07C9)
;   CX=0x1B  Add field and index    -> dmdbbld_addFieldIndex   (sub_08F3)
;
; DM89 imports: Registered as "DMDBBLD" via INT E0h AH=01h
;               Uses INT E0h AH=06h for memory size query
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 11,858 bytes
; Load image: 11,346 bytes (after header)
; DM89 entry point: 02BB:000C (RES startup + TSR)
; SS:SP = 02C6:0002
;
; Segment Map (4 segments, 4 relocations):
;   seg_0000  11184 bytes  CODE   Database build engine + thunk tables
;   seg_02BB    112 bytes  CODE   Entry point, TSR, PSP helper, atol tail
;   seg_02C2     50 bytes  DATA   Module name "DMDBBLD", relay data,
;                                  "DESKMATE$" device signature
;   seg_02C6      2 bytes  BSS    Stack segment
;
; DM flags: 0x0101 (standard RES module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Slot Table (same as DMDBRD/DMDBUPD):
;   Base address: 0xA8
;   6 slots, 16 bytes each (slots 0-5)
;   slot_base = slot_index * 16 + 0xA8
;   Indexed by: record_id / 100
;
;   Slot Entry Layout (16 bytes):
;     +0x00  file handle / name ptr (word)
;     +0x02  status flags (word)
;     +0x04  field count (word)
;     +0x06  record size (word)
;     +0x08  file handle (word) - checked >= 0 for validity
;     +0x0A  control block pointer (word) - points to field definition chain
;     +0x0B  (byte within +0x0A word)
;     +0x0C  reserved (word)
;     +0x0E  reserved (word)
;
; Database Control Block (pointed to by slot+0x0A):
;     +0x0A  first field definition pointer (word)
;     +0x08  record count or block info (word)
;     +0x17  next field pointer (word) - linked list of field definitions
;
; Field Definition (linked list node):
;     +0x00  name string pointer (word)
;     +0x02  field type byte
;     +0x03  field width (word)
;     +0x04  field_flags (word)
;     +0x06  field_type (byte) - 1=simple, 2=indexed, 3=compound
;     +0x09  next field pointer (word) - next in chain
;     +0x15  index pointer (word) - linked list of field index entries
;     +0x17  next field in chain (word)
;
; B-tree Index Node (same format as DMDBRD):
;   Node state byte:
;     0x03 = active node
;     0x44 = 'D' dirty/deleted node
;     0x46 = 'F' free/flush marker
;     0x49 = 'I' in-use marker
;     0x4C = 'L' locked marker
;     0x4E = 'N' new node
;     0x54 = 'T' tree root marker
;   Index page layout (0xF6 bytes):
;     Entries per page: 0x29 (41) at 6 bytes each
;     Entry format: record_id (2 bytes) + key data (4 bytes)
;
; B-tree Construction Buffer (sub_0B69 local frame, 0xD2 bytes):
;   [bp-0x5E]  page size (0x10 default)
;   [bp-0xB6]  recursive build flag
;   [bp-0xBE]  field definition pointer
;   [bp-0x58]  slot base address
;   [bp-0xCC]  file handle
;   [bp-0xC4]  field count
;   [bp-0xD2]  record size
;   [bp-0xB2]  temp buffer 1
;   [bp-0xD0]  temp buffer 2
;   [bp-0xC8]  current block pointer
;   [bp-0xCA]  running index count
;   [bp-0xB8]  node scanner pointer
;   [bp-0xC2]  operation result
;   [bp-0x5C]  computed offset
;   [bp-0x56]  field count from definition
;   [bp-0xCE]  current field pointer in linked list
;   [bp-0xAE..-0x54]  field type array (word per field, up to 40 entries)
;   [bp-0x54..bp]  field offset array (word per field)
;
; Index Entry Encoding (sub_0000_2629):
;   Tree nodes are built with encoded entries:
;     Byte 0: length byte | 0x80 (high bit set)
;     Byte 1: raw data byte
;     Interior: 0x01 = leaf separator, 0x02 = end marker, 0x03 = terminator
;
; Record Addressing:
;   record_id = slot_index * 100 + offset_within_slot
;   slot_base = (record_id / 100) * 16 + 0xA8
;   The slot index field at slot+0x0B stores control block offset 0xB0
;
; Global Variables:
;   [0x10F]  indirect pointer to dispatch parameter block
;   [0x113]  secondary parameter pointer (for 2-arg commands)
;   [0x115]  filename buffer pointer
;   [0x11C]  DMDBRD far-call vector (seg:off for thunk table 1)
;   [0x120]  thunk 1 return address (offset)
;   [0x122]  thunk 1 return address (segment)
;   [0x124]  thunk 2 return address (offset)
;   [0x126]  thunk 2 return address (segment)
;   [0x12C]  thunk 2 far-call vector (seg:off for secondary module)
;
; Error Codes (return values in AX):
;   0x0000  Success
;   0xFFDB  (-37) Record too large for block
;   0xFFDC  (-36) Missing control block
;   0xFFDD  (-35) Memory allocation failed
;   0xFFE2  (-30) Invalid field definition
;   0xFFE3  (-29) Field already defined / duplicate
;   0xFFE4  (-28) Duplicate key in index
;   0xFFE6  (-26) Invalid slot number
;   0xFFE7  (-25) Disk full / allocation failure
;   0xFFE9  (-23) Unknown command
;   0xFFEC  (-20) Field type mismatch
;   0xFFEF  (-17) Max fields exceeded (>= 0x28 = 40)
;   0xFFF0  (-16) Filename already exists
;   0xFFF4  (-12) Index node allocation failed
;   0xFFFA  (-6)  Record not found / offset error
;   0xFFFC  (-4)  File create error
;   0xFFFE  (-2)  Slot already in use
;
; ========================================================================
; THUNK TABLE ARCHITECTURE
; ========================================================================
;
; DMDBBLD has TWO thunk tables that dispatch into external modules:
;
; Thunk Table 1 (0x28F9-0x2A7F): 65 thunks -> DMDBRD
;   Each thunk sets AX = function_number and jumps to loc_0000_2A7F.
;   Dispatch at 0x2A7F: saves return addr at [0x120]/[0x122],
;   far-jumps through [0x11C] into DMDBRD.
;   Function numbers 0x00-0x40 map to DMDBRD operations.
;
; Thunk Table 2 (0x2A8E-0x2B54): 33 thunks -> secondary module
;   Each thunk sets AX = function_number and jumps to loc_0000_2B54.
;   Dispatch at 0x2B54: saves return addr at [0x124]/[0x126],
;   far-jumps through [0x12C] into secondary module.
;   Function numbers 0x00-0x20 map to secondary operations.
;
; Most-called thunks (into DMDBRD):
;   sub_28FF (AX=0x01) 38x - block write/mark (cache set state)
;   sub_2A1F (AX=0x31) 19x - read word from offset
;   sub_2971 (AX=0x14) 17x - calculate block offset (multiply)
;   sub_2B1E (AX=0x18) 13x - write word at offset (2nd module)
;   sub_290B (AX=0x03) 12x - allocate new block
;   sub_2A37 (AX=0x35) 12x - read block header field
;   sub_2929 (AX=0x08) 10x - free/release block
;   sub_2977 (AX=0x15)  8x - read byte from block
;   sub_2AE2 (AX=0x0E)  8x - allocate temp buffer
;   sub_2B30 (AX=0x1B) 26x - write block (2nd module)
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Command Dispatch ---
; 0000:0000  dmdbbld_dispatch         Main CX-based command router (far-call entry)
;
; --- Core Database Operations ---
; 0000:0086  dmdbbld_defineField      CX=0x04: Define a new field in database schema
; 0000:017A  dmdbbld_addField         CX=0x05: Add field (type dispatch: 1=simple, 2=indexed, 3=compound)
; 0000:01F0  dmdbbld_rebuildDatabase  CX=0x16: Rebuild database with new schema
; 0000:04E3  dmdbbld_createDatabase   CX=0x01: Create new .FIL database file
; 0000:07C9  dmdbbld_writeIndexEntry  CX=0x18: Write a single index entry to B-tree
; 0000:08F3  dmdbbld_addFieldIndex    CX=0x1B: Add field with index (wrapper for 07C9)
; 0000:091A  dmdbbld_modifySchema     CX=0x08: Modify field schema / restructure
; 0000:0B69  dmdbbld_buildIndex       CX=0x17: Build/rebuild B-tree index
;
; --- Index Construction Helpers ---
; 0000:1010  dmdbbld_initIndexBlock   Initialize index block for new field
; 0000:105A  dmdbbld_copyFieldData    Copy field data between databases
; 0000:11C2  dmdbbld_setupFieldEntry  Set up field entry in new database
; 0000:12C8  dmdbbld_writeFieldBlock  Write field block to disk
; 0000:13DF  dmdbbld_addSimpleField   Add simple (type 1) field to schema
; 0000:14DE  dmdbbld_formatFieldData  Format field data for storage
; 0000:1571  dmdbbld_createFieldSlot  Create field slot in record
; 0000:1688  dmdbbld_initFieldHeader  Initialize field header in new database
; 0000:1736  dmdbbld_validateField    Validate field and calculate offset
;
; --- B-tree Index Operations ---
; 0000:17F0  dmdbbld_buildCompoundIdx Build compound index (type 3)
; 0000:1AD0  dmdbbld_buildIndexedField Build indexed field (type 2)
; 0000:1E99  dmdbbld_insertIndexEntry Insert entry into B-tree node
; 0000:1F4E  dmdbbld_splitIndexNode   Split full B-tree index node
; 0000:1FE0  dmdbbld_rebalanceNode    Rebalance B-tree node after split
; 0000:212F  dmdbbld_encodeIndexKey   Encode key value into B-tree format
; 0000:22FA  dmdbbld_computeKeyOffset Compute key offset within index page
; 0000:2399  dmdbbld_validateIndex    Validate and finalize index structure
; 0000:244A  dmdbbld_checkDiskSpace   Check available disk space for creation
; 0000:247C  dmdbbld_mergeIndexNodes  Merge adjacent index nodes
; 0000:24EB  dmdbbld_writeIndexBlock  Write index block to cache
; 0000:2503  dmdbbld_finalizeIndex    Finalize index after full build
; 0000:252D  dmdbbld_handleBuildError Handle error during index build
;
; --- Tree Node Manipulation ---
; 0000:260C  dmdbbld_findActiveNode   Find first active (0x03) node in buffer
; 0000:2629  dmdbbld_encodeTreeEntry  Encode tree entry with field offsets
; 0000:26B8  dmdbbld_copyKeyBytes     Copy key bytes from source to node
; 0000:26EA  dmdbbld_skipDirtyNodes   Skip over dirty (0x44) nodes
; 0000:270C  dmdbbld_markDirtyNode    Mark node as dirty and write back
; 0000:2769  dmdbbld_itoaBuf          Integer-to-ASCII into buffer (recursive)
;
; --- Index Page Management ---
; 0000:27A8  dmdbbld_buildRootPage    Build B-tree root page with initial entries
;
; --- File Operations ---
; 0000:28CE  dmdbbld_createFile       Create file on disk (INT 21h/3Ch)
;
; --- Thunk Table 1: DMDBRD interface (65 thunks) ---
; 0000:28F9  dmdbrd_thunk_00  (AX=0x00)  1x  [dmdbbld_buildCompoundIdx]
; 0000:28FF  dmdbrd_thunk_01  (AX=0x01) 38x  Block write/mark dirty
; 0000:2905  dmdbrd_thunk_02  (AX=0x02)  1x  [dmdbbld_modifySchema]
; 0000:290B  dmdbrd_thunk_03  (AX=0x03) 12x  Allocate new block
; 0000:2911  dmdbrd_thunk_04  (AX=0x04)  1x  [dmdbbld_modifySchema]
; 0000:2917  dmdbrd_thunk_05  (AX=0x05)  1x  [dmdbbld_createFile]
; 0000:2923  dmdbrd_thunk_07  (AX=0x07)  3x  [formatFieldData/splitNode]
; 0000:2929  dmdbrd_thunk_08  (AX=0x08) 10x  Free/release block
; 0000:2935  dmdbrd_thunk_0A  (AX=0x0A)  1x  [formatFieldData]
; 0000:2947  dmdbrd_thunk_0D  (AX=0x0D)  4x  Close/cleanup slot
; 0000:294D  dmdbrd_thunk_0E  (AX=0x0E)  1x  [rebuildDatabase]
; 0000:2953  dmdbrd_thunk_0F  (AX=0x0F)  1x  [createDatabase]
; 0000:2959  dmdbrd_thunk_10  (AX=0x10)  1x  [defineField]
; 0000:2965  dmdbrd_thunk_12  (AX=0x12)  4x  Lock block
; 0000:296B  dmdbrd_thunk_13  (AX=0x13)  2x  Get field definition
; 0000:2971  dmdbrd_thunk_14  (AX=0x14) 17x  Calculate block offset
; 0000:2977  dmdbrd_thunk_15  (AX=0x15)  8x  Read byte from block
; 0000:297D  dmdbrd_thunk_16  (AX=0x16)  3x  Read block header
; 0000:2995  dmdbrd_thunk_1A  (AX=0x1A)  1x  Commit header
; 0000:299B  dmdbrd_thunk_1B  (AX=0x1B)  1x  [createDatabase fallback]
; 0000:29A7  dmdbrd_thunk_1D  (AX=0x1D)  1x  Find field by name
; 0000:29BF  dmdbrd_thunk_21  (AX=0x21)  1x  Validate record
; 0000:29C5  dmdbrd_thunk_22  (AX=0x22)  1x  Get filename hash
; 0000:29F5  dmdbrd_thunk_2A  (AX=0x2A)  4x  Compare strings
; 0000:2A07  dmdbrd_thunk_2D  (AX=0x2D)  1x  [rebalanceNode]
; 0000:2A0D  dmdbrd_thunk_2E  (AX=0x2E)  5x  Copy block data
; 0000:2A13  dmdbrd_thunk_2F  (AX=0x2F)  1x  [formatFieldData]
; 0000:2A19  dmdbrd_thunk_30  (AX=0x30)  5x  Set block field
; 0000:2A1F  dmdbrd_thunk_31  (AX=0x31) 19x  Read word from offset
; 0000:2A25  dmdbrd_thunk_32  (AX=0x32)  2x  Get node entry count
; 0000:2A2B  dmdbrd_thunk_33  (AX=0x33)  6x  String copy to buffer
; 0000:2A31  dmdbrd_thunk_34  (AX=0x34)  3x  Copy block range
; 0000:2A37  dmdbrd_thunk_35  (AX=0x35) 12x  Read block header field
; 0000:2A3D  dmdbrd_thunk_36  (AX=0x36)  4x  Write block header field
; 0000:2A49  dmdbrd_thunk_38  (AX=0x38)  1x  [copyFieldData]
; 0000:2A67  dmdbrd_thunk_3D  (AX=0x3D)  3x  [buildCompoundIdx/buildIndexedField]
; 0000:2A6D  dmdbrd_thunk_3E  (AX=0x3E)  1x  [rebalanceNode]
; 0000:2A79  dmdbrd_thunk_40  (AX=0x40)  2x  [copyFieldData/rebalanceNode]
;
; --- Thunk Table 2: Secondary module interface (33 thunks) ---
; 0000:2A8E  mod2_thunk_00  (AX=0x00)  3x  [copyFieldData/addSimpleField/createFieldSlot]
; 0000:2A94  mod2_thunk_01  (AX=0x01)  2x  Get buffer size
; 0000:2A9A  mod2_thunk_02  (AX=0x02)  1x  [buildCompoundIdx]
; 0000:2AA0  mod2_thunk_03  (AX=0x03)  1x  [rebuildDatabase]
; 0000:2AA6  mod2_thunk_04  (AX=0x04)  1x  [rebuildDatabase]
; 0000:2AAC  mod2_thunk_05  (AX=0x05)  1x  [buildIndexedField]
; 0000:2AB2  mod2_thunk_06  (AX=0x06)  2x  Resize memory block
; 0000:2AB8  mod2_thunk_07  (AX=0x07)  4x  Allocate disk block
; 0000:2ABE  mod2_thunk_08  (AX=0x08)  6x  Read disk block
; 0000:2AC4  mod2_thunk_09  (AX=0x09)  7x  Set block size
; 0000:2ACA  mod2_thunk_0A  (AX=0x0A)  2x  [buildIndex]
; 0000:2AD0  mod2_thunk_0B  (AX=0x0B)  2x  Update block pointer
; 0000:2AD6  mod2_thunk_0C  (AX=0x0C)  1x  Copy field value
; 0000:2ADC  mod2_thunk_0D  (AX=0x0D)  1x  Post-dispatch cleanup
; 0000:2AE2  mod2_thunk_0E  (AX=0x0E)  8x  Allocate temp buffer
; 0000:2AEE  mod2_thunk_10  (AX=0x10)  3x  Free temp buffer
; 0000:2AF4  mod2_thunk_11  (AX=0x11)  3x  Flush block to disk
; 0000:2AFA  mod2_thunk_12  (AX=0x12)  3x  Write block header
; 0000:2B06  mod2_thunk_14  (AX=0x14)  3x  [buildIndexedField/computeKeyOffset]
; 0000:2B0C  mod2_thunk_15  (AX=0x15)  1x  [mergeIndexNodes]
; 0000:2B12  mod2_thunk_16  (AX=0x16)  6x  Move block data
; 0000:2B18  mod2_thunk_17  (AX=0x17)  1x  Query block info
; 0000:2B1E  mod2_thunk_18  (AX=0x18) 13x  Write word at offset
; 0000:2B24  mod2_thunk_19  (AX=0x19)  1x  [mergeIndexNodes]
; 0000:2B30  mod2_thunk_1B  (AX=0x1B) 26x  Write/commit block
; 0000:2B4E  mod2_thunk_20  (AX=0x20)  1x  [buildIndexedField]
;
; --- Utility ---
; 0000:2B64  dmdbbld_atol             ASCII string to long integer (atol)
;
; --- Entry Point Segment (seg_02BB) ---
; 02BB:000C  entry_point              RES startup, INT E0h registration, TSR
; 02BB:003E  (inline)                 "DESKMATE$" device signature check
; 02BB:0063  dmdbbld_getPspSize       Get PSP paragraph count for TSR size
;
; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (11184 bytes, file 0x0200-0x2DB0)
; ------------------------------------------------------------------------
seg_0000:

; ========================================================================
; dmdbbld_dispatch -- Main command dispatch (0000:0000)
; ========================================================================
; Called as far-call from DeskMate host when DMDBBLD operations are needed.
; Routes CX command codes to the appropriate handler function.
;
; Input:
;   [0x10F] -> pointer to parameter block
;   Parameter block [0] = command argument (first word)
;   Parameter block [2] = additional arg (pushed for some commands)
;   CX = command code (set by caller before dispatch)
;
; The dispatch has two tiers:
;   Tier 1 (CX=1,4,8,0x16,0x17): push param[2], call handler, cleanup 1 word
;   Tier 2 (CX=5,0x18,0x1B): push param from [0x113], push param[2], call, cleanup 2 words
;   Default: return AX=0xFFE9 (unknown command)
;
; After dispatch, always calls dmdbbld_postDispatch (sub_2ADC) for cleanup.
; Returns result in AX via far return (retf).
; ========================================================================

  0000:0000  55                push     bp
  0000:0001  8bec              mov      bp, sp
  0000:0003  56                push     si
  0000:0004  be0f01            mov      si, 0x10f          ; si = &dispatch_param_ptr
  0000:0007  8b34              mov      si, word ptr [si]   ; si = *dispatch_param_ptr (param block)
  0000:0009  8b0c              mov      cx, word ptr [si]   ; cx = param[0] = command code
  0000:000B  ff7402            push     word ptr [si + 2]   ; push param[2] (first arg for handlers)

  ; Tier 1 dispatch: single-argument commands
  0000:000E  83f901            cmp      cx, 1
  0000:0011  7417              je       0x2a               ; CX=1 -> createDatabase
  0000:0013  83f917            cmp      cx, 0x17
  0000:0016  7418              je       0x30               ; CX=0x17 -> buildIndex (push 0 as 2nd arg)
  0000:0018  83f904            cmp      cx, 4
  0000:001B  741c              je       0x39               ; CX=4 -> defineField
  0000:001D  83f908            cmp      cx, 8
  0000:0020  741d              je       0x3f               ; CX=8 -> modifySchema
  0000:0022  83f916            cmp      cx, 0x16
  0000:0025  741e              je       0x45               ; CX=0x16 -> rebuildDatabase
  0000:0027  eb22              jmp      0x4b               ; -> tier 2 dispatch

loc_0000_002A:
  ; CX=1: Create database
  0000:002A  e8b604            call     0x4e3              ; dmdbbld_createDatabase(param[2])
  0000:002D  eb4b              jmp      0x7a               ; -> cleanup (1 word popped)

loc_0000_0030:
  ; CX=0x17: Build index (extra arg = 0)
  0000:0030  33c0              xor      ax, ax
  0000:0032  50                push     ax                  ; push 0 as second argument
  0000:0033  e8330b            call     0xb69              ; dmdbbld_buildIndex(param[2], 0)
  0000:0036  eb3f              jmp      0x77               ; -> cleanup (2 words popped)

loc_0000_0039:
  ; CX=4: Define field
  0000:0039  e84a00            call     0x86               ; dmdbbld_defineField(param[2])
  0000:003C  eb3c              jmp      0x7a               ; -> cleanup (1 word)

loc_0000_003F:
  ; CX=8: Modify schema
  0000:003F  e8d808            call     0x91a              ; dmdbbld_modifySchema(param[2])
  0000:0042  eb36              jmp      0x7a               ; -> cleanup (1 word)

loc_0000_0045:
  ; CX=0x16: Rebuild database
  0000:0045  e8a801            call     0x1f0              ; dmdbbld_rebuildDatabase(param[2])
  0000:0048  eb30              jmp      0x7a               ; -> cleanup (1 word)

  ; Tier 2 dispatch: two-argument commands (extra arg from [0x113])
loc_0000_004B:
  0000:004B  be1301            mov      si, 0x113          ; si = &secondary_param_ptr
  0000:004E  ff34              push     word ptr [si]       ; push *secondary_param_ptr
  0000:0050  83f905            cmp      cx, 5
  0000:0053  7410              je       0x65               ; CX=5 -> addField
  0000:0055  83f91b            cmp      cx, 0x1b
  0000:0058  7411              je       0x6b               ; CX=0x1B -> addFieldIndex
  0000:005A  83f918            cmp      cx, 0x18
  0000:005D  7412              je       0x71               ; CX=0x18 -> writeIndexEntry
  0000:005F  b8e9ff            mov      ax, 0xffe9         ; error: unknown command (-23)
  0000:0062  eb13              jmp      0x77               ; -> cleanup (2 words)

loc_0000_0065:
  ; CX=5: Add field
  0000:0065  e81201            call     0x17a              ; dmdbbld_addField(secondary_param, param[2])
  0000:0068  eb0d              jmp      0x77

loc_0000_006B:
  ; CX=0x1B: Add field and index
  0000:006B  e88508            call     0x8f3              ; dmdbbld_addFieldIndex(secondary_param, param[2])
  0000:006E  eb07              jmp      0x77

loc_0000_0071:
  ; CX=0x18: Write index entry
  0000:0071  e85507            call     0x7c9              ; dmdbbld_writeIndexEntry(secondary_param, param[2])
  0000:0074  eb01              jmp      0x77

loc_0000_0077:
  0000:0077  83c402            add      sp, 2              ; pop second argument (tier 2)

loc_0000_007A:
  0000:007A  83c402            add      sp, 2              ; pop first argument (tier 1)
  0000:007D  50                push     ax                  ; save result
  0000:007E  e85b2a            call     0x2adc             ; mod2_thunk_0D: post-dispatch cleanup
  0000:0081  58                pop      ax                  ; restore result
  0000:0082  5e                pop      si
  0000:0083  5d                pop      bp
  0000:0084  cb                retf                         ; return to host

; ========================================================================
; dmdbbld_defineField -- Define a new field (0000:0086)
; ========================================================================
; CX=4 handler. Defines a new field in an existing database.
;
; Input:
;   [bp+4] = pointer to field definition parameter block
;     +0x00  slot index (word)
;     +0x02  field name pointer (word)
;     +0x04  field type/attributes (word)
;     +0x09  index info (word)
;
; Process:
;   1. Validate slot index (0-5) and check slot is open (slot+8 >= 0)
;   2. Resize memory for new field (0x800 bytes)
;   3. Validate field via dmdbbld_validateField
;   4. Create field slot via dmdbbld_createFieldSlot
;   5. Set up field entry via dmdbrd_thunk_10 (assign to slot)
;   6. Get field block via dmdbrd_thunk_13
;   7. Init index block via dmdbbld_initIndexBlock
;   8. Write index entry via dmdbbld_writeIndexEntry
;
; Returns: AX = 0 on success, negative error code on failure
; ========================================================================

sub_0000_0086:
  0000:0086  55                push     bp
  0000:0087  8bec              mov      bp, sp
  0000:0089  83ec14            sub      sp, 0x14
  0000:008C  56                push     si
  0000:008D  8b5e04            mov      bx, word ptr [bp + 4]   ; bx = param block
  0000:0090  8b07              mov      ax, word ptr [bx]       ; ax = slot_index
  0000:0092  b104              mov      cl, 4
  0000:0094  d3e0              shl      ax, cl                  ; ax = slot_index * 16
  0000:0096  05a800            add      ax, 0xa8               ; ax = slot_base address
  0000:0099  8946fe            mov      word ptr [bp - 2], ax   ; local: slot_base
  0000:009C  8bd8              mov      bx, ax
  0000:009E  837f0800          cmp      word ptr [bx + 8], 0    ; slot.file_handle >= 0?
  0000:00A2  7c0e              jl       0xb2                   ; invalid slot -> error
  0000:00A4  8b5e04            mov      bx, word ptr [bp + 4]
  0000:00A7  8b37              mov      si, word ptr [bx]       ; si = slot_index
  0000:00A9  0bf6              or       si, si
  0000:00AB  7c05              jl       0xb2                   ; negative -> error
  0000:00AD  83fe06            cmp      si, 6
  0000:00B0  7e06              jle      0xb8                   ; 0-6 ok

loc_0000_00B2:
  0000:00B2  b8e6ff            mov      ax, 0xffe6             ; error: invalid slot (-26)
  0000:00B5  e9bd00            jmp      0x175

loc_0000_00B8:
  ; Resize memory block for field (0x800 bytes)
  0000:00B8  b80008            mov      ax, 0x800
  0000:00BB  50                push     ax
  0000:00BC  8b5efe            mov      bx, word ptr [bp - 2]
  0000:00BF  ff37              push     word ptr [bx]          ; slot.name_ptr
  0000:00C1  e8ee29            call     0x2ab2                 ; mod2_thunk_06: resize memory
  0000:00C4  83c404            add      sp, 4
  0000:00C7  0bc0              or       ax, ax
  0000:00C9  7506              jne      0xd1
  0000:00CB  b8d6ff            mov      ax, 0xffd6             ; error: memory allocation failed
  0000:00CE  e9a400            jmp      0x175

loc_0000_00D1:
  ; Validate the field definition
  0000:00D1  ff7604            push     word ptr [bp + 4]      ; param block
  0000:00D4  e85f16            call     0x1736                 ; dmdbbld_validateField
  0000:00D7  83c402            add      sp, 2
  0000:00DA  8946f4            mov      word ptr [bp - 0xc], ax ; result
  0000:00DD  0bc0              or       ax, ax
  0000:00DF  7d06              jge      0xe7                   ; ok -> continue

loc_0000_00E1:
  0000:00E1  8b46f4            mov      ax, word ptr [bp - 0xc]
  0000:00E4  e98e00            jmp      0x175                  ; return error

loc_0000_00E7:
  ; Create field slot in the record structure
  0000:00E7  8b5e04            mov      bx, word ptr [bp + 4]
  0000:00EA  ff7704            push     word ptr [bx + 4]      ; field type
  0000:00ED  ff7702            push     word ptr [bx + 2]      ; field name
  0000:00F0  ff7709            push     word ptr [bx + 9]      ; index info
  0000:00F3  ff76fe            push     word ptr [bp - 2]      ; slot_base
  0000:00F6  e87814            call     0x1571                 ; dmdbbld_createFieldSlot
  0000:00F9  83c408            add      sp, 8
  0000:00FC  8946f4            mov      word ptr [bp - 0xc], ax
  0000:00FF  0bc0              or       ax, ax
  0000:0101  7cde              jl       0xe1                   ; error -> return

  ; Set up field entry in slot system
  0000:0103  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0106  8b07              mov      ax, word ptr [bx]      ; slot_index
  0000:0108  8946ee            mov      word ptr [bp - 0x12], ax
  0000:010B  8b4702            mov      ax, word ptr [bx + 2]  ; field name
  0000:010E  8946f0            mov      word ptr [bp - 0x10], ax
  0000:0111  c746f2feff        mov      word ptr [bp - 0xe], 0xfffe  ; sentinel: -2
  0000:0116  8d46ee            lea      ax, [bp - 0x12]       ; local struct
  0000:0119  50                push     ax
  0000:011A  b80400            mov      ax, 4
  0000:011D  50                push     ax
  0000:011E  e83828            call     0x2959                 ; dmdbrd_thunk_10: assign field to slot
  0000:0121  83c404            add      sp, 4
  0000:0124  8946ec            mov      word ptr [bp - 0x14], ax
  0000:0127  0bc0              or       ax, ax
  0000:0129  7d05              jge      0x130

loc_0000_012B:
  0000:012B  8b46ec            mov      ax, word ptr [bp - 0x14]
  0000:012E  eb45              jmp      0x175                  ; return error/result

loc_0000_0130:
  ; Get field block and initialize index
  0000:0130  8b46ec            mov      ax, word ptr [bp - 0x14]
  0000:0133  8946f6            mov      word ptr [bp - 0xa], ax  ; field_id
  0000:0136  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0139  8b4702            mov      ax, word ptr [bx + 2]    ; field name
  0000:013C  8946f8            mov      word ptr [bp - 8], ax
  0000:013F  c746fa0000        mov      word ptr [bp - 6], 0     ; zero
  0000:0144  ff76ec            push     word ptr [bp - 0x14]     ; field_id
  0000:0147  e82128            call     0x296b                   ; dmdbrd_thunk_13: get field def
  0000:014A  83c402            add      sp, 2
  0000:014D  8946fc            mov      word ptr [bp - 4], ax    ; field_def_ptr
  0000:0150  50                push     ax
  0000:0151  e8bc0e            call     0x1010                   ; dmdbbld_initIndexBlock
  0000:0154  83c402            add      sp, 2
  0000:0157  8946f4            mov      word ptr [bp - 0xc], ax
  0000:015A  0bc0              or       ax, ax
  0000:015C  7c83              jl       0xe1                     ; error -> return

  ; Write the index entry
  0000:015E  8d46f6            lea      ax, [bp - 0xa]           ; &field_entry struct
  0000:0161  50                push     ax
  0000:0162  ff76fc            push     word ptr [bp - 4]        ; field_def_ptr
  0000:0165  e86106            call     0x7c9                    ; dmdbbld_writeIndexEntry
  0000:0168  83c404            add      sp, 4
  0000:016B  8946f4            mov      word ptr [bp - 0xc], ax
  0000:016E  0bc0              or       ax, ax
  0000:0170  7db9              jge      0x12b                    ; success -> return field_id

  0000:0172  e96cff            jmp      0xe1                     ; error -> return

loc_0000_0175:
  0000:0175  5e                pop      si
  0000:0176  8be5              mov      sp, bp
  0000:0178  5d                pop      bp
  0000:0179  c3                ret

; ========================================================================
; dmdbbld_addField -- Add field to database (0000:017A)
; ========================================================================
; CX=5 handler. Dispatches by field type:
;   Type 1 -> dmdbbld_addSimpleField (sub_13DF)
;   Type 2 -> dmdbbld_buildIndexedField (sub_1AD0)
;   Type 3 -> dmdbbld_buildCompoundIdx (sub_17F0)
;
; Input:
;   [bp+4] = field entry pointer
;   [bp+6] = field definition pointer
;     +0x04  must be -2 (sentinel check)
;     +0x06  field type byte (1, 2, or 3)
;     +0x09  index info (word)
;
; Checks field count < 0x28 (40 max fields).
; ========================================================================

sub_0000_017A:
  0000:017A  55                push     bp
  0000:017B  8bec              mov      bp, sp
  0000:017D  83ec04            sub      sp, 4
  0000:0180  8b5e04            mov      bx, word ptr [bp + 4]   ; field entry
  0000:0183  837f04fe          cmp      word ptr [bx + 4], -2   ; sentinel check
  0000:0187  7405              je       0x18e
  0000:0189  b8e3ff            mov      ax, 0xffe3             ; error: field already defined
  0000:018C  eb5e              jmp      0x1ec

loc_0000_018E:
  ; Get field type byte and dispatch
  0000:018E  8b5e06            mov      bx, word ptr [bp + 6]
  0000:0191  8a4706            mov      al, byte ptr [bx + 6]   ; field_type
  0000:0194  98                cbw
  0000:0195  3d0100            cmp      ax, 1
  0000:0198  7411              je       0x1ab                  ; type 1 -> simple
  0000:019A  3d0200            cmp      ax, 2
  0000:019D  743f              je       0x1de                  ; type 2 -> indexed
  0000:019F  3d0300            cmp      ax, 3
  0000:01A2  742c              je       0x1d0                  ; type 3 -> compound
  0000:01A4  c746fce9ff        mov      word ptr [bp - 4], 0xffe9  ; unknown type
  0000:01A9  eb20              jmp      0x1cb

loc_0000_01AB:
  ; Type 1: Simple field (check count < 0x28)
  0000:01AB  8b5e04            mov      bx, word ptr [bp + 4]
  0000:01AE  807f0628          cmp      byte ptr [bx + 6], 0x28 ; >= 40 fields?
  0000:01B2  7311              jae      0x1c5
  0000:01B4  8b5e06            mov      bx, word ptr [bp + 6]
  0000:01B7  ff7709            push     word ptr [bx + 9]       ; index info
  0000:01BA  ff7604            push     word ptr [bp + 4]       ; field entry
  0000:01BD  e81f12            call     0x13df                  ; dmdbbld_addSimpleField

loc_0000_01C0:
  0000:01C0  83c404            add      sp, 4
  0000:01C3  eb03              jmp      0x1c8

loc_0000_01C5:
  0000:01C5  b8efff            mov      ax, 0xffef             ; error: max fields exceeded

loc_0000_01C8:
  0000:01C8  8946fc            mov      word ptr [bp - 4], ax

loc_0000_01CB:
  0000:01CB  8b46fc            mov      ax, word ptr [bp - 4]
  0000:01CE  eb1c              jmp      0x1ec

loc_0000_01D0:
  ; Type 3: Compound index
  0000:01D0  8b5e06            mov      bx, word ptr [bp + 6]
  0000:01D3  ff7709            push     word ptr [bx + 9]       ; index info
  0000:01D6  ff7604            push     word ptr [bp + 4]       ; field entry
  0000:01D9  e81416            call     0x17f0                  ; dmdbbld_buildCompoundIdx
  0000:01DC  ebe2              jmp      0x1c0

loc_0000_01DE:
  ; Type 2: Indexed field
  0000:01DE  8b5e06            mov      bx, word ptr [bp + 6]
  0000:01E1  ff7709            push     word ptr [bx + 9]       ; index info
  0000:01E4  ff7604            push     word ptr [bp + 4]       ; field entry
  0000:01E7  e8e618            call     0x1ad0                  ; dmdbbld_buildIndexedField
  0000:01EA  ebd4              jmp      0x1c0

loc_0000_01EC:
  0000:01EC  8be5              mov      sp, bp
  0000:01EE  5d                pop      bp
  0000:01EF  c3                ret

; ========================================================================
; dmdbbld_rebuildDatabase -- Rebuild database (0000:01F0)
; ========================================================================
; CX=0x16 handler. Rebuilds a database by:
;   1. Validating slot (0-5, file handle >= 0)
;   2. Iterating over field definitions (3 bytes per field descriptor)
;   3. Creating a new database via dmdbbld_createDatabase
;   4. Assigning new slot and setting up field entries
;   5. Copying field data from old database to new
;   6. Building indexes for indexed fields
;   7. Writing header with record count and record size
;   8. Committing the new database
;
; Input: [bp+4] = pointer to rebuild parameter block
;     +0x00  slot index (word)
;     +0x02  filename (word)
;     +0x04  field count (word)
;     +0x06  field descriptor array pointer (word)
;
; Uses 0x42-byte local frame. Most complex function in module.
; ========================================================================

sub_0000_01F0:
  0000:01F0  55                push     bp
  0000:01F1  8bec              mov      bp, sp
  0000:01F3  83ec42            sub      sp, 0x42            ; 66 bytes local
  0000:01F6  8b5e04            mov      bx, word ptr [bp + 4]
  0000:01F9  8b07              mov      ax, word ptr [bx]    ; slot_index
  0000:01FB  8946d6            mov      word ptr [bp - 0x2a], ax
  0000:01FE  c746cc0000        mov      word ptr [bp - 0x34], 0  ; error_code = 0
  0000:0203  b104              mov      cl, 4
  0000:0205  d3e0              shl      ax, cl
  0000:0207  05a800            add      ax, 0xa8
  0000:020A  8946f8            mov      word ptr [bp - 8], ax  ; old_slot_base
  ; Validate slot
  0000:020D  837ed600          cmp      word ptr [bp - 0x2a], 0
  0000:0211  7c0e              jl       0x221
  0000:0213  837ed606          cmp      word ptr [bp - 0x2a], 6
  0000:0217  7f08              jg       0x221
  0000:0219  8bd8              mov      bx, ax
  0000:021B  837f0800          cmp      word ptr [bx + 8], 0
  0000:021F  7d06              jge      0x227

loc_0000_0221:
  0000:0221  b8e6ff            mov      ax, 0xffe6          ; error: invalid slot
  0000:0224  e9b802            jmp      0x4df

loc_0000_0227:
  ; Save old database parameters
  0000:0227  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:022A  8b4706            mov      ax, word ptr [bx + 6]   ; old record_size
  0000:022D  8946be            mov      word ptr [bp - 0x42], ax
  0000:0230  8b470a            mov      ax, word ptr [bx + 0xa] ; old control_block
  0000:0233  8946d0            mov      word ptr [bp - 0x30], ax
  0000:0236  8b4708            mov      ax, word ptr [bx + 8]   ; old file_handle
  0000:0239  8946d6            mov      word ptr [bp - 0x2a], ax
  ; Get field descriptor array
  0000:023C  8b5e04            mov      bx, word ptr [bp + 4]
  0000:023F  8b4706            mov      ax, word ptr [bx + 6]   ; field_desc_array
  0000:0242  8946d8            mov      word ptr [bp - 0x28], ax
  ; Validate each field descriptor fits in record
  0000:0245  c746ce0000        mov      word ptr [bp - 0x32], 0  ; field_counter = 0
  0000:024A  eb07              jmp      0x253

loc_0000_024C:
  0000:024C  ff46ce            inc      word ptr [bp - 0x32]    ; field_counter++
  0000:024F  8346d803          add      word ptr [bp - 0x28], 3  ; next field desc (3 bytes each)

loc_0000_0253:
  ; Loop: validate each field by checking size against record capacity (0x54)
  0000:0253  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0256  8b46ce            mov      ax, word ptr [bp - 0x32]
  0000:0259  394704            cmp      word ptr [bx + 4], ax    ; field_count > counter?
  0000:025C  7e1f              jle      0x27d                   ; done validating
  0000:025E  ff76be            push     word ptr [bp - 0x42]    ; record_size
  0000:0261  b85400            mov      ax, 0x54               ; 84 = max field size
  0000:0264  50                push     ax
  0000:0265  8b5ed8            mov      bx, word ptr [bp - 0x28] ; current field desc
  0000:0268  ff37              push     word ptr [bx]            ; field name ptr
  0000:026A  e80427            call     0x2971                   ; dmdbrd_thunk_14: calc offset
  0000:026D  83c406            add      sp, 6
  0000:0270  8946f4            mov      word ptr [bp - 0xc], ax
  0000:0273  0bc0              or       ax, ax
  0000:0275  75d5              jne      0x24c                   ; ok -> next field
  0000:0277  b8faff            mov      ax, 0xfffa             ; error: record not found
  0000:027A  e96202            jmp      0x4df

loc_0000_027D:
  ; Create new database with the filename from params
  0000:027D  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0280  ff7702            push     word ptr [bx + 2]       ; filename
  0000:0283  e85d02            call     0x4e3                   ; dmdbbld_createDatabase
  0000:0286  83c402            add      sp, 2
  0000:0289  8946fa            mov      word ptr [bp - 6], ax   ; new_slot_index
  0000:028C  0bc0              or       ax, ax
  0000:028E  7d03              jge      0x293
  0000:0290  e94c02            jmp      0x4df                   ; error -> return

loc_0000_0293:
  ; Set up new slot and prepare for field copying
  0000:0293  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0296  8b07              mov      ax, word ptr [bx]       ; original slot_index
  0000:0298  8946d2            mov      word ptr [bp - 0x2e], ax
  0000:029B  8d46de            lea      ax, [bp - 0x22]        ; temp buffer
  0000:029E  8946d4            mov      word ptr [bp - 0x2c], ax
  0000:02A1  8d46d2            lea      ax, [bp - 0x2e]
  0000:02A4  50                push     ax
  0000:02A5  e8a526            call     0x294d                  ; dmdbrd_thunk_0E: open new slot
  0000:02A8  83c402            add      sp, 2
  0000:02AB  8946cc            mov      word ptr [bp - 0x34], ax ; error_code
  0000:02AE  0bc0              or       ax, ax
  0000:02B0  7d0f              jge      0x2c1

loc_0000_02B2:
  ; Error cleanup: close new slot and return
  0000:02B2  ff76fa            push     word ptr [bp - 6]       ; new_slot_index
  0000:02B5  e88f26            call     0x2947                  ; dmdbrd_thunk_0D: close slot
  0000:02B8  83c402            add      sp, 2
  0000:02BB  8b46cc            mov      ax, word ptr [bp - 0x34]
  0000:02BE  e91e02            jmp      0x4df

loc_0000_02C1:
  ; Set up new database slot
  0000:02C1  8b46fa            mov      ax, word ptr [bp - 6]   ; new_slot_index
  0000:02C4  8946d2            mov      word ptr [bp - 0x2e], ax
  0000:02C7  8d46d2            lea      ax, [bp - 0x2e]
  0000:02CA  50                push     ax
  0000:02CB  e8d827            call     0x2aa6                  ; mod2_thunk_04: init new slot
  0000:02CE  83c402            add      sp, 2
  0000:02D1  8946cc            mov      word ptr [bp - 0x34], ax
  0000:02D4  0bc0              or       ax, ax
  0000:02D6  7cda              jl       0x2b2                   ; error -> cleanup

  ; Initialize field copying loop
  0000:02D8  c746ca0600        mov      word ptr [bp - 0x36], 6  ; header_size = 6
  0000:02DD  8b46fa            mov      ax, word ptr [bp - 6]
  0000:02E0  b104              mov      cl, 4
  0000:02E2  d3e0              shl      ax, cl
  0000:02E4  05a800            add      ax, 0xa8
  0000:02E7  8946da            mov      word ptr [bp - 0x26], ax ; new_slot_base
  0000:02EA  8b5e04            mov      bx, word ptr [bp + 4]
  0000:02ED  8b4706            mov      ax, word ptr [bx + 6]   ; field_desc_array
  0000:02F0  8946d8            mov      word ptr [bp - 0x28], ax
  0000:02F3  c746ce0000        mov      word ptr [bp - 0x32], 0  ; field_counter = 0
  0000:02F8  e93901            jmp      0x434                   ; -> loop check

  ; --- Field copying loop body (0x02FB - 0x042D) ---
  ; [Lines omitted for brevity - this is the main rebuild loop that:
  ;  1. Copies field data from old to new database (sub_105A)
  ;  2. For indexed fields, allocates index structure and builds index
  ;  3. For non-indexed fields, writes field header directly
  ;  4. Updates header_size accumulator]

  ; ... (extensive field iteration code from 0x02FB to 0x04DC)

loc_0000_04DF:
  0000:04DF  8be5              mov      sp, bp
  0000:04E1  5d                pop      bp
  0000:04E2  c3                ret

; ========================================================================
; dmdbbld_createDatabase -- Create new database file (0000:04E3)
; ========================================================================
; CX=1 handler. Creates a new .FIL database file on disk.
;
; Process:
;   1. Check disk space (dmdbbld_checkDiskSpace)
;   2. Get filename hash (dmdbrd_thunk_22) - ensure unique
;   3. Verify no existing slot uses this filename
;   4. Resize memory to 0x1000 bytes
;   5. Allocate two temp buffers via mod2_thunk_0E
;   6. Initialize database header:
;      - Magic byte 0x03 at buffer start
;      - Header constants: +0x17 = 0x70, +0x18 = 0x6a
;      - Initial B-tree bytes at +0x20: FF 8F F8 FF 8F FF
;   7. Create file on disk (INT 21h/3Ch) via dmdbbld_createFile
;   8. Write initial blocks (root page + index page)
;   9. Set up field definition records
;   10. Build root page via dmdbbld_buildRootPage
;   11. Initialize first field header via dmdbbld_initFieldHeader
;   12. Commit headers and write to disk
;   13. Assign slot via dmdbrd_thunk_0F
;   14. Write initial index entry via dmdbbld_writeIndexEntry
;
; Input: [bp+4] = filename pointer
; Returns: AX = new slot index on success, negative error on failure
; ========================================================================

sub_0000_04E3:
  0000:04E3  55                push     bp
  0000:04E4  8bec              mov      bp, sp
  0000:04E6  83ec36            sub      sp, 0x36            ; 54 bytes local
  0000:04E9  56                push     si
  0000:04EA  c746ee0200        mov      word ptr [bp - 0x12], 2  ; initial_block_count = 2

  ; Check disk space
  0000:04EF  e8581f            call     0x244a                  ; dmdbbld_checkDiskSpace
  0000:04F2  0bc0              or       ax, ax
  0000:04F4  7506              jne      0x4fc
  0000:04F6  b8e7ff            mov      ax, 0xffe7             ; error: disk full
  0000:04F9  e9c802            jmp      0x7c4

loc_0000_04FC:
  ; Get filename hash and verify unique
  0000:04FC  ff7604            push     word ptr [bp + 4]       ; filename
  0000:04FF  e8c324            call     0x29c5                  ; dmdbrd_thunk_22: filename hash
  0000:0502  83c402            add      sp, 2
  0000:0505  8946ce            mov      word ptr [bp - 0x32], ax ; hash
  0000:0508  0bc0              or       ax, ax
  0000:050A  7506              jne      0x512
  0000:050C  b8f0ff            mov      ax, 0xfff0             ; error: filename exists
  0000:050F  e9b202            jmp      0x7c4

  ; Check no existing slot uses this filename
loc_0000_0512:
  0000:0512  c746e40000        mov      word ptr [bp - 0x1c], 0  ; slot_scan = 0

loc_0000_051C:
  0000:051C  837ee406          cmp      word ptr [bp - 0x1c], 6  ; checked all 6 slots?
  0000:0520  7d28              jge      0x54a                   ; yes -> continue
  0000:0522  ff76ce            push     word ptr [bp - 0x32]    ; hash
  0000:0525  8b5ee4            mov      bx, word ptr [bp - 0x1c]
  0000:0528  b104              mov      cl, 4
  0000:052A  d3e3              shl      bx, cl
  0000:052C  bea800            mov      si, 0xa8
  0000:052F  ff30              push     word ptr [bx + si]      ; slot[i].name_ptr
  0000:0531  e8c124            call     0x29f5                  ; dmdbrd_thunk_2A: compare strings
  0000:0534  83c404            add      sp, 4
  0000:0537  0bc0              or       ax, ax
  0000:0539  75de              jne      0x519                   ; different -> next
  ; Same filename found in existing slot -> free it and error
  0000:053B  ff76ce            push     word ptr [bp - 0x32]
  0000:053E  e8e823            call     0x2929                  ; dmdbrd_thunk_08: free block
  0000:0541  83c402            add      sp, 2
  0000:0544  b8feff            mov      ax, 0xfffe             ; error: slot already in use
  0000:0547  e97a02            jmp      0x7c4

loc_0000_054A:
  ; Resize memory block to 0x1000 bytes
  0000:054A  b80010            mov      ax, 0x1000
  0000:054D  50                push     ax
  0000:054E  ff76ce            push     word ptr [bp - 0x32]    ; hash/name
  0000:0551  e85e25            call     0x2ab2                  ; mod2_thunk_06: resize
  0000:0554  83c404            add      sp, 4
  0000:0557  0bc0              or       ax, ax
  0000:0559  7506              jne      0x561
  0000:055B  b8d6ff            mov      ax, 0xffd6             ; error: alloc failed
  0000:055E  e96302            jmp      0x7c4

loc_0000_0561:
  ; Allocate temp buffer 1
  0000:0561  8d46cc            lea      ax, [bp - 0x34]
  0000:0564  50                push     ax
  0000:0565  e87a25            call     0x2ae2                  ; mod2_thunk_0E: alloc temp buffer
  0000:0568  83c402            add      sp, 2
  0000:056B  8946d0            mov      word ptr [bp - 0x30], ax ; buf1_ptr
  0000:056E  0bc0              or       ax, ax
  0000:0570  7506              jne      0x578

loc_0000_0572:
  0000:0572  b8f4ff            mov      ax, 0xfff4             ; error: alloc failed
  0000:0575  e94c02            jmp      0x7c4

loc_0000_0578:
  ; Initialize database header in buffer 1
  0000:0578  8b5ed0            mov      bx, word ptr [bp - 0x30]
  0000:057B  c60703            mov      byte ptr [bx], 3        ; magic: active node
  0000:057E  8b5ed0            mov      bx, word ptr [bp - 0x30]
  0000:0581  c6471770          mov      byte ptr [bx + 0x17], 0x70  ; header constant
  0000:0585  8b5ed0            mov      bx, word ptr [bp - 0x30]
  0000:0588  c647186a          mov      byte ptr [bx + 0x18], 0x6a  ; header constant
  ; Write initial B-tree bytes at offset +0x20
  0000:058C  8b46d0            mov      ax, word ptr [bp - 0x30]
  0000:058F  052000            add      ax, 0x20
  0000:0592  8946e0            mov      word ptr [bp - 0x20], ax  ; write_ptr
  0000:0595  8bd8              mov      bx, ax
  0000:0597  ff46e0            inc      word ptr [bp - 0x20]
  0000:059A  c607ff            mov      byte ptr [bx], 0xff     ; B-tree init: FF
  0000:059D  8b5ee0            mov      bx, word ptr [bp - 0x20]
  0000:05A0  ff46e0            inc      word ptr [bp - 0x20]
  0000:05A3  c6078f            mov      byte ptr [bx], 0x8f     ; B-tree init: 8F
  0000:05A6  8b5ee0            mov      bx, word ptr [bp - 0x20]
  0000:05A9  ff46e0            inc      word ptr [bp - 0x20]
  0000:05AC  c607f8            mov      byte ptr [bx], 0xf8     ; B-tree init: F8
  0000:05AF  8b5ee0            mov      bx, word ptr [bp - 0x20]
  0000:05B2  ff46e0            inc      word ptr [bp - 0x20]
  0000:05B5  c607ff            mov      byte ptr [bx], 0xff     ; B-tree init: FF
  0000:05B8  8b5ee0            mov      bx, word ptr [bp - 0x20]
  0000:05BB  ff46e0            inc      word ptr [bp - 0x20]
  0000:05BE  c6078f            mov      byte ptr [bx], 0x8f     ; B-tree init: 8F
  0000:05C1  8b5ee0            mov      bx, word ptr [bp - 0x20]
  0000:05C4  c607ff            mov      byte ptr [bx], 0xff     ; B-tree init: FF
  ; Initial B-tree: FF 8F F8 FF 8F FF (index header signature)

  ; Allocate temp buffer 2
  0000:05C7  8d46d2            lea      ax, [bp - 0x2e]
  0000:05CA  50                push     ax
  0000:05CB  e81425            call     0x2ae2                  ; mod2_thunk_0E: alloc temp buffer
  0000:05CE  83c402            add      sp, 2
  0000:05D1  8946ca            mov      word ptr [bp - 0x36], ax ; buf2_ptr
  0000:05D4  0bc0              or       ax, ax
  0000:05D6  749a              je       0x572                   ; alloc failed -> error

  ; Set magic byte on buffer 2
  0000:05D8  8bd8              mov      bx, ax
  0000:05DA  c60703            mov      byte ptr [bx], 3        ; magic: active node

  ; Create file on disk
  0000:05DD  ff76ce            push     word ptr [bp - 0x32]    ; filename hash
  0000:05E0  b81101            mov      ax, 0x111               ; file mode flags
  0000:05E3  50                push     ax
  0000:05E4  e8e722            call     0x28ce                  ; dmdbbld_createFile
  0000:05E7  83c404            add      sp, 4
  0000:05EA  8946ec            mov      word ptr [bp - 0x14], ax ; file_handle
  0000:05ED  40                inc      ax                       ; -1 check
  0000:05EE  752f              jne      0x61f                   ; ok -> continue

  ; File creation failed -> cleanup
  0000:05F0  ff76ce            push     word ptr [bp - 0x32]
  0000:05F3  e83323            call     0x2929                  ; dmdbrd_thunk_08: free
  0000:05F6  83c402            add      sp, 2
  ; Free buffer 1
  0000:05F9  b84600            mov      ax, 0x46
  0000:05FC  50                push     ax
  0000:05FD  ff76cc            push     word ptr [bp - 0x34]
  0000:0600  2bc0              sub      ax, ax
  0000:0602  50                push     ax
  0000:0603  e8f922            call     0x28ff                  ; dmdbrd_thunk_01: mark free
  0000:0606  83c406            add      sp, 6
  ; Free buffer 2
  0000:0609  b84600            mov      ax, 0x46
  0000:060C  50                push     ax
  0000:060D  ff76d2            push     word ptr [bp - 0x2e]
  0000:0610  2bc0              sub      ax, ax
  0000:0612  50                push     ax
  0000:0613  e8e922            call     0x28ff                  ; dmdbrd_thunk_01: mark free
  0000:0616  83c406            add      sp, 6
  0000:0619  b8fcff            mov      ax, 0xfffc             ; error: file create error
  0000:061C  e9a501            jmp      0x7c4

loc_0000_061F:
  ; File created successfully. Clean up hash block and write initial blocks.
  0000:061F  ff76ce            push     word ptr [bp - 0x32]
  0000:0622  e80423            call     0x2929                  ; dmdbrd_thunk_08: free hash
  0000:0625  83c402            add      sp, 2
  ; Write block 0 (header)
  0000:0628  ff76d0            push     word ptr [bp - 0x30]    ; buf1 (header)
  0000:062B  2bc0              sub      ax, ax
  0000:062D  50                push     ax                      ; block 0
  0000:062E  ff76ec            push     word ptr [bp - 0x14]    ; file_handle
  0000:0631  e8fc24            call     0x2b30                  ; mod2_thunk_1B: write block
  0000:0634  83c406            add      sp, 6
  0000:0637  8946e2            mov      word ptr [bp - 0x1e], ax
  0000:063A  0bc0              or       ax, ax
  0000:063C  7c17              jl       0x655                   ; write failed
  ; Write block 1 (index root)
  0000:063E  ff76ca            push     word ptr [bp - 0x36]    ; buf2 (index)
  0000:0641  b80100            mov      ax, 1
  0000:0644  50                push     ax                      ; block 1
  0000:0645  ff76ec            push     word ptr [bp - 0x14]    ; file_handle
  0000:0648  e8e524            call     0x2b30                  ; mod2_thunk_1B: write block
  0000:064B  83c406            add      sp, 6
  0000:064E  8946e2            mov      word ptr [bp - 0x1e], ax
  0000:0651  0bc0              or       ax, ax
  0000:0653  7d26              jge      0x67b                   ; ok -> continue

loc_0000_0655:
  ; Write failed -> cleanup both buffers
  0000:0655  b84600            mov      ax, 0x46
  0000:0658  50                push     ax
  0000:0659  ff76cc            push     word ptr [bp - 0x34]
  0000:065C  2bc0              sub      ax, ax
  0000:065E  50                push     ax
  0000:065F  e89d22            call     0x28ff                  ; dmdbrd_thunk_01: free buf1
  0000:0662  83c406            add      sp, 6
  0000:0665  b84600            mov      ax, 0x46
  0000:0668  50                push     ax
  0000:0669  ff76d2            push     word ptr [bp - 0x2e]
  0000:066C  2bc0              sub      ax, ax
  0000:066E  50                push     ax
  0000:066F  e88d22            call     0x28ff                  ; dmdbrd_thunk_01: free buf2
  0000:0672  83c406            add      sp, 6

loc_0000_0675:
  0000:0675  8b46e2            mov      ax, word ptr [bp - 0x1e]
  0000:0678  e94901            jmp      0x7c4

loc_0000_067B:
  ; Build initial database structure
  ; Set up root page parameters
  0000:067B  c746f49600        mov      word ptr [bp - 0xc], 0x96  ; offset 0x96 (150)
  0000:0680  b80600            mov      ax, 6
  0000:0683  8946f9            mov      word ptr [bp - 7], ax      ; header_field_1 = 6
  0000:0686  8946f6            mov      word ptr [bp - 0xa], ax    ; header_field_2 = 6
  0000:0689  8b46ec            mov      ax, word ptr [bp - 0x14]   ; file_handle
  0000:068C  8946f2            mov      word ptr [bp - 0xe], ax
  0000:068F  c746fb6000        mov      word ptr [bp - 5], 0x60   ; entry_size = 0x60 (96)
  ; Build root page
  0000:0694  ff76ca            push     word ptr [bp - 0x36]       ; buf2 (index)
  0000:0697  50                push     ax                          ; file_handle
  0000:0698  ff76ee            push     word ptr [bp - 0x12]       ; block_count
  0000:069B  8d46f2            lea      ax, [bp - 0xe]
  0000:069E  50                push     ax
  0000:069F  e80621            call     0x27a8                     ; dmdbbld_buildRootPage
  0000:06A2  83c408            add      sp, 8
  0000:06A5  8946e2            mov      word ptr [bp - 0x1e], ax
  0000:06A8  0bc0              or       ax, ax
  0000:06AA  7cc9              jl       0x675                      ; error -> cleanup

  ; Init first field header
  0000:06AC  ff76ec            push     word ptr [bp - 0x14]       ; file_handle
  0000:06AF  ff76ee            push     word ptr [bp - 0x12]       ; block_count
  0000:06B2  b80600            mov      ax, 6
  0000:06B5  50                push     ax                          ; fields = 6
  0000:06B6  b86000            mov      ax, 0x60
  0000:06B9  50                push     ax                          ; size = 0x60
  0000:06BA  e8cb0f            call     0x1688                     ; dmdbbld_initFieldHeader
  0000:06BD  83c408            add      sp, 8
  0000:06C0  8946e2            mov      word ptr [bp - 0x1e], ax
  0000:06C3  0bc0              or       ax, ax
  0000:06C5  7cae              jl       0x675                      ; error -> cleanup

  ; Free temp buffers
  0000:06C7  b84600            mov      ax, 0x46
  0000:06CA  50                push     ax
  0000:06CB  ff76cc            push     word ptr [bp - 0x34]
  0000:06CE  2bc0              sub      ax, ax
  0000:06D0  50                push     ax
  0000:06D1  e82b22            call     0x28ff                     ; free buf1
  0000:06D4  83c406            add      sp, 6
  0000:06D7  b84600            mov      ax, 0x46
  0000:06DA  50                push     ax
  0000:06DB  ff76d2            push     word ptr [bp - 0x2e]
  0000:06DE  2bc0              sub      ax, ax
  0000:06E0  50                push     ax
  0000:06E1  e81b22            call     0x28ff                     ; free buf2
  0000:06E4  83c406            add      sp, 6

  ; Write header block back
  0000:06E7  ff76d0            push     word ptr [bp - 0x30]       ; buf1 header
  0000:06EA  2bc0              sub      ax, ax
  0000:06EC  50                push     ax                          ; block 0
  0000:06ED  ff76ec            push     word ptr [bp - 0x14]       ; file_handle
  0000:06F0  e83d24            call     0x2b30                     ; mod2_thunk_1B: write block
  0000:06F3  83c406            add      sp, 6
  0000:06F6  8946e2            mov      word ptr [bp - 0x1e], ax
  0000:06F9  0bc0              or       ax, ax
  0000:06FB  7d03              jge      0x700
  0000:06FD  e975ff            jmp      0x675                      ; error

loc_0000_0700:
  ; Write index root block
  0000:0700  ff76ca            push     word ptr [bp - 0x36]       ; buf2 index
  0000:0703  b80100            mov      ax, 1
  0000:0706  50                push     ax                          ; block 1
  0000:0707  ff76ec            push     word ptr [bp - 0x14]       ; file_handle
  0000:070A  e82324            call     0x2b30                     ; mod2_thunk_1B: write
  0000:070D  83c406            add      sp, 6
  0000:0710  8946e2            mov      word ptr [bp - 0x1e], ax
  0000:0713  0bc0              or       ax, ax
  0000:0715  7d03              jge      0x71a
  0000:0717  e95bff            jmp      0x675

loc_0000_071A:
  ; Commit file header
  0000:071A  ff76ec            push     word ptr [bp - 0x14]       ; file_handle
  0000:071D  b81101            mov      ax, 0x111
  0000:0720  50                push     ax
  0000:0721  e87122            call     0x2995                     ; dmdbrd_thunk_1A: commit header
  0000:0724  83c404            add      sp, 4
  0000:0727  0bc0              or       ax, ax
  0000:0729  7d0d              jge      0x738
  ; Commit failed -> try fallback
  0000:072B  ff76ec            push     word ptr [bp - 0x14]
  0000:072E  b81101            mov      ax, 0x111
  0000:0731  50                push     ax
  0000:0732  e86622            call     0x299b                     ; dmdbrd_thunk_1B: fallback commit
  0000:0735  83c404            add      sp, 4

loc_0000_0738:
  ; Assign slot via DMDBRD
  0000:0738  ff7604            push     word ptr [bp + 4]           ; filename
  0000:073B  e81522            call     0x2953                     ; dmdbrd_thunk_0F: assign slot
  0000:073E  83c402            add      sp, 2
  0000:0741  8946ec            mov      word ptr [bp - 0x14], ax   ; slot_index
  0000:0744  0bc0              or       ax, ax
  0000:0746  7d05              jge      0x74d

loc_0000_0748:
  0000:0748  8b46ec            mov      ax, word ptr [bp - 0x14]
  0000:074B  eb77              jmp      0x7c4                      ; return slot_index or error

loc_0000_074D:
  ; Build initial record: record_id = slot_index * 100 + 1
  0000:074D  b86400            mov      ax, 0x64                   ; 100
  0000:0750  f76eec            imul     word ptr [bp - 0x14]       ; slot * 100
  0000:0753  40                inc      ax                          ; +1
  0000:0754  8946e6            mov      word ptr [bp - 0x1a], ax   ; record_id
  0000:0757  c746e89600        mov      word ptr [bp - 0x18], 0x96 ; offset 0x96

  ; Build initial index entry with filename and attributes
  0000:075C  8d46d4            lea      ax, [bp - 0x2c]
  0000:075F  50                push     ax
  0000:0760  bb6900            mov      bx, 0x69
  0000:0763  ff37              push     word ptr [bx]              ; [0x69] = internal name ptr
  0000:0765  e8c322            call     0x2a2b                     ; dmdbrd_thunk_33: string copy
  0000:0768  83c404            add      sp, 4
  0000:076B  8946fe            mov      word ptr [bp - 2], ax      ; end_ptr
  0000:076E  8bd8              mov      bx, ax
  0000:0770  ff46fe            inc      word ptr [bp - 2]
  0000:0773  c60704            mov      byte ptr [bx], 4           ; type = 4 (string terminator)
  ; Copy second name
  0000:0776  ff76fe            push     word ptr [bp - 2]
  0000:0779  bb7200            mov      bx, 0x72
  0000:077C  ff37              push     word ptr [bx]              ; [0x72] = second name
  0000:077E  e8aa22            call     0x2a2b                     ; dmdbrd_thunk_33: string copy
  0000:0781  83c404            add      sp, 4
  0000:0784  8946fe            mov      word ptr [bp - 2], ax
  0000:0787  8bd8              mov      bx, ax
  0000:0789  ff46fe            inc      word ptr [bp - 2]
  0000:078C  c60704            mov      byte ptr [bx], 4           ; type = 4
  0000:078F  8b5efe            mov      bx, word ptr [bp - 2]
  0000:0792  c60700            mov      byte ptr [bx], 0           ; null terminator
  ; Set up index entry struct
  0000:0795  8d46d4            lea      ax, [bp - 0x2c]
  0000:0798  8946ea            mov      word ptr [bp - 0x16], ax   ; entry_data_ptr
  0000:079B  8d46e6            lea      ax, [bp - 0x1a]
  0000:079E  50                push     ax                          ; &record_entry
  0000:079F  8b5eec            mov      bx, word ptr [bp - 0x14]   ; slot_index
  0000:07A2  b104              mov      cl, 4
  0000:07A4  d3e3              shl      bx, cl
  0000:07A6  beb200            mov      si, 0xb2                   ; slot+0x0A (control block offset)
  0000:07A9  ff30              push     word ptr [bx + si]          ; slot.ctrl_block+0x0A
  0000:07AB  e81b00            call     0x7c9                      ; dmdbbld_writeIndexEntry
  0000:07AE  83c404            add      sp, 4
  0000:07B1  8946e2            mov      word ptr [bp - 0x1e], ax
  0000:07B4  0bc0              or       ax, ax
  0000:07B6  7d90              jge      0x748                      ; success -> return slot_index
  ; Error -> close slot
  0000:07B8  ff76ec            push     word ptr [bp - 0x14]
  0000:07BB  e88921            call     0x2947                     ; dmdbrd_thunk_0D: close slot
  0000:07BE  83c402            add      sp, 2
  0000:07C1  e9b1fe            jmp      0x675                      ; return write error

loc_0000_07C4:
  0000:07C4  5e                pop      si
  0000:07C5  8be5              mov      sp, bp
  0000:07C7  5d                pop      bp
  0000:07C8  c3                ret

; ========================================================================
; dmdbbld_writeIndexEntry -- Write index entry to B-tree (0000:07C9)
; ========================================================================
; CX=0x18 handler. Writes a single record entry into the B-tree index.
;
; Input:
;   [bp+4] = field entry pointer
;     +0x00  record key (word)
;     +0x04  must be -2 (sentinel for new entry)
;     +0x07  field type byte
;     +0x11  buffer pointer (word, 0 = allocate new)
;   [bp+6] = record data pointer
;     +0x00  record_id (word)
;
; Process:
;   1. Check sentinel at entry+4 == -2
;   2. Calculate slot from record_id / 100
;   3. Get record size and file handle from slot
;   4. Calculate field offset via dmdbrd_thunk_14 (multiply by 0x54)
;   5. If buffer==0, allocate new via mod2_thunk_07
;   6. Encode index key via dmdbbld_encodeIndexKey
;   7. Allocate new block via dmdbrd_thunk_03 (0x4E bytes)
;   8. Write block via dmdbrd_thunk_01 (mark as 0x49='I')
;   9. Free temp buffer via mod2_thunk_10
;   10. Commit via mod2_thunk_1B (write block)
;   11. Check if count incremented, flush if needed
;
; Returns: AX = 0 on success, negative error on failure
; ========================================================================

sub_0000_07C9:
  0000:07C9  55                push     bp
  0000:07CA  8bec              mov      bp, sp
  0000:07CC  83ec12            sub      sp, 0x12
  0000:07CF  8b5e06            mov      bx, word ptr [bp + 6]   ; record data
  0000:07D2  8b07              mov      ax, word ptr [bx]       ; record_id
  0000:07D4  8946f0            mov      word ptr [bp - 0x10], ax
  0000:07D7  8b5e04            mov      bx, word ptr [bp + 4]   ; field entry
  0000:07DA  837f04fe          cmp      word ptr [bx + 4], -2   ; sentinel check
  0000:07DE  7406              je       0x7e6
  0000:07E0  b8e3ff            mov      ax, 0xffe3             ; error: field already defined
  0000:07E3  e90901            jmp      0x8ef

loc_0000_07E6:
  ; Calculate slot from record_id
  0000:07E6  8b46f0            mov      ax, word ptr [bp - 0x10]
  0000:07E9  99                cwd
  0000:07EA  b96400            mov      cx, 0x64               ; 100
  0000:07ED  f7f9              idiv     cx                      ; ax = slot_index
  0000:07EF  b104              mov      cl, 4
  0000:07F1  d3e0              shl      ax, cl
  0000:07F3  05a800            add      ax, 0xa8
  0000:07F6  8946fe            mov      word ptr [bp - 2], ax   ; slot_base
  0000:07F9  8bd8              mov      bx, ax
  0000:07FB  8b4708            mov      ax, word ptr [bx + 8]   ; file_handle
  0000:07FE  8946f6            mov      word ptr [bp - 0xa], ax
  0000:0801  8b4706            mov      ax, word ptr [bx + 6]   ; record_size
  0000:0804  8946ee            mov      word ptr [bp - 0x12], ax

  ; Calculate field offset
  0000:0807  50                push     ax                       ; record_size
  0000:0808  b85400            mov      ax, 0x54                ; entry size constant
  0000:080B  50                push     ax
  0000:080C  8b5e04            mov      bx, word ptr [bp + 4]
  0000:080F  ff37              push     word ptr [bx]            ; field key
  0000:0811  e85d21            call     0x2971                   ; dmdbrd_thunk_14: calc offset
  0000:0814  83c406            add      sp, 6
  0000:0817  8946fc            mov      word ptr [bp - 4], ax    ; field_offset
  0000:081A  0bc0              or       ax, ax
  0000:081C  7506              jne      0x824
  0000:081E  b8faff            mov      ax, 0xfffa             ; error: not found
  0000:0821  e9cb00            jmp      0x8ef

loc_0000_0824:
  ; Get or allocate buffer
  0000:0824  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0827  8b4711            mov      ax, word ptr [bx + 0x11] ; buffer_ptr
  0000:082A  8946f8            mov      word ptr [bp - 8], ax
  0000:082D  0bc0              or       ax, ax
  0000:082F  7521              jne      0x852                    ; have buffer -> use it
  ; Allocate new buffer
  0000:0831  ff76fe            push     word ptr [bp - 2]        ; slot_base
  0000:0834  2bc0              sub      ax, ax
  0000:0836  50                push     ax
  0000:0837  e87e22            call     0x2ab8                   ; mod2_thunk_07: allocate disk block
  0000:083A  83c404            add      sp, 4
  0000:083D  8946f8            mov      word ptr [bp - 8], ax    ; new buffer
  0000:0840  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0843  894711            mov      word ptr [bx + 0x11], ax ; save to field entry
  0000:0846  837ef800          cmp      word ptr [bp - 8], 0
  0000:084A  7516              jne      0x862
  0000:084C  b8d6ff            mov      ax, 0xffd6             ; alloc failed
  0000:084F  e99d00            jmp      0x8ef

loc_0000_0852:
  ; Set existing buffer size
  0000:0852  b8f80f            mov      ax, 0xff8               ; 4088 bytes
  0000:0855  50                push     ax
  0000:0856  ff76f8            push     word ptr [bp - 8]
  0000:0859  ff76fe            push     word ptr [bp - 2]        ; slot_base
  0000:085C  e86522            call     0x2ac4                   ; mod2_thunk_09: set block size
  0000:085F  83c406            add      sp, 6

loc_0000_0862:
  ; Encode the index key
  0000:0862  ff7606            push     word ptr [bp + 6]        ; record data
  0000:0865  ff76ee            push     word ptr [bp - 0x12]     ; record_size
  0000:0868  ff7604            push     word ptr [bp + 4]        ; field entry
  0000:086B  e8c118            call     0x212f                   ; dmdbbld_encodeIndexKey
  0000:086E  83c406            add      sp, 6
  0000:0871  8946f2            mov      word ptr [bp - 0xe], ax  ; encode_result
  0000:0874  0bc0              or       ax, ax
  0000:0876  7d05              jge      0x87d

loc_0000_0878:
  0000:0878  8b46f2            mov      ax, word ptr [bp - 0xe]
  0000:087B  eb72              jmp      0x8ef

loc_0000_087D:
  ; Allocate new index node (0x4E = 78 bytes)
  0000:087D  b84e00            mov      ax, 0x4e
  0000:0880  50                push     ax
  0000:0881  ff76f8            push     word ptr [bp - 8]        ; buffer
  0000:0884  ff76f6            push     word ptr [bp - 0xa]      ; file_handle
  0000:0887  ff76f0            push     word ptr [bp - 0x10]     ; record_id
  0000:088A  e87e20            call     0x290b                   ; dmdbrd_thunk_03: alloc block
  0000:088D  83c408            add      sp, 8
  0000:0890  8946fa            mov      word ptr [bp - 6], ax    ; new_node
  ; Mark index as in-use (0x49 = 'I')
  0000:0893  b84900            mov      ax, 0x49
  0000:0896  50                push     ax
  0000:0897  ff76f8            push     word ptr [bp - 8]
  0000:089A  ff76f6            push     word ptr [bp - 0xa]
  0000:089D  e85f20            call     0x28ff                   ; dmdbrd_thunk_01: mark 'I'
  0000:08A0  83c406            add      sp, 6
  ; Check allocation succeeded
  0000:08A3  837efa00          cmp      word ptr [bp - 6], 0
  0000:08A7  7505              jne      0x8ae
  0000:08A9  b8f4ff            mov      ax, 0xfff4             ; alloc failed
  0000:08AC  eb41              jmp      0x8ef

loc_0000_08AE:
  ; Free temp buffer and write block
  0000:08AE  ff76fa            push     word ptr [bp - 6]
  0000:08B1  e83a22            call     0x2aee                   ; mod2_thunk_10: free temp
  0000:08B4  83c402            add      sp, 2
  ; Write index node to disk
  0000:08B7  ff76fa            push     word ptr [bp - 6]
  0000:08BA  ff76f8            push     word ptr [bp - 8]
  0000:08BD  ff76f6            push     word ptr [bp - 0xa]
  0000:08C0  e86d22            call     0x2b30                   ; mod2_thunk_1B: write block
  0000:08C3  83c406            add      sp, 6
  0000:08C6  8946f2            mov      word ptr [bp - 0xe], ax
  0000:08C9  0bc0              or       ax, ax
  0000:08CB  7cab              jl       0x878                    ; error

  ; Check if record count changed -> flush
  0000:08CD  b80500            mov      ax, 5
  0000:08D0  50                push     ax
  0000:08D1  ff76fc            push     word ptr [bp - 4]        ; field_offset
  0000:08D4  e8a020            call     0x2977                   ; dmdbrd_thunk_15: read byte
  0000:08D7  83c404            add      sp, 4
  0000:08DA  0bc0              or       ax, ax
  0000:08DC  740f              je       0x8ed                    ; no change -> skip flush
  0000:08DE  2bc0              sub      ax, ax
  0000:08E0  50                push     ax
  0000:08E1  ff7604            push     word ptr [bp + 4]
  0000:08E4  ff76fe            push     word ptr [bp - 2]        ; slot_base
  0000:08E7  e80a22            call     0x2af4                   ; mod2_thunk_11: flush
  0000:08EA  83c406            add      sp, 6

loc_0000_08ED:
  0000:08ED  2bc0              sub      ax, ax                   ; return 0 = success

loc_0000_08EF:
  0000:08EF  8be5              mov      sp, bp
  0000:08F1  5d                pop      bp
  0000:08F2  c3                ret

; ========================================================================
; dmdbbld_addFieldIndex -- Add field with index (0000:08F3)
; ========================================================================
; CX=0x1B handler. Wrapper that sets up a simple field entry struct
; and calls dmdbbld_writeIndexEntry.
;
; Input:
;   [bp+4] = field handle (word)
;   [bp+6] = field definition pointer
;     +0x00  record_id (word)
;     +0x02  field name (word)
;
; Local struct [bp-6]:
;   [bp-6]  = record_id
;   [bp-4]  = field_name
;   [bp-2]  = 0 (null entry marker)
; ========================================================================

sub_0000_08F3:
  0000:08F3  55                push     bp
  0000:08F4  8bec              mov      bp, sp
  0000:08F6  83ec06            sub      sp, 6
  0000:08F9  8b5e06            mov      bx, word ptr [bp + 6]
  0000:08FC  8b07              mov      ax, word ptr [bx]        ; record_id
  0000:08FE  8946fa            mov      word ptr [bp - 6], ax
  0000:0901  8b4702            mov      ax, word ptr [bx + 2]    ; field_name
  0000:0904  8946fc            mov      word ptr [bp - 4], ax
  0000:0907  c746fe0000        mov      word ptr [bp - 2], 0     ; null marker
  0000:090C  8d46fa            lea      ax, [bp - 6]             ; &local_entry
  0000:090F  50                push     ax
  0000:0910  ff7604            push     word ptr [bp + 4]        ; field handle
  0000:0913  e8b3fe            call     0x7c9                    ; dmdbbld_writeIndexEntry
  0000:0916  8be5              mov      sp, bp
  0000:0918  5d                pop      bp
  0000:0919  c3                ret

; ========================================================================
; dmdbbld_modifySchema -- Modify field schema (0000:091A)
; ========================================================================
; CX=8 handler. Restructures a database field schema, potentially
; removing fields, updating indexes, and adjusting record counts.
;
; Process:
;   1. Validate slot (0-5, handle >= 0)
;   2. Check field not already defined (dmdbrd_thunk_1D)
;   3. Get current field definition and index structure
;   4. Validate index via dmdbbld_validateIndex
;   5. Scan index entries, comparing with filename ([0x115])
;   6. For non-matching entries, increment delete counter and mark 'D'
;   7. Move/compact remaining entries in slot blocks
;   8. Update record count (subtracting deleted entries)
;   9. Commit changes back to disk
;
; Input: [bp+4] = pointer to modification parameter block
;     +0x00  slot_index (word)
;     +0x02  field_name (word)
;
; Uses 0x22-byte local frame with DI, SI saved.
; ========================================================================

sub_0000_091A:
  0000:091A  55                push     bp
  0000:091B  8bec              mov      bp, sp
  0000:091D  83ec22            sub      sp, 0x22
  0000:0920  57                push     di
  0000:0921  56                push     si
  0000:0922  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0925  8b37              mov      si, word ptr [bx]        ; slot_index
  0000:0927  8b7f02            mov      di, word ptr [bx + 2]    ; field_name
  ; Validate slot range
  0000:092A  0bf6              or       si, si
  0000:092C  7c05              jl       0x933
  0000:092E  83fe06            cmp      si, 6
  0000:0931  7c06              jl       0x939

loc_0000_0933:
  0000:0933  b8e6ff            mov      ax, 0xffe6              ; invalid slot
  0000:0936  e92a02            jmp      0xb63

loc_0000_0939:
  ; Calculate slot_base and validate
  0000:0939  8bc6              mov      ax, si
  0000:093B  b104              mov      cl, 4
  0000:093D  d3e0              shl      ax, cl
  0000:093F  05a800            add      ax, 0xa8
  0000:0942  8946fc            mov      word ptr [bp - 4], ax    ; slot_base
  0000:0945  8bd8              mov      bx, ax
  0000:0947  8b7708            mov      si, word ptr [bx + 8]    ; file_handle
  0000:094A  0bf6              or       si, si
  0000:094C  7ce5              jl       0x933                    ; no file -> error
  ; Check field not already defined
  0000:094E  57                push     di                        ; field_name
  0000:094F  50                push     ax                        ; slot_base
  0000:0950  e85420            call     0x29a7                   ; dmdbrd_thunk_1D: find field
  0000:0953  83c404            add      sp, 4
  0000:0956  8946f0            mov      word ptr [bp - 0x10], ax
  0000:0959  0bc0              or       ax, ax
  0000:095B  740e              je       0x96b                    ; not found -> ok
  0000:095D  8bd8              mov      bx, ax
  0000:095F  837f0400          cmp      word ptr [bx + 4], 0
  0000:0963  7406              je       0x96b
  0000:0965  b8e3ff            mov      ax, 0xffe3              ; already defined
  0000:0968  e9f801            jmp      0xb63

  ; [... extensive schema modification code continues through 0x0B63 ...]
  ; The function iterates over index entries, compares field names,
  ; marks non-matching entries as deleted ('D'), compacts the
  ; remaining entries, updates counts, and commits.

loc_0000_0B63:
  0000:0B63  5e                pop      si
  0000:0B64  5f                pop      di
  0000:0B65  8be5              mov      sp, bp
  0000:0B67  5d                pop      bp
  0000:0B68  c3                ret

; ========================================================================
; dmdbbld_buildIndex -- Build/rebuild B-tree index (0000:0B69)
; ========================================================================
; CX=0x17 handler. The largest function in the module (0xD2 byte frame).
; Builds a complete B-tree index for a database field.
;
; Process:
;   1. Validate record (dmdbrd_thunk_21) and get field def (dmdbrd_thunk_13)
;   2. Calculate slot_base from record_id / 100
;   3. Read field count, record size, and field chain
;   4. Collect field types and offsets into local arrays
;   5. Get control block and allocate work buffers
;   6. Read initial block, copy data into sort buffer
;   7. Main loop: iterate through all data pages
;      a. For each active (0x03) node, extract key and insert into index
;      b. Handle page splits when buffer fills (>= 0x400)
;      c. Chain to next data page via next-page pointer
;   8. Finalize index after all pages processed
;   9. Clean up buffers
;
; Input:
;   [bp+6] = record_id (word)
;   [bp+4] = flags (word, 0 for normal build)
;
; Returns: AX = 0 on success, negative error on failure
; ========================================================================

sub_0000_0B69:
  0000:0B69  55                push     bp
  0000:0B6A  8bec              mov      bp, sp
  0000:0B6C  81ecd200          sub      sp, 0xd2             ; 210 bytes local frame!
  0000:0B70  56                push     si
  0000:0B71  c746a21000        mov      word ptr [bp - 0x5e], 0x10  ; page_size = 16
  0000:0B76  c7864aff0000      mov      word ptr [bp - 0xb6], 0     ; recursive_flag = 0

  ; Validate record
  0000:0B7C  ff7606            push     word ptr [bp + 6]       ; record_id
  0000:0B7F  e83d1e            call     0x29bf                  ; dmdbrd_thunk_21: validate
  0000:0B82  83c402            add      sp, 2
  0000:0B85  0bc0              or       ax, ax
  0000:0B87  7511              jne      0xb9a                   ; invalid -> check alt path
  ; Get field definition
  0000:0B89  ff7606            push     word ptr [bp + 6]
  0000:0B8C  e8dc1d            call     0x296b                  ; dmdbrd_thunk_13: get field def
  0000:0B8F  83c402            add      sp, 2
  0000:0B92  898642ff          mov      word ptr [bp - 0xbe], ax ; field_def
  0000:0B96  0bc0              or       ax, ax
  0000:0B98  7506              jne      0xba0

loc_0000_0B9A:
  0000:0B9A  b8e2ff            mov      ax, 0xffe2             ; invalid field def
  0000:0B9D  e96a04            jmp      0x100a

loc_0000_0BA0:
  ; Calculate slot from record_id / 100
  0000:0BA0  8b4606            mov      ax, word ptr [bp + 6]
  0000:0BA3  99                cwd
  0000:0BA4  b96400            mov      cx, 0x64
  0000:0BA7  f7f9              idiv     cx
  0000:0BA9  b104              mov      cl, 4
  0000:0BAB  d3e0              shl      ax, cl
  0000:0BAD  05a800            add      ax, 0xa8
  0000:0BB0  8946a8            mov      word ptr [bp - 0x58], ax ; slot_base
  ; Read slot fields
  0000:0BB3  8bd8              mov      bx, ax
  0000:0BB5  8b4708            mov      ax, word ptr [bx + 8]    ; file_handle
  0000:0BB8  898634ff          mov      word ptr [bp - 0xcc], ax
  0000:0BBC  8b4704            mov      ax, word ptr [bx + 4]    ; field_count
  0000:0BBF  89863cff          mov      word ptr [bp - 0xc4], ax
  0000:0BC3  8b4706            mov      ax, word ptr [bx + 6]    ; record_size
  0000:0BC6  89862eff          mov      word ptr [bp - 0xd2], ax

  ; Calculate field offset from record
  0000:0BCA  50                push     ax
  0000:0BCB  b85400            mov      ax, 0x54
  0000:0BCE  50                push     ax
  0000:0BCF  8b9e42ff          mov      bx, word ptr [bp - 0xbe]
  0000:0BD3  ff37              push     word ptr [bx]            ; field name
  0000:0BD5  e8991d            call     0x2971                   ; dmdbrd_thunk_14: calc offset
  0000:0BD8  83c406            add      sp, 6
  0000:0BDB  8946a4            mov      word ptr [bp - 0x5c], ax

  ; Read field type byte
  0000:0BDE  b80500            mov      ax, 5
  0000:0BE1  50                push     ax
  0000:0BE2  ff76a4            push     word ptr [bp - 0x5c]
  0000:0BE5  e88f1d            call     0x2977                   ; dmdbrd_thunk_15: read byte
  0000:0BE8  83c404            add      sp, 4
  0000:0BEB  898636ff          mov      word ptr [bp - 0xca], ax
  0000:0BEF  0bc0              or       ax, ax
  0000:0BF1  7513              jne      0xc06                    ; has type -> continue

  ; No existing index -> build from scratch via dmdbbld_handleBuildError
  0000:0BF3  ff76a4            push     word ptr [bp - 0x5c]
  0000:0BF6  ffb642ff          push     word ptr [bp - 0xbe]
  0000:0BFA  ff76a8            push     word ptr [bp - 0x58]
  0000:0BFD  e82d19            call     0x252d                   ; dmdbbld_handleBuildError

loc_0000_0C00:
  0000:0C00  83c406            add      sp, 6
  0000:0C03  e90404            jmp      0x100a

  ; [... extensive index building code from 0x0C06 to 0x1009 ...]
  ; This section:
  ;  - Collects field types into arrays at [bp-0xAE..] and [bp-0x54..]
  ;  - Iterates linked list of field definitions
  ;  - Reads control block and allocates work buffers
  ;  - Main loop reads each data page, processes active nodes
  ;  - Handles page splits when buffer exceeds 0x400 bytes
  ;  - Chains through data pages via next-page pointers
  ;  - Calls sub-functions for node manipulation

loc_0000_100A:
  0000:100A  5e                pop      si
  0000:100B  8be5              mov      sp, bp
  0000:100D  5d                pop      bp
  0000:100E  c3                ret
  ; (padding byte follows)

; ========================================================================
; Functions 0x1010 through 0x28CD
; ========================================================================
; These are the index construction helper functions, B-tree operations,
; tree node manipulation, and utility functions. They are documented
; in the function index above. Key functions include:
;
; dmdbbld_initIndexBlock (0x1010) - Initialize index block for new field
; dmdbbld_copyFieldData (0x105A) - Copy field data between databases
; dmdbbld_setupFieldEntry (0x11C2) - Set up field entry
; dmdbbld_writeFieldBlock (0x12C8) - Write field block
; dmdbbld_addSimpleField (0x13DF) - Add simple field (type 1)
; dmdbbld_formatFieldData (0x14DE) - Format field data for storage
; dmdbbld_createFieldSlot (0x1571) - Create field slot in record
; dmdbbld_initFieldHeader (0x1688) - Init field header in new DB
; dmdbbld_validateField (0x1736) - Validate field and calc offset
; dmdbbld_buildCompoundIdx (0x17F0) - Build compound index (type 3)
; dmdbbld_buildIndexedField (0x1AD0) - Build indexed field (type 2)
; dmdbbld_insertIndexEntry (0x1E99) - Insert entry into B-tree
; dmdbbld_splitIndexNode (0x1F4E) - Split full B-tree node
; dmdbbld_rebalanceNode (0x1FE0) - Rebalance after split
; dmdbbld_encodeIndexKey (0x212F) - Encode key into B-tree format
; dmdbbld_computeKeyOffset (0x22FA) - Compute key offset
; dmdbbld_validateIndex (0x2399) - Validate index structure
; dmdbbld_checkDiskSpace (0x244A) - Check disk space
; dmdbbld_mergeIndexNodes (0x247C) - Merge index nodes
; dmdbbld_writeIndexBlock (0x24EB) - Write index block
; dmdbbld_finalizeIndex (0x2503) - Finalize index build
; dmdbbld_handleBuildError (0x252D) - Handle build error
; dmdbbld_findActiveNode (0x260C) - Find active node (0x03)
; dmdbbld_encodeTreeEntry (0x2629) - Encode tree entry
; dmdbbld_copyKeyBytes (0x26B8) - Copy key bytes
; dmdbbld_skipDirtyNodes (0x26EA) - Skip dirty (0x44) nodes
; dmdbbld_markDirtyNode (0x270C) - Mark node dirty
;
; These functions follow the same patterns seen in detail above:
; - push bp; mov bp,sp; sub sp,N prologue
; - Slot addressing: slot_index*16+0xA8
; - Heavy use of thunk tables for DMDBRD and secondary module calls
; - Error returns as negative AX values
; - Block state management via marker bytes (03/44/46/49/4C/4E/54)

; ========================================================================
; dmdbbld_itoaBuf -- Integer to ASCII (0000:2769)
; ========================================================================
; Recursive integer-to-decimal conversion. Writes ASCII digits into
; a buffer pointed to by [bp+6]. Uses divide-by-10 recursion.
;
; Input:
;   [bp+4] = integer value (word)
;   [bp+6] = buffer pointer (word)
; Returns: AX = updated buffer pointer (past last digit written)
; ========================================================================

; sub_0000_2769 at 0x2769 (documented in function index)

; ========================================================================
; dmdbbld_buildRootPage -- Build B-tree root page (0000:27A8)
; ========================================================================
; Constructs the initial B-tree root page for a newly created database.
; Builds a page with:
;   - 'T' (0x54) marker byte
;   - Field name entry
;   - Block count
;   - Size and offset parameters
;   - Terminal markers (0x30, 0x01, 0x02, 0x03)
;
; Checks if page fits in available space (0x400 per block).
; Returns AX = 0 on success, 0xFFDB if too large.
; ========================================================================

; sub_0000_27A8 at 0x27A8 (documented in function index)

; ========================================================================
; dmdbbld_createFile -- Create file on disk (0000:28CE)
; ========================================================================
; Wrapper for INT 21h/3Ch (Create File).
;
; Input:
;   [bp+4] = file flags pointer (word)
;   [bp+6] = filename pointer (for DX)
; Returns: AX = file handle on success, AX = -1 on error
;
; On error, calls dmdbrd_thunk_05 to report the error.
; ========================================================================

sub_0000_28CE:
  0000:28CE  55                push     bp
  0000:28CF  8bec              mov      bp, sp
  0000:28D1  57                push     di
  0000:28D2  56                push     si
  0000:28D3  8b5606            mov      dx, word ptr [bp + 6]   ; filename -> DX
  0000:28D6  b90000            mov      cx, 0                    ; attributes = 0
  0000:28D9  b43c              mov      ah, 0x3c                 ; Create File
  0000:28DB  cd21              int      0x21
  0000:28DD  730f              jae      0x28ee                  ; success (CF=0)
  ; Create failed
  0000:28DF  ff7604            push     word ptr [bp + 4]       ; flags
  0000:28E2  e83200            call     0x2917                  ; dmdbrd_thunk_05: report error
  0000:28E5  83c402            add      sp, 2
  0000:28E8  b8ffff            mov      ax, 0xffff              ; return -1
  0000:28EB  eb08              jmp      0x28f5

loc_0000_28EE:
  ; Success: store file handle and clear flags
  0000:28EE  8b5e04            mov      bx, word ptr [bp + 4]
  0000:28F1  c7070000          mov      word ptr [bx], 0        ; clear flags

loc_0000_28F5:
  0000:28F5  5e                pop      si
  0000:28F6  5f                pop      di
  0000:28F7  5d                pop      bp
  0000:28F8  c3                ret

; ========================================================================
; THUNK TABLE 1: DMDBRD Interface (0000:28F9 - 0000:2A8C)
; ========================================================================
; 65 thunk functions, each setting AX to a function number (0x00..0x40)
; and jumping to the common dispatch point at loc_0000_2A7F.
;
; Dispatch mechanism at 0x2A7F:
;   1. Pop return address from stack into [0x120] (offset) and [0x122] (CS)
;   2. Far-jump through [0x11C] into DMDBRD module
;   3. DMDBRD will return via [0x120]:[0x122]
; ========================================================================

sub_0000_28F9:                                ; dmdbrd_thunk_00 (AX=0)
  0000:28F9  b80000            mov      ax, 0
  0000:28FC  e98001            jmp      0x2a7f

sub_0000_28FF:                                ; dmdbrd_thunk_01 (AX=1) - 38 calls
  0000:28FF  b80100            mov      ax, 1
  0000:2902  e97a01            jmp      0x2a7f

sub_0000_2905:                                ; dmdbrd_thunk_02 (AX=2)
  0000:2905  b80200            mov      ax, 2
  0000:2908  e97401            jmp      0x2a7f

sub_0000_290B:                                ; dmdbrd_thunk_03 (AX=3) - 12 calls
  0000:290B  b80300            mov      ax, 3
  0000:290E  e96e01            jmp      0x2a7f

sub_0000_2911:                                ; dmdbrd_thunk_04 (AX=4)
  0000:2911  b80400            mov      ax, 4
  0000:2914  e96801            jmp      0x2a7f

sub_0000_2917:                                ; dmdbrd_thunk_05 (AX=5)
  0000:2917  b80500            mov      ax, 5
  0000:291A  e96201            jmp      0x2a7f
  ; thunk_06 (AX=6) at 0x291D (unreferenced)

sub_0000_2923:                                ; dmdbrd_thunk_07 (AX=7)
  0000:2923  b80700            mov      ax, 7
  0000:2926  e95601            jmp      0x2a7f

sub_0000_2929:                                ; dmdbrd_thunk_08 (AX=8) - 10 calls
  0000:2929  b80800            mov      ax, 8
  0000:292C  e95001            jmp      0x2a7f
  ; thunk_09 (AX=9) at 0x292F (unreferenced)

sub_0000_2935:                                ; dmdbrd_thunk_0A (AX=0xA)
  0000:2935  b80a00            mov      ax, 0xa
  0000:2938  e94401            jmp      0x2a7f
  ; thunks 0x0B, 0x0C at 0x293B (unreferenced)

sub_0000_2947:                                ; dmdbrd_thunk_0D (AX=0xD) - 4 calls
  0000:2947  b80d00            mov      ax, 0xd
  0000:294A  e93201            jmp      0x2a7f

sub_0000_294D:                                ; dmdbrd_thunk_0E (AX=0xE)
  0000:294D  b80e00            mov      ax, 0xe
  0000:2950  e92c01            jmp      0x2a7f

sub_0000_2953:                                ; dmdbrd_thunk_0F (AX=0xF)
  0000:2953  b80f00            mov      ax, 0xf
  0000:2956  e92601            jmp      0x2a7f

sub_0000_2959:                                ; dmdbrd_thunk_10 (AX=0x10)
  0000:2959  b81000            mov      ax, 0x10
  0000:295C  e92001            jmp      0x2a7f
  ; thunk_11 (AX=0x11) at 0x295F (unreferenced)

sub_0000_2965:                                ; dmdbrd_thunk_12 (AX=0x12) - 4 calls
  0000:2965  b81200            mov      ax, 0x12
  0000:2968  e91401            jmp      0x2a7f

sub_0000_296B:                                ; dmdbrd_thunk_13 (AX=0x13) - 2 calls
  0000:296B  b81300            mov      ax, 0x13
  0000:296E  e90e01            jmp      0x2a7f

sub_0000_2971:                                ; dmdbrd_thunk_14 (AX=0x14) - 17 calls
  0000:2971  b81400            mov      ax, 0x14
  0000:2974  e90801            jmp      0x2a7f

sub_0000_2977:                                ; dmdbrd_thunk_15 (AX=0x15) - 8 calls
  0000:2977  b81500            mov      ax, 0x15
  0000:297A  e90201            jmp      0x2a7f

sub_0000_297D:                                ; dmdbrd_thunk_16 (AX=0x16) - 3 calls
  0000:297D  b81600            mov      ax, 0x16
  0000:2980  e9fc00            jmp      0x2a7f
  ; thunks 0x17, 0x18, 0x19 at 0x2983 (unreferenced)

sub_0000_2995:                                ; dmdbrd_thunk_1A (AX=0x1A)
  0000:2995  b81a00            mov      ax, 0x1a
  0000:2998  e9e400            jmp      0x2a7f

sub_0000_299B:                                ; dmdbrd_thunk_1B (AX=0x1B)
  0000:299B  b81b00            mov      ax, 0x1b
  0000:299E  e9de00            jmp      0x2a7f
  ; thunk_1C (AX=0x1C) at 0x29A1 (unreferenced)

sub_0000_29A7:                                ; dmdbrd_thunk_1D (AX=0x1D)
  0000:29A7  b81d00            mov      ax, 0x1d
  0000:29AA  e9d200            jmp      0x2a7f
  ; thunks 0x1E, 0x1F, 0x20 at 0x29AD (unreferenced)

sub_0000_29BF:                                ; dmdbrd_thunk_21 (AX=0x21)
  0000:29BF  b82100            mov      ax, 0x21
  0000:29C2  e9ba00            jmp      0x2a7f

sub_0000_29C5:                                ; dmdbrd_thunk_22 (AX=0x22)
  0000:29C5  b82200            mov      ax, 0x22
  0000:29C8  e9b400            jmp      0x2a7f
  ; thunks 0x23-0x29 at 0x29CB (unreferenced)

sub_0000_29F5:                                ; dmdbrd_thunk_2A (AX=0x2A) - 4 calls
  0000:29F5  b82a00            mov      ax, 0x2a
  0000:29F8  e98400            jmp      0x2a7f
  ; thunks 0x2B, 0x2C at 0x29FB (unreferenced)

sub_0000_2A07:                                ; dmdbrd_thunk_2D (AX=0x2D)
  0000:2A07  b82d00            mov      ax, 0x2d
  0000:2A0A  eb73              jmp      0x2a7f

sub_0000_2A0D:                                ; dmdbrd_thunk_2E (AX=0x2E) - 5 calls
  0000:2A0D  b82e00            mov      ax, 0x2e
  0000:2A10  eb6d              jmp      0x2a7f

sub_0000_2A13:                                ; dmdbrd_thunk_2F (AX=0x2F)
  0000:2A13  b82f00            mov      ax, 0x2f
  0000:2A16  eb67              jmp      0x2a7f

sub_0000_2A19:                                ; dmdbrd_thunk_30 (AX=0x30) - 5 calls
  0000:2A19  b83000            mov      ax, 0x30
  0000:2A1C  eb61              jmp      0x2a7f

sub_0000_2A1F:                                ; dmdbrd_thunk_31 (AX=0x31) - 19 calls
  0000:2A1F  b83100            mov      ax, 0x31
  0000:2A22  eb5b              jmp      0x2a7f

sub_0000_2A25:                                ; dmdbrd_thunk_32 (AX=0x32) - 2 calls
  0000:2A25  b83200            mov      ax, 0x32
  0000:2A28  eb55              jmp      0x2a7f

sub_0000_2A2B:                                ; dmdbrd_thunk_33 (AX=0x33) - 6 calls
  0000:2A2B  b83300            mov      ax, 0x33
  0000:2A2E  eb4f              jmp      0x2a7f

sub_0000_2A31:                                ; dmdbrd_thunk_34 (AX=0x34) - 3 calls
  0000:2A31  b83400            mov      ax, 0x34
  0000:2A34  eb49              jmp      0x2a7f

sub_0000_2A37:                                ; dmdbrd_thunk_35 (AX=0x35) - 12 calls
  0000:2A37  b83500            mov      ax, 0x35
  0000:2A3A  eb43              jmp      0x2a7f

sub_0000_2A3D:                                ; dmdbrd_thunk_36 (AX=0x36) - 4 calls
  0000:2A3D  b83600            mov      ax, 0x36
  0000:2A40  eb3d              jmp      0x2a7f
  ; thunk_37 at 0x2A42 (unreferenced)

sub_0000_2A49:                                ; dmdbrd_thunk_38 (AX=0x38)
  0000:2A49  b83800            mov      ax, 0x38
  0000:2A4C  eb31              jmp      0x2a7f
  ; thunks 0x39-0x3C at 0x2A4E (unreferenced)

sub_0000_2A67:                                ; dmdbrd_thunk_3D (AX=0x3D) - 3 calls
  0000:2A67  b83d00            mov      ax, 0x3d
  0000:2A6A  eb13              jmp      0x2a7f

sub_0000_2A6D:                                ; dmdbrd_thunk_3E (AX=0x3E)
  0000:2A6D  b83e00            mov      ax, 0x3e
  0000:2A70  eb0d              jmp      0x2a7f
  ; thunk_3F at 0x2A72 (unreferenced)

sub_0000_2A79:                                ; dmdbrd_thunk_40 (AX=0x40) - 2 calls
  0000:2A79  b84000            mov      ax, 0x40
  0000:2A7C  eb01              jmp      0x2a7f

; --- Thunk Table 1 Dispatch Point ---
loc_0000_2A7F:
  0000:2A7F  bb2001            mov      bx, 0x120           ; return address storage (offset)
  0000:2A82  8f07              pop      word ptr [bx]        ; save caller's return offset
  0000:2A84  bb2201            mov      bx, 0x122           ; return address storage (segment)
  0000:2A87  8c0f              mov      word ptr [bx], cs    ; save caller's CS
  0000:2A89  bb1c01            mov      bx, 0x11c           ; DMDBRD far-call vector
  0000:2A8C  ff2f              jmp      far [bx]             ; far-jump into DMDBRD

; ========================================================================
; THUNK TABLE 2: Secondary Module Interface (0000:2A8E - 0000:2B61)
; ========================================================================
; 33 thunk functions, each setting AX to a function number (0x00..0x20)
; and jumping to the common dispatch point at loc_0000_2B54.
;
; Dispatch mechanism at 0x2B54:
;   1. Pop return address into [0x124] (offset) and [0x126] (CS)
;   2. Far-jump through [0x12C] into secondary module
; ========================================================================

sub_0000_2A8E:                                ; mod2_thunk_00 (AX=0) - 3 calls
  0000:2A8E  b80000            mov      ax, 0
  0000:2A91  e9c000            jmp      0x2b54

sub_0000_2A94:                                ; mod2_thunk_01 (AX=1) - 2 calls
  0000:2A94  b80100            mov      ax, 1
  0000:2A97  e9ba00            jmp      0x2b54

sub_0000_2A9A:                                ; mod2_thunk_02 (AX=2)
  0000:2A9A  b80200            mov      ax, 2
  0000:2A9D  e9b400            jmp      0x2b54

sub_0000_2AA0:                                ; mod2_thunk_03 (AX=3)
  0000:2AA0  b80300            mov      ax, 3
  0000:2AA3  e9ae00            jmp      0x2b54

sub_0000_2AA6:                                ; mod2_thunk_04 (AX=4)
  0000:2AA6  b80400            mov      ax, 4
  0000:2AA9  e9a800            jmp      0x2b54

sub_0000_2AAC:                                ; mod2_thunk_05 (AX=5)
  0000:2AAC  b80500            mov      ax, 5
  0000:2AAF  e9a200            jmp      0x2b54

sub_0000_2AB2:                                ; mod2_thunk_06 (AX=6) - 2 calls
  0000:2AB2  b80600            mov      ax, 6
  0000:2AB5  e99c00            jmp      0x2b54

sub_0000_2AB8:                                ; mod2_thunk_07 (AX=7) - 4 calls
  0000:2AB8  b80700            mov      ax, 7
  0000:2ABB  e99600            jmp      0x2b54

sub_0000_2ABE:                                ; mod2_thunk_08 (AX=8) - 6 calls
  0000:2ABE  b80800            mov      ax, 8
  0000:2AC1  e99000            jmp      0x2b54

sub_0000_2AC4:                                ; mod2_thunk_09 (AX=9) - 7 calls
  0000:2AC4  b80900            mov      ax, 9
  0000:2AC7  e98a00            jmp      0x2b54

sub_0000_2ACA:                                ; mod2_thunk_0A (AX=0xA) - 2 calls
  0000:2ACA  b80a00            mov      ax, 0xa
  0000:2ACD  e98400            jmp      0x2b54

sub_0000_2AD0:                                ; mod2_thunk_0B (AX=0xB) - 2 calls
  0000:2AD0  b80b00            mov      ax, 0xb
  0000:2AD3  eb7f              jmp      0x2b54

sub_0000_2AD6:                                ; mod2_thunk_0C (AX=0xC)
  0000:2AD6  b80c00            mov      ax, 0xc
  0000:2AD9  eb79              jmp      0x2b54

sub_0000_2ADC:                                ; mod2_thunk_0D (AX=0xD) - post-dispatch cleanup
  0000:2ADC  b80d00            mov      ax, 0xd
  0000:2ADF  eb73              jmp      0x2b54

sub_0000_2AE2:                                ; mod2_thunk_0E (AX=0xE) - 8 calls (alloc temp buf)
  0000:2AE2  b80e00            mov      ax, 0xe
  0000:2AE5  eb6d              jmp      0x2b54
  ; thunk_0F at 0x2AE7 (unreferenced)

sub_0000_2AEE:                                ; mod2_thunk_10 (AX=0x10) - 3 calls (free temp)
  0000:2AEE  b81000            mov      ax, 0x10
  0000:2AF1  eb61              jmp      0x2b54

sub_0000_2AF4:                                ; mod2_thunk_11 (AX=0x11) - 3 calls (flush)
  0000:2AF4  b81100            mov      ax, 0x11
  0000:2AF7  eb5b              jmp      0x2b54

sub_0000_2AFA:                                ; mod2_thunk_12 (AX=0x12) - 3 calls
  0000:2AFA  b81200            mov      ax, 0x12
  0000:2AFD  eb55              jmp      0x2b54
  ; thunk_13 at 0x2AFF (unreferenced)

sub_0000_2B06:                                ; mod2_thunk_14 (AX=0x14) - 3 calls
  0000:2B06  b81400            mov      ax, 0x14
  0000:2B09  eb49              jmp      0x2b54

sub_0000_2B0C:                                ; mod2_thunk_15 (AX=0x15)
  0000:2B0C  b81500            mov      ax, 0x15
  0000:2B0F  eb43              jmp      0x2b54

sub_0000_2B12:                                ; mod2_thunk_16 (AX=0x16) - 6 calls
  0000:2B12  b81600            mov      ax, 0x16
  0000:2B15  eb3d              jmp      0x2b54

sub_0000_2B18:                                ; mod2_thunk_17 (AX=0x17)
  0000:2B18  b81700            mov      ax, 0x17
  0000:2B1B  eb37              jmp      0x2b54

sub_0000_2B1E:                                ; mod2_thunk_18 (AX=0x18) - 13 calls
  0000:2B1E  b81800            mov      ax, 0x18
  0000:2B21  eb31              jmp      0x2b54

sub_0000_2B24:                                ; mod2_thunk_19 (AX=0x19)
  0000:2B24  b81900            mov      ax, 0x19
  0000:2B27  eb2b              jmp      0x2b54
  ; thunk_1A at 0x2B29 (unreferenced)

sub_0000_2B30:                                ; mod2_thunk_1B (AX=0x1B) - 26 calls
  0000:2B30  b81b00            mov      ax, 0x1b
  0000:2B33  eb1f              jmp      0x2b54
  ; thunks 0x1C-0x1F at 0x2B35 (unreferenced)

sub_0000_2B4E:                                ; mod2_thunk_20 (AX=0x20)
  0000:2B4E  b82000            mov      ax, 0x20
  0000:2B51  eb01              jmp      0x2b54

; --- Thunk Table 2 Dispatch Point ---
loc_0000_2B54:
  0000:2B54  bb2401            mov      bx, 0x124           ; return address storage (offset)
  0000:2B57  8f07              pop      word ptr [bx]        ; save caller's return offset
  0000:2B59  bb2601            mov      bx, 0x126           ; return address storage (segment)
  0000:2B5C  8c0f              mov      word ptr [bx], cs    ; save caller's CS
  0000:2B5E  bb2c01            mov      bx, 0x12c           ; secondary module far-call vector
  0000:2B61  ff2f              jmp      far [bx]             ; far-jump into secondary module

; ========================================================================
; dmdbbld_atol -- ASCII to long integer (0000:2B64)
; ========================================================================
; Standard atol() implementation from MSC 5.x runtime library.
; Converts ASCII decimal string to 32-bit signed integer in DX:AX.
;
; Input: [bp+4] = pointer to ASCII string
; Returns: DX:AX = 32-bit signed value
;
; Algorithm:
;   1. Skip whitespace (spaces, tabs)
;   2. Check for sign (+/-)
;   3. Parse digits: value = value * 10 + digit
;      (uses shift-and-add: x*10 = x*2 + x*8 = (x<<1) + (x<<3))
;   4. Negate if minus sign
;
; Note: This function crosses the seg_0000/seg_02BB boundary at 0x2BAF.
; The tail (negation and epilogue) is in seg_02BB.
; ========================================================================

sub_0000_2B64:
  0000:2B64  e90100            jmp      0x2b68

loc_0000_2B68:
  0000:2B68  55                push     bp
  0000:2B69  8bec              mov      bp, sp
  0000:2B6B  57                push     di
  0000:2B6C  56                push     si
  0000:2B6D  8b7604            mov      si, word ptr [bp + 4]   ; string pointer
  0000:2B70  33c0              xor      ax, ax                   ; clear result
  0000:2B72  99                cwd                               ; DX:AX = 0
  0000:2B73  33db              xor      bx, bx

loc_0000_2B75:
  ; Skip whitespace
  0000:2B75  ac                lodsb                             ; al = *si++
  0000:2B76  3c20              cmp      al, 0x20                ; space?
  0000:2B78  74fb              je       0x2b75
  0000:2B7A  3c09              cmp      al, 9                   ; tab?
  0000:2B7C  74f7              je       0x2b75
  ; Save sign character
  0000:2B7E  50                push     ax
  0000:2B7F  3c2d              cmp      al, 0x2d                ; '-'?
  0000:2B81  7404              je       0x2b87
  0000:2B83  3c2b              cmp      al, 0x2b                ; '+'?
  0000:2B85  7501              jne      0x2b88                   ; no sign -> parse digits

loc_0000_2B87:
  0000:2B87  ac                lodsb                             ; skip sign char

loc_0000_2B88:
  ; Parse digit loop
  0000:2B88  3c39              cmp      al, 0x39                ; > '9'?
  0000:2B8A  771f              ja       0x2bab                   ; not a digit -> done
  0000:2B8C  2c30              sub      al, 0x30                ; convert to value
  0000:2B8E  721b              jb       0x2bab                   ; < '0' -> done
  ; Multiply BX:DX by 10 using shifts
  0000:2B90  d1e3              shl      bx, 1                    ; bx *= 2
  0000:2B92  d1d2              rcl      dx, 1
  0000:2B94  8bcb              mov      cx, bx                   ; save bx*2
  0000:2B96  8bfa              mov      di, dx
  0000:2B98  d1e3              shl      bx, 1                    ; bx *= 4
  0000:2B9A  d1d2              rcl      dx, 1
  0000:2B9C  d1e3              shl      bx, 1                    ; bx *= 8
  0000:2B9E  d1d2              rcl      dx, 1
  0000:2BA0  03d9              add      bx, cx                   ; bx = bx*8 + bx*2 = bx*10
  0000:2BA2  13d7              adc      dx, di
  0000:2BA4  03d8              add      bx, ax                   ; add digit
  0000:2BA6  83d200            adc      dx, 0
  0000:2BA9  ebdc              jmp      0x2b87                   ; next char

loc_0000_2BAB:
  ; Check sign and finalize
  0000:2BAB  58                pop      ax                       ; recover sign char
  0000:2BAC  3c2d              cmp      al, 0x2d                ; was '-'?
  0000:2BAE  93                xchg     bx, ax                   ; AX = result low
  0000:2BAF  7507              jne      0x2bb8                   ; -> (seg_02BB:0008) return positive

; --- Crosses into seg_02BB ---
; seg_02BB:0000-0007 contains the negation code
;   02BB:0001  f7d8    neg ax
;   02BB:0003  83d200  adc dx, 0
;   02BB:0006  f7da    neg dx
; seg_02BB:0008 is the return point (pop si, pop di, pop bp, ret)

; ========================================================================
; SEGMENT seg_02BB  (112 bytes, file 0x2DB0-0x2E20)
; ========================================================================
; Contains:
;   - Tail of atol() (negation for negative numbers)
;   - RES entry point (registration + TSR)
;   - "DESKMATE$" device signature check (inline)
;   - PSP size helper function
; ========================================================================

; entry_point -- RES Module Startup (02BB:000C)
; ========================================================================
; Standard DM89 RES entry sequence:
;   1. Set DS to data segment (seg_02C2)
;   2. Save ES (PSP segment) to data area
;   3. Query memory via INT E0h AH=06h
;   4. If bit 15 set: use AX=0x1F0, else AX=0x1FF
;   5. Register module via INT E0h AH=01h with CX=seg_0000
;   6. Call getPspSize to calculate TSR paragraph count
;   7. Go TSR via INT 21h AH=31h
; ========================================================================

; entry_point:
;   02BB:000C  b8c202     mov ax, seg_02C2    ; [RELOC]
;   02BB:000F  8ed8       mov ds, ax
;   02BB:0011  06         push es
;   02BB:0012  58         pop ax               ; ax = PSP segment
;   02BB:0013  bb0200     mov bx, 2
;   02BB:0016  894720     mov [bx+0x20], ax    ; save PSP to data[0x22]
;   02BB:0019  b80006     mov ax, 0x600        ; INT E0h AH=06h: memory query
;   02BB:001C  cde0       int 0xe0
;   02BB:001E  250080     and ax, 0x8000       ; test bit 15
;   02BB:0021  7405       je  loc_02BB_0028
;   02BB:0023  b8f001     mov ax, 0x1f0        ; large memory mode
;   02BB:0026  eb03       jmp loc_02BB_002B
; loc_02BB_0028:
;   02BB:0028  b8ff01     mov ax, 0x1ff        ; small memory mode
; loc_02BB_002B:
;   02BB:002B  b90000     mov cx, seg_0000     ; [RELOC] code segment
;   02BB:002E  1e         push ds
;   02BB:002F  07         pop es               ; ES = data segment
;   02BB:0030  cde0       int 0xe0             ; INT E0h AH=01h: register module
;   02BB:0032  eb00       jmp loc_02BB_0034
; loc_02BB_0034:
;   02BB:0034  e82c00     call sub_02BB_0063   ; getPspSize
;   02BB:0037  32c0       xor al, al           ; exit code = 0
;   02BB:0039  b431       mov ah, 0x31
;   02BB:003B  cd21       int 0x21             ; TSR (keep process)
;   02BB:003D  cb         retf                 ; (never reached)

; "DESKMATE$" device signature check (inline at 02BB:003E):
;   Checks INT E0h vector for "DESKMATE$" device driver signature.
;   Uses INT 21h/35h to get vector, then compares 9 bytes at offset +3
;   against "DESKMATE$" string at seg_02C2:0028.

; dmdbbld_getPspSize -- Get paragraph count for TSR (02BB:0063)
;   02BB:0063  b451       mov ah, 0x51         ; Get PSP
;   02BB:0065  cd21       int 0x21
;   02BB:0067  4b         dec bx               ; MCB = PSP - 1
;   02BB:0068  8ec3       mov es, bx
;   02BB:006A  268b1603   mov dx, es:[3]       ; MCB paragraph count
;   02BB:006F  8bc2       mov ax, dx
;   02BB:0071  ...        (continues into seg_02C2)

; ========================================================================
; SEGMENT seg_02C2  (50 bytes, file 0x2E20-0x2E52)
; ========================================================================
; Data segment containing:
;   +0x02  "DMDBBLD\0"            Module name string
;   +0x0A  Relay data (14 bytes)  Module dispatch pointers [RELOC->seg_0000]
;                                  [RELOC->seg_02BB at +0x10]
;   +0x28  "DESKMATE$\0"          Device signature for detection
; ========================================================================

; seg_02C2:
;   02C2:0002  "DMDBBLD"           ; module name
;   02C2:000A  00 00 00 00         ; padding
;   02C2:000C  3D 00               ; [RELOC->seg_0000] dispatch entry
;   02C2:000E  BB 02               ; [RELOC->seg_02BB]
;   02C2:0028  "DESKMATE$"         ; device driver signature

; ========================================================================
; SEGMENT seg_02C6  (2 bytes, file 0x2E60)
; ========================================================================
; BSS/Stack segment. SS:SP = 02C6:0002 at entry.
; ========================================================================
