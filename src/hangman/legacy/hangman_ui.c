/* ========================================================================
 * hangman_ui.c -- UI/drawing functions for HANGMAN.PDM
 * ========================================================================
 * Game board rendering, hangman figure drawing, letter tiles,
 * animations, and result message display.
 *
 * All drawing is done via DeskMate API (INT E0h) -- no direct video access.
 *
 * Reference: /disassembly/annotated/hangman.asm
 * ========================================================================
 */

#include "hangman.h"
#include <string.h>

/* ---- External string data (from hangman_data.c) --------------------- */
extern const char sz_Scoreboard[];
extern const char sz_CurrentGame[];
extern const char sz_ColHeaders[];
extern const char sz_CurPlayer[];
extern const char sz_CurWord[];
extern const char sz_WordsPerGameL[];
extern const char sz_NumGuesses[];
extern const char sz_NumWrong[];
extern const char sz_MaxWrong[];
extern const char sz_BlankPad[];
extern const char sz_Hangman[];
extern const char sz_YouveBeen[];
extern const char sz_Pardoned[];
extern const char sz_Hanged[];
extern const char sz_PressAnyKey[];
extern const char sz_PleaseWait[];
extern const Hangman_FigureStage g_hangmanStages[10];

/* ========================================================================
 * hangman_drawGameBoard -- Draw scoreboard, current game, column headers
 * Address: 0000:02D6
 * ======================================================================== */
void hangman_drawGameBoard(void)
{
    unsigned int playerAreaHeight;

    /* Set text attributes: bold+underline */
    dm_setTextAttr(0, 1, 3);
    /* Set colors: fg=2, bg=1 */
    dm_setColor(1, 2);

    /* Define scoreboard area (menu item for game controls) */
    playerAreaHeight = HANGMAN_ROW_HEIGHT * g_numPlayers;
    dm_defineMenu(HANGMAN_BOARD_Y, HANGMAN_BOARD_X,
                  0 /* unused */, playerAreaHeight + 0x0A50,
                  1);

    /* Reset text attributes */
    dm_setTextAttr(0, 1, 0);
    /* Header colors: fg=3, bg=1 */
    dm_setColor(3, 1);

    /* Draw "SCOREBOARD" header */
    dm_setCursorPos(HANGMAN_BOARD_X, HANGMAN_BOARD_Y);
    dm_drawString(sz_Scoreboard);

    /* Draw "CURRENT GAME" header */
    dm_setCursorPos(HANGMAN_BOARD_Y,
                    (int)(playerAreaHeight + HANGMAN_SCORE_BASE_Y));
    dm_drawString(sz_CurrentGame);

    /* Draw column headers */
    dm_setColor(2, 0);
    dm_setCursorPos(HANGMAN_COL_HDR_X, HANGMAN_COL_HDR_Y);
    dm_drawString(sz_ColHeaders);
}


/* ========================================================================
 * hangman_drawPlayerScores -- Draw per-player score rows in scoreboard
 * Address: 0000:0391
 * Iterates through all players, drawing name, words guessed, and score.
 * Highlights the current player with a different color.
 * ======================================================================== */
void hangman_drawPlayerScores(void)
{
    unsigned int i;
    unsigned int yPos;
    Hangman_PlayerData *pPlayer;

    pPlayer = &g_playerData[0];
    dm_setColor(2, 0);

    for (i = 0; i < g_numPlayers; i++) {
        /* Calculate Y position for this player row */
        yPos = HANGMAN_ROW_HEIGHT * i + HANGMAN_SCORE_BASE_Y;

        /* Highlight current player */
        if (i == g_currentPlayer) {
            dm_setColor(2, 3);
        }

        /* Draw blank padding then player name */
        dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)yPos);
        dm_drawString(sz_BlankPad);
        dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)yPos);
        dm_drawString(pPlayer->playerName);

        /* Draw words guessed count */
        dm_setCursorPos(HANGMAN_WORDS_COL_X, (int)yPos);
        hangman_printNumber((int)pPlayer->wordsGuessedDisplay);

        /* Draw score */
        dm_setCursorPos(HANGMAN_SCORE_COL_X, (int)yPos);
        hangman_printNumber((int)pPlayer->scoreDisplay);

        /* Reset color if was highlighted */
        if (i == g_currentPlayer) {
            dm_setColor(2, 0);
        }

        pPlayer++;
    }

    /* Draw current game info */
    hangman_drawCurrentGame();

    /* Reset colors */
    dm_setColor(0, 1);
    dm_setTextAttr(0, 1, 2);
}


