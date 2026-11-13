/* ========================================================================
 * hangman.c -- Main game logic for HANGMAN.PDM
 * ========================================================================
 * DeskMate 3.05 Hangman word-guessing game (1-4 players)
 * Original: Microsoft C 5.x (1987), Medium Memory Model
 * Transpiled to C89 for OpenWatcom
 *
 * Contains: initialization, game loop, input handling, word selection,
 * guess checking, save/restore, profanity filter.
 *
 * Reference: /disassembly/annotated/hangman.asm
 * ========================================================================
 */

#include "hangman.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ---- External data (from hangman_data.c) ----------------------------- */
extern const char sz_Hangman[];
extern const char sz_HangmanPdm[];
extern const char sz_BlankPad[];
extern const char sz_AlreadyGuessed[];
extern const char sz_PrevSaved[];
extern const char sz_SavePrompt[];
extern const char sz_SaveOverwrite[];
extern const char sz_PlayAgain[];
extern const char sz_GameSaved[];
extern const char sz_SaveError[];
extern const char sz_RestoreError[];
extern const char sz_PressAnyKey[];
extern const char sz_YouveBeen[];
extern const char sz_Pardoned[];
extern const char sz_Hanged[];
extern const char sz_PleaseWait[];
extern const char sz_HangmanCfg[];
extern const char sz_DmConfig[];
extern const char sz_HangCfg[];
extern const char *g_defaultPlayerNames[];
extern const unsigned int g_wordListIndex[16];
extern const char g_packedWordList[];
extern const unsigned int g_packedWordListSize;
extern const Hangman_ProfanityEntry g_profanityList[];
extern const unsigned int g_profanityCount;


/* ========================================================================
 * hangman_main -- _main() entry point
 * Address: 0000:0010
 * Called from CRT startup. Initializes game, enters game loop if ready,
 * then cleans up. The CRT startup code is provided by OpenWatcom.
 * ======================================================================== */
int hangman_main(void)
{
    unsigned int result;

    result = hangman_init();

    if (result == HANGMAN_READY) {
        hangman_gameLoop();
    }

    hangman_cleanup();
    return 0;
}

/* OpenWatcom entry point */
int main(void)
{
    return hangman_main();
}


/* ========================================================================
 * hangman_init -- Initialize game: load resources, set up UI, load config
 * Address: 0000:001F
 * Loads DeskMate resources (DMCSR, DMGUF, SPELL), sets up the application
 * window and menu bar, attempts to load a saved game.
 * Returns: HANGMAN_READY (0xFFFE) if game ready, 0 if user declined.
 * ======================================================================== */
unsigned int hangman_init(void)
{
    unsigned int result;

    /* Load DMCSR cursor resource */
    /* 0000:0025 */
    g_cursorHandle = dm_initCursor();
    if (g_cursorHandle == DM_ERROR) {
        /* Fatal: cannot load cursor resource */
        exit(1);
    }

    /* Load DMGUF graphics resource */
    /* 0000:0038 */
    result = dm_loadDmguf();
    if (result == DM_ERROR) {
        dm_cleanupCursor();
        exit(1);
    }

    /* Check for SPELL word source */
    /* 0000:004B */
    if (dm_checkApiEvent(DM_EVENT_WORD_LIST) == 0) {
        /* Load SPELL resource */
        /* 0000:0059 */
        result = dm_loadSpell();
        if (result == DM_ERROR) {
            dm_cleanupCursor();
            dm_unloadRes();
            exit(1);
        }
        /* SPELL loaded -- init game state for word source */
        /* 0000:006F */
        hangman_initGameState();
        g_spellAvailable = 1;
    }

    /* Set application title */
    /* 0000:0078 */
    dm_setAppTitle(sz_HangmanPdm);

    /* Initialize DeskMate application (DM API 0x020A) */
    /* 0000:0082 */
    dm_initApp();
    dm_setBorder();
    dm_showStatusBar();

    /* Set up menu bar */
    /* 0000:008B */
    hangman_setupMenuBar();

    /* Show cursor */
    /* 0000:008E */
    dm_showCursor();

    /* Load saved game config */
    /* 0000:0091 */
    result = hangman_loadConfig();

    if (result == DM_ERROR) {
        /* No config or error */
        return 0;
    }

    if (result == HANGMAN_READY) {
        /* Config found, ask user if they want to continue saved game */
        /* 0000:00A0 */
        result = hangman_defineGame();
        if (result != HANGMAN_READY) {
            return 0;
        }
    }

    /* Fresh start: set up display */
    /* 0000:00AC */
    dm_hideCursor();
    hangman_initLetterTiles();
    hangman_drawGameBoard();
    hangman_drawStartScreen();

    return HANGMAN_READY;
}


/* ========================================================================
 * hangman_cleanup -- Clean up and exit program
 * Address: 0000:00BF
 * Saves player state, sets timeout, unloads resources. Does not return.
 * ======================================================================== */
