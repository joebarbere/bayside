# DeskMate 3.05 Reverse Engineering Status

## Legend

| Symbol | Meaning |
|--------|---------|
| :white_large_square: | Not started |
| :construction: | In progress |
| :yellow_circle: | Partially complete |
| :white_check_mark: | Complete |

## Stage 1: Research & Acquisition

| Task | Status | Notes |
|------|--------|-------|
| DeskMate version history documented | :white_check_mark: | See research/docs/ |
| DeskMate 3.05 binaries acquired | :white_check_mark: | archive.org ISO + WinWorld 3.5"/5.25" disk images; 148 files extracted |
| DOSBox config for original | :white_check_mark: | dosbox/configs/deskmate-tandy.conf (Tandy mode, 8086, 4000 cycles) |
| File format documentation | :white_check_mark: | 20 formats documented (.SND/.SNG/.PNT/.FIG/.WKS/.FIL/.RES/.CFG/.R89/.MOD/.FF1/.RFD/.HLP/.TUT/.PCL/.CLN/.ADR/.LBL/.ACC/.CLP + .PNT/.SNG noted as acquisition targets); see research/docs/file-formats.md |
| Desk accessory documentation | :white_check_mark: | All 18 ACC modules profiled with function counts, imports, INT patterns, and RE priority; see research/docs/desk-accessories.md |
| SDK / compiler identified | :white_check_mark: | Microsoft C 5.x (1987 runtime); DM89 extended header format decoded; INT E0h API service classes mapped |
| Hardware register documentation | :white_check_mark: | TGA/TGA2, SN76496, PSSJ DAC, PC speaker, keyboard, mouse; see research/references/hardware-registers.md |

## Stage 2: Binary Analysis

| Binary | Disassembled | Call Graph | Compiler ID | Notes |
|--------|-------------|------------|-------------|-------|
| DESK.EXE | :white_check_mark: | :white_check_mark: | :white_check_mark: | Hand-written ASM; DM89 header; 118 functions, 3218 insns, 6 segments, 33 relocs; 48 unique INT calls; version 05.00 build 900919 |
| DESKTOP.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 521 functions, 23206 insns, 78% coverage; 19 INT E0h + 35 INT 21h calls |
| TEXT.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 408 functions, 23650 insns, 81% coverage; 23 INT E0h + 15 INT 21h calls |
| WRKSHEET.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 416 functions, 6 segments, 15 relocs |
| FILER.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 318 functions, 6 segments, 25 relocs; imports dmguf+dmform+dmdb |
| DRAW.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 554 functions, 9 segments, 32 relocs; uses INT 33h (mouse) + INT 34h-3Dh (8087 FP) |
| CALENDAR.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 486 functions, 6 segments, 25 relocs |
| ADDRESS.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 316 functions, 6 segments, 35 relocs; imports dmguf+dmdb |
| TELECOM.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 269 functions, 5 segments, 13 relocs |
| HANGMAN.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 200 functions, 7501 insns; 18 INT E0h + 14 INT 21h calls; word game with embedded packed word list; profanity filter via SPELL resource; loads PRGUF+DMGUF+DMCSR+SPELL |
| PC_LINK.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x (1988); MZ+DM89; 538 functions, 5 segments, 18 DOS API services; DM89 CS:IP overrides broken MZ entry |
| FORMSET.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 419 functions, 6 segments, 25 relocs; imports dmguf+dmform+dmdb |
| PLAY.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 114 functions, 5295 insns; 40 INT E0h + 6 INT 21h calls; "Teach Me!" tutorial player (not music); imports dmguf+dmplay+unpack; 15 built-in .TUT lesson catalog |
| MAILMRGE.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 168 functions, 6 segments, 19 relocs |
| INSTALL.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.x; MZ+DM89; 210 functions, 5 segments, 13 relocs |
| DMVID.EXE | :white_check_mark: | :white_check_mark: | :white_check_mark: | MSC 5.0 small model; plain MZ (no DM89); 74 functions (41 named); CRT chain → _main; config I/O to DMCSR.CFG |
| INSTALL.EXE | :white_check_mark: | :white_check_mark: | :white_check_mark: | 828-byte chain loader; validates DM89 sig then EXEC's DESK.EXE |
| *.RES (52 files) | :white_check_mark: | :white_check_mark: | :white_check_mark: | 1056 functions, 59351 insns total; 48 MZ+DM89 + 3 plain MZ + 1 compressed data (TUTKBD.RES); DMFONT.RES largest (179 funcs); see disassembly/raw/res/ |
| *.ACC (18 files) | :white_check_mark: | :white_check_mark: | :white_check_mark: | 2141 functions total; DMHELP.ACC largest (223 funcs); 11 import dmguf; see disassembly/raw/acc/ |

## Stage 3: Annotation

**Cross-cutting reference:** INT E0h API reference compiled (2026-04-07). All 8 service classes documented, 28 AX codes inventoried, full cross-reference by module. See `research/docs/int-e0h-api-reference.md`.

