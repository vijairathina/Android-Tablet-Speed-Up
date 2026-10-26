<#
.SYNOPSIS
    Master one-click speed-up script for legacy Android tablets.
    Automates connection verification, crash loop fixes, debloating,
    storage reclamation, battery optimizations, and YouTube Lite deployment.
#>
param(
    [string]$DeviceId = ""
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       LEGACY ANDROID TABLET OPTIMIZER & SPEED-UP         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Device check
$devices = & $adb devices -l
$activeDevices = $devices | Where-Object { $_ -match "\s+device\s+" }

if (-not $activeDevices) {
    Write-Host "Error: No active Android device found via ADB." -ForegroundColor Red
    Write-Host "Please run .\connect_device.ps1 or connect your tablet via USB." -ForegroundColor Yellow
    exit 1
}

if (-not $DeviceId) {
    $firstDevice = ($activeDevices[0] -split "\s+")[0]
    $DeviceId = $firstDevice
}

Write-Host "Target Device: $DeviceId" -ForegroundColor Green

# 2. Run Modules
Write-Host "`n>>> Step 1: Stabilizing Google Play Services & eliminating ANR crashes..." -ForegroundColor Yellow
& "$PSScriptRoot\fix_google_services.ps1" -DeviceId $DeviceId

Write-Host "`n>>> Step 2: Debloating OEM stubs, telemetry, and dead apps..." -ForegroundColor Yellow
& "$PSScriptRoot\debloat.ps1" -DeviceId $DeviceId

Write-Host "`n>>> Step 3: Cleaning thumbnail caches and recovering storage..." -ForegroundColor Yellow
& "$PSScriptRoot\clean_storage.ps1" -DeviceId $DeviceId

Write-Host "`n>>> Step 4: Applying battery savings & radio optimizations..." -ForegroundColor Yellow
& "$PSScriptRoot\optimize_battery.ps1" -DeviceId $DeviceId

Write-Host "`n>>> Step 5: Installing lightweight YouTube with Google Sign-in support..." -ForegroundColor Yellow
& "$PSScriptRoot\install_youtube_lite.ps1" -DeviceId $DeviceId

# 3. Final Diagnostics Summary
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                FINAL OPTIMIZATION REPORT                 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$target = "-s $DeviceId"
Write-Host "Storage Space:" -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell df -h /data"

Write-Host "`nRAM Status:" -ForegroundColor Yellow
$mem = Invoke-Expression "& `"$adb`" $target shell dumpsys meminfo | grep -E 'Total RAM|Free RAM|Used RAM'"
Write-Host $mem

Write-Host "`nSystem Load & Idle:" -ForegroundColor Yellow
$top = Invoke-Expression "& `"$adb`" $target shell top -n 1 -m 5"
Write-Host ($top -join "`n")

Write-Host "`nTablet optimization completed successfully!" -ForegroundColor Green
