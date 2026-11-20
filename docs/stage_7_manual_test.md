# Stage 7 manual test checklist

1. Create a workspace and a named analysis session. Confirm both remain after
   navigating away and back. Completing a session must not delete any records.
2. Load the fabricated supported-statement, sales, expense and debtor/creditor
   samples.
3. Open **Export reports** and confirm the description lists local visual
   summaries, supported-statement movement, flags and balances.
4. Choose **Save PDF**. Use the device save dialog and open the saved file.
   Confirm the title, highlighted section headers, key-number cards, circular
   money-in/out chart and monthly bar chart appear without raw transaction rows.
5. Choose **Save Excel** and confirm the key metrics and monthly cash-flow rows
   are present.
6. Cancel either save dialog and confirm HESABU reports that no export was
   saved and no data is removed.
7. Use **Clear cache** in Settings, reopen reports and confirm imported results
   no longer appear. Original source files outside HESABU remain untouched.
   Workspace/session labels remain as local organisation metadata; **Delete all
   data / clear cache** removes those too.

Use fabricated data for screenshots or demos. Saved report files are chosen by
the user and are outside HESABU's encrypted database, so store or share them
carefully.
