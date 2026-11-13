/* ========================================================================
 * words.c -- HANGMAN.PDM word choice: pseudo-word generator, SPELL lookup,
 * "Please wait" box and the word filter
 * ========================================================================
 * How a word is chosen (hangman_playWord): a pronounceable pseudo-word of
 * the requested length is generated from two cumulative letter-frequency
 * tables driven by _rand, then the SPELL resource is asked whether it is a
 * real word. If it is not, SPELL's spelling suggestions are searched for one
 * of the right length. Every candidate must pass the word filter
 * (hangman_profanityCheck). While this loops, the dots after the "Please
 * wait" message blink and DeskMate events are polled so the user can cancel.
 *
 * Several of the annotation names of this area are wrong; they are kept
 * because they are link labels (functions.txt). Each comment says what the
 * function really does.
 * ======================================================================== */
#include "hangman.h"

/* ---- letter classes returned by hangman_animFrame -------------------- */
#define LC_VOWEL      1             /* a e i o u */
#define LC_CONSONANT  (-1)
#define LC_Q          (-3)          /* q: must be followed by u */
/* generator states (hangman_showLetterAnim / hangman_animSequence):
 * 1 / 2 = one / two vowels in a row, -1 / -2 = one / two consonants in a
 * row, -3 = just emitted a q. A third vowel or consonant is never drawn. */
#define GS_VOWEL2     2
#define GS_CONS2      (-2)

#define LETTER_COUNT  25            /* table entries 'a'..'y'; past -> 'z' */

#define WAIT_W        0x294         /* "Please wait" box height(?) argument */
#define SCREEN_COLS   0x50

/* Menu item state bytes in DGROUP (1 = enabled). The word chooser greys
 * them out while it runs and restores them afterwards. */
#define MENU_ITEM_43  DG8(0x0043)
#define MENU_ITEM_4E  DG8(0x004E)
#define MENU_ITEM_59  DG8(0x0059)
#define MENU_ITEM_85  DG8(0x0085)
#define MENU_ITEM_90  DG8(0x0090)
#define MENU_ITEM_9B  DG8(0x009B)

/* Word filter fragments: original DGROUP strings (pointer values matter:
 * they are passed to the original _strncmp). */
#define FRAG(off)     ((char *)(off))

/* address: 0000:23EB hangman_readWordFromRes
 * Not a resource read: collects a typed word from DeskMate events. Waits
 * with dm_replyEvent; every key event other than Enter (0x0D) stores
 * dm_keyToChar(key) at *word++. The count is incremented for every event
 * that is not Enter -- non-key events included, and no terminator is
 * written. Returns the count. Used by hangman_chooseWord when DeskMate
 * answers query 0xFD17. */
int hangman_readWordFromRes(char *word)
{
    int count = 0;                  /* bp-0A */
    struct words_event ev;          /* bp-08 */

    for (;;) {
        dm_replyEvent(&ev);
        if (ev.type == 1) {
            if (ev.code == 0x0D) {
                break;
            }
            *word++ = (char)dm_keyToChar(ev.code);
        }
        count++;
    }
    return count;
}

/* address: 0000:242A hangman_initGameState
 * Seed the random generator: _srand(low word of time + milliseconds), then
 * discard rand() % 100 further values. */
void hangman_initGameState(void)
{
    struct words_timeb tb;          /* bp-0E */
    int skip;                       /* bp-02 */
    int i;                          /* bp-04 */

    _ftime(&tb);
    _srand(tb.time_lo + tb.millitm);
    skip = _rand() % 100;
    for (i = 0; i < skip; i++) {
        _rand();
    }
}

/* address: 0000:246C hangman_playWord
 * Choose the word to guess: fill `word` with a real word of `len` letters.
 * Shows the "Please wait" box and greys out menu items meanwhile. Returns
 * 0 when a word was chosen (it is upper-cased, menus restored, box closed),
 * -1 when cancelled from the menu or when SPELL failed (-2). */
