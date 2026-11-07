# Multi-Wallet Finance Tracker

An offline-first Android app for tracking money across cash, e-wallets, and bank accounts.
Every wallet balance and the total net worth are derived from an auditable transaction
ledger stored in local SQLite. No accounts, no network, no cloud.

## Features

- Multiple wallets with opening balances recorded as ledger entries
- Expenses, income, and wallet-to-wallet transfers
- Edit and delete any transaction, with atomic balance reversal
- Dashboard: net worth, monthly income vs expense, category breakdown, recent activity
- Archive wallets; permanent deletion only when the wallet has no history
- Light and dark Material 3 themes, 48dp targets, text scaling checked at 2.0x
- Offline-first ledger; optional AI quick entry uses your own provider key (network required only while AI is enabled)

## Tech stack

| Layer | Choice |
|---|---|
| Platform | Flutter 3.44 / Dart 3.12, Android only |
| State | `flutter_bloc` (Cubit, sealed states) |
| DI | `get_it` |
| Database | `sqflite` with raw SQL, `user_version` migrations |
| Models | `equatable`, `uuid`, `intl` |
| Tests | `flutter_test`, `bloc_test`, `mocktail`, `sqflite_common_ffi` |

## Architecture

Feature-first Clean Architecture: `lib/core` holds shared plumbing; each of
`wallet`, `transaction`, `category`, and `dashboard` owns `data`, `domain`, and
`presentation`. Use cases own validation and ledger rules; repositories own SQL
and atomic writes. A single `applyEffect` path is the only place wallet balances
change.

Project documents:

- [Specification](docs/SPEC.md)
- [Implementation plan](docs/PLAN.md)

## Getting started

```bash
flutter pub get
flutter run
```

Select an Android device or emulator. The app creates and seeds its local
database on first launch.

## Tests

```bash
flutter analyze
flutter test
```

The suite covers:

- The 10-test ledger gate (expense, income, transfer, edit, delete, rollback, same-wallet transfer, 200 randomized mutations, local-date month grouping)
- All ten acceptance scenarios from `docs/SPEC.md`
- A 10,000-row benchmark that reports net worth, month totals, category breakdown, recent-list, and wallet-list query times against the 50 ms budget
- Text scaling at 1.3x and 2.0x, theme contrast ratios, and a 48dp tap-target check

Latest run: **197 tests, all passing**.

## Release build

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

The release build currently uses the debug signing key from
`android/app/build.gradle.kts`. Replace it with your own keystore before
publishing to Google Play.

## Offline verification

The core ledger works in airplane mode. AI quick entry is optional, off by default, and uses your own provider key (BYOK); there is no proxy. The release manifest declares `INTERNET` for that optional feature. To verify the ledger offline: enable airplane mode, create wallets and transactions, force-stop the app, then reopen it — all data is still there.
