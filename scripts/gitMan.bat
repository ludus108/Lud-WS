@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM ============================================================
REM gitMan_v13.bat - ADVANCED SAFE + PRE-PULL REMEDY
REM ============================================================

set "DEFAULT_BRANCH=main"
set "DEBUG_HOLD=1"

call :main
goto :hold

:main
git --version >nul 2>&1 || goto :fatal_git
git rev-parse --is-inside-work-tree >nul 2>&1 || goto :fatal_repo
goto menu

:menu
cls
echo ==========================================
echo  gitMan v13 - Git + Submodules Manager
echo ==========================================
echo 1^) Status
echo 2^) Pull (root + submodules) [con rimedio]
echo 3^) Create/Switch branch (all)
echo 4^) Commit (all) [con conferma]
echo 5^) Push (root + submodules) [clean required]
echo 6^) Sync submodules
echo 7^) Foreach custom command
echo 8^) Gestione SINGOLO submodule
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
if "%CHOICE%"=="8" goto submodule_select
if "%CHOICE%"=="0" goto goodbye

echo [WARN] Opzione non valida.
call :hold
goto menu

:confirm
set "ANSWER="
set /p ANSWER=%~1 [Y/N]:
if /I "%ANSWER%"=="Y" exit /b 0
if /I "%ANSWER%"=="N" exit /b 1
echo [WARN] Inserisci Y o N.
goto confirm

:submodules_init
echo [INFO] Init/sync submoduli...
git submodule sync --recursive || goto :fatal_cmd
git submodule update --init --recursive || goto :fatal_cmd
goto :eof

:get_current_branch
set "TMPB="
for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "TMPB=%%b"
if /i "!TMPB!"=="HEAD" set "TMPB=%DEFAULT_BRANCH%"
if "!TMPB!"=="" set "TMPB=%DEFAULT_BRANCH%"
set "%~1=!TMPB!"
goto :eof

:pick_branch
set "PB_COUNT=0"
for /f "delims=" %%b in ('git for-each-ref --format="%%(refname:short)" refs/heads refs/remotes/origin ^| findstr /V /I "origin/HEAD"') do (
  set /a PB_COUNT+=1
  set "PB_!PB_COUNT!=%%b"
)

if "%PB_COUNT%"=="0" (
  echo [WARN] Nessuna branch trovata, uso %DEFAULT_BRANCH%
  set "%~1=%DEFAULT_BRANCH%"
  exit /b 0
)

echo.
echo ===== Seleziona branch =====
for /L %%i in (1,1,%PB_COUNT%) do echo %%i^) !PB_%%i!
echo 0^) Inserimento manuale
set /p PB_SEL=Scelta branch:

if "%PB_SEL%"=="0" (
  set "PB_MANUAL="
  set /p PB_MANUAL=Inserisci branch:
  if "%PB_MANUAL%"=="" (set "%~1=%DEFAULT_BRANCH%") else (set "%~1=%PB_MANUAL%")
  exit /b 0
)

if not defined PB_%PB_SEL% (
  echo [WARN] Scelta non valida, uso branch corrente.
  call :get_current_branch %~1
  exit /b 0
)

set "%~1=!PB_%PB_SEL%!"
exit /b 0

:pick_branch_in_current_repo
set "PB_COUNT=0"
for /f "delims=" %%b in ('git for-each-ref --format="%%(refname:short)" refs/heads refs/remotes/origin ^| findstr /V /I "origin/HEAD"') do (
  set /a PB_COUNT+=1
  set "PB_!PB_COUNT!=%%b"
)

if "%PB_COUNT%"=="0" (
  set "%~1=%DEFAULT_BRANCH%"
  exit /b 0
)

echo.
echo ===== Seleziona branch (submodule) =====
for /L %%i in (1,1,%PB_COUNT%) do echo %%i^) !PB_%%i!
echo 0^) Inserimento manuale
set /p PB_SEL=Scelta branch:

if "%PB_SEL%"=="0" (
  set "PB_MANUAL="
  set /p PB_MANUAL=Inserisci branch:
  if "%PB_MANUAL%"=="" (set "%~1=%DEFAULT_BRANCH%") else (set "%~1=%PB_MANUAL%")
  exit /b 0
)

if not defined PB_%PB_SEL% (
  for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "%~1=%%b"
  exit /b 0
)

