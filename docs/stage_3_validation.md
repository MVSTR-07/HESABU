# Stage 3 validation, 27/10/2026

**Manual sign-off, 27/10/2026:** the user explicitly confirmed both the M-Pesa
Analyser and Customer Performance work. Stage 3 is signed off. Earlier pending
notes and checklists are retained as validation history.

- Final full unit/widget suite including the scoped PDF correction: 89 passed.
- Fifteen Stage 3 tests cover medians, strict configurable drop-off boundaries,
  RFM segments, totals, future dates, retention/churn, concentration, contacts,
  sales CSV validation, overlapping statement deduplication, merges/undo,
  encrypted persistence/deletion and desktop/narrow widgets.
- Native Windows customer test passed using a separate real secure-vault key
  and disposable encrypted database. Reopening, merge undo, clear cache and full
  key-rotating deletion passed. It did not change the user's production profile.
- Normal Windows app built in 17.4 seconds and launched successfully with
  url_launcher registered. Static analysis was clean before the scoped PDF fix.
- Final regression suite after the scoped correction passed all 89 tests and
  static analysis was clean. `flutter clean` removed obsolete build/test outputs;
  a fresh normal Windows build passed in 84.4 seconds, synced in 302 ms and
  launched. The normal executable was reopened standalone for manual testing.
- Calling/SMS device handlers were not invoked with fabricated numbers. URI
  construction and no-handler UI are implemented; manual device verification
  remains in the checklist. Android SDK/device validation remains pending.
- A user-authorised single-page PDF follow-up found the centred-header cause;
  invented regression and real PDFium tests passed. The provided page parsed
  41 rows in memory; no transaction values or document exports were printed or
  saved. The temporary probe source was removed. Full-statement compatibility
  is not signed off. Local source deletion was blocked by automatic approval
  review; the user was explicitly told to remove that Downloads file manually.

The validation outcomes above are the retained evidence summary. Raw console
captures were removed because they included machine paths and diagnostic metadata.
Follow `stage_3_manual_test.md` for the manual checklist history.

27/10/2026: the user authorized Stage 4 after checkpointing the completed work.
