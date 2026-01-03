#!/usr/bin/env pwsh
# Mochimo Wallet Android Build Script
# Builds Android APK from upstream extension submodule

param(
    [switch]$SkipExtensionBuild = $false
)

$ErrorActionPreference = "Stop"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🚀 Mochimo Wallet Android - Build Script" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

$repoRoot = $PSScriptRoot
$extensionDir = Join-Path $repoRoot "mochiwallet"
$androidDir = Join-Path $repoRoot "android"
$patchesDir = Join-Path $repoRoot "patches"
$assetsDir = Join-Path $androidDir "app\src\main\assets"

# Step 1: Check submodule exists (auto-init if missing)
Write-Host "[1/7] Checking submodule..." -ForegroundColor Yellow
if (-not (Test-Path $extensionDir) -or -not (Test-Path (Join-Path $extensionDir "package.json"))) {
    Write-Host "   Submodule missing; initializing..." -ForegroundColor Yellow
    $submoduleReady = $false

    # Prefer git submodule if this is a git repo
    if (Test-Path (Join-Path $repoRoot ".git")) {
        Push-Location $repoRoot
        $ErrorActionPreference = "Continue"
        git submodule update --init --recursive "mochiwallet" 2>&1 | Out-Null
        $gitExit = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        Pop-Location
        if ($gitExit -eq 0 -and (Test-Path (Join-Path $extensionDir "package.json"))) {
            $submoduleReady = $true
        }
    }

    # Fallback: plain git clone if submodule init failed or not a git repo
    if (-not $submoduleReady) {
        Remove-Item -Recurse -Force $extensionDir -ErrorAction SilentlyContinue
        $ErrorActionPreference = "Continue"
        git clone https://github.com/adequatesystems/mochiwallet.git $extensionDir 2>&1 | Out-Null
        $gitExit = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        if ($gitExit -eq 0 -and (Test-Path (Join-Path $extensionDir "package.json"))) {
            $submoduleReady = $true
        }
    }

    if (-not $submoduleReady) {
        Write-Host "ERROR: mochiwallet submodule not found and auto-init failed!" -ForegroundColor Red
        Write-Host "Ensure git is installed and run: git submodule update --init --recursive" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "   ✅ Submodule initialized" -ForegroundColor Green
} else {
    Write-Host "   ✅ Submodule present" -ForegroundColor Green
}

# Step 2: Build extension (unless skipped)
if (-not $SkipExtensionBuild) {
    Write-Host "`n[2/7] Building web extension..." -ForegroundColor Yellow
    Push-Location $extensionDir
    
    # Check if we need to install/build dependencies
    $needsBuild = -not (Test-Path "node_modules") -or -not (Test-Path "node_modules\mochimo-wallet\dist") -or -not (Test-Path "node_modules\mochimo-mesh-api-client\dist")
    
    if ($needsBuild) {
        Write-Host "   Installing dependencies..." -ForegroundColor Gray
        
        # Create pnpm-workspace.yaml with onlyBuiltDependencies if it doesn't exist or is incomplete
        $workspaceFile = Join-Path $extensionDir "pnpm-workspace.yaml"
        $workspaceContent = @"
packages: []

onlyBuiltDependencies:
  - mochimo-wallet
  - mochimo-wots
  - mochimo-mesh-api-client
"@
        $workspaceContent | Set-Content $workspaceFile -Force
        Write-Host "   Created pnpm-workspace.yaml with onlyBuiltDependencies" -ForegroundColor Gray
        
        # Try normal pnpm install first
        $env:ErrorActionPreference = "Continue"
        npx pnpm@8 install 2>&1 | Out-Null
        $installResult = $LASTEXITCODE
        $env:ErrorActionPreference = "Stop"
        
        # Check if git dependencies were built successfully
        $mochiWalletDist = Join-Path $extensionDir "node_modules\mochimo-wallet\dist"
        $meshApiDist = Join-Path $extensionDir "node_modules\mochimo-mesh-api-client\dist"
        
        if ($installResult -ne 0 -or -not (Test-Path $mochiWalletDist) -or -not (Test-Path $meshApiDist)) {
            Write-Host "   Git dependencies need manual build (upstream missing onlyBuiltDependencies)..." -ForegroundColor Yellow
            
            # Install with --ignore-scripts to skip failed builds
            Write-Host "   Re-installing with --ignore-scripts..." -ForegroundColor Gray
            Remove-Item -Recurse -Force "node_modules" -ErrorAction SilentlyContinue
            npx pnpm@8 install --ignore-scripts
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                throw "pnpm install --ignore-scripts failed"
            }
            
            # Build mochimo-wallet manually
            Write-Host "   Building mochimo-wallet dependency..." -ForegroundColor Gray
            $tempBuildDir = Join-Path $env:TEMP "mochimo-wallet-build-$(Get-Random)"
            
            # Clone mochimo-wallet (git writes progress to stderr, so suppress errors temporarily)
            $ErrorActionPreference = "Continue"
            git clone --depth 1 --branch v1.1.54 https://github.com/adequatesystems/mochimo-wallet.git $tempBuildDir 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            
            Push-Location $tempBuildDir
            
            # Add missing onlyBuiltDependencies to its pnpm-workspace.yaml
            $mwWorkspace = @"
packages:
  - 'examples/*'

onlyBuiltDependencies:
  - mochimo-mesh-api-client
  - mochimo-wots
"@
            $mwWorkspace | Set-Content "pnpm-workspace.yaml" -Force
            
            # Install and build (vite outputs TS errors to stderr but still produces valid JS)
            $ErrorActionPreference = "Continue"
            npx pnpm@8 install 2>&1 | Out-Null
            npx vite build 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            
            if (-not (Test-Path "dist\index.js")) {
                Pop-Location
                Remove-Item -Recurse -Force $tempBuildDir -ErrorAction SilentlyContinue
                Pop-Location
                throw "Failed to build mochimo-wallet"
            }
            
            # Copy dist to node_modules
            $destDir = Join-Path $extensionDir "node_modules\mochimo-wallet"
            Copy-Item -Recurse -Force "dist" "$destDir\"
            
            Pop-Location
            Remove-Item -Recurse -Force $tempBuildDir -ErrorAction SilentlyContinue
            Write-Host "   ✅ mochimo-wallet built" -ForegroundColor Green
            
            # Build mochimo-mesh-api-client manually
            Write-Host "   Building mochimo-mesh-api-client dependency..." -ForegroundColor Gray
            $tempBuildDir2 = Join-Path $env:TEMP "mochimo-mesh-api-client-build-$(Get-Random)"
            
            # Clone (git writes progress to stderr, so suppress errors temporarily)
            $ErrorActionPreference = "Continue"
            git clone --depth 1 https://github.com/adequatesystems/mochimo-mesh-api-client.git $tempBuildDir2 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            
            Push-Location $tempBuildDir2
            
            # Install and build (suppress stderr for npm/npx)
            $ErrorActionPreference = "Continue"
            npm install --ignore-scripts 2>&1 | Out-Null
            npx tsup src/index.ts --format cjs,esm --dts 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            
            if (-not (Test-Path "dist\index.js")) {
                Pop-Location
                Remove-Item -Recurse -Force $tempBuildDir2 -ErrorAction SilentlyContinue
                Pop-Location
                throw "Failed to build mochimo-mesh-api-client"
            }
            
            # Copy dist to node_modules
            $destDir2 = Join-Path $extensionDir "node_modules\mochimo-mesh-api-client"
            Copy-Item -Recurse -Force "dist" "$destDir2\"
            
            Pop-Location
            Remove-Item -Recurse -Force $tempBuildDir2 -ErrorAction SilentlyContinue
            Write-Host "   ✅ mochimo-mesh-api-client built" -ForegroundColor Green
        } else {
            Write-Host "   ✅ Dependencies installed" -ForegroundColor Green
        }
    }
    
    # Build extension
    Write-Host "   Building extension..." -ForegroundColor Gray
    npx pnpm@8 run build
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "pnpm run build failed"
    }
    
    Pop-Location
    Write-Host "   ✅ Extension built" -ForegroundColor Green
} else {
    Write-Host "`n[2/7] Skipping extension build (using existing dist/)" -ForegroundColor Yellow
}

