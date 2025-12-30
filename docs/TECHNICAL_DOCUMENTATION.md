# Technical Documentation
## mochiwallet-android Maintainer Guide

**Audience**: Repository maintainer  
**Purpose**: Understand the architecture, critical components, and maintenance workflows for the Android wrapper

---

## 1. Architecture Overview

### What This Repository Does

This repository wraps the Mochimo wallet Chrome extension as an Android application. It does **not** contain the wallet logic itselfthat lives in the upstream `adequate-systems/mochiwallet` repository.

**Core Strategy**:
- Use git submodule to track the upstream extension
- Apply minimal Android-specific patches
- Bundle extension in Android WebView
- Automate the entire build process

### Repository Structure

```
mochiwallet-android/              # This repo (Android wrapper only)
 mochiwallet/                  # Git submodule  adequate-systems/mochiwallet
 android/                      # Standard Android project (Gradle, Kotlin)
    app/src/main/
       assets/               # Built extension copied here at build time
       java/.../MainActivity.kt   # WebView configuration
    gradle.properties         # Java home configuration
    local.properties          # Android SDK location
 patches/
    polyfills.js              # Chrome API polyfills + Buffer for WebView (CRITICAL)
    android-ui.css            # Full-width layout for mobile screens
    hide-sidebar-button.js    # Hides panel toggle button in header
    hide-mcm-import.js        # Hides "Import MCM File" option
    hide-export-wallet.js     # Hides Backup/Export section in Settings
    vite.config.patch         # Documents the relative path patch (informational)
 build.ps1                     # Automated build orchestration (Windows)
 build.sh                      # Automated build orchestration (Linux/macOS)
 .gitmodules                   # Submodule configuration
 docs/
     TECHNICAL_DOCUMENTATION.md    # This file
     UI_PATCHES.md                 # UI patch documentation
```

### Why This Architecture?

1. **Separation of Concerns**: Wallet development happens upstream; Android wrapper is minimal
2. **Maintainability**: Updates from upstream are a simple `git pull` in the submodule
3. **Single Source of Truth**: Extension code isn't duplicated or forked
4. **Automation**: One script handles the entire build pipeline

---

## 2. Critical Components

### 2.1 Git Submodule (`mochiwallet/`)

**File**: `.gitmodules`

```ini
[submodule "mochiwallet"]
    path = mochiwallet
    url = https://github.com/adequate-systems/mochiwallet.git
    branch = main
```

**Key Points**:
- The Android repo tracks a specific commit of the extension
- Updates are manual and intentional (you control when to pull changes)
- After updating submodule, must commit the new pointer

**Common Operations**:
```powershell
# Initial clone setup
git submodule init && git submodule update

# Update to latest upstream
cd mochiwallet && git pull origin main && cd ..

# Check current version
cd mochiwallet && git log -1 --oneline && cd ..
```

### 2.2 Build Scripts (`build.ps1` / `build.sh`)

**Purpose**: Orchestrates the entire build pipeline (cross-platform)

- `build.ps1` - Windows (PowerShell)
- `build.sh` - Linux/macOS/WSL (Bash)

**Seven Steps**:
1.  Verify `mochiwallet/` submodule exists (auto-init/clone if missing)
2.  Build extension: `cd mochiwallet && pnpm install && pnpm run build`
3.  Patch `vite.config.ts` to set `base: './'` (required for WebView)
4.  Copy `mochiwallet/dist/`  `android/app/src/main/assets/`
5.  Inject `patches/polyfills.js` into assets
6.  Fix `index.html`: remove `require('buffer')`, add polyfills script tag
7.  Build Android APK: `cd android && ./gradlew assembleDebug`

**Critical Patches Applied**:

| Patch | File Modified | Why Needed |
|-------|--------------|------------|
| `base: './'` | `mochiwallet/vite.config.ts` | WebView needs relative paths, not absolute (`/assets/`) |
| Fix asset paths | `android/app/src/main/assets/index.html` | Convert `/assets/` to `./assets/` for WebView compatibility |
| Add polyfills | `android/app/src/main/assets/index.html` | Chrome APIs don't exist in WebView |
| Remove `require('buffer')` | `android/app/src/main/assets/index.html` | Node.js require() doesn't work in WebView |

**Build Options**:
```powershell
# Windows (PowerShell)
.\build.ps1                        # Full build
.\build.ps1 -SkipExtensionBuild    # Use existing mochiwallet/dist/

# Linux/macOS (Bash)
./build.sh                         # Full build
./build.sh -s                      # Use existing mochiwallet/dist/
./build.sh -h                      # Show help
```