void hangman_cleanup(void)
{
    /* Initialize window with saved handle */
    /* 0000:00BF */
    dm_initWindow(g_windowHandle);

    /* Save letter tile state */
    /* 0000:00C9 */
    hangman_saveLetterTiles();

    /* Set timeout (180 ticks = ~10 seconds) */
    /* 0000:00CC */
    dm_setTimeout(HANGMAN_TIMER_TICKS);

    /* Show cursor */
    dm_showCursor();

    /* Unload SPELL if loaded */
    /* 0000:00D9 */
    if (g_spellAvailable != 0) {
        dm_unloadSpell();
    }

    /* Unload DMGUF resource */
    /* 0000:00E3 */
    dm_unloadRes();

    /* Unload DMCSR cursor resource */
    dm_cleanupCursor();

    /* Exit */
    exit(0);
}


/* ========================================================================
 * hangman_loadConfig -- Load saved game from HANGMAN.CFG
 * Address: 0000:00F3
 * Returns: HANGMAN_READY if game ready, DM_ERROR if cancelled, 0 if no save.
 * ======================================================================== */
unsigned int hangman_loadConfig(void)
{
    unsigned int result;

    /* Set window title to "Hangman" */
    /* 0000:00F9 */
    result = dm_setTitle(sz_Hangman);
    if (result == DM_ERROR) {
        /* No title set -> no saved game */
        g_savedGameValid = 0;
        g_hasSavedGame = 0;
        return HANGMAN_READY;
    }

    if (result != HANGMAN_READY) {
        /* Config file found */
        /* 0000:0119 */
        g_hasSavedGame = 1;

        /* Get config title value */
        result = dm_getTitle(sz_Hangman);
        if (result != 0) {
            g_savedGameValid = 0;
            return HANGMAN_READY;
        }

        /* Parse saved game data */
        /* 0000:0133 */
        g_savedGameValid = 1;

        /* Read config data into buffer (90 bytes) */
        dm_readConfig(sz_DmConfig, sz_HangCfg,
                      g_configBuffer, HANGMAN_CONFIG_BUF_SIZE);

        /* Prompt user: continue saved game? */
        /* 0000:0157 */
        result = dm_msgBox(0);

        if (result == DM_BTN_YES) {
            /* User wants to restore */
            /* 0000:0169 */
            return hangman_restoreGame();
        }

        if (result == DM_BTN_NO) {
            /* User declined */
            return DM_ERROR;
        }
    }

    return HANGMAN_READY;
}


/* ========================================================================
 * hangman_validateSaveData -- Validate saved game data structure
 * Address: 0000:0181
 * Checks that all fields are within valid ranges.
 * Returns: 1 if valid, 0 if invalid.
 * ======================================================================== */
int hangman_validateSaveData(Hangman_SaveData *data)
{
    unsigned int i;
    Hangman_PlayerData *pPlayer;

    /* Validate player count: 1-4 */
    /* 0000:0190 */
    if (data->numPlayers < 1 || data->numPlayers > 4) {
        return 0;
    }

    /* Validate wordsPerGame: 1-10 */
    /* 0000:01A2 */
    if (data->wordsPerGame < 1 || data->wordsPerGame > 10) {
        return 0;
    }

    /* Validate maxWrongGuesses: 3-12 */
    /* 0000:01AE */
    if (data->maxWrongGuesses < 3 || data->maxWrongGuesses > 12) {
        return 0;
    }

    /* Validate per-player data */
    /* 0000:01BA */
    for (i = 0; i < data->numPlayers; i++) {
        pPlayer = &data->players[i];

        /* Validate name length */
        /* 0000:01C4 */
        if (strlen(pPlayer->playerName) > HANGMAN_MAX_NAME_LEN) {
            return 0;
        }

        /* Validate guess counts */
        /* 0000:01F5 */
        if (pPlayer->currentGuessCount > HANGMAN_MAX_GUESSES) {
            return 0;
        }
        /* 0000:01FA */
        if (pPlayer->currentWrongCount > HANGMAN_MAX_WRONG) {
            return 0;
        }
        /* 0000:0200 */
        if (pPlayer->wordsGuessedDisplay > 9) {
            return 0;
        }
        /* 0000:0206 */
        if (pPlayer->wordsGuessedCorrect > data->wordsPerGame) {
            return 0;
        }
        /* 0000:0216 */
        if (data->wordsPerGame < pPlayer->wordsPlayed) {
            return 0;
        }
    }

    return 1;
}


/* ========================================================================
 * hangman_setupMenuBar -- Set up the application menu bar
 * Address: 0000:0229
 * Creates Game (Save, Restore, Exit), Run, About, Players menus.
 * Also sets game window dimensions and timer.
 * ======================================================================== */
