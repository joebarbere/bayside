; ========================================================================
; ALARM.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; ALARM.RES is the alarm/timer service for DeskMate 3.05.
; It manages scheduled alarms for the Calendar application and plays alert
; sounds when alarms fire. The module installs as a TSR (Terminate and Stay
; Resident) and hooks several interrupt vectors to monitor system time.
;
; When an alarm time is reached, ALARM.RES triggers an audible alert (bell
; character via INT 10h) and can display notification messages. It maintains
; an ordered list of up to 20 pending alarms sorted by trigger time.
;
; The module reads alarm configuration from ALARM.CFG (located via the
; DESKMATE environment variable) and supports both one-shot and recurring
; alarm types ('A' = add alarm, 'D' = delete alarm, 'C' = clear all).
;
; DM89 imports: INT E0h (DeskMate host API)
; Hooks: INT 00h, INT 1Ch (timer tick), INT 28h (DOS idle), INT 13h (disk),
;        INT 10h (video), INT E9h, INT 1Ah (time of day)
;

; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- ALARM.RES Functions ---
;
; Address          Name                              Description
; -------          ----                              -----------
; 0000:0000        alarm_interruptVectorTable        Saved interrupt vector table (00h/1Ch/28h/13h/10h/E9h/1Ah)
; 0000:002C        alarm_getDTA                      Get current DTA address via INT 21h/2Fh
; 0000:0035        alarm_checkKeyboard               Check keyboard buffer, call INT 28h idle if empty
; 0000:013B        alarm_registerWithHost            Register ALARM module name with DM89 host via INT E0h/02h
; 0000:01CA        alarm_saveInterruptVectors        Save original interrupt vectors (00h,1Ch,28h,13h,10h,E9h,1Ah)
; 0000:025D        alarm_saveStackContext            Save SS, DS, and SP for interrupt handler restoration
; 0000:028F        alarm_beep                        Sound alert beep via INT 10h/0Eh (BEL character)
; 0000:02A0        alarm_getInDOSFlag                Get DOS InDOS flag address via INT 21h/34h
; 0000:02BA        alarm_findResident                Find resident module via INT E0h/02h name lookup
; 0000:031A        alarm_readFile                    Read file via INT 21h/3Fh (handle, far ptr, count, bytes_read)
; 0000:0337        alarm_openFile                    Open file via INT 21h/3Dh (filename, mode, handle_out)
; 0000:034F        alarm_closeFile                   Close file via INT 21h/3Eh (handle)
; 0000:0380        alarm_memcpyReverse               Copy memory block in reverse (overlapping safe, far ptrs)
; 0000:03A8        alarm_notifyHost                  Notify DeskMate host of alarm event via INT E0h/02h
; 0000:03B8        alarm_processMessage              Process incoming alarm message (G=set, c=clear, other=update)
; 0000:0493        alarm_dispatchCommand             Dispatch alarm command: A=add, D=delete, C=clear+add
; 0000:06EE        alarm_installTSR                  Install alarm TSR: register with host, hook vectors, go resident
; 0000:07CD        alarm_addAlarmFromRecord          Add alarm from Calendar record (parse time, insert into list)
; 0000:0839        alarm_insertAlarm                 Insert alarm into sorted alarm list at correct position
; 0000:08F1        alarm_deleteAlarmByRecord         Delete alarm matching Calendar record from alarm list
; 0000:098D        alarm_clearAllAlarms              Clear all alarms (set alarm count to 0)
; 0000:0994        alarm_removeAlarmByIndex          Remove alarm at given index, shift remaining entries
; 0000:09DD        alarm_encodeTime                  Encode day-of-week + quarter-hour into 32-bit tick count
; 0000:0C98        alarm_checkAlreadyLoaded          Check if ALARM.RES is already loaded via INT E9h vector
; 0000:0CEB        alarm_getEnvVariable              Get DeskMate environment variable value from environment block
; 0000:0D3F        alarm_matchEnvKey                 Match environment key=value pair, copy value if found
; 0000:0DA0        alarm_formatOutput                Format alarm output string via printf-like formatting
; 0000:0F08        alarm_unhookAtExit                Restore original interrupt vectors on exit/unload
; 0000:0F21        alarm_callInitList                Call near initialization function list (atexit-style, backward)
; 0000:0F30        alarm_callFarInitList             Call far initialization function list (backward)
; 0000:0FAC        alarm_registerHostCallbacks       Register alarm callback handlers with DeskMate host
; 0000:0FC5        alarm_unregisterCallbacks         Unregister alarm callbacks from DeskMate host
; 0000:100A        alarm_callHostFunction            Call DeskMate host function via indirect far call dispatch
; 0000:1132        alarm_fatalError                  Fatal error handler - write error message, terminate
; 0000:1158        alarm_verifyChecksum              Verify code integrity checksum (XOR 0x55 over 0x42 bytes)
; 0000:1308        alarm_lookupMessage               Look up error message string by ID in message table
; 0000:1333        alarm_writeMessage                Write message string to stderr (handle 2)
; 0000:135C        alarm_allocNear                   Allocate near memory from heap, resize PSP if needed
; 0000:139E        alarm_strcat                      String concatenation (append src to dest)
; 0000:13DE        alarm_strcpy                      String copy (dest, src)
; 0000:1410        alarm_strcmp                      String comparison (returns 0 if equal, -1/1 otherwise)
; 0000:143C        alarm_strlen                      String length (returns character count)
; 0000:1458        alarm_strncpy                     String copy with max length (dest, src, maxlen)
; 0000:1480        alarm_strncmp                     String comparison with max length (s1, s2, maxlen)
; 0000:14BA        alarm_printf                      Formatted output (printf-like, writes to stream)
; 0000:1524        alarm_memcpy                      Memory copy (far src/dest, count) via rep movsb
; 0000:1542        alarm_getCurrentDateTime          Get current date/time as 32-bit day+time value
; 0000:1594        alarm_strchr                      Find character in string (returns pointer or 0)
; 0000:15BE        alarm_getKey                      Get keyboard input via INT 16h
; 0000:15D2        alarm_getInterruptVector          Get interrupt vector via INT 21h/35h
; 0000:15E4        alarm_terminateResident           Terminate and stay resident via INT 21h/31h
; 0000:15F6        alarm_setInterruptVector          Set interrupt vector via INT 21h/25h
; 0000:160C        alarm_divSigned32                 Signed 32-bit division (dividend/divisor -> quotient)
; 0000:16A8        alarm_mulUnsigned32               Unsigned 32-bit multiplication
; 0000:16DC        alarm_divUnsigned32               Unsigned 32-bit division
; 0000:173E        alarm_fwrite                      Write data to file stream (buffered output)
; 0000:187A        alarm_flushAndWrite               Flush stream buffer and write character
; 0000:19D0        alarm_openStreamBuffer            Open/initialize stream buffer for writing
; 0000:1A54        alarm_closeStream                 Close output stream, flush remaining data
; 0000:1AEA        alarm_dateToTicks                 Convert date (year,month,day,hour,min,sec) to tick count
; 0000:1C00        alarm_allocStreamBuffer           Allocate buffer for file stream I/O
; 0000:1C6C        alarm_flushStream                 Flush stream buffer to disk
; 0000:1CDA        alarm_seekFile                    Seek file position via INT 21h/42h
; 0000:1D54        alarm_writeToFile                 Low-level write to file handle (INT 21h/40h)
; 0000:1DFA        alarm_writeRawBytes               Write raw bytes to file, handle errors
; 0000:1E7C        alarm_isDeviceHandle              Check if file handle is a device (IOCTL flag 0x40)
; 0000:1EA0        alarm_initAlarmConfig             Initialize alarm config (parse ALARM.CFG once)
; 0000:1EB0        alarm_parseAlarmConfig            Parse ALARM.CFG - read repeat interval and sound file
; 0000:1F60        alarm_validateLeapYear            Validate date considering leap year rules
; 0000:202A        alarm_memcpyForward               Forward memory copy (aligned, optimized with word moves)
; 0000:207C        alarm_setDOSError                 Set DOS error code from INT 21h result
; 0000:20DC        alarm_stackAvail                  Check available stack space
; 0000:2100        alarm_malloc                      C library malloc - allocate memory from heap
; 0000:2146        alarm_atol                        Convert ASCII string to long integer (atol)
; 0000:2163        alarm_heapAlloc                   Internal heap allocator (first-fit free list)
; 0000:2246        alarm_heapGrow                    Grow heap by allocating more DOS memory
; 0000:2280        alarm_heapSplit                   Split heap block and update free list
; 0000:22A2        alarm_sbrk                        sbrk - extend heap via INT 21h/48h or 4Ah
; 0000:2316        alarm_heapExtend                  Extend heap segment (near or far heap)
; 0000:2384        alarm_findHeapSegment             Find heap segment with enough space
; 023D:0000        alarm_updateHeapTop               Update heap top pointer after allocation
;


seg_0000:


; --- alarm_interruptVectorTable ---
; Saved interrupt vector table (00h/1Ch/28h/13h/10h/E9h/1Ah)
alarm_interruptVectorTable:  ; (sub_0000_0000)
  0000:0000  0000              add      byte ptr [bx + si], al
  0000:0002  0000              add      byte ptr [bx + si], al
  0000:0004  0000              add      byte ptr [bx + si], al
  0000:0006  0000              add      byte ptr [bx + si], al
  0000:0008  0000              add      byte ptr [bx + si], al
  0000:000A  0000              add      byte ptr [bx + si], al
  0000:000C  0000              add      byte ptr [bx + si], al
  0000:000E  0000              add      byte ptr [bx + si], al
  0000:0010  0000              add      byte ptr [bx + si], al
  0000:0012  0000              add      byte ptr [bx + si], al
  0000:0014  0000              add      byte ptr [bx + si], al
  0000:0016  0000              add      byte ptr [bx + si], al
  0000:0018  0000              add      byte ptr [bx + si], al
  0000:001A  0000              add      byte ptr [bx + si], al
  0000:001C  0000              add      byte ptr [bx + si], al
  0000:001E  0000              add      byte ptr [bx + si], al
  0000:0020  0000              add      byte ptr [bx + si], al
  0000:0022  0000              add      byte ptr [bx + si], al
  0000:0024  0000              add      byte ptr [bx + si], al
  0000:0026  0000              add      byte ptr [bx + si], al
  0000:0028  0000              add      byte ptr [bx + si], al
  0000:002A  0000              add      byte ptr [bx + si], al

; --- alarm_getDTA ---
; Get current DTA address via INT 21h/2Fh
alarm_getDTA:  ; (sub_0000_002C)
  0000:002C  b42f              mov      ah, 0x2f
  0000:002E  cd21              int      0x21  ; INT 21h/2Fh: Get DTA
  0000:0030  8cc2              mov      dx, es
  0000:0032  8bc3              mov      ax, bx
  0000:0034  c3                ret

; --- alarm_checkKeyboard ---
; Check keyboard buffer, call INT 28h idle if empty
alarm_checkKeyboard:  ; (sub_0000_0035)
  0000:0035  b401              mov      ah, 1
  0000:0037  cd16              int      0x16  ; INT 16h/01h: Check keyboard buffer
  0000:0039  b401              mov      ah, 1
  0000:003B  7505              jne      0x42  ; -> loc_0000_0042
  0000:003D  cd28              int      0x28  ; INT 28h, AH=01h
  0000:003F  b80000            mov      ax, 0

loc_0000_0042:
  0000:0042  c3                ret
  0000:0043  db 1E 55 BD 48 02 8E DD FF 06 F6 00 9C FF 1E AA 18 ; |.U.H............| [RELOC->seg_0248]
  0000:0053  db 9C FF 0E F6 00 9D 5D 1F CA 02 00 1E 55 BD 48 02 ; |......].....U.H.| [RELOC->seg_0248]
  0000:0063  db 8E DD FF 06 F8 00 5D 9C FF 1E 5C 14 FF 0E F8 00 ; |......]...\.....|
  0000:0073  db 1F CF 9C 0A E4 75 25 FB                         ; |.....u%.|
  0000:007B  55                push     bp
  0000:007C  8bec              mov      bp, sp
  0000:007E  817e0600e0        cmp      word ptr [bp + 6], 0xe000
  0000:0083  5d                pop      bp
  0000:0084  7519              jne      0x9f  ; -> loc_0000_009F
  0000:0086  06                push     es
  0000:0087  b84000            mov      ax, 0x40
  0000:008A  8ec0              mov      es, ax
  0000:008C  fa                cli
  0000:008D  268b166c00        mov      dx, word ptr es:[0x6c]
  0000:0092  268b0e6e00        mov      cx, word ptr es:[0x6e]
  0000:0097  26a07000          mov      al, byte ptr es:[0x70]
  0000:009B  fb                sti
  0000:009C  07                pop      es
  0000:009D  9d                popf
  0000:009E  cf                iret

loc_0000_009F:
  0000:009F  9d                popf
  0000:00A0  2eff2e002b        ljmp     cs:[0x2b00]
  0000:00A5  db B4 0F CD 10 80 FC 50 75 0C 3C 02 74 0D 3C 03 74 ; |......Pu.<.t.<.t|
  0000:00B5  db 09 3C 07 74 05 B8 00 00 EB 03 B8 01 00 C3 EB 09 ; |.<.t............|
  0000:00C5  db 90                                              ; |.|
  0000:00C6  db 4C 49 53 54 45 4E                               ; "LISTEN"
  0000:00CC  db 00                                                ; NUL
  0000:00CD  db 00                                              ; |.|
  0000:00CE  db 50 53 51 52 56 57                               ; "PSQRVW"
  0000:00D4  db 1E 06 9C B8 48 02 8E D8 FF 06 70 00 8C 16 4C 00 ; |....H.....p...L.| [RELOC->seg_0248]
  0000:00E4  db 89 26 4E 00 FA FC 83 3E FC 00 01 74 08 8E 16 A0 ; |.&N....>...t....|
  0000:00F4  db 16 8B 26 A6 16 FB 06 53 E8 F3 03 83 C4 04 FA 8E ; |..&....S........|
  0000:0104  db 16 4C 00 8B 26 4E 00 FB FF 0E 70 00 9D 07 1F    ; |.L..&N....p....|
  0000:0113  db 5F 5E 5A 59 5B 58                               ; "_^ZY[X"
  0000:0119  db CF 8C 16 4C 00 89 26 4E 00 FA FC 8E 16 A0 16 8B ; |...L..&N........|
  0000:0129  db 26 A6 16 FB E8 3C 06 FA 8E 16 4C 00 8B 26 4E 00 ; |&....<....L..&N.|
  0000:0139  db FB C3                                           ; |..|