### 2.3 Polyfills (`patches/polyfills.js`)

**Purpose**: Bridge the gap between Chrome extension APIs and Android WebView

**Critical Features**:

1. **Buffer Polyfill with HEX Encoding**
   ```javascript
   Buffer.from("420000000e00000001000000", "hex")
   ```
   - Used by Mochimo WOTS+ address generation
   - Converts 24-character hex string  12-byte array
   - **WITHOUT THIS**: "Invalid tag" error during account creation

2. **Chrome API Stubs**
   - `chrome.runtime.sendMessage()`
   - `chrome.storage.local.get/set()`
   - `chrome.tabs.create()`
   - Extension expects these APIs; WebView doesn't provide them
   - Polyfills provide compatible localStorage-based implementations

**Debug Mode**:
The polyfills file includes a `POLYFILL_DEBUG` flag at the top:
```javascript
const POLYFILL_DEBUG = false; // Set to true for verbose logging
```
Set to `true` when troubleshooting Chrome API compatibility issues.

**Never Delete This File**: The wallet will not function without it.

### 2.4 Android WebView Configuration (`android/app/src/main/java/com/mochimo/wallet/MainActivity.kt`)

**Critical Settings**:

```kotlin
webView.settings.apply {
    javaScriptEnabled = true
    domStorageEnabled = true
    allowFileAccessFromFileURLs = true      // REQUIRED
    allowUniversalAccessFromFileURLs = true // REQUIRED
}
```

**Why These Are Critical**:
- Chrome extensions have special privileges
- Android WebView is sandboxed by default
- `allowFileAccessFromFileURLs` enables loading local assets
- Without these: CORS errors, blank screen

**Error Handling**:
The `WalletWebViewClient` includes error handlers for robust operation:
- `onReceivedError()` - Displays user-friendly error page for loading failures
- `onReceivedHttpError()` - Logs HTTP errors for debugging
- `onReceivedSslError()` - **Always cancels** invalid SSL certificates (security)

### 2.5 Environment Configuration

**`JAVA_HOME` environment variable** (required):
```bash
# Windows (PowerShell)
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot", "User")

# Linux/macOS
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk  # or your JDK path
```
Specifies which JDK to use. **Java 17 is required** (LTS until 2029, compatible with AGP 8.2.0).

**`android/local.properties`** (auto-created by build script):
```properties
sdk.dir=C:\\Android
```
Tells Gradle where the Android SDK is installed. The build script auto-detects common SDK locations.

---

## 3. Maintenance Workflows

### 3.1 Updating from Upstream

**Standard Workflow**:

```powershell
# 1. Update submodule
cd mochiwallet
git pull origin main
cd ..

# 2. Rebuild
.\build.ps1

# 3. Test thoroughly
# - Install APK on device/emulator
# - Create wallet, add account, check balance, send transaction

# 4. Commit the update
git add mochiwallet
git commit -m "Update to mochiwallet v1.x.x"
git push
```

**Version Pinning** (for stable releases):

```powershell
cd mochiwallet
git checkout v1.2.3  # Use specific tag
cd ..
.\build.ps1
git add mochiwallet
git commit -m "Pin to mochiwallet v1.2.3"
git push
```

**What to Watch For After Updates**:
1.  Build script patches still apply cleanly
2.  No new `require()` statements in extension code
3.  No new Chrome APIs used that need polyfilling
4.  Account creation still works (hex Buffer encoding test)
5.  All core wallet functions operational

### 3.2 Troubleshooting Build Issues

| Problem | Diagnosis | Solution |
|---------|----------|----------|
| "Submodule not found" | Fresh clone without init | `git submodule init && git submodule update` |
| Blank white screen | Assets not loading | Check `base: './'` patch applied; verify assets copied |
| "Invalid tag" error | Polyfills missing or broken | Verify `patches/polyfills.js` in assets; check hex encoding |
| Gradle build fails | Wrong Java version | Verify `JAVA_HOME` environment variable points to Java 17 |
| pnpm install fails | Network or cache issue | `cd mochiwallet && pnpm store prune && pnpm install` |
| PowerShell execution policy | Scripts disabled on system | `powershell -ExecutionPolicy Bypass -File .\build.ps1` |
| Extension TypeScript errors | Upstream repo has type errors | Use `.\build.ps1 -SkipExtensionBuild` with existing dist/ |
| Git dependency build fails | Upstream missing `onlyBuiltDependencies` | Build script handles this automatically (see section 3.2.1) |
| local.properties SDK path error | CRLF in path | Ensure no trailing whitespace in `sdk.dir` value |
| Patches fail to apply | Upstream changed file structure | Manually inspect `mochiwallet/vite.config.ts`, update build.ps1 |

