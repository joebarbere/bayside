/* ========================================================================
 * draw.c -- HANGMAN.PDM gallows/figure drawing, end-of-word animations,
 *           result banner and the timed wait (area C, 0000:1AFB-23EA)
 * ========================================================================
 * The picture is made of shape records in DGROUP, each drawn with
 * dm_drawAt(shape, DRAW_STYLE, 0). A record starts with a type word (8 =
 * line, 12/13/14/22... = longer primitives) and a zero word, followed by
 * byte (x, y) pairs. dm_setTextAttr(0, a, b) selects how the next shapes
 * are drawn: (0,1,3)/(0,2,3)/(0,0,3) draw in the figure colour, (0,2,2)
 * and (0,1,2) draw in the background colour, i.e. erase.
 *
 * Two stage tables index the picture (word pointers to shape records):
 *   FIG_STAGES  0A20: 13 entries, stage 0..12. Stages 0-5 are the gallows
 *                     (base, post, beam, brace, rope...), 6-12 the figure
 *                     (head, body, arms, legs). One stage per wrong guess.
 *   HANG_STAGES 0B80: 7 entries used as 0..6: the figure hanging from the
 *                     rope, drawn after a lost word.
 * g_figureStageBase (ABA6) shifts stage numbers so that the last allowed
 * wrong guess always completes the figure: it is 12 - g_maxWrongGuesses,
 * and stages 0..base are pre-drawn as part of the empty gallows.
 * ======================================================================== */
#include "hangman.h"

#define DRAW_STYLE      0x0EE0      /* 2nd arg of every dm_drawAt here */
#define FIG_STAGES      ((int *)0x0A20)
#define HANG_STAGES     ((int *)0x0B80)

/* Shape records (DGROUP offsets). Roles are inferred from the coordinates
 * and from the order things are drawn/erased in; the primitives themselves
 * are rendered by DMCSR, which is not disassembled yet. */
#define SHP_0998        0x0998
#define SHP_09A6        0x09A6
#define SHP_09AE        0x09AE
#define SHP_09B6        0x09B6
#define SHP_09BE        0x09BE
#define SHP_0A3A        0x0A3A
#define SHP_0A94        0x0A94
#define SHP_0A9C        0x0A9C
#define SHP_0AA4        0x0AA4
#define SHP_0AAC        0x0AAC
#define SHP_ROPE_SHORT  0x0AB4      /* line (48,0D)-(48,10) */
#define SHP_ROPE        0x0ABE
#define SHP_TRAPDOOR    0x0AD4      /* 4-point outline (55,58)(55,70)(52,70)(52,58) */
#define SHP_BODY        0x0B04      /* line (48,28)-(48,40) */
#define SHP_ARM_L       0x0B0C      /* line (48,2E)-(3C,34) */
#define SHP_ARM_R       0x0B14      /* line (48,2E)-(54,34) */
#define SHP_LEG_L       0x0B1C      /* legs, pose 1 (type 13 records) */
#define SHP_LEG_R       0x0B2A
#define SHP_FLAIL_L     0x0B38      /* arm lines whose end points move */
#define SHP_FLAIL_R     0x0B40
#define SHP_LEG2_L      0x0B48      /* legs, final (hanging) pose */
#define SHP_LEG2_R      0x0B56
#define SHP_LEG3_L      0x0B64      /* legs, kicking pose */
#define SHP_LEG3_R      0x0B72
#define SHP_BANNER      0x0B8E      /* result message frame */

/* End points of SHP_FLAIL_L / SHP_FLAIL_R (x, y bytes of the 2nd point) */
#define FLAIL_L_X       DG8(0x0B3E)
#define FLAIL_L_Y       DG8(0x0B3F)
#define FLAIL_R_X       DG8(0x0B46)
#define FLAIL_R_Y       DG8(0x0B47)

#define g_currentWordLen  DG16(0xAB90)  /* letters in the current word */
#define g_figureShown     DG16(0x0EEA)  /* 1 once the figure area is drawn */

/* MSC long helpers: args on the stack, the callee pops them (ret 8),
 * result in DX:AX. Called exactly where the original calls them. */
