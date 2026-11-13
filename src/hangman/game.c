/* ========================================================================
 * game.c -- HANGMAN.PDM area A: saved-game check, scoreboard, game loop,
 * input dispatch, guess scoring (0000:00F3 .. 0000:0DD7)
 * ======================================================================== */
#include "hangman.h"

/* DGROUP strings / descriptors used here (original offsets) */
#define S_BLANK12       ((char *)0x0F20)    /* 12 spaces */
#define S_TITLE         ((char *)0x0F0C)    /* "Hangman" */
#define S_SCOREBOARD    ((char *)0x10DC)    /* "             SCOREBOARD   ..." */
#define S_CURRENT_GAME  ((char *)0x1104)    /* "            CURRENT GAME  ..." */
#define S_SCORE_HEADER  ((char *)0x112C)    /* "Player       Words Guessed     Score" */
#define S_BLANK_NAME    ((char *)0x1152)    /* 12 spaces (erases a name) */
#define S_CUR_PLAYER    ((char *)0x1160)    /* "Current player: " */
#define S_CUR_WORD      ((char *)0x1172)    /* "Current word: " */
#define S_WORDS_PER     ((char *)0x1182)    /* "Words per game: " */
#define S_GUESSES       ((char *)0x1194)    /* "Number of guesses so far: " */
#define S_WRONG         ((char *)0x11B0)    /* "Number of wrong guesses: " */
#define S_MAX_WRONG     ((char *)0x11CA)    /* "Maximum wrong guesses: " */
#define S_RESULT_BOX    ((char *)0x137A)    /* result message frame */
#define S_PARDONED      ((char *)0x1386)    /* "PARDONED!" */
#define S_HANGED        ((char *)0x1390)    /* " HANGED!" */

#define MB_RESTORE      ((char *)0x0EBA)    /* "restore saved game?" box */
#define MB_OVERWRITE    ((char *)0x0EC6)    /* "replace saved game?" box */
#define MB_NEW_GAME     ((char *)0x0ECC)    /* end-of-game "play again?" box */
#define MB_SAVE_RESULT  ((char *)0x0ED2)    /* save result box; text word at 0ED5 */
#define MB_SAVE_TEXT    DG16(0x0ED5)
#define T_SAVE_FAILED   0x12EE
#define T_SAVE_OK       0x12CC
#define ABOUT_FORM      ((char *)0x0EFE)

#define MB_YES          0xF701
#define MB_NO           0xF702              /* loadConfig: quit */
#define MB_RESTORE_YES  0xF703
#define MB_QUIT         0xF704

/* Menu / control ids (dm event code, type 3) */
#define MENU_FIRST      0xF500
#define MENU_LAST       0xF50C
#define TILE_FIRST      0xF546              /* letter tiles A..Z */
#define TILE_LAST       0xF55F

#define EV_NONE   0
#define EV_KEY    1
#define EV_MENU   3
#define EV_TIMER  6

/* Board geometry (DeskMate virtual coordinates) */
#define ROW_H     0xDC
#define ROW_Y0    0x44C

/* Letter tiles: 26 records of 0x14 bytes at 00CA, "used" flag at +0x10.
 * Word tiles: records of 0x17 bytes at 02D2, "revealed" flag at +0x10. */
#define LETTER_TILE(i)  ((char *)(0xCA + (i) * 0x14))
#define LETTER_USED(i)  DG8(0xDA + (i) * 0x14)
#define WORD_TILE(i)    ((char *)(0x2D2 + (i) * 0x17))
#define WORD_SHOWN(i)   DG8(0x2E2 + (i) * 0x17)

/* DS (= DGROUP in the small model), as the original's `mov [bp-4],ds` */
unsigned hm_getDS(void);
#pragma aux hm_getDS = "mov ax,ds" value [ax] modify exact [ax];

/* address: 0000:00F3 hangman_loadConfig
 * Look for a saved game. g_configDesc describes it to DeskMate; when
 * dm_setTitle fails (-1/-2) or dm_getTitle reports nothing, a new game is
 * defined (HM_READY). Otherwise the saved record (0x5A bytes, far pointer at
 * 0EF3) is copied to ABA8 and the user is asked whether to restore it:
 * F703 = restore (returns restoreGame's result), F702 = quit (-1).
 * The runtime routine called "_sscanf" is really movedata(srcseg, srcoff,
 * dstseg, dstoff, n). */
