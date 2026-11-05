# Implementation Plan — Multi-Wallet Finance Tracker (V1.0)

Companion to [SPEC.md](./SPEC.md). Each phase has a verification step that must pass before moving on.

**Rule:** the ledger is tested before any screen is built. Phase 4 is the heart of the project.

---

## Phase 0 — Decisions and tooling (DONE)

- [x] Review and prune third-party skills; keep a bloc/Clean-Architecture set.
- [x] Correct the spec: integer cents, soft delete, migrations, local dates, edit/delete transactions.
- [x] Write `docs/SPEC.md` and `docs/PLAN.md`.

---

## Phase 1 — Project setup

### Task 1.1 Initialize the Flutter project

```
flutter create . --project-name multi_wallet_tracker --org com.yckovon --platforms=android
```

- Keep `.git/`, `.opencode/`, `docs/`, `README.md`.
- Confirm `android/app/build.gradle.kts` has a sane `applicationId`.

### Task 1.2 Add dependencies

```
flutter pub add flutter_bloc equatable get_it intl path sqflite uuid
flutter pub add dev:bloc_test dev:mocktail dev:sqflite_common_ffi
```

- Do **not** add `qflite` (does not exist).
- Do not add `google_fonts`, `dynamic_color`, or any network package.

### Task 1.3 Lints and analysis

- Replace `analysis_options.yaml` with `flutter_lints` plus `strict-casts`, `strict-inference`,
  `strict-raw-types`.
- Enable `prefer_const_constructors`, `avoid_print`, `always_declare_return_types`.

### Task 1.4 Folder skeleton and DI

Create the tree from SPEC section 4 (empty placeholder files are fine, but no dead code).

- `lib/injection_container.dart` with `GetIt sl`, `initDependencies()`.
- `lib/app.dart` returns `MaterialApp` with the theme from `core/theme`.

**Verify:** `flutter analyze` is clean and `flutter run` shows a placeholder screen.

---

## Phase 2 — Core: money, database, migrations, seed

### Task 2.1 Money value object

`lib/core/money/money.dart`

- `Money(int minorUnits)`, `Money.zero()`.
- `Money.parsePesos(String)` — rejects empty, negative, zero, and more than 2 decimals.
- `format()` using `intl` with `PHP` and 2 decimals.
- `+`, `-`, comparison operators.

**Verify:** unit tests covering `"1,234.50"`, `"0.01"`, `"12.345"` (rejected), `"-5"` (rejected),
`""` (rejected), and round-trip format/parse.

### Task 2.2 Database helper and migrations

`lib/core/database/app_database.dart`, `migrations.dart`, `seed.dart`

- `AppDatabase` owns a single `Database` instance; `close()` for tests.
- `onConfigure`: `PRAGMA foreign_keys = ON`.
- `onCreate`: schema v1 from SPEC section 5, then seed.
- `onUpgrade`: switch on `oldVersion`, forward-only.
- `kSchemaVersion = 1`.
- Constructor takes an optional `databaseFactory` so tests use `sqflite_common_ffi`.

**Verify:** a test opens an in-memory database and asserts all three tables and all five indexes exist,
`PRAGMA foreign_keys` returns 1, and `user_version` equals `kSchemaVersion`.

### Task 2.3 Seed data

- Insert the default categories from SPEC section 5 with stable UUIDs (constants, not random).
- `Opening Balance` is a system category of type `INCOME`.

**Verify:** fresh database contains exactly the seeded categories, once each; reopening does not duplicate
them (seed only runs in `onCreate`).

---

## Phase 3 — Domain layer

### Task 3.1 Entities

`features/*/domain/entities/`

