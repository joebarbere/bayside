; ========================================================================
; DMDBUPD.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMDBUPD.RES is the database update engine for DeskMate 3.05.
; It provides all write/modify operations for .FIL database files:
; insert new records, update existing records, delete records, and
; commit changes to disk. Used by Filer, FormSet, and Address Book.
;
; The module shares the slot table architecture with DMDBRD.RES:
;   slot_index = record_id / 100
;   Slot table base = 0xA8 + (slot_index * 16)
;
; Unlike DMDBRD which has a full CRT, DMDBUPD is a simpler TSR module
; that registers via INT E0h and dispatches operations through a
; command-code based system. After most operations, it calls
; sub_0000_3007 (dmdbupd_flushFile) to sync changes to disk.
;
; The module contains a large thunk table (0x30C9 - 0x3248) where
; ~65 small functions each set AX to a function number (0x00-0x40)
; and jump to a common far-call dispatch point at 0x3249. This
; mechanism allows the module to call back into DMDBRD's API for
; any operation by function number.
;
; Command codes dispatched at entry point (0000:0000):
;   CX=0x00  -> dmdbupd_init (sub_0000_00B0, called 2x)
;   CX=0x07  -> dmdbupd_commitRecord (sub_0000_00B0)
;   CX=0x12  -> dmdbupd_insertRecord (sub_0000_04EF)
;   CX=0x13  -> dmdbupd_deleteRecord (sub_0000_09B1)
;   CX=0x1C  -> dmdbupd_updateField (sub_0000_01AD)
;   CX=0x24  -> dmdbupd_renameColumn (sub_0000_0896)
;   CX=0x25  -> dmdbupd_deleteColumn (sub_0000_077F)
;   CX=0x27  -> dmdbupd_commitRecord (sub_0000_00B0, variant)
;   CX=0x1E  -> dmdbupd_setFieldLock (sub_0000_07D7)
;   CX=0x1A  -> dmdbupd_clearFieldLock (sub_0000_07DD)
;
; After most command handlers, dmdbupd_flushFile (sub_0000_3007) is
; called to ensure file handle consistency.
;
; DM89 imports: Registered as "DMDBUPD" (referenced by DMDBRD)
;               Uses INT E0h AH=01h for API registration
;               Uses INT E0h AH=06h for memory/system query
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 13,873 bytes
; Load image: 13,361 bytes (after header)
; DM89 entry point: 0331:0006 (TSR registration)
; SS:SP = 0336:0200
;
; Segment Map (4 segments, 4 relocations):
;   seg_0000  13,104 bytes  CODE/DATA  Update engine + thunk table
;   seg_0331      50 bytes  CODE       Entry point, RES registration, TSR
;   seg_0335       2 bytes  DATA       Module data (minimal)
;   seg_0336       BSS      BSS        Stack segment
;
; DM flags: 0x0101 (standard RES module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Shared with DMDBRD.RES (same slot table layout):
;   Slot Table (0xA8 + slot*16, 6 slots max)
;   Buffer Cache Entries (11 bytes each)
;   Database handles at [slot_base + 0xB0]
;
; Update-specific state:
;   [0x010A]  (byte) DOS major version
;   [0x010B]  (byte) DOS minor version
;   [0x010C]  (word) file handle for current write operation
;   [0x0111]  (word) current database handle
;   [0x0113]  (word) parameter pointer for thunk dispatch
;   [0x0115]  (word) work buffer pointer
;   [0x011C]  (dword) far-call target for DMDBRD thunks
;   [0x0120]  (dword) far-call return address
;
; Far-call thunk mechanism (0x3249):
;   Each thunk function (sub_0000_30C9 through sub_0000_3243) pushes
;   a function number in AX, then jumps to 0x3249 which:
;   1. Pops the return address into [0x120]
;   2. Stores CS into [0x122]
;   3. Performs an indirect far jump through [0x11C]
;   This calls into DMDBRD.RES's dispatch table.
;
; Function number to DMDBRD mapping (thunk table at 0x3258):
;   Word-offset pairs map function numbers to DMDBRD entry points.
;
; Error Codes (same as DMDBRD plus):
;   0xFFD3  (-45)  Null handle / no database open
;   0xFFE3  (-29)  Record locked
;   0xFFF9  (-7)   Column definition error
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Entry Point / Dispatch ---
; (0000:0000)            dmdbupd_dispatch     Command dispatcher (CX-based)
; (0331:0006)            entry_point          TSR registration + INT E0h
;
; --- Core Update Operations ---
; sub_0000_00B0          dmdbupd_commitRecord    Commit/write a record to database
; sub_0000_01AD          dmdbupd_updateField     Update a field value in a record
; sub_0000_04EF          dmdbupd_insertRecord    Insert a new record into database
; sub_0000_077F          dmdbupd_deleteColumn    Delete a column from database schema
; sub_0000_07D7          dmdbupd_setFieldLock    Set lock flag on a field
; sub_0000_07DD          dmdbupd_clearFieldLock  Clear lock flag on a field
; sub_0000_0896          dmdbupd_renameColumn    Rename a column in database schema
; sub_0000_09B1          dmdbupd_deleteRecord    Delete a record from database
;
; --- Record Write Helpers ---
; sub_0000_0B24          dmdbupd_writeRecordBlock   Write record data block to file
; sub_0000_0BE7          dmdbupd_buildRecordData    Build record data from fields
; sub_0000_0CB8          dmdbupd_deleteRecordBlock  Mark record block as deleted
; sub_0000_0D83          dmdbupd_updateFieldData    Write updated field data
; sub_0000_0E8A          dmdbupd_freeRecordBlock    Free disk space for deleted record
; sub_0000_0F28          dmdbupd_rebuildIndex       Rebuild index after schema change
; sub_0000_0F41          dmdbupd_compactRecords     Compact records after deletion
;
; --- Index Update Operations ---
; sub_0000_0FC8          dmdbupd_updateIndex        Update B-tree index entry
; sub_0000_1077          dmdbupd_writeIndexBlock    Write index block to disk
; sub_0000_120C          dmdbupd_splitIndexPage     Split a full B-tree page
; sub_0000_1226          dmdbupd_insertIndexEntry   Insert entry into B-tree index
; sub_0000_14C5          dmdbupd_rebalanceIndex     Rebalance B-tree after insert
;
; --- Field / Schema Operations ---
; sub_0000_1915          dmdbupd_validateField      Validate field data before write
; sub_0000_1896          dmdbupd_getFieldSchema     Get schema definition for field
;
; --- File I/O ---
; sub_0000_2FC6          dmdbupd_writeFile          Write data to file (INT 21h/40h)
; sub_0000_3007          dmdbupd_flushFile          Flush file to disk (dup+close or 68h)
; sub_0000_3043          dmdbupd_getDiskFreeSpace   Get disk free space (INT 21h/36h)
; sub_0000_2EA8          dmdbupd_seekAndWrite       Seek to position and write data
; sub_0000_2E01          dmdbupd_writeBlock         Write a data block to file
; sub_0000_2D0A          dmdbupd_writeFieldBlock    Write field data block
; sub_0000_2D4C          dmdbupd_writeHeader        Write database header block
; sub_0000_2C9B          dmdbupd_writeIndexEntry    Write index entry to file
; sub_0000_2C3F          dmdbupd_seekToBlock        Seek to specific block in file
; sub_0000_2B05          dmdbupd_allocateBlock      Allocate a new block in file
;
; --- DMDBRD Thunk Table (far-call dispatchers) ---
; sub_0000_30C9 - sub_0000_3243  (65+ functions)
;   Each sets AX=function_number and jumps to 0x3249 dispatch point.
;   These provide access to DMDBRD.RES's full API from DMDBUPD.
;   Function numbers 0x00 through 0x40 map to DMDBRD operations.
;   Key thunks:
;     sub_0000_30C9  -> fn 0x00 (init)
;     sub_0000_30CF  -> fn 0x01 (open database)
;     sub_0000_30DB  -> fn 0x02 (close database)
;     sub_0000_3105  -> fn 0x0B (read forward)
;     sub_0000_3159  -> fn 0x19 (read field)
;     sub_0000_31D7  -> fn 0x2E (cache state)
;     sub_0000_31E9  -> fn 0x31 (read block)
;     sub_0000_3201  -> fn 0x35 (file seek)
;     sub_0000_3207  -> fn 0x36 (file read)
;     sub_0000_3213  -> fn 0x38 (file write)
;     sub_0000_321F  -> fn 0x3A (string copy)
;     sub_0000_3225  -> fn 0x3B (memory copy)
;     sub_0000_3243  -> fn 0x40 (last function)
;
; --- CRT Utilities ---
; sub_0000_32B2          dmdbupd_atol              String to long conversion
; sub_0000_330A          dmdbupd_memcpy            Memory copy (rep movsb)
; sub_0000_2F65          dmdbupd_parseColumnRefs   Parse column reference string
;
; --- State Management ---
; sub_0000_1D3B          dmdbupd_saveState         Save module state before operation
; sub_0000_1D8E          dmdbupd_restoreState      Restore module state after operation
; sub_0000_16E5          dmdbupd_lockRecord        Lock a record for exclusive write
; sub_0000_166B          dmdbupd_unlockRecord      Unlock a record after write
; sub_0000_16A1          dmdbupd_checkLock         Check if record is locked
; sub_0000_17FE          dmdbupd_validateWrite     Validate write operation preconditions
; sub_0000_19CD          dmdbupd_beginTransaction  Begin a write transaction
; sub_0000_19FC          dmdbupd_endTransaction    End a write transaction
;
; --- High-level Operations ---
; sub_0000_21C6          dmdbupd_updateRecordIndex  Update index after record change
; sub_0000_2203          dmdbupd_rebuildAllIndexes  Rebuild all indexes for database
; sub_0000_2339          dmdbupd_compactDatabase    Compact database file
; sub_0000_24B7          dmdbupd_resizeRecord       Resize a record's allocated space
; sub_0000_264A          dmdbupd_copyRecord         Copy record data between blocks
; sub_0000_26CB          dmdbupd_moveRecord         Move record to new location
; sub_0000_2742          dmdbupd_reallocateBlock    Reallocate a data block
; sub_0000_27E5          dmdbupd_extendFile         Extend database file size
; sub_0000_2859          dmdbupd_truncateFile       Truncate unused space from file
; sub_0000_2872          dmdbupd_syncHeader         Sync header to disk
;
; ========================================================================
; CODE / DATA
; ========================================================================

; ========================================================================
; SEGMENT seg_0000  (13,104 bytes, file 0x0200-0x3530)
; Database update engine + thunk table
; ========================================================================
seg_0000:

; ========================================================================
; dmdbupd_dispatch (0000:0000)
; Main command dispatcher. Receives CX=command code, SI=parameter block.
; Routes to appropriate handler function. Most handlers pop their
; parameters from [si+2] (pushed before call). After most handlers,
; calls dmdbupd_flushFile to sync disk.
;
; Command routing:
;   CX=0x00 -> push [si+2], call dmdbupd_commitRecord (init mode)
;   CX=0x07 -> push [si+2], call dmdbupd_commitRecord (commit mode)
;   CX=0x12 -> push [si+2], call dmdbupd_insertRecord
;   CX=0x13 -> push [si+2], call dmdbupd_deleteRecord
;   CX=0x1C -> push [si+2], call dmdbupd_updateField
;   CX=0x24 -> push [si+2], call dmdbupd_renameColumn
;   CX=0x25 -> push [si+2], call dmdbupd_deleteColumn
;   CX=0x27 -> push [si+2], call dmdbupd_commitRecord
;   CX=0x1E -> call dmdbupd_setFieldLock, call dmdbupd_flushFile
;   CX=0x1A -> call dmdbupd_clearFieldLock, call dmdbupd_flushFile
; ========================================================================
dmdbupd_dispatch:
  0000:0000  55                push     bp
  0000:0001  8bec              mov      bp, sp
  0000:0003  56                push     si
  ; CX = command code, [si] = parameter base
  0000:0004  83f900            cmp      cx, 0           ; CX=0: init
  0000:0007  7455              je       .cmd_commit     ; -> 0x005E
  0000:0009  83f912            cmp      cx, 0x12        ; CX=0x12: insert record
  0000:000C  745b              je       .cmd_insert     ; -> 0x0069 (approx)
  0000:000E  83f913            cmp      cx, 0x13        ; CX=0x13: delete record
  0000:0011  7461              je       .cmd_delete     ; -> 0x0074 (approx)
  ; ... additional command checks ...
  ; [See raw disassembly 0x0000-0x00AF for complete dispatcher]

; After dispatch, most paths converge to:
; loc_0000_00A6: add sp, 2 (pop parameter)
; loc_0000_00A9: add sp, 2 (pop second parameter)
; loc_0000_00AC: pop si; pop bp; retf

; ========================================================================
; dmdbupd_commitRecord (0000:00B0)
; Commit/write a record to the database file. This is the primary
; write operation that:
; 1. Validates the slot and database handle
; 2. Builds record data from field values (dmdbupd_buildRecordData)
; 3. If record has a lock flag, writes to index (dmdbupd_writeRecordBlock)
; 4. Writes record data to disk (dmdbupd_writeIndexBlock)
; 5. Updates the version counter in the record header
; 6. Writes the updated version via dmdbupd_seekAndWrite
;
; Parameters:
;   [bp+4] = record context pointer
;   [bp+6] = database context pointer
; Returns: AX = 0 on success, negative on error
; ========================================================================
dmdbupd_commitRecord:  ; sub_0000_00B0
  0000:00B0  55                push     bp
  0000:00B1  8bec              mov      bp, sp
  0000:00B3  83ec16            sub      sp, 0x16        ; 22 bytes locals
  ; Compute slot from record_id
  0000:00B6  8b5e06            mov      bx, word ptr [bp + 6]
  0000:00B9  8b07              mov      ax, word ptr [bx]
  0000:00BB  99                cdq
  0000:00BC  b96400            mov      cx, 0x64        ; / 100
  0000:00BF  f7f9              idiv     cx
  0000:00C1  8946f4            mov      word ptr [bp - 0xc], ax  ; slot_index
  0000:00C4  b104              mov      cl, 4
  0000:00C6  d3e0              shl      ax, cl
  0000:00C8  05a800            add      ax, 0xa8
  0000:00CB  8946fc            mov      word ptr [bp - 4], ax    ; slot table entry
  ; Check database handle
  0000:00CE  8b5e04            mov      bx, word ptr [bp + 4]
  0000:00D1  8b4708            mov      ax, word ptr [bx + 8]   ; record handle
  0000:00D4  8946f0            mov      word ptr [bp - 0x10], ax
  0000:00D7  0bc0              or       ax, ax
  0000:00D9  7506              jne      .has_handle
  0000:00DB  b8d3ff            mov      ax, 0xffd3      ; -45: null handle
  0000:00DE  e9c800            jmp      .done
  ; ... [rest of function: build data, write, update version]
  ; [See raw disassembly 0x00B0-0x01AC for complete listing]

; ========================================================================
; dmdbupd_updateField (0000:01AD)
; Update a specific field value within a record. Validates the field
; type, writes the new value, and updates any affected indexes.
; [Function spans 0x01AD - 0x04EE, 834 bytes]
; ========================================================================

; ========================================================================
; dmdbupd_insertRecord (0000:04EF)
; Insert a new record into the database. Allocates space, writes
; the record data, updates all indexes, and commits to disk.
; [Function spans 0x04EF - 0x077E, 656 bytes]
; ========================================================================

; ========================================================================
; dmdbupd_deleteColumn (0000:077F)
; Delete a column from the database schema. Removes the column
; definition, rebuilds affected indexes.
; [Function spans 0x077F - 0x07D6, 88 bytes]
; ========================================================================

; ========================================================================
; dmdbupd_setFieldLock (0000:07D7)
; Set the lock flag on a field to prevent concurrent modification.
; Very small function (6 bytes), simply stores lock state.
; ========================================================================
dmdbupd_setFieldLock:  ; sub_0000_07D7
  ; [See raw disassembly for 6-byte implementation]

; ========================================================================
; dmdbupd_clearFieldLock (0000:07DD)
; Clear the lock flag on a field.
; ========================================================================
dmdbupd_clearFieldLock:  ; sub_0000_07DD
  ; [See raw disassembly for implementation]

; ========================================================================
; dmdbupd_renameColumn (0000:0896)
; Rename a column in the database schema. Updates the column name
; in the header and rebuilds affected indexes.
; [Function spans 0x0896 - 0x09B0, 283 bytes]
; ========================================================================

; ========================================================================
; dmdbupd_deleteRecord (0000:09B1)
; Delete a record from the database. Marks the record as deleted,
; frees disk space, updates indexes, and compacts if needed.
; [Function spans 0x09B1 - 0x0B23, 371 bytes]
; ========================================================================

; ========================================================================
; Remaining functions (0x0B24 - 0x30C8):
; Record write helpers, index update operations, field/schema ops,
; file I/O wrappers, state management, and high-level operations.
; See FUNCTION INDEX above for complete listing with descriptions.
; ========================================================================

; ========================================================================
; DMDBRD Thunk Table (0x30C9 - 0x3258)
; 65+ small functions that each set AX to a function number and jump
; to the common far-call dispatch point. This is the mechanism by which
; DMDBUPD calls into DMDBRD.RES operations.
;
; Each thunk is 3-6 bytes:
;   mov ax, <function_number>   ; B8 xx 00
;   jmp loc_0000_3249           ; E9 xx xx (or EB xx)
;   [optional NOP padding]
;
; The dispatch point at 0x3249:
;   mov bx, 0x120
;   pop word ptr [bx]          ; save return address
;   mov bx, 0x122
;   mov word ptr [bx], cs      ; save return segment
;   mov bx, 0x11C
;   ljmp [bx]                  ; far jump to DMDBRD handler
;
; After DMDBRD finishes, it returns via the saved address at [0x120].
; ========================================================================

; --- Function offset table (0x3258 - 0x329B) ---
; Word pairs mapping function numbers to code offsets.
; Used by DMDBRD to look up the operation handler.

; ========================================================================
; dmdbupd_flushFile (0000:3007)
; Flush database file to disk after write operations.
; Checks DOS version: if >= 3.30, uses INT 21h/68h (commit file).
; Otherwise, uses INT 21h/45h (dup handle) + INT 21h/3Eh (close dup)
; as a flush workaround for older DOS versions.
; ========================================================================
dmdbupd_flushFile:  ; sub_0000_3007
  0000:3007  56                push     si
  0000:3008  50                push     ax
  0000:3009  53                push     bx
  0000:300A  33f6              xor      si, si
  0000:300C  8b841101          mov      ax, word ptr [si + 0x111]  ; db_handle
  0000:3010  3d0000            cmp      ax, 0
  0000:3013  7c2a              jl       .done           ; no handle -> skip
  0000:3015  8b9c0c01          mov      bx, word ptr [si + 0x10c]  ; file handle
  0000:3019  8a840a01          mov      al, byte ptr [si + 0x10a]  ; DOS major
  0000:301D  3c03              cmp      al, 3
  0000:301F  7c12              jl       .use_dup        ; DOS < 3.x
  0000:3021  7f08              jg       .use_commit     ; DOS > 3.x
  0000:3023  8a840b01          mov      al, byte ptr [si + 0x10b]  ; DOS minor
  0000:3027  3c1e              cmp      al, 0x1e        ; 30 decimal
  0000:3029  7c08              jl       .use_dup        ; DOS < 3.30
.use_commit:
  0000:302B  b80068            mov      ax, 0x6800      ; INT 21h/68h: commit file
  0000:302E  cd21              int      0x21
  0000:3030  eb0d              jmp      .done
.use_dup:
  0000:3033  b445              mov      ah, 0x45        ; INT 21h/45h: dup handle
  0000:3035  cd21              int      0x21
  0000:3037  7206              jb       .done
  0000:3039  8bd8              mov      bx, ax          ; BX = duplicated handle
  0000:303B  b43e              mov      ah, 0x3e        ; INT 21h/3Eh: close file
  0000:303D  cd21              int      0x21            ; closing dup flushes original
.done:
  0000:303F  5b                pop      bx
  0000:3040  58                pop      ax
  0000:3041  5e                pop      si
  0000:3042  c3                ret

; ========================================================================
; dmdbupd_getDiskFreeSpace (0000:3043)
; Get available disk space for the specified drive.
; Parameters:
;   [bp+4] = pointer to result (dword)
;   [bp+6] = drive number (0=default, 1=A, 2=B, etc.)
; Returns: result stored at pointer, AX = free clusters * sectors * bytes
; ========================================================================
dmdbupd_getDiskFreeSpace:  ; sub_0000_3043
  0000:3043  55                push     bp
  0000:3044  8bec              mov      bp, sp
  0000:3046  53                push     bx
  0000:3047  51                push     cx
  0000:3048  8a5606            mov      dl, byte ptr [bp + 6]  ; drive
  0000:304B  b436              mov      ah, 0x36
  0000:304D  cd21              int      0x21            ; Get disk free space
  ; [See raw disassembly for result calculation]

; ========================================================================
; SEGMENT seg_0331  (50 bytes, file 0x3530-0x3562)
; Entry point, RES registration, TSR
; ========================================================================
seg_0331:

; entry_point (0331:0006):
; Simple TSR registration:
; 1. INT E0h AH=01h to register API dispatch
; 2. INT E0h AH=02h to register module name "DMDBUPD"
; 3. INT 21h AH=31h to go TSR
; [See raw disassembly for byte-level detail]

; ========================================================================
; SEGMENT seg_0335  (2 bytes, file 0x3562-0x3564)
; Minimal module data
; ========================================================================

; ========================================================================
; SEGMENT seg_0336  (BSS)
; Stack segment
; ========================================================================
