# Stage 1 manual test

Use fabricated information only while validating this development scaffold.

1. Launch with `..\` paths avoided: from the project root run ` .\tool\flutter.ps1 run -d windows`.
2. Confirm the intro states that records stay local and account screens are demo-only.
3. Get started → enter an invalid email; confirm the validation message.
4. Sign up with `shop@example.test`. Confirm the dashboard shows a two-column grid.
5. Load sample data twice. It must report 12 payments, not 24. No analysis results should appear yet.
6. Close and reopen the app. Confirm the demo session and sample count persist.
7. Open Customer performance. In free demo mode the paid gate appears. In Settings switch Preview paid plan on, return and open the card; it now shows the Stage 3 placeholder. No charge occurs.
8. Change appearance to dark, light and device default. Restart; the selection persists.
9. Log out; log back in with the same demo email. Samples must remain. A different email must not access/create another profile over existing data.
10. Settings → Clear cache. Confirm completion; the 12 sample records remain.
11. Settings → Delete all data / clear cache → Cancel. Confirm records remain.
12. Confirm deletion. Check the completion message and return to intro. Restart; no account, sample payments, paid preview or theme preference should remain.
13. Resize the window narrowly and test on Android later. Cards should still form two columns without overflow. Check keyboard navigation and readable text with increased system text size.
14. Optional real-device plugin check: ` .\tool\flutter.ps1 test integration_test/storage_smoke_test.dart -d windows`. This writes only a fabricated probe into the development app database.

Automated tests cover encrypted bytes, wrong-key rejection, persistence, idempotent
fixtures, key rotation, cache vs full wipe, preserving a file outside the app folder,
missing-key lockout, UI flow, entitlement and disabled AI. Parser/drop-off tests will
arrive with Stages 2 and 3, using fabricated statements.