; --- alarm_registerWithHost ---
; Register ALARM module name with DM89 host via INT E0h/02h
alarm_registerWithHost:  ; (sub_0000_013B)
  0000:013B  8d164200          lea      dx, [0x42]
  0000:013F  8d1e4800          lea      bx, [0x48]
  0000:0143  e87401            call     0x2ba  ; -> sub_0000_02BA  ; alarm_findResident
  0000:0146  c3                ret
  0000:0147  db 41 4C 41 52 4D                                  ; "ALARM"
  0000:014C  db 00                                                ; NUL
  0000:014D  db 00 00 6C 01 00 00 6D 01 00 00 00 00 00 00 00 00 ; |..l...m.........| [RELOC->seg_0000]
  0000:015D  db 00 00 00 00 00 00 00 00 00 00 00 00 03 03 00 CB ; |................|
  0000:016D  db 06 1E 52 50 B8 4C 02 8E D8 B8 00 25 2E C5 16 10 ; |..RP.L.....%....| [RELOC->seg_024C]
  0000:017D  db 00 CD 21 B8 1C 25 2E C5 16 14 00 CD 21 B8 28 25 ; |..!..%......!.(%|
  0000:018D  db 2E C5 16 1C 00 CD 21 B8 13 25 2E C5 16 20 00 CD ; |......!..%... ..|
  0000:019D  db 21 B8 10 25 2E C5 16 24 00 CD 21 B8 E9 25 2E C5 ; |!..%...$..!..%..|
  0000:01AD  db 16 28 00 CD 21 B8 1A 25 2E C5 16 18 00 CD 21 58 ; |.(..!..%......!X|
  0000:01BD  db 5A 1F 07 CB B8 20 00 8B D0 EE C3 CC C3          ; |Z.... .......|

; --- alarm_saveInterruptVectors ---
; Save original interrupt vectors (00h,1Ch,28h,13h,10h,E9h,1Ah)
alarm_saveInterruptVectors:  ; (sub_0000_01CA)
  0000:01CA  06                push     es
  0000:01CB  0e                push     cs
  0000:01CC  06                push     es
  0000:01CD  50                push     ax
  0000:01CE  53                push     bx
  0000:01CF  b80035            mov      ax, 0x3500
  0000:01D2  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:01D4  2e891e1000        mov      word ptr cs:[0x10], bx
  0000:01D9  2e8c061200        mov      word ptr cs:[0x12], es
  0000:01DE  b81c35            mov      ax, 0x351c
  0000:01E1  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:01E3  2e891e1400        mov      word ptr cs:[0x14], bx
  0000:01E8  2e8c061600        mov      word ptr cs:[0x16], es
  0000:01ED  b82835            mov      ax, 0x3528
  0000:01F0  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:01F2  2e891e1c00        mov      word ptr cs:[0x1c], bx
  0000:01F7  2e8c061e00        mov      word ptr cs:[0x1e], es
  0000:01FC  b81335            mov      ax, 0x3513
  0000:01FF  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:0201  2e891e2000        mov      word ptr cs:[0x20], bx
  0000:0206  2e8c062200        mov      word ptr cs:[0x22], es
  0000:020B  b81035            mov      ax, 0x3510
  0000:020E  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:0210  2e891e2400        mov      word ptr cs:[0x24], bx
  0000:0215  2e8c062600        mov      word ptr cs:[0x26], es
  0000:021A  b8e935            mov      ax, 0x35e9
  0000:021D  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:021F  2e891e2800        mov      word ptr cs:[0x28], bx
  0000:0224  2e8c062a00        mov      word ptr cs:[0x2a], es
  0000:0229  b81a35            mov      ax, 0x351a
  0000:022C  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:022E  2e891e1800        mov      word ptr cs:[0x18], bx
  0000:0233  2e8c061a00        mov      word ptr cs:[0x1a], es
  0000:0238  5b                pop      bx
  0000:0239  58                pop      ax
  0000:023A  07                pop      es
  0000:023B  07                pop      es
  0000:023C  bb4701            mov      bx, 0x147  ; "ALARM"
  0000:023F  36a1e901          mov      ax, word ptr ss:[0x1e9]
  0000:0243  2ea36701          mov      word ptr cs:[0x167], ax
  0000:0247  b80006            mov      ax, 0x600
  0000:024A  cde0              int      0xe0  ; INT E0h, AH=06h
  0000:024C  250080            and      ax, 0x8000
  0000:024F  7505              jne      0x256  ; -> loc_0000_0256
  0000:0251  b8ff01            mov      ax, 0x1ff
  0000:0254  eb03              jmp      0x259  ; -> loc_0000_0259

loc_0000_0256:
  0000:0256  b8f001            mov      ax, 0x1f0

loc_0000_0259:
  0000:0259  cde0              int      0xe0  ; INT E0h, AH=01h
  0000:025B  07                pop      es
  0000:025C  c3                ret

; --- alarm_saveStackContext ---
; Save SS, DS, and SP for interrupt handler restoration
alarm_saveStackContext:  ; (sub_0000_025D)
  0000:025D  8cd0              mov      ax, ss
  0000:025F  36a3a016          mov      word ptr ss:[0x16a0], ax
  0000:0263  8cd8              mov      ax, ds
  0000:0265  36a35000          mov      word ptr ss:[0x50], ax
  0000:0269  8bc4              mov      ax, sp
  0000:026B  36a3a616          mov      word ptr ss:[0x16a6], ax
  0000:026F  c3                ret
  0000:0270  55                push     bp
  0000:0271  8bec              mov      bp, sp
  0000:0273  b450              mov      ah, 0x50
  0000:0275  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0278  cd21              int      0x21  ; INT 21h/50h: Set PSP
  0000:027A  5d                pop      bp
  0000:027B  c3                ret
  0000:027C  55                push     bp
  0000:027D  8bec              mov      bp, sp
  0000:027F  1e                push     ds
  0000:0280  8b5604            mov      dx, word ptr [bp + 4]
  0000:0283  8b4606            mov      ax, word ptr [bp + 6]
  0000:0286  8ed8              mov      ds, ax
  0000:0288  b41a              mov      ah, 0x1a
  0000:028A  cd21              int      0x21  ; INT 21h/1Ah: Set DTA
  0000:028C  1f                pop      ds
  0000:028D  5d                pop      bp
  0000:028E  c3                ret

; --- alarm_beep ---
; Sound alert beep via INT 10h/0Eh (BEL character)
alarm_beep:  ; (sub_0000_028F)
  0000:028F  b8070e            mov      ax, 0xe07
  0000:0292  cd10              int      0x10  ; INT 10h/0Eh: Write char (teletype)
  0000:0294  c3                ret
  0000:0295  db B4 52 CD 21 83 EB 02 26 8B 07 C3                ; |.R.!...&...|

; --- alarm_getInDOSFlag ---
; Get DOS InDOS flag address via INT 21h/34h
alarm_getInDOSFlag:  ; (sub_0000_02A0)
  0000:02A0  55                push     bp
  0000:02A1  8bec              mov      bp, sp
  0000:02A3  b434              mov      ah, 0x34
  0000:02A5  cd21              int      0x21  ; INT 21h, AH=34h
  0000:02A7  8bc3              mov      ax, bx
  0000:02A9  2d0100            sub      ax, 1
  0000:02AC  8b5e04            mov      bx, word ptr [bp + 4]
  0000:02AF  8907              mov      word ptr [bx], ax
  0000:02B1  8c4702            mov      word ptr [bx + 2], es
  0000:02B4  8c068c08          mov      word ptr [0x88c], es
  0000:02B8  5d                pop      bp
  0000:02B9  c3                ret

; --- alarm_findResident ---
; Find resident module via INT E0h/02h name lookup
alarm_findResident:  ; (sub_0000_02BA)
  0000:02BA  53                push     bx
  0000:02BB  51                push     cx
  0000:02BC  52                push     dx
  0000:02BD  56                push     si
  0000:02BE  57                push     di
  0000:02BF  06                push     es
  0000:02C0  1e                push     ds
  0000:02C1  06                push     es
  0000:02C2  1f                pop      ds
  0000:02C3  83ec1c            sub      sp, 0x1c
  0000:02C6  8bc4              mov      ax, sp
  0000:02C8  050f00            add      ax, 0xf
  0000:02CB  b90400            mov      cx, 4
  0000:02CE  d3e8              shr      ax, cl
  0000:02D0  8cd6              mov      si, ss
  0000:02D2  03c6              add      ax, si
  0000:02D4  8ec0              mov      es, ax
  0000:02D6  53                push     bx
  0000:02D7  33db              xor      bx, bx
  0000:02D9  8bf9              mov      di, cx
  0000:02DB  8bf2              mov      si, dx
  0000:02DD  8bd7              mov      dx, di
  0000:02DF  b109              mov      cl, 9
  0000:02E1  fc                cld
  0000:02E2  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:02E4  5e                pop      si
  0000:02E5  26c707ffff        mov      word ptr es:[bx], 0xffff
  0000:02EA  b80802            mov      ax, 0x208
  0000:02ED  cde0              int      0xe0  ; INT E0h, AH=02h
  0000:02EF  0bc0              or       ax, ax
  0000:02F1  7c18              jl       0x30b  ; -> loc_0000_030B
  0000:02F3  268b07            mov      ax, word ptr es:[bx]
  0000:02F6  3dffff            cmp      ax, 0xffff
  0000:02F9  740e              je       0x309  ; -> loc_0000_0309
  0000:02FB  8904              mov      word ptr [si], ax
  0000:02FD  26a10200          mov      ax, word ptr es:[2]
  0000:0301  894402            mov      word ptr [si + 2], ax
  0000:0304  b80100            mov      ax, 1
  0000:0307  eb02              jmp      0x30b  ; -> loc_0000_030B

loc_0000_0309:
  0000:0309  33c0              xor      ax, ax

loc_0000_030B:
  0000:030B  83c41c            add      sp, 0x1c
  0000:030E  1f                pop      ds
  0000:030F  07                pop      es
  0000:0310  5f                pop      di
  0000:0311  5e                pop      si
  0000:0312  5a                pop      dx
  0000:0313  59                pop      cx
  0000:0314  5b                pop      bx
  0000:0315  c3                ret
  0000:0316  db B4 40 EB 02                                     ; |.@..|

; --- alarm_readFile ---
; Read file via INT 21h/3Fh (handle, far ptr, count, bytes_read)
alarm_readFile:  ; (sub_0000_031A)
  0000:031A  b43f              mov      ah, 0x3f
  0000:031C  55                push     bp
  0000:031D  8bec              mov      bp, sp
  0000:031F  1e                push     ds
  0000:0320  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0323  c55606            lds      dx, ptr [bp + 6]
  0000:0326  8b4e0a            mov      cx, word ptr [bp + 0xa]
  0000:0329  cd21              int      0x21  ; INT 21h/3Fh: Read file
  0000:032B  1f                pop      ds
  0000:032C  7207              jb       0x335  ; -> loc_0000_0335
  0000:032E  8b5e0c            mov      bx, word ptr [bp + 0xc]
  0000:0331  8907              mov      word ptr [bx], ax
  0000:0333  33c0              xor      ax, ax

loc_0000_0335:
  0000:0335  5d                pop      bp
  0000:0336  c3                ret

; --- alarm_openFile ---
; Open file via INT 21h/3Dh (filename, mode, handle_out)
alarm_openFile:  ; (sub_0000_0337)
  0000:0337  55                push     bp
  0000:0338  8bec              mov      bp, sp
  0000:033A  8b4606            mov      ax, word ptr [bp + 6]
  0000:033D  b43d              mov      ah, 0x3d
  0000:033F  8b5604            mov      dx, word ptr [bp + 4]
  0000:0342  cd21              int      0x21  ; INT 21h/3Dh: Open file
  0000:0344  7207              jb       0x34d  ; -> loc_0000_034D
  0000:0346  8b5e08            mov      bx, word ptr [bp + 8]
  0000:0349  8907              mov      word ptr [bx], ax
  0000:034B  33c0              xor      ax, ax

loc_0000_034D:
  0000:034D  5d                pop      bp
  0000:034E  c3                ret

; --- alarm_closeFile ---
; Close file via INT 21h/3Eh (handle)
alarm_closeFile:  ; (sub_0000_034F)
  0000:034F  55                push     bp
  0000:0350  8bec              mov      bp, sp
  0000:0352  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0355  b43e              mov      ah, 0x3e
  0000:0357  cd21              int      0x21  ; INT 21h/3Eh: Close file
  0000:0359  7202              jb       0x35d  ; -> loc_0000_035D
  0000:035B  33c0              xor      ax, ax

loc_0000_035D:
  0000:035D  5d                pop      bp
  0000:035E  c3                ret
  0000:035F  55                push     bp
  0000:0360  8bec              mov      bp, sp
  0000:0362  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0365  8b4e08            mov      cx, word ptr [bp + 8]
  0000:0368  8b5606            mov      dx, word ptr [bp + 6]
  0000:036B  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:036E  b442              mov      ah, 0x42
  0000:0370  cd21              int      0x21  ; INT 21h/42h: Seek (lseek)
  0000:0372  720a              jb       0x37e  ; -> loc_0000_037E
  0000:0374  8b5e0c            mov      bx, word ptr [bp + 0xc]
  0000:0377  8907              mov      word ptr [bx], ax
  0000:0379  895702            mov      word ptr [bx + 2], dx
  0000:037C  33c0              xor      ax, ax

loc_0000_037E:
  0000:037E  5d                pop      bp
  0000:037F  c3                ret

; --- alarm_memcpyReverse ---
; Copy memory block in reverse (overlapping safe, far ptrs)
alarm_memcpyReverse:  ; (sub_0000_0380)
  0000:0380  55                push     bp
  0000:0381  8bec              mov      bp, sp
  0000:0383  56                push     si
  0000:0384  57                push     di
  0000:0385  1e                push     ds
  0000:0386  8e5e04            mov      ds, word ptr [bp + 4]
  0000:0389  8b7606            mov      si, word ptr [bp + 6]
  0000:038C  8e4608            mov      es, word ptr [bp + 8]
  0000:038F  8b7e0a            mov      di, word ptr [bp + 0xa]
  0000:0392  8b4e0c            mov      cx, word ptr [bp + 0xc]
  0000:0395  8bc1              mov      ax, cx
  0000:0397  48                dec      ax
  0000:0398  03f0              add      si, ax
  0000:039A  03f8              add      di, ax
  0000:039C  fd                std
  0000:039D  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:039F  fc                cld
  0000:03A0  1f                pop      ds
  0000:03A1  5f                pop      di
  0000:03A2  5e                pop      si
  0000:03A3  8be5              mov      sp, bp
  0000:03A5  5d                pop      bp
  0000:03A6  c3                ret
  0000:03A7  db 00                                              ; |.|

; --- alarm_notifyHost ---
; Notify DeskMate host of alarm event via INT E0h/02h
alarm_notifyHost:  ; (sub_0000_03A8)
  0000:03A8  8cd8              mov      ax, ds
  0000:03AA  8ec0              mov      es, ax
  0000:03AC  bb5400            mov      bx, 0x54
  0000:03AF  ba5800            mov      dx, 0x58
  0000:03B2  b80602            mov      ax, 0x206
  0000:03B5  cde0              int      0xe0  ; INT E0h, AH=02h
  0000:03B7  c3                ret

; --- alarm_processMessage ---
; Process incoming alarm message (G=set, c=clear, other=update)
alarm_processMessage:  ; (sub_0000_03B8)
  0000:03B8  55                push     bp
  0000:03B9  8bec              mov      bp, sp
  0000:03BB  83ec04            sub      sp, 4
  0000:03BE  57                push     di
  0000:03BF  56                push     si
  0000:03C0  c45e04            les      bx, ptr [bp + 4]
  0000:03C3  26803f47          cmp      byte ptr es:[bx], 0x47
  0000:03C7  7403              je       0x3cc  ; -> loc_0000_03CC
  0000:03C9  e99000            jmp      0x45c  ; -> loc_0000_045C

loc_0000_03CC:
  0000:03CC  ff4604            inc      word ptr [bp + 4]
  0000:03CF  8b4604            mov      ax, word ptr [bp + 4]
  0000:03D2  8cc2              mov      dx, es
  0000:03D4  bf7600            mov      di, 0x76
  0000:03D7  8bf0              mov      si, ax
  0000:03D9  1e                push     ds
  0000:03DA  07                pop      es
  0000:03DB  1e                push     ds
  0000:03DC  8eda              mov      ds, dx
  0000:03DE  b94000            mov      cx, 0x40
  0000:03E1  f2a5              repne movsw word ptr es:[di], word ptr [si]
  0000:03E3  1f                pop      ds
  0000:03E4  a07600            mov      al, byte ptr [0x76]
  0000:03E7  98                cwde
  0000:03E8  a37200            mov      word ptr [0x72], ax
  0000:03EB  803e7700ff        cmp      byte ptr [0x77], 0xff
  0000:03F0  7503              jne      0x3f5  ; -> loc_0000_03F5
  0000:03F2  e99800            jmp      0x48d  ; -> loc_0000_048D

loc_0000_03F5:
  0000:03F5  b80700            mov      ax, 7
  0000:03F8  ba0100            mov      dx, 1
  0000:03FB  52                push     dx
  0000:03FC  50                push     ax
  0000:03FD  a07700            mov      al, byte ptr [0x77]
  0000:0400  98                cwde
  0000:0401  99                cdq
  0000:0402  52                push     dx
  0000:0403  50                push     ax
  0000:0404  e8a112            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:0407  b93c00            mov      cx, 0x3c
  0000:040A  2bdb              sub      bx, bx
  0000:040C  53                push     bx
  0000:040D  51                push     cx
  0000:040E  b90700            mov      cx, 7
  0000:0411  bb0100            mov      bx, 1
  0000:0414  53                push     bx
  0000:0415  51                push     cx
  0000:0416  8bc8              mov      cx, ax
  0000:0418  a07800            mov      al, byte ptr [0x78]
  0000:041B  98                cwde
  0000:041C  8bda              mov      bx, dx
  0000:041E  99                cdq
  0000:041F  52                push     dx
  0000:0420  50                push     ax
  0000:0421  8bf1              mov      si, cx
  0000:0423  8bfb              mov      di, bx
  0000:0425  e88012            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:0428  52                push     dx
  0000:0429  50                push     ax
  0000:042A  e8df11            call     0x160c  ; -> sub_0000_160C  ; alarm_divSigned32
  0000:042D  03c6              add      ax, si
  0000:042F  13d7              adc      dx, di
  0000:0431  8946fc            mov      word ptr [bp - 4], ax
  0000:0434  8956fe            mov      word ptr [bp - 2], dx
  0000:0437  a18406            mov      ax, word ptr [0x684]
  0000:043A  8b168606          mov      dx, word ptr [0x686]
  0000:043E  3956fe            cmp      word ptr [bp - 2], dx
  0000:0441  724a              jb       0x48d  ; -> loc_0000_048D
  0000:0443  7705              ja       0x44a  ; -> loc_0000_044A
  0000:0445  3946fc            cmp      word ptr [bp - 4], ax
  0000:0448  7243              jb       0x48d  ; -> loc_0000_048D

loc_0000_044A:
  0000:044A  b87900            mov      ax, 0x79
  0000:044D  50                push     ax
  0000:044E  ff76fe            push     word ptr [bp - 2]
  0000:0451  ff76fc            push     word ptr [bp - 4]
  0000:0454  e8e203            call     0x839  ; -> sub_0000_0839  ; alarm_insertAlarm
  0000:0457  83c406            add      sp, 6
  0000:045A  eb31              jmp      0x48d  ; -> loc_0000_048D

loc_0000_045C:
  0000:045C  c45e04            les      bx, ptr [bp + 4]
  0000:045F  26803f63          cmp      byte ptr es:[bx], 0x63
  0000:0463  7505              jne      0x46a  ; -> loc_0000_046A
  0000:0465  e82505            call     0x98d  ; -> sub_0000_098D  ; alarm_clearAllAlarms
  0000:0468  eb23              jmp      0x48d  ; -> loc_0000_048D

loc_0000_046A:
  0000:046A  ff4e04            dec      word ptr [bp + 4]
  0000:046D  8b4604            mov      ax, word ptr [bp + 4]
  0000:0470  8b5606            mov      dx, word ptr [bp + 6]
  0000:0473  bf6014            mov      di, 0x1460
  0000:0476  8bf0              mov      si, ax
  0000:0478  1e                push     ds
  0000:0479  07                pop      es
  0000:047A  1e                push     ds
  0000:047B  8eda              mov      ds, dx
  0000:047D  b91400            mov      cx, 0x14
  0000:0480  f2a5              repne movsw word ptr es:[di], word ptr [si]
  0000:0482  1f                pop      ds
  0000:0483  b86014            mov      ax, 0x1460
  0000:0486  50                push     ax
  0000:0487  e80900            call     0x493  ; -> sub_0000_0493  ; alarm_dispatchCommand
  0000:048A  83c402            add      sp, 2

loc_0000_048D:
  0000:048D  5e                pop      si
  0000:048E  5f                pop      di
  0000:048F  8be5              mov      sp, bp
  0000:0491  5d                pop      bp
  0000:0492  c3                ret

; --- alarm_dispatchCommand ---
; Dispatch alarm command: A=add, D=delete, C=clear+add
alarm_dispatchCommand:  ; (sub_0000_0493)
  0000:0493  55                push     bp
  0000:0494  8bec              mov      bp, sp
  0000:0496  83ec08            sub      sp, 8
  0000:0499  8b5e04            mov      bx, word ptr [bp + 4]
  0000:049C  8a4701            mov      al, byte ptr [bx + 1]
  0000:049F  98                cwde
  0000:04A0  3d4100            cmp      ax, 0x41
  0000:04A3  740c              je       0x4b1  ; -> loc_0000_04B1
  0000:04A5  3d4300            cmp      ax, 0x43
  0000:04A8  7423              je       0x4cd  ; -> loc_0000_04CD
  0000:04AA  3d4400            cmp      ax, 0x44
  0000:04AD  7410              je       0x4bf  ; -> loc_0000_04BF
  0000:04AF  eb3c              jmp      0x4ed  ; -> loc_0000_04ED

loc_0000_04B1:
  0000:04B1  ff7726            push     word ptr [bx + 0x26]
  0000:04B4  ff7724            push     word ptr [bx + 0x24]
  0000:04B7  e81303            call     0x7cd  ; -> sub_0000_07CD  ; alarm_addAlarmFromRecord

loc_0000_04BA:
  0000:04BA  83c404            add      sp, 4
  0000:04BD  eb2e              jmp      0x4ed  ; -> loc_0000_04ED

loc_0000_04BF:
  0000:04BF  8b5e04            mov      bx, word ptr [bp + 4]
  0000:04C2  ff7722            push     word ptr [bx + 0x22]
  0000:04C5  ff7720            push     word ptr [bx + 0x20]
  0000:04C8  e82604            call     0x8f1  ; -> sub_0000_08F1  ; alarm_deleteAlarmByRecord
  0000:04CB  ebed              jmp      0x4ba  ; -> loc_0000_04BA

loc_0000_04CD:
  0000:04CD  8b5e04            mov      bx, word ptr [bp + 4]
  0000:04D0  c6470144          mov      byte ptr [bx + 1], 0x44
  0000:04D4  ff7604            push     word ptr [bp + 4]
  0000:04D7  e8b9ff            call     0x493  ; -> sub_0000_0493  ; alarm_dispatchCommand
  0000:04DA  83c402            add      sp, 2
  0000:04DD  8b5e04            mov      bx, word ptr [bp + 4]
  0000:04E0  c6470141          mov      byte ptr [bx + 1], 0x41
  0000:04E4  ff7604            push     word ptr [bp + 4]
  0000:04E7  e8a9ff            call     0x493  ; -> sub_0000_0493  ; alarm_dispatchCommand
  0000:04EA  83c402            add      sp, 2

loc_0000_04ED:
  0000:04ED  8be5              mov      sp, bp
  0000:04EF  5d                pop      bp
  0000:04F0  c3                ret
  0000:04F1  db 90                                              ; |.|
  0000:04F2  55                push     bp
  0000:04F3  8bec              mov      bp, sp
  0000:04F5  c45e04            les      bx, ptr [bp + 4]
  0000:04F8  ff4604            inc      word ptr [bp + 4]
  0000:04FB  268a07            mov      al, byte ptr es:[bx]
  0000:04FE  2ae4              sub      ah, ah
  0000:0500  3d0100            cmp      ax, 1
  0000:0503  750a              jne      0x50f  ; -> loc_0000_050F
  0000:0505  06                push     es
  0000:0506  ff7604            push     word ptr [bp + 4]
  0000:0509  e8acfe            call     0x3b8  ; -> sub_0000_03B8  ; alarm_processMessage
  0000:050C  83c404            add      sp, 4

loc_0000_050F:
  0000:050F  5d                pop      bp
  0000:0510  c3                ret
  0000:0511  55                push     bp
  0000:0512  8bec              mov      bp, sp
  0000:0514  83ec04            sub      sp, 4
  0000:0517  eb25              jmp      0x53e  ; -> loc_0000_053E

loc_0000_0519:
  0000:0519  c41eae18          les      bx, ptr [0x18ae]
  0000:051D  268b07            mov      ax, word ptr es:[bx]
  0000:0520  268b5702          mov      dx, word ptr es:[bx + 2]
  0000:0524  3946fc            cmp      word ptr [bp - 4], ax
  0000:0527  7505              jne      0x52e  ; -> loc_0000_052E
  0000:0529  3956fe            cmp      word ptr [bp - 2], dx
  0000:052C  7410              je       0x53e  ; -> loc_0000_053E

loc_0000_052E:
  0000:052E  268b07            mov      ax, word ptr es:[bx]
  0000:0531  268b5702          mov      dx, word ptr es:[bx + 2]
  0000:0535  8946fc            mov      word ptr [bp - 4], ax
  0000:0538  8956fe            mov      word ptr [bp - 2], dx
  0000:053B  ff4e04            dec      word ptr [bp + 4]

loc_0000_053E:
  0000:053E  837e0400          cmp      word ptr [bp + 4], 0
  0000:0542  7fd5              jg       0x519  ; -> loc_0000_0519
  0000:0544  8be5              mov      sp, bp
  0000:0546  5d                pop      bp
  0000:0547  c3                ret
  0000:0548  db 50 51 52 53 54 55 56 57                         ; "PQRSTUVW"
  0000:0550  db 1E 06 B8 48 02 8E D8 FC 07 1F                   ; |...H......| [RELOC->seg_0248]
  0000:055A  db 5F 5E 5D 5B 5B 5A 59 58                         ; "_^][[ZYX"
  0000:0562  db CF                                              ; |.|
  0000:0563  db 50 51 52 53 54 55 56 57                         ; "PQRSTUVW"
  0000:056B  db 1E 06 8B EC B8 48 02 8E D8 FC C7 46 12 00 00 07 ; |.....H.....F....| [RELOC->seg_0248]
  0000:057B  db 1F                                              ; |.|
  0000:057C  db 5F 5E 5D 5B 5B 5A 59 58                         ; "_^][[ZYX"
  0000:0584  db CF                                              ; |.|
  0000:0585  db 50 51 52 53 54 55 56 57                         ; "PQRSTUVW"
  0000:058D  db 1E 06 8B EC B8 48 02 8E D8 FC 9C FF 1E 94 16 FF ; |.....H..........| [RELOC->seg_0248]
  0000:059D  db 0E FE 00 75 1A C4 1E AE 18 26 8B 07 26 8B 57 02 ; |...u.....&..&.W.|
  0000:05AD  db A3 84 06 89 16 86 06 C7 06 FE 00 E8 03 EB 0A 83 ; |................|
  0000:05BD  db 06 84 06 01 83 16 86 06 00 83 3E 70 00 00 75 46 ; |..........>p..uF|
  0000:05CD  db C7 06 70 00 01 00 C4 1E 88 06 26 83 3F 00 75 30 ; |..p.......&.?.u0|
  0000:05DD  db 83 3E F6 00 00 75 29 83 3E F8 00 00 75 22 83 3E ; |.>...u).>...u".>|
  0000:05ED  db 74 00 00 7E 1B A1 84 06 8B 16 86 06 39 16 9A 0A ; |t..~........9...|
  0000:05FD  db 77 0E 72 06 39 06 98 0A 77 06 E8 B7 FB E8 0D FB ; |w.r.9...w.......|
  0000:060D  db C7 06 70 00 00 00 07 1F                         ; |..p.....|
  0000:0615  db 5F 5E 5D 5B 5B 5A 59 58                         ; "_^][[ZYX"
  0000:061D  db CF                                              ; |.|
  0000:061E  db 50 51 52 53 54 55 56 57                         ; "PQRSTUVW"
  0000:0626  db 1E 06 8B EC B8 48 02 8E D8 FC 9C FF 1E 98 16 83 ; |.....H..........| [RELOC->seg_0248]
  0000:0636  db 3E 70 00 00 75 35 C7 06 70 00 01 00 C4 1E 88 06 ; |>p..u5..p.......|
  0000:0646  db 26 83 3F 00 74 1F 83 3E 74 00 00 7E 18 A1 84 06 ; |&.?.t..>t..~....|
  0000:0656  db 8B 16 86 06 39 16 9A 0A 77 0B 72 06 39 06 98 0A ; |....9...w.r.9...|
  0000:0666  db 77 03 E8 AF FA C7 06 70 00 00 00 07 1F          ; |w......p.....|
  0000:0673  db 5F 5E 5D 5B 5B 5A 59 58                         ; "_^][[ZYX"
  0000:067B  db CF                                              ; |.|
  0000:067C  55                push     bp
  0000:067D  8bec              mov      bp, sp
  0000:067F  83ec06            sub      sp, 6
  0000:0682  c746fe8808        mov      word ptr [bp - 2], 0x888
  0000:0687  a18406            mov      ax, word ptr [0x684]
  0000:068A  8b168606          mov      dx, word ptr [0x686]
  0000:068E  8946fa            mov      word ptr [bp - 6], ax
  0000:0691  8956fc            mov      word ptr [bp - 4], dx
  0000:0694  eb22              jmp      0x6b8  ; -> loc_0000_06B8

loc_0000_0696:
  0000:0696  837efe00          cmp      word ptr [bp - 2], 0
  0000:069A  7423              je       0x6bf  ; -> loc_0000_06BF
  0000:069C  a18406            mov      ax, word ptr [0x684]
  0000:069F  8b168606          mov      dx, word ptr [0x686]
  0000:06A3  3946fa            cmp      word ptr [bp - 6], ax
  0000:06A6  7505              jne      0x6ad  ; -> loc_0000_06AD
  0000:06A8  3956fc            cmp      word ptr [bp - 4], dx
  0000:06AB  740b              je       0x6b8  ; -> loc_0000_06B8

loc_0000_06AD:
  0000:06AD  ff4efe            dec      word ptr [bp - 2]
  0000:06B0  8346fa01          add      word ptr [bp - 6], 1
  0000:06B4  8356fc00          adc      word ptr [bp - 4], 0

loc_0000_06B8:
  0000:06B8  e87af9            call     0x35  ; -> sub_0000_0035  ; alarm_checkKeyboard
  0000:06BB  0bc0              or       ax, ax
  0000:06BD  74d7              je       0x696  ; -> loc_0000_0696

loc_0000_06BF:
  0000:06BF  837efe00          cmp      word ptr [bp - 2], 0
  0000:06C3  7505              jne      0x6ca  ; -> loc_0000_06CA
  0000:06C5  b80d00            mov      ax, 0xd
  0000:06C8  eb20              jmp      0x6ea  ; -> loc_0000_06EA

loc_0000_06CA:
  0000:06CA  2bc0              sub      ax, ax
  0000:06CC  50                push     ax
  0000:06CD  e8ee0e            call     0x15be  ; -> sub_0000_15BE  ; alarm_getKey
  0000:06D0  83c402            add      sp, 2
  0000:06D3  8946fe            mov      word ptr [bp - 2], ax
  0000:06D6  807efe00          cmp      byte ptr [bp - 2], 0
  0000:06DA  7509              jne      0x6e5  ; -> loc_0000_06E5
  0000:06DC  8a46ff            mov      al, byte ptr [bp - 1]
  0000:06DF  2ae4              sub      ah, ah
  0000:06E1  0c80              or       al, 0x80
  0000:06E3  eb05              jmp      0x6ea  ; -> loc_0000_06EA

loc_0000_06E5:
  0000:06E5  8a46fe            mov      al, byte ptr [bp - 2]
  0000:06E8  2ae4              sub      ah, ah

loc_0000_06EA:
  0000:06EA  8be5              mov      sp, bp
  0000:06EC  5d                pop      bp
  0000:06ED  c3                ret

; --- alarm_installTSR ---
; Install alarm TSR: register with host, hook vectors, go resident
alarm_installTSR:  ; (sub_0000_06EE)
  0000:06EE  55                push     bp
  0000:06EF  8bec              mov      bp, sp
  0000:06F1  83ec14            sub      sp, 0x14
  0000:06F4  c746ec0000        mov      word ptr [bp - 0x14], 0
  0000:06F9  b8e000            mov      ax, 0xe0
  0000:06FC  50                push     ax
  0000:06FD  e8d20e            call     0x15d2  ; -> sub_0000_15D2  ; alarm_getInterruptVector
  0000:0700  83c402            add      sp, 2
  0000:0703  050300            add      ax, 3
  0000:0706  8946fc            mov      word ptr [bp - 4], ax
  0000:0709  8956fe            mov      word ptr [bp - 2], dx
  0000:070C  8d46ee            lea      ax, [bp - 0x12]
  0000:070F  8946f8            mov      word ptr [bp - 8], ax
  0000:0712  8c56fa            mov      word ptr [bp - 6], ss
  0000:0715  b80900            mov      ax, 9
  0000:0718  50                push     ax
  0000:0719  ff76f8            push     word ptr [bp - 8]
  0000:071C  16                push     ss
  0000:071D  ff76fc            push     word ptr [bp - 4]
  0000:0720  52                push     dx
  0000:0721  e8000e            call     0x1524  ; -> sub_0000_1524  ; alarm_memcpy
  0000:0724  83c40a            add      sp, 0xa
  0000:0727  b80900            mov      ax, 9
  0000:072A  50                push     ax
  0000:072B  b80a01            mov      ax, 0x10a
  0000:072E  50                push     ax
  0000:072F  8d46ee            lea      ax, [bp - 0x12]
  0000:0732  50                push     ax
  0000:0733  e84a0d            call     0x1480  ; -> sub_0000_1480  ; alarm_strncmp
  0000:0736  83c406            add      sp, 6
  0000:0739  0bc0              or       ax, ax
  0000:073B  752a              jne      0x767  ; -> loc_0000_0767
  0000:073D  e8fbf9            call     0x13b  ; -> sub_0000_013B  ; alarm_registerWithHost
  0000:0740  3d0100            cmp      ax, 1
  0000:0743  7522              jne      0x767  ; -> loc_0000_0767
  0000:0745  e847fb            call     0x28f  ; -> sub_0000_028F  ; alarm_beep
  0000:0748  e86108            call     0xfac  ; -> sub_0000_0FAC  ; alarm_registerHostCallbacks
  0000:074B  8b4604            mov      ax, word ptr [bp + 4]
  0000:074E  a30001            mov      word ptr [0x100], ax
  0000:0751  8b4606            mov      ax, word ptr [bp + 6]
  0000:0754  a30201            mov      word ptr [0x102], ax
  0000:0757  b80001            mov      ax, 0x100
  0000:075A  50                push     ax
  0000:075B  e8ac08            call     0x100a  ; -> sub_0000_100A  ; alarm_callHostFunction
  0000:075E  83c402            add      sp, 2
  0000:0761  e86108            call     0xfc5  ; -> sub_0000_0FC5  ; alarm_unregisterCallbacks
  0000:0764  b80100            mov      ax, 1

loc_0000_0767:
  0000:0767  8be5              mov      sp, bp
  0000:0769  5d                pop      bp
  0000:076A  c3                ret
  0000:076B  db 90                                              ; |.|
  0000:076C  55                push     bp
  0000:076D  8bec              mov      bp, sp
  0000:076F  83ec12            sub      sp, 0x12
  0000:0772  833e720000        cmp      word ptr [0x72], 0
  0000:0777  744a              je       0x7c3  ; -> loc_0000_07C3
  0000:0779  b80f00            mov      ax, 0xf
  0000:077C  50                push     ax
  0000:077D  b86800            mov      ax, 0x68
  0000:0780  50                push     ax
  0000:0781  8d46f0            lea      ax, [bp - 0x10]
  0000:0784  50                push     ax
  0000:0785  e8d00c            call     0x1458  ; -> sub_0000_1458  ; alarm_strncpy
  0000:0788  83c406            add      sp, 6
  0000:078B  2bc0              sub      ax, ax
  0000:078D  50                push     ax
  0000:078E  8d46f0            lea      ax, [bp - 0x10]
  0000:0791  50                push     ax
  0000:0792  e8ff0d            call     0x1594  ; -> sub_0000_1594  ; alarm_strchr
  0000:0795  83c404            add      sp, 4
  0000:0798  8946ee            mov      word ptr [bp - 0x12], ax
  0000:079B  8bd8              mov      bx, ax
  0000:079D  ff061401          inc      word ptr [0x114]
  0000:07A1  a01401            mov      al, byte ptr [0x114]
  0000:07A4  0430              add      al, 0x30
  0000:07A6  8807              mov      byte ptr [bx], al
  0000:07A8  833e140108        cmp      word ptr [0x114], 8
  0000:07AD  7506              jne      0x7b5  ; -> loc_0000_07B5
  0000:07AF  c70614010000      mov      word ptr [0x114], 0

loc_0000_07B5:
  0000:07B5  b89c0a            mov      ax, 0xa9c
  0000:07B8  50                push     ax
  0000:07B9  8d46f0            lea      ax, [bp - 0x10]
  0000:07BC  50                push     ax
  0000:07BD  e82eff            call     0x6ee  ; -> sub_0000_06EE  ; alarm_installTSR
  0000:07C0  83c404            add      sp, 4

loc_0000_07C3:
  0000:07C3  2bc0              sub      ax, ax
  0000:07C5  50                push     ax
  0000:07C6  e8cb01            call     0x994  ; -> sub_0000_0994  ; alarm_removeAlarmByIndex
  0000:07C9  8be5              mov      sp, bp
  0000:07CB  5d                pop      bp
  0000:07CC  c3                ret

; --- alarm_addAlarmFromRecord ---
; Add alarm from Calendar record (parse time, insert into list)
alarm_addAlarmFromRecord:  ; (sub_0000_07CD)
  0000:07CD  55                push     bp
  0000:07CE  8bec              mov      bp, sp
  0000:07D0  83ec0c            sub      sp, 0xc
  0000:07D3  c45e04            les      bx, ptr [bp + 4]
  0000:07D6  268a4707          mov      al, byte ptr es:[bx + 7]
  0000:07DA  98                cwde
  0000:07DB  50                push     ax
  0000:07DC  e8fe01            call     0x9dd  ; -> sub_0000_09DD  ; alarm_encodeTime
  0000:07DF  83c402            add      sp, 2
  0000:07E2  8946f4            mov      word ptr [bp - 0xc], ax
  0000:07E5  8956f6            mov      word ptr [bp - 0xa], dx
  0000:07E8  a18406            mov      ax, word ptr [0x684]
  0000:07EB  8b168606          mov      dx, word ptr [0x686]
  0000:07EF  3956f6            cmp      word ptr [bp - 0xa], dx
  0000:07F2  7707              ja       0x7fb  ; -> loc_0000_07FB
  0000:07F4  723f              jb       0x835  ; -> loc_0000_0835
  0000:07F6  3946f4            cmp      word ptr [bp - 0xc], ax
  0000:07F9  723a              jb       0x835  ; -> loc_0000_0835

loc_0000_07FB:
  0000:07FB  8b4604            mov      ax, word ptr [bp + 4]
  0000:07FE  8b5606            mov      dx, word ptr [bp + 6]
  0000:0801  050d00            add      ax, 0xd
  0000:0804  8946fc            mov      word ptr [bp - 4], ax
  0000:0807  8956fe            mov      word ptr [bp - 2], dx
  0000:080A  b88814            mov      ax, 0x1488
  0000:080D  8946f8            mov      word ptr [bp - 8], ax
  0000:0810  8c5efa            mov      word ptr [bp - 6], ds
  0000:0813  b87900            mov      ax, 0x79
  0000:0816  50                push     ax
  0000:0817  ff76f8            push     word ptr [bp - 8]
  0000:081A  1e                push     ds
  0000:081B  ff76fc            push     word ptr [bp - 4]
  0000:081E  52                push     dx
  0000:081F  e8020d            call     0x1524  ; -> sub_0000_1524  ; alarm_memcpy
  0000:0822  83c40a            add      sp, 0xa
  0000:0825  b88814            mov      ax, 0x1488
  0000:0828  50                push     ax
  0000:0829  ff76f6            push     word ptr [bp - 0xa]
  0000:082C  ff76f4            push     word ptr [bp - 0xc]
  0000:082F  e80700            call     0x839  ; -> sub_0000_0839  ; alarm_insertAlarm
  0000:0832  83c406            add      sp, 6

loc_0000_0835:
  0000:0835  8be5              mov      sp, bp
  0000:0837  5d                pop      bp
  0000:0838  c3                ret

; --- alarm_insertAlarm ---
; Insert alarm into sorted alarm list at correct position
alarm_insertAlarm:  ; (sub_0000_0839)
  0000:0839  55                push     bp
  0000:083A  8bec              mov      bp, sp
  0000:083C  83ec0c            sub      sp, 0xc
  0000:083F  56                push     si
  0000:0840  c746fe0000        mov      word ptr [bp - 2], 0
  0000:0845  eb03              jmp      0x84a  ; -> loc_0000_084A

loc_0000_0847:
  0000:0847  ff46fe            inc      word ptr [bp - 2]

loc_0000_084A:
  0000:084A  a17400            mov      ax, word ptr [0x74]
  0000:084D  3946fe            cmp      word ptr [bp - 2], ax
  0000:0850  7d1c              jge      0x86e  ; -> loc_0000_086E
  0000:0852  b87d00            mov      ax, 0x7d
  0000:0855  f76efe            imul     word ptr [bp - 2]
  0000:0858  8bd8              mov      bx, ax
  0000:085A  8b4604            mov      ax, word ptr [bp + 4]
  0000:085D  8b5606            mov      dx, word ptr [bp + 6]
  0000:0860  39979a0a          cmp      word ptr [bx + 0xa9a], dx
  0000:0864  72e1              jb       0x847  ; -> loc_0000_0847
  0000:0866  7706              ja       0x86e  ; -> loc_0000_086E
  0000:0868  3987980a          cmp      word ptr [bx + 0xa98], ax
  0000:086C  76d9              jbe      0x847  ; -> loc_0000_0847

loc_0000_086E:
  0000:086E  837efe14          cmp      word ptr [bp - 2], 0x14
  0000:0872  7d78              jge      0x8ec  ; -> loc_0000_08EC
  0000:0874  b87d00            mov      ax, 0x7d
  0000:0877  f76efe            imul     word ptr [bp - 2]
  0000:087A  8bf0              mov      si, ax
  0000:087C  05980a            add      ax, 0xa98
  0000:087F  8946fa            mov      word ptr [bp - 6], ax
  0000:0882  8c5efc            mov      word ptr [bp - 4], ds
  0000:0885  8bc6              mov      ax, si
  0000:0887  05150b            add      ax, 0xb15
  0000:088A  8946f6            mov      word ptr [bp - 0xa], ax
  0000:088D  8c5ef8            mov      word ptr [bp - 8], ds
  0000:0890  a17400            mov      ax, word ptr [0x74]
  0000:0893  2b46fe            sub      ax, word ptr [bp - 2]
  0000:0896  8946f4            mov      word ptr [bp - 0xc], ax
  0000:0899  ff067400          inc      word ptr [0x74]
  0000:089D  833e740014        cmp      word ptr [0x74], 0x14
  0000:08A2  7e07              jle      0x8ab  ; -> loc_0000_08AB
  0000:08A4  ff0e7400          dec      word ptr [0x74]
  0000:08A8  ff4ef4            dec      word ptr [bp - 0xc]

loc_0000_08AB:
  0000:08AB  b87d00            mov      ax, 0x7d
  0000:08AE  f76ef4            imul     word ptr [bp - 0xc]
  0000:08B1  8946f4            mov      word ptr [bp - 0xc], ax
  0000:08B4  50                push     ax
  0000:08B5  ff76f6            push     word ptr [bp - 0xa]
  0000:08B8  ff76f8            push     word ptr [bp - 8]
  0000:08BB  ff76fa            push     word ptr [bp - 6]
  0000:08BE  ff76fc            push     word ptr [bp - 4]
  0000:08C1  e8bcfa            call     0x380  ; -> sub_0000_0380  ; alarm_memcpyReverse
  0000:08C4  83c40a            add      sp, 0xa
  0000:08C7  b87d00            mov      ax, 0x7d
  0000:08CA  f76efe            imul     word ptr [bp - 2]
  0000:08CD  8bf0              mov      si, ax
  0000:08CF  8b4604            mov      ax, word ptr [bp + 4]
  0000:08D2  8b5606            mov      dx, word ptr [bp + 6]
  0000:08D5  8984980a          mov      word ptr [si + 0xa98], ax
  0000:08D9  89949a0a          mov      word ptr [si + 0xa9a], dx
  0000:08DD  ff7608            push     word ptr [bp + 8]
  0000:08E0  8bc6              mov      ax, si
  0000:08E2  059c0a            add      ax, 0xa9c
  0000:08E5  50                push     ax
  0000:08E6  e8f50a            call     0x13de  ; -> sub_0000_13DE  ; alarm_strcpy
  0000:08E9  83c404            add      sp, 4

loc_0000_08EC:
  0000:08EC  5e                pop      si
  0000:08ED  8be5              mov      sp, bp
  0000:08EF  5d                pop      bp
  0000:08F0  c3                ret

; --- alarm_deleteAlarmByRecord ---
; Delete alarm matching Calendar record from alarm list
alarm_deleteAlarmByRecord:  ; (sub_0000_08F1)
  0000:08F1  55                push     bp
  0000:08F2  8bec              mov      bp, sp
  0000:08F4  81ec8800          sub      sp, 0x88
  0000:08F8  56                push     si
  0000:08F9  c45e04            les      bx, ptr [bp + 4]
  0000:08FC  268a4707          mov      al, byte ptr es:[bx + 7]
  0000:0900  98                cwde
  0000:0901  50                push     ax
  0000:0902  e8d800            call     0x9dd  ; -> sub_0000_09DD  ; alarm_encodeTime
  0000:0905  83c402            add      sp, 2
  0000:0908  898678ff          mov      word ptr [bp - 0x88], ax
  0000:090C  89967aff          mov      word ptr [bp - 0x86], dx
  0000:0910  8b4604            mov      ax, word ptr [bp + 4]
  0000:0913  8b5606            mov      dx, word ptr [bp + 6]
  0000:0916  050d00            add      ax, 0xd
  0000:0919  894680            mov      word ptr [bp - 0x80], ax
  0000:091C  895682            mov      word ptr [bp - 0x7e], dx
  0000:091F  8d4684            lea      ax, [bp - 0x7c]
  0000:0922  89867cff          mov      word ptr [bp - 0x84], ax
  0000:0926  8c967eff          mov      word ptr [bp - 0x82], ss
  0000:092A  b87900            mov      ax, 0x79
  0000:092D  50                push     ax
  0000:092E  ffb67cff          push     word ptr [bp - 0x84]
  0000:0932  16                push     ss
  0000:0933  ff7680            push     word ptr [bp - 0x80]
  0000:0936  52                push     dx
  0000:0937  e8ea0b            call     0x1524  ; -> sub_0000_1524  ; alarm_memcpy
  0000:093A  83c40a            add      sp, 0xa
  0000:093D  c746fe0000        mov      word ptr [bp - 2], 0
  0000:0942  eb03              jmp      0x947  ; -> loc_0000_0947

loc_0000_0944:
  0000:0944  ff46fe            inc      word ptr [bp - 2]

loc_0000_0947:
  0000:0947  a17400            mov      ax, word ptr [0x74]
  0000:094A  3946fe            cmp      word ptr [bp - 2], ax
  0000:094D  7d39              jge      0x988  ; -> loc_0000_0988
  0000:094F  b87d00            mov      ax, 0x7d
  0000:0952  f76efe            imul     word ptr [bp - 2]
  0000:0955  8bf0              mov      si, ax
  0000:0957  8b8678ff          mov      ax, word ptr [bp - 0x88]
  0000:095B  8b967aff          mov      dx, word ptr [bp - 0x86]
  0000:095F  3984980a          cmp      word ptr [si + 0xa98], ax
  0000:0963  75df              jne      0x944  ; -> loc_0000_0944
  0000:0965  39949a0a          cmp      word ptr [si + 0xa9a], dx
  0000:0969  75d9              jne      0x944  ; -> loc_0000_0944
  0000:096B  8bc6              mov      ax, si
  0000:096D  059c0a            add      ax, 0xa9c
  0000:0970  50                push     ax
  0000:0971  8d4684            lea      ax, [bp - 0x7c]
  0000:0974  50                push     ax
  0000:0975  e8980a            call     0x1410  ; -> sub_0000_1410  ; alarm_strcmp
  0000:0978  83c404            add      sp, 4
  0000:097B  0bc0              or       ax, ax
  0000:097D  75c5              jne      0x944  ; -> loc_0000_0944
  0000:097F  ff76fe            push     word ptr [bp - 2]
  0000:0982  e80f00            call     0x994  ; -> sub_0000_0994  ; alarm_removeAlarmByIndex
  0000:0985  83c402            add      sp, 2

loc_0000_0988:
  0000:0988  5e                pop      si
  0000:0989  8be5              mov      sp, bp
  0000:098B  5d                pop      bp
  0000:098C  c3                ret

; --- alarm_clearAllAlarms ---
; Clear all alarms (set alarm count to 0)
alarm_clearAllAlarms:  ; (sub_0000_098D)
  0000:098D  c70674000000      mov      word ptr [0x74], 0
  0000:0993  c3                ret

; --- alarm_removeAlarmByIndex ---
; Remove alarm at given index, shift remaining entries
alarm_removeAlarmByIndex:  ; (sub_0000_0994)
  0000:0994  55                push     bp
  0000:0995  8bec              mov      bp, sp
  0000:0997  83ec0a            sub      sp, 0xa
  0000:099A  56                push     si
  0000:099B  b87d00            mov      ax, 0x7d
  0000:099E  f76e04            imul     word ptr [bp + 4]
  0000:09A1  8bf0              mov      si, ax
  0000:09A3  05980a            add      ax, 0xa98
  0000:09A6  8946fc            mov      word ptr [bp - 4], ax
  0000:09A9  8c5efe            mov      word ptr [bp - 2], ds
  0000:09AC  8bc6              mov      ax, si
  0000:09AE  05150b            add      ax, 0xb15
  0000:09B1  8946f8            mov      word ptr [bp - 8], ax
  0000:09B4  8c5efa            mov      word ptr [bp - 6], ds
  0000:09B7  ff0e7400          dec      word ptr [0x74]
  0000:09BB  a17400            mov      ax, word ptr [0x74]
  0000:09BE  2b4604            sub      ax, word ptr [bp + 4]
  0000:09C1  b97d00            mov      cx, 0x7d
  0000:09C4  f7e9              imul     cx
  0000:09C6  8946f6            mov      word ptr [bp - 0xa], ax
  0000:09C9  50                push     ax
  0000:09CA  ff76fc            push     word ptr [bp - 4]
  0000:09CD  1e                push     ds
  0000:09CE  ff76f8            push     word ptr [bp - 8]
  0000:09D1  1e                push     ds
  0000:09D2  e84f0b            call     0x1524  ; -> sub_0000_1524  ; alarm_memcpy
  0000:09D5  83c40a            add      sp, 0xa
  0000:09D8  5e                pop      si
  0000:09D9  8be5              mov      sp, bp
  0000:09DB  5d                pop      bp
  0000:09DC  c3                ret

; --- alarm_encodeTime ---
; Encode day-of-week + quarter-hour into 32-bit tick count
alarm_encodeTime:  ; (sub_0000_09DD)
  0000:09DD  55                push     bp
  0000:09DE  8bec              mov      bp, sp
  0000:09E0  83ec04            sub      sp, 4
  0000:09E3  57                push     di
  0000:09E4  56                push     si
  0000:09E5  8a4604            mov      al, byte ptr [bp + 4]
  0000:09E8  2ae4              sub      ah, ah
  0000:09EA  257c00            and      ax, 0x7c
  0000:09ED  d1e8              shr      ax, 1
  0000:09EF  d1e8              shr      ax, 1
  0000:09F1  8946fc            mov      word ptr [bp - 4], ax
  0000:09F4  8a4604            mov      al, byte ptr [bp + 4]
  0000:09F7  2ae4              sub      ah, ah
  0000:09F9  250300            and      ax, 3
  0000:09FC  b90f00            mov      cx, 0xf
  0000:09FF  f7e1              mul      cx
  0000:0A01  8946fe            mov      word ptr [bp - 2], ax
  0000:0A04  b80700            mov      ax, 7
  0000:0A07  ba0100            mov      dx, 1
  0000:0A0A  52                push     dx
  0000:0A0B  50                push     ax
  0000:0A0C  2bc0              sub      ax, ax
  0000:0A0E  50                push     ax
  0000:0A0F  ff76fc            push     word ptr [bp - 4]
  0000:0A12  e8930c            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:0A15  b93c00            mov      cx, 0x3c
  0000:0A18  2bdb              sub      bx, bx
  0000:0A1A  53                push     bx
  0000:0A1B  51                push     cx
  0000:0A1C  b90700            mov      cx, 7
  0000:0A1F  bb0100            mov      bx, 1
  0000:0A22  53                push     bx
  0000:0A23  51                push     cx
  0000:0A24  2bc9              sub      cx, cx
  0000:0A26  51                push     cx
  0000:0A27  ff76fe            push     word ptr [bp - 2]
  0000:0A2A  8bf0              mov      si, ax
  0000:0A2C  8bfa              mov      di, dx
  0000:0A2E  e8770c            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:0A31  52                push     dx
  0000:0A32  50                push     ax
  0000:0A33  e8a60c            call     0x16dc  ; -> sub_0000_16DC  ; alarm_divUnsigned32
  0000:0A36  03c6              add      ax, si
  0000:0A38  13d7              adc      dx, di
  0000:0A3A  5e                pop      si
  0000:0A3B  5f                pop      di
  0000:0A3C  8be5              mov      sp, bp
  0000:0A3E  5d                pop      bp
  0000:0A3F  c3                ret
  0000:0A40  55                push     bp
  0000:0A41  8bec              mov      bp, sp
  0000:0A43  81ecde00          sub      sp, 0xde
  0000:0A47  57                push     di
  0000:0A48  56                push     si
  0000:0A49  e87ef7            call     0x1ca  ; -> sub_0000_01CA  ; alarm_saveInterruptVectors
  0000:0A4C  e84902            call     0xc98  ; -> sub_0000_0C98  ; alarm_checkAlreadyLoaded
  0000:0A4F  0bc0              or       ax, ax
  0000:0A51  7411              je       0xa64  ; -> loc_0000_0A64
  0000:0A53  b80010            mov      ax, 0x1000
  0000:0A56  50                push     ax
  0000:0A57  b8ff00            mov      ax, 0xff

loc_0000_0A5A:
  0000:0A5A  50                push     ax
  0000:0A5B  e8860b            call     0x15e4  ; -> sub_0000_15E4  ; alarm_terminateResident
  0000:0A5E  83c404            add      sp, 4
  0000:0A61  e92e02            jmp      0xc92  ; -> loc_0000_0C92

loc_0000_0A64:
  0000:0A64  c706b0184000      mov      word ptr [0x18b0], 0x40
  0000:0A6A  c706ae186c00      mov      word ptr [0x18ae], 0x6c
  0000:0A70  b81601            mov      ax, 0x116
  0000:0A73  50                push     ax
  0000:0A74  e87402            call     0xceb  ; -> sub_0000_0CEB  ; alarm_getEnvVariable
  0000:0A77  83c402            add      sp, 2
  0000:0A7A  a39208            mov      word ptr [0x892], ax
  0000:0A7D  50                push     ax
  0000:0A7E  8d8622ff          lea      ax, [bp - 0xde]
  0000:0A82  50                push     ax
  0000:0A83  e85809            call     0x13de  ; -> sub_0000_13DE  ; alarm_strcpy
  0000:0A86  83c404            add      sp, 4
  0000:0A89  ff369208          push     word ptr [0x892]
  0000:0A8D  e8ac09            call     0x143c  ; -> sub_0000_143C  ; alarm_strlen
  0000:0A90  83c402            add      sp, 2
  0000:0A93  8bf0              mov      si, ax
  0000:0A95  8b1e9208          mov      bx, word ptr [0x892]
  0000:0A99  8078ff5c          cmp      byte ptr [bx + si - 1], 0x5c
  0000:0A9D  740f              je       0xaae  ; -> loc_0000_0AAE
  0000:0A9F  b81f01            mov      ax, 0x11f
  0000:0AA2  50                push     ax
  0000:0AA3  8d8622ff          lea      ax, [bp - 0xde]
  0000:0AA7  50                push     ax
  0000:0AA8  e8f308            call     0x139e  ; -> sub_0000_139E  ; alarm_strcat
  0000:0AAB  83c404            add      sp, 4

loc_0000_0AAE:
  0000:0AAE  b82101            mov      ax, 0x121
  0000:0AB1  50                push     ax
  0000:0AB2  8d8622ff          lea      ax, [bp - 0xde]
  0000:0AB6  50                push     ax
  0000:0AB7  e8e408            call     0x139e  ; -> sub_0000_139E  ; alarm_strcat
  0000:0ABA  83c404            add      sp, 4
  0000:0ABD  c606760000        mov      byte ptr [0x76], 0
  0000:0AC2  8d46fe            lea      ax, [bp - 2]
  0000:0AC5  50                push     ax
  0000:0AC6  2bc0              sub      ax, ax
  0000:0AC8  50                push     ax
  0000:0AC9  8d8622ff          lea      ax, [bp - 0xde]
  0000:0ACD  50                push     ax
  0000:0ACE  e866f8            call     0x337  ; -> sub_0000_0337  ; alarm_openFile
  0000:0AD1  83c406            add      sp, 6
  0000:0AD4  0bc0              or       ax, ax
  0000:0AD6  752d              jne      0xb05  ; -> loc_0000_0B05
  0000:0AD8  8d46f8            lea      ax, [bp - 8]
  0000:0ADB  50                push     ax
  0000:0ADC  b88000            mov      ax, 0x80
  0000:0ADF  50                push     ax
  0000:0AE0  b87600            mov      ax, 0x76
  0000:0AE3  1e                push     ds
  0000:0AE4  50                push     ax
  0000:0AE5  ff76fe            push     word ptr [bp - 2]
  0000:0AE8  e82ff8            call     0x31a  ; -> sub_0000_031A  ; alarm_readFile
  0000:0AEB  83c40a            add      sp, 0xa
  0000:0AEE  0bc0              or       ax, ax
  0000:0AF0  740a              je       0xafc  ; -> loc_0000_0AFC
  0000:0AF2  b82c01            mov      ax, 0x12c
  0000:0AF5  50                push     ax
  0000:0AF6  e8a702            call     0xda0  ; -> sub_0000_0DA0  ; alarm_formatOutput
  0000:0AF9  83c402            add      sp, 2

loc_0000_0AFC:
  0000:0AFC  ff76fe            push     word ptr [bp - 2]
  0000:0AFF  e84df8            call     0x34f  ; -> sub_0000_034F  ; alarm_closeFile
  0000:0B02  83c402            add      sp, 2

loc_0000_0B05:
  0000:0B05  a07600            mov      al, byte ptr [0x76]
  0000:0B08  98                cwde
  0000:0B09  a37200            mov      word ptr [0x72], ax
  0000:0B0C  e84ef7            call     0x25d  ; -> sub_0000_025D  ; alarm_saveStackContext
  0000:0B0F  e81af5            call     0x2c  ; -> sub_0000_002C  ; alarm_getDTA
  0000:0B12  a38e08            mov      word ptr [0x88e], ax
  0000:0B15  89169008          mov      word ptr [0x890], dx
  0000:0B19  b88806            mov      ax, 0x688
  0000:0B1C  50                push     ax
  0000:0B1D  e880f7            call     0x2a0  ; -> sub_0000_02A0  ; alarm_getInDOSFlag
  0000:0B20  83c402            add      sp, 2
  0000:0B23  c41eae18          les      bx, ptr [0x18ae]
  0000:0B27  268b07            mov      ax, word ptr es:[bx]
  0000:0B2A  268b5702          mov      dx, word ptr es:[bx + 2]
  0000:0B2E  a38406            mov      word ptr [0x684], ax
  0000:0B31  89168606          mov      word ptr [0x686], dx
  0000:0B35  e855fe            call     0x98d  ; -> sub_0000_098D  ; alarm_clearAllAlarms
  0000:0B38  c68673ff47        mov      byte ptr [bp - 0x8d], 0x47
  0000:0B3D  8dbe74ff          lea      di, [bp - 0x8c]
  0000:0B41  be7600            mov      si, 0x76
  0000:0B44  16                push     ss
  0000:0B45  07                pop      es
  0000:0B46  b94000            mov      cx, 0x40
  0000:0B49  f2a5              repne movsw word ptr es:[di], word ptr [si]
  0000:0B4B  c746fc4000        mov      word ptr [bp - 4], 0x40
  0000:0B50  c746fa6c00        mov      word ptr [bp - 6], 0x6c
  0000:0B55  c45efa            les      bx, ptr [bp - 6]
  0000:0B58  268b07            mov      ax, word ptr es:[bx]
  0000:0B5B  268b5702          mov      dx, word ptr es:[bx + 2]
  0000:0B5F  a38406            mov      word ptr [0x684], ax
  0000:0B62  89168606          mov      word ptr [0x686], dx
  0000:0B66  8d46f4            lea      ax, [bp - 0xc]
  0000:0B69  50                push     ax
  0000:0B6A  e8d509            call     0x1542  ; -> sub_0000_1542  ; alarm_getCurrentDateTime
  0000:0B6D  83c402            add      sp, 2
  0000:0B70  3b16f400          cmp      dx, word ptr [0xf4]
  0000:0B74  7f20              jg       0xb96  ; -> loc_0000_0B96
  0000:0B76  7c06              jl       0xb7e  ; -> loc_0000_0B7E
  0000:0B78  3b06f200          cmp      ax, word ptr [0xf2]
  0000:0B7C  7318              jae      0xb96  ; -> loc_0000_0B96

loc_0000_0B7E:
  0000:0B7E  c70670000100      mov      word ptr [0x70], 1
  0000:0B84  8d8673ff          lea      ax, [bp - 0x8d]
  0000:0B88  16                push     ss
  0000:0B89  50                push     ax
  0000:0B8A  e82bf8            call     0x3b8  ; -> sub_0000_03B8  ; alarm_processMessage
  0000:0B8D  83c404            add      sp, 4
  0000:0B90  c70670000000      mov      word ptr [0x70], 0

loc_0000_0B96:
  0000:0B96  b81c00            mov      ax, 0x1c
  0000:0B99  50                push     ax
  0000:0B9A  e8350a            call     0x15d2  ; -> sub_0000_15D2  ; alarm_getInterruptVector
  0000:0B9D  83c402            add      sp, 2
  0000:0BA0  a39416            mov      word ptr [0x1694], ax
  0000:0BA3  89169616          mov      word ptr [0x1696], dx
  0000:0BA7  b82800            mov      ax, 0x28
  0000:0BAA  50                push     ax
  0000:0BAB  e8240a            call     0x15d2  ; -> sub_0000_15D2  ; alarm_getInterruptVector
  0000:0BAE  83c402            add      sp, 2
  0000:0BB1  a39816            mov      word ptr [0x1698], ax
  0000:0BB4  89169a16          mov      word ptr [0x169a], dx
  0000:0BB8  b81300            mov      ax, 0x13
  0000:0BBB  50                push     ax
  0000:0BBC  e8130a            call     0x15d2  ; -> sub_0000_15D2  ; alarm_getInterruptVector
  0000:0BBF  83c402            add      sp, 2
  0000:0BC2  a3aa18            mov      word ptr [0x18aa], ax
  0000:0BC5  8916ac18          mov      word ptr [0x18ac], dx
  0000:0BC9  b81000            mov      ax, 0x10
  0000:0BCC  50                push     ax
  0000:0BCD  e8020a            call     0x15d2  ; -> sub_0000_15D2  ; alarm_getInterruptVector
  0000:0BD0  83c402            add      sp, 2
  0000:0BD3  a35c14            mov      word ptr [0x145c], ax
  0000:0BD6  89165e14          mov      word ptr [0x145e], dx
  0000:0BDA  b81a00            mov      ax, 0x1a
  0000:0BDD  50                push     ax
  0000:0BDE  e8f109            call     0x15d2  ; -> sub_0000_15D2  ; alarm_getInterruptVector
  0000:0BE1  83c402            add      sp, 2
  0000:0BE4  a38006            mov      word ptr [0x680], ax
  0000:0BE7  89168206          mov      word ptr [0x682], dx
  0000:0BEB  b88505            mov      ax, 0x585  ; "PQRSTUVW"
  0000:0BEE  ba0000            mov      dx, 0  ; RELOC->seg_0000
  0000:0BF1  52                push     dx
  0000:0BF2  50                push     ax
  0000:0BF3  b81c00            mov      ax, 0x1c
  0000:0BF6  50                push     ax
  0000:0BF7  e8fc09            call     0x15f6  ; -> sub_0000_15F6  ; alarm_setInterruptVector
  0000:0BFA  83c406            add      sp, 6
  0000:0BFD  b81e06            mov      ax, 0x61e  ; "PQRSTUVW"
  0000:0C00  ba0000            mov      dx, 0  ; RELOC->seg_0000
  0000:0C03  52                push     dx
  0000:0C04  50                push     ax
  0000:0C05  b82800            mov      ax, 0x28
  0000:0C08  50                push     ax
  0000:0C09  e8ea09            call     0x15f6  ; -> sub_0000_15F6  ; alarm_setInterruptVector
  0000:0C0C  83c406            add      sp, 6
  0000:0C0F  b84300            mov      ax, 0x43
  0000:0C12  ba0000            mov      dx, 0  ; RELOC->seg_0000
  0000:0C15  52                push     dx
  0000:0C16  50                push     ax
  0000:0C17  b81300            mov      ax, 0x13
  0000:0C1A  50                push     ax
  0000:0C1B  e8d809            call     0x15f6  ; -> sub_0000_15F6  ; alarm_setInterruptVector
  0000:0C1E  83c406            add      sp, 6
  0000:0C21  b85e00            mov      ax, 0x5e
  0000:0C24  ba0000            mov      dx, 0  ; RELOC->seg_0000
  0000:0C27  52                push     dx
  0000:0C28  50                push     ax
  0000:0C29  b81000            mov      ax, 0x10
  0000:0C2C  50                push     ax
  0000:0C2D  e8c609            call     0x15f6  ; -> sub_0000_15F6  ; alarm_setInterruptVector
  0000:0C30  83c406            add      sp, 6
  0000:0C33  b8c300            mov      ax, 0xc3
  0000:0C36  ba0000            mov      dx, 0  ; RELOC->seg_0000
  0000:0C39  52                push     dx
  0000:0C3A  50                push     ax
  0000:0C3B  b8e900            mov      ax, 0xe9
  0000:0C3E  50                push     ax
  0000:0C3F  e8b409            call     0x15f6  ; -> sub_0000_15F6  ; alarm_setInterruptVector
  0000:0C42  83c406            add      sp, 6
  0000:0C45  b87500            mov      ax, 0x75
  0000:0C48  ba0000            mov      dx, 0  ; RELOC->seg_0000
  0000:0C4B  52                push     dx
  0000:0C4C  50                push     ax
  0000:0C4D  b81a00            mov      ax, 0x1a
  0000:0C50  50                push     ax
  0000:0C51  e8a209            call     0x15f6  ; -> sub_0000_15F6  ; alarm_setInterruptVector
  0000:0C54  83c406            add      sp, 6
  0000:0C57  a1a616            mov      ax, word ptr [0x16a6]
  0000:0C5A  053200            add      ax, 0x32
  0000:0C5D  b104              mov      cl, 4
  0000:0C5F  d3e8              shr      ax, cl
  0000:0C61  0306a016          add      ax, word ptr [0x16a0]
  0000:0C65  2b06e901          sub      ax, word ptr [0x1e9]
  0000:0C69  8946f8            mov      word ptr [bp - 8], ax
  0000:0C6C  e89902            call     0xf08  ; -> sub_0000_0F08  ; alarm_unhookAtExit
  0000:0C6F  c70670000100      mov      word ptr [0x70], 1
  0000:0C75  c706fc000100      mov      word ptr [0xfc], 1
  0000:0C7B  e82af7            call     0x3a8  ; -> sub_0000_03A8  ; alarm_notifyHost
  0000:0C7E  c706fc000000      mov      word ptr [0xfc], 0
  0000:0C84  c70670000000      mov      word ptr [0x70], 0
  0000:0C8A  ff76f8            push     word ptr [bp - 8]
  0000:0C8D  2bc0              sub      ax, ax
  0000:0C8F  e9c8fd            jmp      0xa5a  ; -> loc_0000_0A5A

loc_0000_0C92:
  0000:0C92  5e                pop      si
  0000:0C93  5f                pop      di
  0000:0C94  8be5              mov      sp, bp
  0000:0C96  5d                pop      bp
  0000:0C97  c3                ret

; --- alarm_checkAlreadyLoaded ---
; Check if ALARM.RES is already loaded via INT E9h vector
alarm_checkAlreadyLoaded:  ; (sub_0000_0C98)
  0000:0C98  55                push     bp
  0000:0C99  8bec              mov      bp, sp
  0000:0C9B  83ec10            sub      sp, 0x10
  0000:0C9E  b8e900            mov      ax, 0xe9
  0000:0CA1  50                push     ax
  0000:0CA2  e82d09            call     0x15d2  ; -> sub_0000_15D2  ; alarm_getInterruptVector
  0000:0CA5  83c402            add      sp, 2
  0000:0CA8  050300            add      ax, 3
  0000:0CAB  8946fc            mov      word ptr [bp - 4], ax
  0000:0CAE  8956fe            mov      word ptr [bp - 2], dx
  0000:0CB1  8d46f0            lea      ax, [bp - 0x10]
  0000:0CB4  8946f8            mov      word ptr [bp - 8], ax
  0000:0CB7  8c56fa            mov      word ptr [bp - 6], ss
  0000:0CBA  b80700            mov      ax, 7
  0000:0CBD  50                push     ax
  0000:0CBE  ff76f8            push     word ptr [bp - 8]
  0000:0CC1  16                push     ss
  0000:0CC2  ff76fc            push     word ptr [bp - 4]
  0000:0CC5  52                push     dx
  0000:0CC6  e85b08            call     0x1524  ; -> sub_0000_1524  ; alarm_memcpy
  0000:0CC9  83c40a            add      sp, 0xa
  0000:0CCC  b80600            mov      ax, 6
  0000:0CCF  50                push     ax
  0000:0CD0  8d46f0            lea      ax, [bp - 0x10]
  0000:0CD3  50                push     ax
  0000:0CD4  b86401            mov      ax, 0x164
  0000:0CD7  50                push     ax
  0000:0CD8  e8a507            call     0x1480  ; -> sub_0000_1480  ; alarm_strncmp
  0000:0CDB  83c406            add      sp, 6
  0000:0CDE  8bc8              mov      cx, ax
  0000:0CE0  83f901            cmp      cx, 1
  0000:0CE3  1bc0              sbb      ax, ax
  0000:0CE5  f7d8              neg      ax
  0000:0CE7  8be5              mov      sp, bp
  0000:0CE9  5d                pop      bp
  0000:0CEA  c3                ret

; --- alarm_getEnvVariable ---
; Get DeskMate environment variable value from environment block
alarm_getEnvVariable:  ; (sub_0000_0CEB)
  0000:0CEB  55                push     bp
  0000:0CEC  8bec              mov      bp, sp
  0000:0CEE  83ec08            sub      sp, 8
  0000:0CF1  c746f82c00        mov      word ptr [bp - 8], 0x2c
  0000:0CF6  a1e901            mov      ax, word ptr [0x1e9]
  0000:0CF9  8946fa            mov      word ptr [bp - 6], ax
  0000:0CFC  c746fc0000        mov      word ptr [bp - 4], 0
  0000:0D01  c45ef8            les      bx, ptr [bp - 8]
  0000:0D04  268b07            mov      ax, word ptr es:[bx]
  0000:0D07  8946fe            mov      word ptr [bp - 2], ax

loc_0000_0D0A:
  0000:0D0A  c45efc            les      bx, ptr [bp - 4]
  0000:0D0D  26803f00          cmp      byte ptr es:[bx], 0
  0000:0D11  7426              je       0xd39  ; -> loc_0000_0D39
  0000:0D13  b82406            mov      ax, 0x624
  0000:0D16  50                push     ax
  0000:0D17  ff7604            push     word ptr [bp + 4]
  0000:0D1A  06                push     es
  0000:0D1B  53                push     bx
  0000:0D1C  e82000            call     0xd3f  ; -> sub_0000_0D3F  ; alarm_matchEnvKey
  0000:0D1F  83c408            add      sp, 8
  0000:0D22  0bc0              or       ax, ax
  0000:0D24  750e              jne      0xd34  ; -> loc_0000_0D34

loc_0000_0D26:
  0000:0D26  c45efc            les      bx, ptr [bp - 4]
  0000:0D29  ff46fc            inc      word ptr [bp - 4]
  0000:0D2C  26803f00          cmp      byte ptr es:[bx], 0
  0000:0D30  74d8              je       0xd0a  ; -> loc_0000_0D0A
  0000:0D32  ebf2              jmp      0xd26  ; -> loc_0000_0D26

loc_0000_0D34:
  0000:0D34  b82406            mov      ax, 0x624
  0000:0D37  eb02              jmp      0xd3b  ; -> loc_0000_0D3B

loc_0000_0D39:
  0000:0D39  2bc0              sub      ax, ax

loc_0000_0D3B:
  0000:0D3B  8be5              mov      sp, bp
  0000:0D3D  5d                pop      bp
  0000:0D3E  c3                ret

; --- alarm_matchEnvKey ---
; Match environment key=value pair, copy value if found
alarm_matchEnvKey:  ; (sub_0000_0D3F)
  0000:0D3F  55                push     bp
  0000:0D40  8bec              mov      bp, sp
  0000:0D42  56                push     si

loc_0000_0D43:
  0000:0D43  c45e04            les      bx, ptr [bp + 4]
  0000:0D46  26803f00          cmp      byte ptr es:[bx], 0
  0000:0D4A  741f              je       0xd6b  ; -> loc_0000_0D6B
  0000:0D4C  8b5e08            mov      bx, word ptr [bp + 8]
  0000:0D4F  803f00            cmp      byte ptr [bx], 0
  0000:0D52  7417              je       0xd6b  ; -> loc_0000_0D6B
  0000:0D54  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0D57  ff4604            inc      word ptr [bp + 4]
  0000:0D5A  8b7608            mov      si, word ptr [bp + 8]
  0000:0D5D  ff4608            inc      word ptr [bp + 8]
  0000:0D60  8a04              mov      al, byte ptr [si]
  0000:0D62  263807            cmp      byte ptr es:[bx], al
  0000:0D65  74dc              je       0xd43  ; -> loc_0000_0D43

loc_0000_0D67:
  0000:0D67  2bc0              sub      ax, ax
  0000:0D69  eb32              jmp      0xd9d  ; -> loc_0000_0D9D

loc_0000_0D6B:
  0000:0D6B  8b5e08            mov      bx, word ptr [bp + 8]
  0000:0D6E  803f00            cmp      byte ptr [bx], 0
  0000:0D71  75f4              jne      0xd67  ; -> loc_0000_0D67
  0000:0D73  c45e04            les      bx, ptr [bp + 4]
  0000:0D76  26803f3d          cmp      byte ptr es:[bx], 0x3d
  0000:0D7A  75eb              jne      0xd67  ; -> loc_0000_0D67
  0000:0D7C  837e0a00          cmp      word ptr [bp + 0xa], 0
  0000:0D80  7418              je       0xd9a  ; -> loc_0000_0D9A
  0000:0D82  ff4604            inc      word ptr [bp + 4]

loc_0000_0D85:
  0000:0D85  8b5e0a            mov      bx, word ptr [bp + 0xa]
  0000:0D88  ff460a            inc      word ptr [bp + 0xa]
  0000:0D8B  c47604            les      si, ptr [bp + 4]
  0000:0D8E  ff4604            inc      word ptr [bp + 4]
  0000:0D91  268a04            mov      al, byte ptr es:[si]
  0000:0D94  8807              mov      byte ptr [bx], al
  0000:0D96  0ac0              or       al, al
  0000:0D98  75eb              jne      0xd85  ; -> loc_0000_0D85

loc_0000_0D9A:
  0000:0D9A  b80100            mov      ax, 1

loc_0000_0D9D:
  0000:0D9D  5e                pop      si
  0000:0D9E  5d                pop      bp
  0000:0D9F  c3                ret

; --- alarm_formatOutput ---
; Format alarm output string via printf-like formatting
alarm_formatOutput:  ; (sub_0000_0DA0)
  0000:0DA0  55                push     bp
  0000:0DA1  8bec              mov      bp, sp
  0000:0DA3  ff7604            push     word ptr [bp + 4]
  0000:0DA6  e81107            call     0x14ba  ; -> sub_0000_14BA  ; alarm_printf
  0000:0DA9  83c402            add      sp, 2
  0000:0DAC  5d                pop      bp
  0000:0DAD  c3                ret
  0000:0DAE  db E8 93 01 E8 C6 03 33 ED FF 36 0A 02 FF 36 08 02 ; |......3..6...6..|
  0000:0DBE  db FF 36 06 02 E8 7B FC 50 E8 E3 00 E8 1C 00 CB E8 ; |.6...{.P........|
  0000:0DCE  db 62 03 CB E8 5F 05 CB E8 01 00 CB                ; |b..._......|

loc_0000_0DD9:
  0000:0DD9  50                push     ax
  0000:0DDA  e85503            call     0x1132  ; -> sub_0000_1132  ; alarm_fatalError
  0000:0DDD  e85305            call     0x1333  ; -> sub_0000_1333  ; alarm_writeMessage
  0000:0DE0  b8ff00            mov      ax, 0xff
  0000:0DE3  50                push     ax
  0000:0DE4  ff167601          call     word ptr [0x176]
  0000:0DE8  b430              mov      ah, 0x30
  0000:0DEA  cd21              int      0x21  ; INT 21h/30h: Get DOS version
  0000:0DEC  a3eb01            mov      word ptr [0x1eb], ax
  0000:0DEF  06                push     es
  0000:0DF0  b80035            mov      ax, 0x3500
  0000:0DF3  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:0DF5  891ed701          mov      word ptr [0x1d7], bx
  0000:0DF9  8c06d901          mov      word ptr [0x1d9], es
  0000:0DFD  1f                pop      ds
  0000:0DFE  b80025            mov      ax, 0x2500
  0000:0E01  ba9200            mov      dx, 0x92
  0000:0E04  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:0E06  16                push     ss
  0000:0E07  1f                pop      ds
  0000:0E08  8b0e3e05          mov      cx, word ptr [0x53e]
  0000:0E0C  e32e              jcxz     0xe3c  ; -> loc_0000_0E3C
  0000:0E0E  8e06e901          mov      es, word ptr [0x1e9]
  0000:0E12  268b362c00        mov      si, word ptr es:[0x2c]
  0000:0E17  c5064005          lds      ax, ptr [0x540]
  0000:0E1B  8cda              mov      dx, ds
  0000:0E1D  33db              xor      bx, bx
  0000:0E1F  36ff1e3c05        lcall    ss:[0x53c]
  0000:0E24  7305              jae      0xe2b  ; -> loc_0000_0E2B
  0000:0E26  16                push     ss
  0000:0E27  1f                pop      ds
  0000:0E28  e92703            jmp      0x1152  ; -> loc_0000_1152

loc_0000_0E2B:
  0000:0E2B  36c5064405        lds      ax, ptr ss:[0x544]
  0000:0E30  8cda              mov      dx, ds
  0000:0E32  bb0300            mov      bx, 3
  0000:0E35  36ff1e3c05        lcall    ss:[0x53c]
  0000:0E3A  16                push     ss
  0000:0E3B  1f                pop      ds

loc_0000_0E3C:
  0000:0E3C  8e06e901          mov      es, word ptr [0x1e9]
  0000:0E40  268b0e2c00        mov      cx, word ptr es:[0x2c]
  0000:0E45  e336              jcxz     0xe7d  ; -> loc_0000_0E7D
  0000:0E47  8ec1              mov      es, cx
  0000:0E49  33ff              xor      di, di

loc_0000_0E4B:
  0000:0E4B  26803d00          cmp      byte ptr es:[di], 0
  0000:0E4F  742c              je       0xe7d  ; -> loc_0000_0E7D
  0000:0E51  b90c00            mov      cx, 0xc
  0000:0E54  beca01            mov      si, 0x1ca
  0000:0E57  f3a6              repe cmpsb byte ptr [si], byte ptr es:[di]
  0000:0E59  740b              je       0xe66  ; -> loc_0000_0E66
  0000:0E5B  b9ff7f            mov      cx, 0x7fff
  0000:0E5E  33c0              xor      ax, ax
  0000:0E60  f2ae              repne scasb al, byte ptr es:[di]
  0000:0E62  7519              jne      0xe7d  ; -> loc_0000_0E7D
  0000:0E64  ebe5              jmp      0xe4b  ; -> loc_0000_0E4B

loc_0000_0E66:
  0000:0E66  06                push     es
  0000:0E67  1e                push     ds
  0000:0E68  07                pop      es
  0000:0E69  1f                pop      ds
  0000:0E6A  8bf7              mov      si, di
  0000:0E6C  bff201            mov      di, 0x1f2
  0000:0E6F  ac                lodsb    al, byte ptr [si]
  0000:0E70  98                cwde
  0000:0E71  91                xchg     cx, ax
  0000:0E72  ac                lodsb    al, byte ptr [si]
  0000:0E73  fec0              inc      al
  0000:0E75  7401              je       0xe78  ; -> loc_0000_0E78
  0000:0E77  48                dec      ax

loc_0000_0E78:
  0000:0E78  aa                stosb    byte ptr es:[di], al
  0000:0E79  e2f7              loop     0xe72
  0000:0E7B  16                push     ss
  0000:0E7C  1f                pop      ds

loc_0000_0E7D:
  0000:0E7D  bb0400            mov      bx, 4

loc_0000_0E80:
  0000:0E80  80a7f201bf        and      byte ptr [bx + 0x1f2], 0xbf
  0000:0E85  b80044            mov      ax, 0x4400
  0000:0E88  cd21              int      0x21  ; INT 21h/44h: IOCTL
  0000:0E8A  720a              jb       0xe96  ; -> loc_0000_0E96
  0000:0E8C  f6c280            test     dl, 0x80
  0000:0E8F  7405              je       0xe96  ; -> loc_0000_0E96
  0000:0E91  808ff20140        or       byte ptr [bx + 0x1f2], 0x40

loc_0000_0E96:
  0000:0E96  4b                dec      bx
  0000:0E97  79e7              jns      0xe80  ; -> loc_0000_0E80
  0000:0E99  be4805            mov      si, 0x548  ; "PQRSTUVW"
  0000:0E9C  bf4805            mov      di, 0x548  ; "PQRSTUVW"
  0000:0E9F  e88e00            call     0xf30  ; -> sub_0000_0F30  ; alarm_callFarInitList
  0000:0EA2  be4805            mov      si, 0x548  ; "PQRSTUVW"
  0000:0EA5  bf4805            mov      di, 0x548  ; "PQRSTUVW"
  0000:0EA8  e87600            call     0xf21  ; -> sub_0000_0F21  ; alarm_callInitList
  0000:0EAB  c3                ret
  0000:0EAC  55                push     bp
  0000:0EAD  8bec              mov      bp, sp
  0000:0EAF  be7606            mov      si, 0x676
  0000:0EB2  bf7606            mov      di, 0x676
  0000:0EB5  e86900            call     0xf21  ; -> sub_0000_0F21  ; alarm_callInitList
  0000:0EB8  be4805            mov      si, 0x548  ; "PQRSTUVW"
  0000:0EBB  bf4a05            mov      di, 0x54a
  0000:0EBE  e86000            call     0xf21  ; -> sub_0000_0F21  ; alarm_callInitList
  0000:0EC1  eb03              jmp      0xec6  ; -> loc_0000_0EC6
  0000:0EC3  55                push     bp
  0000:0EC4  8bec              mov      bp, sp

loc_0000_0EC6:
  0000:0EC6  be4a05            mov      si, 0x54a
  0000:0EC9  bf4a05            mov      di, 0x54a
  0000:0ECC  e85200            call     0xf21  ; -> sub_0000_0F21  ; alarm_callInitList
  0000:0ECF  be4a05            mov      si, 0x54a
  0000:0ED2  bf4a05            mov      di, 0x54a
  0000:0ED5  e85800            call     0xf30  ; -> sub_0000_0F30  ; alarm_callFarInitList
  0000:0ED8  e87d02            call     0x1158  ; -> sub_0000_1158  ; alarm_verifyChecksum
  0000:0EDB  0bc0              or       ax, ax
  0000:0EDD  740b              je       0xeea  ; -> loc_0000_0EEA
  0000:0EDF  837e0400          cmp      word ptr [bp + 4], 0
  0000:0EE3  7505              jne      0xeea  ; -> loc_0000_0EEA
  0000:0EE5  c74604ff00        mov      word ptr [bp + 4], 0xff

loc_0000_0EEA:
  0000:0EEA  b90f00            mov      cx, 0xf
  0000:0EED  bb0500            mov      bx, 5
  0000:0EF0  f687f20101        test     byte ptr [bx + 0x1f2], 1
  0000:0EF5  7404              je       0xefb  ; -> loc_0000_0EFB
  0000:0EF7  b43e              mov      ah, 0x3e
  0000:0EF9  cd21              int      0x21  ; INT 21h/3Eh: Close file

loc_0000_0EFB:
  0000:0EFB  43                inc      bx
  0000:0EFC  e2f2              loop     0xef0
  0000:0EFE  e80700            call     0xf08  ; -> sub_0000_0F08  ; alarm_unhookAtExit
  0000:0F01  8b4604            mov      ax, word ptr [bp + 4]
  0000:0F04  b44c              mov      ah, 0x4c
  0000:0F06  cd21              int      0x21  ; INT 21h/4Ch: Exit with return code

; --- alarm_unhookAtExit ---
; Restore original interrupt vectors on exit/unload
alarm_unhookAtExit:  ; (sub_0000_0F08)
  0000:0F08  8b0e3e05          mov      cx, word ptr [0x53e]
  0000:0F0C  e307              jcxz     0xf15  ; -> loc_0000_0F15
  0000:0F0E  bb0200            mov      bx, 2
  0000:0F11  ff1e3c05          lcall    [0x53c]

loc_0000_0F15:
  0000:0F15  1e                push     ds
  0000:0F16  c516d701          lds      dx, ptr [0x1d7]
  0000:0F1A  b80025            mov      ax, 0x2500
  0000:0F1D  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:0F1F  1f                pop      ds
  0000:0F20  c3                ret

; --- alarm_callInitList ---
; Call near initialization function list (atexit-style, backward)
alarm_callInitList:  ; (sub_0000_0F21)
  0000:0F21  3bf7              cmp      si, di
  0000:0F23  730a              jae      0xf2f  ; -> loc_0000_0F2F
  0000:0F25  4f                dec      di
  0000:0F26  4f                dec      di
  0000:0F27  8b0d              mov      cx, word ptr [di]
  0000:0F29  e3f6              jcxz     0xf21  ; -> sub_0000_0F21
  0000:0F2B  ffd1              call     cx
  0000:0F2D  ebf2              jmp      0xf21  ; -> sub_0000_0F21  ; alarm_callInitList

loc_0000_0F2F:
  0000:0F2F  c3                ret

; --- alarm_callFarInitList ---
; Call far initialization function list (backward)
alarm_callFarInitList:  ; (sub_0000_0F30)
  0000:0F30  3bf7              cmp      si, di
  0000:0F32  730e              jae      0xf42  ; -> loc_0000_0F42
  0000:0F34  83ef04            sub      di, 4
  0000:0F37  8b05              mov      ax, word ptr [di]
  0000:0F39  0b4502            or       ax, word ptr [di + 2]
  0000:0F3C  74f2              je       0xf30  ; -> sub_0000_0F30
  0000:0F3E  ff1d              lcall    [di]
  0000:0F40  ebee              jmp      0xf30  ; -> sub_0000_0F30  ; alarm_callFarInitList

loc_0000_0F42:
  0000:0F42  c3                ret
  0000:0F43  db 00                                              ; |.|
  0000:0F44  55                push     bp
  0000:0F45  8bec              mov      bp, sp
  0000:0F47  55                push     bp
  0000:0F48  8e1ee901          mov      ds, word ptr [0x1e9]
  0000:0F4C  33c9              xor      cx, cx
  0000:0F4E  8bc1              mov      ax, cx
  0000:0F50  8be9              mov      bp, cx
  0000:0F52  8bf9              mov      di, cx
  0000:0F54  49                dec      cx
  0000:0F55  8b362c00          mov      si, word ptr [0x2c]
  0000:0F59  33f6              xor      si, si
  0000:0F5B  0bf6              or       si, si
  0000:0F5D  7408              je       0xf67  ; -> loc_0000_0F67
  0000:0F5F  8ec6              mov      es, si

loc_0000_0F61:
  0000:0F61  f2ae              repne scasb al, byte ptr es:[di]
  0000:0F63  45                inc      bp
  0000:0F64  ae                scasb    al, byte ptr es:[di]
  0000:0F65  75fa              jne      0xf61  ; -> loc_0000_0F61

loc_0000_0F67:
  0000:0F67  45                inc      bp
  0000:0F68  97                xchg     di, ax
  0000:0F69  40                inc      ax
  0000:0F6A  24fe              and      al, 0xfe
  0000:0F6C  8bfd              mov      di, bp
  0000:0F6E  d1e5              shl      bp, 1
  0000:0F70  03c5              add      ax, bp
  0000:0F72  16                push     ss
  0000:0F73  1f                pop      ds
  0000:0F74  57                push     di
  0000:0F75  bf0900            mov      di, 9
  0000:0F78  e8e103            call     0x135c  ; -> sub_0000_135C  ; alarm_allocNear
  0000:0F7B  5f                pop      di
  0000:0F7C  8bcf              mov      cx, di
  0000:0F7E  8bfd              mov      di, bp
  0000:0F80  03f8              add      di, ax
  0000:0F82  892e0a02          mov      word ptr [0x20a], bp
  0000:0F86  1e                push     ds
  0000:0F87  07                pop      es
  0000:0F88  8ede              mov      ds, si
  0000:0F8A  33f6              xor      si, si
  0000:0F8C  49                dec      cx
  0000:0F8D  e313              jcxz     0xfa2  ; -> loc_0000_0FA2
  0000:0F8F  813c3b43          cmp      word ptr [si], 0x433b
  0000:0F93  7405              je       0xf9a  ; -> loc_0000_0F9A
  0000:0F95  897e00            mov      word ptr [bp], di
  0000:0F98  45                inc      bp
  0000:0F99  45                inc      bp

loc_0000_0F9A:
  0000:0F9A  ac                lodsb    al, byte ptr [si]
  0000:0F9B  aa                stosb    byte ptr es:[di], al
  0000:0F9C  0ac0              or       al, al
  0000:0F9E  75fa              jne      0xf9a  ; -> loc_0000_0F9A
  0000:0FA0  e2ed              loop     0xf8f

loc_0000_0FA2:
  0000:0FA2  894e00            mov      word ptr [bp], cx
  0000:0FA5  16                push     ss
  0000:0FA6  1f                pop      ds
  0000:0FA7  5d                pop      bp
  0000:0FA8  8be5              mov      sp, bp
  0000:0FAA  5d                pop      bp
  0000:0FAB  c3                ret

; --- alarm_registerHostCallbacks ---
; Register alarm callback handlers with DeskMate host
alarm_registerHostCallbacks:  ; (sub_0000_0FAC)
  0000:0FAC  06                push     es
  0000:0FAD  53                push     bx
  0000:0FAE  52                push     dx
  0000:0FAF  1e                push     ds
  0000:0FB0  07                pop      es
  0000:0FB1  bb1402            mov      bx, 0x214
  0000:0FB4  ba1802            mov      dx, 0x218
  0000:0FB7  b80602            mov      ax, 0x206
  0000:0FBA  cde0              int      0xe0  ; INT E0h, AH=02h
  0000:0FBC  9a1c100000        lcall    0, 0x101c  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:0FC1  5a                pop      dx
  0000:0FC2  5b                pop      bx
  0000:0FC3  07                pop      es
  0000:0FC4  c3                ret

; --- alarm_unregisterCallbacks ---
; Unregister alarm callbacks from DeskMate host
alarm_unregisterCallbacks:  ; (sub_0000_0FC5)
  0000:0FC5  06                push     es
  0000:0FC6  52                push     dx
  0000:0FC7  1e                push     ds
  0000:0FC8  07                pop      es
  0000:0FC9  ba1802            mov      dx, 0x218
  0000:0FCC  b80702            mov      ax, 0x207
  0000:0FCF  cde0              int      0xe0  ; INT E0h, AH=02h
  0000:0FD1  5a                pop      dx
  0000:0FD2  07                pop      es
  0000:0FD3  c3                ret
  0000:0FD4  db E8 D5 FF E8 36 00 C3 E8 38 00 E8 E4 FF C3       ; |....6...8.....|

loc_0000_0FE2:
  0000:0FE2  55                push     bp
  0000:0FE3  8bec              mov      bp, sp
  0000:0FE5  83c504            add      bp, 4
  0000:0FE8  9a39100000        lcall    0, 0x1039  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:0FED  3dffff            cmp      ax, 0xffff
  0000:0FF0  7416              je       0x1008  ; -> loc_0000_1008
  0000:0FF2  3dfeff            cmp      ax, 0xfffe
  0000:0FF5  7411              je       0x1008  ; -> loc_0000_1008
  0000:0FF7  9a57100000        lcall    0, 0x1057  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:0FFC  a31e02            mov      word ptr [0x21e], ax
  0000:0FFF  ff1e1402          lcall    [0x214]
  0000:1003  9a81100000        lcall    0, 0x1081  ; -> sub_0000_0000 | RELOC->seg_0000

loc_0000_1008:
  0000:1008  5d                pop      bp
  0000:1009  c3                ret

; --- alarm_callHostFunction ---
; Call DeskMate host function via indirect far call dispatch
alarm_callHostFunction:  ; (sub_0000_100A)
  0000:100A  b8da10            mov      ax, 0x10da
  0000:100D  e9d2ff            jmp      0xfe2  ; -> loc_0000_0FE2
  0000:1010  db B8 D6 10 E9 CC FF B8 D7 10 E9 C6 FF 50 C7 06 20 ; |............P.. |
  0000:1020  db 02 FF FF B8 D5 10 25 FF 0F FF 1E 14 02 3C 20 58 ; |......%......< X|
  0000:1030  db 7F 06 C7 06 20 02 FF 0F CB 83 3E 20 02 FF 75 01 ; |.... .....> ..u.|
  0000:1040  db CB 3D 0A 11 7F 05 23 06 20 02 CB 3D 2D 11 B8 FE ; |.=....#. ..=-...|
  0000:1050  db FF 74 03 B8 FF FF CB 9C 3D 90 10 75 22 81 3E 20 ; |.t......=..u".> |
  0000:1060  db 02 FF 0F 74 1A 50 B8 D5 10 FF 1E 14 02 3C 29 58 ; |...t.P.......<)X|
  0000:1070  db 7F 0D 53 8B 5D 0E 8B 1F D1 E3 43 29 5D 02 5B 9D ; |..S.].....C)].[.|
  0000:1080  db CB 9C 81 3E 1E 02 90 10 74 0A 81 3E 1E 02 17 11 ; |...>....t..>....|
  0000:1090  db 74 02 9D CB 81 3E 20 02 FF 0F 74 69 50 B8 D5 10 ; |t....> ...tiP...|
  0000:10A0  db FF 1E 14 02 3C 29 7F 18 81 3E 1E 02 17 11 74 10 ; |....<)...>....t.|
  0000:10B0  db 58 53 8B 5D 0E 8B 1F D1 E3 43 01 5D 02 5B EB    ; |XS.].....C.].[.|
  0000:10BF  db 45 3C 35 58                                     ; "E<5X"
  0000:10C3  db 7F 40 81 3E 1E 02 17 11                         ; |.@.>....|
  0000:10CB  db 75 38 56 57 51 52                               ; "u8VWQR"
  0000:10D1  db 8B 76 00 83 C6 04 E8 2D 00 32 E4 B1 04 F6 E1 BF ; |.v.....-.2......|
  0000:10E1  db 22 02 03 F8 B9 04 00 B8 00 00                   ; |".........|
  0000:10EB  db 4E 4F 47 46                                     ; "NOGF"
  0000:10EF  db 80 3C 00 74 0D 8A 15 38 14 75 04 E2 F1 EB 03 B8 ; |.<.t...8.u......|
  0000:10FF  db FF FF                                           ; |..|
  0000:1101  db 5A 59 5F 5E                                     ; "ZY_^"
  0000:1105  db 9D CB 55 83 EC 0B 8B EC 1E 1E 07 16 1F 8D 46 00 ; |..U...........F.|
  0000:1115  db 55 50 8B EC B8 31 10 25 FF 0F 26 FF 1E 14 02 83 ; |UP...1.%..&.....|
  0000:1125  db C4 02 5D 1F 8A 46 00 83 C4 0B 5D C3 00          ; |..]..F....]..|

