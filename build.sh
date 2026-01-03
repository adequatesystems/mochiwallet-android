#!/usr/bin/env bash
# Mochimo Wallet Android Build Script
# Builds Android APK from upstream extension submodule
# Cross-platform version (Linux, macOS, WSL)
# Mirrors the functionality of build.ps1 for Windows

set -e  # Exit on error

# Parse arguments
SKIP_EXTENSION_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--skip-extension-build)
            SKIP_EXTENSION_BUILD=true
            shift
            ;;
        -h|--help)
            echo "Usage: ./build.sh [options]"
            echo ""
            echo "Options:"
            echo "  -s, --skip-extension-build  Skip building the web extension"
            echo "  -h, --help                  Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🚀 Mochimo Wallet Android - Build Script${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get script directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_DIR="$REPO_ROOT/mochiwallet"
ANDROID_DIR="$REPO_ROOT/android"
PATCHES_DIR="$REPO_ROOT/patches"
ASSETS_DIR="$ANDROID_DIR/app/src/main/assets"

# Step 1: Check submodule exists (auto-init if missing)
echo -e "${YELLOW}[1/7] Checking submodule...${NC}"
if [ ! -d "$EXTENSION_DIR" ] || [ ! -f "$EXTENSION_DIR/package.json" ]; then
    echo -e "   ${YELLOW}Submodule missing; initializing...${NC}"
    submodule_ready=false

    # Prefer git submodule if this is a git repo
    if [ -d "$REPO_ROOT/.git" ]; then
        if (cd "$REPO_ROOT" && git submodule update --init --recursive "mochiwallet" >/dev/null 2>&1); then
            if [ -d "$EXTENSION_DIR" ] && [ -f "$EXTENSION_DIR/package.json" ]; then
                submodule_ready=true
            fi
        fi
    fi

    # Fallback: plain git clone if submodule init failed or not a git repo
    if [ "$submodule_ready" = false ]; then
        rm -rf "$EXTENSION_DIR"
        if git clone https://github.com/adequatesystems/mochiwallet.git "$EXTENSION_DIR" >/dev/null 2>&1; then
            if [ -d "$EXTENSION_DIR" ] && [ -f "$EXTENSION_DIR/package.json" ]; then
                submodule_ready=true
            fi
        fi
    fi

    if [ "$submodule_ready" = false ]; then
        echo -e "${RED}ERROR: mochiwallet submodule not found and auto-init failed!${NC}"
        echo -e "${YELLOW}Ensure git is installed and run: git submodule update --init --recursive${NC}"
        exit 1
    fi

    echo -e "   ${GREEN}✅ Submodule initialized${NC}"
else
    echo -e "   ${GREEN}✅ Submodule present${NC}"
fi

# Step 2: Build extension (unless skipped)
if [ "$SKIP_EXTENSION_BUILD" = false ]; then
    echo -e "\n${YELLOW}[2/7] Building web extension...${NC}"
    pushd "$EXTENSION_DIR" > /dev/null
    
    # Check if we need to install/build dependencies
    NEEDS_BUILD=false
    if [ ! -d "node_modules" ] || [ ! -d "node_modules/mochimo-wallet/dist" ] || [ ! -d "node_modules/mochimo-mesh-api-client/dist" ]; then
        NEEDS_BUILD=true
    fi
    
    if [ "$NEEDS_BUILD" = true ]; then
        echo -e "   Installing dependencies..."
        
        # Create pnpm-workspace.yaml with onlyBuiltDependencies if it doesn't exist or is incomplete
        cat > pnpm-workspace.yaml << 'EOF'
packages: []

onlyBuiltDependencies:
  - mochimo-wallet
  - mochimo-wots
  - mochimo-mesh-api-client