set "%~1=!PB_%PB_SEL%!"
exit /b 0

:is_root_clean
git diff --quiet
if errorlevel 1 exit /b 1
git diff --cached --quiet
if errorlevel 1 exit /b 1
exit /b 0

:are_submodules_clean
set "SUB_DIRTY=0"
for /f "tokens=2 delims= " %%s in ('git submodule status --recursive') do (
  pushd "%%s" >nul 2>&1
  if errorlevel 1 (
    set "SUB_DIRTY=1"
  ) else (
    git diff --quiet
    if errorlevel 1 set "SUB_DIRTY=1"
    git diff --cached --quiet
    if errorlevel 1 set "SUB_DIRTY=1"
    for /f "delims=" %%u in ('git ls-files --others --exclude-standard') do set "SUB_DIRTY=1"
    popd >nul
  )
)
if "%SUB_DIRTY%"=="1" exit /b 1
exit /b 0

:ensure_clean_before_push
call :is_root_clean
if errorlevel 1 (
  echo [ERR] Root repository non pulito.
  exit /b 1
)
call :are_submodules_clean
if errorlevel 1 (
  echo [ERR] Uno o più submoduli non sono puliti.
  exit /b 1
)
exit /b 0

:is_repo_dirty
git diff --quiet
if errorlevel 1 exit /b 1
git diff --cached --quiet
if errorlevel 1 exit /b 1
for /f "delims=" %%u in ('git ls-files --others --exclude-standard') do exit /b 1
exit /b 0

:remedy_before_pull_current_repo
REM uso: call :remedy_before_pull_current_repo "LABEL"
REM ritorna 0=ok, 1=skip/abort
set "LBL=%~1"

call :is_repo_dirty
if not errorlevel 1 exit /b 0

echo.
echo [WARN] Repo non pulita: %LBL%
git status -sb
echo.
echo Scegli rimedio prima del pull:
echo  1^) Auto-commit (tracked + untracked)
echo  2^) Stash -u
echo  3^) Skip pull su questa repo
echo  0^) Annulla operazione
set /p RMD=Scelta:

if "%RMD%"=="1" (
  set "RMSG="
  set /p RMSG=Messaggio commit [default: wip: pre-pull auto-save]:
  if "%RMSG%"=="" set "RMSG=wip: pre-pull auto-save"
  git add -A
  git commit -m "%RMSG%"
  if errorlevel 1 (
    echo [ERR] Commit automatico fallito in %LBL%.
    exit /b 1
  )
  echo [OK] Auto-commit eseguito in %LBL%.
  exit /b 0
)

if "%RMD%"=="2" (
  set "SMSG="
  set /p SMSG=Messaggio stash [default: wip: pre-pull stash]:
  if "%SMSG%"=="" set "SMSG=wip: pre-pull stash"
  git stash push -u -m "%SMSG%"
  if errorlevel 1 (
    echo [ERR] Stash fallito in %LBL%.
    exit /b 1
  )
  echo [OK] Stash creato in %LBL%.
  exit /b 0
)

if "%RMD%"=="3" (
  echo [INFO] Skip pull su %LBL%.
  exit /b 1
)

if "%RMD%"=="0" (
  echo [INFO] Operazione annullata.
  exit /b 1
)

echo [WARN] Scelta non valida.
exit /b 1

:do_status
echo [INFO] STATUS ROOT
git status -sb
echo.
echo [INFO] STATUS SUBMODULES
git submodule foreach --recursive "echo ---- $name ($sm_path) ---- & git status -sb & echo."
echo [INFO] SUBMODULE POINTERS
git submodule status --recursive
call :hold
goto menu

:do_pull
call :submodules_init

set "BRANCH="
echo [INFO] Selezione branch per PULL
call :pick_branch BRANCH
echo %BRANCH% | findstr /B /I "origin/" >nul
if not errorlevel 1 set "BRANCH=%BRANCH:origin/=%"

REM Rimedio ROOT prima del pull
call :remedy_before_pull_current_repo "ROOT"
if errorlevel 1 (
  echo [INFO] Pull root annullato/skip.
  call :hold
  goto menu
)

echo [INFO] Pull root su branch: %BRANCH%
git fetch --all --prune || goto :fatal_cmd
git checkout %BRANCH%
if errorlevel 1 (
  echo [ERR] Checkout root fallito.
  call :hold
  goto menu
)
git pull --ff-only origin %BRANCH%
if errorlevel 1 echo [WARN] Pull root non fast-forward o bloccato.

