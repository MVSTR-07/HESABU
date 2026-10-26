# BizLens · HESABU

Private on-device data analysis for small businesses in Kenya. Flutter/Dart,
Windows first and Android next. **Stage 1 scaffold only.** BizLens is a placeholder
product name; the repository remains HESABU.

## Run from VS Code

Open this folder in VS Code and install the recommended Flutter extension.
This machine's Flutter SDK is at `a local Flutter SDK`. The wrapper below
finds either that SDK or a normal Flutter installation on PATH.

```powershell
.\tool\flutter.ps1 doctor -v
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
.\tool\flutter.ps1 run -d windows
```

If Flutter is on PATH these are standard `flutter` commands. A Windows run/build
requires Developer Mode and Visual Studio with **Desktop development with C++**,
including CMake, MSVC, a Windows SDK and **C++ ATL for the installed toolset**
(required by Windows secure key storage). VS Code is the editor; it does not replace
these native compiler tools. Android later requires the Android SDK and a device.

## What Stage 1 includes

- Intro, local demo sign-up/login, dashboard and Settings.
- Tool cards registered in one list and displayed in two columns; tools show their
  planned stages instead of pretending to analyse data.
- Clearly labelled free/paid demo gating; no real subscriptions or payments.
- SQLCipher encrypted SQLite with a random key protected by device secure storage.
- Confirmed full deletion, cache-only cleanup, light/dark/device themes, KES and Kenyan dates.
- Twelve fabricated demo payments to verify storage, with no real statement imports.
- A disabled, removable AI interface and no runtime server/network integration.

Windows data lives in `%LOCALAPPDATA%\BizLens\private`, **not this OneDrive folder**.
Android backups and device transfer are excluded. Never commit real statements,
databases, keys, exports or customer information to this repository.

## Test and development

See [the manual checklist](docs/stage_1_manual_test.md) and
[architecture and privacy boundaries](docs/architecture.md). Automated tests use
fabricated data and disposable test folders. The separate integration test exercises
the real device vault and should be run only on a development device/profile.

`flutter clean` removes rebuildable project outputs when you finish diagnosis.
Keep `pubspec.lock` and the installed Flutter SDK: they are useful development
dependencies, not disposable build leftovers. Never use broad disk cleanup.

**Stop after Stage 1 for manual testing.** Stage 2 (M-Pesa parsing and analysis)
starts only when explicitly requested.