| Module | Functions Labeled | Data Structures | Hardware I/O | Notes |
|--------|------------------|-----------------|--------------|-------|
| DESK.EXE | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 118 functions named; INT E0h dispatch handler at seg_03F5:0000; PDM/RES module loader chain; 32-slot resource table (11 bytes/entry); INT 09h/13h/21h/24h hooks; memory management; EMS support; keyboard translation tables; 5 global variable regions mapped; see disassembly/annotated/desk.asm |
| DESKTOP.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 521 functions named (300+ app + 60 PRGUF + 25 DMGUF + 100+ CRT); 18 subsystems mapped; PRGUF thunk table (60+ entries); DMGUF thunk table (25 entries); view state machine (files/tree/menus); icon grid layout engine; file manager with sort/search; menu definition CRUD; disk format/copy via FORMAT.COM+DISKCOPY.COM; DESKTOP.CFG config I/O; no direct HW I/O -- uses DM API via INT E0h; see disassembly/annotated/desktop.asm |
| TEXT.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 408 functions named; document buffer format with inline control codes (0x01=picture, 0x03=indent, 0x10-0x13=bold/underline); 50+ PRGUF stubs mapped; text editing, formatting, print, spell check (DMSPELL), thesaurus (DMTHES), mail merge field insertion; no direct HW I/O -- uses DM API via INT E0h; see disassembly/annotated/text.asm |
| WRKSHEET.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 416 functions named; spreadsheet grid 26 cols x 99 rows; custom 4-byte packed FP format (bias 0x3500); software FP math library (trig, log, exp, power via Taylor series -- no x87); formula compiler with recursive descent evaluator; 16 built-in functions (ABS/ATN/COS/EXP/INT/LOG/SGN/SIN/SQR/TAN/CMT/MAX/MIN/SUM/AVG/RMT); PRGUF+DMGUF dual resource dispatch; .WKS file format I/O via direct INT 21h; cell editing, formatting, row/col operations, print; no direct HW I/O; see disassembly/annotated/wrksheet.asm |
| FILER.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 318 functions named; flat-file database with .FIL format; field definitions (up to 22 fields), record management, sort/search/filter, calculated/index fields; DMFORM (form rendering) + DMDB (database engine) imports via DM89 far-call dispatch; DMGUF thunks for config I/O; no direct HW I/O; see disassembly/annotated/filer.asm |
| DRAW.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 554 functions named; vector graphics editor with 10 shape tools (line/rect/circle/ellipse/polygon/arc/text/freehand/Bezier); .FIG file format with per-shape-type writers; shape bounding box/transform/group operations; 42 PRGUF + 40 DMGUF thunks; software FP library (INT 34h-3Dh 8087 emulation); INT 33h mouse; color/pattern tables; undo support; zoom/grid/snap; 9 segments, 32 relocations; see disassembly/annotated/draw.asm |
| ADDRESS.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 316 functions named (120+ app + 50 DMGUF + 40 DMDB + CRT); address record structure (7 fields); A-Z alphabetical index tabs; auto-dial via INT 14h with Hayes AT commands; date validation with leap year (div 4/100/400); print subsystem (labels/envelopes/list); imports dmguf+dmdb via DM89 far-call dispatch; no direct HW I/O except COM port; see disassembly/annotated/address.asm |
| CALENDAR.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 486 functions named; calendar/scheduler with 4 view modes (monthly/weekly/daily/event edit); alarm support via ALARM.RES; recurring events; DMDB session for .CAL file storage; 50+ global variables mapped; PRGUF/DMGUF/DMDB dispatch thunks; 30 INT E0h + 17 INT 21h calls; no direct HW I/O; see disassembly/annotated/calendar.asm |
| TELECOM.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 269 functions named; terminal emulator with phone book (20 entries), serial comm via PRGUF, file transfer via PROTOCOL.RES, charset translation via TRANSLAT.RES; baud 300-9600, 7/8 data bits, N/E/O parity; capture-to-file; 14 INT E0h + 21 INT 21h calls; no direct UART I/O -- delegates to resources; see disassembly/annotated/telecom.asm |
| PC_LINK.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 538 functions named; Quantum Computer Services (pre-AOL) online service client; page/menu navigation via linked-list page stack; packet-based protocol with 2-byte message codes (Df/DK/MK/ES/ZK); PROTOCOL.RES + DMGUF.RES + PRGUF.RES triple resource dispatch; modem dialing, login/auth, file download manager; DM89 CS:IP overrides broken MZ entry; copyright 1988-1990 Quantum Computer Services Inc.; see disassembly/annotated/pc_link.asm |
| HANGMAN.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 200 functions named (100+ app + CRT); player struct (21 bytes), BSS map, packed word list format, profanity filter (55 fragments); no direct HW I/O -- uses DM API via INT E0h; see disassembly/annotated/hangman.asm |
| FORMSET.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 419 functions named (96.4% coverage); form designer/editor for FILER databases; form layout with field placement, labels, boxes, lines; field binding to database columns; visual form editing; imports dmguf+dmform+dmdb via DM89 far-call dispatch; DMDB thunk table (40+ entries); 6 segments, 25 relocations; no direct HW I/O; see disassembly/annotated/formset.asm |
| PLAY.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 114 functions named (25 app + 30 DMGUF + 9 PRGUF + 6 resource + 25 CRT); tutorial lesson catalog (15 entries); dmplay/unpack resource interaction; no direct HW I/O; see disassembly/annotated/play.asm |
| MAILMRGE.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 168 functions named (45 app + 11 host + 22 DM + CRT); merge field substitution, header/footer, date formatting, printer control; 21 INT E0h + 17 INT 21h calls; no direct HW I/O; see disassembly/annotated/mailmrge.asm |
| INSTALL.EXE | :white_check_mark: | :white_check_mark: | :white_check_mark: | All instructions annotated; 316-byte chain loader; validates DM89 signature in DESK.EXE; INT 21h/4Bh overlay load; patches MOLDAPP.MOD→INSTALL in environment; stack switch + far return trampoline; see disassembly/annotated/install.asm |
| INSTALL.PDM | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 210 functions named; DeskMate installer module; hard disk detection, file copy engine, DMCSR.CFG config writer; DMGUF/PRGUF import thunks; INT E0h stack-switch wrapper; 5 segments, 13 relocations; see disassembly/annotated/install-pdm.asm |
| DMVID.EXE | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 74 functions named (18 app + 56 CRT); DMCSR.CFG format mapped; no direct HW I/O — selects .RES driver for DESK.EXE; see disassembly/annotated/dmvid.asm |
| *.RES (52 files) | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 52 RES modules annotated (51 executable + 1 compressed data TUTKBD.RES); key modules: PRGUF (core PDM API thunk library), DMFONT (font rendering, 179 funcs), DMFORM (form engine), DMDBRD/DMDBUPD/DMDBBLD (database read/update/build), ALARM/ALRMINIT (alarm TSR), SPELL/SPL (spell checker + dictionary trie), PROTOCOL (XMODEM/YMODEM file transfer), DMPLAY (tutorial playback), DMSSM (sound manager), DMEMM (EMS memory), D87 (8087 detection), DMUNPACK (decompression); 16 video drivers (Tandy/CGA/EGA/VGA/Hercules/MCGA/Tandy1000 enhanced+standard pairs) with full I/O port and framebuffer documentation; 11 printer drivers; see disassembly/annotated/res/ |
| *.ACC (18 files) | :white_check_mark: | :white_check_mark: | :white_check_mark: | All 18 ACC desk accessories annotated; DMHELP (223 funcs, help system), DMACCESS (81 funcs, accessibility dispatcher), DMALARM (145 funcs, alarm TSR), DMSERV (191 funcs, service utility), DMSPELL (153 funcs, spell checker), DMCLIP (124 funcs, clipboard), DMPHONE (192 funcs, phone dialer), DMSETUP (193 funcs, configuration), DMNOTEPD (notepad), DMTODO (to-do list), DMDRWPRT (draw print), 6 printer driver ACCs; see disassembly/annotated/acc/ |

