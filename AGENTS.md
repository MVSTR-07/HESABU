# Project instructions

- The confirmed repository name is HESABU, owned by MVSTR-07 on GitHub.
- Do not delete anything outside this project unless the user explicitly requests it.
- Clean up temporary files, unnecessary caches, and obsolete generated files left by builds, rebuilds, or diagnosis within this project when they are no longer needed.
- Preserve source files, user data, configuration, and useful deliverables. Do not treat an unfamiliar file as unnecessary without evidence.
- Before recursive cleanup, verify the resolved target path stays inside this project.

## BizLens implementation
- Flutter/Dart only; Windows first, Android second. BizLens is a placeholder product name; HESABU remains the repository name.
- Work one stage at a time. Explain files and run/test commands before coding; stop after each stage for manual testing and explicit instruction to continue.
- Business data must stay on-device in encrypted SQLite, outside synced folders. Never upload statements, customers, transactions, results, or diagnostic data containing them.
- Base analysis is pure local Dart, with no AI or network dependencies. Optional paid AI stays disabled behind an interface until Stage 6; explicit per-request consent is required before any transmission.
- A future account service may store email and subscription status only. Stage 1 uses clearly marked local demo account/subscription stubs.
- Include confirmed local database/cache deletion, KES, dd/MM/yyyy, light/dark themes, fabricated samples, and meaningful privacy/storage tests.
- Keep lib/core pure Dart; lib/data handles storage; lib/features owns tools; lib/ui holds shared widgets; lib/ai contains the removable disabled interface.

## Confirmed GUI reference
- Use the user's Canva design "HESABU desktop UI screens" (20 pages) as the visual reference: https://canva.link/ftnb5ru4rh22mj7 (design ID DAHZG3wZbPQ).
- The reference was accessed successfully through Canva. Its styling has not yet been applied to the Flutter scaffold.
- The user instructed us to wait for further instructions before interface changes or Stage 2. Finish only any outstanding Stage 1 work.
- Stage 1 now builds and runs on Windows. Visual Studio Build Tools 2026 with MSVC, CMake, Windows SDK and ATL is installed; no reboot required. Windows doctor checks, 11 unit/widget tests, static analysis and real Windows secure-storage integration test passed. See docs/validation.md and docs/evidence/.
- Stage 1 is NOT signed off until the user runs the manual checklist and explicitly confirms. Do not start Canva styling or Stage 2 before that confirmation.