EOF
        echo -e "   Created pnpm-workspace.yaml with onlyBuiltDependencies"
        
        # Try normal pnpm install first
        set +e  # Temporarily disable exit on error
        npx pnpm@8 install > /dev/null 2>&1
        INSTALL_RESULT=$?
        set -e
        
        # Check if git dependencies were built successfully
        MOCHI_WALLET_DIST="$EXTENSION_DIR/node_modules/mochimo-wallet/dist"
        MESH_API_DIST="$EXTENSION_DIR/node_modules/mochimo-mesh-api-client/dist"
        
        if [ $INSTALL_RESULT -ne 0 ] || [ ! -d "$MOCHI_WALLET_DIST" ] || [ ! -d "$MESH_API_DIST" ]; then
            echo -e "   ${YELLOW}Git dependencies need manual build (upstream missing onlyBuiltDependencies)...${NC}"
            
            # Install with --ignore-scripts to skip failed builds
            echo -e "   Re-installing with --ignore-scripts..."
            rm -rf node_modules
            npx pnpm@8 install --ignore-scripts
            
            # Build mochimo-wallet manually
            echo -e "   Building mochimo-wallet dependency..."
            TEMP_BUILD_DIR=$(mktemp -d)
            
            # Clone mochimo-wallet
            git clone --depth 1 --branch v1.1.54 https://github.com/adequatesystems/mochimo-wallet.git "$TEMP_BUILD_DIR" > /dev/null 2>&1
            
            pushd "$TEMP_BUILD_DIR" > /dev/null
            
            # Add missing onlyBuiltDependencies to its pnpm-workspace.yaml
            cat > pnpm-workspace.yaml << 'EOF'
packages:
  - 'examples/*'

onlyBuiltDependencies:
  - mochimo-mesh-api-client
  - mochimo-wots
EOF
            
            # Install and build
            npx pnpm@8 install > /dev/null 2>&1
            npx vite build > /dev/null 2>&1
            
            if [ ! -f "dist/index.js" ]; then
                popd > /dev/null
                rm -rf "$TEMP_BUILD_DIR"
                popd > /dev/null
                echo -e "   ${RED}Failed to build mochimo-wallet${NC}"
                exit 1
            fi
            
            # Copy dist to node_modules
            cp -r dist "$EXTENSION_DIR/node_modules/mochimo-wallet/"
            
            popd > /dev/null
            rm -rf "$TEMP_BUILD_DIR"
            echo -e "   ${GREEN}✅ mochimo-wallet built${NC}"
            
            # Build mochimo-mesh-api-client manually
            echo -e "   Building mochimo-mesh-api-client dependency..."
            TEMP_BUILD_DIR2=$(mktemp -d)
            
            git clone --depth 1 https://github.com/adequatesystems/mochimo-mesh-api-client.git "$TEMP_BUILD_DIR2" > /dev/null 2>&1
            
            pushd "$TEMP_BUILD_DIR2" > /dev/null
            npm install --ignore-scripts > /dev/null 2>&1
            npx tsup src/index.ts --format cjs,esm --dts > /dev/null 2>&1
            
            if [ ! -f "dist/index.js" ]; then
                popd > /dev/null
                rm -rf "$TEMP_BUILD_DIR2"
                popd > /dev/null
                echo -e "   ${RED}Failed to build mochimo-mesh-api-client${NC}"
                exit 1
            fi
            
            # Copy dist to node_modules
            cp -r dist "$EXTENSION_DIR/node_modules/mochimo-mesh-api-client/"
            
            popd > /dev/null
            rm -rf "$TEMP_BUILD_DIR2"
            echo -e "   ${GREEN}✅ mochimo-mesh-api-client built${NC}"
        else
            echo -e "   ${GREEN}✅ Dependencies installed${NC}"
        fi
    fi
    
    # Build extension
    echo -e "   Building extension..."
    npx pnpm@8 run build
    
    popd > /dev/null
    echo -e "   ${GREEN}✅ Extension built${NC}"
else
    echo -e "\n${YELLOW}[2/7] Skipping extension build (using existing dist/)${NC}"
fi

# Step 3: Apply Android patches
echo -e "\n${YELLOW}[3/7] Applying Android patches...${NC}"

VITE_CONFIG="$EXTENSION_DIR/vite.config.ts"
if [ -f "$VITE_CONFIG" ]; then
    if ! grep -q "base: './'" "$VITE_CONFIG"; then
        echo -e "   Patching vite.config.ts..."
        sed -i.bak "s|base: '/'|base: './'|g" "$VITE_CONFIG"
        rm -f "$VITE_CONFIG.bak"
        echo -e "   ${GREEN}✅ Patched vite.config.ts${NC}"
    else
        echo -e "   ${GREEN}vite.config.ts already patched${NC}"
    fi
else
    echo -e "   ${YELLOW}WARNING: vite.config.ts not found${NC}"
fi

# Step 4: Copy assets to Android
echo -e "\n${YELLOW}[4/7] Copying assets to Android...${NC}"

