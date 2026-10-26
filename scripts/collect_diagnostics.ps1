param (
    [string]$adb = "C:\ADB\adb.exe"
)

$outDir = "d:\PY\AndroidDebug\diagnostics"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Auto-detect device
$devicesRaw = & $adb devices -l
Write-Host "ADB Devices output:"
Write-Host $devicesRaw

# Extract device ID
$deviceId = $null
foreach ($line in ($devicesRaw -split "`r?`n")) {
    if ($line -match "^([^\s]+)\s+device\b") {
        $deviceId = $matches[1]
        break
    }
}

if (-not $deviceId) {
    Write-Error "No authorized ADB device found!"
    exit 1
}

Write-Host "Target Device: $deviceId"

function Run-AdbCommand {
    param(
        [string]$Name,
        [string]$Command
    )
    Write-Host "Collecting $Name..."
    $outFile = Join-Path $outDir "$Name.txt"
    $res = & $adb -s $deviceId shell $Command
    $res | Out-File -FilePath $outFile -Encoding utf8
    return $res
}

# Properties
Run-AdbCommand "getprop_all" "getprop" | Out-Null
Run-AdbCommand "cpuinfo_proc" "cat /proc/cpuinfo" | Out-Null
Run-AdbCommand "meminfo_proc" "cat /proc/meminfo" | Out-Null
Run-AdbCommand "df" "df -h" | Out-Null
Run-AdbCommand "dumpsys_battery" "dumpsys battery" | Out-Null
Run-AdbCommand "dumpsys_cpuinfo" "dumpsys cpuinfo" | Out-Null
Run-AdbCommand "top" "top -n 1" | Out-Null
Run-AdbCommand "dumpsys_meminfo" "dumpsys meminfo" | Out-Null
Run-AdbCommand "dumpsys_diskstats" "dumpsys diskstats" | Out-Null
Run-AdbCommand "packages_all" "pm list packages" | Out-Null
Run-AdbCommand "packages_third_party" "pm list packages -3" | Out-Null
Run-AdbCommand "packages_disabled" "pm list packages -d" | Out-Null
Run-AdbCommand "package_youtube" "dumpsys package com.google.android.youtube" | Out-Null
Run-AdbCommand "package_gms" "dumpsys package com.google.android.gms" | Out-Null
Run-AdbCommand "package_vending" "dumpsys package com.android.vending" | Out-Null
Run-AdbCommand "dumpsys_activity_top" "dumpsys activity top" | Out-Null
Run-AdbCommand "uptime" "uptime" | Out-Null
Run-AdbCommand "date" "date" | Out-Null

Write-Host "Data collection complete! All files saved to $outDir"
