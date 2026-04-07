; ========================================================================
; TUTKBD.RES -- Raw Data Analysis
; DeskMate 3.05, Tandy Corporation
; Generated for the Bayside reverse engineering project
; ========================================================================
;
; TUTKBD.RES is NOT an MZ executable. It is a compressed data resource
; containing tutorial keyboard mapping and bitmap data used by the
; PLAY.PDM "Teach Me!" tutorial system via DMPLAY.RES.
;
; File size: 1931 bytes (0x078B)
; Format: DeskMate packed data file (loaded via DMUNPACK.RES)
;
; DMPLAY.RES references this file at data offset 059C:3B54 as the
; string ":TUTKBD.RES" (colon prefix indicates a DeskMate resource
; path). PLAY.PDM imports "unpack" (DMUNPACK.RES) to decompress it.
;
; When decompressed, the data expands to approximately 3235 bytes
; (0x0CA3) of tutorial keyboard layout data, containing:
;   - Key-to-note mapping tables (ASCII key -> musical note/position)
;   - Keyboard bitmap graphics (2bpp or 4bpp piano keyboard image)
;   - Screen coordinate data for key label positioning
;
; ========================================================================

; ========================================================================
; FILE HEADER (0x0000 - 0x0017, 24 bytes)
; ========================================================================
;
; This is a DeskMate packed resource header, not an MZ header.
; The format is used for data-only resources loaded by DMUNPACK.RES.
;
;   Offset  Size  Value       Description
;   ------  ----  -----       -----------
;   0x0000  1     0x01        Type/version byte (packed data resource)
;   0x0001  11    "TUTKBD.RES\0"  Embedded filename (NUL-terminated)
;   0x000C  2     0x0000      Reserved / flags
;   0x000E  2     0x0CA3      Uncompressed data size (3235 bytes)
;   0x0010  4     0x00000000  Reserved
;   0x0014  2     0x0000      Reserved
;   0x0016  2     0x7000      Load segment hint or flags
;   ------  ----  -----       -----------
;   Total: 24 bytes (0x18)
;

  0000:0000  01                     db   0x01              ; type = packed data resource
  0000:0001  54 55 54 4B 42 44 2E   db   "TUTKBD."        ; filename part 1
  0000:0008  52 45 53 00            db   "RES", 0          ; filename part 2 + NUL
  0000:000C  00 00                  dw   0x0000            ; reserved/flags
  0000:000E  A3 0C                  dw   0x0CA3            ; uncompressed size = 3235
  0000:0010  00 00 00 00            dd   0x00000000        ; reserved
  0000:0014  00 00                  dw   0x0000            ; reserved
  0000:0016  00 70                  dw   0x7000            ; load hint / flags