; --- alarm_fatalError ---
; Fatal error handler - write error message, terminate
alarm_fatalError:  ; (sub_0000_1132)
  0000:1132  55                push     bp
  0000:1133  8bec              mov      bp, sp
  0000:1135  b8fc00            mov      ax, 0xfc
  0000:1138  50                push     ax
  0000:1139  e8f701            call     0x1333  ; -> sub_0000_1333  ; alarm_writeMessage
  0000:113C  833e660200        cmp      word ptr [0x266], 0
  0000:1141  7404              je       0x1147  ; -> loc_0000_1147
  0000:1143  ff166602          call     word ptr [0x266]

loc_0000_1147:
  0000:1147  b8ff00            mov      ax, 0xff
  0000:114A  50                push     ax
  0000:114B  e8e501            call     0x1333  ; -> sub_0000_1333  ; alarm_writeMessage
  0000:114E  8be5              mov      sp, bp
  0000:1150  5d                pop      bp
  0000:1151  c3                ret

loc_0000_1152:
  0000:1152  b80200            mov      ax, 2
  0000:1155  e981fc            jmp      0xdd9  ; -> loc_0000_0DD9

; --- alarm_verifyChecksum ---
; Verify code integrity checksum (XOR 0x55 over 0x42 bytes)
alarm_verifyChecksum:  ; (sub_0000_1158)
  0000:1158  56                push     si
  0000:1159  33f6              xor      si, si
  0000:115B  b94200            mov      cx, 0x42
  0000:115E  32e4              xor      ah, ah
  0000:1160  fc                cld
  0000:1161  ac                lodsb    al, byte ptr [si]
  0000:1162  32e0              xor      ah, al
  0000:1164  e2fb              loop     0x1161
  0000:1166  80f455            xor      ah, 0x55
  0000:1169  740d              je       0x1178  ; -> loc_0000_1178
  0000:116B  e8c4ff            call     0x1132  ; -> sub_0000_1132  ; alarm_fatalError
  0000:116E  b80100            mov      ax, 1
  0000:1171  50                push     ax
  0000:1172  e8be01            call     0x1333  ; -> sub_0000_1333  ; alarm_writeMessage
  0000:1175  b80100            mov      ax, 1

