/* ========================================================================
 * save.c -- HANGMAN.PDM save/restore through the DeskMate config record,
 * DeskMate event queries, word choice
 * ======================================================================== */
#include "areab.h"

#define SAVE_SIZE       0x5A            /* g_numPlayers .. g_maxWrongGuesses */
#define SAVE_TIMER      0xB4
#define MSG_BOX         ((char *)0x0ED2) /* message box; text pointer at +3 */
#define MSG_TEXT        DG16(0x0ED5)
#define MSG_RESTORE_BAD 0x1316          /* "saved game is invalid" text */
#define CFG_PTR_OFF     DG16(0x0EF3)    /* far pointer + size in g_saveConfig */
#define CFG_PTR_SEG     DG16(0x0EF5)
#define CFG_SIZE        DG16(0x0EF7)

/* DS (== DGROUP) for the far pointer in the config descriptor */
unsigned save_getDS(void);
#pragma aux save_getDS = "mov ax,ds" value [ax] modify exact [ax];

/* address: 0000:14FC hangman_getTimerTick -- tail call to dm_getTick */
int hangman_getTimerTick(void)
{
    return dm_getTick();
}

/* address: 0000:1500 hangman_showAlreadyGuessed -- put `letter` in place
 * of the '%' in the message text at 0FBC, show message box 0EB4, put the
 * '%' back. Returns the message box result. */
int hangman_showAlreadyGuessed(int letter)
{
    char *mark;
    int result;

    mark = (char *)_strstr((char *)0x0FBC, 0x25);
    *mark = (char)letter;
    result = dm_msgBox((char *)0x0EB4);
    *mark = '%';
    return result;
}

/* address: 0000:152F hangman_chooseWord -- if DeskMate sent a word-list
 * event (FD17) read the word from the resource, else return a random word
 * length 4..9. */
int hangman_chooseWord(void)
{
    int r;

    if (hangman_checkDmApiEvent(0xFD17) != 0) {
        return hangman_readWordFromRes(WORD_TEXT);
    }
    r = _rand() % 6;
    return r + 4;
}

/* address: 0000:1564 hangman_checkDmApiEvent -- peek the next DeskMate
 * event; if it is a type-1 event with this code, acknowledge it, set
 * API_EVENT_SEEN and return 1, else 0. */
int hangman_checkDmApiEvent(int code)
{
    struct HmEvent ev;

    dm_getEvent(&ev);
    if (ev.type == 1 && ev.code == code) {
        dm_replyEvent(&ev);
        API_EVENT_SEEN = 1;
        return 1;
    }
    return 0;
}

/* address: 0000:1976 hangman_saveGame -- copy the game state into
 * g_saveBuffer and write it as the DeskMate config record. Returns 0 on
 * success (game marked saved), -1 if writing failed. */
int hangman_saveGame(void)
{
    _memcpy(g_saveBuffer, (char *)&g_numPlayers, SAVE_SIZE);
    dm_setTimer(SAVE_TIMER);
    CFG_PTR_OFF = (int)g_saveBuffer;
    CFG_PTR_SEG = save_getDS();
    CFG_SIZE = SAVE_SIZE;
    if (dm_writeConfig(g_saveConfig) == -1) {
        return -1;
    }
    if (dm_deleteConfig(g_saveConfig) == -1) {
        dm_readConfig(g_saveConfig);
        return -1;
    }
    GAME_SAVED = 1;
    SAVE_EXISTS = 1;
    return 0;
}

/* address: 0000:19DA hangman_restoreGame -- read the config record into
 * g_saveBuffer; if it validates, make it the game state and continue with
 * the player whose turn it was. Returns 0, or HM_READY (-2) after telling
 * the user the saved game is invalid. */
int hangman_restoreGame(void)
{
    SAVE_EXISTS = 0;
    dm_setTimer(SAVE_TIMER);
    dm_readConfig(g_saveConfig);
    dm_deleteConfig(g_saveConfig);
    if (hangman_validateSaveData(g_saveBuffer) != 0) {
        _memcpy((char *)&g_numPlayers, g_saveBuffer, SAVE_SIZE);
        CUR_PLAYER = hangman_restoreFromBuffer();
        WORD_NUMBER = g_players[CUR_PLAYER].played + 1;
        return 0;
    }
    MSG_TEXT = MSG_RESTORE_BAD;
    dm_msgBox(MSG_BOX);
    return HM_READY;
}

/* address: 0000:1A4B hangman_restoreFromBuffer -- whose turn: the first
 * player after player 0 who has played fewer words than player 0, else 0 */
int hangman_restoreFromBuffer(void)
{
    struct HmPlayer *p;
    unsigned first;
    int i;

    p = &g_players[0];
    first = g_players[0].played;
    for (i = 1; p = &g_players[i], i < g_numPlayers; i++) {
        if (p->played < first) {
            return i;
        }
    }
    return 0;
}