void hangman_setupMenuBar(void)
{
    unsigned int screenW;
    unsigned int screenH;
    unsigned int menuWidth;

    /* Clear screen: set colors */
    /* 0000:0229 */
    dm_setColor(0, 1);

    /* Set text attributes */
    /* 0000:0236 */
    dm_setTextAttr(0, 1, 2);

    /* Calculate window size based on screen dimensions */
    /* 0000:0247 */
    screenW = dm_getScreenWidth(HANGMAN_BASE_WIDTH);
    screenW += HANGMAN_OFFSET_WIDTH;
    screenH = dm_getScreenHeight();
    dm_setCursorPos(0, (int)screenH);

    /* Set background */
    dm_setBackground();

    /* Define menu structure */
    /* 0000:0268 */
    menuWidth = dm_multiply(HANGMAN_BOARD_X, 0);
    menuWidth = dm_divide(menuWidth, HANGMAN_BOARD_Y);
    menuWidth--;
    dm_defineMenu(menuWidth, HANGMAN_BOARD_Y, 0, 0, 0);

    /* Mark timer as active */
    /* 0000:0290 */
    g_timerActive = 1;

    /* Set timer interval (180 ticks) */
    dm_setTimer(HANGMAN_TIMER_TICKS);

    /* Position cursor and draw title */
    /* 0000:029F */
    dm_setCursorPos(HANGMAN_TITLE_X, HANGMAN_TITLE_Y);

    /* Draw title with padding */
    dm_drawString(sz_BlankPad);
    dm_drawString(sz_Hangman);
    dm_drawString(sz_BlankPad);
    dm_drawString(sz_BlankPad);
}


/* ========================================================================
 * hangman_printNumber -- Print a 2-digit number
 * Address: 0000:06E2
 * Parameters: number = value to print (0-99)
 * Prints tens digit (or space if 0) followed by ones digit.
 * ======================================================================== */
void hangman_printNumber(int number)
{
    int tens;
    int ones;

    /* 0000:06EB */
    tens = number / 10;
    ones = number % 10;

    /* Print tens digit or space */
    /* 0000:06F6 */
    if (tens == 0) {
        dm_drawChar(' ');
    } else {
        dm_drawChar((unsigned int)('0' + tens));
    }

    /* Print ones digit */
    /* 0000:0710 */
    dm_drawChar((unsigned int)('0' + ones));
}


/* ========================================================================
 * hangman_initRoundState -- Initialize per-round state for a player
 * Address: 0000:071B
 * Parameters: roundState = pointer to player's 3-byte round state
 * ======================================================================== */
void hangman_initRoundState(unsigned char *roundState)
{
    /* 0000:0722 */
    roundState[2] = (unsigned char)g_currentWordLen;  /* lettersRemaining */
    /* 0000:072F */
    roundState[1] = 0;  /* wrongGuesses */
    /* 0000:0732 */
    roundState[0] = 0;  /* totalGuesses */
}


/* ========================================================================
 * hangman_gameLoop -- Main game loop
 * Address: 0000:0737
 * Iterates through words, calls chooseWord + playRound for each.
 * After all words, asks "Would you like to play again?"
 * ======================================================================== */
void hangman_gameLoop(void)
{
    int roundResult;

    for (;;) {
        /* Check if all words have been played */
        /* 0000:0743 */
        while (g_currentWordIndex <= g_wordsPerGame) {
            /* Choose a word */
            /* 0000:074C */
            g_currentWordLen = hangman_chooseWord();

            /* Play one round */
            /* 0000:0752 */
            roundResult = hangman_playRound();

            if (roundResult == HANGMAN_ROUND_EXIT) {
                /* Exit requested */
                /* 0000:0759 */
                return;
            }

            if (roundResult == HANGMAN_ROUND_RESTART) {
                /* Restart game (from menu action) */
                break;
            }

            /* Normal completion: advance to next word */
            /* 0000:073F */
            g_currentWordIndex++;
        }

        if (roundResult == HANGMAN_ROUND_RESTART) {
            /* Already handling restart below */
        } else {
            /* All words played: ask "play again?" */
            /* 0000:0767 */
            dm_showCursor();
            if (dm_msgBox(0) == DM_BTN_CANCEL) {
                /* User chose "No" */
                return;
            }

            /* Restart: reset game state */
            /* 0000:0779 */
            dm_hideCursor();
            hangman_newGame();
        }

        /* Restart game display */
        /* 0000:077F */
        dm_initWindow(g_windowHandle);
        hangman_drawStartScreen();
        hangman_resetDisplay();
    }
}


/* ========================================================================
 * hangman_playRound -- Play one complete round (all players, one word)
 * Address: 0000:0795
 * Cycles through each player for the current word.
 * Returns: 0 = round complete, -1 = exit, -2 = restart.
 * ======================================================================== */