loc_0000_1178:
  0000:1178  5e                pop      si
  0000:1179  c3                ret
  0000:117A  db 8F 06 68 02 BA 02 00 38 16 EB 01 74 29 8E 06 E9 ; |..h....8...t)...|
  0000:118A  db 01 26 8E 06 2C 00 8C 06 0E 02 33 C0 99 B9 00 80 ; |.&..,.....3.....|
  0000:119A  db 33 FF F2 AE AE 75 FB 47 47 89 3E 0C 02 B9 FF FF ; |3....u.GG.>.....|
  0000:11AA  db F2 AE F7 D1 8B D1 BF 01 00 BE 81 00 8E 1E E9 01 ; |................|
  0000:11BA  db AC 3C 20 74 FB 3C 09 74 F7                      ; |.< t.<.t.|
  0000:11C3  db 3C 0D 74 6F 0A                                  ; "<\rto\n"
  0000:11C8  db C0                                              ; |.|
  0000:11C9  db 74 6B 47 4E                                     ; "tkGN"
  0000:11CD  db AC 3C 20 74 E8 3C 09 74 E4                      ; |.< t.<.t.|
  0000:11D6  db 3C 0D 74 5C 0A                                  ; "<\rt\\n"
  0000:11DB  db C0                                              ; |.|
  0000:11DC  db 74 58 3C 22 74 24 3C 5C 74                      ; "tX<"t$<\t"
  0000:11E5  db 03 42 EB E4 33 C9 41 AC 3C 5C 74 FA 3C 22 74 04 ; |.B..3.A.<\t.<"t.|
  0000:11F5  db 03 D1 EB D3 8B C1 D1 E9 13 D1 A8 01 75 CA EB 01 ; |............u...|
  0000:1205  db 4E AC                                           ; |N.|
  0000:1207  db 3C 0D 74 2B 0A                                  ; "<\rt+\n"
  0000:120C  db C0                                              ; |.|
  0000:120D  db 74 27 3C 22 74                                  ; "t'<"t"
  0000:1212  db BA 3C 5C 74 03 42 EB EC 33 C9 41 AC 3C 5C 74 FA ; |.<\t.B..3.A.<\t.|
  0000:1222  db 3C 22 74 04 03 D1 EB DB 8B C1 D1 E9 13 D1 A8 01 ; |<"t.............|
  0000:1232  db 75 D2 EB 97 16 1F 89 3E 06 02 03 D7 47 D1 E7 03 ; |u......>....G...|
  0000:1242  db D7 80 E2 FE 2B E2 8B C4 A3 08 02 8B D8 03 FB 16 ; |....+...........|
  0000:1252  db 07 36 89 3F 43 43 C5 36 0C 02 AC AA 0A C0 75 FA ; |.6.?CC.6......u.|
  0000:1262  db BE 81 00 36 8E 1E E9 01 EB 03 33 C0 AA AC 3C 20 ; |...6......3...< |
  0000:1272  db 74 FB 3C 09 74 F7 3C 0D 75 03 E9 7F 00 0A C0 75 ; |t.<.t.<.u......u|
  0000:1282  db 03 EB 79 90 36 89                               ; |..y.6.|
  0000:1288  db 3F 43 43 4E                                     ; "?CCN"
  0000:128C  db AC 3C 20 74 DB 3C 09 74 D7                      ; |.< t.<.t.|
  0000:1295  db 3C 0D 74 62 0A                                  ; "<\rtb\n"
  0000:129A  db C0                                              ; |.|
  0000:129B  db 74 5E 3C 22 74 27 3C 5C 74                      ; "t^<"t'<\t"
  0000:12A4  db 03 AA EB E4 33 C9 41 AC 3C 5C 74 FA 3C 22 74 06 ; |....3.A.<\t.<"t.|
  0000:12B4  db B0 5C F3 AA EB D1 B0 5C D1 E9 F3 AA 73 06 B0 22 ; |.\.....\....s.."|
  0000:12C4  db AA EB C5 4E AC                                  ; |...N.|
  0000:12C9  db 3C 0D 74 2E 0A                                  ; "<\rt.\n"
  0000:12CE  db C0                                              ; |.|
  0000:12CF  db 74 2A 3C 22 74                                  ; "t*<"t"
  0000:12D4  db B7 3C 5C 74 03 AA EB EC 33 C9 41 AC 3C 5C 74 FA ; |.<\t....3.A.<\t.|
  0000:12E4  db 3C 22 74 06 B0 5C F3 AA EB D9 B0 5C D1 E9 F3 AA ; |<"t..\.....\....|
  0000:12F4  db 73 96 B0 22 AA EB CD 33 C0 AA 16 1F C7 07 00 00 ; |s.."...3........|
  0000:1304  db FF 26 68 02                                     ; |.&h.|

; --- alarm_lookupMessage ---
; Look up error message string by ID in message table
alarm_lookupMessage:  ; (sub_0000_1308)
  0000:1308  55                push     bp
  0000:1309  8bec              mov      bp, sp
  0000:130B  56                push     si
  0000:130C  57                push     di
  0000:130D  1e                push     ds
  0000:130E  07                pop      es
  0000:130F  8b5604            mov      dx, word ptr [bp + 4]
  0000:1312  be5205            mov      si, 0x552

loc_0000_1315:
  0000:1315  ad                lodsw    ax, word ptr [si]
  0000:1316  3bc2              cmp      ax, dx
  0000:1318  7410              je       0x132a  ; -> loc_0000_132A
  0000:131A  40                inc      ax
  0000:131B  96                xchg     si, ax
  0000:131C  740c              je       0x132a  ; -> loc_0000_132A
  0000:131E  97                xchg     di, ax
  0000:131F  33c0              xor      ax, ax
  0000:1321  b9ffff            mov      cx, 0xffff
  0000:1324  f2ae              repne scasb al, byte ptr es:[di]
  0000:1326  8bf7              mov      si, di
  0000:1328  ebeb              jmp      0x1315  ; -> loc_0000_1315

loc_0000_132A:
  0000:132A  96                xchg     si, ax
  0000:132B  5f                pop      di
  0000:132C  5e                pop      si
  0000:132D  8be5              mov      sp, bp
  0000:132F  5d                pop      bp
  0000:1330  c20200            ret      2

; --- alarm_writeMessage ---
; Write message string to stderr (handle 2)
alarm_writeMessage:  ; (sub_0000_1333)
  0000:1333  55                push     bp
  0000:1334  8bec              mov      bp, sp
  0000:1336  57                push     di
  0000:1337  ff7604            push     word ptr [bp + 4]
  0000:133A  e8cbff            call     0x1308  ; -> sub_0000_1308  ; alarm_lookupMessage
  0000:133D  0bc0              or       ax, ax
  0000:133F  7414              je       0x1355  ; -> loc_0000_1355
  0000:1341  92                xchg     dx, ax
  0000:1342  8bfa              mov      di, dx
  0000:1344  33c0              xor      ax, ax
  0000:1346  b9ffff            mov      cx, 0xffff
  0000:1349  f2ae              repne scasb al, byte ptr es:[di]
  0000:134B  f7d1              not      cx
  0000:134D  49                dec      cx
  0000:134E  bb0200            mov      bx, 2
  0000:1351  b440              mov      ah, 0x40
  0000:1353  cd21              int      0x21  ; INT 21h/40h: Write file

loc_0000_1355:
  0000:1355  5f                pop      di
  0000:1356  8be5              mov      sp, bp
  0000:1358  5d                pop      bp
  0000:1359  c20200            ret      2

; --- alarm_allocNear ---
; Allocate near memory from heap, resize PSP if needed
alarm_allocNear:  ; (sub_0000_135C)
  0000:135C  8bd0              mov      dx, ax
  0000:135E  03067801          add      ax, word ptr [0x178]
  0000:1362  7235              jb       0x1399  ; -> loc_0000_1399
  0000:1364  39067201          cmp      word ptr [0x172], ax
  0000:1368  7325              jae      0x138f  ; -> loc_0000_138F
  0000:136A  050f00            add      ax, 0xf
  0000:136D  50                push     ax
  0000:136E  d1d8              rcr      ax, 1
  0000:1370  b103              mov      cl, 3
  0000:1372  d3e8              shr      ax, cl
  0000:1374  8cd9              mov      cx, ds
  0000:1376  8b1ee901          mov      bx, word ptr [0x1e9]
  0000:137A  2bcb              sub      cx, bx
  0000:137C  03c1              add      ax, cx
  0000:137E  8ec3              mov      es, bx
  0000:1380  8bd8              mov      bx, ax
  0000:1382  b44a              mov      ah, 0x4a
  0000:1384  cd21              int      0x21  ; INT 21h/4Ah: Resize memory block
  0000:1386  58                pop      ax
  0000:1387  7210              jb       0x1399  ; -> loc_0000_1399
  0000:1389  24f0              and      al, 0xf0
  0000:138B  48                dec      ax
  0000:138C  a37201            mov      word ptr [0x172], ax

loc_0000_138F:
  0000:138F  95                xchg     bp, ax
  0000:1390  8b2e7801          mov      bp, word ptr [0x178]
  0000:1394  01167801          add      word ptr [0x178], dx
  0000:1398  c3                ret

loc_0000_1399:
  0000:1399  8bc7              mov      ax, di
  0000:139B  e93bfa            jmp      0xdd9  ; -> loc_0000_0DD9

; --- alarm_strcat ---
; String concatenation (append src to dest)
alarm_strcat:  ; (sub_0000_139E)
  0000:139E  55                push     bp
  0000:139F  8bec              mov      bp, sp
  0000:13A1  8bd7              mov      dx, di
  0000:13A3  8bde              mov      bx, si
  0000:13A5  8cd8              mov      ax, ds
  0000:13A7  8ec0              mov      es, ax
  0000:13A9  8b7e04            mov      di, word ptr [bp + 4]
  0000:13AC  33c0              xor      ax, ax
  0000:13AE  b9ffff            mov      cx, 0xffff
  0000:13B1  f2ae              repne scasb al, byte ptr es:[di]
  0000:13B3  8d75ff            lea      si, [di - 1]
  0000:13B6  8b7e06            mov      di, word ptr [bp + 6]
  0000:13B9  b9ffff            mov      cx, 0xffff
  0000:13BC  f2ae              repne scasb al, byte ptr es:[di]
  0000:13BE  f7d1              not      cx
  0000:13C0  2bf9              sub      di, cx
  0000:13C2  87fe              xchg     si, di
  0000:13C4  8b4604            mov      ax, word ptr [bp + 4]
  0000:13C7  f7c60100          test     si, 1
  0000:13CB  7402              je       0x13cf  ; -> loc_0000_13CF
  0000:13CD  a4                movsb    byte ptr es:[di], byte ptr [si]
  0000:13CE  49                dec      cx

loc_0000_13CF:
  0000:13CF  d1e9              shr      cx, 1
  0000:13D1  f3a5              rep movsw word ptr es:[di], word ptr [si]
  0000:13D3  13c9              adc      cx, cx
  0000:13D5  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:13D7  8bf3              mov      si, bx
  0000:13D9  8bfa              mov      di, dx
  0000:13DB  5d                pop      bp
  0000:13DC  c3                ret
  0000:13DD  db 00                                              ; |.|

; --- alarm_strcpy ---
; String copy (dest, src)
alarm_strcpy:  ; (sub_0000_13DE)
  0000:13DE  55                push     bp
  0000:13DF  8bec              mov      bp, sp
  0000:13E1  8bd7              mov      dx, di
  0000:13E3  8bde              mov      bx, si
  0000:13E5  8b7606            mov      si, word ptr [bp + 6]
  0000:13E8  8bfe              mov      di, si
  0000:13EA  8cd8              mov      ax, ds
  0000:13EC  8ec0              mov      es, ax
  0000:13EE  33c0              xor      ax, ax
  0000:13F0  b9ffff            mov      cx, 0xffff
  0000:13F3  f2ae              repne scasb al, byte ptr es:[di]
  0000:13F5  f7d1              not      cx
  0000:13F7  8b7e04            mov      di, word ptr [bp + 4]
  0000:13FA  8bc7              mov      ax, di
  0000:13FC  a801              test     al, 1
  0000:13FE  7402              je       0x1402  ; -> loc_0000_1402
  0000:1400  a4                movsb    byte ptr es:[di], byte ptr [si]
  0000:1401  49                dec      cx

loc_0000_1402:
  0000:1402  d1e9              shr      cx, 1
  0000:1404  f3a5              rep movsw word ptr es:[di], word ptr [si]
  0000:1406  13c9              adc      cx, cx
  0000:1408  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:140A  8bf3              mov      si, bx
  0000:140C  8bfa              mov      di, dx
  0000:140E  5d                pop      bp
  0000:140F  c3                ret

; --- alarm_strcmp ---
; String comparison (returns 0 if equal, -1/1 otherwise)
alarm_strcmp:  ; (sub_0000_1410)
  0000:1410  55                push     bp
  0000:1411  8bec              mov      bp, sp
  0000:1413  8bd7              mov      dx, di
  0000:1415  8bde              mov      bx, si
  0000:1417  8cd8              mov      ax, ds
  0000:1419  8ec0              mov      es, ax
  0000:141B  8b7604            mov      si, word ptr [bp + 4]
  0000:141E  8b7e06            mov      di, word ptr [bp + 6]
  0000:1421  33c0              xor      ax, ax
  0000:1423  b9ffff            mov      cx, 0xffff
  0000:1426  f2ae              repne scasb al, byte ptr es:[di]
  0000:1428  f7d1              not      cx
  0000:142A  2bf9              sub      di, cx
  0000:142C  f3a6              repe cmpsb byte ptr [si], byte ptr es:[di]
  0000:142E  7405              je       0x1435  ; -> loc_0000_1435
  0000:1430  1bc0              sbb      ax, ax
  0000:1432  1dffff            sbb      ax, 0xffff

loc_0000_1435:
  0000:1435  8bf3              mov      si, bx
  0000:1437  8bfa              mov      di, dx
  0000:1439  5d                pop      bp
  0000:143A  c3                ret
  0000:143B  db 00                                              ; |.|

; --- alarm_strlen ---
; String length (returns character count)
alarm_strlen:  ; (sub_0000_143C)
  0000:143C  55                push     bp
  0000:143D  8bec              mov      bp, sp
  0000:143F  8bd7              mov      dx, di
  0000:1441  8cd8              mov      ax, ds
  0000:1443  8ec0              mov      es, ax
  0000:1445  8b7e04            mov      di, word ptr [bp + 4]
  0000:1448  33c0              xor      ax, ax
  0000:144A  b9ffff            mov      cx, 0xffff
  0000:144D  f2ae              repne scasb al, byte ptr es:[di]
  0000:144F  f7d1              not      cx
  0000:1451  49                dec      cx
  0000:1452  91                xchg     cx, ax
  0000:1453  8bfa              mov      di, dx
  0000:1455  5d                pop      bp
  0000:1456  c3                ret
  0000:1457  db 00                                              ; |.|

; --- alarm_strncpy ---
; String copy with max length (dest, src, maxlen)
alarm_strncpy:  ; (sub_0000_1458)
  0000:1458  55                push     bp
  0000:1459  8bec              mov      bp, sp
  0000:145B  57                push     di
  0000:145C  56                push     si
  0000:145D  1e                push     ds
  0000:145E  07                pop      es
  0000:145F  8b7e04            mov      di, word ptr [bp + 4]
  0000:1462  8b7606            mov      si, word ptr [bp + 6]
  0000:1465  8bdf              mov      bx, di
  0000:1467  8b4e08            mov      cx, word ptr [bp + 8]
  0000:146A  e30c              jcxz     0x1478  ; -> loc_0000_1478
  0000:146C  ac                lodsb    al, byte ptr [si]
  0000:146D  0ac0              or       al, al
  0000:146F  7403              je       0x1474  ; -> loc_0000_1474
  0000:1471  aa                stosb    byte ptr es:[di], al
  0000:1472  e2f8              loop     0x146c

loc_0000_1474:
  0000:1474  32c0              xor      al, al
  0000:1476  f3aa              rep stosb byte ptr es:[di], al

loc_0000_1478:
  0000:1478  8bc3              mov      ax, bx
  0000:147A  5e                pop      si
  0000:147B  5f                pop      di
  0000:147C  8be5              mov      sp, bp
  0000:147E  5d                pop      bp
  0000:147F  c3                ret

; --- alarm_strncmp ---
; String comparison with max length (s1, s2, maxlen)
alarm_strncmp:  ; (sub_0000_1480)
  0000:1480  55                push     bp
  0000:1481  8bec              mov      bp, sp
  0000:1483  57                push     di
  0000:1484  56                push     si
  0000:1485  1e                push     ds
  0000:1486  07                pop      es
  0000:1487  8b4e08            mov      cx, word ptr [bp + 8]
  0000:148A  e326              jcxz     0x14b2  ; -> loc_0000_14B2
  0000:148C  8bd9              mov      bx, cx
  0000:148E  8b7e04            mov      di, word ptr [bp + 4]
  0000:1491  8bf7              mov      si, di
  0000:1493  33c0              xor      ax, ax
  0000:1495  f2ae              repne scasb al, byte ptr es:[di]
  0000:1497  f7d9              neg      cx
  0000:1499  03cb              add      cx, bx
  0000:149B  8bfe              mov      di, si
  0000:149D  8b7606            mov      si, word ptr [bp + 6]
  0000:14A0  f3a6              repe cmpsb byte ptr [si], byte ptr es:[di]
  0000:14A2  8a44ff            mov      al, byte ptr [si - 1]
  0000:14A5  33c9              xor      cx, cx
  0000:14A7  3a45ff            cmp      al, byte ptr [di - 1]
  0000:14AA  7704              ja       0x14b0  ; -> loc_0000_14B0
  0000:14AC  7404              je       0x14b2  ; -> loc_0000_14B2
  0000:14AE  49                dec      cx
  0000:14AF  49                dec      cx

loc_0000_14B0:
  0000:14B0  f7d1              not      cx

loc_0000_14B2:
  0000:14B2  8bc1              mov      ax, cx
  0000:14B4  5e                pop      si
  0000:14B5  5f                pop      di
  0000:14B6  8be5              mov      sp, bp
  0000:14B8  5d                pop      bp
  0000:14B9  c3                ret

; --- alarm_printf ---
; Formatted output (printf-like, writes to stream)
alarm_printf:  ; (sub_0000_14BA)
  0000:14BA  55                push     bp
  0000:14BB  8bec              mov      bp, sp
  0000:14BD  83ec08            sub      sp, 8
  0000:14C0  57                push     di
  0000:14C1  56                push     si
  0000:14C2  be7202            mov      si, 0x272
  0000:14C5  ff7604            push     word ptr [bp + 4]
  0000:14C8  e871ff            call     0x143c  ; -> sub_0000_143C  ; alarm_strlen
  0000:14CB  83c402            add      sp, 2
  0000:14CE  8bf8              mov      di, ax
  0000:14D0  56                push     si
  0000:14D1  e8fc04            call     0x19d0  ; -> sub_0000_19D0  ; alarm_openStreamBuffer
  0000:14D4  83c402            add      sp, 2
  0000:14D7  8946fe            mov      word ptr [bp - 2], ax
  0000:14DA  56                push     si
  0000:14DB  57                push     di
  0000:14DC  b80100            mov      ax, 1
  0000:14DF  50                push     ax
  0000:14E0  ff7604            push     word ptr [bp + 4]
  0000:14E3  e85802            call     0x173e  ; -> sub_0000_173E  ; alarm_fwrite
  0000:14E6  83c408            add      sp, 8
  0000:14E9  8946fa            mov      word ptr [bp - 6], ax
  0000:14EC  56                push     si
  0000:14ED  ff76fe            push     word ptr [bp - 2]
  0000:14F0  e86105            call     0x1a54  ; -> sub_0000_1A54  ; alarm_closeStream
  0000:14F3  83c404            add      sp, 4
  0000:14F6  397efa            cmp      word ptr [bp - 6], di
  0000:14F9  751f              jne      0x151a  ; -> loc_0000_151A
  0000:14FB  ff4c02            dec      word ptr [si + 2]
  0000:14FE  780a              js       0x150a  ; -> loc_0000_150A
  0000:1500  b00a              mov      al, 0xa
  0000:1502  8b1c              mov      bx, word ptr [si]
  0000:1504  ff04              inc      word ptr [si]
  0000:1506  8807              mov      byte ptr [bx], al
  0000:1508  eb0b              jmp      0x1515  ; -> loc_0000_1515

loc_0000_150A:
  0000:150A  56                push     si
  0000:150B  b80a00            mov      ax, 0xa
  0000:150E  50                push     ax
  0000:150F  e86803            call     0x187a  ; -> sub_0000_187A  ; alarm_flushAndWrite
  0000:1512  83c404            add      sp, 4

loc_0000_1515:
  0000:1515  2bc0              sub      ax, ax
  0000:1517  eb04              jmp      0x151d  ; -> loc_0000_151D
  0000:1519  db 90                                              ; |.|

loc_0000_151A:
  0000:151A  b8ffff            mov      ax, 0xffff

loc_0000_151D:
  0000:151D  5e                pop      si
  0000:151E  5f                pop      di
  0000:151F  8be5              mov      sp, bp
  0000:1521  5d                pop      bp
  0000:1522  c3                ret
  0000:1523  db 90                                              ; |.|

; --- alarm_memcpy ---
; Memory copy (far src/dest, count) via rep movsb
alarm_memcpy:  ; (sub_0000_1524)
  0000:1524  55                push     bp
  0000:1525  8bec              mov      bp, sp
  0000:1527  56                push     si
  0000:1528  57                push     di
  0000:1529  1e                push     ds
  0000:152A  8e5e04            mov      ds, word ptr [bp + 4]
  0000:152D  8b7606            mov      si, word ptr [bp + 6]
  0000:1530  8e4608            mov      es, word ptr [bp + 8]
  0000:1533  8b7e0a            mov      di, word ptr [bp + 0xa]
  0000:1536  8b4e0c            mov      cx, word ptr [bp + 0xc]
  0000:1539  f3a4              rep movsb byte ptr es:[di], byte ptr [si]
  0000:153B  1f                pop      ds
  0000:153C  5f                pop      di
  0000:153D  5e                pop      si
  0000:153E  8be5              mov      sp, bp
  0000:1540  5d                pop      bp
  0000:1541  c3                ret

; --- alarm_getCurrentDateTime ---
; Get current date/time as 32-bit day+time value
alarm_getCurrentDateTime:  ; (sub_0000_1542)
  0000:1542  55                push     bp
  0000:1543  8bec              mov      bp, sp
  0000:1545  56                push     si
  0000:1546  b42a              mov      ah, 0x2a
  0000:1548  cd21              int      0x21  ; INT 21h/2Ah: Get date
  0000:154A  8bda              mov      bx, dx
  0000:154C  8bf1              mov      si, cx
  0000:154E  b42c              mov      ah, 0x2c
  0000:1550  cd21              int      0x21  ; INT 21h/2Ch: Get time
  0000:1552  b400              mov      ah, 0
  0000:1554  8ac6              mov      al, dh
  0000:1556  50                push     ax
  0000:1557  8ac1              mov      al, cl
  0000:1559  50                push     ax
  0000:155A  8ac5              mov      al, ch
  0000:155C  50                push     ax
  0000:155D  50                push     ax
  0000:155E  b42a              mov      ah, 0x2a
  0000:1560  cd21              int      0x21  ; INT 21h/2Ah: Get date
  0000:1562  3bda              cmp      bx, dx
  0000:1564  58                pop      ax
  0000:1565  7408              je       0x156f  ; -> loc_0000_156F
  0000:1567  3c17              cmp      al, 0x17
  0000:1569  7504              jne      0x156f  ; -> loc_0000_156F
  0000:156B  8bd3              mov      dx, bx
  0000:156D  8bce              mov      cx, si

loc_0000_156F:
  0000:156F  b400              mov      ah, 0
  0000:1571  8ac2              mov      al, dl
  0000:1573  50                push     ax
  0000:1574  8ac6              mov      al, dh
  0000:1576  50                push     ax
  0000:1577  81e9bc07          sub      cx, 0x7bc
  0000:157B  51                push     cx
  0000:157C  e86b05            call     0x1aea  ; -> sub_0000_1AEA  ; alarm_dateToTicks
  0000:157F  83c40c            add      sp, 0xc
  0000:1582  837e0400          cmp      word ptr [bp + 4], 0
  0000:1586  7408              je       0x1590  ; -> loc_0000_1590
  0000:1588  8b5e04            mov      bx, word ptr [bp + 4]
  0000:158B  895702            mov      word ptr [bx + 2], dx
  0000:158E  8907              mov      word ptr [bx], ax

loc_0000_1590:
  0000:1590  5e                pop      si
  0000:1591  5d                pop      bp
  0000:1592  c3                ret
  0000:1593  db 00                                              ; |.|

; --- alarm_strchr ---
; Find character in string (returns pointer or 0)
alarm_strchr:  ; (sub_0000_1594)
  0000:1594  55                push     bp
  0000:1595  8bec              mov      bp, sp
  0000:1597  57                push     di
  0000:1598  8b7e04            mov      di, word ptr [bp + 4]
  0000:159B  1e                push     ds
  0000:159C  07                pop      es
  0000:159D  8bdf              mov      bx, di
  0000:159F  33c0              xor      ax, ax
  0000:15A1  b9ffff            mov      cx, 0xffff
  0000:15A4  f2ae              repne scasb al, byte ptr es:[di]
  0000:15A6  41                inc      cx
  0000:15A7  f7d9              neg      cx
  0000:15A9  8a4606            mov      al, byte ptr [bp + 6]
  0000:15AC  8bfb              mov      di, bx
  0000:15AE  f2ae              repne scasb al, byte ptr es:[di]
  0000:15B0  4f                dec      di
  0000:15B1  3805              cmp      byte ptr [di], al
  0000:15B3  7402              je       0x15b7  ; -> loc_0000_15B7
  0000:15B5  33ff              xor      di, di

loc_0000_15B7:
  0000:15B7  8bc7              mov      ax, di
  0000:15B9  5f                pop      di
  0000:15BA  8be5              mov      sp, bp
  0000:15BC  5d                pop      bp
  0000:15BD  c3                ret

; --- alarm_getKey ---
; Get keyboard input via INT 16h
alarm_getKey:  ; (sub_0000_15BE)
  0000:15BE  55                push     bp
  0000:15BF  8bec              mov      bp, sp
  0000:15C1  8a6604            mov      ah, byte ptr [bp + 4]
  0000:15C4  cd16              int      0x16  ; INT 16h
  0000:15C6  7508              jne      0x15d0  ; -> loc_0000_15D0
  0000:15C8  807e0401          cmp      byte ptr [bp + 4], 1
  0000:15CC  7502              jne      0x15d0  ; -> loc_0000_15D0
  0000:15CE  33c0              xor      ax, ax

loc_0000_15D0:
  0000:15D0  5d                pop      bp
  0000:15D1  c3                ret

; --- alarm_getInterruptVector ---
; Get interrupt vector via INT 21h/35h
alarm_getInterruptVector:  ; (sub_0000_15D2)
  0000:15D2  55                push     bp
  0000:15D3  8bec              mov      bp, sp
  0000:15D5  8b4604            mov      ax, word ptr [bp + 4]
  0000:15D8  b435              mov      ah, 0x35
  0000:15DA  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:15DC  8cc2              mov      dx, es
  0000:15DE  8bc3              mov      ax, bx
  0000:15E0  8be5              mov      sp, bp
  0000:15E2  5d                pop      bp
  0000:15E3  c3                ret

; --- alarm_terminateResident ---
; Terminate and stay resident via INT 21h/31h
alarm_terminateResident:  ; (sub_0000_15E4)
  0000:15E4  55                push     bp
  0000:15E5  8bec              mov      bp, sp
  0000:15E7  8b4604            mov      ax, word ptr [bp + 4]
  0000:15EA  8b5606            mov      dx, word ptr [bp + 6]
  0000:15ED  b431              mov      ah, 0x31
  0000:15EF  cd21              int      0x21  ; INT 21h/31h: TSR (keep process)
  0000:15F1  8be5              mov      sp, bp
  0000:15F3  5d                pop      bp
  0000:15F4  c3                ret
  0000:15F5  db 00                                              ; |.|

; --- alarm_setInterruptVector ---
; Set interrupt vector via INT 21h/25h
alarm_setInterruptVector:  ; (sub_0000_15F6)
  0000:15F6  55                push     bp
  0000:15F7  8bec              mov      bp, sp
  0000:15F9  8b4604            mov      ax, word ptr [bp + 4]
  0000:15FC  1e                push     ds
  0000:15FD  c55606            lds      dx, ptr [bp + 6]
  0000:1600  b425              mov      ah, 0x25
  0000:1602  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:1604  1f                pop      ds
  0000:1605  33c0              xor      ax, ax
  0000:1607  8be5              mov      sp, bp
  0000:1609  5d                pop      bp
  0000:160A  c3                ret
  0000:160B  db 00                                              ; |.|

; --- alarm_divSigned32 ---
; Signed 32-bit division (dividend/divisor -> quotient)
alarm_divSigned32:  ; (sub_0000_160C)
  0000:160C  55                push     bp
  0000:160D  8bec              mov      bp, sp
  0000:160F  57                push     di
  0000:1610  56                push     si
  0000:1611  53                push     bx
  0000:1612  33ff              xor      di, di
  0000:1614  8b4606            mov      ax, word ptr [bp + 6]
  0000:1617  0bc0              or       ax, ax
  0000:1619  7d11              jge      0x162c  ; -> loc_0000_162C
  0000:161B  47                inc      di
  0000:161C  8b5604            mov      dx, word ptr [bp + 4]
  0000:161F  f7d8              neg      ax
  0000:1621  f7da              neg      dx
  0000:1623  1d0000            sbb      ax, 0
  0000:1626  894606            mov      word ptr [bp + 6], ax
  0000:1629  895604            mov      word ptr [bp + 4], dx

loc_0000_162C:
  0000:162C  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:162F  0bc0              or       ax, ax
  0000:1631  7d11              jge      0x1644  ; -> loc_0000_1644
  0000:1633  47                inc      di
  0000:1634  8b5608            mov      dx, word ptr [bp + 8]
  0000:1637  f7d8              neg      ax
  0000:1639  f7da              neg      dx
  0000:163B  1d0000            sbb      ax, 0
  0000:163E  89460a            mov      word ptr [bp + 0xa], ax
  0000:1641  895608            mov      word ptr [bp + 8], dx

loc_0000_1644:
  0000:1644  0bc0              or       ax, ax
  0000:1646  7515              jne      0x165d  ; -> loc_0000_165D
  0000:1648  8b4e08            mov      cx, word ptr [bp + 8]
  0000:164B  8b4606            mov      ax, word ptr [bp + 6]
  0000:164E  33d2              xor      dx, dx
  0000:1650  f7f1              div      cx
  0000:1652  8bd8              mov      bx, ax
  0000:1654  8b4604            mov      ax, word ptr [bp + 4]
  0000:1657  f7f1              div      cx
  0000:1659  8bd3              mov      dx, bx
  0000:165B  eb38              jmp      0x1695  ; -> loc_0000_1695

loc_0000_165D:
  0000:165D  8bd8              mov      bx, ax
  0000:165F  8b4e08            mov      cx, word ptr [bp + 8]
  0000:1662  8b5606            mov      dx, word ptr [bp + 6]
  0000:1665  8b4604            mov      ax, word ptr [bp + 4]

loc_0000_1668:
  0000:1668  d1eb              shr      bx, 1
  0000:166A  d1d9              rcr      cx, 1
  0000:166C  d1ea              shr      dx, 1
  0000:166E  d1d8              rcr      ax, 1
  0000:1670  0bdb              or       bx, bx
  0000:1672  75f4              jne      0x1668  ; -> loc_0000_1668
  0000:1674  f7f1              div      cx
  0000:1676  8bf0              mov      si, ax
  0000:1678  f7660a            mul      word ptr [bp + 0xa]
  0000:167B  91                xchg     cx, ax
  0000:167C  8b4608            mov      ax, word ptr [bp + 8]
  0000:167F  f7e6              mul      si
  0000:1681  03d1              add      dx, cx
  0000:1683  720c              jb       0x1691  ; -> loc_0000_1691
  0000:1685  3b5606            cmp      dx, word ptr [bp + 6]
  0000:1688  7707              ja       0x1691  ; -> loc_0000_1691
  0000:168A  7206              jb       0x1692  ; -> loc_0000_1692
  0000:168C  3b4604            cmp      ax, word ptr [bp + 4]
  0000:168F  7601              jbe      0x1692  ; -> loc_0000_1692

loc_0000_1691:
  0000:1691  4e                dec      si

loc_0000_1692:
  0000:1692  33d2              xor      dx, dx
  0000:1694  96                xchg     si, ax

loc_0000_1695:
  0000:1695  4f                dec      di
  0000:1696  7507              jne      0x169f  ; -> loc_0000_169F
  0000:1698  f7da              neg      dx
  0000:169A  f7d8              neg      ax
  0000:169C  83da00            sbb      dx, 0

loc_0000_169F:
  0000:169F  5b                pop      bx
  0000:16A0  5e                pop      si
  0000:16A1  5f                pop      di
  0000:16A2  8be5              mov      sp, bp
  0000:16A4  5d                pop      bp
  0000:16A5  c20800            ret      8

; --- alarm_mulUnsigned32 ---
; Unsigned 32-bit multiplication
alarm_mulUnsigned32:  ; (sub_0000_16A8)
  0000:16A8  55                push     bp
  0000:16A9  8bec              mov      bp, sp
  0000:16AB  8b4606            mov      ax, word ptr [bp + 6]
  0000:16AE  8b5e0a            mov      bx, word ptr [bp + 0xa]
  0000:16B1  0bd8              or       bx, ax
  0000:16B3  8b5e08            mov      bx, word ptr [bp + 8]
  0000:16B6  750b              jne      0x16c3  ; -> loc_0000_16C3
  0000:16B8  8b4604            mov      ax, word ptr [bp + 4]
  0000:16BB  f7e3              mul      bx
  0000:16BD  8be5              mov      sp, bp
  0000:16BF  5d                pop      bp
  0000:16C0  c20800            ret      8

