# Stage 1 architecture

BizLens is the temporary product name. HESABU is the GitHub repository.

## Boundaries

- `lib/core/`: pure Dart parsers, analysers, fixtures and result models. No Flutter, database or network imports. Future modules implement `ToolModule<Input, Result>` with `importData()` and `analyse()`.
- `lib/data/`: encrypted SQLite, private filesystem ownership and device key storage. `LocalStore` lets UI tests run without native plugins.
- `lib/features/`: onboarding, demo identity, dashboard, settings; each future tool gets its own folder here. Cards come only from `features/tools/tool_registry.dart`.
- `lib/ui/`: shared widgets, appearance and Kenyan formatting.
- `lib/ai/`: disabled interface. There is no provider implementation, network client or enable switch. Deleting this folder removes the optional interface without affecting base analysis.
- `lib/app_controller.dart`: local navigation, demo session, entitlement and settings state.

## Data flow and storage

UI → controller → LocalStore → SQLCipher. No business-data network path exists.
The only Stage 1 data is a local demo email/session, preferences, demo entitlement
and fabricated payment fixtures. No actual account service exists. The local demo
is not authentication or payment enforcement; anyone using the same device can
enter its demo email. Production auth and entitlement remain future work and must
not receive any business record, result, password or diagnostic payload.

The database is at `%LOCALAPPDATA%\BizLens\private\bizlens.db` on Windows,
outside this OneDrive-backed source tree. Android uses private application support
storage. Every database open requires the device-protected random 256-bit key;
keys are neither embedded nor written to source/plaintext settings. Losing the
key locks existing records instead of silently replacing them. The app verifies
SQLCipher availability and verifies the key before using the schema. Native
temporary SQL storage stays in memory. Business imports must not be copied into
public temporary/download folders in later stages.

Android release manifest has no Internet permission and disables cloud backups
and device transfer. Debug/profile manifests allow the Flutter debugger's local
network connection. No business information is transmitted by app code. SDK and
package downloads are development tooling, separate from the app's runtime.
User-controlled OS backup tools can copy local files; Windows users must not
configure cloud backup of the private data directory. SQLCipher still encrypts
those bytes at rest. No software can promise forensic deletion from SSD storage;
reset deletes app files and the old device key, then creates a fresh empty DB.

## Deletion

Cache-only cleanup removes `private/cache` and preserves the DB. Full reset closes
SQLite, removes only BizLens's key, deletes the contents of the owned private
directory (including journals and future cached imports), and generates a new key
and empty DB. It clears demo identity, plan and appearance. It does not delete
original user import files. Cleanup refuses paths outside the owned directory,
does not follow links, and reports success only after completing the operation.
Failure locks the UI. Startup offers a separate confirmed reset if a key is lost.

## Upcoming stages (not implemented)

2. `features/mpesa/` + pure Dart statement parsers and normalised transactions.
3. `features/customers/` + identity merging, RFM and adjustable drop-off logic.
4. Independent stock, sales and expense modules.
5. P&L, debts, imports/cleaning and exports.
6. Optional paid AI: explicit payload disclosure and consent for every send.

Do not build any next stage until the user has manually tested and approved it.

## Dependencies

SQLite configuration uses the SQLCipher build selected by sqlite3's native hooks:
https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md
Device key protection: https://pub.dev/packages/flutter_secure_storage
Windows build prerequisites: https://docs.flutter.dev/platform-integration/windows/setup
Review SQLCipher/OpenSSL and other dependency notices before distribution.