long draw_lmul(long a, long b);
long draw_lmod(long a, long b);
#pragma aux draw_lmul "__crt_lmul" parm routine [] value [dx ax] modify [ax bx cx dx es];
#pragma aux draw_lmod "__crt_lmod" parm routine [] value [dx ax] modify [ax bx cx dx es];

/* MSC struct timeb filled by _ftime */
struct draw_timeb {
    long          time;             /* seconds since 1970 */
    unsigned int  millitm;
    int           timezone;
    int           dstflag;
};

/* address: 0000:1AFB -- draw the empty gallows for the current
 * maxWrongGuesses: set the stage base to 12 - maxWrongGuesses and draw
 * with no wrong guesses, then flag the figure area as shown. */
void hangman_drawHangmanFigure(void)
{
    g_figureStageBase = 12 - g_maxWrongGuesses;
    hangman_drawWrongGuess(0);
    g_figureShown = 1;
}

/* address: 0000:1B15 -- clear and frame the picture area: background box
 * sized by the number of player rows, ground shapes, and the message area
 * below it. (Not the hangman parts; the dm_* names here are guesses.) */
void hangman_drawHangmanParts(void)
{
    dm_setTextAttr(0, 1, 3);
    dm_setColor(2, 3);
    dm_setFont(0);
    dm_defineMenu(0, 0, 0x0F28, 0xDC * g_numPlayers + 0x07BC, 1);
    dm_setTextAttr(0, 0, 3);
    dm_drawAt(SHP_0A94, DRAW_STYLE, 0);
    dm_drawAt(SHP_0AA4, DRAW_STYLE, 0);
    dm_drawAt(SHP_0A9C, DRAW_STYLE, 0);
    dm_getDialogField(0x1424, 0x18, 0x01C2);
    dm_setDialogField(0x01F4, 0x012C, 0x82, 0x82, 0);
}

/* address: 0000:1BC4 -- redraw the whole picture in the game window:
 * frame, gallows stages 0..base, then one stage per wrong guess
 * (stages base+0 .. base+wrong). Returns to the cursor window. */
void hangman_drawWrongGuess(int wrong)
{
    int base;               /* bp-2 */
    int i;                  /* si */

    base = g_figureStageBase;
    dm_setActiveWin(g_windowHandle);
    dm_setColor(2, 3);
    hangman_drawHangmanParts();
    g_figureStageBase = 0;
    for (i = 0; base >= i; i++) {
        hangman_drawHangmanStage(FIG_STAGES, i);
    }
    g_figureStageBase = base;
    for (i = 0; wrong >= i; i++) {
        hangman_drawHangmanStage(FIG_STAGES, i);
    }
    dm_setActiveWin(g_cursorHandle);
}

/* address: 0000:1C30 -- end of a word (win or loss): erase the figure
 * (stages 6..12) and the short rope, then redraw the rope. */
void hangman_drawCelebration(void)
{
    int i;                  /* si */

    dm_setTextAttr(0, 2, 2);
    i = 6;
    do {
        dm_drawAt(FIG_STAGES[i], DRAW_STYLE, 0);
        i++;
    } while (i <= 12);
    dm_drawAt(SHP_ROPE_SHORT, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_ROPE, DRAW_STYLE, 0);
}

/* address: 0000:1C9B -- draw stages 1..7 of a stage table with a
 * temporary stage base: (FIG_STAGES, 5) = the whole standing figure,
 * (HANG_STAGES, -1) = the hanged figure (entries 0..6). */
void hangman_drawGallowsPart(int *table, int base)
{
    int saved;              /* bp-2 */
    int i;                  /* si */

    saved = g_figureStageBase;
    g_figureStageBase = base;
    i = 1;
    do {
        hangman_drawHangmanStage(table, i);
        i++;
    } while (i <= 7);
    g_figureStageBase = saved;
}

/* address: 0000:1CCC -- word guessed ("pardoned"): take down the rope and
 * gallows pieces and draw the whole figure standing free. */
void hangman_drawSmileyFace(void)
{
    dm_setTextAttr(0, 1, 2);
    dm_drawAt(SHP_0AAC, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_0998, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 2);
    dm_drawAt(SHP_09B6, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_09BE, DRAW_STYLE, 0);
    hangman_drawGallowsPart(FIG_STAGES, 5);
    dm_setTextAttr(0, 0, 3);
    dm_drawAt(SHP_0A3A, DRAW_STYLE, 0);
}