### 3.2.1 Git Dependency Build Workaround

**Problem**: The upstream `mochiwallet` extension depends on git-hosted packages (`mochimo-wallet`, `mochimo-mesh-api-client`, `mochimo-wots`) that may fail to build during `pnpm install`. This happens because:

1. **pnpm 10.x blocks git dependencies** - Requires explicit `onlyBuiltDependencies` allowlist
2. **Upstream packages missing `onlyBuiltDependencies`** - The `mochimo-wallet` git package itself has nested git dependencies that lack this configuration
3. **TypeScript errors in upstream** - Type incompatibilities with `@types/node` v20+ cause `tsc` compilation to fail

**Root Cause**: The `mochimo-wallet` package's `pnpm-workspace.yaml` only contains:
```yaml
packages:
  - 'examples/*'
```

It's missing the `onlyBuiltDependencies` section needed for pnpm 10.x to allow building its own git dependencies (`mochimo-mesh-api-client`, `mochimo-wots`).

**Automatic Workaround**: The build scripts (`build.ps1` / `build.sh`) now handle this automatically:

1. Create a `pnpm-workspace.yaml` in the extension directory with proper `onlyBuiltDependencies`
2. Attempt normal `pnpm@8 install`
3. If `node_modules/mochimo-wallet/dist/` is missing, trigger manual build:
   - Re-install with `--ignore-scripts` to skip failed builds
   - Clone `mochimo-wallet` separately with correct `onlyBuiltDependencies` config
   - Run `npx vite build` (TypeScript errors shown but esbuild produces valid output)
   - Clone `mochimo-mesh-api-client` separately
   - Run `npx tsup src/index.ts --format cjs,esm --dts`
   - Copy pre-built `dist/` folders to the extension's `node_modules/`

**Why This Works**: While `tsc` (TypeScript compiler) fails on type errors, Vite uses esbuild internally which ignores type errors and produces valid JavaScript output.

**Manual Recovery**: If automated build fails:
```powershell
# 1. Clone and build mochimo-wallet separately
git clone --depth 1 --branch v1.1.54 https://github.com/adequate-systems/mochimo-wallet.git temp-mw
cd temp-mw

# Add missing config to pnpm-workspace.yaml
@"
packages:
  - 'examples/*'
onlyBuiltDependencies:
  - mochimo-mesh-api-client
  - mochimo-wots
"@ | Set-Content pnpm-workspace.yaml

npx pnpm@8 install
npx vite build  # Shows TS errors but produces dist/

# 2. Copy to extension node_modules
Copy-Item -Recurse dist ..\mochiwallet\node_modules\mochimo-wallet\
cd ..
Remove-Item -Recurse temp-mw

# 3. Continue with extension build
cd mochiwallet
npx pnpm@8 run build
```

**Upstream Fix**: This workaround will become unnecessary if/when the upstream `adequate-systems/mochimo-wallet` repository adds the `onlyBuiltDependencies` configuration to their `pnpm-workspace.yaml`.

**Debug Commands**:
```powershell
# Check submodule state
git submodule status

# View submodule history
git log --oneline -- mochiwallet

# Force clean rebuild
Remove-Item android/app/src/main/assets/* -Recurse -Force
.\build.ps1

# Check APK contents
C:\Android\build-tools\34.0.0\aapt.exe list android/app/build/outputs/apk/debug/app-debug.apk

# View device logs
C:\Android\platform-tools\adb.exe logcat -s chromium:I
```

### 3.3 Testing New Releases

**Checklist After Upstream Update**:

- [ ] Build completes without errors
- [ ] APK installs on device/emulator
- [ ] App launches (not blank screen)
- [ ] Welcome screen displays correctly
- [ ] "Create Wallet" flow works
- [ ] Account creation succeeds (no "Invalid tag")
- [ ] Mnemonic backup displayed and confirmed
- [ ] Wallet unlocks with correct password
- [ ] Balance check succeeds
- [ ] Send transaction works
- [ ] Transaction history displays
- [ ] Import wallet (JSON) works
- [ ] Import wallet (mnemonic) works

### 3.4 When Upstream Changes Break Things

**Common Scenarios**:

1. **New `require()` statements in extension**
   - Symptom: JavaScript errors in WebView
   - Fix: Update build.ps1 to strip additional require() calls
   
2. **New Chrome APIs used**
   - Symptom: `chrome.someNewApi is not defined`
   - Fix: Add stub to `patches/polyfills.js`
   
3. **Vite config structure changed**
   - Symptom: Patch fails to apply
   - Fix: Update build.ps1 patching logic to match new structure
   
4. **Build output directory changed**
   - Symptom: Assets not copied, blank screen
   - Fix: Update `$distDir` variable in build.ps1

**If Polyfills Need Updating**:
```javascript
// Add to patches/polyfills.js
window.chrome.newApi = {
    someMethod: function(args) {
        console.warn('chrome.newApi.someMethod called (polyfill)');
        // Provide compatible implementation or no-op
    }
};
```

---

## 4. Technical Deep Dive

### 4.1 Why Each Patch Exists

**Patch: `base: './'` in vite.config**

Chrome extensions use absolute paths:
```html
<script src="/assets/index-abc123.js"></script>
```

Android WebView with `file:///android_asset/` needs relative:
```html
<script src="./assets/index-abc123.js"></script>
```

Without this: All asset loads fail with 404.

**Patch: Remove `require('buffer')`**

Extension code may include:
```javascript
const Buffer = require('buffer').Buffer;
```

This is Node.js/CommonJS syntax. Browser/WebView doesn't have `require()`. The polyfills.js provides `Buffer` globally instead.

**Patch: Inject polyfills.js**

Must load before any wallet code executes. Build script adds:
```html
<script src="./polyfills.js"></script>
```
before the extension's main bundle.

### 4.2 The Buffer Hex Encoding Saga

**Why This Is Critical**:

Mochimo WOTS+ addresses use 12-byte tags. The wallet generates these via:
```javascript
Buffer.from("420000000e00000001000000", "hex")
```

Without hex encoding support:
- Tag validation fails
- Account creation throws "Invalid tag"
- Wallet is unusable

**Polyfill Implementation**:
```javascript
const hexTable = '0123456789abcdef';
// ...conversion logic for hex strings
```

This was a major compatibility hurdle. Standard browser `Buffer` implementations often lack hex encoding. The polyfill must include it.

### 4.3 Chrome API Compatibility

**What the Extension Uses**:
- `chrome.storage.local` - Persisting wallet data
- `chrome.runtime.sendMessage` - Internal messaging
- `chrome.tabs.create` - Opening external links

**Polyfill Strategy**:
- Map `chrome.storage.local`  `localStorage`
- `chrome.runtime.sendMessage`  console log (no-op for single-page app)
- `chrome.tabs.create`  `window.open()`

These work because the extension is essentially a single-page app in Android context.

### 4.4 Build Automation Philosophy

**Why PowerShell Script**:
- Cross-platform (PowerShell Core on Linux/Mac)
- Direct filesystem manipulation
- Easy to understand and modify
- No additional build tool dependencies

**Idempotency**:
The script can be run multiple times safely. It:
- Overwrites assets directory (clean slate each build)
- Applies patches fresh each time
- Doesn't leave partial builds

**Fail-Fast**:
If any step fails, script exits immediately. No partial/corrupt builds.

---

## 5. Dependency Management

### 5.1 Upstream Extension

**Repository**: `https://github.com/adequate-systems/mochiwallet`  
**Update Frequency**: As needed  
**Versioning**: The extension may use tags (v1.0.0, v1.1.0, etc.)

**Best Practice**: Pin to tagged releases when available for stability.

### 5.2 Build Tools

| Tool | Version | Notes |
|------|---------|-------|
| Java | 17 (LTS) | Eclipse Adoptium recommended |
| Gradle | 8.4 | Managed by wrapper (`./gradlew`) |
| Android Gradle Plugin | 8.2.0 | In `android/build.gradle` |
| Android SDK | API 34 | Build tools 34.0.0 |
| Node.js | Latest LTS | For building extension |
| pnpm | v8+ | Required for extension dependencies |

**Do Not Upgrade**:
- Java: 17 is LTS until 2029, stay on it
- Gradle: 8.4 is stable with AGP 8.2.0, no need to change

**Safe to Upgrade**:
- Node.js: Keep on LTS track
- Android SDK build-tools: Minor updates usually safe

### 5.3 Android Dependencies

Defined in `android/app/build.gradle`:
```gradle
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.webkit:webkit:1.8.0'
    // etc.
}
```

