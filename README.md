# Android Tablet Speed-Up & Revival Guide

A complete, production-tested guide and automation toolkit to revive, debloat, and speed up low-RAM legacy Android tablets (Android 5.0 to 8.1, 1GB–2GB RAM, MediaTek/Allwinner/Rockchip chipsets).

Tested and verified on:
- **Device 1:** iBall Slide Dazzle i7 (`iBall_Slide_Dazzle_i7`)
  - **Chipset:** MediaTek MT8321M (Quad-core ARM Cortex-A7 @ 1.3GHz)
  - **RAM:** 1.0 GB | **Storage:** 8.0 GB eMMC | **OS:** Android 7.0 (Nougat, API 24)
- **Device 2:** iBall Slide Snap 4G2 (`Snap_4G2`)
  - **Chipset:** MediaTek MT6735M (Quad-core 64-bit ARM Cortex-A53 @ 1.0GHz)
  - **RAM:** 2.0 GB | **Storage:** 16.0 GB eMMC | **OS:** Android 7.0 (Nougat, API 24)

---

## 📊 Before & After Results

### Device 1: iBall Slide Dazzle i7 (1GB RAM / 8GB Storage)
| Metric | Before Optimization | After Optimization | Impact |
| :--- | :--- | :--- | :--- |
| **Free Storage (`/data`)** | 221 MB (5% free, **Storage Full Warning**) | **1.4 GB (38% free)** | **+1.2 GB reclaimed** |
| **CPU Idle State** | 0% idle (**100% pinned at all times**) | **>94% idle** | Completely eliminated lag & heating |
| **Google Play Services ANR** | Recurring crash popup every 30s | **0 crashes / completely eliminated** | Stable system watchdog |
| **YouTube Status** | Broken / unplayable / constant crash | **Working smoothly via YouTube Lite** | Supports Google Account Login |
| **Free RAM** | <95 MB (frequent app kills) | **~310 MB free** | Fast multitasking & responsiveness |
| **Battery Standby** | Drains overnight (~8-10h) | **Multi-day standby** | Radios and loggers disabled |

### Device 2: iBall Slide Snap 4G2 (2GB RAM / 16GB Storage)
| Metric | Before Optimization | After Optimization | Impact |
| :--- | :--- | :--- | :--- |
| **Free Storage (`/data`)** | 4.9 GB available (52% used) | **7.2 GB available (30% used)** | **+2.3 GB reclaimed** |
| **Background CPU Load** | 57% pegged (GMS, SearchBox, ToonMe) | **<10% idle baseline** | Background drains killed |
| **YouTube Status** | Broken legacy YouTube / YouTube Kids | **HD YouTube Lite with sign-in** | Smooth 720p/1080p playback |
| **Free RAM** | ~500 MB | **>1.03 GB free** | Clean background memory pool |
| **Battery & Radios** | Constant Wi-Fi/BT scan & GPS active | **Optimized (Doze mode active)** | Preserves battery life |

---

## 🚀 Quick Start (Automated)

You can run the full optimization pipeline automatically using the included PowerShell scripts:

### 1. Connect Device
Connect your tablet via ADB (USB or Wi-Fi), then run:
```powershell
.\scripts\connect_device.ps1
```
*This detects active devices, switches ADB to TCP port 5555, and connects over Wi-Fi so you can disconnect cables.*

### 2. Run One-Click Optimization
```powershell
.\scripts\one_click_speedup.ps1 -DeviceId "192.168.0.18:5555"
```
This executes all 5 optimization phases sequentially:
1. Fixes Google Play Services crash loops
2. Debloats OEM packages, telemetry, and background hogs
3. Purges hidden thumbnail databases and app caches
4. Applies battery-saving radio and display settings
5. Deploys lightweight YouTube with sign-in capabilities

---

## 🌐 Enabling ADB over Wi-Fi (When USB is an Issue)

By default in Android, ADB daemon (`adbd`) only listens on the physical USB port until the system property `service.adb.tcp.port = 5555` is set. If the tablet's USB port or cable has issues:

1. **Option A: The 1-Tap "WiFi ADB" App (Directly on Tablet)**
   - Open Google Play Store or Chrome on the tablet.
   - Install **"WiFi ADB - Debug Over Air"** or **"WiFi ADB"**.
   - Open the app and toggle **ON**. This sets `service.adb.tcp.port 5555` directly on the tablet without requiring a PC USB cable.
   - From your PC: `adb connect <TABLET_IP>:5555`.

2. **Option B: MediaTek Secret Code (No PC / No App)**
   - Open Phone / Dialer on the tablet.
   - Dial: `*#*#3646633#*#*` to open **EngineerMode**.
   - Navigate to **Log and Debugging** -> **User2Root** or **Debug Utils** -> enable Root / Network ADB.

3. **Option C: Android Phone via OTG (Bugjaeger)**
   - Connect another Android phone to the tablet with an OTG cable.
   - Open the free **Bugjaeger Mobile ADB** app and tap the **"Wi-Fi ADB"** button.

4. **Option D: One-time USB Bootstrap**
   - Connect USB cable once to PC with USB Debugging enabled.
   - Run `adb tcpip 5555`.
   - Connect over Wi-Fi: `adb connect <IP>:5555`.
   - Unplug the USB cable; ADB remains wireless until next tablet reboot!

---

## 🛠 Detailed Step-by-Step Guide

### Phase 1: Resolving "Google Play services has stopped" (ANR Loop)

#### Root Cause
On 1GB–2GB RAM Android devices, modern Google Play Services background tasks trigger continuous indexing and voice-model lookups via `com.google.android.googlequicksearchbox` (the Google App). This pegs CPU cores, starving Android's `system_server`. When Google Play Services' internal health watchdog times out, Android displays the fatal ANR: *"Unfortunately, Google Play services has stopped"*.

#### Solution
Disable the CPU-hogging search box service and clear corrupted caches:
```bash
adb shell pm disable-user com.google.android.googlequicksearchbox
adb shell pm clear com.google.android.googlequicksearchbox
adb shell pm disable-user com.google.android.feedback
adb shell pm disable-user com.google.android.marvin.talkback
```
*Result: Google Play Store continues to work normally for app downloads, but the background CPU spinlock is permanently terminated.*

---

### Phase 2: Surgical Debloating

Preinstalled carrier stubs, telemetry, and unworking bundled applications consume precious RAM and flash storage. These can be safely uninstalled for the primary user (`User 0`) without root access:

```bash
# 1. Unworking or outdated multimedia apps
adb shell pm uninstall -k --user 0 com.google.android.apps.youtube.kids
adb shell pm uninstall -k --user 0 com.google.android.youtube
adb shell pm uninstall -k --user 0 com.google.android.music
adb shell pm uninstall -k --user 0 com.google.android.videos
adb shell pm uninstall -k --user 0 com.google.android.apps.tachyon

# 2. Third-party telemetry, spyware & ad stubs
adb shell pm uninstall -k --user 0 com.baidu.map.location
adb shell pm uninstall -k --user 0 com.opera.mini.native
adb shell pm uninstall -k --user 0 com.opera.branding
adb shell pm uninstall -k --user 0 elink.com
adb shell pm uninstall -k --user 0 com.sts
adb shell pm uninstall -k --user 0 com.example
adb shell pm uninstall -k --user 0 com.vicman.toonmeapp

# 3. Indic keyboard dictionaries (if not using regional fonts)
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.assamese
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.bengali
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.gujarati
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.hindi
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.kannada
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.malayalam
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.marathi
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.odia
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.punjabi
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.tamil
adb shell pm uninstall -k --user 0 com.process9.indicakeypad.dict.telugu

# 4. MediaTek background diagnostic loggers
adb shell pm disable-user com.mediatek.mtklogger
adb shell pm disable-user com.mediatek.sensorhub.ui
adb shell pm disable-user com.mediatek.atci.service
adb shell pm disable-user com.mediatek.lbs.em2.ui
adb shell pm disable-user com.mediatek.thermalmanager
adb shell pm disable-user com.mediatek.ygps
adb shell pm disable-user org.simalliance.openmobileapi.service
```