/* address: 0000:1D7F -- clear the message area and show a two-line
 * result in a frame ("YOU'VE BEEN" / "PARDONED!", ... / " HANGED!"). */
void hangman_showResultMessage(char *line1, char *line2)
{
    dm_setColor(2, 3);
    dm_setTextAttr(0, 0, 2);
    dm_setDialogField(0x01F4, 0x012C, 0x82, 0x82, 0);
    dm_setTextAttr(0, 1, 3);
    dm_setFont(0);
    dm_setDialogField(0x0352, 0x02BC, 0x0320, 0x0190, 1);
    dm_drawAt(SHP_BANNER, DRAW_STYLE, 0);
    dm_drawLine(1);
    dm_setCursorPos(0x014A, 0x01D6);
    dm_drawString(line1);
    dm_setCursorPos(0x01C2, 0x02EE);
    dm_drawString(line2);
    dm_drawLine(0);
}

/* address: 0000:1E3C -- reveal the word: set the "shown" flag (+10h) of
 * every letter tile (17h-byte records at 02D2) and redraw the tiles. */
void hangman_drawPressAnyKey(void)
{
    int i;                  /* si */

    for (i = 0; g_currentWordLen > i; i++) {
        DG8(0x02E2 + 0x17 * i) = 1;
    }
    hangman_drawWordBlanks();
}

/* address: 0000:1E62 -- word lost: reset the flailing arms and play the
 * hanging animation, frame n followed by a wait of n*100 ms, until a
 * frame returns 0 or the wait is interrupted by an event. Frame 0 always
 * returns 0, so in practice exactly one frame is shown. */
void hangman_drawDeathAnim(void)
{
    int frame = 0;          /* bp-2 */

    FLAIL_L_X = 0x3C;
    FLAIL_R_Y = 0x34;
    FLAIL_L_Y = 0x34;
    FLAIL_R_X = 0x54;
    while (hangman_drawProfanityList(frame) != 0) {
        ++frame;
        if (hangman_delayLoop(draw_lmul((long)(unsigned)frame, 100L)) == 0) {
            break;
        }
    }
}

/* address: 0000:1EAE -- one frame of the hanging animation (the old name
 * is a misidentification; this has nothing to do with profanity): kick
 * the legs, flail the arms (on odd frames their end points move by
 * frame%4), open the trap door, wait 500 ms, then drop the arms and leave
 * the figure hanging with the final leg pose. Always returns 0. */
int hangman_drawProfanityList(int frame)
{
    unsigned char step;     /* bp-2 */

    dm_setTextAttr(0, 2, 2);
    dm_drawAt(SHP_LEG_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_LEG_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_ROPE, DRAW_STYLE, 0);
    dm_setTextAttr(0, 1, 3);
    dm_drawAt(SHP_LEG3_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_LEG3_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 2);
    dm_drawAt(SHP_FLAIL_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_FLAIL_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 1, 3);
    dm_drawAt(SHP_ARM_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_ARM_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 2);
    dm_drawAt(SHP_LEG3_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_LEG3_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_ROPE, DRAW_STYLE, 0);
    dm_setTextAttr(0, 1, 3);
    dm_drawAt(SHP_LEG_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_LEG_R, DRAW_STYLE, 0);
    dm_drawAt(SHP_BODY, DRAW_STYLE, 0);
    if (frame % 2 != 0) {
        FLAIL_L_X++;
        step = (unsigned char)(frame % 4);
        FLAIL_L_Y += step;
        FLAIL_R_X--;
        FLAIL_R_Y += step;
    }
    dm_setTextAttr(0, 2, 2);
    dm_drawAt(SHP_ARM_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_ARM_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 1, 3);
    dm_drawAt(SHP_FLAIL_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_FLAIL_R, DRAW_STYLE, 0);
    dm_drawAt(SHP_BODY, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_TRAPDOOR, DRAW_STYLE, 0);
    hangman_delayLoop(500L);
    dm_setTextAttr(0, 2, 2);
    dm_drawAt(SHP_FLAIL_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_FLAIL_R, DRAW_STYLE, 0);
    FLAIL_R_X = 0x4B;
    FLAIL_L_X = 0x45;
    FLAIL_L_Y = 0x41;
    FLAIL_R_Y = 0x41;
    dm_setTextAttr(0, 1, 3);
    dm_drawAt(SHP_FLAIL_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_FLAIL_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 2);
    dm_drawAt(SHP_LEG_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_LEG_R, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_ROPE, DRAW_STYLE, 0);
    dm_setTextAttr(0, 1, 3);
    dm_drawAt(SHP_LEG2_L, DRAW_STYLE, 0);
    dm_drawAt(SHP_LEG2_R, DRAW_STYLE, 0);
    dm_drawAt(SHP_BODY, DRAW_STYLE, 0);
    dm_setTextAttr(0, 2, 3);
    dm_drawAt(SHP_TRAPDOOR, DRAW_STYLE, 0);
    return 0;
}