echo [INFO] Pull submoduli su branch %BRANCH%
for /f "tokens=2 delims= " %%s in ('git submodule status --recursive') do (
  echo ------------------------------------------
  echo [INFO] Submodule: %%s
  pushd "%%s" >nul 2>&1
  if errorlevel 1 (
    echo [ERR] Impossibile entrare in %%s
  ) else (
    call :remedy_before_pull_current_repo "SUBMODULE %%s"
    if errorlevel 1 (
      echo [INFO] Skip pull submodule %%s
    ) else (
      git fetch --all --prune

      git show-ref --verify --quiet refs/heads/%BRANCH%
      if errorlevel 1 (
        git ls-remote --exit-code --heads origin %BRANCH% >nul 2>&1
        if errorlevel 1 (
          echo [WARN] Branch %BRANCH% non trovata in %%s, skip.
        ) else (
          git checkout -b %BRANCH% --track origin/%BRANCH%
          git pull --ff-only origin %BRANCH%
        )
      ) else (
        git checkout %BRANCH%
        git pull --ff-only origin %BRANCH%
        if errorlevel 1 echo [WARN] Pull non fast-forward in %%s
      )
    )
    popd >nul
  )
)

echo [INFO] Commit automatico puntatori submodule nel root (se cambiati)
git add .
git diff --cached --quiet
if errorlevel 1 git commit -m "chore: update submodule pointers after pull"

echo [OK] Pull completato.
call :hold
goto menu

:do_branch
call :submodules_init
set "NEWB="
set /p NEWB=Nuova branch (es: feature/lws):
if "%NEWB%"=="" (
  echo [ERR] Branch vuota.
  call :hold
  goto menu
)

echo [INFO] Root branch: %NEWB%
git show-ref --verify --quiet refs/heads/%NEWB%
if errorlevel 1 (git checkout -b %NEWB%) else (git checkout %NEWB%)

echo [INFO] Branch nei submoduli
for /f "tokens=2 delims= " %%s in ('git submodule status --recursive') do (
  echo ------------------------------------------
  echo [INFO] Submodule: %%s
  pushd "%%s" >nul 2>&1
  if errorlevel 1 (
    echo [ERR] Impossibile entrare in %%s
  ) else (
    git show-ref --verify --quiet refs/heads/%NEWB%
    if errorlevel 1 (git checkout -b %NEWB%) else (git checkout %NEWB%)
    popd >nul
  )
)

echo [OK] Branch pronta su root + submoduli.
call :hold
goto menu

:do_commit
call :submodules_init
set "MSG="
set /p MSG=Messaggio commit:
if "%MSG%"=="" (
  echo [ERR] Messaggio vuoto.
  call :hold
  goto menu
)

call :confirm "Confermi COMMIT su root + submoduli?"
if errorlevel 1 (
  echo [INFO] Commit annullato.
  call :hold
  goto menu
)

echo [INFO] Commit submoduli
for /f "tokens=2 delims= " %%s in ('git submodule status --recursive') do (
  echo ------------------------------------------
  echo [INFO] Submodule: %%s
  pushd "%%s" >nul 2>&1
  if errorlevel 1 (
    echo [ERR] Impossibile entrare in %%s
  ) else (
    git add -A
    git diff --cached --quiet
    if errorlevel 1 (
      git commit -m "%MSG%"
      echo [OK] commit in %%s
    ) else (
      echo [INFO] niente da committare in %%s
    )
    popd >nul
  )
)

echo [INFO] Commit root
git add -A
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "%MSG%"
  echo [OK] Commit root fatto.
) else (
  echo [WARN] Niente da committare nel root.
)

call :hold
goto menu

:do_push
call :submodules_init

set "PBRANCH="
echo [INFO] Selezione branch per PUSH
call :pick_branch PBRANCH
echo %PBRANCH% | findstr /B /I "origin/" >nul
if not errorlevel 1 set "PBRANCH=%PBRANCH:origin/=%"

call :ensure_clean_before_push
if errorlevel 1 (
  echo [INFO] Esegui prima commit/stash delle modifiche.
  call :hold
  goto menu
)