int hangman_playRound(void)
{
    int inputResult;
    Hangman_PlayerData *pPlayer;
    unsigned int saveResult;

    /* 0000:079B */
    while (g_currentPlayer < g_numPlayers) {
        /* Check for pending event */
        /* 0000:081D */
        if (g_eventPending != 0) {
            g_eventPending = 0;
        }

        /* Set up word buffer */
        /* 0000:079D */
        g_wordBuffer[0] = '\0';

        /* Play the word for this player */
        inputResult = hangman_playWord(g_wordBuffer, g_currentWordLen);

        if (inputResult == 0) {
            /* Word complete: advance to next player */
            /* 0000:082D */
            hangman_layoutWordTiles();
            hangman_clearRevealFlags();

            /* Init round state for next player */
            pPlayer = &g_playerData[g_currentPlayer];
            hangman_initRoundState(&pPlayer->currentGuessCount);

            hangman_drawInitialBoard();

            /* Enter input processing loop */
            /* 0000:0847 */
            inputResult = hangman_processInput();

            hangman_adjustWordLayout();
            hangman_resetGuessedFlags();

            if (inputResult == 0) {
                /* Normal completion: advance player */
                /* Clear game area for next player */
                dm_setColor(2, 3);
                dm_fillRect(0, HANGMAN_ROW_HEIGHT,
                            HANGMAN_GAME_AREA_X,
                            (int)(HANGMAN_ROW_HEIGHT * g_numPlayers + 0x528),
                            HANGMAN_GAME_AREA_W);

                g_currentPlayer++;
                continue;
            }
        }

        /* Exit requested during play */
        /* 0000:07B4 */
        dm_showCursor();

        if (g_gameStateFlags == 0) {
            /* Ask to save before quitting */
            /* 0000:07BE */
            saveResult = hangman_promptSaveOnExit();
            if (saveResult == DM_BTN_YES) {
                saveResult = hangman_saveGame();
                if (saveResult == DM_ERROR) {
                    /* Save failed */
                    dm_msgBox(0);
                }
            }
        }

        return HANGMAN_ROUND_EXIT;
    }

    /* All players done: reset to player 0 */
    /* 0000:085E */
    g_currentPlayer = 0;
    return HANGMAN_ROUND_OK;
}


/* ========================================================================
 * hangman_processInput -- Main input event loop
 * Address: 0000:086A
 * Processes keyboard, menu, and timer events during gameplay.
 * Returns: 0 = word complete, -1 = exit, -2 = restart, -3 = menu redraw.
 * ======================================================================== */
int hangman_processInput(void)
{
    unsigned int eventBuf[10];
    unsigned int eventType;
    int letterIdx;
    int result;
    Hangman_PlayerData *pPlayer;

    result = HANGMAN_ROUND_RESTART;
    dm_showCursor();

    /* Event loop */
    /* 0000:0879 */
    for (;;) {
        /* Get next DM event */
        dm_getEvent(eventBuf);
        eventType = eventBuf[0];

        switch (eventType) {
        case DM_EVENT_IDLE:
            /* Idle: check for end-of-round */
            dm_yield();
            break;

        case DM_EVENT_KEYPRESS:
            /* Keyboard event: map key to letter */
            /* 0000:08CC type 1 */
            letterIdx = hangman_mapKeyToLetter(eventBuf[1]);

            if (letterIdx < 0 || letterIdx >= HANGMAN_NUM_LETTERS) {
                /* Not a valid letter key */
                dm_replyEvent(eventBuf[1]);
                break;
            }

            /* Check if letter already guessed */
            /* 0000:0919 */
            if (g_letterGuessed[letterIdx] != 0) {
                hangman_showAlreadyGuessed((unsigned int)letterIdx);
                break;
            }

            /* Mark letter as guessed */
            g_letterGuessed[letterIdx] = 1;

            /* Draw the guessed letter bitmap (dim the tile) */
            if (g_letterBitmapPtrs[letterIdx] != 0) {
                dm_drawBitmap(g_letterBitmapPtrs[letterIdx], 0, 0);
            }

            /* Check guess against word */
            dm_hideCursor();
            result = hangman_checkGuess((unsigned int)letterIdx);

            if (result != 0) {
                /* Word is complete (win or lose) */
                return 0;
            }

            /* Update display after guess */
            hangman_updateAfterGuess();
            dm_showCursor();
            break;

        case DM_EVENT_MENU:
            /* Menu event */
            /* 0000:08CC type 3 */
            if (eventBuf[1] <= DM_MENU_PLAYERS_ADD) {
                result = hangman_handleMenuAction(eventBuf[1]);
                if (result != 0) {
                    return result;
                }
            }
            break;

        case DM_EVENT_TIMER:
            /* Timer event */
            /* 0000:08CC type 6 */
            hangman_handleTimerEvent();
            break;

        default:
            /* Unknown event: reply and continue */
            dm_replyEvent(eventBuf[0]);
            break;
        }
    }
}


