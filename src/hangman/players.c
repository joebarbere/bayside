/* ========================================================================
 * players.c -- HANGMAN.PDM player table: new game, remove player
 * ======================================================================== */
#include "areab.h"

/* address: 0000:1417 hangman_newGame -- zero every player's score and
 * start at player 0, word 1 */
void hangman_newGame(void)
{
    int i;

    for (i = 0; g_numPlayers > i; i++) {
        hangman_resetPlayerData(&g_players[i].b0D);
    }
    CUR_PLAYER = 0;
    WORD_NUMBER = 1;
}

/* address: 0000:1449 hangman_resetPlayerData -- score points at a player
 * record's +0D: clear w13, played and won (in that order). */
void hangman_resetPlayerData(unsigned char *score)
{
    *(int *)(score + 6) = 0;
    *(int *)(score + 4) = 0;
    score[3] = 0;
}

/* address: 0000:185E hangman_aboutDialog -- misnamed: REMOVE player
 * `index` (chosen in Delete Player). Later players move down one slot;
 * the freed last record is cleared. Returns HM_READY (-2) if the removed
 * player was the one to move (turn goes to player 0), else 0 (the
 * current-player index is shifted down if it was above `index`). */
int hangman_aboutDialog(int index)
{
    int i;

    g_numPlayers--;
    for (i = index; g_numPlayers > i; i++) {
        hangman_aboutBuildInfo(&g_players[i + 1], &g_players[i]);
    }
    g_players[g_numPlayers].name[0] = 0;
    hangman_resetPlayerData(&g_players[g_numPlayers].b0D);
    if (index == CUR_PLAYER) {
        CUR_PLAYER = 0;
        return HM_READY;
    }
    if (index < CUR_PLAYER) {
        CUR_PLAYER--;
    }
    return 0;
}

/* address: 0000:18D3 hangman_aboutBuildInfo -- misnamed: copy player
 * record src to dst (name, then the score bytes from +0D) */
void hangman_aboutBuildInfo(struct HmPlayer *src, struct HmPlayer *dst)
{
    _strncpy(dst->name, src->name);
    hangman_aboutGetVersion(&src->b0D, &dst->b0D);
}

/* address: 0000:18F8 hangman_aboutGetVersion -- misnamed: copy a player's
 * 8 score bytes (+0D..+14): four bytes, then two words */
void hangman_aboutGetVersion(unsigned char *src, unsigned char *dst)
{
    dst[0] = src[0];
    dst[1] = src[1];
    dst[2] = src[2];
    dst[3] = src[3];
    *(int *)(dst + 4) = *(int *)(src + 4);
    *(int *)(dst + 6) = *(int *)(src + 6);
}
