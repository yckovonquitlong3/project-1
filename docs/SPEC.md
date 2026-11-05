# Multi-Wallet Finance Tracker — Technical Specification

**Version:** 1.0 (MVP)
**Platform:** Android (offline only)
**Status:** Approved for implementation. Supersedes the original SPEC.md; see §12 for the corrections.

---

## 1. Purpose

An offline-first Android app for manually tracking money across several accounts (Cash, GCash, Maya,
bank accounts). V1 delivers a **correct local ledger**: every wallet balance and the total net worth are
derived from an auditable transaction history, with no network access, APIs, or cloud.

The product is the ledger. If balances are provably correct, the UI is just screens.

---

## 2. Scope

### In scope (V1.0)

- Create, edit, archive wallets with an initial balance.
- Manual expense and income entries with category, note, timestamp.
- Internal wallet-to-wallet transfers that do not change net worth.
- Edit and delete any transaction, including transfers.
- Dashboard: net worth, current-month income vs expense, category breakdown, recent transactions.
- Local SQLite persistence, 100% offline.

### Out of scope (V1.5+)

- Natural-language / AI querying, receipt OCR.
- Recurring/subscription automation.
- Cloud backup, sync, Firebase.
- Bank or e-wallet scrapers.
- iOS, Web, Desktop targets.
- Multi-currency (V1 is PHP only).
- Transfer fees (V1.5: add `fee_minor` to transfers).

---

## 3. Technology stack

| Layer | Choice | Notes |
|---|---|---|
| Platform | Flutter (Dart 3), Android only | `flutter create --platforms=android` |
| State management | `flutter_bloc` 9.1.1 (Cubit + Bloc) | Sealed state classes, `BlocBuilder` |
| DI | `get_it` 9.3.0 | `injection_container.dart`, no service locator in widgets |
| Database | `sqflite` 2.4.5 + `path` | Raw SQL. **`qflite` does not exist on pub.dev** |
| Models | `equatable`, `uuid`, `intl` | |
| Testing | `flutter_test`, `bloc_test`, `mocktail`, `sqflite_common_ffi` | |

Pin exact versions with `flutter pub add` at setup time. Do not hand-write version numbers.

**Why not Drift / Riverpod:** the project intentionally targets the bloc + Clean Architecture stack used
in local job listings. Skills under `.opencode/skills/` were chosen to match this stack.
---

## 4. Architecture

Feature-first Clean Architecture. Each feature owns its three layers; `core` holds shared plumbing.

```
lib/
|-- main.dart
|-- app.dart
|-- injection_container.dart        # get_it registrations
|-- core/
|   |-- constants/                  # account types, category ids, app constants
|   |-- database/                   # app_database.dart, migrations.dart, seed.dart
|   |-- error/                      # Failure types, database exception mapping
|   |-- money/                      # Money value object, formatter, parser
|   |-- theme/                      # AppTheme, tokens
|   `-- utils/                      # date helpers (local_date), misc
`-- features/
    |-- wallet/
    |   |-- data/          # WalletModel, WalletDao, WalletRepositoryImpl
    |   |-- domain/        # Wallet entity, WalletRepository, usecases/
    |   `-- presentation/  # WalletCubit, WalletState, screens, widgets
    |-- transaction/
    |   |-- data/
    |   |-- domain/
    |   `-- presentation/
    `-- dashboard/
        |-- data/          # DashboardDao (aggregate queries)
        |-- domain/
        `-- presentation/
```

### Layer rules

1. **Domain imports nothing from `data` or `presentation`, and never imports `package:flutter`.**
2. **Presentation talks to domain only** (entities + use cases), never to DAOs or `sqflite`.
3. **Data implements domain interfaces.** `sqflite` types stop at the repository boundary.
4. **No cross-feature imports.** A feature may depend on `core` and its own layers only. Dashboard
   queries the database through its own DAO, never through `WalletRepository`.
5. **Use cases are required for every write and for aggregate reads.** They are the home of ledger
   rules. A use case is a single `call()` class, not a service layer.

### Cross-feature refresh

Repositories expose a broadcast `Stream<void> changes` (a `LedgerBus` in `core/`). Wallet and Dashboard
cubits subscribe to it. This avoids `WalletBloc` knowing about `TransactionBloc` and avoids cross-feature
imports entirely.

### Navigation

