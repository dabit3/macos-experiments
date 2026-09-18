#!/bin/bash
set -euo pipefail
MODE="${1:-success}"
case "$MODE" in success|failure|cancel|incomplete) ;; *) exit 2 ;; esac
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$HOME/Library/Application Support/Watchword/Demo Output"
mkdir -p "$OUTPUT"
printf '\033[2J\033[H\033]0;Watchword — %s export\007' "$MODE"
printf 'WATCHWORD / EXPORT DESK\n────────────────────────────────────────\n'
printf 'Archive · Yesterday: Export completed successfully.\n'
printf 'No current export is running yet.\n\n'
printf 'Arm Watchword now. The new task begins in 25 seconds.\n'
sleep 25
printf '\nTODAY / NEW JOB · Atlas field journal\n'
printf 'Collecting twelve records. No deliverable is ready yet.\n'
sleep 4
printf 'Encoding finished for 12 records. Final verification still pending.\n'
sleep 4
case "$MODE" in
    success)
        awk -F '\t' 'BEGIN {OFS=","} {$1=$1; print}' "$ROOT/field-journal.tsv" > "$OUTPUT/atlas-journal.csv"
        printf 'Checking the exported artifact…\n'
        sleep 4
        test "$(wc -l < "$OUTPUT/atlas-journal.csv" | tr -d ' ')" = 13
        printf 'Delivery complete: all twelve records were written and verified.\n'
        printf 'The new Atlas export is ready to use. Nothing remains to process.\n'
        ;;
    failure)
        printf 'Verification stopped: destination volume is full.\n'
        printf 'This export failed; no usable artifact was delivered.\n'
        ;;
    cancel)
        printf 'The operator cancelled this export before delivery.\n'
        printf 'Temporary output discarded. The new export did not complete.\n'
        ;;
    incomplete)
        printf 'Upload queued. Waiting for a connection; delivery has not happened.\n'
        ;;
esac
printf '\nWatchword reads only this visible Terminal window.\n'
printf 'Press Return to close this fixture.\n'
read -r _
