; ========================================================================
; DMEFORM.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMEFORM.RES is the Extended Form Engine for DeskMate 3.05.
; It provides an advanced form layout and rendering system used by
; applications like Filer (FILER.PDM) and Form Set (FORMSET.PDM)
; to display and edit structured data entry forms.
;
; The form engine handles:
;   - Form field definitions (text, numeric, date, checkbox)
;   - Field layout and positioning on screen
;   - Field validation and input masking
;   - Tab order navigation between fields
;   - Scroll views for forms larger than the window
;   - Data binding between form fields and record buffers
;   - Form printing via the print driver subsystem
;
; DM89 imports: DMCSR (cursor/screen driver)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 11,889 bytes
; Load image: 11,377 bytes (after header)
; DM89 entry point: 02BA:0086
; SS:SP = 02C8:0002
;
; Segment Map (5 segments, 7 relocations):
;   seg_0000  0x02B30 bytes  CODE   Form engine: field management,
;                                   layout calculation, rendering,
;                                   input handling, validation, scrolling
;   seg_02B3  0x00070 bytes  CODE   Additional code segment
;   seg_02BA  0x000E0 bytes  CODE   DM89 entry, registration, dispatch
;   seg_02C8  BSS                   Stack
;   seg_02C9  BSS                   Runtime form state
;
; ========================================================================
; FUNCTION INDEX (seg_0000 - Form Engine)
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmeform_initModule            Module initialization
; 0000:00B7   dmeform_createForm            Create new form instance
; 0000:00D9   dmeform_addField              Add field to form definition
; 0000:0188   dmeform_renderForm            Render entire form to screen
; 0000:0268   dmeform_handleInput           Handle keyboard input in form
; 0000:03BD   dmeform_validateField         Validate field value
; 0000:051E   dmeform_navigateField         Navigate to next/prev field (tab)
; 0000:05D9   dmeform_scrollView            Scroll form view
; 0000:062B   dmeform_updateField           Update field display after edit
; 0000:06C1   dmeform_getFieldValue         Get current value from field
; 0000:0786   dmeform_setFieldValue         Set value into field
; 0000:082D   dmeform_processFieldEvent     Process field-level event
; 0000:086E   dmeform_drawFieldFrame        Draw field border/frame
; 0000:093B   dmeform_calculateLayout       Calculate form layout geometry
; 0000:0AED   dmeform_printForm             Print form to printer
; 0000:0B7B   dmeform_formatFieldForPrint   Format field value for printing
; 0000:0BC6   dmeform_printFieldRow         Print one row of form fields
; 0000:0C2C   dmeform_handleResize          Handle form window resize
; 0000:0CBA   dmeform_destroyForm           Destroy form, free resources
; 0000:0DC1   dmeform_fieldLookup           Look up field by index or name
; 0000:0FD5   dmeform_complexFieldEdit      Complex field editing (date, etc.)
; 0000:1074   dmeform_fieldTypeHandler      Field-type-specific handler
; 0000:1250   dmeform_clipToViewport        Clip rendering to viewport
; 0000:132D   dmeform_scrollableRender      Render with scroll offset
; 0000:144D   dmeform_cursorTrack           Track cursor position in field
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; No direct hardware I/O -- uses DMCSR for all screen operations
; and DM89 host API for memory/event management.
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Form engine code (11,056 bytes)
; seg_02B3: Additional code (112 bytes)
; seg_02BA: DM89 entry (224 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmeform.asm for complete byte-level listing]
