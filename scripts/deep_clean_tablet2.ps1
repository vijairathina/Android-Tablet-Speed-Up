<#
.SYNOPSIS
    Deep clean for Tablet 2: removes all non-mandatory apps and purges all personal storage,
    keeping only Chrome, YouTube Lite, Play Store, and core Android system services.
#>
param(
    [string]$Target = "192.168.0.18:5555"
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

Write-Host "=== Deep Cleaning Tablet 2 ($Target) ===" -ForegroundColor Cyan

# 1. Third-Party Apps to Remove
$appsToRemove = @(
    "com.rvappstudios.kids.drawing.games.coloring.book.paint",
    "com.JindoBlu.OfflineGames",
    "com.outfit7.mytalkingtomfriends",
    "com.anydesk.anydeskandroid",
    "cn.readpad.whiteboard",
    "com.king.candycrushsaga",
    "com.androidbull.tictactoe",
    "com.vicman.toonmeapp",
    
    # Non-mandatory preinstalled Google/OEM apps
    "com.google.android.apps.maps",
    "com.google.android.apps.photos",
    "com.google.android.calendar",
    "com.google.android.keep",
    "com.google.android.gm",
    "com.android.calculator2",
    "com.android.email",
    "com.android.music",
    "com.mediatek.calendarimporter"
)

Write-Host "`n>>> Removing non-mandatory apps..." -ForegroundColor Yellow
foreach ($pkg in $appsToRemove) {
    Write-Host "Removing: $pkg..." -ForegroundColor Gray
    # First clear app data to free disk space immediately
    & $adb -s $Target shell pm clear $pkg 2>$null | Out-Null
    # Uninstall for user 0
    $un = & $adb -s $Target shell pm uninstall -k --user 0 $pkg 2>&1
    if ($un -match "Success") {
        Write-Host "  -> Uninstalled: $pkg" -ForegroundColor Green
    } else {
        & $adb -s $Target shell pm disable-user $pkg 2>$null | Out-Null
        Write-Host "  -> Disabled: $pkg" -ForegroundColor Yellow
    }
}

# 2. Storage Purge
Write-Host "`n>>> Purging user storage and temporary files..." -ForegroundColor Yellow
$purgePaths = @(
    "/sdcard/Recording/*",
    "/sdcard/DCIM/*",
    "/sdcard/Pictures/*",
    "/sdcard/Screenshots/*",
    "/sdcard/Movies/*",
    "/sdcard/Meet/*",
    "/sdcard/Download/*",
    "/sdcard/bluetooth/*",
    "/sdcard/push/*",
    "/sdcard/*.png",
    "/sdcard/.thumbnails/*",
    "/sdcard/Android/data/*/cache/*",
    "/data/local/tmp/*"
)

foreach ($path in $purgePaths) {
    Write-Host "Purging $path..." -ForegroundColor Gray
    & $adb -s $Target shell "rm -rf $path" 2>$null | Out-Null
}

Write-Host "`n>>> Trimming OS system cache..." -ForegroundColor Yellow
& $adb -s $Target shell "pm trim-caches 500M" 2>$null | Out-Null

Write-Host "`nDeep clean completed successfully!" -ForegroundColor Green