int hangman_loadConfig(void)
{
    int r;                  /* bp-2 */
    unsigned dstOff;        /* bp-6 */
    unsigned dstSeg;        /* bp-4 */

    r = dm_setTitle(g_configDesc);
    if (r == -1 || r == -2) {
        g_haveSavedGame = g_configOpen = 0;
        return HM_READY;
    }
    g_configOpen = 1;
    if (dm_getTitle(g_configDesc) != 0) {
        g_haveSavedGame = 0;
        return HM_READY;
    }
    g_haveSavedGame = 1;
    dstOff = 0xABA8;
    dstSeg = hm_getDS();
    _sscanf(DG16(0x0EF5), DG16(0x0EF3), dstSeg, dstOff, 0x5A);
    r = dm_msgBox(MB_RESTORE);
    if (r == MB_RESTORE_YES) {
        return hangman_restoreGame();
    }
    if (r == MB_NO) {
        return HM_ERROR;
    }
    return HM_READY;
}

/* address: 0000:0181 hangman_validateSaveData
 * Sanity-check a saved-game record: 1..4 players, 1..10 words per game,
 * 3..12 wrong guesses, per-player counters in range and names of at most
 * 12 characters. Returns 1 if valid, 0 if not. */
int hangman_validateSaveData(HmSave *save)
{
    char *name;             /* bp-2 */
    int n;                  /* bp-4 */
    HmStats *st;            /* bp-6 */
    int i;                  /* bp-8 */

    n = save->numPlayers;
    if (n < 1 || n > 4) {
        return 0;
    }
    if (save->wordsPerGame < 1 || save->wordsPerGame > 10) {
        return 0;
    }
    if (save->maxWrongGuesses < 3 || save->maxWrongGuesses > 12) {
        return 0;
    }
    for (i = 0; ; i++) {
        name = save->players[i].name;
        if (i >= n) {
            return 1;
        }
        st = &save->players[i].st;
        if (st->guesses > 0x15 || st->wrong > 12 || st->lettersLeft > 9) {
            return 0;
        }
        if ((unsigned)st->wins > (unsigned)save->wordsPerGame) {
            return 0;
        }
        if ((unsigned)save->wordsPerGame < st->played) {
            return 0;
        }
        if ((unsigned)_strlen(name) > 12) {
            return 0;
        }
    }
}

/* address: 0000:0229 hangman_setupMenuBar
 * Paint the window background and title area: background fill, a frame
 * sized from the screen metrics, then "Hangman" centred between blanks.
 * (The dm_* names of the metric calls are unverified guesses.) */
void hangman_setupMenuBar(void)
{
    int mul;
    int div;

    dm_setColor(0, 1);
    dm_setTextAttr(0, 1, 2);
    dm_setCursorPos(0, dm_getScreenHeight(dm_getScreenWidth(0x122) + 0x158));
    dm_setBackground();
    mul = dm_multiply(0x294);
    div = dm_divide(0x64);
    dm_defineMenu(div - 1, mul, 0x1EDC, 0x1564, 0);
    DG8(0x00C4) = 1;
    dm_setTimer(0xB4);
    dm_setCursorPos(0x960, 0x24);
    dm_drawString(S_BLANK12);
    dm_drawString(S_TITLE);
    dm_drawString(S_BLANK12);
    dm_drawString(S_BLANK12);
}

/* address: 0000:02D6 hangman_drawGameBoard
 * Draw the scoreboard frame (height grows with the number of players) and
 * its SCOREBOARD / CURRENT GAME / column headings. */
void hangman_drawGameBoard(void)
{
    dm_setTextAttr(0, 1, 3);
    dm_setColor(1, 2);
    dm_defineMenu(0x64, 0x294, 0xF3C, ROW_H * g_numPlayers + 0xA50, 1);
    dm_setTextAttr(0, 1, 0);
    dm_setColor(3, 1);
    dm_setCursorPos(0x64, 0x294);
    dm_drawString(S_SCOREBOARD);
    dm_setCursorPos(0x64, ROW_H * g_numPlayers + ROW_Y0);
    dm_drawString(S_CURRENT_GAME);
    dm_setColor(2, 0);
    dm_setCursorPos(0xC8, 0x370);
    dm_drawString(S_SCORE_HEADER);
}

