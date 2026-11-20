# Stage 7: production-readiness polish

The first Stage 7 checkpoint strengthens HESABU's existing local report export.
It creates a consolidated visual report from already-calculated local results:
recorded sales/expenses, M-Pesa aggregate movement, flags for review and open
balances. The report includes visual KPI cards, a cash-in/out circle chart and
a monthly bar chart in its PDF output. Excel includes the same metrics and the
underlying monthly chart rows for inspection.

The exporter works in memory and opens the platform save dialog. It does not
upload records, send data to AI, or retain another report copy after export.
Raw statement rows and original source files are excluded from the consolidated
report by default.

## Source roadmap

The product-facing tool is the **Financial Statement Analyser**. M-Pesa is its
first connector, not its permanent boundary. New bank, wallet and card formats
will be implemented as provider-specific adapters that normalise their local
CSV/PDF exports into the same transaction/result models. Each adapter must have
fabricated fixtures and parser tests before it accepts a real layout.

Future direct POS access is a separate connector class, not a statement-file
shortcut: it will need an explicit vendor integration, local authorisation,
source identity, idempotent sale IDs and a reconciliation view against imported
financial statements. It must remain optional and must not turn the base app
into a cloud store of business data.

Later Stage 7 work will add local workspaces/sessions and these provider
adapters. The existing M-Pesa connector remains unchanged while the new
adapters are developed and tested with fabricated provider formats.
