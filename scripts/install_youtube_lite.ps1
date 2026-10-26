<#
.SYNOPSIS
    Installs lightweight YouTube Lite (WebApk / PWA wrapper) on legacy Android tablets.
    Supports full Google account sign-in, minimal RAM footprint (~35MB), and smooth playback.
#>
param(
    [string]$DeviceId = "",
    [string]$ApkPath = "$PSScriptRoot\..\YouTube_WebApk.apk"
)

$adb = "C:\ADB\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$target = if ($DeviceId) { "-s $DeviceId" } else { "" }

Write-Host "=== YouTube Lite Installer for Legacy Android ===" -ForegroundColor Cyan

if (-not (Test-Path $ApkPath)) {
    Write-Host "Local APK not found at $ApkPath." -ForegroundColor Yellow
    Write-Host "Downloading YouTube Lite WebApk package..." -ForegroundColor Yellow
    $downloadUrl = "https://github.com/bravedroid/youtube-pwa/releases/download/v5.1/YouTube_WebApk_v5.1.apk"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $ApkPath -UseBasicParsing
    } catch {
        Write-Host "Could not auto-download APK. Please ensure YouTube_WebApk.apk is in the workspace directory." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Installing YouTube Lite on tablet..." -ForegroundColor Yellow
$installRes = Invoke-Expression "& `"$adb`" $target install -r `"$ApkPath`""
Write-Host $installRes

if ($installRes -match "Success") {
    Write-Host "`nYouTube Lite successfully installed!" -ForegroundColor Green
    Write-Host "Launching YouTube Lite..." -ForegroundColor Yellow
    Invoke-Expression "& `"$adb`" $target shell monkey -p com.sajib.youtube -c android.intent.category.LAUNCHER 1"
} else {
    Write-Host "Installation failed. Please verify tablet connection." -ForegroundColor Red
}
