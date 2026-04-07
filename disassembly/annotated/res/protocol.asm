; ========================================================================
; PROTOCOL.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; PROTOCOL.RES is the file transfer protocol module for DeskMate 3.05.
; It implements XMODEM and YMODEM file transfer protocols used by the
; Telecom terminal emulator (TELECOM.PDM) for sending and receiving
; files over serial connections.
;
; The module handles the full protocol state machine including:
;   - XMODEM: 128-byte blocks, checksum or CRC-16 error detection
;   - YMODEM: 1024-byte blocks, batch file transfer, CRC-16
;   - Packet framing (SOH/STX/EOT/ACK/NAK/CAN)
;   - Timeout and retry logic
;   - Flow control coordination with the serial port driver
;
; The module communicates with TELECOM.PDM through a callback interface
; for serial I/O operations (send byte, receive byte, check ready).
;
; DM89 imports: INT E0h (DeskMate host API)
; Uses: INT 1Ah (timer), INT 21h for file I/O
;

; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- PROTOCOL.RES Functions ---
;
; Address          Name                              Description
; -------          ----                              -----------
; 0000:0000        protocol_dispatchTable            Protocol function dispatch table (7 entries)
; 0000:00EE        protocol_mainHandler              Main protocol handler - dispatch send/receive commands
; 0000:03E7        protocol_initState                Initialize protocol state machine
; 0000:040B        protocol_cleanupState             Clean up protocol state on completion/abort
; 0000:0497        protocol_getTimerTick             Get timer tick count via INT 1Ah for timeouts
; 0000:049F        protocol_waitWithTimeout          Wait for event with timeout (recursive retry)
; 0000:0534        protocol_checkTimeout             Check if timeout has elapsed (2 callers)
; 0000:0570        protocol_sendFile                 XMODEM/YMODEM send file top-level handler
; 0000:065A        protocol_sendByte                 Send single byte to serial port (3 callers)
; 0000:06A2        protocol_setCallback              Set serial I/O callback function pointer
; 0000:06B0        protocol_setOptions               Set protocol options (block size, CRC mode)
; 0000:06DA        protocol_transferLoop             Main transfer loop - send/receive blocks (7 callers)
; 0000:07A9        protocol_buildPacket              Build XMODEM/YMODEM packet (header + data + checksum)
; 0000:0838        protocol_validatePacket           Validate received packet (checksum/CRC, 3 callers)
; 0000:0845        protocol_receiveFile              XMODEM/YMODEM receive file handler
; 0000:092A        protocol_sendACK                  Send ACK byte (0x06) to remote (4 callers)
; 0000:0942        protocol_sendNAK                  Send NAK byte (0x15) to request retransmit (2 callers)
; 0000:0954        protocol_sendCAN                  Send CAN byte (0x18) to abort transfer (2 callers)
; 0000:098A        protocol_receiveByte              Receive single byte from serial port with timeout
; 0000:0A27        protocol_receiveBlock             Receive one data block (128 or 1024 bytes)
; 0000:0AA5        protocol_writeToFile              Write received block to output file (2 callers)
; 0000:0AE6        protocol_handleYmodemBatch        Handle YMODEM batch header (filename/size block)
; 0000:0AFA        protocol_readFromFile             Read next block from input file for sending (4 callers)
; 0000:0B48        protocol_processBlock             Process one transfer block (send or receive, 5 callers)
; 0000:0CA6        protocol_handleRetry              Handle retry after NAK/timeout (4 callers)
; 0000:0CCC        protocol_xmodemSendBlock          XMODEM-specific send block with ACK wait
; 0000:0D59        protocol_calculateCRC             Calculate CRC-16 for data block (2 callers)
; 0000:0DE2        protocol_initXmodem               Initialize XMODEM protocol parameters
; 0000:0E26        protocol_crcUpdate                Update CRC-16 with new data byte
; 0000:0EA9        protocol_ymodemReceive            YMODEM receive protocol state machine
; 0000:10CA        protocol_ymodemSend               YMODEM send protocol state machine
; 0000:1138        protocol_setBlockSize128          Set block size to 128 bytes (XMODEM standard)
; 0000:1152        protocol_setBlockSize1024         Set block size to 1024 bytes (YMODEM)
; 0000:1175        protocol_enableCRC                Enable CRC-16 mode (vs checksum)
; 0000:117C        protocol_openOutputFile           Open output file for received data (2 callers)
; 0000:11F3        protocol_openInputFile            Open input file for sending
; 0000:1225        protocol_closeTransferFile        Close transfer file handle
; 0000:1293        protocol_updateProgress           Update transfer progress display (2 callers)
; 0000:131B        protocol_calculateChecksum        Calculate simple checksum for XMODEM
; 0000:136C        protocol_parseBatchFilename       Parse YMODEM batch filename from block 0
; 0000:1417        protocol_getProtocolName          Get current protocol name string
; 0000:1425        protocol_getTransferDir           Get transfer direction string (Send/Receive)
; 0000:143C        protocol_setStatusMsg             Set status message for display
; 0000:1449        protocol_getErrorMsg              Get error message string
; 0000:144F        protocol_setErrorState            Set protocol error state
; 0000:1457        protocol_clearError               Clear protocol error state
; 0000:145B        protocol_serialIO                 Serial I/O wrapper - call Telecom callback (3 callers)
; 0000:1512        protocol_initXmodemState          Initialize XMODEM protocol state machine
; 0000:1536        protocol_initYmodemState          Initialize YMODEM protocol state machine
; 0000:1606        protocol_resetTransfer            Reset transfer state for new transfer
; 0000:1614        protocol_intE0hDispatch           INT E0h dispatch table (4 entries)
; 0000:1672        protocol_getCallbackA             Get serial callback A (2 callers)
; 0000:1678        protocol_getCallbackB             Get serial callback B (2 callers)
; 0000:167E        protocol_getCallbackC             Get serial callback C
; 0000:1684        protocol_getCallbackD             Get serial callback D
; 0000:168A        protocol_getCallbackE             Get serial callback E
; 0000:1690        protocol_getCallbackF             Get serial callback F
; 0000:17D4        protocol_crtInit                  MSC CRT initialization
; 0000:1898        protocol_crtSetup                 MSC CRT data segment setup
; 0000:18F4        protocol_crtCloseFiles            MSC CRT close open file handles
; 0000:1921        protocol_setIntVector             Set interrupt vector (INT 21h/25h, 4 callers)
; 0000:1930        protocol_getIntVector             Get interrupt vector (INT 21h/35h, 2 callers)
; 0000:1944        protocol_resizeMemory             Resize memory block (INT 21h/4Ah, 3 callers)
; 0000:1964        protocol_exitCleanup              Exit cleanup and terminate
; 0000:1B82        protocol_heapTop                  Get/update heap top pointer
; 0000:1BAD        protocol_allocMemory              Allocate memory from heap (5 callers)
; 0000:1BD6        protocol_formatTransferStr        Format transfer statistics string (3 callers)
; 0000:1C28        protocol_packetHeader             Build packet header bytes (2 callers)
; 0000:1C54        protocol_crcTable                 CRC-16 table lookup (2 callers)
; 0000:1C82        protocol_packetChecksum           Compute and append packet checksum/CRC
; 0000:1C94        protocol_terminateResident        TSR exit via INT 21h/31h
; 0000:1CD6        protocol_printf                   Formatted output (printf-like)
; 0000:1DEC        protocol_flushOutput              Flush output stream buffer
; 0000:1DFC        protocol_writeOutput              Write formatted output to file/device
; 0000:1EAC        protocol_seekStream               Seek stream position
; 0000:1F76        protocol_putChar                  Write single character to output stream (5 callers)
; 0000:1FAA        protocol_writeString              Write string to output (2 callers)
; 0000:1FD2        protocol_writeNewline             Write newline to output
; 0000:1FD6        protocol_formatNumber             Format number for output
; 0000:2034        protocol_divmod10                 Divide by 10 for decimal formatting (2 callers)
; 0000:2050        protocol_outputDigit              Output single decimal digit
;


seg_0000:


; --- protocol_dispatchTable ---
; Protocol function dispatch table (7 entries)
protocol_dispatchTable:  ; (sub_0000_0000)
  0000:0000  0000              add      byte ptr [bx + si], al
  0000:0002  0000              add      byte ptr [bx + si], al
  0000:0004  0000              add      byte ptr [bx + si], al
  0000:0006  0000              add      byte ptr [bx + si], al
  0000:0008  0000              add      byte ptr [bx + si], al
  0000:000A  0000              add      byte ptr [bx + si], al
  0000:000C  0000              add      byte ptr [bx + si], al
  0000:000E  0000              add      byte ptr [bx + si], al

; --- protocol_entryPoint ---
; MSC 5.x CRT startup / DM89 entry point
protocol_entryPoint:  ; (entry_point)
  0000:0010  b430              mov      ah, 0x30
  0000:0012  cd21              int      0x21  ; INT 21h/30h: Get DOS version
  0000:0014  3c02              cmp      al, 2
  0000:0016  7302              jae      0x1a  ; -> loc_0000_001A
  0000:0018  cd20              int      0x20  ; INT 20h, AH=30h

loc_0000_001A:
  0000:001A  bf0e02            mov      di, 0x20e  ; RELOC->seg_020E
  0000:001D  8b360200          mov      si, word ptr [2]
  0000:0021  2bf7              sub      si, di
  0000:0023  81fe0010          cmp      si, 0x1000
  0000:0027  7203              jb       0x2c  ; -> loc_0000_002C
  0000:0029  be0010            mov      si, 0x1000

loc_0000_002C:
  0000:002C  fa                cli
  0000:002D  8ed7              mov      ss, di
  0000:002F  81c4ae1e          add      sp, 0x1eae
  0000:0033  fb                sti
  0000:0034  7310              jae      0x46  ; -> loc_0000_0046
  0000:0036  16                push     ss
  0000:0037  1f                pop      ds
  0000:0038  e80919            call     0x1944  ; -> sub_0000_1944  ; protocol_resizeMemory
  0000:003B  33c0              xor      ax, ax
  0000:003D  50                push     ax
  0000:003E  e86c1b            call     0x1bad  ; -> sub_0000_1BAD  ; protocol_allocMemory
  0000:0041  b8ff4c            mov      ax, 0x4cff
  0000:0044  cd21              int      0x21  ; INT 21h/4Ch: Exit with return code

loc_0000_0046:
  0000:0046  83e4fe            and      sp, 0xfffe
  0000:0049  3689264800        mov      word ptr ss:[0x48], sp
  0000:004E  3689264400        mov      word ptr ss:[0x44], sp
  0000:0053  8bc6              mov      ax, si
  0000:0055  b104              mov      cl, 4
  0000:0057  d3e0              shl      ax, cl
  0000:0059  48                dec      ax
  0000:005A  36a34200          mov      word ptr ss:[0x42], ax
  0000:005E  03f7              add      si, di
  0000:0060  89360200          mov      word ptr [2], si
  0000:0064  8cc3              mov      bx, es
  0000:0066  2bde              sub      bx, si
  0000:0068  f7db              neg      bx
  0000:006A  b44a              mov      ah, 0x4a
  0000:006C  cd21              int      0x21  ; INT 21h/4Ah: Resize memory block
  0000:006E  368c1e6f07        mov      word ptr ss:[0x76f], ds
  0000:0073  16                push     ss
  0000:0074  07                pop      es
  0000:0075  fc                cld
  0000:0076  bf140a            mov      di, 0xa14
  0000:0079  b9b01e            mov      cx, 0x1eb0
  0000:007C  2bcf              sub      cx, di
  0000:007E  33c0              xor      ax, ax
  0000:0080  f3aa              rep stosb byte ptr es:[di], al
  0000:0082  16                push     ss
  0000:0083  1f                pop      ds
  0000:0084  e84d17            call     0x17d4  ; -> sub_0000_17D4  ; protocol_crtInit
  0000:0087  16                push     ss
  0000:0088  1f                pop      ds
  0000:0089  33ed              xor      bp, bp
  0000:008B  ff369007          push     word ptr [0x790]
  0000:008F  ff368e07          push     word ptr [0x78e]
  0000:0093  ff368c07          push     word ptr [0x78c]
  0000:0097  e85400            call     0xee  ; -> sub_0000_00EE  ; protocol_mainHandler
  0000:009A  50                push     ax
  0000:009B  e8fa17            call     0x1898  ; -> sub_0000_1898  ; protocol_crtSetup
  0000:009E  b80e02            mov      ax, 0x20e  ; RELOC->seg_020E
  0000:00A1  8ed8              mov      ds, ax
  0000:00A3  b80300            mov      ax, 3
  0000:00A6  36c70646009818    mov      word ptr ss:[0x46], 0x1898

loc_0000_00AD:
  0000:00AD  50                push     ax
  0000:00AE  e89318            call     0x1944  ; -> sub_0000_1944  ; protocol_resizeMemory
  0000:00B1  e8f91a            call     0x1bad  ; -> sub_0000_1BAD  ; protocol_allocMemory
  0000:00B4  b8ff00            mov      ax, 0xff
  0000:00B7  50                push     ax
  0000:00B8  ff164600          call     word ptr [0x46]
  0000:00BC  e901fd            jmp      0xfffffdc0
  0000:00BF  db 01 15 02 23 02 3A 02 4E 02 62 02 6A 02 72 02 83 ; |...#.:.N.b.j.r..|
  0000:00CF  db 02 92 02 A9 02 BA 02 D9 02 E7 02 EF 02 FA 02 0D ; |................|
  0000:00DF  db 03 1B 03 23 03 2B 03 C8 02 33 03 00 00 00 00    ; |...#.+...3.....|

