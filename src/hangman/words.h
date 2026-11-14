/* Area D (23EB-2FFF): word choice/generation, profanity -- C prototypes */
#ifndef WORDS_H
#define WORDS_H

/* DeskMate event record as filled by dm_getEvent / dm_replyEvent: type
 * byte, then a word (key code / menu id); 8 bytes in the original frames. */
struct words_event {
    unsigned char type;             /* 0 none, 1 key, 3 menu, 6 ... */
    unsigned code;
    unsigned char rest[5];
};

/* MSC struct timeb as written by _ftime: 10 bytes, time split to avoid
 * long arithmetic */
struct words_timeb {
    unsigned time_lo;
    unsigned time_hi;
    unsigned millitm;
    int timezone;
    int dstflag;
};

/* ---- DGROUP globals (words.syms) ------------------------------------ */
extern char     g_waitMessage[];    /* "Please wait while a word is chosen..." */
extern unsigned g_firstLetterFreq[];/* 25 cumulative rand() thresholds a..y */
extern unsigned g_nextLetterFreq[]; /* same, for the following letters */
extern char     g_suggestBuf[];     /* SPELL suggestions, NUL-separated */

int  hangman_readWordFromRes(char *word);           /* 23EB */
void hangman_initGameState(void);                   /* 242A */
int  hangman_playWord(char *word, int len);         /* 246C */
int  hangman_wordAnimEnter(char *word);             /* 2558 */
int  hangman_wordAnimExit(char *word, int len);     /* 2591 */
void hangman_showLetterAnim(char *word, int len);   /* 260F */
int  hangman_animFrame(int c);                      /* 2698 */
int  hangman_animFlash(unsigned *freq);             /* 26CB */
int  hangman_animSequence(int *state);              /* 2702 */
int  hangman_drawWordStatus(void);                  /* 2778 */
int  hangman_showWaitMessage(void);                 /* 27A3 */
void hangman_drawScoreUpdate(int box);              /* 2864 */
int  hangman_getWordFlags(void);                    /* 28C2 */
int  hangman_setWordFlags(int was);                 /* 2905 */
int  hangman_animCleanup(char *s, int n);           /* 294E */
int  hangman_profanityCheck(char *word);            /* 297E */
int  hangman_crtEntryStub(void);                    /* 2F96 */
#endif
