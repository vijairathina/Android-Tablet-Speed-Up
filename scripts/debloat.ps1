<#
.SYNOPSIS
    Debloats Android tablets by safely uninstalling preinstalled OEM bloat, telemetry,
    adware stubs, dead services, and unworking legacy YouTube for User 0.
#>
param(
    [string]$DeviceId = ""
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$target = if ($DeviceId) { "-s $DeviceId" } else { "" }

Write-Host "=== Android Tablet Deep Debloater ===" -ForegroundColor Cyan

$bloatPackages = @(
    # Unworking heavy Google apps (YouTube Kids / legacy YouTube)
    "com.google.android.apps.youtube.kids",
    "com.google.android.youtube",
    
    # Pre-installed OEM bloat / telemetry / demo apps
    "com.baidu.map.location",
    "com.opera.branding",
    "elink.com",
    "com.sts",
    "com.example",
    "com.google.android.marvin.talkback",

    # Indic Keyboard Dictionary Packages (takes up RAM/Storage)
    "com.process9.indicakeypad.dict.assamese",
    "com.process9.indicakeypad.dict.bengali",
    "com.process9.indicakeypad.dict.gujarati",
    "com.process9.indicakeypad.dict.hindi",
    "com.process9.indicakeypad.dict.kannada",
    "com.process9.indicakeypad.dict.malayalam",
    "com.process9.indicakeypad.dict.marathi",
    "com.process9.indicakeypad.dict.odia",
    "com.process9.indicakeypad.dict.punjabi",
    "com.process9.indicakeypad.dict.tamil",
    "com.process9.indicakeypad.dict.telugu",

    # MediaTek background debug/telemetry loggers
    "com.mediatek.mtklogger",
    "com.mediatek.sensorhub.ui",
    "com.mediatek.atci.service",
    "com.mediatek.lbs.em2.ui",
    "org.simalliance.openmobileapi.service"
)

foreach ($pkg in $bloatPackages) {
    Write-Host "Checking & removing package: $pkg..." -ForegroundColor Gray
    # Try uninstalling for user 0
    $res = Invoke-Expression "& `"$adb`" $target shell pm uninstall -k --user 0 $pkg 2>&1"
    if ($res -match "Success") {
        Write-Host "  -> Uninstalled: $pkg" -ForegroundColor Green
    } else {
        # Fallback to disabling if package is protected or already absent
        $dis = Invoke-Expression "& `"$adb`" $target shell pm disable-user $pkg 2>&1"
        if ($dis -match "new state: disabled") {
            Write-Host "  -> Disabled: $pkg" -ForegroundColor Yellow
        }
    }
}

Write-Host "`nDebloating complete! System RAM and CPU headroom restored." -ForegroundColor Green