int hangman_playWord(char *word, int len)
{
    char dot = '.';                 /* bp-02: blinking '.' / ' ' */
    int tries;                      /* bp-04 */
    int box;                        /* bp-06 */
    int result;                     /* bp-08 */
    int menus;                      /* bp-0A */

    dm_waitReady();
    box = hangman_showWaitMessage();
    menus = hangman_getWordFlags();
    tries = 0;
    for (;;) {
        hangman_showLetterAnim(word, len);
        if (tries > 0x24) {
            tries = hangman_drawWordStatus();
            dot = (dot == '.') ? ' ' : '.';
        }
        dm_drawChar((int)(signed char)dot);
        result = hangman_crtEntryStub();
        if (result != 0) {
            if (result == -1) {
                break;
            }
            if (result == 2) {
                tries = 0;
                dot = '.';
                box = hangman_showWaitMessage();
            }
        }
        result = hangman_wordAnimEnter(word);
        if (result == 1) {
            result = 0;
            break;
        }
        if (result != -2) {
            result = hangman_wordAnimExit(word, len);
            if (result == 1) {
                result = 0;
                break;
            }
        }
        if (result == -2) {
            result = -1;
            break;
        }
        tries++;
    }

    if (result == 0) {
        _strupr(word);
        hangman_setWordFlags(menus);
        hangman_drawScoreUpdate(box);
    }
    dm_scrollContent();
    return result;
}

/* address: 0000:2558 hangman_wordAnimEnter
 * Ask SPELL whether `word` is a real word. Returns 1 if it is and passes
 * the word filter, 0 if SPELL does not know it (-1), else -2 -- which
 * includes a real word that fails the filter, so hangman_playWord then
 * gives up with -1 rather than trying another word. */
int hangman_wordAnimEnter(char *word)
{
    int r;                          /* bp-02 */

    r = dm_spellCheckWord(word);
    if (r == 0 && hangman_profanityCheck(word) != 0) {
        return 1;
    }
    if (r == -1) {
        return 0;
    }
    return -2;
}

/* address: 0000:2591 hangman_wordAnimExit
 * Ask SPELL for suggestions for `word` (a list of NUL-separated strings in
 * g_suggestBuf). Copy the first one that is `len` characters long, passes
 * the word filter and is all lower case over `word` and return 1; return
 * 0 if none fits, -2 if SPELL failed. */
int hangman_wordAnimExit(char *word, int len)
{
    char *s = g_suggestBuf;         /* bp-04 */
    int n;                          /* bp-06 */
    int slen;                       /* bp-02 */

    n = dm_spellSuggest(word, g_suggestBuf);
    if (n == -2) {
        return -2;
    }
    while (n-- != 0) {
        slen = _strlen(s);
        if (slen == len && hangman_profanityCheck(s) != 0
                && hangman_animCleanup(s, slen) != 0) {
            _strncpy(word, s);      /* 3CF8 is really strcpy */
            return 1;
        }
        s += slen + 1;
    }
    return 0;
}

/* address: 0000:260F hangman_showLetterAnim
 * Generate a pronounceable pseudo-word of `len` letters into `word`: first
 * letter from g_firstLetterFreq, the rest from hangman_animSequence (no
 * three vowels or consonants in a row). A q is followed by u when there is
 * room for at least two more letters after the u; otherwise the q is taken
 * back and that letter drawn again. */
void hangman_showLetterAnim(char *word, int len)
{
    int saved;                      /* bp-02: state before the last letter */
    int state;                      /* bp-04 */
    int i;                          /* bp-06 */

    *word = (char)hangman_animFlash(g_firstLetterFreq);
    state = hangman_animFrame((int)(signed char)*word++);
    for (i = 1; i < len; i++) {
        if (state == LC_Q) {
            if (len - 3 >= i) {
                *word++ = 'u';
                state = GS_CONS2;
            } else {
                word--;
                i -= 2;
                state = saved;
            }
        } else {
            saved = state;
            *word++ = (char)hangman_animSequence(&state);
        }
    }
    *word = 0;
}