/* ========================================================================
 * hangman_drawCurrentGame -- Draw "Current Game" info panel
 * Address: 0000:047C
 * Shows current player name, word number, words per game, guess counts.
 * ======================================================================== */
void hangman_drawCurrentGame(void)
{
    unsigned int baseY;
    unsigned int rowY;
    Hangman_PlayerData *pPlayer;

    baseY = HANGMAN_ROW_HEIGHT * g_numPlayers + HANGMAN_SCORE_BASE_Y;
    pPlayer = &g_playerData[g_currentPlayer];

    /* Row 1: "Current player: <name>" */
    rowY = baseY + HANGMAN_ROW_HEIGHT;
    dm_setColor(2, 0);
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_BlankPad);
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_CurPlayer);
    dm_drawString(pPlayer->playerName);

    /* Row 2: "Current word: <N>" */
    rowY += HANGMAN_ROW_HEIGHT;
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_BlankPad);
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_CurWord);
    hangman_printNumber((int)g_currentWordIndex);

    /* Row 3: "Words per game: <N>" */
    rowY += HANGMAN_ROW_HEIGHT;
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_BlankPad);
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_WordsPerGameL);
    hangman_printNumber((int)g_wordsPerGame);

    /* Row 4: "Number of guesses so far: <N>" */
    rowY += HANGMAN_ROW_HEIGHT;
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_BlankPad);
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_NumGuesses);
    hangman_printNumber((int)pPlayer->currentGuessCount);

    /* Row 5: "Number of wrong guesses: <N>" */
    rowY += HANGMAN_ROW_HEIGHT;
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_BlankPad);
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_NumWrong);
    hangman_printNumber((int)pPlayer->currentWrongCount);

    /* Row 6: "Maximum wrong guesses: <N>" */
    rowY += HANGMAN_ROW_HEIGHT;
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_BlankPad);
    dm_setCursorPos(HANGMAN_COL_HDR_Y, (int)rowY);
    dm_drawString(sz_MaxWrong);
    hangman_printNumber((int)g_maxWrongGuesses);
}


/* ========================================================================
 * hangman_drawInitialBoard -- Draw initial board with scores and tiles
 * Address: 0000:115C
 * ======================================================================== */
void hangman_drawInitialBoard(void)
{
    hangman_drawPlayerScores();
    hangman_drawLetterTiles();
    hangman_drawWordBlanks();
}


/* ========================================================================
 * hangman_drawLetterTiles -- Draw all 26 letter tiles (A-Z)
 * Address: 0000:116D
 * Draws letter tiles using bitmap resources loaded from DMGUF.
 * Each tile shows the letter; guessed letters are dimmed/marked.
 * ======================================================================== */
void hangman_drawLetterTiles(void)
{
    unsigned int i;

    for (i = 0; i < HANGMAN_NUM_LETTERS; i++) {
        if (g_letterBitmapPtrs[i] != 0) {
            /* Draw the letter bitmap at its computed position.
             * Position calculation depends on the letter index:
             * arranged in two rows of 13 letters each. */
            dm_drawBitmap(g_letterBitmapPtrs[i], 0, 0);
        }
    }
}


/* ========================================================================
 * hangman_drawWordBlanks -- Draw blank tiles for letters in current word
 * Address: 0000:1198
 * ======================================================================== */
void hangman_drawWordBlanks(void)
{
    unsigned int i;

    for (i = 0; i < g_currentWordLen; i++) {
        /* Draw a blank/underscore tile at the word display position.
         * The position is calculated by hangman_layoutWordTiles. */
        dm_drawChar('_');
    }
}


/* ========================================================================
 * hangman_redrawAfterDefine -- Redraw board after player definition change
 * Address: 0000:11C2
 * ======================================================================== */
void hangman_redrawAfterDefine(void)
{
    hangman_drawGameBoard();
    hangman_drawPlayerScores();
}


/* ========================================================================
 * hangman_initLetterTiles -- Initialize 26 letter tiles from resource
 * Address: 0000:11CC
 * Loads bitmap data for all 26 letter tiles from the DMGUF resource.
 * ======================================================================== */
void hangman_initLetterTiles(void)
{
    unsigned int i;

    for (i = 0; i < HANGMAN_NUM_LETTERS; i++) {
        g_letterBitmapPtrs[i] = dm_loadBitmap(i);
    }
}


/* ========================================================================
 * hangman_saveLetterTiles -- Save letter tile state to resource
 * Address: 0000:11FA
 * Saves bitmap handles for cleanup during exit.
 * ======================================================================== */
