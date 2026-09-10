@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM ============================================================
REM Git + Submodules Manager (BAT)
REM ============================================================

set "DEFAULT_BRANCH=main"

:check_git
git --version >nul 2>&1
if errorlevel 1 (
  echo [ERR] Git non trovato nel PATH.
  echo Installa Git e riapri il terminale.
  pause
  exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo [ERR] Non sei dentro un repository git.
  pause
  exit /b 1
)

:menu
cls
echo ==========================================
echo  Git + Submodules Manager (BAT)
echo ==========================================
echo 1^) Status
echo 2^) Pull (root + submodules)
echo 3^) Create/Switch branch (all)
echo 4^) Commit (all)
echo 5^) Push (root + submodules)
echo 6^) Sync submodules
echo 7^) Foreach custom command
echo 0^) Exit
echo.
set /p CHOICE=Seleziona opzione: 

if "%CHOICE%"=="1" goto do_status
if "%CHOICE%"=="2" goto do_pull
if "%CHOICE%"=="3" goto do_branch
if "%CHOICE%"=="4" goto do_commit
if "%CHOICE%"=="5" goto do_push
if "%CHOICE%"=="6" goto do_sync
if "%CHOICE%"=="7" goto do_foreach
if "%CHOICE%"=="0" goto end

echo [WARN] Opzione non valida.
timeout /t 1 >nul
goto menu

:submodules_init
echo [INFO] Init/sync submoduli...
git submodule sync --recursive
git submodule update --init --recursive
goto :eof

:get_current_branch
for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "CUR_BRANCH=%%b"
if /i "%CUR_BRANCH%"=="HEAD" set "CUR_BRANCH=%DEFAULT_BRANCH%"
if "%CUR_BRANCH%"=="" set "CUR_BRANCH=%DEFAULT_BRANCH%"
goto :eof

:do_status
echo [INFO] STATUS ROOT
git status -sb
echo.
echo [INFO] STATUS SUBMODULES
git submodule foreach --recursive "echo ---- $name ($sm_path) ---- & git status -sb & echo."
echo [INFO] SUBMODULE POINTERS
git submodule status --recursive
pause
goto menu

:do_pull
call :submodules_init
set "BRANCH="
set /p BRANCH=Branch (invio = corrente): 
if "%BRANCH%"=="" (
  call :get_current_branch
  set "BRANCH=%CUR_BRANCH%"
)

echo [INFO] Pull root su branch: %BRANCH%
git fetch --all --prune
git checkout %BRANCH%
git pull --ff-only origin %BRANCH%
if errorlevel 1 echo [WARN] Pull root non fast-forward.

echo [INFO] Pull submoduli su branch %BRANCH%
git submodule foreach --recursive ^
"b=%BRANCH%; ^
echo ---- $name ($sm_path) ----; ^
git fetch --all --prune; ^
git show-ref --verify --quiet refs/heads/$b; ^
if [ $? -eq 0 ]; then ^
  git checkout $b; ^
  git pull --ff-only origin $b || echo [WARN] no ff-only pull; ^
else ^
  git ls-remote --exit-code --heads origin $b >/dev/null 2>&1; ^
  if [ $? -eq 0 ]; then ^
    git checkout -b $b --track origin/$b; ^
    git pull --ff-only origin $b || true; ^
  else ^
    echo [WARN] branch $b non esiste in $name, skip; ^
  fi; ^
fi"

echo [INFO] Commit puntatori submodule nel root (se cambiati)
git add .
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "chore: update submodule pointers after pull"
)

echo [OK] Pull completato.
pause
goto menu

:do_branch
call :submodules_init
set "NEWB="
set /p NEWB=Nuova branch (es: feature/lws): 
if "%NEWB%"=="" (
  echo [ERR] Branch vuota.
  pause
  goto menu
)

echo [INFO] Root branch: %NEWB%
git show-ref --verify --quiet refs/heads/%NEWB%
if errorlevel 1 (
  git checkout -b %NEWB%
) else (
  git checkout %NEWB%
)

echo [INFO] Branch nei submoduli
git submodule foreach --recursive ^
"b=%NEWB%; ^
echo ---- $name ($sm_path) ----; ^
git show-ref --verify --quiet refs/heads/$b; ^
if [ $? -eq 0 ]; then git checkout $b; else git checkout -b $b; fi"

echo [OK] Branch pronta su root + submoduli.
pause
goto menu

:do_commit
call :submodules_init
set "MSG="
set /p MSG=Messaggio commit: 
if "%MSG%"=="" (
  echo [ERR] Messaggio vuoto.
  pause
  goto menu
)

echo [INFO] Commit submoduli
git submodule foreach --recursive ^
"echo ---- $name ($sm_path) ----; ^
git add -A; ^
git diff --cached --quiet; ^
if [ $? -ne 0 ]; then ^
  git commit -m \"%MSG%\"; ^
  echo [OK] commit in $name; ^
else ^
  echo [INFO] niente da committare in $name; ^
fi"

echo [INFO] Commit root
git add -A
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "%MSG%"
  echo [OK] Commit root fatto.
) else (
  echo [WARN] Niente da committare nel root.
)

pause
goto menu

:do_push
call :submodules_init
set "PBRANCH="
set /p PBRANCH=Branch push (invio = corrente): 
if "%PBRANCH%"=="" (
  call :get_current_branch
  set "PBRANCH=%CUR_BRANCH%"
)

echo [INFO] Push submoduli
git submodule foreach --recursive ^
"echo ---- $name ($sm_path) ----; ^
cb=$(git rev-parse --abbrev-ref HEAD); ^
if [ \"$cb\" = \"HEAD\" ]; then ^
  echo [WARN] detached HEAD in $name, skip; ^
else ^
  if [ \"$cb\" != \"%PBRANCH%\" ]; then ^
    echo [WARN] $name e su $cb (non %PBRANCH%), pusho $cb; ^
    git push -u origin $cb; ^
  else ^
    git push -u origin %PBRANCH%; ^
  fi; ^
fi"

echo [INFO] Push root
git push -u origin %PBRANCH%
echo [OK] Push completato.
pause
goto menu

:do_sync
echo [INFO] Sync URL submodule da .gitmodules
git submodule sync --recursive
git submodule update --init --recursive --remote
echo [OK] Sync completato.
pause
goto menu

:do_foreach
set "FCMD="
set /p FCMD=Comando per ogni submodule (es: git status -sb): 
if "%FCMD%"=="" (
  echo [ERR] Comando vuoto.
  pause
  goto menu
)
git submodule foreach --recursive "%FCMD%"
pause
goto menu

:end
echo [OK] Uscita.
endlocal
exit /b 0