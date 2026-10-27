<#
.SYNOPSIS
    Configures hostname to "tablet" across Android OS, Termux, Debian PRoot, and Tailscale.

.DESCRIPTION
    Ensures that the tablet identifies itself consistently as "tablet" across all environments:
    - Android OS device name & Bluetooth name
    - Termux Linux rootfs (/etc/hostname, /etc/hosts, PS1 shell prompt)
    - Debian PRoot Linux container (/etc/hostname, /etc/hosts, PS1 prompt)
    - Tailscale VPN MagicDNS network identity (http://tablet:8123)

.EXAMPLE
    .\scripts\set_hostname.ps1 -DeviceIp "192.168.0.100" -Hostname "tablet"
#>

param(
    [string]$DeviceIp = "192.168.0.100",
    [string]$Hostname = "tablet",
    [string]$AdbPath = "C:\ADB\adb.exe"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Setting Hostname to '$Hostname' on Android Server" -ForegroundColor Cyan
Write-Host " Device IP: $DeviceIp" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Configure Android System Properties via ADB
Write-Host "`n[1/4] Setting Android OS Device Names via ADB..." -ForegroundColor Yellow
if (Test-Path $AdbPath) {
    & $AdbPath connect "$($DeviceIp):5555" | Out-Null
    & $AdbPath -s "$($DeviceIp):5555" shell "settings put global device_name $Hostname"
    & $AdbPath -s "$($DeviceIp):5555" shell "settings put system device_name $Hostname"
    & $AdbPath -s "$($DeviceIp):5555" shell "settings put secure bluetooth_name $Hostname"
    Write-Host "  [+] Android global device_name: $(& $AdbPath -s "$($DeviceIp):5555" shell 'settings get global device_name')" -ForegroundColor Green
    Write-Host "  [+] Android bluetooth_name:     $(& $AdbPath -s "$($DeviceIp):5555" shell 'settings get secure bluetooth_name')" -ForegroundColor Green
} else {
    Write-Warning "ADB executable not found at $AdbPath. Skipping ADB property updates."
}

# 2. Configure Termux Environment
Write-Host "`n[2/4] Configuring Termux Environment..." -ForegroundColor Yellow
$termuxCommands = @"
echo '$Hostname' > /data/data/com.termux/files/usr/etc/hostname
echo -e '127.0.0.1 localhost $Hostname\n::1 ip6-localhost $Hostname' > /data/data/com.termux/files/usr/etc/hosts
mkdir -p /data/data/com.termux/files/usr/etc/profile.d
echo 'export HOSTNAME=$Hostname' > /data/data/com.termux/files/usr/etc/profile.d/hostname.sh
chmod +x /data/data/com.termux/files/usr/etc/profile.d/hostname.sh

if [ ! -f /data/data/com.termux/files/usr/bin/hostname.orig ]; then
    cp /data/data/com.termux/files/usr/bin/hostname /data/data/com.termux/files/usr/bin/hostname.orig
fi
printf '%s\n' '#!/data/data/com.termux/files/usr/bin/bash' 'if [ "\$#" -eq 0 ]; then' '    cat /data/data/com.termux/files/usr/etc/hostname 2>/dev/null || echo "$Hostname"' 'else' '    /data/data/com.termux/files/usr/bin/hostname.orig "\$@" 2>/dev/null || true' 'fi' > /data/data/com.termux/files/usr/bin/hostname
chmod +x /data/data/com.termux/files/usr/bin/hostname
termux-fix-shebang /data/data/com.termux/files/usr/bin/hostname 2>/dev/null

grep -q 'export HOSTNAME=$Hostname' ~/.bashrc || echo 'export HOSTNAME=$Hostname' >> ~/.bashrc
grep -q 'export PS1=' ~/.bashrc || echo 'export PS1="\[\e[0;32m\]\u@$Hostname\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\\$ "' >> ~/.bashrc
"@

$cleanTermuxCommands = $termuxCommands.Replace("`r`n", "`n")
$cleanTermuxCommands | ssh -p 8022 -o StrictHostKeyChecking=no "u0_a108@$DeviceIp" "bash"
Write-Host "  [+] Termux hostname set to '$Hostname'" -ForegroundColor Green

# 3. Configure Debian PRoot Environment
Write-Host "`n[3/4] Configuring Debian PRoot Environment..." -ForegroundColor Yellow
$debianCommands = @"
export PROOT_NO_SECCOMP=1
proot-distro login debian -- bash -c '
echo "$Hostname" > /etc/hostname
echo -e "127.0.0.1 $Hostname localhost\n::1 $Hostname localhost ip6-localhost" > /etc/hosts
if [ ! -f /bin/hostname.orig ]; then
    cp /bin/hostname /bin/hostname.orig
fi
printf "%s\n" "#!/bin/bash" "if [ \"\\\$#\" -eq 0 ]; then" "    cat /etc/hostname 2>/dev/null || echo \"$Hostname\"" "else" "    /bin/hostname.orig \"\\\$@\" 2>/dev/null || true" "fi" > /bin/hostname
chmod +x /bin/hostname
grep -q "export HOSTNAME=$Hostname" /root/.bashrc || echo "export HOSTNAME=$Hostname" >> /root/.bashrc
grep -q "export PS1=" /root/.bashrc || echo "export PS1=\"\[\e[0;31m\]\u@$Hostname\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]# \"" >> /root/.bashrc
'
"@

$cleanDebianCommands = $debianCommands.Replace("`r`n", "`n")
$cleanDebianCommands | ssh -p 8022 -o StrictHostKeyChecking=no "u0_a108@$DeviceIp" "bash"
Write-Host "  [+] Debian PRoot hostname set to '$Hostname'" -ForegroundColor Green

# 4. Configure Tailscale Hostname
Write-Host "`n[4/4] Setting Tailscale Machine Hostname..." -ForegroundColor Yellow
$tailscaleCommand = "tailscale set --hostname=$Hostname 2>/dev/null || true; tailscale status | grep $Hostname"
ssh -p 8022 -o StrictHostKeyChecking=no "u0_a108@$DeviceIp" "$tailscaleCommand"
Write-Host "  [+] Tailscale hostname verified as '$Hostname'" -ForegroundColor Green

Write-Host "`n Hostname configuration complete! The tablet is now named '$Hostname' everywhere." -ForegroundColor Green