loc_0000_16C3:
  0000:16C3  f7e3              mul      bx
  0000:16C5  8bc8              mov      cx, ax
  0000:16C7  8b4604            mov      ax, word ptr [bp + 4]
  0000:16CA  f7660a            mul      word ptr [bp + 0xa]
  0000:16CD  03c8              add      cx, ax
  0000:16CF  8b4604            mov      ax, word ptr [bp + 4]
  0000:16D2  f7e3              mul      bx
  0000:16D4  03d1              add      dx, cx
  0000:16D6  8be5              mov      sp, bp
  0000:16D8  5d                pop      bp
  0000:16D9  c20800            ret      8

; --- alarm_divUnsigned32 ---
; Unsigned 32-bit division
alarm_divUnsigned32:  ; (sub_0000_16DC)
  0000:16DC  55                push     bp
  0000:16DD  8bec              mov      bp, sp
  0000:16DF  53                push     bx
  0000:16E0  56                push     si
  0000:16E1  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:16E4  0bc0              or       ax, ax
  0000:16E6  7515              jne      0x16fd  ; -> loc_0000_16FD
  0000:16E8  8b4e08            mov      cx, word ptr [bp + 8]
  0000:16EB  8b4606            mov      ax, word ptr [bp + 6]
  0000:16EE  33d2              xor      dx, dx
  0000:16F0  f7f1              div      cx
  0000:16F2  8bd8              mov      bx, ax
  0000:16F4  8b4604            mov      ax, word ptr [bp + 4]
  0000:16F7  f7f1              div      cx
  0000:16F9  8bd3              mov      dx, bx
  0000:16FB  eb38              jmp      0x1735  ; -> loc_0000_1735

loc_0000_16FD:
  0000:16FD  8bc8              mov      cx, ax
  0000:16FF  8b5e08            mov      bx, word ptr [bp + 8]
  0000:1702  8b5606            mov      dx, word ptr [bp + 6]
  0000:1705  8b4604            mov      ax, word ptr [bp + 4]

loc_0000_1708:
  0000:1708  d1e9              shr      cx, 1
  0000:170A  d1db              rcr      bx, 1
  0000:170C  d1ea              shr      dx, 1
  0000:170E  d1d8              rcr      ax, 1
  0000:1710  0bc9              or       cx, cx
  0000:1712  75f4              jne      0x1708  ; -> loc_0000_1708
  0000:1714  f7f3              div      bx
  0000:1716  8bf0              mov      si, ax
  0000:1718  f7660a            mul      word ptr [bp + 0xa]
  0000:171B  91                xchg     cx, ax
  0000:171C  8b4608            mov      ax, word ptr [bp + 8]
  0000:171F  f7e6              mul      si
  0000:1721  03d1              add      dx, cx
  0000:1723  720c              jb       0x1731  ; -> loc_0000_1731
  0000:1725  3b5606            cmp      dx, word ptr [bp + 6]
  0000:1728  7707              ja       0x1731  ; -> loc_0000_1731
  0000:172A  7206              jb       0x1732  ; -> loc_0000_1732
  0000:172C  3b4604            cmp      ax, word ptr [bp + 4]
  0000:172F  7601              jbe      0x1732  ; -> loc_0000_1732

loc_0000_1731:
  0000:1731  4e                dec      si

loc_0000_1732:
  0000:1732  33d2              xor      dx, dx
  0000:1734  96                xchg     si, ax

loc_0000_1735:
  0000:1735  5e                pop      si
  0000:1736  5b                pop      bx
  0000:1737  8be5              mov      sp, bp
  0000:1739  5d                pop      bp
  0000:173A  c20800            ret      8
  0000:173D  db 00                                              ; |.|

; --- alarm_fwrite ---
; Write data to file stream (buffered output)
alarm_fwrite:  ; (sub_0000_173E)
  0000:173E  55                push     bp
  0000:173F  8bec              mov      bp, sp
  0000:1741  83ec08            sub      sp, 8
  0000:1744  57                push     di
  0000:1745  56                push     si
  0000:1746  8b7604            mov      si, word ptr [bp + 4]
  0000:1749  8b7e0a            mov      di, word ptr [bp + 0xa]
  0000:174C  8b4606            mov      ax, word ptr [bp + 6]
  0000:174F  f76608            mul      word ptr [bp + 8]
  0000:1752  8946fe            mov      word ptr [bp - 2], ax
  0000:1755  8946fc            mov      word ptr [bp - 4], ax
  0000:1758  837e0600          cmp      word ptr [bp + 6], 0
  0000:175C  7406              je       0x1764  ; -> loc_0000_1764
  0000:175E  837e0800          cmp      word ptr [bp + 8], 0
  0000:1762  7506              jne      0x176a  ; -> loc_0000_176A

loc_0000_1764:
  0000:1764  2bc0              sub      ax, ax
  0000:1766  e90b01            jmp      0x1874  ; -> loc_0000_1874
  0000:1769  db 90                                              ; |.|

loc_0000_176A:
  0000:176A  f645060c          test     byte ptr [di + 6], 0xc
  0000:176E  7565              jne      0x17d5  ; -> loc_0000_17D5
  0000:1770  8bdf              mov      bx, di
  0000:1772  81eb6a02          sub      bx, 0x26a
  0000:1776  b103              mov      cl, 3
  0000:1778  d3fb              sar      bx, cl
  0000:177A  8bc3              mov      ax, bx
  0000:177C  d1e3              shl      bx, 1
  0000:177E  03d8              add      bx, ax
  0000:1780  d1e3              shl      bx, 1
  0000:1782  f6870a0301        test     byte ptr [bx + 0x30a], 1
  0000:1787  754c              jne      0x17d5  ; -> loc_0000_17D5
  0000:1789  f746fcff01        test     word ptr [bp - 4], 0x1ff
  0000:178E  7520              jne      0x17b0  ; -> loc_0000_17B0
  0000:1790  ff76fc            push     word ptr [bp - 4]
  0000:1793  56                push     si
  0000:1794  8a4507            mov      al, byte ptr [di + 7]
  0000:1797  98                cwde
  0000:1798  50                push     ax
  0000:1799  e8b805            call     0x1d54  ; -> sub_0000_1D54  ; alarm_writeToFile
  0000:179C  83c406            add      sp, 6
  0000:179F  8946f8            mov      word ptr [bp - 8], ax
  0000:17A2  3dffff            cmp      ax, 0xffff
  0000:17A5  74bd              je       0x1764  ; -> loc_0000_1764

loc_0000_17A7:
  0000:17A7  2bd2              sub      dx, dx
  0000:17A9  f77606            div      word ptr [bp + 6]
  0000:17AC  e9c500            jmp      0x1874  ; -> loc_0000_1874
  0000:17AF  db 90                                              ; |.|

loc_0000_17B0:
  0000:17B0  ff4d02            dec      word ptr [di + 2]
  0000:17B3  780b              js       0x17c0  ; -> loc_0000_17C0
  0000:17B5  8a04              mov      al, byte ptr [si]
  0000:17B7  8b1d              mov      bx, word ptr [di]
  0000:17B9  ff05              inc      word ptr [di]
  0000:17BB  8807              mov      byte ptr [bx], al
  0000:17BD  eb0c              jmp      0x17cb  ; -> loc_0000_17CB
  0000:17BF  db 90                                              ; |.|

loc_0000_17C0:
  0000:17C0  57                push     di
  0000:17C1  8a04              mov      al, byte ptr [si]
  0000:17C3  98                cwde
  0000:17C4  50                push     ax
  0000:17C5  e8b200            call     0x187a  ; -> sub_0000_187A  ; alarm_flushAndWrite
  0000:17C8  83c404            add      sp, 4

loc_0000_17CB:
  0000:17CB  f6450620          test     byte ptr [di + 6], 0x20
  0000:17CF  7593              jne      0x1764  ; -> loc_0000_1764
  0000:17D1  46                inc      si
  0000:17D2  ff4efc            dec      word ptr [bp - 4]

loc_0000_17D5:
  0000:17D5  f6450608          test     byte ptr [di + 6], 8
  0000:17D9  7540              jne      0x181b  ; -> loc_0000_181B
  0000:17DB  8bdf              mov      bx, di
  0000:17DD  81eb6a02          sub      bx, 0x26a
  0000:17E1  b103              mov      cl, 3
  0000:17E3  d3fb              sar      bx, cl
  0000:17E5  8bc3              mov      ax, bx
  0000:17E7  d1e3              shl      bx, 1
  0000:17E9  03d8              add      bx, ax
  0000:17EB  d1e3              shl      bx, 1
  0000:17ED  f6870a0301        test     byte ptr [bx + 0x30a], 1
  0000:17F2  745c              je       0x1850  ; -> loc_0000_1850
  0000:17F4  eb25              jmp      0x181b  ; -> loc_0000_181B

loc_0000_17F6:
  0000:17F6  ff4d02            dec      word ptr [di + 2]
  0000:17F9  780b              js       0x1806  ; -> loc_0000_1806
  0000:17FB  8a04              mov      al, byte ptr [si]
  0000:17FD  8b1d              mov      bx, word ptr [di]
  0000:17FF  ff05              inc      word ptr [di]
  0000:1801  8807              mov      byte ptr [bx], al
  0000:1803  eb0c              jmp      0x1811  ; -> loc_0000_1811
  0000:1805  db 90                                              ; |.|

loc_0000_1806:
  0000:1806  57                push     di
  0000:1807  8a04              mov      al, byte ptr [si]
  0000:1809  98                cwde
  0000:180A  50                push     ax
  0000:180B  e86c00            call     0x187a  ; -> sub_0000_187A  ; alarm_flushAndWrite
  0000:180E  83c404            add      sp, 4

loc_0000_1811:
  0000:1811  f6450620          test     byte ptr [di + 6], 0x20
  0000:1815  7553              jne      0x186a  ; -> loc_0000_186A
  0000:1817  46                inc      si
  0000:1818  ff4efc            dec      word ptr [bp - 4]

loc_0000_181B:
  0000:181B  837efc00          cmp      word ptr [bp - 4], 0
  0000:181F  7449              je       0x186a  ; -> loc_0000_186A
  0000:1821  837d0200          cmp      word ptr [di + 2], 0
  0000:1825  74cf              je       0x17f6  ; -> loc_0000_17F6
  0000:1827  8b4502            mov      ax, word ptr [di + 2]
  0000:182A  2b46fc            sub      ax, word ptr [bp - 4]
  0000:182D  1bc9              sbb      cx, cx
  0000:182F  23c1              and      ax, cx
  0000:1831  0346fc            add      ax, word ptr [bp - 4]
  0000:1834  8946fa            mov      word ptr [bp - 6], ax
  0000:1837  50                push     ax
  0000:1838  56                push     si
  0000:1839  ff35              push     word ptr [di]
  0000:183B  e8ec07            call     0x202a  ; -> sub_0000_202A  ; alarm_memcpyForward
  0000:183E  83c406            add      sp, 6
  0000:1841  8b46fa            mov      ax, word ptr [bp - 6]
  0000:1844  0105              add      word ptr [di], ax
  0000:1846  03f0              add      si, ax
  0000:1848  2946fc            sub      word ptr [bp - 4], ax
  0000:184B  294502            sub      word ptr [di + 2], ax
  0000:184E  ebcb              jmp      0x181b  ; -> loc_0000_181B

loc_0000_1850:
  0000:1850  ff76fc            push     word ptr [bp - 4]
  0000:1853  56                push     si
  0000:1854  8a4507            mov      al, byte ptr [di + 7]
  0000:1857  98                cwde
  0000:1858  50                push     ax
  0000:1859  e8f804            call     0x1d54  ; -> sub_0000_1D54  ; alarm_writeToFile
  0000:185C  83c406            add      sp, 6
  0000:185F  8946f8            mov      word ptr [bp - 8], ax
  0000:1862  3dffff            cmp      ax, 0xffff
  0000:1865  7403              je       0x186a  ; -> loc_0000_186A
  0000:1867  2946fc            sub      word ptr [bp - 4], ax

loc_0000_186A:
  0000:186A  8b46fe            mov      ax, word ptr [bp - 2]
  0000:186D  2b46fc            sub      ax, word ptr [bp - 4]
  0000:1870  e934ff            jmp      0x17a7  ; -> loc_0000_17A7
  0000:1873  db 90                                              ; |.|

loc_0000_1874:
  0000:1874  5e                pop      si
  0000:1875  5f                pop      di
  0000:1876  8be5              mov      sp, bp
  0000:1878  5d                pop      bp
  0000:1879  c3                ret

; --- alarm_flushAndWrite ---
; Flush stream buffer and write character
alarm_flushAndWrite:  ; (sub_0000_187A)
  0000:187A  55                push     bp
  0000:187B  8bec              mov      bp, sp
  0000:187D  83ec08            sub      sp, 8
  0000:1880  57                push     di
  0000:1881  56                push     si
  0000:1882  8b7606            mov      si, word ptr [bp + 6]
  0000:1885  8a4407            mov      al, byte ptr [si + 7]
  0000:1888  98                cwde
  0000:1889  8946fa            mov      word ptr [bp - 6], ax
  0000:188C  8bc6              mov      ax, si
  0000:188E  2d6a02            sub      ax, 0x26a
  0000:1891  b103              mov      cl, 3
  0000:1893  d3f8              sar      ax, cl
  0000:1895  8bc8              mov      cx, ax
  0000:1897  d1e0              shl      ax, 1
  0000:1899  03c1              add      ax, cx
  0000:189B  d1e0              shl      ax, 1
  0000:189D  050a03            add      ax, 0x30a
  0000:18A0  8946f8            mov      word ptr [bp - 8], ax
  0000:18A3  f6440683          test     byte ptr [si + 6], 0x83
  0000:18A7  7406              je       0x18af  ; -> loc_0000_18AF
  0000:18A9  f6440640          test     byte ptr [si + 6], 0x40
  0000:18AD  740b              je       0x18ba  ; -> loc_0000_18BA

loc_0000_18AF:
  0000:18AF  804c0620          or       byte ptr [si + 6], 0x20
  0000:18B3  b8ffff            mov      ax, 0xffff
  0000:18B6  e91001            jmp      0x19c9  ; -> loc_0000_19C9
  0000:18B9  db 90                                              ; |.|

loc_0000_18BA:
  0000:18BA  f6440601          test     byte ptr [si + 6], 1
  0000:18BE  75ef              jne      0x18af  ; -> loc_0000_18AF
  0000:18C0  804c0602          or       byte ptr [si + 6], 2
  0000:18C4  806406ef          and      byte ptr [si + 6], 0xef
  0000:18C8  2bc0              sub      ax, ax
  0000:18CA  894402            mov      word ptr [si + 2], ax
  0000:18CD  8bf8              mov      di, ax
  0000:18CF  897efc            mov      word ptr [bp - 4], di
  0000:18D2  f644060c          test     byte ptr [si + 6], 0xc
  0000:18D6  755f              jne      0x1937  ; -> loc_0000_1937
  0000:18D8  8bde              mov      bx, si
  0000:18DA  81eb6a02          sub      bx, 0x26a
  0000:18DE  b103              mov      cl, 3
  0000:18E0  d3fb              sar      bx, cl
  0000:18E2  8bc3              mov      ax, bx
  0000:18E4  d1e3              shl      bx, 1
  0000:18E6  03d8              add      bx, ax
  0000:18E8  d1e3              shl      bx, 1
  0000:18EA  f6870a0301        test     byte ptr [bx + 0x30a], 1
  0000:18EF  7546              jne      0x1937  ; -> loc_0000_1937
  0000:18F1  81fe7202          cmp      si, 0x272
  0000:18F5  7406              je       0x18fd  ; -> loc_0000_18FD
  0000:18F7  81fe7a02          cmp      si, 0x27a
  0000:18FB  7533              jne      0x1930  ; -> loc_0000_1930

loc_0000_18FD:
  0000:18FD  ff76fa            push     word ptr [bp - 6]
  0000:1900  e87905            call     0x1e7c  ; -> sub_0000_1E7C  ; alarm_isDeviceHandle
  0000:1903  83c402            add      sp, 2
  0000:1906  0bc0              or       ax, ax
  0000:1908  752d              jne      0x1937  ; -> loc_0000_1937
  0000:190A  ff068403          inc      word ptr [0x384]
  0000:190E  81fe7202          cmp      si, 0x272
  0000:1912  7506              jne      0x191a  ; -> loc_0000_191A
  0000:1914  b88c06            mov      ax, 0x68c
  0000:1917  eb04              jmp      0x191d  ; -> loc_0000_191D
  0000:1919  db 90                                              ; |.|

loc_0000_191A:
  0000:191A  b8a816            mov      ax, 0x16a8

loc_0000_191D:
  0000:191D  894404            mov      word ptr [si + 4], ax
  0000:1920  8904              mov      word ptr [si], ax
  0000:1922  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:1925  c747020002        mov      word ptr [bx + 2], 0x200
  0000:192A  c60701            mov      byte ptr [bx], 1
  0000:192D  eb08              jmp      0x1937  ; -> loc_0000_1937
  0000:192F  db 90                                              ; |.|

loc_0000_1930:
  0000:1930  56                push     si
  0000:1931  e8cc02            call     0x1c00  ; -> sub_0000_1C00  ; alarm_allocStreamBuffer
  0000:1934  83c402            add      sp, 2

loc_0000_1937:
  0000:1937  f6440608          test     byte ptr [si + 6], 8
  0000:193B  7519              jne      0x1956  ; -> loc_0000_1956
  0000:193D  8bde              mov      bx, si
  0000:193F  81eb6a02          sub      bx, 0x26a
  0000:1943  b103              mov      cl, 3
  0000:1945  d3fb              sar      bx, cl
  0000:1947  8bc3              mov      ax, bx
  0000:1949  d1e3              shl      bx, 1
  0000:194B  03d8              add      bx, ax
  0000:194D  d1e3              shl      bx, 1
  0000:194F  f6870a0301        test     byte ptr [bx + 0x30a], 1
  0000:1954  7450              je       0x19a6  ; -> loc_0000_19A6

loc_0000_1956:
  0000:1956  8b3c              mov      di, word ptr [si]
  0000:1958  2b7c04            sub      di, word ptr [si + 4]
  0000:195B  8b4404            mov      ax, word ptr [si + 4]
  0000:195E  40                inc      ax
  0000:195F  8904              mov      word ptr [si], ax
  0000:1961  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:1964  8b4702            mov      ax, word ptr [bx + 2]
  0000:1967  48                dec      ax
  0000:1968  894402            mov      word ptr [si + 2], ax
  0000:196B  0bff              or       di, di
  0000:196D  7e13              jle      0x1982  ; -> loc_0000_1982
  0000:196F  57                push     di
  0000:1970  ff7404            push     word ptr [si + 4]
  0000:1973  ff76fa            push     word ptr [bp - 6]
  0000:1976  e8db03            call     0x1d54  ; -> sub_0000_1D54  ; alarm_writeToFile
  0000:1979  83c406            add      sp, 6
  0000:197C  8946fc            mov      word ptr [bp - 4], ax
  0000:197F  eb1a              jmp      0x199b  ; -> loc_0000_199B
  0000:1981  db 90                                              ; |.|

loc_0000_1982:
  0000:1982  8b5efa            mov      bx, word ptr [bp - 6]
  0000:1985  f687f20120        test     byte ptr [bx + 0x1f2], 0x20
  0000:198A  740f              je       0x199b  ; -> loc_0000_199B
  0000:198C  b80200            mov      ax, 2
  0000:198F  50                push     ax
  0000:1990  2bc0              sub      ax, ax
  0000:1992  50                push     ax
  0000:1993  50                push     ax
  0000:1994  53                push     bx
  0000:1995  e84203            call     0x1cda  ; -> sub_0000_1CDA  ; alarm_seekFile
  0000:1998  83c408            add      sp, 8

loc_0000_199B:
  0000:199B  8b5c04            mov      bx, word ptr [si + 4]
  0000:199E  8a4604            mov      al, byte ptr [bp + 4]
  0000:19A1  8807              mov      byte ptr [bx], al
  0000:19A3  eb17              jmp      0x19bc  ; -> loc_0000_19BC
  0000:19A5  db 90                                              ; |.|

loc_0000_19A6:
  0000:19A6  bf0100            mov      di, 1
  0000:19A9  8bc7              mov      ax, di
  0000:19AB  50                push     ax
  0000:19AC  8d4604            lea      ax, [bp + 4]
  0000:19AF  50                push     ax
  0000:19B0  ff76fa            push     word ptr [bp - 6]
  0000:19B3  e89e03            call     0x1d54  ; -> sub_0000_1D54  ; alarm_writeToFile
  0000:19B6  83c406            add      sp, 6
  0000:19B9  8946fc            mov      word ptr [bp - 4], ax

loc_0000_19BC:
  0000:19BC  397efc            cmp      word ptr [bp - 4], di
  0000:19BF  7403              je       0x19c4  ; -> loc_0000_19C4
  0000:19C1  e9ebfe            jmp      0x18af  ; -> loc_0000_18AF

loc_0000_19C4:
  0000:19C4  8a4604            mov      al, byte ptr [bp + 4]
  0000:19C7  2ae4              sub      ah, ah

loc_0000_19C9:
  0000:19C9  5e                pop      si
  0000:19CA  5f                pop      di
  0000:19CB  8be5              mov      sp, bp
  0000:19CD  5d                pop      bp
  0000:19CE  c3                ret
  0000:19CF  db 90                                              ; |.|

; --- alarm_openStreamBuffer ---
; Open/initialize stream buffer for writing
alarm_openStreamBuffer:  ; (sub_0000_19D0)
  0000:19D0  55                push     bp
  0000:19D1  8bec              mov      bp, sp
  0000:19D3  83ec04            sub      sp, 4
  0000:19D6  56                push     si
  0000:19D7  8b7604            mov      si, word ptr [bp + 4]
  0000:19DA  ff068403          inc      word ptr [0x384]
  0000:19DE  81fe7202          cmp      si, 0x272
  0000:19E2  7508              jne      0x19ec  ; -> loc_0000_19EC
  0000:19E4  c746fe8c06        mov      word ptr [bp - 2], 0x68c
  0000:19E9  eb0c              jmp      0x19f7  ; -> loc_0000_19F7
  0000:19EB  db 90                                              ; |.|

loc_0000_19EC:
  0000:19EC  81fe7a02          cmp      si, 0x27a
  0000:19F0  7524              jne      0x1a16  ; -> loc_0000_1A16
  0000:19F2  c746fea816        mov      word ptr [bp - 2], 0x16a8

loc_0000_19F7:
  0000:19F7  f644060c          test     byte ptr [si + 6], 0xc
  0000:19FB  7519              jne      0x1a16  ; -> loc_0000_1A16
  0000:19FD  8bde              mov      bx, si
  0000:19FF  81eb6a02          sub      bx, 0x26a
  0000:1A03  b103              mov      cl, 3
  0000:1A05  d3fb              sar      bx, cl
  0000:1A07  8bc3              mov      ax, bx
  0000:1A09  d1e3              shl      bx, 1
  0000:1A0B  03d8              add      bx, ax
  0000:1A0D  d1e3              shl      bx, 1
  0000:1A0F  f6870a0301        test     byte ptr [bx + 0x30a], 1
  0000:1A14  7404              je       0x1a1a  ; -> loc_0000_1A1A

loc_0000_1A16:
  0000:1A16  2bc0              sub      ax, ax
  0000:1A18  eb35              jmp      0x1a4f  ; -> loc_0000_1A4F

loc_0000_1A1A:
  0000:1A1A  8bc6              mov      ax, si
  0000:1A1C  2d6a02            sub      ax, 0x26a
  0000:1A1F  b103              mov      cl, 3
  0000:1A21  d3f8              sar      ax, cl
  0000:1A23  8bc8              mov      cx, ax
  0000:1A25  d1e0              shl      ax, 1
  0000:1A27  03c1              add      ax, cx
  0000:1A29  d1e0              shl      ax, 1
  0000:1A2B  050a03            add      ax, 0x30a
  0000:1A2E  8946fc            mov      word ptr [bp - 4], ax
  0000:1A31  8b46fe            mov      ax, word ptr [bp - 2]
  0000:1A34  894404            mov      word ptr [si + 4], ax
  0000:1A37  8904              mov      word ptr [si], ax
  0000:1A39  8b5efc            mov      bx, word ptr [bp - 4]
  0000:1A3C  b80002            mov      ax, 0x200
  0000:1A3F  894702            mov      word ptr [bx + 2], ax
  0000:1A42  894402            mov      word ptr [si + 2], ax
  0000:1A45  c60701            mov      byte ptr [bx], 1
  0000:1A48  804c0602          or       byte ptr [si + 6], 2
  0000:1A4C  b80100            mov      ax, 1

loc_0000_1A4F:
  0000:1A4F  5e                pop      si
  0000:1A50  8be5              mov      sp, bp
  0000:1A52  5d                pop      bp
  0000:1A53  c3                ret

; --- alarm_closeStream ---
; Close output stream, flush remaining data
alarm_closeStream:  ; (sub_0000_1A54)
  0000:1A54  55                push     bp
  0000:1A55  8bec              mov      bp, sp
  0000:1A57  83ec02            sub      sp, 2
  0000:1A5A  56                push     si
  0000:1A5B  837e0400          cmp      word ptr [bp + 4], 0
  0000:1A5F  745b              je       0x1abc  ; -> loc_0000_1ABC
  0000:1A61  817e067202        cmp      word ptr [bp + 6], 0x272
  0000:1A66  7407              je       0x1a6f  ; -> loc_0000_1A6F
  0000:1A68  817e067a02        cmp      word ptr [bp + 6], 0x27a
  0000:1A6D  7576              jne      0x1ae5  ; -> loc_0000_1AE5

loc_0000_1A6F:
  0000:1A6F  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1A72  8a4707            mov      al, byte ptr [bx + 7]
  0000:1A75  98                cwde
  0000:1A76  50                push     ax
  0000:1A77  e80204            call     0x1e7c  ; -> sub_0000_1E7C  ; alarm_isDeviceHandle
  0000:1A7A  83c402            add      sp, 2
  0000:1A7D  0bc0              or       ax, ax
  0000:1A7F  7464              je       0x1ae5  ; -> loc_0000_1AE5
  0000:1A81  8b4606            mov      ax, word ptr [bp + 6]
  0000:1A84  2d6a02            sub      ax, 0x26a
  0000:1A87  b103              mov      cl, 3
  0000:1A89  d3f8              sar      ax, cl
  0000:1A8B  8bc8              mov      cx, ax
  0000:1A8D  d1e0              shl      ax, 1
  0000:1A8F  03c1              add      ax, cx
  0000:1A91  d1e0              shl      ax, 1
  0000:1A93  050a03            add      ax, 0x30a
  0000:1A96  8946fe            mov      word ptr [bp - 2], ax
  0000:1A99  ff7606            push     word ptr [bp + 6]
  0000:1A9C  e8cd01            call     0x1c6c  ; -> sub_0000_1C6C  ; alarm_flushStream
  0000:1A9F  83c402            add      sp, 2
  0000:1AA2  8b5efe            mov      bx, word ptr [bp - 2]
  0000:1AA5  c60700            mov      byte ptr [bx], 0
  0000:1AA8  c747020000        mov      word ptr [bx + 2], 0
  0000:1AAD  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1AB0  8bf3              mov      si, bx
  0000:1AB2  2bc0              sub      ax, ax
  0000:1AB4  8904              mov      word ptr [si], ax
  0000:1AB6  894704            mov      word ptr [bx + 4], ax
  0000:1AB9  eb2a              jmp      0x1ae5  ; -> loc_0000_1AE5
  0000:1ABB  db 90                                              ; |.|

loc_0000_1ABC:
  0000:1ABC  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1ABF  817f048c06        cmp      word ptr [bx + 4], 0x68c
  0000:1AC4  7407              je       0x1acd  ; -> loc_0000_1ACD
  0000:1AC6  817f04a816        cmp      word ptr [bx + 4], 0x16a8
  0000:1ACB  7518              jne      0x1ae5  ; -> loc_0000_1AE5

loc_0000_1ACD:
  0000:1ACD  8a4707            mov      al, byte ptr [bx + 7]
  0000:1AD0  98                cwde
  0000:1AD1  50                push     ax
  0000:1AD2  e8a703            call     0x1e7c  ; -> sub_0000_1E7C  ; alarm_isDeviceHandle
  0000:1AD5  83c402            add      sp, 2
  0000:1AD8  0bc0              or       ax, ax
  0000:1ADA  7409              je       0x1ae5  ; -> loc_0000_1AE5
  0000:1ADC  ff7606            push     word ptr [bp + 6]
  0000:1ADF  e88a01            call     0x1c6c  ; -> sub_0000_1C6C  ; alarm_flushStream
  0000:1AE2  83c402            add      sp, 2

loc_0000_1AE5:
  0000:1AE5  5e                pop      si
  0000:1AE6  8be5              mov      sp, bp
  0000:1AE8  5d                pop      bp
  0000:1AE9  c3                ret

; --- alarm_dateToTicks ---
; Convert date (year,month,day,hour,min,sec) to tick count
alarm_dateToTicks:  ; (sub_0000_1AEA)
  0000:1AEA  55                push     bp
  0000:1AEB  8bec              mov      bp, sp
  0000:1AED  83ec20            sub      sp, 0x20
  0000:1AF0  57                push     di
  0000:1AF1  56                push     si
  0000:1AF2  8b7604            mov      si, word ptr [bp + 4]
  0000:1AF5  b88051            mov      ax, 0x5180
  0000:1AF8  ba0100            mov      dx, 1
  0000:1AFB  52                push     dx
  0000:1AFC  50                push     ax
  0000:1AFD  8d4403            lea      ax, [si + 3]
  0000:1B00  99                cdq
  0000:1B01  33c2              xor      ax, dx
  0000:1B03  2bc2              sub      ax, dx
  0000:1B05  b90200            mov      cx, 2
  0000:1B08  d3f8              sar      ax, cl
  0000:1B0A  33c2              xor      ax, dx
  0000:1B0C  2bc2              sub      ax, dx
  0000:1B0E  99                cdq
  0000:1B0F  52                push     dx
  0000:1B10  50                push     ax
  0000:1B11  e894fb            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:1B14  8946ea            mov      word ptr [bp - 0x16], ax
  0000:1B17  8956ec            mov      word ptr [bp - 0x14], dx
  0000:1B1A  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1B1D  d1e3              shl      bx, 1
  0000:1B1F  8bbf9e03          mov      di, word ptr [bx + 0x39e]
  0000:1B23  8bc6              mov      ax, si
  0000:1B25  99                cdq
  0000:1B26  b90400            mov      cx, 4
  0000:1B29  f7f9              idiv     cx
  0000:1B2B  0bd2              or       dx, dx
  0000:1B2D  7507              jne      0x1b36  ; -> loc_0000_1B36
  0000:1B2F  837e0602          cmp      word ptr [bp + 6], 2
  0000:1B33  7e01              jle      0x1b36  ; -> loc_0000_1B36
  0000:1B35  47                inc      di

loc_0000_1B36:
  0000:1B36  b83c00            mov      ax, 0x3c
  0000:1B39  99                cdq
  0000:1B3A  52                push     dx
  0000:1B3B  50                push     ax
  0000:1B3C  8b460c            mov      ax, word ptr [bp + 0xc]
  0000:1B3F  99                cdq
  0000:1B40  52                push     dx
  0000:1B41  50                push     ax
  0000:1B42  e863fb            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:1B45  b9100e            mov      cx, 0xe10
  0000:1B48  2bdb              sub      bx, bx
  0000:1B4A  53                push     bx
  0000:1B4B  51                push     cx
  0000:1B4C  8bc8              mov      cx, ax
  0000:1B4E  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:1B51  8bda              mov      bx, dx
  0000:1B53  99                cdq
  0000:1B54  52                push     dx
  0000:1B55  50                push     ax
  0000:1B56  894ee4            mov      word ptr [bp - 0x1c], cx
  0000:1B59  895ee6            mov      word ptr [bp - 0x1a], bx
  0000:1B5C  e849fb            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:1B5F  b98051            mov      cx, 0x5180
  0000:1B62  bb0100            mov      bx, 1
  0000:1B65  53                push     bx
  0000:1B66  51                push     cx
  0000:1B67  8bc8              mov      cx, ax
  0000:1B69  b86d01            mov      ax, 0x16d
  0000:1B6C  8bda              mov      bx, dx
  0000:1B6E  f7ee              imul     si
  0000:1B70  8bd0              mov      dx, ax
  0000:1B72  8b4608            mov      ax, word ptr [bp + 8]
  0000:1B75  03c2              add      ax, dx
  0000:1B77  03c7              add      ax, di
  0000:1B79  99                cdq
  0000:1B7A  52                push     dx
  0000:1B7B  50                push     ax
  0000:1B7C  894ee0            mov      word ptr [bp - 0x20], cx
  0000:1B7F  895ee2            mov      word ptr [bp - 0x1e], bx
  0000:1B82  e823fb            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:1B85  0346e0            add      ax, word ptr [bp - 0x20]
  0000:1B88  1356e2            adc      dx, word ptr [bp - 0x1e]
  0000:1B8B  0346e4            add      ax, word ptr [bp - 0x1c]
  0000:1B8E  1356e6            adc      dx, word ptr [bp - 0x1a]
  0000:1B91  8bc8              mov      cx, ax
  0000:1B93  8b460e            mov      ax, word ptr [bp + 0xe]
  0000:1B96  8bda              mov      bx, dx
  0000:1B98  99                cdq
  0000:1B99  03c8              add      cx, ax
  0000:1B9B  13da              adc      bx, dx
  0000:1B9D  81c100a6          add      cx, 0xa600
  0000:1BA1  81d3ce12          adc      bx, 0x12ce
  0000:1BA5  014eea            add      word ptr [bp - 0x16], cx
  0000:1BA8  115eec            adc      word ptr [bp - 0x14], bx
  0000:1BAB  8b4608            mov      ax, word ptr [bp + 8]
  0000:1BAE  03c7              add      ax, di
  0000:1BB0  8946fc            mov      word ptr [bp - 4], ax
  0000:1BB3  e8ea02            call     0x1ea0  ; -> sub_0000_1EA0  ; alarm_initAlarmConfig
  0000:1BB6  a1c603            mov      ax, word ptr [0x3c6]
  0000:1BB9  8b16c803          mov      dx, word ptr [0x3c8]
  0000:1BBD  0146ea            add      word ptr [bp - 0x16], ax
  0000:1BC0  1156ec            adc      word ptr [bp - 0x14], dx
  0000:1BC3  8d4450            lea      ax, [si + 0x50]
  0000:1BC6  8946f8            mov      word ptr [bp - 8], ax
  0000:1BC9  8b4606            mov      ax, word ptr [bp + 6]
  0000:1BCC  48                dec      ax
  0000:1BCD  8946f6            mov      word ptr [bp - 0xa], ax
  0000:1BD0  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:1BD3  8946f2            mov      word ptr [bp - 0xe], ax
  0000:1BD6  833eca0300        cmp      word ptr [0x3ca], 0
  0000:1BDB  7417              je       0x1bf4  ; -> loc_0000_1BF4
  0000:1BDD  8d46ee            lea      ax, [bp - 0x12]
  0000:1BE0  50                push     ax
  0000:1BE1  e87c03            call     0x1f60  ; -> sub_0000_1F60  ; alarm_validateLeapYear
  0000:1BE4  83c402            add      sp, 2
  0000:1BE7  0bc0              or       ax, ax
  0000:1BE9  7409              je       0x1bf4  ; -> loc_0000_1BF4
  0000:1BEB  816eea100e        sub      word ptr [bp - 0x16], 0xe10
  0000:1BF0  835eec00          sbb      word ptr [bp - 0x14], 0

loc_0000_1BF4:
  0000:1BF4  8b46ea            mov      ax, word ptr [bp - 0x16]
  0000:1BF7  8b56ec            mov      dx, word ptr [bp - 0x14]
  0000:1BFA  5e                pop      si
  0000:1BFB  5f                pop      di
  0000:1BFC  8be5              mov      sp, bp
  0000:1BFE  5d                pop      bp
  0000:1BFF  c3                ret

; --- alarm_allocStreamBuffer ---
; Allocate buffer for file stream I/O
alarm_allocStreamBuffer:  ; (sub_0000_1C00)
  0000:1C00  55                push     bp
  0000:1C01  8bec              mov      bp, sp
  0000:1C03  83ec02            sub      sp, 2
  0000:1C06  56                push     si
  0000:1C07  8b4604            mov      ax, word ptr [bp + 4]
  0000:1C0A  2d6a02            sub      ax, 0x26a
  0000:1C0D  b103              mov      cl, 3
  0000:1C0F  d3f8              sar      ax, cl
  0000:1C11  8bc8              mov      cx, ax
  0000:1C13  d1e0              shl      ax, 1
  0000:1C15  03c1              add      ax, cx
  0000:1C17  d1e0              shl      ax, 1
  0000:1C19  050a03            add      ax, 0x30a
  0000:1C1C  8946fe            mov      word ptr [bp - 2], ax
  0000:1C1F  b80002            mov      ax, 0x200
  0000:1C22  50                push     ax
  0000:1C23  e8da04            call     0x2100  ; -> sub_0000_2100  ; alarm_malloc
  0000:1C26  83c402            add      sp, 2
  0000:1C29  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1C2C  894704            mov      word ptr [bx + 4], ax
  0000:1C2F  0bc0              or       ax, ax
  0000:1C31  740f              je       0x1c42  ; -> loc_0000_1C42
  0000:1C33  804f0608          or       byte ptr [bx + 6], 8
  0000:1C37  8b5efe            mov      bx, word ptr [bp - 2]
  0000:1C3A  c747020002        mov      word ptr [bx + 2], 0x200
  0000:1C3F  eb17              jmp      0x1c58  ; -> loc_0000_1C58
  0000:1C41  db 90                                              ; |.|

