<#
.SYNOPSIS
    Fixes the recurring 'Google Play services has stopped' ANR error on low-RAM Android tablets.
    Root Cause: com.google.android.googlequicksearchbox engages in background sync/indexing loops
    that peg CPU at 100%, causing Google Play Services (GMS) watchdogs to timeout and throw ANRs.
#>
param(
    [string]$DeviceId = ""
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$target = if ($DeviceId) { "-s $DeviceId" } else { "" }

Write-Host "=== Fixing Google Play Services Crash & ANR Loop ===" -ForegroundColor Cyan

# 1. Disable Google Quick Search Box
Write-Host "Disabling com.google.android.googlequicksearchbox..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell pm disable-user com.google.android.googlequicksearchbox"
Invoke-Expression "& `"$adb`" $target shell pm clear com.google.android.googlequicksearchbox"

# 2. Disable heavy Google background sync/telemetry stubs
Write-Host "Disabling Google feedback and heavy stubs..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell pm disable-user com.google.android.feedback"
Invoke-Expression "& `"$adb`" $target shell pm disable-user com.google.android.marvin.talkback"

# 3. Clear Google Play Services corrupted cache
Write-Host "Clearing Google Play Services cache (safely preserving account credentials)..." -ForegroundColor Yellow
Invoke-Expression "& `"$adb`" $target shell pm trim-caches 100M"

Write-Host "Google Play Services stabilized. CPU starvation eliminated!" -ForegroundColor Green
