; ========================================================================
; TUTKBD.RES -- Fully Annotated Data Analysis
; DeskMate 3.05, Tandy Corporation
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; TUTKBD.RES is the tutorial keyboard data resource for DeskMate 3.05's
; PLAY.PDM application ("Teach Me!" mode). Unlike all other .RES files,
; this is NOT an MZ executable -- it is a pure compressed data file
; loaded and decompressed at runtime by DMUNPACK.RES.
;
; The file is referenced by DMPLAY.RES (the sound/tutorial playback
; engine) at data offset 059C:3B54, stored as the path ":TUTKBD.RES".
; The colon prefix is a DeskMate convention indicating a resource in the
; DeskMate installation directory. PLAY.PDM imports both "dmplay" and
; "unpack" to access this data.
;
; When decompressed, the data provides:
;   1. A mapping from PC keyboard keys to musical notes/piano positions
;   2. A bitmap image of a piano keyboard for on-screen rendering
;   3. Layout coordinates for positioning key labels in the UI
;
; This allows PLAY.PDM's tutorial mode to:
;   - Display a piano keyboard on screen
;   - Highlight keys as the user presses them
;   - Map QWERTY keyboard input to musical notes in real time
;   - Guide the user through lessons by showing which keys to press
;
; File size: 1931 bytes (0x078B)
; Uncompressed size: ~3235 bytes (0x0CA3)
; Compression ratio: ~59%
;
; ========================================================================

; ========================================================================
; STRUCTURE INDEX
; ========================================================================
;
; Address          Name                              Description
; -------          ----                              -----------
; 0000:0000        tutkbd_header                     Packed resource file header (24 bytes)
; 0000:0018        tutkbd_compressedBody             DMUNPACK-compressed tutorial data (1907 bytes)
;

; ========================================================================
; FILE HEADER
; ========================================================================
;
; The header identifies this as a DeskMate packed data resource.
; Format: type byte + filename + metadata fields.
;
; This format is distinct from the MZ+DM89 format used by executable
; .RES/.ACC/.PDM files. It appears to be specific to data resources
; that are loaded via DMUNPACK.RES's decompression routines.
;

tutkbd_header:

  ; --- Type byte ---
  ; 0x01 indicates a packed data resource (as opposed to MZ 0x4D5A)
  0000:0000  01                     db   0x01              ; tutkbd_type: packed data resource

  ; --- Embedded filename ---
  ; The resource's own filename, NUL-terminated. Used by the loader
  ; to verify the correct file has been opened. 10 chars + NUL = 11 bytes.
  0000:0001  54 55 54 4B 42 44 2E   db   "TUTKBD."        ; tutkbd_filename (part 1)
  0000:0008  52 45 53 00            db   "RES", 0          ; tutkbd_filename (part 2 + NUL)

  ; --- Reserved / flags ---
  ; Purpose unclear; zero in this file. May indicate sub-type or
  ; compression method in other packed resources.
  0000:000C  00 00                  dw   0x0000            ; tutkbd_flags: 0 (no special flags)

  ; --- Uncompressed data size ---
  ; The size of the data after DMUNPACK decompression.
  ; 0x0CA3 = 3235 bytes. This tells the loader how much memory to
  ; allocate (via INT 21h/48h) before decompressing.
  0000:000E  A3 0C                  dw   0x0CA3            ; tutkbd_uncompressedSize: 3235 bytes

  ; --- Reserved fields ---
  ; Six bytes of zeros. May be reserved for future use or may encode
  ; additional metadata in other packed resource files.
  0000:0010  00 00 00 00            dd   0x00000000        ; tutkbd_reserved1: 0
  0000:0014  00 00                  dw   0x0000            ; tutkbd_reserved2: 0

  ; --- Load hint / segment hint ---
  ; 0x7000 may indicate a preferred load segment or memory region.
  ; In the DeskMate memory map, segment 0x7000 would be at physical
  ; address 0x70000 (448KB), near the top of conventional memory in
  ; a 512KB system. This could be a hint to the loader about where
  ; to place the decompressed data, or it may be a flags field.
  0000:0016  00 70                  dw   0x7000            ; tutkbd_loadHint: segment 0x7000 (?)


