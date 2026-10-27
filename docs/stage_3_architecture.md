# Customer performance and drop-off

`core/customers` is pure Dart. `CustomerSalesParser.parse` normalises a bounded
UTF-8 CSV (25 MB, 50,000 rows, strict quotes/headers/cents/dates). The analyser's
input is a payment list plus explicit analysis date/configuration; its output
models cover ranked customers, five RFM segments, drop-off and monthly activity.
No AI, remote analysis, statement upload, or account server was introduced.

`CustomerRepository` is a typed JSON workspace in the existing encrypted
SQLCipher settings table (`customer_workspace`). No plaintext sidecar, new key,
schema replacement or duplicate report cache is needed. Reports recalculate on
reopen. Clear cache erases this workspace before the database vacuum; full wipe
also destroys the old key. Sample, sales and M-Pesa data never enter Git. The
manual checklist documents independent-source duplicate limitations.

Full Kenyan phone numbers define the preferred identity; otherwise exact
normalised names are used. Masked numbers are not invented. Names alone do not
prove identity; confirmed aliases can be merged manually. Merges link identities
without changing original payments, reject cycles and support twenty undo
states. Exact M-Pesa fingerprints deduplicate overlapping saved statements.
Sales IDs deduplicate CSVs; conflicting IDs reject the whole batch. Without a
Sale ID, identity/date/amount define a fallback key; genuinely identical sales
need distinct explicit IDs to remain separate. Raw sales files are not retained.

Only positive classified M-Pesa customer receipts are included. Totals are gross
received customer payments, not profit or reversal-adjusted sales. Repayments,
Fuliza draws/costs, outgoing transfers and fees are excluded. Cross-source
duplicate/reversal matching is not guessed. Customer contact text is not a
verified address book; owners should review identities before following up.

Purchase gaps use the median of intervals between distinct Kenya purchase
dates, ignoring same-day zero intervals. Days since payment exceeding 1.5x is At
Risk; exceeding 3x is Lost, with adjustable positive multipliers and Lost > At
Risk. There is no invented personalised drop-off estimate for a one-date history.
Future-dated payments are excluded at the chosen analysis date.

RFM uses tie-aware percentile scores 1–5, reversing recency so recent is better.
Drop-off takes precedence; other customers are Champions when R/F/M >= 4, Loyal
when F >= 3, otherwise Promising. Rank computation is O(n log n), with cached
totals. Top-five concentration uses total received customer payments. Historical
monthly worth divides total by the active first-to-last purchase span, with a
one-month minimum. It is an estimate, not a revenue forecast.

Monthly retention is the previous calendar month's active customers who pay
again this month; churn is its complement. Missing months are included; a zero
denominator is undefined. Charts show up to 24 months, including the incomplete
current month. These are activity-based rates, separate from individual drop-off.
The new-customer activity count includes returning customers who were inactive
in the immediately previous month; it is not a first-ever acquisition count.

Contact actions open a validated `tel:` or `sms:` URI through the operating
system, only after an explicit user action. SMS text is editable, including the
saved `{name}` template; BizLens never sends an SMS or places a call automatically.
No server is involved. An unavailable Windows handler is reported. Android's SDK
and device checks remain pending. Optional AI is still disabled.

The user explicitly deferred Stage 2 PDF compatibility after one recurring
missing-Details error affected 91/153 pages. That issue remains a release blocker;
Stage 3 testing does not sign off Stage 2 PDFs. The user subsequently authorised
one scoped attempt with a supplied single page after Stage 3, followed by deletion
of that original local file. No full statement is needed or requested.

The scoped follow-up found a centred Details header was being treated as the
column's left edge, putting description words into the date field. The reader
now measures actual date/time text extents for that boundary. An invented
centred-header regression was added; the supplied page parsed 41 transactions
without printing any values or saving its contents. The temporary probe source
was removed. This does not sign off the whole statement or every layout variant.
Automatic approval review blocked deletion of the original supplied Downloads
file; the user was asked to delete it manually. No local document copies or
exports were created, and chat/service-side deletion is outside these tools.