/* address: 0000:0391 hangman_drawPlayerScores
 * One scoreboard row per player (name, words guessed, score), the current
 * player highlighted; then the CURRENT GAME panel. */
void hangman_drawPlayerScores(void)
{
    int y;                  /* bp-2 */
    int i;                  /* bp-4 */
    HmPlayer *p;            /* bp-6 */

    p = g_players;
    dm_setColor(2, 0);
    for (i = 0; i < g_numPlayers; i++, p++) {
        y = ROW_H * i + ROW_Y0;
        dm_setCursorPos(0xC8, y);
        if (i == g_curPlayer) {
            dm_setColor(2, 3);
        }
        dm_drawString(S_BLANK_NAME);
        dm_setCursorPos(0xC8, y);
        dm_drawString(p->name);
        dm_setCursorPos(0x7D0, y);
        hangman_printNumber(p->st.wins);
        dm_setCursorPos(0xD48, y);
        hangman_printNumber(p->st.score);
        if (i == g_curPlayer) {
            dm_setColor(2, 0);
        }
    }
    hangman_drawCurrentGame();
    dm_setColor(0, 1);
    dm_setTextAttr(0, 1, 2);
}

/* address: 0000:047C hangman_drawCurrentGame
 * CURRENT GAME panel below the scoreboard: current player (name centred),
 * words per game, current word number, guesses, wrong guesses, maximum. */
void hangman_drawCurrentGame(void)
{
    int row;                /* bp-2 */
    HmPlayer *p;            /* bp-4 */
    int len;                /* bp-6 */

    row = g_numPlayers;
    p = &g_players[g_curPlayer];
    row++;
    dm_setCursorPos(0x1F4, ROW_H * row + ROW_Y0);
    dm_drawString(S_CUR_PLAYER);
    len = _strlen(p->name);
    dm_setColor(2, 3);
    dm_setCursorPos(-((len / 2 + len / 11) * 100 - 0xC80), ROW_H * row + ROW_Y0);
    dm_drawString(p->name);

    row++;
    dm_setCursorPos(0x1F4, ROW_H * row + ROW_Y0);
    dm_setColor(2, 0);
    dm_drawString(S_WORDS_PER);
    dm_setCursorPos(0xC1C, ROW_H * row + ROW_Y0);
    dm_setColor(2, 3);
    hangman_printNumber(g_wordsPerGame);

    row++;
    dm_setCursorPos(0x1F4, ROW_H * row + ROW_Y0);
    dm_setColor(2, 0);
    dm_drawString(S_CUR_WORD);
    dm_setCursorPos(0xC1C, ROW_H * row + ROW_Y0);
    dm_setColor(2, 3);
    hangman_printNumber(g_wordNumber);

    row++;
    dm_setCursorPos(0x1F4, ROW_H * row + ROW_Y0);
    dm_setColor(2, 0);
    dm_drawString(S_GUESSES);
    dm_setCursorPos(0xC1C, ROW_H * row + ROW_Y0);
    dm_setColor(2, 3);
    hangman_printNumber(p->st.guesses);

    row++;
    dm_setCursorPos(0x1F4, ROW_H * row + ROW_Y0);
    dm_setColor(2, 0);
    dm_drawString(S_WRONG);
    dm_setCursorPos(0xC1C, ROW_H * row + ROW_Y0);
    dm_setColor(2, 3);
    hangman_printNumber(p->st.wrong);

    row++;
    dm_setCursorPos(0x1F4, ROW_H * row + ROW_Y0);
    dm_setColor(2, 0);
    dm_drawString(S_MAX_WRONG);
    dm_setCursorPos(0xC1C, ROW_H * row + ROW_Y0);
    dm_setColor(2, 3);
    hangman_printNumber(g_maxWrongGuesses);
}

/* address: 0000:06E2 hangman_printNumber
 * Draw n as two characters: tens digit (blank when 0) and units digit.
 * Signed division; values >= 100 give a non-digit first character. */
void hangman_printNumber(int n)
{
    int tens;               /* bp-2 */

    tens = n / 10;
    dm_drawChar(tens != 0 ? tens + '0' : ' ');
    dm_drawChar(n % 10 + '0');
}

