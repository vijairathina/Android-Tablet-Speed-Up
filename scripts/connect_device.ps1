<#
.SYNOPSIS
    Connects to an Android tablet via USB, enables TCP/IP debugging on port 5555,
    detects the tablet's Wi-Fi IP address, and connects wirelessly.
#>
param(
    [string]$TargetIP = ""
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) {
    $adb = "adb"
}

Write-Host "=== Android Tablet ADB Connection Helper ===" -ForegroundColor Cyan

# Check if ADB server is running
& $adb start-server | Out-Null

if ($TargetIP -ne "") {
    Write-Host "Attempting direct wireless connection to $TargetIP:5555..." -ForegroundColor Yellow
    $res = & $adb connect "${TargetIP}:5555"
    Write-Host $res
    if ($res -match "connected to") {
        Write-Host "Successfully connected to $TargetIP wirelessly!" -ForegroundColor Green
        & $adb devices -l
        exit 0
    }
}

Write-Host "`nChecking for USB connected devices..." -ForegroundColor Yellow
$devices = & $adb devices -l
$usbDevice = $devices | Where-Object { $_ -match "device\s+product:" -and $_ -notmatch ":5555" }

if (-not $usbDevice) {
    Write-Host "No USB device detected in ADB mode." -ForegroundColor Red
    Write-Host "Please ensure:" -ForegroundColor Gray
    Write-Host "  1. Tablet is connected to PC via a USB data cable."
    Write-Host "  2. 'Developer options' -> 'USB debugging' is turned ON in Android Settings."
    Write-Host "  3. Accept the 'Allow USB debugging' popup on the tablet screen."
    exit 1
}

Write-Host "Found USB Device: $usbDevice" -ForegroundColor Green
Write-Host "Switching ADB to TCP/IP port 5555..." -ForegroundColor Yellow
& $adb tcpip 5555
Start-Sleep -Seconds 2

# Detect tablet Wi-Fi IP
Write-Host "Detecting tablet Wi-Fi IP..." -ForegroundColor Yellow
$ipOut = & $adb shell "ip addr show wlan0"
$matchedIP = ""
if ($ipOut -match "inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)") {
    $matchedIP = $matches[1]
}

if (-not $matchedIP -and $TargetIP -ne "") {
    $matchedIP = $TargetIP
}

if ($matchedIP) {
    Write-Host "Found tablet IP: $matchedIP. Connecting over Wi-Fi..." -ForegroundColor Green
    & $adb connect "${matchedIP}:5555"
    Write-Host "You can now safely unplug the USB cable!" -ForegroundColor Green
} else {
    Write-Host "Could not automatically determine Wi-Fi IP. Please check tablet Wi-Fi settings." -ForegroundColor Yellow
}

& $adb devices -l
