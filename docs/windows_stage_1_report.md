# Stage 1 Windows verification · 26/10/2026

**Automated Windows checks passed. User acceptance is still pending.**
Canva styling and Stage 2 have not started.

## Toolchain and build

Installed Visual Studio Build Tools 2026 18.11.2 with the C++ desktop workload,
MSVC, CMake, Windows SDK 10.0.26100.0 and C++ ATL. The initial native build exposed
a missing `atlstr.h`; adding the ATL component fixed that error. The installer
and vswhere reported that no restart is required.

Flutter 3.47.8 / Dart 3.13.7 and Windows/Visual Studio are green in
[the full doctor output](evidence/flutter-doctor-windows-installed.txt).
The only remaining doctor issue is the Android SDK, outside this Windows stage.

`flutter run -d windows` built `build/windows/x64/runner/Debug/bizlens.exe` and
opened the normal application. The compiled app is left open for manual testing.
Keep its complete Debug folder; the executable needs its adjacent runtime files.

## Real Windows key and database persistence

1. The native integration test used `DeviceKeyVault` / `FlutterSecureStorage`
   and SQLCipher, not an in-memory vault. It checked that the key is 256 bits,
   survives reopening and decrypts a persisted fabricated probe. The database
   file has no plain SQLite header or readable probe text.
2. That test saved 12 fabricated sample payments. Its process ID was **36424**,
   and process exit was confirmed. [Native test output](evidence/windows-secure-storage-test.txt).
3. The normal application was launched separately and displayed **12 fabricated
   demo payments stored locally**. [Native UI text](evidence/windows-ui-before-close.txt).
4. That normal app process (**36008**) was fully closed. The database hash after
   closure matched the database saved by the native test:
   `CDE3245998D2493519DA39879DBD63B5BA19655FCF1ECEB883F8C4813CF60F29`.
   [Closed-process/hash record](evidence/database-before-normal-app-close.json).
5. A new normal app process (**35612**) opened and displayed the same 12 samples,
   without a storage error. [Relaunch result](evidence/windows-relaunch-result.json)
   and [native UI text](evidence/windows-ui-after-relaunch.txt).
6. The standalone compiled executable was also opened for the user's manual
   testing, again showing the persisted 12 samples.
   [Standalone UI text](evidence/windows-standalone-ui.txt).

This verifies persistence across actual process exits, not just a hot restart.
No encryption key, plaintext password, database contents or real business data
is included in this report. Native screenshot capture timed out, so the evidence
is native integration assertions, process/hash records and live accessibility text.

## Authentication and subscription audit

The account and plan controls are explicitly labelled **local demo** in the UI.
The controller has `TODO(real-auth)` and `TODO(real-subscription)` markers, and
the account screen repeats the auth TODO. No password field, password argument,
password file, password logging or password persistence exists in these stubs.
Only email and local demo session/entitlement settings are stored in the encrypted
database. Unit tests assert the exact identity/plan keys. No auth server or payment
service is connected.

## Checks and manual acceptance

- Static analysis: no issues.
- Unit/widget suite: **11 passed**, including encryption, wrong-key rejection,
  safe deletion, key rotation, demo gating and narrow-screen/large-text layout.
- Native Windows storage integration: **passed** using the real device vault.
- Normal Windows build/run and full-process reopen: **passed**.
- Manual UI acceptance and native Delete all data interaction: **awaiting user**.

The verification profile is `stage1@example.test`, with 12 fabricated payments.
Use the [manual checklist](stage_1_manual_test.md). After a confirmed full reset,
an empty encrypted database file is recreated; all old records and demo settings
must be gone. Do not start another stage until the user confirms the checklist.

Commands from the project root:

```powershell
.\tool\flutter.ps1 doctor -v
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
.\tool\flutter.ps1 test integration_test/storage_smoke_test.dart -d windows
.\tool\flutter.ps1 run -d windows
```
