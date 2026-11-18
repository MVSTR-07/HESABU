# Stage 4: Stock, Sales and Expense analysers

All three tools use local pure-Dart analysis modules under `lib/core/`, a small
repository over `LocalStore`, and separate Flutter screens under `lib/features/`.
Their records are stored in three SQLCipher tables in the existing encrypted
database. Schema version 3 is added through migration; existing account,
appearance, M-Pesa and customer data is retained.

- **Sales:** manually enter/edit/delete dated product sales with quantity,
  unit price and optional customer. Summaries include KES revenue, records,
  units, average sale, top products and a daily trend.
- **Expenses:** manually enter/edit/delete dated category/description/amount
  records with optional payee. Summaries include totals, categories, monthly
  spend, average and largest expense.
- **Stock:** record opening units and cumulative receipts, sales and write-offs,
  unit cost and reorder level. Summaries include on-hand units/value, reorder
  and out-of-stock alerts, and fastest movers.

Each screen provides a fabricated-data action for local preview. Current Stage 4
does not import sales/expense spreadsheets; the CSV/Excel importer remains Stage
5. Inventory entries are snapshots with cumulative quantities, not a movement
ledger. The clear-cache action deletes Stage 4 records, M-Pesa imports/results,
customer workspace and cache files while retaining profile/theme settings.
Delete all data wipes the complete local profile and generates a fresh key.

No Stage 4 feature uses a server, network service or AI. The same Flutter screens
are used on Windows and Android; platform UI fit is covered by narrow-viewport
widget tests. Native Android build/device validation remains separate.