loc_0000_1C42:
  0000:1C42  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1C45  804f0604          or       byte ptr [bx + 6], 4
  0000:1C49  8b46fe            mov      ax, word ptr [bp - 2]
  0000:1C4C  40                inc      ax
  0000:1C4D  894704            mov      word ptr [bx + 4], ax
  0000:1C50  8b5efe            mov      bx, word ptr [bp - 2]
  0000:1C53  c747020100        mov      word ptr [bx + 2], 1

loc_0000_1C58:
  0000:1C58  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1C5B  8bf3              mov      si, bx
  0000:1C5D  8b4404            mov      ax, word ptr [si + 4]
  0000:1C60  8907              mov      word ptr [bx], ax
  0000:1C62  c747020000        mov      word ptr [bx + 2], 0
  0000:1C67  5e                pop      si
  0000:1C68  8be5              mov      sp, bp
  0000:1C6A  5d                pop      bp
  0000:1C6B  c3                ret

; --- alarm_flushStream ---
; Flush stream buffer to disk
alarm_flushStream:  ; (sub_0000_1C6C)
  0000:1C6C  55                push     bp
  0000:1C6D  8bec              mov      bp, sp
  0000:1C6F  83ec04            sub      sp, 4
  0000:1C72  57                push     di
  0000:1C73  56                push     si
  0000:1C74  8b7604            mov      si, word ptr [bp + 4]
  0000:1C77  2bff              sub      di, di
  0000:1C79  8a4406            mov      al, byte ptr [si + 6]
  0000:1C7C  2403              and      al, 3
  0000:1C7E  3c02              cmp      al, 2
  0000:1C80  7546              jne      0x1cc8  ; -> loc_0000_1CC8
  0000:1C82  f6440608          test     byte ptr [si + 6], 8
  0000:1C86  7519              jne      0x1ca1  ; -> loc_0000_1CA1
  0000:1C88  8bde              mov      bx, si
  0000:1C8A  81eb6a02          sub      bx, 0x26a
  0000:1C8E  b103              mov      cl, 3
  0000:1C90  d3fb              sar      bx, cl
  0000:1C92  8bc3              mov      ax, bx
  0000:1C94  d1e3              shl      bx, 1
  0000:1C96  03d8              add      bx, ax
  0000:1C98  d1e3              shl      bx, 1
  0000:1C9A  f6870a0301        test     byte ptr [bx + 0x30a], 1
  0000:1C9F  7427              je       0x1cc8  ; -> loc_0000_1CC8

loc_0000_1CA1:
  0000:1CA1  8b04              mov      ax, word ptr [si]
  0000:1CA3  2b4404            sub      ax, word ptr [si + 4]
  0000:1CA6  8946fc            mov      word ptr [bp - 4], ax
  0000:1CA9  0bc0              or       ax, ax
  0000:1CAB  7e1b              jle      0x1cc8  ; -> loc_0000_1CC8
  0000:1CAD  50                push     ax
  0000:1CAE  ff7404            push     word ptr [si + 4]
  0000:1CB1  8a4407            mov      al, byte ptr [si + 7]
  0000:1CB4  98                cwde
  0000:1CB5  50                push     ax
  0000:1CB6  e89b00            call     0x1d54  ; -> sub_0000_1D54  ; alarm_writeToFile
  0000:1CB9  83c406            add      sp, 6
  0000:1CBC  3b46fc            cmp      ax, word ptr [bp - 4]
  0000:1CBF  7407              je       0x1cc8  ; -> loc_0000_1CC8
  0000:1CC1  804c0620          or       byte ptr [si + 6], 0x20
  0000:1CC5  bfffff            mov      di, 0xffff

loc_0000_1CC8:
  0000:1CC8  8b4404            mov      ax, word ptr [si + 4]
  0000:1CCB  8904              mov      word ptr [si], ax
  0000:1CCD  c744020000        mov      word ptr [si + 2], 0
  0000:1CD2  8bc7              mov      ax, di
  0000:1CD4  5e                pop      si
  0000:1CD5  5f                pop      di
  0000:1CD6  8be5              mov      sp, bp
  0000:1CD8  5d                pop      bp
  0000:1CD9  c3                ret

; --- alarm_seekFile ---
; Seek file position via INT 21h/42h
alarm_seekFile:  ; (sub_0000_1CDA)
  0000:1CDA  55                push     bp
  0000:1CDB  8bec              mov      bp, sp
  0000:1CDD  83ec04            sub      sp, 4
  0000:1CE0  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1CE3  3b1ef001          cmp      bx, word ptr [0x1f0]
  0000:1CE7  7205              jb       0x1cee  ; -> loc_0000_1CEE
  0000:1CE9  b80009            mov      ax, 0x900
  0000:1CEC  eb2a              jmp      0x1d18  ; -> loc_0000_1D18

loc_0000_1CEE:
  0000:1CEE  f746080080        test     word ptr [bp + 8], 0x8000
  0000:1CF3  7448              je       0x1d3d  ; -> loc_0000_1D3D
  0000:1CF5  837e0a00          cmp      word ptr [bp + 0xa], 0
  0000:1CF9  741a              je       0x1d15  ; -> loc_0000_1D15
  0000:1CFB  33c9              xor      cx, cx
  0000:1CFD  8bd1              mov      dx, cx
  0000:1CFF  b80142            mov      ax, 0x4201
  0000:1D02  cd21              int      0x21  ; INT 21h/42h: Seek (lseek)
  0000:1D04  724b              jb       0x1d51  ; -> loc_0000_1D51
  0000:1D06  f7460a0200        test     word ptr [bp + 0xa], 2
  0000:1D0B  750e              jne      0x1d1b  ; -> loc_0000_1D1B
  0000:1D0D  034606            add      ax, word ptr [bp + 6]
  0000:1D10  135608            adc      dx, word ptr [bp + 8]
  0000:1D13  7928              jns      0x1d3d  ; -> loc_0000_1D3D

loc_0000_1D15:
  0000:1D15  b80016            mov      ax, 0x1600

loc_0000_1D18:
  0000:1D18  f9                stc
  0000:1D19  eb36              jmp      0x1d51  ; -> loc_0000_1D51

loc_0000_1D1B:
  0000:1D1B  8956fe            mov      word ptr [bp - 2], dx
  0000:1D1E  8946fc            mov      word ptr [bp - 4], ax
  0000:1D21  8bd1              mov      dx, cx
  0000:1D23  b80242            mov      ax, 0x4202
  0000:1D26  cd21              int      0x21  ; INT 21h/42h: Seek (lseek)
  0000:1D28  034606            add      ax, word ptr [bp + 6]
  0000:1D2B  135608            adc      dx, word ptr [bp + 8]
  0000:1D2E  790d              jns      0x1d3d  ; -> loc_0000_1D3D
  0000:1D30  8b4efe            mov      cx, word ptr [bp - 2]
  0000:1D33  8b56fc            mov      dx, word ptr [bp - 4]
  0000:1D36  b80042            mov      ax, 0x4200
  0000:1D39  cd21              int      0x21  ; INT 21h/42h: Seek (lseek)
  0000:1D3B  ebd8              jmp      0x1d15  ; -> loc_0000_1D15

loc_0000_1D3D:
  0000:1D3D  8b5606            mov      dx, word ptr [bp + 6]
  0000:1D40  8b4e08            mov      cx, word ptr [bp + 8]
  0000:1D43  8a460a            mov      al, byte ptr [bp + 0xa]
  0000:1D46  b442              mov      ah, 0x42
  0000:1D48  cd21              int      0x21  ; INT 21h/42h: Seek (lseek)
  0000:1D4A  7205              jb       0x1d51  ; -> loc_0000_1D51
  0000:1D4C  80a7f201fd        and      byte ptr [bx + 0x1f2], 0xfd

loc_0000_1D51:
  0000:1D51  e91503            jmp      0x2069  ; -> loc_0000_2069

; --- alarm_writeToFile ---
; Low-level write to file handle (INT 21h/40h)
alarm_writeToFile:  ; (sub_0000_1D54)
  0000:1D54  55                push     bp
  0000:1D55  8bec              mov      bp, sp
  0000:1D57  83ec08            sub      sp, 8
  0000:1D5A  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1D5D  3b1ef001          cmp      bx, word ptr [0x1f0]
  0000:1D61  7207              jb       0x1d6a  ; -> loc_0000_1D6A
  0000:1D63  b80009            mov      ax, 0x900
  0000:1D66  f9                stc

loc_0000_1D67:
  0000:1D67  e9ff02            jmp      0x2069  ; -> loc_0000_2069

loc_0000_1D6A:
  0000:1D6A  f687f20120        test     byte ptr [bx + 0x1f2], 0x20
  0000:1D6F  740b              je       0x1d7c  ; -> loc_0000_1D7C
  0000:1D71  b80242            mov      ax, 0x4202
  0000:1D74  33c9              xor      cx, cx
  0000:1D76  8bd1              mov      dx, cx
  0000:1D78  cd21              int      0x21  ; INT 21h/42h: Seek (lseek)
  0000:1D7A  72eb              jb       0x1d67  ; -> loc_0000_1D67

loc_0000_1D7C:
  0000:1D7C  f687f20180        test     byte ptr [bx + 0x1f2], 0x80
  0000:1D81  746e              je       0x1df1  ; -> loc_0000_1DF1
  0000:1D83  8b5606            mov      dx, word ptr [bp + 6]
  0000:1D86  1e                push     ds
  0000:1D87  07                pop      es
  0000:1D88  33c0              xor      ax, ax
  0000:1D8A  8946fe            mov      word ptr [bp - 2], ax
  0000:1D8D  8946fc            mov      word ptr [bp - 4], ax
  0000:1D90  fc                cld
  0000:1D91  57                push     di
  0000:1D92  56                push     si
  0000:1D93  8bfa              mov      di, dx
  0000:1D95  8bf2              mov      si, dx
  0000:1D97  8966f8            mov      word ptr [bp - 8], sp
  0000:1D9A  8b4e08            mov      cx, word ptr [bp + 8]
  0000:1D9D  e354              jcxz     0x1df3  ; -> loc_0000_1DF3
  0000:1D9F  b00a              mov      al, 0xa
  0000:1DA1  f2ae              repne scasb al, byte ptr es:[di]
  0000:1DA3  754a              jne      0x1def  ; -> loc_0000_1DEF
  0000:1DA5  e83403            call     0x20dc  ; -> sub_0000_20DC  ; alarm_stackAvail
  0000:1DA8  3da800            cmp      ax, 0xa8
  0000:1DAB  7648              jbe      0x1df5  ; -> loc_0000_1DF5
  0000:1DAD  83ec02            sub      sp, 2
  0000:1DB0  8bdc              mov      bx, sp
  0000:1DB2  ba0002            mov      dx, 0x200
  0000:1DB5  3d2802            cmp      ax, 0x228
  0000:1DB8  7303              jae      0x1dbd  ; -> loc_0000_1DBD
  0000:1DBA  ba8000            mov      dx, 0x80

loc_0000_1DBD:
  0000:1DBD  2be2              sub      sp, dx
  0000:1DBF  8bd4              mov      dx, sp
  0000:1DC1  8bfa              mov      di, dx
  0000:1DC3  16                push     ss
  0000:1DC4  07                pop      es
  0000:1DC5  8b4e08            mov      cx, word ptr [bp + 8]
  0000:1DC8  ac                lodsb    al, byte ptr [si]
  0000:1DC9  3c0a              cmp      al, 0xa
  0000:1DCB  740c              je       0x1dd9  ; -> loc_0000_1DD9

loc_0000_1DCD:
  0000:1DCD  3bfb              cmp      di, bx
  0000:1DCF  7419              je       0x1dea  ; -> loc_0000_1DEA

loc_0000_1DD1:
  0000:1DD1  aa                stosb    byte ptr es:[di], al
  0000:1DD2  e2f4              loop     0x1dc8
  0000:1DD4  e82300            call     0x1dfa  ; -> sub_0000_1DFA  ; alarm_writeRawBytes
  0000:1DD7  eb61              jmp      0x1e3a  ; -> loc_0000_1E3A

loc_0000_1DD9:
  0000:1DD9  b00d              mov      al, 0xd
  0000:1DDB  3bfb              cmp      di, bx
  0000:1DDD  7503              jne      0x1de2  ; -> loc_0000_1DE2
  0000:1DDF  e81800            call     0x1dfa  ; -> sub_0000_1DFA  ; alarm_writeRawBytes

loc_0000_1DE2:
  0000:1DE2  aa                stosb    byte ptr es:[di], al
  0000:1DE3  b00a              mov      al, 0xa
  0000:1DE5  ff46fc            inc      word ptr [bp - 4]
  0000:1DE8  ebe3              jmp      0x1dcd  ; -> loc_0000_1DCD

loc_0000_1DEA:
  0000:1DEA  e80d00            call     0x1dfa  ; -> sub_0000_1DFA  ; alarm_writeRawBytes
  0000:1DED  ebe2              jmp      0x1dd1  ; -> loc_0000_1DD1

loc_0000_1DEF:
  0000:1DEF  5e                pop      si
  0000:1DF0  5f                pop      di

loc_0000_1DF1:
  0000:1DF1  eb55              jmp      0x1e48  ; -> loc_0000_1E48

loc_0000_1DF3:
  0000:1DF3  eb45              jmp      0x1e3a  ; -> loc_0000_1E3A

loc_0000_1DF5:
  0000:1DF5  33c0              xor      ax, ax
  0000:1DF7  e9dfef            jmp      0xdd9  ; -> loc_0000_0DD9

; --- alarm_writeRawBytes ---
; Write raw bytes to file, handle errors
alarm_writeRawBytes:  ; (sub_0000_1DFA)
  0000:1DFA  50                push     ax
  0000:1DFB  53                push     bx
  0000:1DFC  51                push     cx
  0000:1DFD  8bcf              mov      cx, di
  0000:1DFF  2bca              sub      cx, dx
  0000:1E01  e310              jcxz     0x1e13  ; -> loc_0000_1E13
  0000:1E03  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1E06  b440              mov      ah, 0x40
  0000:1E08  cd21              int      0x21  ; INT 21h/40h: Write file
  0000:1E0A  720d              jb       0x1e19  ; -> loc_0000_1E19
  0000:1E0C  0146fe            add      word ptr [bp - 2], ax
  0000:1E0F  0bc0              or       ax, ax
  0000:1E11  7406              je       0x1e19  ; -> loc_0000_1E19

loc_0000_1E13:
  0000:1E13  59                pop      cx
  0000:1E14  5b                pop      bx
  0000:1E15  58                pop      ax
  0000:1E16  8bfa              mov      di, dx
  0000:1E18  c3                ret

loc_0000_1E19:
  0000:1E19  83c408            add      sp, 8
  0000:1E1C  7304              jae      0x1e22  ; -> loc_0000_1E22
  0000:1E1E  b409              mov      ah, 9
  0000:1E20  eb1e              jmp      0x1e40  ; -> loc_0000_1E40

loc_0000_1E22:
  0000:1E22  f687f20140        test     byte ptr [bx + 0x1f2], 0x40
  0000:1E27  740b              je       0x1e34  ; -> loc_0000_1E34
  0000:1E29  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1E2C  803f1a            cmp      byte ptr [bx], 0x1a
  0000:1E2F  7503              jne      0x1e34  ; -> loc_0000_1E34
  0000:1E31  f8                clc
  0000:1E32  eb0c              jmp      0x1e40  ; -> loc_0000_1E40

loc_0000_1E34:
  0000:1E34  f9                stc
  0000:1E35  b8001c            mov      ax, 0x1c00
  0000:1E38  eb06              jmp      0x1e40  ; -> loc_0000_1E40

loc_0000_1E3A:
  0000:1E3A  8b46fe            mov      ax, word ptr [bp - 2]
  0000:1E3D  2b46fc            sub      ax, word ptr [bp - 4]

loc_0000_1E40:
  0000:1E40  8b66f8            mov      sp, word ptr [bp - 8]
  0000:1E43  5e                pop      si
  0000:1E44  5f                pop      di

loc_0000_1E45:
  0000:1E45  e92102            jmp      0x2069  ; -> loc_0000_2069

loc_0000_1E48:
  0000:1E48  8b4e08            mov      cx, word ptr [bp + 8]
  0000:1E4B  0bc9              or       cx, cx
  0000:1E4D  7505              jne      0x1e54  ; -> loc_0000_1E54
  0000:1E4F  8bc1              mov      ax, cx
  0000:1E51  e91502            jmp      0x2069  ; -> loc_0000_2069

loc_0000_1E54:
  0000:1E54  8b5606            mov      dx, word ptr [bp + 6]
  0000:1E57  b440              mov      ah, 0x40
  0000:1E59  cd21              int      0x21  ; INT 21h/40h: Write file
  0000:1E5B  7304              jae      0x1e61  ; -> loc_0000_1E61
  0000:1E5D  b409              mov      ah, 9
  0000:1E5F  ebe4              jmp      0x1e45  ; -> loc_0000_1E45

loc_0000_1E61:
  0000:1E61  0bc0              or       ax, ax
  0000:1E63  75e0              jne      0x1e45  ; -> loc_0000_1E45
  0000:1E65  f687f20140        test     byte ptr [bx + 0x1f2], 0x40
  0000:1E6A  740a              je       0x1e76  ; -> loc_0000_1E76
  0000:1E6C  8bda              mov      bx, dx
  0000:1E6E  803f1a            cmp      byte ptr [bx], 0x1a
  0000:1E71  7503              jne      0x1e76  ; -> loc_0000_1E76
  0000:1E73  f8                clc
  0000:1E74  ebcf              jmp      0x1e45  ; -> loc_0000_1E45

loc_0000_1E76:
  0000:1E76  f9                stc
  0000:1E77  b8001c            mov      ax, 0x1c00
  0000:1E7A  ebc9              jmp      0x1e45  ; -> loc_0000_1E45

; --- alarm_isDeviceHandle ---
; Check if file handle is a device (IOCTL flag 0x40)
alarm_isDeviceHandle:  ; (sub_0000_1E7C)
  0000:1E7C  55                push     bp
  0000:1E7D  8bec              mov      bp, sp
  0000:1E7F  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1E82  3b1ef001          cmp      bx, word ptr [0x1f0]
  0000:1E86  7d11              jge      0x1e99  ; -> loc_0000_1E99
  0000:1E88  83fb00            cmp      bx, 0
  0000:1E8B  7c0c              jl       0x1e99  ; -> loc_0000_1E99
  0000:1E8D  f687f20140        test     byte ptr [bx + 0x1f2], 0x40
  0000:1E92  7405              je       0x1e99  ; -> loc_0000_1E99
  0000:1E94  b80100            mov      ax, 1
  0000:1E97  eb02              jmp      0x1e9b  ; -> loc_0000_1E9B

loc_0000_1E99:
  0000:1E99  33c0              xor      ax, ax

loc_0000_1E9B:
  0000:1E9B  8be5              mov      sp, bp
  0000:1E9D  5d                pop      bp
  0000:1E9E  c3                ret
  0000:1E9F  db 00                                              ; |.|

; --- alarm_initAlarmConfig ---
; Initialize alarm config (parse ALARM.CFG once)
alarm_initAlarmConfig:  ; (sub_0000_1EA0)
  0000:1EA0  833e740600        cmp      word ptr [0x674], 0
  0000:1EA5  7507              jne      0x1eae  ; -> loc_0000_1EAE
  0000:1EA7  e80600            call     0x1eb0  ; -> sub_0000_1EB0  ; alarm_parseAlarmConfig
  0000:1EAA  ff067406          inc      word ptr [0x674]

loc_0000_1EAE:
  0000:1EAE  c3                ret
  0000:1EAF  db 90                                              ; |.|

; --- alarm_parseAlarmConfig ---
; Parse ALARM.CFG - read repeat interval and sound file
alarm_parseAlarmConfig:  ; (sub_0000_1EB0)
  0000:1EB0  55                push     bp
  0000:1EB1  8bec              mov      bp, sp
  0000:1EB3  83ec04            sub      sp, 4
  0000:1EB6  57                push     di
  0000:1EB7  56                push     si
  0000:1EB8  b8ba03            mov      ax, 0x3ba
  0000:1EBB  50                push     ax
  0000:1EBC  e82cee            call     0xceb  ; -> sub_0000_0CEB  ; alarm_getEnvVariable
  0000:1EBF  83c402            add      sp, 2
  0000:1EC2  8bf0              mov      si, ax
  0000:1EC4  0bf6              or       si, si
  0000:1EC6  7503              jne      0x1ecb  ; -> loc_0000_1ECB
  0000:1EC8  e98f00            jmp      0x1f5a  ; -> loc_0000_1F5A

loc_0000_1ECB:
  0000:1ECB  803c00            cmp      byte ptr [si], 0
  0000:1ECE  7503              jne      0x1ed3  ; -> loc_0000_1ED3
  0000:1ED0  e98700            jmp      0x1f5a  ; -> loc_0000_1F5A

loc_0000_1ED3:
  0000:1ED3  b80300            mov      ax, 3
  0000:1ED6  50                push     ax
  0000:1ED7  56                push     si
  0000:1ED8  ff36cc03          push     word ptr [0x3cc]
  0000:1EDC  e879f5            call     0x1458  ; -> sub_0000_1458  ; alarm_strncpy
  0000:1EDF  83c406            add      sp, 6
  0000:1EE2  b8100e            mov      ax, 0xe10
  0000:1EE5  99                cdq
  0000:1EE6  52                push     dx
  0000:1EE7  50                push     ax
  0000:1EE8  83c603            add      si, 3
  0000:1EEB  56                push     si
  0000:1EEC  e85702            call     0x2146  ; -> sub_0000_2146  ; alarm_atol
  0000:1EEF  83c402            add      sp, 2
  0000:1EF2  52                push     dx
  0000:1EF3  50                push     ax
  0000:1EF4  e8b1f7            call     0x16a8  ; -> sub_0000_16A8  ; alarm_mulUnsigned32
  0000:1EF7  a3c603            mov      word ptr [0x3c6], ax
  0000:1EFA  8916c803          mov      word ptr [0x3c8], dx
  0000:1EFE  2bff              sub      di, di

loc_0000_1F00:
  0000:1F00  8bdf              mov      bx, di
  0000:1F02  03de              add      bx, si
  0000:1F04  803f00            cmp      byte ptr [bx], 0
  0000:1F07  741f              je       0x1f28  ; -> loc_0000_1F28
  0000:1F09  8bdf              mov      bx, di
  0000:1F0B  03de              add      bx, si
  0000:1F0D  8a07              mov      al, byte ptr [bx]
  0000:1F0F  98                cwde
  0000:1F10  8bd8              mov      bx, ax
  0000:1F12  f6872b0404        test     byte ptr [bx + 0x42b], 4
  0000:1F17  7509              jne      0x1f22  ; -> loc_0000_1F22
  0000:1F19  8bdf              mov      bx, di
  0000:1F1B  03de              add      bx, si
  0000:1F1D  803f2d            cmp      byte ptr [bx], 0x2d
  0000:1F20  7506              jne      0x1f28  ; -> loc_0000_1F28

loc_0000_1F22:
  0000:1F22  47                inc      di
  0000:1F23  83ff03            cmp      di, 3
  0000:1F26  7cd8              jl       0x1f00  ; -> loc_0000_1F00

loc_0000_1F28:
  0000:1F28  8bdf              mov      bx, di
  0000:1F2A  03de              add      bx, si
  0000:1F2C  803f00            cmp      byte ptr [bx], 0
  0000:1F2F  7415              je       0x1f46  ; -> loc_0000_1F46
  0000:1F31  b80300            mov      ax, 3
  0000:1F34  50                push     ax
  0000:1F35  8bc7              mov      ax, di
  0000:1F37  03c6              add      ax, si
  0000:1F39  50                push     ax
  0000:1F3A  ff36ce03          push     word ptr [0x3ce]
  0000:1F3E  e817f5            call     0x1458  ; -> sub_0000_1458  ; alarm_strncpy
  0000:1F41  83c406            add      sp, 6
  0000:1F44  eb07              jmp      0x1f4d  ; -> loc_0000_1F4D

loc_0000_1F46:
  0000:1F46  8b1ece03          mov      bx, word ptr [0x3ce]
  0000:1F4A  c60700            mov      byte ptr [bx], 0

loc_0000_1F4D:
  0000:1F4D  8b1ece03          mov      bx, word ptr [0x3ce]
  0000:1F51  803f01            cmp      byte ptr [bx], 1
  0000:1F54  1bc0              sbb      ax, ax
  0000:1F56  40                inc      ax
  0000:1F57  a3ca03            mov      word ptr [0x3ca], ax

loc_0000_1F5A:
  0000:1F5A  5e                pop      si
  0000:1F5B  5f                pop      di
  0000:1F5C  8be5              mov      sp, bp
  0000:1F5E  5d                pop      bp
  0000:1F5F  c3                ret

; --- alarm_validateLeapYear ---
; Validate date considering leap year rules
alarm_validateLeapYear:  ; (sub_0000_1F60)
  0000:1F60  55                push     bp
  0000:1F61  8bec              mov      bp, sp
  0000:1F63  83ec06            sub      sp, 6
  0000:1F66  57                push     di
  0000:1F67  56                push     si
  0000:1F68  8b7604            mov      si, word ptr [bp + 4]
  0000:1F6B  837c0803          cmp      word ptr [si + 8], 3
  0000:1F6F  7d03              jge      0x1f74  ; -> loc_0000_1F74
  0000:1F71  e9ae00            jmp      0x2022  ; -> loc_0000_2022

loc_0000_1F74:
  0000:1F74  837c0809          cmp      word ptr [si + 8], 9
  0000:1F78  7e03              jle      0x1f7d  ; -> loc_0000_1F7D
  0000:1F7A  e9a500            jmp      0x2022  ; -> loc_0000_2022

loc_0000_1F7D:
  0000:1F7D  837c0803          cmp      word ptr [si + 8], 3
  0000:1F81  7e09              jle      0x1f8c  ; -> loc_0000_1F8C
  0000:1F83  837c0809          cmp      word ptr [si + 8], 9
  0000:1F87  7d03              jge      0x1f8c  ; -> loc_0000_1F8C
  0000:1F89  e98000            jmp      0x200c  ; -> loc_0000_200C

loc_0000_1F8C:
  0000:1F8C  8b7c0a            mov      di, word ptr [si + 0xa]
  0000:1F8F  81c76c07          add      di, 0x76c
  0000:1F93  81ffc207          cmp      di, 0x7c2
  0000:1F97  7e15              jle      0x1fae  ; -> loc_0000_1FAE
  0000:1F99  837c0803          cmp      word ptr [si + 8], 3
  0000:1F9D  750f              jne      0x1fae  ; -> loc_0000_1FAE
  0000:1F9F  8b5c08            mov      bx, word ptr [si + 8]
  0000:1FA2  d1e3              shl      bx, 1
  0000:1FA4  8b87a003          mov      ax, word ptr [bx + 0x3a0]
  0000:1FA8  050700            add      ax, 7
  0000:1FAB  eb0a              jmp      0x1fb7  ; -> loc_0000_1FB7
  0000:1FAD  db 90                                              ; |.|

loc_0000_1FAE:
  0000:1FAE  8b5c08            mov      bx, word ptr [si + 8]
  0000:1FB1  d1e3              shl      bx, 1
  0000:1FB3  8b87a203          mov      ax, word ptr [bx + 0x3a2]

loc_0000_1FB7:
  0000:1FB7  8946fa            mov      word ptr [bp - 6], ax
  0000:1FBA  f7c70300          test     di, 3
  0000:1FBE  7503              jne      0x1fc3  ; -> loc_0000_1FC3
  0000:1FC0  ff46fa            inc      word ptr [bp - 6]

loc_0000_1FC3:
  0000:1FC3  8b7c0a            mov      di, word ptr [si + 0xa]
  0000:1FC6  83ef46            sub      di, 0x46
  0000:1FC9  b86d01            mov      ax, 0x16d
  0000:1FCC  f7ef              imul     di
  0000:1FCE  8bc8              mov      cx, ax
  0000:1FD0  8d4501            lea      ax, [di + 1]
  0000:1FD3  8bd9              mov      bx, cx
  0000:1FD5  99                cdq
  0000:1FD6  33c2              xor      ax, dx
  0000:1FD8  2bc2              sub      ax, dx
  0000:1FDA  b90200            mov      cx, 2
  0000:1FDD  d3f8              sar      ax, cl
  0000:1FDF  33c2              xor      ax, dx
  0000:1FE1  2bc2              sub      ax, dx
  0000:1FE3  0346fa            add      ax, word ptr [bp - 6]
  0000:1FE6  03c3              add      ax, bx
  0000:1FE8  050400            add      ax, 4
  0000:1FEB  99                cdq
  0000:1FEC  b90700            mov      cx, 7
  0000:1FEF  f7f9              idiv     cx
  0000:1FF1  8b46fa            mov      ax, word ptr [bp - 6]
  0000:1FF4  2bc2              sub      ax, dx
  0000:1FF6  8946fe            mov      word ptr [bp - 2], ax
  0000:1FF9  837c0803          cmp      word ptr [si + 8], 3
  0000:1FFD  7513              jne      0x2012  ; -> loc_0000_2012
  0000:1FFF  39440e            cmp      word ptr [si + 0xe], ax
  0000:2002  7f08              jg       0x200c  ; -> loc_0000_200C
  0000:2004  751c              jne      0x2022  ; -> loc_0000_2022
  0000:2006  837c0402          cmp      word ptr [si + 4], 2
  0000:200A  7c16              jl       0x2022  ; -> loc_0000_2022

loc_0000_200C:
  0000:200C  b80100            mov      ax, 1
  0000:200F  eb13              jmp      0x2024  ; -> loc_0000_2024
  0000:2011  db 90                                              ; |.|

loc_0000_2012:
  0000:2012  8b46fe            mov      ax, word ptr [bp - 2]
  0000:2015  39440e            cmp      word ptr [si + 0xe], ax
  0000:2018  7cf2              jl       0x200c  ; -> loc_0000_200C
  0000:201A  7506              jne      0x2022  ; -> loc_0000_2022
  0000:201C  837c0401          cmp      word ptr [si + 4], 1
  0000:2020  7cea              jl       0x200c  ; -> loc_0000_200C

loc_0000_2022:
  0000:2022  2bc0              sub      ax, ax

loc_0000_2024:
  0000:2024  5e                pop      si
  0000:2025  5f                pop      di
  0000:2026  8be5              mov      sp, bp
  0000:2028  5d                pop      bp
  0000:2029  c3                ret

; --- alarm_memcpyForward ---
; Forward memory copy (aligned, optimized with word moves)
alarm_memcpyForward:  ; (sub_0000_202A)
  0000:202A  55                push     bp
  0000:202B  8bec              mov      bp, sp
  0000:202D  8bd7              mov      dx, di
  0000:202F  8bde              mov      bx, si
  0000:2031  8cd8              mov      ax, ds
  0000:2033  8ec0              mov      es, ax
  0000:2035  8b7606            mov      si, word ptr [bp + 6]
  0000:2038  8b7e04            mov      di, word ptr [bp + 4]
  0000:203B  8bc7              mov      ax, di
  0000:203D  8b4e08            mov      cx, word ptr [bp + 8]
  0000:2040  e30e              jcxz     0x2050  ; -> loc_0000_2050
  0000:2042  a801              test     al, 1
  0000:2044  7402              je       0x2048  ; -> loc_0000_2048
  0000:2046  a4                movsb    byte ptr es:[di], byte ptr [si]
  0000:2047  49                dec      cx

loc_0000_2048:
  0000:2048  d1e9              shr      cx, 1
  0000:204A  f3a5              rep movsw word ptr es:[di], word ptr [si]
  0000:204C  13c9              adc      cx, cx
  0000:204E  f3a4              rep movsb byte ptr es:[di], byte ptr [si]

loc_0000_2050:
  0000:2050  8bf3              mov      si, bx
  0000:2052  8bfa              mov      di, dx
  0000:2054  5d                pop      bp
  0000:2055  c3                ret
  0000:2056  db 72 13 33 C0 8B E5 5D C3 73 F8 50 E8 18 00 58 8B ; |r.3...].s.P...X.|
  0000:2066  db E5 5D C3                                        ; |.].|

loc_0000_2069:
  0000:2069  7307              jae      0x2072  ; -> loc_0000_2072
  0000:206B  e80e00            call     0x207c  ; -> sub_0000_207C  ; alarm_setDOSError
  0000:206E  b8ffff            mov      ax, 0xffff
  0000:2071  99                cdq

loc_0000_2072:
  0000:2072  8be5              mov      sp, bp
  0000:2074  5d                pop      bp
  0000:2075  c3                ret
  0000:2076  db 32 E4 E8 01 00 C3                               ; |2.....|

; --- alarm_setDOSError ---
; Set DOS error code from INT 21h result
alarm_setDOSError:  ; (sub_0000_207C)
  0000:207C  a2ee01            mov      byte ptr [0x1ee], al
  0000:207F  0ae4              or       ah, ah
  0000:2081  7523              jne      0x20a6  ; -> loc_0000_20A6
  0000:2083  803eeb0103        cmp      byte ptr [0x1eb], 3
  0000:2088  720d              jb       0x2097  ; -> loc_0000_2097
  0000:208A  3c22              cmp      al, 0x22
  0000:208C  730d              jae      0x209b  ; -> loc_0000_209B
  0000:208E  3c20              cmp      al, 0x20
  0000:2090  7205              jb       0x2097  ; -> loc_0000_2097
  0000:2092  b005              mov      al, 5
  0000:2094  eb07              jmp      0x209d  ; -> loc_0000_209D
  0000:2096  db 90                                              ; |.|

loc_0000_2097:
  0000:2097  3c13              cmp      al, 0x13
  0000:2099  7602              jbe      0x209d  ; -> loc_0000_209D

loc_0000_209B:
  0000:209B  b013              mov      al, 0x13

loc_0000_209D:
  0000:209D  bb0c04            mov      bx, 0x40c
  0000:20A0  d7                xlatb

loc_0000_20A1:
  0000:20A1  98                cwde
  0000:20A2  a3e301            mov      word ptr [0x1e3], ax
  0000:20A5  c3                ret

loc_0000_20A6:
  0000:20A6  8ac4              mov      al, ah
  0000:20A8  ebf7              jmp      0x20a1  ; -> loc_0000_20A1
  0000:20AA  55                push     bp
  0000:20AB  8bec              mov      bp, sp
  0000:20AD  83ec04            sub      sp, 4
  0000:20B0  57                push     di
  0000:20B1  56                push     si
  0000:20B2  be6a02            mov      si, 0x26a
  0000:20B5  2bff              sub      di, di
  0000:20B7  eb15              jmp      0x20ce  ; -> loc_0000_20CE
  0000:20B9  db 90                                              ; |.|

loc_0000_20BA:
  0000:20BA  f6440683          test     byte ptr [si + 6], 0x83
  0000:20BE  740b              je       0x20cb  ; -> loc_0000_20CB
  0000:20C0  56                push     si
  0000:20C1  e8a8fb            call     0x1c6c  ; -> sub_0000_1C6C  ; alarm_flushStream
  0000:20C4  83c402            add      sp, 2
  0000:20C7  40                inc      ax
  0000:20C8  7401              je       0x20cb  ; -> loc_0000_20CB
  0000:20CA  47                inc      di

loc_0000_20CB:
  0000:20CB  83c608            add      si, 8

loc_0000_20CE:
  0000:20CE  39368203          cmp      word ptr [0x382], si
  0000:20D2  73e6              jae      0x20ba  ; -> loc_0000_20BA
  0000:20D4  8bc7              mov      ax, di
  0000:20D6  5e                pop      si
  0000:20D7  5f                pop      di
  0000:20D8  8be5              mov      sp, bp
  0000:20DA  5d                pop      bp
  0000:20DB  c3                ret

; --- alarm_stackAvail ---
; Check available stack space
alarm_stackAvail:  ; (sub_0000_20DC)
  0000:20DC  59                pop      cx
  0000:20DD  a12c05            mov      ax, word ptr [0x52c]
  0000:20E0  3bc4              cmp      ax, sp
  0000:20E2  7306              jae      0x20ea  ; -> loc_0000_20EA
  0000:20E4  2bc4              sub      ax, sp
  0000:20E6  f7d8              neg      ax

loc_0000_20E8:
  0000:20E8  ffe1              jmp      cx