- `Wallet`, `Category`, `TransactionRecord` (name it `TransactionRecord` to avoid clashing with
  sqflite's `Transaction`), plus enums `AccountType`, `TransactionType`.
- Immutable, `Equatable`, `copyWith` where useful. `Money` fields, `DateTime` fields.

**Verify:** equality and `copyWith` unit tests.

### Task 3.2 Repository contracts

- `WalletRepository`: `watchAll`, `getById`, `create`, `update`, `archive`, `hardDelete`,
  `hasTransactions`.
- `TransactionRepository`: `watchRecent`, `getByWallet`, `create`, `update`, `delete`, `verifyBalances`.
- `DashboardRepository`: `getNetWorth`, `getMonthSummary`, `getCategoryBreakdown`.

Contracts return domain objects, throw `Failure` subtypes, never expose `sqflite` types.

### Task 3.3 Use cases

One class per operation, each with `call()`:

- `CreateWallet` (handles the opening-balance transaction), `UpdateWallet`, `ArchiveWallet`.
- `AddExpense`, `AddIncome`, `TransferMoney`, `EditTransaction`, `DeleteTransaction`.
- `GetNetWorth`, `GetMonthSummary`, `GetCategoryBreakdown`, `VerifyBalances`.

Use cases own all ledger rules; repositories own SQL only.

**Verify:** `flutter analyze` clean; no `package:flutter` import anywhere under `domain/`.
---

## Phase 4 — Data layer and the ledger engine (test-first)

### Task 4.1 Models and DAOs

`features/*/data/`

- `WalletModel`, `CategoryModel`, `TransactionModel` with `fromMap` / `toMap`, mapping `Money` to
  `*_minor` and `DateTime` to `occurred_at_ms` + `local_date`.
- `WalletDao`, `CategoryDao`, `TransactionDao` — pure SQL, take a `DatabaseExecutor` so they can run
  inside an existing transaction.

**Verify:** round-trip tests for every model; `local_date` is correct for a timestamp near midnight.

### Task 4.2 Repository implementations

- `WalletRepositoryImpl`, `TransactionRepositoryImpl`, `DashboardRepositoryImpl`.
- `LedgerBus` (broadcast stream in `core/`) emitted after every successful write.

**Verify:** integration tests against real in-memory SQLite.

### Task 4.3 The `applyEffect` path

Single private helper used by create, edit, delete, and transfer:

```dart
Future<void> applyEffect(DatabaseExecutor txn, TransactionRecord t, int sign)
```

All writes go through `db.transaction((txn) async { ... })`, always passing `txn` down.

**Verify — these tests must exist and pass before any UI work:**

1. Expense decreases one wallet by the exact amount.
2. Income increases one wallet.
3. Transfer changes both wallets, net worth unchanged.
4. Edit expense reverses the old amount and applies the new one.
5. Delete expense restores the pre-transaction balance.
6. Delete transfer restores both wallets.
7. Rollback: force an insert failure after a balance update; balance is unchanged.
8. Same-wallet transfer is rejected and writes nothing.
9. `verifyBalances()` returns empty after 200 randomized mutations (seeded RNG).
10. Monthly grouping: a 2026-11-01 07:00 Asia/Manila transaction is counted in November.

---

## Phase 5 — Wallet feature

### Task 5.1 `WalletCubit`

States: `WalletInitial`, `WalletLoading`, `WalletLoaded(List<Wallet>, List<Wallet> archived)`,
`WalletFailure(message)`. Subscribes to `LedgerBus`.

Events/methods: `load`, `create`, `update`, `archive`, `restore`.

**Verify:** `bloc_test` for load success, load failure, create, archive, and refresh on bus event.

### Task 5.2 Wallet screens

- `WalletListScreen`: balance per wallet, type icon, archived section, empty state.
- `WalletFormSheet` (bottom sheet): name, account type, icon, initial balance (create only).
- Archive confirmation dialog; hard delete only when `hasTransactions == false`.

**Verify:** widget test for validation (empty name, zero/negative balance) and manual run.

---

## Phase 6 — Transaction feature

### Task 6.1 `TransactionCubit`

States mirror the amount/validation lifecycle: `TransactionIdle`, `TransactionSaving`,
`TransactionSaved`, `TransactionFailure`.

Methods: `addExpense`, `addIncome`, `addTransfer`, `edit`, `delete`.

**Verify:** `bloc_test` for each path, including a failure from the repository.

### Task 6.2 Entry form

`AddTransactionScreen` with a segmented control (Expense / Income / Transfer):

- Amount (numeric keypad, `Money.parsePesos`).
- Wallet picker (expense/income: one wallet; transfer: source + target, archived excluded).
- Category picker filtered by type; hidden for transfers.
- Date/time picker (defaults to now), note field.
- Validation: amount > 0, category required where applicable, source != target.

**Verify:** widget tests for each validation rule; manual run matches SPEC section 10 scenarios 1-4.

### Task 6.3 Detail, edit, delete

- `TransactionDetailScreen` with amount, type, wallets, category, note, timestamp.
- Edit reuses the entry form pre-filled; delete shows a confirmation.
- Both routes refresh through `LedgerBus`.

**Verify:** edit and delete acceptance scenarios from SPEC section 10 pass.
---

## Phase 7 — Dashboard

### Task 7.1 `DashboardCubit`

Loads in parallel: net worth, month summary, category breakdown, recent transactions.
Subscribes to `LedgerBus`.

**Verify:** unit test that a transfer leaves net worth unchanged; month summary uses `local_date`.

### Task 7.2 Dashboard screen

- Net worth header card.
- Horizontal wallet carousel (top 5 by balance).
- Month row: income vs expense, current month name.
- Category breakdown list with amounts and percentages.
- Recent transactions (max 20) tapping through to detail.
- Empty state for a brand-new install.

**Verify:** manual run + widget test for the empty state and for amount formatting.

---

## Phase 8 — Quality and release

### Task 8.1 Acceptance suite

Automate every scenario in SPEC section 10 as an integration test.

### Task 8.2 Accessibility and layout

- 48dp tap targets, semantic labels on icon-only buttons.
- Text scale 1.3 and 2.0 do not overflow the dashboard or forms.
- Dark theme verified on the dashboard and both forms.

### Task 8.3 Performance check

- Seed 10,000 transactions in a test database.
- Assert dashboard queries complete in under 50 ms on the emulator.
- Confirm the transaction list is lazy (`ListView.builder`).

### Task 8.4 Offline and build

- Airplane mode: create wallets, add all three transaction types, restart, verify persistence.
- `flutter build apk --release` succeeds and the APK installs on a device/emulator.

---

## Ordering rules

1. Do not start Phase 5 until Phase 4's ten tests pass.
2. Do not add a package without a line in SPEC section 3.
3. Every schema change bumps `kSchemaVersion` and adds an `onUpgrade` case.
4. No widget may import `sqflite` or a DAO.
5. Any balance change goes through `applyEffect`; if a new code path needs it, refactor rather than
   duplicating the arithmetic.

---

## Differences from the original plan.md

| # | Original | Change | Why |
|---|---|---|---|
| 1 | Phase 1 `flutter_bloc, get_it, sqflite, path, ...` | same list, real versions, plus `sqflite_common_ffi` for tests | testable repositories |
| 2 | no migration task | Phase 2.2 `user_version` + `onUpgrade` | schema will change in V1.5 |
| 3 | Task 2.1 entities + models in one task | split into domain entities and data models | keeps layers honest |
| 4 | Task 3.1 wallet repository does CRUD only | added `archive`, `hasTransactions` | soft delete |
| 5 | Task 4.1 three write paths | single `applyEffect` + edit/delete | one place for balance math |
| 6 | Task 4.2 "trigger WalletBloc refresh" | `LedgerBus` stream | avoids bloc-to-bloc coupling |
| 7 | no transaction edit/delete | Phase 6.3 | required by FR-5 |
| 8 | Task 5.2 "tap a recent transaction to view details" with no such task | Phase 6.3 builds the detail screen | the plan promised an unbuilt screen |
| 9 | no ledger test gate | Phase 4.3 verify list (10 tests) | UI before a proven ledger is wasted work |
| 10 | Task 6.1 three scenarios | full acceptance suite + a11y + perf + release | matches SPEC section 10 |