**Update Strategy**: Minor version bumps usually safe, test thoroughly after major version changes.

---

## 6. Future Considerations

### 6.1 Potential Upstream Changes

**If Extension Adds**:
- New Chrome APIs  Add polyfill stubs
- Build tool changes  Update build.ps1
- New dependencies  Verify WebView compatibility
- pnpm workspace config  Required for git dependencies

### 6.2 Android Platform Changes

**Android 15+ (API 35+)**:
- WebView security policies may tighten
- May need to update `allowFileAccess` settings
- Test thoroughly on new Android versions

**Gradle 9.x**:
- May require JDK updates
- Review deprecated APIs in build scripts

### 6.3 Scalability

**If Adding Features**:
- Keep Android-specific code minimal
- Propose upstream changes to extension when possible
- Document any new patches in this file
- Update build.ps1 with clear comments

### 6.4 CI/CD Opportunities

Future automation could include:
- Daily checks for upstream updates
- Automated test builds
- APK signing for production releases
- Play Store deployment pipeline

---

## 7. Quick Reference

### Build Commands

```powershell
# Full build
.\build.ps1

# Build with existing extension build
.\build.ps1 -SkipExtensionBuild

# Build and install
.\build.ps1 -Install

# Build for specific device
.\build.ps1 -Install -Device SERIAL_NUMBER
```

### Git Submodule

```powershell
# Check status
git submodule status

# Update to latest
cd mochiwallet && git pull && cd .. && .\build.ps1

# View current commit
cd mochiwallet && git log -1 --oneline && cd ..

# View update history
git log --oneline -- mochiwallet
```

### Android Commands

```powershell
# Install APK
C:\Android\platform-tools\adb.exe install -r android/app/build/outputs/apk/debug/app-debug.apk

# View logs
C:\Android\platform-tools\adb.exe logcat -s chromium:I

# List connected devices
C:\Android\platform-tools\adb.exe devices
```

### Troubleshooting

```powershell
# Clean rebuild
Remove-Item android/app/src/main/assets/* -Recurse -Force
.\build.ps1

# Reset submodule
git submodule deinit -f mochiwallet
git submodule update --init

# Clear pnpm cache (if extension build fails)
cd mochiwallet
pnpm store prune
pnpm install
cd ..
```

---

## 8. Critical Files Reference

| File | Purpose | Never Delete |
|------|---------|--------------|
| `patches/polyfills.js` | Chrome API compatibility + Buffer hex encoding | CRITICAL |
| `patches/hide-sidebar-button.js` | Hides panel toggle button in header | Optional |
| `patches/hide-mcm-import.js` | Hides "Import MCM File" option | Optional |
| `patches/hide-export-wallet.js` | Hides Backup/Export section in Settings | Optional |
| `patches/android-ui.css` | Full-width mobile layout | Optional |
| `android/.../MainActivity.kt` | WebView configuration | CRITICAL |
| `android/local.properties` | SDK location | Required |
| `android/gradle.properties` | Java path | Required |
| `build.ps1` | Build orchestration | CRITICAL |
| `.gitmodules` | Submodule config | CRITICAL |
| `mochiwallet/` | Upstream extension (submodule) | CRITICAL |

---

## 9. Maintainer Checklist

### New Maintainer Onboarding

- [ ] Understand git submodule concept
- [ ] Read main README.md for build setup
- [ ] Read this technical documentation
- [ ] Successfully build APK from clean clone
- [ ] Test wallet functionality on device/emulator
- [ ] Perform practice upstream update
- [ ] Review build.ps1 line by line

### Before Each Upstream Update

- [ ] Read upstream changelog/release notes
- [ ] Check for new Chrome API usage
- [ ] Check for build tool changes
- [ ] Update submodule in test branch first
- [ ] Build and test thoroughly
- [ ] Verify all critical wallet functions
- [ ] Document any new patches needed
- [ ] Update this documentation if architecture changes

### Release Checklist

- [ ] Submodule points to stable commit/tag
- [ ] Build completes without warnings
- [ ] All tests pass
- [ ] APK signed (for production)
- [ ] Version number updated in Android manifest
- [ ] CHANGELOG.md updated (if exists)
- [ ] Git tag created: `v1.x.x-android`
- [ ] Pushed to GitHub
- [ ] Release notes published

---

**Last Updated**: 2025-12-30  
**Maintainer**: adequate-systems  
**Repository**: https://github.com/adequate-systems/mochiwallet-android

