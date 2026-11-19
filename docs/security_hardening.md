# HESABU security hardening

I use defense in depth rather than relying on a single hidden folder or a
client-side premium flag.

## Current controls

- Business data is stored in SQLCipher with a random key held by platform
  secure storage.
- Android cloud backup and device transfer are disabled for HESABU data.
- Android uses `FLAG_SECURE`, preventing screenshots, screen recording and
  task-switcher previews of business screens.
- Imported files are read into memory and are not copied to a plaintext cache.
- PDF passwords are held only in memory during the import attempt.
- Startup and import errors are deliberately redacted and never logged with
  paths, statement contents, passwords or native exception text.
- Deletion removes the database key before deleting the database files. This is
  cryptographic erasure; flash storage may still retain physical blocks outside
  the app's control.
- No business-data network permission is present in the Android manifest.

## Release controls

Android release builds should be produced with:

```powershell
.\tool\flutter.ps1 build appbundle --release `
  --obfuscate --split-debug-info=build/symbols/android
```

The symbol directory is private build output and must never be committed. Keep
release signing keys outside the repository and use Google Play App Signing when
publishing.

Windows release packages should be code-signed before distribution. Signing
helps users verify origin; it cannot make a local executable impossible to
patch, so premium entitlement must still be checked with signed server state.

## Remaining limits

A rooted Android device or fully compromised Windows account can inspect data
while HESABU is unlocked. App hardening can raise the cost and reduce accidental
leaks, but it cannot defeat an attacker who controls the operating system.