/* address: 0000:071B hangman_initRoundState
 * Start of a word for one player: guesses = wrong = 0, letters left =
 * low byte of g_wordLen. */
void hangman_initRoundState(HmStats *st)
{
    st->lettersLeft = (unsigned char)g_wordLen;
    st->wrong = st->guesses = 0;
}

/* address: 0000:0737 hangman_gameLoop
 * Play words until g_wordNumber passes g_wordsPerGame, then offer a new
 * game (MB_QUIT ends). playRound -1 quits; -2 (restore / new game from the
 * menu) skips the end-of-game box and redraws. */
void hangman_gameLoop(void)
{
    int r;                  /* bp-2; deliberately not initialised (original) */

    for (;;) {
        while (g_wordNumber <= g_wordsPerGame) {
            g_wordLen = hangman_chooseWord();
            r = hangman_playRound();
            if (r == -1) {
                return;
            }
            if (r == -2) {
                break;
            }
            g_wordNumber++;
        }
        if (r != -2) {
            dm_showCursor();
            if (dm_msgBox(MB_NEW_GAME) == MB_QUIT) {
                return;
            }
            dm_hideCursor();
            hangman_newGame();
        }
        dm_initWindow(g_windowHandle);
        hangman_drawStartScreen();
        hangman_resetDisplay();
    }
}

/* address: 0000:0795 hangman_playRound
 * Every player in turn (from g_curPlayer) plays the current word. Returns
 * 0 when all have played (g_curPlayer reset), -1 to quit (after the
 * optional save prompt), or processInput's nonzero result (-2). */
int hangman_playRound(void)
{
    int r;                  /* bp-2 */

    for (; g_curPlayer < g_numPlayers; g_curPlayer++) {
        if (g_resumeRound == 0) {
            g_word[0] = 0;
            if (hangman_playWord(g_word, g_wordLen) != 0) {
                dm_showCursor();
                if (g_gameSaved == 0 && hangman_promptSaveOnExit() == MB_RESTORE_YES
                        && hangman_saveGame() == -1) {
                    MB_SAVE_TEXT = T_SAVE_FAILED;
                    dm_msgBox(MB_SAVE_RESULT);
                }
                return -1;
            }
        } else {
            g_resumeRound = 0;
        }
        hangman_layoutWordTiles();
        hangman_clearRevealFlags();
        hangman_initRoundState(&g_players[g_curPlayer].st);
        hangman_drawInitialBoard();
        r = hangman_processInput();
        hangman_adjustWordLayout();
        hangman_resetGuessedFlags();
        if (r != 0) {
            return r;
        }
        dm_setColor(2, 3);
        dm_fillRect(0x9C4, ROW_H * g_numPlayers + 0x528, 0x4B0, 0xDC, 0);
    }
    g_curPlayer = 0;
    return 0;
}

/* address: 0000:086A hangman_processInput
 * Event loop for one player's word. Letters (keys or tile clicks) are
 * marked used and scored through hangman_checkGuess; menu commands go to
 * hangman_handleMenuAction, timer events to hangman_handleTimerEvent.
 * While state == 0 no new event is fetched: the current one is processed
 * again (state is the last checkGuess result: 0 = continue, -1 = word over;
 * -2 = first pass). Returns 0 when the word is over (after an empty event)
 * or a menu result of -3, else the nonzero menu result / -1 from the timer.
 */
int hangman_processInput(void)
{
    int state;              /* bp-2 */
    HmEvent ev;             /* bp-0Ah */
    HmEvent prev;           /* bp-12h (type and code only) */
    int r;                  /* bp-14h */

    state = HM_READY;
    dm_showCursor();
    for (;;) {
        if (state != 0) {
            if (state == HM_READY) {
                g_roundOver = DG16(0x0EEA) = state = 0;
            }
            for (;;) {
                dm_getEvent(&ev);
                if (ev.type == EV_NONE || ev.type == EV_TIMER
                        || (ev.type == EV_MENU && ev.code <= MENU_LAST)) {
                    break;
                }
                dm_yield();
            }
            if (state == -1 && ev.type == EV_NONE) {
                r = 0;
                break;
            }
        }
        prev.type = ev.type;
        prev.code = ev.code;
        dm_replyEvent(&ev);
        r = hangman_mapKeyToLetter(&prev, &ev);
        if (r != -1) {
            if (LETTER_USED(r) == 1) {
                ev.type = EV_NONE;
                hangman_showAlreadyGuessed(r + 'A');
                continue;
            }
            LETTER_USED(r) = 1;
            dm_drawBitmap(g_letterBitmaps[r], LETTER_TILE(r));
            state = hangman_checkGuess(r + 'A');
            continue;
        }
        if (ev.type == EV_MENU && ev.code <= MENU_LAST) {
            r = hangman_handleMenuAction(ev.code);
            if (r != 0) {
                break;
            }
        }
        if (ev.type == EV_TIMER) {
            if (hangman_handleTimerEvent((unsigned char *)&ev) != 0) {
                r = -1;
                break;
            }
            hangman_refreshBoard();
        }
    }
    dm_hideCursor();
    if (r == -3) {
        return 0;
    }
    return r;
}

