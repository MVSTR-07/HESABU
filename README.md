# HESABU

Private on-device data analysis for small businesses in Kenya. Flutter/Dart,
Windows first and Android next. **Stages 2 and 3 manually signed off on 27/10/2026.**
HESABU is the application and repository name.

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
- Tool cards registered in one list and displayed in two columns; M-Pesa opens
  its analyser and later tools show their planned stages.
- Clearly labelled free/paid demo gating; no real subscriptions or payments.
- SQLCipher encrypted SQLite with a random key protected by device secure storage.
- Confirmed full deletion, import/cache cleanup, light/dark/device themes, KES and Kenyan dates.
- Twelve fabricated demo payments to verify Stage 1 storage.
- A disabled, removable AI interface and no runtime server/network integration.

Windows data lives in `%LOCALAPPDATA%\BizLens\private`, **not this OneDrive folder**. The internal storage location retains its original name so existing encrypted HESABU installs continue to find their data.
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

## Stage 2: M-Pesa

CSV and password-protected text PDF import, local classification, cash movement,
period charts/tables, busiest times, parties, fees/Fuliza cost, observed balance
and configurable anomaly rules. Sources and results stay in encrypted SQLite.
Clear cache now also removes saved M-Pesa imports/results; originals are untouched.

Follow [the Stage 2 checklist](docs/stage_2_manual_test.md) and read
[supported formats and analysis definitions](docs/stage_2_architecture.md).
Scanned PDFs need a CSV alternative. The Android bridge is implemented but has
not been device-tested. Existing UI styling is retained.

```powershell
.\tool\flutter.ps1 test --concurrency=1
.\tool\flutter.ps1 test integration_test/mpesa_storage_test.dart -d windows
dart run tool/export_mpesa_sample.dart
```

The last command exports both fabricated statement formats to ignored
`sample_output/`. Its public sample PDF password is `demo-only-2026`.
The generator source is in `tool/generate_mpesa_fixtures.py`; no real PDF/CSV
statement files belong in Git.

## Stage 3: customer performance

Local RFM, personalised drop-off, ranked clients, concentration, monthly
retention/churn, manual identity merges/undo, sales CSV import and intentional
phone/SMS composer actions. Enable **Preview paid plan** in Settings, then open
Customer performance and **Use fabricated customers**. No statement is needed.

See [the Stage 3 checklist](docs/stage_3_manual_test.md) and
[definitions/privacy](docs/stage_3_architecture.md).

**Stages 2 and 3 are signed off:** the user confirmed the M-Pesa Analyser and
Customer Performance work. Stage 4 (Stock, Sales and Expense analysers) is now
authorized; Stage 5 awaits Stage 4 manual sign-off.

## Appearance
The shared HESABU interface uses a dark-blue glass treatment on Windows and Android, with a selectable light appearance. UI ornament is drawn locally in Flutter; the separate Canva-generated artwork is reserved for advertising posters and is not an application background.