Plain `Navigator.push` / named routes. No `go_router` in V1; deep links are out of scope.
---

## 5. Database schema

SQLite, `user_version` migrations from day one. `PRAGMA foreign_keys = ON` is executed in sqflite's
`onConfigure`, on **every** connection.

```sql
CREATE TABLE wallets (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  account_type    TEXT NOT NULL CHECK (account_type IN ('CASH','E_WALLET','BANK','OTHER')),
  icon_identifier TEXT NOT NULL,
  balance_minor   INTEGER NOT NULL DEFAULT 0,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  is_archived     INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
  created_at_ms   INTEGER NOT NULL,
  updated_at_ms   INTEGER NOT NULL
);

CREATE TABLE categories (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN ('EXPENSE','INCOME')),
  icon_identifier TEXT NOT NULL,
  color_hex       TEXT NOT NULL,
  is_system       INTEGER NOT NULL DEFAULT 0,
  is_archived     INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
  sort_order      INTEGER NOT NULL DEFAULT 0,
  UNIQUE (name, type)
);

CREATE TABLE transactions (
  id               TEXT PRIMARY KEY,
  amount_minor     INTEGER NOT NULL CHECK (amount_minor > 0),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('EXPENSE','INCOME','TRANSFER')),
  source_wallet_id TEXT NOT NULL REFERENCES wallets(id)    ON DELETE RESTRICT,
  target_wallet_id TEXT          REFERENCES wallets(id)    ON DELETE RESTRICT,
  category_id      TEXT          REFERENCES categories(id) ON DELETE RESTRICT,
  occurred_at_ms   INTEGER NOT NULL,
  local_date       TEXT NOT NULL,
  note             TEXT,
  created_at_ms    INTEGER NOT NULL,
  updated_at_ms    INTEGER NOT NULL,
  CHECK (transaction_type <> 'TRANSFER' OR target_wallet_id IS NOT NULL),
  CHECK (transaction_type =  'TRANSFER' OR category_id IS NOT NULL),
  CHECK (source_wallet_id <> target_wallet_id)
);

CREATE INDEX idx_tx_occurred   ON transactions(occurred_at_ms DESC);
CREATE INDEX idx_tx_source     ON transactions(source_wallet_id, occurred_at_ms DESC);
CREATE INDEX idx_tx_target     ON transactions(target_wallet_id, occurred_at_ms DESC);
CREATE INDEX idx_tx_category   ON transactions(category_id, occurred_at_ms DESC);
CREATE INDEX idx_tx_local_date ON transactions(local_date);
```

### Rules attached to the schema

- **Money is never REAL.** `*_minor` columns are integer centavos.
- **History is never cascade-deleted.** `ON DELETE RESTRICT`; wallet deletion is a soft archive.
- **`local_date`** is `YYYY-MM-DD` computed at write time in `Asia/Manila`. Monthly aggregation groups on
  this column, never on a UTC timestamp.
- **`occurred_at_ms`** is epoch milliseconds, used for ordering and detail display.
- **Categories** are soft-archived. A category referenced by any transaction cannot be hard-deleted.

### Migrations

`app_database.dart` owns `openDatabase(version: kSchemaVersion, onConfigure:, onCreate:, onUpgrade:)`.
Every schema change bumps the version and adds a step in `migrations.dart`. Never edit `onCreate` without
a matching `onUpgrade` path.

### Seed data (schema v1)

Expense: Groceries, Transportation, Utilities, Food & Dining, School/Education, Online Shopping,
Subscriptions, Entertainment, Miscellaneous.

Income: Salary, Allowance, Freelance/Side Hustle, Selling, Gifts, **Opening Balance** (system).

Seeded categories are `is_system = 1` where they must not be deleted; `Opening Balance` is reserved and
hidden from the category picker.
---

## 6. Money

```dart
class Money {
  final int minorUnits;      // centavos
  const Money(this.minorUnits);
  static Money parsePesos(String input);  // "1,234.50" -> 123450
  String format();                        // 123450 -> ₱1,234.50
}
```

- Input is parsed with a strict decimal parser, rejecting more than 2 decimals, negatives, and zero.
- All arithmetic is integer arithmetic.
- `intl` is used only in `format()`; no locale-dependent parsing.

---

## 7. Ledger rules

### 7.1 Balance effect

One function is the only place balance math exists:

| Type | source wallet | target wallet |
|---|---|---|
| EXPENSE | `-amount` | — |
| INCOME | `+amount` | — |
| TRANSFER | `-amount` | `+amount` |

`applyEffect(txn, transaction, sign)` with `sign = +1` to apply and `-1` to reverse. Create applies `+1`;
delete reverses `-1`; edit reverses the old row then applies the new one. Every path runs inside
`db.transaction((txn) async { ... })` and always uses the passed `txn`, never the outer `db`.

### 7.2 Opening balance

Creating a wallet writes a system `INCOME` transaction (`Opening Balance`) in the same SQL transaction.
The wallet row therefore always starts at zero and every balance change has a matching row. A wallet with
zero opening balance gets no transaction.

Implication: `wallets.balance_minor` is always equal to the sum of its transaction deltas.

### 7.3 Net worth

`SUM(balance_minor)` over all wallets. Transfers must leave this value unchanged (two opposite deltas).
Archived wallets remain in the sum if their balance is non-zero.

### 7.4 Integrity check

A repository/use-case method `verifyBalances()` runs the reconciliation query and returns mismatches.
It is asserted in debug builds after every write in tests, and exposed behind a debug-only menu entry.

### 7.5 Deletion

- **Wallet:** `is_archived = 1`. Hard delete allowed only when the wallet has zero transactions; otherwise
  the UI offers archive only.
