/* ========================================================================
 * board.c -- HANGMAN.PDM board redraw helpers: letter buttons, word tiles
 * ======================================================================== */
#include "areab.h"

/* address: 0000:0DF0 hangman_resetDisplay -- rebuild the menu bar, letter
 * buttons and board, then restore the default colour / text attributes. */
void hangman_resetDisplay(void)
{
    hangman_setupMenuBar();
    hangman_drawLetterTiles();
    hangman_drawGameBoard();
    dm_setColor(0, 1);
    dm_setTextAttr(0, 1, 2);
}

/* address: 0000:0E18 hangman_refreshBoard -- repaint after a dialog that
 * could not save the screen under it. Without a game window only the menu
 * bar is rebuilt; otherwise the figure screen or the scores, word blanks
 * and the current player's gallows. */
void hangman_refreshBoard(void)
{
    dm_hideCursor();
    if (g_windowHandle != 0) {
        hangman_resetDisplay();
        if (HANGMAN_SHOWN != 0) {
            hangman_drawHangmanFigure();
        } else {
            hangman_drawPlayerScores();
            hangman_drawWordBlanks();
            hangman_drawWrongGuess(g_players[CUR_PLAYER].st.wrong);
        }
    } else {
        hangman_setupMenuBar();
    }
    dm_showCursor();
}

/* address: 0000:115C hangman_drawInitialBoard -- scores and word blanks,
 * plus the gallows figure unless the round is over. */
void hangman_drawInitialBoard(void)
{
    hangman_drawPlayerScores();
    hangman_drawWordBlanks();
    if (ROUND_OVER == 0) {
        hangman_drawHangmanFigure();
    }
}

/* address: 0000:116D hangman_drawLetterTiles -- draw the 26 letter buttons */
void hangman_drawLetterTiles(void)
{
    int i;

    for (i = 0; i < NUM_LETTERS; i++) {
        dm_drawBitmap(g_letterBitmaps[i], &g_letterTiles[i]);
    }
}

/* address: 0000:1198 hangman_drawWordBlanks -- draw every tile of the
 * current word (handle -1: draw the descriptor's own image) */
void hangman_drawWordBlanks(void)
{
    int i;

    for (i = 0; WORD_LEN > i; i++) {
        dm_drawBitmap(-1, &g_wordTiles[i]);
    }
}

/* address: 0000:11C2 hangman_redrawAfterDefine -- undo the word-tile
 * offsets, lay the tiles out again for the new player count, redraw. */
void hangman_redrawAfterDefine(void)
{
    hangman_adjustWordLayout();
    hangman_layoutWordTiles();
    hangman_drawWordBlanks();
}

/* address: 0000:11CC hangman_initLetterTiles -- load the 26 letter-button
 * bitmaps, keep their handles, and draw them */
void hangman_initLetterTiles(void)
{
    int i;

    for (i = 0; i < NUM_LETTERS; i++) {
        g_letterBitmaps[i] = dm_loadBitmap(&g_letterTiles[i]);
    }
    hangman_drawLetterTiles();
}

/* address: 0000:11FA hangman_saveLetterTiles -- release the letter-button
 * bitmaps (dm_saveBitmap with each handle) at cleanup */
void hangman_saveLetterTiles(void)
{
    int i;

    for (i = 0; i < NUM_LETTERS; i++) {
        dm_saveBitmap(g_letterBitmaps[i], &g_letterTiles[i]);
    }
}

/* address: 0000:122B hangman_adjustWordLayout -- remove the offsets that
 * hangman_layoutWordTiles added to each word tile and clear the word area */
void hangman_adjustWordLayout(void)
{
    int i;

    for (i = 0; WORD_LEN > i; i++) {
        g_wordTiles[i].x -= WORD_OFS_X;
        g_wordTiles[i].y -= WORD_OFS_Y;
    }
    dm_fillRect(WORD_OFS_X - 0x78, WORD_OFS_Y + 0xCD0,
                0x190 * WORD_LEN + 0x3C, 0x294, 0);
}

/* address: 0000:127F hangman_resetGuessedFlags -- mark all letters as not
 * guessed and redraw the letter buttons */
void hangman_resetGuessedFlags(void)
{
    int i;

    for (i = 0; i < NUM_LETTERS; i++) {
        g_letterTiles[i].guessed = 0;
    }
    hangman_drawLetterTiles();
}

/* address: 0000:1463 hangman_layoutWordTiles -- centre the word: compute
 * the x/y offsets from the word length and player count, add them to each
 * tile, mark it shown and pick its letter glyph. */
void hangman_layoutWordTiles(void)
{
    int i;

    WORD_OFS_X = (0x50 - (WORD_LEN << 2)) / 2 * 100;
    WORD_OFS_Y = 0x6E * g_numPlayers;
    for (i = 0; i < WORD_LEN; i++) {
        g_wordTiles[i].shown = 1;
        g_wordTiles[i].x += WORD_OFS_X;
        g_wordTiles[i].y += WORD_OFS_Y;
        g_wordTiles[i].glyph = LETTER_GLYPHS[(signed char)WORD_TEXT[i]];
    }
}

/* address: 0000:14D3 hangman_clearRevealFlags -- hide every word letter */
void hangman_clearRevealFlags(void)
{
    int i;

    for (i = 0; i < WORD_LEN; i++) {
        g_wordTiles[i].revealed = 0;
    }
}

/* address: 0000:1AE0 hangman_drawStartScreen -- size the game window to
 * the player count and create it (handle kept for cleanup / redraws) */
void hangman_drawStartScreen(void)
{
    DG16(0x0EDE) = 0xDC * g_numPlayers + 0x7D4;
    g_windowHandle = dm_initScrollbar((char *)0x0ED8);
}
