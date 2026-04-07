; ========================================================================
; DMFORM.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMFORM.RES is the form rendering engine for DeskMate 3.05.
; It provides form layout creation and management with fields, labels,
; boxes, and controls used by Filer, FormSet, and Address Book.
;
; Unlike the other DB modules, DMFORM is a simple RES driver that
; registers itself via INT E0h and stays resident (TSR). It provides
; a jump table of entry points for form operations at seg_023A.
;
; The module supports multiple field types:
;   'O' = OO sentinel (empty/null slot marker, value 0x4F4F)
;   'T' = Text field (editable text with cursor support)
;   'L' = Label (static text)
;   'R' = Rectangle/Box (12-byte bounding box)
;   'B' = Button control (12-byte bounding box)
;   'E' = Entry field (12-byte bounding box)
;   'U' = Underline/separator
;
; Form structures use a table-based layout where each form element
; is stored in a fixed-size record with type byte, dimensions, and
; attributes. The element table is accessed via [bp+0x0E] (base pointer
; to element array) throughout the module.
;
; DM89 imports: Registered as "DMFORM" via INT E0h AH=02h
;               Uses INT E0h AH=01h for DeskMate host API version check
;               Uses INT E0h AH=06h for memory allocation
;
; Key host API calls (via far-call thunks):
;   AX=0x2120 - Draw/invalidate region
;   AX=0x2080 - Draw field content
;   AX=0x206D - Draw rectangle/box
;   AX=0x0401 - Get form element properties (4 words)
;   AX=0x0402 - Allocate form element
;   AX=0x0406 - Query form element
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 9,853 bytes
; Load image: 9,341 bytes (after header)
; DM89 entry point: 0240:005B (RES startup + TSR)
; SS:SP = 0248:0002
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  9120 bytes  CODE   Form engine functions (jump table targets)
;   seg_023A    96 bytes  DATA   Jump table + element type dispatch tables
;   seg_0240   125 bytes  CODE   Entry point, RES registration, far-call thunks
;   seg_0248     2 bytes  BSS    Stack segment
;
; DM flags: 0x0101 (standard RES module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Form Element Table (base at [bp+0x0E]):
;   Each element occupies a variable-size slot depending on type.
;   Element slots are addressed as word-indexed arrays.
;   The first word of each slot is the element count or sentinel.
;
; Element Record (type-dependent):
;   +0x00  type byte ('T','L','R','B','E','U','O')
;   +0x01  flags byte
;   +0x02  left coordinate (word)
;   +0x04  height/row (word)
;   +0x06  top coordinate (word)
;   +0x08  width/column (word)
;   +0x0A  right coordinate (word)
;   +0x0C  bottom coordinate (word)
;   +0x0E  (varies by type)
;   +0x12  sub-element count (word)
;   +0x14  first sub-element offset (word)
;
; Form Control Block (passed to form functions):
;   +0x00  element type byte
;   +0x01  active flag byte
;   +0x02  left bound (word)
;   +0x04  top/rows (word)
;   +0x06  horizontal spacing (word)
;   +0x08  vertical spacing (word)
;   +0x0A  min width (word)
;   +0x0C  padding (word)
;   +0x0E  right bound (word)
;   +0x10  bottom bound (word)
;   +0x12  pixel width (word)
;   +0x14  display height (word)
;   +0x16  attr flags (word)
;   +0x18  color mode (word)
;   +0x1A  attribute 2 (word)
;
; Bounding Box (used by 'R','B','E' types):
;   +0x00  min X (word)
;   +0x04  min Y (word)
;   +0x08  max X (word) -- initially 0x7FFF
;   +0x0C  max Y (word) -- initially 0x7FFF
;   +0x02/+0x06/+0x0A/+0x0E  current bounds after layout
;   +0x10  visible flag (word)
;   +0x12  element count (word)
;
; Attribute Bytes (for 'T' type at offset +0x12..+0x17):
;   byte +0x12  text attribute (foreground/background)
;   byte +0x13  highlight attribute
;   byte +0x14  character width
;   byte +0x15  combined flags (bit 2=bold, bits 3-4=font)
;   byte +0x16  underline style
;   byte +0x17  reserved
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Form Engine Functions ---
;
; Address   Name                          Size  Description
; -------   ----                          ----  -----------
; 0000:001E dmform_registerModule           68  Module registration - copies "DMCSR" ID, calls INT E0h/02h to register
; 0000:0062 dmform_returnToHost              6  Return from host call (add sp,8; pop bp; ret)
; 0000:0068 dmform_loadElementPtr           10  Load far pointer to element from [bp+0]/[bp+2]
; 0000:0072 dmform_initElementTable         54  Initialize element table - set all slots to 'OO' sentinel
; 0000:00AC dmform_resetElementFlags        19  Reset element flags, call dmform_processAllElements
; 0000:00CA dmform_lookupElement           146  Lookup element by index - validate 'OO' sentinel, return element data
; 0000:015A dmform_setElementIndex          21  Set element index: multiply by element size, add base, call thunk
; 0000:0170 dmform_insertElement           233  Insert element into table - shift existing, update links and counts
; 0000:0260 dmform_removeElement           288  Remove element from table - compact array, update links
; 0000:0382 dmform_setElementCallback       16  Set element callback: save [bp+0xC], call thunk, restore
; 0000:0392 dmform_loadElementFarPtr         8  Load element far pointer via DS bridge
; 0000:039A dmform_layoutFormOpen          370  Open/layout a form - query host for dimensions, set control block, allocate
; 0000:050A dmform_layoutFormClose           6  Close form layout, call thunks
; 0000:0516 dmform_layoutFormInit           18  Initialize form layout state
; 0000:0524 dmform_populateElements        140  Populate form elements - iterate and copy data to host-allocated slots
; 0000:05B4 dmform_copyElementData          87  Copy single element data to allocated slot via rep movsw
; 0000:060A dmform_rebuildElements         140  Rebuild elements after modification - reindex and recopy
; 0000:0696 dmform_loadElementDS             6  Load DS from element far pointer
; 0000:069E dmform_layoutFormAuto          366  Auto-layout form with calculated dimensions and spacing
; 0000:0770 dmform_adjustElementPositions   50  Adjust element positions after resizing (propagate delta)
; 0000:07A4 dmform_calcFormHeight           88  Calculate total form height by scanning element types
; 0000:07FC dmform_checkFirstElement        15  Check if first element exists (non-null at [bp+0x0E])
; 0000:080B dmform_sumTextWidths            58  Sum widths of text elements in form
; 0000:0849 dmform_copyElementBlock         67  Copy element data block (rep movsb) between buffers
; 0000:0893 dmform_findElementByType        44  Find element in table by matching type and link at offset+4
; 0000:08CF dmform_loadElementWithDS         6  Load element with DS bridge, call thunk pair
; 0000:08D5 dmform_freeElementChain         42  Free chain of elements - walk linked list, call free thunk
; 0000:0911 dmform_loadElementByIndex        7  Load element by index from [bp+6], call sub
; 0000:091E dmform_processElement          430  Process single element - type dispatch ('O','T','L','R','B','E','U')
; 0000:0AAC dmform_processElementClose       5  Close element processing state
; 0000:0AB5 dmform_processAllElements       29  Process all elements: call thunks for full layout pass
; 0000:0AD0 dmform_createNewElement        132  Create new element - allocate, set sentinel, copy data, link
; 0000:0B55 dmform_getElementDimensions      8  Get element dimensions (return ptr pair)
; 0000:0B5D dmform_calcPixelBounds          78  Calculate pixel bounds for element (min/max X,Y with offsets)
; 0000:0BAB dmform_calcPixelBoundsAlt       60  Calculate pixel bounds (alternate, from fixed element list)
; 0000:0BE7 dmform_insertElementSorted      43  Insert element into sorted position in array
; 0000:0C12 dmform_deleteElementByIndex     96  Delete element by index from array, compact remaining
; 0000:0C72 dmform_appendElement            33  Append element to end of array
; 0000:0C98 dmform_shiftElements           100  Shift elements in table (handle 'OO' compound vs simple types)
; 0000:0D05 dmform_getElementSize           24  Get element pixel size based on type byte
; 0000:0D27 dmform_getElementTypeInfo       39  Get element type info (dimension lookup for T/O/R/B/E/U)
; 0000:0D7D dmform_getElementHeight         18  Get element height from type table
; 0000:0D93 dmform_getElementWidth          15  Get element width from type table
; 0000:0DA7 dmform_sumSubElementWidths      36  Sum widths of all sub-elements in a compound element
; 0000:0DCB dmform_getElementPixelWidth     22  Get element pixel width (word at element table offset)
; 0000:0DE1 dmform_setElementPixelIndex     16  Set element pixel index from [bp+0x0C]
; 0000:0DF1 dmform_hitTestElement          146  Hit-test: check if point is inside element bounding box
; 0000:0E81 dmform_hitTestElementMouse       59  Hit-test with mouse coordinates (ES:[ptr])
; 0000:0EBC dmform_divideUnsigned32         49  Unsigned 32-bit divide (AX:BX / CX:DX)
; 0000:0EFD dmform_multiply32              108  32-bit multiply (result in DX:AX:BX:CX)
; 0000:0F69 dmform_findElementInArray       36  Find element in sorted array by matching word value
; 0000:0F8D dmform_findElementInList        18  Find element in list by type/value pair
; 0000:0FA5 dmform_calcAllBounds           139  Calculate bounding box for all visible elements
; 0000:1030 dmform_loadElementFarPtr2        6  Load far element pointer (DS bridge variant 2)
; 0000:103A dmform_updateElementLayout     253  Update element layout after insertion/deletion
; 0000:10F1 dmform_resetLayoutState          6  Reset layout state: set [bp+0x0C]=0, load registers
; 0000:110E dmform_insertAndReflow         195  Insert element and reflow: shift data, update sizes, move blocks
; 0000:11DB dmform_resetLayoutState2         6  Reset layout state variant 2
; 0000:11EB dmform_deleteAndReflow         257  Delete element and reflow: compact, update sizes, move blocks
; 0000:12EB dmform_loadElementTriple        12  Load element triple pointer (DS, ES, far)
; 0000:130B dmform_createTypedElement      188  Create element by type dispatch (L=0x14, R=0x18, B=0x18, E=0x18, T,U)
; 0000:13CF dmform_loadElementFarPtr3        6  Load far pointer variant 3
; 0000:13DE dmform_setElementBounds        110  Set element bounding box and call host draw
; 0000:1449 dmform_compactAndRelink         78  Compact element array and update links
; 0000:149E dmform_applyTextAttributes      47  Apply text field attributes (normal style)
; 0000:14DB dmform_applyLabelAttributes     77  Apply label field attributes (extended style)
; 0000:152E dmform_loadElementFarPtr4        6  Load far pointer variant 4
; 0000:1538 dmform_initFormArrays           65  Initialize form arrays (set counts, zero slots)
; 0000:1579 dmform_insertTextElement       109  Insert text element with calculated dimensions
; 0000:15EB dmform_insertOtherElement       60  Insert non-text element (R/B/E/L/U type)
; 0000:162B dmform_loadElementFarPtr5        6  Load far pointer variant 5
; 0000:163B dmform_editElement             170  Edit element - validate, get bounds, draw, call host
; 0000:16E5 dmform_updateElementBounds     179  Update element bounds from host data
; 0000:17A2 dmform_loadElementTriple2       12  Load element triple pointer variant 2
; 0000:17B2 dmform_moveElement             144  Move element to new position with redraw
; 0000:184A dmform_loadElementTriple3       12  Load element triple pointer variant 3
; 0000:185A dmform_resizeElement           148  Resize element with bounds checking and redraw
; 0000:18CA dmform_swapElements             14  Swap two elements in the table
; 0000:18D5 dmform_loadElementFarPtr6        6  Load far pointer variant 6
; 0000:18DB dmform_selectElement           170  Select element - highlight, get bounds, call host with 0x2080
; 0000:1937 dmform_loadElementFarPtr7        6  Load far pointer variant 7
; 0000:1947 dmform_deselectElement          14  Deselect element (reverse highlight)
; 0000:1967 dmform_loadElementFarPtr8        6  Load far pointer variant 8
; 0000:197B dmform_deleteElement            19  Delete element and call thunks
; 0000:1982 dmform_addElementToList         54  Add element to display list, update count
; 0000:19BB dmform_loadElementFarPtr9        6  Load far pointer variant 9
; 0000:19CC dmform_getElementAddress        14  Get element address: lookup and return seg:off
; 0000:19E2 dmform_loadElementTriple4       12  Load far pointer triple variant 4
; 0000:19F4 dmform_setElementPosition      100  Set element position with bounds check and redraw
; 0000:1A4C dmform_adjustPosition           25  Adjust element position: propagate through linked elements
; 0000:1B3C dmform_loadElementTriple5       12  Load far pointer triple variant 5
; 0000:1B4C dmform_hitTestAll               60  Hit-test all elements against point
; 0000:1B88 dmform_loadElementTriple6       12  Load far pointer triple variant 6
; 0000:1B97 dmform_findElementByValue       70  Find element by matching value in array
; 0000:1BDD dmform_loadElementTriple7       12  Load far pointer triple variant 7
; 0000:1BF5 dmform_buildElementList        142  Build display element list from form data
; 0000:1C83 dmform_loadElementTriple8       12  Load far pointer triple variant 8
; 0000:1C8A dmform_layoutElements          188  Layout elements within container bounds
; 0000:1D47 dmform_loadElementTriple9       12  Load far pointer triple variant 9
; 0000:1D59 dmform_drawAllElements         129  Draw all elements: validate, get bounds, draw each
; 0000:1DD9 dmform_transformCoordinates    432  Transform element coordinates for scaling/scrolling
; 0000:208D dmform_loadElementTriple10      12  Load far pointer triple variant 10
; 0000:20AC dmform_refreshElements         179  Refresh elements: recompute bounds, redraw visible
; 0000:2161 dmform_drawElementBounds         6  Draw element bounds (invalidate + redraw region)
; 0000:2167 dmform_validateAndDraw         132  Validate form state and draw all elements with host calls
; 0000:222A dmform_loadElementTriple11      12  Load far pointer triple variant 11
; 0000:2236 dmform_drawFormRegion          112  Draw form region with host invalidation
; 0000:22A2 dmform_loadElementTriple12      12  Load far pointer triple variant 12
; 0000:22B1 dmform_copyFormData             83  Copy form data between buffers (block copy)
; 0000:2304 dmform_clearFormData             8  Clear form data structure (zero word at [bx+0x10])
; 0000:230C dmform_loadElementFarPtr10       6  Load far pointer variant 10
; 0000:2322 dmform_findInBuffer             35  Find matching element in buffer by value
; 0000:2355 dmform_loadElementFarPtr11       6  Load far pointer variant 11
; 0000:235B dmform_insertIntoBuffer         42  Insert data into buffer at matched position
; 0000:2385 dmform_clearHighBitChain        28  Clear high-bit flags in element attribute chain
;
; --- Segment seg_023A: Jump Table ---
;
; 023A:0000  (data) Jump table continuation + element type dispatch vectors
; 023A:0025  (data) Function entry point offsets for host API dispatch
;
; --- Segment seg_0240: Entry Point + Registration ---
;
; 0240:0004  "DMFORM" module name string
; 0240:005B  entry_point - Register DMFORM with DeskMate host, then TSR
;
; ========================================================================
; DISPATCH TABLE
; ========================================================================
;
; The jump table at seg_023A:0025 contains word offsets into seg_0000
; for each form API function. The host calls into DMFORM via a
; far-call dispatcher that indexes this table.
;
; Functions are invoked by the host (DESK.EXE or Filer/FormSet/Address)
; via the registered far-call entry at 0000:0062.
;
; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (9120 bytes, file 0x0200-0x25A0)
; Form engine functions - all form layout, rendering, and hit-testing
; ------------------------------------------------------------------------
seg_0000:

; 0000:0000-0x001D  Data area: relocation targets and module ID
  0000:0000  db D1 E0 1E BF 3A 02 8E DF BF 0F 00 03 F8 8B 3D 1F ; [RELOC->seg_023A]
  0000:0010  db FF D7 CB EA F5 23 00 00                         ; [RELOC->seg_0000]
  0000:0018  db 44 4D 43 53 52                                  ; "DMCSR" - cursor/form module ID
  0000:001D  db 00                                                ; NUL terminator

; -----------------------------------------------------------------------
; dmform_registerModule  (0000:001E)
; Register the DMFORM module with the DeskMate host via INT E0h.
; Copies "DMCSR" ID string to stack frame, calls INT E0h AH=02h
; to register, then sets up the return-to-host far pointer at
; [bp+4]:[bp+6] = cs:0x0062.
;
; Parameters: none (called from entry_point at 0240:005B)
; Returns: far pointer to dmform_returnToHost stored at [bp+4..7]
; -----------------------------------------------------------------------
dmform_registerModule:
  0000:001E  55                push     bp
  0000:001F  8bec              mov      bp, sp
  0000:0021  83c504            add      bp, 4            ; skip saved BP + return addr
  0000:0024  55                push     bp
  0000:0025  83ec0e            sub      sp, 0xe          ; allocate local frame
  0000:0028  8bec              mov      bp, sp
  0000:002A  1e                push     ds
  0000:002B  06                push     es
  0000:002C  50                push     ax
  0000:002D  53                push     bx
  0000:002E  51                push     cx
  0000:002F  52                push     dx
  0000:0030  56                push     si
  0000:0031  57                push     di
  0000:0032  0e                push     cs
  0000:0033  1f                pop      ds               ; DS = CS (code segment)
  0000:0034  16                push     ss
  0000:0035  07                pop      es               ; ES = SS
  0000:0036  8d7e08            lea      di, [bp + 8]     ; dest = stack buffer
  0000:0039  be1800            mov      si, 0x18         ; src = "DMCSR\0"
  0000:003C  b90600            mov      cx, 6            ; 6 bytes including NUL
  0000:003F  f3a4              rep movsb                  ; copy module ID to stack
  0000:0041  16                push     ss
  0000:0042  1f                pop      ds               ; DS = SS
  0000:0043  8d5608            lea      dx, [bp + 8]     ; DX -> module ID on stack
  0000:0046  8d5e00            lea      bx, [bp]         ; BX -> local frame
  0000:0049  b80802            mov      ax, 0x208        ; INT E0h AH=02h: register module
  0000:004C  cde0              int      0xe0             ; Register with DeskMate host
  0000:004E  c746046200        mov      word ptr [bp + 4], 0x62  ; return offset = dmform_returnToHost
  0000:0053  8c4e06            mov      word ptr [bp + 6], cs    ; return segment = CS
  0000:0056  5f                pop      di
  0000:0057  5e                pop      si
  0000:0058  5a                pop      dx
  0000:0059  59                pop      cx
  0000:005A  5b                pop      bx
  0000:005B  58                pop      ax
  0000:005C  07                pop      es
  0000:005D  1f                pop      ds
  0000:005E  8b6e0e            mov      bp, word ptr [bp + 0xe]  ; restore caller's BP
  0000:0061  cb                retf                       ; far return to host

; -----------------------------------------------------------------------
; dmform_returnToHost  (0000:0062)
; Clean return stub - adjusts stack and returns.
; Called when host invokes a form function via the registered far pointer.
; -----------------------------------------------------------------------
  0000:0062  db 83 C4 08 5D C3                               ; add sp,8; pop bp; ret

; -----------------------------------------------------------------------
; dmform_loadElementPtr  (0000:0068..0071)
; Bridge: load far pointer from [bp+0]/[bp+2], set DS, call next function.
; -----------------------------------------------------------------------
  0000:0068  db C3 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3        ; ret; push ds; load; pop ds; ret

; -----------------------------------------------------------------------
; dmform_initElementTable  (0000:0072)
; Initialize all element slots to 'OO' (0x4F4F) sentinel value.
; Iterates through element array writing 0x4F4F to each slot,
; then clears [bp+0x0C] to mark form as initialized.
;
; Parameters: [bp+0x0C] = element count to init
;             [bp+0x0E] = base pointer to element array
; Returns: AX = 0 (via pop chain)
; -----------------------------------------------------------------------
  0000:0072  db 53 51 56 8B 5D 0C C7 07 4F 4F 83 C3 12 8B    ; push bx,cx,si; load count
  0000:0080  db 07 8B C8 D1 E1 05 0A 00 E8 5B 0B 50 2B F6 83 C3
  0000:0090  db 02 8B 00 53 2B DB E8 77 0B 5B 83 C6 02 3B F1 7C
  0000:00A0  db F0 C7 45 0C 00 00                               ; [bp+0x0C] = 0
  0000:00A6  db 58 5E 59 5B                                     ; pop chain
  0000:00AA  db C3                                              ; ret

; -----------------------------------------------------------------------
; dmform_resetElementFlags  (0000:00AC..00C9)
; Reset element flags and call processAllElements.
; Sets [bp+0x0C] = 0, calls dmform_processAllElements.
; -----------------------------------------------------------------------
  0000:00AC  db 1E 8B 7E 00 8E 5E 02 C7 45 0C 00 00 8B 46 04
  0000:00BC  db E8 D9 0E E8 02 00 1F C3                        ; call processAll, return

; -----------------------------------------------------------------------
; dmform_lookupElement  (0000:00CA)
; Look up element by index in the element table.
; Validates the 'OO' sentinel, scans forward through slots,
; returns element data or 0xFFFF on not-found.
;
; Parameters: AX = element index
;             [bp+0x0E] = element table base
; Returns: AX = element data (or 0xFFFF if not found)
; -----------------------------------------------------------------------
  0000:00CA  db 55 83 EC 04 8B EC                              ; push bp; sub sp,4; mov bp,sp
  0000:00D0  db 53 51 52 56                                     ; push bx,cx,dx,si
  0000:00D4  db 89 46 00 8B D8 D1 E3 03 5D 0E 81              ; save index, calc offset
  0000:00DF  db 3F 4F 4F 74                                     ; cmp [bx],'OO'; je found
  0000:00E3  db 06 B8 FF FF EB 73 90                            ; not found: return 0xFFFF
; ... (element traversal, sub-element counting, type checking)
  0000:0156  db 5E 5A 59 5B                                     ; pop si,dx,cx,bx
  0000:015A  db 83 C4 04 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_setElementIndex  (0000:015A)
; Multiply element index by element record size and add to base.
; Calls the thunk at [bp+0x0C] offset.
; -----------------------------------------------------------------------
  0000:015A  db 53 8B 5D 0C D1 E0 03 45 0E 89 45
  0000:0165  db 0C E8 65 1C 89 5D 0C 5B C3                     ; call thunk, ret

; -----------------------------------------------------------------------
; dmform_insertElement  (0000:0170)
; Insert a new element into the form table.
; Shifts existing elements to make room, updates sub-element links
; and element counts. Handles both 'OO' compound and simple types.
;
; Parameters: AX = element index
;             ES:[SI] = source element data (4 words of coordinates)
;             [bp+0x0E] = element table base
; Returns: AX = resulting element count
; -----------------------------------------------------------------------
  0000:0170  db 55 83 EC 1A 8B EC                              ; push bp; sub sp,0x1A
  0000:0176  db 53 51 52 56 57                                  ; push all work regs
; ... (element insertion logic with array shifting)
  0000:0259  db 5F 5E 5A 59 5B                                  ; pop chain
  0000:025E  db 83 C4 1A 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_removeElement  (0000:0260)
; Remove element from form table, compacting remaining entries.
; Handles 'OO' compound type removal (remove all sub-elements first).
;
; Parameters: AX = element index to remove
; Returns: AX = remaining element count
; -----------------------------------------------------------------------
  0000:0260  db 55 83 EC 0C 8B EC 53 56                        ; setup
; ... (removal + compaction logic)
  0000:037E  db 83 C4 0C 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_setElementCallback  (0000:0382)
; -----------------------------------------------------------------------
  0000:0382  db 51 8B 4D 0C 89 5D 0C E8 F8 1E 89 4D 0C 59 C3  ; save/restore [bp+0x0C]

; -----------------------------------------------------------------------
; dmform_loadElementFarPtr  (0000:0392)
; -----------------------------------------------------------------------
  0000:0392  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3           ; DS bridge

; -----------------------------------------------------------------------
; dmform_layoutFormOpen  (0000:039A)
; Open and lay out a form.
; Queries host for form dimensions via INT E0h AH=04h subfunction 01h/02h,
; calculates element positions, initializes the control block, and
; allocates form storage via INT E0h AH=04h subfunction 06h.
;
; Parameters: [bp+0x0C] = form handle (0 for new form)
;             [bp+0x0E] = element table base
; Returns: AX = 0 on success, 0xFFFF on failure
; -----------------------------------------------------------------------
  0000:039A  db 55 83 EC 2C 8B EC                              ; push bp; sub sp,0x2C
  0000:03A0  db 53 51 52 56                                     ; push work regs
; ... (dimension query, control block init, allocation)
  0000:0504  db 5E 5A 59 5B                                     ; pop chain
  0000:0508  db 83 C4 2C 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_layoutFormClose + dmform_layoutFormInit  (0000:050A..0529)
; -----------------------------------------------------------------------
  0000:050A  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3           ; close thunk
  0000:0516  db E8 81 FE E8 4C 1C C3                            ; init: call register + thunk

; -----------------------------------------------------------------------
; dmform_populateElements  (0000:0524)
; Populate host-allocated form element slots with data from the
; element table. Iterates through all elements copying their data.
; -----------------------------------------------------------------------
  0000:0524  db 55 83 EC 08 8B EC
  0000:052A  db 53 51 52 56                                     ; push work regs
; ... (population loop)
  0000:05B0  db 5E 5A 59 5B                                     ; pop chain
  0000:05B4  db 83 C4 08 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_copyElementData  (0000:05B4)
; Copy data for one element to its allocated slot using rep movsw.
; -----------------------------------------------------------------------
  0000:05B4  db 55 83 EC 06 8B EC
  0000:05BA  db 53 51 52 56 57                                  ; push work regs
; ... (single element copy with rep movsw)
  0000:0601  db 5F 5E 5A 59 5B
  0000:0606  db 83 C4 06 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_rebuildElements  (0000:060A)
; Rebuild form elements after a structural change (add/remove).
; Reindexes the element table and re-copies all data.
; -----------------------------------------------------------------------
  0000:060A  db 55 83 EC 0C 8B EC
  0000:0610  db 53 51 52 56 57                                  ; push work regs
; ... (rebuild loop with re-indexing)
  0000:068B  db 5F 5E 5A 59 5B
  0000:0690  db 83 C4 0C 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_loadElementDS  (0000:0696)
; -----------------------------------------------------------------------
  0000:0696  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3           ; DS bridge

; -----------------------------------------------------------------------
; dmform_layoutFormAuto  (0000:069E)
; Auto-layout form with computed dimensions.
; Similar to dmform_layoutFormOpen but with automatic sizing.
; Calculates scroll parameters (0x64 and 0x6E constants for
; horizontal and vertical scroll units).
; -----------------------------------------------------------------------
  0000:069E  db 55 83 EC 2C 8B EC
  0000:06A4  db 53 51 52 56                                     ; push work regs
; ... (auto-layout with scroll calculation)
  0000:076C  db 5E 5A 59 5B
  0000:0770  db 83 C4 2C 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_adjustElementPositions  (0000:0770)
; After a form resize, propagate position delta through all elements.
; For 'OO' compound elements, adjusts all sub-elements recursively.
; -----------------------------------------------------------------------
  0000:0770  db 53 51 8B DA D1 E3 03 5D 0E 8A 0F               ; load type byte
  0000:077B  db 80 F9 4F 75 1D                                  ; cmp cl,'O'; jne skip
; ... (delta propagation for compound elements)
  0000:07A0  db 5A 5E 59 5B C3                                  ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_calcFormHeight  (0000:07A4)
; Calculate total form height by scanning all elements.
; Dispatches on type: 'T' checks height attribute at +0x14,
; 'OO' recurses into sub-elements.
; -----------------------------------------------------------------------
  0000:07A4  db 55 83 EC 04 8B EC 53 51 56                     ; setup
; ... (type dispatch loop)
  0000:07FC  db 83 C4 04 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_checkFirstElement  (0000:07FC)
; Check if element table has at least one entry.
; Returns via dmform_adjustElementPositions if non-empty.
; -----------------------------------------------------------------------
  0000:07FC  db 53 8B 5D 0E 83 3F 00 74 09 83 EB 12 B8 04 00 E8 9A FF 5B C3

; -----------------------------------------------------------------------
; dmform_sumTextWidths  (0000:080B)
; Sum character widths of all text-type elements in the form.
; Skips elements marked with high bit in attribute byte.
; -----------------------------------------------------------------------
  0000:080B  db 55 83 EC 02 8B EC
  0000:0811  db 53 51 52 56                                     ; push work regs
; ... (width summation loop with attribute check)
  0000:0845  db 5A 5E 59 5B
  0000:0849  db 83 C4 02 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_copyElementBlock  (0000:0849)
; Copy a block of element data between source and destination.
; Uses rep movsb for byte-level copy.
; -----------------------------------------------------------------------
  0000:0849  db 55 83 EC 04 8B EC
  0000:084F  db 53 51 57 56                                     ; push work regs
; ... (block copy with rep movsb)
  0000:088B  db 5E 5F 59 5B
  0000:088F  db 83 C4 04 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_findElementByType  (0000:0893)
; Find element in table by matching type byte and link value at +4.
; Returns: AX = element data, or falls through if not found.
; -----------------------------------------------------------------------
  0000:0893  db 55 83 EC 04 8B EC 53 56 06 8E C3               ; setup
; ... (type matching loop)
  0000:08CF  db 07 5E 5B 83 C4 04 5D C3                        ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_loadElementWithDS  (0000:08CF)
; -----------------------------------------------------------------------
  0000:08CF  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3           ; DS bridge

; -----------------------------------------------------------------------
; dmform_freeElementChain  (0000:08D5)
; Free a chain of elements by walking linked list.
; Clears high bit of attribute byte, then calls free thunk.
; -----------------------------------------------------------------------
  0000:08D5  db 53 51 83 7D 04 00 74 26                        ; check if chain head exists
; ... (walk and free loop)
  0000:08FF  db 59 5B C3                                        ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_loadElementByIndex  (0000:0911)
; Load element by index from [bp+6] and call processing function.
; -----------------------------------------------------------------------
  0000:0911  db 1E 8B 7E 00 8E 5E 02 8B 46 04 E8 02 00 1F C3  ; load and dispatch

; -----------------------------------------------------------------------
; dmform_processElement  (0000:091E)
; Process a single form element for rendering.
; Dispatches on element type byte:
;   'O' (0x4F) = compound element, process sub-elements recursively
;   'T' (0x54) = text field, calculate dimensions and render
;   Other = simple element, get size and render
;
; Sets up INT E0h calls for element allocation (AH=04h, func 06h)
; and property query (AH=04h, func 01h).
;
; Parameters: AX = element index
; Returns: varies by element type
; -----------------------------------------------------------------------
  0000:091E  db 55 83 EC 2E 8B EC
  0000:0924  db 53 51 52 56                                     ; push work regs
; ... (type dispatch: 'O' compound, 'T' text, default simple)
; Calls INT E0h AH=04h:
;   func 06h = allocate element storage
;   func 01h = get element properties (4 words)
  0000:0AAC  db 5E 5A 59 5B
  0000:0AB0  db 83 C4 2E 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_processAllElements  (0000:0AB5)
; Process all elements in the form for a complete layout pass.
; Calls internal thunks to iterate through element table.
; -----------------------------------------------------------------------
  0000:0AB5  db 1E 8B 7E 00 8E 5E 02 8B 46 04 E8 02 00 1F C3  ; load
  0000:0AC5  db 50 E8 53 FE 58 E8 11 09 C3                     ; call processElement, return

; -----------------------------------------------------------------------
; dmform_createNewElement  (0000:0AD0)
; Create a new element - allocate slot, set 'OO' sentinel, copy data.
; Links new element into the display list.
;
; Parameters: AX = element type, DX:SI = source data, ES:BX = dest
; Returns: AX = element offset in table
; -----------------------------------------------------------------------
  0000:0AD0  db 55 83 EC 04 8B EC
  0000:0AD6  db 53 51 52 56 50                                  ; push work regs + type
; ... (allocate, sentinel, copy, link)
  0000:0B51  db 5E 5A 59 5B
  0000:0B55  db 83 C4 04 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_getElementDimensions  (0000:0B55..0B5C)
; -----------------------------------------------------------------------
  0000:0B55  db 8B 7E 00 8B 76 02 C3                            ; mov di,[bp+0]; mov si,[bp+2]; ret

; -----------------------------------------------------------------------
; dmform_calcPixelBounds  (0000:0B5D)
; Calculate pixel bounding rectangle for an element.
; Adds offsets 0x01BA (442) and subtracts 0x00DD (221) for coordinate
; mapping between form coordinates and pixel coordinates.
; Calls host function 0x206D to draw the bounding box.
; -----------------------------------------------------------------------
  0000:0B5D  db 50 53 51 52 56                                  ; push work regs
; ... (coordinate transform + draw call)
  0000:0BA6  db 5E 5A 59 5B 58 C3                               ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_calcPixelBoundsAlt  (0000:0BAC)
; Alternate pixel bounds calculation (from fixed element list at [bp+0x0C]).
; Same transform constants: +0x01BA, -0x00DD.
; -----------------------------------------------------------------------
  0000:0BAC  db 50 53 51 52 56                                  ; push work regs
; ... (alternate coordinate transform)
  0000:0BE2  db 5E 5A 59 5B 58 C3                               ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_insertElementSorted  (0000:0BE7)
; Insert element into array maintaining sorted order.
; Used for z-ordering and display list management.
; -----------------------------------------------------------------------
  0000:0BE7  db 53 56 8B 5D 08 2B D8 89 5D 08                  ; setup
; ... (find position, shift, insert)
  0000:0C12  db 5E 5B C3                                        ; pop, ret

; -----------------------------------------------------------------------
; dmform_deleteElementByIndex  (0000:0C12)
; Delete element by index, compact array, decrement count.
; -----------------------------------------------------------------------
  0000:0C12  db 53 51 52 56 57 55 53                            ; push all work regs
; ... (search, compact, update count)
  0000:0C6C  db 5D 5F 5E 5A 59 5B C3                            ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_appendElement  (0000:0C72)
; Append element to end of array, update count and index.
; -----------------------------------------------------------------------
  0000:0C72  db C3 53 51 56 8B 5D 0E 8B 75 06                  ; setup
; ... (append logic)
  0000:0C98  db 5E 59 5B C3                                     ; pop, ret

; -----------------------------------------------------------------------
; dmform_shiftElements  (0000:0C98)
; Shift elements in table for insert/remove operations.
; Handles 'OO' compound type (shifts sub-elements) and simple types.
; -----------------------------------------------------------------------
  0000:0C98  db 55 83 EC 06 8B EC
  0000:0C9E  db 53 51 56 57                                     ; push work regs
; ... (shift logic with type dispatch)
  0000:0CFF  db 5F 5E 59 5B
  0000:0D03  db 83 C4 06 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_getElementSize  (0000:0D05..0D26)
; Get element size based on type byte at [bp+0x0E]+offset.
; Returns: AX = 0xFFFF if not found, otherwise element index * size.
; -----------------------------------------------------------------------
  0000:0D05  db 53 51 8B 5D 0E 8B 1F D1 E3 43 8B 4D 08 2B CB 83 E9 02 3B C8 7F 03 B8 FF FF 59 5B C3

; -----------------------------------------------------------------------
; dmform_getElementTypeInfo  (0000:0D27..0D7C)
; Get element dimension info based on type character.
; Dispatches: T=text, O=compound, R=rect(12), B=button(12), E=entry(12), U=underline.
; -----------------------------------------------------------------------
  0000:0D27  db 53 51 56 8B D8 D1 E0 8B 75 0E 03 F0 8A 04     ; load type
  0000:0D35  db 3C 54 75 07 8B C3 E8 43 00 EB                  ; type 'T'?
  0000:0D3F  db 3D 3C 4F 75 10                                  ; type 'O'?
  0000:0D44  db 8B C3 E8 88 00 8B C8 8B C3 E8 93 00 03 C1 EB  ; compound
  0000:0D52  db 29 3C 52 75 05 B8 0C 00 EB                     ; type 'R'? -> size 12
  0000:0D5B  db 20 3C 42 75 05 B8 0C 00 EB 17                  ; type 'B'? -> size 12
  0000:0D65  db 3C 45 75 05 B8 0C 00 EB 0E                     ; type 'E'? -> size 12
  0000:0D6E  db 3C 55 75 07 8B C3 E8 23 00 EB 03 B8 0A 00     ; type 'U'? -> calculated
  0000:0D7C  db 5E 59 5B C3                                     ; pop, ret

; -----------------------------------------------------------------------
; dmform_getElementHeight / dmform_getElementWidth  (0000:0D7D..0DA6)
; -----------------------------------------------------------------------
  0000:0D7D  db C3 56 D1 E0 8B 75 0E 03 F0 83 C6 14 8A 04 2A E4 40 05 18 00 2D 02 00 D1 E8 5E C3
  0000:0D97  db 56 D1 E0 8B 75 0E 03 F0 83 C6 12 8B 04 5E C3

; -----------------------------------------------------------------------
; dmform_sumSubElementWidths  (0000:0DA7)
; Sum widths of sub-elements in a compound element.
; -----------------------------------------------------------------------
  0000:0DA7  db 53 51 56 2B C9 8B 75 0C 83 C6 12 8B 1C 4B 83 C6 02 8B 04 E8 67 FF 03 C8 4B 79 F3 8B C1 5E 59 5B C3

; -----------------------------------------------------------------------
; dmform_getElementPixelWidth  (0000:0DCB..0DEA)
; -----------------------------------------------------------------------
  0000:0DCB  db 8B 7E 00 8B 46 02 56 8B F0 D1 E6 03 75 0E 83 C6 12 8B 04 05 0A 00 5E C3

; -----------------------------------------------------------------------
; dmform_setElementPixelIndex  (0000:0DE1..0DF0)
; -----------------------------------------------------------------------
  0000:0DE1  db 53 8B 5D 0C D1 E0 03 45 0E 89 45 0C E8 B8 FF 89 5D 0C 5B C3

; -----------------------------------------------------------------------
; dmform_hitTestElement  (0000:0DF1)
; Hit-test: check if point (ES:[ptr]) is inside element bounding box.
; Compares point coordinates against element min/max X,Y.
; Returns: AX = 1 if inside, 0 if outside
; -----------------------------------------------------------------------
  0000:0DF1  db 53 51 57 8B 5D 0E 8B F9 D1 E7 8B 49 02 8B 41 0A 3B C8 7C 01 91
; ... (coordinate range check)
  0000:0E31  db 2B C0 5F 59 5B C3                               ; return 0 (not hit)

; -----------------------------------------------------------------------
; dmform_hitTestElementMouse  (0000:0E3D..0E80)
; Hit-test with mouse coordinates from ES:[ptr], checking against
; element bounds with 0x32 (50-pixel) margin.
; -----------------------------------------------------------------------
  0000:0E3D  db 51 56 8B F0 D1 E6 03 75 0E                     ; setup
; ... (bounds check with margin)
  0000:0E80  db 2B C0 5E 59 C3                                  ; return 0

; -----------------------------------------------------------------------
; dmform_hitTestElementMouse2  (0000:0E81..0EBB)
; Second variant of mouse hit-test (checks ES:[bx] coordinates).
; -----------------------------------------------------------------------
  0000:0E81  db 51 56 8B F0 D1 E6 03 75 0E                     ; setup
; ... (ES-based coordinate check)
  0000:0EBB  db 2B C0 5E 59 C3                                  ; return 0

; -----------------------------------------------------------------------
; dmform_divideUnsigned32  (0000:0EBC)
; 32-bit unsigned division. Uses shift-and-subtract algorithm.
; Parameters: DX:AX = dividend, CX:BX = divisor
; Returns: DX:AX = quotient
; -----------------------------------------------------------------------
  0000:0EBC  db 55 83 EC 07 8B EC C6 46 00 20 3B C6            ; setup, init shift counter
; ... (32-bit division loop)
  0000:0EED  db 8B DA 8B C1 D1 E3 D1 D0 83 C4 07 5D C3        ; return quotient

; -----------------------------------------------------------------------
; dmform_multiply32  (0000:0EFD)
; 32-bit multiply using repeated 16x16 partial products.
; Parameters: [bp+8..0x0E] = operands
; Returns: DX:AX:BX:CX = 64-bit product
; -----------------------------------------------------------------------
  0000:0EFD  db 55 83 EC 10 8B EC                               ; setup
; ... (partial product accumulation)
  0000:0F6D  db 83 C4 10 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_findElementInArray  (0000:0F69..0F8C)
; Find element in array by matching word value.
; Scans [bp+0x0E] table comparing elements.
; Returns: AX = found index, or 0 if not found.
; -----------------------------------------------------------------------
  0000:0F69  db 51 8B 5D 0E 8B 1F 8B CB D1 E3 4B D1 E3 03 5D 0E 3B 47 02 74 0B 83 EB 04 49 75 F5 B8 00 00 EB 04 8B C1 8B 1F 59 C3

; -----------------------------------------------------------------------
; dmform_findElementInList  (0000:0F8D..0FA4)
; -----------------------------------------------------------------------
  0000:0F8D  db 8B 7E 00 8B 46 02 53 E8 D0 FF 3D 00 00 74 02 8B C3 5B C3

; -----------------------------------------------------------------------
; dmform_calcAllBounds  (0000:0FA5)
; Calculate bounding box encompassing all visible form elements.
; Initializes bounds to 0x7FFF (max) / 0x0000 (min) and expands
; to include each visible element.
; -----------------------------------------------------------------------
  0000:0FA5  db 53 51 52 56 57 55                               ; push all work regs
; ... (bounds accumulation loop)
  0000:1029  db 5D 5F 5E 5A 59 5B C3                            ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_loadElementFarPtr2 + dmform_updateElementLayout
; (0000:1030..10F0)
; Update element layout after structural changes.
; For new elements (type==0), initializes default properties.
; For existing elements, recalculates positions and sizes.
; -----------------------------------------------------------------------
  0000:1030  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3           ; DS bridge
  0000:103A  db 55 83 EC 04 8B EC 53 51 52                     ; setup
; ... (layout update logic with type dispatch)
  0000:10EF  db 5D C3                                            ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_resetLayoutState  (0000:10F1)
; -----------------------------------------------------------------------
  0000:10F1  db 1E 8B 7E 00 8E 5E 02 C7 45 0C 00 00 8B 46 04 8B 5E 06 E8 02 00 1F C3

; -----------------------------------------------------------------------
; dmform_insertAndReflow  (0000:110E)
; Insert element and reflow form layout.
; For 'O' compound elements, updates sub-element counts and offsets.
; Moves data blocks using rep movsw with direction flag management.
; -----------------------------------------------------------------------
  0000:110E  db 53 51 52 56 57                                  ; push work regs
; ... (insert + reflow + block move with rep movsw)
  0000:11D0  db 5F 5E 5A 59 5B C3                               ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_resetLayoutState2  (0000:11DB)
; -----------------------------------------------------------------------
  0000:11DB  db 1E 8B 7E 00 8E 5E 02 C7 45 0C 00 00 E8 02 00 1F C3

; -----------------------------------------------------------------------
; dmform_deleteAndReflow  (0000:11EB)
; Delete element and reflow form layout.
; Compacts element array, updates sizes, moves blocks using rep movsw.
; Handles both forward and reverse direction (FD/FC flag).
; -----------------------------------------------------------------------
  0000:11EB  db 53 51 52 56 57 55                               ; push all work regs
; ... (delete + compact + reflow)
  0000:12E5  db 5D 5F 5E 5A 59 5B C3                            ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_loadElementTriple  (0000:12EB)
; -----------------------------------------------------------------------
  0000:12EB  db 1E 06 8B 7E 00 8E 5E 02 8B 76 04 8E 46 06 C7 45 0C 00 00 E8 03 00 07 1F C3

; -----------------------------------------------------------------------
; dmform_createTypedElement  (0000:130B)
; Create form element by type.
; Dispatches on type byte:
;   'L' (label)  -> allocate 0x14 bytes
;   'R' (rect)   -> allocate 0x18 bytes
;   'B' (button) -> allocate 0x18 bytes
;   'E' (entry)  -> allocate 0x18 bytes
;   'T' (text)   -> call dmform_insertTextElement
;   'U' (underline) -> call dmform_insertOtherElement
; After allocation, copies element data using rep movsw,
; sets bounds, and calls host draw function 0x2120.
; -----------------------------------------------------------------------
  0000:130B  db 51 56 57 26 8A 04                               ; load type byte
  0000:0311  db 3C 4C 75 05 B9 14 00 EB 19                     ; 'L' -> 20 bytes
  0000:031A  db 3C 52 75 05 B9 18 00 EB 10                     ; 'R' -> 24 bytes
  0000:0323  db 3C 42 75 05 B9 18 00 EB 07                     ; 'B' -> 24 bytes
  0000:032C  db 3C 45 75 33 B9 18 00                            ; 'E' -> 24 bytes
; ... (allocate, copy, set bounds, host draw call)
  0000:13C8  db 58 5F 5E 59 83 C4 08 5D C3                     ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_loadElementFarPtr3  (0000:13CF)
; -----------------------------------------------------------------------
  0000:13CF  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3

; -----------------------------------------------------------------------
; dmform_setElementBounds  (0000:13DE)
; Set element bounding box and call host draw.
; Gets min/max bounds from element, calls dmform_calcAllBounds,
; then issues host draw call 0x2120 to invalidate region.
; -----------------------------------------------------------------------
  0000:13DE  db C7 45 0C 00 00 8B 46 04 E8 B0 FB 3D 00 00 74 55
; ... (bounds calculation + host draw)
  0000:143C  db 5D EB 03 E8 01 00 C3                            ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_compactAndRelink  (0000:1449)
; Compact element array and update all element links.
; Used after deletion to maintain array integrity.
; -----------------------------------------------------------------------
  0000:1449  db 55 83 EC 02 8B EC
  0000:144F  db 53 51 52 56                                     ; push work regs
; ... (compact + relink loop)
  0000:1494  db 5E 5A 59 5B
  0000:1498  db 83 C4 02 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_applyTextAttributes  (0000:149E)
; Apply attribute bytes to text field element (normal style).
; Copies up to 4 attribute bytes from ES:[ptr] if not 0xFF (default).
; -----------------------------------------------------------------------
  0000:149E  db 80 7F 01 5A 7E 05 E8 06 00 EB 03 E8 31 00 C3  ; check style flag
  0000:14AD  db 53 83 C3 14 26 8A 04 3C FF 74 02 88 07         ; byte 0: text attr
  0000:14BA  db 26 8A 44 01 3C FF 74 03 88 47 01               ; byte 1: highlight
  0000:14C5  db 26 8A 44 03 3C FF 74 03 88 47 03               ; byte 3: underline
  0000:14D0  db 26 8A 44 02 3C FF 74 03 88 47 02 5B C3         ; byte 2: width

; -----------------------------------------------------------------------
; dmform_applyLabelAttributes  (0000:14DB)
; Apply attribute bytes to label element (extended style with bold/font).
; Copies up to 8 attribute bytes from ES:[ptr], including font flags.
; -----------------------------------------------------------------------
  0000:14DB  db 53 83 C3 14 26 8A 44 04 3C FF 74 02 88 07      ; byte 4: base attr
; ... (7 more attribute byte copies)
  0000:152E  db 5B C3                                            ; ret

; -----------------------------------------------------------------------
; dmform_loadElementFarPtr4  (0000:152E)
; -----------------------------------------------------------------------
  0000:152E  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3

; -----------------------------------------------------------------------
; dmform_initFormArrays  (0000:1538)
; Initialize form arrays - set element counts to zero,
; clear all display list slots.
; -----------------------------------------------------------------------
  0000:1538  db 53 51 C7 45 06 01 00 C7 45 0A 00 00 C7 45 0C 00 00
; ... (array initialization loop)
  0000:1578  db C3                                              ; ret

; -----------------------------------------------------------------------
; dmform_insertTextElement  (0000:1579)
; Insert a text element with calculated dimensions.
; Reads character width from attribute byte at offset +0x14,
; allocates appropriately sized storage, and copies data.
; -----------------------------------------------------------------------
  0000:1579  db 53 51 56 57 26 80 7C 14 00                     ; check char width
; ... (calculate size, allocate, copy text data)
  0000:15E6  db 5F 5E 59 5B C3                                  ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_insertOtherElement  (0000:15EB)
; Insert non-text element (R/B/E/L/U types).
; Reads element count from ES:[ptr+0x12], allocates, copies data.
; -----------------------------------------------------------------------
  0000:15EB  db 53 51 56 57 26 8B 44 12                        ; load element count
; ... (allocate, copy element data)
  0000:1627  db 5F 5E 59 5B C3                                  ; pop chain, ret

; -----------------------------------------------------------------------
; dmform_loadElementFarPtr5  (0000:162B)
; -----------------------------------------------------------------------
  0000:162B  db 1E 8B 7E 00 8E 5E 02 8B 46 04 E8 5F F9

; -----------------------------------------------------------------------
; dmform_editElement  (0000:163B)
; Edit a form element - validate state, get bounding box,
; call host draw functions for visual update.
; -----------------------------------------------------------------------
  0000:163B  db 8B 76 06 8E 46 08 3D 00 00 75 03 E9 96 00     ; validate
; ... (bounds calculation + draw)
  0000:1799  db 5E 5A 59 5B
  0000:179D  db 83 C4 14 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_updateElementBounds  (0000:16E5)
; Update element bounds from host-provided data.
; Copies coordinate data and sets position/size attributes based
; on element type ('O' compound vs 'T' text vs others).
; For 'T' (text) with active flag, calculates width from character
; width attribute using formula: width = charWidth * 100 + offset.
; -----------------------------------------------------------------------
  0000:16E5  db 55 83 EC 14 8B EC
  0000:16EB  db 53 51 52 56                                     ; push work regs
; ... (bounds update with type dispatch)
  0000:1799  db 5E 5A 59 5B
  0000:179D  db 83 C4 14 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_loadElementTriple2  (0000:17A2)
; -----------------------------------------------------------------------
  0000:17A2  db 1E 06 8B 7E 00 8E 5E 02 C7 45 0C 00 00 8B 46 04 E8 E3 F7

; -----------------------------------------------------------------------
; dmform_moveElement  (0000:17B2)
; Move element to new position, call host draw 0x2080 to update display.
; Gets element bounds, calls processElement, re-renders.
; -----------------------------------------------------------------------
  0000:17B2  db 3D 00 00 75 03 E9 8E 00 8B 76 06 8E 46 08     ; validate
; ... (move + redraw logic)
  0000:1841  db 58 5F 5E 5A 59 5B
  0000:1847  db 83 C4 04 5D C3                                  ; cleanup and ret

; -----------------------------------------------------------------------
; dmform_loadElementTriple3 + dmform_resizeElement
; (0000:184A..1936)
; -----------------------------------------------------------------------
  0000:184A  db 1E 06 8B 7E 00 8E 5E 02 8B 46 04 8B 76 06 8E 46 08

; dmform_resizeElement: resize with bounds checking and redraw.
; Gets current bounds, adjusts, validates min/max, calls host draw.
  0000:185A  db C7 45 0C 00 00 80 7D 01 00 74 5D               ; check active flag
; ... (resize + redraw + host calls)
  0000:1927  db 06 8B 46 00 89 44 02 58 89 04 5E 5B 83 C4 04 5D C3

; -----------------------------------------------------------------------
; dmform_swapElements  (0000:18CA..18D4)
; Swap two element positions in the display order.
; -----------------------------------------------------------------------
  0000:18CA  db 53 50 33 DB E8 C4 F2 8B D8 58 E8 1F F3 8B C3 8B 5D 06 D1 E3 D1 E3 83 EB 04 03 5D 0E 89 07 5B C3

; (Additional thunks and functions continue through 0x23A0...)
; All following functions use the same pattern of push/pop frames,
; type dispatch, and host API calls via INT E0h and far-call thunks.

; ... (remaining form engine functions 0x1937..0x239F)
; These include: selectElement, deselectElement, deleteElement,
; addElementToList, getElementAddress, setElementPosition,
; hitTestAll, findElementByValue, buildElementList, layoutElements,
; drawAllElements, transformCoordinates, refreshElements, drawFormRegion,
; copyFormData, clearFormData, findInBuffer, insertIntoBuffer,
; clearHighBitChain.
;
; (raw bytes preserved from original disassembly below)

  0000:1937  db 1E 8B 7E 00 8E 5E 02 8B 46 04 E8 56 F6 E8 02 00 1F C3
  0000:1947  db 53 50 33 DB E8 C4 F2 8B D8 58 E8 1F F3 8B C3 8B
  0000:1957  db 5D 06 D1 E3 D1 E3 83 EB 04 03 5D 0E 89 07 5B C3
  0000:1967  db 1E 8B 7E 00 8E 5E 02 8B 46 04 8B 5E 04 E8 21 F6
  0000:1977  db E8 02 00 1F C3
  0000:197C  db 55 83 EC 02 8B EC
  0000:1982  db 53 51 56 50 2B DB E8 87 F2 8B C8 8B 5D 0E 8B 37 D1 E6 D1 E6 8B
  0000:1997  db 00 89 40 04 83 EE 02 83 FE 00 7F F3 FF 07 8B 07
  0000:19A7  db 40 89 45 06 83 C3 02 58 89 07 89 4F 02 5E 59 5B
  0000:19B7  db 83 C4 02 5D C3

  0000:19BC  db 1E 8B 7E 00 8E 5E 02 8B 46 04 E8
  0000:19C7  db 02 00 1F C3 E8 CA F5 3D 00 00 75 06 B8 FF FF 99
  0000:19D7  db EB 07 D1 E0 03 45 0E 1E 5A C3

  0000:19E1  db 1E 06 8B 7E 00 8E
  0000:19E7  db 5E 02 8B 46 04 8B 76 06 8E 46 08 E8 A3 F5 3D 00
  0000:19F7  db 00 74 55 80 7D 01 00 74 4C 55 83 EC 08 8B EC 8B
  0000:1A07  db D8 D1 E3 03 5D 0E 8B 4F 02 8B 57 0A 3B D1 7D 02
  0000:1A17  db 87 CA 89 4E 00 89 56 04 8B 4F 06 8B 57 0E 3B D1
  0000:1A27  db 7D 02 87 CA 89 4E 02 89 56 06 50 E8 2C F1 58 E8
  0000:1A37  db 19 00 16 55 1E 57 B8 1E 21 E8 DB E5 83 C4 08 83
  0000:1A47  db C4 08 5D EB 03 E8 03 00 07 1F C3

  0000:1A52  db 53 8B 5D 0E D1
  0000:1A57  db E0 03 D8 8A 07 3C 54 75 05 E8 22 00 EB 1E 3C 4C
  0000:1A67  db 75 05 E8 60 00 EB 15 3C 4F 75 05 E8 0D E9 EB 0C
  0000:1A77  db 3C 55 75 05 E8 1F FA EB 03 E8 6B 00 5B C3

; Attribute application for text (0x1A87..0x1B3B)
  0000:1A87  db 26 8A 04 3C FF 74 03 88 47 13 26 8A 44 01 3C FF 74 03
  0000:1A97  db 88 47 12 26 8A 44 03 3C FF 74 03 88 47 01 26 8A
  0000:1AA7  db 44 02 3C FF 74 07 80 67 15 FC 08 47 15 26 8A 44
  0000:1AB7  db 06 3C FF 74 0F 3C 04 7E 0B 80 67 15 03 D0 E0 D0
  0000:1AC7  db E0 08 47 15 C3
  0000:1ACC  db 26 8A 44 04 3C FF 74 03 88 47 12
  0000:1AD7  db 26 8A 44 05 3C FF 74 03 88 47 01 26 8A 44 06 3C
  0000:1AE7  db FF 74 03 88 47 13 C3
  0000:1AEE  db 26 8A 44 04 3C FF 74 03 88
  0000:1AF7  db 47 12 26 8A 44 05 3C FF 74 03 88 47 14 26 8A 44
  0000:1B07  db 06 3C FF 74 03 88 47 13 26 8A 44 07 3C FF 74 03
  0000:1B17  db 88 47 01 26 8A 44 09 3C FF 74 03 88 47 16 26 8A
  0000:1B27  db 44 08 3C FF 74 03 88 47 15 26 8A 44 0A 3C FF 74
  0000:1B37  db 03 88 47 17 C3

; dmform_loadElementTriple5 + dmform_hitTestAll (0000:1B3C..1B87)
  0000:1B3C  db 1E 06 8B 7E 00 8E 5E 02 8B 5E 04
  0000:1B47  db 8E 46 06 E8 03 00 07 1F C3
  0000:1B50  db 51 56 55 8B 6D 0E 3E
  0000:1B57  db 8B 4E 00 2B C0 83 F9 00 74 1C D1 E1 D1 E1 83 E9
  0000:1B67  db 02 BE 02 00 3E 8B 02 E8 10 F3 3D 01 00 74 07 83
  0000:1B77  db C6 04 3B F1 7E EE 5D 5E 59 C3

; dmform_loadElementTriple6 + dmform_findElementByValue (0000:1B83..1BDC)
  0000:1B83  db 1E 8B 7E 00 8E
  0000:1B87  db 5E 02 8B 46 04 8B 5E 06 8B 4E 08 E8 02 00 1F C3
  0000:1B97  db 55
  0000:1B98  db 83 EC 04 8B EC 53 51 56 89 46 00 89 5E 02 8B 5D
  0000:1BA7  db 0E 8B 37 2B C0 83 FE 00 74 29 D1 E6 D1 E6 83 EE
  0000:1BB7  db 02 03 F3 8B DD 83 C3 00 8B 04 E8 72 F2 2B C8 83
  0000:1BC7  db F9 00 74 0C 83 EE 04 3B 75 0E 7F EC 2B C0 EB 03
  0000:1BD7  db 8B 44 02 5E 59 5B 83 C4 04 5D C3

; dmform_loadElementTriple7 + dmform_buildElementList (0000:1BDD..1C82)
  0000:1BDD  db 1E 06 8B 7E 00
  0000:1BE7  db 8E 5E 02 8B 76 04 8E 46 06 8B 4E 08 E8 03 00 07
  0000:1BF7  db 1F C3
  0000:1BF9  db 53 51 56 C7 45 0C 00 00 83 F9 00 75 03 EB
  0000:1C07  db 64 90 8B 5D 08 4B D1 E3 03 5D 0E 8B C1 D1 E0 05
  0000:1C17  db 14 00 E8 EC F0 3D FF FF
  0000:1C1F  db 74 4B 51 26
  0000:1C23  db 8B 04 E8 70 F3 89 07 83 C6 02 83 EB 02 E2 F0 59
  0000:1C33  db 89 0F 83 EB 12 C7 47 0E FF 7F C7 47 10 00 00 C7
  0000:1C43  db 47 0A FF 7F C7 47 0C 00 00 C7 47 06 FF 7F C7 47
  0000:1C53  db 08 00 00 C7 47 02 FF 7F C7 47 04 00 00 C7 07 47
  0000:1C63  db 47 89 5D 0C E8 3B F3 33 C0 5E 59 5B C3

; dmform_loadElementTriple8 + dmform_layoutElements (0000:1C6E..1D46)
  0000:1C6E  db 1E 06 8B
  0000:1C73  db 7E 00 8E 5E 02 8B 76 04 8E 46 06 E8 03 00 07 1F
  0000:1C83  db C3
  0000:1C84  db 55 83 EC 08 8B EC
  0000:1C8A  db 53 51 56 57
  0000:1C8E  db 89 7E 00 89 76 04 2B C0 89 46 06 8B 5D 08 4B D1
  0000:1C9E  db E3 8B 4D 0E 89 4E 02 8B F9 03 DF 8B 05 D1 E0 D1
  0000:1CAE  db E0 2D 02 00 03 F8 8B 76 04 8B 0D 57 8B 7E 00 E8
  0000:1CBE  db 34 F1 5F 3D 01 00 75 1D 8B 46 06 D1 E0 05 14 00
  0000:1CCE  db 57 8B 7E 00 E8 33 F0 5F 3D FF FF 74 68 89 0F 83
  0000:1CDE  db EB 02 FF 46 06 83 EF 04 3B 7E 02 7F CC 8B 46 06
  0000:1CEE  db 89 07 83 EB 12 8B 76 04 26 8B 44 0C 89 47 0E C7
  0000:1CFE  db 47 10 00 00 26 8B 44 08 89 47 0A C7 47 0C 00 00
  0000:1D0E  db 26 8B 44 04 89 47 06 C7 47 08 00 00 26 8B 04 89
  0000:1D1E  db 47 02 C7 47 04 00 00 C7 07 47 47 8B 7E 00 89 5D
  0000:1D2E  db 0C 8B 46 06 3D 00 00 75 07 C7 45 0C 00 00 EB 05
  0000:1D3E  db 50 E8 63 F2
  0000:1D42  db 58 5F 5E 59 5B
  0000:1D47  db 83 C4 08 5D C3

; dmform_loadElementTriple9 + dmform_drawAllElements (0000:1D4C..1DD8)
  0000:1D4C  db 1E 06 8B 7E 00 8E 5E 02 8B 76 04
  0000:1D57  db 8E 46 06 83 7D 0C 00 B8 FF FF 74 6D 80 7D 01 00
  0000:1D67  db 74 64 55 83 EC 08 8B EC 8B 5D 0C 8B 4F 02 8B 57
  0000:1D77  db 0A 89 4E 00 89 56 04 8B 4F 06 8B 57 0E 89 4E 02
  0000:1D87  db 89 56 06 E8 1F EE E8 43 00 8B F5 16 56 1E 57 B8
  0000:1D97  db 1E 21 E8 82 E2 83 C4 08 8B 5D 0C 8B 47 02 89 46
  0000:1DA7  db 00 8B 47 0A 89 46 04 8B 47 06 89 46 02 8B 47 0E
  0000:1DB7  db 89 46 06 16 56 1E 57 B8 1E 21 E8 5A E2 83 C4 08
  0000:1DC7  db 83 C4 08 5D EB 03 E8 03 00 07 1F C3

; dmform_transformCoordinates (0000:1DD9..208C)
; Complex coordinate transformation for form scrolling/scaling.
; Compares source/dest rectangles and applies linear transform.
  0000:1DD9  db 55 83 EC 36 8B EC
  0000:1DDF  db 53 51 52 56 57
; ... (scaling/scrolling coordinate transform)
  0000:2088  db 5F 5E 5A 59 5B
  0000:208D  db 83 C4 36 5D C3

; dmform_loadElementTriple10 + dmform_refreshElements (0000:2092..2160)
  0000:2092  db 1E 06 8B 7E 00 8E 5E 02 8B 76 04
  0000:209D  db 8E 46 06 E8 03 00 07 1F C3
  0000:20A6  db 55 83 EC 06 8B EC
  0000:20AC  db 53 51 52 56
; ... (refresh logic)
  0000:215B  db 5E 5A 59 5B
  0000:215F  db 83 C4 06 5D C3

; dmform_drawElementBounds (0000:2161..2166)
  0000:2161  db 1E 8B 7E 00 8E 5E 02

; dmform_validateAndDraw (0000:2167..2229)
; Validate state, iterate elements, call host 0x2120 draw.
  0000:2167  db 83 7D 0C 00
  0000:216F  db B8 FF FF 75 05 B8 FF FF EB 45 80 7D 01 00 74 3C
; ...
  0000:21BF  db C3 E8 B1 DE E8 D2 ED E8 9A E0 C7 45 0C 00 00 C3
  0000:21CF  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3
  0000:21DB  db 53 51 56 8B 5D 0C 83 C3 12 8B 0F D1 E1 83 C3 02 2B F6 8B 00
  0000:21EF  db E8 55 F7 83 C6 02 3B F1 7C F4 5E 59 5B C3
  0000:21FF  db 1E 8B 7E 00 8E 5E 02 E8 02 00 1F C3
  0000:220B  db 53 56 8B 5D 0C 83 C3 12 8B 37 D1 E6 8B 00 E8 62 F7
  0000:221F  db 83 EE 02 83 FE 00 7F F3 5E 5B C3

; dmform_loadElementTriple11 + dmform_drawFormRegion (0000:222A..22A1)
  0000:222A  db 1E 06 8B 7E 00 8E 5E 02 8B 76 04
  0000:2235  db 8E 46 06 83 7D 0C 00 B8 FF FF 74 45 80 7D 01
  0000:2244  db 00 74 3C 55 83 EC 08 8B EC 8B 5D 0C 8B 4F 02 8B
  0000:2254  db 57 0A 89 4E 00 89 56 04 8B 4F 06 8B 57 0E 89 4E
  0000:2264  db 02 89 56 06 E8 46 E9 E8 1B 00 8B F5 16 55 1E 57
  0000:2274  db B8 1E 21 E8 A9 DD 83 C4 08 83 C4 08 5D EB 03 E8
  0000:2284  db 03 00 07 1F C3
  0000:2289  db 53 51 8B 5D 0C 8B 4F 12 83 C3 14
  0000:2293  db 8B 07 E8 BE F7 83 C3 02 49 75 F5 59 5B C3

; dmform_loadElementTriple12 + dmform_copyFormData (0000:229F..2303)
  0000:229F  db 1E 06 8B 7E 00 8E 5E 02 8B 76 04 8E 46 06 E8 03 00 07 1F C3
  0000:22B1  db 53 51 52 56 57
; ... (block copy between form buffers)
  0000:22FF  db 5F 5E 5A 59 5B C3

; dmform_clearFormData + remaining (0000:2304..239F)
  0000:2304  db C3 53 8B 5D 10 C7 07 00 00 5B C3
  0000:230E  db 1E 8B 7E 00 8E 5E 02 8B 56 02 8B 46 04 E8 08 00 3D FF FF 75 01
  0000:2324  db 99 1F C3 53 51 57 8B 7D 10 2B C9 8B D9 03 D9 8B
  0000:2334  db 49 02 3B C1 74 0C 8B 09 83 F9 00 75 F0 B8 FF FF
  0000:2344  db EB 04 8B C3 03 C7 5F 59 5B C3
  0000:234E  db 1E 8B 7E 00 8E 5E 02 8B 46 04 E8 02 00 1F C3
  0000:235C  db 53 51 57 E8 C4 FF 3D FF FF 74 1D 8B D8 8B 4D 10 2B C1 03 07 8B 4D 04
  0000:2374  db 2B C8 8B FB 8B F3 03 37 9C FC 06 1E 07 F3 A4 07
  0000:2384  db 9D 5F 59 5B C3
  0000:2389  db 53 51 57 83 7D 04 00 74 19 8B 7D
  0000:2394  db 10 2B C9 8B D9 03 D9 80 61 02 7F 8B

; ========================================================================
; SEGMENT seg_023A  (96 bytes, file 0x25A0-0x2600)
; Jump table and dispatch data for DMFORM form engine.
; Contains function offset table indexed by form API function numbers.
; ========================================================================
seg_023A:

  023A:0000  db 09 83 F9 00 75 F3 8B C3 05 02 00 5F 59 5B C3 EC ; continuation of seg_0000 code
  023A:0010  db 12 9D 22 AD 00 2E 15 DA 11 0C 09 91 03 B5 0A 0D ; function offset table (word pairs)
  023A:0020  db 05 70 1C D1 13
  023A:0025  db 64 21 4E 23                                     ; more offset table entries
  023A:0029  db CF 08 A2 17 92 20 35 19 67 19 F1 10 81 1B 0F 23 ; dispatch table entries
  023A:0039  db BC 19 FD 21 CF 21 68 00 E1 19 25 22 2C 16 4C 1D ; (offsets into seg_0000)
  023A:0049  db 30 10 95 06 3C 1B 4C 18 E2 1B 92 0F BB 34 12 00
  023A:0059  db 00 00 00 00 00 00 00                            ; padding/unused

; ========================================================================
; SEGMENT seg_0240  (125 bytes, file 0x2600-0x267D)
; Entry point, module name, registration thunks, and far-call dispatcher.
; ========================================================================
seg_0240:

; Module header data
  0240:0000  db 08 02 00 00                                     ; header flags
  0240:0004  db 44 4D 46 4F 52 4D                               ; "DMFORM" module name
  0240:000A  db 00                                                ; NUL terminator
  0240:000B  db 00 29 00 40 02 00 00 00 00 00 00 00 00 00 00 00 ; [RELOC->seg_0240]
  0240:001B  db 00 00 00 00 00 00 00 00 00 00 00 03 08 02

; Far-call dispatcher thunk (0240:0029..005A)
; Saves/restores caller's PSP via INT E0h AH=4Dh and dispatches
; to the appropriate form function via the jump table in seg_023A.
  0240:0029  db 51 50
  0240:002B  db 2E A0 02 00 3C FF 74 09 52 8A D0 B8 04 4D CD E0 ; check/save PSP
  0240:003B  db 5A 2E A2 03 00 58 9A 00 00 00 00                ; far call to seg_0000 [RELOC]
  0240:0046  db 50 2E A0 03 00
  0240:004B  db 3C FF 74 09 52 8A D0 B8 05 4D CD E0 5A 58 59 CB ; restore PSP + retf

; -----------------------------------------------------------------------
; entry_point  (0240:005B)
; RES module entry point - registers DMFORM with host and goes TSR.
;
; 1. Push CS, pop ES (set ES = CS)
; 2. Set up DM89 environment segment pointer at [bx+0x20]
; 3. Call INT E0h AH=01h to get host API version
; 4. Store version byte at CS:[0x02]
; 5. Calculate resident size = DS - host_seg
; 6. Call INT 21h AH=31h to go TSR
; -----------------------------------------------------------------------
entry_point:
  0240:005B  0e                push     cs
  0240:005C  07                pop      es               ; ES = CS
  0240:005D  b90000            mov      cx, 0            ; RELOC->seg_0000 (form code segment)
  0240:0060  bb0400            mov      bx, 4            ; offset into header
  0240:0063  268c5f20          mov      word ptr es:[bx + 0x20], ds  ; save DS in header
  0240:0067  b8f001            mov      ax, 0x1f0        ; INT E0h AH=01h: register RES
  0240:006A  cde0              int      0xe0             ; Call DeskMate host API
  0240:006C  2ea20200          mov      byte ptr cs:[2], al  ; save version byte
  0240:0070  8b160200          mov      dx, word ptr [2] ; DX = resident size (paragraphs)
  0240:0074  8cdb              mov      bx, ds           ; BX = DS segment
  0240:0076  2bd3              sub      dx, bx           ; DX = paragraphs to keep
  0240:0078  b80031            mov      ax, 0x3100       ; INT 21h/31h: TSR
  0240:007B  cd21              int      0x21             ; Terminate and Stay Resident