- **Transaction:** hard delete (the user's intent is to remove it). The reversal is applied in the same
  SQL transaction.
- **Category:** `is_archived = 1`. Hard delete blocked while referenced (`ON DELETE RESTRICT` enforces it).
---

## 8. Functional requirements

### FR-1 Wallets

- **1.1** Create a wallet with name, account type, icon, and initial balance.
- **1.2** Edit name, type, and icon. Balance is never edited directly.
- **1.3** Creating a wallet with a non-zero initial balance writes an `Opening Balance` income transaction.
- **1.4** Archive a wallet after a confirmation dialog. Archived wallets are hidden from pickers and shown
  in a separate "Archived" section. Hard delete is offered only for wallets with zero transactions.
- **1.5** Wallet list shows name, type icon, and current balance, ordered by `sort_order`, then name.

### FR-2 Expense and income

- **2.1** Expense deducts from the selected source wallet and requires a category of type `EXPENSE`.
- **2.2** Income adds to the selected wallet and requires a category of type `INCOME`.
- **2.3** The transaction insert and the balance update happen in **one** `db.transaction` block.
- **2.4** The amount must be greater than zero and is stored as centavos.

### FR-3 Transfers

- **3.1** Source and target wallets are required and must differ (also enforced by a CHECK constraint).
- **3.2** Source decreases, target increases, in the same SQL transaction.
- **3.3** Net worth is invariant across a transfer.
- **3.4** `category_id` is NULL for transfers.
- **3.5** Archived wallets cannot be selected as source or target.

### FR-4 Dashboard

- **4.1** Net worth = sum of all wallet balances (including archived, if non-zero).
- **4.2** Current-month total income and total expense, grouped by `local_date`.
- **4.3** Current-month expense breakdown by category, sorted by amount descending.
- **4.4** Recent transactions, `ORDER BY occurred_at_ms DESC`, limited to 20, showing wallet, category,
  amount, and relative date.
- **4.5** Tapping a transaction opens a detail screen.

### FR-5 Transaction management

- **5.1** Edit any transaction. The old effect is reversed and the new effect applied atomically.
- **5.2** Delete any transaction with a confirmation. The effect is reversed atomically.
- **5.3** Editing or deleting a transfer updates both wallets.
- **5.4** Totals and wallet balances refresh immediately after any write.

### FR-6 Data integrity

- **6.1** `PRAGMA foreign_keys = ON` on every connection.
- **6.2** All writes that touch more than one row are atomic.
- **6.3** A debug-only `verifyBalances()` reports any wallet whose `balance_minor` differs from the sum of
  its transaction deltas.

---

## 9. Non-functional requirements

- **Offline:** no network permission needed; the app must run fully in airplane mode.
- **Latency:** list and aggregate queries under 50 ms with 10,000 transactions.
- **Startup:** database open + first frame under 2 s on a mid-range device.
- **Durability:** schema versioned; migrations forward-only and tested.
- **Accessibility:** 48dp minimum tap targets, semantic labels on icon-only buttons, text scaling respected.
- **Localization:** V1 is English with PHP formatting; user-facing strings live in `core/constants`
  rather than being duplicated in widgets.
---

## 10. Acceptance criteria

```gherkin
Scenario: Logging an expense
  Given a "GCash" wallet with a balance of ₱1,000.00
  When the user logs an Expense of ₱150.00 for "Food & Dining" using "GCash"
  Then the "GCash" balance is ₱850.00 immediately
  And net worth decreases by ₱150.00
  And exactly one new row exists in transactions

Scenario: Logging income
  Given a "Cash" wallet with ₱500.00
  When the user logs Income of ₱2,000.00 for "Salary" into "Cash"
  Then the "Cash" balance is ₱2,500.00

Scenario: Internal transfer
  Given a "Bank" wallet with ₱5,000.00 and a "Maya" wallet with ₱200.00
  When the user transfers ₱1,000.00 from "Bank" to "Maya"
  Then "Bank" is ₱4,000.00 and "Maya" is ₱1,200.00
  And net worth is unchanged

Scenario: Transfer to the same wallet
  Given a wallet "Cash"
  When the user attempts a transfer from "Cash" to "Cash"
  Then the form rejects it and no database write occurs

Scenario: Rollback on failure
  Given an active database write transaction
  When an error occurs after the balance update but before the transaction insert
  Then the balance is unchanged and no transaction row exists

Scenario: Edit an expense
  Given a ₱150.00 expense on "GCash" with balance ₱850.00
  When the user changes the amount to ₱100.00
  Then "GCash" is ₱900.00 and net worth increases by ₱50.00

Scenario: Delete a transfer
  Given a completed ₱1,000.00 transfer from "Bank" to "Maya"
  When the user deletes it
  Then both balances return to their pre-transfer values and net worth is unchanged

Scenario: Opening balance is auditable
  Given a new wallet created with ₱2,500.00
  Then one "Opening Balance" income transaction exists for ₱2,500.00
  And the wallet balance equals the sum of its transaction deltas

Scenario: Balance integrity
  Given any sequence of writes
  Then for every wallet, balance_minor equals the sum of its transaction deltas

Scenario: Monthly summary respects local time
  Given a transaction at 2026-11-01 07:00 Asia/Manila
  Then it is counted in November, not October
```

---

## 11. Testing strategy

| Layer | What | Tool |
|---|---|---|
| Money / entities | parsing, formatting, equality, value objects | `flutter_test` |
| DAO / repositories | real SQLite via `sqflite_common_ffi` in-memory, atomicity, rollback | `flutter_test` |
| Use cases | ledger rules, transfer invariance, edit/delete reversal | `flutter_test` |
| Cubits | state transitions, error states | `bloc_test` + `mocktail` |
| Widgets | forms, validation, empty/loading/error states | `flutter_test` |
| Acceptance | the Gherkin scenarios above | integration test |

The repository / use-case tests in section 10 are written **before** the UI. The coverage floor applies
to the ledger layer (money, repositories, use cases), not to widgets.

---

## 12. Changes from the original specification

| # | Original | Change | Why |
|---|---|---|---|
| 1 | `qflite` | `sqflite` | `qflite` does not exist on pub.dev |
| 2 | `flutter_bloc v8.1+` | `flutter_bloc 9.1.1` | current major |
| 3 | `amount REAL` | `amount_minor INTEGER` | float rounding corrupts totals |
| 4 | `timestamp TEXT` | `occurred_at_ms INTEGER` + `local_date TEXT` | UTC strings misgroup months in UTC+8 |
| 5 | `ON DELETE CASCADE` on wallets | `ON DELETE RESTRICT` + `is_archived` | deleting a wallet erased history |
| 6 | `category_id ON DELETE SET NULL` | `ON DELETE RESTRICT` + `is_archived` | deleted categories vanished from reports |
| 7 | balance set directly at creation | `Opening Balance` transaction | keeps balance = sum of ledger |
| 8 | no transaction edit/delete | FR-5 | users need it; it is the hardest ledger operation |
| 9 | indexes on timestamp/source only | added target, category, `local_date`, composites | keeps queries under the 50 ms budget |
| 10 | enums enforced in Dart only | SQL `CHECK` constraints | database-level integrity |
| 11 | no migration story | `user_version` + `onUpgrade` | V1.5 will change the schema |
| 12 | no balance verification | `verifyBalances()` | materialized balance can drift |