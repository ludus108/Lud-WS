@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "GIT=D:\PortableGit\cmd\git.exe"
cd /d "%~dp0"
for /f "delims=" %%R in ('"%GIT%" rev-parse --show-toplevel') do set "ROOT=%%R"

if not exist "%GIT%" (
    echo ERRORE: Git non trovato in:
    echo %GIT%
    pause
    exit /b 1
)

if not exist "%ROOT%\.gitmodules" (
    echo ERRORE: file .gitmodules non trovato in:
    echo %ROOT%
    pause
    exit /b 1
)

cd /d "%ROOT%"

call :loadSubmodules
if !SUBCOUNT! LEQ 0 (
    echo Nessun submodulo trovato.
    pause
    exit /b 1
)

:choose_repo
cls
echo ==================================
echo        SELEZIONE SUBMODULO
echo ==================================
for /L %%i in (1,1,!SUBCOUNT!) do (
    call echo %%i - %%SUBDISPLAY%%i%%
)
echo.
echo 0 - Esci
echo.
set /p repo_choice=Scelta: 

if "%repo_choice%"=="0" exit /b 0

call set "REPO_REL=%%SUBPATH%repo_choice%%"
call set "REPO_NAME=%%SUBNAME%repo_choice%%"
call set "REPO_URL=%%SUBURL%repo_choice%%"
call set "REPO_DISP=%%SUBDISPLAY%repo_choice%%"

if not defined REPO_REL (
    echo Scelta non valida.
    pause
    goto choose_repo
)

set "REPO=%ROOT%\%REPO_REL%"

if not exist "%REPO%\.git" (
    echo.
    echo ERRORE: il submodulo non sembra inizializzato:
    echo %REPO%
    echo.
    choice /m "Vuoi inizializzarlo ora"
    if errorlevel 2 goto choose_repo

    "%GIT%" submodule update --init --recursive "%REPO_REL%"
    if errorlevel 1 (
        echo Inizializzazione fallita.
        pause
        goto choose_repo
    )
)

cd /d "%REPO%"

:menu
cls
for /f "delims=" %%b in ('"%GIT%" branch --show-current') do set "CURRENT_BRANCH=%%b"
if not defined CURRENT_BRANCH set "CURRENT_BRANCH=(detached o sconosciuto)"

echo ==================================
echo           GIT MANAGER
echo ==================================
echo Submodulo: %REPO_DISP%
echo Nome: %REPO_NAME%
echo Path: %REPO%
echo URL: %REPO_URL%
echo Branch attuale: !CURRENT_BRANCH!
echo.
echo 1  - Status
echo 2  - Add all
echo 3  - Commit
echo 4  - Push
echo 5  - Pull
echo 6  - Status + Add + Commit + Push
echo 7  - Stash
echo 8  - Pop stash
echo 9  - Cambia branch
echo 10 - Cambia submodulo
echo 11 - Init/update submodules
echo 0  - Esci
echo.
set /p choice=Scelta: 

if "%choice%"=="1" goto status
if "%choice%"=="2" goto add
if "%choice%"=="3" goto commit
if "%choice%"=="4" goto push
if "%choice%"=="5" goto pull
if "%choice%"=="6" goto full
if "%choice%"=="7" goto stash
if "%choice%"=="8" goto popstash
if "%choice%"=="9" goto switchbranch
if "%choice%"=="10" goto choose_repo
if "%choice%"=="11" goto submodule_update
if "%choice%"=="0" exit /b 0
goto menu

:status
echo.
"%GIT%" status
pause
goto menu

:add
echo.
"%GIT%" add .
echo Add completato.
pause
goto menu

:commit
echo.
"%GIT%" status --porcelain | findstr . >nul
if errorlevel 1 (
    echo Nessuna modifica da committare.
    pause
    goto menu
)

set /p msg=Messaggio commit: 
if not defined msg (
    echo Messaggio vuoto. Commit annullato.
    pause
    goto menu
)
"%GIT%" commit -m "%msg%"
pause
goto menu

:push
echo.
"%GIT%" push
pause
goto menu

:pull
echo.
"%GIT%" pull
pause
goto menu

:full
echo.
"%GIT%" status
"%GIT%" add .
"%GIT%" status --porcelain | findstr . >nul
if errorlevel 1 (
    echo Nessuna modifica da committare.
    pause
    goto menu
)
set /p msg=Messaggio commit: 
if not defined msg (
    echo Messaggio vuoto. Operazione annullata.
    pause
    goto menu
)
"%GIT%" commit -m "%msg%"
"%GIT%" push
pause
goto menu

:stash
echo.
"%GIT%" stash
pause
goto menu

:popstash
echo.
"%GIT%" stash pop
pause
goto menu

