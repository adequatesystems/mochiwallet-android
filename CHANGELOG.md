# Changelog

All notable changes to mochiwallet-android will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
