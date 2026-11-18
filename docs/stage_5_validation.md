# Stage 5 validation

Validation completed 18 November 2026. All fixtures are fabricated; no imported
user files are part of automated validation.

- `dart format lib test` — completed.
- `.\tool\flutter.ps1 analyze --no-pub` — clean.
- `.\tool\flutter.ps1 test --no-pub --concurrency=1` — all 118 tests passed.
- `.\tool\flutter.ps1 build windows --release --no-pub` — passed.
- `.\tool\flutter.ps1 build windows --profile --no-pub` — passed after
  closing the earlier Profile app that held the output executable open.
- `git diff --check` — passed (Git only reported line-ending conversion notices).

Coverage includes Stage 5 P&L period calculations, obligation validation and
overdue logic, CSV/XLSX parsing and invalid rows, PDF/XLSX generation in memory,
encrypted debt persistence and clear-cache deletion. The app is open using the
new Profile build for the owner’s manual testing. Formal Stage 5 sign-off is
pending.

The Stage 5 narrow-screen widget test also checks that the tool-screen back
arrow returns to the dashboard.
