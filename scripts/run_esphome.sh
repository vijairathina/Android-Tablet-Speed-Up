#!/bin/bash
# Start ESPHome Device Builder Dashboard on port 6052
export PROOT_NO_SECCOMP=1
proot-distro login debian -- bash -c "
    mkdir -p /root/config/esphome
    exec /opt/esphome-venv/bin/esphome-device-builder /root/config/esphome --host 0.0.0.0 --port 6052
"
