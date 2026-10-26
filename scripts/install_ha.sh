#!/bin/bash
export PROOT_NO_SECCOMP=1
proot-distro login debian -- bash -c "
    set -e
    echo '=== Installing Home Assistant Core with pre-resolved requirements ==='
    cp /data/data/com.termux/files/home/ha_requirements.txt /root/ha_requirements.txt
    /opt/ha-venv/bin/pip install --upgrade pip wheel setuptools
    /opt/ha-venv/bin/pip install -r /root/ha_requirements.txt
    /opt/ha-venv/bin/pip install --no-deps homeassistant==2026.2.3
    echo '=== Home Assistant Core Installation Finished ==='
"