/* address: 0000:09A2 hangman_mapKeyToLetter
 * Letter index 0..25 for a letter-tile click (any time) or an A-Z key that
 * is not a repeat of the previous key event; -1 otherwise. */
int hangman_mapKeyToLetter(HmEvent *prev, HmEvent *ev)
{
    unsigned c;             /* bp-2 */

    if (ev->type == EV_MENU && ev->code >= TILE_FIRST && ev->code <= TILE_LAST) {
        dm_yield();
        return ev->code - TILE_FIRST;
    }
    if (ev->type == EV_KEY) {
        c = dm_keyToChar(ev->code);
        if (c >= 'A' && c <= 'Z') {
            if (prev->type == EV_NONE || dm_keyToChar(prev->code) != c) {
                return c - 'A';
            }
        }
    }
    return -1;
}

/* address: 0000:0A0C hangman_handleMenuAction
 * Menu commands F500..F50C. Returns -2 = start over (new/restored game),
 * -3 = players changed during a finished word, -1 = quit, 0 = continue. */
int hangman_handleMenuAction(unsigned id)
{
    switch (id - MENU_FIRST) {
    case 0:     /* F500 New Game */
        if (hangman_defineGame() == HM_READY) {
            return HM_READY;
        }
        break;
    case 1:     /* F501 Save */
        if (g_haveSavedGame == 1 && dm_msgBox(MB_OVERWRITE) != MB_YES) {
            break;
        }
        MB_SAVE_TEXT = hangman_saveGame() == -1 ? T_SAVE_FAILED : T_SAVE_OK;
        dm_msgBox(MB_SAVE_RESULT);
        break;
    case 2:     /* F502 Restore */
        hangman_restoreGame();
        return HM_READY;
    case 11:    /* F50B Add Player */
        if (hangman_addPlayerDialog() == -1) {
            break;
        }
        /* fall through */
    case 12:    /* F50C Delete Player */
        if (id == 0xF50C) {
            id = hangman_deletePlayerDialog();
            if (id == 0xFFFF) {
                break;
            }
        }
        hangman_updatePlayerCount(g_numPlayers);
        hangman_redrawAfterDefine();
        hangman_drawGameBoard();
        hangman_drawPlayerScores();
        dm_initWindow(g_windowHandle);
        hangman_drawStartScreen();
        if (g_roundOver != 0) {
            hangman_drawHangmanFigure();
        } else {
            hangman_drawWrongGuess(g_players[g_curPlayer].st.wrong);
        }
        if (id == 0xFFFE) {
            return -3;
        }
        break;
    case 10:    /* F50A Define Players */
        if (hangman_definePlayersDialog() == -1) {
            break;
        }
        dm_setColor(2, 3);
        dm_fillRect(0x9C4, ROW_H * g_numPlayers + 0x528, 0x4B0, 0xDC, 0);
        hangman_drawPlayerScores();
        break;
    case 5:     /* F505 About */
        hangman_aboutBoxHandler(ABOUT_FORM);
        hangman_refreshBoard();
        break;
    case 4:     /* F504 (runs a program; quits if it returns nonzero) */
        if (hangman_runDialog() == 0) {
            break;
        }
        /* fall through */
    case 3:     /* F503 Quit */
        if (g_gameSaved == 0 && hangman_promptSaveOnExit() == MB_RESTORE_YES
                && hangman_saveGame() == -1) {
            MB_SAVE_TEXT = T_SAVE_FAILED;
            dm_msgBox(MB_SAVE_RESULT);
        }
        return -1;
    }
    return 0;
}