echo [INFO] Branch target push: %PBRANCH%
call :confirm "Confermi PUSH su origin (root + submoduli)?"
if errorlevel 1 (
  echo [INFO] Push annullato.
  call :hold
  goto menu
)

echo [INFO] Push submoduli
for /f "tokens=2 delims= " %%s in ('git submodule status --recursive') do (
  echo ------------------------------------------
  echo [INFO] Submodule: %%s
  pushd "%%s" >nul 2>&1
  if errorlevel 1 (
    echo [ERR] Impossibile entrare in %%s
  ) else (
    for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "SM_BRANCH=%%b"
    if /i "!SM_BRANCH!"=="HEAD" (
      echo [WARN] Detached HEAD in %%s, skip push.
    ) else (
      echo [INFO] Push %%s branch !SM_BRANCH!
      git push -u origin !SM_BRANCH!
      if errorlevel 1 (
        echo [ERR] Push fallito in %%s
        popd >nul
        call :hold
        goto menu
      )
    )
    popd >nul
  )
)

echo [INFO] Push root: %PBRANCH%
git push -u origin %PBRANCH%
if errorlevel 1 (
  echo [ERR] Push root fallito.
  call :hold
  goto menu
)

echo [OK] Push completato.
call :hold
goto menu

:do_sync
echo [INFO] Sync URL submodule da .gitmodules
git submodule sync --recursive
git submodule update --init --recursive --remote
echo [OK] Sync completato.
call :hold
goto menu

:do_foreach
set "FCMD="
set /p FCMD=Comando per ogni submodule (es: git status -sb):
if "%FCMD%"=="" (
  echo [ERR] Comando vuoto.
  call :hold
  goto menu
)
git submodule foreach --recursive "%FCMD%"
call :hold
goto menu

:submodule_select
cls
echo ==========================================
echo  Selezione submodule
echo ==========================================
set "SM_COUNT=0"
for /f "tokens=2 delims= " %%s in ('git submodule status --recursive') do (
  set /a SM_COUNT+=1
  set "SM_!SM_COUNT!=%%s"
  echo !SM_COUNT!^) %%s
)
if "%SM_COUNT%"=="0" (
  echo [WARN] Nessun submodule trovato.
  call :hold
  goto menu
)
echo 0^) Indietro
echo.
set /p SM_IDX=Seleziona submodule:

if "%SM_IDX%"=="0" goto menu
if not defined SM_%SM_IDX% (
  echo [WARN] Selezione non valida.
  call :hold
  goto submodule_select
)

set "SM_PATH=!SM_%SM_IDX%!"
goto submodule_menu

:submodule_menu
cls
echo ==========================================
echo  Submodule: %SM_PATH%
echo ==========================================
echo 1^) Status
echo 2^) Pull (scegli branch)
echo 3^) Branch create/switch
echo 4^) Commit
echo 5^) Push (scegli branch)
echo 6^) Custom command
echo 7^) Cambia submodule
echo 0^) Menu principale
echo.
set /p SMACT=Seleziona azione:

if "%SMACT%"=="1" goto sm_status
if "%SMACT%"=="2" goto sm_pull
if "%SMACT%"=="3" goto sm_branch
if "%SMACT%"=="4" goto sm_commit
if "%SMACT%"=="5" goto sm_push
if "%SMACT%"=="6" goto sm_custom
if "%SMACT%"=="7" goto submodule_select
if "%SMACT%"=="0" goto menu

echo [WARN] Opzione non valida.
call :hold
goto submodule_menu

:sm_status
pushd "%SM_PATH%"
echo [INFO] STATUS %SM_PATH%
git status -sb
popd
call :hold
goto submodule_menu

:sm_pull
pushd "%SM_PATH%"
call :remedy_before_pull_current_repo "SUBMODULE %SM_PATH%"
if errorlevel 1 (
  popd
  call :hold
  goto submodule_menu
)

set "SMB="
echo [INFO] Selezione branch per PULL su %SM_PATH%
call :pick_branch_in_current_repo SMB
echo !SMB! | findstr /B /I "origin/" >nul
if not errorlevel 1 set "SMB=!SMB:origin/=!"

echo [INFO] Pull %SM_PATH% branch !SMB!
git fetch --all --prune