loc_0000_20EA:
  0000:20EA  33c0              xor      ax, ax
  0000:20EC  ebfa              jmp      0x20e8  ; -> loc_0000_20E8
  0000:20EE  55                push     bp
  0000:20EF  8bec              mov      bp, sp
  0000:20F1  8b5e04            mov      bx, word ptr [bp + 4]
  0000:20F4  0bdb              or       bx, bx
  0000:20F6  7404              je       0x20fc  ; -> loc_0000_20FC
  0000:20F8  804ffe01          or       byte ptr [bx - 2], 1

loc_0000_20FC:
  0000:20FC  8be5              mov      sp, bp
  0000:20FE  5d                pop      bp
  0000:20FF  c3                ret

; --- alarm_malloc ---
; C library malloc - allocate memory from heap
alarm_malloc:  ; (sub_0000_2100)
  0000:2100  55                push     bp
  0000:2101  8bec              mov      bp, sp
  0000:2103  56                push     si
  0000:2104  57                push     di
  0000:2105  bb2004            mov      bx, 0x420
  0000:2108  833f00            cmp      word ptr [bx], 0
  0000:210B  7529              jne      0x2136  ; -> loc_0000_2136
  0000:210D  1e                push     ds
  0000:210E  07                pop      es
  0000:210F  b80500            mov      ax, 5
  0000:2112  e88d01            call     0x22a2  ; -> sub_0000_22A2  ; alarm_sbrk
  0000:2115  7505              jne      0x211c  ; -> loc_0000_211C
  0000:2117  33c0              xor      ax, ax
  0000:2119  99                cdq
  0000:211A  eb24              jmp      0x2140  ; -> loc_0000_2140

loc_0000_211C:
  0000:211C  40                inc      ax
  0000:211D  24fe              and      al, 0xfe
  0000:211F  a32004            mov      word ptr [0x420], ax
  0000:2122  a32204            mov      word ptr [0x422], ax
  0000:2125  96                xchg     si, ax
  0000:2126  c7040100          mov      word ptr [si], 1
  0000:212A  83c604            add      si, 4
  0000:212D  c744fefeff        mov      word ptr [si - 2], 0xfffe
  0000:2132  89362604          mov      word ptr [0x426], si

loc_0000_2136:
  0000:2136  8b4e04            mov      cx, word ptr [bp + 4]
  0000:2139  8cd8              mov      ax, ds
  0000:213B  8ec0              mov      es, ax
  0000:213D  e82300            call     0x2163  ; -> sub_0000_2163  ; alarm_heapAlloc

loc_0000_2140:
  0000:2140  5f                pop      di
  0000:2141  5e                pop      si
  0000:2142  8be5              mov      sp, bp
  0000:2144  5d                pop      bp
  0000:2145  c3                ret

; --- alarm_atol ---
; Convert ASCII string to long integer (atol)
alarm_atol:  ; (sub_0000_2146)
  0000:2146  e97901            jmp      0x22c2  ; -> loc_0000_22C2
  0000:2149  db 00 59 8B DC 2B D8 72 0A 3B 1E 2C 05 72 04 8B E3 ; |.Y..+.r.;.,.r...|
  0000:2159  db FF E1 33 C0 E9 79 EC                            ; |..3..y.|

loc_0000_2160:
  0000:2160  e9ce00            jmp      0x2231  ; -> loc_0000_2231

; --- alarm_heapAlloc ---
; Internal heap allocator (first-fit free list)
alarm_heapAlloc:  ; (sub_0000_2163)
  0000:2163  41                inc      cx
  0000:2164  74fa              je       0x2160  ; -> loc_0000_2160
  0000:2166  80e1fe            and      cl, 0xfe
  0000:2169  83f9ee            cmp      cx, -0x12
  0000:216C  73f2              jae      0x2160  ; -> loc_0000_2160
  0000:216E  8b7702            mov      si, word ptr [bx + 2]
  0000:2171  fc                cld
  0000:2172  ad                lodsw    ax, word ptr [si]
  0000:2173  8bfe              mov      di, si
  0000:2175  a801              test     al, 1
  0000:2177  7442              je       0x21bb  ; -> loc_0000_21BB

loc_0000_2179:
  0000:2179  48                dec      ax
  0000:217A  3bc1              cmp      ax, cx
  0000:217C  7315              jae      0x2193  ; -> loc_0000_2193
  0000:217E  8bd0              mov      dx, ax
  0000:2180  03f0              add      si, ax
  0000:2182  ad                lodsw    ax, word ptr [si]
  0000:2183  a801              test     al, 1
  0000:2185  7434              je       0x21bb  ; -> loc_0000_21BB
  0000:2187  03c2              add      ax, dx
  0000:2189  050200            add      ax, 2
  0000:218C  8bf7              mov      si, di
  0000:218E  8944fe            mov      word ptr [si - 2], ax
  0000:2191  ebe6              jmp      0x2179  ; -> loc_0000_2179

loc_0000_2193:
  0000:2193  8bfe              mov      di, si
  0000:2195  740c              je       0x21a3  ; -> loc_0000_21A3
  0000:2197  03f9              add      di, cx
  0000:2199  894cfe            mov      word ptr [si - 2], cx
  0000:219C  2bc1              sub      ax, cx
  0000:219E  48                dec      ax
  0000:219F  8905              mov      word ptr [di], ax
  0000:21A1  eb05              jmp      0x21a8  ; -> loc_0000_21A8

loc_0000_21A3:
  0000:21A3  03f9              add      di, cx
  0000:21A5  fe4cfe            dec      byte ptr [si - 2]

loc_0000_21A8:
  0000:21A8  8bc6              mov      ax, si
  0000:21AA  8cda              mov      dx, ds
  0000:21AC  8cd1              mov      cx, ss
  0000:21AE  3bd1              cmp      dx, cx
  0000:21B0  7405              je       0x21b7  ; -> loc_0000_21B7
  0000:21B2  268c1e3205        mov      word ptr es:[0x532], ds

loc_0000_21B7:
  0000:21B7  897f02            mov      word ptr [bx + 2], di
  0000:21BA  c3                ret

loc_0000_21BB:
  0000:21BB  26c606380502      mov      byte ptr es:[0x538], 2

loc_0000_21C1:
  0000:21C1  3dfeff            cmp      ax, 0xfffe
  0000:21C4  7425              je       0x21eb  ; -> loc_0000_21EB
  0000:21C6  8bfe              mov      di, si
  0000:21C8  03f0              add      si, ax

loc_0000_21CA:
  0000:21CA  ad                lodsw    ax, word ptr [si]
  0000:21CB  a801              test     al, 1
  0000:21CD  74f2              je       0x21c1  ; -> loc_0000_21C1
  0000:21CF  8bfe              mov      di, si

loc_0000_21D1:
  0000:21D1  48                dec      ax
  0000:21D2  3bc1              cmp      ax, cx
  0000:21D4  73bd              jae      0x2193  ; -> loc_0000_2193
  0000:21D6  8bd0              mov      dx, ax
  0000:21D8  03f0              add      si, ax
  0000:21DA  ad                lodsw    ax, word ptr [si]
  0000:21DB  a801              test     al, 1
  0000:21DD  74e2              je       0x21c1  ; -> loc_0000_21C1
  0000:21DF  03c2              add      ax, dx
  0000:21E1  050200            add      ax, 2
  0000:21E4  8bf7              mov      si, di
  0000:21E6  8944fe            mov      word ptr [si - 2], ax
  0000:21E9  ebe6              jmp      0x21d1  ; -> loc_0000_21D1

loc_0000_21EB:
  0000:21EB  8b4708            mov      ax, word ptr [bx + 8]
  0000:21EE  0bc0              or       ax, ax
  0000:21F0  7404              je       0x21f6  ; -> loc_0000_21F6
  0000:21F2  8ed8              mov      ds, ax
  0000:21F4  eb14              jmp      0x220a  ; -> loc_0000_220A

loc_0000_21F6:
  0000:21F6  26fe0e3805        dec      byte ptr es:[0x538]
  0000:21FB  7411              je       0x220e  ; -> loc_0000_220E
  0000:21FD  8cd8              mov      ax, ds
  0000:21FF  8cd7              mov      di, ss
  0000:2201  3bc7              cmp      ax, di
  0000:2203  7405              je       0x220a  ; -> loc_0000_220A
  0000:2205  268e1e2e05        mov      ds, word ptr es:[0x52e]

loc_0000_220A:
  0000:220A  8b37              mov      si, word ptr [bx]
  0000:220C  ebbc              jmp      0x21ca  ; -> loc_0000_21CA

loc_0000_220E:
  0000:220E  8b7706            mov      si, word ptr [bx + 6]
  0000:2211  33c0              xor      ax, ax
  0000:2213  e86a00            call     0x2280  ; -> sub_0000_2280  ; alarm_heapSplit
  0000:2216  3bc6              cmp      ax, si
  0000:2218  740d              je       0x2227  ; -> loc_0000_2227
  0000:221A  2401              and      al, 1
  0000:221C  40                inc      ax
  0000:221D  40                inc      ax
  0000:221E  98                cwde
  0000:221F  e85e00            call     0x2280  ; -> sub_0000_2280  ; alarm_heapSplit
  0000:2222  740d              je       0x2231  ; -> loc_0000_2231
  0000:2224  fe4dfe            dec      byte ptr [di - 2]

loc_0000_2227:
  0000:2227  e81c00            call     0x2246  ; -> sub_0000_2246  ; alarm_heapGrow
  0000:222A  7405              je       0x2231  ; -> loc_0000_2231
  0000:222C  96                xchg     si, ax
  0000:222D  4e                dec      si
  0000:222E  4e                dec      si
  0000:222F  eb99              jmp      0x21ca  ; -> loc_0000_21CA

loc_0000_2231:
  0000:2231  8cd8              mov      ax, ds
  0000:2233  8cd1              mov      cx, ss
  0000:2235  3bc1              cmp      ax, cx
  0000:2237  7404              je       0x223d  ; -> loc_0000_223D
  0000:2239  26a33205          mov      word ptr es:[0x532], ax

loc_0000_223D:
  0000:223D  8b07              mov      ax, word ptr [bx]
  0000:223F  894702            mov      word ptr [bx + 2], ax
  0000:2242  33c0              xor      ax, ax
  0000:2244  99                cdq
  0000:2245  c3                ret

; --- alarm_heapGrow ---
; Grow heap by allocating more DOS memory
alarm_heapGrow:  ; (sub_0000_2246)
  0000:2246  51                push     cx
  0000:2247  8b45fe            mov      ax, word ptr [di - 2]
  0000:224A  a801              test     al, 1
  0000:224C  7403              je       0x2251  ; -> loc_0000_2251
  0000:224E  2bc8              sub      cx, ax
  0000:2250  49                dec      cx

loc_0000_2251:
  0000:2251  41                inc      cx
  0000:2252  41                inc      cx
  0000:2253  baff7f            mov      dx, 0x7fff

loc_0000_2256:
  0000:2256  263b163405        cmp      dx, word ptr es:[0x534]
  0000:225B  7604              jbe      0x2261  ; -> loc_0000_2261
  0000:225D  d1ea              shr      dx, 1
  0000:225F  75f5              jne      0x2256  ; -> loc_0000_2256

loc_0000_2261:
  0000:2261  8bc1              mov      ax, cx
  0000:2263  03c6              add      ax, si
  0000:2265  7215              jb       0x227c  ; -> loc_0000_227C
  0000:2267  03c2              add      ax, dx
  0000:2269  720d              jb       0x2278  ; -> loc_0000_2278
  0000:226B  f7d2              not      dx
  0000:226D  23c2              and      ax, dx
  0000:226F  2bc6              sub      ax, si
  0000:2271  e80c00            call     0x2280  ; -> sub_0000_2280  ; alarm_heapSplit
  0000:2274  7508              jne      0x227e  ; -> loc_0000_227E
  0000:2276  f7d2              not      dx

loc_0000_2278:
  0000:2278  d1ea              shr      dx, 1
  0000:227A  75e5              jne      0x2261  ; -> loc_0000_2261

loc_0000_227C:
  0000:227C  33c0              xor      ax, ax

loc_0000_227E:
  0000:227E  59                pop      cx
  0000:227F  c3                ret

; --- alarm_heapSplit ---
; Split heap block and update free list
alarm_heapSplit:  ; (sub_0000_2280)
  0000:2280  52                push     dx
  0000:2281  51                push     cx
  0000:2282  e81d00            call     0x22a2  ; -> sub_0000_22A2  ; alarm_sbrk
  0000:2285  7418              je       0x229f  ; -> loc_0000_229F
  0000:2287  57                push     di
  0000:2288  8bfe              mov      di, si
  0000:228A  8bf0              mov      si, ax
  0000:228C  03f2              add      si, dx
  0000:228E  c744fefeff        mov      word ptr [si - 2], 0xfffe
  0000:2293  897706            mov      word ptr [bx + 6], si
  0000:2296  8bd6              mov      dx, si
  0000:2298  2bd7              sub      dx, di
  0000:229A  4a                dec      dx
  0000:229B  8955fe            mov      word ptr [di - 2], dx
  0000:229E  58                pop      ax

loc_0000_229F:
  0000:229F  59                pop      cx
  0000:22A0  5a                pop      dx
  0000:22A1  c3                ret

; --- alarm_sbrk ---
; sbrk - extend heap via INT 21h/48h or 4Ah
alarm_sbrk:  ; (sub_0000_22A2)
  0000:22A2  53                push     bx
  0000:22A3  50                push     ax
  0000:22A4  33d2              xor      dx, dx
  0000:22A6  1e                push     ds
  0000:22A7  52                push     dx
  0000:22A8  52                push     dx
  0000:22A9  50                push     ax
  0000:22AA  b80100            mov      ax, 1
  0000:22AD  50                push     ax
  0000:22AE  06                push     es
  0000:22AF  1f                pop      ds
  0000:22B0  e86300            call     0x2316  ; -> sub_0000_2316  ; alarm_heapExtend
  0000:22B3  83c408            add      sp, 8
  0000:22B6  83faff            cmp      dx, -1
  0000:22B9  1f                pop      ds
  0000:22BA  5a                pop      dx
  0000:22BB  5b                pop      bx
  0000:22BC  7402              je       0x22c0  ; -> loc_0000_22C0
  0000:22BE  0bd2              or       dx, dx

loc_0000_22C0:
  0000:22C0  c3                ret
  0000:22C1  db 00                                              ; |.|

loc_0000_22C2:
  0000:22C2  55                push     bp
  0000:22C3  8bec              mov      bp, sp
  0000:22C5  57                push     di
  0000:22C6  56                push     si
  0000:22C7  8b7604            mov      si, word ptr [bp + 4]
  0000:22CA  33c0              xor      ax, ax
  0000:22CC  99                cdq
  0000:22CD  33db              xor      bx, bx

loc_0000_22CF:
  0000:22CF  ac                lodsb    al, byte ptr [si]
  0000:22D0  3c20              cmp      al, 0x20
  0000:22D2  74fb              je       0x22cf  ; -> loc_0000_22CF
  0000:22D4  3c09              cmp      al, 9
  0000:22D6  74f7              je       0x22cf  ; -> loc_0000_22CF
  0000:22D8  50                push     ax
  0000:22D9  3c2d              cmp      al, 0x2d
  0000:22DB  7404              je       0x22e1  ; -> loc_0000_22E1
  0000:22DD  3c2b              cmp      al, 0x2b
  0000:22DF  7501              jne      0x22e2  ; -> loc_0000_22E2

loc_0000_22E1:
  0000:22E1  ac                lodsb    al, byte ptr [si]

loc_0000_22E2:
  0000:22E2  3c39              cmp      al, 0x39
  0000:22E4  771f              ja       0x2305  ; -> loc_0000_2305
  0000:22E6  2c30              sub      al, 0x30
  0000:22E8  721b              jb       0x2305  ; -> loc_0000_2305
  0000:22EA  d1e3              shl      bx, 1
  0000:22EC  d1d2              rcl      dx, 1
  0000:22EE  8bcb              mov      cx, bx
  0000:22F0  8bfa              mov      di, dx
  0000:22F2  d1e3              shl      bx, 1
  0000:22F4  d1d2              rcl      dx, 1
  0000:22F6  d1e3              shl      bx, 1
  0000:22F8  d1d2              rcl      dx, 1
  0000:22FA  03d9              add      bx, cx
  0000:22FC  13d7              adc      dx, di
  0000:22FE  03d8              add      bx, ax
  0000:2300  83d200            adc      dx, 0
  0000:2303  ebdc              jmp      0x22e1  ; -> loc_0000_22E1

loc_0000_2305:
  0000:2305  58                pop      ax
  0000:2306  3c2d              cmp      al, 0x2d
  0000:2308  93                xchg     bx, ax
  0000:2309  7507              jne      0x2312  ; -> loc_0000_2312
  0000:230B  f7d8              neg      ax
  0000:230D  83d200            adc      dx, 0
  0000:2310  f7da              neg      dx

loc_0000_2312:
  0000:2312  5e                pop      si
  0000:2313  5f                pop      di
  0000:2314  5d                pop      bp
  0000:2315  c3                ret

; --- alarm_heapExtend ---
; Extend heap segment (near or far heap)
alarm_heapExtend:  ; (sub_0000_2316)
  0000:2316  55                push     bp
  0000:2317  8bec              mov      bp, sp
  0000:2319  56                push     si
  0000:231A  57                push     di
  0000:231B  06                push     es
  0000:231C  837e0800          cmp      word ptr [bp + 8], 0
  0000:2320  7538              jne      0x235a  ; -> loc_0000_235A
  0000:2322  bf7801            mov      di, 0x178
  0000:2325  8b5606            mov      dx, word ptr [bp + 6]
  0000:2328  8b4604            mov      ax, word ptr [bp + 4]
  0000:232B  48                dec      ax
  0000:232C  7507              jne      0x2335  ; -> loc_0000_2335
  0000:232E  e85300            call     0x2384  ; -> sub_0000_2384  ; alarm_findHeapSegment
  0000:2331  7227              jb       0x235a  ; -> loc_0000_235A
  0000:2333  eb48              jmp      0x237d  ; -> loc_0000_237D

loc_0000_2335:
  0000:2335  8b36c801          mov      si, word ptr [0x1c8]
  0000:2339  48                dec      ax
  0000:233A  7411              je       0x234d  ; -> loc_0000_234D
  0000:233C  3bf7              cmp      si, di
  0000:233E  740d              je       0x234d  ; -> loc_0000_234D
  0000:2340  8b4402            mov      ax, word ptr [si + 2]
  0000:2343  89460c            mov      word ptr [bp + 0xc], ax
  0000:2346  56                push     si
  0000:2347  e83a00            call     0x2384  ; -> sub_0000_2384  ; alarm_findHeapSegment
  0000:234A  5e                pop      si
  0000:234B  7330              jae      0x237d  ; -> loc_0000_237D

loc_0000_234D:
  0000:234D  83c604            add      si, 4
  0000:2350  81fec801          cmp      si, 0x1c8
  0000:2354  7304              jae      0x235a  ; -> loc_0000_235A
  0000:2356  0bd2              or       dx, dx
  0000:2358  7506              jne      0x2360  ; -> loc_0000_2360

loc_0000_235A:
  0000:235A  b8ffff            mov      ax, 0xffff
  0000:235D  99                cdq
  0000:235E  eb1d              jmp      0x237d  ; -> loc_0000_237D

loc_0000_2360:
  0000:2360  8bda              mov      bx, dx
  0000:2362  83c30f            add      bx, 0xf
  0000:2365  d1db              rcr      bx, 1
  0000:2367  b103              mov      cl, 3
  0000:2369  d3eb              shr      bx, cl
  0000:236B  b448              mov      ah, 0x48
  0000:236D  cd21              int      0x21  ; INT 21h/48h: Allocate memory
  0000:236F  72e9              jb       0x235a  ; -> loc_0000_235A
  0000:2371  92                xchg     dx, ax
  0000:2372  8904              mov      word ptr [si], ax
  0000:2374  895402            mov      word ptr [si + 2], dx
  0000:2377  8936c801          mov      word ptr [0x1c8], si
  0000:237B  33c0              xor      ax, ax

loc_0000_237D:
  0000:237D  07                pop      es
  0000:237E  5f                pop      di
  0000:237F  5e                pop      si
  0000:2380  8be5              mov      sp, bp
  0000:2382  5d                pop      bp
  0000:2383  c3                ret

; --- alarm_findHeapSegment ---
; Find heap segment with enough space
alarm_findHeapSegment:  ; (sub_0000_2384)
  0000:2384  8b4e0c            mov      cx, word ptr [bp + 0xc]
  0000:2387  8bf7              mov      si, di

loc_0000_2389:
  0000:2389  394c02            cmp      word ptr [si + 2], cx
  0000:238C  740c              je       0x239a  ; -> loc_0000_239A
  0000:238E  83c604            add      si, 4
  0000:2391  81fec801          cmp      si, 0x1c8
  0000:2395  75f2              jne      0x2389  ; -> loc_0000_2389
  0000:2397  f9                stc
  0000:2398  eb3f              jmp      0x23d9  ; -> loc_023D_0009

loc_0000_239A:
  0000:239A  8bda              mov      bx, dx
  0000:239C  031c              add      bx, word ptr [si]
  0000:239E  7239              jb       0x23d9  ; -> loc_023D_0009
  0000:23A0  8bd3              mov      dx, bx
  0000:23A2  8ec1              mov      es, cx
  0000:23A4  3bf7              cmp      si, di
  0000:23A6  7506              jne      0x23ae  ; -> loc_0000_23AE
  0000:23A8  391e7201          cmp      word ptr [0x172], bx
  0000:23AC  7326              jae      0x23d4  ; -> loc_023D_0004

loc_0000_23AE:
  0000:23AE  83c30f            add      bx, 0xf
  0000:23B1  d1db              rcr      bx, 1
  0000:23B3  d1eb              shr      bx, 1
  0000:23B5  d1eb              shr      bx, 1
  0000:23B7  d1eb              shr      bx, 1
  0000:23B9  3bf7              cmp      si, di
  0000:23BB  7509              jne      0x23c6  ; -> loc_0000_23C6
  0000:23BD  03d9              add      bx, cx
  0000:23BF  a1e901            mov      ax, word ptr [0x1e9]
  0000:23C2  2bd8              sub      bx, ax
  0000:23C4  8ec0              mov      es, ax

loc_0000_23C6:
  0000:23C6  b44a              mov      ah, 0x4a
  0000:23C8  cd21              int      0x21  ; INT 21h/4Ah: Resize memory block
  0000:23CA  720d              jb       0x23d9  ; -> loc_023D_0009
  0000:23CC  3bf7              cmp      si, di
  0000:23CE  7504              jne      0x23d4  ; -> loc_023D_0004

; ------------------------------------------------------------------------
; SEGMENT seg_023D  (176 bytes, file 0x25D0-0x2680)
; ------------------------------------------------------------------------
seg_023D:


; --- alarm_updateHeapTop ---
; Update heap top pointer after allocation
alarm_updateHeapTop:  ; (sub_023D_0000)
  023D:0000  89167201          mov      word ptr [0x172], dx

loc_023D_0004:
  023D:0004  92                xchg     dx, ax
  023D:0005  8704              xchg     word ptr [si], ax
  023D:0007  8bd1              mov      dx, cx

loc_023D_0009:
  023D:0009  c3                ret

; --- alarm_entryPoint ---
; MSC 5.x CRT startup / DM89 entry point
alarm_entryPoint:  ; (entry_point)
  023D:000A  b430              mov      ah, 0x30
  023D:000C  cd21              int      0x21  ; INT 21h/30h: Get DOS version
  023D:000E  3c02              cmp      al, 2
  023D:0010  7302              jae      0x14  ; -> loc_023D_0014
  023D:0012  cd20              int      0x20  ; INT 20h, AH=30h

loc_023D_0014:
  023D:0014  bf4802            mov      di, 0x248  ; RELOC->seg_0248
  023D:0017  8b360200          mov      si, word ptr [2]
  023D:001B  2bf7              sub      si, di
  023D:001D  81fe0010          cmp      si, 0x1000
  023D:0021  7203              jb       0x26  ; -> loc_023D_0026
  023D:0023  be0010            mov      si, 0x1000

loc_023D_0026:
  023D:0026  fa                cli
  023D:0027  8ed7              mov      ss, di
  023D:0029  81c4be18          add      sp, 0x18be
  023D:002D  fb                sti
  023D:002E  7314              jae      0x44  ; -> loc_023D_0044
  023D:0030  16                push     ss
  023D:0031  1f                pop      ds
  023D:0032  9acd0d0000        lcall    0, 0xdcd  ; -> sub_023D_0000 | RELOC->seg_0000
  023D:0037  33c0              xor      ax, ax
  023D:0039  50                push     ax
  023D:003A  9ad10d0000        lcall    0, 0xdd1  ; -> sub_023D_0000 | RELOC->seg_0000
  023D:003F  b8ff4c            mov      ax, 0x4cff
  023D:0042  cd21              int      0x21  ; INT 21h/4Ch: Exit with return code

loc_023D_0044:
  023D:0044  83e4fe            and      sp, 0xfffe
  023D:0047  3689267801        mov      word ptr ss:[0x178], sp
  023D:004C  3689267401        mov      word ptr ss:[0x174], sp
  023D:0051  8bc6              mov      ax, si
  023D:0053  b104              mov      cl, 4
  023D:0055  d3e0              shl      ax, cl
  023D:0057  48                dec      ax
  023D:0058  36a37201          mov      word ptr ss:[0x172], ax
  023D:005C  03f7              add      si, di
  023D:005E  89360200          mov      word ptr [2], si
  023D:0062  8cc3              mov      bx, es
  023D:0064  2bde              sub      bx, si
  023D:0066  f7db              neg      bx
  023D:0068  b44a              mov      ah, 0x4a
  023D:006A  cd21              int      0x21  ; INT 21h/4Ah: Resize memory block
  023D:006C  368c1ee901        mov      word ptr ss:[0x1e9], ds
  023D:0071  16                push     ss
  023D:0072  07                pop      es
  023D:0073  fc                cld
  023D:0074  bf2406            mov      di, 0x624
  023D:0077  b9c018            mov      cx, 0x18c0
  023D:007A  2bcf              sub      cx, di
  023D:007C  33c0              xor      ax, ax
  023D:007E  f3aa              rep stosb byte ptr es:[di], al
  023D:0080  16                push     ss
  023D:0081  1f                pop      ds
  023D:0082  06                push     es
  023D:0083  0e                push     cs
  023D:0084  07                pop      es
  023D:0085  9ac90d0000        lcall    0, 0xdc9  ; -> sub_023D_0000 | RELOC->seg_0000
  023D:008A  07                pop      es
  023D:008B  16                push     ss
  023D:008C  1f                pop      ds
  023D:008D  9aae0d0000        lcall    0, 0xdae  ; -> sub_023D_0000 | RELOC->seg_0000
  023D:0092  b84802            mov      ax, 0x248  ; RELOC->seg_0248
  023D:0095  8ed8              mov      ds, ax
  023D:0097  b80300            mov      ax, 3
  023D:009A  36c7067601ac0e    mov      word ptr ss:[0x176], 0xeac
  023D:00A1  9ad50d0000        lcall    0, 0xdd5  ; -> sub_023D_0000 | RELOC->seg_0000
  023D:00A6  0000              add      byte ptr [bx + si], al
  023D:00A8  0000              add      byte ptr [bx + si], al
  023D:00AA  0000              add      byte ptr [bx + si], al
  023D:00AC  0000              add      byte ptr [bx + si], al
  023D:00AE  0000              add      byte ptr [bx + si], al

; ------------------------------------------------------------------------
; SEGMENT seg_0248  (64 bytes, file 0x2680-0x26C0)
; ------------------------------------------------------------------------
seg_0248:

  0248:0000  0000              add      byte ptr [bx + si], al
  0248:0002  0000              add      byte ptr [bx + si], al
  0248:0004  0000              add      byte ptr [bx + si], al
  0248:0006  0000              add      byte ptr [bx + si], al
  0248:0008  4d                dec      bp
  0248:0009  53                push     bx
  0248:000A  205275            and      byte ptr [bp + si + 0x75], dl
  0248:000D  6e                outsb    dx, byte ptr [si]
  0248:000E  2d5469            sub      ax, 0x6954
  0248:0011  6d                insw     word ptr es:[di], dx
  0248:0012  65204c69          and      byte ptr gs:[si + 0x69], cl
  0248:0016  627261            bound    si, dword ptr [bp + si + 0x61]
  0248:0019  7279              jb       0x144
  0248:001B  202d              and      byte ptr [di], ch
  0248:001D  20436f            and      byte ptr [bp + di + 0x6f], al
  0248:0020  7079              jo       0x14b  ; -> loc_024C_010B
  0248:0022  7269              jb       0x13d
  0248:0024  67687420          push     0x2074
  0248:0028  286329            sub      byte ptr [bp + di + 0x29], ah
  0248:002B  2031              and      byte ptr [bx + di], dh
  0248:002D  3938              cmp      word ptr [bx + si], di
  0248:002F  382c              cmp      byte ptr [si], ch
  0248:0031  204d69            and      byte ptr [di + 0x69], cl
  0248:0034  63726f            arpl     word ptr [bp + si + 0x6f], si
  0248:0037  736f              jae      0x158
  0248:0039  667420            je       0x10c
  0248:003C  43                inc      bx
  0248:003D  6f                outsw    dx, word ptr [si]
  0248:003E  7270              jb       0x160

; ------------------------------------------------------------------------
; SEGMENT seg_024C  (1507 bytes, file 0x26C0-0x2CA3)
; ------------------------------------------------------------------------
seg_024C:

  024C:0000  1100              adc      word ptr [bx + si], ax
  024C:0002  44                inc      sp
  024C:0003  4d                dec      bp
  024C:0004  43                inc      bx
  024C:0005  53                push     bx
  024C:0006  52                push     dx
  024C:0007  0000              add      byte ptr [bx + si], al
  024C:0009  0000              add      byte ptr [bx + si], al
  024C:000B  0000              add      byte ptr [bx + si], al
  024C:000D  0000              add      byte ptr [bx + si], al
  024C:000F  0000              add      byte ptr [bx + si], al
  024C:0011  0000              add      byte ptr [bx + si], al
  024C:0013  00cd              add      ch, cl
  024C:0015  ab                stosw    word ptr es:[di], ax
  024C:0016  badc41            mov      dx, 0x41dc
  024C:0019  4c                dec      sp
  024C:001A  52                push     dx
  024C:001B  4d                dec      bp

loc_024C_001C:
  024C:001C  49                dec      cx
  024C:001D  4e                dec      si
  024C:001E  49                dec      cx
  024C:001F  54                push     sp
  024C:0020  0000              add      byte ptr [bx + si], al
  024C:0022  5b                pop      bx
  024C:0023  4f                dec      di
  024C:0024  4b                dec      bx
  024C:0025  5d                pop      bp
  024C:0026  0000              add      byte ptr [bx + si], al
  024C:0028  41                inc      cx
  024C:0029  6c                insb     byte ptr es:[di], dx
  024C:002A  61                popaw
  024C:002B  726d              jb       0x18a
  024C:002D  2000              and      byte ptr [bx + si], al
  024C:002F  0000              add      byte ptr [bx + si], al
  024C:0031  0001              add      byte ptr [bx + di], al
  024C:0033  0000              add      byte ptr [bx + si], al
  024C:0035  0000              add      byte ptr [bx + si], al
  024C:0037  ff00              inc      word ptr [bx + si]
  024C:0039  0000              add      byte ptr [bx + si], al
  024C:003B  0000              add      byte ptr [bx + si], al
  024C:003D  0000              add      byte ptr [bx + si], al
  024C:003F  0000              add      byte ptr [bx + si], al
  024C:0041  0000              add      byte ptr [bx + si], al
  024C:0043  0000              add      byte ptr [bx + si], al
  024C:0045  0000              add      byte ptr [bx + si], al
  024C:0047  0000              add      byte ptr [bx + si], al
  024C:0049  0000              add      byte ptr [bx + si], al
  024C:004B  0000              add      byte ptr [bx + si], al

loc_024C_004D:
  024C:004D  0000              add      byte ptr [bx + si], al
  024C:004F  0000              add      byte ptr [bx + si], al
  024C:0051  0000              add      byte ptr [bx + si], al
  024C:0053  0000              add      byte ptr [bx + si], al
  024C:0055  0000              add      byte ptr [bx + si], al
  024C:0057  0000              add      byte ptr [bx + si], al
  024C:0059  0000              add      byte ptr [bx + si], al

loc_024C_005B:
  024C:005B  0000              add      byte ptr [bx + si], al
  024C:005D  0000              add      byte ptr [bx + si], al
  024C:005F  0000              add      byte ptr [bx + si], al
  024C:0061  0000              add      byte ptr [bx + si], al
  024C:0063  0000              add      byte ptr [bx + si], al
  024C:0065  0000              add      byte ptr [bx + si], al
  024C:0067  0000              add      byte ptr [bx + si], al
  024C:0069  0000              add      byte ptr [bx + si], al
  024C:006B  0000              add      byte ptr [bx + si], al
  024C:006D  0000              add      byte ptr [bx + si], al
  024C:006F  0000              add      byte ptr [bx + si], al
  024C:0071  0000              add      byte ptr [bx + si], al
  024C:0073  0000              add      byte ptr [bx + si], al
  024C:0075  0000              add      byte ptr [bx + si], al
  024C:0077  0000              add      byte ptr [bx + si], al
  024C:0079  0000              add      byte ptr [bx + si], al
  024C:007B  0000              add      byte ptr [bx + si], al
  024C:007D  0000              add      byte ptr [bx + si], al
  024C:007F  0000              add      byte ptr [bx + si], al
  024C:0081  0000              add      byte ptr [bx + si], al
  024C:0083  0000              add      byte ptr [bx + si], al
  024C:0085  0000              add      byte ptr [bx + si], al
  024C:0087  0000              add      byte ptr [bx + si], al
  024C:0089  0000              add      byte ptr [bx + si], al
  024C:008B  0000              add      byte ptr [bx + si], al
  024C:008D  0000              add      byte ptr [bx + si], al
  024C:008F  0000              add      byte ptr [bx + si], al
  024C:0091  0000              add      byte ptr [bx + si], al
  024C:0093  0000              add      byte ptr [bx + si], al
  024C:0095  0000              add      byte ptr [bx + si], al
  024C:0097  0000              add      byte ptr [bx + si], al
  024C:0099  0000              add      byte ptr [bx + si], al
  024C:009B  0000              add      byte ptr [bx + si], al
  024C:009D  0000              add      byte ptr [bx + si], al
  024C:009F  0000              add      byte ptr [bx + si], al
  024C:00A1  0000              add      byte ptr [bx + si], al
  024C:00A3  0000              add      byte ptr [bx + si], al
  024C:00A5  0000              add      byte ptr [bx + si], al
  024C:00A7  0000              add      byte ptr [bx + si], al
  024C:00A9  0000              add      byte ptr [bx + si], al
  024C:00AB  0000              add      byte ptr [bx + si], al
  024C:00AD  0000              add      byte ptr [bx + si], al
  024C:00AF  0000              add      byte ptr [bx + si], al
  024C:00B1  0000              add      byte ptr [bx + si], al
  024C:00B3  0000              add      byte ptr [bx + si], al
  024C:00B5  0000              add      byte ptr [bx + si], al
  024C:00B7  0000              add      byte ptr [bx + si], al
  024C:00B9  0008              add      byte ptr [bx + si], cl
  024C:00BB  0000              add      byte ptr [bx + si], al
  024C:00BD  0001              add      byte ptr [bx + di], al
  024C:00BF  0000              add      byte ptr [bx + si], al
  024C:00C1  0000              add      byte ptr [bx + si], al
  024C:00C3  0001              add      byte ptr [bx + di], al
  024C:00C5  0000              add      byte ptr [bx + si], al
  024C:00C7  0000              add      byte ptr [bx + si], al
  024C:00C9  004445            add      byte ptr [si + 0x45], al
  024C:00CC  53                push     bx
  024C:00CD  4b                dec      bx
  024C:00CE  4d                dec      bp
  024C:00CF  41                inc      cx
  024C:00D0  54                push     sp
  024C:00D1  45                inc      bp
  024C:00D2  2400              and      al, 0
  024C:00D4  0000              add      byte ptr [bx + si], al
  024C:00D6  44                inc      sp
  024C:00D7  4d                dec      bp
  024C:00D8  43                inc      bx
  024C:00D9  4f                dec      di
  024C:00DA  4e                dec      si
  024C:00DB  46                inc      si
  024C:00DC  49                dec      cx
  024C:00DD  47                inc      di
  024C:00DE  005c00            add      byte ptr [si], bl
  024C:00E1  41                inc      cx
  024C:00E2  4c                dec      sp
  024C:00E3  41                inc      cx
  024C:00E4  52                push     dx
  024C:00E5  4d                dec      bp
  024C:00E6  2e43              inc      bx
  024C:00E8  46                inc      si
  024C:00E9  47                inc      di
  024C:00EA  0000              add      byte ptr [bx + si], al
  024C:00EC  41                inc      cx
  024C:00ED  6c                insb     byte ptr es:[di], dx
  024C:00EE  61                popaw
  024C:00EF  726d              jb       0x24e
  024C:00F1  20636f            and      byte ptr [bp + di + 0x6f], ah
  024C:00F4  6e                outsb    dx, byte ptr [si]
  024C:00F5  6669677572617469  imul     esp, dword ptr [bx + 0x75], 0x69746172
  024C:00FD  6f                outsw    dx, word ptr [si]
  024C:00FE  6e                outsb    dx, byte ptr [si]
  024C:00FF  206669            and      byte ptr [bp + 0x69], ah
  024C:0102  6c                insb     byte ptr es:[di], dx
  024C:0103  65206572          and      byte ptr gs:[di + 0x72], ah
  024C:0107  726f              jb       0x268
  024C:0109  7200              jb       0x1fb