---

### Phase 3: Reviving YouTube with Google Account Login

#### Why Official YouTube Fails
1. Modern YouTube APKs require Android 8.0+ and consume over 350 MB of RAM alone.
2. Legacy YouTube versions (v14/v15) display unskippable *"Switch to youtube.com"* or *"Error 400"* screens due to deprecated backend API endpoints.
3. YouTube Vanced is discontinued and its microG authentication often fails on Android 7.0 and older.

#### The Working Solution: YouTube Lite (WebApk / PWA Wrapper)
Using a lightweight WebApk wrapper (5.7 MB):
- **Full Google Sign-In:** Allows access to your subscriptions, history, playlists, and recommendations.
- **Minimal RAM Footprint:** Operates under 40 MB RAM using Android System WebView hardware acceleration.
- **Native Experience:** Full screen video, touch gestures, and home screen launcher icon without browser address bars.

Install via ADB:
```bash
adb install -r YouTube_WebApk.apk
adb shell monkey -p com.sajib.youtube -c android.intent.category.LAUNCHER 1
```

---

### Phase 4: Deep Storage Reclamation

On devices with 8GB–16GB storage, Android's hidden gallery thumbnails often expand unchecked to 1–2 GB.

```bash
# 1. Purge hidden thumbnail databases
adb shell rm -rf /sdcard/DCIM/.thumbnails/*
adb shell rm -rf /sdcard/.thumbnails/*

# 2. Clear app cache files
adb shell rm -rf /sdcard/Android/data/*/cache/*
adb shell rm -rf /data/local/tmp/*

# 3. Force system-wide cache trim
adb shell pm trim-caches 500M
```
*Note: This does not delete personal photos or videos; it only removes cached thumbnail previews that are regenerated on-demand in much smaller sizes.*

---

### Phase 5: Battery & Background Drain Reduction

Old tablets often have degraded lithium-ion batteries. Background hardware polling causes severe sleep drain:

1. **Disable Always-On Wi-Fi & Bluetooth Scanning:**
   ```bash
   adb shell settings put global wifi_scan_always_enabled 0
   adb shell settings put global ble_scan_always_enabled 0
   ```
2. **Disable Hardware GPS Polling:**
   ```bash
   adb shell settings put secure location_mode 0
   ```
3. **Optimize Display Timeout & Brightness:**
   ```bash
   adb shell settings put system screen_off_timeout 60000
   adb shell settings put system screen_brightness 130
   ```
4. **Enable Android Doze Mode:**
   ```bash
   adb shell dumpsys deviceidle enable
   ```

---

## 📁 Repository Structure

```
Android-Tablet-Speed-Up/
├── README.md                          # Comprehensive documentation & troubleshooting guide
├── .gitignore                         # Excludes large binaries, logs, and screenshots
├── YouTube_WebApk.apk                 # Lightweight YouTube client (5.7 MB, sign-in enabled)
└── scripts/
    ├── connect_device.ps1             # USB detection and Wi-Fi ADB connector
    ├── fix_google_services.ps1        # Solves Google Play Services ANR / freeze loops
    ├── debloat.ps1                    # Uninstalls OEM bloatware & telemetry
    ├── clean_storage.ps1              # Purges cache and recovers 1GB+ storage
    ├── optimize_battery.ps1           # Battery life and background radio optimizer
    ├── install_youtube_lite.ps1       # YouTube Lite deployer
    ├── collect_diagnostics.ps1        # System stats and hardware collector
    ├── deep_clean_tablet2.ps1         # Purges non-mandatory apps and user storage
    └── one_click_speedup.ps1          # Master automated optimization pipeline
```

---

## 📜 License
MIT License. Free to use, modify, and distribute for reviving legacy Android hardware.