/* address: 0000:2698 hangman_animFrame
 * Letter class: 1 for a vowel (a e i o u), -3 for q, -1 otherwise. */
int hangman_animFrame(int c)
{
    switch (c) {
    case 'a':
    case 'e':
    case 'i':
    case 'o':
    case 'u':
        return LC_VOWEL;
    case 'q':
        return LC_Q;
    }
    return LC_CONSONANT;
}

/* address: 0000:26CB hangman_animFlash
 * Draw a random letter from a cumulative frequency table of 25 unsigned
 * words: the first entry greater than _rand() picks 'a'+index ('z' past
 * the end). */
int hangman_animFlash(unsigned *freq)
{
    unsigned r;                     /* bp-02 */
    unsigned i;                     /* bp-04 */

    r = _rand();
    for (i = 0; i < LETTER_COUNT && freq[i] <= r; i++) {
    }
    return i + 'a';
}

/* address: 0000:2702 hangman_animSequence
 * Draw the next letter from g_nextLetterFreq, redrawing until it may follow
 * the current generator state *state (no third vowel or consonant in a
 * row, no q after two consonants); update *state and return the letter. */
int hangman_animSequence(int *state)
{
    int c;                          /* bp-04 */
    int cls;                        /* bp-02 */

    for (;;) {
        c = hangman_animFlash(g_nextLetterFreq);
        cls = hangman_animFrame(c);
        if (cls == LC_VOWEL) {
            if (*state == GS_VOWEL2) {
                continue;
            }
            *state = (*state == 1) ? GS_VOWEL2 : 1;
            return c;
        }
        if (cls == LC_Q) {
            if (*state == GS_CONS2) {
                continue;
            }
            *state = LC_Q;
            return c;
        }
        if (*state == GS_CONS2) {
            continue;
        }
        *state = (*state == -1) ? GS_CONS2 : -1;
        return c;
    }
}

/* address: 0000:2778 hangman_drawWordStatus
 * Move the cursor back to the start of the blinking dots (below the
 * "Please wait" text) and return 0 (resets the caller's try counter). */
int hangman_drawWordStatus(void)
{
    dm_setCursorPos(((SCREEN_COLS - (unsigned)_strlen(g_waitMessage)) >> 1) * 100u,
                    g_numPlayers * 0x6E + 0xE2E);
    return 0;
}

/* address: 0000:27A3 hangman_showWaitMessage
 * Open the "Please wait while a word is chosen..." box (centred, its
 * position depends on the number of players), draw the text and leave the
 * cursor on the line below for the dots. Returns 0 if the box saved the
 * screen under it (dm_openDialogEx), 1 if the board must be redrawn when
 * it closes. */
int hangman_showWaitMessage(void)
{
    int box;                        /* bp-02 */
    int y;                          /* bp-04 */
    unsigned x;                     /* bp-06 */
    unsigned len;                   /* bp-08 */

    len = _strlen(g_waitMessage);
    x = ((SCREEN_COLS - len) >> 1) * 100u;
    y = g_numPlayers * 0x6E + 0xD52;
    if (dm_openDialog(x, y - 0x32, 100u * len, (char *)WAIT_W) <= 0x8598) {
        dm_openDialogEx(x, y - 0x32, 100u * len, (char *)WAIT_W, g_dlgSaveArea);
        box = 0;
    } else {
        box = 1;
    }
    dm_setColor(1, 0);
    dm_setCursorPos(x, y);
    dm_drawString(g_waitMessage);
    dm_setColor(0, 1);
    dm_setCursorPos(x, y + 0xDC);
    return box;
}

/* address: 0000:2864 hangman_drawScoreUpdate
 * Close the "Please wait" box: redraw the board if it could not save the
 * screen (box != 0), else restore what was under it. */
