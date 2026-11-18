# Customer performance and drop-off

`lib/core/customers` contains the pure-Dart CSV parser, customer models and RFM
analysis. The results include ranked customers, five segments, personalised
drop-off flags, concentration and monthly activity. No AI or remote analysis is
used.

## Records and identity

Customer data is kept as a typed workspace in the existing encrypted SQLCipher
database. Reports are recalculated when the app opens. Clear cache removes the
workspace; the original imported CSV remains in its original location.

Full phone numbers are the preferred identity. Otherwise, exact normalised names
are used. Owners can review and merge aliases manually; names alone do not prove
that two people are the same. Merges preserve original payments and can be
undone. The analyser avoids guessing links between customers, sales and
reversals.

Only positive classified M-Pesa customer receipts count as customer payments.
Totals are gross receipts, not profit. Purchase gaps use the median interval
between distinct purchase dates. Drop-off thresholds are configurable. RFM uses
tie-aware percentile scores; recent activity improves the recency score.

Monthly retention compares active customers from the previous month with those
who returned this month. Missing months are included; a month with no prior
customers has an undefined rate. Concentration estimates how much customer
income comes from the top five. It is a description of recorded activity, not a
forecast.

Contact buttons open the operating system's phone or SMS composer only after an
explicit tap. Message text is editable. HESABU does not send messages or place
calls automatically. Android device checks remain pending.

PDF parsing supports selectable text and validated table layouts; scanned PDFs
are not OCR'd. Use CSV export for unsupported layouts and validate additional
statement variants before release.