/* ========================================================================
 * hangman_mapKeyToLetter -- Map keyboard event to letter index
 * Address: 0000:09A2
 * Parameters: keyCode = raw keyboard event code
 * Returns: 0-25 for A-Z, -1 for non-letter keys.
 * ======================================================================== */
int hangman_mapKeyToLetter(unsigned int keyCode)
{
    unsigned int ch;

    /* Convert key code to character via DM API */
    ch = dm_keyToChar(keyCode);

    /* Check for uppercase A-Z */
    if (ch >= 'A' && ch <= 'Z') {
        return (int)(ch - 'A');
    }

    /* Check for lowercase a-z */
    if (ch >= 'a' && ch <= 'z') {
        return (int)(ch - 'a');
    }

    return -1;
}


/* ========================================================================
 * hangman_handleMenuAction -- Handle menu selections
 * Address: 0000:0A0C
 * Dispatches menu IDs (0xF500-0xF50C) to appropriate handlers.
 * Returns: 0 = continue, nonzero = exit/restart/redraw.
 *
 * Jump table at 0000:0B5B:
 *   0xF500: Exit
 *   0xF501: Save
 *   0xF502: Restore
 *   0xF508: Players>Define
 *   0xF50A: Run...
 *   0xF50B: About...
 * ======================================================================== */
int hangman_handleMenuAction(unsigned int menuId)
{
    unsigned int saveResult;

    switch (menuId) {
    case DM_MENU_EXIT:
        /* Game > Exit */
        return HANGMAN_ROUND_EXIT;

    case DM_MENU_SAVE:
        /* Game > Save */
        /* 0000:0A0C case F501 */
        saveResult = hangman_saveGame();
        if (saveResult == DM_ERROR) {
            dm_msgBox(0);
        } else {
            dm_msgBox(0);
        }
        /* Redraw the board */
        hangman_drawGameBoard();
        hangman_drawPlayerScores();
        return 0;

    case DM_MENU_RESTORE:
        /* Game > Restore */
        saveResult = hangman_restoreGame();
        if (saveResult == DM_ERROR) {
            dm_msgBox(0);
        } else {
            hangman_refreshBoard();
        }
        return 0;

    case DM_MENU_PLAYERS_DEF:
        /* Players > Define */
        hangman_definePlayersDialog();
        hangman_drawGameBoard();
        hangman_drawPlayerScores();
        return 0;

    case DM_MENU_RUN:
        /* Run... */
        hangman_runDialog();
        return 0;

    case DM_MENU_ABOUT:
        /* About... */
        hangman_aboutDialog();
        return 0;

    case DM_MENU_PLAYERS_ADD:
        /* Players > Add/Delete (context-dependent) */
        hangman_addPlayerDialog();
        return 0;

    default:
        break;
    }

    return 0;
}


/* ========================================================================
 * hangman_checkGuess -- Check guessed letter against word
 * Address: 0000:0B79
 * Parameters: letterIndex = 0-25 (A-Z)
 * Returns: 0 = continue playing, -1 = word complete (win or lose).
 * ======================================================================== */
int hangman_checkGuess(unsigned int letterIndex)
{
    unsigned int i;
    int found;
    char guessChar;
    Hangman_PlayerData *pPlayer;

    pPlayer = &g_playerData[g_currentPlayer];
    guessChar = (char)('A' + letterIndex);
    found = 0;

    /* Scan the current word for matching letters */
    for (i = 0; i < g_currentWordLen; i++) {
        if (g_wordBuffer[i] == guessChar) {
            /* Letter matches -- reveal it */
            found = 1;
            pPlayer->lettersRemaining--;

            /* Animate the letter reveal */
            hangman_showLetterAnim(i);
        }
    }

    /* Increment total guesses */
    pPlayer->numGuesses++;
    pPlayer->currentGuessCount++;

    if (found == 0) {
        /* Wrong guess */
        pPlayer->numWrongGuesses++;
        pPlayer->currentWrongCount++;

        /* Draw the next hangman part */
        hangman_drawWrongGuess(pPlayer->numWrongGuesses);

        /* Check for lose condition */
        if (pPlayer->numWrongGuesses >= g_maxWrongGuesses) {
            hangman_handleLose();
            return -1;
        }
    } else {
        /* Correct guess: check for win */
        if (pPlayer->lettersRemaining == 0) {
            hangman_handleWin();
            return -1;
        }
    }

    return 0;
}


/* ========================================================================
 * hangman_updateAfterGuess -- Update display after a guess
 * Address: 0000:0C47
 * Redraws the current game info panel with updated counts.
 * ======================================================================== */
void hangman_updateAfterGuess(void)
{
    hangman_drawPlayerScores();
    hangman_drawWordStatus();
}


/* ========================================================================
 * hangman_handleWin -- Handle win: "PARDONED!", update score
 * Address: 0000:0D4B
 * ======================================================================== */
