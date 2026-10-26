#!/bin/bash
# Start Home Assistant Core on port 8123
export PROOT_NO_SECCOMP=1
proot-distro login debian -- bash -c "
    mkdir -p /root/.homeassistant
    exec /opt/ha-venv/bin/hass -c /root/.homeassistant
"