void hangman_saveLetterTiles(void)
{
    unsigned int i;

    for (i = 0; i < HANGMAN_NUM_LETTERS; i++) {
        if (g_letterBitmapPtrs[i] != 0) {
            dm_saveBitmap(g_letterBitmapPtrs[i]);
        }
    }
}


/* ========================================================================
 * hangman_adjustWordLayout -- Adjust word blank positions for word length
 * Address: 0000:122B
 * Centers the word blanks based on the current word length.
 * ======================================================================== */
void hangman_adjustWordLayout(void)
{
    /* The original calculates X offset to center the word display:
     * g_wordXOffset = (game_area_width - word_len * tile_width) / 2 */
    unsigned int tileWidth;
    unsigned int totalWidth;

    tileWidth = 0x28;  /* 40 pixels per letter tile */
    totalWidth = g_currentWordLen * tileWidth;

    if (totalWidth < HANGMAN_GAME_AREA_W) {
        g_wordXOffset = (HANGMAN_GAME_AREA_W - totalWidth) / 2;
    } else {
        g_wordXOffset = 0;
    }
}


/* ========================================================================
 * hangman_resetGuessedFlags -- Reset all 26 letter "guessed" flags to 0
 * Address: 0000:127F
 * ======================================================================== */
void hangman_resetGuessedFlags(void)
{
    unsigned int i;

    for (i = 0; i < HANGMAN_NUM_LETTERS; i++) {
        g_letterGuessed[i] = 0;
    }
}


/* ========================================================================
 * hangman_layoutWordTiles -- Calculate and position word letter tiles
 * Address: 0000:1463
 * Sets up the display positions for each letter of the current word.
 * ======================================================================== */
void hangman_layoutWordTiles(void)
{
    hangman_adjustWordLayout();
}


/* ========================================================================
 * hangman_clearRevealFlags -- Clear all word tile "revealed" flags
 * Address: 0000:14D3
 * ======================================================================== */
void hangman_clearRevealFlags(void)
{
    /* The original clears a flags array for each position in the word.
     * This tracks which letters have been revealed by correct guesses. */
    unsigned int i;

    for (i = 0; i < HANGMAN_WORD_BUF_SIZE; i++) {
        g_wordBuffer[i] = 0;
    }
}


/* ========================================================================
 * hangman_drawStartScreen -- Draw initial game screen layout
 * Address: 0000:1AE0
 * Sets up the gallows drawing area and game board background.
 * ======================================================================== */
void hangman_drawStartScreen(void)
{
    /* Clear game area with background color */
    dm_setColor(2, 3);
    dm_fillRect(0, 0, HANGMAN_GAME_AREA_W, HANGMAN_ROW_HEIGHT * 4, 0);

    /* Draw the gallows base (always visible) */
    hangman_drawGallowsPart(0);
}


/* ========================================================================
 * hangman_drawHangmanFigure -- Draw hangman figure at current wrong level
 * Address: 0000:1AFB
 * Draws all parts up to and including the current wrong guess count.
 * ======================================================================== */
void hangman_drawHangmanFigure(void)
{
    Hangman_PlayerData *pPlayer;
    unsigned int wrongCount;

    pPlayer = &g_playerData[g_currentPlayer];
    wrongCount = pPlayer->numWrongGuesses;

    if (wrongCount > 0) {
        hangman_drawHangmanParts(wrongCount);
    }
}


/* ========================================================================
 * hangman_drawHangmanParts -- Draw specific hangman body parts
 * Address: 0000:1B15
 * Parameters: parts = number of wrong guesses (1-10)
 * Draws all stages from 0 up to (parts-1), mapping through the
 * configurable max wrong guesses to determine which stages to show.
 * ======================================================================== */
void hangman_drawHangmanParts(unsigned int parts)
{
    unsigned int i;
    unsigned int stageCount;

    /* Map the number of wrong guesses to the number of drawing stages.
     * If maxWrongGuesses < 10, some stages are combined. */
    stageCount = parts;
    if (stageCount > 10) {
        stageCount = 10;
    }

    dm_setColor(0, 1);  /* black on white for the figure */

    for (i = 0; i < stageCount; i++) {
        hangman_drawHangmanStage(i);
    }
}


/* ========================================================================
 * hangman_drawWrongGuess -- Draw hangman part for Nth wrong guess
 * Address: 0000:1BC4
 * Parameters: wrongNum = which wrong guess (1-based)
 * Maps the wrong guess number to a drawing stage based on maxWrongGuesses.
 * ======================================================================== */
