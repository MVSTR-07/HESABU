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
- Visual Studio Build Tools 2026 18.11.2 installed with the C++ desktop workload,
  MSVC, CMake, Windows SDK 10.0.26100.0 and C++ ATL. The first build found missing
  `atlstr.h`; installing `Microsoft.VisualStudio.Component.VC.ATL` resolved it.
  Installer and vswhere confirm no reboot is required.
- `flutter doctor -v`: Flutter and Windows/Visual Studio checks are green.
  Only Android SDK setup remains outstanding. Full output is in
  `evidence/flutter-doctor-windows-installed.txt`.
- `flutter run -d windows`: built `build/windows/x64/runner/Debug/bizlens.exe`
  successfully and launched the normal application.
- `flutter test integration_test/storage_smoke_test.dart -d windows`: passed
  against the real Windows secure-storage plugin and SQLCipher. It verified a
  256-bit device key, readable fabricated data after reopening, an encrypted file,
  and 12 persisted sample payments. Keys are never printed or exported.
- The native test process exited; the normal application then displayed those
  same 12 samples. The normal app was also fully closed (process exit confirmed)
  and relaunched for a second UI check. Process/hash/UI evidence is stored under
  `evidence/`. Native screen capture timed out, so this evidence uses the app's
  accessibility text and process records rather than synthetic screenshots.
- Auth and subscription remain visibly labelled local DEMO STUBS, with explicit
  TODOs for real verified auth/entitlements. There is no password field, password
  parameter, password persistence or password logging in those stubs. A test
  asserts the exact persisted identity/plan keys.
- Android build/device testing: not run; Android SDK is not installed.

SQLCipher prints native HMAC/decryption diagnostics during the deliberately wrong
key test. That test passes only when the wrong key is rejected.

Stage 1 is **awaiting the user's manual checklist and sign-off**. Native automated
verification is not the user's acceptance test. Canva styling and Stage 2 remain
on hold.

These checks do not replace manual testing or a production security review.
Account sign-up/login and subscription status are local demo stubs only.
Stage 2 is not implemented.
