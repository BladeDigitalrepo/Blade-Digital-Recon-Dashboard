#!/data/data/com.termux/files/usr/bin/env bash
# port_recon.sh - Port & connection reconnaissance for Termux (Android)
# Usage: ./port_recon.sh [--scan-net] [--nmap] [--notify]

OUTDIR="$HOME/port_recon"
LOG="$OUTDIR/port_recon_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$OUTDIR"
echo "Port Recon started at $(date)" | tee -a "$LOG"

# Helpers
safe_cmd() { command -v "$1" >/dev/null 2>&1; }

# 1) ADB status
echo -e "\n=== ADB Status ===" | tee -a "$LOG"
if safe_cmd adb; then
  adb start-server 2>/dev/null
  adb devices -l 2>&1 | tee -a "$LOG"
else
  echo "adb not installed/in PATH" | tee -a "$LOG"
fi

# 2) Listening sockets
echo -e "\n=== Listening sockets ===" | tee -a "$LOG"
if safe_cmd ss; then
  ss -tulpen 2>&1 | tee -a "$LOG" || echo "ss error or permission denied" | tee -a "$LOG"
elif safe_cmd netstat; then
  netstat -tulnp 2>&1 | tee -a "$LOG" || echo "netstat error or permission denied" | tee -a "$LOG"
else
  echo "ss/netstat not available; will parse /proc/net/tcp /udp" | tee -a "$LOG"
fi

# 3) Parse /proc/net/tcp and udp
parse_proc_sockets() {
  proto=$1
  path="/proc/net/$proto"
  [ -r "$path" ] || return 0                                                                                                                              echo -e "\n--- $proto (parsed) ---" | tee -a "$LOG"
  awk 'NR>1 { printf "%s %s %s\n",$2,$4,$10 }' "$path" | while read -r local st inode; do
    iphex=${local%:*}; porthex=${local#*:}
    ip=$(printf "%d.%d.%d.%d" "0x${iphex:6:2}" "0x${iphex:4:2}" "0x${iphex:2:2}" "0x${iphex:0:2}")
    port=$((16#$porthex))
    echo "proto=$proto state=$st $ip:$port inode=$inode" | tee -a "$LOG"
  done
}
parse_proc_sockets tcp
parse_proc_sockets udp

# 4) Map socket inode -> pid
echo -e "\n=== Mapping socket inodes -> PID (best effort) ===" | tee -a "$LOG"
for inode in $(awk 'NR>1{print $10}' /proc/net/tcp /proc/net/udp 2>/dev/null | sort -u); do
  found=0
  for pidfd in /proc/[0-9]*/fd 2>/dev/null; do
    pid=$(basename "$(dirname "$pidfd")")
    for fd in "$pidfd"/* 2>/dev/null; do
      link=$(readlink -f "$fd" 2>/dev/null) || continue
      if [[ "$link" == "socket:[$inode]" ]]; then
        cmd=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
        echo "inode=$inode -> pid=$pid cmd='$cmd'" | tee -a "$LOG"
        found=1; break 2
      fi
    done
  done
  [ $found -eq 0 ] && echo "inode=$inode -> (no matching pid or denied)" | tee -a "$LOG"
done

# 5) Active TCP connections
echo -e "\n=== Active TCP connections ===" | tee -a "$LOG"
if safe_cmd ss; then
  ss -tnp 2>&1 | tee -a "$LOG" || echo "ss permission denied" | tee -a "$LOG"
elif safe_cmd netstat; then
  netstat -tnp 2>&1 | tee -a "$LOG" || echo "netstat permission denied" | tee -a "$LOG"
else
  awk 'NR>1{print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/net/tcp 2>/dev/null | tee -a "$LOG"
fi

# 6) Local LAN discovery
echo -e "\n=== Local LAN discovery ===" | tee -a "$LOG"
if safe_cmd nmap; then
  echo "Tip: run with --scan-net to enable full nmap ping sweep" | tee -a "$LOG"
else
  echo "Using ip neigh + arp:" | tee -a "$LOG"
  ip neigh show 2>/dev/null | tee -a "$LOG"
  safe_cmd arp && arp -n 2>/dev/null | tee -a "$LOG"
fi

# optional nmap netscan                                                                                                                                 if [[ " $* " == *" --scan-net "* ]] && safe_cmd nmap; then
  SUBNET=$(ip route | awk '/src/ {print $1; exit}')
  [ -z "$SUBNET" ] && SUBNET="192.168.1.0/24"
  echo -e "\n[nmap -sn $SUBNET]" | tee -a "$LOG"
  nmap -sn "$SUBNET" 2>&1 | tee -a "$LOG"
fi

# 7) Service detection
if [[ " $* " == *" --nmap "* ]] && safe_cmd nmap; then
  echo -e "\n=== nmap -sV on listening ports ===" | tee -a "$LOG"
  ports=$(ss -tln 2>/dev/null | awk 'NR>1{split($4,a,":"); print a[length(a)]}' | sort -u | tr '\n' ',' | sed 's/,$//')
  [ -z "$ports" ] && ports=$(awk 'NR>1{split($2,a,":"); print strtonum("0x" a[2])}' /proc/net/tcp 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
  if [ -n "$ports" ]; then
    echo "Detected ports: $ports" | tee -a "$LOG"
    nmap -sV -p "$ports" localhost 2>&1 | tee -a "$LOG"
  else
    echo "No listening ports detected" | tee -a "$LOG"
  fi
fi

# 8) ADB over Wi-Fi check
echo -e "\n=== ADB over Wi-Fi check (5555) ===" | tee -a "$LOG"
if safe_cmd ss; then
  ss -ltnp 2>/dev/null | grep -E '(:| )5555' | tee -a "$LOG" || echo "No 5555 listener" | tee -a "$LOG"
elif safe_cmd ncat; then
  ncat -vz 127.0.0.1 5555 2>&1 | tee -a "$LOG"
elif safe_cmd nc; then
  nc -vz 127.0.0.1 5555 2>&1 | tee -a "$LOG" || echo "nc can't connect or denied" | tee -a "$LOG"
else
  echo "no nc/ncat to test 5555" | tee -a "$LOG"
fi

echo -e "\nRecon complete. Log: $LOG" | tee -a "$LOG"

# 9) Optional Termux notification
if [[ " $* " == *" --notify "* ]] && safe_cmd termux-notification; then
  termux-notification -t "port_recon" -c "Recon finished. See $LOG"
fi-
