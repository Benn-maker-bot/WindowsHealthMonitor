#!/bin/bash
# Usage: run-scenario.sh <script.ps1> <file|dot> <scenario> [extra script options]
#  file: start the script with pwsh -File, as Task Scheduler does.
#  dot:  dot-source it, replace Test-IsAdministrator with a stub (Linux has no Windows
#        administrator check), then call Invoke-WindowsHealthMonitor - the stage 1 test hook.
SCRIPT=$(realpath "$1"); MODE=$2; S=$3; shift 3
HERE=$(dirname "$(realpath "$0")")
ROOT="$HERE/run/$(basename "$SCRIPT" .ps1)-$MODE/$S"; rm -rf "$ROOT"; mkdir -p "$ROOT/Windows/System32" "$ROOT/state"
cp "$SCRIPT" "$ROOT/WindowsHealthMonitor.ps1"
cp "$HERE/mock-dism.sh" "$ROOT/Windows/System32/Dism.exe"; cp "$HERE/mock-sfc.sh" "$ROOT/Windows/System32/sfc.exe"
export SystemRoot="$ROOT/Windows" SystemDrive="/" SIM_SCENARIO="${S%%#*}" SIM_STATE="$ROOT/state"
mkdir -p "$ROOT/Windows/Logs/CBS"; export SIM_CBS="$ROOT/Windows/Logs/CBS/CBS.log"
echo "2026-10-01 09:00:00, Info                  CSI    00000001 [SR] An OLD line from an earlier run" > "$SIM_CBS"
if [ "$MODE" = dot ]; then
  cat > "$ROOT/driver.ps1" <<PS
. "$ROOT/WindowsHealthMonitor.ps1" -NoPopup $*
function Test-IsAdministrator { \$true }
Invoke-WindowsHealthMonitor
exit \$script:Outcome.Code
PS
  pwsh -NoProfile -File "$ROOT/driver.ps1" > "$ROOT/console.txt" 2>&1
else
  pwsh -NoProfile -File "$ROOT/WindowsHealthMonitor.ps1" -NoPopup "$@" > "$ROOT/console.txt" 2>&1
fi
echo $? > "$ROOT/exitcode"
