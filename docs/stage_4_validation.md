# Stage 4 validation: stock, sales and expenses

The three analysers are implemented. Automated validation passed:
the pure-Dart analysis tests, encrypted-storage persistence and cleanup tests,
static analysis, and a Windows profile build. The project owner approved Stage 4
on 18 November 2026. Stage 5 has not started.

This release candidate also changes the app's package identity and Windows
storage location to HESABU. On first launch it migrates the existing encrypted
Windows key store and database without reading or replacing their contents. If
both old and new locations contain data, startup stops and preserves both
copies. The migration is tested against a disposable database and then checked
against the existing local workspace before this release candidate is accepted.

Current checks:

```powershell
.\tool\flutter.ps1 analyze --no-pub
.\tool\flutter.ps1 test --no-pub --concurrency=1
.\tool\flutter.ps1 build windows --profile --no-pub
```

## Results, 18/11/2026

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --concurrency=1`: all **108 tests passed**.
- `flutter build windows --profile --no-pub`: passed and produced
  `HESABU.exe`; Windows file metadata and window title say HESABU.
- The migration test verifies that an encrypted database and its stored
  settings survive a move to the HESABU directory and filename.
- The rebuilt app migrated the existing Windows key store and encrypted
  workspace, then opened the saved dashboard. No data was reset or reseeded.
- The old and new locations were checked after migration; only the new database
  and key-store locations remain.
- Android device validation remains pending.

The [Stage 4 checklist](stage_4_manual_test.md) is retained for repeat manual
checks. This approval does not authorize Stage 5.
