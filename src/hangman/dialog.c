/* ========================================================================
 * dialog.c -- HANGMAN.PDM game-settings dialogs
 * ======================================================================== */
#include "areab.h"

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
/* ... for the Quit dialog (hangman_runDialog) */
#define DQUIT_A  0x0834
#define DQUIT_B  0x0604
#define DQUIT_C  0x0ED8
#define DQUIT_D  ((char *)0x0898)
/* ... for Add Player */
#define DADD_A   0x0898
#define DADD_B   0x074E
#define DADD_C   0x0D48
#define DADD_D   ((char *)0x07BC)

/* dm_openDialog results above this mean the screen under the dialog could
 * not be saved: the board is repainted instead of restored on close. */
#define DLG_NO_SAVE  0x88B8

/* Define Players form: per-player controls (stride 0x2F) and state bytes */
#define DP_CTRL_SHOWN(i)  DG8(0x0CDC + 0x2F * (i))
#define DP_ITEM_SHOWN(i)  DG8(0x0CBA + 8 * (i))
#define DP_CTRL_WORD(i)   DG16(0x0CF5 + 0x2F * (i))
#define DP_CTRL_TEXT(i)   DG16(0x0CFE + 0x2F * (i))   /* edit buffer pointer */
#define DP_FOCUS          0x1094
/* Delete Player form: one radio button per player */
#define DEL_RADIO_SHOWN(i) DG8(0x0E68 + 5 * (i))
#define DEL_ITEM_SHOWN(i)  DG8(0x0E28 + 8 * (i))
#define DEL_SELECTED       DG8(0x0E8D)   /* radio index chosen by the user */
#define DEL_DEFAULT        DG8(0x0E92)
#define DEL_FOCUS          0x1044

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

/* address: 0000:10AD hangman_spinnerControl -- step the two-digit number
 * in `text` (" 4", "12") by dir (+1/-1) within min..max. Returns 0 if it
 * was already at the limit in that direction (nothing changes) or is now
 * strictly inside; -1 if it just reached the limit it moved towards; 1 if
 * it just left the opposite limit (that arrow can be re-enabled). Marks
 * the Define Game form as changed (first byte of g_defGameForm). */
int hangman_spinnerControl(int dir, char *text, int min, int max)
{
    int value;      /* bp-2 */
    int tens;       /* bp-4 */

    value = _atoi(text);
    if ((dir == 1 && value == max) || (dir == -1 && value == min)) {
        return 0;
    }
    g_defGameForm[0] = 1;
    if (dir == 1) {
        value++;
    } else {
        value--;
    }
    tens = value / 10;
    *text++ = (tens != 0) ? (char)tens + '0' : ' ';
    *text = (char)(value % 10) + '0';
    if (dir == 1) {
        if (value == max) {
            return -1;
        }
        if (min + 1 == value) {
            return 1;
        }
        return 0;
    }
    if (max - 1 == value) {
        return 1;
    }
    if (value == min) {
        return -1;
    }
    return 0;
}

/* address: 0000:12A2 hangman_definePlayersDialog -- "Define Players":
 * one name field per player (fields for absent players hidden). The form
 * edits copies of the names on the stack; OK copies them back.
 * Returns 0 on OK, -1 on Cancel.
 * Original quirk: for hidden fields it clears the first byte of whatever
 * the field's edit-buffer pointer still holds -- a stack address left by
 * an earlier call, or the initial data. */
