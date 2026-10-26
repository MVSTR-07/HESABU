# Stage 1 validation · 26/10/2026

Environment: Windows 10, Flutter 3.47.8 stable, Dart 3.13.7.

- `flutter pub get`: passed after Windows Developer Mode was enabled.
- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: 11 tests passed, including encrypted SQLCipher files,
  wrong-key rejection, persistence, cache-only deletion, full deletion/key rotation,
  symlink-safe cleanup, preserving original files outside the app folder, lost-key
  lockout, disabled AI, demo gating and narrow-screen/large-text navigation.
- `flutter test --no-pub tool/render_preview.dart`: passed. Generated fabricated
  intro, dashboard, dark dashboard and settings previews for visual inspection.
- `flutter build windows --debug --no-pub`: blocked because the Visual Studio
  Windows C++ toolchain is not installed. No Windows executable was produced.
- Real-device secure-storage integration test: not run; requires that toolchain.
- Android build/device testing: not run; Android SDK is not installed.

SQLCipher prints native HMAC/decryption diagnostics during the deliberately wrong
key test. That test passes only when the wrong key is rejected.

These checks do not replace manual testing or a production security review.
Account sign-up/login and subscription status are local demo stubs only.
Stage 2 is not implemented.
