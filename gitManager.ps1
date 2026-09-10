$ErrorActionPreference = "Stop"
$DefaultBranch = "main"

function Info($msg)  { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Err($msg)   { Write-Host "[ERR]  $msg" -ForegroundColor Red }

function Ensure-GitRepo {
    try {
        $inside = git rev-parse --is-inside-work-tree 2>$null
        if ($inside -ne "true") { throw "not git repo" }
    } catch {
        Err "Non sei dentro un repository git."
        exit 1
    }
}

function Ensure-SubmodulesInit {
    Info "Init/sync submoduli..."
    git submodule sync --recursive
    git submodule update --init --recursive
    Ok "Submoduli pronti."
}

function Get-CurrentBranch {
    $b = git rev-parse --abbrev-ref HEAD
    if ($b -eq "HEAD" -or [string]::IsNullOrWhiteSpace($b)) { return $DefaultBranch }
    return $b
}

function Do-Status {
    Info "STATUS ROOT"
    git status -sb
    Write-Host ""
    Info "STATUS SUBMODULES"
    git submodule foreach --recursive 'echo "---- $name ($sm_path) ----"; git status -sb; echo'
    Info "SUBMODULE POINTERS (root)"
    git submodule status --recursive
}

function Do-Pull([string]$branchArg) {
    Ensure-SubmodulesInit
    $branch = if ([string]::IsNullOrWhiteSpace($branchArg)) { Get-CurrentBranch } else { $branchArg }

    Info "Pull root su branch: $branch"
    git fetch --all --prune
    git checkout $branch
    try { git pull --ff-only origin $branch } catch { Warn "Pull root non fast-forward." }

    Info "Pull submoduli"
    git submodule foreach --recursive "
      b='$branch';
      echo '----' \$name '(' \$sm_path ')' '----';
      git fetch --all --prune;
      git show-ref --verify --quiet refs/heads/\$b;
      if [ \$? -eq 0 ]; then
        git checkout \$b;
        git pull --ff-only origin \$b || echo '[WARN] no ff-only pull';
      else
        git ls-remote --exit-code --heads origin \$b >/dev/null 2>&1;
        if [ \$? -eq 0 ]; then
          git checkout -b \$b --track origin/\$b;
          git pull --ff-only origin \$b || true;
        else
          echo '[WARN] branch' \$b 'non esiste in' \$name ', skip';
        fi
      fi
    "

    git add .
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        try { git commit -m "chore: update submodule pointers after pull" | Out-Null } catch {}
    }
    Ok "Pull completato."
}

function Do-Branch([string]$newBranch) {
    if ([string]::IsNullOrWhiteSpace($newBranch)) {
        Err "Branch non valida."
        return
    }

    Ensure-SubmodulesInit
    Info "Creo/switch root branch: $newBranch"
    git show-ref --verify --quiet "refs/heads/$newBranch"
    if ($LASTEXITCODE -eq 0) { git checkout $newBranch } else { git checkout -b $newBranch }

    Info "Creo/switch stessa branch nei submoduli"
    git submodule foreach --recursive "
      b='$newBranch';
      echo '----' \$name '(' \$sm_path ')' '----';
      git show-ref --verify --quiet refs/heads/\$b;
      if [ \$? -eq 0 ]; then git checkout \$b; else git checkout -b \$b; fi
    "
    Ok "Branch pronta su root + submoduli."
}

function Do-Commit([string]$message) {
    if ([string]::IsNullOrWhiteSpace($message)) {
        Err "Messaggio commit vuoto."
        return
    }

    Ensure-SubmodulesInit
    Info "Commit submoduli"
    git submodule foreach --recursive "
      echo '----' \$name '(' \$sm_path ')' '----';
      git add -A;
      git diff --cached --quiet;
      if [ \$? -ne 0 ]; then
        git commit -m '$message';
        echo '[OK] commit in' \$name;
      else
        echo '[INFO] niente da committare in' \$name;
      fi
    "

    Info "Commit root"
    git add -A
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m $message | Out-Null
        Ok "Commit root fatto."
    } else {
        Warn "Niente da committare nel root."
    }
}

function Do-Push([string]$branchArg) {
    Ensure-SubmodulesInit
    $branch = if ([string]::IsNullOrWhiteSpace($branchArg)) { Get-CurrentBranch } else { $branchArg }

    Info "Push submoduli"
    git submodule foreach --recursive "
      echo '----' \$name '(' \$sm_path ')' '----';
      cb=\$(git rev-parse --abbrev-ref HEAD);
      if [ \"\$cb\" = 'HEAD' ]; then
        echo '[WARN] detached HEAD in' \$name ', skip';
      else
        if [ \"\$cb\" != '$branch' ]; then
          echo '[WARN]' \$name 'è su' \$cb '(non $branch), pusho' \$cb;
          git push -u origin \$cb;
        else
          git push -u origin $branch;
        fi
      fi
    "

    Info "Push root"
    git push -u origin $branch
    Ok "Push completato."
}

function Do-Sync {
    Info "Sync URL submodule da .gitmodules"
    git submodule sync --recursive
    git submodule update --init --recursive --remote
    Ok "Sync completato."
}

function Do-Foreach([string]$cmd) {
    if ([string]::IsNullOrWhiteSpace($cmd)) {
        Err "Comando vuoto."
        return
    }
    git submodule foreach --recursive $cmd
}

function Pause-Return {
    Write-Host ""
    Read-Host "Premi INVIO per tornare al menu"
}

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Magenta
    Write-Host " Git + Submodules Manager (Interactive)  " -ForegroundColor Magenta
    Write-Host "==========================================" -ForegroundColor Magenta
    Write-Host "1) Status"
    Write-Host "2) Pull (root + submodules)"
    Write-Host "3) Create/Switch branch (all)"
    Write-Host "4) Commit (all)"
    Write-Host "5) Push (root + submodules)"
    Write-Host "6) Sync submodules"
    Write-Host "7) Foreach custom command"
    Write-Host "0) Exit"
    Write-Host ""
}

# MAIN
Ensure-GitRepo

while ($true) {
    Show-Menu
    $choice = Read-Host "Seleziona opzione"

    switch ($choice) {
        "1" {
            Do-Status
            Pause-Return
        }
        "2" {
            $b = Read-Host "Branch (invio = corrente)"
            Do-Pull $b
            Pause-Return
        }
        "3" {
            $b = Read-Host "Nuova branch (es: feature/lws)"
            Do-Branch $b
            Pause-Return
        }
        "4" {
            $m = Read-Host 'Messaggio commit'
            Do-Commit $m
            Pause-Return
        }
        "5" {
            $b = Read-Host "Branch push (invio = corrente)"
            Do-Push $b
            Pause-Return
        }
        "6" {
            Do-Sync
            Pause-Return
        }
        "7" {
            $c = Read-Host 'Comando da eseguire in ogni submodule (es: git status -sb)'
            Do-Foreach $c
            Pause-Return
        }
        "0" {
            Ok "Uscita."
            break
        }
        default {
            Warn "Opzione non valida."
            Start-Sleep -Seconds 1
        }
    }
}