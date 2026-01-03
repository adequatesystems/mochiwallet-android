# Mochimo Wallet - Android

[![Build Android APK](https://github.com/adequatesystems/mochiwallet-android/actions/workflows/build.yml/badge.svg)](https://github.com/adequatesystems/mochiwallet-android/actions/workflows/build.yml)

Android mobile app for the Mochimo cryptocurrency wallet, built as a WebView wrapper around the [mochiwallet](https://github.com/adequatesystems/mochiwallet) Chromium extension.

**Current Release:** v0.0.18  
**Target SDK:** Android 15 (API 35)  
**Minimum SDK:** Android 7.0 (API 24)

**This is a clean, separate repository** that pulls the upstream extension as a git submodule and contains only Android-specific code.

---

## 🚀 Quick Start

```powershell
# Clone this repository
git clone https://github.com/adequatesystems/mochiwallet-android.git
cd mochiwallet-android

# Initialize the upstream extension submodule (build scripts will auto-init/clone if missing)
git submodule init
git submodule update

# Build the Android APK (Windows)
.\build.ps1

# Build the Android APK (Linux/macOS)
./build.sh
```

**Build Complete** The APK will be at: `android/app/build/outputs/apk/debug/app-debug.apk`

---

## 📋 Prerequisites

Before building, install these:

| Component | Version | Download / Install |
|-----------|---------|-------------------|
| **Java 17** | Eclipse Adoptium OpenJDK | [Download](https://adoptium.net/temurin/releases/?version=17) |
| **Android SDK** | API 35 | `C:\Android\cmdline-tools\latest\bin\sdkmanager.bat "platform-tools" "platforms;android-35" "build-tools;35.0.0"` |
| **Node.js** | v16+ | [Download](https://nodejs.org/) |
| **pnpm** | v8.x | `npm install -g pnpm@8` or `corepack enable` (Node.js 16.13+) |
| **Git** | Latest | [Download](https://git-scm.com/) |

> **Note:** Verify `pnpm` is in your PATH by running `pnpm --version`. If not found, ensure your Node.js/npm global bin directory is in PATH.

### Initial Configuration

**1. Set JAVA_HOME environment variable (recommended):**
```powershell
# PowerShell - set for current user permanently
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot", "User")

# Or set temporarily for current session
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot"
```
> **Note:** The build script will auto-detect Java 17 in common locations if `JAVA_HOME` is not set. Replace the path with your actual JDK installation directory if setting manually.

**2. Set Android SDK Path:**

Create `android/local.properties`:
```properties
sdk.dir=C:\\Android
```
*(Or let the build script auto-create it)*

---

## 🏗️ Architecture

This repository uses a clean separation between extension code and Android wrapper:

```
mochiwallet-android/            # This repo (Android-specific only)
│
├── .github/                     # GitHub Actions CI/CD workflows
│   └── workflows/build.yml      # Automated APK build
│
├── mochiwallet/                 # Git submodule → upstream extension
│   ├── src/                     # Extension source code
│   └── dist/                    # Built by pnpm, copied to Android
│
├── android/                     # Android project
│   ├── app/src/main/
│   │   ├── assets/              # Web app deployed here (build time)
│   │   └── java/.../MainActivity.kt  # WebView configuration
│   └── gradle files
│
├── patches/                     # Android-specific patches
│   ├── polyfills.js             # Chrome API compatibility (CRITICAL)
│   └── vite.config.patch        # Documents the relative path patch
│
├── docs/                        # Documentation
│   └── TECHNICAL_DOCUMENTATION.md  # Complete technical guide
│
└── build.ps1                    # Automated build script
```

### What's in This Repo vs Submodule

**This repo contains:**
✅ Android project (`android/`)  
✅ Android-specific patches (`patches/`)  
✅ Build automation (`build.ps1`)  
✅ Documentation (`docs/`)

**Submodule contains:**
📦 Extension source code  
📦 Wallet logic and UI  
📦 Built via `pnpm run build`

---

## 🔧 How It Works

### Build Process (Automated)

```
build.ps1 executes 7 steps:

1. Verify mochiwallet/ submodule exists (auto-init if needed)
2. Build web extension (pnpm install + build, with git dependency workaround)
3. Apply Android patches (vite config base: './')
4. Copy dist/ to android/app/src/main/assets/
5. Copy patches/polyfills.js to assets/
6. Fix index.html (fix asset paths, remove require('buffer'), add polyfills)
7. Build Android APK with Gradle (auto-detects Java 17)

Result: android/app/build/outputs/apk/debug/app-debug.apk
```

### Key Android Modifications

The following changes make the Chrome extension work in Android WebView:

**1. Chrome API Polyfills** (`patches/polyfills.js` - 416 lines)
- `Buffer.from()` with **hex encoding** (CRITICAL for Mochimo address generation)
- `Buffer.from()` with **base64 encoding** (for wallet encryption)
- `chrome.runtime.*` polyfills (session management)
- `chrome.storage.*` polyfills (localStorage wrapper)
- `chrome.tabs.*` polyfills (mock implementation)

**2. Vite Configuration Patch**
```javascript
base: './'  // Changed from '/' for relative paths in Android WebView
```

**3. WebView Settings** (`android/.../MainActivity.kt`)
```kotlin
allowFileAccessFromFileURLs = true       // Enable file:// URL loading
allowUniversalAccessFromFileURLs = true  // Enable cross-origin requests
```

---

## 📖 Documentation

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)** | Complete technical guide | First-time setup, troubleshooting, integration workflow |

---

## 🎨 Mobile UI Patches

The build scripts automatically apply patches to adapt the browser extension UI for mobile devices. These patches remove UI elements that rely on browser APIs not available in Android WebView:

| Patch | What It Does |
|-------|--------------|
| `android-ui.css` | Optimizes layout for mobile screens |
| `mobile-ui-panel-button.js` | Removes panel toggle button (browser panel API not available on mobile) |
| `mobile-ui-mcm-import.js` | Removes "Import MCM File" option (file picker API not available on mobile) |
| `mobile-ui-export.js` | Removes Backup section (file download API not available on mobile) |
| `legal-links.js` | Adds Terms of Service and Privacy Policy links at bottom of screen |

These patches are optional but recommended. See [docs/UI_PATCHES.md](docs/UI_PATCHES.md) for details and opt-out instructions.

---

## 🔄 Development Workflows

### Building the APK

```powershell
# Windows (PowerShell)
.\build.ps1                    # Full build
.\build.ps1 -SkipExtensionBuild # Skip extension build (if only Android changed)

# Linux/macOS (Bash)
./build.sh                     # Full build
./build.sh -s                  # Skip extension build
./build.sh -h                  # Show help
```

### Updating from Upstream

When the extension has new features or fixes:

```powershell
# Update submodule to latest upstream
cd mochiwallet
git pull origin main
cd ..

# Rebuild with new changes
.\build.ps1

# Commit the submodule update
git add mochiwallet
git commit -m "Update to latest upstream extension"
```

### Making Changes

**To modify extension code:**
1. Make changes in the upstream mochimo-wallet repo
2. Push to upstream
3. Pull updates here and rebuild

**To modify Android wrapper:**
- Edit `android/` - Android project files
- Edit `patches/polyfills.js` - Chrome API compatibility
- Edit `build.ps1` - Build process
- Then run `.\build.ps1`

---

## 🧪 Testing

### Testing Checklist

After building and installing the APK on your device/emulator, verify these features work:

- [ ] App launches (not blank screen)
- [ ] Welcome screen displays correctly
- [ ] Create new wallet with password
- [ ] View and backup mnemonic phrase
- [ ] Complete wallet creation
- [ ] Create account (no "Invalid tag" error)
- [ ] Unlock wallet with password
- [ ] View account address and tag
- [ ] Check balance (API call succeeds)
- [ ] Settings dialog opens

---

## 🛠️ Troubleshooting

| Problem | Likely Cause | Solution |
|---------|-------------|----------|
| "Submodule not found" | Submodule not initialized | `git submodule init && git submodule update` |
| Blank white screen | Polyfills not loaded or asset paths wrong | Run `.\build.ps1` to ensure polyfills and path fixes applied |
| "Invalid tag" error | Missing hex encoding | Restore `patches/polyfills.js` from repo |
| Gradle build fails | Wrong Java version | Install Java 17; build script auto-detects common locations |
| SDK location not found | Missing local.properties | Create `android/local.properties` with `sdk.dir=C:\\Android` |
| Assets not loading | Wrong vite base path | Verify patch applied: `base: './'` in vite.config |
| pnpm install fails | Git dependencies issue | Build script handles this automatically; see technical docs |
| PowerShell execution policy | Scripts disabled | `powershell -ExecutionPolicy Bypass -File .\build.ps1` |

**For detailed troubleshooting:** See [docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)

---

## 🎯 Why This Architecture?

### Advantages

✅ **Clean Separation** - Android code separate from extension code  
✅ **Easy Updates** - Pull upstream changes with `git pull` in submodule  
✅ **Single Source of Truth** - Patches in `patches/` directory  
✅ **Minimal Repo** - Only ~30 files, ~2 MB (vs 50+ MB mixed repo)  
✅ **Clear Documentation** - All Android changes documented  
✅ **Repeatable Builds** - Single command: `.\build.ps1`

### What This Repo DOESN'T Include

❌ Extension source code (in submodule)  
❌ node_modules (installed in submodule)  
❌ Build outputs (dist/, APKs)  
❌ Temporary files (.gradle, build/)

---

## � Security Considerations

This is a **cryptocurrency wallet** handling sensitive data. Here's what you should know:

### WebView Permissions

The app enables these WebView settings that are normally restricted:

| Setting | Why Required | Risk Mitigation |
|---------|--------------|-----------------|
| `allowFileAccessFromFileURLs` | Load local assets from `file:///android_asset/` | Only loads bundled files, no external content |
| `allowUniversalAccessFromFileURLs` | Cross-origin requests for local files | App is sandboxed, no network file access |
| `javaScriptEnabled` | Wallet UI is JavaScript-based | Only executes bundled, reviewed code |

### Data Storage

- **Wallet data**: Stored in app-private localStorage (via polyfills)
- **Location**: `/data/data/com.mochimo.mochiwallet/` (Android app sandbox)
- **Encryption**: Wallet is encrypted with user password (handled by extension code)
- **Backup disabled**: `android:allowBackup="false"` prevents cloud backup of wallet data

### Network Security

- **Cleartext traffic disabled**: `android:usesCleartextTraffic="false"`
- **SSL errors rejected**: Invalid certificates are always rejected (no bypass)
- **No external scripts**: All JavaScript is bundled at build time

### Best Practices for Users

1. **Use a strong password** for wallet encryption
2. **Back up your mnemonic phrase** securely (offline, not in cloud)
3. **Don't install from untrusted sources** - only use official releases
4. **Keep your device secure** - use device encryption and screen lock

---

## �📦 What Gets Committed

**Commit to this repo:**
- ✅ `android/` (excluding build outputs)
- ✅ `patches/`
- ✅ `docs/`
- ✅ `build.ps1`
- ✅ Configuration files

**Don't commit:**
- ❌ `mochiwallet/` (it's a submodule)
- ❌ `android/build/`, `android/.gradle/`
- ❌ `android/local.properties` (environment-specific)
- ❌ `android/app/src/main/assets/*` (generated during build)

---

## 🤝 Contributing

1. Fork this repository
2. Make changes to Android-specific code
3. Test thoroughly (see Testing Checklist)
4. Submit pull request

For extension changes, contribute to the upstream [mochiwallet](https://github.com/adequatesystems/mochiwallet) repository.

---

## 📜 License

Same as upstream mochimo-wallet project.

---

## 🔗 Links

- **Upstream Extension:** https://github.com/adequatesystems/mochiwallet
- **Mochimo Network:** https://mochimo.org
- **Privacy Policy:** https://mochimo.org/mobile-wallet-privacy
- **Documentation:** [docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)

---

## ❓ Getting Help

- **Technical documentation:** [docs/TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)
- **Build issues:** See Troubleshooting section in technical documentation
- **Integration questions:** See "Updating from Upstream" in technical documentation


