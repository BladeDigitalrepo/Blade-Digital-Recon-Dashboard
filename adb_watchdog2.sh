#!/data/data/com.termux/files/usr/bin/env bash
#
# adb_watchdog2.sh - Hardened ADB-over-WiFi watchdog for Termux
#
# Features:
#  - multiple detection fallbacks (ss, netstat, nc/ncat, /proc parsing)
#  - configurable interval
#  - logging with rotation (keep last N logs)
#  - optional Termux notification (requires `pkg install termux-api`)
#  - safe remediation: pkill adb, attempt 'adb usb' to force USB-only
#  - test-mode to simulate detection
#
# Usage:
#   ./adb_watchdog2.sh               # run with defaults
#   ./adb_watchdog2.sh --interval 15 --notify --keep 10
#   ./adb_watchdog2.sh --test       # create a fake listener for testing
#
# Notes:
#  - Reboot/disabling wireless-debugging programmatically typically requires root.
#  - This script is "best-effort" on unrooted devices; it maximizes what is possible without root.

LOGDIR="$HOME/adb_watchdog"
mkdir -p "$LOGDIR"
KEEP_LOGS=5
INTERVAL=10          # seconds between checks
NOTIFY=0
TESTMODE=0

# rotate logs: keep $KEEP_LOGS most recent
rotate_logs() {
  local keep=$1
  ls -1t "$LOGDIR"/adb_watchdog_*.log 2>/dev/null | sed -n "$((keep+1)),\$p" | xargs -r rm -f --
}

logfile_create() {
  LOGFILE="$LOGDIR/adb_watchdog_$(date +%Y%m%d_%H%M%S).log"
  rotate_logs "$KEEP_LOGS"
  touch "$LOGFILE"
  echo "Watchdog started at $(date)" >> "$LOGFILE"
}

# helpers
safe_cmd() { command -v "$1" >/dev/null 2>&1; }
notify() {
  local title="$1"; local msg="$2"
  echo "[$(date +'%F %T')] $title - $msg" | tee -a "$LOGFILE"
  if [ "$NOTIFY" -eq 1 ] && safe_cmd termux-notification; then
    termux-notification -t "$title" -c "$msg"
  fi
}

# detection logic tries multiple ways (ss -> netstat -> nc -> /proc)
detect_adb_tcpip() {
  # 1) prefer ss
  if safe_cmd ss; then
    ss -ltnp 2>/dev/null | grep -E '(:| )5555' && return 0
  fi
  # 2) fallback to netstat
  if safe_cmd netstat; then
    netstat -ltnp 2>/dev/null | grep -E '(:| )5555' && return 0
  fi
  # 3) try connect to localhost:5555 (works even if ss/netstat are blocked)
  if safe_cmd ncat; then
    ncat -vz 127.0.0.1 5555 >/dev/null 2>&1 && return 0 || true
  elif safe_cmd nc; then
    nc -vz 127.0.0.1 5555 >/dev/null 2>&1 && return 0 || true
  fi
  # 4) final fallback: parse /proc/net/tcp for local listening 5555 (best-effort)
  if [ -r /proc/net/tcp ]; then
    awk 'NR>1 { split($2,a,":"); port = strtonum("0x" a[2]); if(port==5555) print $0 }' /proc/net/tcp 2>/dev/null | grep -q . && return 0
  fi
  return 1
}

# remediation steps (safe order)
remediate_adb() {
  # record process owners for later analysis
  if safe_cmd ss; then ss -ltnp 2>/dev/null | grep -E '(:| )5555' >> "$LOGFILE" 2>&1; fi
  if safe_cmd netstat; then netstat -ltnp 2>/dev/null | grep -E '(:| )5555' >> "$LOGFILE" 2>&1; fi

  # 1) try polite method: tell device to go back to USB mode (works if device is connected via adb and authorized)
  if safe_cmd adb; then
    echo "[${DATE}] Attempting 'adb usb' (force USB-only)..." | tee -a "$LOGFILE"
    adb usb 2>&1 | tee -a "$LOGFILE"
  fi

  # 2) kill adb processes (local)
  echo "[${DATE}] Killing adb processes (pkill adb)..." | tee -a "$LOGFILE"
  pkill adb 2>/dev/null || killall adb 2>/dev/null || true

  # 3) attempt to revoke adb keys (best-effort - may not work without root)
  if safe_cmd adb; then
    echo "[${DATE}] Attempting 'adb disconnect' + 'adb kill-server'..." | tee -a "$LOGFILE"
    adb disconnect 2>&1 | tee -a "$LOGFILE"
    adb kill-server 2>&1 | tee -a "$LOGFILE"
  fi

  # 4) extra: if Termux API available, notify the user
  notify "ADB Watchdog" "Detected ADB-over-WiFi and attempted remediation (pkill/adb disconnect)."
}

# parse command line
while [ $# -gt 0 ]; do
  case "$1" in
    --interval) INTERVAL="$2"; shift 2;;
    --keep) KEEP_LOGS="$2"; shift 2;;
    --notify) NOTIFY=1; shift;;
    --test) TESTMODE=1; shift;;
    --help) echo "Usage: $0 [--interval N] [--keep N] [--notify] [--test]"; exit 0;;
    *) shift;;
  esac
done

logfile_create

# Test mode: launch a simple listener on 127.0.0.1:5555 (so detection can be verified)
if [ "$TESTMODE" -eq 1 ]; then
  notify "ADB Watchdog (test)" "Starting a fake listener on 127.0.0.1:5555 for 30s"
  # use ncat or nc to create a short-lived listen if available
  if safe_cmd ncat; then
    ncat -l 127.0.0.1 5555 >/dev/null 2>&1 &
    TESTPID=$!
  elif safe_cmd nc; then
    ( while true; do nc -l 127.0.0.1 5555 >/dev/null 2>&1; done ) &
    TESTPID=$!
  else
    echo "No ncat/nc available to run test listener." | tee -a "$LOGFILE"
  fi
fi

notify "ADB Watchdog" "Started (interval=${INTERVAL}s) - logs: $LOGFILE"
# main loop
while true; do
  DATE=$(date +"%Y-%m-%d %H:%M:%S")
  if detect_adb_tcpip; then
    echo "[$DATE] DETECTED: ADB over Wi-Fi (port 5555)!" | tee -a "$LOGFILE"
    remediate_adb 2>&1 | tee -a "$LOGFILE"
  else
    echo "[$DATE] OK: no listener on 5555" | tee -a "$LOGFILE"
  fi

  # if test mode we stop after first cycle and kill the test listener
  if [ "$TESTMODE" -eq 1 ]; then
    if [ -n "$TESTPID" ]; then kill "$TESTPID" 2>/dev/null || true; fi
    echo "Test run complete." | tee -a "$LOGFILE"
    exit 0
  fi

  sleep "$INTERVAL"
done
