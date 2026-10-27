#!/data/data/com.termux/files/usr/bin/bash
# Battery monitor script for Termux & Home Assistant

OUT_FILE="/data/data/com.termux/files/home/battery.json"
TMP_FILE="/data/data/com.termux/files/home/battery.json.tmp"

while true; do
    if command -v termux-battery-status >/dev/null 2>&1; then
        termux-battery-status > "$TMP_FILE" 2>/dev/null
        if [ -s "$TMP_FILE" ]; then
            mv "$TMP_FILE" "$OUT_FILE"
        fi
    fi
    sleep 15
done