# Step 3: Apply Android patches
Write-Host "`n[3/7] Applying Android patches..." -ForegroundColor Yellow

# Patch vite.config if not already patched
$viteConfigPath = Join-Path $extensionDir "vite.config.ts"
if (Test-Path $viteConfigPath) {
    $viteContent = Get-Content $viteConfigPath -Raw
    if ($viteContent -notmatch "base: '\.\/'") {
        Write-Host "   Patching vite.config.ts..." -ForegroundColor Gray
        $viteContent = $viteContent -replace "base: '/'", "base: './'"
        $viteContent | Set-Content $viteConfigPath -NoNewline
        Write-Host "   ✅ Patched vite.config.ts" -ForegroundColor Green
    } else {
        Write-Host "   vite.config.ts already patched" -ForegroundColor Green
    }
} else {
    Write-Host "   WARNING: vite.config.ts not found" -ForegroundColor Yellow
}

# Step 4: Copy assets to Android
Write-Host "`n[4/7] Copying assets to Android..." -ForegroundColor Yellow

$distPath = Join-Path $extensionDir "dist"
if (-not (Test-Path $distPath)) {
    throw "Extension dist/ directory not found. Build the extension first."
}

# Clear existing assets
if (Test-Path $assetsDir) {
    Remove-Item -Path "$assetsDir\*" -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null

# Copy dist to assets
Copy-Item -Path "$distPath\*" -Destination $assetsDir -Recurse -Force
$fileCount = (Get-ChildItem -Path $assetsDir -Recurse -File).Count
Write-Host "   ✅ Copied $fileCount files" -ForegroundColor Green

# Step 5: Add polyfills.js and optional UI overrides
Write-Host "`n[5/7] Adding Android polyfills and mobile UI patches..." -ForegroundColor Yellow

$polyfillsSrc = Join-Path $patchesDir "polyfills.js"
$polyfillsDst = Join-Path $assetsDir "polyfills.js"
$androidUiCssSrc = Join-Path $patchesDir "android-ui.css"
$androidUiCssDst = Join-Path $assetsDir "android-ui.css"
$mobileUiPanelJsSrc = Join-Path $patchesDir "mobile-ui-panel-button.js"
$mobileUiPanelJsDst = Join-Path $assetsDir "mobile-ui-panel-button.js"
$mobileUiMcmJsSrc = Join-Path $patchesDir "mobile-ui-mcm-import.js"
$mobileUiMcmJsDst = Join-Path $assetsDir "mobile-ui-mcm-import.js"
$mobileUiExportJsSrc = Join-Path $patchesDir "mobile-ui-export.js"
$mobileUiExportJsDst = Join-Path $assetsDir "mobile-ui-export.js"
$mobileUiMainScreenJsSrc = Join-Path $patchesDir "mobile-ui-main-screen.js"
$mobileUiMainScreenJsDst = Join-Path $assetsDir "mobile-ui-main-screen.js"
$legalLinksJsSrc = Join-Path $patchesDir "legal-links.js"
$legalLinksJsDst = Join-Path $assetsDir "legal-links.js"

if (Test-Path $polyfillsSrc) {
    Copy-Item -Path $polyfillsSrc -Destination $polyfillsDst -Force
    Write-Host "   ✅ polyfills.js copied" -ForegroundColor Green
} else {
    Write-Host "   ERROR: polyfills.js not found in patches/" -ForegroundColor Red
    exit 1
}

if (Test-Path $androidUiCssSrc) {
    Copy-Item -Path $androidUiCssSrc -Destination $androidUiCssDst -Force
    Write-Host "   ✅ android-ui.css copied (mobile layout)" -ForegroundColor Green
} else {
    Write-Host "   (optional) android-ui.css not found in patches/" -ForegroundColor Yellow
}

if (Test-Path $mobileUiPanelJsSrc) {
    Copy-Item -Path $mobileUiPanelJsSrc -Destination $mobileUiPanelJsDst -Force
    Write-Host "   ✅ mobile-ui-panel-button.js copied (panel button N/A on mobile)" -ForegroundColor Green
} else {
    Write-Host "   (optional) mobile-ui-panel-button.js not found in patches/" -ForegroundColor Yellow
}

if (Test-Path $mobileUiMcmJsSrc) {
    Copy-Item -Path $mobileUiMcmJsSrc -Destination $mobileUiMcmJsDst -Force
    Write-Host "   ✅ mobile-ui-mcm-import.js copied (MCM import N/A on mobile)" -ForegroundColor Green
} else {
    Write-Host "   (optional) mobile-ui-mcm-import.js not found in patches/" -ForegroundColor Yellow
}

if (Test-Path $mobileUiExportJsSrc) {
    Copy-Item -Path $mobileUiExportJsSrc -Destination $mobileUiExportJsDst -Force
    Write-Host "   ✅ mobile-ui-export.js copied (file export N/A on mobile)" -ForegroundColor Green
} else {
    Write-Host "   (optional) mobile-ui-export.js not found in patches/" -ForegroundColor Yellow
}

if (Test-Path $mobileUiMainScreenJsSrc) {
    Copy-Item -Path $mobileUiMainScreenJsSrc -Destination $mobileUiMainScreenJsDst -Force
    Write-Host "   ✅ mobile-ui-main-screen.js copied (main screen customizations)" -ForegroundColor Green
} else {
    Write-Host "   (optional) mobile-ui-main-screen.js not found in patches/" -ForegroundColor Yellow
}

if (Test-Path $legalLinksJsSrc) {
    Copy-Item -Path $legalLinksJsSrc -Destination $legalLinksJsDst -Force
    Write-Host "   ✅ legal-links.js copied (Terms of Service and Privacy Policy links)" -ForegroundColor Green
} else {
    Write-Host "   (optional) legal-links.js not found in patches/" -ForegroundColor Yellow
}

# Step 6: Fix index.html
Write-Host "`n[6/7] Fixing index.html..." -ForegroundColor Yellow

$indexPath = Join-Path $assetsDir "index.html"
if (-not (Test-Path $indexPath)) {
    Write-Host "   ERROR: index.html not found!" -ForegroundColor Red
    exit 1
}

$content = Get-Content $indexPath -Raw

# Remove require('buffer') line
$originalContent = $content
$content = $content -replace 'window\.Buffer = window\.Buffer \|\| require\([''"]buffer[\'']\)\.Buffer;', ''