DIST_PATH="$EXTENSION_DIR/dist"
if [ ! -d "$DIST_PATH" ]; then
    echo -e "${RED}ERROR: Extension dist/ directory not found. Build the extension first.${NC}"
    exit 1
fi

# Clear existing assets
rm -rf "$ASSETS_DIR"
mkdir -p "$ASSETS_DIR"

# Copy dist to assets
cp -r "$DIST_PATH"/* "$ASSETS_DIR/"
FILE_COUNT=$(find "$ASSETS_DIR" -type f | wc -l)
echo -e "   ${GREEN}✅ Copied $FILE_COUNT files${NC}"

# Step 5: Add polyfills.js and optional UI overrides
echo -e "\n${YELLOW}[5/7] Adding Android polyfills and mobile UI patches...${NC}"

POLYFILLS_SRC="$PATCHES_DIR/polyfills.js"
POLYFILLS_DST="$ASSETS_DIR/polyfills.js"
ANDROID_UI_CSS_SRC="$PATCHES_DIR/android-ui.css"
ANDROID_UI_CSS_DST="$ASSETS_DIR/android-ui.css"
MOBILE_UI_PANEL_JS_SRC="$PATCHES_DIR/mobile-ui-panel-button.js"
MOBILE_UI_PANEL_JS_DST="$ASSETS_DIR/mobile-ui-panel-button.js"
MOBILE_UI_MCM_JS_SRC="$PATCHES_DIR/mobile-ui-mcm-import.js"
MOBILE_UI_MCM_JS_DST="$ASSETS_DIR/mobile-ui-mcm-import.js"
MOBILE_UI_EXPORT_JS_SRC="$PATCHES_DIR/mobile-ui-export.js"
MOBILE_UI_EXPORT_JS_DST="$ASSETS_DIR/mobile-ui-export.js"
MOBILE_UI_MAIN_SCREEN_JS_SRC="$PATCHES_DIR/mobile-ui-main-screen.js"
MOBILE_UI_MAIN_SCREEN_JS_DST="$ASSETS_DIR/mobile-ui-main-screen.js"
LEGAL_LINKS_JS_SRC="$PATCHES_DIR/legal-links.js"
LEGAL_LINKS_JS_DST="$ASSETS_DIR/legal-links.js"

if [ -f "$POLYFILLS_SRC" ]; then
    cp "$POLYFILLS_SRC" "$POLYFILLS_DST"
    echo -e "   ${GREEN}✅ polyfills.js copied${NC}"
else
    echo -e "   ${RED}ERROR: polyfills.js not found in patches/${NC}"
    exit 1
fi

if [ -f "$ANDROID_UI_CSS_SRC" ]; then
    cp "$ANDROID_UI_CSS_SRC" "$ANDROID_UI_CSS_DST"
    echo -e "   ${GREEN}✅ android-ui.css copied (mobile layout)${NC}"
else
    echo -e "   ${YELLOW}(optional) android-ui.css not found in patches/${NC}"
fi

if [ -f "$MOBILE_UI_PANEL_JS_SRC" ]; then
    cp "$MOBILE_UI_PANEL_JS_SRC" "$MOBILE_UI_PANEL_JS_DST"
    echo -e "   ${GREEN}✅ mobile-ui-panel-button.js copied (panel button N/A on mobile)${NC}"
else
    echo -e "   ${YELLOW}(optional) mobile-ui-panel-button.js not found in patches/${NC}"
fi

if [ -f "$MOBILE_UI_MCM_JS_SRC" ]; then
    cp "$MOBILE_UI_MCM_JS_SRC" "$MOBILE_UI_MCM_JS_DST"
    echo -e "   ${GREEN}✅ mobile-ui-mcm-import.js copied (MCM import N/A on mobile)${NC}"
else
    echo -e "   ${YELLOW}(optional) mobile-ui-mcm-import.js not found in patches/${NC}"
fi

if [ -f "$MOBILE_UI_EXPORT_JS_SRC" ]; then
    cp "$MOBILE_UI_EXPORT_JS_SRC" "$MOBILE_UI_EXPORT_JS_DST"
    echo -e "   ${GREEN}✅ mobile-ui-export.js copied (file export N/A on mobile)${NC}"
else
    echo -e "   ${YELLOW}(optional) mobile-ui-export.js not found in patches/${NC}"
fi

if [ -f "$MOBILE_UI_MAIN_SCREEN_JS_SRC" ]; then
    cp "$MOBILE_UI_MAIN_SCREEN_JS_SRC" "$MOBILE_UI_MAIN_SCREEN_JS_DST"
    echo -e "   ${GREEN}✅ mobile-ui-main-screen.js copied (main screen customizations)${NC}"
else
    echo -e "   ${YELLOW}(optional) mobile-ui-main-screen.js not found in patches/${NC}"
fi

if [ -f "$LEGAL_LINKS_JS_SRC" ]; then
    cp "$LEGAL_LINKS_JS_SRC" "$LEGAL_LINKS_JS_DST"
    echo -e "   ${GREEN}✅ legal-links.js copied (Terms of Service and Privacy Policy links)${NC}"
else
    echo -e "   ${YELLOW}(optional) legal-links.js not found in patches/${NC}"
fi

# Step 6: Fix index.html
echo -e "\n${YELLOW}[6/7] Fixing index.html...${NC}"

INDEX_PATH="$ASSETS_DIR/index.html"
if [ ! -f "$INDEX_PATH" ]; then
    echo -e "   ${RED}ERROR: index.html not found!${NC}"
    exit 1
fi

# Read content
CONTENT=$(cat "$INDEX_PATH")

# Remove require('buffer') line (escape pipe chars for sed)
CONTENT=$(echo "$CONTENT" | sed "s/window\.Buffer = window\.Buffer || require(['\"]buffer['\"]).\.Buffer;//g")

# Fix absolute asset paths to relative paths for Android WebView
# Convert "/assets/" to "./assets/" in src, href attributes
CONTENT=$(echo "$CONTENT" | sed 's|src="/assets/|src="./assets/|g')
CONTENT=$(echo "$CONTENT" | sed 's|href="/assets/|href="./assets/|g')

# Remove existing polyfills/mobile UI script tags to re-inject in correct order
CONTENT=$(echo "$CONTENT" | sed '/<script src="\.\/polyfills\.js"><\/script>/d')
CONTENT=$(echo "$CONTENT" | sed '/<script src="\.\/mobile-ui-panel-button\.js"><\/script>/d')
CONTENT=$(echo "$CONTENT" | sed '/<script src="\.\/mobile-ui-mcm-import\.js"><\/script>/d')
CONTENT=$(echo "$CONTENT" | sed '/<script src="\.\/mobile-ui-export\.js"><\/script>/d')
CONTENT=$(echo "$CONTENT" | sed '/<script src="\.\/mobile-ui-main-screen\.js"><\/script>/d')
CONTENT=$(echo "$CONTENT" | sed '/<script src="\.\/legal-links\.js"><\/script>/d')

# Build script tags array based on which patch files exist
SCRIPT_TAGS='    <script src="./polyfills.js"></script>'
if [ -f "$MOBILE_UI_PANEL_JS_DST" ]; then
    SCRIPT_TAGS="$SCRIPT_TAGS"$'\n''    <script src="./mobile-ui-panel-button.js"></script>'
fi
if [ -f "$MOBILE_UI_MCM_JS_DST" ]; then
    SCRIPT_TAGS="$SCRIPT_TAGS"$'\n''    <script src="./mobile-ui-mcm-import.js"></script>'
fi
if [ -f "$MOBILE_UI_EXPORT_JS_DST" ]; then
    SCRIPT_TAGS="$SCRIPT_TAGS"$'\n''    <script src="./mobile-ui-export.js"></script>'
fi
if [ -f "$MOBILE_UI_MAIN_SCREEN_JS_DST" ]; then
    SCRIPT_TAGS="$SCRIPT_TAGS"$'\n''    <script src="./mobile-ui-main-screen.js"></script>'
fi
if [ -f "$LEGAL_LINKS_JS_DST" ]; then
    SCRIPT_TAGS="$SCRIPT_TAGS"$'\n''    <script src="./legal-links.js"></script>'
fi

# Inject scripts before the popup bundle module script
if echo "$CONTENT" | grep -q '<script type="module"[^>]*src="\./assets/popup-'; then
    echo -e "   Injecting polyfills and mobile UI patches before popup bundle..."
    # Use awk for reliable multi-line insertion
    CONTENT=$(echo "$CONTENT" | awk -v scripts="$SCRIPT_TAGS" '
        /<script type="module"[^>]*src="\.\/assets\/popup-/ && !done {
            print scripts
            done=1
        }
        {print}
    ')
else
    echo -e "   ${YELLOW}WARNING: module popup script not found; appending scripts at end of <head>${NC}"
    CONTENT=$(echo "$CONTENT" | sed "s|</head>|$SCRIPT_TAGS\n</head>|")
fi

# Add android-ui.css link after popup CSS if not present
if ! echo "$CONTENT" | grep -q 'android-ui\.css'; then
    if echo "$CONTENT" | grep -q 'popup-.*\.css'; then
        echo -e "   Adding android-ui.css link..."
        CONTENT=$(echo "$CONTENT" | awk '
            /<link rel="stylesheet"[^>]*popup-[^>]*\.css"/ && !done {
                print
                print "    <link rel=\"stylesheet\" href=\"./android-ui.css\">"
                done=1
                next
            }
            {print}
        ')
    else
        echo -e "   ${YELLOW}WARNING: popup CSS link not found; appending android-ui.css at end of <head>${NC}"
        CONTENT=$(echo "$CONTENT" | sed 's|</head>|    <link rel="stylesheet" href="./android-ui.css">\n</head>|')
    fi
fi

# Write updated content
echo "$CONTENT" > "$INDEX_PATH"
echo -e "   ${GREEN}✅ index.html fixed${NC}"

# Step 7: Build Android APK
echo -e "\n${YELLOW}[7/7] Building Android APK...${NC}"

pushd "$ANDROID_DIR" > /dev/null

# Check/create local.properties
LOCAL_PROPS="$ANDROID_DIR/local.properties"
if [ ! -f "$LOCAL_PROPS" ]; then
    echo -e "   ${YELLOW}Creating local.properties...${NC}"
    
    # Try to find Android SDK
    SDK_DIR=""
    if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
        SDK_DIR="$ANDROID_HOME"
    elif [ -n "$ANDROID_SDK_ROOT" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
        SDK_DIR="$ANDROID_SDK_ROOT"
    elif [ -d "$HOME/Android/Sdk" ]; then
        SDK_DIR="$HOME/Android/Sdk"
    elif [ -d "$HOME/Library/Android/sdk" ]; then
        SDK_DIR="$HOME/Library/Android/sdk"
    fi
    
    if [ -n "$SDK_DIR" ]; then
        echo "sdk.dir=$SDK_DIR" > "$LOCAL_PROPS"
        echo -e "   Found SDK at: $SDK_DIR"
    else
        echo -e "   ${YELLOW}WARNING: Android SDK not found. Set ANDROID_HOME or create local.properties manually.${NC}"
    fi
fi

# Check JAVA_HOME - Gradle requires Java 17
if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    echo -e "   ${YELLOW}JAVA_HOME not set, searching for Java 17...${NC}"
    
    # Try common Java 17 locations
    JAVA_SEARCH_PATHS=(
        "/usr/lib/jvm/java-17-openjdk"*
        "/usr/lib/jvm/temurin-17"*
        "/usr/lib/jvm/adoptium-17"*
        "/Library/Java/JavaVirtualMachines/temurin-17"*/Contents/Home
        "/Library/Java/JavaVirtualMachines/adoptopenjdk-17"*/Contents/Home
        "/opt/homebrew/opt/openjdk@17"*
    )
    
    for pattern in "${JAVA_SEARCH_PATHS[@]}"; do
        for path in $pattern; do
            if [ -d "$path" ]; then
                export JAVA_HOME="$path"
                echo -e "   Found Java 17: $JAVA_HOME"
                break 2
            fi
        done
    done
fi

if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    echo -e "   ${YELLOW}WARNING: JAVA_HOME not set and Java 17 not found!${NC}"
    echo -e "   ${YELLOW}Install Eclipse Adoptium JDK 17 and set JAVA_HOME environment variable${NC}"
fi

# Build APK
echo -e "   Running Gradle build..."
./gradlew assembleDebug
BUILD_RESULT=$?

popd > /dev/null

if [ $BUILD_RESULT -ne 0 ]; then
    echo -e "\n${RED}Android build failed!${NC}"
    exit 1
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Build Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Show APK info
APK_PATH="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo ""
    echo -e "${CYAN}📦 APK Location:${NC}"
    echo -e "   $APK_PATH"
    echo -e "   Size: $APK_SIZE"
fi
echo ""
echo -e "${YELLOW}To install on a running device/emulator:${NC} adb install -r \"$APK_PATH\""
echo ""
