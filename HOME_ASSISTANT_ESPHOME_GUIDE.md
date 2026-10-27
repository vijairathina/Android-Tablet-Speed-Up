# 🏠 Turn an Old Android Tablet into an All-in-One Smart Home Server
### Home Assistant Core + ESPHome Web Dashboard via Termux & Debian PRoot

This guide documents the complete, verified, step-by-step procedure to transform a legacy Android tablet (tested on MediaTek MT6735M quad-core 64-bit ARMv8, 2GB RAM, Android 7.0 Nougat) into a dedicated, 24/7 Smart Home Hub and ESPHome firmware build server.

Once configured, the tablet is **100% self-contained**:
- **Home Assistant Web UI** (`http://<TABLET_IP>:8123`) manages all smart home automations, devices, and dashboards.
- **ESPHome Web Dashboard** (`http://<TABLET_IP>:6052`) creates configurations, compiles firmware, and flashes ESP8266 / ESP32 devices Over-The-Air (OTA) directly from the tablet's browser — **no PC required**.
- **OpenSSH Server** (`port 8022`) allows headless management from any computer or smartphone.

---

## 📋 Hardware & Software Prerequisites

| Component | Minimum Requirement | Recommended (Tested Spec) |
| :--- | :--- | :--- |
| **Device Architecture** | 64-bit ARM (`aarch64` / `arm64`) | MediaTek MT6735M Quad-core ARM Cortex-A53 |
| **RAM** | 1.5 GB | 2.0 GB (with ZRAM / Swap enabled) |
| **Internal Storage** | 6.0 GB free | 16.0 GB eMMC (~3.5 GB free after full setup) |
| **Android Version** | Android 7.0 (Nougat, API 24) or newer | Android 7.0 Nougat |
| **Base App** | Termux (from [F-Droid](https://f-droid.org/en/packages/com.termux/)) | Termux v0.118+ |

> [!IMPORTANT]
> **Install Termux from F-Droid, NEVER Google Play Store.** The Google Play Store build of Termux is deprecated and will fail when downloading packages.

---

## 🛠️ Step 1: Prepare Termux Environment

1. Open Termux on the tablet and grant storage permissions:
   ```bash
   termux-setup-storage
   ```
2. Prevent Android from sleeping or killing Termux when the screen turns off:
   ```bash
   termux-wake-lock
   ```
3. Update package lists and install basic tools:
   ```bash
   pkg update -y
   pkg install -y openssh proot-distro git curl
   ```
4. Set a password for remote SSH access:
   ```bash
   passwd
   ```
5. Start OpenSSH server:
   ```bash
   sshd
   ```
   *You can now connect remotely from your PC:*
   ```powershell
   ssh -p 8022 u0_a108@<TABLET_IP>
   ```

---

## 📦 Step 2: Install Debian Linux via `proot-distro`

Debian provides standard glibc support and pre-compiled wheels for Python packages that Android's bionic libc cannot run directly.

1. Install Debian 13 (Trixie):
   ```bash
   proot-distro install debian
   ```
2. Log into the Debian container:
   ```bash
   proot-distro login debian
   ```
3. Install build tools, compiler toolchain, and system libraries required for compiling Home Assistant C-extensions:
   ```bash
   apt-get update -y
   apt-get install -y --no-install-recommends \
       python3 python3-pip python3-venv python3-dev \
       build-essential gcc gcc-aarch64-linux-gnu g++ g++-aarch64-linux-gnu \
       libffi-dev libssl-dev libjpeg-dev zlib1g-dev \
       libpcap-dev libturbojpeg0-dev libsqlite3-dev \
       libxml2-dev libxslt1-dev ffmpeg ca-certificates curl
   ```

---

## ⚡ Step 3: Install ESPHome & Web Dashboard

Recent versions of ESPHome separated the web UI into the `esphome-device-builder` package.

1. Inside Debian, create an isolated virtual environment for ESPHome:
   ```bash
   python3 -m venv /opt/esphome-venv
   /opt/esphome-venv/bin/pip install --upgrade pip wheel
   ```
2. Install ESPHome and ESPHome Device Builder:
   ```bash
   /opt/esphome-venv/bin/pip install esphome esphome-device-builder
   ```
3. Create the ESPHome configurations directory:
   ```bash
   mkdir -p /root/config/esphome
   ```
4. Test running the dashboard:
   ```bash
   /opt/esphome-venv/bin/esphome-device-builder /root/config/esphome --host 0.0.0.0 --port 6052
   ```
   *Open `http://<TABLET_IP>:6052` in your browser to verify it loads.*

---

## 🏡 Step 4: Install Home Assistant Core

Home Assistant Core requires specific dependency alignment to avoid PyPI resolver deadlocks on `aarch64`.

1. Inside Debian, create an isolated virtual environment for Home Assistant:
   ```bash
   python3 -m venv /opt/ha-venv
   /opt/ha-venv/bin/pip install --upgrade pip wheel setuptools uv
   ```

2. Pre-install dependencies to resolve the upstream `cryptography` / `bluetooth` conflict and build assist pipeline C++ extensions:
   ```bash
   # Pin cryptography to the version required by Home Assistant Core 2026.2.x
   /opt/ha-venv/bin/pip install cryptography==46.0.5 pyopenssl==25.3.0
   /opt/ha-venv/bin/pip install --no-deps bluetooth-data-tools==1.29.24
   /opt/ha-venv/bin/pip install habluetooth
   /opt/ha-venv/bin/pip install --no-deps home-assistant-bluetooth

   # Pre-compile C++ assist packages (prevents 'Loading data' UI hang upon login)
   /opt/ha-venv/bin/pip install pymicro-vad==1.0.1 pyspeex-noise==1.0.2
   ```

3. Install Home Assistant Core:
   ```bash
   /opt/ha-venv/bin/pip install homeassistant==2026.2.3
   ```

4. Create configuration directory:
   ```bash
   mkdir -p /root/.homeassistant
   ```

5. Launch Home Assistant Core for the first time:
   ```bash
   /opt/ha-venv/bin/hass -c /root/.homeassistant
   ```
   > [!NOTE]
   > On the first run, Home Assistant will spend 3–5 minutes downloading the web frontend (`home-assistant-frontend`), generating secret encryption keys, and compiling SQLite databases. Once port `8123` opens, the web setup wizard is ready.

---

## 🚀 Step 5: Automate 24/7 Background Services

To ensure that Home Assistant, ESPHome, and SSH start automatically without needing a terminal open:

1. In Termux (outside the Debian container), create `~/start_services.sh`:
   ```bash
   cat << 'EOF' > ~/start_services.sh
   #!/data/data/com.termux/files/usr/bin/bash

   # 1. Acquire Android wake-lock to prevent CPU sleep
   termux-wake-lock 2>/dev/null

   # 2. Start SSH server
   if ! pgrep -f "sshd" >/dev/null; then
       sshd
       echo "[+] SSH server started on port 8022"
   fi

   # 3. Start Tailscale daemon in userspace networking mode
   if command -v tailscaled-start >/dev/null 2>&1; then
       tailscaled-start
   fi

   # 4. Start Battery Monitor loop (updates ~/battery.json every 15s)
   if ! pgrep -f "battery_monitor.sh" >/dev/null; then
       nohup /data/data/com.termux/files/home/battery_monitor.sh > /dev/null 2>&1 &
       echo "[+] Battery monitor started"
   fi

   # 5. Disable seccomp filtering for PRoot stability on Android kernels
   export PROOT_NO_SECCOMP=1

   # 6. Start ESPHome Device Builder Dashboard
   if ! pgrep -f "esphome-device-builder" >/dev/null; then
       nohup proot-distro login debian -- /opt/esphome-venv/bin/esphome-device-builder /root/config/esphome --host 0.0.0.0 --port 6052 > ~/esphome.log 2>&1 &
       echo "[+] ESPHome dashboard started on port 6052"
   fi

   # 7. Start Home Assistant Core
   if ! pgrep -f "/opt/ha-venv/bin/hass" >/dev/null; then
       nohup proot-distro login debian -- /opt/ha-venv/bin/hass -c /root/.homeassistant > ~/ha.log 2>&1 &
       echo "[+] Home Assistant Core started on port 8123"
   fi
   EOF
   chmod +x ~/start_services.sh
   ```

2. Add the script to `~/.bashrc` so it starts whenever Termux opens:
   ```bash
   echo '~/start_services.sh' >> ~/.bashrc
   ```

3. Setup `Termux:Boot` for 100% automated headless startup upon tablet reboot:
   - Download the official `termux-boot-app` matching your Termux build signature (e.g. `termux-boot-app_v0.8.1+github.debug.apk`).
   - Install via ADB:
     ```powershell
     adb install termux-boot-app_v0.8.1+github.debug.apk
     ```
   - Whitelist both Termux and Termux:Boot from Android Doze battery optimizations:
     ```powershell
     adb shell dumpsys deviceidle whitelist +com.termux
     adb shell dumpsys deviceidle whitelist +com.termux.boot
     ```
   - Launch Termux:Boot once so Android registers the boot receiver:
     ```powershell
     adb shell monkey -p com.termux.boot -c android.intent.category.LAUNCHER 1
     ```
   - Copy the startup script into `~/.termux/boot/`:
     ```bash
     mkdir -p ~/.termux/boot
     cp ~/start_services.sh ~/.termux/boot/start_services.sh
     chmod +x ~/.termux/boot/start_services.sh
     ```

---

## 📌 Step 6: Set Permanent Static IP via ADB (Headless UI Automation)

On production Android devices (`adbd cannot run as root`), `ip addr add` is blocked (`Permission denied`). You can configure a permanent Static IP directly through Android's native Settings UI using automated ADB input commands:

1. Open Android Wi-Fi Settings:
   ```powershell
   adb shell am start -a android.settings.WIFI_SETTINGS
   ```
2. Long-press your connected Wi-Fi SSID in the list to trigger the context menu:
   ```powershell
   adb shell input swipe 200 225 200 225 2000
   ```
3. Tap **Modify network**:
   ```powershell
   adb shell input tap 330 385
   ```
4. Dismiss the on-screen keyboard:
   ```powershell
   adb shell input keyevent 111
   ```
5. Check **Advanced options** (if not already checked) and set **IP settings** to **Static**.
6. Tap the **IP address** field, clear previous text, and enter your desired static IP (e.g. `192.168.0.100`):
   ```powershell
   adb shell "input tap 530 752; for i in $(seq 1 20); do input keyevent 67; done; input text 192.168.0.100; input keyevent 111"
   ```
7. Verify Gateway (`192.168.0.1`), Prefix length (`24`), and DNS (`8.8.8.8`).
8. Tap **SAVE** (`input tap 504 902`).
9. Verify the interface adopts the new static IP:
   ```powershell
   adb shell ip addr show wlan0
   ```
   *(Look for `inet 192.168.0.100/24 ... valid_lft forever`)*

---

## 🔒 Step 7: Remote Access via Tailscale (Userspace Mode)

Tailscale's official Android app requires Android 8.0+ (API 26). However, the standalone Linux `tailscale` and `tailscaled` ARM64 binaries run natively in Termux using **Userspace Networking** (gVisor netstack), requiring **no root access** and **no kernel TUN module**:

1. Download the official Tailscale Linux ARM64 tarball:
   ```bash
   cd ~
   curl -LO https://pkgs.tailscale.com/stable/tailscale_1.104.2_arm64.tgz
   tar -xzf tailscale_1.104.2_arm64.tgz
   ```
2. Install the binaries into Termux's system path:
   ```bash
   cp ~/tailscale_1.104.2_arm64/tailscaled /data/data/com.termux/files/usr/bin/tailscaled
   cp ~/tailscale_1.104.2_arm64/tailscale /data/data/com.termux/files/usr/bin/tailscale.real
   chmod +x /data/data/com.termux/files/usr/bin/tailscaled /data/data/com.termux/files/usr/bin/tailscale.real
   ```
3. Create the `tailscale` CLI wrapper passing the userspace socket:
   ```bash
   cat << 'EOF' > /data/data/com.termux/files/usr/bin/tailscale
   #!/data/data/com.termux/files/usr/bin/bash
   exec /data/data/com.termux/files/usr/bin/tailscale.real --socket /data/data/com.termux/files/usr/var/run/tailscale/tailscaled.sock "$@"
   EOF
   chmod +x /data/data/com.termux/files/usr/bin/tailscale
   ```
4. Create the background daemon start script (`/data/data/com.termux/files/usr/bin/tailscaled-start`):
   ```bash
   cat << 'EOF' > /data/data/com.termux/files/usr/bin/tailscaled-start
   #!/data/data/com.termux/files/usr/bin/bash
   if pgrep -f "/usr/bin/tailscaled" > /dev/null 2>&1; then
       echo "Tailscaled is already running."
       exit 0
   fi
   mkdir -p /data/data/com.termux/files/usr/var/run/tailscale
   mkdir -p /data/data/com.termux/files/home/.tailscale
   rm -f /data/data/com.termux/files/usr/var/run/tailscale/tailscaled.sock

   nohup /data/data/com.termux/files/usr/bin/tailscaled \
     --tun=userspace-networking \
     --statedir=/data/data/com.termux/files/home/.tailscale \
     --socket=/data/data/com.termux/files/usr/var/run/tailscale/tailscaled.sock \
     --socks5-server=localhost:1055 \
     --outbound-http-proxy-listen=localhost:1056 \
     > /data/data/com.termux/files/home/tailscaled.log 2>&1 &
   EOF
   chmod +x /data/data/com.termux/files/usr/bin/tailscaled-start
   ```
5. Log into Tailscale:
   ```bash
   tailscaled-start
   tailscale login
   # Or with an auth-key:
   # tailscale up --authkey=tskey-auth-... --hostname=tablet-ha
   ```
   *Follow the authentication link in your browser to authorize the tablet on your tailnet.*

---

## 🔋 Step 8: Detect Tablet Battery & Charging Status in Home Assistant

To monitor the tablet's battery percentage and charging state directly on the Home Assistant dashboard (essential for setting up smart plug battery protection automations to cycle between 20% and 80%):

1. **Install Termux:API App & Package:**
   - Install `termux-api-app_v0.53.0+github.debug.apk` via ADB:
     ```powershell
     adb install termux-api.apk
     adb shell dumpsys deviceidle whitelist +com.termux.api
     ```
   - In Termux, install the CLI companion:
     ```bash
     pkg install -y termux-api
     ```
   - Verify battery detection:
     ```bash
     termux-battery-status
     ```

2. **Create the Background Battery Monitor:**
   - Create `~/battery_monitor.sh`:
     ```bash
     cat << 'EOF' > ~/battery_monitor.sh
     #!/data/data/com.termux/files/usr/bin/bash
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
     EOF
     chmod +x ~/battery_monitor.sh
     ```

3. **Configure Home Assistant Sensors:**
   - In `/root/.homeassistant/configuration.yaml` (inside Debian PRoot), add:
     ```yaml
     command_line:
       - sensor:
           name: "Tablet Battery Level"
           unique_id: tablet_battery_level
           command: "cat /data/data/com.termux/files/home/battery.json"
           value_template: "{{ value_json.percentage }}"
           unit_of_measurement: "%"
           device_class: battery
           state_class: measurement
           scan_interval: 15
       - sensor:
           name: "Tablet Battery Status"
           unique_id: tablet_battery_status
           command: "cat /data/data/com.termux/files/home/battery.json"
           value_template: "{{ value_json.status }}"
           icon: "mdi:battery-charging"
           scan_interval: 15
       - sensor:
           name: "Tablet Power Source"
           unique_id: tablet_power_source
           command: "cat /data/data/com.termux/files/home/battery.json"
           value_template: "{{ value_json.plugged }}"
           icon: "mdi:power-plug"
           scan_interval: 15
       - sensor:
           name: "Tablet Battery Temperature"
           unique_id: tablet_battery_temperature
           command: "cat /data/data/com.termux/files/home/battery.json"
           value_template: "{{ value_json.temperature }}"
           unit_of_measurement: "°C"
           device_class: temperature
           state_class: measurement
           scan_interval: 15
       - binary_sensor:
           name: "Tablet Charging"
           unique_id: tablet_charging
           command: "cat /data/data/com.termux/files/home/battery.json"
           value_template: "{{ value_json.status in ['CHARGING', 'FULL'] or value_json.plugged in ['PLUGGED_USB', 'PLUGGED_AC'] }}"
           payload_on: "True"
           payload_off: "False"
           device_class: battery_charging
           scan_interval: 15
     ```

4. **Restart Home Assistant:**
   ```bash
   pkill -f "/opt/ha-venv/bin/hass" && ~/start_services.sh
   ```
   *Your Home Assistant dashboard now displays:*
   - **`sensor.tablet_battery_level`** (Shows 0–100% with native battery icon)
   - **`binary_sensor.tablet_charging`** (`on` when charging, `off` when on battery)
   - **`sensor.tablet_power_source`** (`PLUGGED_USB`, `PLUGGED_AC`, `UNPLUGGED`)
   - **`sensor.tablet_battery_temperature`** (Live temperature in °C)

---

## ⏰ Step 9: Daily Automated Maintenance Restart (Every Night at 12:00 AM)

Running a 24/7 server on a budget Android device can lead to RAM fragmentation over time. MediaTek chipsets feature a native hardware Real-Time Clock (RTC) **Scheduled Power On & Off** feature in the PMIC that powers down the device, and then **powers it back on automatically without pressing the physical power button**:

1. **Launch MediaTek Schedule Power On/Off settings via ADB:**
   ```powershell
   adb shell am start -n com.mediatek.schpwronoff/.AlarmClock
   ```
2. **Configure Daily Schedule:**
   - **Power OFF:** Set to `00:00` (12:00 AM midnight), Repeat `Every day`.
   - **Power ON:** Set to `00:05` (12:05 AM, 5 minutes later), Repeat `Every day`.
3. **Automated Headless Reboot Cycle:**
   - Every night at 12:00 AM, Android performs a graceful system shutdown.
   - For 5 minutes, hardware enters zero-power RTC standby, completely clearing RAM and dissipating heat.
   - At 12:05 AM, the hardware RTC alarm fires and **boots Android automatically**.
   - `Termux:Boot` launches upon boot and automatically starts `sshd`, `tailscaled`, `battery_monitor`, `esphome`, and Home Assistant!

---

## 🏷️ Step 10: Set Device Hostname to `tablet` Across All Environments

To ensure the server is identified consistently across your home network, SSH terminals, and Tailscale VPN without messy generic IDs:

1. **Run the One-Click Hostname Setup Script:**
   ```powershell
   .\scripts\set_hostname.ps1 -DeviceIp "<TABLET_IP>" -Hostname "tablet"
   ```

2. **What this script configures automatically:**
   - **Android OS Properties:** Sets `device_name` and `bluetooth_name` to `tablet` in Android Settings.
   - **Termux Environment:** Sets `/data/data/com.termux/files/usr/etc/hostname` to `tablet`, updates `/etc/hosts`, configures `HOSTNAME=tablet` in login profile, and customizes `PS1` prompt to `u0_a108@tablet:~$ `.
   - **Debian PRoot Container:** Sets `/etc/hostname` and `/etc/hosts`, sets shell prompt to `root@tablet:~# `, and wraps `hostname` binary so system queries return `tablet`.
   - **Tailscale VPN:** Registers `--hostname=tablet`, enabling remote access anywhere via:
     - `http://tablet:8123` (Home Assistant)
     - `http://tablet:6052` (ESPHome)
     - `ssh -p 8022 u0_a108@tablet` (OpenSSH)

---

## 🌐 Verifying & Using the Server

From any phone, tablet, or PC connected to the same Wi-Fi network:

### 1. Home Assistant Setup (`http://<TABLET_IP>:8123`)
- Open `http://<TABLET_IP>:8123` in Google Chrome or any modern browser.
- Complete the initial setup: create your owner account, name your home, and set location.
- Home Assistant will automatically detect local network smart devices (Google Cast, Philips Hue, ESPHome nodes, WLED, Shelly, TP-Link, etc.).

### 2. ESPHome Firmware Builder (`http://<TABLET_IP>:6052`)
- Open `http://<TABLET_IP>:6052`.
- Click **Add Device** to create a new YAML configuration for your ESP8266 or ESP32 boards.
- Click **Install** -> **Wirelessly**: the tablet will compile the binary using PlatformIO inside Debian and upload it directly to your microcontroller via OTA Wi-Fi.

---

## 🔍 Useful Diagnostics & Troubleshooting

| Action | Command (via Termux SSH) |
| :--- | :--- |
| **Check Port Status** | `netstat -tulpn \| grep -E '8022\|6052\|8123'` |
| **Check Tailscale Status** | `tailscale status` |
| **View Battery JSON** | `cat ~/battery.json` |
| **View Home Assistant Live Log** | `tail -f /data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs/root/.homeassistant/home-assistant.log` |
| **View ESPHome Output** | `cat ~/esphome.log` |
| **Check RAM & Swap Usage** | `free -m` |
| **Check Storage Available** | `df -h /data` |
| **Restart All Services** | `killall -9 python3 2>/dev/null; ~/start_services.sh` |

### Common Gotchas & Fixes:
1. **Assertion error `IS_IN_SYSENTER(tracee)`:**
   - Cause: Android Linux kernel's seccomp filter conflicting with PRoot system call emulation.
   - Solution: Always run with `export PROOT_NO_SECCOMP=1`.
2. **Missing FFmpeg warning in HA logs:**
   - Solution: Run `apt-get install -y ffmpeg` inside Debian.
3. **Wi-Fi IP Address Changed:**
   - Solution: Configure a Static IP on the tablet directly via Android Wi-Fi settings (Step 6) or assign a DHCP reservation in your router.
4. **Tailscale APK Install Failed (`INSTALL_FAILED_OLDER_SDK`):**
   - Cause: Official Tailscale Android APK requires API 26 (Android 8.0+), but legacy tablets run Android 7.0 (API 24).
   - Solution: Run the standalone Linux ARM64 static binary in userspace networking mode inside Termux (Step 7).