# Fix absolute asset paths to relative paths for Android WebView
# Convert "/assets/" to "./assets/" in src, href attributes
$content = $content -replace '(src|href)="/assets/', '$1="./assets/'

# Ensure Android UI override stylesheet is present after the popup CSS link
$androidUiLink = '    <link rel="stylesheet" href="./android-ui.css">'
if ($content -notmatch 'android-ui\.css') {
    $popupCssPattern = '<link rel="stylesheet"[^>]*popup-[^"\s]+\.css"[^>]*>'
    if ($content -match $popupCssPattern) {
        Write-Host "   Adding android-ui.css link..." -ForegroundColor Gray
        $content = $content -replace $popupCssPattern, "$&`n$androidUiLink"
    } else {
        Write-Host "   WARNING: popup CSS link not found; appending android-ui.css at end of <head>" -ForegroundColor Yellow
        $content = $content -replace '(</head>)', "    $androidUiLink`n$1"
    }
}

# Normalize script injection for polyfills and mobile UI patches: ensure order before the module popup bundle
$content = $content -replace ' *<script src="\./(polyfills|mobile-ui-panel-button|mobile-ui-mcm-import|mobile-ui-export|mobile-ui-main-screen|legal-links)\.js"></script>\r?\n?', ''

$scriptTags = @('    <script src="./polyfills.js"></script>')
if (Test-Path $mobileUiPanelJsDst) { $scriptTags += '    <script src="./mobile-ui-panel-button.js"></script>' }
if (Test-Path $mobileUiMcmJsDst) { $scriptTags += '    <script src="./mobile-ui-mcm-import.js"></script>' }
if (Test-Path $mobileUiExportJsDst) { $scriptTags += '    <script src="./mobile-ui-export.js"></script>' }
if (Test-Path $mobileUiMainScreenJsDst) { $scriptTags += '    <script src="./mobile-ui-main-screen.js"></script>' }
if (Test-Path $legalLinksJsDst) { $scriptTags += '    <script src="./legal-links.js"></script>' }

