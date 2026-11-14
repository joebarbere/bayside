/* Area C (1AFB-23EA): hangman figure, animations, delays -- C prototypes */
#ifndef DRAW_H
#define DRAW_H

/* ---- DGROUP globals (draw.syms) -------------------------------------- */
extern int g_figureStageBase;   /* ABA6: 12 - maxWrongGuesses while playing */

/* ---- Functions in draw.c --------------------------------------------- */
void hangman_drawHangmanFigure(void);                       /* 1AFB */
void hangman_drawHangmanParts(void);                        /* 1B15 */
void hangman_drawWrongGuess(int wrong);                     /* 1BC4 */
void hangman_drawCelebration(void);                         /* 1C30 */
void hangman_drawGallowsPart(int *table, int base);         /* 1C9B */
void hangman_drawSmileyFace(void);                          /* 1CCC */
void hangman_showResultMessage(char *line1, char *line2);   /* 1D7F */
void hangman_drawPressAnyKey(void);                         /* 1E3C */
void hangman_drawDeathAnim(void);                           /* 1E62 */
int  hangman_drawProfanityList(int frame);                  /* 1EAE */
int  hangman_delayLoop(long ms);                            /* 222F */
void hangman_drawHangmanStage(int *table, int stage);       /* 22D7 */
int  hangman_handleTimerEvent(unsigned char *ev);           /* 239A */

#endif