void hangman_drawWrongGuess(unsigned int wrongNum)
{
    unsigned int stage;

    /* Map wrong guess number to drawing stage.
     * With default maxWrongGuesses=7:
     *   wrong 1 -> stage 0+1 (gallows)
     *   wrong 2 -> stage 2 (head)
     *   wrong 3 -> stage 3 (body)
     *   wrong 4 -> stage 4 (left arm)
     *   wrong 5 -> stage 5 (right arm)
     *   wrong 6 -> stage 6 (left leg)
     *   wrong 7 -> stage 7 (right leg)
     * With fewer max guesses, multiple stages per wrong guess. */

    if (g_maxWrongGuesses >= 10) {
        /* 1:1 mapping */
        stage = wrongNum - 1;
    } else {
        /* Scale: stage = (wrongNum - 1) * 10 / maxWrongGuesses */
        stage = ((wrongNum - 1) * 10) / g_maxWrongGuesses;
    }

    if (stage < 10) {
        hangman_drawHangmanStage(stage);
    }
}


/* ========================================================================
 * hangman_drawCelebration -- Draw celebration animation (word guessed)
 * Address: 0000:1C30
 * ======================================================================== */
void hangman_drawCelebration(void)
{
    hangman_drawSmileyFace();
    hangman_showResultMessage(sz_YouveBeen, sz_Pardoned);
    hangman_drawPressAnyKey();
}


/* ========================================================================
 * hangman_drawGallowsPart -- Draw a section of the gallows structure
 * Address: 0000:1C9B
 * Parameters: partId = gallows part index (0 = base, 1 = crossbar, etc.)
 * ======================================================================== */
void hangman_drawGallowsPart(unsigned int partId)
{
    hangman_drawHangmanStage(partId);
}


/* ========================================================================
 * hangman_drawSmileyFace -- Draw smiley/celebration face animation
 * Address: 0000:1CCC
 * ======================================================================== */
void hangman_drawSmileyFace(void)
{
    /* Draw a happy face over the hangman area to celebrate a win.
     * Uses DeskMate drawing primitives for the face outline. */
    dm_setColor(0, 1);

    /* Eyes (dots) */
    dm_setCursorPos(170, 85);
    dm_drawChar('*');
    dm_setCursorPos(180, 85);
    dm_drawChar('*');

    /* Smile (arc approximation) */
    dm_drawLine(168, 95, 182, 95);
}


/* ========================================================================
 * hangman_showResultMessage -- Display "YOU'VE BEEN PARDONED/HANGED" msg
 * Address: 0000:1D7F
 * ======================================================================== */
void hangman_showResultMessage(const char *line1, const char *line2)
{
    unsigned int msgY;

    msgY = HANGMAN_ROW_HEIGHT * g_numPlayers + HANGMAN_SCORE_BASE_Y;
    msgY += HANGMAN_ROW_HEIGHT * 8;  /* below the game info rows */

    dm_setColor(0, 3);  /* highlight color */
    dm_setCursorPos(HANGMAN_BOARD_X, (int)msgY);
    dm_drawString(line1);

    msgY += HANGMAN_ROW_HEIGHT;
    dm_setCursorPos(HANGMAN_BOARD_X, (int)msgY);
    dm_drawString(line2);
}


/* ========================================================================
 * hangman_drawPressAnyKey -- Draw "(Press any key to continue)" prompt
 * Address: 0000:1E3C
 * ======================================================================== */
void hangman_drawPressAnyKey(void)
{
    unsigned int msgY;

    msgY = HANGMAN_ROW_HEIGHT * g_numPlayers + HANGMAN_SCORE_BASE_Y;
    msgY += HANGMAN_ROW_HEIGHT * 10;

    dm_setColor(2, 0);
    dm_setCursorPos(HANGMAN_BOARD_X, (int)msgY);
    dm_drawString(sz_PressAnyKey);
}


/* ========================================================================
 * hangman_drawDeathAnim -- Draw death animation (hangman complete)
 * Address: 0000:1E62
 * ======================================================================== */
void hangman_drawDeathAnim(void)
{
    /* Draw the complete hangman figure */
    hangman_drawHangmanParts(10);

    /* Show "HANGED!" message */
    hangman_showResultMessage(sz_YouveBeen, sz_Hanged);
    hangman_drawPressAnyKey();
}


/* ========================================================================
 * hangman_drawProfanityList -- Draw profanity filter word list
 * Address: 0000:1EAE
 * This function is used during SPELL check operations and draws
 * the list of filtered words. In normal gameplay it is not called.
 * ======================================================================== */