int hangman_definePlayersDialog(void)
{
    char names[MAX_PLAYERS][NAME_SIZE];     /* bp-3C */
    int running = 1;                        /* bp-2 */
    unsigned opened;                        /* bp-4 */
    int result;                             /* bp-8 */
    int i;                                  /* si */

    DLG_FOCUS = DP_FOCUS;
    for (i = 0; g_numPlayers > i; i++) {
        DP_CTRL_SHOWN(i) = 1;
        DP_ITEM_SHOWN(i) = 1;
        DP_CTRL_WORD(i) = -1;
        _strncpy(names[i], g_players[i].name);      /* strcpy */
        DP_CTRL_TEXT(i) = (int)names[i];
    }
    for (; i < MAX_PLAYERS; i++) {
        DP_CTRL_SHOWN(i) = 0;
        DP_ITEM_SHOWN(i) = 0;
        *(char *)DP_CTRL_TEXT(i) = 0;
    }

    opened = dm_openDialog(DGAME_A, DGAME_B, DGAME_C, g_defGameDlg);
    if (opened <= DLG_NO_SAVE) {
        dm_openDialogEx(DGAME_A, DGAME_B, DGAME_C, g_defGameDlg, g_dlgSaveArea);
        opened = 0;
    }
    DG8(0x0DAB) = 0;
    dm_showForm(g_playersForm);

    while (running) {
        switch (dm_getFormResult(g_playersForm)) {
        case DG_OK:
            DLG_OK_STATE = 0;
            result = 0;
            running = 0;
            for (i = 0; g_numPlayers > i; i++) {
                _strncpy(g_players[i].name, names[i]);  /* strcpy */
            }
            break;
        case DG_CANCEL:
            DLG_CANCEL_STATE = 0;
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

/* address: 0000:159D hangman_runDialog -- open dialog 0898 and let
 * DeskMate run it modally (dm_runProgram, menu F504 and the CRT entry
 * stub); returns dm_runProgram's result (nonzero: go on to quit). */
int hangman_runDialog(void)
{
    unsigned opened;    /* bp-2 */
    int result;         /* bp-4 */

    opened = dm_openDialog(DQUIT_A, DQUIT_B, DQUIT_C, DQUIT_D);
    if (opened <= DLG_NO_SAVE) {
        dm_openDialogEx(DQUIT_A, DQUIT_B, DQUIT_C, DQUIT_D, g_dlgSaveArea);
        opened = 0;
    }
    result = dm_runProgram();
    if (opened != 0) {
        hangman_refreshBoard();
    } else {
        dm_closeDialog(DQUIT_A, DQUIT_B, DQUIT_C, DQUIT_D, g_dlgSaveArea);
    }
    return result;
}

/* address: 0000:1612 hangman_addPlayerDialog -- "Add Player": the name is
 * typed straight into the next free player record; OK makes it count.
 * The shared OK/Cancel buttons are moved up 0x528 while it is open.
 * Returns 0 on OK, -1 on Cancel. */
int hangman_addPlayerDialog(void)
{
    int running = 1;    /* bp-2 */
    unsigned opened;    /* bp-4 */
    int result;         /* bp-6 */
    char *name;

    opened = dm_openDialog(DADD_A, DADD_B, DADD_C, DADD_D);
    if (opened <= DLG_NO_SAVE) {
        dm_openDialogEx(DADD_A, DADD_B, DADD_C, DADD_D, g_dlgSaveArea);
        opened = 0;
    }
    DLG_OK_Y -= 0x528;
    DLG_CANCEL_Y -= 0x528;
    name = g_players[g_numPlayers].name;
    DG16(0x0DF4) = (int)name;       /* edit field buffer */
    *name = 0;
    DG16(0x0DEB) = 0;
    DG8(0x0E0D) = 0;
    dm_showForm(g_addPlayerForm);

    while (running) {
        switch (dm_getFormResult(g_addPlayerForm)) {
        case DG_OK:
            DLG_OK_STATE = 0;
            result = 0;
            running = 0;
            g_numPlayers++;
            break;
        case DG_CANCEL:
            DLG_CANCEL_STATE = 0;
            result = -1;
            running = 0;
            break;
        }
    }

    dm_yield();
    DLG_OK_Y += 0x528;
    DLG_CANCEL_Y += 0x528;
    if (opened != 0) {
        hangman_refreshBoard();
    } else {
        dm_closeDialog(DADD_A, DADD_B, DADD_C, DADD_D, g_dlgSaveArea);
    }
    return result;
}

/* address: 0000:1709 hangman_deletePlayerDialog -- "Delete Player": one
 * radio button per player (the last one preselected). OK removes the
 * chosen player (hangman_aboutDialog) and clears the freed score row.
 * Returns -1 on Cancel, else hangman_aboutDialog's result (0 / HM_READY). */
int hangman_deletePlayerDialog(void)
{
    int running = 1;    /* bp-2 */
    unsigned opened;    /* bp-4 */
    int i;              /* bp-6 */
    int result;         /* bp-8 */
    unsigned char last;

    opened = dm_openDialog(DGAME_A, DGAME_B, DGAME_C, g_defGameDlg);
    if (opened <= DLG_NO_SAVE) {
        dm_openDialogEx(DGAME_A, DGAME_B, DGAME_C, g_defGameDlg, g_dlgSaveArea);
        opened = 0;
    }
    DLG_FOCUS = DEL_FOCUS;
    DG8(0x0EA1) = 0;
    last = (unsigned char)g_numPlayers - 1;
    DEL_DEFAULT = last;
    DEL_SELECTED = last;
    for (i = 0; i < g_numPlayers; i++) {
        DEL_RADIO_SHOWN(i) = 1;
        DEL_ITEM_SHOWN(i) = 1;
    }
    for (; i < MAX_PLAYERS; i++) {
        DEL_RADIO_SHOWN(i) = 0;
        DEL_ITEM_SHOWN(i) = 0;
    }
    dm_showForm(g_delPlayerForm);

    while (running) {
        switch (dm_getFormResult(g_delPlayerForm)) {
        case DG_OK:
            DLG_OK_STATE = 0;
            running = 0;
            result = hangman_aboutDialog((signed char)DEL_SELECTED);
            break;
        case DG_CANCEL:
            DLG_CANCEL_STATE = 0;
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
    if (result != -1) {
        dm_fillRect(0x64, 0xDC * g_numPlayers + 0xA41, 0x1E78, 0x118, 0);
    }
    return result;
}

/* address: 0000:1945 hangman_updatePlayerCount -- enable Add Player and
 * Delete Player, then disable Add at 4 players / Delete at 1 player, and
 * update the menu (dm_setTimer 0B4h, also used after save/restore). */
void hangman_updatePlayerCount(int count)
{
    MENU_ADD_ENABLE = 1;
    MENU_DEL_ENABLE = 1;
    if (count == 4) {
        MENU_ADD_ENABLE = 0;
    } else if (count == 1) {
        MENU_DEL_ENABLE = 0;
    }
    dm_setTimer(0xB4);
}

/* address: 0000:1A93 hangman_promptSaveOnExit -- ask "Would you like to
 * save this game before quitting?" (plus the overwrite warning when a
 * saved game exists). Returns the message box result (F703 = yes). */
int hangman_promptSaveOnExit(void)
{
    char text[0x10E];       /* bp-10E */

    _strncpy(text, (char *)0x124C);     /* strcpy */
    if (SAVE_EXISTS == 1) {
        _strcpy(text, (char *)0x1FE6);  /* strcat "  " */
        _strcpy(text, (char *)0x127E);  /* strcat overwrite warning */
    }
    DG16(0x0EC3) = (int)text;
    return dm_msgBox((char *)0x0EC0);
}