:switchbranch
echo.
"%GIT%" fetch --all --prune >nul 2>&1

call :loadBranches
if !LOCALCOUNT! LEQ 0 (
    echo Nessun branch locale trovato.
    pause
    goto menu
)

echo Branch locali:
for /L %%i in (1,1,!LOCALCOUNT!) do (
    call set "B=%%LOCALBRANCH%%i%%"
    if /i "!B!"=="!CURRENT_BRANCH!" (
        call echo   L%%i - %%LOCALBRANCH%%i%%  [corrente]
    ) else (
        call echo   L%%i - %%LOCALBRANCH%%i%%
    )
)

echo.
if !REMOTECOUNT! GTR 0 (
    echo Branch remoti:
    for /L %%i in (1,1,!REMOTECOUNT!) do (
        call echo   R%%i - %%REMOTEDISPLAY%%i%%
    )
)

echo.
echo Scrivi:
echo - L1, L2, ... per branch locali
echo - R1, R2, ... per branch remoti
echo.
set /p bchoice=Scelta branch: 
if not defined bchoice goto menu

set "PREFIX=!bchoice:~0,1!"
set "INDEX=!bchoice:~1!"

if /i "!PREFIX!"=="L" (
    call set "SELECTED_BRANCH=%%LOCALBRANCH%INDEX%%"
    if not defined SELECTED_BRANCH (
        echo Scelta non valida.
        pause
        goto menu
    )
    if /i "!SELECTED_BRANCH!"=="!CURRENT_BRANCH!" (
        echo Sei gia' su questo branch.
        pause
        goto menu
    )
    "%GIT%" status --porcelain | findstr . >nul
    if not errorlevel 1 (
        echo Attenzione: hai modifiche locali non salvate.
        choice /m "Vuoi continuare comunque"
        if errorlevel 2 goto menu
    )
    "%GIT%" switch "%SELECTED_BRANCH%"
    pause
    goto menu
) else if /i "!PREFIX!"=="R" (
    call set "SELECTED_BRANCH=%%REMOTEBRANCH%INDEX%%"
    call set "SELECTED_DISPLAY=%%REMOTEDISPLAY%INDEX%%"
    if not defined SELECTED_BRANCH (
        echo Scelta non valida.
        pause
        goto menu
    )
    for %%X in ("%SELECTED_BRANCH%") do set "NEWLOCAL=%%~nxX"
    echo Creo branch locale "%NEWLOCAL%" che traccia "%SELECTED_DISPLAY%"
    "%GIT%" switch -c "%NEWLOCAL%" --track "%SELECTED_BRANCH%"
    pause
    goto menu
) else (
    echo Scelta non valida.
    pause
    goto menu
)

:submodule_update
echo.
"%GIT%" submodule update --init --recursive
pause
goto menu

:loadSubmodules
set /a SUBCOUNT=0
for /f "usebackq tokens=1,* delims==" %%A in (`"%GIT%" config -f "%ROOT%\.gitmodules" --get-regexp "^submodule\..*\.path$"`) do (
    set /a SUBCOUNT+=1
    set "SUBKEY!SUBCOUNT!=%%A"
    set "SUBPATH!SUBCOUNT!=%%B"
)

for /L %%i in (1,1,!SUBCOUNT!) do (
    call set "KEY=%%SUBKEY%%i%%"
    call set "PATHVAL=%%SUBPATH%%i%%"
    set "TMP=!KEY:submodule.=!"
    set "TMP=!TMP:.path=!"
    set "SUBNAME%%i=!TMP!"
    set "SUBURL%%i="
    for /f "usebackq delims=" %%U in (`"%GIT%" config -f "%ROOT%\.gitmodules" --get submodule.!TMP!.url`) do (
        set "SUBURL%%i=%%U"
    )
    set "SUBDISPLAY%%i=!TMP!  [!PATHVAL!]"
)

exit /b 0

:loadBranches
set /a LOCALCOUNT=0
set /a REMOTECOUNT=0

for /f "delims=" %%b in ('"%GIT%" branch --format="%%(refname:short)"') do (
    set /a LOCALCOUNT+=1
    set "LOCALBRANCH!LOCALCOUNT!=%%b"
)

for /f "delims=" %%b in ('"%GIT%" branch -r --format="%%(refname:short)"') do (
    echo %%b | findstr /i /c:"origin/HEAD" >nul
    if errorlevel 1 (
        set /a REMOTECOUNT+=1
        set "REMOTEBRANCH!REMOTECOUNT!=%%b"
        set "REMOTEDISPLAY!REMOTECOUNT!=%%b"
        set "TMP=%%b"
        if /i "!TMP:~0,7!"=="origin/" set "REMOTEDISPLAY!REMOTECOUNT!=!TMP:~7!"
    )
)

exit /b 0