void hangman_drawScoreUpdate(int box)
{
    unsigned len;                   /* bp-06 */
    unsigned x;                     /* bp-04 */
    int y;                          /* bp-02 */

    len = _strlen(g_waitMessage);
    x = ((SCREEN_COLS - len) >> 1) * 100u;
    y = g_numPlayers * 0x6E + 0xD52;
    if (box != 0) {
        hangman_refreshBoard();
    } else {
        dm_closeDialog(x, y - 0x32, 100u * len, (char *)WAIT_W, g_dlgSaveArea);
    }
}

/* address: 0000:28C2 hangman_getWordFlags
 * Grey out the menu items while a word is chosen. Returns bit 0/1 = the
 * items at 004E/0059 were enabled (they are only restored if they were). */
int hangman_getWordFlags(void)
{
    int was = 0;                    /* bp-02 */

    if (MENU_ITEM_4E == 1) {
        was |= 1;
    }
    if (MENU_ITEM_59 == 1) {
        was |= 2;
    }
    MENU_ITEM_9B = 0;
    MENU_ITEM_90 = 0;
    MENU_ITEM_85 = 0;
    MENU_ITEM_59 = 0;
    MENU_ITEM_4E = 0;
    MENU_ITEM_43 = 0;
    dm_setTimer(0xB4);
    return was;
}

/* address: 0000:2905 hangman_setWordFlags
 * Re-enable the menu items greyed out by hangman_getWordFlags (`was` is its
 * result); 0090 only with fewer than 4 players, 009B only with more than
 * one. Returns 0. */
int hangman_setWordFlags(int was)
{
    MENU_ITEM_43 = 1;
    if (was & 1) {
        MENU_ITEM_4E = 1;
    }
    if (was & 2) {
        MENU_ITEM_59 = 1;
    }
    MENU_ITEM_85 = 1;
    if (g_numPlayers < 4) {
        MENU_ITEM_90 = 1;
    }
    if (g_numPlayers > 1) {
        MENU_ITEM_9B = 1;
    }
    dm_setTimer(0xB4);
    return 0;
}

/* address: 0000:294E hangman_animCleanup
 * Return 1 if the first n characters of s are all 'a'..'z', else 0. */
int hangman_animCleanup(char *s, int n)
{
    signed char c;                  /* bp-02 */

    while (n-- != 0) {
        c = *s++;
        if (c < 'a' || c > 'z') {
            return 0;
        }
    }
    return 1;
}

/* address: 0000:297E hangman_profanityCheck
 * Word filter. Dispatches on the first letter and compares the rest of the
 * word with fragments of offensive words; returns 0 if the word starts
 * with one of them, 1 if it is acceptable (also for words not starting
 * with 'a'..'w', and for j/k). The fragments live in DGROUP 1FEA-2188. */