; --- protocol_mainHandler ---
; Main protocol handler - dispatch send/receive commands
protocol_mainHandler:  ; (sub_0000_00EE)
  0000:00EE  2e8c1eea00        mov      word ptr cs:[0xea], ds
  0000:00F3  8926140a          mov      word ptr [0xa14], sp
  0000:00F7  8c16160a          mov      word ptr [0xa16], ss
  0000:00FB  06                push     es
  0000:00FC  53                push     bx
  0000:00FD  57                push     di
  0000:00FE  56                push     si
  0000:00FF  bb9c00            mov      bx, 0x9c
  0000:0102  a16f07            mov      ax, word ptr [0x76f]
  0000:0105  894720            mov      word ptr [bx + 0x20], ax
  0000:0108  1e                push     ds
  0000:0109  07                pop      es
  0000:010A  b8ff01            mov      ax, 0x1ff
  0000:010D  b90000            mov      cx, 0  ; RELOC->seg_0000
  0000:0110  cde0              int      0xe0  ; INT E0h, AH=01h
  0000:0112  5e                pop      si
  0000:0113  5f                pop      di
  0000:0114  5b                pop      bx
  0000:0115  07                pop      es
  0000:0116  e8fb14            call     0x1614  ; -> sub_0000_1614  ; protocol_intE0hDispatch
  0000:0119  9a39010000        lcall    0, 0x139  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:011E  a14800            mov      ax, word ptr [0x48]
  0000:0121  b104              mov      cl, 4
  0000:0123  d3e8              shr      ax, cl
  0000:0125  40                inc      ax
  0000:0126  8cdb              mov      bx, ds
  0000:0128  03c3              add      ax, bx
  0000:012A  2b066f07          sub      ax, word ptr [0x76f]
  0000:012E  8bd0              mov      dx, ax
  0000:0130  83c201            add      dx, 1
  0000:0133  33c0              xor      ax, ax
  0000:0135  b431              mov      ah, 0x31
  0000:0137  cd21              int      0x21  ; INT 21h/31h: TSR (keep process)
  0000:0139  cb                retf
  0000:013A  db 2E C7 06 B8 01 01 00 55 06 1E 2E 8E 1E EA 00 07 ; |.......U........|
  0000:014A  db 2E 8E 1E EA 00 9A 60 01 00 00 06 1F 07 5D 2E C7 ; |......`......]..| [RELOC->seg_0000]
  0000:015A  db 06 B8 01 00 00 CB 89 26 18 0A 8C 16 1A 0A 8C C1 ; |.......&........|
  0000:016A  db 89 0E 1C 0A FA 8B 26 14 0A 8E 16 16 0A FB       ; |......&.......|
  0000:0178  db 56 57 51 55                                     ; "VWQU"
  0000:017C  db 06 A3 9A 00 8B F5 B9 10 00 2B E1 8B FC 8E 1E 1A ; |.........+......|
  0000:018C  db 0A 16 07 F3 A4 26 A1 9A 00 2D 80 00 16 1F 8B F0 ; |.....&...-......|
  0000:019C  db 03 F6 2E FF 94 BC 00 83 C4 10 07                ; |...........|
  0000:01A7  db 5B 50 58 59 5F 5E                               ; "[PXY_^"
  0000:01AD  db FA 8B 26 18 0A 8E 16 1A 0A FB CB 00 00 1E 2E 8E ; |..&.............|
  0000:01BD  db 1E EA 00 58 A3 1C 0A 89 26 18 0A 8C 16 1A 0A FA ; |...X....&.......|
  0000:01CD  db 8B 26 14 0A 8E 16 16 0A FB E8 54 14 FA 8B 26 18 ; |.&........T...&.|
  0000:01DD  db 0A 8E 16 1A 0A FB A1 1C 0A 50 1F CB             ; |.........P..|
  0000:01E9  55                push     bp
  0000:01EA  8bec              mov      bp, sp
  0000:01EC  ff7608            push     word ptr [bp + 8]
  0000:01EF  ff7606            push     word ptr [bp + 6]
  0000:01F2  ff7604            push     word ptr [bp + 4]
  0000:01F5  e81a13            call     0x1512  ; -> sub_0000_1512  ; protocol_initXmodemState
  0000:01F8  83c406            add      sp, 6
  0000:01FB  5d                pop      bp
  0000:01FC  c3                ret
  0000:01FD  55                push     bp
  0000:01FE  8bec              mov      bp, sp
  0000:0200  ff7606            push     word ptr [bp + 6]
  0000:0203  ff7604            push     word ptr [bp + 4]
  0000:0206  e82d13            call     0x1536  ; -> sub_0000_1536  ; protocol_initYmodemState
  0000:0209  83c404            add      sp, 4
  0000:020C  2ec706ec000100    mov      word ptr cs:[0xec], 1
  0000:0213  5d                pop      bp
  0000:0214  c3                ret
  0000:0215  55                push     bp
  0000:0216  8bec              mov      bp, sp
  0000:0218  ff7604            push     word ptr [bp + 4]
  0000:021B  e8c40b            call     0xde2  ; -> sub_0000_0DE2  ; protocol_initXmodem
  0000:021E  83c402            add      sp, 2
  0000:0221  5d                pop      bp
  0000:0222  c3                ret
  0000:0223  55                push     bp
  0000:0224  8bec              mov      bp, sp
  0000:0226  ff760a            push     word ptr [bp + 0xa]
  0000:0229  ff7608            push     word ptr [bp + 8]
  0000:022C  ff7606            push     word ptr [bp + 6]
  0000:022F  ff7604            push     word ptr [bp + 4]
  0000:0232  e8a504            call     0x6da  ; -> sub_0000_06DA  ; protocol_transferLoop
  0000:0235  83c408            add      sp, 8
  0000:0238  5d                pop      bp
  0000:0239  c3                ret
  0000:023A  55                push     bp
  0000:023B  8bec              mov      bp, sp
  0000:023D  ff7608            push     word ptr [bp + 8]
  0000:0240  ff7606            push     word ptr [bp + 6]
  0000:0243  ff7604            push     word ptr [bp + 4]
  0000:0246  e81212            call     0x145b  ; -> sub_0000_145B  ; protocol_serialIO
  0000:0249  83c406            add      sp, 6
  0000:024C  5d                pop      bp
  0000:024D  c3                ret
  0000:024E  55                push     bp
  0000:024F  8bec              mov      bp, sp
  0000:0251  ff7608            push     word ptr [bp + 8]
  0000:0254  ff7606            push     word ptr [bp + 6]
  0000:0257  ff7604            push     word ptr [bp + 4]
  0000:025A  e8db0e            call     0x1138  ; -> sub_0000_1138  ; protocol_setBlockSize128
  0000:025D  83c406            add      sp, 6
  0000:0260  5d                pop      bp
  0000:0261  c3                ret
  0000:0262  55                push     bp
  0000:0263  8bec              mov      bp, sp
  0000:0265  e8ea0e            call     0x1152  ; -> sub_0000_1152  ; protocol_setBlockSize1024
  0000:0268  5d                pop      bp
  0000:0269  c3                ret
  0000:026A  55                push     bp
  0000:026B  8bec              mov      bp, sp
  0000:026D  e8050f            call     0x1175  ; -> sub_0000_1175  ; protocol_enableCRC
  0000:0270  5d                pop      bp
  0000:0271  c3                ret
  0000:0272  55                push     bp
  0000:0273  8bec              mov      bp, sp
  0000:0275  ff7606            push     word ptr [bp + 6]
  0000:0278  ff7604            push     word ptr [bp + 4]
  0000:027B  e8a70f            call     0x1225  ; -> sub_0000_1225  ; protocol_closeTransferFile
  0000:027E  83c404            add      sp, 4
  0000:0281  5d                pop      bp
  0000:0282  c3                ret
  0000:0283  55                push     bp
  0000:0284  8bec              mov      bp, sp
  0000:0286  e86a0f            call     0x11f3  ; -> sub_0000_11F3  ; protocol_openInputFile
  0000:0289  2ec706ec000000    mov      word ptr cs:[0xec], 0
  0000:0290  5d                pop      bp
  0000:0291  c3                ret
  0000:0292  55                push     bp
  0000:0293  8bec              mov      bp, sp
  0000:0295  ff760a            push     word ptr [bp + 0xa]
  0000:0298  ff7608            push     word ptr [bp + 8]
  0000:029B  ff7606            push     word ptr [bp + 6]
  0000:029E  ff7604            push     word ptr [bp + 4]
  0000:02A1  e8b603            call     0x65a  ; -> sub_0000_065A  ; protocol_sendByte
  0000:02A4  83c408            add      sp, 8
  0000:02A7  5d                pop      bp
  0000:02A8  c3                ret
  0000:02A9  55                push     bp
  0000:02AA  8bec              mov      bp, sp
  0000:02AC  ff7606            push     word ptr [bp + 6]
  0000:02AF  ff7604            push     word ptr [bp + 4]
  0000:02B2  e89308            call     0xb48  ; -> sub_0000_0B48  ; protocol_processBlock
  0000:02B5  83c404            add      sp, 4
  0000:02B8  5d                pop      bp
  0000:02B9  c3                ret
  0000:02BA  55                push     bp
  0000:02BB  8bec              mov      bp, sp
  0000:02BD  ff7604            push     word ptr [bp + 4]
  0000:02C0  e85411            call     0x1417  ; -> sub_0000_1417  ; protocol_getProtocolName
  0000:02C3  83c402            add      sp, 2
  0000:02C6  5d                pop      bp
  0000:02C7  c3                ret
  0000:02C8  55                push     bp
  0000:02C9  8bec              mov      bp, sp
  0000:02CB  ff7606            push     word ptr [bp + 6]
  0000:02CE  ff7604            push     word ptr [bp + 4]
  0000:02D1  e85111            call     0x1425  ; -> sub_0000_1425  ; protocol_getTransferDir
  0000:02D4  83c404            add      sp, 4
  0000:02D7  5d                pop      bp
  0000:02D8  c3                ret
  0000:02D9  55                push     bp
  0000:02DA  8bec              mov      bp, sp
  0000:02DC  ff7604            push     word ptr [bp + 4]
  0000:02DF  e8c003            call     0x6a2  ; -> sub_0000_06A2  ; protocol_setCallback
  0000:02E2  83c402            add      sp, 2
  0000:02E5  5d                pop      bp
  0000:02E6  c3                ret
  0000:02E7  55                push     bp
  0000:02E8  8bec              mov      bp, sp
  0000:02EA  e8c303            call     0x6b0  ; -> sub_0000_06B0  ; protocol_setOptions
  0000:02ED  5d                pop      bp
  0000:02EE  c3                ret
  0000:02EF  db 2E C7 06 B8 01 01 00 E8 12 01 C3 2E 83 3E EC 00 ; |.............>..|
  0000:02FF  db 00 74 0A 2E C7 06 B8 01 00 00 E8 DB 00 C3       ; |.t............|
  0000:030D  55                push     bp
  0000:030E  8bec              mov      bp, sp
  0000:0310  ff7604            push     word ptr [bp + 4]
  0000:0313  e8f012            call     0x1606  ; -> sub_0000_1606  ; protocol_resetTransfer
  0000:0316  83c402            add      sp, 2
  0000:0319  5d                pop      bp
  0000:031A  c3                ret
  0000:031B  55                push     bp
  0000:031C  8bec              mov      bp, sp
  0000:031E  e81b11            call     0x143c  ; -> sub_0000_143C  ; protocol_setStatusMsg
  0000:0321  5d                pop      bp
  0000:0322  c3                ret
  0000:0323  55                push     bp
  0000:0324  8bec              mov      bp, sp
  0000:0326  e82611            call     0x144f  ; -> sub_0000_144F  ; protocol_setErrorState
  0000:0329  5d                pop      bp
  0000:032A  c3                ret
  0000:032B  55                push     bp
  0000:032C  8bec              mov      bp, sp
  0000:032E  e81811            call     0x1449  ; -> sub_0000_1449  ; protocol_getErrorMsg
  0000:0331  5d                pop      bp
  0000:0332  c3                ret
  0000:0333  55                push     bp
  0000:0334  8bec              mov      bp, sp
  0000:0336  e81e11            call     0x1457  ; -> sub_0000_1457  ; protocol_clearError
  0000:0339  5d                pop      bp
  0000:033A  c3                ret
  0000:033B  db 00 CB 50 8C D8 2E A3 B5 04 58 CB CB 9C          ; |..P......X...|
  0000:0348  db 50 53 51 52 57 56                               ; "PSQRWV"
  0000:034E  db 1E 06 2E A1 B5 04 50 07 26 89 26 18 0A 26 8C 16 ; |......P.&.&..&..|
  0000:035E  db 1A 0A FA 26 8B 26 14 0A 26 8E 16 16 0A FB       ; |...&.&..&.....|
  0000:036C  55                push     bp
  0000:036D  8bec              mov      bp, sp
  0000:036F  1e                push     ds
  0000:0370  57                push     di
  0000:0371  06                push     es
  0000:0372  1f                pop      ds
  0000:0373  e8fa01            call     0x570  ; -> sub_0000_0570  ; protocol_sendFile
  0000:0376  83c404            add      sp, 4
  0000:0379  5d                pop      bp
  0000:037A  2ea1b504          mov      ax, word ptr cs:[0x4b5]
  0000:037E  50                push     ax
  0000:037F  07                pop      es
  0000:0380  fa                cli
  0000:0381  268b26180a        mov      sp, word ptr es:[0xa18]
  0000:0386  268e161a0a        mov      ss, word ptr es:[0xa1a]
  0000:038B  fb                sti
  0000:038C  07                pop      es
  0000:038D  1f                pop      ds
  0000:038E  5e                pop      si
  0000:038F  5f                pop      di
  0000:0390  5a                pop      dx
  0000:0391  59                pop      cx
  0000:0392  5b                pop      bx
  0000:0393  58                pop      ax
  0000:0394  9d                popf
  0000:0395  cb                retf
  0000:0396  db 9C                                              ; |.|
  0000:0397  db 50 53 51 52 57 56                               ; "PSQRWV"
  0000:039D  db 1E 06 2E A1 B5 04 50 07 26 89 26 18 0A 26 8C 16 ; |......P.&.&..&..|
  0000:03AD  db 1A 0A FA 26 8B 26 14 0A 26 8E 16 16 0A FB       ; |...&.&..&.....|
  0000:03BB  55                push     bp
  0000:03BC  8bec              mov      bp, sp
  0000:03BE  1e                push     ds
  0000:03BF  57                push     di
  0000:03C0  06                push     es
  0000:03C1  1f                pop      ds
  0000:03C2  9ab8040000        lcall    0, 0x4b8  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:03C7  83c404            add      sp, 4
  0000:03CA  5d                pop      bp
  0000:03CB  2ea1b504          mov      ax, word ptr cs:[0x4b5]
  0000:03CF  50                push     ax
  0000:03D0  07                pop      es
  0000:03D1  fa                cli
  0000:03D2  268b26180a        mov      sp, word ptr es:[0xa18]
  0000:03D7  268e161a0a        mov      ss, word ptr es:[0xa1a]
  0000:03DC  fb                sti
  0000:03DD  07                pop      es
  0000:03DE  1f                pop      ds
  0000:03DF  5e                pop      si
  0000:03E0  5f                pop      di
  0000:03E1  5a                pop      dx
  0000:03E2  59                pop      cx
  0000:03E3  5b                pop      bx
  0000:03E4  58                pop      ax
  0000:03E5  9d                popf
  0000:03E6  cb                retf

; --- protocol_initState ---
; Initialize protocol state machine
protocol_initState:  ; (sub_0000_03E7)
  0000:03E7  55                push     bp
  0000:03E8  8bec              mov      bp, sp
  0000:03EA  1e                push     ds
  0000:03EB  57                push     di
  0000:03EC  56                push     si
  0000:03ED  b81c35            mov      ax, 0x351c
  0000:03F0  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:03F2  2e891ead04        mov      word ptr cs:[0x4ad], bx
  0000:03F7  2e8c06af04        mov      word ptr cs:[0x4af], es
  0000:03FC  0e                push     cs
  0000:03FD  1f                pop      ds
  0000:03FE  ba3e04            mov      dx, 0x43e
  0000:0401  b81c25            mov      ax, 0x251c
  0000:0404  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:0406  5e                pop      si
  0000:0407  5f                pop      di
  0000:0408  1f                pop      ds
  0000:0409  5d                pop      bp
  0000:040A  c3                ret

; --- protocol_cleanupState ---
; Clean up protocol state on completion/abort
protocol_cleanupState:  ; (sub_0000_040B)
  0000:040B  55                push     bp
  0000:040C  8bec              mov      bp, sp
  0000:040E  1e                push     ds
  0000:040F  57                push     di
  0000:0410  56                push     si
  0000:0411  2ea1ad04          mov      ax, word ptr cs:[0x4ad]
  0000:0415  2e0b06ad04        or       ax, word ptr cs:[0x4ad]
  0000:041A  741d              je       0x439  ; -> loc_0000_0439
  0000:041C  2e8b16ad04        mov      dx, word ptr cs:[0x4ad]
  0000:0421  2e8e1eaf04        mov      ds, word ptr cs:[0x4af]
  0000:0426  b81c25            mov      ax, 0x251c
  0000:0429  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:042B  2ec706ad040000    mov      word ptr cs:[0x4ad], 0
  0000:0432  2ec706af040000    mov      word ptr cs:[0x4af], 0

loc_0000_0439:
  0000:0439  5e                pop      si
  0000:043A  5f                pop      di
  0000:043B  1f                pop      ds
  0000:043C  5d                pop      bp
  0000:043D  c3                ret
  0000:043E  db FC 50 2E A1 B8 01 0B C0 75 48 2E A1 AB 04 0B C0 ; |.P......uH......|
  0000:044E  db 75 40 2E C7 06 AB 04 01 00                      ; |u@.......|
  0000:0457  db 53 51 52 57 56                                  ; "SQRWV"
  0000:045C  db 1E 06 2E 8C 16 A7 04 2E 89 26 A9 04 2E A1 B5 04 ; |.........&......|
  0000:046C  db 8E D8 8E C0 8E D0 BC C0 04 E8 3B 0F 2E 8E 16 A7 ; |..........;.....|
  0000:047C  db 04 2E 8B 26 A9 04 07 1F                         ; |...&....|
  0000:0484  db 5E 5F 5A 59 5B 2E                               ; "^_ZY[."
  0000:048A  db C7 06 AB 04 00 00 58 FB 2E FF 2E AD 04          ; |......X......|

; --- protocol_getTimerTick ---
; Get timer tick count via INT 1Ah for timeouts
protocol_getTimerTick:  ; (sub_0000_0497)
  0000:0497  2ec706b8010100    mov      word ptr cs:[0x1b8], 1
  0000:049E  c3                ret

; --- protocol_waitWithTimeout ---
; Wait for event with timeout (recursive retry)
protocol_waitWithTimeout:  ; (sub_0000_049F)
  0000:049F  2ec706b8010000    mov      word ptr cs:[0x1b8], 0
  0000:04A6  c3                ret
  0000:04A7  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0000:04B7  db 00                                              ; |.|
  0000:04B8  55                push     bp
  0000:04B9  8bec              mov      bp, sp
  0000:04BB  e8d9ff            call     0x497  ; -> sub_0000_0497  ; protocol_getTimerTick

loc_0000_04BE:
  0000:04BE  e85a0e            call     0x131b  ; -> sub_0000_131B  ; protocol_calculateChecksum
  0000:04C1  0bc0              or       ax, ax
  0000:04C3  751e              jne      0x4e3  ; -> loc_0000_04E3
  0000:04C5  8b1e2815          mov      bx, word ptr [0x1528]
  0000:04C9  c647045a          mov      byte ptr [bx + 4], 0x5a
  0000:04CD  8b1e2815          mov      bx, word ptr [0x1528]
  0000:04D1  c6470562          mov      byte ptr [bx + 5], 0x62
  0000:04D5  8b1e2815          mov      bx, word ptr [0x1528]
  0000:04D9  c747020200        mov      word ptr [bx + 2], 2
  0000:04DE  e85300            call     0x534  ; -> sub_0000_0534  ; protocol_checkTimeout
  0000:04E1  eb4c              jmp      0x52f  ; -> loc_0000_052F

loc_0000_04E3:
  0000:04E3  a12815            mov      ax, word ptr [0x1528]
  0000:04E6  050400            add      ax, 4
  0000:04E9  50                push     ax
  0000:04EA  e8a60d            call     0x1293  ; -> sub_0000_1293  ; protocol_updateProgress
  0000:04ED  83c402            add      sp, 2
  0000:04F0  3d0100            cmp      ax, 1
  0000:04F3  7522              jne      0x517  ; -> loc_0000_0517
  0000:04F5  a12815            mov      ax, word ptr [0x1528]
  0000:04F8  40                inc      ax
  0000:04F9  40                inc      ax
  0000:04FA  50                push     ax
  0000:04FB  a12815            mov      ax, word ptr [0x1528]
  0000:04FE  050400            add      ax, 4
  0000:0501  1e                push     ds
  0000:0502  50                push     ax
  0000:0503  b80200            mov      ax, 2
  0000:0506  50                push     ax
  0000:0507  e8d001            call     0x6da  ; -> sub_0000_06DA  ; protocol_transferLoop
  0000:050A  83c408            add      sp, 8
  0000:050D  3d0100            cmp      ax, 1
  0000:0510  75ac              jne      0x4be  ; -> loc_0000_04BE
  0000:0512  e81f00            call     0x534  ; -> sub_0000_0534  ; protocol_checkTimeout
  0000:0515  eba7              jmp      0x4be  ; -> loc_0000_04BE

loc_0000_0517:
  0000:0517  a12815            mov      ax, word ptr [0x1528]
  0000:051A  40                inc      ax
  0000:051B  40                inc      ax
  0000:051C  50                push     ax
  0000:051D  a12815            mov      ax, word ptr [0x1528]
  0000:0520  050400            add      ax, 4
  0000:0523  1e                push     ds
  0000:0524  50                push     ax
  0000:0525  b80300            mov      ax, 3
  0000:0528  50                push     ax
  0000:0529  e8ae01            call     0x6da  ; -> sub_0000_06DA  ; protocol_transferLoop
  0000:052C  83c408            add      sp, 8

loc_0000_052F:
  0000:052F  e86dff            call     0x49f  ; -> sub_0000_049F  ; protocol_waitWithTimeout
  0000:0532  5d                pop      bp
  0000:0533  cb                retf

; --- protocol_checkTimeout ---
; Check if timeout has elapsed (2 callers)
protocol_checkTimeout:  ; (sub_0000_0534)
  0000:0534  b87c00            mov      ax, 0x7c
  0000:0537  f72ec404          imul     word ptr [0x4c4]
  0000:053B  8bd8              mov      bx, ax
  0000:053D  c787400a0100      mov      word ptr [bx + 0xa40], 1
  0000:0543  ff06c404          inc      word ptr [0x4c4]
  0000:0547  a1c404            mov      ax, word ptr [0x4c4]
  0000:054A  250f00            and      ax, 0xf
  0000:054D  a3c404            mov      word ptr [0x4c4], ax
  0000:0550  b87c00            mov      ax, 0x7c
  0000:0553  f72ec404          imul     word ptr [0x4c4]
  0000:0557  05400a            add      ax, 0xa40
  0000:055A  a32815            mov      word ptr [0x1528], ax
  0000:055D  2bc0              sub      ax, ax
  0000:055F  50                push     ax
  0000:0560  50                push     ax
  0000:0561  b8f8f5            mov      ax, 0xf5f8
  0000:0564  50                push     ax
  0000:0565  b80600            mov      ax, 6
  0000:0568  50                push     ax
  0000:0569  e8ee00            call     0x65a  ; -> sub_0000_065A  ; protocol_sendByte
  0000:056C  83c408            add      sp, 8
  0000:056F  c3                ret

; --- protocol_sendFile ---
; XMODEM/YMODEM send file top-level handler
protocol_sendFile:  ; (sub_0000_0570)
  0000:0570  55                push     bp
  0000:0571  8bec              mov      bp, sp
  0000:0573  56                push     si
  0000:0574  833ed40400        cmp      word ptr [0x4d4], 0
  0000:0579  750e              jne      0x589  ; -> loc_0000_0589
  0000:057B  833ece0400        cmp      word ptr [0x4ce], 0
  0000:0580  7511              jne      0x593  ; -> loc_0000_0593
  0000:0582  803ec60400        cmp      byte ptr [0x4c6], 0
  0000:0587  750a              jne      0x593  ; -> loc_0000_0593

loc_0000_0589:
  0000:0589  c45e04            les      bx, ptr [bp + 4]
  0000:058C  26c60700          mov      byte ptr es:[bx], 0
  0000:0590  e9c400            jmp      0x657  ; -> loc_0000_0657

loc_0000_0593:
  0000:0593  803ec60400        cmp      byte ptr [0x4c6], 0
  0000:0598  7440              je       0x5da  ; -> loc_0000_05DA
  0000:059A  c45e04            les      bx, ptr [bp + 4]
  0000:059D  a1cb04            mov      ax, word ptr [0x4cb]
  0000:05A0  26894705          mov      word ptr es:[bx + 5], ax
  0000:05A4  c45e04            les      bx, ptr [bp + 4]
  0000:05A7  a1c904            mov      ax, word ptr [0x4c9]
  0000:05AA  26894703          mov      word ptr es:[bx + 3], ax
  0000:05AE  c45e04            les      bx, ptr [bp + 4]
  0000:05B1  a1c704            mov      ax, word ptr [0x4c7]
  0000:05B4  26894701          mov      word ptr es:[bx + 1], ax
  0000:05B8  c45e04            les      bx, ptr [bp + 4]
  0000:05BB  a0c604            mov      al, byte ptr [0x4c6]
  0000:05BE  268807            mov      byte ptr es:[bx], al
  0000:05C1  c606c60400        mov      byte ptr [0x4c6], 0
  0000:05C6  c706c7040000      mov      word ptr [0x4c7], 0
  0000:05CC  c706c9040000      mov      word ptr [0x4c9], 0
  0000:05D2  c706cb040000      mov      word ptr [0x4cb], 0
  0000:05D8  eb7d              jmp      0x657  ; -> loc_0000_0657

loc_0000_05DA:
  0000:05DA  b80700            mov      ax, 7
  0000:05DD  f72ed004          imul     word ptr [0x4d0]
  0000:05E1  8bd8              mov      bx, ax
  0000:05E3  8b87e315          mov      ax, word ptr [bx + 0x15e3]
  0000:05E7  c45e04            les      bx, ptr [bp + 4]
  0000:05EA  26894705          mov      word ptr es:[bx + 5], ax
  0000:05EE  b80700            mov      ax, 7
  0000:05F1  f72ed004          imul     word ptr [0x4d0]
  0000:05F5  8bd8              mov      bx, ax
  0000:05F7  8b87e115          mov      ax, word ptr [bx + 0x15e1]
  0000:05FB  c45e04            les      bx, ptr [bp + 4]
  0000:05FE  26894703          mov      word ptr es:[bx + 3], ax
  0000:0602  b80700            mov      ax, 7
  0000:0605  f72ed004          imul     word ptr [0x4d0]
  0000:0609  8bd8              mov      bx, ax
  0000:060B  8b87df15          mov      ax, word ptr [bx + 0x15df]
  0000:060F  c45e04            les      bx, ptr [bp + 4]
  0000:0612  26894701          mov      word ptr es:[bx + 1], ax
  0000:0616  b80700            mov      ax, 7
  0000:0619  f72ed004          imul     word ptr [0x4d0]
  0000:061D  8bd8              mov      bx, ax
  0000:061F  8a87de15          mov      al, byte ptr [bx + 0x15de]
  0000:0623  c45e04            les      bx, ptr [bp + 4]
  0000:0626  268807            mov      byte ptr es:[bx], al
  0000:0629  b80700            mov      ax, 7
  0000:062C  f72ed004          imul     word ptr [0x4d0]
  0000:0630  8bf0              mov      si, ax
  0000:0632  c684de1500        mov      byte ptr [si + 0x15de], 0
  0000:0637  c784df150000      mov      word ptr [si + 0x15df], 0
  0000:063D  c784e1150000      mov      word ptr [si + 0x15e1], 0
  0000:0643  c784e3150000      mov      word ptr [si + 0x15e3], 0
  0000:0649  a1d004            mov      ax, word ptr [0x4d0]
  0000:064C  40                inc      ax
  0000:064D  250f00            and      ax, 0xf
  0000:0650  a3d004            mov      word ptr [0x4d0], ax
  0000:0653  ff0ece04          dec      word ptr [0x4ce]

loc_0000_0657:
  0000:0657  5e                pop      si
  0000:0658  5d                pop      bp
  0000:0659  c3                ret

; --- protocol_sendByte ---
; Send single byte to serial port (3 callers)
protocol_sendByte:  ; (sub_0000_065A)
  0000:065A  55                push     bp
  0000:065B  8bec              mov      bp, sp
  0000:065D  56                push     si
  0000:065E  833ece0410        cmp      word ptr [0x4ce], 0x10
  0000:0663  7504              jne      0x669  ; -> loc_0000_0669
  0000:0665  2bc0              sub      ax, ax
  0000:0667  eb36              jmp      0x69f  ; -> loc_0000_069F

loc_0000_0669:
  0000:0669  b80700            mov      ax, 7
  0000:066C  f72ed204          imul     word ptr [0x4d2]
  0000:0670  8bf0              mov      si, ax
  0000:0672  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:0675  8984e315          mov      word ptr [si + 0x15e3], ax
  0000:0679  8b4608            mov      ax, word ptr [bp + 8]
  0000:067C  8984e115          mov      word ptr [si + 0x15e1], ax
  0000:0680  8b4606            mov      ax, word ptr [bp + 6]
  0000:0683  8984df15          mov      word ptr [si + 0x15df], ax
  0000:0687  8a4604            mov      al, byte ptr [bp + 4]
  0000:068A  8884de15          mov      byte ptr [si + 0x15de], al
  0000:068E  ff06ce04          inc      word ptr [0x4ce]
  0000:0692  a1d204            mov      ax, word ptr [0x4d2]
  0000:0695  40                inc      ax
  0000:0696  250f00            and      ax, 0xf
  0000:0699  a3d204            mov      word ptr [0x4d2], ax
  0000:069C  b80100            mov      ax, 1

loc_0000_069F:
  0000:069F  5e                pop      si
  0000:06A0  5d                pop      bp
  0000:06A1  c3                ret

; --- protocol_setCallback ---
; Set serial I/O callback function pointer
protocol_setCallback:  ; (sub_0000_06A2)
  0000:06A2  55                push     bp
  0000:06A3  8bec              mov      bp, sp
  0000:06A5  8b4604            mov      ax, word ptr [bp + 4]
  0000:06A8  a3dc04            mov      word ptr [0x4dc], ax
  0000:06AB  a3de04            mov      word ptr [0x4de], ax
  0000:06AE  5d                pop      bp
  0000:06AF  c3                ret

; --- protocol_setOptions ---
; Set protocol options (block size, CRC mode)
protocol_setOptions:  ; (sub_0000_06B0)
  0000:06B0  c706dc040000      mov      word ptr [0x4dc], 0
  0000:06B6  c706de040000      mov      word ptr [0x4de], 0
  0000:06BC  c3                ret
  0000:06BD  55                push     bp
  0000:06BE  8bec              mov      bp, sp
  0000:06C0  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:06C3  a3cb04            mov      word ptr [0x4cb], ax
  0000:06C6  8b4608            mov      ax, word ptr [bp + 8]
  0000:06C9  a3c904            mov      word ptr [0x4c9], ax
  0000:06CC  8b4606            mov      ax, word ptr [bp + 6]
  0000:06CF  a3c704            mov      word ptr [0x4c7], ax
  0000:06D2  8a4604            mov      al, byte ptr [bp + 4]
  0000:06D5  a2c604            mov      byte ptr [0x4c6], al
  0000:06D8  5d                pop      bp
  0000:06D9  c3                ret

; --- protocol_transferLoop ---
; Main transfer loop - send/receive blocks (7 callers)
protocol_transferLoop:  ; (sub_0000_06DA)
  0000:06DA  55                push     bp
  0000:06DB  8bec              mov      bp, sp
  0000:06DD  83ec04            sub      sp, 4
  0000:06E0  56                push     si
  0000:06E1  8b4604            mov      ax, word ptr [bp + 4]
  0000:06E4  0bc0              or       ax, ax
  0000:06E6  7417              je       0x6ff  ; -> loc_0000_06FF
  0000:06E8  3d0100            cmp      ax, 1
  0000:06EB  747b              je       0x768  ; -> loc_0000_0768
  0000:06ED  3d0200            cmp      ax, 2
  0000:06F0  7503              jne      0x6f5  ; -> loc_0000_06F5
  0000:06F2  e98a00            jmp      0x77f  ; -> loc_0000_077F

loc_0000_06F5:
  0000:06F5  3d0300            cmp      ax, 3
  0000:06F8  7503              jne      0x6fd  ; -> loc_0000_06FD
  0000:06FA  e99000            jmp      0x78d  ; -> loc_0000_078D

loc_0000_06FD:
  0000:06FD  eb64              jmp      0x763  ; -> loc_0000_0763

loc_0000_06FF:
  0000:06FF  c706c4040000      mov      word ptr [0x4c4], 0
  0000:0705  c706c2040000      mov      word ptr [0x4c2], 0
  0000:070B  c606e60401        mov      byte ptr [0x4e6], 1
  0000:0710  e82501            call     0x838  ; -> sub_0000_0838  ; protocol_validatePacket
  0000:0713  8b4606            mov      ax, word ptr [bp + 6]
  0000:0716  0b4608            or       ax, word ptr [bp + 8]
  0000:0719  742e              je       0x749  ; -> loc_0000_0749
  0000:071B  c746fe0000        mov      word ptr [bp - 2], 0
  0000:0720  eb10              jmp      0x732  ; -> loc_0000_0732

loc_0000_0722:
  0000:0722  8b5efe            mov      bx, word ptr [bp - 2]
  0000:0725  c47606            les      si, ptr [bp + 6]
  0000:0728  268a00            mov      al, byte ptr es:[bx + si]
  0000:072B  8887a414          mov      byte ptr [bx + 0x14a4], al
  0000:072F  ff46fe            inc      word ptr [bp - 2]

loc_0000_0732:
  0000:0732  8b5e0a            mov      bx, word ptr [bp + 0xa]
  0000:0735  8b46fe            mov      ax, word ptr [bp - 2]
  0000:0738  3907              cmp      word ptr [bx], ax
  0000:073A  7fe6              jg       0x722  ; -> loc_0000_0722
  0000:073C  c7062215a414      mov      word ptr [0x1522], 0x14a4
  0000:0742  8b07              mov      ax, word ptr [bx]
  0000:0744  a3a01e            mov      word ptr [0x1ea0], ax
  0000:0747  eb0c              jmp      0x755  ; -> loc_0000_0755

loc_0000_0749:
  0000:0749  c70622150000      mov      word ptr [0x1522], 0
  0000:074F  c706a01e0000      mov      word ptr [0x1ea0], 0

loc_0000_0755:
  0000:0755  b8a01e            mov      ax, 0x1ea0
  0000:0758  50                push     ax
  0000:0759  ff362215          push     word ptr [0x1522]
  0000:075D  e8e803            call     0xb48  ; -> sub_0000_0B48  ; protocol_processBlock
  0000:0760  83c404            add      sp, 4

loc_0000_0763:
  0000:0763  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0766  eb3c              jmp      0x7a4  ; -> loc_0000_07A4

loc_0000_0768:
  0000:0768  ff760a            push     word ptr [bp + 0xa]
  0000:076B  ff7608            push     word ptr [bp + 8]
  0000:076E  ff7606            push     word ptr [bp + 6]
  0000:0771  e8e505            call     0xd59  ; -> sub_0000_0D59  ; protocol_calculateCRC

loc_0000_0774:
  0000:0774  83c406            add      sp, 6
  0000:0777  8946fc            mov      word ptr [bp - 4], ax
  0000:077A  e8aa02            call     0xa27  ; -> sub_0000_0A27  ; protocol_receiveBlock
  0000:077D  ebe4              jmp      0x763  ; -> loc_0000_0763

loc_0000_077F:
  0000:077F  ff760a            push     word ptr [bp + 0xa]
  0000:0782  ff7608            push     word ptr [bp + 8]
  0000:0785  ff7606            push     word ptr [bp + 6]
  0000:0788  e81e07            call     0xea9  ; -> sub_0000_0EA9  ; protocol_ymodemReceive
  0000:078B  ebe7              jmp      0x774  ; -> loc_0000_0774

loc_0000_078D:
  0000:078D  e89702            call     0xa27  ; -> sub_0000_0A27  ; protocol_receiveBlock
  0000:0790  ff760a            push     word ptr [bp + 0xa]
  0000:0793  ff7608            push     word ptr [bp + 8]
  0000:0796  ff7606            push     word ptr [bp + 6]
  0000:0799  e82e09            call     0x10ca  ; -> sub_0000_10CA  ; protocol_ymodemSend
  0000:079C  83c406            add      sp, 6
  0000:079F  8946fc            mov      word ptr [bp - 4], ax
  0000:07A2  ebbf              jmp      0x763  ; -> loc_0000_0763

loc_0000_07A4:
  0000:07A4  5e                pop      si
  0000:07A5  8be5              mov      sp, bp
  0000:07A7  5d                pop      bp
  0000:07A8  c3                ret

; --- protocol_buildPacket ---
; Build XMODEM/YMODEM packet (header + data + checksum)
protocol_buildPacket:  ; (sub_0000_07A9)
  0000:07A9  55                push     bp
  0000:07AA  8bec              mov      bp, sp
  0000:07AC  83ec08            sub      sp, 8
  0000:07AF  57                push     di
  0000:07B0  56                push     si
  0000:07B1  2bff              sub      di, di
  0000:07B3  2bf6              sub      si, si
  0000:07B5  eb1f              jmp      0x7d6  ; -> loc_0000_07D6

loc_0000_07B7:
  0000:07B7  8b5e06            mov      bx, word ptr [bp + 6]
  0000:07BA  8a00              mov      al, byte ptr [bx + si]
  0000:07BC  98                cwde
  0000:07BD  8bd8              mov      bx, ax
  0000:07BF  8bc7              mov      ax, di
  0000:07C1  32d8              xor      bl, al
  0000:07C3  2aff              sub      bh, bh
  0000:07C5  d1e3              shl      bx, 1
  0000:07C7  8b87f204          mov      ax, word ptr [bx + 0x4f2]
  0000:07CB  8bd7              mov      dx, di
  0000:07CD  b108              mov      cl, 8
  0000:07CF  d3ea              shr      dx, cl
  0000:07D1  33c2              xor      ax, dx
  0000:07D3  8bf8              mov      di, ax
  0000:07D5  46                inc      si

loc_0000_07D6:
  0000:07D6  397604            cmp      word ptr [bp + 4], si
  0000:07D9  77dc              ja       0x7b7  ; -> loc_0000_07B7
  0000:07DB  897efa            mov      word ptr [bp - 6], di
  0000:07DE  c746fc0000        mov      word ptr [bp - 4], 0
  0000:07E3  8bc7              mov      ax, di
  0000:07E5  8b56fc            mov      dx, word ptr [bp - 4]
  0000:07E8  250f00            and      ax, 0xf
  0000:07EB  2bd2              sub      dx, dx
  0000:07ED  b118              mov      cl, 0x18
  0000:07EF  e89014            call     0x1c82  ; -> sub_0000_1C82  ; protocol_packetChecksum
  0000:07F2  8b5efa            mov      bx, word ptr [bp - 6]
  0000:07F5  81e300f0          and      bx, 0xf000
  0000:07F9  b108              mov      cl, 8
  0000:07FB  d3eb              shr      bx, cl
  0000:07FD  0bd8              or       bx, ax
  0000:07FF  8bca              mov      cx, dx
  0000:0801  8b46fa            mov      ax, word ptr [bp - 6]
  0000:0804  25f000            and      ax, 0xf0
  0000:0807  8bd0              mov      dx, ax
  0000:0809  0bca              or       cx, dx
  0000:080B  8b46fa            mov      ax, word ptr [bp - 6]
  0000:080E  25000f            and      ax, 0xf00
  0000:0811  0bd8              or       bx, ax
  0000:0813  81cb0180          or       bx, 0x8001
  0000:0817  81c90180          or       cx, 0x8001
  0000:081B  895efa            mov      word ptr [bp - 6], bx
  0000:081E  894efc            mov      word ptr [bp - 4], cx
  0000:0821  b80400            mov      ax, 4
  0000:0824  50                push     ax
  0000:0825  8d46fa            lea      ax, [bp - 6]
  0000:0828  50                push     ax
  0000:0829  ff7608            push     word ptr [bp + 8]
  0000:082C  e8f913            call     0x1c28  ; -> sub_0000_1C28  ; protocol_packetHeader
  0000:082F  83c406            add      sp, 6
  0000:0832  5e                pop      si
  0000:0833  5f                pop      di
  0000:0834  8be5              mov      sp, bp
  0000:0836  5d                pop      bp
  0000:0837  c3                ret

; --- protocol_validatePacket ---
; Validate received packet (checksum/CRC, 3 callers)
protocol_validatePacket:  ; (sub_0000_0838)
  0000:0838  c70616140000      mov      word ptr [0x1416], 0
  0000:083E  c70614140000      mov      word ptr [0x1414], 0
  0000:0844  c3                ret

; --- protocol_receiveFile ---
; XMODEM/YMODEM receive file handler
protocol_receiveFile:  ; (sub_0000_0845)
  0000:0845  55                push     bp
  0000:0846  8bec              mov      bp, sp
  0000:0848  83ec08            sub      sp, 8
  0000:084B  57                push     di
  0000:084C  56                push     si
  0000:084D  c746fa1814        mov      word ptr [bp - 6], 0x1418
  0000:0852  813e16148000      cmp      word ptr [0x1416], 0x80
  0000:0858  7c03              jl       0x85d  ; -> loc_0000_085D
  0000:085A  e9bf00            jmp      0x91c  ; -> loc_0000_091C

loc_0000_085D:
  0000:085D  8b1e1614          mov      bx, word ptr [0x1416]
  0000:0861  ff061614          inc      word ptr [0x1416]
  0000:0865  8a4604            mov      al, byte ptr [bp + 4]
  0000:0868  88871814          mov      byte ptr [bx + 0x1418], al
  0000:086C  833e141400        cmp      word ptr [0x1414], 0
  0000:0871  7503              jne      0x876  ; -> loc_0000_0876
  0000:0873  e99000            jmp      0x906  ; -> loc_0000_0906

loc_0000_0876:
  0000:0876  807e040d          cmp      byte ptr [bp + 4], 0xd
  0000:087A  7403              je       0x87f  ; -> loc_0000_087F
  0000:087C  e9a300            jmp      0x922  ; -> loc_0000_0922

loc_0000_087F:
  0000:087F  8b5e06            mov      bx, word ptr [bp + 6]
  0000:0882  a11614            mov      ax, word ptr [0x1416]
  0000:0885  2d0900            sub      ax, 9
  0000:0888  8907              mov      word ptr [bx], ax
  0000:088A  8b76fa            mov      si, word ptr [bp - 6]
  0000:088D  8b1e1614          mov      bx, word ptr [0x1416]
  0000:0891  c640ff00          mov      byte ptr [bx + si - 1], 0
  0000:0895  8d46fc            lea      ax, [bp - 4]
  0000:0898  50                push     ax
  0000:0899  b81d14            mov      ax, 0x141d
  0000:089C  50                push     ax
  0000:089D  a11614            mov      ax, word ptr [0x1416]
  0000:08A0  2d0600            sub      ax, 6
  0000:08A3  50                push     ax
  0000:08A4  e802ff            call     0x7a9  ; -> sub_0000_07A9  ; protocol_buildPacket
  0000:08A7  83c406            add      sp, 6
  0000:08AA  e88bff            call     0x838  ; -> sub_0000_0838  ; protocol_validatePacket
  0000:08AD  a01c14            mov      al, byte ptr [0x141c]
  0000:08B0  3846ff            cmp      byte ptr [bp - 1], al
  0000:08B3  7505              jne      0x8ba  ; -> loc_0000_08BA
  0000:08B5  b80100            mov      ax, 1
  0000:08B8  eb02              jmp      0x8bc  ; -> loc_0000_08BC

loc_0000_08BA:
  0000:08BA  2bc0              sub      ax, ax

loc_0000_08BC:
  0000:08BC  8a0e1b14          mov      cl, byte ptr [0x141b]
  0000:08C0  8bf0              mov      si, ax
  0000:08C2  384efe            cmp      byte ptr [bp - 2], cl
  0000:08C5  7505              jne      0x8cc  ; -> loc_0000_08CC
  0000:08C7  b80100            mov      ax, 1
  0000:08CA  eb02              jmp      0x8ce  ; -> loc_0000_08CE

loc_0000_08CC:
  0000:08CC  2bc0              sub      ax, ax

loc_0000_08CE:
  0000:08CE  8a0e1a14          mov      cl, byte ptr [0x141a]
  0000:08D2  8bf8              mov      di, ax
  0000:08D4  384efd            cmp      byte ptr [bp - 3], cl
  0000:08D7  7505              jne      0x8de  ; -> loc_0000_08DE
  0000:08D9  b80100            mov      ax, 1
  0000:08DC  eb02              jmp      0x8e0  ; -> loc_0000_08E0

loc_0000_08DE:
  0000:08DE  2bc0              sub      ax, ax

loc_0000_08E0:
  0000:08E0  8a0e1914          mov      cl, byte ptr [0x1419]
  0000:08E4  8946f8            mov      word ptr [bp - 8], ax
  0000:08E7  384efc            cmp      byte ptr [bp - 4], cl
  0000:08EA  7505              jne      0x8f1  ; -> loc_0000_08F1
  0000:08EC  b80100            mov      ax, 1
  0000:08EF  eb02              jmp      0x8f3  ; -> loc_0000_08F3

loc_0000_08F1:
  0000:08F1  2bc0              sub      ax, ax

loc_0000_08F3:
  0000:08F3  2346f8            and      ax, word ptr [bp - 8]
  0000:08F6  23c7              and      ax, di
  0000:08F8  85c6              test     si, ax
  0000:08FA  7405              je       0x901  ; -> loc_0000_0901
  0000:08FC  b81814            mov      ax, 0x1418
  0000:08FF  eb23              jmp      0x924  ; -> loc_0000_0924

loc_0000_0901:
  0000:0901  e8a203            call     0xca6  ; -> sub_0000_0CA6  ; protocol_handleRetry
  0000:0904  eb1c              jmp      0x922  ; -> loc_0000_0922

loc_0000_0906:
  0000:0906  807e045a          cmp      byte ptr [bp + 4], 0x5a
  0000:090A  7508              jne      0x914  ; -> loc_0000_0914
  0000:090C  c70614140100      mov      word ptr [0x1414], 1
  0000:0912  eb0e              jmp      0x922  ; -> loc_0000_0922

loc_0000_0914:
  0000:0914  c70616140000      mov      word ptr [0x1416], 0
  0000:091A  eb06              jmp      0x922  ; -> loc_0000_0922

loc_0000_091C:
  0000:091C  e88703            call     0xca6  ; -> sub_0000_0CA6  ; protocol_handleRetry
  0000:091F  e816ff            call     0x838  ; -> sub_0000_0838  ; protocol_validatePacket

loc_0000_0922:
  0000:0922  2bc0              sub      ax, ax

loc_0000_0924:
  0000:0924  5e                pop      si
  0000:0925  5f                pop      di
  0000:0926  8be5              mov      sp, bp
  0000:0928  5d                pop      bp
  0000:0929  c3                ret

; --- protocol_sendACK ---
; Send ACK byte (0x06) to remote (4 callers)
protocol_sendACK:  ; (sub_0000_092A)
  0000:092A  a12e15            mov      ax, word ptr [0x152e]
  0000:092D  a3a014            mov      word ptr [0x14a0], ax
  0000:0930  ff062e15          inc      word ptr [0x152e]
  0000:0934  833e2e157f        cmp      word ptr [0x152e], 0x7f
  0000:0939  7e06              jle      0x941  ; -> loc_0000_0941
  0000:093B  c7062e151000      mov      word ptr [0x152e], 0x10

loc_0000_0941:
  0000:0941  c3                ret

; --- protocol_sendNAK ---
; Send NAK byte (0x15) to request retransmit (2 callers)
protocol_sendNAK:  ; (sub_0000_0942)
  0000:0942  ff063015          inc      word ptr [0x1530]
  0000:0946  833e30157f        cmp      word ptr [0x1530], 0x7f
  0000:094B  7e06              jle      0x953  ; -> loc_0000_0953
  0000:094D  c70630151000      mov      word ptr [0x1530], 0x10

loc_0000_0953:
  0000:0953  c3                ret

; --- protocol_sendCAN ---
; Send CAN byte (0x18) to abort transfer (2 callers)
protocol_sendCAN:  ; (sub_0000_0954)
  0000:0954  55                push     bp
  0000:0955  8bec              mov      bp, sp
  0000:0957  83ec02            sub      sp, 2
  0000:095A  56                push     si
  0000:095B  a1dc15            mov      ax, word ptr [0x15dc]
  0000:095E  8b0e9e1e          mov      cx, word ptr [0x1e9e]
  0000:0962  ff069e1e          inc      word ptr [0x1e9e]
  0000:0966  03c1              add      ax, cx
  0000:0968  99                cdq
  0000:0969  b91400            mov      cx, 0x14
  0000:096C  f7f9              idiv     cx
  0000:096E  8956fe            mov      word ptr [bp - 2], dx
  0000:0971  8bf2              mov      si, dx
  0000:0973  b102              mov      cl, 2
  0000:0975  d3e6              shl      si, cl
  0000:0977  8b4604            mov      ax, word ptr [bp + 4]
  0000:097A  89844e16          mov      word ptr [si + 0x164e], ax
  0000:097E  8b4606            mov      ax, word ptr [bp + 6]
  0000:0981  89845016          mov      word ptr [si + 0x1650], ax
  0000:0985  5e                pop      si
  0000:0986  8be5              mov      sp, bp
  0000:0988  5d                pop      bp
  0000:0989  c3                ret

; --- protocol_receiveByte ---
; Receive single byte from serial port with timeout
protocol_receiveByte:  ; (sub_0000_098A)
  0000:098A  55                push     bp
  0000:098B  8bec              mov      bp, sp
  0000:098D  83ec0c            sub      sp, 0xc
  0000:0990  c746f80000        mov      word ptr [bp - 8], 0
  0000:0995  c746fa0000        mov      word ptr [bp - 6], 0
  0000:099A  c746fc0000        mov      word ptr [bp - 4], 0
  0000:099F  a1a214            mov      ax, word ptr [0x14a2]
  0000:09A2  8946fe            mov      word ptr [bp - 2], ax
  0000:09A5  a11214            mov      ax, word ptr [0x1412]
  0000:09A8  8946f6            mov      word ptr [bp - 0xa], ax
  0000:09AB  eb44              jmp      0x9f1  ; -> loc_0000_09F1

loc_0000_09AD:
  0000:09AD  837ef800          cmp      word ptr [bp - 8], 0
  0000:09B1  7544              jne      0x9f7  ; -> loc_0000_09F7
  0000:09B3  8b5efe            mov      bx, word ptr [bp - 2]
  0000:09B6  d1e3              shl      bx, 1
  0000:09B8  d1e3              shl      bx, 1
  0000:09BA  8b875016          mov      ax, word ptr [bx + 0x1650]
  0000:09BE  8946f4            mov      word ptr [bp - 0xc], ax
  0000:09C1  ff4ef6            dec      word ptr [bp - 0xa]
  0000:09C4  ff46fe            inc      word ptr [bp - 2]
  0000:09C7  8b46fe            mov      ax, word ptr [bp - 2]
  0000:09CA  99                cdq
  0000:09CB  b91400            mov      cx, 0x14
  0000:09CE  f7f9              idiv     cx
  0000:09D0  8956fe            mov      word ptr [bp - 2], dx
  0000:09D3  8b5ef4            mov      bx, word ptr [bp - 0xc]
  0000:09D6  807f07a5          cmp      byte ptr [bx + 7], 0xa5
  0000:09DA  7505              jne      0x9e1  ; -> loc_0000_09E1
  0000:09DC  ff46fa            inc      word ptr [bp - 6]
  0000:09DF  eb03              jmp      0x9e4  ; -> loc_0000_09E4

loc_0000_09E1:
  0000:09E1  ff46fc            inc      word ptr [bp - 4]

loc_0000_09E4:
  0000:09E4  8a4604            mov      al, byte ptr [bp + 4]
  0000:09E7  384705            cmp      byte ptr [bx + 5], al
  0000:09EA  7505              jne      0x9f1  ; -> loc_0000_09F1
  0000:09EC  c746f80100        mov      word ptr [bp - 8], 1

loc_0000_09F1:
  0000:09F1  837ef600          cmp      word ptr [bp - 0xa], 0
  0000:09F5  75b6              jne      0x9ad  ; -> loc_0000_09AD

loc_0000_09F7:
  0000:09F7  837ef800          cmp      word ptr [bp - 8], 0
  0000:09FB  7426              je       0xa23  ; -> loc_0000_0A23
  0000:09FD  8b46fe            mov      ax, word ptr [bp - 2]
  0000:0A00  a3a214            mov      word ptr [0x14a2], ax
  0000:0A03  8b46f6            mov      ax, word ptr [bp - 0xa]
  0000:0A06  a31214            mov      word ptr [0x1412], ax
  0000:0A09  8b46fa            mov      ax, word ptr [bp - 6]
  0000:0A0C  01060815          add      word ptr [0x1508], ax
  0000:0A10  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0A13  0106b215          add      word ptr [0x15b2], ax
  0000:0A17  837efa00          cmp      word ptr [bp - 6], 0
  0000:0A1B  7406              je       0xa23  ; -> loc_0000_0A23
  0000:0A1D  c7062a150000      mov      word ptr [0x152a], 0

loc_0000_0A23:
  0000:0A23  8be5              mov      sp, bp
  0000:0A25  5d                pop      bp
  0000:0A26  c3                ret

; --- protocol_receiveBlock ---
; Receive one data block (128 or 1024 bytes)
protocol_receiveBlock:  ; (sub_0000_0A27)
  0000:0A27  56                push     si
  0000:0A28  833e0a1500        cmp      word ptr [0x150a], 0
  0000:0A2D  7571              jne      0xaa0  ; -> loc_0000_0AA0
  0000:0A2F  803eec0401        cmp      byte ptr [0x4ec], 1
  0000:0A34  752b              jne      0xa61  ; -> loc_0000_0A61
  0000:0A36  b80900            mov      ax, 9
  0000:0A39  50                push     ax
  0000:0A3A  b80212            mov      ax, 0x1202
  0000:0A3D  50                push     ax
  0000:0A3E  b81612            mov      ax, 0x1216
  0000:0A41  50                push     ax
  0000:0A42  e8e311            call     0x1c28  ; -> sub_0000_1C28  ; protocol_packetHeader
  0000:0A45  83c406            add      sp, 6
  0000:0A48  c7060a151612      mov      word ptr [0x150a], 0x1216
  0000:0A4E  c70600120900      mov      word ptr [0x1200], 9
  0000:0A54  c7063e0a0000      mov      word ptr [0xa3e], 0
  0000:0A5A  c606ec0400        mov      byte ptr [0x4ec], 0
  0000:0A5F  eb3c              jmp      0xa9d  ; -> loc_0000_0A9D

loc_0000_0A61:
  0000:0A61  833e9e1e00        cmp      word ptr [0x1e9e], 0
  0000:0A66  7438              je       0xaa0  ; -> loc_0000_0AA0
  0000:0A68  8b36dc15          mov      si, word ptr [0x15dc]
  0000:0A6C  b102              mov      cl, 2
  0000:0A6E  d3e6              shl      si, cl
  0000:0A70  8b845016          mov      ax, word ptr [si + 0x1650]
  0000:0A74  a30a15            mov      word ptr [0x150a], ax
  0000:0A77  8b844e16          mov      ax, word ptr [si + 0x164e]
  0000:0A7B  a30012            mov      word ptr [0x1200], ax
  0000:0A7E  c7063e0a0000      mov      word ptr [0xa3e], 0
  0000:0A84  ff06dc15          inc      word ptr [0x15dc]
  0000:0A88  a1dc15            mov      ax, word ptr [0x15dc]
  0000:0A8B  99                cdq
  0000:0A8C  b91400            mov      cx, 0x14
  0000:0A8F  f7f9              idiv     cx
  0000:0A91  8916dc15          mov      word ptr [0x15dc], dx
  0000:0A95  ff0e9e1e          dec      word ptr [0x1e9e]
  0000:0A99  ff061214          inc      word ptr [0x1412]

loc_0000_0A9D:
  0000:0A9D  e80500            call     0xaa5  ; -> sub_0000_0AA5  ; protocol_writeToFile

loc_0000_0AA0:
  0000:0AA0  e88303            call     0xe26  ; -> sub_0000_0E26  ; protocol_crcUpdate
  0000:0AA3  5e                pop      si
  0000:0AA4  c3                ret

; --- protocol_writeToFile ---
; Write received block to output file (2 callers)
protocol_writeToFile:  ; (sub_0000_0AA5)
  0000:0AA5  c70698149001      mov      word ptr [0x1498], 0x190
  0000:0AAB  a11014            mov      ax, word ptr [0x1410]
  0000:0AAE  a30c15            mov      word ptr [0x150c], ax
  0000:0AB1  b82415            mov      ax, 0x1524
  0000:0AB4  50                push     ax
  0000:0AB5  2bc0              sub      ax, ax
  0000:0AB7  50                push     ax
  0000:0AB8  e89911            call     0x1c54  ; -> sub_0000_1C54  ; protocol_crcTable
  0000:0ABB  83c404            add      sp, 4
  0000:0ABE  81062415b600      add      word ptr [0x1524], 0xb6
  0000:0AC4  8316261500        adc      word ptr [0x1526], 0
  0000:0AC9  833e261517        cmp      word ptr [0x1526], 0x17
  0000:0ACE  7c15              jl       0xae5  ; -> loc_0000_0AE5
  0000:0AD0  7f07              jg       0xad9  ; -> loc_0000_0AD9
  0000:0AD2  833e2415ff        cmp      word ptr [0x1524], -1
  0000:0AD7  760c              jbe      0xae5  ; -> loc_0000_0AE5

loc_0000_0AD9:
  0000:0AD9  c7062415b600      mov      word ptr [0x1524], 0xb6
  0000:0ADF  c70626150000      mov      word ptr [0x1526], 0

loc_0000_0AE5:
  0000:0AE5  c3                ret

; --- protocol_handleYmodemBatch ---
; Handle YMODEM batch header (filename/size block)
protocol_handleYmodemBatch:  ; (sub_0000_0AE6)
  0000:0AE6  55                push     bp
  0000:0AE7  8bec              mov      bp, sp
  0000:0AE9  ff7604            push     word ptr [bp + 4]
  0000:0AEC  ff7606            push     word ptr [bp + 6]
  0000:0AEF  e87a08            call     0x136c  ; -> sub_0000_136C  ; protocol_parseBatchFilename
  0000:0AF2  83c404            add      sp, 4
  0000:0AF5  e8adff            call     0xaa5  ; -> sub_0000_0AA5  ; protocol_writeToFile
  0000:0AF8  5d                pop      bp
  0000:0AF9  c3                ret

; --- protocol_readFromFile ---
; Read next block from input file for sending (4 callers)
protocol_readFromFile:  ; (sub_0000_0AFA)
  0000:0AFA  55                push     bp
  0000:0AFB  8bec              mov      bp, sp
  0000:0AFD  807e0422          cmp      byte ptr [bp + 4], 0x22
  0000:0B01  7407              je       0xb0a  ; -> loc_0000_0B0A
  0000:0B03  833e9e1e00        cmp      word ptr [0x1e9e], 0
  0000:0B08  753c              jne      0xb46  ; -> loc_0000_0B46

loc_0000_0B0A:
  0000:0B0A  803eec0400        cmp      byte ptr [0x4ec], 0
  0000:0B0F  7535              jne      0xb46  ; -> loc_0000_0B46
  0000:0B11  c60602125a        mov      byte ptr [0x1202], 0x5a
  0000:0B16  a03015            mov      al, byte ptr [0x1530]
  0000:0B19  a20712            mov      byte ptr [0x1207], al
  0000:0B1C  a0a014            mov      al, byte ptr [0x14a0]
  0000:0B1F  a20812            mov      byte ptr [0x1208], al
  0000:0B22  8a4604            mov      al, byte ptr [bp + 4]
  0000:0B25  0c80              or       al, 0x80
  0000:0B27  a20912            mov      byte ptr [0x1209], al
  0000:0B2A  c6060a120d        mov      byte ptr [0x120a], 0xd
  0000:0B2F  b80312            mov      ax, 0x1203
  0000:0B32  50                push     ax
  0000:0B33  b80712            mov      ax, 0x1207
  0000:0B36  50                push     ax
  0000:0B37  b80300            mov      ax, 3
  0000:0B3A  50                push     ax
  0000:0B3B  e86bfc            call     0x7a9  ; -> sub_0000_07A9  ; protocol_buildPacket
  0000:0B3E  83c406            add      sp, 6
  0000:0B41  c606ec0401        mov      byte ptr [0x4ec], 1

loc_0000_0B46:
  0000:0B46  5d                pop      bp
  0000:0B47  c3                ret

; --- protocol_processBlock ---
; Process one transfer block (send or receive, 5 callers)
protocol_processBlock:  ; (sub_0000_0B48)
  0000:0B48  55                push     bp
  0000:0B49  8bec              mov      bp, sp
  0000:0B4B  83ec04            sub      sp, 4
  0000:0B4E  56                push     si
  0000:0B4F  c70612140000      mov      word ptr [0x1412], 0
  0000:0B55  c706a2140000      mov      word ptr [0x14a2], 0
  0000:0B5B  c7069e1e0000      mov      word ptr [0x1e9e], 0
  0000:0B61  c706dc150000      mov      word ptr [0x15dc], 0
  0000:0B67  c70608150400      mov      word ptr [0x1508], 4
  0000:0B6D  c70610150000      mov      word ptr [0x1510], 0
  0000:0B73  c706b2151000      mov      word ptr [0x15b2], 0x10
  0000:0B79  c7060e150000      mov      word ptr [0x150e], 0
  0000:0B7F  c706360a0000      mov      word ptr [0xa36], 0
  0000:0B85  c706380a0000      mov      word ptr [0xa38], 0
  0000:0B8B  c7063a0a0000      mov      word ptr [0xa3a], 0
  0000:0B91  c7063c0a0000      mov      word ptr [0xa3c], 0
  0000:0B97  c706340a7800      mov      word ptr [0xa34], 0x78
  0000:0B9D  c70610140a00      mov      word ptr [0x1410], 0xa
  0000:0BA3  c7062a150000      mov      word ptr [0x152a], 0
  0000:0BA9  b87f00            mov      ax, 0x7f
  0000:0BAC  a33015            mov      word ptr [0x1530], ax
  0000:0BAF  a32e15            mov      word ptr [0x152e], ax
  0000:0BB2  a3a014            mov      word ptr [0x14a0], ax
  0000:0BB5  e872fd            call     0x92a  ; -> sub_0000_092A  ; protocol_sendACK
  0000:0BB8  c60602125a        mov      byte ptr [0x1202], 0x5a
  0000:0BBD  a03015            mov      al, byte ptr [0x1530]
  0000:0BC0  a20712            mov      byte ptr [0x1207], al
  0000:0BC3  a0a014            mov      al, byte ptr [0x14a0]
  0000:0BC6  a20812            mov      byte ptr [0x1208], al
  0000:0BC9  837e0400          cmp      word ptr [bp + 4], 0
  0000:0BCD  745d              je       0xc2c  ; -> loc_0000_0C2C
  0000:0BCF  c706d8150500      mov      word ptr [0x15d8], 5
  0000:0BD5  c706320a0000      mov      word ptr [0xa32], 0
  0000:0BDB  c6060912a3        mov      byte ptr [0x1209], 0xa3
  0000:0BE0  c746fc0000        mov      word ptr [bp - 4], 0
  0000:0BE5  eb0f              jmp      0xbf6  ; -> loc_0000_0BF6

loc_0000_0BE7:
  0000:0BE7  8b5efc            mov      bx, word ptr [bp - 4]
  0000:0BEA  8b7604            mov      si, word ptr [bp + 4]
  0000:0BED  8a00              mov      al, byte ptr [bx + si]
  0000:0BEF  88870a12          mov      byte ptr [bx + 0x120a], al
  0000:0BF3  ff46fc            inc      word ptr [bp - 4]

loc_0000_0BF6:
  0000:0BF6  8b5e06            mov      bx, word ptr [bp + 6]
  0000:0BF9  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0BFC  3907              cmp      word ptr [bx], ax
  0000:0BFE  7fe7              jg       0xbe7  ; -> loc_0000_0BE7
  0000:0C00  8b1f              mov      bx, word ptr [bx]
  0000:0C02  c6870a120d        mov      byte ptr [bx + 0x120a], 0xd
  0000:0C07  b80312            mov      ax, 0x1203
  0000:0C0A  50                push     ax
  0000:0C0B  b80712            mov      ax, 0x1207
  0000:0C0E  50                push     ax
  0000:0C0F  8b5e06            mov      bx, word ptr [bp + 6]
  0000:0C12  8b07              mov      ax, word ptr [bx]
  0000:0C14  050300            add      ax, 3
  0000:0C17  50                push     ax
  0000:0C18  e88efb            call     0x7a9  ; -> sub_0000_07A9  ; protocol_buildPacket
  0000:0C1B  83c406            add      sp, 6
  0000:0C1E  b80212            mov      ax, 0x1202
  0000:0C21  50                push     ax
  0000:0C22  8b5e06            mov      bx, word ptr [bp + 6]
  0000:0C25  8b07              mov      ax, word ptr [bx]
  0000:0C27  050900            add      ax, 9
  0000:0C2A  eb6c              jmp      0xc98  ; -> loc_0000_0C98

loc_0000_0C2C:
  0000:0C2C  c706d8150000      mov      word ptr [0x15d8], 0
  0000:0C32  c706320a0100      mov      word ptr [0xa32], 1
  0000:0C38  c6060912a0        mov      byte ptr [0x1209], 0xa0
  0000:0C3D  c6060a124b        mov      byte ptr [0x120a], 0x4b
  0000:0C42  c6060b126b        mov      byte ptr [0x120b], 0x6b
  0000:0C47  c6060c120d        mov      byte ptr [0x120c], 0xd
  0000:0C4C  c606031200        mov      byte ptr [0x1203], 0
  0000:0C51  c606041200        mov      byte ptr [0x1204], 0
  0000:0C56  c606051200        mov      byte ptr [0x1205], 0
  0000:0C5B  c606061200        mov      byte ptr [0x1206], 0
  0000:0C60  e81905            call     0x117c  ; -> sub_0000_117C  ; protocol_openOutputFile
  0000:0C63  40                inc      ax
  0000:0C64  7505              jne      0xc6b  ; -> loc_0000_0C6B
  0000:0C66  b8ffff            mov      ax, 0xffff
  0000:0C69  eb36              jmp      0xca1  ; -> loc_0000_0CA1

loc_0000_0C6B:
  0000:0C6B  a1e204            mov      ax, word ptr [0x4e2]
  0000:0C6E  0b06e404          or       ax, word ptr [0x4e4]
  0000:0C72  750b              jne      0xc7f  ; -> loc_0000_0C7F
  0000:0C74  b8e204            mov      ax, 0x4e2
  0000:0C77  1e                push     ds
  0000:0C78  50                push     ax
  0000:0C79  e8fc09            call     0x1678  ; -> sub_0000_1678  ; protocol_getCallbackB
  0000:0C7C  83c404            add      sp, 4

loc_0000_0C7F:
  0000:0C7F  c706c2040000      mov      word ptr [0x4c2], 0
  0000:0C85  c706c4040000      mov      word ptr [0x4c4], 0
  0000:0C8B  c7062815400a      mov      word ptr [0x1528], 0xa40
  0000:0C91  b80212            mov      ax, 0x1202
  0000:0C94  50                push     ax
  0000:0C95  b80b00            mov      ax, 0xb

loc_0000_0C98:
  0000:0C98  50                push     ax
  0000:0C99  e84afe            call     0xae6  ; -> sub_0000_0AE6  ; protocol_handleYmodemBatch
  0000:0C9C  83c404            add      sp, 4
  0000:0C9F  2bc0              sub      ax, ax

loc_0000_0CA1:
  0000:0CA1  5e                pop      si
  0000:0CA2  8be5              mov      sp, bp
  0000:0CA4  5d                pop      bp
  0000:0CA5  c3                ret

; --- protocol_handleRetry ---
; Handle retry after NAK/timeout (4 callers)
protocol_handleRetry:  ; (sub_0000_0CA6)
  0000:0CA6  833ed81500        cmp      word ptr [0x15d8], 0
  0000:0CAB  7414              je       0xcc1  ; -> loc_0000_0CC1
  0000:0CAD  b8a01e            mov      ax, 0x1ea0
  0000:0CB0  50                push     ax
  0000:0CB1  ff362215          push     word ptr [0x1522]
  0000:0CB5  e890fe            call     0xb48  ; -> sub_0000_0B48  ; protocol_processBlock
  0000:0CB8  83c404            add      sp, 4
  0000:0CBB  ff0ed815          dec      word ptr [0x15d8]
  0000:0CBF  eb0a              jmp      0xccb  ; -> loc_0000_0CCB

loc_0000_0CC1:
  0000:0CC1  833e2a1500        cmp      word ptr [0x152a], 0
  0000:0CC6  7503              jne      0xccb  ; -> loc_0000_0CCB
  0000:0CC8  e80100            call     0xccc  ; -> sub_0000_0CCC  ; protocol_xmodemSendBlock

loc_0000_0CCB:
  0000:0CCB  c3                ret

; --- protocol_xmodemSendBlock ---
; XMODEM-specific send block with ACK wait
protocol_xmodemSendBlock:  ; (sub_0000_0CCC)
  0000:0CCC  55                push     bp
  0000:0CCD  8bec              mov      bp, sp
  0000:0CCF  83ec04            sub      sp, 4
  0000:0CD2  833e081500        cmp      word ptr [0x1508], 0
  0000:0CD7  747c              je       0xd55  ; -> loc_0000_0D55
  0000:0CD9  b80900            mov      ax, 9
  0000:0CDC  f72e1015          imul     word ptr [0x1510]
  0000:0CE0  05b415            add      ax, 0x15b4
  0000:0CE3  8946fc            mov      word ptr [bp - 4], ax
  0000:0CE6  ff0e0815          dec      word ptr [0x1508]
  0000:0CEA  ff061015          inc      word ptr [0x1510]
  0000:0CEE  a11015            mov      ax, word ptr [0x1510]
  0000:0CF1  99                cdq
  0000:0CF2  b90400            mov      cx, 4
  0000:0CF5  f7f9              idiv     cx
  0000:0CF7  89161015          mov      word ptr [0x1510], dx
  0000:0CFB  e844fc            call     0x942  ; -> sub_0000_0942  ; protocol_sendNAK
  0000:0CFE  8b5efc            mov      bx, word ptr [bp - 4]
  0000:0D01  c6075a            mov      byte ptr [bx], 0x5a
  0000:0D04  8b5efc            mov      bx, word ptr [bp - 4]
  0000:0D07  a03015            mov      al, byte ptr [0x1530]
  0000:0D0A  884705            mov      byte ptr [bx + 5], al
  0000:0D0D  8b5efc            mov      bx, word ptr [bp - 4]
  0000:0D10  a0a014            mov      al, byte ptr [0x14a0]
  0000:0D13  884706            mov      byte ptr [bx + 6], al
  0000:0D16  8b5efc            mov      bx, word ptr [bp - 4]
  0000:0D19  c64707a5          mov      byte ptr [bx + 7], 0xa5
  0000:0D1D  8b5efc            mov      bx, word ptr [bp - 4]
  0000:0D20  c647080d          mov      byte ptr [bx + 8], 0xd
  0000:0D24  ff06360a          inc      word ptr [0xa36]
  0000:0D28  ff063a0a          inc      word ptr [0xa3a]
  0000:0D2C  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0D2F  40                inc      ax
  0000:0D30  50                push     ax
  0000:0D31  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0D34  050500            add      ax, 5
  0000:0D37  50                push     ax
  0000:0D38  b80300            mov      ax, 3
  0000:0D3B  50                push     ax
  0000:0D3C  e86afa            call     0x7a9  ; -> sub_0000_07A9  ; protocol_buildPacket
  0000:0D3F  83c406            add      sp, 6
  0000:0D42  ff76fc            push     word ptr [bp - 4]
  0000:0D45  b80900            mov      ax, 9
  0000:0D48  50                push     ax
  0000:0D49  e808fc            call     0x954  ; -> sub_0000_0954  ; protocol_sendCAN
  0000:0D4C  83c404            add      sp, 4
  0000:0D4F  c7062a150100      mov      word ptr [0x152a], 1

loc_0000_0D55:
  0000:0D55  8be5              mov      sp, bp
  0000:0D57  5d                pop      bp
  0000:0D58  c3                ret

; --- protocol_calculateCRC ---
; Calculate CRC-16 for data block (2 callers)
protocol_calculateCRC:  ; (sub_0000_0D59)
  0000:0D59  55                push     bp
  0000:0D5A  8bec              mov      bp, sp
  0000:0D5C  83ec06            sub      sp, 6
  0000:0D5F  56                push     si
  0000:0D60  8b5e08            mov      bx, word ptr [bp + 8]
  0000:0D63  ff37              push     word ptr [bx]
  0000:0D65  ff7606            push     word ptr [bp + 6]
  0000:0D68  ff7604            push     word ptr [bp + 4]
  0000:0D6B  e8ed06            call     0x145b  ; -> sub_0000_145B  ; protocol_serialIO
  0000:0D6E  83c406            add      sp, 6
  0000:0D71  3d0100            cmp      ax, 1
  0000:0D74  7505              jne      0xd7b  ; -> loc_0000_0D7B

loc_0000_0D76:
  0000:0D76  b80100            mov      ax, 1
  0000:0D79  eb62              jmp      0xddd  ; -> loc_0000_0DDD

loc_0000_0D7B:
  0000:0D7B  833eee0404        cmp      word ptr [0x4ee], 4
  0000:0D80  7504              jne      0xd86  ; -> loc_0000_0D86
  0000:0D82  2bc0              sub      ax, ax
  0000:0D84  eb57              jmp      0xddd  ; -> loc_0000_0DDD

loc_0000_0D86:
  0000:0D86  a1f004            mov      ax, word ptr [0x4f0]
  0000:0D89  8b0eee04          mov      cx, word ptr [0x4ee]
  0000:0D8D  ff06ee04          inc      word ptr [0x4ee]
  0000:0D91  03c1              add      ax, cx
  0000:0D93  99                cdq
  0000:0D94  b90400            mov      cx, 4
  0000:0D97  f7f9              idiv     cx
  0000:0D99  8956fc            mov      word ptr [bp - 4], dx
  0000:0D9C  c746fe0000        mov      word ptr [bp - 2], 0
  0000:0DA1  eb1a              jmp      0xdbd  ; -> loc_0000_0DBD

loc_0000_0DA3:
  0000:0DA3  8b5efe            mov      bx, word ptr [bp - 2]
  0000:0DA6  c47604            les      si, ptr [bp + 4]
  0000:0DA9  268a00            mov      al, byte ptr es:[bx + si]
  0000:0DAC  8bc8              mov      cx, ax
  0000:0DAE  b87c00            mov      ax, 0x7c
  0000:0DB1  f76efc            imul     word ptr [bp - 4]
  0000:0DB4  8bf0              mov      si, ax
  0000:0DB6  88882412          mov      byte ptr [bx + si + 0x1224], cl
  0000:0DBA  ff46fe            inc      word ptr [bp - 2]

loc_0000_0DBD:
  0000:0DBD  8b5e08            mov      bx, word ptr [bp + 8]
  0000:0DC0  8b46fe            mov      ax, word ptr [bp - 2]
  0000:0DC3  3907              cmp      word ptr [bx], ax
  0000:0DC5  7fdc              jg       0xda3  ; -> loc_0000_0DA3
  0000:0DC7  b87c00            mov      ax, 0x7c
  0000:0DCA  f76efc            imul     word ptr [bp - 4]
  0000:0DCD  8bf0              mov      si, ax
  0000:0DCF  8b07              mov      ax, word ptr [bx]
  0000:0DD1  89842012          mov      word ptr [si + 0x1220], ax
  0000:0DD5  c78422120000      mov      word ptr [si + 0x1222], 0
  0000:0DDB  eb99              jmp      0xd76  ; -> loc_0000_0D76

loc_0000_0DDD:
  0000:0DDD  5e                pop      si
  0000:0DDE  8be5              mov      sp, bp
  0000:0DE0  5d                pop      bp
  0000:0DE1  c3                ret

; --- protocol_initXmodem ---
; Initialize XMODEM protocol parameters
protocol_initXmodem:  ; (sub_0000_0DE2)
  0000:0DE2  55                push     bp
  0000:0DE3  8bec              mov      bp, sp
  0000:0DE5  83ec02            sub      sp, 2
  0000:0DE8  56                push     si
  0000:0DE9  833eee0404        cmp      word ptr [0x4ee], 4
  0000:0DEE  7505              jne      0xdf5  ; -> loc_0000_0DF5
  0000:0DF0  b8ffff            mov      ax, 0xffff
  0000:0DF3  eb2c              jmp      0xe21  ; -> loc_0000_0E21

loc_0000_0DF5:
  0000:0DF5  a1f004            mov      ax, word ptr [0x4f0]
  0000:0DF8  8b0eee04          mov      cx, word ptr [0x4ee]
  0000:0DFC  ff06ee04          inc      word ptr [0x4ee]
  0000:0E00  03c1              add      ax, cx
  0000:0E02  99                cdq
  0000:0E03  b90400            mov      cx, 4
  0000:0E06  f7f9              idiv     cx
  0000:0E08  8956fe            mov      word ptr [bp - 2], dx
  0000:0E0B  b87c00            mov      ax, 0x7c
  0000:0E0E  f7ea              imul     dx
  0000:0E10  8bf0              mov      si, ax
  0000:0E12  c78420120000      mov      word ptr [si + 0x1220], 0
  0000:0E18  8b4604            mov      ax, word ptr [bp + 4]
  0000:0E1B  89842212          mov      word ptr [si + 0x1222], ax
  0000:0E1F  2bc0              sub      ax, ax

loc_0000_0E21:
  0000:0E21  5e                pop      si
  0000:0E22  8be5              mov      sp, bp
  0000:0E24  5d                pop      bp
  0000:0E25  c3                ret

; --- protocol_crcUpdate ---
; Update CRC-16 with new data byte
protocol_crcUpdate:  ; (sub_0000_0E26)
  0000:0E26  56                push     si
  0000:0E27  833ee80400        cmp      word ptr [0x4e8], 0
  0000:0E2C  7579              jne      0xea7  ; -> loc_0000_0EA7

loc_0000_0E2E:
  0000:0E2E  833eee0400        cmp      word ptr [0x4ee], 0
  0000:0E33  7472              je       0xea7  ; -> loc_0000_0EA7
  0000:0E35  833eb21500        cmp      word ptr [0x15b2], 0
  0000:0E3A  746b              je       0xea7  ; -> loc_0000_0EA7
  0000:0E3C  b87c00            mov      ax, 0x7c
  0000:0E3F  f72ef004          imul     word ptr [0x4f0]
  0000:0E43  8bf0              mov      si, ax
  0000:0E45  83bc201200        cmp      word ptr [si + 0x1220], 0
  0000:0E4A  7e27              jle      0xe73  ; -> loc_0000_0E73
  0000:0E4C  052012            add      ax, 0x1220
  0000:0E4F  50                push     ax
  0000:0E50  8bc6              mov      ax, si
  0000:0E52  052412            add      ax, 0x1224
  0000:0E55  50                push     ax
  0000:0E56  e800ff            call     0xd59  ; -> sub_0000_0D59  ; protocol_calculateCRC
  0000:0E59  83c404            add      sp, 4
  0000:0E5C  ff06f004          inc      word ptr [0x4f0]
  0000:0E60  a1f004            mov      ax, word ptr [0x4f0]
  0000:0E63  99                cdq
  0000:0E64  b90400            mov      cx, 4
  0000:0E67  f7f9              idiv     cx
  0000:0E69  8916f004          mov      word ptr [0x4f0], dx
  0000:0E6D  ff0eee04          dec      word ptr [0x4ee]
  0000:0E71  eb2d              jmp      0xea0  ; -> loc_0000_0EA0

loc_0000_0E73:
  0000:0E73  833eb2150e        cmp      word ptr [0x15b2], 0xe
  0000:0E78  7c2d              jl       0xea7  ; -> loc_0000_0EA7
  0000:0E7A  2bc0              sub      ax, ax
  0000:0E7C  50                push     ax
  0000:0E7D  b87c00            mov      ax, 0x7c
  0000:0E80  f72ef004          imul     word ptr [0x4f0]
  0000:0E84  8bd8              mov      bx, ax
  0000:0E86  ffb72212          push     word ptr [bx + 0x1222]
  0000:0E8A  b8faf5            mov      ax, 0xf5fa
  0000:0E8D  50                push     ax
  0000:0E8E  b80600            mov      ax, 6
  0000:0E91  50                push     ax
  0000:0E92  e8c5f7            call     0x65a  ; -> sub_0000_065A  ; protocol_sendByte
  0000:0E95  83c408            add      sp, 8
  0000:0E98  c706e8040100      mov      word ptr [0x4e8], 1
  0000:0E9E  eb07              jmp      0xea7  ; -> loc_0000_0EA7

loc_0000_0EA0:
  0000:0EA0  833eee0400        cmp      word ptr [0x4ee], 0
  0000:0EA5  7f87              jg       0xe2e  ; -> loc_0000_0E2E

loc_0000_0EA7:
  0000:0EA7  5e                pop      si
  0000:0EA8  c3                ret

; --- protocol_ymodemReceive ---
; YMODEM receive protocol state machine
protocol_ymodemReceive:  ; (sub_0000_0EA9)
  0000:0EA9  55                push     bp
  0000:0EAA  8bec              mov      bp, sp
  0000:0EAC  83ec08            sub      sp, 8
  0000:0EAF  56                push     si
  0000:0EB0  8d46fc            lea      ax, [bp - 4]
  0000:0EB3  50                push     ax
  0000:0EB4  c45e04            les      bx, ptr [bp + 4]
  0000:0EB7  268a07            mov      al, byte ptr es:[bx]
  0000:0EBA  98                cwde
  0000:0EBB  50                push     ax
  0000:0EBC  e886f9            call     0x845  ; -> sub_0000_0845  ; protocol_receiveFile
  0000:0EBF  83c404            add      sp, 4
  0000:0EC2  8946f8            mov      word ptr [bp - 8], ax
  0000:0EC5  0bc0              or       ax, ax
  0000:0EC7  7503              jne      0xecc  ; -> loc_0000_0ECC
  0000:0EC9  e9c201            jmp      0x108e  ; -> loc_0000_108E

loc_0000_0ECC:
  0000:0ECC  8bd8              mov      bx, ax
  0000:0ECE  8a4706            mov      al, byte ptr [bx + 6]
  0000:0ED1  2ae4              sub      ah, ah
  0000:0ED3  50                push     ax
  0000:0ED4  e8b3fa            call     0x98a  ; -> sub_0000_098A  ; protocol_receiveByte
  0000:0ED7  83c402            add      sp, 2
  0000:0EDA  c706da150300      mov      word ptr [0x15da], 3
  0000:0EE0  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:0EE3  8a4707            mov      al, byte ptr [bx + 7]
  0000:0EE6  2480              and      al, 0x80
  0000:0EE8  3c80              cmp      al, 0x80
  0000:0EEA  751c              jne      0xf08  ; -> loc_0000_0F08
  0000:0EEC  c45e04            les      bx, ptr [bp + 4]
  0000:0EEF  26c6075a          mov      byte ptr es:[bx], 0x5a
  0000:0EF3  c45e04            les      bx, ptr [bp + 4]
  0000:0EF6  26c6470162        mov      byte ptr es:[bx + 1], 0x62

loc_0000_0EFB:
  0000:0EFB  8b5e08            mov      bx, word ptr [bp + 8]
  0000:0EFE  c7070200          mov      word ptr [bx], 2

loc_0000_0F02:
  0000:0F02  b80100            mov      ax, 1
  0000:0F05  e9bd01            jmp      0x10c5  ; -> loc_0000_10C5

loc_0000_0F08:
  0000:0F08  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:0F0B  8a4707            mov      al, byte ptr [bx + 7]
  0000:0F0E  2ae4              sub      ah, ah
  0000:0F10  3d2000            cmp      ax, 0x20
  0000:0F13  7420              je       0xf35  ; -> loc_0000_0F35
  0000:0F15  3d2100            cmp      ax, 0x21
  0000:0F18  747c              je       0xf96  ; -> loc_0000_0F96
  0000:0F1A  3d2400            cmp      ax, 0x24
  0000:0F1D  7503              jne      0xf22  ; -> loc_0000_0F22
  0000:0F1F  e98100            jmp      0xfa3  ; -> loc_0000_0FA3

loc_0000_0F22:
  0000:0F22  3d2500            cmp      ax, 0x25
  0000:0F25  7503              jne      0xf2a  ; -> loc_0000_0F2A
  0000:0F27  e9af00            jmp      0xfd9  ; -> loc_0000_0FD9

loc_0000_0F2A:
  0000:0F2A  3d2600            cmp      ax, 0x26
  0000:0F2D  7503              jne      0xf32  ; -> loc_0000_0F32
  0000:0F2F  e93c01            jmp      0x106e  ; -> loc_0000_106E

loc_0000_0F32:
  0000:0F32  e97a01            jmp      0x10af  ; -> loc_0000_10AF

loc_0000_0F35:
  0000:0F35  8a4705            mov      al, byte ptr [bx + 5]
  0000:0F38  2ae4              sub      ah, ah
  0000:0F3A  3b062e15          cmp      ax, word ptr [0x152e]
  0000:0F3E  7550              jne      0xf90  ; -> loc_0000_0F90
  0000:0F40  e8e7f9            call     0x92a  ; -> sub_0000_092A  ; protocol_sendACK
  0000:0F43  c7062a150000      mov      word ptr [0x152a], 0
  0000:0F49  ff0e0c15          dec      word ptr [0x150c]
  0000:0F4D  750a              jne      0xf59  ; -> loc_0000_0F59
  0000:0F4F  b82400            mov      ax, 0x24
  0000:0F52  50                push     ax
  0000:0F53  e8a4fb            call     0xafa  ; -> sub_0000_0AFA  ; protocol_readFromFile
  0000:0F56  83c402            add      sp, 2

loc_0000_0F59:
  0000:0F59  c746fe0000        mov      word ptr [bp - 2], 0
  0000:0F5E  eb14              jmp      0xf74  ; -> loc_0000_0F74

loc_0000_0F60:
  0000:0F60  8b76fe            mov      si, word ptr [bp - 2]
  0000:0F63  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:0F66  8a4008            mov      al, byte ptr [bx + si + 8]
  0000:0F69  8bde              mov      bx, si
  0000:0F6B  c47604            les      si, ptr [bp + 4]
  0000:0F6E  268800            mov      byte ptr es:[bx + si], al
  0000:0F71  ff46fe            inc      word ptr [bp - 2]

loc_0000_0F74:
  0000:0F74  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0F77  3946fe            cmp      word ptr [bp - 2], ax
  0000:0F7A  7ce4              jl       0xf60  ; -> loc_0000_0F60
  0000:0F7C  8bd8              mov      bx, ax
  0000:0F7E  c47604            les      si, ptr [bp + 4]
  0000:0F81  26c60000          mov      byte ptr es:[bx + si], 0
  0000:0F85  8b5e08            mov      bx, word ptr [bp + 8]
  0000:0F88  8b46fc            mov      ax, word ptr [bp - 4]
  0000:0F8B  8907              mov      word ptr [bx], ax
  0000:0F8D  e972ff            jmp      0xf02  ; -> loc_0000_0F02

loc_0000_0F90:
  0000:0F90  e813fd            call     0xca6  ; -> sub_0000_0CA6  ; protocol_handleRetry
  0000:0F93  e91901            jmp      0x10af  ; -> loc_0000_10AF

loc_0000_0F96:
  0000:0F96  b82200            mov      ax, 0x22
  0000:0F99  50                push     ax
  0000:0F9A  e85dfb            call     0xafa  ; -> sub_0000_0AFA  ; protocol_readFromFile
  0000:0F9D  83c402            add      sp, 2
  0000:0FA0  e90c01            jmp      0x10af  ; -> loc_0000_10AF

loc_0000_0FA3:
  0000:0FA3  833ed81500        cmp      word ptr [0x15d8], 0
  0000:0FA8  7418              je       0xfc2  ; -> loc_0000_0FC2
  0000:0FAA  c706d8150000      mov      word ptr [0x15d8], 0
  0000:0FB0  c45e04            les      bx, ptr [bp + 4]
  0000:0FB3  26c60753          mov      byte ptr es:[bx], 0x53
  0000:0FB7  c45e04            les      bx, ptr [bp + 4]
  0000:0FBA  26c647015b        mov      byte ptr es:[bx + 1], 0x5b
  0000:0FBF  e939ff            jmp      0xefb  ; -> loc_0000_0EFB

loc_0000_0FC2:
  0000:0FC2  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:0FC5  8a4705            mov      al, byte ptr [bx + 5]
  0000:0FC8  2ae4              sub      ah, ah
  0000:0FCA  3b06a014          cmp      ax, word ptr [0x14a0]
  0000:0FCE  75c0              jne      0xf90  ; -> loc_0000_0F90

loc_0000_0FD0:
  0000:0FD0  c7062a150000      mov      word ptr [0x152a], 0
  0000:0FD6  e9d600            jmp      0x10af  ; -> loc_0000_10AF

loc_0000_0FD9:
  0000:0FD9  833ed81500        cmp      word ptr [0x15d8], 0
  0000:0FDE  7414              je       0xff4  ; -> loc_0000_0FF4
  0000:0FE0  b8a01e            mov      ax, 0x1ea0
  0000:0FE3  50                push     ax
  0000:0FE4  ff362215          push     word ptr [0x1522]
  0000:0FE8  e85dfb            call     0xb48  ; -> sub_0000_0B48  ; protocol_processBlock
  0000:0FEB  83c404            add      sp, 4
  0000:0FEE  ff0ed815          dec      word ptr [0x15d8]
  0000:0FF2  eb70              jmp      0x1064  ; -> loc_0000_1064

loc_0000_0FF4:
  0000:0FF4  a1a214            mov      ax, word ptr [0x14a2]
  0000:0FF7  a3dc15            mov      word ptr [0x15dc], ax
  0000:0FFA  a11214            mov      ax, word ptr [0x1412]
  0000:0FFD  01069e1e          add      word ptr [0x1e9e], ax
  0000:1001  c70612140000      mov      word ptr [0x1412], 0
  0000:1007  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:100A  8a4705            mov      al, byte ptr [bx + 5]
  0000:100D  2ae4              sub      ah, ah
  0000:100F  3b062e15          cmp      ax, word ptr [0x152e]
  0000:1013  750b              jne      0x1020  ; -> loc_0000_1020
  0000:1015  e812f9            call     0x92a  ; -> sub_0000_092A  ; protocol_sendACK
  0000:1018  c7062a150000      mov      word ptr [0x152a], 0
  0000:101E  eb44              jmp      0x1064  ; -> loc_0000_1064

loc_0000_1020:
  0000:1020  833e320a00        cmp      word ptr [0xa32], 0
  0000:1025  743a              je       0x1061  ; -> loc_0000_1061
  0000:1027  c7069e1e0000      mov      word ptr [0x1e9e], 0
  0000:102D  c706dc150000      mov      word ptr [0x15dc], 0
  0000:1033  c606ec0400        mov      byte ptr [0x4ec], 0
  0000:1038  c7060a150000      mov      word ptr [0x150a], 0
  0000:103E  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:1041  8a4705            mov      al, byte ptr [bx + 5]
  0000:1044  2ae4              sub      ah, ah
  0000:1046  a32e15            mov      word ptr [0x152e], ax
  0000:1049  8a4706            mov      al, byte ptr [bx + 6]
  0000:104C  a33015            mov      word ptr [0x1530], ax
  0000:104F  c706320a0000      mov      word ptr [0xa32], 0
  0000:1055  e8d2f8            call     0x92a  ; -> sub_0000_092A  ; protocol_sendACK
  0000:1058  c7062a150000      mov      word ptr [0x152a], 0
  0000:105E  e9a1fe            jmp      0xf02  ; -> loc_0000_0F02

loc_0000_1061:
  0000:1061  e842fc            call     0xca6  ; -> sub_0000_0CA6  ; protocol_handleRetry

loc_0000_1064:
  0000:1064  ff06380a          inc      word ptr [0xa38]
  0000:1068  ff063c0a          inc      word ptr [0xa3c]
  0000:106C  eb41              jmp      0x10af  ; -> loc_0000_10AF

loc_0000_106E:
  0000:106E  8b5ef8            mov      bx, word ptr [bp - 8]
  0000:1071  8a4705            mov      al, byte ptr [bx + 5]
  0000:1074  2ae4              sub      ah, ah
  0000:1076  3b06a014          cmp      ax, word ptr [0x14a0]
  0000:107A  750d              jne      0x1089  ; -> loc_0000_1089
  0000:107C  b82400            mov      ax, 0x24
  0000:107F  50                push     ax
  0000:1080  e877fa            call     0xafa  ; -> sub_0000_0AFA  ; protocol_readFromFile
  0000:1083  83c402            add      sp, 2
  0000:1086  e947ff            jmp      0xfd0  ; -> loc_0000_0FD0

loc_0000_1089:
  0000:1089  e840fc            call     0xccc  ; -> sub_0000_0CCC  ; protocol_xmodemSendBlock
  0000:108C  eb21              jmp      0x10af  ; -> loc_0000_10AF

loc_0000_108E:
  0000:108E  833ed81500        cmp      word ptr [0x15d8], 0
  0000:1093  741a              je       0x10af  ; -> loc_0000_10AF
  0000:1095  ff0e340a          dec      word ptr [0xa34]
  0000:1099  7514              jne      0x10af  ; -> loc_0000_10AF
  0000:109B  ff0ed815          dec      word ptr [0x15d8]
  0000:109F  7412              je       0x10b3  ; -> loc_0000_10B3
  0000:10A1  b8a01e            mov      ax, 0x1ea0
  0000:10A4  50                push     ax
  0000:10A5  ff362215          push     word ptr [0x1522]
  0000:10A9  e89cfa            call     0xb48  ; -> sub_0000_0B48  ; protocol_processBlock
  0000:10AC  83c404            add      sp, 4

loc_0000_10AF:
  0000:10AF  2bc0              sub      ax, ax
  0000:10B1  eb12              jmp      0x10c5  ; -> loc_0000_10C5

loc_0000_10B3:
  0000:10B3  c45e04            les      bx, ptr [bp + 4]
  0000:10B6  26c60753          mov      byte ptr es:[bx], 0x53
  0000:10BA  c45e04            les      bx, ptr [bp + 4]
  0000:10BD  26c647015a        mov      byte ptr es:[bx + 1], 0x5a
  0000:10C2  e936fe            jmp      0xefb  ; -> loc_0000_0EFB

loc_0000_10C5:
  0000:10C5  5e                pop      si
  0000:10C6  8be5              mov      sp, bp
  0000:10C8  5d                pop      bp
  0000:10C9  c3                ret

; --- protocol_ymodemSend ---
; YMODEM send protocol state machine
protocol_ymodemSend:  ; (sub_0000_10CA)
  0000:10CA  55                push     bp
  0000:10CB  8bec              mov      bp, sp
  0000:10CD  83ec04            sub      sp, 4
  0000:10D0  833e121400        cmp      word ptr [0x1412], 0
  0000:10D5  7504              jne      0x10db  ; -> loc_0000_10DB

loc_0000_10D7:
  0000:10D7  2bc0              sub      ax, ax
  0000:10D9  eb59              jmp      0x1134  ; -> loc_0000_1134

loc_0000_10DB:
  0000:10DB  ff0e9814          dec      word ptr [0x1498]
  0000:10DF  75f6              jne      0x10d7  ; -> loc_0000_10D7
  0000:10E1  8d46fc            lea      ax, [bp - 4]
  0000:10E4  50                push     ax
  0000:10E5  2bc0              sub      ax, ax
  0000:10E7  50                push     ax
  0000:10E8  e8690b            call     0x1c54  ; -> sub_0000_1C54  ; protocol_crcTable
  0000:10EB  83c404            add      sp, 4
  0000:10EE  a12415            mov      ax, word ptr [0x1524]
  0000:10F1  8b162615          mov      dx, word ptr [0x1526]
  0000:10F5  3956fe            cmp      word ptr [bp - 2], dx
  0000:10F8  7f0f              jg       0x1109  ; -> loc_0000_1109
  0000:10FA  7c05              jl       0x1101  ; -> loc_0000_1101
  0000:10FC  3946fc            cmp      word ptr [bp - 4], ax
  0000:10FF  7308              jae      0x1109  ; -> loc_0000_1109

loc_0000_1101:
  0000:1101  c70698149001      mov      word ptr [0x1498], 0x190
  0000:1107  ebce              jmp      0x10d7  ; -> loc_0000_10D7

loc_0000_1109:
  0000:1109  ff0eda15          dec      word ptr [0x15da]
  0000:110D  740c              je       0x111b  ; -> loc_0000_111B
  0000:110F  b82600            mov      ax, 0x26
  0000:1112  50                push     ax
  0000:1113  e8e4f9            call     0xafa  ; -> sub_0000_0AFA  ; protocol_readFromFile
  0000:1116  83c402            add      sp, 2
  0000:1119  ebbc              jmp      0x10d7  ; -> loc_0000_10D7

loc_0000_111B:
  0000:111B  c45e04            les      bx, ptr [bp + 4]
  0000:111E  26c60753          mov      byte ptr es:[bx], 0x53
  0000:1122  c45e04            les      bx, ptr [bp + 4]
  0000:1125  26c647015a        mov      byte ptr es:[bx + 1], 0x5a
  0000:112A  8b5e08            mov      bx, word ptr [bp + 8]
  0000:112D  c7070200          mov      word ptr [bx], 2
  0000:1131  b80100            mov      ax, 1

loc_0000_1134:
  0000:1134  8be5              mov      sp, bp
  0000:1136  5d                pop      bp
  0000:1137  c3                ret

; --- protocol_setBlockSize128 ---
; Set block size to 128 bytes (XMODEM standard)
protocol_setBlockSize128:  ; (sub_0000_1138)
  0000:1138  55                push     bp
  0000:1139  8bec              mov      bp, sp
  0000:113B  ff7608            push     word ptr [bp + 8]
  0000:113E  ff7606            push     word ptr [bp + 6]
  0000:1141  ff7604            push     word ptr [bp + 4]
  0000:1144  e81403            call     0x145b  ; -> sub_0000_145B  ; protocol_serialIO
  0000:1147  83c406            add      sp, 6
  0000:114A  c706e8040000      mov      word ptr [0x4e8], 0
  0000:1150  5d                pop      bp
  0000:1151  c3                ret

; --- protocol_setBlockSize1024 ---
; Set block size to 1024 bytes (YMODEM)
protocol_setBlockSize1024:  ; (sub_0000_1152)
  0000:1152  c706e8040000      mov      word ptr [0x4e8], 0
  0000:1158  833eee0400        cmp      word ptr [0x4ee], 0
  0000:115D  7415              je       0x1174  ; -> loc_0000_1174
  0000:115F  ff06f004          inc      word ptr [0x4f0]
  0000:1163  a1f004            mov      ax, word ptr [0x4f0]
  0000:1166  99                cdq
  0000:1167  b90400            mov      cx, 4
  0000:116A  f7f9              idiv     cx
  0000:116C  8916f004          mov      word ptr [0x4f0], dx
  0000:1170  ff0eee04          dec      word ptr [0x4ee]

loc_0000_1174:
  0000:1174  c3                ret

; --- protocol_enableCRC ---
; Enable CRC-16 mode (vs checksum)
protocol_enableCRC:  ; (sub_0000_1175)
  0000:1175  c706e8040000      mov      word ptr [0x4e8], 0
  0000:117B  c3                ret

; --- protocol_openOutputFile ---
; Open output file for received data (2 callers)
protocol_openOutputFile:  ; (sub_0000_117C)
  0000:117C  833ef40600        cmp      word ptr [0x6f4], 0
  0000:1181  7404              je       0x1187  ; -> loc_0000_1187
  0000:1183  2bc0              sub      ax, ax
  0000:1185  eb6b              jmp      0x11f2  ; -> loc_0000_11F2

loc_0000_1187:
  0000:1187  9a3d030000        lcall    0, 0x33d  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:118C  c6069a1401        mov      byte ptr [0x149a], 1
  0000:1191  c7069b149603      mov      word ptr [0x149b], 0x396
  0000:1197  c7069d140000      mov      word ptr [0x149d], 0  ; RELOC->seg_0000
  0000:119D  b89a14            mov      ax, 0x149a
  0000:11A0  50                push     ax
  0000:11A1  e8e604            call     0x168a  ; -> sub_0000_168A  ; protocol_getCallbackE
  0000:11A4  83c402            add      sp, 2
  0000:11A7  a3f206            mov      word ptr [0x6f2], ax
  0000:11AA  40                inc      ax
  0000:11AB  7505              jne      0x11b2  ; -> loc_0000_11B2

loc_0000_11AD:
  0000:11AD  b8ffff            mov      ax, 0xffff
  0000:11B0  eb40              jmp      0x11f2  ; -> loc_0000_11F2

loc_0000_11B2:
  0000:11B2  c70612153c03      mov      word ptr [0x1512], 0x33c
  0000:11B8  c70614150000      mov      word ptr [0x1514], 0  ; RELOC->seg_0000
  0000:11BE  c70616154703      mov      word ptr [0x1516], 0x347
  0000:11C4  c70618150000      mov      word ptr [0x1518], 0  ; RELOC->seg_0000
  0000:11CA  c7061a154603      mov      word ptr [0x151a], 0x346
  0000:11D0  c7061c150000      mov      word ptr [0x151c], 0  ; RELOC->seg_0000
  0000:11D6  c7061e154603      mov      word ptr [0x151e], 0x346
  0000:11DC  c70620150000      mov      word ptr [0x1520], 0  ; RELOC->seg_0000
  0000:11E2  b81215            mov      ax, 0x1512
  0000:11E5  50                push     ax
  0000:11E6  e89504            call     0x167e  ; -> sub_0000_167E  ; protocol_getCallbackC
  0000:11E9  83c402            add      sp, 2
  0000:11EC  a3f406            mov      word ptr [0x6f4], ax
  0000:11EF  40                inc      ax
  0000:11F0  74bb              je       0x11ad  ; -> loc_0000_11AD

loc_0000_11F2:
  0000:11F2  c3                ret

; --- protocol_openInputFile ---
; Open input file for sending
protocol_openInputFile:  ; (sub_0000_11F3)
  0000:11F3  833ef20600        cmp      word ptr [0x6f2], 0
  0000:11F8  740a              je       0x1204  ; -> loc_0000_1204
  0000:11FA  ff36f206          push     word ptr [0x6f2]
  0000:11FE  e88f04            call     0x1690  ; -> sub_0000_1690  ; protocol_getCallbackF
  0000:1201  83c402            add      sp, 2

loc_0000_1204:
  0000:1204  c706f2060000      mov      word ptr [0x6f2], 0
  0000:120A  833ef40600        cmp      word ptr [0x6f4], 0
  0000:120F  740a              je       0x121b  ; -> loc_0000_121B
  0000:1211  ff36f406          push     word ptr [0x6f4]
  0000:1215  e86c04            call     0x1684  ; -> sub_0000_1684  ; protocol_getCallbackD
  0000:1218  83c402            add      sp, 2

loc_0000_121B:
  0000:121B  c706f4060000      mov      word ptr [0x6f4], 0
  0000:1221  e8e7f1            call     0x40b  ; -> sub_0000_040B  ; protocol_cleanupState
  0000:1224  c3                ret

; --- protocol_closeTransferFile ---
; Close transfer file handle
protocol_closeTransferFile:  ; (sub_0000_1225)
  0000:1225  55                push     bp
  0000:1226  8bec              mov      bp, sp
  0000:1228  83ec22            sub      sp, 0x22
  0000:122B  56                push     si
  0000:122C  b87c00            mov      ax, 0x7c
  0000:122F  f72ec204          imul     word ptr [0x4c2]
  0000:1233  8bd8              mov      bx, ax
  0000:1235  83bf400a00        cmp      word ptr [bx + 0xa40], 0
  0000:123A  7504              jne      0x1240  ; -> loc_0000_1240
  0000:123C  2bc0              sub      ax, ax
  0000:123E  eb4e              jmp      0x128e  ; -> loc_0000_128E

loc_0000_1240:
  0000:1240  b87c00            mov      ax, 0x7c
  0000:1243  f72ec204          imul     word ptr [0x4c2]
  0000:1247  05400a            add      ax, 0xa40
  0000:124A  8946fe            mov      word ptr [bp - 2], ax
  0000:124D  c746fc0000        mov      word ptr [bp - 4], 0

loc_0000_1252:
  0000:1252  8b5efc            mov      bx, word ptr [bp - 4]
  0000:1255  8b76fe            mov      si, word ptr [bp - 2]
  0000:1258  8a00              mov      al, byte ptr [bx + si]
  0000:125A  c47604            les      si, ptr [bp + 4]
  0000:125D  268800            mov      byte ptr es:[bx + si], al
  0000:1260  ff46fc            inc      word ptr [bp - 4]
  0000:1263  837efc7c          cmp      word ptr [bp - 4], 0x7c
  0000:1267  7ce9              jl       0x1252  ; -> loc_0000_1252
  0000:1269  b87c00            mov      ax, 0x7c
  0000:126C  f72ec204          imul     word ptr [0x4c2]
  0000:1270  8bd8              mov      bx, ax
  0000:1272  c787400a0000      mov      word ptr [bx + 0xa40], 0
  0000:1278  ff06c204          inc      word ptr [0x4c2]
  0000:127C  a1c204            mov      ax, word ptr [0x4c2]
  0000:127F  250f00            and      ax, 0xf
  0000:1282  a3c204            mov      word ptr [0x4c2], ax
  0000:1285  a1d604            mov      ax, word ptr [0x4d6]
  0000:1288  a3d804            mov      word ptr [0x4d8], ax
  0000:128B  b80100            mov      ax, 1

loc_0000_128E:
  0000:128E  5e                pop      si
  0000:128F  8be5              mov      sp, bp
  0000:1291  5d                pop      bp
  0000:1292  c3                ret

; --- protocol_updateProgress ---
; Update transfer progress display (2 callers)
protocol_updateProgress:  ; (sub_0000_1293)
  0000:1293  55                push     bp
  0000:1294  8bec              mov      bp, sp
  0000:1296  56                push     si
  0000:1297  a1e204            mov      ax, word ptr [0x4e2]
  0000:129A  0b06e404          or       ax, word ptr [0x4e4]
  0000:129E  750b              jne      0x12ab  ; -> loc_0000_12AB
  0000:12A0  b8e204            mov      ax, 0x4e2
  0000:12A3  1e                push     ds
  0000:12A4  50                push     ax
  0000:12A5  e8d003            call     0x1678  ; -> sub_0000_1678  ; protocol_getCallbackB
  0000:12A8  83c404            add      sp, 4

loc_0000_12AB:
  0000:12AB  c41ee204          les      bx, ptr [0x4e2]
  0000:12AF  268b470c          mov      ax, word ptr es:[bx + 0xc]
  0000:12B3  268b570e          mov      dx, word ptr es:[bx + 0xe]
  0000:12B7  26394708          cmp      word ptr es:[bx + 8], ax
  0000:12BB  750a              jne      0x12c7  ; -> loc_0000_12C7
  0000:12BD  2639570a          cmp      word ptr es:[bx + 0xa], dx
  0000:12C1  7504              jne      0x12c7  ; -> loc_0000_12C7
  0000:12C3  2bc0              sub      ax, ax
  0000:12C5  eb51              jmp      0x1318  ; -> loc_0000_1318

loc_0000_12C7:
  0000:12C7  8b5e04            mov      bx, word ptr [bp + 4]
  0000:12CA  8b36e204          mov      si, word ptr [0x4e2]
  0000:12CE  26c4740c          les      si, ptr es:[si + 0xc]
  0000:12D2  268a04            mov      al, byte ptr es:[si]
  0000:12D5  8807              mov      byte ptr [bx], al
  0000:12D7  c41ee204          les      bx, ptr [0x4e2]
  0000:12DB  26ff470c          inc      word ptr es:[bx + 0xc]
  0000:12DF  c41ee204          les      bx, ptr [0x4e2]
  0000:12E3  26837f1200        cmp      word ptr es:[bx + 0x12], 0
  0000:12E8  7e04              jle      0x12ee  ; -> loc_0000_12EE
  0000:12EA  26ff4f12          dec      word ptr es:[bx + 0x12]

loc_0000_12EE:
  0000:12EE  c41ee204          les      bx, ptr [0x4e2]
  0000:12F2  268b4704          mov      ax, word ptr es:[bx + 4]
  0000:12F6  268b5706          mov      dx, word ptr es:[bx + 6]
  0000:12FA  2639470c          cmp      word ptr es:[bx + 0xc], ax
  0000:12FE  7515              jne      0x1315  ; -> loc_0000_1315
  0000:1300  2639570e          cmp      word ptr es:[bx + 0xe], dx
  0000:1304  750f              jne      0x1315  ; -> loc_0000_1315
  0000:1306  268b07            mov      ax, word ptr es:[bx]
  0000:1309  268b5702          mov      dx, word ptr es:[bx + 2]
  0000:130D  2689470c          mov      word ptr es:[bx + 0xc], ax
  0000:1311  2689570e          mov      word ptr es:[bx + 0xe], dx

loc_0000_1315:
  0000:1315  b80100            mov      ax, 1

loc_0000_1318:
  0000:1318  5e                pop      si
  0000:1319  5d                pop      bp
  0000:131A  c3                ret

; --- protocol_calculateChecksum ---
; Calculate simple checksum for XMODEM
protocol_calculateChecksum:  ; (sub_0000_131B)
  0000:131B  56                push     si
  0000:131C  833e0a1500        cmp      word ptr [0x150a], 0
  0000:1321  7505              jne      0x1328  ; -> loc_0000_1328

loc_0000_1323:
  0000:1323  b80100            mov      ax, 1
  0000:1326  eb42              jmp      0x136a  ; -> loc_0000_136A

loc_0000_1328:
  0000:1328  8b1e3e0a          mov      bx, word ptr [0xa3e]
  0000:132C  8b360a15          mov      si, word ptr [0x150a]
  0000:1330  8a00              mov      al, byte ptr [bx + si]
  0000:1332  98                cwde
  0000:1333  50                push     ax
  0000:1334  e83b03            call     0x1672  ; -> sub_0000_1672  ; protocol_getCallbackA
  0000:1337  83c402            add      sp, 2
  0000:133A  40                inc      ax
  0000:133B  7505              jne      0x1342  ; -> loc_0000_1342
  0000:133D  b80100            mov      ax, 1
  0000:1340  eb02              jmp      0x1344  ; -> loc_0000_1344

loc_0000_1342:
  0000:1342  2bc0              sub      ax, ax

loc_0000_1344:
  0000:1344  a3300a            mov      word ptr [0xa30], ax
  0000:1347  0bc0              or       ax, ax
  0000:1349  7404              je       0x134f  ; -> loc_0000_134F
  0000:134B  2bc0              sub      ax, ax
  0000:134D  eb1b              jmp      0x136a  ; -> loc_0000_136A

loc_0000_134F:
  0000:134F  ff063e0a          inc      word ptr [0xa3e]
  0000:1353  a10012            mov      ax, word ptr [0x1200]
  0000:1356  39063e0a          cmp      word ptr [0xa3e], ax
  0000:135A  7506              jne      0x1362  ; -> loc_0000_1362
  0000:135C  c7060a150000      mov      word ptr [0x150a], 0

loc_0000_1362:
  0000:1362  a1d604            mov      ax, word ptr [0x4d6]
  0000:1365  a3d804            mov      word ptr [0x4d8], ax
  0000:1368  ebb9              jmp      0x1323  ; -> loc_0000_1323

loc_0000_136A:
  0000:136A  5e                pop      si
  0000:136B  c3                ret

; --- protocol_parseBatchFilename ---
; Parse YMODEM batch filename from block 0
protocol_parseBatchFilename:  ; (sub_0000_136C)
  0000:136C  55                push     bp
  0000:136D  8bec              mov      bp, sp
  0000:136F  83ec04            sub      sp, 4
  0000:1372  56                push     si
  0000:1373  c746fe0000        mov      word ptr [bp - 2], 0
  0000:1378  eb10              jmp      0x138a  ; -> loc_0000_138A

loc_0000_137A:
  0000:137A  2bc0              sub      ax, ax

loc_0000_137C:
  0000:137C  8946fc            mov      word ptr [bp - 4], ax
  0000:137F  0bc0              or       ax, ax
  0000:1381  7404              je       0x1387  ; -> loc_0000_1387
  0000:1383  2bc0              sub      ax, ax
  0000:1385  eb27              jmp      0x13ae  ; -> loc_0000_13AE

loc_0000_1387:
  0000:1387  ff46fe            inc      word ptr [bp - 2]

loc_0000_138A:
  0000:138A  8b4606            mov      ax, word ptr [bp + 6]
  0000:138D  3946fe            cmp      word ptr [bp - 2], ax
  0000:1390  7d19              jge      0x13ab  ; -> loc_0000_13AB
  0000:1392  8b5efe            mov      bx, word ptr [bp - 2]
  0000:1395  8b7604            mov      si, word ptr [bp + 4]
  0000:1398  8a00              mov      al, byte ptr [bx + si]
  0000:139A  2ae4              sub      ah, ah
  0000:139C  50                push     ax
  0000:139D  e8d202            call     0x1672  ; -> sub_0000_1672  ; protocol_getCallbackA
  0000:13A0  83c402            add      sp, 2
  0000:13A3  40                inc      ax
  0000:13A4  75d4              jne      0x137a  ; -> loc_0000_137A
  0000:13A6  b80100            mov      ax, 1
  0000:13A9  ebd1              jmp      0x137c  ; -> loc_0000_137C

loc_0000_13AB:
  0000:13AB  b80100            mov      ax, 1

loc_0000_13AE:
  0000:13AE  5e                pop      si
  0000:13AF  8be5              mov      sp, bp
  0000:13B1  5d                pop      bp
  0000:13B2  c3                ret
  0000:13B3  db 83 3E DE 04 00 74 1E FF 0E DE 04 75 18 2B C0 50 ; |.>...t.....u.+.P|
  0000:13C3  db 50 B8 F4 F5 50 B8 06 00 50 E8 EE F2 83 C4 08 A1 ; |P...P...P.......|
  0000:13D3  db DC 04 A3 DE 04 83 3E D4 04 00 74 18 FF 0E D4 04 ; |......>...t.....|
  0000:13E3  db 75 12 2B C0 50 50 B8 05 00 50 B8 06 00 50 E8 C9 ; |u.+.PP...P...P..|
  0000:13F3  db F2 83 C4 08 83 3E D8 04 00 74 18 FF 0E D8 04 75 ; |.....>...t.....u|
  0000:1403  db 12 2B C0 50 50 FF 36 DA 04 B8 06 00 50 E8 AA F2 ; |.+.PP.6.....P...|
  0000:1413  db 83 C4 08 C3                                     ; |....|

; --- protocol_getProtocolName ---
; Get current protocol name string
protocol_getProtocolName:  ; (sub_0000_1417)
  0000:1417  55                push     bp
  0000:1418  8bec              mov      bp, sp
  0000:141A  b8b600            mov      ax, 0xb6
  0000:141D  f76e04            imul     word ptr [bp + 4]
  0000:1420  a3d404            mov      word ptr [0x4d4], ax
  0000:1423  5d                pop      bp
  0000:1424  c3                ret

; --- protocol_getTransferDir ---
; Get transfer direction string (Send/Receive)
protocol_getTransferDir:  ; (sub_0000_1425)
  0000:1425  55                push     bp
  0000:1426  8bec              mov      bp, sp
  0000:1428  b8b600            mov      ax, 0xb6
  0000:142B  f76e04            imul     word ptr [bp + 4]
  0000:142E  a3d604            mov      word ptr [0x4d6], ax
  0000:1431  a3d804            mov      word ptr [0x4d8], ax
  0000:1434  8b4606            mov      ax, word ptr [bp + 6]
  0000:1437  a3da04            mov      word ptr [0x4da], ax
  0000:143A  5d                pop      bp
  0000:143B  c3                ret

; --- protocol_setStatusMsg ---
; Set status message for display
protocol_setStatusMsg:  ; (sub_0000_143C)
  0000:143C  c7063c0a0000      mov      word ptr [0xa3c], 0
  0000:1442  c7063a0a0000      mov      word ptr [0xa3a], 0
  0000:1448  c3                ret

; --- protocol_getErrorMsg ---
; Get error message string
protocol_getErrorMsg:  ; (sub_0000_1449)
  0000:1449  b8360a            mov      ax, 0xa36
  0000:144C  8cda              mov      dx, ds
  0000:144E  c3                ret

; --- protocol_setErrorState ---
; Set protocol error state
protocol_setErrorState:  ; (sub_0000_144F)
  0000:144F  a13a0a            mov      ax, word ptr [0xa3a]
  0000:1452  03063c0a          add      ax, word ptr [0xa3c]
  0000:1456  c3                ret

; --- protocol_clearError ---
; Clear protocol error state
protocol_clearError:  ; (sub_0000_1457)
  0000:1457  a1b215            mov      ax, word ptr [0x15b2]
  0000:145A  c3                ret

; --- protocol_serialIO ---
; Serial I/O wrapper - call Telecom callback (3 callers)
protocol_serialIO:  ; (sub_0000_145B)
  0000:145B  55                push     bp
  0000:145C  8bec              mov      bp, sp
  0000:145E  83ec06            sub      sp, 6
  0000:1461  56                push     si
  0000:1462  833eb21500        cmp      word ptr [0x15b2], 0
  0000:1467  7505              jne      0x146e  ; -> loc_0000_146E
  0000:1469  2bc0              sub      ax, ax
  0000:146B  e99f00            jmp      0x150d  ; -> loc_0000_150D

loc_0000_146E:
  0000:146E  a10e15            mov      ax, word ptr [0x150e]
  0000:1471  b107              mov      cl, 7
  0000:1473  d3e0              shl      ax, cl
  0000:1475  059e16            add      ax, 0x169e
  0000:1478  8946fa            mov      word ptr [bp - 6], ax
  0000:147B  ff0eb215          dec      word ptr [0x15b2]
  0000:147F  ff060e15          inc      word ptr [0x150e]
  0000:1483  a10e15            mov      ax, word ptr [0x150e]
  0000:1486  99                cdq
  0000:1487  b91000            mov      cx, 0x10
  0000:148A  f7f9              idiv     cx
  0000:148C  89160e15          mov      word ptr [0x150e], dx
  0000:1490  e8aff4            call     0x942  ; -> sub_0000_0942  ; protocol_sendNAK
  0000:1493  8b5efa            mov      bx, word ptr [bp - 6]
  0000:1496  c6075a            mov      byte ptr [bx], 0x5a
  0000:1499  8b5efa            mov      bx, word ptr [bp - 6]
  0000:149C  a03015            mov      al, byte ptr [0x1530]
  0000:149F  884705            mov      byte ptr [bx + 5], al
  0000:14A2  8b5efa            mov      bx, word ptr [bp - 6]
  0000:14A5  a0a014            mov      al, byte ptr [0x14a0]
  0000:14A8  884706            mov      byte ptr [bx + 6], al
  0000:14AB  8b5efa            mov      bx, word ptr [bp - 6]
  0000:14AE  c64707a0          mov      byte ptr [bx + 7], 0xa0
  0000:14B2  c746fe0000        mov      word ptr [bp - 2], 0
  0000:14B7  eb14              jmp      0x14cd  ; -> loc_0000_14CD

loc_0000_14B9:
  0000:14B9  8b5efe            mov      bx, word ptr [bp - 2]
  0000:14BC  c47604            les      si, ptr [bp + 4]
  0000:14BF  268a00            mov      al, byte ptr es:[bx + si]
  0000:14C2  8bf3              mov      si, bx
  0000:14C4  8b5efa            mov      bx, word ptr [bp - 6]
  0000:14C7  884008            mov      byte ptr [bx + si + 8], al
  0000:14CA  ff46fe            inc      word ptr [bp - 2]

loc_0000_14CD:
  0000:14CD  8b4608            mov      ax, word ptr [bp + 8]
  0000:14D0  3946fe            cmp      word ptr [bp - 2], ax
  0000:14D3  7ce4              jl       0x14b9  ; -> loc_0000_14B9
  0000:14D5  8b76fe            mov      si, word ptr [bp - 2]
  0000:14D8  ff46fe            inc      word ptr [bp - 2]
  0000:14DB  8b5efa            mov      bx, word ptr [bp - 6]
  0000:14DE  c640080d          mov      byte ptr [bx + si + 8], 0xd
  0000:14E2  8b46fa            mov      ax, word ptr [bp - 6]
  0000:14E5  40                inc      ax
  0000:14E6  50                push     ax
  0000:14E7  8b46fa            mov      ax, word ptr [bp - 6]
  0000:14EA  050500            add      ax, 5
  0000:14ED  50                push     ax
  0000:14EE  8b46fe            mov      ax, word ptr [bp - 2]
  0000:14F1  40                inc      ax
  0000:14F2  40                inc      ax
  0000:14F3  50                push     ax
  0000:14F4  e8b2f2            call     0x7a9  ; -> sub_0000_07A9  ; protocol_buildPacket
  0000:14F7  83c406            add      sp, 6
  0000:14FA  ff76fa            push     word ptr [bp - 6]
  0000:14FD  8b46fe            mov      ax, word ptr [bp - 2]
  0000:1500  050800            add      ax, 8
  0000:1503  50                push     ax
  0000:1504  e84df4            call     0x954  ; -> sub_0000_0954  ; protocol_sendCAN
  0000:1507  83c404            add      sp, 4
  0000:150A  b80100            mov      ax, 1

loc_0000_150D:
  0000:150D  5e                pop      si
  0000:150E  8be5              mov      sp, bp
  0000:1510  5d                pop      bp
  0000:1511  c3                ret

; --- protocol_initXmodemState ---
; Initialize XMODEM protocol state machine
protocol_initXmodemState:  ; (sub_0000_1512)
  0000:1512  55                push     bp
  0000:1513  8bec              mov      bp, sp
  0000:1515  803ee60400        cmp      byte ptr [0x4e6], 0
  0000:151A  7504              jne      0x1520  ; -> loc_0000_1520
  0000:151C  2bc0              sub      ax, ax
  0000:151E  eb14              jmp      0x1534  ; -> loc_0000_1534

loc_0000_1520:
  0000:1520  8d4608            lea      ax, [bp + 8]
  0000:1523  50                push     ax
  0000:1524  ff7606            push     word ptr [bp + 6]
  0000:1527  ff7604            push     word ptr [bp + 4]
  0000:152A  b80100            mov      ax, 1
  0000:152D  50                push     ax
  0000:152E  e8a9f1            call     0x6da  ; -> sub_0000_06DA  ; protocol_transferLoop
  0000:1531  83c408            add      sp, 8

loc_0000_1534:
  0000:1534  5d                pop      bp
  0000:1535  c3                ret

; --- protocol_initYmodemState ---
; Initialize YMODEM protocol state machine
protocol_initYmodemState:  ; (sub_0000_1536)
  0000:1536  55                push     bp
  0000:1537  8bec              mov      bp, sp
  0000:1539  81ec8e00          sub      sp, 0x8e
  0000:153D  e8a7ee            call     0x3e7  ; -> sub_0000_03E7  ; protocol_initState
  0000:1540  e839fc            call     0x117c  ; -> sub_0000_117C  ; protocol_openOutputFile
  0000:1543  c706c2040000      mov      word ptr [0x4c2], 0
  0000:1549  c706c4040000      mov      word ptr [0x4c4], 0
  0000:154F  c7062815400a      mov      word ptr [0x1528], 0xa40
  0000:1555  c78678ff1300      mov      word ptr [bp - 0x88], 0x13
  0000:155B  8d8678ff          lea      ax, [bp - 0x88]
  0000:155F  50                push     ax
  0000:1560  ff7606            push     word ptr [bp + 6]
  0000:1563  ff7604            push     word ptr [bp + 4]
  0000:1566  2bc0              sub      ax, ax
  0000:1568  50                push     ax
  0000:1569  e86ef1            call     0x6da  ; -> sub_0000_06DA  ; protocol_transferLoop
  0000:156C  83c408            add      sp, 8
  0000:156F  8d8674ff          lea      ax, [bp - 0x8c]
  0000:1573  50                push     ax
  0000:1574  e85f06            call     0x1bd6  ; -> sub_0000_1BD6  ; protocol_formatTransferStr
  0000:1577  83c402            add      sp, 2
  0000:157A  c646fa05          mov      byte ptr [bp - 6], 5
  0000:157E  c78672ff0000      mov      word ptr [bp - 0x8e], 0

loc_0000_1584:
  0000:1584  8d46fc            lea      ax, [bp - 4]
  0000:1587  50                push     ax
  0000:1588  e84b06            call     0x1bd6  ; -> sub_0000_1BD6  ; protocol_formatTransferStr
  0000:158B  83c402            add      sp, 2
  0000:158E  8b46fc            mov      ax, word ptr [bp - 4]
  0000:1591  8b56fe            mov      dx, word ptr [bp - 2]
  0000:1594  2b8674ff          sub      ax, word ptr [bp - 0x8c]
  0000:1598  1b9676ff          sbb      dx, word ptr [bp - 0x8a]
  0000:159C  0bd2              or       dx, dx
  0000:159E  7c2f              jl       0x15cf  ; -> loc_0000_15CF
  0000:15A0  7f05              jg       0x15a7  ; -> loc_0000_15A7
  0000:15A2  3d1e00            cmp      ax, 0x1e
  0000:15A5  7228              jb       0x15cf  ; -> loc_0000_15CF

loc_0000_15A7:
  0000:15A7  8d8678ff          lea      ax, [bp - 0x88]
  0000:15AB  50                push     ax
  0000:15AC  ff7606            push     word ptr [bp + 6]
  0000:15AF  ff7604            push     word ptr [bp + 4]
  0000:15B2  2bc0              sub      ax, ax
  0000:15B4  50                push     ax
  0000:15B5  e822f1            call     0x6da  ; -> sub_0000_06DA  ; protocol_transferLoop
  0000:15B8  83c408            add      sp, 8
  0000:15BB  8d8674ff          lea      ax, [bp - 0x8c]
  0000:15BF  50                push     ax
  0000:15C0  e81306            call     0x1bd6  ; -> sub_0000_1BD6  ; protocol_formatTransferStr
  0000:15C3  83c402            add      sp, 2
  0000:15C6  fe4efa            dec      byte ptr [bp - 6]
  0000:15C9  7504              jne      0x15cf  ; -> loc_0000_15CF
  0000:15CB  2bc0              sub      ax, ax
  0000:15CD  eb33              jmp      0x1602  ; -> loc_0000_1602

loc_0000_15CF:
  0000:15CF  8d867aff          lea      ax, [bp - 0x86]
  0000:15D3  50                push     ax
  0000:15D4  e8bcfc            call     0x1293  ; -> sub_0000_1293  ; protocol_updateProgress
  0000:15D7  83c402            add      sp, 2
  0000:15DA  3d0100            cmp      ax, 1
  0000:15DD  7519              jne      0x15f8  ; -> loc_0000_15F8
  0000:15DF  8d8678ff          lea      ax, [bp - 0x88]
  0000:15E3  50                push     ax
  0000:15E4  8d867aff          lea      ax, [bp - 0x86]
  0000:15E8  16                push     ss
  0000:15E9  50                push     ax
  0000:15EA  b80200            mov      ax, 2
  0000:15ED  50                push     ax
  0000:15EE  e8e9f0            call     0x6da  ; -> sub_0000_06DA  ; protocol_transferLoop
  0000:15F1  83c408            add      sp, 8
  0000:15F4  898672ff          mov      word ptr [bp - 0x8e], ax

loc_0000_15F8:
  0000:15F8  83be72ff00        cmp      word ptr [bp - 0x8e], 0
  0000:15FD  7485              je       0x1584  ; -> loc_0000_1584
  0000:15FF  b80100            mov      ax, 1

loc_0000_1602:
  0000:1602  8be5              mov      sp, bp
  0000:1604  5d                pop      bp
  0000:1605  c3                ret

; --- protocol_resetTransfer ---
; Reset transfer state for new transfer
protocol_resetTransfer:  ; (sub_0000_1606)
  0000:1606  55                push     bp
  0000:1607  8bec              mov      bp, sp
  0000:1609  8a4604            mov      al, byte ptr [bp + 4]
  0000:160C  a2e604            mov      byte ptr [0x4e6], al
  0000:160F  5d                pop      bp
  0000:1610  c3                ret
  0000:1611  db C3 C3 90                                        ; |...|

; --- protocol_intE0hDispatch ---
; INT E0h dispatch table (4 entries)
protocol_intE0hDispatch:  ; (sub_0000_1614)
  0000:1614  06                push     es
  0000:1615  53                push     bx
  0000:1616  52                push     dx
  0000:1617  1e                push     ds
  0000:1618  07                pop      es
  0000:1619  bbf606            mov      bx, 0x6f6
  0000:161C  bafa06            mov      dx, 0x6fa
  0000:161F  b80602            mov      ax, 0x206
  0000:1622  cde0              int      0xe0  ; INT E0h, AH=02h
  0000:1624  9aa2160000        lcall    0, 0x16a2  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:1629  5a                pop      dx
  0000:162A  5b                pop      bx
  0000:162B  07                pop      es
  0000:162C  c3                ret
  0000:162D  db 06 52 1E 07 BA FA 06 B8 07 02 CD E0 5A 07 C3 E8 ; |.R..........Z...|
  0000:163D  db D5 FF E8 54 00 C3 E8 56 00 E8 E4 FF C3          ; |...T...V.....|

loc_0000_164A:
  0000:164A  55                push     bp
  0000:164B  8bec              mov      bp, sp
  0000:164D  83c504            add      bp, 4
  0000:1650  9ac9160000        lcall    0, 0x16c9  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:1655  3dffff            cmp      ax, 0xffff
  0000:1658  7416              je       0x1670  ; -> loc_0000_1670
  0000:165A  3dfeff            cmp      ax, 0xfffe
  0000:165D  7411              je       0x1670  ; -> loc_0000_1670
  0000:165F  9af8160000        lcall    0, 0x16f8  ; -> sub_0000_0000 | RELOC->seg_0000
  0000:1664  a30007            mov      word ptr [0x700], ax
  0000:1667  ff1ef606          lcall    [0x6f6]
  0000:166B  9a22170000        lcall    0, 0x1722  ; -> sub_0000_0000 | RELOC->seg_0000

loc_0000_1670:
  0000:1670  5d                pop      bp
  0000:1671  c3                ret

; --- protocol_getCallbackA ---
; Get serial callback A (2 callers)
protocol_getCallbackA:  ; (sub_0000_1672)
  0000:1672  b8af20            mov      ax, 0x20af
  0000:1675  e9d2ff            jmp      0x164a  ; -> loc_0000_164A

; --- protocol_getCallbackB ---
; Get serial callback B (2 callers)
protocol_getCallbackB:  ; (sub_0000_1678)
  0000:1678  b8b820            mov      ax, 0x20b8
  0000:167B  e9ccff            jmp      0x164a  ; -> loc_0000_164A

; --- protocol_getCallbackC ---
; Get serial callback C
protocol_getCallbackC:  ; (sub_0000_167E)
  0000:167E  b8dd20            mov      ax, 0x20dd
  0000:1681  e9c6ff            jmp      0x164a  ; -> loc_0000_164A

; --- protocol_getCallbackD ---
; Get serial callback D
protocol_getCallbackD:  ; (sub_0000_1684)
  0000:1684  b8de20            mov      ax, 0x20de
  0000:1687  e9c0ff            jmp      0x164a  ; -> loc_0000_164A

; --- protocol_getCallbackE ---
; Get serial callback E
protocol_getCallbackE:  ; (sub_0000_168A)
  0000:168A  b8df20            mov      ax, 0x20df
  0000:168D  e9baff            jmp      0x164a  ; -> loc_0000_164A

; --- protocol_getCallbackF ---
; Get serial callback F
protocol_getCallbackF:  ; (sub_0000_1690)
  0000:1690  b8e020            mov      ax, 0x20e0
  0000:1693  e9b4ff            jmp      0x164a  ; -> loc_0000_164A
  0000:1696  db B8 D6 20 E9 AE FF B8 D7 20 E9 A8 FF 50 B8 D5 20 ; |.. ..... ...P.. |
  0000:16A6  db 25 FF 0F FF 1E F6 06 C7 06 02 07 FF 0F 3C 20 7E ; |%............< ~|
  0000:16B6  db 10 C7 06 02 07 FF FF 3C 37 7E 06 C7 06 02 07 FF ; |.......<7~......|
  0000:16C6  db EF 58 CB 81 3E 02 07 FF 0F 74 11 81 3E 02 07 FF ; |.X..>....t..>...|
  0000:16D6  db EF 74 1E                                        ; |.t.|
  0000:16D9  db 3D 44 21 7E                                     ; "=D!~"
  0000:16DD  db 19 B8 FF FF CB 3D 0A 21 7F 05 23 06 02 07 CB 3D ; |.....=.!..#....=|
  0000:16ED  db 2D 21 B8 FE FF 74 03 B8 FF FF CB 9C 3D 90 20 75 ; |-!...t......=. u|
  0000:16FD  db 22 81 3E 02 07 FF 0F 74 1A 50 B8 D5 20 FF 1E F6 ; |".>....t.P.. ...|
  0000:170D  db 06 3C 29 58 7F 0D 53 8B 5D 0E 8B 1F D1 E3 43 29 ; |.<)X..S.].....C)|
  0000:171D  db 5D 02 5B 9D CB 9C 81 3E 00 07 90 20 74 0A 81 3E ; |].[....>... t..>|
  0000:172D  db 00 07 17 21 74 02 9D CB 81 3E 02 07 FF 0F 74 6A ; |...!t....>....tj|
  0000:173D  db 50 B8 D5 20 FF 1E F6 06 3C 29 7F 18 81 3E 00 07 ; |P.. ....<)...>..|
  0000:174D  db 17 21 74 10 58 53 8B 5D 0E 8B 1F D1 E3 43 01 5D ; |.!t.XS.].....C.]|
  0000:175D  db 02 5B EB                                        ; |.[.|
  0000:1760  db 46 3C 37 58                                     ; "F<7X"
  0000:1764  db 7F 41 81 3E 00 07 17                            ; |.A.>...|
  0000:176B  db 21 75 39 56 57 51 52                            ; "!u9VWQR"
  0000:1772  db 8B 76 00 83 C6 04 E8 2E 00 32 E4 B1 04 F6 E1 BF ; |.v.......2......|
  0000:1782  db 04 07 03 F8 B9 04 00 B8 00 00                   ; |..........|
  0000:178C  db 4E 4F 47 46                                     ; "NOGF"
  0000:1790  db 8A 15 0A 14 74 0D 8A 15 38 14 75 04 E2 F0 EB 03 ; |....t...8.u.....|
  0000:17A0  db B8 FF FF                                        ; |...|
  0000:17A3  db 5A 59 5F 5E                                     ; "ZY_^"
  0000:17A7  db 9D CB 55 83 EC 0B 8B EC 1E 1E 07 16 1F 8D 46 00 ; |..U...........F.|
  0000:17B7  db 55 50 8B EC B8 31 20 25 FF 0F 26 FF 1E F6 06 83 ; |UP...1 %..&.....|
  0000:17C7  db C4 02 5D 1F 8A 46 00 83 C4 0B 5D C3 00          ; |..]..F....]..|

; --- protocol_crtInit ---
; MSC CRT initialization
protocol_crtInit:  ; (sub_0000_17D4)
  0000:17D4  b430              mov      ah, 0x30
  0000:17D6  cd21              int      0x21  ; INT 21h/30h: Get DOS version
  0000:17D8  a37107            mov      word ptr [0x771], ax
  0000:17DB  b80035            mov      ax, 0x3500
  0000:17DE  cd21              int      0x21  ; INT 21h/35h: Get interrupt vector
  0000:17E0  891e5d07          mov      word ptr [0x75d], bx
  0000:17E4  8c065f07          mov      word ptr [0x75f], es
  0000:17E8  0e                push     cs
  0000:17E9  1f                pop      ds
  0000:17EA  b80025            mov      ax, 0x2500
  0000:17ED  ba9e00            mov      dx, 0x9e
  0000:17F0  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:17F2  16                push     ss
  0000:17F3  1f                pop      ds
  0000:17F4  8b0e3009          mov      cx, word ptr [0x930]
  0000:17F8  e32e              jcxz     0x1828  ; -> loc_0000_1828
  0000:17FA  8e066f07          mov      es, word ptr [0x76f]
  0000:17FE  268b362c00        mov      si, word ptr es:[0x2c]
  0000:1803  c5063209          lds      ax, ptr [0x932]
  0000:1807  8cda              mov      dx, ds
  0000:1809  33db              xor      bx, bx
  0000:180B  36ff1e2e09        lcall    ss:[0x92e]
  0000:1810  7305              jae      0x1817  ; -> loc_0000_1817
  0000:1812  16                push     ss
  0000:1813  1f                pop      ds
  0000:1814  e97704            jmp      0x1c8e  ; -> loc_0000_1C8E

loc_0000_1817:
  0000:1817  36c5063609        lds      ax, ptr ss:[0x936]
  0000:181C  8cda              mov      dx, ds
  0000:181E  bb0300            mov      bx, 3
  0000:1821  36ff1e2e09        lcall    ss:[0x92e]
  0000:1826  16                push     ss
  0000:1827  1f                pop      ds

loc_0000_1828:
  0000:1828  8e066f07          mov      es, word ptr [0x76f]
  0000:182C  268b0e2c00        mov      cx, word ptr es:[0x2c]
  0000:1831  e336              jcxz     0x1869  ; -> loc_0000_1869
  0000:1833  8ec1              mov      es, cx
  0000:1835  33ff              xor      di, di

loc_0000_1837:
  0000:1837  26803d00          cmp      byte ptr es:[di], 0
  0000:183B  742c              je       0x1869  ; -> loc_0000_1869
  0000:183D  b90c00            mov      cx, 0xc
  0000:1840  be5007            mov      si, 0x750
  0000:1843  f3a6              repe cmpsb byte ptr [si], byte ptr es:[di]
  0000:1845  740b              je       0x1852  ; -> loc_0000_1852
  0000:1847  b9ff7f            mov      cx, 0x7fff
  0000:184A  33c0              xor      ax, ax
  0000:184C  f2ae              repne scasb al, byte ptr es:[di]
  0000:184E  7519              jne      0x1869  ; -> loc_0000_1869
  0000:1850  ebe5              jmp      0x1837  ; -> loc_0000_1837

loc_0000_1852:
  0000:1852  06                push     es
  0000:1853  1e                push     ds
  0000:1854  07                pop      es
  0000:1855  1f                pop      ds
  0000:1856  8bf7              mov      si, di
  0000:1858  bf7807            mov      di, 0x778
  0000:185B  ac                lodsb    al, byte ptr [si]
  0000:185C  98                cwde
  0000:185D  91                xchg     cx, ax
  0000:185E  ac                lodsb    al, byte ptr [si]
  0000:185F  fec0              inc      al
  0000:1861  7401              je       0x1864  ; -> loc_0000_1864
  0000:1863  48                dec      ax

loc_0000_1864:
  0000:1864  aa                stosb    byte ptr es:[di], al
  0000:1865  e2f7              loop     0x185e
  0000:1867  16                push     ss
  0000:1868  1f                pop      ds

loc_0000_1869:
  0000:1869  bb0400            mov      bx, 4

loc_0000_186C:
  0000:186C  80a77807bf        and      byte ptr [bx + 0x778], 0xbf
  0000:1871  b80044            mov      ax, 0x4400
  0000:1874  cd21              int      0x21  ; INT 21h/44h: IOCTL
  0000:1876  720a              jb       0x1882  ; -> loc_0000_1882
  0000:1878  f6c280            test     dl, 0x80
  0000:187B  7405              je       0x1882  ; -> loc_0000_1882
  0000:187D  808f780740        or       byte ptr [bx + 0x778], 0x40

loc_0000_1882:
  0000:1882  4b                dec      bx
  0000:1883  79e7              jns      0x186c  ; -> loc_0000_186C
  0000:1885  be3a09            mov      si, 0x93a
  0000:1888  bf3a09            mov      di, 0x93a
  0000:188B  e8a200            call     0x1930  ; -> sub_0000_1930  ; protocol_getIntVector
  0000:188E  be3a09            mov      si, 0x93a
  0000:1891  bf3a09            mov      di, 0x93a
  0000:1894  e88a00            call     0x1921  ; -> sub_0000_1921  ; protocol_setIntVector
  0000:1897  c3                ret

; --- protocol_crtSetup ---
; MSC CRT data segment setup
protocol_crtSetup:  ; (sub_0000_1898)
  0000:1898  55                push     bp
  0000:1899  8bec              mov      bp, sp
  0000:189B  be220a            mov      si, 0xa22
  0000:189E  bf220a            mov      di, 0xa22
  0000:18A1  e87d00            call     0x1921  ; -> sub_0000_1921  ; protocol_setIntVector
  0000:18A4  be3a09            mov      si, 0x93a
  0000:18A7  bf3a09            mov      di, 0x93a
  0000:18AA  e87400            call     0x1921  ; -> sub_0000_1921  ; protocol_setIntVector
  0000:18AD  eb03              jmp      0x18b2  ; -> loc_0000_18B2
  0000:18AF  55                push     bp
  0000:18B0  8bec              mov      bp, sp

loc_0000_18B2:
  0000:18B2  be3a09            mov      si, 0x93a
  0000:18B5  bf3a09            mov      di, 0x93a
  0000:18B8  e86600            call     0x1921  ; -> sub_0000_1921  ; protocol_setIntVector
  0000:18BB  be3a09            mov      si, 0x93a
  0000:18BE  bf3a09            mov      di, 0x93a
  0000:18C1  e86c00            call     0x1930  ; -> sub_0000_1930  ; protocol_getIntVector
  0000:18C4  e89d00            call     0x1964  ; -> sub_0000_1964  ; protocol_exitCleanup
  0000:18C7  0bc0              or       ax, ax
  0000:18C9  740b              je       0x18d6  ; -> loc_0000_18D6
  0000:18CB  837e0400          cmp      word ptr [bp + 4], 0
  0000:18CF  7505              jne      0x18d6  ; -> loc_0000_18D6
  0000:18D1  c74604ff00        mov      word ptr [bp + 4], 0xff

loc_0000_18D6:
  0000:18D6  b90f00            mov      cx, 0xf
  0000:18D9  bb0500            mov      bx, 5
  0000:18DC  f687780701        test     byte ptr [bx + 0x778], 1
  0000:18E1  7404              je       0x18e7  ; -> loc_0000_18E7
  0000:18E3  b43e              mov      ah, 0x3e
  0000:18E5  cd21              int      0x21  ; INT 21h/3Eh: Close file

loc_0000_18E7:
  0000:18E7  43                inc      bx
  0000:18E8  e2f2              loop     0x18dc
  0000:18EA  e80700            call     0x18f4  ; -> sub_0000_18F4  ; protocol_crtCloseFiles
  0000:18ED  8b4604            mov      ax, word ptr [bp + 4]
  0000:18F0  b44c              mov      ah, 0x4c
  0000:18F2  cd21              int      0x21  ; INT 21h/4Ch: Exit with return code

; --- protocol_crtCloseFiles ---
; MSC CRT close open file handles
protocol_crtCloseFiles:  ; (sub_0000_18F4)
  0000:18F4  8b0e3009          mov      cx, word ptr [0x930]
  0000:18F8  e307              jcxz     0x1901  ; -> loc_0000_1901
  0000:18FA  bb0200            mov      bx, 2
  0000:18FD  ff1e2e09          lcall    [0x92e]

loc_0000_1901:
  0000:1901  1e                push     ds
  0000:1902  c5165d07          lds      dx, ptr [0x75d]
  0000:1906  b80025            mov      ax, 0x2500
  0000:1909  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:190B  1f                pop      ds
  0000:190C  803e9a0700        cmp      byte ptr [0x79a], 0
  0000:1911  740d              je       0x1920  ; -> loc_0000_1920
  0000:1913  1e                push     ds
  0000:1914  a09b07            mov      al, byte ptr [0x79b]
  0000:1917  c5169c07          lds      dx, ptr [0x79c]
  0000:191B  b425              mov      ah, 0x25
  0000:191D  cd21              int      0x21  ; INT 21h/25h: Set interrupt vector
  0000:191F  1f                pop      ds

loc_0000_1920:
  0000:1920  c3                ret

; --- protocol_setIntVector ---
; Set interrupt vector (INT 21h/25h, 4 callers)
protocol_setIntVector:  ; (sub_0000_1921)
  0000:1921  3bf7              cmp      si, di
  0000:1923  730a              jae      0x192f  ; -> loc_0000_192F
  0000:1925  4f                dec      di
  0000:1926  4f                dec      di
  0000:1927  8b0d              mov      cx, word ptr [di]
  0000:1929  e3f6              jcxz     0x1921  ; -> sub_0000_1921
  0000:192B  ffd1              call     cx
  0000:192D  ebf2              jmp      0x1921  ; -> sub_0000_1921  ; protocol_setIntVector

loc_0000_192F:
  0000:192F  c3                ret

; --- protocol_getIntVector ---
; Get interrupt vector (INT 21h/35h, 2 callers)
protocol_getIntVector:  ; (sub_0000_1930)
  0000:1930  3bf7              cmp      si, di
  0000:1932  730e              jae      0x1942  ; -> loc_0000_1942
  0000:1934  83ef04            sub      di, 4
  0000:1937  8b05              mov      ax, word ptr [di]
  0000:1939  0b4502            or       ax, word ptr [di + 2]
  0000:193C  74f2              je       0x1930  ; -> sub_0000_1930
  0000:193E  ff1d              lcall    [di]
  0000:1940  ebee              jmp      0x1930  ; -> sub_0000_1930  ; protocol_getIntVector

loc_0000_1942:
  0000:1942  c3                ret
  0000:1943  db 00                                              ; |.|

; --- protocol_resizeMemory ---
; Resize memory block (INT 21h/4Ah, 3 callers)
protocol_resizeMemory:  ; (sub_0000_1944)
  0000:1944  55                push     bp
  0000:1945  8bec              mov      bp, sp
  0000:1947  b8fc00            mov      ax, 0xfc
  0000:194A  50                push     ax
  0000:194B  e85f02            call     0x1bad  ; -> sub_0000_1BAD  ; protocol_allocMemory
  0000:194E  833ea00700        cmp      word ptr [0x7a0], 0
  0000:1953  7404              je       0x1959  ; -> loc_0000_1959
  0000:1955  ff16a007          call     word ptr [0x7a0]

loc_0000_1959:
  0000:1959  b8ff00            mov      ax, 0xff
  0000:195C  50                push     ax
  0000:195D  e84d02            call     0x1bad  ; -> sub_0000_1BAD  ; protocol_allocMemory
  0000:1960  8be5              mov      sp, bp
  0000:1962  5d                pop      bp
  0000:1963  c3                ret

; --- protocol_exitCleanup ---
; Exit cleanup and terminate
protocol_exitCleanup:  ; (sub_0000_1964)
  0000:1964  56                push     si
  0000:1965  33f6              xor      si, si
  0000:1967  b94200            mov      cx, 0x42
  0000:196A  32e4              xor      ah, ah
  0000:196C  fc                cld
  0000:196D  ac                lodsb    al, byte ptr [si]
  0000:196E  32e0              xor      ah, al
  0000:1970  e2fb              loop     0x196d
  0000:1972  80f455            xor      ah, 0x55
  0000:1975  740d              je       0x1984  ; -> loc_0000_1984
  0000:1977  e8caff            call     0x1944  ; -> sub_0000_1944  ; protocol_resizeMemory
  0000:197A  b80100            mov      ax, 1
  0000:197D  50                push     ax
  0000:197E  e82c02            call     0x1bad  ; -> sub_0000_1BAD  ; protocol_allocMemory
  0000:1981  b80100            mov      ax, 1

loc_0000_1984:
  0000:1984  5e                pop      si
  0000:1985  c3                ret
  0000:1986  db 8F 06 A2 07 BA 02 00 38 16 71 07 74 29 8E 06 6F ; |.......8.q.t)..o|
  0000:1996  db 07 26 8E 06 2C 00 8C 06 94 07 33 C0 99 B9 00 80 ; |.&..,.....3.....|
  0000:19A6  db 33 FF F2 AE AE 75 FB 47 47 89 3E 92 07 B9 FF FF ; |3....u.GG.>.....|
  0000:19B6  db F2 AE F7 D1 8B D1 BF 01 00 BE 81 00 8E 1E 6F 07 ; |..............o.|
  0000:19C6  db AC 3C 20 74 FB 3C 09 74 F7                      ; |.< t.<.t.|
  0000:19CF  db 3C 0D 74 6F 0A                                  ; "<\rto\n"
  0000:19D4  db C0                                              ; |.|
  0000:19D5  db 74 6B 47 4E                                     ; "tkGN"
  0000:19D9  db AC 3C 20 74 E8 3C 09 74 E4                      ; |.< t.<.t.|
  0000:19E2  db 3C 0D 74 5C 0A                                  ; "<\rt\\n"
  0000:19E7  db C0                                              ; |.|
  0000:19E8  db 74 58 3C 22 74 24 3C 5C 74                      ; "tX<"t$<\t"
  0000:19F1  db 03 42 EB E4 33 C9 41 AC 3C 5C 74 FA 3C 22 74 04 ; |.B..3.A.<\t.<"t.|
  0000:1A01  db 03 D1 EB D3 8B C1 D1 E9 13 D1 A8 01 75 CA EB 01 ; |............u...|
  0000:1A11  db 4E AC                                           ; |N.|
  0000:1A13  db 3C 0D 74 2B 0A                                  ; "<\rt+\n"
  0000:1A18  db C0                                              ; |.|
  0000:1A19  db 74 27 3C 22 74                                  ; "t'<"t"
  0000:1A1E  db BA 3C 5C 74 03 42 EB EC 33 C9 41 AC 3C 5C 74 FA ; |.<\t.B..3.A.<\t.|
  0000:1A2E  db 3C 22 74 04 03 D1 EB DB 8B C1 D1 E9 13 D1 A8 01 ; |<"t.............|
  0000:1A3E  db 75 D2 EB 97 16 1F 89 3E 8C 07 03 D7 47 D1 E7 03 ; |u......>....G...|
  0000:1A4E  db D7 80 E2 FE 2B E2 8B C4 A3 8E 07 8B D8 03 FB 16 ; |....+...........|
  0000:1A5E  db 07 36 89 3F 43 43 C5 36 92 07 AC AA 0A C0 75 FA ; |.6.?CC.6......u.|
  0000:1A6E  db BE 81 00 36 8E 1E 6F 07 EB 03 33 C0 AA AC 3C 20 ; |...6..o...3...< |
  0000:1A7E  db 74 FB 3C 09 74 F7 3C 0D 75 03 E9 7F 00 0A C0 75 ; |t.<.t.<.u......u|
  0000:1A8E  db 03 EB 79 90 36 89                               ; |..y.6.|
  0000:1A94  db 3F 43 43 4E                                     ; "?CCN"
  0000:1A98  db AC 3C 20 74 DB 3C 09 74 D7                      ; |.< t.<.t.|
  0000:1AA1  db 3C 0D 74 62 0A                                  ; "<\rtb\n"
  0000:1AA6  db C0                                              ; |.|
  0000:1AA7  db 74 5E 3C 22 74 27 3C 5C 74                      ; "t^<"t'<\t"
  0000:1AB0  db 03 AA EB E4 33 C9 41 AC 3C 5C 74 FA 3C 22 74 06 ; |....3.A.<\t.<"t.|
  0000:1AC0  db B0 5C F3 AA EB D1 B0 5C D1 E9 F3 AA 73 06 B0 22 ; |.\.....\....s.."|
  0000:1AD0  db AA EB C5 4E AC                                  ; |...N.|
  0000:1AD5  db 3C 0D 74 2E 0A                                  ; "<\rt.\n"
  0000:1ADA  db C0                                              ; |.|
  0000:1ADB  db 74 2A 3C 22 74                                  ; "t*<"t"
  0000:1AE0  db B7 3C 5C 74 03 AA EB EC 33 C9 41 AC 3C 5C 74 FA ; |.<\t....3.A.<\t.|
  0000:1AF0  db 3C 22 74 06 B0 5C F3 AA EB D9 B0 5C D1 E9 F3 AA ; |<"t..\.....\....|
  0000:1B00  db 73 96 B0 22 AA EB CD 33 C0 AA 16 1F C7 07 00 00 ; |s.."...3........|
  0000:1B10  db FF 26 A2 07                                     ; |.&..|
  0000:1B14  55                push     bp
  0000:1B15  8bec              mov      bp, sp
  0000:1B17  55                push     bp
  0000:1B18  8e1e6f07          mov      ds, word ptr [0x76f]
  0000:1B1C  33c9              xor      cx, cx
  0000:1B1E  8bc1              mov      ax, cx
  0000:1B20  8be9              mov      bp, cx
  0000:1B22  8bf9              mov      di, cx
  0000:1B24  49                dec      cx
  0000:1B25  8b362c00          mov      si, word ptr [0x2c]
  0000:1B29  0bf6              or       si, si
  0000:1B2B  7410              je       0x1b3d  ; -> loc_0000_1B3D
  0000:1B2D  8ec6              mov      es, si
  0000:1B2F  26803e000000      cmp      byte ptr es:[0], 0
  0000:1B35  7406              je       0x1b3d  ; -> loc_0000_1B3D

loc_0000_1B37:
  0000:1B37  f2ae              repne scasb al, byte ptr es:[di]
  0000:1B39  45                inc      bp
  0000:1B3A  ae                scasb    al, byte ptr es:[di]
  0000:1B3B  75fa              jne      0x1b37  ; -> loc_0000_1B37

loc_0000_1B3D:
  0000:1B3D  45                inc      bp
  0000:1B3E  97                xchg     di, ax
  0000:1B3F  40                inc      ax
  0000:1B40  24fe              and      al, 0xfe
  0000:1B42  8bfd              mov      di, bp
  0000:1B44  d1e5              shl      bp, 1
  0000:1B46  03c5              add      ax, bp
  0000:1B48  16                push     ss
  0000:1B49  1f                pop      ds
  0000:1B4A  57                push     di
  0000:1B4B  bf0900            mov      di, 9
  0000:1B4E  e84301            call     0x1c94  ; -> sub_0000_1C94  ; protocol_terminateResident
  0000:1B51  5f                pop      di
  0000:1B52  8bcf              mov      cx, di
  0000:1B54  8bfd              mov      di, bp
  0000:1B56  03f8              add      di, ax
  0000:1B58  892e9007          mov      word ptr [0x790], bp
  0000:1B5C  1e                push     ds
  0000:1B5D  07                pop      es
  0000:1B5E  8ede              mov      ds, si
  0000:1B60  33f6              xor      si, si
  0000:1B62  49                dec      cx
  0000:1B63  e313              jcxz     0x1b78  ; -> loc_0000_1B78
  0000:1B65  813c3b43          cmp      word ptr [si], 0x433b
  0000:1B69  7405              je       0x1b70  ; -> loc_0000_1B70
  0000:1B6B  897e00            mov      word ptr [bp], di
  0000:1B6E  45                inc      bp
  0000:1B6F  45                inc      bp

loc_0000_1B70:
  0000:1B70  ac                lodsb    al, byte ptr [si]
  0000:1B71  aa                stosb    byte ptr es:[di], al
  0000:1B72  0ac0              or       al, al
  0000:1B74  75fa              jne      0x1b70  ; -> loc_0000_1B70
  0000:1B76  e2ed              loop     0x1b65

loc_0000_1B78:
  0000:1B78  894e00            mov      word ptr [bp], cx
  0000:1B7B  16                push     ss
  0000:1B7C  1f                pop      ds
  0000:1B7D  5d                pop      bp
  0000:1B7E  8be5              mov      sp, bp
  0000:1B80  5d                pop      bp
  0000:1B81  c3                ret

; --- protocol_heapTop ---
; Get/update heap top pointer
protocol_heapTop:  ; (sub_0000_1B82)
  0000:1B82  55                push     bp
  0000:1B83  8bec              mov      bp, sp
  0000:1B85  56                push     si
  0000:1B86  57                push     di
  0000:1B87  1e                push     ds
  0000:1B88  07                pop      es
  0000:1B89  8b5604            mov      dx, word ptr [bp + 4]
  0000:1B8C  be4209            mov      si, 0x942

loc_0000_1B8F:
  0000:1B8F  ad                lodsw    ax, word ptr [si]
  0000:1B90  3bc2              cmp      ax, dx
  0000:1B92  7410              je       0x1ba4  ; -> loc_0000_1BA4
  0000:1B94  40                inc      ax
  0000:1B95  96                xchg     si, ax
  0000:1B96  740c              je       0x1ba4  ; -> loc_0000_1BA4
  0000:1B98  97                xchg     di, ax
  0000:1B99  33c0              xor      ax, ax
  0000:1B9B  b9ffff            mov      cx, 0xffff
  0000:1B9E  f2ae              repne scasb al, byte ptr es:[di]
  0000:1BA0  8bf7              mov      si, di
  0000:1BA2  ebeb              jmp      0x1b8f  ; -> loc_0000_1B8F

loc_0000_1BA4:
  0000:1BA4  96                xchg     si, ax
  0000:1BA5  5f                pop      di
  0000:1BA6  5e                pop      si
  0000:1BA7  8be5              mov      sp, bp
  0000:1BA9  5d                pop      bp
  0000:1BAA  c20200            ret      2

; --- protocol_allocMemory ---
; Allocate memory from heap (5 callers)
protocol_allocMemory:  ; (sub_0000_1BAD)
  0000:1BAD  55                push     bp
  0000:1BAE  8bec              mov      bp, sp
  0000:1BB0  57                push     di
  0000:1BB1  ff7604            push     word ptr [bp + 4]
  0000:1BB4  e8cbff            call     0x1b82  ; -> sub_0000_1B82  ; protocol_heapTop
  0000:1BB7  0bc0              or       ax, ax
  0000:1BB9  7414              je       0x1bcf  ; -> loc_0000_1BCF
  0000:1BBB  92                xchg     dx, ax
  0000:1BBC  8bfa              mov      di, dx
  0000:1BBE  33c0              xor      ax, ax
  0000:1BC0  b9ffff            mov      cx, 0xffff
  0000:1BC3  f2ae              repne scasb al, byte ptr es:[di]
  0000:1BC5  f7d1              not      cx
  0000:1BC7  49                dec      cx
  0000:1BC8  bb0200            mov      bx, 2
  0000:1BCB  b440              mov      ah, 0x40
  0000:1BCD  cd21              int      0x21  ; INT 21h/40h: Write file

loc_0000_1BCF:
  0000:1BCF  5f                pop      di
  0000:1BD0  8be5              mov      sp, bp
  0000:1BD2  5d                pop      bp
  0000:1BD3  c20200            ret      2

; --- protocol_formatTransferStr ---
; Format transfer statistics string (3 callers)
protocol_formatTransferStr:  ; (sub_0000_1BD6)
  0000:1BD6  55                push     bp
  0000:1BD7  8bec              mov      bp, sp
  0000:1BD9  56                push     si
  0000:1BDA  b42a              mov      ah, 0x2a
  0000:1BDC  cd21              int      0x21  ; INT 21h/2Ah: Get date
  0000:1BDE  8bda              mov      bx, dx
  0000:1BE0  8bf1              mov      si, cx
  0000:1BE2  b42c              mov      ah, 0x2c
  0000:1BE4  cd21              int      0x21  ; INT 21h/2Ch: Get time
  0000:1BE6  b400              mov      ah, 0
  0000:1BE8  8ac6              mov      al, dh
  0000:1BEA  50                push     ax
  0000:1BEB  8ac1              mov      al, cl
  0000:1BED  50                push     ax
  0000:1BEE  8ac5              mov      al, ch
  0000:1BF0  50                push     ax
  0000:1BF1  50                push     ax
  0000:1BF2  b42a              mov      ah, 0x2a
  0000:1BF4  cd21              int      0x21  ; INT 21h/2Ah: Get date
  0000:1BF6  3bda              cmp      bx, dx
  0000:1BF8  58                pop      ax
  0000:1BF9  7408              je       0x1c03  ; -> loc_0000_1C03
  0000:1BFB  3c17              cmp      al, 0x17
  0000:1BFD  7504              jne      0x1c03  ; -> loc_0000_1C03
  0000:1BFF  8bd3              mov      dx, bx
  0000:1C01  8bce              mov      cx, si

loc_0000_1C03:
  0000:1C03  b400              mov      ah, 0
  0000:1C05  8ac2              mov      al, dl
  0000:1C07  50                push     ax
  0000:1C08  8ac6              mov      al, dh
  0000:1C0A  50                push     ax
  0000:1C0B  81e9bc07          sub      cx, 0x7bc
  0000:1C0F  51                push     cx
  0000:1C10  e8c300            call     0x1cd6  ; -> sub_0000_1CD6  ; protocol_printf
  0000:1C13  83c40c            add      sp, 0xc
  0000:1C16  837e0400          cmp      word ptr [bp + 4], 0
  0000:1C1A  7408              je       0x1c24  ; -> loc_0000_1C24
  0000:1C1C  8b5e04            mov      bx, word ptr [bp + 4]
  0000:1C1F  895702            mov      word ptr [bx + 2], dx
  0000:1C22  8907              mov      word ptr [bx], ax

loc_0000_1C24:
  0000:1C24  5e                pop      si
  0000:1C25  5d                pop      bp
  0000:1C26  c3                ret
  0000:1C27  db 00                                              ; |.|

; --- protocol_packetHeader ---
; Build packet header bytes (2 callers)
protocol_packetHeader:  ; (sub_0000_1C28)
  0000:1C28  55                push     bp
  0000:1C29  8bec              mov      bp, sp
  0000:1C2B  8bd7              mov      dx, di
  0000:1C2D  8bde              mov      bx, si
  0000:1C2F  8cd8              mov      ax, ds
  0000:1C31  8ec0              mov      es, ax
  0000:1C33  8b7606            mov      si, word ptr [bp + 6]
  0000:1C36  8b7e04            mov      di, word ptr [bp + 4]
  0000:1C39  8bc7              mov      ax, di
  0000:1C3B  8b4e08            mov      cx, word ptr [bp + 8]
  0000:1C3E  e30e              jcxz     0x1c4e  ; -> loc_0000_1C4E
  0000:1C40  a801              test     al, 1
  0000:1C42  7402              je       0x1c46  ; -> loc_0000_1C46
  0000:1C44  a4                movsb    byte ptr es:[di], byte ptr [si]
  0000:1C45  49                dec      cx

loc_0000_1C46:
  0000:1C46  d1e9              shr      cx, 1
  0000:1C48  f3a5              rep movsw word ptr es:[di], word ptr [si]
  0000:1C4A  13c9              adc      cx, cx
  0000:1C4C  f3a4              rep movsb byte ptr es:[di], byte ptr [si]

loc_0000_1C4E:
  0000:1C4E  8bf3              mov      si, bx
  0000:1C50  8bfa              mov      di, dx
  0000:1C52  5d                pop      bp
  0000:1C53  c3                ret

; --- protocol_crcTable ---
; CRC-16 table lookup (2 callers)
protocol_crcTable:  ; (sub_0000_1C54)
  0000:1C54  55                push     bp
  0000:1C55  8bec              mov      bp, sp
  0000:1C57  8b4604            mov      ax, word ptr [bp + 4]
  0000:1C5A  0bc0              or       ax, ax
  0000:1C5C  750e              jne      0x1c6c  ; -> loc_0000_1C6C
  0000:1C5E  cd1a              int      0x1a  ; INT 1Ah
  0000:1C60  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1C63  8917              mov      word ptr [bx], dx
  0000:1C65  894f02            mov      word ptr [bx + 2], cx
  0000:1C68  b400              mov      ah, 0
  0000:1C6A  eb14              jmp      0x1c80  ; -> loc_0000_1C80

loc_0000_1C6C:
  0000:1C6C  48                dec      ax
  0000:1C6D  b8ffff            mov      ax, 0xffff
  0000:1C70  750e              jne      0x1c80  ; -> loc_0000_1C80
  0000:1C72  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1C75  8b17              mov      dx, word ptr [bx]
  0000:1C77  8b4f02            mov      cx, word ptr [bx + 2]
  0000:1C7A  b401              mov      ah, 1
  0000:1C7C  cd1a              int      0x1a  ; INT 1Ah, AH=01h
  0000:1C7E  33c0              xor      ax, ax

loc_0000_1C80:
  0000:1C80  5d                pop      bp
  0000:1C81  c3                ret

; --- protocol_packetChecksum ---
; Compute and append packet checksum/CRC
protocol_packetChecksum:  ; (sub_0000_1C82)
  0000:1C82  32ed              xor      ch, ch
  0000:1C84  e306              jcxz     0x1c8c  ; -> loc_0000_1C8C
  0000:1C86  d1e0              shl      ax, 1
  0000:1C88  d1d2              rcl      dx, 1
  0000:1C8A  e2fa              loop     0x1c86

loc_0000_1C8C:
  0000:1C8C  c3                ret
  0000:1C8D  db 00                                              ; |.|

loc_0000_1C8E:
  0000:1C8E  b80200            mov      ax, 2
  0000:1C91  e919e4            jmp      0xad  ; -> loc_0000_00AD

; --- protocol_terminateResident ---
; TSR exit via INT 21h/31h
protocol_terminateResident:  ; (sub_0000_1C94)
  0000:1C94  8bd0              mov      dx, ax
  0000:1C96  03064800          add      ax, word ptr [0x48]
  0000:1C9A  7235              jb       0x1cd1  ; -> loc_0000_1CD1
  0000:1C9C  39064200          cmp      word ptr [0x42], ax
  0000:1CA0  7325              jae      0x1cc7  ; -> loc_0000_1CC7
  0000:1CA2  050f00            add      ax, 0xf
  0000:1CA5  50                push     ax
  0000:1CA6  d1d8              rcr      ax, 1
  0000:1CA8  b103              mov      cl, 3
  0000:1CAA  d3e8              shr      ax, cl
  0000:1CAC  8cd9              mov      cx, ds
  0000:1CAE  8b1e6f07          mov      bx, word ptr [0x76f]
  0000:1CB2  2bcb              sub      cx, bx
  0000:1CB4  03c1              add      ax, cx
  0000:1CB6  8ec3              mov      es, bx
  0000:1CB8  8bd8              mov      bx, ax
  0000:1CBA  b44a              mov      ah, 0x4a
  0000:1CBC  cd21              int      0x21  ; INT 21h/4Ah: Resize memory block
  0000:1CBE  58                pop      ax
  0000:1CBF  7210              jb       0x1cd1  ; -> loc_0000_1CD1
  0000:1CC1  24f0              and      al, 0xf0
  0000:1CC3  48                dec      ax
  0000:1CC4  a34200            mov      word ptr [0x42], ax

loc_0000_1CC7:
  0000:1CC7  95                xchg     bp, ax
  0000:1CC8  8b2e4800          mov      bp, word ptr [0x48]
  0000:1CCC  01164800          add      word ptr [0x48], dx
  0000:1CD0  c3                ret

loc_0000_1CD1:
  0000:1CD1  8bc7              mov      ax, di
  0000:1CD3  e9d7e3            jmp      0xad  ; -> loc_0000_00AD

; --- protocol_printf ---
; Formatted output (printf-like)
protocol_printf:  ; (sub_0000_1CD6)
  0000:1CD6  55                push     bp
  0000:1CD7  8bec              mov      bp, sp
  0000:1CD9  83ec20            sub      sp, 0x20
  0000:1CDC  57                push     di
  0000:1CDD  56                push     si
  0000:1CDE  8b7604            mov      si, word ptr [bp + 4]
  0000:1CE1  b88051            mov      ax, 0x5180
  0000:1CE4  ba0100            mov      dx, 1
  0000:1CE7  52                push     dx
  0000:1CE8  50                push     ax
  0000:1CE9  8d4403            lea      ax, [si + 3]
  0000:1CEC  99                cdq
  0000:1CED  33c2              xor      ax, dx
  0000:1CEF  2bc2              sub      ax, dx
  0000:1CF1  b90200            mov      cx, 2
  0000:1CF4  d3f8              sar      ax, cl
  0000:1CF6  33c2              xor      ax, dx
  0000:1CF8  2bc2              sub      ax, dx
  0000:1CFA  99                cdq
  0000:1CFB  52                push     dx
  0000:1CFC  50                push     ax
  0000:1CFD  e87602            call     0x1f76  ; -> sub_0000_1F76  ; protocol_putChar
  0000:1D00  8946ea            mov      word ptr [bp - 0x16], ax
  0000:1D03  8956ec            mov      word ptr [bp - 0x14], dx
  0000:1D06  8b5e06            mov      bx, word ptr [bp + 6]
  0000:1D09  d1e3              shl      bx, 1
  0000:1D0B  8bbfbc07          mov      di, word ptr [bx + 0x7bc]
  0000:1D0F  8bc6              mov      ax, si
  0000:1D11  99                cdq
  0000:1D12  b90400            mov      cx, 4
  0000:1D15  f7f9              idiv     cx
  0000:1D17  0bd2              or       dx, dx
  0000:1D19  7507              jne      0x1d22  ; -> loc_0000_1D22
  0000:1D1B  837e0602          cmp      word ptr [bp + 6], 2
  0000:1D1F  7e01              jle      0x1d22  ; -> loc_0000_1D22
  0000:1D21  47                inc      di

loc_0000_1D22:
  0000:1D22  b83c00            mov      ax, 0x3c
  0000:1D25  99                cdq
  0000:1D26  52                push     dx
  0000:1D27  50                push     ax
  0000:1D28  8b460c            mov      ax, word ptr [bp + 0xc]
  0000:1D2B  99                cdq
  0000:1D2C  52                push     dx
  0000:1D2D  50                push     ax
  0000:1D2E  e84502            call     0x1f76  ; -> sub_0000_1F76  ; protocol_putChar
  0000:1D31  b9100e            mov      cx, 0xe10
  0000:1D34  2bdb              sub      bx, bx
  0000:1D36  53                push     bx
  0000:1D37  51                push     cx
  0000:1D38  8bc8              mov      cx, ax
  0000:1D3A  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:1D3D  8bda              mov      bx, dx
  0000:1D3F  99                cdq
  0000:1D40  52                push     dx
  0000:1D41  50                push     ax
  0000:1D42  894ee4            mov      word ptr [bp - 0x1c], cx
  0000:1D45  895ee6            mov      word ptr [bp - 0x1a], bx
  0000:1D48  e82b02            call     0x1f76  ; -> sub_0000_1F76  ; protocol_putChar
  0000:1D4B  b98051            mov      cx, 0x5180
  0000:1D4E  bb0100            mov      bx, 1
  0000:1D51  53                push     bx
  0000:1D52  51                push     cx
  0000:1D53  8bc8              mov      cx, ax
  0000:1D55  b86d01            mov      ax, 0x16d
  0000:1D58  8bda              mov      bx, dx
  0000:1D5A  f7ee              imul     si
  0000:1D5C  8bd0              mov      dx, ax
  0000:1D5E  8b4608            mov      ax, word ptr [bp + 8]
  0000:1D61  03c2              add      ax, dx
  0000:1D63  03c7              add      ax, di
  0000:1D65  99                cdq
  0000:1D66  52                push     dx
  0000:1D67  50                push     ax
  0000:1D68  894ee0            mov      word ptr [bp - 0x20], cx
  0000:1D6B  895ee2            mov      word ptr [bp - 0x1e], bx
  0000:1D6E  e80502            call     0x1f76  ; -> sub_0000_1F76  ; protocol_putChar
  0000:1D71  0346e0            add      ax, word ptr [bp - 0x20]
  0000:1D74  1356e2            adc      dx, word ptr [bp - 0x1e]
  0000:1D77  0346e4            add      ax, word ptr [bp - 0x1c]
  0000:1D7A  1356e6            adc      dx, word ptr [bp - 0x1a]
  0000:1D7D  8bc8              mov      cx, ax
  0000:1D7F  8b460e            mov      ax, word ptr [bp + 0xe]
  0000:1D82  8bda              mov      bx, dx
  0000:1D84  99                cdq
  0000:1D85  03c8              add      cx, ax
  0000:1D87  13da              adc      bx, dx
  0000:1D89  81c100a6          add      cx, 0xa600
  0000:1D8D  81d3ce12          adc      bx, 0x12ce
  0000:1D91  014eea            add      word ptr [bp - 0x16], cx
  0000:1D94  115eec            adc      word ptr [bp - 0x14], bx
  0000:1D97  8b4608            mov      ax, word ptr [bp + 8]
  0000:1D9A  03c7              add      ax, di
  0000:1D9C  8946fc            mov      word ptr [bp - 4], ax
  0000:1D9F  e84a00            call     0x1dec  ; -> sub_0000_1DEC  ; protocol_flushOutput
  0000:1DA2  a1e407            mov      ax, word ptr [0x7e4]
  0000:1DA5  8b16e607          mov      dx, word ptr [0x7e6]
  0000:1DA9  0146ea            add      word ptr [bp - 0x16], ax
  0000:1DAC  1156ec            adc      word ptr [bp - 0x14], dx
  0000:1DAF  8d4450            lea      ax, [si + 0x50]
  0000:1DB2  8946f8            mov      word ptr [bp - 8], ax
  0000:1DB5  8b4606            mov      ax, word ptr [bp + 6]
  0000:1DB8  48                dec      ax
  0000:1DB9  8946f6            mov      word ptr [bp - 0xa], ax
  0000:1DBC  8b460a            mov      ax, word ptr [bp + 0xa]
  0000:1DBF  8946f2            mov      word ptr [bp - 0xe], ax
  0000:1DC2  833ee80700        cmp      word ptr [0x7e8], 0
  0000:1DC7  7417              je       0x1de0  ; -> loc_0000_1DE0
  0000:1DC9  8d46ee            lea      ax, [bp - 0x12]
  0000:1DCC  50                push     ax
  0000:1DCD  e8dc00            call     0x1eac  ; -> sub_0000_1EAC  ; protocol_seekStream
  0000:1DD0  83c402            add      sp, 2
  0000:1DD3  0bc0              or       ax, ax
  0000:1DD5  7409              je       0x1de0  ; -> loc_0000_1DE0
  0000:1DD7  816eea100e        sub      word ptr [bp - 0x16], 0xe10
  0000:1DDC  835eec00          sbb      word ptr [bp - 0x14], 0

loc_0000_1DE0:
  0000:1DE0  8b46ea            mov      ax, word ptr [bp - 0x16]
  0000:1DE3  8b56ec            mov      dx, word ptr [bp - 0x14]
  0000:1DE6  5e                pop      si
  0000:1DE7  5f                pop      di
  0000:1DE8  8be5              mov      sp, bp
  0000:1DEA  5d                pop      bp
  0000:1DEB  c3                ret

; --- protocol_flushOutput ---
; Flush output stream buffer
protocol_flushOutput:  ; (sub_0000_1DEC)
  0000:1DEC  833e200a00        cmp      word ptr [0xa20], 0
  0000:1DF1  7507              jne      0x1dfa  ; -> loc_0000_1DFA
  0000:1DF3  e80600            call     0x1dfc  ; -> sub_0000_1DFC  ; protocol_writeOutput
  0000:1DF6  ff06200a          inc      word ptr [0xa20]

loc_0000_1DFA:
  0000:1DFA  c3                ret
  0000:1DFB  db 90                                              ; |.|

; --- protocol_writeOutput ---
; Write formatted output to file/device
protocol_writeOutput:  ; (sub_0000_1DFC)
  0000:1DFC  55                push     bp
  0000:1DFD  8bec              mov      bp, sp
  0000:1DFF  83ec04            sub      sp, 4
  0000:1E02  57                push     di
  0000:1E03  56                push     si
  0000:1E04  b8d807            mov      ax, 0x7d8
  0000:1E07  50                push     ax
  0000:1E08  e8cb01            call     0x1fd6  ; -> sub_0000_1FD6  ; protocol_formatNumber
  0000:1E0B  83c402            add      sp, 2
  0000:1E0E  8bf0              mov      si, ax
  0000:1E10  0bf6              or       si, si
  0000:1E12  7503              jne      0x1e17  ; -> loc_0000_1E17
  0000:1E14  e98f00            jmp      0x1ea6  ; -> loc_0000_1EA6

loc_0000_1E17:
  0000:1E17  803c00            cmp      byte ptr [si], 0
  0000:1E1A  7503              jne      0x1e1f  ; -> loc_0000_1E1F
  0000:1E1C  e98700            jmp      0x1ea6  ; -> loc_0000_1EA6

loc_0000_1E1F:
  0000:1E1F  b80300            mov      ax, 3
  0000:1E22  50                push     ax
  0000:1E23  56                push     si
  0000:1E24  ff36ea07          push     word ptr [0x7ea]
  0000:1E28  e87f01            call     0x1faa  ; -> sub_0000_1FAA  ; protocol_writeString
  0000:1E2B  83c406            add      sp, 6
  0000:1E2E  b8100e            mov      ax, 0xe10
  0000:1E31  99                cdq
  0000:1E32  52                push     dx
  0000:1E33  50                push     ax
  0000:1E34  83c603            add      si, 3
  0000:1E37  56                push     si
  0000:1E38  e89701            call     0x1fd2  ; -> sub_0000_1FD2  ; protocol_writeNewline
  0000:1E3B  83c402            add      sp, 2
  0000:1E3E  52                push     dx
  0000:1E3F  50                push     ax
  0000:1E40  e83301            call     0x1f76  ; -> sub_0000_1F76  ; protocol_putChar
  0000:1E43  a3e407            mov      word ptr [0x7e4], ax
  0000:1E46  8916e607          mov      word ptr [0x7e6], dx
  0000:1E4A  2bff              sub      di, di

loc_0000_1E4C:
  0000:1E4C  8bdf              mov      bx, di
  0000:1E4E  03de              add      bx, si
  0000:1E50  803f00            cmp      byte ptr [bx], 0
  0000:1E53  741f              je       0x1e74  ; -> loc_0000_1E74
  0000:1E55  8bdf              mov      bx, di
  0000:1E57  03de              add      bx, si
  0000:1E59  8a07              mov      al, byte ptr [bx]
  0000:1E5B  98                cwde
  0000:1E5C  8bd8              mov      bx, ax
  0000:1E5E  f6872b0804        test     byte ptr [bx + 0x82b], 4
  0000:1E63  7509              jne      0x1e6e  ; -> loc_0000_1E6E
  0000:1E65  8bdf              mov      bx, di
  0000:1E67  03de              add      bx, si
  0000:1E69  803f2d            cmp      byte ptr [bx], 0x2d
  0000:1E6C  7506              jne      0x1e74  ; -> loc_0000_1E74

loc_0000_1E6E:
  0000:1E6E  47                inc      di
  0000:1E6F  83ff03            cmp      di, 3
  0000:1E72  7cd8              jl       0x1e4c  ; -> loc_0000_1E4C

loc_0000_1E74:
  0000:1E74  8bdf              mov      bx, di
  0000:1E76  03de              add      bx, si
  0000:1E78  803f00            cmp      byte ptr [bx], 0
  0000:1E7B  7415              je       0x1e92  ; -> loc_0000_1E92
  0000:1E7D  b80300            mov      ax, 3
  0000:1E80  50                push     ax
  0000:1E81  8bc7              mov      ax, di
  0000:1E83  03c6              add      ax, si
  0000:1E85  50                push     ax
  0000:1E86  ff36ec07          push     word ptr [0x7ec]
  0000:1E8A  e81d01            call     0x1faa  ; -> sub_0000_1FAA  ; protocol_writeString
  0000:1E8D  83c406            add      sp, 6
  0000:1E90  eb07              jmp      0x1e99  ; -> loc_0000_1E99

loc_0000_1E92:
  0000:1E92  8b1eec07          mov      bx, word ptr [0x7ec]
  0000:1E96  c60700            mov      byte ptr [bx], 0

loc_0000_1E99:
  0000:1E99  8b1eec07          mov      bx, word ptr [0x7ec]
  0000:1E9D  803f01            cmp      byte ptr [bx], 1
  0000:1EA0  1bc0              sbb      ax, ax
  0000:1EA2  40                inc      ax
  0000:1EA3  a3e807            mov      word ptr [0x7e8], ax

loc_0000_1EA6:
  0000:1EA6  5e                pop      si
  0000:1EA7  5f                pop      di
  0000:1EA8  8be5              mov      sp, bp
  0000:1EAA  5d                pop      bp
  0000:1EAB  c3                ret

; --- protocol_seekStream ---
; Seek stream position
protocol_seekStream:  ; (sub_0000_1EAC)
  0000:1EAC  55                push     bp
  0000:1EAD  8bec              mov      bp, sp
  0000:1EAF  83ec06            sub      sp, 6
  0000:1EB2  57                push     di
  0000:1EB3  56                push     si
  0000:1EB4  8b7604            mov      si, word ptr [bp + 4]
  0000:1EB7  837c0803          cmp      word ptr [si + 8], 3
  0000:1EBB  7d03              jge      0x1ec0  ; -> loc_0000_1EC0
  0000:1EBD  e9ae00            jmp      0x1f6e  ; -> loc_0000_1F6E

loc_0000_1EC0:
  0000:1EC0  837c0809          cmp      word ptr [si + 8], 9
  0000:1EC4  7e03              jle      0x1ec9  ; -> loc_0000_1EC9
  0000:1EC6  e9a500            jmp      0x1f6e  ; -> loc_0000_1F6E

loc_0000_1EC9:
  0000:1EC9  837c0803          cmp      word ptr [si + 8], 3
  0000:1ECD  7e09              jle      0x1ed8  ; -> loc_0000_1ED8
  0000:1ECF  837c0809          cmp      word ptr [si + 8], 9
  0000:1ED3  7d03              jge      0x1ed8  ; -> loc_0000_1ED8
  0000:1ED5  e98000            jmp      0x1f58  ; -> loc_0000_1F58

loc_0000_1ED8:
  0000:1ED8  8b7c0a            mov      di, word ptr [si + 0xa]
  0000:1EDB  81c76c07          add      di, 0x76c
  0000:1EDF  81ffc207          cmp      di, 0x7c2
  0000:1EE3  7e15              jle      0x1efa  ; -> loc_0000_1EFA
  0000:1EE5  837c0803          cmp      word ptr [si + 8], 3
  0000:1EE9  750f              jne      0x1efa  ; -> loc_0000_1EFA
  0000:1EEB  8b5c08            mov      bx, word ptr [si + 8]
  0000:1EEE  d1e3              shl      bx, 1
  0000:1EF0  8b87be07          mov      ax, word ptr [bx + 0x7be]
  0000:1EF4  050700            add      ax, 7
  0000:1EF7  eb0a              jmp      0x1f03  ; -> loc_0000_1F03
  0000:1EF9  db 90                                              ; |.|

loc_0000_1EFA:
  0000:1EFA  8b5c08            mov      bx, word ptr [si + 8]
  0000:1EFD  d1e3              shl      bx, 1
  0000:1EFF  8b87c007          mov      ax, word ptr [bx + 0x7c0]

loc_0000_1F03:
  0000:1F03  8946fa            mov      word ptr [bp - 6], ax
  0000:1F06  f7c70300          test     di, 3
  0000:1F0A  7503              jne      0x1f0f  ; -> loc_0000_1F0F
  0000:1F0C  ff46fa            inc      word ptr [bp - 6]

loc_0000_1F0F:
  0000:1F0F  8b7c0a            mov      di, word ptr [si + 0xa]
  0000:1F12  83ef46            sub      di, 0x46
  0000:1F15  b86d01            mov      ax, 0x16d
  0000:1F18  f7ef              imul     di
  0000:1F1A  8bc8              mov      cx, ax
  0000:1F1C  8d4501            lea      ax, [di + 1]
  0000:1F1F  8bd9              mov      bx, cx
  0000:1F21  99                cdq
  0000:1F22  33c2              xor      ax, dx
  0000:1F24  2bc2              sub      ax, dx
  0000:1F26  b90200            mov      cx, 2
  0000:1F29  d3f8              sar      ax, cl
  0000:1F2B  33c2              xor      ax, dx
  0000:1F2D  2bc2              sub      ax, dx
  0000:1F2F  0346fa            add      ax, word ptr [bp - 6]
  0000:1F32  03c3              add      ax, bx
  0000:1F34  050400            add      ax, 4
  0000:1F37  99                cdq
  0000:1F38  b90700            mov      cx, 7
  0000:1F3B  f7f9              idiv     cx
  0000:1F3D  8b46fa            mov      ax, word ptr [bp - 6]
  0000:1F40  2bc2              sub      ax, dx
  0000:1F42  8946fe            mov      word ptr [bp - 2], ax
  0000:1F45  837c0803          cmp      word ptr [si + 8], 3
  0000:1F49  7513              jne      0x1f5e  ; -> loc_0000_1F5E
  0000:1F4B  39440e            cmp      word ptr [si + 0xe], ax
  0000:1F4E  7f08              jg       0x1f58  ; -> loc_0000_1F58
  0000:1F50  751c              jne      0x1f6e  ; -> loc_0000_1F6E
  0000:1F52  837c0402          cmp      word ptr [si + 4], 2
  0000:1F56  7c16              jl       0x1f6e  ; -> loc_0000_1F6E

loc_0000_1F58:
  0000:1F58  b80100            mov      ax, 1
  0000:1F5B  eb13              jmp      0x1f70  ; -> loc_0000_1F70
  0000:1F5D  db 90                                              ; |.|

loc_0000_1F5E:
  0000:1F5E  8b46fe            mov      ax, word ptr [bp - 2]
  0000:1F61  39440e            cmp      word ptr [si + 0xe], ax
  0000:1F64  7cf2              jl       0x1f58  ; -> loc_0000_1F58
  0000:1F66  7506              jne      0x1f6e  ; -> loc_0000_1F6E
  0000:1F68  837c0401          cmp      word ptr [si + 4], 1
  0000:1F6C  7cea              jl       0x1f58  ; -> loc_0000_1F58

loc_0000_1F6E:
  0000:1F6E  2bc0              sub      ax, ax

loc_0000_1F70:
  0000:1F70  5e                pop      si
  0000:1F71  5f                pop      di
  0000:1F72  8be5              mov      sp, bp
  0000:1F74  5d                pop      bp
  0000:1F75  c3                ret

; --- protocol_putChar ---
; Write single character to output stream (5 callers)
protocol_putChar:  ; (sub_0000_1F76)
  0000:1F76  55                push     bp
  0000:1F77  8bec              mov      bp, sp
  0000:1F79  8b4606            mov      ax, word ptr [bp + 6]
  0000:1F7C  8b5e0a            mov      bx, word ptr [bp + 0xa]
  0000:1F7F  0bd8              or       bx, ax
  0000:1F81  8b5e08            mov      bx, word ptr [bp + 8]
  0000:1F84  750b              jne      0x1f91  ; -> loc_0000_1F91
  0000:1F86  8b4604            mov      ax, word ptr [bp + 4]
  0000:1F89  f7e3              mul      bx
  0000:1F8B  8be5              mov      sp, bp
  0000:1F8D  5d                pop      bp
  0000:1F8E  c20800            ret      8

loc_0000_1F91:
  0000:1F91  f7e3              mul      bx
  0000:1F93  8bc8              mov      cx, ax
  0000:1F95  8b4604            mov      ax, word ptr [bp + 4]
  0000:1F98  f7660a            mul      word ptr [bp + 0xa]
  0000:1F9B  03c8              add      cx, ax
  0000:1F9D  8b4604            mov      ax, word ptr [bp + 4]
  0000:1FA0  f7e3              mul      bx
  0000:1FA2  03d1              add      dx, cx
  0000:1FA4  8be5              mov      sp, bp
  0000:1FA6  5d                pop      bp
  0000:1FA7  c20800            ret      8

; --- protocol_writeString ---
; Write string to output (2 callers)
protocol_writeString:  ; (sub_0000_1FAA)
  0000:1FAA  55                push     bp
  0000:1FAB  8bec              mov      bp, sp
  0000:1FAD  57                push     di
  0000:1FAE  56                push     si
  0000:1FAF  1e                push     ds
  0000:1FB0  07                pop      es
  0000:1FB1  8b7e04            mov      di, word ptr [bp + 4]
  0000:1FB4  8b7606            mov      si, word ptr [bp + 6]
  0000:1FB7  8bdf              mov      bx, di
  0000:1FB9  8b4e08            mov      cx, word ptr [bp + 8]
  0000:1FBC  e30c              jcxz     0x1fca  ; -> loc_0000_1FCA
  0000:1FBE  ac                lodsb    al, byte ptr [si]
  0000:1FBF  0ac0              or       al, al
  0000:1FC1  7403              je       0x1fc6  ; -> loc_0000_1FC6
  0000:1FC3  aa                stosb    byte ptr es:[di], al
  0000:1FC4  e2f8              loop     0x1fbe

loc_0000_1FC6:
  0000:1FC6  32c0              xor      al, al
  0000:1FC8  f3aa              rep stosb byte ptr es:[di], al

loc_0000_1FCA:
  0000:1FCA  8bc3              mov      ax, bx
  0000:1FCC  5e                pop      si
  0000:1FCD  5f                pop      di
  0000:1FCE  8be5              mov      sp, bp
  0000:1FD0  5d                pop      bp
  0000:1FD1  c3                ret

; --- protocol_writeNewline ---
; Write newline to output
protocol_writeNewline:  ; (sub_0000_1FD2)
  0000:1FD2  e9b500            jmp      0x208a  ; -> loc_0000_208A
  0000:1FD5  db 00                                              ; |.|

; --- protocol_formatNumber ---
; Format number for output
protocol_formatNumber:  ; (sub_0000_1FD6)
  0000:1FD6  55                push     bp
  0000:1FD7  8bec              mov      bp, sp
  0000:1FD9  83ec04            sub      sp, 4
  0000:1FDC  57                push     di
  0000:1FDD  56                push     si
  0000:1FDE  8b369007          mov      si, word ptr [0x790]
  0000:1FE2  0bf6              or       si, si
  0000:1FE4  7446              je       0x202c  ; -> loc_0000_202C
  0000:1FE6  837e0400          cmp      word ptr [bp + 4], 0
  0000:1FEA  7440              je       0x202c  ; -> loc_0000_202C
  0000:1FEC  ff7604            push     word ptr [bp + 4]
  0000:1FEF  e84200            call     0x2034  ; -> sub_0000_2034  ; protocol_divmod10
  0000:1FF2  83c402            add      sp, 2
  0000:1FF5  8bf8              mov      di, ax
  0000:1FF7  eb04              jmp      0x1ffd  ; -> loc_0000_1FFD
  0000:1FF9  db 90                                              ; |.|

loc_0000_1FFA:
  0000:1FFA  83c602            add      si, 2

loc_0000_1FFD:
  0000:1FFD  833c00            cmp      word ptr [si], 0
  0000:2000  742a              je       0x202c  ; -> loc_0000_202C
  0000:2002  ff34              push     word ptr [si]
  0000:2004  e82d00            call     0x2034  ; -> sub_0000_2034  ; protocol_divmod10
  0000:2007  83c402            add      sp, 2
  0000:200A  3bc7              cmp      ax, di
  0000:200C  7eec              jle      0x1ffa  ; -> loc_0000_1FFA
  0000:200E  8b1c              mov      bx, word ptr [si]
  0000:2010  80393d            cmp      byte ptr [bx + di], 0x3d
  0000:2013  75e5              jne      0x1ffa  ; -> loc_0000_1FFA
  0000:2015  57                push     di
  0000:2016  ff7604            push     word ptr [bp + 4]
  0000:2019  53                push     bx
  0000:201A  e83300            call     0x2050  ; -> sub_0000_2050  ; protocol_outputDigit
  0000:201D  83c406            add      sp, 6
  0000:2020  0bc0              or       ax, ax
  0000:2022  75d6              jne      0x1ffa  ; -> loc_0000_1FFA
  0000:2024  8b1c              mov      bx, word ptr [si]
  0000:2026  8d4101            lea      ax, [bx + di + 1]
  0000:2029  eb03              jmp      0x202e  ; -> loc_0000_202E
  0000:202B  db 90                                              ; |.|

loc_0000_202C:
  0000:202C  2bc0              sub      ax, ax

loc_0000_202E:
  0000:202E  5e                pop      si
  0000:202F  5f                pop      di
  0000:2030  8be5              mov      sp, bp
  0000:2032  5d                pop      bp
  0000:2033  c3                ret

; --- protocol_divmod10 ---
; Divide by 10 for decimal formatting (2 callers)
protocol_divmod10:  ; (sub_0000_2034)
  0000:2034  55                push     bp
  0000:2035  8bec              mov      bp, sp
  0000:2037  8bd7              mov      dx, di
  0000:2039  8cd8              mov      ax, ds
  0000:203B  8ec0              mov      es, ax
  0000:203D  8b7e04            mov      di, word ptr [bp + 4]
  0000:2040  33c0              xor      ax, ax
  0000:2042  b9ffff            mov      cx, 0xffff
  0000:2045  f2ae              repne scasb al, byte ptr es:[di]
  0000:2047  f7d1              not      cx
  0000:2049  49                dec      cx
  0000:204A  91                xchg     cx, ax
  0000:204B  8bfa              mov      di, dx
  0000:204D  5d                pop      bp
  0000:204E  c3                ret
  0000:204F  db 00                                              ; |.|

; --- protocol_outputDigit ---
; Output single decimal digit
protocol_outputDigit:  ; (sub_0000_2050)
  0000:2050  55                push     bp
  0000:2051  8bec              mov      bp, sp
  0000:2053  57                push     di
  0000:2054  56                push     si
  0000:2055  1e                push     ds
  0000:2056  07                pop      es
  0000:2057  8b4e08            mov      cx, word ptr [bp + 8]
  0000:205A  e326              jcxz     0x2082  ; -> loc_0000_2082
  0000:205C  8bd9              mov      bx, cx
  0000:205E  8b7e04            mov      di, word ptr [bp + 4]
  0000:2061  8bf7              mov      si, di
  0000:2063  33c0              xor      ax, ax
  0000:2065  f2ae              repne scasb al, byte ptr es:[di]
  0000:2067  f7d9              neg      cx
  0000:2069  03cb              add      cx, bx
  0000:206B  8bfe              mov      di, si
  0000:206D  8b7606            mov      si, word ptr [bp + 6]
  0000:2070  f3a6              repe cmpsb byte ptr [si], byte ptr es:[di]
  0000:2072  8a44ff            mov      al, byte ptr [si - 1]
  0000:2075  33c9              xor      cx, cx
  0000:2077  3a45ff            cmp      al, byte ptr [di - 1]
  0000:207A  7704              ja       0x2080  ; -> loc_0000_2080
  0000:207C  7404              je       0x2082  ; -> loc_0000_2082
  0000:207E  49                dec      cx
  0000:207F  49                dec      cx

loc_0000_2080:
  0000:2080  f7d1              not      cx

loc_0000_2082:
  0000:2082  8bc1              mov      ax, cx
  0000:2084  5e                pop      si
  0000:2085  5f                pop      di
  0000:2086  8be5              mov      sp, bp
  0000:2088  5d                pop      bp
  0000:2089  c3                ret

loc_0000_208A:
  0000:208A  55                push     bp
  0000:208B  8bec              mov      bp, sp
  0000:208D  57                push     di
  0000:208E  56                push     si
  0000:208F  8b7604            mov      si, word ptr [bp + 4]
  0000:2092  33c0              xor      ax, ax
  0000:2094  99                cdq
  0000:2095  33db              xor      bx, bx

loc_0000_2097:
  0000:2097  ac                lodsb    al, byte ptr [si]
  0000:2098  3c20              cmp      al, 0x20
  0000:209A  74fb              je       0x2097  ; -> loc_0000_2097
  0000:209C  3c09              cmp      al, 9
  0000:209E  74f7              je       0x2097  ; -> loc_0000_2097
  0000:20A0  50                push     ax
  0000:20A1  3c2d              cmp      al, 0x2d
  0000:20A3  7404              je       0x20a9  ; -> loc_0000_20A9
  0000:20A5  3c2b              cmp      al, 0x2b
  0000:20A7  7501              jne      0x20aa  ; -> loc_0000_20AA

loc_0000_20A9:
  0000:20A9  ac                lodsb    al, byte ptr [si]

loc_0000_20AA:
  0000:20AA  3c39              cmp      al, 0x39
  0000:20AC  771f              ja       0x20cd  ; -> loc_0000_20CD
  0000:20AE  2c30              sub      al, 0x30
  0000:20B0  721b              jb       0x20cd  ; -> loc_0000_20CD
  0000:20B2  d1e3              shl      bx, 1
  0000:20B4  d1d2              rcl      dx, 1
  0000:20B6  8bcb              mov      cx, bx
  0000:20B8  8bfa              mov      di, dx
  0000:20BA  d1e3              shl      bx, 1
  0000:20BC  d1d2              rcl      dx, 1
  0000:20BE  d1e3              shl      bx, 1
  0000:20C0  d1d2              rcl      dx, 1
  0000:20C2  03d9              add      bx, cx
  0000:20C4  13d7              adc      dx, di
  0000:20C6  03d8              add      bx, ax
  0000:20C8  83d200            adc      dx, 0
  0000:20CB  ebdc              jmp      0x20a9  ; -> loc_0000_20A9

loc_0000_20CD:
  0000:20CD  58                pop      ax
  0000:20CE  3c2d              cmp      al, 0x2d
  0000:20D0  93                xchg     bx, ax
  0000:20D1  7507              jne      0x20da  ; -> loc_0000_20DA
  0000:20D3  f7d8              neg      ax
  0000:20D5  83d200            adc      dx, 0
  0000:20D8  f7da              neg      dx

loc_0000_20DA:
  0000:20DA  5e                pop      si
  0000:20DB  5f                pop      di
  0000:20DC  5d                pop      bp
  0000:20DD  c3                ret
  0000:20DE  db 00 00                                           ; |..|

; ------------------------------------------------------------------------
; SEGMENT seg_020E  (64 bytes, file 0x22E0-0x2320)
; ------------------------------------------------------------------------
seg_020E:

  020E:0000  db 00 00 00 00 00 00 00 00                         ; |........|
  020E:0008  db 4D 53 20 52 75 6E 2D 54 69 6D 65 20 4C 69 62 72 ; "MS Run-Time Library - Copyright (c) 1988, Microsoft Corp"
  020E:0018  db 61 72 79 20 2D 20 43 6F 70 79 72 69 67 68 74 20
  020E:0028  db 28 63 29 20 31 39 38 38 2C 20 4D 69 63 72 6F 73
  020E:0038  db 6F 66 74 20 43 6F 72 70

; ------------------------------------------------------------------------
; SEGMENT seg_0212  (2530 bytes, file 0x2320-0x2D02)
; ------------------------------------------------------------------------
seg_0212:

  0212:0000  db 11 00 00 00 00 00 AF 18 00 00 0E 02 00 00 00 00 ; |................| [RELOC->seg_020E]
  0212:0010  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0020  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0030  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0040  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0050  db 00 00 00 00 00 00 00 00 48 00 00 00             ; |........H...|
  0212:005C  db 50 52 4F 54 4F 43 4F 4C 3A                      ; "PROTOCOL:"
  0212:0065  db 01 00 00 BA 01 00 00 00 00 00 00 00 00 00 00 00 ; |................| [RELOC->seg_0000]
  0212:0075  db 00 00 00 00 00 00 00 00 00 30 2E 31 00 00 00 00 ; |.........0.1....|
  0212:0085  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0095  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:00A5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:00B5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:00C5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:00D5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:00E5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:00F5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0105  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0115  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0125  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0135  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0145  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0155  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0165  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0175  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0185  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0195  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:01A5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:01B5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:01C5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:01D5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:01E5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:01F5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0205  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0215  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0225  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0235  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0245  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0255  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0265  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0275  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0285  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0295  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:02A5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:02B5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:02C5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:02D5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:02E5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:02F5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0305  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0315  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0325  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0335  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0345  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0355  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0365  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0375  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0385  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0395  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:03A5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:03B5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:03C5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:03D5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:03E5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:03F5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0405  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0415  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0425  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0435  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0445  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0455  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0465  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0475  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0485  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:0495  db 00 00 00 00 00 00 00 00 00 00 00 08 22 00 00 00 ; |............"...|
  0212:04A5  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 C1 ; |................|
  0212:04B5  db C0 81 C1 40 01 01 C3 C0 03 80 02 41 C2 01 C6 C0 ; |...@.......A....|
  0212:04C5  db 06 80 07 41 C7 00 05 C1 C5 81 C4 40 04 01 CC C0 ; |...A.......@....|
  0212:04D5  db 0C 80 0D 41 CD 00 0F C1 CF 81 CE 40 0E 00 0A C1 ; |...A.......@....|
  0212:04E5  db CA 81 CB 40 0B 01 C9 C0 09 80 08 41 C8 01 D8 C0 ; |...@.......A....|
  0212:04F5  db 18 80 19 41 D9 00 1B C1 DB 81 DA 40 1A 00 1E C1 ; |...A.......@....|
  0212:0505  db DE 81 DF 40 1F 01 DD C0 1D 80 1C 41 DC 00 14 C1 ; |...@.......A....|
  0212:0515  db D4 81 D5 40 15 01 D7 C0 17 80 16 41 D6 01 D2 C0 ; |...@.......A....|
  0212:0525  db 12 80 13 41 D3 00 11 C1 D1 81 D0 40 10 01 F0 C0 ; |...A.......@....|
  0212:0535  db 30 80 31 41 F1 00 33 C1 F3 81 F2 40 32 00 36 C1 ; |0.1A..3....@2.6.|
  0212:0545  db F6 81 F7 40 37 01 F5 C0 35 80 34 41 F4 00 3C C1 ; |...@7...5.4A..<.|
  0212:0555  db FC 81 FD 40 3D 01 FF C0 3F 80 3E 41 FE 01 FA C0 ; |...@=...?.>A....|
  0212:0565  db 3A 80 3B 41 FB 00 39 C1 F9 81 F8 40 38 00 28 C1 ; |:.;A..9....@8.(.|
  0212:0575  db E8 81 E9 40 29 01 EB C0 2B 80 2A 41 EA 01 EE C0 ; |...@)...+.*A....|
  0212:0585  db 2E 80 2F 41 EF 00 2D C1 ED 81 EC 40 2C 01 E4 C0 ; |../A..-....@,...|
  0212:0595  db 24 80 25 41 E5 00 27 C1 E7 81 E6 40 26 00 22 C1 ; |$.%A..'....@&.".|
  0212:05A5  db E2 81 E3 40 23 01 E1 C0 21 80 20 41 E0 01 A0 C0 ; |...@#...!. A....|
  0212:05B5  db 60 80 61 41 A1 00 63 C1 A3 81 A2 40 62 00 66 C1 ; |`.aA..c....@b.f.|
  0212:05C5  db A6 81 A7 40 67 01 A5 C0 65 80 64 41 A4 00 6C C1 ; |...@g...e.dA..l.|
  0212:05D5  db AC 81 AD 40 6D 01 AF C0 6F 80 6E 41 AE 01 AA C0 ; |...@m...o.nA....|
  0212:05E5  db 6A 80 6B 41 AB 00 69 C1 A9 81 A8 40 68 00 78 C1 ; |j.kA..i....@h.x.|
  0212:05F5  db B8 81 B9 40 79 01 BB C0 7B 80 7A 41 BA 01 BE C0 ; |...@y...{.zA....|
  0212:0605  db 7E 80 7F 41 BF 00 7D C1 BD 81 BC 40 7C 01 B4 C0 ; |~..A..}....@|...|
  0212:0615  db 74 80 75 41 B5 00 77 C1 B7 81 B6 40 76 00 72 C1 ; |t.uA..w....@v.r.|
  0212:0625  db B2 81 B3 40 73 01 B1 C0 71 80 70 41 B0 00 50 C1 ; |...@s...q.pA..P.|
  0212:0635  db 90 81 91 40 51 01 93 C0 53 80 52 41 92 01 96 C0 ; |...@Q...S.RA....|
  0212:0645  db 56 80 57 41 97 00 55 C1 95 81 94 40 54 01 9C C0 ; |V.WA..U....@T...|
  0212:0655  db 5C 80 5D 41 9D 00 5F C1 9F 81 9E 40 5E 00 5A C1 ; |\.]A.._....@^.Z.|
  0212:0665  db 9A 81 9B 40 5B 01 99 C0 59 80 58 41 98 01 88 C0 ; |...@[...Y.XA....|
  0212:0675  db 48 80 49 41 89 00 4B C1 8B 81 8A 40 4A 00 4E C1 ; |H.IA..K....@J.N.|
  0212:0685  db 8E 81 8F 40 4F 01 8D C0 4D 80 4C 41 8C 00 44 C1 ; |...@O...M.LA..D.|
  0212:0695  db 84 81 85 40 45 01 87 C0 47 80 46 41 86 01 82 C0 ; |...@E...G.FA....|
  0212:06A5  db 42 80 43 41 83 00 41 C1 81 81 80 40 40 00 00 00 ; |B.CA..A....@@...|
  0212:06B5  db 00 CD AB BA DC                                  ; |.....|
  0212:06BA  db 44 4D 43 53 52                                  ; "DMCSR"
  0212:06BF  db 00                                                ; NUL
  0212:06C0  db 00 00 00 00                                     ; |....|
  0212:06C4  db 31 30 30 30 43 47 41                            ; "1000CGA"
  0212:06CB  db 00                                                ; NUL
  0212:06CC  db 44 44 47 41 45 47 41                            ; "DDGAEGA"
  0212:06D3  db 00                                                ; NUL
  0212:06D4  db 48 45 52 43 50 4C 41 4E 54 43 31 36 54 43 34    ; "HERCPLANTC16TC4"
  0212:06E3  db 00                                                ; NUL
  0212:06E4  db 56 47 41 00                                     ; |VGA.|
  0212:06E8  db 4D 43 47 41 45 47 41                            ; "MCGAEGA"
  0212:06EF  db 00                                                ; NUL
  0212:06F0  db 4C 52 45 53 54 32 35 36 54 43 34 30 48          ; "LREST256TC40H"
  0212:06FD  db 00                                                ; NUL
  0212:06FE  db 00 00 43 00 00 00 4D 00 00 00 45 00 00 00 54 00 ; |..C...M...E...T.|
  0212:070E  db 00 00                                           ; |..|
  0212:0710  db 3B 43 5F 46 49 4C 45 5F 49 4E 46 4F             ; ";C_FILE_INFO"
  0212:071C  db 00                                                ; NUL
  0212:071D  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:072D  db 00 00 00 00 00 00 00 00 00 14 00 81 81 81 01 01 ; |................|
  0212:073D  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:074D  db 00 00 00 00 00 96 07 0E 02 43 00 00 00 00 00 00 ; |.........C......| [RELOC->seg_020E]
  0212:075D  db 00 00 00 00 00 00 00 FF FF 1E 00 3B 00 5A 00 78 ; |...........;.Z.x|
  0212:076D  db 00 97 00 B5 00 D4 00 F3 00 11 01 30 01 4E 01 6D ; |...........0.N.m|
  0212:077D  db 01 FF FF 1E 00 3A 00 59 00 77 00 96 00 B4 00 D3 ; |.....:.Y.w......|
  0212:078D  db 00 F2 00 10 01 2F 01 4D 01 6C 01 54 5A 00 00 50 ; |...../.M.l.TZ..P|
  0212:079D  db 53 54 00 50 44 54 00 80 70 00 00 01 00 DC 07 E0 ; |ST.PDT..p.......|
  0212:07AD  db 07                                              ; |.|
  0212:07AE  db 53 75 6E 4D 6F 6E 54 75 65 57 65 64 54 68 75 46 ; "SunMonTueWedThuFriSat"
  0212:07BE  db 72 69 53 61 74
  0212:07C3  db 00                                                ; NUL
  0212:07C4  db 4A 61 6E 46 65 62 4D 61 72 41 70 72 4D 61 79 4A ; "JanFebMarAprMayJunJulAugSepOctNovDec"
  0212:07D4  db 75 6E 4A 75 6C 41 75 67 53 65 70 4F 63 74 4E 6F
  0212:07E4  db 76 44 65 63
  0212:07E8  db 00                                                ; NUL
  0212:07E9  db 00 00                                           ; |..|
  0212:07EB  db 20 20 20 20 20 20 20 20 20 28 28 28 28 28 20 20 ; "         (((((                  H"
  0212:07FB  db 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20
  0212:080B  db 48
  0212:080C  db 10 10 10 10 10 10 10 10 10 10 10 10 10 10 10 84 ; |................|
  0212:081C  db 84 84 84 84 84 84 84 84 84 10 10 10 10 10 10 10 ; |................|
  0212:082C  db 81 81 81 81 81 81 01 01 01 01 01 01 01 01 01 01 ; |................|
  0212:083C  db 01 01 01 01 01 01 01 01 01 01 10 10 10 10 10 10 ; |................|
  0212:084C  db 82 82 82 82 82 82 02 02 02 02 02 02 02 02 02 02 ; |................|
  0212:085C  db 02 02 02 02 02 02 02 02 02 02 10 10 10 10 20 00 ; |.............. .|
  0212:086C  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:087C  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:088C  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:089C  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:08AC  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:08BC  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:08CC  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:08DC  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:08EC  db 00 00 00 00 00 00 00 00 00 00 00 00 00 00       ; |..............|
  0212:08FA  db 3C 3C 4E 4D 53 47 3E 3E                         ; "<<NMSG>>"
  0212:0902  db 00                                                ; NUL
  0212:0903  db 00                                              ; |.|
  0212:0904  db 52 36 30 30 30 0D 0A 2D 20 73 74 61 63 6B 20 6F ; "R6000\r\n- stack overflow\r\n"
  0212:0914  db 76 65 72 66 6C 6F 77 0D 0A
  0212:091D  db 00                                                ; NUL
  0212:091E  db 03 00                                           ; |..|
  0212:0920  db 52 36 30 30 33 0D 0A 2D 20 69 6E 74 65 67 65 72 ; "R6003\r\n- integer divide by 0\r\n"
  0212:0930  db 20 64 69 76 69 64 65 20 62 79 20 30 0D 0A
  0212:093E  db 00                                                ; NUL
  0212:093F  db 09 00                                           ; |..|
  0212:0941  db 52 36 30 30 39 0D 0A 2D 20 6E 6F 74 20 65 6E 6F ; "R6009\r\n- not enough space for environment\r\n"
  0212:0951  db 75 67 68 20 73 70 61 63 65 20 66 6F 72 20 65 6E
  0212:0961  db 76 69 72 6F 6E 6D 65 6E 74 0D 0A
  0212:096C  db 00                                                ; NUL
  0212:096D  db FC 00 0D 0A 00 FF 00                            ; |.......|
  0212:0974  db 72 75 6E 2D 74 69 6D 65 20 65 72 72 6F 72 20    ; "run-time error "
  0212:0983  db 00                                                ; NUL
  0212:0984  db 01 00                                           ; |..|
  0212:0986  db 52 36 30 30 31 0D 0A 2D 20 6E 75 6C 6C 20 70 6F ; "R6001\r\n- null pointer assignment\r\n"
  0212:0996  db 69 6E 74 65 72 20 61 73 73 69 67 6E 6D 65 6E 74
  0212:09A6  db 0D 0A
  0212:09A8  db 00                                                ; NUL
  0212:09A9  db 02 00                                           ; |..|
  0212:09AB  db 52 36 30 30 32 0D 0A 2D 20 66 6C 6F 61 74 69 6E ; "R6002\r\n- floating point not loaded\r\n"
  0212:09BB  db 67 20 70 6F 69 6E 74 20 6E 6F 74 20 6C 6F 61 64
  0212:09CB  db 65 64 0D 0A
  0212:09CF  db 00                                                ; NUL
  0212:09D0  db FF FF FF 00 00 00 00 00 00 00 00 00 00 00 00 00 ; |................|
  0212:09E0  db 00 00                                           ; |..|
