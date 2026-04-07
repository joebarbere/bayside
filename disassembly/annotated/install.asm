; ========================================================================
; INSTALL.EXE -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Chain loader / bootstrap for DeskMate installer
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; INSTALL.EXE is a tiny chain-loader (828 bytes total, 316 bytes of code)
; that validates DESK.EXE contains a valid DM89 signature, then uses
; INT 21h/4Bh (EXEC, subfunction 01h = load overlay) to load DESK.EXE
; into memory. After loading, it patches the environment block to replace
; the "MOLDAPP.MOD" module reference with "INSTALL" so that DESK.EXE
; will launch INSTALL.PDM instead of DESKTOP.PDM on startup.
;
; Finally, it transfers control to DESK.EXE's entry point via a far
; return, with DS set from the child PSP segment.
;
; If any step fails (file not found, read error, invalid signature),
; it prints an error message and exits.
;
; This binary itself has a DM89 header (signature present in the MZ
; extended header area), making it recognizable by the DeskMate ecosystem.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 828 bytes
; Code size: 316 bytes (after header)
; Pages: 2
; Relocations: 2
; Entry point: 0000:000C
; SS:SP = 0018:0800
; Min alloc: 0x0079 paragraphs
; Max alloc: 0x0079 paragraphs
; DM89 signature: present
; DM89 raw: 444d38393c00000000000000000000000000000000000000000000000000000002b00
;
; Segment Map (3 segments):
;   seg_0000  0x00A0 bytes  CODE   Chain-loader logic
;   seg_000A  0x009C bytes  DATA   Strings, EXEC parameter block, read buffer
;   seg_0018  0x0800 bytes  STACK  Stack segment
;
; Relocation Table (2 entries):
;   000A:002B  -> seg_000A  (EXEC parameter block segment fixup)
;   0000:000D  -> seg_000A  (DS/ES segment load at entry)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; EXEC Parameter Block (seg_000A, offset 0x25):
;   [0x25] +00  word  0x000D   Environment segment (0 = inherit parent)
;   [0x27] +02  dword 0x000A:0025  Command-line pointer (seg:off)
;   [0x2B] +06  dword FCB1 pointer (RELOC -> seg_000A)
;   [0x2F] +0A  dword FCB2 pointer
;   [0x33] +0E  word  (unused)
;   [0x35] +10  word  SS value (filled by DOS on load)
;   [0x37] +12  word  SP value (filled by DOS on load)
;   [0x39] +14  word  CS value (filled by DOS on load)
;   [0x3B] +16  word  IP value (filled by DOS on load)
;
; MZ Header Read Buffer (seg_000A, offset 0x9C, 60 bytes):
;   After reading 0x3C bytes from DESK.EXE, the buffer maps:
;   [0x9C] +00  MZ header fields (signature, page count, etc.)
;   [0xB4] +18  e_lfanew / header_paragraphs (checked >= 0x25)
;   [0xB6] +1A  cs_entry (compared against saved value from data seg)
;   [0xB8] +1C  DM89 magic 'DM' (0x4D44)
;   [0xBA] +1E  DM89 magic '89' (0x3938)
;
; String Table:
;   seg_000A:0002  word 0x13  (unknown data byte)
;   seg_000A:0003  "DDESK.EXE"      Filename for DESK.EXE (with 'D' prefix)
;   seg_000A:0004  "DESK.EXE"       (offset +1 into the above -- actual open target)
;   seg_000A:0011  "MOLDAPP.MOD"    Module name to search for in environment
;   seg_000A:001D  "INSTALL"        Replacement module name
;   seg_000A:003D  "Please change to the drive containing the DESKMATE 1 disk\r\n
;                   before running install.\r\n$"
;   seg_000A:0093  "$$$$$$$$$"      Padding / sentinel
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Address   Name                     Size  Description
; -------   ----                     ----  -----------
; 0000:0000 install_printErrorExit     12  Print error message and exit
; 0000:000C install_entryPoint        148  Entry: validate DESK.EXE, EXEC, patch, jump
;
; ========================================================================
; INTERRUPT CALLS
; ========================================================================
;
; INT 21h/09h  Print string (DS:DX -> '$'-terminated string)
; INT 21h/3Dh  Open file (DS:DX -> filename, AL=0 read-only)
; INT 21h/3Fh  Read file (BX=handle, CX=count, DS:DX->buffer)
; INT 21h/3Eh  Close file (BX=handle)
; INT 21h/4Bh  EXEC (AL=01h load overlay; DS:DX->filename, ES:BX->param block)
; INT 21h/4Ch  Exit process (AL=return code)
; INT 21h/51h  Get PSP segment (returns BX=PSP segment)
;
; ========================================================================
; CODE / DATA
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (160 bytes, file 0x0200-0x02A0)
; CODE: Chain-loader logic
; ------------------------------------------------------------------------
seg_0000:

; ========================================================================
; install_printErrorExit
; Address: 0000:0000
; Parameters: none (uses DS:003D as error message)
; Returns: does not return (exits to DOS)
; Description: Prints the "Please change to the drive containing the
;   DESKMATE 1 disk" error message, then exits with return code 0.
;   All error paths in the loader jump here.
; ========================================================================
install_printErrorExit:                         ; 0000:0000
  0000:0000  ba3d00            mov      dx, 0x3d           ; DS:DX -> error message at seg_000A:003D
  0000:0003  b409              mov      ah, 9              ; INT 21h/09h: Print '$'-terminated string
  0000:0005  cd21              int      0x21
  0000:0007  b8004c            mov      ax, 0x4c00         ; INT 21h/4Ch: Exit with return code 0
  0000:000A  cd21              int      0x21

; ========================================================================
; install_entryPoint  (DM89 entry point)
; Address: 0000:000C
; Parameters: none
; Returns: does not return (transfers to DESK.EXE)
; Description: Main chain-loader logic:
;   1. Set DS/ES to data segment (seg_000A)
;   2. Open "DESK.EXE" and read first 0x3C bytes (MZ header)
;   3. Validate header: check header_paragraphs >= 0x25,
;      check DM89 signature "DM89" at offset +1C/+1E,
;      check cs_entry matches expected value
;   4. Use INT 21h/4Bh (EXEC subfunction 01h = load but don't execute)
;      to load DESK.EXE into memory
;   5. Get the loaded program's PSP via INT 21h/51h
;   6. Patch PSP: set terminate address to point to our trampoline
;   7. Scan the child's environment block for "MOLDAPP.MOD"
;   8. Replace "MOLDAPP.MOD" with "INSTALL" (so DESK.EXE launches
;      INSTALL.PDM instead of DESKTOP.PDM)
;   9. Set up SS:SP from EXEC parameter block, push CS:IP,
;      far-return into DESK.EXE's entry point
; ========================================================================
install_entryPoint:                             ; 0000:000C
  0000:000C  b80a00            mov      ax, 0xa            ; RELOC -> seg_000A (data segment)
  0000:000F  8ed8              mov      ds, ax             ; DS = data segment
  0000:0011  8ec0              mov      es, ax             ; ES = data segment

  ; --- Step 1: Open DESK.EXE ---
  0000:0013  ba0400            mov      dx, 4              ; DS:DX -> "DESK.EXE" (seg_000A:0004)
                                                           ;   (skips the leading 'D' at offset 3)
  0000:0016  b8003d            mov      ax, 0x3d00         ; INT 21h/3Dh: Open file, AL=00 (read-only)
  0000:0019  cd21              int      0x21
  0000:001B  72e3              jb       install_printErrorExit  ; Jump if carry (file not found)

  ; --- Step 2: Read 0x3C bytes of MZ header ---
  0000:001D  8bd8              mov      bx, ax             ; BX = file handle
  0000:001F  b93c00            mov      cx, 0x3c           ; CX = 60 bytes to read
  0000:0022  ba9c00            mov      dx, 0x9c           ; DS:DX -> read buffer at seg_000A:009C
  0000:0025  b43f              mov      ah, 0x3f           ; INT 21h/3Fh: Read file
  0000:0027  cd21              int      0x21
  0000:0029  72d5              jb       install_printErrorExit  ; Jump if read error

  ; --- Close the file ---
  0000:002B  b43e              mov      ah, 0x3e           ; INT 21h/3Eh: Close file
  0000:002D  cd21              int      0x21

  ; --- Step 3: Validate DM89 signature ---
  ; Check: header_paragraphs (at buffer+0x18 = 0xB4) must be > 0x25
  0000:002F  833eb40025        cmp      word ptr [0xb4], 0x25
  0000:0034  76ca              jbe      install_printErrorExit  ; Fail if header too small

  ; Check: bytes at buffer+0x1C must be "DM" (0x4D44 little-endian)
  0000:0036  813eb800444d      cmp      word ptr [0xb8], 0x4d44  ; 'DM'
  0000:003C  75c2              jne      install_printErrorExit

  ; Check: bytes at buffer+0x1E must be "89" (0x3938 little-endian)
  0000:003E  813eba003839      cmp      word ptr [0xba], 0x3938  ; '89'
  0000:0044  75ba              jne      install_printErrorExit

  ; Check: entry CS (at buffer+0x1A = 0xB6) must match our stored value
  0000:0046  a10200            mov      ax, word ptr [2]   ; Load expected CS value from data seg
  0000:0049  3906b600          cmp      word ptr [0xb6], ax ; Compare with DESK.EXE header CS
  0000:004D  75b1              jne      install_printErrorExit

  ; --- Step 4: EXEC (load overlay) DESK.EXE ---
  0000:004F  ba0400            mov      dx, 4              ; DS:DX -> "DESK.EXE"
  0000:0052  bb2700            mov      bx, 0x27           ; ES:BX -> EXEC parameter block at 0x27
                                                           ;   (subfunction 01h uses load-only params)
  0000:0055  b8014b            mov      ax, 0x4b01         ; INT 21h/4Bh, AL=01h: Load but don't execute
  0000:0058  cd21              int      0x21
  0000:005A  72a4              jb       install_printErrorExit  ; Jump if EXEC failed

  ; --- Step 5: Get child PSP ---
  0000:005C  b451              mov      ah, 0x51           ; INT 21h/51h: Get PSP segment
  0000:005E  cd21              int      0x21               ; BX = PSP segment of loaded program

  ; --- Step 6: Patch PSP terminate address ---
  ; PSP:000A = terminate address (CS:IP for INT 20h/Ctrl-C)
  ; Set it to CS:0007, which points to our trampoline (pop ds; retf)
  0000:0060  8ec3              mov      es, bx             ; ES = child PSP segment
  0000:0062  26c7060a000700    mov      word ptr es:[0xa], 7    ; PSP:000A (IP) = 0007
  0000:0069  268c0e0c00        mov      word ptr es:[0xc], cs   ; PSP:000C (CS) = our CS

  ; --- Step 7: Search environment for "MOLDAPP.MOD" ---
  ; The environment block starts at offset 0x100 in the child's memory.
  ; We scan for 'D' (0x44) as the first character of "DDESK.EXE" which
  ; precedes "MOLDAPP.MOD" in the environment string area.
  0000:006E  bf0001            mov      di, 0x100          ; ES:DI -> start of environment block
  0000:0071  b044              mov      al, 0x44           ; AL = 'D' (search character)

install_searchLoop:                             ; 0000:0073
  0000:0073  b9ffff            mov      cx, 0xffff         ; CX = max scan length
  0000:0076  f2ae              repne scasb                  ; Scan for 'D' in ES:DI

  ; Compare next 12 bytes against "MOLDAPP.MOD\0"
  0000:0078  be1100            mov      si, 0x11           ; DS:SI -> "MOLDAPP.MOD" at seg_000A:0011
  0000:007B  b90c00            mov      cx, 0xc            ; CX = 12 bytes (including null)
  0000:007E  f3a6              repe cmpsb                   ; Compare strings
  0000:0080  75f1              jne      install_searchLoop  ; Not found, keep searching

  ; --- Step 8: Patch "MOLDAPP.MOD" with "INSTALL\0" ---
  ; At this point DI points past "MOLDAPP.MOD". We back up 0x16 bytes
  ; to overwrite from the start of the module reference.
  0000:0082  be1d00            mov      si, 0x1d           ; DS:SI -> "INSTALL" at seg_000A:001D
  0000:0085  b90800            mov      cx, 8              ; CX = 8 bytes ("INSTALL" + null)
  0000:0088  83ef16            sub      di, 0x16           ; Back up DI to start of module name field
  0000:008B  f3a4              rep movsb                    ; Copy "INSTALL\0" over "MOLDAPP.MOD"

  ; --- Step 9: Transfer control to DESK.EXE ---
  ; Load SS:SP from EXEC parameter block (filled by DOS during load)
  0000:008D  fa                cli                          ; Disable interrupts for stack switch
  0000:008E  8b263500          mov      sp, word ptr [0x35] ; SP from param block +10
  0000:0092  8e163700          mov      ss, word ptr [0x37] ; SS from param block +12
  0000:0096  fb                sti                          ; Re-enable interrupts

  ; Push DESK.EXE entry point CS:IP onto the new stack, then far-return
  0000:0097  ff363b00          push     word ptr [0x3b]     ; Push CS from param block +16
  0000:009B  ff363900          push     word ptr [0x39]     ; Push IP from param block +14
  0000:009F  06                push     es                   ; Push child PSP segment

; At this point, execution falls through to seg_000A:0000 where
; "pop ds; retf" transfers control. The RETF pops IP and CS from the
; stack, jumping to DESK.EXE's entry point. DS is set to the child PSP.

; ------------------------------------------------------------------------
; SEGMENT seg_000A  (156 bytes, file 0x02A0-0x033C)
; DATA: Strings, EXEC parameter block, MZ header read buffer
; ------------------------------------------------------------------------
seg_000A:

; Trampoline: reached via fall-through from seg_0000.
; Restores DS from the PSP segment pushed on the stack, then far-returns
; to DESK.EXE's entry point.
install_trampoline:                             ; 000A:0000
  000A:0000  1f                pop      ds                  ; DS = child PSP segment (from push es above)
  000A:0001  cb                retf                         ; Far return to DESK.EXE entry point (CS:IP on stack)

; Data area
  000A:0002  db 13                                          ; Unknown data byte (0x13)

; --- String: "DDESK.EXE" ---
; Offset 0003: full string including leading 'D'
; Offset 0004: "DESK.EXE" (the actual filename used by open/EXEC)
str_DDESK_EXE:                                  ; 000A:0003
  000A:0003  db 44 44 45 53 4B 2E 45 58 45      ; "DDESK.EXE"
  000A:000C  db 00                                ; NUL terminator

; Padding / reserved
  000A:000D  db 00 00 00 00                       ; 4 zero bytes

; --- String: "MOLDAPP.MOD" ---
; The module name to search for in the environment block
str_MOLDAPP_MOD:                                ; 000A:0011
  000A:0011  db 4D 4F 4C 44 41 50 50 2E 4D 4F 44  ; "MOLDAPP.MOD"
  000A:001C  db 00                                ; NUL terminator

; --- String: "INSTALL" ---
; Replacement module name (patched over MOLDAPP.MOD)
str_INSTALL:                                    ; 000A:001D
  000A:001D  db 49 4E 53 54 41 4C 4C              ; "INSTALL"
  000A:0024  db 00                                ; NUL terminator

; --- EXEC Parameter Block ---
; Used by INT 21h/4Bh subfunction 01h (load overlay)
; Structure (14 bytes at offset 0x25):
;   +00 word  environment_segment (0x000D = offset into our data)
;   +02 dword command_line pointer
;   +06 dword FCB1 pointer (RELOC -> seg_000A)
;   +0A dword FCB2 pointer
;   +0E word  (reserved, filled by DOS)
; After EXEC completes, DOS fills in:
;   +10 word  SS value for loaded program
;   +12 word  SP value
;   +14 word  IP value (entry point)
;   +16 word  CS value (entry point)
install_execParamBlock:                         ; 000A:0025
  000A:0025  db 00 0D 00 00 25 00 0A 00           ; env_seg=0x000D, cmdline=000A:0025
  000A:002D  db 00 00 00 00 00 00 00 00            ; FCB1, FCB2 (zeroed)
  ; After EXEC, the following are filled by DOS:
  000A:0035  db 01 00 00 00 00 00 00 00            ; SS:SP and CS:IP (load results)

; --- Error Message String ---
; '$'-terminated string for INT 21h/09h
str_errorMessage:                               ; 000A:003D
  000A:003D  db "Please change to the drive containing the DESKMATE 1 disk"
  000A:0077  db 0D 0A                              ; \r\n
  000A:0079  db "before running install."
  000A:0090  db 0D 0A                              ; \r\n
  000A:0092  db 24                                 ; '$' terminator

; --- Padding ---
str_padding:                                    ; 000A:0093
  000A:0093  db 24 24 24 24 24 24 24 24 24        ; "$$$$$$$$$"

; MZ header read buffer starts at 000A:009C (60 bytes)
; This area receives the first 0x3C bytes of DESK.EXE for validation.

; ========================================================================
; END OF INSTALL.EXE DISASSEMBLY
; ========================================================================
