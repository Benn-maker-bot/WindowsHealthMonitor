#!/bin/bash
# Fake sfc.exe: writes UTF-16LE, exactly as the real SFC does when its output is captured.
n=$(( $(cat "$SIM_STATE/sfc" 2>/dev/null || echo 0) + 1 )); echo $n > "$SIM_STATE/sfc"
say() { printf '%b' "$1" | iconv -f UTF-8 -t UTF-16LE; }
say '\r\nBeginning system scan.  This process will take some time.\r\n\r\nBeginning verification phase of system scan.\r\n'
for p in 5 50 100; do say "\rVerification $p% complete."; done
say '\r\n\r\n'
cbs() { echo "$(date '+%Y-%m-%d %H:%M:%S'), Info                  CSI    0000$n [SR] $1" >> "$SIM_CBS"; }
clean='Windows Resource Protection did not find any integrity violations.\r\n'
case "$SIM_SCENARIO:$*:$n" in
  sfc-repair:*verifyonly*:1)  say 'Windows Resource Protection found integrity violations.\r\n'; exit 1 ;;
  sfc-repair:*scannow*)       cbs 'Repairing corrupted file \\??\\C:\\WINDOWS\\System32\\example.dll from store'; cbs 'Repair complete'
                              say 'Windows Resource Protection found corrupt files and successfully repaired them.\r\n'; exit 0 ;;
  sfc-partial:*verifyonly*:1) say 'Windows Resource Protection found integrity violations.\r\n'; exit 1 ;;
  sfc-partial:*scannow*)      cbs 'Cannot repair member file [l:11]"example.dll"'
                              say 'Windows Resource Protection found corrupt files but was unable to fix some of them.\r\n'; exit 0 ;;
  sfc-pending:*)              say 'There is a system repair pending which requires reboot to complete.\r\n'; exit 0 ;;
  *)                          say "$clean"; exit 0 ;;
esac
