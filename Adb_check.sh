#!/data/data/com.termux/files/usr/bin/bash
# adb_check.sh - Check ADB status + connected devices in Termux

LOGFILE="$HOME/adb_status.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

echo "=============================" >> "$LOGFILE"
echo "[ $DATE ] ADB Status Check" >> "$LOGFILE"
echo "=============================" >> "$LOGFILE"

# 1. Check if ADB server is running
if pgrep -x adb > /dev/null; then
    echo "[+] ADB server is running." | tee -a "$LOGFILE"
else
    echo "[-] ADB server is NOT running." | tee -a "$LOGFILE"
    exit 0
fi

# 2. Show listening port (5037 is default)
if command -v ss &>/dev/null; then
    ss -tulnp | grep 5037 | tee -a "$LOGFILE"
else
    netstat -tulnp 2>/dev/null | grep 5037 | tee -a "$LOGFILE"
fi

# 3. List connected devices
echo "[+] Connected devices:" | tee -a "$LOGFILE"
adb devices -l | tee -a "$LOGFILE"

echo "" >> "$LOGFILE"