## Stage 4: C Transpilation

| Module | Functions | Lines of C | Compiles | Notes |
|--------|-----------|-----------|----------|-------|
| common/ | :white_large_square: | — | :white_large_square: | DOS API, video, sound wrappers |
| desktop/ | :white_large_square: | — | :white_large_square: | Shell + desktop UI |
| text/ | :white_large_square: | — | :white_large_square: | Word processor |
| worksheet/ | :white_large_square: | — | :white_large_square: | Spreadsheet |
| filer/ | :white_large_square: | — | :white_large_square: | Database / file manager |
| draw/ | :white_large_square: | — | :white_large_square: | Vector graphics |
| calendar/ | :white_large_square: | — | :white_large_square: | Scheduler |
| addressbook/ | :white_large_square: | — | :white_large_square: | Address book |
| telecom/ | :white_large_square: | — | :white_large_square: | Terminal emulator |
| pclink/ | :white_large_square: | — | :white_large_square: | Online service client |
| hangman/ | :white_large_square: | — | :white_large_square: | Word game |
| formset/ | :white_large_square: | — | :white_large_square: | Form designer |
| play/ | :white_large_square: | — | :white_large_square: | Music player |
| mailmerge/ | :white_large_square: | — | :white_large_square: | Mail merge |

## Stage 5: Verification

| Module | Runs in DOSBox | Visual Match | File I/O Match | Regression Tests |
|--------|---------------|--------------|----------------|-----------------|
| Shell (DESK.EXE) | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Desktop | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Text | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Worksheet | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Filer | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Draw | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Address Book | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Calendar | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Telecom | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| PC-Link | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Hangman | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Form Set | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Play | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Mail Merge | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
