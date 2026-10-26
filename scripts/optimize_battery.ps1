<#
.SYNOPSIS
    Optimizes battery life and eliminates background radio drain on Android tablets.
#>
param(
    [string]$DeviceId = ""
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$target = if ($DeviceId) { "-s $DeviceId" } else { "" }

Write-Host "=== Android Tablet Battery & Radio Optimizer ===" -ForegroundColor Cyan

# 1. Turn off always-on background Wi-Fi and Bluetooth scanning
Write-Host "Disabling background Wi-Fi and Bluetooth LE location scanning..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell settings put global wifi_scan_always_enabled 0"
Invoke-Expression "& `"$adb`" $target shell settings put global ble_scan_always_enabled 0"

# 2. Turn off GPS location hardware
Write-Host "Disabling power-hungry GPS hardware chip..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell settings put secure location_mode 0"

# 3. Configure display settings (display is #1 battery consumer)
Write-Host "Configuring display timeout (60s) and comfortable brightness (130/255)..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell settings put system screen_off_timeout 60000"
Invoke-Expression "& `"$adb`" $target shell settings put system screen_brightness 130"

# 4. Enforce aggressive Doze/Idle state when screen turns off
Write-Host "Enabling aggressive Doze mode..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell dumpsys deviceidle enable"

Write-Host "Battery optimizations applied successfully!" -ForegroundColor Green
