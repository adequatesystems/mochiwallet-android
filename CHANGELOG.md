# Changelog

All notable changes to mochiwallet-android will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.18] - 2026-01-03

### Changed
- **Production release** for Google Play Store submission
- Incremented `versionCode` to 19 (required for Play Store upload)
- Removed "beta" designation from version name

### Fixed
- **External link security**: Implemented `shouldOverrideUrlLoading()` to force all external URLs (http/https) to open in the device browser. This critical security fix prevents external content from loading within the WebView's permissive environment.

### Removed
- **CAMERA permission**: Removed unused camera permission that was reserved for future QR scanning feature. Permissions should only be requested when features are implemented.

### Security
- External URLs now properly isolated from WebView JavaScript bridge
- Only local `file://` URLs permitted within WebView
- Unsupported URL schemes are blocked with logging

## [0.0.18-beta.4] - 2026-01-03

### Fixed
- **Edge-to-edge display issue**: Fixed content overlapping with status bar on Android 15 devices. The app now properly handles window insets to prevent the wallet UI from drawing behind system bars.

### Technical Details
- Added `WindowCompat.setDecorFitsSystemWindows(window, false)` to enable proper edge-to-edge handling
- Implemented `setupWindowInsets()` to apply appropriate padding based on system bar dimensions
- Maintains backward compatibility with Android 7.0+ (minSdk 24)

### Added
- Play Store assets and screenshots now included in repository

## [0.0.18-beta.3] - 2026-01-01

### Changed
- **Updated targetSdk to 35** (Android 15) to meet Google Play Store requirements
- Updated compileSdk to 35

## [0.0.18-beta.2] - 2026-01-01

### Fixed
- **External links now open in device browser**: Links to external sites (e.g., Mochiscan transaction viewer) now open in the device's default browser instead of within the WebView. This allows users to return to the wallet app using the back button or app switcher, rather than being trapped in an external webpage with no navigation controls.

### Technical Details
- Added `shouldOverrideUrlLoading()` method to `WalletWebViewClient` in `MainActivity.kt`
- Local `file://` URLs continue to load within WebView (required for wallet functionality)
- External `http://` and `https://` URLs launch via `ACTION_VIEW` Intent

## [0.0.18-beta.1] - 2025-12-31

### Added
- Initial beta release for Google Play Store
- Release build configuration with signing support
- ProGuard minification and resource shrinking
- GitHub Actions workflow for automated release builds
- Play Store assets (icon, feature graphic, screenshots)

### Changed
- Updated to versionCode 18, versionName 0.0.18-beta.1
- Configured targetSdk 34 for Android 14 compatibility

## [0.0.17] - Previous Release

- Development version prior to Play Store preparation
