# Budget

A small native macOS app (SwiftUI, macOS 14+) for tracking personal spending.

- Add expenses quickly (⌘N from anywhere, Enter to save).
- See this month's spending against your budget, with category totals.
- See a monthly cash-flow summary: expected pay − fixed items due − spending budget = what is left over.
- Look back at any past month.

All data lives in three plain CSV files on your Mac. There is no database, no account and no network access.
Nothing is built in: every amount, category, date and label is something you entered.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build and run

1. Open `Budget.xcodeproj` in Xcode.
2. Choose the **Budget** scheme and **My Mac** as the destination.
3. Press **⌘R** to run, or **⌘U** to run the unit tests.

From Terminal:

```bash
xcodebuild -project Budget.xcodeproj -scheme Budget -destination 'platform=macOS' test
```

The project signs the app to run locally and has no development team set, so it builds on any Mac as it is.
The bundle identifier is the placeholder `com.example.Budget`; change it under *Signing & Capabilities* if you like.

### First launch

- macOS asks whether Budget may access your Documents folder. Allow it, because that is where the data is kept.
- The app creates `~/Documents/Budget/` with three files that contain headers only. No amounts or categories are filled in.
- The window asks you to open **Settings** (⌘,). Enter your currency, monthly budget, pay schedule and at least one
  category, then press **Save**. After that you can add expenses.

## Where the data is

Everything is in `~/Documents/Budget/`. Settings has an **Open Data Folder in Finder** button.

| File | Columns | What it holds |
| --- | --- | --- |
| `settings.csv` | `key,value` | `currency`, `currency_symbol`, `monthly_budget`, `pay_amount`, `pay_frequency_days`, `next_pay_date`, `categories` (comma-separated) |
| `fixed_items.csv` | `name,amount,frequency_days,next_due_date` | Recurring obligations such as rent, loan payments and subscriptions |
| `expenses.csv` | `date,amount,category,description` | One row per expense |

Format rules:

- Dates are written `YYYY-MM-DD`.
- Amounts are positive, use `.` as the decimal point and have at most two decimal places. No currency symbols or thousands separators.
- Frequencies are whole numbers of days, 1 or more.
- Values containing commas, quotes or line breaks are wrapped in double quotes, and a quote inside a value is written twice (`""`), as in standard CSV.

You can edit the files in any text editor or spreadsheet. The app re-reads them when you switch back to it, or when
you choose **File ▸ Reload Data** (⌘R).

Safety:

- Files are written to a temporary file and then swapped into place, so a crash cannot leave a half-written file.
- If a row cannot be understood, the app shows a warning with the file name and line number, ignores that row in the
  totals and keeps it in the file. Other rows are unaffected, and nothing is silently dropped.
- If a file was changed outside the app since it was last read, the app refuses to overwrite it and asks you to reload first.

## Backing up

Your data is just the `~/Documents/Budget` folder, so backing up means copying it.

```bash
cp -R ~/Documents/Budget ~/Documents/Budget-backup-$(date +%F)
```

- If you use Time Machine, the Documents folder is already part of its backups.
- If *Desktop & Documents Folders* is turned on in iCloud Drive, the folder is synced to iCloud as well.
- To restore, quit Budget, replace the three files in `~/Documents/Budget` with your copies, and open the app again.

To move to another Mac, copy the folder to the same place there.

## How the numbers are worked out

- **Month totals** add up every expense dated in the chosen month. The progress bar turns amber at 80% of the monthly
  budget and red above 100%.
- **Pay dates and due dates** come from the stored "next" date and the frequency in days. The schedule is that date
  plus or minus any whole number of frequencies, so it works for any month, past or future, and for any schedule.
- **Cash flow** for a month = (pay amount × number of pay dates in the month) − (every fixed item occurrence due in
  the month) − (monthly spending budget).

Because schedules are counted in days, a 30-day item does not land on the same day each month. It can fall twice in a
long month or skip February. The stored "next" dates are never changed by the app; you can leave them alone or update them in Settings.

## Project layout

```
Budget/
  App/       App entry point and the app's state (reads and saves through Storage)
  Models/    Day, MonthRef, Settings, Expense, FixedItem
  Storage/   CSV parser and writer, file formats, atomic file access
  Logic/     Validation, schedule math, month totals, cash flow, money formatting
  Views/     SwiftUI screens: dashboard, expense form, settings
BudgetTests/ Unit tests for the CSV code, file formats, validation, schedules, totals and cash flow
```

## Privacy

- The app never connects to the network.
- Your data is stored outside this repository, and `.gitignore` excludes `*.csv` and Xcode's per-user files, so
  personal data cannot be committed by accident.

## Trying it without touching your real data

Set the `BUDGET_DATA_DIR` environment variable to another folder (in Xcode: *Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸
Arguments ▸ Environment Variables*). The app then uses that folder instead of `~/Documents/Budget`.