void hangman_handleWin(void)
{
    Hangman_PlayerData *pPlayer;

    pPlayer = &g_playerData[g_currentPlayer];

    /* Update player stats */
    pPlayer->wordsGuessedCorrect++;
    pPlayer->wordsGuessedDisplay++;

    /* Calculate score: base points + bonus for fewer guesses */
    pPlayer->score += (g_currentWordLen * 10) +
                      (g_maxWrongGuesses - pPlayer->numWrongGuesses) * 5;
    pPlayer->scoreDisplay = pPlayer->score;
    pPlayer->wordsPlayed++;

    /* Draw celebration */
    hangman_drawCelebration();
    hangman_drawScoreUpdate();
}


/* ========================================================================
 * hangman_handleLose -- Handle loss: "HANGED!", show complete figure
 * Address: 0000:0D9C
 * ======================================================================== */
void hangman_handleLose(void)
{
    Hangman_PlayerData *pPlayer;

    pPlayer = &g_playerData[g_currentPlayer];

    /* Update player stats */
    pPlayer->wordsPlayed++;

    /* Draw death animation and message */
    hangman_drawDeathAnim();
    hangman_drawScoreUpdate();
}


/* ========================================================================
 * hangman_defineGame -- "Define Game" dialog handler
 * Address: 0000:0DD8
 * Called when user needs to configure game settings.
 * Returns: HANGMAN_READY if settings applied.
 * ======================================================================== */
unsigned int hangman_defineGame(void)
{
    return hangman_defineGameDialog();
}


/* ========================================================================
 * hangman_resetDisplay -- Reset and redraw full game display
 * Address: 0000:0DF0
 * ======================================================================== */
void hangman_resetDisplay(void)
{
    hangman_setupMenuBar();
    hangman_drawGameBoard();
    hangman_drawPlayerScores();
}


/* ========================================================================
 * hangman_refreshBoard -- Refresh game board after dialog/restore
 * Address: 0000:0E18
 * ======================================================================== */
void hangman_refreshBoard(void)
{
    dm_hideCursor();
    hangman_drawGameBoard();
    hangman_drawStartScreen();
    hangman_drawInitialBoard();
    dm_showCursor();
}


/* ========================================================================
 * hangman_getTimerTick -- Get timer tick (DM API 0x0501)
 * Address: 0000:14FC
 * ======================================================================== */
unsigned int hangman_getTimerTick(void)
{
    return dm_getTick();
}


/* ========================================================================
 * hangman_showAlreadyGuessed -- Show "letter already guessed" message
 * Address: 0000:1500
 * ======================================================================== */
void hangman_showAlreadyGuessed(unsigned int letterIndex)
{
    char msg[80];
    char letterChar;

    letterChar = (char)('A' + letterIndex);

    /* The original string has a '%' placeholder for the letter.
     * "The letter % has already been guessed.  Try a different letter!" */
    strncpy(msg, sz_AlreadyGuessed, sizeof(msg) - 1);
    msg[sizeof(msg) - 1] = '\0';

    /* Replace '%' with the actual letter */
    {
        char *p;
        p = strchr(msg, '%');
        if (p != NULL) {
            *p = letterChar;
        }
    }

    dm_setColor(2, 0);
    dm_drawString(msg);
    hangman_delayLoop(30);
}


/* ========================================================================
 * hangman_chooseWord -- Choose a word for the current round
 * Address: 0000:152F
 * Checks for DMSPELL resource or selects random category.
 * Returns: word length.
 * ======================================================================== */
unsigned int hangman_chooseWord(void)
{
    unsigned int category;

    /* Show wait message */
    hangman_showWaitMessage();

    /* Check for external word source (DMSPELL) */
    /* 0000:1535 */
    if (dm_checkApiEvent(DM_EVENT_WORD_SRC) != 0) {
        /* Read word from DMSPELL resource */
        /* 0000:1543 */
        return hangman_readWordFromRes(g_wordBuffer);
    }

    /* Select random category: rand() % 6 + 4 -> categories 4-9 */
    /* 0000:154F */
    category = ((unsigned int)rand() % HANGMAN_NUM_CATEGORIES)
               + HANGMAN_CATEGORY_BASE;

    /* Read a word from the packed word list for this category */
    /* TODO: implement word extraction from packed list using category */
    (void)category;

    return (unsigned int)strlen(g_wordBuffer);
}


/* ========================================================================
 * hangman_newGame -- Start new game: reset all player scores and counters
 * Address: 0000:1417
 * ======================================================================== */
void hangman_newGame(void)
{
    unsigned int i;

    g_currentWordIndex = 1;
    g_currentPlayer = 0;
    g_gameStateFlags = 0;
    g_scoreAccumulator = 0;

    for (i = 0; i < g_numPlayers; i++) {
        hangman_resetPlayerData(&g_playerData[i]);
    }
}


/* ========================================================================
 * hangman_resetPlayerData -- Reset one player's score and round data
 * Address: 0000:1449
 * ======================================================================== */
