#!/data/data/com.termux/files/usr/bin/bash
# Auto-start services for Android Home Assistant, ESPHome, Tailscale & Battery Monitor

# 1. Acquire wake lock so services keep running with screen off
termux-wake-lock 2>/dev/null

# 2. Start SSH server on port 8022 if not running
if ! pgrep -f "sshd" >/dev/null; then
    sshd
    echo "[+] SSH server started on port 8022"
else
    echo "[=] SSH server already running on port 8022"
fi

# 3. Start Tailscale daemon in userspace networking mode
if command -v tailscaled-start >/dev/null 2>&1; then
    tailscaled-start
fi

# 4. Start Battery Monitor loop (updates ~/battery.json every 15s)
if ! pgrep -f "battery_monitor.sh" >/dev/null; then
    nohup /data/data/com.termux/files/home/battery_monitor.sh > /dev/null 2>&1 &
    echo "[+] Battery monitor started"
else
    echo "[=] Battery monitor already running"
fi

export PROOT_NO_SECCOMP=1

# 5. Start ESPHome Device Builder Dashboard on port 6052
if ! pgrep -f "esphome-device-builder" >/dev/null; then
    nohup proot-distro login debian -- /opt/esphome-venv/bin/esphome-device-builder /root/config/esphome --host 0.0.0.0 --port 6052 > ~/esphome.log 2>&1 &
    echo "[+] ESPHome dashboard started on port 6052"
else
    echo "[=] ESPHome dashboard already running on port 6052"
fi

# 6. Start Home Assistant Core on port 8123
if ! pgrep -f "/opt/ha-venv/bin/hass" >/dev/null; then
    nohup proot-distro login debian -- /opt/ha-venv/bin/hass -c /root/.homeassistant > ~/ha.log 2>&1 &
    echo "[+] Home Assistant Core started on port 8123"
else
    echo "[=] Home Assistant Core already running on port 8123"
fi
