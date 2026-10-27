# Stage 2 validation, 26/10/2026

**Manual sign-off, 27/10/2026:** the user explicitly confirmed that the M-Pesa
Analyser and Customer Performance work. Stage 2 is signed off; pending/deferred
notes below document the repair history, not the current sign-off status.

- Static analysis: no issues.
- Full unit/widget suite after baseline/whole-document diagnostics: 73 passed with
  `flutter test --concurrency=1`.
- Fabricated functional screen rendering: passed; previews visually inspected in
  `docs/previews/stage-2-*.png`. Existing themes/layout conventions retained.
- Fabricated password-protected PDF: rendered and inspected; every extracted
  transaction matches the CSV fixture in automated PDFium tests.
- Added a two-page encrypted portrait regression PDF with blank amounts, split
  timestamps, wrapped descriptions, summary and repeated headings. Every field
  matches the fabricated CSV; both rendered pages were visually inspected.
- The updated Windows storage test passed its portrait-PDF assertions. The
  runner then failed to connect while launching the second maintenance test;
  running that maintenance test alone passed. Actual app imports/results and
  cache were cleared and verified after reopening; profile/settings and original
  files were preserved. The one-off maintenance source was removed afterwards.
- After removing the one-off maintenance source, `flutter clean` removed old
  project build/test outputs. A fresh normal Windows build passed in 79.4
  seconds and launched successfully; the rebuilt app was left open for the
  user's own-statement retry. The retained Debug output is needed for testing.
- Native Windows integration: built successfully and passed after a fresh clean
  build (95.5 seconds). Real Windows vault entry, PDF password rejection,
  encrypted source/results persistence, Clear cache and full key-rotating wipe
  passed. The test used isolated temporary storage and a separate vault key.
- Git ignore verified for CSV/PDF, mixed-case extensions and real-data folders.
- Normal `flutter run -d windows`: passed after the user freed disk space.
  Built the normal application in 39.7 seconds, synced successfully and opened
  a responding BizLens window. Native accessibility inspection confirmed the
  dashboard loaded, existing 12 fabricated demo payments remained readable,
  and the M-Pesa tool was available. No runtime error appeared during launch.
- Android: SDK/device not available; native picker bridge not device-validated.

The validation outcomes above are the retained evidence summary. Raw console
captures were removed because they included machine paths and diagnostic metadata.
The initial parallel full-suite run also ran out of disk; after project cleanup,
all 60 tests passed serially.

At this point the user's manual sign-off remained pending. The user later
confirmed Stage 2 works; this historical checklist is retained for reference.

The user's own PDF still rejects a row; its layout compatibility is unresolved.
Added value-free on-screen diagnostics and privacy regression tests to identify
the affected page/row/columns on the next local retry. Static analysis is clean;
all 68 unit/widget tests passed. Normal diagnostic build passed in 21.2 seconds.
Passing fabricated tests is not claimed as proof that the user's PDF imports.

27/10/2026: reproduced the user's footer hypothesis using fabricated positioned
text. A nearby computer-generated notice produced the same receipt-cell
conflict before the fix. Footer boundaries are now recognised before row/anchor
grouping and restricted to the leftmost column. Tests verify no later transaction
is silently dropped and Safaricom merchant descriptions are retained. All 71
unit/widget tests passed. The user's diagonal approval-stamp screenshot does
did not establish whether its lettering was selectable; the user subsequently
confirmed it is image-only. The reader uses text extraction without OCR, so that
stamp contributes no text. No real statement or password was opened for this
repair. The normal Windows build passed in 21.5 seconds; own-PDF retry is pending.

Subsequent page-3 diagnostic reported a missing Details cell. Added a fabricated
tight-row regression with descriptions above receipt glyph tops; lower-edge
boundaries keep adjacent descriptions separate. Whole-document layout failures
are now collected across all pages and grouped by reason/columns, with one
representative per issue type. A 157-page diagnostic-summary test verifies this
grouping, including a different issue late in the document. Full suite: 73
passed; targeted PDF tests rerun after grouping refinements. The user's actual
statement remains unverified until a local retry; real rows were not used as
fixtures.

After the user reaffirmed PDF compatibility as the core requirement, resumed
repair. Added an invented regression in which a date inside Details widened
the completion-time column and reproduced the same missing-Details diagnostic.
The boundary now uses aligned completion dates and their clock text rather
than all date-like text in the header band. Regression and existing encrypted
PDF/CSV-equivalence tests pass. This is not confirmation of the cause of every
remaining failure in the user's full statement; local full import is pending.

Subsequent careful local inspection identified physical seven-column grids on
both supplied PDF formats, plus a separate summary on page 1 and separate
two-column footer tables. Replaced geometry guessing with vector-grid extraction
for ruled PDFs, retaining the previous fallback only for unruled tables. An
independent local extraction compared every receipt, timestamp, description,
paid-in, withdrawn and balance field: zero mismatches across all 66 supplied
transactions (25 + 41). No real values were logged/exported or made fixtures;
temporary inspection source was removed. Fabricated grid fixtures and tests
cover centred headings, wrapped cells, unrelated tables, empty descriptions and
broken borders. All 96 permanent unit/widget tests passed; static analysis clean.
Native Windows storage/build validation passed, including the ruled protected
fixture, real secure-vault persistence, cache clearing and full wipe. The user's
full-statement import was pending at that point. The user later signed off Stage
2 after testing the M-Pesa analyser in the app.
