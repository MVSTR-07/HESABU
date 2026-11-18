# Stage 5: Finance, imports and reports

## Local accounting records

P&L is calculated directly from the existing sales and expense tables. It
reports recorded sales minus recorded expenses for the selected period and
labels the result as an operating surplus. It intentionally does not infer
stock cost from inventory snapshots, M-Pesa movements, tax or unrecorded
transactions.

Debtor/creditor entries live in the additive SQLCipher schema version 4 table
`obligations`. The migration preserves all previous tables. Entries store the
party, note, original amount, paid amount, creation date, optional due date and
optional reference. Partial settlement updates the paid amount; overpayment is
rejected. Clear cache and full delete remove these records.

## Import and export

CSV and Excel (`.xlsx` and `.xls`) bytes are read from the selected file in
memory. The first worksheet is previewed, common columns are detected, rows
with invalid required values are skipped with row-number-only messages, and
the user confirms before the clean rows are saved transactionally into the
existing sales or expense tables. No source copy or plaintext temp file is
created. Only UTF-8 CSV is supported. The Excel reader uses `excel_plus` for
compatibility with the existing PDF parsing dependencies.

PDF and Excel exports are built in memory from local saved summaries and handed
to a platform save dialog. Exports are user-owned deliverables; HESABU does not
keep another cached copy. The PDF/Excel report contains year-to-date sales,
expenses, operating surplus and open debt balances.

## Files and validation

- `lib/core/finance/`: pure local P&L and obligation rules/models.
- `lib/core/imports/`: in-memory CSV/XLSX parser, cleaning and preview model.
- `lib/core/reports/`: in-memory PDF/XLSX summary generator.
- `lib/data/`: additive encrypted schema, batch writes and repository APIs.
- `lib/features/`: separate P&L, debt, import and report screens.
- `test/finance`, `test/imports`, `test/reports`, and device-store migration and
  deletion coverage use fabricated records only.

Run `.\tool\flutter.ps1 analyze --no-pub`,
`.\tool\flutter.ps1 test --no-pub --concurrency=1`, and
`.\tool\flutter.ps1 build windows --profile --no-pub` from the repository
root.
