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
       build-essential gcc gcc-aarch64-linux-gnu \
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

2. Pre-install dependencies to resolve the upstream `cryptography` / `bluetooth` conflict:
   ```bash
   # Pin cryptography to the version required by Home Assistant Core 2026.2.x
   /opt/ha-venv/bin/pip install cryptography==46.0.5 pyopenssl==25.3.0
   /opt/ha-venv/bin/pip install --no-deps bluetooth-data-tools==1.29.24
   /opt/ha-venv/bin/pip install habluetooth
   /opt/ha-venv/bin/pip install --no-deps home-assistant-bluetooth
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

   # 3. Disable seccomp filtering for PRoot stability on Android kernels
   export PROOT_NO_SECCOMP=1

   # 4. Start ESPHome Device Builder Dashboard
   if ! pgrep -f "esphome-device-builder" >/dev/null; then
       nohup proot-distro login debian -- /opt/esphome-venv/bin/esphome-device-builder /root/config/esphome --host 0.0.0.0 --port 6052 > ~/esphome.log 2>&1 &
       echo "[+] ESPHome dashboard started on port 6052"
   fi

   # 5. Start Home Assistant Core
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

3. *(Optional)* Setup `Termux:Boot` for automatic launch upon tablet reboot:
   ```bash
   mkdir -p ~/.termux/boot
   cp ~/start_services.sh ~/.termux/boot/start_services.sh
   chmod +x ~/.termux/boot/start_services.sh
   ```

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
   - Solution: In your Wi-Fi router's admin panel, create a **DHCP Static IP Reservation** for the tablet's MAC address so the IP address never changes.
