; ========================================================================
; DMEMM.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMEMM.RES is the Expanded Memory Manager driver for DeskMate 3.05.
; It provides an abstraction layer over EMS (Expanded Memory
; Specification, LIM EMS 3.2/4.0) and XMS, allowing DeskMate
; applications to use memory beyond the 640KB conventional limit.
;
; The driver detects available expanded memory via:
;   1. INT 2Fh/43xxh - XMS detection (INT 2Fh multiplex)
;   2. INT 67h - EMS driver detection (check for "EMMXXXX0" device name)
;   3. INT 67h/40h - Get EMS status
;   4. INT 67h/42h - Get unallocated page count
;
; If EMS is available with at least 4 free pages (64KB), the driver:
;   - Allocates EMS pages via INT 67h/43h
;   - Maps pages into the page frame via INT 67h/44h or 4Fh/4Eh
;   - Implements a page-swapping memory manager that provides
;     a virtual memory pool to DeskMate applications
;   - Manages allocation, deallocation, and page table bookkeeping
;
; The driver also falls back to conventional memory allocation
; (INT 21h/48h-49h) when EMS is not available, providing a
; unified memory API regardless of hardware configuration.
;
; Module name: "DMEMM$" (the $ suffix indicates a device-style driver)
; Device string: "EMMXXXX0DMEMM"
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 2,582 bytes
; Load image: 2,070 bytes (after header)
; DM89 entry point: 0000:0000
; SS:SP = 001A:0002
;
; Segment Map (4 segments, 6 relocations):
;   seg_0000  416 bytes   CODE   Entry point, EMS/XMS detection,
;                                initialization, conventional memory
;                                allocation fallback
;   seg_001A  1,376 bytes CODE   EMS page management: allocate, free,
;                                map, swap, read/write through pages,
;                                page table maintenance
;   seg_0070  160 bytes   CODE   Resident ISR code: handles EMS page
;                                restore on context switch, process
;                                cleanup
;   seg_007A  118 bytes   DATA   DM89 header "EMMXXXX0DMEMM",
;                                dispatch table, module info
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Initialization (seg_0000) ---
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmemm_init                    Entry: detect EMS/XMS, init memory pool
; 0000:00A2   dmemm_allocConventional       Allocate block via conventional memory
;                                           (INT 21h/48h-51h for PSP management)
;
; --- Page Management (seg_001A) ---
;
; 001A:0012   dmemm_setupPageFrame          Set up EMS page frame mapping
; 001A:0034   dmemm_apiEntry                API entry: "DMEMM$" dispatcher
; 001A:0045   dmemm_returnSuccess           Return success (clear carry flag)
; 001A:004F   dmemm_chainInterrupt          Chain to original interrupt handler
; 001A:005F   dmemm_cleanupProcess          Clean up pages owned by exiting process
; 001A:0083   dmemm_readPage                Read data from EMS page (map + copy)
; 001A:00AB   dmemm_writePage               Write data to EMS page (map + copy)
; 001A:0105   dmemm_checkAvailable          Check if page slot is available
; 001A:012C   dmemm_mapPhysicalPage         Map EMS physical page (INT 67h)
; 001A:0181   dmemm_allocPages              Allocate EMS pages for handle
; 001A:01E6   dmemm_freePages               Free EMS pages for handle
; 001A:0230   dmemm_findHandle              Find handle in page table
; 001A:024C   dmemm_insertHandle            Insert handle into page table
; 001A:0254   dmemm_allocBlock              Allocate memory block (EMS or conventional)
; 001A:039C   dmemm_getPageInfo             Get page information for handle
; 001A:03B5   dmemm_copyBlock               Copy memory block between pages
; 001A:03D0   dmemm_resizeBlock             Resize memory block
; 001A:0403   dmemm_readFromFile            Read data from file into page
; 001A:0459   dmemm_writeToFile             Write data from page to file
; 001A:0496   dmemm_queryStatus             Query memory manager status
; 001A:04F6   dmemm_detectVersion           Detect EMS version and set parameters
;
; --- Resident Handler (seg_0070) ---
;
; 0070:0010   dmemm_residentHandler         ISR: save/restore EMS pages on
;                                           context switch, clean up on exit
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; INT 2Fh/43xxh - XMS Detection and Control
;   AH=43h, AL=00h - Get XMS installed state (returns AL=80h if present)
;   AH=43h, AL=10h - Get XMS driver entry point
;
; INT 67h - EMS Driver Services
;   AH=40h - Get EMS manager status
;   AH=41h - Get EMS page frame address
;   AH=42h - Get unallocated page count
;   AH=43h - Allocate EMS pages
;   AH=44h - Map EMS page to physical page
;   AH=45h - Release EMS handle
;   AH=47h - Save page map for handle
;   AH=48h - Restore page map for handle
;   AH=4Eh - Save/restore page map (EMS 4.0)
;   AH=4Fh - Save/restore partial page map (EMS 4.0)
;   AH=50h - Map/unmap multiple pages (EMS 4.0)
;   AH=51h - Reallocate pages for handle (EMS 4.0)
;
; INT 21h/48h - Allocate conventional memory block
; INT 21h/49h - Free conventional memory block
; INT 21h/50h - Set PSP
; INT 21h/51h - Get PSP
;
; INT E0h/06h - DM89 system query (version detection)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Page Table (at seg_001A data area):
;   [0x00] first_handle    - Head of handle linked list (segment)
;   [0x02] xms_entry_off   - XMS driver entry offset
;   [0x04] xms_entry_seg   - XMS driver entry segment
;   [0x06] ems_pages_free  - Number of free EMS pages
;   [0x08] pool_size       - Total pool size (words)
;   [0x0A] page_base_seg   - EMS page frame base segment
;   [0x0C] max_handles     - Maximum handle count (up to 0xFE)
;   [0x0D] page_function   - EMS function code (4Eh or 4Fh)
;   [0x0E] version_flag    - EMS version flag
;   [0x100] psp_segment    - Current PSP segment for context tracking
;
; Handle Entry (per allocated block, 8 bytes):
;   +0x00  next_handle     - Next handle in list (segment, 0=end)
;   +0x01  owner_psp       - Owning PSP segment
;   +0x02  block_size      - Size in pages
;   +0x03  ems_handle      - EMS handle number
;   +0x04  page_count      - Mapped page count
;   +0x05  flags           - Handle flags
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Init + detection (416 bytes)
; seg_001A: Page management (1,376 bytes)
; seg_0070: Resident ISR (160 bytes)
; seg_007A: Module header (118 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmemm.asm for complete byte-level listing]
