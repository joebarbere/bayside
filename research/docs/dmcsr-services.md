# DeskMate resource services: DMCSR, DMGUF, PRGUF, SPELL

How a PDM's service calls are dispatched inside the DeskMate 3.05 resource
libraries, and what the services HANGMAN depends on actually do. Read
straight from the binaries in `archive/deskmate-3.05/extracted/`.
`tools/resdis.py` reproduces every address below:

```bash
tools/resdis.py DMCSR --table        # all 338 DMCSR services -> handler
tools/resdis.py DMCSR 13 14 16       # disassemble handlers
tools/resdis.py DMGUF 23             # "forwarded to PRGUF"
tools/resdis.py PRGUF 23
```

Addresses are `seg:off` within the file's load image, before relocation.
The PDM reaches each resource through the far entry point that INT E0h
AX=0206h writes to ES:BX.

## Registration and entry points

Each resource's init code registers a record with DESK.EXE (INT E0h
AX=01F0h or 01FFh, ES:BX → the record): an 8-byte name, then far pointers.
The first pointer is the service gateway.

| Resource | Record | Gateway | Dispatch | Handler table |
|---|---|---|---|---|
| DMCSR.R89 | 0FFD:0001 | 0FFD:019F | 0000:046C | word table at DGROUP 1180:0F31, index `AX & 0FFFh`, max 0151h |
| DMGUF.R89 | 02D3:0000 | 02BE:0084 | 0000:0005 → 0000:0081 | word table at `[DS:0033]`:0009 (02B5:0009) |
| PRGUF.RES | 0163:0006 | 0155:007E | 0000:000B | word table at `[DS:002F]`:000D |
| SPELL.RES | 01A4:000E | 018A:0068 | 0000:002C | word table at CS:0000 (21 entries) |

### DMCSR

- The gateway (0FFD:019F) saves the registers. Until DMCSR is initialised
  (DGROUP:0F04 = 1) it accepts only service 0118h, and returns at once for
  anything else. Then it far-calls the dispatcher.
- The dispatcher (0000:046C) rejects `AX & 0FFFh > 0151h` with AX = FFFFh.
  It splits AX: the low 12 bits index the handler table, and the top
  nibble is pushed as an argument for the handler.
- Handlers find their C arguments at SS:BP. HANGMAN's glue at 0000:345A
  sets BP to the caller's argument list.

### DMGUF and PRGUF

DMGUF's gateway forwards many codes to PRGUF without looking at them.
PRGUF is the library DMGUF loads at init through INT E0h 0206h, storing
the entry point at DS:002F.

- **Forwarded unchanged:** 0000h–0017h, 0019h, 0022h–0035h, 0037h–007Fh,
  AEh and B0h. This includes 0023h, keyToChar.
- **001Ah, special:** DMGUF calls PRGUF service 0000h and returns 1 if
  PRGUF's AX ≥ 0, else 0.
- **Handled by DMGUF itself:** 0018h, 001Bh–0021h, 0036h, and the other
  codes from 80h up. These go through DMGUF's own table, and codes ≥ 80h
  index it at `code − 80h`.

## The event queue (DMCSR 0013h, 0014h, 0016h)

HANGMAN's stubs give these misleading names: `dm_getEvent` (3494) sends
0014h, `dm_replyEvent` (348E) sends 0013h, and `dm_yield` (349A) sends
0016h. What the handlers actually do:

| Code | Handler | HANGMAN stub | Behaviour |
|---|---|---|---|
| 0014h | 0000:2A31 | dm_getEvent | **Peek, non-blocking.** If an event is held (flags FC2h/FCAh), copies it into the record. Otherwise polls the input sources (three far handlers at 158Ch, then three more via 2DA4h); the first event found is copied to the hold buffer FC3h and held. Nothing pending → type 0. A type-1 (key) event gets FFFFh in its second word. Returns with ZF set when the type is 0. |
| 0013h | 0000:2B9B | dm_replyEvent | **Get, blocking.** Calls the peek body until it returns an event, then consumes it by clearing the hold flags. Type 4 is not consumed. |
| 0016h | 0000:2BD5 | dm_yield | **Flush.** Clears the hold flags, discarding the held event without returning it. |

The record at arg0 (DS-relative) is 7 bytes: type byte, then the key or
menu word, then two more words. HANGMAN uses type 0 (none), 1 (key),
3 (menu or tile click) and 6 (timer).

What this means for HANGMAN:

- `hangman_processInput` (0000:086A) runs at the start of each turn. It
  peeks and flushes until nothing (or a timer or menu event) is pending,
  so **keys typed ahead are discarded**. It then blocks in 0013h for the
  next real input.
- `hangman_delayLoop` stops early only if an event is already pending
  when it peeks.
- The word-generation poll (0000:2F96) flushes anything pending.

## dm_keyToChar (DMGUF 0023h → PRGUF 0023h)

The PRGUF handler is at 0000:01CA, with the conversion at 0000:01D5.

1. The key word goes through the DOS country **case-map routine**: the far
   pointer at offset 12h of the country info, stored in PRGUF at DS:035E
   during init (0000:0E76). It changes only AL ≥ 80h.
