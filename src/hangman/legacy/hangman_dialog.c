/* ========================================================================
 * hangman_dialog.c -- Dialog handlers for HANGMAN.PDM
 * ========================================================================
 * Handles all dialog boxes: Define Game, Define Players, Add Player,
 * Delete Player, Run..., and About.
 *
 * All dialogs are presented via DeskMate API (dm_openDialog, dm_msgBox).
 *
 * Reference: /disassembly/annotated/hangman.asm
 * ========================================================================
 */

#include "hangman.h"
#include <string.h>

/* ---- External string data (from hangman_data.c) --------------------- */
extern const char sz_DefineGame[];
extern const char sz_NumPlayers[];
extern const char sz_WordsPerGame[];
extern const char sz_WrongGuesses[];
extern const char sz_DefinePlayers[];
extern const char sz_Player1[];
extern const char sz_Player2[];
extern const char sz_Player3[];
extern const char sz_Player4[];
extern const char sz_AddPlayer[];
extern const char sz_NewPlayerName[];
extern const char sz_DeletePlayer[];
extern const char sz_ChooseDelete[];
extern const char sz_Cancel[];
extern const char sz_AboutTitle[];
extern const char sz_Version[];
extern const char sz_Resources[];
extern const char sz_DeskExe[];
extern const char sz_CancelBtn[];
extern const char sz_Copyright1[];
extern const char sz_Copyright2[];
extern const char sz_Hangman[];
extern const char sz_HangmanPdm[];
extern const char *g_defaultPlayerNames[];


/* ========================================================================
 * hangman_defineGameDialog -- Show "Define Game" dialog
 * Address: 0000:0E56
 * Lets user configure: number of players, words per game, wrong guesses.
 * Uses spinner controls for numeric fields.
 * Returns: DM_GAME_READY if settings changed, DM_ERROR if cancelled.
 * ======================================================================== */
unsigned int hangman_defineGameDialog(void)
{
    unsigned int result;
    unsigned int oldPlayers;
    unsigned int oldWords;
    unsigned int oldWrong;

    /* Save current settings for cancel detection */
    oldPlayers = g_numPlayers;
    oldWords = g_wordsPerGame;
    oldWrong = g_maxWrongGuesses;

    /* Open the Define Game dialog */
    /* The original builds a dialog definition structure and passes it
     * to dm_openDialog. The dialog contains three spinner fields:
     *   Field 1: Number of Players (1-4)
     *   Field 2: Words per Game (1-10)
     *   Field 3: Wrong Guesses (3-12)
     */
    result = dm_openDialog(0);  /* dialog param from g_defineGameDialog */

    if (result == DM_BTN_CANCEL) {
        /* User cancelled -- restore previous settings */
        g_numPlayers = oldPlayers;
        g_wordsPerGame = oldWords;
        g_maxWrongGuesses = oldWrong;
        return DM_ERROR;
    }

    /* Read dialog field values */
    /* In the original, fields are read from the dialog control structure
     * at DGROUP offsets g_defineGameDialog (0x0C08) */
    /* g_numPlayers = dm_getDialogField(1); */
    /* g_wordsPerGame = dm_getDialogField(2); */
    /* g_maxWrongGuesses = dm_getDialogField(3); */

    /* Validate ranges */
    if (g_numPlayers < HANGMAN_MIN_PLAYERS) g_numPlayers = HANGMAN_MIN_PLAYERS;
    if (g_numPlayers > HANGMAN_MAX_PLAYERS) g_numPlayers = HANGMAN_MAX_PLAYERS;
    if (g_wordsPerGame < HANGMAN_MIN_WORDS) g_wordsPerGame = HANGMAN_MIN_WORDS;
    if (g_wordsPerGame > HANGMAN_MAX_WORDS) g_wordsPerGame = HANGMAN_MAX_WORDS;
    if (g_maxWrongGuesses < HANGMAN_MIN_WRONG) g_maxWrongGuesses = HANGMAN_MIN_WRONG;
    if (g_maxWrongGuesses > HANGMAN_MAX_WRONG) g_maxWrongGuesses = HANGMAN_MAX_WRONG;

    /* If player count changed, update player data arrays */
    if (g_numPlayers != oldPlayers) {
        hangman_updatePlayerCount(g_numPlayers);
    }

    dm_closeDialog();
    return DM_GAME_READY;
}