git show-ref --verify --quiet refs/heads/!SMB!
if errorlevel 1 (
  git ls-remote --exit-code --heads origin !SMB! >nul 2>&1
  if errorlevel 1 (
    echo [ERR] Branch !SMB! non esiste ne locale ne su origin.
    popd
    call :hold
    goto submodule_menu
  ) else (
    git checkout -b !SMB! --track origin/!SMB!
  )
) else (
  git checkout !SMB!
)

git pull --ff-only origin !SMB!
if errorlevel 1 echo [WARN] Pull non fast-forward.
popd
call :hold
goto submodule_menu

:sm_branch
set "NEWB="
set /p NEWB=Nuova branch:
if "%NEWB%"=="" (
  echo [ERR] Branch vuota.
  call :hold
  goto submodule_menu
)
pushd "%SM_PATH%"
git show-ref --verify --quiet refs/heads/%NEWB%
if errorlevel 1 (git checkout -b %NEWB%) else (git checkout %NEWB%)
popd
echo [OK] Branch impostata su %SM_PATH%.
call :hold
goto submodule_menu

:sm_commit
set "SMSG="
set /p SMSG=Messaggio commit:
if "%SMSG%"=="" (
  echo [ERR] Messaggio vuoto.
  call :hold
  goto submodule_menu
)
call :confirm "Confermi COMMIT su %SM_PATH%?"
if errorlevel 1 (
  echo [INFO] Commit annullato.
  call :hold
  goto submodule_menu
)
pushd "%SM_PATH%"
git add -A
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "%SMSG%"
  echo [OK] Commit eseguito su %SM_PATH%.
) else (
  echo [WARN] Niente da committare su %SM_PATH%.
)
popd
call :hold
goto submodule_menu

:sm_push
call :confirm "Confermi PUSH su %SM_PATH%?"
if errorlevel 1 (
  echo [INFO] Push annullato.
  call :hold
  goto submodule_menu
)

pushd "%SM_PATH%"

git diff --quiet
if errorlevel 1 (
  echo [ERR] Working tree non pulito su %SM_PATH%.
  popd
  call :hold
  goto submodule_menu
)
git diff --cached --quiet
if errorlevel 1 (
  echo [ERR] Index non pulito su %SM_PATH%.
  popd
  call :hold
  goto submodule_menu
)

set "SM_PUSH_BRANCH="
echo [INFO] Selezione branch per PUSH su %SM_PATH%
call :pick_branch_in_current_repo SM_PUSH_BRANCH
echo !SM_PUSH_BRANCH! | findstr /B /I "origin/" >nul
if not errorlevel 1 set "SM_PUSH_BRANCH=!SM_PUSH_BRANCH:origin/=!"

git show-ref --verify --quiet refs/heads/!SM_PUSH_BRANCH!
if errorlevel 1 (
  echo [ERR] Branch locale !SM_PUSH_BRANCH! non trovata in %SM_PATH%.
  popd
  call :hold
  goto submodule_menu
)

git checkout !SM_PUSH_BRANCH!
if errorlevel 1 (
  echo [ERR] Checkout branch !SM_PUSH_BRANCH! fallito.
  popd
  call :hold
  goto submodule_menu
)

git push -u origin !SM_PUSH_BRANCH!
if errorlevel 1 (
  echo [ERR] Push fallito su %SM_PATH%.
  popd
  call :hold
  goto submodule_menu
)

popd
echo [OK] Push completato su %SM_PATH% (!SM_PUSH_BRANCH!).
call :hold
goto submodule_menu

:sm_custom
set "SCMD="
set /p SCMD=Comando custom per %SM_PATH%:
if "%SCMD%"=="" (
  echo [ERR] Comando vuoto.
  call :hold
  goto submodule_menu
)
pushd "%SM_PATH%"
cmd /c "%SCMD%"
popd
call :hold
goto submodule_menu

:hold
if "%DEBUG_HOLD%"=="1" pause
goto :eof

:fatal_git
echo [FATAL] Git non trovato o non eseguibile.
goto :fatal_end

:fatal_repo
echo [FATAL] Non sei dentro un repository Git.
goto :fatal_end

:fatal_cmd
echo [FATAL] Un comando Git ha restituito errore.
goto :fatal_end

:fatal_end
if "%DEBUG_HOLD%"=="1" pause
exit /b 1

:goodbye
echo [OK] Uscita.
if "%DEBUG_HOLD%"=="1" pause
exit /b 0