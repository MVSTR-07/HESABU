# Stage 1 manual test

Use fabricated information only while validating this development scaffold.

The Windows verification leaves `stage1@example.test` as a local demo profile
with 12 fabricated payments. Log out to test introduction/login, or use the
confirmed full reset to start fresh before creating your own test profile.

1. From the project root run `.\tool\flutter.ps1 run -d windows` (or select **BizLens · Windows** in VS Code and press F5).
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
14. Optional real-device plugin check: `.\tool\flutter.ps1 test integration_test/storage_smoke_test.dart -d windows`. This uses the real Windows key vault and writes only a fabricated probe into the development app database.

## Sign-off

- [ ] Launch succeeds without a storage error.
- [ ] Intro, both Sign up / Log in tabs, Dashboard, every tool preview dialog and Settings open correctly.
- [ ] Demo warnings are visible; no password field or actual payment appears.
- [ ] Load samples, close the entire app, reopen: 12 samples are still readable.
- [ ] Cache-only cleanup preserves samples.
- [ ] Cancelling Delete all data preserves samples.
- [ ] Confirming Delete all data clears samples, account/session, plan and preferences, and displays completion.
- [ ] Reopen after deletion: introduction appears and a new demo profile starts with zero samples.
- [ ] Light/dark themes and a narrow window remain usable.

Full deletion intentionally creates a **new empty encrypted database**. A database
file remaining at `%LOCALAPPDATA%\BizLens\private\bizlens.db` after reset is
expected; old records must be gone. It does not delete original import files.

After completing the checklist, report **Stage 1 passed** or describe the failing
step. Do not start Canva styling or Stage 2 until the user explicitly confirms.

Automated tests cover encrypted bytes, wrong-key rejection, persistence, idempotent
fixtures, key rotation, cache vs full wipe, preserving a file outside the app folder,
missing-key lockout, UI flow, entitlement and disabled AI. Parser/drop-off tests will
arrive with Stages 2 and 3, using fabricated statements.