/* ========================================================================
 * hangman_spinnerControl -- Up/down spinner for numeric dialog fields
 * Address: 0000:10AD
 * Parameters: direction = 0 for down, 1 for up
 * Adjusts the currently focused numeric field in the Define Game dialog.
 * ======================================================================== */
void hangman_spinnerControl(unsigned int direction)
{
    /* The original reads the focused field ID, then increments or
     * decrements the value within its valid range.
     * This is called from the dialog event handler when the user
     * clicks the up/down arrows on a spinner control. */
    (void)direction;
}


/* ========================================================================
 * hangman_definePlayersDialog -- Show "Define Players" dialog
 * Address: 0000:12A2
 * Lets user edit player names (1-4 text fields).
 * Returns: DM_GAME_READY if OK, DM_ERROR if cancelled.
 * ======================================================================== */
unsigned int hangman_definePlayersDialog(void)
{
    unsigned int result;
    unsigned int i;
    char nameBuf[HANGMAN_MAX_NAME_LEN + 1];

    /* Open the Define Players dialog.
     * The dialog has 1-4 text fields depending on g_numPlayers.
     * Each field is pre-filled with the current player name. */

    /* Set dialog field values from current player names */
    for (i = 0; i < g_numPlayers; i++) {
        dm_setDialogField(i + 1, (unsigned int)g_playerData[i].playerName);
    }

    result = dm_openDialog(0);

    if (result == DM_BTN_CANCEL) {
        return DM_ERROR;
    }

    /* Read back player names from dialog fields */
    for (i = 0; i < g_numPlayers; i++) {
        /* Get the field value (pointer to name string) */
        dm_getDialogField(i + 1);
        /* Copy name, truncating to max length */
        strncpy(g_playerData[i].playerName, nameBuf, HANGMAN_MAX_NAME_LEN);
        g_playerData[i].playerName[HANGMAN_MAX_NAME_LEN] = '\0';
    }

    dm_closeDialog();
    return DM_GAME_READY;
}


/* ========================================================================
 * hangman_runDialog -- Show "Run..." dialog (execute external program)
 * Address: 0000:159D
 * Uses DMGUF "Run" dialog to let user run another program.
 * Returns: result from dm_runProgram.
 * ======================================================================== */
unsigned int hangman_runDialog(void)
{
    /* The original calls the DMGUF "Run" dialog handler, which
     * presents a file browser and launches the selected program
     * via DM API AX=00B4h (dm_runProgram). */
    return dm_runProgram(NULL);
}


/* ========================================================================
 * hangman_addPlayerDialog -- Show "Add Player" dialog
 * Address: 0000:1612
 * Adds a new player if current count < 4.
 * Returns: DM_GAME_READY if player added, DM_ERROR if cancelled/full.
 * ======================================================================== */
unsigned int hangman_addPlayerDialog(void)
{
    unsigned int result;
    char newName[HANGMAN_MAX_NAME_LEN + 1];

    /* Check if we can add more players */
    if (g_numPlayers >= HANGMAN_MAX_PLAYERS) {
        return DM_ERROR;
    }

    /* Open the Add Player dialog with a text input field */
    /* Pre-fill with default name */
    strncpy(newName, g_defaultPlayerNames[g_numPlayers], HANGMAN_MAX_NAME_LEN);
    newName[HANGMAN_MAX_NAME_LEN] = '\0';

    dm_setDialogField(1, (unsigned int)newName);
    result = dm_openDialog(0);

    if (result == DM_BTN_CANCEL) {
        return DM_ERROR;
    }

    /* Add the new player */
    g_numPlayers++;
    hangman_resetPlayerData(&g_playerData[g_numPlayers - 1]);
    strncpy(g_playerData[g_numPlayers - 1].playerName,
            newName, HANGMAN_MAX_NAME_LEN);
    g_playerData[g_numPlayers - 1].playerName[HANGMAN_MAX_NAME_LEN] = '\0';

    dm_closeDialog();

    /* Redraw the board with the new player */
    hangman_redrawAfterDefine();

    return DM_GAME_READY;
}


