@echo off
setlocal

REM --- Config personalizzata ---
set "GIT_EXE=D:\PortableGit\cmd\git.exe"
set "TARGET=D:\sketchs\Lud-WS-git\Lud-WS\scripts\gitMan.bat"

if not exist "%GIT_EXE%" (
  echo [ERR] Git non trovato:
  echo       %GIT_EXE%
  pause
  exit /b 1
)

if not exist "%TARGET%" (
  echo [ERR] Script non trovato:
  echo       %TARGET%
  pause
  exit /b 1
)

set "GIT_DIR=%GIT_EXE:\cmd\git.exe=%"
set "GIT_BASH=%GIT_DIR%\git-bash.exe"

if not exist "%GIT_BASH%" (
  set "GIT_BASH=%GIT_DIR%\bin\bash.exe"
)

if not exist "%GIT_BASH%" (
  echo [ERR] git-bash/bash non trovato in:
  echo       %GIT_DIR%
  pause
  exit /b 1
)

echo [INFO] Git Bash: %GIT_BASH%
echo [INFO] Script:   %TARGET%

REM Converte path Windows in stile bash (es: D:/...)
set "TARGET_BASH=%TARGET:\=/%"

REM Avvio in Git Bash
"%GIT_BASH%" --login -i -c "\"%TARGET_BASH%\""

endlocal
exit /b 0