/* ========================================================================
 * main.c -- HANGMAN.PDM program lifecycle: entry, init, cleanup
 * ======================================================================== */
#include "hangman.h"

/* address: 0000:0010 -- called by the MSC startup as _main() */
void hangman_main(void)
{
    if (hangman_init() == HM_READY) {
        hangman_gameLoop();
    }
    hangman_cleanup();
}

/* address: 0000:001F
 * Load DeskMate resources, set up the window and menus, then either restore
 * a saved game or ask for game settings. Returns HM_READY when a game can
 * start, 0 when the user backed out. Exits the program on resource failure.
 */
int hangman_init(void)
{
    int result;

    g_cursorHandle = dm_initCursor();
    if (g_cursorHandle == HM_ERROR) {
        _exit(-1);
    }
    if (dm_loadDmguf() == HM_ERROR) {
        dm_cleanupCursor();
        _exit(-1);
    }
    if (hangman_checkDmApiEvent(HM_EVT_WORD_LIST) == 0) {
        if (dm_loadSpell() == HM_ERROR) {
            dm_cleanupCursor();
            dm_unloadRes();
            _exit(-1);
        }
        hangman_initGameState();
        g_spellLoaded = 1;
    }

    dm_setAppTitle(g_titleDesc);
    dm_initApp();
    dm_setBorder();
    dm_showStatusBar();
    hangman_setupMenuBar();
    dm_showCursor();

    result = hangman_loadConfig();
    if (result == HM_ERROR) {
        return 0;
    }
    if (result == HM_READY && hangman_defineGame() != HM_READY) {
        return 0;
    }
    dm_hideCursor();
    hangman_initLetterTiles();
    hangman_drawGameBoard();
    hangman_drawStartScreen();
    return HM_READY;
}

/* address: 0000:00BF -- restore display state, release resources, exit(0) */
void hangman_cleanup(void)
{
    dm_initWindow(g_windowHandle);
    hangman_saveLetterTiles();
    dm_setTimeout(0xB4);
    dm_showCursor();
    if (g_spellLoaded) {
        dm_unloadSpell();
    }
    dm_unloadRes();
    dm_cleanupCursor();
    _exit(0);
}
