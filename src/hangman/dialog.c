/* ========================================================================
 * dialog.c -- HANGMAN.PDM game-settings dialogs
 * ======================================================================== */
#include "hangman.h"

/* "Define Game" dialog control ids returned by dm_getFormResult */
#define DG_WORDS_UP     0xF565
#define DG_WORDS_DOWN   0xF566
#define DG_WRONG_UP     0xF567
#define DG_WRONG_DOWN   0xF568
#define DG_OK           0xF56E
#define DG_CANCEL       0xF56F

/* Dialog placement arguments shared by open / open-ex / close */
#define DGAME_A  0x08FC
#define DGAME_B  0x04BA
#define DGAME_C  0x0D48

/* address: 0000:0DD8 -- Define Game, then Define Players, then start a
 * new game. Returns HM_READY if both dialogs were confirmed, else 0. */
int hangman_defineGame(void)
{
    if (hangman_defineGameDialog() != 0) {
        return 0;
    }
    if (hangman_definePlayersDialog() != 0) {
        return 0;
    }
    hangman_newGame();
    return HM_READY;
}

/* address: 0000:0E56 -- run the "Define Game" dialog.
 * Players are radio buttons handled by the form itself (state byte 0C0F);
 * the up/down arrows step the two numeric text fields through
 * hangman_spinnerControl, which returns 1 / -1 when the value reached a
 * limit (the arrow on the other side is then re-enabled and this one
 * disabled -- the bytes poked below are control state in g_defGameDlg).
 * Returns 0 on OK, -1 on Cancel. */
int hangman_defineGameDialog(void)
{
    int running = 1;        /* bp-2 */
    unsigned opened;        /* bp-4: nonzero = dialog could not save-under */
    int result;             /* bp-6 */

    opened = dm_openDialog(DGAME_A, DGAME_B, DGAME_C, g_defGameDlg);
    if (opened <= 0x88B8) {
        dm_openDialogEx(DGAME_A, DGAME_B, DGAME_C, g_defGameDlg, g_dlgSaveArea);
        opened = 0;
    }
    DG8(0x0CA7) = 0;
    DG16(0x0BA0) = 0x1008;
    dm_showForm(g_defGameForm);

    while (running) {
        switch (dm_getFormResult(g_defGameForm)) {
        case DG_WORDS_UP:
            DG8(0x0C26) = 0;
            DG8(0x0C9E) = 1;
            result = hangman_spinnerControl(1, g_wordsPerGameText, 1, 10);
            if (result == 1) {
                DG8(0x0C2C) = 1;
                DG8(0x0C9D) = 1;
            } else if (result == -1) {
                DG8(0x0C18) = 0;
                DG8(0x0C9E) = 1;
                DG8(0x0CA7) = 1;
            }
            break;
        case DG_WORDS_DOWN:
            DG8(0x0C3A) = 0;
            DG8(0x0C9D) = 1;
            result = hangman_spinnerControl(-1, g_wordsPerGameText, 1, 10);
            if (result == 1) {
                DG8(0x0C18) = 1;
                DG8(0x0C9E) = 1;
            } else if (result == -1) {
                DG8(0x0C2C) = 0;
                DG8(0x0C9D) = 1;
                DG8(0x0CA7) = 2;
            }
            break;
        case DG_WRONG_UP:
            DG8(0x0C4E) = 0;
            DG8(0x0CA0) = 1;
            result = hangman_spinnerControl(1, g_wrongGuessText, 3, 12);
            if (result == 1) {
                DG8(0x0C54) = 1;
                DG8(0x0C9F) = 1;
            } else if (result == -1) {
                DG8(0x0C40) = 0;
                DG8(0x0CA0) = 1;
                DG8(0x0CA7) = 3;
            }
            break;
        case DG_WRONG_DOWN:
            DG8(0x0C62) = 0;
            DG8(0x0C9F) = 1;
            result = hangman_spinnerControl(-1, g_wrongGuessText, 3, 12);
            if (result == 1) {
                DG8(0x0C40) = 1;
                DG8(0x0CA0) = 1;
            } else if (result == -1) {
                DG8(0x0C54) = 0;
                DG8(0x0C9F) = 1;
                DG8(0x0CA7) = 4;
            }
            break;
        case DG_OK:
            DG8(0x0C76) = 0;
            g_numPlayers = (signed char)DG8(0x0C0F) + 1;
            hangman_updatePlayerCount(g_numPlayers);
            g_wordsPerGame = _atoi(g_wordsPerGameText);
            g_maxWrongGuesses = _atoi(g_wrongGuessText);
            DG16(0x0EEA) = 0;
            running = 0;
            result = 0;
            break;
        case DG_CANCEL:
            DG8(0x0C8A) = 0;
            result = -1;
            running = 0;
            break;
        }
    }

    dm_yield();
    if (opened != 0) {
        hangman_refreshBoard();
    } else {
        dm_closeDialog(DGAME_A, DGAME_B, DGAME_C, g_defGameDlg, g_dlgSaveArea);
    }
    return result;
}
