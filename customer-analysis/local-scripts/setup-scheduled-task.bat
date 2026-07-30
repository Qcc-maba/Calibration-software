@echo off
setlocal

echo ============================================================
echo   QCC Analytics - הגדרת משימה מתוזמנת (Task Scheduler)
echo   הסנכרון ירוץ כל יום ב-03:00
echo ============================================================
echo.

set SCRIPT_DIR=%~dp0
set TASK_NAME=QCC_Analytics_Sync
set TASK_SCRIPT=%SCRIPT_DIR%run-sync-scheduled.bat

echo [INFO] Script path: %TASK_SCRIPT%
echo [INFO] Task name:   %TASK_NAME%
echo.

net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] יש להריץ קובץ זה כמנהל מערכת (Run as Administrator)
    echo         לחץ ימני על הקובץ ובחר "הפעל כמנהל מערכת"
    pause
    exit /b 1
)

schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] המשימה כבר קיימת - מוחק ומגדיר מחדש...
    schtasks /delete /tn "%TASK_NAME%" /f >nul
)

echo [INFO] יוצר משימה מתוזמנת...
schtasks /create ^
    /tn "%TASK_NAME%" ^
    /tr "\"%TASK_SCRIPT%\"" ^
    /sc DAILY ^
    /st 03:00 ^
    /ru SYSTEM ^
    /rl HIGHEST ^
    /f

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] המשימה נוצרה בהצלחה!
    echo.
    echo     שם המשימה : %TASK_NAME%
    echo     זמן הרצה  : כל יום ב-03:00
    echo     סקריפט    : %TASK_SCRIPT%
    echo     לוגים     : %SCRIPT_DIR%logs\
    echo.
    echo [INFO] בסיום הסנכרון, השרת יעתיק את הנתונים לפרודקשן
    echo        אוטומטית תוך 3 דקות.
    echo.
    echo [INFO] לבדיקת המשימה ידנית:
    echo        schtasks /run /tn "%TASK_NAME%"
    echo.
    echo [INFO] לצפייה בלוגים:
    echo        %SCRIPT_DIR%logs\
) else (
    echo.
    echo [ERROR] יצירת המשימה נכשלה!
    echo         נסה להריץ שוב כמנהל מערכת.
)

echo.
pause
