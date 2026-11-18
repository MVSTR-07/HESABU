# Stage 5 manual test checklist

Run HESABU on Windows:

```powershell
.\tool\flutter.ps1 run -d windows
```

Use fabricated records only if you need examples. The tests below may add
records to this device's encrypted HESABU database.

1. Open **Profit and loss**. Note the year-to-date totals, then open Sales and
   Expenses and compare them with the saved rows. Confirm it clearly says that
   stock cost, tax and unrecorded transactions are not included. Use the top-left
   back arrow to return to the dashboard.
2. Open **Debtors and creditors** and choose **Use fabricated balances**.
   Confirm the customer and supplier balances show separately. Add another
   balance, include a partial payment, then record another payment. Check that
   overpayment is rejected and a settled item is marked settled. Add a due date
   in the past and check the overdue marker. Delete a fabricated entry.
3. Open **Import and clean** and preview the fabricated CSV. Check that two rows
   are clean, one invalid date is called out with its row number, and values are
   visible before import. Import the rows and confirm they appear under Sales.
   Preview the fabricated Excel workbook too; real files are not needed.
4. If you have a suitable disposable CSV/XLSX, choose it and confirm that the
   preview appears before import. Cancel without importing and confirm existing
   records remain unchanged. Test an empty or unsupported file for a clear
   error. HESABU does not copy the source into its cache.
5. Open **Export reports**, save both PDF and Excel reports to a folder you
   choose, then open them and check the period, totals, open balances and basis
   note. Cancel one save dialog and confirm HESABU reports cancellation. Exports
   are copies you choose to keep; delete them yourself if no longer needed.
6. Close and reopen HESABU. Confirm imported sales, balances, and analysis
   remain readable.
7. Settings → **Clear cache** removes saved statements, customers, sales,
   expenses, stock, debts and cache files. Cancel the confirmation. Only confirm
   if all current HESABU data is disposable. The automated wipe test passed on a
   temporary database.
8. Settings → **Delete all data** is also destructive. It deletes the entire
   local profile and rotates the database key. Do not confirm unless you intend
   to erase the current profile.

Please report any issue or confirm Stage 5 sign-off before Stage 6 begins.
