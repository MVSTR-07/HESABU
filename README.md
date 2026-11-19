# HESABU

**A clearer view of your business.**

HESABU is a Flutter app for small businesses in Kenya. It helps turn everyday
records into useful answers, while keeping business data on the device. The
first release is being built for Windows, with Android support planned from the
same Dart codebase.

I am building this repository in stages. The M-Pesa, customer, stock, sales and
expense tools are in place, and I am continuing to expand the financial tools
and test the Windows and Android experience. HESABU is not yet a finished
published product.

## What you can explore

- **M-Pesa statements:** import CSV or supported text-based PDF statements and
  review money in and out, fees, activity patterns and rule-based flags.
- **Customer performance:** review payment history, customer segments,
  concentration and personalised drop-off signals.
- **Stock, sales and expenses:** enter records locally and explore summaries.
- **Profit and loss, balances, imports and reports:** create a simple working
  surplus view, track customer/supplier balances, review CSV/Excel rows before
  import, and save local PDF/Excel summaries. These tools are intended as a
  practical working view, not a replacement for formal accounts.
- **Light and dark appearance:** the shared interface uses a dark-blue glass
  style, with a light option.

Analysis runs locally. Imported records and results are kept in an encrypted
SQLite database on the device; they are not sent to a HESABU server. The account
and paid-plan screens are clearly labelled demos: there is no real sign-in,
billing or account server yet. The optional AI area is disabled and no AI service
is connected.

## Run it on Windows

Install Flutter and open this folder in VS Code. On Windows, Flutter also needs
Visual Studio or Build Tools with the **Desktop development with C++** workload.
Then run these commands in PowerShell from the project folder:

```powershell
.\tool\flutter.ps1 doctor -v
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 run -d windows
```

To check the code locally:

```powershell
.\tool\flutter.ps1 analyze --no-pub
.\tool\flutter.ps1 test --no-pub --concurrency=1
.\tool\flutter.ps1 build windows --profile --no-pub
```

Tests use fabricated records. Never use a real statement or customer details in
a sample, test, screenshot or Git commit. The app's **Delete all data / clear
cache** control clears the app's local records; original files selected for
import are left where they are.

## Project map

- `lib/core/` — Dart parsers, analysis rules, sample data and result models.
- `lib/data/` — encrypted local storage and repositories.
- `lib/features/` — screens for each tool and shared navigation.
- `lib/ui/` — reusable widgets, theme and formatting.
- `lib/ai/` — disabled interface kept separate so it can be removed cleanly.
- `test/` and `integration_test/` — fabricated-data and local-storage checks.
- `docs/` — architecture notes, validation and manual checklists.

## Where the work stands

I have a working Windows build with encrypted local storage, M-Pesa and customer
analysis, stock/sales/expense records, financial summaries, debt tracking,
tabular imports and local report export. I am continuing Android testing,
broader M-Pesa PDF compatibility work and the workspace model before release.

The repository is named **HESABU** and is owned by **MVSTR-07**. The project is
being prepared for public review; do not treat a GitHub copy as a hosted service
or upload real business records to it.