; ========================================================================
; COMPRESSED DATA BODY
; ========================================================================
;
; 1907 bytes of DMUNPACK-compressed data starting at offset 0x18.
;
; The compression algorithm used by DMUNPACK.RES is believed to be an
; LZSS variant (Lempel-Ziv-Storer-Szymanski), which was widely used in
; late-1980s DOS software for its simplicity and low memory requirements.
; The 59% compression ratio is consistent with LZSS applied to bitmap
; data with moderate redundancy.
;
; When decompressed, the ~3235 bytes contain three logical sections
; (boundaries estimated from the analogous uncompressed data visible
; in DMPLAY.RES at offset 059C:3BA0):
;
; SECTION 1: KEY-TO-NOTE MAPPING TABLE (~200 bytes)
;   Format: pairs of (ASCII_keycode, note_descriptor) where each
;   note_descriptor encodes the musical note index and/or screen
;   coordinate for the corresponding piano key.
;
;   Known mappings (from DMPLAY.RES uncompressed reference data):
;     Number row (black keys / sharps):
;       '1' -> C#, '3' -> D#, '4' -> F#, '5' -> G#, '7' -> A#
;       '9' -> C#(+1), '0' -> D#(+1), '8' -> F#(+1), '=' -> G#(+1)
;     Letter rows (white keys / naturals):
;       'a' -> C, 'b' -> D, 'c' -> E, 'd' -> F, 'e' -> G,
;       'f' -> A, 'g' -> B, 'h' -> C(+1), ... through 'z'
;     Special keys:
;       '[', '\', ']', '`' -> additional notes
;       ';', ',', '.', '/' -> additional notes
;
;   Each entry also includes a screen coordinate byte pair encoding
;   the (column, row) position on the on-screen keyboard graphic
;   where the corresponding key should be highlighted.
;
; SECTION 2: KEYBOARD BITMAP DATA (~2800 bytes)
;   A bitmap image of a two-octave piano keyboard rendered in 2bpp
;   (2 bits per pixel) format compatible with Tandy TGA 320x200x16
;   and CGA 320x200x4 modes.
;
;   The bitmap uses a limited palette:
;     Color 0 (00) = black (black keys, outlines)
;     Color 1 (01) = dark (key shadows)
;     Color 2 (10) = medium (white key faces -- value 0xAA pattern)
;     Color 3 (11) = bright (highlights, active key -- value 0xFF pattern)
;
;   The repeating 0xAA bytes (binary 10101010) produce a solid fill
;   of color 2, while 0xFF bytes (binary 11111111) produce color 3.
;   Mixed patterns like 0xBF (10111111) show a color 2 pixel followed
;   by three color 3 pixels, used for key edges and transitions.
;
; SECTION 3: LAYOUT PARAMETERS (~50 bytes)
;   Screen positioning data including:
;     - Keyboard graphic X,Y origin within the PLAY.PDM window
;     - Key width and height in pixels
;     - Spacing between octaves
;     - Text label positions for note names (C, D, E, F, G, A, B)
;

tutkbd_compressedBody:

  ; First bytes of compressed stream.
  ; The decompressor (DMUNPACK.RES) reads control bytes to determine
  ; whether the following data is a literal run or a back-reference
  ; to previously decompressed output.
  0000:0018  07 00 00 D0 74 BA BD 3C  66 0E DB 69 7B 7F F5 B9
  0000:0028  B9 BF DC E7 72 2C B2 DC  6D B5 F5 B4 B9 2C 75 01
  0000:0038  A8 FF 18 03 A5 2B 79 A7  1D 9D F6 62 BA 80 B4 7C
  0000:0048  C8 59 A3 3C DC BA 29 C8  C7 BA 0C B8 5C B7 23 06
  0000:0058  F9 9A F6 EE 73 0B 26 E8  B1 B2 8E A2 CE 55 D7 5A
  0000:0068  CB 3D 26 0C BB DB 60 9E  79 6A A4 1D 58 F9 A7 21
  0000:0078  56 6D C5 55 9C 70 95 67  5F FE BC F3 F8 57 9F 3D

  ; ... (compressed data continues for 1907 bytes total) ...
  ; See raw disassembly (disassembly/raw/res/tutkbd.asm) for complete hex dump.

  ; Final bytes of compressed stream:
  0000:0780  4A FD 89 8F 5B D3 EB 83  EB B0 00

; ========================================================================
; END OF FILE
; ========================================================================
;
; Summary:
;   File type:        Packed data resource (not executable)
;   Total size:       1931 bytes
;   Header:           24 bytes (0x0000-0x0017)
;   Compressed body:  1907 bytes (0x0018-0x078A)
;   Uncompressed:     ~3235 bytes
;   Compression:      LZSS variant via DMUNPACK.RES
;   Referenced by:    DMPLAY.RES at 059C:3B54 (":TUTKBD.RES")
;   Used by:          PLAY.PDM "Teach Me!" tutorial mode
;   Contains:         Keyboard mapping table, piano bitmap, layout params
;
; Related files:
;   PLAY.PDM      -- Tutorial music application (imports dmplay, unpack)
;   DMPLAY.RES    -- Playback/tutorial engine (references TUTKBD.RES)
;   DMUNPACK.RES  -- Decompression library (unpacks TUTKBD.RES body)
;   DMMDS.RES     -- SN76496 music driver (plays notes from mappings)
;   DMMDP.RES     -- PC Speaker music driver (fallback)
;
; ========================================================================