$modulePattern = '<script type="module"[^>]*src="\./assets/popup-[^"\s]+\.js"[^>]*></script>'
if ($content -match $modulePattern) {
    Write-Host "   Injecting polyfills and mobile UI patches before popup bundle..." -ForegroundColor Gray
    $content = [regex]::Replace($content, $modulePattern, { param($m) ($scriptTags -join "`n") + "`n" + $m.Value }, 1)
} else {
    Write-Host "   WARNING: module popup script not found; appending patches at end of <head>" -ForegroundColor Yellow
    $injection = ($scriptTags -join "`n")
    $content = $content -replace '(</head>)', "    $injection`n$1"
}

if ($content -ne $originalContent) {
    $content | Set-Content $indexPath -NoNewline
    Write-Host "   ✅ index.html fixed" -ForegroundColor Green
} else {
    Write-Host "   index.html already correct" -ForegroundColor Green
}

# Step 7: Build Android APK
Write-Host "`n[7/7] Building Android APK..." -ForegroundColor Yellow

Push-Location $androidDir

# Check local.properties exists and get SDK path
$sdkDir = $null
$localPropsPath = Join-Path $androidDir "local.properties"

# Try to find Android SDK in this order:
# 1. Existing local.properties
# 2. ANDROID_HOME environment variable
# 3. ANDROID_SDK_ROOT environment variable
# 4. Common default locations