/* address: 0000:222F -- wait `ms` milliseconds (measured with _ftime,
 * seconds taken mod 1000) or until an event is pending, whichever comes
 * first. Returns 1 when the time ran out, 0 when an event arrived.
 * Quirk kept from the original: when the seconds counter wraps past a
 * multiple of 1000 it adds the start value instead of 1000. */
int hangman_delayLoop(long ms)
{
    unsigned long deadline;     /* bp-1A */
    unsigned int now;           /* bp-16 */
    unsigned int start;         /* bp-14 */
    unsigned char ev[8];        /* bp-12: event record (type byte first) */
    struct draw_timeb tb;       /* bp-0A */

    _ftime(&tb);
    start = (unsigned int)draw_lmod(tb.time, 1000L);
    deadline = (unsigned long)draw_lmul((long)start, 1000L) + tb.millitm + ms;
    for (;;) {
        dm_getEvent(ev);
        if (ev[0] != 0) {
            return 0;
        }
        _ftime(&tb);
        now = (unsigned int)draw_lmod(tb.time, 1000L);
        if (now < start) {
            now += start;
        }
        if ((unsigned long)draw_lmul((long)now, 1000L) + tb.millitm >= deadline) {
            return 1;
        }
    }
}

/* address: 0000:22D7 -- draw stage `stage` (+ g_figureStageBase) from a
 * stage table. For FIG_STAGES gallows stages (<= 5) extra pieces are
 * drawn first: stage 5 draws 09A6 and erases 09AE/09B6, stage 3 erases
 * 0AA4 (presumably joints that the new piece covers). */
void hangman_drawHangmanStage(int *table, int stage)
{
    int n;                  /* bp-2 */

    n = stage + g_figureStageBase;
    dm_setTextAttr(0, 1, 3);
    if (n <= 5 && table != HANG_STAGES) {
        if (n == 5) {
            dm_drawAt(SHP_09A6, DRAW_STYLE, 0);
            dm_setTextAttr(0, 2, 2);
            dm_drawAt(SHP_09AE, DRAW_STYLE, 0);
            dm_drawAt(SHP_09B6, DRAW_STYLE, 0);
        } else if (n == 3) {
            dm_setTextAttr(0, 0, 2);
            dm_drawAt(SHP_0AA4, DRAW_STYLE, 0);
        }
        dm_setTextAttr(0, 2, 3);
    }
    dm_drawAt(table[n], DRAW_STYLE, 0);
}

/* address: 0000:239A -- handle a DeskMate system event (type 6) during
 * play: blank the title-bar text, then subtype 3 -> dm_checkSpell(arg),
 * subtype 4 -> poll dm_getTick and return -1 if it reports -1.
 * ev: event record (type byte, subtype word at +1, argument word at +3).
 * Returns 0 normally, -1 to make processInput leave the round. */
int hangman_handleTimerEvent(unsigned char *ev)
{
    dm_setCursorPos(0x0960, 0x24);
    dm_drawString(0x0F20);
    dm_drawString(0x0F20);
    if (*(int *)(ev + 1) == 3) {
        dm_checkSpell(*(int *)(ev + 3));
    } else if (*(int *)(ev + 1) == 4) {
        if (hangman_getTimerTick() == -1) {
            return -1;
        }
    }
    return 0;
}
