# Stage 3 manual sign-off

M-Pesa PDF layout compatibility remains deferred, as the user explicitly
requested. Stage 3 can be tested without a statement. No Canva styling or Stage
4 work is included. Use fabricated data for deletion and contact testing.

```powershell
.\tool\flutter.ps1 run -d windows
```

1. Settings → enable **Preview paid plan**. This remains a free local demo
   switch, with no billing. Open **Customer performance** on the dashboard.
   Free-demo access should show the gate, not the customer report.
2. Select **Use fabricated customers**. Expect seven identities, including one
   name-only alias. The fabricated report should contain all five segments:
   Champions, Loyal, Promising, At Risk and Lost. Repeating the sample button
   on the same analysis date must not double the payments.
3. Inspect ranked clients, total/payment-count/average, first/last dates, days
   since payment, median gap, R/F/M scores and the top-five concentration share.
   The sample's largest client is Wanjiku Demo. Inspect At Risk / Recently
   Dropped and historical monthly worth. Same-day repeats do not create a zero
   median gap; one-date histories show insufficient history.
4. Settings → customer follow-up settings: change default multipliers 1.5 / 3
   to 2 / 4, save, return to Customers and refresh. Confirm invalid values
   (zero, Lost lower than At Risk, or non-numbers) give an error. Flags use strict
   greater-than boundaries. Restore 1.5 / 3 and edit the `{name}` SMS template.
5. Select the Wanjiku Alias Demo identity and merge it into Wanjiku Demo.
   Confirm: one fewer identity, unchanged total spend, recomputed frequency/gap,
   and the destination name. Close/reopen the app: the merge must remain.
   **Undo last merge** restores both identities; up to twenty undo states persist.
6. Inspect monthly activity retention/churn bars and active/new counts. The
   previous month's active customers are the denominator; an empty baseline
   displays “—”. The current month is incomplete. Adjust **As of** to an older
   date: later payments must be excluded with a count, not treated as old data.
7. Inspect a **Contact this customer** dialog: number is prefilled and SMS text
   is editable. Close without calling/sending. Never contact fabricated sample
   numbers. For a real full phone number, an intentional Open phone / Open SMS
   action should open the device app and require the user's final call/send.
   Windows may have no compatible handler; show a useful message in that case.
   Masked/name-only identities have no contact action. Android device testing
   remains pending.
8. Import a fabricated sales CSV through **Import sales CSV**. Headers:
   `Date,Customer Name,Phone,Amount,Sale ID`. Kenyan phones support `07…`, `01…`,
   `254…` and `+254…`; a missing phone is allowed with a name. Dates support
   `dd/MM/yyyy` or ISO, with optional time. Amounts are positive KES. Re-import
   the same CSV: no doubles. Reuse an ID with a changed amount: clear error,
   unchanged dataset. Invalid dates/quotes/phone/amount must not partially import.

Generate a fabricated CSV (relative to today's date):

```powershell
dart run tool/export_customer_sample.dart
```

Output: ignored `sample_output/fabricated_customer_sales.csv`. The sample button
and generated CSV share IDs when exported on the same day. Do not import the same
real sale independently through M-Pesa and sales CSV: cross-source matching is
not guessed. Within saved M-Pesa statements, exact overlapping rows are excluded
and only classified customer receipts contribute; fees/Fuliza/reversals do not.

9. Settings → Clear cache: cancel first. Then confirm: customer sales, merges,
   M-Pesa imports and reports must disappear after reopening. Account/appearance
   and follow-up preferences remain; original selected files remain untouched.
10. Load samples again, then Delete all data: verify samples, profile, customer
    data and settings disappear. Test both themes and a narrow window.

Stop for the user's Stage 3 sign-off. Do not start Stage 4. The user subsequently
explicitly resumed PDF compatibility work; its validation remains separate.
