#!/bin/bash
# Usage: run-all.sh <script.ps1> <file|dot>  - the 10 quick scenarios (lock and time-out run separately)
cd "$(dirname "$0")"
run() { ./run-scenario.sh "$1" "$2" "${@:3}"; }
run "$1" "$2" healthy
run "$1" "$2" "healthy#afterdism" -SfcMode AfterDismRepairOnly
for s in dism-repair dism-fail not-repairable unrecognised sfc-repair sfc-partial sfc-pending; do run "$1" "$2" $s; done
run "$1" "$2" "sfc-repair#always" -SfcMode AlwaysRepair
B=$(basename "$1" .ps1)-$2
for d in run/$B/*/; do printf '%-22s %s\n' "$(basename $d)" "$(cat $d/exitcode)"; done
