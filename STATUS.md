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
| File format documentation | :yellow_circle: | .PDM (confirmed MZ+DM89 header), .WKS, .FIL, .CFG partially documented; .SND, .FIG, .SNG headers known from community; see research/docs/deskmate-sdk-research.md |
| SDK / compiler identified | :white_check_mark: | Microsoft C 5.x (1987 runtime); DM89 extended header format decoded; INT E0h API service classes mapped |
| Hardware register documentation | :white_large_square: | TGA, SN76496, DAC |

## Stage 2: Binary Analysis

| Binary | Disassembled | Call Graph | Compiler ID | Notes |
|--------|-------------|------------|-------------|-------|
| DESK.EXE | :white_large_square: | :white_large_square: | :white_check_mark: | Hand-written ASM; DM89 header; 5 segments, 33 relocs; version 05.00 build 900919 |
| DESKTOP.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89; imports dmguf |
| TEXT.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| WRKSHEET.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| FILER.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89; imports dmguf+dmform+dmdb |
| DRAW.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| CALENDAR.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| ADDRESS.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89; imports dmguf+dmform+dmdb |
| TELECOM.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| HANGMAN.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89; contains profanity filter |
| PC_LINK.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x (1988); MZ+DM89; DM89 CS:IP overrides broken MZ entry |
| FORMSET.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| PLAY.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89; imports dmplay; smallest PDM (12KB) |
| MAILMRGE.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| INSTALL.PDM | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 |
| DMVID.EXE | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.0 small model; plain MZ (no DM89); standalone DOS program |
| INSTALL.EXE | :white_check_mark: | :white_check_mark: | :white_check_mark: | 828-byte chain loader; validates DM89 sig then EXEC's DESK.EXE |
| *.RES | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89 (except ALRMINIT/D87/DMUNPACK: plain MZ legacy) |
| *.ACC | :white_large_square: | :white_large_square: | :white_check_mark: | MSC 5.x; MZ+DM89; typically import dmguf |

## Stage 3: Annotation

| Module | Functions Labeled | Data Structures | Hardware I/O | Notes |
|--------|------------------|-----------------|--------------|-------|
| DESK.EXE | :white_large_square: | :white_large_square: | :white_large_square: | |
| DESKTOP.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| TEXT.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| WRKSHEET.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| FILER.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| DRAW.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| ADDRESS.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| CALENDAR.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| TELECOM.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| PC_LINK.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| HANGMAN.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| FORMSET.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| PLAY.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| MAILMRGE.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| DMVID.EXE | :white_large_square: | :white_large_square: | :white_large_square: | |
| *.RES | :white_large_square: | :white_large_square: | :white_large_square: | |

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