if (Test-Path $localPropsPath) {
    $localProps = Get-Content $localPropsPath -Raw
    if ($localProps -match 'sdk\.dir=(.+)') {
        $sdkDir = ($matches[1] -replace '\\\\', '\').Trim()
        Write-Host "   Found SDK in local.properties: $sdkDir" -ForegroundColor Gray
    }
}

if (-not $sdkDir -or -not (Test-Path $sdkDir)) {
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
        $sdkDir = $env:ANDROID_HOME
        Write-Host "   Found SDK via ANDROID_HOME: $sdkDir" -ForegroundColor Gray
    } elseif ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
        $sdkDir = $env:ANDROID_SDK_ROOT
        Write-Host "   Found SDK via ANDROID_SDK_ROOT: $sdkDir" -ForegroundColor Gray
    } else {
        # Check common default locations
        $defaultLocations = @(
            "C:\Android",
            "$env:LOCALAPPDATA\Android\Sdk",
            "$env:USERPROFILE\AppData\Local\Android\Sdk"
        )
        foreach ($loc in $defaultLocations) {
            if (Test-Path $loc) {
                $sdkDir = $loc
                Write-Host "   Found SDK at default location: $sdkDir" -ForegroundColor Gray
                break
            }
        }
    }
}

if (-not $sdkDir -or -not (Test-Path $sdkDir)) {
    Write-Host "   WARNING: Android SDK not found!" -ForegroundColor Yellow
    Write-Host "   Set ANDROID_HOME environment variable or create android/local.properties" -ForegroundColor Yellow
    $sdkDir = "C:\Android"  # Fallback for local.properties
}

# Create/update local.properties if needed
if (-not (Test-Path $localPropsPath)) {
    Write-Host "   Creating local.properties with SDK path..." -ForegroundColor Yellow
    "sdk.dir=$($sdkDir -replace '\\', '/')" | Set-Content $localPropsPath
}

# Check JAVA_HOME - Gradle requires Java 17
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    # Try to find Java 17 in common locations
    $javaLocations = @(
        "C:\Program Files\Eclipse Adoptium\jdk-17*",
        "C:\Program Files\Java\jdk-17*",
        "C:\Program Files\Microsoft\jdk-17*"
    )
    foreach ($pattern in $javaLocations) {
        $found = Get-ChildItem $pattern -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $env:JAVA_HOME = $found.FullName
            Write-Host "   Found Java 17: $($env:JAVA_HOME)" -ForegroundColor Gray
            break
        }
    }
}

if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    Write-Host "   WARNING: JAVA_HOME not set and Java 17 not found!" -ForegroundColor Yellow
    Write-Host "   Install Eclipse Adoptium JDK 17 and set JAVA_HOME environment variable" -ForegroundColor Yellow
}

# Build APK
Write-Host "   Running Gradle build..." -ForegroundColor Gray
.\gradlew.bat assembleDebug
$buildResult = $LASTEXITCODE

Pop-Location

if ($buildResult -ne 0) {
    Write-Host "`nAndroid build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green

# Show APK info
$apkPath = Join-Path $androidDir "app\build\outputs\apk\debug\app-debug.apk"
if (Test-Path $apkPath) {
    $apkSize = (Get-Item $apkPath).Length / 1MB
    Write-Host ""
    Write-Host "APK Location:" -ForegroundColor Cyan
    Write-Host "   $apkPath" -ForegroundColor White
    Write-Host "   Size: $({"{0:N2}" -f $apkSize}) MB" -ForegroundColor White
}

Write-Host ""
Write-Host "To install on a connected device/emulator:" -ForegroundColor Yellow
Write-Host "   adb install -r `"$apkPath`"" -ForegroundColor White
Write-Host ""
