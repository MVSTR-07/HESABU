# HESABU Windows smoke check

The project owner has already signed off Stage 1. This short checklist is useful
when checking a fresh build or reviewing the app in a job interview. Use
fabricated information only.

```powershell
.\tool\flutter.ps1 run -d windows
```

1. Confirm the window and app identity say **HESABU**.
2. Move through the intro and local demo sign-up/log-in screens. Confirm they
   explain that authentication is a demo and request no password.
3. Open the dashboard, M-Pesa analyser, Customer performance and Settings.
   Confirm the tools open and the navigation remains usable at a narrow window
   size.
4. Load the built-in fabricated sample data and confirm the summary appears.
5. Close the whole app and open it again. Confirm saved sample data is still
   readable.
6. Use **Clear cache** and confirm the saved sample data is removed while app
   preferences remain.
7. Use **Delete all data / clear cache** only if you are ready to remove the
   local demo records, account state and preferences. Confirm the app reports
   completion and returns to an empty local workspace.

Do not select a real statement during a public demo or screen recording.