2. AL in `a`–`z` is upper-cased with `and al,5Fh`.
3. AH passes through unchanged.

## DMCSR version (00D5h)

The handler at 0000:0653 returns **036Fh**. HANGMAN's glue at 0000:38C6
calls it once, after loading DMCSR, and uses AL to choose the mask for
service codes (stored at DS:1DE6):

| AL | Mask | Effect |
|---|---|---|
| ≤ 20h | 0FFFh | codes above 210Ah are refused (FFFFh; FFFEh for 212Dh) |
| ≤ 37h | FFFFh | |
| > 37h | EFFFh | codes up to 2144h pass unmasked, so DMCSR sees 20xxh |

Real DeskMate takes the last row. The helpers at 0000:391C and 0000:3946
adjust arguments for services 2090h and 2117h on older DMCSR versions;
HANGMAN doesn't call either.

## SPELL

- The gateway brackets each call with INT 15h AX=7002h/7003h (Tandy BIOS
  calls; DOSBox-X logs unknown 70xxh calls) and switches the current PSP
  (INT 21h AH=50h/51h).
- Services 0–3, 9 and 10 first check the dictionary (0000:0F7F) and return
  **FFFEh** if it is unavailable.

| Service | Handler | Returns |
|---|---|---|
| 0002h, check word | 0000:0FF7 | 0 = known, FFFFh = unknown, FFFEh = error (internal code 0Bh) |
| 0003h, suggest | 0000:102B | count, at most 21 (15h); writes each suggestion as a NUL-terminated string, back to back, then an empty string |

## DMCSR services HANGMAN calls

| Code | Handler | HANGMAN stub (name is a guess unless verified above) |
|---|---|---|
| 0006h | 0000:30E6 | dm_showCursor |
| 0007h | 0000:310D | dm_hideCursor |
| 0013h | 0000:2B9B | dm_replyEvent (get, blocking) |
| 0014h | 0000:2A31 | dm_getEvent (peek) |
| 0016h | 0000:2BD5 | dm_yield (flush held event) |
| 0017h | 0000:3802 | dm_setTimer |
| 0018h | 0000:38D1 | dm_setTimeout |
| 001Bh | 0000:67A6 | dm_loadBitmap |
| 001Ch | 0000:6878 | dm_drawBitmap |
| 001Eh | 0000:6A16 | dm_saveBitmap |
| 002Bh | 0000:2242 | dm_setScrollArea |
| 002Ch | 0000:2270 | dm_setScrollPos |
| 002Dh | 0000:2293 | dm_initScrollbar |
| 002Eh | 0000:2366 | dm_setActiveWin |
| 0030h | 0000:2335 | dm_initWindow |
| 003Fh | 0000:0E41 | dm_getScreenWidth |
| 0041h | 0000:0E4D | dm_getScreenHeight |
| 0042h | 0000:0E53 | dm_divide |
| 0043h | 0000:0E59 | dm_multiply |
| 0044h | 0000:0E83 | dm_setCursorPos |
| 0047h | 0000:0E98 | dm_showStatusBar |
| 0049h | 0000:0EB0 | dm_drawLine |
| 004Ah | 0000:0EBF | dm_setColor |
| 004Bh | 0000:0EC8 | dm_setTextAttr |
| 004Ch | 0000:0ED7 | dm_setFont |
| 0051h | 0000:0F74 | dm_drawChar |
| 0052h | 0000:0F7A | dm_drawString |
| 005Ah | 0000:0FD1 | dm_defineMenu |
| 005Bh | 0000:0FE3 | dm_defineDialog |
| 005Ch | 0000:0FF8 | dm_setDialogField |
| 005Fh | 0000:3F43 | dm_getDialogField |
| 0060h | 0000:10C4 | dm_drawAt |
| 0061h | 0000:100A | dm_openDialog |
| 0062h | 0000:1019 | dm_openDialogEx |
| 0063h | 0000:102B | dm_closeDialog |
| 006Ah | 0000:107F | dm_setBorder |
| 006Ch | 0000:1085 | dm_setBackground |
| 006Eh | 0000:1097 | dm_fillRect |
| 00D5h | 0000:0653 | version (HANGMAN glue 0000:38C6), returns 036Fh |
| 00D6h | 0000:0602 | dm_cursorInit |
| 00D7h | 0000:0623 | dm_cursorCleanup |
| 00E3h | 0000:5905 | dm_showForm |
| 00E4h | 0000:5A24 | dm_getFormResult |
| 00E9h | 0000:630B | dm_msgBox |
| 00F7h | 0000:0D8A | dm_scrollContent |
| 00F8h | 0000:0D8D | dm_waitReady |
| 0100h | 0000:1C16 | dm_setAppTitle |
| 0102h | 0000:8796 | dm_spellOp |

## Still open

- **Drawing, window, form and dialog services** have handler addresses but
  haven't been read. HANGMAN's traces only check the arguments it passes
  to them, which is enough to verify the C rebuild.
- **The input sources** that peek polls (keyboard, mouse, timer) are found
  through 158Ch but haven't been read. They decide when timer events
  (type 6) are generated.
- **Event type 4**, built at 0000:2E04 when DS:0FD2 changes, isn't
  understood yet.
