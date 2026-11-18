# Stage 4 manual test checklist

Run the Windows app:

```powershell
.\tool\flutter.ps1 run -d windows
```

1. Open **Sales analyser** from the dashboard. Use fabricated sales and check
   revenue, sale count, units, average, daily chart, product rankings and saved
   records. Close/reopen the app and confirm they remain. Add, edit and delete a
   sale; cancel a delete once, then confirm it.
2. Add a sale with a product, quantity, unit price, date and optional customer.
   Try blank product, zero/invalid quantity, invalid price and a future date;
   confirm the form explains the error and does not save an invalid record.
3. Open **Expense analyser**. Use fabricated expenses and check category and
   monthly totals. Add, edit, cancel deletion, then delete a fabricated record.
   Try blank category/description, invalid amount and a future date.
4. Open **Stock analyser**. Use fabricated stock and inspect on-hand/value,
   reorder alerts, out-of-stock items and fastest movers. Add/edit/delete an
   item. Confirm the form rejects negative/non-numeric values and sold plus
   damaged quantities above opening plus received units.
5. Resize the window narrow and scroll each of the three screens to the saved
   record section. Confirm rows remain readable, action menus work and no content
   is clipped. Repeat if available with larger text.
6. Settings → **Clear cache**. This deletes every saved M-Pesa import/result,
   customer record, sale, expense, stock item and cache file in this local
   workspace. Cancel once. Confirm only if everything currently saved here is
   disposable; otherwise skip the destructive confirmation. Automated deletion
   coverage uses a disposable encrypted database and has already passed.
7. Settings → **Delete all data** is also destructive: it removes the complete
   local profile and all local records. Only confirm in a disposable workspace
   or when you explicitly want that data erased. Automated full-wipe tests have
   already passed.
8. Check dark and light appearance. No real business records or statements are
   needed for this checklist.

Please stop here and report any issue or confirm Stage 4 sign-off before Stage 5.
