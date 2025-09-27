# ⚡ Blade Digital Recon Dashboard ⚡
> **ADB | Watchdog | Port Recon — All on Mobile**

![Blade Digital Banner](./assets/blade_banner.png)

A compact **mobile recon toolkit** designed to run inside **[Termux](https://termux.dev/)** (or Kali NetHunter).  
Easily check ADB status, run a watchdog against Wi-Fi debugging, and perform deep port/device reconnaissance — all from your Android device.

---

## ✨ Features
- 🔍 **ADB Check** → Detect if ADB is running & exposed on port `5555`.
- 🛡️ **Watchdog** → Kill ADB over Wi-Fi if it’s enabled, log it, and notify you.
- 🌐 **Port Recon** → Run local scans, map processes, identify connected devices, and log everything.
- 🎨 **Blade Digital Dashboard** → Neon-glitch TUI menu to control it all.

---

## 📂 Project Structure
---

## 🚀 Quick Start

### 1. Install Termux + Dependencies
```bash
pkg update && pkg upgrade -y
pkg install git curl wget nmap net-tools ncurses nc openjdk-17 -y
pkg install termux-api -y    # optional (for notifications)
## 2.Clone Repository:
git clone
ttps://github.com/BladeDigitalrepo/blade-digital
-recon-dashboard.git
cd blade-digital-recon-dashboard
3.Make Scripts Executable
Bash
Copycode
chmod +x*.ss
4. Run
./blade_recon_dashboard.sh


==================================
BLADE≋≋
⚡ Blade Digital Recon Dashboard ⚡
ADB | Watchdog | Port Recon | Logs
==================================

1) Run ADB Check
2) Start ADB Watchdog
3) Stop ADB Watchdog
4) Run Port Recon (quick)
5) Run Port Recon (full)
6) View Logs
7) Exit

