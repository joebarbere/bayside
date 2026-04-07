; ========================================================================
; CALENDAR.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.
; Compiled with Microsoft C 5.x (1987), Medium Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; CALENDAR.PDM is the calendar/scheduler application for DeskMate 3.05.
; It provides a graphical monthly calendar view, weekly and daily views,
; event creation and editing, recurring event support, alarm scheduling
; (via ALRMINIT.RES / DMALARM.ACC), time-of-day display, and print
; functionality. Calendar data is stored in .CAL files.
;
; The application supports four primary views:
;   1 = Monthly view (grid of days with event indicators)
;   2 = Weekly view (7-day agenda list)
;   3 = Daily view (hourly time slots with event detail)
;   4 = Event edit view (form-based event editor)
;
; Calendar events are stored as records in DMDB-managed database files.
; Each event has: date, start time, end time, description text, recurrence
; type, and alarm flag. The alarm subsystem communicates with DMALARM.ACC
; to trigger pop-up notifications at scheduled times.
;
; DM89 imports: PRGUF (Program User Functions),
;               DMGUF (General User Functions / form engine)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 72,593 bytes
; Load image: 72,081 bytes (after header)
; DM89 entry point: 0E4D:0000 (MSC 5.x CRT startup)
; SS:SP = 1686:0DAC
;
; Segment Map (6 segments, 25 relocations):
;   seg_0000  0x0CD94 bytes  CODE   Calendar application code + DMGUF thunks
;   seg_0E4D  0x00090 bytes  CODE   MSC 5.x CRT startup + DeskMate host stubs
;   seg_0E56  0x00310 bytes  CODE   DM89 import far-call dispatcher (PRGUF/DMGUF)
;   seg_0E87  0x00040 bytes  DATA   DGROUP fixup area (MSC CRT copyright)
;   seg_0E8B  0x07FB0 bytes  DATA   Strings, menus, event definitions,
;                                   record buffers, date/time state, alarm data
;   seg_1686  0x00DAC bytes  STACK  Stack segment
;
; Medium memory model: multiple code segments, DGROUP at 0E87.
;
; DM flags: 0x0101 (standard PDM module)
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Global Variables (selected):
;   [0x0004]  g_moduleContext    - Module context byte (0xFF = not resident)
;   [0x01B6]  g_monthLengths[]  - Array of 12 words: days per month (indexed 0-11)
;   [0x1C90]  g_alarmEnabled    - Byte flag: alarm enabled for current event
;   [0x1CA4]  g_eventModified   - Byte flag: current event has unsaved changes
;   [0x1D0D]  g_currentEventIdx - Word: index of currently selected event (-1=none)
;   [0x1D31]  g_editMode        - Byte: 0=view, nonzero=editing
;   [0x1D44]  g_printBuffer     - Print format buffer
;   [0x1970]  g_fileIoBuffer    - File I/O buffer base (used in DM event dispatch)
;   [0x20D5]  g_appVersionCode  - Application version code (masked with 0x0FFF)
;   [0x20F0]  g_tempStringBuf   - Temporary string buffer (for event names)
;   [0x20F3]  g_tempStringPtr   - Pointer within temp string buffer
;   [0x2852]  g_fileHandleB     - File handle B (second resource file)
;   [0x2854]  g_fileHandleA     - File handle A (primary resource file)
;   [0x2856]  g_filenameA       - Filename string A (for file open)
;   [0x285B]  g_filenameB       - Filename string B (for file open)
;   [0x2860]  g_heapLimit       - Heap limit value (max allocation size)
;   [0x2862]  g_stackBase       - Initial stack pointer (saved at startup)
;   [0x2864]  g_exitCallback    - Far pointer to exit callback function
;   [0x2866]  g_stackTop        - Stack top value (saved at startup)
;   [0x28B8]  g_moduleNameBuf   - 12-byte module name comparison buffer
;   [0x28C5]  g_savedInt00vec   - Saved INT 00h vector (offset)
;   [0x28C7]  g_savedInt00seg   - Saved INT 00h vector (segment)
;   [0x28D7]  g_pspSegment      - PSP segment address
;   [0x28D9]  g_dosVersion      - DOS version (from INT 21h AH=30h)
;   [0x28E0]  g_fileHandleFlags - File handle flags array (5 bytes, handles 0-4)
;   [0x2902]  g_prgufDispatch   - Far pointer: PRGUF dispatch function (offset)
;   [0x2904]  g_prgufDispatchSeg - PRGUF dispatch function (segment)
;   [0x2906]  g_prgufCallBlock  - PRGUF call parameter block
;   [0x290C]  g_dmgufDispatch   - Far pointer: DMGUF dispatch function (offset)
;   [0x290E]  g_dmgufDispatchSeg - DMGUF dispatch function (segment)
;   [0x2910]  g_dmgufResName    - DMGUF resource name string
;   [0x2916]  g_prgufActive     - Byte flag: 1=PRGUF loaded, 0=DMGUF only
;   [0x2919]  g_savedBP         - Saved BP for thunk dispatch
;   [0x291B]  g_savedRetAddr    - Saved return address for thunk dispatch
;   [0x2920]  g_alarmResName    - 8-byte alarm resource name for comparison
;   [0x2922]  g_alarmModName    - Alarm module name string (for INT E0h load)
;   [0x2928]  g_savedSS         - Saved SS for stack switch during file I/O
;   [0x292A]  g_savedSP         - Saved SP for stack switch during file I/O
;   [0x292C]  g_ioResultPtr     - Pointer to I/O result buffer
;   [0x292E]  g_ioFileHandle    - File handle for DM-mediated I/O
;   [0x2936]  g_dbDispatchPtr   - Far pointer to DMDB dispatch function
;   [0x293A]  g_dbResName       - DMDB resource name string
;   [0x2940]  g_dbSessionHandle - DMDB session handle
;   [0x3122]  g_bssStart        - Start of BSS zero-init region
;   [0x3162]  g_dmgufFuncTable  - DMGUF function pointer table base
;   [0x31AE]  g_fieldWidth      - Field width for record display
;   [0x6692]  g_fieldCount      - Number of fields in current record
;   [0x72D8]  g_eventDescField  - Event description field buffer
;   [0x3AFE]  g_eventTimeField  - Event time/date field buffer
;
; Event Record Structure (approx. layout):
;   +0x00   date_year     (byte) Year offset from 1900
;   +0x01   date_month    (byte) Month (1-12)
;   +0x02   date_day      (byte) Day of month (1-31)
;   +0x03   start_hour    (byte) Event start hour (0-23)
;   +0x04   start_minute  (byte) Event start minute (0-59)
;   +0x05   end_hour      (byte) Event end hour (0-23)
;   +0x06   end_minute    (byte) Event end minute (0-59)
;   +0x07   flags         (byte) Event flags (alarm, recurring type)
;   +0x08.. description   (var)  Null-terminated event description string
;
; Date/Time Calculation Structure (3-byte compact date):
;   +0x00   year          (byte) Year
;   +0x01   month         (byte) Month
;   +0x02   dayOfYear     (byte) Day-of-year or day-of-month
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Calendar Application Functions ---
;
; Address   Name                            Size  Description
; -------   ----                            ----  -----------
; 0000:0010 calendar_allocAndCopyDate        39   Allocate date struct, copy from source
; 0000:0037 calendar_initDateDisplay        103   Initialize date display with current date
; 0000:009E calendar_renderDateRange        121   Render a range of dates (3 or 6 lines)
; 0000:0117 calendar_renderSingleDay        428   Render one day cell (event indicators, highlight)
; 0000:02C3 calendar_getDayMetrics           88   Get day cell position and size metrics
; 0000:031B calendar_drawDayCell            109   Draw a single day cell with borders
; 0000:0388 calendar_handleDayClick         294   Handle mouse click on a day cell
; 0000:04AE calendar_scrollMonthForward      61   Scroll calendar forward one month
; 0000:04EB calendar_scrollMonthBackward     61   Scroll calendar backward one month
; 0000:0528 calendar_updateMonthDisplay      30   Update month display after scroll
; 0000:0546 calendar_setViewTitle            43   Set window title bar with current view info
; 0000:0571 calendar_switchToMonthView       65   Switch to monthly calendar view
; 0000:05B2 calendar_switchToWeekView        74   Switch to weekly agenda view
; 0000:05FC calendar_switchToDayView         66   Switch to daily schedule view
; 0000:063E calendar_switchToEventEdit       75   Switch to event edit view
; 0000:0689 calendar_viewDispatcher         287   View mode dispatcher (month/week/day/edit)
; 0000:07A8 calendar_getDataSegment           17  Return current DS
; 0000:07B9 calendar_parseTimeString          91  Parse "HH:MM" time string into hours/minutes
; 0000:0814 calendar_formatTimeDisplay       113  Format time value for display (12h/24h)
; 0000:0885 calendar_drawTimeField           114  Draw a time field on screen
; 0000:08F7 calendar_drawTimePair             73  Draw start/end time pair
; 0000:0940 calendar_updateTimeDisplay        78  Update time display with current values
; 0000:098E calendar_drawEventIndicator      155  Draw event indicator dot/mark on day cell
; 0000:0A29 calendar_setDayHighlight          64  Set highlight on selected day
; 0000:0A69 calendar_clearDayHighlight        46  Clear highlight from previously selected day
; 0000:0A97 calendar_toggleDayHighlight      106  Toggle day highlight (clear old, set new)
; 0000:0B01 calendar_buildMonthGrid          440  Build complete monthly grid display
; 0000:0CB9 calendar_getDayOfWeek            231  Calculate day-of-week for given date
; 0000:0DA0 calendar_initWeekView            163  Initialize weekly view display
; 0000:0E43 calendar_allocAndInitWeek         39  Allocate and init weekly view struct
; 0000:0E6A calendar_updateWeekTimeSlots      71  Update time slot display in weekly view
; 0000:0EB1 calendar_buildWeekDisplay        426  Build complete weekly display
; 0000:105B calendar_getDataSegment_2         17  Return current DS (duplicate for far calls)
; 0000:106C calendar_getSystemDateTime       110  Get current system date/time
; 0000:10DA calendar_setDateField_year        25  Set year field in date structure
; 0000:10F3 calendar_setDateField_month       25  Set month field in date structure
; 0000:110C calendar_getDaysInMonth            46  Get number of days in given month/year
; 0000:113A calendar_getDaysInMonth_ext        37  Extended days-in-month with leap year check
; 0000:115F calendar_isLeapYear               130  Check if year is a leap year
; 0000:11E1 calendar_getMonthLength            54  Get month length (wrapper for getDaysInMonth)
; 0000:1217 calendar_validateDate             230  Validate and normalize a date structure
; 0000:12FD calendar_computeDayOfYear          73  Compute day-of-year from month/day
; 0000:1346 calendar_compareDates              47  Compare two date structures (-1/0/1)
; 0000:1375 calendar_formatDateString         282  Format date as displayable string
; 0000:148F calendar_getDateComponent           34  Extract a component from date struct
; 0000:14B1 calendar_setDateComponents        200  Set multiple date components at once
; 0000:1579 calendar_computeWeekNumber         69  Compute ISO week number for date
; 0000:15BE calendar_parseDateString          390  Parse date string into date structure
; 0000:1744 calendar_scanDecimalNumber        103  Scan decimal number from string
; 0000:17AB calendar_formatNumber             124  Format number with leading zeros/padding
; 0000:1827 calendar_getTimeSeparator          40  Get time separator character (: or .)
; 0000:184F calendar_getDateSeparator          43  Get date separator character (/ or -)
; 0000:187A calendar_parseTimeField           309  Parse time field from user input
; 0000:19AF calendar_adjustDateField          136  Adjust a date field by delta (add/subtract)
; 0000:1A37 calendar_computeWeekRows          216  Compute number of week rows needed for month
; 0000:1B0F calendar_getDayName                66  Get day-of-week name string
; 0000:1B51 calendar_getMonthDays_jan          79  Get days in January for given year
; 0000:1BA0 calendar_getMonthDays_feb          69  Get days in February (leap year aware)
; 0000:1BE5 calendar_getMonthDays_mar          94  Get days in March
; 0000:1C43 calendar_getMonthDays_apr          92  Get days in April
; 0000:1C9F calendar_getMonthDays_may          83  Get days in May
; 0000:1CF2 calendar_getMonthDays_jun          83  Get days in June
; 0000:1D45 calendar_getMonthDays_jul          55  Get days in July
; 0000:1D7C calendar_getMonthDays_aug          56  Get days in August
; 0000:1DB4 calendar_allocAndInitDaily          40  Allocate and init daily view struct
; 0000:1DDC calendar_initDailyView            151  Initialize daily schedule view
; 0000:1E73 calendar_mainEventLoop            894  Main application event loop
; 0000:21F1 calendar_getDataSegment_3          17  Return current DS (far call variant)
; 0000:2202 calendar_setupCalendarDisplay      60  Set up calendar display (title, grid, events)
; 0000:223E calendar_refreshEventMarkers       77  Refresh event markers on current view
; 0000:228B calendar_scanEventsForMonth       173  Scan database for events in current month
; 0000:2338 calendar_scanEventsForRange       173  Scan database for events in date range
; 0000:23E5 calendar_markEventDays            196  Mark days that have events on the grid
; 0000:24A9 calendar_handleTimerTick            71  Handle timer tick (update clock display)
; 0000:24F0 calendar_handleKeyUp              129  Handle cursor-up key in month view
; 0000:2571 calendar_handleKeyDown            134  Handle cursor-down key in month view
; 0000:25F7 calendar_getSelectedRow             56  Get row of currently selected day
; 0000:262F calendar_getSelectedCol             57  Get column of currently selected day
; 0000:2668 calendar_handleKeyRight           184  Handle cursor-right key in month view
; 0000:2720 calendar_handleKeyLeft            201  Handle cursor-left key in month view
; 0000:27E9 calendar_handlePageDown             53  Handle page-down (next month)
; 0000:281E calendar_handleHomeKey            231  Handle Home key (go to today)
; 0000:2905 calendar_handleEndKey             225  Handle End key (go to last day of month)
; 0000:29E6 calendar_handleMonthForward       211  Navigate forward one month
; 0000:2AB9 calendar_handleMonthBackward      214  Navigate backward one month
; 0000:2B8F calendar_handleYearForward        124  Navigate forward one year
; 0000:2C0B calendar_handleYearBackward        61  Navigate backward one year
; 0000:2C48 calendar_handleGotoDate           138  Go to specific date (dialog)
; 0000:2CD2 calendar_updateSelectedDay        145  Update display after day selection change
; 0000:2D63 calendar_handleWeekNavigation     217  Handle navigation in weekly view
; 0000:2E3C calendar_navigateDay              534  Navigate to specific day with full refresh
; 0000:3052 calendar_getDayNumber              39  Get day number for grid position
; 0000:3079 calendar_isValidDay                27  Check if grid position is a valid day
; 0000:3094 calendar_drawMonthHeader          222  Draw month/year header on calendar grid
; 0000:3172 calendar_drawGridLine              48  Draw horizontal grid line
; 0000:31A2 calendar_clearGridCell             20  Clear a grid cell area
; 0000:31B6 calendar_drawDayNumber             71  Draw day number in grid cell
; 0000:31FD calendar_getGridCellX              19  Calculate X coordinate for grid column
; 0000:3210 calendar_getGridCellY              54  Calculate Y coordinate for grid row
; 0000:3246 calendar_drawGridBackground        74  Draw grid background rectangle
; 0000:3290 calendar_drawCalendarFrame        266  Draw complete calendar frame with borders
; 0000:339A calendar_drawDayNames             327  Draw day-of-week name headers (Sun-Sat)
; 0000:34E1 calendar_setupDailyViewHeader     194  Set up daily view header (date + times)
; 0000:35A3 calendar_drawDailyTimeSlots       407  Draw hourly time slots for daily view
; 0000:373A calendar_drawTwoTimeHeaders       141  Draw AM/PM time column headers
; 0000:37C7 calendar_drawTimeHeader           100  Draw single time column header
; 0000:382B calendar_getViewportWidth          60  Get current viewport width
; 0000:3867 calendar_setDailyViewport          85  Set up viewport for daily view
; 0000:38BC calendar_handleDailyScroll        126  Handle scrolling in daily view
; 0000:393A calendar_handleDailyKeyNav        138  Handle keyboard navigation in daily view
; 0000:39C4 calendar_dailyMoveUp               96  Move up one time slot in daily view
; 0000:3A24 calendar_dailyMoveDown            101  Move down one time slot in daily view
; 0000:3A89 calendar_dailyPageUp               76  Page up in daily view
; 0000:3AD5 calendar_dailyPageDown            147  Page down in daily view
; 0000:3B68 calendar_dailyHomeEnd              86  Home/End navigation in daily view
; 0000:3BBE calendar_redrawDailyView           55  Redraw daily view after navigation
; 0000:3BF5 calendar_renderDailyEvents        235  Render events in daily time slots
; 0000:3CE0 calendar_getDailyScrollPos         92  Get current scroll position in daily view
; 0000:3D3C calendar_setDailyScrollPos         30  Set scroll position in daily view
; 0000:3D5A calendar_getTimeSlotRange         145  Get visible time slot range
; 0000:3DEB calendar_formatDailyEntry         466  Format daily event entry for display
; 0000:3FBD calendar_formatEventTime          299  Format event time range (start - end)
; 0000:40E8 calendar_getEventDuration         105  Calculate event duration in minutes
; 0000:4151 calendar_allocAndInitPrint          36  Allocate and init print struct
; 0000:4175 calendar_initPrintView            142  Initialize print view/dialog
; 0000:4203 calendar_printCalendar            428  Print calendar (main print handler)
; 0000:43AF calendar_getDataSegment_4          17  Return current DS (print context)
; 0000:43C0 calendar_trimTrailingSpaces        57  Trim trailing spaces from string
; 0000:43F9 calendar_padStringToWidth         137  Pad string to specified width with spaces
; 0000:4482 calendar_formatPrintDate          103  Format date for print output
; 0000:44E9 calendar_formatEventForPrint      321  Format a complete event record for printing
; 0000:462A calendar_getRecurrenceInfo         84  Get recurrence type info for event
; 0000:467E calendar_getRecurrenceType         71  Get recurrence type code
; 0000:46C5 calendar_handleRecurrence         265  Handle recurring event logic
; 0000:47CE calendar_editEventDialog          518  Event edit dialog (form-based editor)
; 0000:49D4 calendar_initFormControls         139  Initialize form field controls
; 0000:4A5F calendar_getFormFieldValue         55  Get value from form field
; 0000:4A96 calendar_setFormFieldValue         49  Set value in form field
; 0000:4AC7 calendar_clearFormField            42  Clear a form field
; 0000:4AF1 calendar_validateFormField         55  Validate form field value
; 0000:4B28 calendar_handleEventForm          426  Handle event edit form interactions
; 0000:4CD2 calendar_handleAlarmSetup         417  Handle alarm setup/configuration
; 0000:4E73 calendar_handleAlarmEdit          301  Handle alarm time edit
; 0000:4FA0 calendar_handleAlarmToggle        133  Handle alarm enable/disable toggle
; 0000:5025 calendar_handleAlarmRepeat        185  Handle alarm repeat settings
; 0000:50DE calendar_handleFormEvent          214  Handle form event in event editor
; 0000:51B4 calendar_notifySystemDate          23  Notify system of date change
; 0000:51CB calendar_createNewEvent           236  Create a new blank event record
; 0000:52B7 calendar_editExistingEvent        411  Edit an existing event record
; 0000:5452 calendar_deleteEvent               98  Delete current event
; 0000:54B4 calendar_copyEvent                 60  Copy event to clipboard
; 0000:54F0 calendar_readCalendarFile         420  Read and parse .CAL file
; 0000:5694 calendar_saveCalendarFile          21  Save current calendar data to file
; 0000:56A9 calendar_openCalFile              131  Open a .CAL file
; 0000:572C calendar_getFileExtension          21  Get ".CAL" file extension string
; 0000:5741 calendar_buildFilename             70  Build full filename with .CAL extension
; 0000:5787 calendar_fileOpenDialog           217  File Open dialog handler
; 0000:5860 calendar_formatFileListEntry       88  Format entry for file list display
; 0000:58B8 calendar_formatFileInfo            98  Format file info (size, date)
; 0000:591A calendar_handleFileMenu           269  Handle File menu commands
; 0000:5A27 calendar_commitAndSave             28  Commit changes and save file
; 0000:5A43 calendar_checkUnsavedChanges       47  Check for unsaved changes, prompt save
; 0000:5A72 calendar_handleFileNew             86  Handle File > New command
; 0000:5AC8 calendar_main                    1170  _main() - init, load file, enter event loop
; 0000:5F5A calendar_getScreenDimensions       60  Get screen width/height
; 0000:5F96 calendar_handleResize             618  Handle window resize event
; 0000:6200 calendar_loadEventList             61  Load events for current date range
; 0000:623D calendar_triggerReload             34  Trigger full reload of calendar data
; 0000:625F calendar_reloadAndRefresh         160  Reload calendar file and refresh display
; 0000:62FF calendar_handleViewChange         129  Handle view mode change request
; 0000:6380 calendar_handleMenuCommand        415  Menu command dispatcher
; 0000:651F calendar_setupEventFields         307  Set up event form fields
; 0000:6652 calendar_eventEditorMain         1291  Main event editor routine
; 0000:6B5D calendar_getEventCount             46  Get count of events for current day
; 0000:6B8B calendar_formatEventListEntry     237  Format event for list display
; 0000:6C78 calendar_getEventTimeString        73  Get formatted time string for event
; 0000:6CC1 calendar_buildEventList           111  Build event list for current day
; 0000:6D30 calendar_clearEventList            99  Clear event list display
; 0000:6D93 calendar_formatEventFields         91  Format event fields for display
; 0000:6DEE calendar_dispatchViewHandler       66  Dispatch to view-specific handler (1-4)
; 0000:6E30 calendar_initViewHandler          148  Initialize view-specific handler
; 0000:6EC4 calendar_checkEventAtDate          53  Check if events exist at given date
; 0000:6EF9 calendar_resetViewState            17  Reset view state variables
; 0000:6F0A calendar_processEvent            1579  Main event processor (keyboard/menu/form)
;
; --- Navigation and Date Arithmetic ---
;
; 0000:7535 calendar_printCurrentDay           71  Print current day's events
; 0000:757C calendar_invokeViewRenderer        37  Call view-specific render function
; 0000:75A1 calendar_getDateComponents        104  Get year/month/day components from date
; 0000:7609 calendar_prepareMonthView         138  Prepare month view for display
; 0000:7693 calendar_setMonthField             56  Set month field and update display
; 0000:76CB calendar_handleMonthChange        111  Handle month change navigation
; 0000:773A calendar_updateMonthField          54  Update month field with validation
; 0000:7770 calendar_setDateFromComponents     84  Set date from year/month/day components
; 0000:77C4 calendar_checkViewBounds           47  Check if date is within view bounds
; 0000:77F3 calendar_checkDailyBounds          20  Check if time is within daily view bounds
; 0000:7807 calendar_checkPrintBounds           7  Check if within print bounds
; 0000:780E calendar_handleMonthViewEvent     397  Handle event in month view mode
; 0000:799B calendar_enterMonthView            25  Enter month view (set DS, init)
; 0000:79B4 calendar_setupMonthRenderer        86  Set up month view renderer
; 0000:7A0A calendar_drawMonthView            270  Draw complete month view
; 0000:7B18 calendar_getMonthViewState         57  Get month view state info
; 0000:7B51 calendar_handleMonthNavigation    292  Handle navigation within month view
; 0000:7C75 calendar_updateDateDisplay         54  Update date string display
; 0000:7CAB calendar_handleWeekViewEvent      464  Handle event in weekly view mode
; 0000:7E7B calendar_enterWeekView             25  Enter week view (set DS, init)
; 0000:7E94 calendar_setupWeekRenderer         86  Set up week view renderer
; 0000:7EEA calendar_drawWeekView             198  Draw complete week view
; 0000:7FB0 calendar_getWeekViewState          69  Get week view state info
; 0000:7FF5 calendar_drawWeekDayColumns       459  Draw day columns in week view
; 0000:81C0 calendar_handleWeekDaySelect      212  Handle day selection in week view
; 0000:8294 calendar_selectWeekDay            125  Select a specific day in week view
; 0000:8311 calendar_validateWeekDate          97  Validate date within week view range
; 0000:8372 calendar_getWeekStartDate          53  Get start date of current week
; 0000:83A7 calendar_handleWeekNavigation     386  Handle navigation within week view
; 0000:8529 calendar_commitFormChanges          32  Commit any pending form changes
; 0000:8549 calendar_clearGridRegion            35  Clear a region of the calendar grid
; 0000:856C calendar_updateDateRange          102  Update displayed date range
; 0000:85D2 calendar_refreshDateHeader         76  Refresh date header display
; 0000:861E calendar_handleWeekEventEdit      238  Handle event editing in week view
; 0000:870C calendar_handleWeekResize         117  Handle resize in weekly view
; 0000:8781 calendar_handleFileOpen            85  Handle File > Open command
; 0000:87D6 calendar_handleFileSaveAs         131  Handle File > Save As command
; 0000:8859 calendar_handleEditDelete         100  Handle Edit > Delete command
; 0000:88BD calendar_handleDailyBoundsCheck    45  Check daily view bounds
; 0000:88EA calendar_handleDailyEventCreate   271  Handle event creation in daily view
; 0000:89F9 calendar_handleDailyViewEvent     947  Handle event in daily view mode
; 0000:8DAC calendar_enterDailyView            28  Enter daily view (set DS, init)
; 0000:8DC8 calendar_setupDailyRenderer        92  Set up daily view renderer
; 0000:8E24 calendar_drawDailyView            151  Draw complete daily view
; 0000:8EBB calendar_getDailyViewState         69  Get daily view state info
; 0000:8F00 calendar_handleDailyNavigation    250  Handle navigation within daily view
; 0000:8FFA calendar_updateDailyDisplay        79  Update daily view display
; 0000:9049 calendar_getAlarmState              40  Get alarm state for current event
; 0000:9071 calendar_toggleAlarm               39  Toggle alarm on/off for current event
; 0000:9098 calendar_handleAlarmMenu          184  Handle alarm menu commands
; 0000:9150 calendar_handlePrintMenu          130  Handle print menu commands
; 0000:91D2 calendar_handleOptionsMenu        658  Handle Options menu commands
; 0000:9464 calendar_enterEventEditor          28  Enter event editor (set DS, init)
; 0000:9480 calendar_handleSearchMenu         231  Handle Search menu commands
; 0000:9567 calendar_handleSearchAction       493  Handle search/find action
; 0000:9754 calendar_handleGotoAction         121  Handle Go To Date action
; 0000:97CD calendar_drawSearchResult         215  Draw search result highlight
; 0000:98A4 calendar_handleFindNext           153  Handle Find Next command
; 0000:993D calendar_clearSearchHighlight       65  Clear search highlight
; 0000:997E calendar_performSearch            175  Perform search in event database
; 0000:9A2D calendar_handleSearchDialog       276  Handle search dialog interactions
; 0000:9B41 calendar_resetSearchState          48  Reset search state
; 0000:9B71 calendar_handleSearchResults      265  Handle search results display
; 0000:9C7A calendar_checkSearchMatch          51  Check if event matches search criteria
; 0000:9CAD calendar_continueSearch            51  Continue search from current position
; 0000:9CE0 calendar_searchForward            141  Search forward through events
; 0000:9D6D calendar_searchBackward            96  Search backward through events
; 0000:9DCD calendar_handleSearchOptions      178  Handle search options/criteria
; 0000:9E7F calendar_loadSearchState          121  Load saved search state
; 0000:9EF8 calendar_handleSearchFilter        86  Handle search filter settings
; 0000:9F4E calendar_handleEventForm_2        441  Handle event form (search context)
; 0000:A107 calendar_handleGotoResult          99  Handle goto search result
; 0000:A16A calendar_navigateToEvent          215  Navigate to specific event
; 0000:A241 calendar_loadEventRecord          197  Load event record from database
; 0000:A306 calendar_handleSearchNavigation   283  Handle navigation in search results
; 0000:A421 calendar_handleSearchList         195  Handle search result list display
; 0000:A4E4 calendar_getSearchResultCount      86  Get search result count
; 0000:A53A calendar_handleGotoDialog         450  Handle Go To Date dialog
; 0000:A6FC calendar_getDateFromDialog         43  Get date from dialog fields
; 0000:A727 calendar_notifyViewChange          23  Notify view of data change
; 0000:A73E calendar_getAlarmCount             13  Get count of active alarms
; 0000:A74B calendar_getAlarmFlag               8  Get alarm flag for current context
; 0000:A753 calendar_validateAlarmSettings     88  Validate alarm time settings
; 0000:A7AB calendar_getRecurrenceCode         17  Get recurrence type code
; 0000:A7BC calendar_getRepeatInterval          8  Get repeat interval for recurring event
; 0000:A7C4 calendar_handleAlarmNotify        246  Handle alarm notification/trigger
; 0000:A8BA calendar_checkAlarmTrigger         91  Check if alarm should trigger now
; 0000:A915 calendar_getEventFieldValue        63  Get a field value from event record
; 0000:A954 calendar_updateAlarmState          93  Update alarm state after change
; 0000:A9B1 calendar_loadAlarmSettings         99  Load alarm settings from record
; 0000:AA14 calendar_getFieldPointer           38  Get pointer to field in event record
; 0000:AA3A calendar_getFieldByIndex          142  Get field by index from event
; 0000:AAC8 calendar_getFieldByType           154  Get field by type code from event
; 0000:AB62 calendar_buildRecurrenceList      320  Build list of recurring event instances
; 0000:ACA2 calendar_getRecurrenceCount        68  Get count of recurrence instances
; 0000:ACE6 calendar_handleRecurrenceEdit     186  Handle editing of recurrence settings
; 0000:ADA0 calendar_handleAlarmConfig        186  Handle alarm configuration dialog
; 0000:AE5A calendar_loadRecurrenceData       138  Load recurrence data from record
; 0000:AEE4 calendar_handleRecurrenceDialog   278  Handle recurrence settings dialog
; 0000:AFFA calendar_saveRecurrenceData       262  Save recurrence data to record
; 0000:B100 calendar_updateRecurrenceView     220  Update recurrence view display
; 0000:B1DC calendar_handleAlarmList          145  Handle alarm list display
; 0000:B26D calendar_loadAlarmRecord          154  Load alarm record from database
; 0000:B307 calendar_addAlarm                 143  Add alarm to event
; 0000:B396 calendar_removeAlarm              143  Remove alarm from event
; 0000:B425 calendar_updateAlarm              144  Update alarm time/settings
; 0000:B4B5 calendar_loadEventsByDateRange    284  Load events for a date range
; 0000:B5D1 calendar_filterEventsByDate       342  Filter events by specific date
; 0000:B727 calendar_buildDailyEventList      331  Build event list for a single day
; 0000:B872 calendar_handleRecurrenceRefresh   76  Refresh recurrence display
; 0000:B8BE calendar_saveEventChanges         186  Save changes to current event
; 0000:B978 calendar_getEventSummary          129  Get summary text for event
; 0000:B9F9 calendar_getEventDetail           115  Get detail text for event
; 0000:BA6C calendar_handleAlarmService       471  Handle alarm service interactions
; 0000:BC43 calendar_checkEventConflict       201  Check for time conflicts with other events
; 0000:BD0C calendar_getConflictInfo           99  Get conflict information
; 0000:BD6F calendar_handlePrintSetup         130  Handle print setup dialog
; 0000:BDF1 calendar_getPrintConfig            97  Get print configuration
; 0000:BE52 calendar_handlePrintRange         149  Handle print date range selection
; 0000:BEE7 calendar_validatePrintRange       123  Validate print date range
; 0000:BF62 calendar_handleEditMenu           169  Handle Edit menu commands
; 0000:C00B calendar_handleEditCopy           107  Handle Edit > Copy command
; 0000:C076 calendar_handleEditPaste          134  Handle Edit > Paste command
; 0000:C0FC calendar_getClipboardEventCount    47  Get count of events in clipboard
; 0000:C12B calendar_getClipboardState         56  Get clipboard state flags
; 0000:C163 calendar_handleEventFormEdit      906  Handle event form editing session
; 0000:C4ED calendar_handleEventListNav       111  Handle navigation in event list
; 0000:C55C calendar_handleEventListSelect    119  Handle event selection in list
; 0000:C5D3 calendar_handleEventListForm      314  Handle form interactions in event list
; 0000:C70D calendar_handleDailyEventNav      112  Handle event navigation in daily view
; 0000:C77D calendar_handleDailyEventForm     560  Handle daily event form editing
; 0000:C9AD calendar_handleDailyPrintDialog   159  Handle print dialog from daily view
; 0000:CA4C calendar_handleDailyEventDelete    77  Handle event deletion from daily view
; 0000:CA99 calendar_handleDailyAlarmSetup     94  Handle alarm setup from daily view
; 0000:CAF7 calendar_handleEventFormNavigation 257  Handle navigation in event edit form
; 0000:CBF8 calendar_callDbFunction            32  Call DMDB function via dispatch table
; 0000:CC18 calendar_callDbWithParam           81  Call DMDB function with parameter
; 0000:CC69 calendar_handleDbOperation        191  Handle database operation result
; 0000:CD28 calendar_readConfigFile           108  Read calendar configuration file
; 0000:CD94 calendar_getDataSegment_main        2  Return DS (module entry utility)
;
; --- CRT Initialization and DM89 Dispatch (sub_0CD94 area) ---
;
; 0000:CD94 calendar_getDS                      2  Return current DS
; 0000:CD97 calendar_crtEntryTable            (data) CRT entry point table:
;            0000:CD97  lcall _initBSS (0xCDB3)
;            0000:CD9A  lcall _initData (0xCDB6)
;            0000:CDA0  push args, call sub_06F0A (main event processor)
;            0000:CDB3  call sub_0CDD2 (CRT init)
;            0000:CDB7  call sub_0DDEA (BSS init)
;            0000:CDBB  call sub_0DFEB (exit cleanup)
;            0000:CDBF  call sub_0CDC3 (emergency exit)
;
; 0000:CDC3 calendar_emergencyExit             15  Emergency exit (init+exit+callback)
; 0000:CDD2 calendar_crtInit                  196  CRT initialization:
;            - INT 21h AH=30h: get DOS version
;            - INT 21h AH=35h: get INT 00h vector, save it
;            - INT 21h AH=25h: set INT 00h vector to div-by-zero handler
;            - Process command line environment
;            - INT 21h AH=44h: IOCTL - check device type for file handles 0-4
;            - Set up file handle flags in [0x28E0]
; 0000:CE96 calendar_callExitCleanup           23  Call exit routines
; 0000:CEAD calendar_exitProcess               69  Exit process:
;            - INT 21h AH=3Eh: close open file handles
;            - INT 21h AH=4Ch: terminate process
;            - INT 21h AH=25h: restore saved INT 00h vector
; 0000:CEF2 calendar_restoreInt00              25  Restore original INT 00h vector
; 0000:CF0B calendar_indirectCall              15  Indirect function call via CX register
; 0000:CF1A calendar_runStartup               222  Run startup sequence (parse args, init)
;
; --- PRGUF/DMGUF Resource Loading ---
;
; 0000:CFF8 calendar_loadDmgufResource         66  Load DMGUF resource module:
;            - INT E0h AX=0206h with DMGUF name at [0x2910]
;            - Stores dispatch pointer at [0x290C]/[0x290E]
;            - INT E0h AX=0208h to execute resource init
;            - Sets [0x2916] flag based on result
; 0000:D03A calendar_unloadDmgufResource      169  Unload DMGUF resource:
;            - INT E0h AX=0207h to unload
;            - Reset dispatch pointers to default stubs
;
; --- PRGUF Dispatch Thunks (far-call via [0x2902]/[0x2904]) ---
;
; The primary PRGUF dispatcher at loc_0D062 handles function codes 0x00-0x38+
; by checking [0x2916] to determine if PRGUF or DMGUF is active, then
; dispatching via the stored far pointer at [0x2902].
;
; The secondary DMGUF dispatcher at loc_0D0A6 handles function codes 0x1A+
; by dispatching via the stored far pointer at [0x290C].
;
; 0000:D05A calendar_prgufStubRetFF           (code) Default PRGUF stub: return -1
; 0000:D05E calendar_dmgufStubRetFF           (code) Default DMGUF stub: return -1
; 0000:D062 (loc) prguf_dispatch                    Primary PRGUF dispatch entry
; 0000:D0A6 (loc) dmguf_dispatch                    Secondary DMGUF dispatch entry
;
; 0000:D0E3 prguf_getFieldValue                6  PRGUF func 0x00: get field value
; 0000:D0E9 prguf_func_0C                      6  PRGUF func 0x0C: get record info
; 0000:D0EF prguf_func_0E                      6  PRGUF func 0x0E: navigate record
; 0000:D0F5 prguf_func_13                      6  PRGUF func 0x13: get field list
; 0000:D0FB dmguf_openForm                     12  DMGUF func 0x1A: open form
;      D101 prguf_func_22                      6  PRGUF func 0x22: get field info
; 0000:D107 prguf_func_23                      6  PRGUF func 0x23: set field property
; 0000:D10D prguf_func_24                      6  PRGUF func 0x24: get/set field attr
; 0000:D113 dmguf_readRecord                   6  DMGUF func 0xAF: read record
; 0000:D119 dmguf_setFormField                 6  DMGUF func 0xB3: set form field
; 0000:D11F dmguf_getFormStatus                6  DMGUF func 0xB4: get form status
; 0000:D125 prguf_setFieldFormat               6  PRGUF func 0x38: set field format
;
; --- DMDB Resource Module Loading & Dispatch ---
;
; 0000:D12B calendar_loadDbModule             104  Load DMDB resource module:
;            - Compare module name at [0x2920] with environment
;            - INT E0h AX=0206h to load DMDB resource at [0x2922]
;            - INT E0h AX=0700h: cooperative yield
;            - INT E0h AX=0207h: unload if yield requested
;            - Store dispatch table at [0x3162]
;
; 0000:D193 calendar_dbFileIoDispatch         208  DMDB file I/O dispatcher:
;            - Handles file read/write via stack switch
;            - INT E0h AX=0600h: poll for event
;            - INT E0h AX=060Eh: dispatch event
;            - INT E0h AX=0603h: file write (2 call sites)
;            - Manages separate I/O stack at [0x2928]/[0x292A]
;
; --- DMDB API Thunks (6-byte stubs: load AX, jmp to dispatcher) ---
;
; 0000:D263 dmdb_getStatus                     6  DMDB func 0x0501: get status
; 0000:D269 dmdb_func_0401                     6  DMDB func 0x0401: validate field
; 0000:D26F dmdb_func_0402                     6  DMDB func 0x0402: field operation
; 0000:D275 dmdb_func_0601                     6  DMDB func 0x0601: file service
; 0000:D27B dmdb_func_0604                     6  DMDB func 0x0604: file service 2
; 0000:D281 dmdb_func_060E                     6  DMDB func 0x060E: close/finalize
; 0000:D287 dmdb_func_0004                     6  DMDB func 0x0004: set error handler
;
; 0000:D28D calendar_loadDbResource            25  Load DMDB via INT E0h AX=0206h
; 0000:D2A6 calendar_unloadDbResource          15  Unload DMDB via INT E0h AX=0207h
; 0000:D2B5 calendar_initDbEngine               7  Init DB engine (load + init)
; 0000:D2BC calendar_shutdownDbEngine           7  Shutdown DB engine (deinit + unload)
;
; 0000:D2C3 dmdb_genericDispatch               40  Generic DMDB dispatch (resolve + call)
; 0000:D2EB dmdb_beginTransaction               6  DMDB func 0x2006: begin transaction
; 0000:D2F1 dmdb_endTransaction                 6  DMDB func 0x2007: end transaction
; 0000:D2F7 dmdb_getEvent                       6  DMDB func 0x2013: get/dispatch event
; 0000:D2FD dmdb_peekEvent                      6  DMDB func 0x2014: peek at next event
; 0000:D303 dmdb_putEvent                       6  DMDB func 0x2015: put event back
; 0000:D309 dmdb_closeSession                   6  DMDB func 0x2016: close editing session
; 0000:D30F dmdb_refreshView                    6  DMDB func 0x2017: refresh view
; 0000:D315 dmdb_updateView                     6  DMDB func 0x2018: update view display
; 0000:D31B dmdb_createFormRow                  6  DMDB func 0x201B: create form row
; 0000:D321 dmdb_setFormRow                     6  DMDB func 0x201C: set form row content
; 0000:D327 dmdb_deleteFormRow                  6  DMDB func 0x201E: delete form row
; 0000:D32D dmdb_setRowMode_input               6  DMDB func 0x2020: set row to input mode (*)
; 0000:D333 dmdb_setRowMode_display             6  DMDB func 0x2021: set row to display mode (*)
; 0000:D339 dmdb_beginEditSession              42  DMDB func 0x2022: begin edit session (*)
; 0000:D363 dmdb_getFieldExtent                12  DMDB func 0x2024: get field extent (*)
; 0000:D36F dmdb_allocWorkspace                12  DMDB func 0x202E: alloc workspace (*)
; 0000:D37B dmdb_setActiveWorkspace            24  DMDB func 0x202F+: workspace ops (*)
; 0000:D393 dmdb_getWindowMetric                6  DMDB func 0x203F: get window metric
; 0000:D399 dmdb_getFieldMetric_0               6  DMDB func 0x2040: get field metric 0
; 0000:D39F dmdb_getFieldMetric_1               6  DMDB func 0x2041: get field metric 1
; 0000:D3A5 dmdb_setFieldMetric_0               6  DMDB func 0x2042: set field metric 0
; 0000:D3AB dmdb_setFieldMetric_1              12  DMDB func 0x2043: set field metric 1
; 0000:D3B7 dmdb_getRecordMetric               18  DMDB func 0x204A: get record metric
; 0000:D3C9 dmdb_refreshTitleBar                6  DMDB func 0x206A: refresh title bar
; 0000:D3CF dmdb_getRecordPosition              6  DMDB func 0x206D: get record position
; 0000:D3D5 dmdb_setFileHandle                  6  DMDB func 0x2079: set file handle
; 0000:D3DB dmdb_setFieldDef                   48  DMDB func 0x207B: set field definition
; 0000:D40B dmdb_setFormLayout                  6  DMDB func 0x207D: set form layout
; 0000:D411 dmdb_getPrintConfig_0               6  DMDB func 0x2086: get print config 0
; 0000:D417 dmdb_getPrintConfig_1               6  DMDB func 0x2087: get print config 1
; 0000:D41D dmdb_setPrintConfig                 6  DMDB func 0x2089: set print config
; 0000:D423 dmdb_getPrintExtent                 6  DMDB func 0x208D: get print extent
; 0000:D429 dmdb_closePrintSession              6  DMDB func 0x208F: close print session
; 0000:D42F dmdb_setDatabaseSize                6  DMDB func 0x2091: set database size
; 0000:D435 dmdb_setViewMode                    6  DMDB func 0x2099: set view mode
; 0000:D43B dmdb_setPrinterDevice               6  DMDB func 0x209D: set printer device
; 0000:D441 dmdb_getViewState                   6  DMDB func 0x20A3: get view state
; 0000:D447 dmdb_setViewState                   6  DMDB func 0x20A4: set view state
; 0000:D44D dmdb_setWindowExtent                6  DMDB func 0x20A9: set window extent (*)
; 0000:D453 dmdb_getWindowExtent                6  DMDB func 0x20AA: get window extent (*)
; 0000:D459 dmdb_openPrintSession              18  DMDB func 0x20AC: open print session
; 0000:D46B dmdb_setWindowTitle                 6  DMDB func 0x20B9: set window title
; 0000:D471 dmdb_setWindowName                  6  DMDB func 0x20BA: set window name
; 0000:D477 dmdb_initEditSession                6  DMDB func 0x20D0: init editing session
; 0000:D47D dmdb_openFile                       7  DMDB func 0x20E3: open file
; 0000:D484 dmdb_closeFile                     74  DMDB func 0x20E4: close file (w/ dispatch)
; 0000:D4CE calendar_callDbDispatch            78  Call DMDB dispatch with function code
; 0000:D51C calendar_dbSessionInit             56  Init DMDB session: create + configure
; 0000:D554 calendar_dbSessionSetup            38  Set up DMDB session state
; 0000:D57A dm_pollEvent                       14  INT E0h AX=0600h: poll for event
; 0000:D588 calendar_pollAndDispatch           45  Poll for event and dispatch
; 0000:D5B5 dm_unloadFormModule_a              13  INT E0h AX=0207h: unload form module (var A)
; 0000:D5C2 dm_unloadFormModule_b              35  INT E0h AX=0207h: unload form module (var B)
; 0000:D5E5 calendar_unloadBothModules         30  Unload both PRGUF and DMGUF form modules
; 0000:D603 calendar_fullCleanup              117  Full resource cleanup sequence
;
; --- Print Engine ---
;
; 0000:D678 calendar_printEngine              505  Print engine: format and output events
; 0000:D871 calendar_printRecursive            28  Recursive print helper
; 0000:D88D calendar_printLineBreak            12  Print line break / newline
; 0000:D899 calendar_printPageBreak            17  Print page break
; 0000:D8AA calendar_printHeader              139  Print page header (date, title)
; 0000:D935 prguf_func_AE                      6  PRGUF func 0xAE: open file (for print)
; 0000:D93B dmdb_util_dispatch                 14  DMDB utility dispatch
; 0000:D949 dmdb_util_dispatch_2               16  DMDB utility dispatch (variant 2)
; 0000:D959 dmdb_util_dispatch_3               21  DMDB utility dispatch (variant 3)
; 0000:D96E dmdb_util_0                         6  DMDB utility thunk 0
; 0000:D974 dmdb_util_1                         6  DMDB utility thunk 1
; 0000:D97A dmdb_util_2                         6  DMDB utility thunk 2
; 0000:D980 dmdb_util_3                         6  DMDB utility thunk 3
; 0000:D986 dmdb_util_4                         6  DMDB utility thunk 4
; 0000:D98C dmdb_util_5                         6  DMDB utility thunk 5
; 0000:D992 dmdb_util_6                         6  DMDB utility thunk 6
; 0000:D998 dmdb_util_7                         6  DMDB utility thunk 7
; 0000:D99E dmdb_resolveFunc_0                  6  DMDB: resolve function pointer 0
; 0000:D9A4 dmdb_resolveFunc_1                  6  DMDB: resolve function pointer 1
; 0000:D9AA calendar_dbCallWithResolve        147  DMDB call with function resolution
; 0000:DA3D calendar_dbGetResolvedPtr          15  Get resolved DMDB function pointer
; 0000:DA4C calendar_dbResourceDispatch       595  DMDB resource dispatch table handler
;
; --- Low-level I/O and Memory ---
;
; 0000:DC9F calendar_fileIoHandler            288  File I/O handler (read/write via DMDB)
; 0000:DDBF calendar_ioStatusCheck             43  Check I/O operation status
; 0000:DDEA calendar_initBSSData               38  Initialize BSS data segment
; 0000:DE10 calendar_initDataSegment          432  Initialize data segment (strings, tables)
; 0000:DFC0 calendar_exitCleanup               43  Exit cleanup (free resources)
; 0000:DFEB calendar_runExitHandlers           41  Run exit handler chain
;
; --- DeskMate INT E0h Wrappers ---
;
; 0000:E014 calendar_writeStderr               66  Write to stderr (INT 21h AH=40h, handle 2)
; 0000:E056 calendar_dmCallWrapper_056         64  DM call wrapper (general purpose)
; 0000:E096 calendar_dmCallWrapper_096         50  DM call wrapper (form/dialog)
; 0000:E0C8 calendar_compareStrings            44  Compare two strings (memcmp variant)
; 0000:E0F4 calendar_getStringResource         28  Get string from resource table
; 0000:E110 calendar_getStringById             54  Get string by ID from resource array
; 0000:E146 calendar_copyToBuffer              62  Copy data to buffer with length
; 0000:E184 calendar_getResourcePtr            28  Get resource pointer
; 0000:E1A0 calendar_formatString             148  Format string (sprintf-like)
; 0000:E234 calendar_nop                        1  NOP (alignment byte)
; 0000:E235 calendar_formatString_2            71  Format string variant 2
; 0000:E27C calendar_memcpyFar                 30  Far memory copy
; 0000:E29A calendar_strlenFar                 66  Far string length
; 0000:E2DC calendar_memsetFar                 88  Far memory set
; 0000:E334 calendar_setDateValue              40  Set date value in structure
; 0000:E35C calendar_getDateValue              44  Get date value from structure
; 0000:E388 calendar_compareValues             46  Compare two values
; 0000:E3B6 calendar_getInterruptVector        50  Get interrupt vector (INT 21h AH=35h)
; 0000:E3E8 calendar_callThunk                  6  Call thunk via pointer
; 0000:E3EE calendar_resolveThunk              46  Resolve thunk address
; 0000:E41C calendar_initBSSZero              180  Zero-fill BSS region
;
; --- MSC 5.x C Runtime Library ---
;
; (Located within seg_0000, addresses above 0xE41C are CRT/library code)
;
; --- CRT Startup (segment 0E4D) ---
;
; 0E4D:0000 start                            323  MSC 5.x CRT startup (_cstart)
;            - PSP check and memory model setup
;            - INT 20h vector at PSP:0000
;            - Calculate available memory, set up SS:SP
;            - INT 21h AH=4Ah: resize memory block
;            - Save PSP segment to [0x28D7]
;            - Zero BSS (0x3122..0x7FF0)
;            - Far-call CRT init at 0xCDB3
;            - Far-call data init at 0xCD98
;            - Set exit callback [0x2864] = 0xCE96
;            - Far-call _main() at 0xCDBF with argc=3
;            - DeskMate host callback loop:
;              * INT E0h AX=0600h (event poll)
;              * INT E0h AX=060Dh (check status >= 0x4411)
;              * INT E0h AX=4D06h (task switch if status high enough)
;              * Copy 14 bytes of event data from caller to CS:[0x12]
;              * Open files via sub_0E819 (AX=0x20DF)
;              * INT 21h AH=34h (get InDOS flag address)
;
; 0E4D:0344 crt_closeFile                      5  Close file handle (DMDB func 0x20E0)
; 0E4D:0349 crt_openFile                       5  Open file handle (DMDB func 0x20DF)
; 0E4D:034E crt_getWindowHeight                5  Get window height (DMDB func 0x203B)
; 0E4D:0353 crt_getWindowWidth                 5  Get window width (DMDB func 0x203A)
; 0E4D:0358 crt_readFileBlock                  5  Read file block (DMDB func 0x202B)
; 0E4D:035D crt_writeFileBlock                 5  Write file block (DMDB func 0x202C)
; 0E4D:0362 crt_refreshForm                    5  Refresh form (DMDB func 0x2132)
; 0E4D:0367 crt_commitForm                     5  Commit form (DMDB func 0x2131)
; 0E4D:036C crt_getFormVersion                 3  Get form version (DMDB func 0x2111)
; 0E4D:036F crt_genericDispatch               30  Generic DMDB far-call dispatcher
;
; 0E4D:037B crt_callFormEngine                (code) Far-call to form engine entry
;            - Sets DS to 0x0E87 (DGROUP), calls sub_0D9B0 (DMDB resource)
;
; 0E4D:038D sub_0E85D                        5767  DM89 import table resolver and dispatch
;            - Sets DS to 0x0E87 (DGROUP)
;            - Calls sub_0DACE (DMDB resource dispatch)
;            - This is the largest function; contains the full relocation
;              table with import entries for PRGUF/DMGUF/DMDB
;
; 0E4D:039E (data) DM89 relocation/import table
;            - "MS RunTime Library - Copyright (c) 1987, Microsoft Corp\x1E"
;            - Followed by structured import table entries:
;              Each entry: offset(2), segment(2), flags(1), import_id(2)
;              Maps DM89 thunk calls to resolved function addresses
;
; 0E4D:04F5 (data) Segment fixup table
;            - Segment address pairs for relocation processing
;
; --- DM89 Import Far-Call Dispatcher (segment 0E56) ---
;
; 0E56:0000 sub_0FEE4                        4598  DM89 import table resolver
;            - Processes the import/relocation table at 0E4D:039E
;            - Resolves far-call targets for all PRGUF/DMGUF imports
;            - Contains sprintf, string formatting engine
;            - Calls sub_0E235 (format string) and sub_0E613 (format dispatch)
;
; 0E56:012F sub_0E613                         192  Format dispatch (number/string formatting)
; 0E56:01EF sub_0E6D3                         321  Extended format dispatch
;
; --- C Runtime Library Functions (in segment 0E56) ---
;
; The CRT library occupies the latter portion of the DM89 dispatch segment.
; These functions are standard MSC 5.x runtime implementations.
;
; 110DA  calendar_setDateField_far             25  Far version of setDateField_year
; 110F3  calendar_setDateField_far_2          238  Far version of setDateField_month
; 111E1  calendar_getMonthLength_far          284  Far version of getMonthLength
; 112FD  calendar_computeDayOfYear_far        120  Far version of computeDayOfYear
; 11375  calendar_formatDateString_far        316  Far version of formatDateString
; 114B1  calendar_setDateComponents_far       269  Far version of setDateComponents
; 115BE  calendar_parseDateString_far         493  Far version of parseDateString
; 117AB  calendar_formatNumber_far            207  Far version of formatNumber
; 1187A  calendar_parseTimeField_far          279  Far version of parseTimeField
;
; ========================================================================
; INT E0h CALLS (DeskMate API)
; ========================================================================
;
; AX=0206h  Load resource module (PRGUF, DMGUF, DMDB/alarm modules)
;           - DS:DX -> resource name string
;           - BX -> parameter block pointer (for some calls)
;           - Returns: AX=1 on success, AX=0 on failure
;           - Called at: 0xCFAE, 0xD005, 0xD170, 0xD29B
;
; AX=0207h  Unload resource module
;           - DS:DX -> resource name string
;           - ES = DS (pushed/popped)
;           - Called at: 0xCFE8, 0xD044, 0xD18A, 0xD2B0, 0xD5A4, 0xD5BF
;
; AX=0208h  Execute resource function (call exported function in module)
;           - DS:DX -> resource name at [0x2906]
;           - BX -> callback pointer at [0x2902]
;           - Called at: 0xCFA3, 0xCFC5, 0xD023
;
; AX=020Bh  Form/dialog event handler (keyboard input processing)
;           - ES = DS
;           - Called at: 0xD5CC, 0xD5DF (two call sites for form input)
;
; AX=020Ch  Form/dialog redraw / refresh
;           - Called at: 0xD5FD/0xD600
;
; AX=0600h  Poll for event (get keyboard/mouse/timer input)
;           - Returns: AX = event code (0x8000 bit set = pending)
;           - Called at: 0xD17E, 0xD57A, 0xD1A0, 0xE5AA
;
; AX=0603h  File write / resource dispatch
;           - ES = SS (stack-based buffer)
;           - BX -> file handle at [0x292E]
;           - Called at: 0xD220, 0xD258
;
; AX=060Dh  Check event status
;           - Returns: AX = status code
;           - Used in CRT startup: compare >= 0x4411
;           - Called at: 0xE5B4
;
; AX=060Eh  Dispatch event / close file
;           - Called at: 0xD1AF
;
; AX=0700h  Allocate memory / cooperative yield
;           - Called at: 0xD181 (in alarm module load sequence)
;
; AX=4D04h  Load PDM application (shell service)
;           - DL = application ID
;           - Called at: 0xE6FC (in CRT startup)
;
; AX=4D05h  Unload PDM application (shell service)
;           - DL = application ID
;           - Called at: 0xE76A (in CRT startup)
;
; AX=4D06h  Switch to alternate PDM (task switch)
;           - Called at: 0xE5BE (in CRT startup, when status >= 0x4411)
;
; ========================================================================
; INT 21h CALLS (DOS API)
; ========================================================================
;
; AH=25h  Set interrupt vector
;         - AL=00h: set divide-by-zero handler to local stub
;         - Called at: 0xCDEE (set), 0xCF07 (restore)
;
; AH=30h  Get DOS version
;         - Returns: AL=major, AH=minor
;         - Called at: 0xCDD4
;
; AH=34h  Get InDOS flag pointer
;         - Returns: ES:BX -> InDOS flag
;         - Called at: 0xE5F8 (CRT startup)
;
; AH=35h  Get interrupt vector
;         - AL=00h: get divide-by-zero vector
;         - Returns: ES:BX -> handler
;         - Called at: 0xCDDD, 0xE3BE
;
; AH=3Eh  Close file handle
;         - BX = file handle
;         - Called at: 0xCEE3 (close open handles during exit)
;
; AH=40h  Write to file handle
;         - BX=2 (stderr), CX=count, DS:DX->buffer
;         - Called at: 0xE00B (write error message to stderr)
;
; AH=44h  IOCTL - Get device info
;         - AL=00h, BX=handle
;         - Returns: DX = device info word
;         - Called at: 0xCE72 (check handles 0-4 for device type)
;
; AH=4Ah  Resize memory block
;         - ES = segment, BX = new size in paragraphs
;         - Called at: 0xE530 (CRT startup), 0xE03C
;
; AH=4Ch  Terminate process
;         - AL = return code
;         - Called at: 0xCEF0 (normal exit), 0xE508 (error exit)
;
; AH=50h  Set PSP address
;         - BX = PSP segment
;         - Called at: 0xE737, 0xE745 (in CRT startup callback)
;
; AH=51h  Get PSP address
;         - Returns: BX = PSP segment
;         - Called at: 0xE729 (in CRT startup callback)
;
; ========================================================================
; OTHER INTERRUPTS
; ========================================================================
;
; INT 07h  (1 call) - Coprocessor not-present exception (likely CRT handler)
; INT 20h  (1 call) - Program terminate (at PSP:0000, CRT fallback)
; INT 28h  (1 call) - DOS idle interrupt (cooperative multitasking yield)
; INT ABh  (1 call) - Unknown (possibly Tandy-specific or TSR hook)
;
; ========================================================================
; MODULE ARCHITECTURE
; ========================================================================
;
; CALENDAR.PDM follows the standard DeskMate PDM architecture:
;
; 1. CRT Startup (seg_0E4D:0000)
;    - MSC 5.x _cstart initializes stack, BSS, environment
;    - Resolves DM89 imports (PRGUF, DMGUF function tables)
;    - Calls _main() with argc=3
;
; 2. Main Entry (calendar_main at 0000:5AC8)
;    - Loads resources: PRGUF, DMGUF, DMDB (alarm module optional)
;    - Opens .CAL file or creates new one
;    - Initializes monthly view as default
;    - Enters main event loop (calendar_mainEventLoop at 0000:1E73)
;
; 3. Event Loop (calendar_mainEventLoop)
;    - Polls for events via DMDB event dispatch
;    - Routes to view-specific handlers based on current view mode:
;      * Monthly: calendar_handleMonthViewEvent (0x780E)
;      * Weekly:  calendar_handleWeekViewEvent (0x7CAB)
;      * Daily:   calendar_handleDailyViewEvent (0x89F9)
;      * Editor:  calendar_eventEditorMain (0x6652)
;    - Handles menu commands via calendar_handleMenuCommand (0x6380)
;    - Processes keyboard navigation, timer ticks, resize events
;
; 4. View System
;    - Four views with dedicated render/navigate/event handlers
;    - Views share common date arithmetic (0x110C-0x1D7C range)
;    - Each view has enter/setup/draw/navigate/state functions
;    - View dispatcher at calendar_dispatchViewHandler (0x6DEE)
;
; 5. Event Database
;    - Events stored via DMDB (DeskMate Database) engine
;    - Operations: create, read, update, delete, search, filter
;    - Alarm support via ALRMINIT.RES / DMALARM.ACC integration
;    - Recurrence engine handles daily/weekly/monthly/yearly repeats
;
; 6. Print System
;    - Print engine at calendar_printEngine (0xD678)
;    - Supports page headers, event formatting, date range printing
;    - Uses DMDB print session management (open/close/config)
;
; 7. Resource Cleanup
;    - Reverse order unload: DMDB, DMGUF, PRGUF
;    - Restore INT 00h vector
;    - Exit via INT 21h AH=4Ch
;
; ========================================================================
; END OF HEADER
; ========================================================================
