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

For a local build with profile-video storage enabled, provide the Supabase project URL and
publishable/anon key at build time:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

## Supabase profile-video storage

The worker's single 30-second profile video is stored in the public
`worker-proof-videos` bucket. The bucket's public setting allows playback; uploads and deletes
are performed through the `proof-video` Edge Function after it verifies the caller's Firebase
ID token. The Supabase secret key is used only by the Edge Function and must never be added to
the Flutter app or repository.

Deploy `supabase/functions/proof-video/index.ts` as an Edge Function named `proof-video`.
Set this custom Edge Function secret in the Supabase Dashboard:

- `FIREBASE_PROJECT_ID`: `hustlelink-483a9`

Supabase automatically provides `SUPABASE_URL` and the project's named secret API keys
through `SUPABASE_SECRET_KEYS`. The function reads the `default` key from that JSON value;
you do not need to add a custom `SUPABASE_SECRET_KEY` secret. If you need to view or create
the key, open **Settings → API Keys → Secret keys**. Keep it server-side only.

The function's `verify_jwt = false` setting is intentional: it validates Firebase ID tokens
itself rather than expecting Supabase Auth tokens. Keep that verification in place.

For GitHub Actions APK builds, add these repository Actions variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

These are public client configuration values, not secret keys. The build workflow remains
manual-only and does not run on every push.

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

## Engineering documentation

- [Software Engineering SOP & Quality Framework](docs/ENGINEERING_SOP.md) — reusable project lifecycle, issue handling, review and release checklists.
- [HustleLink Quality Register](docs/HUSTLELINK_QUALITY_REGISTER.md) — categorized history of issues, fixes, decisions, outstanding work and lessons from this project.
- [Admin Dashboard Setup](docs/ADMIN_DASHBOARD_SETUP.md) — module scope, role permissions, backend deployment and required Firebase configuration.

## Dependencies
- `go_router`: declarative routing and the stateful bottom-navigation shell
- `provider`: dependency injection and view-model state access
- `google_fonts`: Space Grotesk typography
- `supabase_flutter`: Supabase Storage and Edge Function client
