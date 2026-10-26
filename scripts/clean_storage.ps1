<#
.SYNOPSIS
    Cleans storage on Android tablets by wiping thumbnail caches, app caches,
    temporary installation APKs, and stale download artifacts.
#>
param(
    [string]$DeviceId = ""
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$target = if ($DeviceId) { "-s $DeviceId" } else { "" }

Write-Host "=== Android Tablet Storage Cleaner ===" -ForegroundColor Cyan

# 1. Report storage before cleaning
Write-Host "Storage Before Cleaning:" -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell df -h /data"

# 2. Clean thumbnail databases & cache folders
Write-Host "`nPurging thumbnail directories and temp files..." -ForegroundColor Yellow
$cleanupCommands = @(
    "rm -rf /sdcard/DCIM/.thumbnails/*",
    "rm -rf /sdcard/.thumbnails/*",
    "rm -rf /sdcard/Android/data/*/cache/*",
    "rm -rf /data/local/tmp/*",
    "rm -rf /sdcard/Download/*.apk",
    "rm -rf /sdcard/Download/*.tmp"
)

foreach ($cmd in $cleanupCommands) {
    Invoke-Expression "& `"$adb`" $target shell `"$cmd`""
}

# 3. Trim OS system and application caches
Write-Host "Trimming application caches..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell pm trim-caches 500M"

# 4. Report storage after cleaning
Write-Host "`nStorage After Cleaning:" -ForegroundColor Green
Invoke-Expression "& `"$adb`" $target shell df -h /data"
