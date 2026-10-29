#!/bin/bash
# Fake DISM.exe: replies according to $SIM_SCENARIO, counting calls in $SIM_STATE.
n=$(( $(cat "$SIM_STATE/dism" 2>/dev/null || echo 0) + 1 )); echo $n > "$SIM_STATE/dism"
printf 'Deployment Image Servicing and Management tool\r\nVersion: 10.0.26100.9549\r\n\r\nImage Version: 10.0.26300.9711\r\n\r\n'
for p in 10.0 40.0 70.0 100.0; do printf '\r[==========                 %s%%                          ] ' $p; done
printf '\r\n'
[ -n "$SIM_SLEEP" ] && sleep "$SIM_SLEEP"
healthy() { printf 'No component store corruption detected.\r\nThe operation completed successfully.\r\n'; exit 0; }
case "$SIM_SCENARIO:$*:$n" in
  healthy:*|sfc-*:*|lock:*)                     healthy ;;
  dism-repair:*ScanHealth*:1|dism-fail:*:1)     printf 'The component store is repairable.\r\nThe operation completed successfully.\r\n'; exit 0 ;;
  dism-repair:*RestoreHealth*)                  printf 'The restore operation completed successfully.\r\nThe operation completed successfully.\r\n'; exit 0 ;;
  dism-repair:*ScanHealth*)                     healthy ;;
  dism-fail:*RestoreHealth*)                    printf 'Error: 87\r\n\r\nThe restorehealth option is unknown.\r\n'; exit 87 ;;
  not-repairable:*)                             printf 'The component store cannot be repaired.\r\n'; exit 0 ;;
  unrecognised:*)                               printf 'Something unexpected happened.\r\n'; exit 0 ;;
esac
