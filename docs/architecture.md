# HESABU architecture and privacy

## How the app is organised

- `lib/core/` contains Dart-only parsers, analysis rules, sample data and result
  models. It has no Flutter UI or network dependency.
- `lib/data/` owns the encrypted SQLite database, device key and repositories.
- `lib/features/` contains the screens and workflows for each tool.
- `lib/ui/` contains shared navigation, formatting, widgets and themes.
- `lib/ai/` contains only a disabled interface. No provider or network client is
  connected.

Screens call local repositories; those repositories use SQLCipher. There is no
business-data server path. The demo account and paid-plan switches are local
placeholders, not real authentication or billing.

## Local storage

The database is encrypted with SQLCipher. A random key is held by the operating
system's protected storage, not in the project or database. Windows stores the
workspace under the current user's local application data; Android uses private
app storage. Neither location belongs in a synced project folder.

On Windows, HESABU safely migrates the existing encrypted key store and database
to the HESABU application identity on first launch after the rename. The files
are moved without decrypting or logging their contents. If both old and new
locations contain files, the app stops with a storage error rather than replacing
either copy. A missing key also locks existing data instead of creating a new
key that would make the old database unreadable.

Imported files are read locally. Passwords are transient input and are never
stored or logged. Original files remain where the owner selected them. Saved
records and analysis results live in the encrypted database. No business data,
results or diagnostics are sent to a service. Optional AI remains off; any future
transmission would need a clear, per-request consent step.

## Cleanup and recovery

**Clear cache** removes saved app workspaces and cached imports while retaining
settings. **Delete all data** removes the app's local records and key, then makes
a fresh empty encrypted database. Both actions operate only within HESABU's
owned local storage. They do not remove original imported files. Cleanup avoids
following links outside the app directory and reports failure instead of
claiming a partial wipe succeeded.

The Windows rename migration keeps the previous encrypted files in place until
the new app can open them. It does not silently discard a conflicting copy.

## Analysis boundaries

The M-Pesa, customer, stock, sales and expense analysis runs in local Dart code.
The app uses KES and Kenyan date conventions. Customer contact actions require
an explicit tap and are handed to the device's phone or messaging app; HESABU
does not place calls or send messages automatically.

Account email and subscription status are the only data that a future account
service may store. No account service is currently connected. Android release
configuration disables cloud backup and device transfer; Android device testing
is still pending.