int hangman_profanityCheck(char *word)
{
    switch (*word++) {
    case 'a':
        if (_strncmp(word, FRAG(0x1FEA), 3) == 0        /* "nus" */
                || _strncmp(word, FRAG(0x1FEE), 7) == 0 /* "bortion" */
                || _strncmp(word, FRAG(0x1FF6), 3) == 0)/* "nal" */
            return 0;
        break;
    case 'b':
        if (_strncmp(word, FRAG(0x1FFA), 4) == 0        /* "itch" */
                || _strncmp(word, FRAG(0x1FFF), 6) == 0 /* "astard" */
                || _strncmp(word, FRAG(0x2006), 6) == 0 /* "estial" */
                || _strncmp(word, FRAG(0x200D), 4) == 0)/* "isex" */
            return 0;
        break;
    case 'c':
        if (_strncmp(word, FRAG(0x2012), 5) == 0        /* "litor" */
                || _strncmp(word, FRAG(0x2018), 5) == 0 /* "oitus" */
                || _strncmp(word, FRAG(0x201E), 5) == 0 /* "ondom" */
                || _strncmp(word, FRAG(0x2024), 6) == 0 /* "opulat" */
                || _strncmp(word, FRAG(0x202B), 5) == 0 /* "rotch" */
                || _strncmp(word, FRAG(0x2031), 3) == 0)/* "rap" */
            return 0;
        break;
    case 'd':
        if (_strncmp(word, FRAG(0x2035), 3) == 0        /* "amn" */
                || _strncmp(word, FRAG(0x2039), 3) == 0 /* "ick" */
                || _strncmp(word, FRAG(0x203D), 5) == 0)/* "efeca" */
            return 0;
        break;
    case 'e':
        if (_strncmp(word, FRAG(0x2043), 7) == 0        /* "jaculat" */
                || _strncmp(word, FRAG(0x204B), 5) == 0)/* "xcrem" */
            return 0;
        break;
    case 'f':
        if (_strncmp(word, FRAG(0x2051), 5) == 0        /* "ellat" */
                || _strncmp(word, FRAG(0x2057), 4) == 0 /* "eces" */
                || _strncmp(word, FRAG(0x205C), 8) == 0 /* "allopian" */
                || _strncmp(word, FRAG(0x2065), 7) == 0 /* "ornicat" */
                || _strncmp(word, FRAG(0x206D), 7) == 0 /* "oreskin" */
                || _strncmp(word, FRAG(0x2075), 5) == 0)/* "aggot" */
            return 0;
        break;
    case 'g':
        if (_strncmp(word, FRAG(0x207B), 5) == 0        /* "oddam" */
                || _strncmp(word, FRAG(0x2081), 4) == 0 /* "lans" */
                || _strncmp(word, FRAG(0x2086), 6) == 0)/* "onorrh" */
            return 0;
        break;
    case 'h':
        if (_strncmp(word, FRAG(0x208D), 3) == 0        /* "ell" */
                || _strncmp(word, FRAG(0x2091), 5) == 0 /* "erpes" */
                || _strncmp(word, FRAG(0x2097), 6) == 0)/* "omosex" */
            return 0;
        break;
    case 'i':
        if (_strncmp(word, FRAG(0x209E), 5) == 0)       /* "ncest" */
            return 0;
        break;
    case 'l':
        if (_strncmp(word, FRAG(0x20A4), 4) == 0        /* "abia" */
                || _strncmp(word, FRAG(0x20A9), 6) == 0)/* "esbian" */
            return 0;
        break;
    case 'm':
        if (_strncmp(word, FRAG(0x20B0), 7) == 0        /* "asochis" */
                || _strncmp(word, FRAG(0x20B8), 5) == 0 /* "enses" */
                || _strncmp(word, FRAG(0x20BE), 5) == 0 /* "olest" */
                || _strncmp(word, FRAG(0x20C4), 7) == 0 /* "enstrua" */
                || _strncmp(word, FRAG(0x20CC), 6) == 0)/* "asturb" */
            return 0;
        break;
    case 'n':
        if (_strncmp(word, FRAG(0x20D3), 5) == 0)       /* "ipple" */
            return 0;
        break;
    case 'o':
        if (_strncmp(word, FRAG(0x20D9), 5) == 0        /* "rgasm" */
                || _strncmp(word, FRAG(0x20DF), 3) == 0)/* "var" */
            return 0;
        break;
    case 'p':
        if (_strncmp(word, FRAG(0x20E3), 4) == 0        /* "enis" */
                || _strncmp(word, FRAG(0x20E8), 5) == 0 /* "enile" */
                || _strncmp(word, FRAG(0x20EE), 4) == 0 /* "hall" */
                || _strncmp(word, FRAG(0x20F3), 3) == 0 /* "imp" */
                || _strncmp(word, FRAG(0x20F7), 6) == 0 /* "rostit" */
                || _strncmp(word, FRAG(0x20FE), 4) == 0 /* "ubic" */
                || _strncmp(word, FRAG(0x2103), 4) == 0 /* "ubis" */
                || _strncmp(word, FRAG(0x2108), 2) == 0 /* "uk" */
                || _strncmp(word, FRAG(0x210B), 3) == 0)/* "uss" */
            return 0;
        break;
    case 'q':
        if (_strncmp(word, FRAG(0x210F), 4) == 0)       /* "ueer" */
            return 0;
        break;
    case 'r':
        if (_strncmp(word, FRAG(0x2114), 3) == 0        /* "ape" */
                || _strncmp(word, FRAG(0x2118), 5) == 0 /* "ectum" */
                || _strncmp(word, FRAG(0x211E), 5) == 0 /* "ectal" */
                || _strncmp(word, FRAG(0x2124), 5) == 0)/* "apist" */
            return 0;
        break;
    case 's':
        if (_strncmp(word, FRAG(0x212A), 3) == 0        /* "hit" */
                || _strncmp(word, FRAG(0x212E), 4) == 0 /* "adis" */
                || _strncmp(word, FRAG(0x2133), 4) == 0 /* "crot" */
                || _strncmp(word, FRAG(0x2138), 2) == 0 /* "ex" */
                || _strncmp(word, FRAG(0x213B), 4) == 0 /* "emen" */
                || _strncmp(word, FRAG(0x2140), 3) == 0 /* "lut" */
                || _strncmp(word, FRAG(0x2144), 4) == 0 /* "odom" */
                || _strncmp(word, FRAG(0x2149), 6) == 0 /* "chmuck" */
                || _strncmp(word, FRAG(0x2150), 6) == 0 /* "yphili" */
                || _strncmp(word, FRAG(0x2157), 4) == 0)/* "perm" */
            return 0;
        break;
    case 't':
        if (_strncmp(word, FRAG(0x215C), 6) == 0        /* "esticl" */
                || _strncmp(word, FRAG(0x2163), 5) == 0 /* "estes" */
                || _strncmp(word, FRAG(0x2169), 3) == 0)/* "its" */
            return 0;
        break;
    case 'u':
        if (_strncmp(word, FRAG(0x216D), 3) == 0        /* "rin" */
                || _strncmp(word, FRAG(0x2171), 3) == 0)/* "ter" */
            return 0;
        break;
    case 'v':
        if (_strncmp(word, FRAG(0x2175), 5) == 0        /* "agina" */
                || _strncmp(word, FRAG(0x217B), 4) == 0 /* "omit" */
                || _strncmp(word, FRAG(0x2180), 4) == 0)/* "ulva" */
            return 0;
        break;
    case 'w':
        if (_strncmp(word, FRAG(0x2185), 3) == 0)       /* "hor" */
            return 0;
        break;
    }
    return 1;
}

/* address: 0000:2F96 hangman_crtEntryStub
 * Not CRT code: poll one DeskMate event while a word is being chosen.
 * Returns -1 to cancel (menu 0xF503, or menu 0xF504 when hangman_runDialog
 * returns nonzero, or a type-6 event hangman_handleTimerEvent rejects),
 * 2 after a type-6 event that redrew the screen (the "Please wait" box
 * must be reopened), else 0. */
int hangman_crtEntryStub(void)
{
    int result = 0;                 /* bp-0A */
    struct words_event ev;          /* bp-08 */

    dm_getEvent(&ev);
    if (ev.type != 0) {
        dm_yield();
        if (ev.type == 3) {
            if ((ev.code == 0xF504 && hangman_runDialog() != 0)
                    || ev.code == 0xF503) {
                result = -1;
            }
        } else if (ev.type == 6) {
            if (hangman_handleTimerEvent((void *)&ev) != 0) {
                result = -1;
            } else {
                dm_hideCursor();
                hangman_resetDisplay();
                hangman_drawHangmanFigure();
                result = 2;
            }
        }
    }
    return result;
}