void hangman_resetPlayerData(Hangman_PlayerData *player)
{
    player->numGuesses = 0;
    player->numWrongGuesses = 0;
    player->lettersRemaining = 0;
    player->wordsGuessedCorrect = 0;
    player->wordsPlayed = 0;
    player->score = 0;
    player->currentGuessCount = 0;
    player->currentWrongCount = 0;
    player->wordsGuessedDisplay = 0;
    player->scoreDisplay = 0;
}


/* ========================================================================
 * hangman_updatePlayerCount -- Update player count and resize arrays
 * Address: 0000:1945
 * ======================================================================== */
void hangman_updatePlayerCount(unsigned int newCount)
{
    unsigned int i;

    if (newCount > HANGMAN_MAX_PLAYERS) {
        newCount = HANGMAN_MAX_PLAYERS;
    }
    if (newCount < HANGMAN_MIN_PLAYERS) {
        newCount = HANGMAN_MIN_PLAYERS;
    }

    /* Initialize any new player slots */
    for (i = g_numPlayers; i < newCount; i++) {
        hangman_resetPlayerData(&g_playerData[i]);
        strncpy(g_playerData[i].playerName,
                g_defaultPlayerNames[i], HANGMAN_MAX_NAME_LEN);
        g_playerData[i].playerName[HANGMAN_MAX_NAME_LEN] = '\0';
    }

    g_numPlayers = newCount;

    if (g_currentPlayer >= g_numPlayers) {
        g_currentPlayer = 0;
    }
}


/* ========================================================================
 * hangman_saveGame -- Save current game state to HANGMAN.CFG
 * Address: 0000:1976
 * Returns: 0 on success, DM_ERROR on failure.
 * ======================================================================== */
unsigned int hangman_saveGame(void)
{
    Hangman_SaveData *pSave;

    /* Build save data in config buffer */
    pSave = (Hangman_SaveData *)g_configBuffer;
    pSave->numPlayers = g_numPlayers;
    memcpy(pSave->players, g_playerData,
           sizeof(Hangman_PlayerData) * g_numPlayers);
    pSave->wordsPerGame = g_wordsPerGame;
    pSave->maxWrongGuesses = g_maxWrongGuesses;

    /* Write to config file */
    return dm_writeConfig(sz_DmConfig, sz_HangCfg,
                          (const char *)g_configBuffer);
}


/* ========================================================================
 * hangman_restoreGame -- Restore saved game state from HANGMAN.CFG
 * Address: 0000:19DA
 * Returns: HANGMAN_READY on success, DM_ERROR on failure.
 * ======================================================================== */
unsigned int hangman_restoreGame(void)
{
    unsigned int result;
    Hangman_SaveData *pSave;

    /* Read config into buffer */
    result = dm_readConfig(sz_DmConfig, sz_HangCfg,
                           g_configBuffer, HANGMAN_CONFIG_BUF_SIZE);

    if (result == DM_ERROR) {
        return DM_ERROR;
    }

    /* Validate the save data */
    /* 0000:1A01 */
    pSave = (Hangman_SaveData *)g_configBuffer;
    if (!hangman_validateSaveData(pSave)) {
        return DM_ERROR;
    }

    /* Restore from buffer */
    hangman_restoreFromBuffer();

    return HANGMAN_READY;
}


/* ========================================================================
 * hangman_restoreFromBuffer -- Restore game state from config buffer
 * Address: 0000:1A4B
 * ======================================================================== */
void hangman_restoreFromBuffer(void)
{
    Hangman_SaveData *pSave;

    pSave = (Hangman_SaveData *)g_configBuffer;

    g_numPlayers = pSave->numPlayers;
    memcpy(g_playerData, pSave->players,
           sizeof(Hangman_PlayerData) * g_numPlayers);
    g_wordsPerGame = pSave->wordsPerGame;
    g_maxWrongGuesses = pSave->maxWrongGuesses;

    /* Reset current position */
    g_currentPlayer = 0;
    g_currentWordIndex = 1;
}


/* ========================================================================
 * hangman_promptSaveOnExit -- "Save before quitting?" dialog
 * Address: 0000:1A93
 * Returns: DM_BTN_YES, DM_BTN_NO, or DM_BTN_CANCEL.
 * ======================================================================== */
unsigned int hangman_promptSaveOnExit(void)
{
    return dm_msgBox(0);
}


/* ========================================================================
 * hangman_readWordFromRes -- Read word from DMSPELL resource data
 * Address: 0000:23EB
 * Parameters: buffer = destination buffer for the word (null-terminated)
 * Returns: word length.
 * ======================================================================== */
unsigned int hangman_readWordFromRes(char *buffer)
{
    /* The original reads characters from the SPELL resource one at a
     * time until a delimiter (0x0D) is reached. Each character is
     * converted to uppercase and stored in the buffer. */
    unsigned int len;

    /* Placeholder: in the full implementation, this reads from
     * the DMSPELL resource via dm_spellOp() */
    buffer[0] = '\0';
    len = (unsigned int)strlen(buffer);

    return len;
}


