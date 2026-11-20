# Stage 6 manual test checklist

1. Start HESABU and sign in to the local demo profile.
2. Open **Settings**. Confirm **Optional AI controls: off** on a new install.
3. Turn on **Enable optional AI controls**. Confirm the wording still says no
   provider, API key, endpoint or network client is installed.
4. Select **Preview consent screen**. Confirm it names a future provider,
   shows the fabricated preview and lists only that fabricated summary.
5. Choose **Keep data on this device**. Confirm the dialog closes with no
   response/result and normal M-Pesa/customer/Stage 4/5 features still work.
6. Reopen the preview and choose **I understand — send listed data**. Confirm
   the dialog simply closes: this build has no provider, so nothing can send.
7. Use **Delete all data / clear cache**, restart HESABU and confirm the local
   AI controls are off again along with the rest of the local profile.

Do not use a real statement or customer data to test the preview; it is designed
to use fabricated text only.