; ========================================================================
; COMPRESSED DATA BODY (0x0018 - 0x078A, 1907 bytes)
; ========================================================================
;
; The body contains DMUNPACK-compressed data. The compression algorithm
; used by DMUNPACK.RES is a simple LZ-style scheme (likely LZSS or
; similar run-length/dictionary hybrid common in late-1980s DOS software).
;
; Compression ratio: 1907 / 3235 = 58.9%
;
; The decompressed data contains tutorial keyboard layout information
; used by DMPLAY.RES to render the on-screen piano keyboard in PLAY.PDM's
; "Teach Me!" mode. Based on the uncompressed data visible in DMPLAY.RES
; at offset 059C:3BA0 onwards (which contains similar keyboard data in
; uncompressed form), the decompressed content includes:
;
; 1. KEY MAPPING TABLE
;    Pairs of (ASCII_char, coordinate/note_index) mapping PC keyboard
;    keys to piano keys:
;      '1' -> note position, '3' -> note, '4' -> note, '5' -> note,
;      '7' -> note, '9' -> note, '0' -> note, '8' -> note, '=' -> note,
;      'a'-'z' -> note positions (white keys),
;      '[', '\', ']', '`' -> additional keys,
;      ';', ',', '.', '/' -> additional keys
;    The coordinate bytes encode (column, row) screen positions for
;    highlighting the corresponding piano key in the on-screen display.
;
; 2. KEYBOARD BITMAP DATA
;    A small bitmap image of a piano keyboard rendered in 2bpp or 4bpp
;    format for the Tandy graphics modes (320x200x16 or 640x200x4).
;    Recognizable by the repeating AA/FF/BF/EA byte patterns typical
;    of 2-bit-per-pixel graphics with a limited palette (black, white,
;    and two highlight colors for key states).
;
; 3. SCREEN LAYOUT PARAMETERS
;    Dimensions, offsets, and spacing values for positioning the
;    keyboard graphic and note labels within the PLAY.PDM window.
;
; Raw hex dump of compressed body follows:
;

  ; --- Compressed data bytes 0x0018-0x003F ---
  0000:0018  07 00 00 D0 74 BA BD 3C  66 0E DB 69 7B 7F F5 B9
  0000:0028  B9 BF DC E7 72 2C B2 DC  6D B5 F5 B4 B9 2C 75 01
  0000:0038  A8 FF 18 03 A5 2B 79 A7

  ; --- Compressed data bytes 0x0040-0x007F ---
  0000:0040  1D 9D F6 62 BA 80 B4 7C  C8 59 A3 3C DC BA 29 C8
  0000:0050  C7 BA 0C B8 5C B7 23 06  F9 9A F6 EE 73 0B 26 E8
  0000:0060  B1 B2 8E A2 CE 55 D7 5A  CB 3D 26 0C BB DB 60 9E
  0000:0070  79 6A A4 1D 58 F9 A7 21  56 6D C5 55 9C 70 95 67

  ; --- Compressed data bytes 0x0080-0x00BF ---
  0000:0080  5F FE BC F3 F8 57 9F 3D  75 E2 97 AA 9A 12 12 AE
  0000:0090  88 BF 55 D1 97 88 B4 86  74 56 03 F6 6D 30 F8 9B
  0000:00A0  4E 3C E8 D4 0E DA 35 22  A9 7A A1 D1 46 AC 70 FF
  0000:00B0  AC 1C 74 6B 41 5F EB 86  F7 BA F1 B1 EE C0 24 74

  ; --- Compressed data bytes 0x00C0-0x00FF ---
  0000:00C0  BC 32 FB 64 22 BD B3 16  D9 4F F0 FB E6 DA 8D E9
  0000:00D0  3C 00 DF D1 EE 2A BE 5F  02 6F FC D0 B1 FF 7D 09
  0000:00E0  3D 5F 62 4F AB F0 49 74  62 2F FD 4F 89 6F AB FA
  0000:00F0  4F F9 01 45 7F 20 6F F3  F2 0A C1 F0 71 45 B8 42

  ; --- Compressed data bytes 0x0100-0x013F ---
  0000:0100  53 DC 21 69 D6 50 D4 DB  33 B7 97 2F 14 B3 48 9A
  0000:0110  79 A4 55 61 E2 2E 83 70  09 44 63 36 AC 64 A7 9A
  0000:0120  DB 90 0F 56 BD 15 17 FC  E9 A7 60 F1 22 50 3C A8
  0000:0130  54 77 28 62 85 CE 87 4C  7C 06 AA 0F 86 0A 75 E0

  ; --- Compressed data bytes 0x0140-0x017F ---
  0000:0140  39 7D 7C 70 2C EB DB D5  2D F3 95 25 EB 54 FE 0E
  0000:0150  5A FD 81 FA E0 40 FF 7B  91 5A 5F 64 40 A9 2E 52
  0000:0160  56 3B 29 3B 39 94 B5 C3  D7 92 F1 B3 B8 0B 1F A2
  0000:0170  1E C6 E8 F5 AC D3 3E BD  22 65 51 48 1B 54 D4 5B

  ; --- Compressed data bytes 0x0180-0x01BF ---
  0000:0180  C0 0A 9F 95 03 44 E5 05  57 A6 79 69 83 07 17 E7
  0000:0190  64 4D CA B0 5D 44 71 17  D0 3E 3F 35 C4 27 09 51
  0000:01A0  92 0C A8 89 06 D6 84 E8  97 2E 9F 3D D8 A7 ED 5A
  0000:01B0  15 25 60 D7 F2 55 A8 7C  B5 FA 1F D5 C4 A9 94 D7

  ; --- Compressed data bytes 0x01C0-0x01FF ---
  0000:01C0  85 14 29 DE 59 AB 1C 68  D4 8D A4 AC 1A F7 DD B7
  0000:01D0  EE 9B 4E AF 0D 25 C1 E5  E0 0E 04 F7 FA 26 82 44
  0000:01E0  09 92 72 3F 73 F1 C4 7F  ED 71 E0 F0 3C 1E 58 06
  0000:01F0  68 27 5E D8 16 9D 0E EA  03 D2 DD 81 F9 01 3C 82

  ; --- Compressed data bytes 0x0200-0x023F ---
  0000:0200  C7 E9 44 09 D0 80 EA D9  08 4F 55 BB E5 C1 38 90
  0000:0210  39 54 26 90 FA FE 30 64  4E 5B 8C 6F 89 FF 5C 30
  0000:0220  1F D5 49 3A 0F E8 CE 67  62 B9 18 D1 59 50 99 D9
  0000:0230  A5 38 90 9D 9C 2B B7 B0  A0 AC 8B 07 EC F2 AD 98

  ; --- Compressed data bytes 0x0240-0x027F ---
  0000:0240  4D B8 1D B0 4D B0 FC 21  38 43 F0 44 EA F1 F8 92
  0000:0250  02 3F 83 41 F5 70 FC 60  98 C3 F1 02 62 8F D4 13
  0000:0260  AA 3F 4C 4E C0 FE B4 D0  FE 04 E2 8B 64 0F 46 6A
  0000:0270  A4 D9 1F B3 7B 8F F6 09  EC 07 60 26 FC 3E DF EE

  ; --- Compressed data bytes 0x0280-0x02BF ---
  0000:0280  3F D8 4F 86 DD 61 B4 27  D1 2B B4 EF 7F 9F 01 2B
  0000:0290  D8 0E E5 79 45 D0 7B 8D  1B 40 9E E0 7D 02 7A F9
  0000:02A0  C4 1E 68 27 BB 01 0F A8  9C 70 7E EE 01 57 F9 0F
  0000:02B0  4D BD 17 FF 8D FF 09 9C  87 F8 27 F0 FD 02 74 0F

  ; --- Compressed data bytes 0x02C0-0x02FF ---
  0000:02C0  FE 13 98 BF 6B 80 3F F3  2B 3F 48 1D D1 D8 CA E3
  0000:02D0  25 1F A8 26 A0 39 42 61  39 74 9C 7E A1 3F B1 03
  0000:02E0  F3 09 CF C7 ED 7A 5D 5A  C0 F5 B4 B4 B1 11 FD C2
  0000:02F0  77 03 98 26 71 FD C4 FC  1F 9C 4E 81 FB 8F DB B7

  ; --- Compressed data bytes 0x0300-0x033F ---
  0000:0300  D1 2C AF 80 76 0F 46 7F  DE 4C 27 C0 3A 18 4D 60
  0000:0310  98 0E D3 AB 3F E0 1E D8  26 FB D5 CD F0 27 C0 3F
  0000:0320  70 4D C5 55 47 C0 9F 00  E4 42 74 65 C6 FD 09 F4
  0000:0330  0E 5C 8F B5 40 13 E8 1E  E9 1F 41 B3 5F E9 1F D0

  ; --- Compressed data bytes 0x0340-0x037F ---
  0000:0340  3D D2 3E 33 B2 B3 12 3C  40 EA 23 CC B2 F5 6C A1
  0000:0350  C4 27 23 98 70 3C E8 E2  E7 2E 0F F4 5C 83 10 39
  0000:0360  E6 E4 18 92 72 B7 40 C4  26 20 7E 01 36 73 68 19
  0000:0370  04 C8 0E 18 4D 33 68 1F  77 61 32 03 86 3B 75 65

  ; --- Compressed data bytes 0x0380-0x03BF ---
  0000:0380  09 90 1C 50 9B 5B 68 B9  04 C8 0E 39 1E 99 ED 55
  0000:0390  90 4C 80 F2 91 E5 C7 C6  E6 13 80 3C A5 19 E9 F4
  0000:03A0  2E 0A 38 03 CE 47 9B E5  09 C0 1E 42 72 BA 38 3E
  0000:03B0  DC E0 B7 F1 FA 62 65 C9  95 97 40 1F E3 07 D7 00

  ; --- Compressed data bytes 0x03C0-0x03FF ---
  0000:03C0  77 9F 4B EB 43 41 33 79  03 EB 80 3E 61 39 69 72
  0000:03D0  13 96 B7 98 9F BF A4 27  20 7C C2 7C D0 50 F2 13
  0000:03E0  90 3E 81 39 69 72 51 CB  5B F0 8F 3E 41 33 92 DE
  0000:03F0  40 FE 94 72 D2 F0 27 8D  6F D2 3F 1A 5E 0E F1 AD

  ; --- Compressed data bytes 0x0400-0x043F ---
  0000:0400  FC 47 AE 82 BF C0 9E 01  FF 28 F1 A5 E1 1F 8D 6C
  0000:0410  45 1B 48 09 9E 11 F8 07  89 47 67 56 9E 42 69 F0
  0000:0420  43 BA A0 F5 97 35 00 37  7F 82 42 F0 0E 0A DF 69
  0000:0430  06 1F F0 4F 80 E1 AF 34  9C 61 5F 04 F8 0E E1 38

  ; --- Compressed data bytes 0x0440-0x047F ---
  0000:0440  3C 84 F8 0E E0 9E 23 43  FE 09 F0 1D C1 35 9B 35
  0000:0450  FE B2 FE 03 BC 8F 37 DA  21 F5 A1 F0 1E 85 19 84
  0000:0460  CD 7F 82 7C 07 A1 1E 97  EC 27 C0 7A 11 EB 8C AA
  0000:0470  F8 27 C0 7A 94 69 7B 25  7C 51 F0 1E C5 1F F8 C4

  ; --- Compressed data bytes 0x0480-0x04BF ---
  0000:0480  5F 11 FC 07 FD 74 FF 2A  3B 60 2F 87 65 0C DD C7
  0000:0490  3B A7 33 98 1F F4 34 F3  F0 1E BA F3 F6 A2 75 27
  0000:04A0  C1 3F 03 D8 26 50 C0 4F  C0 ED 13 D7 E9 19 C2 A7
  0000:04B0  F0 9A 22 28 5E 62 7F D3  B8 93 AD 42 AB FA 27 F0

  ; --- Compressed data bytes 0x04C0-0x04FF ---
  0000:04C0  3E 32 01 FF B8 B3 F2 4A  7F 03 D8 93 3C 26 CC FC
  0000:04D0  A7 20 78 09 35 82 C0 9C  2C 93 75 24 CD 31 FA F3
  0000:04E0  23 64 D3 20 7A 8F CD EF  92 FC DE 9D 42 60 B2 DA
  0000:04F0  C8 4C 81 EC 73 DE 25 B3  92 9F EF 4D 21 C3 9C FB

  ; --- Compressed data bytes 0x0500-0x053F ---
  0000:0500  4F 43 29 9D CA 4A FC 64  0F E3 D6 7F F9 A1 1F F9
  0000:0510  12 AF 7A FE F4 97 64 2F  A7 CA 08 41 70 2E 68 CC
  0000:0520  8B D1 D8 6A C1 7E CD 2B  84 85 F5 09 E8 82 F9 E5
  0000:0530  EC 4D 3B A1 35 BF 84 37  89 92 3E 19 A7 7E 00 97

  ; --- Compressed data bytes 0x0540-0x057F ---
  0000:0540  7C E8 BD F8 65 2F 79 D2  A6 65 28 02 5A 97 FD CE
  0000:0550  12 FF FC 92 7D AC C0 9F  33 F6 99 6F AE 38 A7 46
  0000:0560  E2 BD 4C B9 6C B7 37 77  C8 DE DC 74 6C DC FD 3E
  0000:0570  BD 8C B2 27 E3 DB 8B DF  8B 6C 0D 30 5C BD FF 65

  ; --- Compressed data bytes 0x0580-0x05BF ---
  0000:0580  A9 B3 9E 5A 21 CE 43 F3  0D B3 0D B1 37 F7 3B 4B
  0000:0590  82 7F 0F F9 84 F2 CB 5F  C2 E0 2D 37 4E 23 A3 32
  0000:05A0  5C 4D 28 A0 DB 14 F7 30  E1 B1 24 C7 56 47 59 CF
  0000:05B0  34 F2 E8 75 F9 CF F5 9B  AE BD 64 5C 73 CB 61 61

  ; --- Compressed data bytes 0x05C0-0x05FF ---
  0000:05C0  CD 60 0F A6 0B D7 66 03  41 71 AC CE 83 26 01 30
  0000:05D0  07 CC 49 B3 0A 80 4F D5  2C F3 7D A9 F1 D8 F1 E0
  0000:05E0  07 83 E3 B8 FD 80 9C 59  63 AF 79 00 9A 4B 9F 4F
  0000:05F0  CC 4C 27 11 1A F5 7E F6  4C C5 DD 20 0F B7 67 1B

  ; --- Compressed data bytes 0x0600-0x063F ---
  0000:0600  B6 81 3F BF 6B B8 2C F0  0B 00 70 1B 04 7C 6E 43
  0000:0610  65 48 ED 05 09 28 01 F5  33 6D 6B 03 B8 25 83 72
  0000:0620  7D B6 8F FD 4D 97 FE 53  E2 C8 1C 8E F9 0B 59 A6
  0000:0630  10 84 FC A8 1B 2B B8 90  4F 27 B6 C7 F3 EB 4A ED

  ; --- Compressed data bytes 0x0640-0x067F ---
  0000:0640  82 07 7B B7 C5 20 0E F8  FB AB 49 C1 57 AF 7C 20
  0000:0650  7B 39 9D 2F 16 B4 DB BD  8E BA 48 88 7C 99 D7 E7
  0000:0660  97 31 1F DC F0 DA D3 BB  9D 52 FF D6 B6 26 97 8B
  0000:0670  F2 FF DD 77 DD 3E 52 DB  3A 5B B8 16 9F 7F 27 B0

  ; --- Compressed data bytes 0x0680-0x06BF ---
  0000:0680  F6 1B CA 57 44 D0 CA 5B  7B 7A 86 A5 55 B4 AD 9E
  0000:0690  F9 0C EA BD 20 FB EC 36  73 CA 02 FE D0 34 B8 B2
  0000:06A0  7F AB 24 87 89 7B EF 39  22 F9 8B CF D1 A3 07 CC
  0000:06B0  0F 2B 9F A9 AE BA 9B 5A  6E FB 86 D5 FB 02 1F 56

  ; --- Compressed data bytes 0x06C0-0x06FF ---
  0000:06C0  87 26 B0 DD 8D 95 92 51  7F 8D A7 54 B1 96 D2 90
  0000:06D0  BF 6C 7A F7 65 42 35 FE  A6 83 FD AB DC C0 E3 5D
  0000:06E0  79 20 17 B8 59 B0 87 4E  7E 3A 8B 2E FC B0 76 62
  0000:06F0  FF 57 4E 1C 9B 3C E7 02  45 73 4F 5E 7B ED 6A E5

  ; --- Compressed data bytes 0x0700-0x073F ---
  0000:0700  1B D5 6D 7A D7 9D CE C6  78 5F 45 21 AF 47 E8 93
  0000:0710  A9 6A 5C 13 92 CF 76 B8  06 92 93 32 0B F4 91 D0
  0000:0720  BC C2 4C 47 9D 12 15 DD  D2 16 12 A4 95 9B 24 A6
  0000:0730  83 9E 7A F9 95 9D 32 FE  26 95 D7 B5 93 5F 90 6A

  ; --- Compressed data bytes 0x0740-0x077F ---
  0000:0740  9F 49 C4 3D D5 DD 63 EC  BB FB 16 8A 0A 8B 06 43
  0000:0750  22 94 02 F0 FA 80 4F CE  2C BE 72 FF 24 73 69 D9
  0000:0760  D2 3A FB 7D FC E9 34 9E  D7 1A 7B 35 DE F3 54 66
  0000:0770  A2 D6 2B D7 34 5E 83 36  5A BF AB E7 76 1E DB 3A

  ; --- Compressed data bytes 0x0780-0x078A (final 11 bytes) ---
  0000:0780  4A FD 89 8F 5B D3 EB 83  EB B0 00

; ========================================================================
; END OF FILE
; ========================================================================
; Total: 1931 bytes
;   Header:          24 bytes (0x0000-0x0017)
;   Compressed body: 1907 bytes (0x0018-0x078A)
;   Uncompressed:    3235 bytes (0x0CA3) estimated
; ========================================================================