/* ========================================================================
 * hangman_initGameState -- Initialize game state variables on first run
 * Address: 0000:242A
 * ======================================================================== */
void hangman_initGameState(void)
{
    unsigned int i;

    g_numPlayers = 1;
    g_wordsPerGame = 5;
    g_maxWrongGuesses = 7;
    g_currentWordIndex = 1;
    g_currentPlayer = 0;
    g_gameStateFlags = 0;
    g_roundActive = 0;
    g_scoreVisible = 0;
    g_eventPending = 0;

    /* Initialize first player with default name */
    hangman_resetPlayerData(&g_playerData[0]);
    strncpy(g_playerData[0].playerName,
            g_defaultPlayerNames[0], HANGMAN_MAX_NAME_LEN);
    g_playerData[0].playerName[HANGMAN_MAX_NAME_LEN] = '\0';

    /* Clear remaining player slots */
    for (i = 1; i < HANGMAN_MAX_PLAYERS; i++) {
        hangman_resetPlayerData(&g_playerData[i]);
        strncpy(g_playerData[i].playerName,
                g_defaultPlayerNames[i], HANGMAN_MAX_NAME_LEN);
        g_playerData[i].playerName[HANGMAN_MAX_NAME_LEN] = '\0';
    }

    /* Reset letter guessed flags */
    hangman_resetGuessedFlags();
}


/* ========================================================================
 * hangman_playWord -- Play one word: display, process guesses, animate
 * Address: 0000:246C
 * Parameters: wordBuf = word buffer, wordLen = word length
 * Returns: 0 = word complete, nonzero = exit/menu action.
 * ======================================================================== */
int hangman_playWord(char *wordBuf, unsigned int wordLen)
{
    (void)wordBuf;
    (void)wordLen;

    /* Word entry animation */
    hangman_wordAnimEnter();

    /* The actual gameplay is driven by hangman_processInput which
     * is called from hangman_playRound after this function sets up
     * the display. This function returns 0 to indicate the word
     * is ready for play. */

    return 0;
}


/* ========================================================================
 * hangman_handleTimerEvent -- Handle timer event (auto-play timeout)
 * Address: 0000:239A
 * ======================================================================== */
void hangman_handleTimerEvent(void)
{
    /* Reset timer */
    dm_setTimer(HANGMAN_TIMER_TICKS);

    /* The original checks if auto-play is active and advances
     * the game state if a timeout occurred during a prompt. */
}


/* ========================================================================
 * hangman_getWordFlags -- Get word category/difficulty flags
 * Address: 0000:28C2
 * ======================================================================== */
unsigned int hangman_getWordFlags(void)
{
    return 0;
}


/* ========================================================================
 * hangman_setWordFlags -- Set display flags for current word
 * Address: 0000:2905
 * ======================================================================== */
void hangman_setWordFlags(void)
{
    /* Sets internal flags that control how the word is displayed
     * (e.g., whether to show hints, difficulty indicator). */
}


/* ========================================================================
 * hangman_profanityCheck -- Check word against profanity filter
 * Address: 0000:297E
 * Uses strncmp to test ~55 word fragments against the input string.
 * Returns: 1 if profanity detected, 0 if clean.
 * ======================================================================== */
int hangman_profanityCheck(const char *word)
{
    unsigned int i;
    unsigned int wordLen;
    unsigned int j;
    char upperWord[HANGMAN_MAX_NAME_LEN + 1];
    unsigned int fragLen;

    wordLen = (unsigned int)strlen(word);
    if (wordLen == 0) {
        return 0;
    }

    /* Convert input to uppercase for comparison */
    for (i = 0; i < wordLen && i < HANGMAN_MAX_NAME_LEN; i++) {
        if (word[i] >= 'a' && word[i] <= 'z') {
            upperWord[i] = (char)(word[i] - 'a' + 'A');
        } else {
            upperWord[i] = word[i];
        }
    }
    upperWord[i] = '\0';

    /* Test each profanity fragment against the input */
    /* 0000:297E -- uses _strncmp (sub_0000_3D6E) for each fragment */
    for (i = 0; g_profanityList[i].firstChar != '\0'; i++) {
        fragLen = (unsigned int)strlen(g_profanityList[i].suffix);

        /* Scan the input for the first character match */
        for (j = 0; j < wordLen; j++) {
            if (upperWord[j] == g_profanityList[i].firstChar) {
                /* First char matches: check suffix */
                if (j + 1 + fragLen <= wordLen) {
                    if (strncmp(&upperWord[j + 1],
                                g_profanityList[i].suffix,
                                fragLen) == 0) {
                        return 1;  /* profanity detected */
                    }
                }
            }
        }
    }

    return 0;  /* clean */
}
