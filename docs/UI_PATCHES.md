## Mobile UI Patches

**Purpose:** Adapt the Chrome extension UI for mobile devices by removing elements that rely on browser APIs unavailable in Android WebView, and optimizing the layout to fill the entire screen.

### Why These Patches Exist

The Mochimo wallet is a Chrome extension designed for browser environments. Several features rely on browser-specific APIs that are not available in Android WebView:

1. **Panel Toggle Button** - Opens a separate browser panel window (Chrome extension API, not available on mobile)
2. **Import MCM File** - Uses browser file picker APIs (not available on mobile)
3. **Export/Backup Wallet** - Uses browser file download APIs (not available on mobile)
4. **Fixed Viewport Size** - Chrome extensions have a fixed popup size; mobile needs full-screen scaling

These patches remove these UI elements to provide a clean mobile experience without confusing non-functional buttons.

### UI Scaling Solution

The UI scaling is handled at two levels:

**1. WebView Settings (MainActivity.kt):**
```kotlin
settings.apply {
    useWideViewPort = true          // Enable viewport meta tag support
    loadWithOverviewMode = true     // Fit content to screen width
    setSupportZoom(false)           // Disable pinch zoom
    builtInZoomControls = false     // Hide zoom controls
    displayZoomControls = false
}
```

**2. CSS Overrides (android-ui.css):**
```css
html, body {
    height: 100%;
    min-height: 100vh;
    min-height: 100dvh;  /* Dynamic viewport height for mobile */
    overflow-x: hidden;
}
```

These settings ensure the wallet UI fills the entire screen without the bottom 25% being cut off.

### Files Introduced

| File | Purpose | Detection Method |
|------|---------|------------------|
| `patches/android-ui.css` | Full-screen layout for mobile | CSS overrides |
| `patches/mobile-ui-panel-button.js` | Removes panel toggle button (not available on mobile) | SVG icon detection |
| `patches/mobile-ui-mcm-import.js` | Removes "Import MCM File" option (not available on mobile) | Text matching |
| `patches/mobile-ui-export.js` | Removes Backup section (not available on mobile) | Text matching |
| `patches/legal-links.js` | Adds Terms of Service and Privacy Policy links | DOM injection |

### What Each Patch Does

**mobile-ui-panel-button.js:**
- Removes the panel toggle button in the header (right side, after network status indicator)
- This button opens a browser panel window, which is a Chrome extension feature not available on mobile
- Detection: Buttons in header with SVG containing `<rect>` and <=2 `<line>` elements

**mobile-ui-mcm-import.js:**
- Removes "Import MCM File" option in the Add Account dialog
- MCM file import uses browser file picker APIs not available on mobile
- Detection: Buttons with text/aria-label containing "import mcm"

**mobile-ui-export.js:**
- Removes "Export Wallet" button in Settings
- Removes "Backup" heading (h2/h3/h4)
- Removes description text about exporting wallet
- File export uses browser download APIs not available on mobile
- Detection: Text content matching

**legal-links.js:**
- Adds "By using this App you accept the Terms of Service" link at bottom center
- Adds "Privacy Policy" link below
- Links open in device browser (external URLs)
- URLs: `https://mochimo.org/mobile-wallet-terms` and `https://mochimo.org/mobile-wallet-privacy`

### How Patches Are Applied (Automated)

The build scripts (`build.ps1` / `build.sh`) automatically:

1. Copy patch files from `patches/` to `android/app/src/main/assets/`
2. Inject script/link tags into `index.html` in this order:
   - `polyfills.js` (required)
   - `mobile-ui-panel-button.js`
   - `mobile-ui-mcm-import.js`
   - `mobile-ui-export.js`
   - `legal-links.js`
   - Main bundle
   - `android-ui.css`

If any patch file is missing, the build continues without it.

### Technical Implementation

All JavaScript patches use:
- **MutationObserver** - Re-applies changes when DOM changes (SPA navigation)
- **Marker attributes** - Prevents re-processing already-modified elements (`data-mobile-ui-*`)
- **Timed retries** - Multiple scans at 200ms, 500ms, 1000ms, 2000ms after load
- **display: none !important** - Ensures elements are removed from view

### Disabling Patches

To disable any patch:
1. Remove or rename the file in `patches/`
2. Rebuild with `build.ps1` or `build.sh`

Or manually delete from `android/app/src/main/assets/` and remove the script tag from `index.html`.

### Debugging

Patches log to console when removing elements:
```
[Mobile UI] Removed panel button (not applicable on mobile)
[Mobile UI] Removed element (not applicable on mobile): BUTTON Export Wallet button
```

View logs with:
```powershell
adb logcat -v time | Select-String -Pattern "\[Mobile UI\]"
```

### Notes

- Patches are **optional** but recommended for a clean mobile experience
- No color/typography changes are made - only removes elements that aren't functional on mobile
- Patches target specific elements to avoid breaking other UI components
- CSS `:has()` selector is NOT used (not supported in older Android WebView)