loc_024C_010B:
  024C:010B  005045            add      byte ptr [bx + si + 0x45], dl
  024C:010E  52                push     dx
  024C:010F  53                push     bx
  024C:0110  4f                dec      di
  024C:0111  4e                dec      si
  024C:0112  41                inc      cx
  024C:0113  4c                dec      sp
  024C:0114  2e43              inc      bx
  024C:0116  41                inc      cx
  024C:0117  4c                dec      sp
  024C:0118  206e6f            and      byte ptr [bp + 0x6f], ch
  024C:011B  7420              je       0x22d
  024C:011D  666f              outsd    dx, dword ptr [si]
  024C:011F  756e              jne      0x27f
  024C:0121  640000            add      byte ptr fs:[bx + si], al
  024C:0124  4c                dec      sp
  024C:0125  49                dec      cx
  024C:0126  53                push     bx
  024C:0127  54                push     sp
  024C:0128  45                inc      bp
  024C:0129  4e                dec      si
  024C:012A  0000              add      byte ptr [bx + si], al
  024C:012C  3033              xor      byte ptr [bp + di], dh
  024C:012E  0000              add      byte ptr [bx + si], al
  024C:0130  6c                insb     byte ptr es:[di], dx
  024C:0131  0100              add      word ptr [bx + si], ax
  024C:0133  0000              add      byte ptr [bx + si], al
  024C:0135  00c3              add      bl, al
  024C:0137  0e                push     cs
  024C:0138  0000              add      byte ptr [bx + si], al
  024C:013A  48                dec      ax  ; RELOC->seg_0248
  024C:013B  0200              add      al, byte ptr [bx + si]

loc_024C_013D:
  024C:013D  0000              add      byte ptr [bx + si], al
  024C:013F  0000              add      byte ptr [bx + si], al
  024C:0141  0000              add      byte ptr [bx + si], al
  024C:0143  0000              add      byte ptr [bx + si], al
  024C:0145  0000              add      byte ptr [bx + si], al
  024C:0147  0000              add      byte ptr [bx + si], al
  024C:0149  0000              add      byte ptr [bx + si], al
  024C:014B  0000              add      byte ptr [bx + si], al
  024C:014D  0000              add      byte ptr [bx + si], al
  024C:014F  0000              add      byte ptr [bx + si], al
  024C:0151  0000              add      byte ptr [bx + si], al
  024C:0153  0000              add      byte ptr [bx + si], al
  024C:0155  0000              add      byte ptr [bx + si], al
  024C:0157  0000              add      byte ptr [bx + si], al
  024C:0159  0000              add      byte ptr [bx + si], al
  024C:015B  0000              add      byte ptr [bx + si], al
  024C:015D  0000              add      byte ptr [bx + si], al
  024C:015F  0000              add      byte ptr [bx + si], al
  024C:0161  0000              add      byte ptr [bx + si], al
  024C:0163  0000              add      byte ptr [bx + si], al
  024C:0165  0000              add      byte ptr [bx + si], al
  024C:0167  0000              add      byte ptr [bx + si], al
  024C:0169  0000              add      byte ptr [bx + si], al
  024C:016B  0000              add      byte ptr [bx + si], al
  024C:016D  0000              add      byte ptr [bx + si], al
  024C:016F  0000              add      byte ptr [bx + si], al
  024C:0171  0000              add      byte ptr [bx + si], al
  024C:0173  0000              add      byte ptr [bx + si], al
  024C:0175  0000              add      byte ptr [bx + si], al
  024C:0177  0000              add      byte ptr [bx + si], al
  024C:0179  0000              add      byte ptr [bx + si], al
  024C:017B  0000              add      byte ptr [bx + si], al
  024C:017D  0000              add      byte ptr [bx + si], al
  024C:017F  0000              add      byte ptr [bx + si], al
  024C:0181  0000              add      byte ptr [bx + si], al
  024C:0183  0000              add      byte ptr [bx + si], al
  024C:0185  0000              add      byte ptr [bx + si], al
  024C:0187  007801            add      byte ptr [bx + si + 1], bh
  024C:018A  3b435f            cmp      ax, word ptr [bp + di + 0x5f]
  024C:018D  46                inc      si
  024C:018E  49                dec      cx

loc_024C_018F:
  024C:018F  4c                dec      sp
  024C:0190  45                inc      bp
  024C:0191  5f                pop      di
  024C:0192  49                dec      cx
  024C:0193  4e                dec      si
  024C:0194  46                inc      si
  024C:0195  4f                dec      di
  024C:0196  0000              add      byte ptr [bx + si], al
  024C:0198  0000              add      byte ptr [bx + si], al
  024C:019A  0000              add      byte ptr [bx + si], al
  024C:019C  0000              add      byte ptr [bx + si], al
  024C:019E  0000              add      byte ptr [bx + si], al
  024C:01A0  0000              add      byte ptr [bx + si], al
  024C:01A2  0000              add      byte ptr [bx + si], al
  024C:01A4  0000              add      byte ptr [bx + si], al
  024C:01A6  0000              add      byte ptr [bx + si], al
  024C:01A8  0000              add      byte ptr [bx + si], al
  024C:01AA  0000              add      byte ptr [bx + si], al
  024C:01AC  0000              add      byte ptr [bx + si], al
  024C:01AE  0000              add      byte ptr [bx + si], al
  024C:01B0  1400              adc      al, 0
  024C:01B2  818181010100      add      word ptr [bx + di + 0x181], 1
  024C:01B8  0000              add      byte ptr [bx + si], al
  024C:01BA  0000              add      byte ptr [bx + si], al
  024C:01BC  0000              add      byte ptr [bx + si], al
  024C:01BE  0000              add      byte ptr [bx + si], al
  024C:01C0  0000              add      byte ptr [bx + si], al
  024C:01C2  0000              add      byte ptr [bx + si], al
  024C:01C4  0000              add      byte ptr [bx + si], al
  024C:01C6  0000              add      byte ptr [bx + si], al
  024C:01C8  0000              add      byte ptr [bx + si], al
  024C:01CA  0000              add      byte ptr [bx + si], al
  024C:01CC  1002              adc      byte ptr [bp + si], al
  024C:01CE  48                dec      ax  ; RELOC->seg_0248
  024C:01CF  024300            add      al, byte ptr [bp + di]
  024C:01D2  0000              add      byte ptr [bx + si], al
  024C:01D4  cdab              int      0xab  ; INT ABh
  024C:01D6  badc44            mov      dx, 0x44dc
  024C:01D9  4d                dec      bp
  024C:01DA  43                inc      bx
  024C:01DB  53                push     bx
  024C:01DC  52                push     dx
  024C:01DD  0000              add      byte ptr [bx + si], al
  024C:01DF  0000              add      byte ptr [bx + si], al
  024C:01E1  0031              add      byte ptr [bx + di], dh
  024C:01E3  3030              xor      byte ptr [bx + si], dh
  024C:01E5  304347            xor      byte ptr [bp + di + 0x47], al
  024C:01E8  41                inc      cx
  024C:01E9  004444            add      byte ptr [si + 0x44], al
  024C:01EC  47                inc      di
  024C:01ED  41                inc      cx
  024C:01EE  45                inc      bp
  024C:01EF  47                inc      di
  024C:01F0  41                inc      cx
  024C:01F1  004845            add      byte ptr [bx + si + 0x45], cl
  024C:01F4  52                push     dx
  024C:01F5  43                inc      bx
  024C:01F6  50                push     ax
  024C:01F7  4c                dec      sp
  024C:01F8  41                inc      cx
  024C:01F9  4e                dec      si
  024C:01FA  54                push     sp
  024C:01FB  43                inc      bx
  024C:01FC  31365443          xor      word ptr [0x4354], si
  024C:0200  3400              xor      al, 0
  024C:0202  56                push     si
  024C:0203  47                inc      di
  024C:0204  41                inc      cx
  024C:0205  004d43            add      byte ptr [di + 0x43], cl
  024C:0208  47                inc      di
  024C:0209  41                inc      cx
  024C:020A  4d                dec      bp
  024C:020B  0000              add      byte ptr [bx + si], al
  024C:020D  004c52            add      byte ptr [si + 0x52], cl
  024C:0210  45                inc      bp
  024C:0211  53                push     bx
  024C:0212  54                push     sp
  024C:0213  3235              xor      dh, byte ptr [di]
  024C:0215  3654              push     sp
  024C:0217  43                inc      bx
  024C:0218  3430              xor      al, 0x30
  024C:021A  48                dec      ax
  024C:021B  0000              add      byte ptr [bx + si], al
  024C:021D  004500            add      byte ptr [di], al
  024C:0220  0000              add      byte ptr [bx + si], al
  024C:0222  4d                dec      bp
  024C:0223  0000              add      byte ptr [bx + si], al
  024C:0225  0000              add      byte ptr [bx + si], al
  024C:0227  0000              add      byte ptr [bx + si], al
  024C:0229  00940800          add      byte ptr [si + 8], dl
  024C:022D  00940801          add      byte ptr [si + 0x108], dl
  024C:0231  0000              add      byte ptr [bx + si], al
  024C:0233  0000              add      byte ptr [bx + si], al
  024C:0235  0000              add      byte ptr [bx + si], al
  024C:0237  0002              add      byte ptr [bp + si], al
  024C:0239  0100              add      word ptr [bx + si], ax
  024C:023B  0000              add      byte ptr [bx + si], al
  024C:023D  0000              add      byte ptr [bx + si], al
  024C:023F  0002              add      byte ptr [bp + si], al
  024C:0241  0200              add      al, byte ptr [bx + si]
  024C:0243  0000              add      byte ptr [bx + si], al
  024C:0245  0000              add      byte ptr [bx + si], al
  024C:0247  00840300          add      byte ptr [si + 3], al
  024C:024B  0000              add      byte ptr [bx + si], al
  024C:024D  0000              add      byte ptr [bx + si], al
  024C:024F  0002              add      byte ptr [bp + si], al
  024C:0251  0400              add      al, 0
  024C:0253  0000              add      byte ptr [bx + si], al
  024C:0255  0000              add      byte ptr [bx + si], al
  024C:0257  0000              add      byte ptr [bx + si], al
  024C:0259  0000              add      byte ptr [bx + si], al
  024C:025B  0000              add      byte ptr [bx + si], al
  024C:025D  0000              add      byte ptr [bx + si], al
  024C:025F  0000              add      byte ptr [bx + si], al
  024C:0261  0000              add      byte ptr [bx + si], al
  024C:0263  0000              add      byte ptr [bx + si], al
  024C:0265  0000              add      byte ptr [bx + si], al
  024C:0267  0000              add      byte ptr [bx + si], al
  024C:0269  0000              add      byte ptr [bx + si], al
  024C:026B  0000              add      byte ptr [bx + si], al
  024C:026D  0000              add      byte ptr [bx + si], al
  024C:026F  0000              add      byte ptr [bx + si], al
  024C:0271  0000              add      byte ptr [bx + si], al
  024C:0273  0000              add      byte ptr [bx + si], al
  024C:0275  0000              add      byte ptr [bx + si], al
  024C:0277  0000              add      byte ptr [bx + si], al
  024C:0279  0000              add      byte ptr [bx + si], al
  024C:027B  0000              add      byte ptr [bx + si], al
  024C:027D  0000              add      byte ptr [bx + si], al
  024C:027F  0000              add      byte ptr [bx + si], al
  024C:0281  0000              add      byte ptr [bx + si], al
  024C:0283  0000              add      byte ptr [bx + si], al
  024C:0285  0000              add      byte ptr [bx + si], al
  024C:0287  0000              add      byte ptr [bx + si], al
  024C:0289  0000              add      byte ptr [bx + si], al
  024C:028B  0000              add      byte ptr [bx + si], al
  024C:028D  0000              add      byte ptr [bx + si], al
  024C:028F  0000              add      byte ptr [bx + si], al
  024C:0291  0000              add      byte ptr [bx + si], al
  024C:0293  0000              add      byte ptr [bx + si], al
  024C:0295  0000              add      byte ptr [bx + si], al
  024C:0297  0000              add      byte ptr [bx + si], al
  024C:0299  0000              add      byte ptr [bx + si], al
  024C:029B  0000              add      byte ptr [bx + si], al
  024C:029D  0000              add      byte ptr [bx + si], al
  024C:029F  0000              add      byte ptr [bx + si], al
  024C:02A1  0000              add      byte ptr [bx + si], al
  024C:02A3  0000              add      byte ptr [bx + si], al
  024C:02A5  0000              add      byte ptr [bx + si], al
  024C:02A7  0000              add      byte ptr [bx + si], al
  024C:02A9  0000              add      byte ptr [bx + si], al
  024C:02AB  0000              add      byte ptr [bx + si], al
  024C:02AD  0000              add      byte ptr [bx + si], al
  024C:02AF  0000              add      byte ptr [bx + si], al
  024C:02B1  0000              add      byte ptr [bx + si], al
  024C:02B3  0000              add      byte ptr [bx + si], al
  024C:02B5  0000              add      byte ptr [bx + si], al
  024C:02B7  0000              add      byte ptr [bx + si], al
  024C:02B9  0000              add      byte ptr [bx + si], al
  024C:02BB  0000              add      byte ptr [bx + si], al
  024C:02BD  0000              add      byte ptr [bx + si], al
  024C:02BF  0000              add      byte ptr [bx + si], al
  024C:02C1  0000              add      byte ptr [bx + si], al
  024C:02C3  0000              add      byte ptr [bx + si], al
  024C:02C5  0000              add      byte ptr [bx + si], al
  024C:02C7  0000              add      byte ptr [bx + si], al
  024C:02C9  0001              add      byte ptr [bx + di], al
  024C:02CB  0000              add      byte ptr [bx + si], al
  024C:02CD  0200              add      al, byte ptr [bx + si]
  024C:02CF  0000              add      byte ptr [bx + si], al
  024C:02D1  0000              add      byte ptr [bx + si], al
  024C:02D3  0000              add      byte ptr [bx + si], al
  024C:02D5  0000              add      byte ptr [bx + si], al
  024C:02D7  0000              add      byte ptr [bx + si], al
  024C:02D9  0000              add      byte ptr [bx + si], al
  024C:02DB  0000              add      byte ptr [bx + si], al
  024C:02DD  0000              add      byte ptr [bx + si], al
  024C:02DF  0000              add      byte ptr [bx + si], al
  024C:02E1  0000              add      byte ptr [bx + si], al
  024C:02E3  0000              add      byte ptr [bx + si], al
  024C:02E5  0000              add      byte ptr [bx + si], al
  024C:02E7  0000              add      byte ptr [bx + si], al
  024C:02E9  0000              add      byte ptr [bx + si], al
  024C:02EB  0000              add      byte ptr [bx + si], al
  024C:02ED  0000              add      byte ptr [bx + si], al
  024C:02EF  0000              add      byte ptr [bx + si], al
  024C:02F1  0000              add      byte ptr [bx + si], al
  024C:02F3  0000              add      byte ptr [bx + si], al
  024C:02F5  0000              add      byte ptr [bx + si], al
  024C:02F7  0000              add      byte ptr [bx + si], al
  024C:02F9  0000              add      byte ptr [bx + si], al
  024C:02FB  0000              add      byte ptr [bx + si], al
  024C:02FD  0000              add      byte ptr [bx + si], al
  024C:02FF  0000              add      byte ptr [bx + si], al
  024C:0301  0000              add      byte ptr [bx + si], al
  024C:0303  0000              add      byte ptr [bx + si], al
  024C:0305  0000              add      byte ptr [bx + si], al
  024C:0307  0000              add      byte ptr [bx + si], al
  024C:0309  0000              add      byte ptr [bx + si], al
  024C:030B  0000              add      byte ptr [bx + si], al
  024C:030D  0000              add      byte ptr [bx + si], al
  024C:030F  0000              add      byte ptr [bx + si], al
  024C:0311  0000              add      byte ptr [bx + si], al
  024C:0313  0000              add      byte ptr [bx + si], al
  024C:0315  0000              add      byte ptr [bx + si], al
  024C:0317  0000              add      byte ptr [bx + si], al
  024C:0319  0000              add      byte ptr [bx + si], al
  024C:031B  0000              add      byte ptr [bx + si], al
  024C:031D  0000              add      byte ptr [bx + si], al
  024C:031F  0000              add      byte ptr [bx + si], al
  024C:0321  0000              add      byte ptr [bx + si], al
  024C:0323  0000              add      byte ptr [bx + si], al
  024C:0325  0000              add      byte ptr [bx + si], al
  024C:0327  0000              add      byte ptr [bx + si], al
  024C:0329  0000              add      byte ptr [bx + si], al
  024C:032B  0000              add      byte ptr [bx + si], al
  024C:032D  0000              add      byte ptr [bx + si], al
  024C:032F  0000              add      byte ptr [bx + si], al
  024C:0331  0000              add      byte ptr [bx + si], al
  024C:0333  0000              add      byte ptr [bx + si], al
  024C:0335  0000              add      byte ptr [bx + si], al
  024C:0337  0000              add      byte ptr [bx + si], al
  024C:0339  0000              add      byte ptr [bx + si], al
  024C:033B  0000              add      byte ptr [bx + si], al
  024C:033D  0000              add      byte ptr [bx + si], al
  024C:033F  0000              add      byte ptr [bx + si], al
  024C:0341  0002              add      byte ptr [bp + si], al
  024C:0343  0300              add      ax, word ptr [bx + si]
  024C:0345  00ff              add      bh, bh
  024C:0347  ff1e003b          lcall    [0x3b00]
  024C:034B  005a00            add      byte ptr [bp + si], bl
  024C:034E  7800              js       0x440

loc_024C_0350:
  024C:0350  97                xchg     di, ax
  024C:0351  00b500d4          add      byte ptr [di - 0x2c00], dh
  024C:0355  00f3              add      bl, dh
  024C:0357  0011              add      byte ptr [bx + di], dl
  024C:0359  0130              add      word ptr [bx + si], si
  024C:035B  014e01            add      word ptr [bp + 1], cx
  024C:035E  6d                insw     word ptr es:[di], dx
  024C:035F  01ff              add      di, di
  024C:0361  ff1e003a          lcall    [0x3a00]
  024C:0365  005900            add      byte ptr [bx + di], bl
  024C:0368  7700              ja       0x45a

loc_024C_036A:
  024C:036A  96                xchg     si, ax
  024C:036B  00b400d3          add      byte ptr [si - 0x2d00], dh
  024C:036F  00f2              add      dl, dh
  024C:0371  0010              add      byte ptr [bx + si], dl
  024C:0373  012f              add      word ptr [bx], bp
  024C:0375  014d01            add      word ptr [di + 1], cx
  024C:0378  6c                insb     byte ptr es:[di], dx
  024C:0379  01545a            add      word ptr [si + 0x5a], dx
  024C:037C  0000              add      byte ptr [bx + si], al
  024C:037E  50                push     ax
  024C:037F  53                push     bx
  024C:0380  54                push     sp
  024C:0381  005044            add      byte ptr [bx + si + 0x44], dl
  024C:0384  54                push     sp
  024C:0385  00807000          add      byte ptr [bx + si + 0x70], al
  024C:0389  0001              add      byte ptr [bx + di], al
  024C:038B  00be03c2          add      byte ptr [bp - 0x3dfd], bh
  024C:038F  035375            add      dx, word ptr [bp + di + 0x75]
  024C:0392  6e                outsb    dx, byte ptr [si]
  024C:0393  4d                dec      bp
  024C:0394  6f                outsw    dx, word ptr [si]
  024C:0395  6e                outsb    dx, byte ptr [si]
  024C:0396  54                push     sp
  024C:0397  7565              jne      0x4ee
  024C:0399  57                push     di
  024C:039A  656454            push     sp
  024C:039D  687546            push     0x4675
  024C:03A0  7269              jb       0x4fb
  024C:03A2  53                push     bx
  024C:03A3  61                popaw
  024C:03A4  7400              je       0x496

loc_024C_03A6:
  024C:03A6  4a                dec      dx
  024C:03A7  61                popaw
  024C:03A8  6e                outsb    dx, byte ptr [si]
  024C:03A9  46                inc      si
  024C:03AA  65624d61          bound    cx, dword ptr gs:[di + 0x61]
  024C:03AE  7241              jb       0x4e1
  024C:03B0  7072              jo       0x514
  024C:03B2  4d                dec      bp
  024C:03B3  61                popaw
  024C:03B4  794a              jns      0x4f0
  024C:03B6  756e              jne      0x516
  024C:03B8  4a                dec      dx
  024C:03B9  756c              jne      0x517
  024C:03BB  41                inc      cx
  024C:03BC  7567              jne      0x515
  024C:03BE  53                push     bx
  024C:03BF  65704f            jo       0x501
  024C:03C2  63744e            arpl     word ptr [si + 0x4e], si
  024C:03C5  6f                outsw    dx, word ptr [si]
  024C:03C6  7644              jbe      0x4fc
  024C:03C8  656300            arpl     word ptr gs:[bx + si], ax
  024C:03CB  0000              add      byte ptr [bx + si], al
  024C:03CD  16                push     ss
  024C:03CE  0202              add      al, byte ptr [bp + si]
  024C:03D0  180d              sbb      byte ptr [di], cl
  024C:03D2  090c              or       word ptr [si], cx
  024C:03D4  0c0c              or       al, 0xc
  024C:03D6  07                pop      es
  024C:03D7  081616ff          or       byte ptr [0xff16], dl
  024C:03DB  120d              adc      cl, byte ptr [di]
  024C:03DD  1202              adc      al, byte ptr [bp + si]
  024C:03DF  ff00              inc      word ptr [bx + si]
  024C:03E1  0000              add      byte ptr [bx + si], al
  024C:03E3  0000              add      byte ptr [bx + si], al
  024C:03E5  0000              add      byte ptr [bx + si], al
  024C:03E7  0000              add      byte ptr [bx + si], al
  024C:03E9  0000              add      byte ptr [bx + si], al
  024C:03EB  2020              and      byte ptr [bx + si], ah
  024C:03ED  2020              and      byte ptr [bx + si], ah
  024C:03EF  2020              and      byte ptr [bx + si], ah

loc_024C_03F1:
  024C:03F1  2020              and      byte ptr [bx + si], ah
  024C:03F3  2028              and      byte ptr [bx + si], ch
  024C:03F5  2828              sub      byte ptr [bx + si], ch
  024C:03F7  2828              sub      byte ptr [bx + si], ch
  024C:03F9  2020              and      byte ptr [bx + si], ah
  024C:03FB  2020              and      byte ptr [bx + si], ah
  024C:03FD  2020              and      byte ptr [bx + si], ah
  024C:03FF  2020              and      byte ptr [bx + si], ah
  024C:0401  2020              and      byte ptr [bx + si], ah
  024C:0403  2020              and      byte ptr [bx + si], ah
  024C:0405  2020              and      byte ptr [bx + si], ah
  024C:0407  2020              and      byte ptr [bx + si], ah
  024C:0409  2020              and      byte ptr [bx + si], ah

loc_024C_040B:
  024C:040B  48                dec      ax

loc_024C_040C:
  024C:040C  1010              adc      byte ptr [bx + si], dl
  024C:040E  1010              adc      byte ptr [bx + si], dl
  024C:0410  1010              adc      byte ptr [bx + si], dl
  024C:0412  1010              adc      byte ptr [bx + si], dl
  024C:0414  1010              adc      byte ptr [bx + si], dl
  024C:0416  1010              adc      byte ptr [bx + si], dl
  024C:0418  1010              adc      byte ptr [bx + si], dl
  024C:041A  10848484          adc      byte ptr [si - 0x7b7c], al
  024C:041E  84848484          test     byte ptr [si - 0x7b7c], al
  024C:0422  84848410          test     byte ptr [si + 0x1084], al

loc_024C_0426:
  024C:0426  1010              adc      byte ptr [bx + si], dl
  024C:0428  1010              adc      byte ptr [bx + si], dl
  024C:042A  1010              adc      byte ptr [bx + si], dl
  024C:042C  818181818181      add      word ptr [bx + di - 0x7e7f], 0x8181
  024C:0432  0101              add      word ptr [bx + di], ax
  024C:0434  0101              add      word ptr [bx + di], ax
  024C:0436  0101              add      word ptr [bx + di], ax
  024C:0438  0101              add      word ptr [bx + di], ax
  024C:043A  0101              add      word ptr [bx + di], ax
  024C:043C  0101              add      word ptr [bx + di], ax
  024C:043E  0101              add      word ptr [bx + di], ax
  024C:0440  0101              add      word ptr [bx + di], ax
  024C:0442  0101              add      word ptr [bx + di], ax
  024C:0444  0101              add      word ptr [bx + di], ax
  024C:0446  1010              adc      byte ptr [bx + si], dl
  024C:0448  1010              adc      byte ptr [bx + si], dl
  024C:044A  1010              adc      byte ptr [bx + si], dl
  024C:044C  8282828282        add      byte ptr [bp + si - 0x7d7e], 0x82
  024C:0451  820202            add      byte ptr [bp + si], 2
  024C:0454  0202              add      al, byte ptr [bp + si]
  024C:0456  0202              add      al, byte ptr [bp + si]
  024C:0458  0202              add      al, byte ptr [bp + si]
  024C:045A  0202              add      al, byte ptr [bp + si]
  024C:045C  0202              add      al, byte ptr [bp + si]
  024C:045E  0202              add      al, byte ptr [bp + si]
  024C:0460  0202              add      al, byte ptr [bp + si]
  024C:0462  0202              add      al, byte ptr [bp + si]
  024C:0464  0202              add      al, byte ptr [bp + si]
  024C:0466  1010              adc      byte ptr [bx + si], dl
  024C:0468  1010              adc      byte ptr [bx + si], dl
  024C:046A  2000              and      byte ptr [bx + si], al
  024C:046C  0000              add      byte ptr [bx + si], al
  024C:046E  0000              add      byte ptr [bx + si], al
  024C:0470  0000              add      byte ptr [bx + si], al
  024C:0472  0000              add      byte ptr [bx + si], al
  024C:0474  0000              add      byte ptr [bx + si], al
  024C:0476  0000              add      byte ptr [bx + si], al
  024C:0478  0000              add      byte ptr [bx + si], al
  024C:047A  0000              add      byte ptr [bx + si], al
  024C:047C  0000              add      byte ptr [bx + si], al
  024C:047E  0000              add      byte ptr [bx + si], al
  024C:0480  0000              add      byte ptr [bx + si], al
  024C:0482  0000              add      byte ptr [bx + si], al
  024C:0484  0000              add      byte ptr [bx + si], al
  024C:0486  0000              add      byte ptr [bx + si], al
  024C:0488  0000              add      byte ptr [bx + si], al
  024C:048A  0000              add      byte ptr [bx + si], al
  024C:048C  0000              add      byte ptr [bx + si], al
  024C:048E  0000              add      byte ptr [bx + si], al
  024C:0490  0000              add      byte ptr [bx + si], al
  024C:0492  0000              add      byte ptr [bx + si], al
  024C:0494  0000              add      byte ptr [bx + si], al
  024C:0496  0000              add      byte ptr [bx + si], al
  024C:0498  0000              add      byte ptr [bx + si], al
  024C:049A  0000              add      byte ptr [bx + si], al
  024C:049C  0000              add      byte ptr [bx + si], al
  024C:049E  0000              add      byte ptr [bx + si], al
  024C:04A0  0000              add      byte ptr [bx + si], al
  024C:04A2  0000              add      byte ptr [bx + si], al
  024C:04A4  0000              add      byte ptr [bx + si], al
  024C:04A6  0000              add      byte ptr [bx + si], al
  024C:04A8  0000              add      byte ptr [bx + si], al
  024C:04AA  0000              add      byte ptr [bx + si], al
  024C:04AC  0000              add      byte ptr [bx + si], al
  024C:04AE  0000              add      byte ptr [bx + si], al
  024C:04B0  0000              add      byte ptr [bx + si], al
  024C:04B2  0000              add      byte ptr [bx + si], al
  024C:04B4  0000              add      byte ptr [bx + si], al
  024C:04B6  0000              add      byte ptr [bx + si], al
  024C:04B8  0000              add      byte ptr [bx + si], al
  024C:04BA  0000              add      byte ptr [bx + si], al
  024C:04BC  0000              add      byte ptr [bx + si], al
  024C:04BE  0000              add      byte ptr [bx + si], al
  024C:04C0  0000              add      byte ptr [bx + si], al
  024C:04C2  0000              add      byte ptr [bx + si], al
  024C:04C4  0000              add      byte ptr [bx + si], al
  024C:04C6  0000              add      byte ptr [bx + si], al
  024C:04C8  0000              add      byte ptr [bx + si], al
  024C:04CA  0000              add      byte ptr [bx + si], al
  024C:04CC  0000              add      byte ptr [bx + si], al
  024C:04CE  0000              add      byte ptr [bx + si], al
  024C:04D0  0000              add      byte ptr [bx + si], al
  024C:04D2  0000              add      byte ptr [bx + si], al
  024C:04D4  0000              add      byte ptr [bx + si], al
  024C:04D6  0000              add      byte ptr [bx + si], al
  024C:04D8  0000              add      byte ptr [bx + si], al
  024C:04DA  0000              add      byte ptr [bx + si], al
  024C:04DC  0000              add      byte ptr [bx + si], al
  024C:04DE  0000              add      byte ptr [bx + si], al
  024C:04E0  0000              add      byte ptr [bx + si], al
  024C:04E2  0000              add      byte ptr [bx + si], al
  024C:04E4  0000              add      byte ptr [bx + si], al
  024C:04E6  0000              add      byte ptr [bx + si], al
  024C:04E8  0000              add      byte ptr [bx + si], al
  024C:04EA  0000              add      byte ptr [bx + si], al
  024C:04EC  c01900            rcr      byte ptr [bx + di], 0
  024C:04EF  0000              add      byte ptr [bx + si], al
  024C:04F1  0000              add      byte ptr [bx + si], al
  024C:04F3  0000              add      byte ptr [bx + si], al
  024C:04F5  2000              and      byte ptr [bx + si], al
  024C:04F7  0000              add      byte ptr [bx + si], al
  024C:04F9  0000              add      byte ptr [bx + si], al
  024C:04FB  0000              add      byte ptr [bx + si], al
  024C:04FD  0000              add      byte ptr [bx + si], al
  024C:04FF  0000              add      byte ptr [bx + si], al
  024C:0501  0000              add      byte ptr [bx + si], al
  024C:0503  0000              add      byte ptr [bx + si], al
  024C:0505  0000              add      byte ptr [bx + si], al
  024C:0507  00aa203c          add      byte ptr [bp + si + 0x3c20], ch
  024C:050B  3c4e              cmp      al, 0x4e
  024C:050D  4d                dec      bp
  024C:050E  53                push     bx
  024C:050F  47                inc      di
  024C:0510  3e3e0000          add      byte ptr ds:[bx + si], al
  024C:0514  52                push     dx
  024C:0515  363030            xor      byte ptr ss:[bx + si], dh
  024C:0518  300d              xor      byte ptr [di], cl
  024C:051A  0a2d              or       ch, byte ptr [di]
  024C:051C  207374            and      byte ptr [bp + di + 0x74], dh
  024C:051F  61                popaw
  024C:0520  636b20            arpl     word ptr [bp + di + 0x20], bp
  024C:0523  6f                outsw    dx, word ptr [si]
  024C:0524  7665              jbe      0x67b
  024C:0526  7266              jb       0x67e
  024C:0528  6c                insb     byte ptr es:[di], dx
  024C:0529  6f                outsw    dx, word ptr [si]
  024C:052A  770d              ja       0x629
  024C:052C  0a00              or       al, byte ptr [bx + si]
  024C:052E  0300              add      ax, word ptr [bx + si]
  024C:0530  52                push     dx
  024C:0531  363030            xor      byte ptr ss:[bx + si], dh
  024C:0534  330d              xor      cx, word ptr [di]
  024C:0536  0a2d              or       ch, byte ptr [di]
  024C:0538  20696e            and      byte ptr [bx + di + 0x6e], ch
  024C:053B  7465              je       0x692
  024C:053D  67657220          jb       0x651
  024C:0541  646976696465      imul     si, word ptr fs:[bp + 0x69], 0x6564
  024C:0547  206279            and      byte ptr [bp + si + 0x79], ah
  024C:054A  2030              and      byte ptr [bx + si], dh
  024C:054C  0d0a00            or       ax, 0xa
  024C:054F  0900              or       word ptr [bx + si], ax
  024C:0551  52                push     dx
  024C:0552  363030            xor      byte ptr ss:[bx + si], dh
  024C:0555  390d              cmp      word ptr [di], cx
  024C:0557  0a2d              or       ch, byte ptr [di]
  024C:0559  206e6f            and      byte ptr [bp + 0x6f], ch
  024C:055C  7420              je       0x66e
  024C:055E  656e              outsb    dx, byte ptr gs:[si]
  024C:0560  6f                outsw    dx, word ptr [si]

loc_024C_0561:
  024C:0561  7567              jne      0x6ba
  024C:0563  682073            push     0x7320
  024C:0566  7061              jo       0x6b9
  024C:0568  636520            arpl     word ptr [di + 0x20], sp
  024C:056B  666f              outsd    dx, dword ptr [si]
  024C:056D  7220              jb       0x67f
  024C:056F  656e              outsb    dx, byte ptr gs:[si]
  024C:0571  7669              jbe      0x6cc
  024C:0573  726f              jb       0x6d4
  024C:0575  6e                outsb    dx, byte ptr [si]
  024C:0576  6d                insw     word ptr es:[di], dx
  024C:0577  656e              outsb    dx, byte ptr gs:[si]
  024C:0579  740d              je       0x678
  024C:057B  0a00              or       al, byte ptr [bx + si]
  024C:057D  fc                cld

loc_024C_057E:
  024C:057E  000d              add      byte ptr [di], cl
  024C:0580  0a00              or       al, byte ptr [bx + si]
  024C:0582  ff00              inc      word ptr [bx + si]
  024C:0584  7275              jb       0x6eb
  024C:0586  6e                outsb    dx, byte ptr [si]
  024C:0587  2d7469            sub      ax, 0x6974
  024C:058A  6d                insw     word ptr es:[di], dx

loc_024C_058B:
  024C:058B  65206572          and      byte ptr gs:[di + 0x72], ah

loc_024C_058F:
  024C:058F  726f              jb       0x6f0
  024C:0591  7220              jb       0x6a3
  024C:0593  0002              add      byte ptr [bp + si], al
  024C:0595  005236            add      byte ptr [bp + si + 0x36], dl
  024C:0598  3030              xor      byte ptr [bx + si], dh
  024C:059A  320d              xor      cl, byte ptr [di]
  024C:059C  0a2d              or       ch, byte ptr [di]
  024C:059E  20666c            and      byte ptr [bp + 0x6c], ah
  024C:05A1  6f                outsw    dx, word ptr [si]

loc_024C_05A2:
  024C:05A2  61                popaw
  024C:05A3  7469              je       0x6fe
  024C:05A5  6e                outsb    dx, byte ptr [si]
  024C:05A6  6720706f          and      byte ptr [eax + 0x6f], dh
  024C:05AA  696e74206e        imul     bp, word ptr [bp + 0x74], 0x6e20
  024C:05AF  6f                outsw    dx, word ptr [si]
  024C:05B0  7420              je       0x6c2
  024C:05B2  6c                insb     byte ptr es:[di], dx

loc_024C_05B3:
  024C:05B3  6f                outsw    dx, word ptr [si]
  024C:05B4  61                popaw
  024C:05B5  6465640d0a00      or       ax, 0xa
  024C:05BB  0100              add      word ptr [bx + si], ax
  024C:05BD  52                push     dx
  024C:05BE  363030            xor      byte ptr ss:[bx + si], dh
  024C:05C1  310d              xor      word ptr [di], cx
  024C:05C3  0a2d              or       ch, byte ptr [di]
  024C:05C5  206e75            and      byte ptr [bp + 0x75], ch
  024C:05C8  6c                insb     byte ptr es:[di], dx

loc_024C_05C9:
  024C:05C9  6c                insb     byte ptr es:[di], dx

loc_024C_05CA:
  024C:05CA  20706f            and      byte ptr [bx + si + 0x6f], dh
  024C:05CD  696e746572        imul     bp, word ptr [bp + 0x74], 0x7265

loc_024C_05D2:
  024C:05D2  206173            and      byte ptr [bx + di + 0x73], ah
  024C:05D5  7369              jae      0x730
  024C:05D7  676e              outsb    dx, byte ptr [esi]
  024C:05D9  6d                insw     word ptr es:[di], dx
  024C:05DA  656e              outsb    dx, byte ptr gs:[si]

loc_024C_05DC:
  024C:05DC  740d              je       0x6db
  024C:05DE  0a00              or       al, byte ptr [bx + si]
  024C:05E0  db FF FF FF                                        ; |...|