void hangman_drawProfanityList(void)
{
    /* This function processes the profanity filter list for display
     * during development/testing. In release builds it may be a no-op. */
}


/* ========================================================================
 * hangman_delayLoop -- Delay loop (wait for specified duration)
 * Address: 0000:222F
 * Uses DeskMate tick timer for delay.
 * ======================================================================== */
void hangman_delayLoop(unsigned int duration)
{
    unsigned int startTick;
    unsigned int currentTick;

    startTick = dm_getTick();

    for (;;) {
        dm_yield();
        currentTick = dm_getTick();
        if ((currentTick - startTick) >= duration) {
            break;
        }
    }
}


/* ========================================================================
 * hangman_drawHangmanStage -- Draw a specific hangman figure stage (0-10)
 * Address: 0000:22D7
 * Parameters: stage = drawing stage index (0-9)
 * Draws line segments from the coordinate data for the given stage.
 * ======================================================================== */
void hangman_drawHangmanStage(unsigned int stage)
{
    unsigned int i;
    unsigned int numSegs;
    const int *coords;

    if (stage >= 10) {
        return;
    }

    numSegs = g_hangmanStages[stage].numSegments;
    coords = g_hangmanStages[stage].coords;

    for (i = 0; i < numSegs; i++) {
        dm_drawLine(coords[i * 4],
                    coords[i * 4 + 1],
                    coords[i * 4 + 2],
                    coords[i * 4 + 3]);
    }
}


/* ========================================================================
 * hangman_wordAnimEnter -- Word entry animation
 * Address: 0000:2558
 * ======================================================================== */
void hangman_wordAnimEnter(void)
{
    hangman_animSequence();
}


/* ========================================================================
 * hangman_wordAnimExit -- Word exit/transition animation
 * Address: 0000:2591
 * ======================================================================== */
void hangman_wordAnimExit(void)
{
    hangman_animCleanup();
}


/* ========================================================================
 * hangman_showLetterAnim -- Letter reveal animation
 * Address: 0000:260F
 * Parameters: letterIndex = index of letter being revealed (0-25)
 * ======================================================================== */
void hangman_showLetterAnim(unsigned int letterIndex)
{
    (void)letterIndex;
    hangman_animFrame();
    hangman_animFlash();
}


/* ========================================================================
 * hangman_animFrame -- Single animation frame update
 * Address: 0000:2698
 * ======================================================================== */
void hangman_animFrame(void)
{
    dm_yield();
    hangman_delayLoop(2);
}


/* ========================================================================
 * hangman_animFlash -- Flash animation effect
 * Address: 0000:26CB
 * ======================================================================== */
void hangman_animFlash(void)
{
    dm_setColor(3, 0);
    dm_yield();
    hangman_delayLoop(1);
    dm_setColor(2, 0);
}


/* ========================================================================
 * hangman_animSequence -- Multi-step animation sequence
 * Address: 0000:2702
 * ======================================================================== */
void hangman_animSequence(void)
{
    unsigned int i;

    for (i = 0; i < 3; i++) {
        hangman_animFrame();
        hangman_animFlash();
    }
}


/* ========================================================================
 * hangman_drawWordStatus -- Draw current word status (revealed/hidden)
 * Address: 0000:2778
 * Shows the word with guessed letters revealed and unguessed as blanks.
 * ======================================================================== */
void hangman_drawWordStatus(void)
{
    unsigned int i;
    char ch;

    dm_setColor(0, 1);

    for (i = 0; i < g_currentWordLen; i++) {
        ch = g_wordBuffer[i];
        if (ch != 0) {
            dm_drawChar((unsigned int)ch);
        } else {
            dm_drawChar('_');
        }
    }
}


/* ========================================================================
 * hangman_showWaitMessage -- Display "Please wait while a word is chosen"
 * Address: 0000:27A3
 * ======================================================================== */
void hangman_showWaitMessage(void)
{
    dm_setColor(2, 0);
    dm_setCursorPos(HANGMAN_BOARD_X, HANGMAN_COL_HDR_Y);
    dm_drawString(sz_PleaseWait);
}


/* ========================================================================
 * hangman_drawScoreUpdate -- Draw score update after round
 * Address: 0000:2864
 * ======================================================================== */
void hangman_drawScoreUpdate(void)
{
    hangman_drawPlayerScores();
}


/* ========================================================================
 * hangman_animCleanup -- Clean up animation state
 * Address: 0000:294E
 * ======================================================================== */
void hangman_animCleanup(void)
{
    dm_setColor(2, 0);
}