/* ========================================================================
 * hangman_deletePlayerDialog -- Show "Delete Player" dialog
 * Address: 0000:1709
 * Removes a player if current count > 1.
 * Returns: DM_GAME_READY if player deleted, DM_ERROR if cancelled.
 * ======================================================================== */
unsigned int hangman_deletePlayerDialog(void)
{
    unsigned int result;
    unsigned int deleteIdx;
    unsigned int i;

    /* Check if we can delete a player */
    if (g_numPlayers <= HANGMAN_MIN_PLAYERS) {
        return DM_ERROR;
    }

    /* Open the Delete Player dialog with a selection list */
    result = dm_openDialog(0);

    if (result == DM_BTN_CANCEL) {
        return DM_ERROR;
    }

    /* Get the selected player index to delete */
    deleteIdx = dm_getDialogField(1);
    if (deleteIdx >= g_numPlayers) {
        return DM_ERROR;
    }

    /* Shift remaining players down */
    for (i = deleteIdx; i < g_numPlayers - 1; i++) {
        memcpy(&g_playerData[i], &g_playerData[i + 1],
               sizeof(Hangman_PlayerData));
    }

    g_numPlayers--;

    /* Adjust current player if needed */
    if (g_currentPlayer >= g_numPlayers) {
        g_currentPlayer = 0;
    }

    dm_closeDialog();

    /* Redraw the board */
    hangman_redrawAfterDefine();

    return DM_GAME_READY;
}


/* ========================================================================
 * hangman_aboutDialog -- Show "About..." dialog
 * Address: 0000:185E
 * Displays version, copyright, and resource information.
 * Returns: result from message box.
 * ======================================================================== */
unsigned int hangman_aboutDialog(void)
{
    unsigned int result;

    /* Build the About dialog info */
    hangman_aboutBuildInfo();

    /* Show the About dialog as a message box.
     * The original constructs a multi-line display with:
     *   "About"
     *   "Hangman"
     *   "Version X.XX"
     *   "DeskMate Copyright 1984, 1990"
     *   "Tandy Corporation, All Rights Reserved"
     *   "Resources"
     *   "DESK.EXE      <version>"
     *   <loaded resource list>
     */
    result = dm_msgBox(0);

    return result;
}


/* ========================================================================
 * hangman_aboutBuildInfo -- Build version/resource info for About dialog
 * Address: 0000:18D3
 * Populates the g_aboutLinesPtrs array with pointers to display strings.
 * ======================================================================== */
void hangman_aboutBuildInfo(void)
{
    /* The original fills g_aboutLinesPtrs[] with far pointers to
     * static strings and dynamically constructed version strings.
     * Lines:
     *   [0] = "About"
     *   [1] = "Hangman"
     *   [2] = "Version " + version number
     *   [3] = copyright line 1
     *   [4] = copyright line 2
     *   [5] = blank
     *   [6] = "Resources"
     *   [7] = "DESK.EXE      " + desk version
     *   [8..14] = loaded resource names + versions
     */
    g_aboutLinesPtrs[0] = (unsigned int)sz_AboutTitle;
    g_aboutLinesPtrs[1] = (unsigned int)sz_Hangman;
    g_aboutLinesPtrs[2] = (unsigned int)sz_Version;
    g_aboutLinesPtrs[3] = (unsigned int)sz_Copyright1;
    g_aboutLinesPtrs[4] = (unsigned int)sz_Copyright2;
    g_aboutLinesPtrs[5] = 0;
    g_aboutLinesPtrs[6] = (unsigned int)sz_Resources;
    g_aboutLinesPtrs[7] = (unsigned int)sz_DeskExe;
}


/* ========================================================================
 * hangman_aboutGetVersion -- Get version number for About dialog
 * Address: 0000:18F8
 * Returns: version number as BCD or integer.
 * ======================================================================== */
unsigned int hangman_aboutGetVersion(void)
{
    /* The original reads the version from the DM89 header or a
     * compiled-in constant. DeskMate 3.05 = version 0x0305. */
    return 0x0305;
}
