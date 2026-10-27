# Stage 2 manual sign-off

Stage 1 is signed off. Stage 2 is ready for Windows manual testing; Canva styling
and Stage 3 remain postponed. Use fabricated data first. Deletion tests erase
saved app data, so do not import a real statement until finished.

## Launch and sample imports

```powershell
.\tool\flutter.ps1 run -d windows
```

1. Navigate Intro, demo account, dashboard and Settings as before. Open M-Pesa
   Statement Analyser. Confirm “Your data stays on this device”.
2. Select **Use fabricated CSV**. Confirm 23 source rows, 22 unique transactions and
   one excluded exact duplicate. Inspect all transaction categories, including
   Fuliza, reversals and the explicitly unclassified adjustment.
3. Check these totals (money movement includes loans/reversals, not profit):

| Output | Expected |
|---|---:|
| Money in | KES 266,210.00 |
| Money out | KES 19,927.00 |
| Net | KES 246,283.00 |
| Identified fees, including Fuliza cost | KES 127.00 |
| Fuliza cost (a subset of fees) | KES 70.00 |
| Last observed balance | KES 266,283.00 |

4. Select **Use protected sample PDF**. Cancel once; navigation must unlock.
   Retry with an incorrect password: a clear error appears, no report is saved.
   Retry using `demo-only-2026`: the totals must match the CSV. This password
   belongs only to the fabricated sample; real passwords are never saved/logged.
5. Test the native file chooser with `sample_output/fabricated_mpesa.csv` and
   `sample_output/fabricated_mpesa_protected.pdf`. Re-importing the identical file
   must reuse its saved record. The original files must remain untouched.
   Also try `sample_output/fabricated_mpesa_column_layout.pdf` (same public
   password). Its two portrait pages have a summary, blank amount cells and
   wrapped text; every total must match the CSV. After these checks, retry your
   own PDF locally and compare a few incoming/outgoing rows and totals against
   the original. Do not upload the statement or password.
   If the import fails, the on-screen `PDF layout diagnostic` gives the page,
   candidate row and affected column names without transaction values. Share
   only that diagnostic text or a crop of the error so the mismatch can be
   reproduced with fabricated data.

Generate those fabricated files if needed:

```powershell
dart run tool/export_mpesa_sample.dart
```

## Inspect analysis and persistence

6. Switch Day / Week / Month. Inspect cash chart and exact period table, busiest
   days/hours, top senders/receivers, balance chart, anomaly list and transaction
   pages. Check both themes and a smaller window. Thursday and 10:00 each have
   six unique transactions in the fabricated sample.
7. Confirm duplicate, unusual-spike and large-one-off flags appear. Raise the
   large threshold to KES 10,000,000 and spike multiplier to 2001, apply, and
   confirm only the duplicate remains. Invalid/negative thresholds must show an
   error. Restore defaults: KES 100,000; multiplier 3; minimum KES 1,000;
   baseline count 3.
8. Close the app completely, reopen, and select saved CSV/PDF reports. Confirm
   totals and transactions are readable and saved thresholds are retained.

## Failures and deletion

9. Choose an empty CSV, unrelated CSV, unrelated PDF, corrupt PDF and scanned
   image-only PDF. Each must show a useful error without crashing or saving a
   partial report. An unsupported PDF layout should suggest CSV. A cancelled
   chooser must leave existing reports alone.
   For the full statement, verify its overall money-in/money-out totals against
   the original summary and inspect incoming/outgoing/fee rows on early, middle
   and late pages. A successful import alone is not financial reconciliation.
   Ruled tables now use physical cell borders; if any descriptions lack PDF
   text, those rows remain visible as unavailable/unclassified with a warning.
10. Settings → **Clear cache**: cancel first and confirm reports remain. Then
    confirm cleanup. Return to M-Pesa: no imports/results/history remain. Close
    and reopen to verify. Demo account/theme remain; original selected files
    remain. This button deliberately clears M-Pesa reports as well as cache.
11. Import a fabricated sample again. Settings → **Delete all data**: confirm.
    The account, settings, legacy sample payments, imports, results and cached
    files must disappear. A new empty encrypted database is created. Reopen and
    confirm there are no saved reports; original files remain untouched.

Report any failing step before signing off. Android is not signed off: its SDK
and device checks have not run. Do not start Stage 3 until the user confirms.

## Automated checks

```powershell
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test --concurrency=1
.\tool\flutter.ps1 test integration_test/mpesa_storage_test.dart -d windows
```

The native test uses its own disposable database and its own Windows secure-vault
key. It does not wipe the application's production database or key.
