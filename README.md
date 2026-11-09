# HustleLink

HustleLink is a Flutter application project. The shared Dart application code is suitable for
Android, iOS, web, Windows, macOS and Linux. This repository currently includes the Android
runner and an Android APK GitHub Actions workflow.

## Requirements
- Flutter stable SDK (the included GitHub Actions workflow uses Flutter 3.29.0)
- Android Studio and Android SDK for Android builds
- Xcode for iOS/macOS builds (macOS only)
- Platform-specific toolchains for Windows and Linux desktop builds

## Resolve packages and run
From the project root:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run
```

## Generate the other platform runner folders
If you want to build for iOS, web, Windows, macOS or Linux, generate the missing platform
folders with the Flutter SDK:

```bash
flutter create --platforms=android,ios,web,windows,macos,linux .
flutter pub get
```

Then run for a selected target, for example:

```bash
flutter devices
flutter run -d chrome
```

## Android release APK
```bash
flutter build apk --release
```

The GitHub Actions workflow at `.github/workflows/build.yml` builds and uploads the Android APK
as an artifact when manually triggered.

## Dependencies
- `go_router`: declarative routing and the stateful bottom-navigation shell
- `provider`: dependency injection and view-model state access
- `google_fonts`: Space Grotesk typography
