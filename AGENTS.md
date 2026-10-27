# Project instructions

- The confirmed repository name is HESABU, owned by MVSTR-07 on GitHub.
- Do not delete anything outside this project unless the user explicitly requests it.
- Clean up temporary files, unnecessary caches, and obsolete generated files left by builds, rebuilds, or diagnosis within this project when they are no longer needed.
- Preserve source files, user data, configuration, and useful deliverables. Do not treat an unfamiliar file as unnecessary without evidence.
- Before recursive cleanup, verify the resolved target path stays inside this project.

## HESABU implementation
- Flutter/Dart only; Windows first, Android second. HESABU is the product and repository name.
- Work one stage at a time. Explain files and run/test commands before coding; stop after each stage for manual testing and explicit instruction to continue.
- Business data must stay on-device in encrypted SQLite, outside synced folders. Never upload statements, customers, transactions, results, or diagnostic data containing them.
- Base analysis is pure local Dart, with no AI or network dependencies. Optional paid AI stays disabled behind an interface until Stage 6; explicit per-request consent is required before any transmission.
- A future account service may store email and subscription status only. Stage 1 uses clearly marked local demo account/subscription stubs.
- Include confirmed local database/cache deletion, KES, dd/MM/yyyy, light/dark themes, fabricated samples, and meaningful privacy/storage tests.
- Keep lib/core pure Dart; lib/data handles storage; lib/features owns tools; lib/ui holds shared widgets; lib/ai contains the removable disabled interface.

## Confirmed GUI reference
- Use the user's Canva design "HESABU desktop UI screens" (20 pages) as the visual reference: https://canva.link/ftnb5ru4rh22mj7 (design ID DAHZG3wZbPQ).
- The reference was accessed successfully through Canva. Its styling has not yet been applied to the Flutter scaffold.
- Canva styling remains postponed. Build only the currently authorized stage, using the existing screen style.
- Stage 1 now builds and runs on Windows. Visual Studio Build Tools 2026 with MSVC, CMake, Windows SDK and ATL is installed; no reboot required. Windows doctor checks, 11 unit/widget tests, static analysis and real Windows secure-storage integration test passed. See docs/validation.md and docs/evidence/.
- Stage 1 was signed off by the user and tagged stage-1. Stage 2 (M-Pesa only) is authorized. Keep the existing UI style; Canva styling is postponed. Stop for the user's Stage 2 manual sign-off before Stage 3.
- 27/10/2026: user explicitly deferred unresolved real M-Pesa PDF layout compatibility and authorized Stage 3 to conserve usage. Stage 2 PDF is NOT signed off for release. Implement Stage 3 using existing screens/style, then stop for manual testing. Stage 4 and Canva styling remain postponed.
- Latest instruction: user reaffirmed real M-Pesa PDF compatibility as a core requirement and resumed that repair after Stage 3 implementation. Do not substitute CSV/sample success for full-statement sign-off. Stage 3 still awaits manual sign-off; no Stage 4 or styling work.
- 27/10/2026 manual sign-off: user explicitly confirmed that both the M-Pesa Analyser (Stage 2) and Customer Performance (Stage 3) work. Stages 2 and 3 are now signed off. Prior pending/deferred notes are historical; the user's later authorization below supersedes the earlier Stage 4 hold.
- Styling is now explicitly authorised: dark-blue HESABU glassmorphism across Windows AND Android from shared Flutter widgets. Preserve signed-off features/data; retain a light option. Original Canva artwork MAHZMyd4628 is reserved for future ad posters, NOT an app background.

## Current styling milestone
- 27/10/2026: dark-blue HESABU glassmorphism is implemented through shared Flutter widgets for Windows and Android; Android splash resources match. The light theme remains selectable. The original generated Canva artwork remains reserved for advertising posters only and is not bundled into the app. Stages 2 and 3 remain signed off.
- 27/10/2026: user authorized proceeding to Stage 4 after a Git checkpoint. Implement Stock, Sales and Expense analysers, then stop for the manual test checklist and explicit sign-off. Stage 5 remains unauthorized until Stage 4 is signed off.
