#!/bin/bash
# Usage: run-scenario.sh <scenario> [extra script options]
S=$1; shift
ROOT="$PWD/run/$S"; rm -rf "$ROOT"; mkdir -p "$ROOT/Windows/System32" "$ROOT/state"
cp ../WHM-2.4.0.ps1 "$ROOT/WindowsHealthMonitor.ps1"
cp mock-dism.sh "$ROOT/Windows/System32/Dism.exe"; cp mock-sfc.sh "$ROOT/Windows/System32/sfc.exe"
export SystemRoot="$ROOT/Windows" SystemDrive="/" SIM_SCENARIO="${S%%#*}" SIM_STATE="$ROOT/state"
mkdir -p "$ROOT/Windows/Logs/CBS"; export SIM_CBS="$ROOT/Windows/Logs/CBS/CBS.log"
echo "2026-10-01 09:00:00, Info                  CSI    00000001 [SR] An OLD line from an earlier run" > "$SIM_CBS"
../pwsh/pwsh -NoProfile -File "$ROOT/WindowsHealthMonitor.ps1" -NoPopup "$@" > "$ROOT/console.txt" 2>&1
echo $? > "$ROOT/exitcode"