/* address: 0000:0B79 hangman_checkGuess
 * Score letter (ASCII) for the current player: reveal every occurrence in
 * g_word (the runtime "_strstr" is really strchr) or count a wrong guess.
 * result 1 = word solved, 2 = hanged; on either the round is over and the
 * player's words-played count goes up. Returns -1 if over, else 0. */
int hangman_checkGuess(int letter)
{
    char *pos;              /* bp-2 */
    int idx;                /* bp-4 */
    int result;             /* bp-6 */
    HmStats *st;            /* bp-8 */
    int wrong;              /* bp-0Ah */

    result = 0;
    wrong = 1;
    st = &g_players[g_curPlayer].st;
    st->guesses++;
    pos = (char *)_strstr(g_word, letter);
    if (pos != 0) {
        wrong = 0;
        do {
            idx = (int)pos - (int)g_word;
            WORD_SHOWN(idx) = 1;
            dm_drawBitmap(-1, WORD_TILE(idx));
            if (--st->lettersLeft == 0) {
                result = 1;
                break;
            }
            pos = (char *)_strstr(pos + 1, letter);
        } while (pos != 0);
    } else {
        st->wrong++;
        if ((unsigned)st->wrong >= (unsigned)g_maxWrongGuesses) {
            result = 2;
        }
    }
    if (result != 0) {
        g_roundOver = 1;
        st->played++;
    }
    hangman_updateAfterGuess(result, wrong);
    if (result != 0) {
        return -1;
    }
    return 0;
}

/* address: 0000:0C47 hangman_updateAfterGuess
 * Update the guess counters and gallows after a guess; at the end of a
 * word (result 1 = solved, 2 = hanged) play the win/lose sequence, redraw
 * the scoreboard and pause (3 s after a hanging, else 5 s). */
void hangman_updateAfterGuess(int result, int wrong)
{
    HmStats *st;            /* bp-2 */
    long delay;

    st = &g_players[g_curPlayer].st;
    dm_hideCursor();
    dm_setCursorPos(0xC1C, ROW_H * g_numPlayers + 0x7BC);
    dm_setColor(2, 3);
    hangman_printNumber(st->guesses);
    if (wrong != 0) {
        dm_setCursorPos(0xC1C, ROW_H * g_numPlayers + 0x898);
        hangman_printNumber(st->wrong);
    }
    dm_setColor(0, 1);
    dm_setActiveWin(g_windowHandle);
    hangman_drawHangmanStage((int *)0x0A20, st->wrong);
    if (result != 0) {
        hangman_drawCelebration();
        if (result == 1) {
            hangman_handleWin(st);
        } else {
            hangman_handleLose();
        }
        dm_setActiveWin(g_cursorHandle);
        hangman_drawPressAnyKey();
        hangman_drawPlayerScores();
        dm_setActiveWin(g_windowHandle);
        if (result == 2) {
            hangman_drawDeathAnim();
            delay = 0xBB8;
        } else {
            delay = 0x1388;
        }
        hangman_delayLoop(delay);
        g_gameSaved = 0;
    }
    dm_setActiveWin(g_cursorHandle);
    dm_showCursor();
}

/* address: 0000:0D4B hangman_handleWin
 * Word solved: draw gallows stages 0..5, the smiley and "PARDONED!", then
 * count the win and add (max wrong - wrong) to the score. */
void hangman_handleWin(HmStats *st)
{
    int i;                  /* si */

    DG16(0xABA6) = i = 0;
    for (; i <= 5; i++) {
        hangman_drawHangmanStage((int *)0x0A20, i);
    }
    hangman_drawSmileyFace();
    hangman_showResultMessage(S_RESULT_BOX, S_PARDONED);
    st->wins++;
    st->score += g_maxWrongGuesses - st->wrong;
}

/* address: 0000:0D9C hangman_handleLose -- word lost: "HANGED!" */
void hangman_handleLose(void)
{
    hangman_drawGallowsPart((int *)0x0B80, -1);
    dm_setTextAttr(0, 0, 3);
    dm_drawAt(0xA6A, (char *)0x0EE0, 0);
    hangman_showResultMessage(S_RESULT_BOX, S_HANGED);
}
