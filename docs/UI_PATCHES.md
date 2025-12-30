## Android UI Patches

**Purpose:** Hide UI elements that don't function properly in Android WebView and optimize the layout for mobile devices.

### Why These Patches Exist

The Mochimo wallet is a Chrome extension designed for browser environments. Several features don't work in Android WebView:

1. **Panel Toggle Button** - The "Expand to panel" button opens a separate browser panel, which doesn't exist in WebView
2. **Import MCM File** - File system APIs for importing MCM files aren't available in WebView
3. **Export/Backup Wallet** - File download APIs for exporting wallet data aren't available in WebView

### Files Introduced

| File | Purpose | Detection Method |
|------|---------|------------------|
| `patches/android-ui.css` | Full-width layout for mobile | CSS overrides |
| `patches/hide-sidebar-button.js` | Hides panel toggle button in header | SVG icon detection (rect + line elements) |
| `patches/hide-mcm-import.js` | Hides "Import MCM File" in Add Account | Text matching ("import mcm") |
| `patches/hide-export-wallet.js` | Hides Backup section in Settings | Text matching ("Export Wallet", "Backup" heading) |

### What Each Patch Hides

**hide-sidebar-button.js:**
- Panel toggle button in the header (right side, after network status indicator)
- Detection: Buttons in header with SVG containing `<rect>` and <=2 `<line>` elements (excludes menu icon which has 3 lines)

**hide-mcm-import.js:**
- "Import MCM File" option in the Add Account dialog
- Detection: Buttons with text/aria-label containing "import mcm"

**hide-export-wallet.js:**
- "Export Wallet" button in Settings
- "Backup" heading (h2/h3/h4)
- Description text containing "export your wallet"
- Detection: Text content matching

### How Patches Are Applied (Automated)

The build scripts (`build.ps1` / `build.sh`) automatically:

1. Copy patch files from `patches/` to `android/app/src/main/assets/`
2. Inject script/link tags into `index.html` in this order:
   - `polyfills.js` (required)
   - `hide-sidebar-button.js`
   - `hide-mcm-import.js`
   - `hide-export-wallet.js`
   - Main bundle
   - `android-ui.css`

If any patch file is missing, the build continues without it.

### Technical Implementation

All JavaScript patches use:
- **MutationObserver** - Re-applies hiding when DOM changes (SPA navigation)
- **Marker attributes** - Prevents re-processing already-hidden elements (`data-android-hidden-*`)
- **Timed retries** - Multiple scans at 200ms, 500ms, 1000ms, 2000ms after load
- **display: none !important** - Ensures elements are hidden

### Disabling Patches

To disable any patch:
1. Remove or rename the file in `patches/`
2. Rebuild with `build.ps1` or `build.sh`

Or manually delete from `android/app/src/main/assets/` and remove the script tag from `index.html`.

### Debugging

Patches log to console when hiding elements:
```
[Android Patch] Hidden panel button
[Android Patch] Hidden export element: BUTTON Export Wallet button
```

View logs with:
```powershell
adb logcat -v time | Select-String -Pattern "\[Android Patch\]"
```

### Notes

- Patches are **optional** but recommended for a clean mobile experience
- No color/typography changes are made - only visibility
- Patches target specific elements to avoid breaking other UI components
- CSS `:has()` selector is NOT used (not supported in older Android WebView)
