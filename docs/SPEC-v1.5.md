# Multi-Wallet Finance Tracker — V1.5 Specification

**Version:** 1.5 (AI & Automation Upgrade)
**Platform:** Android (offline-first; optional AI)
**Status:** Draft for approval
**Schema:** v2 (migrates from v1)
**Baseline:** Extends [`SPEC.md`](./SPEC.md) (v1.0). It does not replace the shipped v1 specification.

---

## 1. Purpose

V1.5 extends the verified v1.0 local ledger with:

- Optional transfer fees.
- Recurring subscriptions with local reminders, overdue handling, and deduction when the app is opened.
- Optional AI quick-entry and read-only financial chat using a user-supplied provider key (BYOK).

The core principle is unchanged: **the local SQLite ledger is the single source of truth.** AI
features are read-only or pre-fill assistants. Nothing external may bypass `applyEffect`,
`verifyBalances`, or the atomic write rules.

V1.5 is still offline-first. The ledger works fully in airplane mode. AI requires an internet
connection, a provider key, and explicit user consent. **There is no default proxy, no server, and
no bundled AI key in v1.5.**

---

## 2. Scope

### In scope

- Schema migration v1 → v2 that preserves every existing wallet, category, and transaction.
- Optional `fee_minor` on transfers, with correct net-worth and reporting behavior.
- Subscriptions: create, edit, archive, delete; weekly/monthly/yearly cycles; next billing date;
  auto-deduct toggle; overdue state; manual "Mark as Paid"; "Catch up all".
- Local notifications: 24-hour warning and billing-day alert, scheduled by Android and able to fire
  while the app is closed.
- Deduction processing when the app opens/resumes (no background database writes).
- AI quick-entry from a natural-language prompt, with local validation and user confirmation.
- AI analytics chat with fixed, read-only tools over aggregate data.
- AI settings: Off / BYOK, provider preset, secure key storage, consent, connection test.
- Offline and error fallbacks for every AI action.
- Accessibility, performance, migration, and security tests.

### Out of scope / deferred

- Default AI proxy or zero-config AI (deferred; no server code in v1.5).
- Background database writes while the app is closed.
- Exact-time alarm guarantees.
- Camera/OCR receipt scanning.
- Multi-device cloud sync (Firebase/Supabase database sync).
- Multi-currency. PHP remains the base currency.
- Bank/e-wallet scraper APIs.
- iOS, Web, Desktop targets.
- Persistent AI chat history and user accounts.
- Gemini native API support (Gemini is only a candidate preset if its OpenAI-compatible endpoint
  supports the required calls; otherwise it is deferred).

---

## 3. Decisions that shape this version

| Topic | Decision |
|---|---|
| Notifications | Scheduled locally. They fire when the app is backgrounded, swiped away, or terminated (subject to OS/boot/force-stop rules). |
| Deduction timing | On app start/resume, and when the Subscriptions screen opens. Optional foreground timer while the app is open. No background DB writes. |
| AI default | Off. The user enables it explicitly and accepts a consent screen. |
| AI mode | BYOK only. No proxy, no server, no bundled key. |
| AI providers | OpenAI-compatible providers: OpenAI and DeepSeek presets. Gemini is a possible preset only if its compatibility endpoint supports the required calls. |
| Fee amount | Per-transfer, any non-negative centavo amount. `₱15` is only an acceptance example. |
| Fee reporting | Fee stays on the transfer row; included in monthly expense; synthetic "Transfer fees" breakdown row. |
| Subscription catch-up | Automatic runs process the oldest due cycle once. A separate "Catch up all" action processes all due cycles after confirmation. |
| Billing dates | Preserve the original billing anchor day and local time; clamp short months; do not drift permanently. |
| Idempotency | Charge insert, balance update, next-billing advance, and last-paid timestamp are one SQL transaction, guarded by a unique subscription/period index. |
| Navigation | Four tabs: Dashboard, Wallets, Activity, Subscriptions. AI Chat and Settings are app-bar actions. |
| Documents | Keep `docs/SPEC.md` as the v1.0 baseline; this file and `docs/PLAN-v1.5.md` cover v1.5. |

---

## 4. Technology additions

Versions are resolved with `flutter pub add` at implementation time; do not hardcode guessed
versions.

| Package | Role |
|---|---|
| `flutter_local_notifications` | Local 24-hour and billing-day notifications |
| `timezone` | Timezone-aware scheduling |
| `flutter_timezone` | Reads the device's local timezone for scheduling |
| `flutter_secure_storage` | Encrypted storage for the BYOK key and AI settings |
| `http` | Direct HTTPS calls to the chosen provider |
| `connectivity_plus` | Fast offline detection; not a substitute for handling request failures |

**Not added in v1.5:** Supabase, serverless functions, a default proxy, WorkManager/AlarmManager
background workers. Notification scheduling is handled by `flutter_local_notifications`; deduction
is handled in the foreground.

### Android setup

- `INTERNET` and `ACCESS_NETWORK_STATE` for AI.
- `POST_NOTIFICATIONS` on Android 13+ (runtime permission).
- `RECEIVE_BOOT_COMPLETED` if the notification plugin's boot receiver requires it.
- Notification icon and channels.
- Core library desugaring if required by the notification plugin.
- No exact-alarm permission: reminders use inexact scheduling.
- The v1 "release declares no internet permission" claim no longer applies. The ledger remains
  fully offline; AI is optional.

---

## 5. Database schema v2

### 5.1 Migration principles

- `kSchemaVersion = 2`.
- One migration source of truth: `migrate(db, 0, 2)` creates the latest schema on a fresh install,
  and `onUpgrade` applies the same steps to existing databases.
- The migration is **additive**. Existing wallets, categories, and transactions are preserved.
- A migration test opens a database containing v1 data, upgrades it, and verifies every row plus
  `user_version = 2`.
- No destructive table rebuild is performed. The project's SQLite build accepts `CHECK`
  constraints in `ALTER TABLE ADD COLUMN` (verified during planning), so the fee rule is enforced
  at the database level as well as in the use cases. The new `subscriptions` table has full
  database checks.

### 5.2 `transactions` additions

```sql
ALTER TABLE transactions ADD COLUMN fee_minor INTEGER NOT NULL DEFAULT 0
  CHECK (fee_minor >= 0 AND (fee_minor = 0 OR transaction_type = 'TRANSFER'));
ALTER TABLE transactions ADD COLUMN subscription_id TEXT
  REFERENCES subscriptions(id) ON DELETE RESTRICT;
ALTER TABLE transactions ADD COLUMN billing_period TEXT;

CREATE UNIQUE INDEX idx_tx_subscription_period
  ON transactions(subscription_id, billing_period)
  WHERE subscription_id IS NOT NULL;
```

Rules:

- `fee_minor >= 0` and `fee_minor` is non-zero only for `TRANSFER`. Enforced by the database
  `CHECK` and by the use cases.
- `subscription_id` and `billing_period` are either both NULL (manual transaction) or both non-NULL
  (subscription-generated transaction). `billing_period` is the scheduled due date (`YYYY-MM-DD`)
  that was paid.
- The partial unique index prevents the same subscription from charging the same period twice.
- Existing rows receive `fee_minor = 0`, and NULL subscription fields.
- A subscription with generated transactions cannot be hard-deleted (`ON DELETE RESTRICT`); it must
  be archived instead.

### 5.3 `subscriptions`

```sql
CREATE TABLE subscriptions (
  id                     TEXT PRIMARY KEY,
  name                   TEXT NOT NULL,
  amount_minor           INTEGER NOT NULL CHECK (amount_minor > 0),
  wallet_id              TEXT NOT NULL REFERENCES wallets(id)    ON DELETE RESTRICT,
  category_id            TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  billing_cycle          TEXT NOT NULL CHECK (billing_cycle IN ('WEEKLY','MONTHLY','YEARLY')),
  next_billing_at_ms     INTEGER NOT NULL,
  billing_anchor_day     INTEGER NOT NULL CHECK (billing_anchor_day BETWEEN 1 AND 31),
  billing_time_minutes   INTEGER NOT NULL CHECK (billing_time_minutes BETWEEN 0 AND 1439),
  auto_deduct            INTEGER NOT NULL DEFAULT 1 CHECK (auto_deduct IN (0,1)),
  is_active              INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  is_overdue             INTEGER NOT NULL DEFAULT 0 CHECK (is_overdue IN (0,1)),
  last_paid_at_ms        INTEGER,
  last_failure_reason    TEXT CHECK (
    last_failure_reason IS NULL OR last_failure_reason IN (
      'INSUFFICIENT_BALANCE',
      'WALLET_ARCHIVED',
      'CATEGORY_ARCHIVED',
      'MANUAL_PAYMENT_REQUIRED'
    )
  ),
  last_notified_at_ms    INTEGER,
  created_at_ms          INTEGER NOT NULL,
  updated_at_ms          INTEGER NOT NULL
);

CREATE INDEX idx_sub_due      ON subscriptions(is_active, next_billing_at_ms);
CREATE INDEX idx_sub_wallet   ON subscriptions(wallet_id);
CREATE INDEX idx_sub_category ON subscriptions(category_id);
```

Semantics:

- `is_active = 0` means archived. Archived subscriptions get no reminders and no deductions.
- `is_overdue` is stored for fast UI queries and must be updated in the same transaction as any
  payment/failure. It is true when `next_billing_at_ms <= now` and the period is unpaid.
- `auto_deduct = 0` means "remind only". The runner does not write a transaction; the subscription
  becomes overdue when due and waits for a manual payment.
- `last_failure_reason` drives the overdue banner text.
- `billing_anchor_day` preserves "the 31st" across short months. `billing_time_minutes` preserves
  the local time.
- Hard deletion is allowed only when the subscription has generated no transactions; otherwise
  archive it.

### 5.4 Index inventory after v2

v1's five indexes remain. V2 adds:

- `idx_sub_due`
- `idx_sub_wallet`
- `idx_sub_category`
- `idx_tx_subscription_period`

Tests must assert the new count and the `user_version`.

### 5.5 Seed data

No new seeded categories are required. The existing `Subscriptions` expense category
(`cat-exp-subscriptions`) is the default for subscription charges. "Transfer fees" is a synthetic
reporting bucket, not a category row.

### 5.6 Integrity check

`verifyBalances()` must account for fees:

```sql
-- transfer source
-(amount_minor + fee_minor)

-- transfer target
+amount_minor
```

Any wallet whose stored balance differs from the sum of its transaction deltas is still reported.
Fee transfers must pass this check after create, edit, and delete.

---

## 6. Transfer fees

### 6.1 Balance effect

For a transfer of amount `A` with fee `F`:

| Wallet | Change |
|---|---|
| Source | `-(A + F)` |
| Target | `+A` |
| Net worth | `-F` |

If `F = 0`, net worth is unchanged.

`applyEffect(record, sign)` remains the only balance-mutation path. Create applies `sign = +1`;
delete applies `sign = -1`; edit reverses the old record and applies the new one.

### 6.2 Validation

- Fee is optional; blank means `0`.
- Fee is stored as integer centavos.
- Reject negative, non-numeric, and more than two decimal places.
- Allow `0` and allow fees larger than the transfer amount, with a soft warning.
- Fees only apply to transfers; non-transfer transactions always store `0`.
- The transfer form shows the fee field only for transfers.

### 6.3 Reporting

- `MonthSummary` gains `fees`.
- `MonthSummary.expense` includes fees, so `net = income - expense` stays truthful.
- The category breakdown includes a synthetic row with id `__transfer_fees__`, name
  "Transfer fees", when fees exist in the month.
- The dashboard shows the fee portion ("Includes ₱X in transfer fees") when non-zero.
- Activity and detail screens show the fee on transfer rows.
- AI monthly-summary tools return `fee_minor` separately as well as within expense.

### 6.4 Edit and delete

Editing a transfer reverses the old `(A + F)` and applies the new `(A + F)` atomically. Deleting
reverses both the amount and the fee. The old and new records may have different fees, including
zero.

---

## 7. Subscriptions and reminders

### 7.1 Lifecycle

- Create with name, amount, wallet, category, cycle, next billing date/time, auto-deduct.
- Edit future behavior; past transactions are never rewritten.
- Archive (`is_active = 0`): cancel reminders, stop deductions, keep history.
- Delete: allowed only when no generated transactions; otherwise archive.
- Reactivating a subscription uses the existing next billing date; if it is in the past, it becomes
  overdue and is processed on the next run.

### 7.2 Due processing

A single use case, run only in the foreground, processes due subscriptions. It is triggered on:

- App start and resume.
- Opening the Subscriptions screen.
- Optionally, a foreground timer while the app remains open.

A run lock prevents overlapping runs. The runner is deterministic and testable with an injected
clock.

Automatic run algorithm (oldest due cycle first):

1. Load active subscriptions with `next_billing_at_ms <= now`, oldest first.
2. Skip `auto_deduct = 0`; mark overdue with `MANUAL_PAYMENT_REQUIRED`, notify, and stop processing
   that subscription.
3. If the wallet or category is archived, mark overdue with the matching reason and notify.
4. If the wallet balance is less than the amount, make no ledger change; mark overdue with
   `INSUFFICIENT_BALANCE`; do not advance the date; notify.
5. Otherwise, in one SQL transaction:
   - Insert the `EXPENSE` transaction with `occurred_at_ms` = the scheduled due instant,
     `local_date` = the scheduled due local date, `subscription_id`, and `billing_period` = that
     due date.
   - Apply the balance effect.
   - Advance `next_billing_at_ms` by one cycle from the scheduled date, preserving the anchor day
     and local time.
   - Set `last_paid_at_ms`, clear `last_failure_reason`, and recompute `is_overdue`.
6. Notify "Subscription paid".
7. Notify `LedgerBus` so open screens refresh.

Only **one** cycle is processed per automatic run. If more cycles are still due, the subscription
remains overdue and the banner offers **Catch up all**.

"Catch up all" requires confirmation and repeats the same atomic steps oldest-first until no cycle
is due or the balance is insufficient. It stops at the first failed charge for that subscription
and reports how many cycles were paid.

### 7.3 Insufficient balance and manual payment

- No write, no advancement, overdue state, notification.
- "Mark as Paid" retries one cycle. If the balance is still insufficient, the app explains the
  shortfall and does not write. The user can top up the wallet or edit the subscription.
- The user can also record a normal expense manually if they paid from a different source.

### 7.4 Billing dates

- Weekly: `+7 days`.
- Monthly: next month, same anchor day, clamped to the last day of that month.
- Yearly: next year, same month/day, clamped for leap years.
- Advancing from a late payment uses the **scheduled date**, not "now", to preserve the anchor.
- Device-local time is used. A timezone change may shift the local time of the next reminder; this
  is documented behavior, not silently normalized.
- Month-end examples: Jan 31 → Feb 28/29 → Mar 31 (the anchor stays 31).

### 7.5 Notifications

- Two notifications per cycle: 24 hours before and at the billing date/time.
- Schedule upcoming cycles for the next 12 months, with a documented per-app cap; refresh on app
  start/resume and on subscription create/edit/archive/delete.
- Stable notification IDs per subscription, cycle, and stage; cancel stale IDs when editing.
- Notification tap opens the subscription detail screen.
- Use inexact scheduling (no exact-alarm permission).
- Runtime notification permission on Android 13+; if denied, show an in-app banner and continue to
  process deductions on open.
- Boot: rely on the plugin's boot receiver; verify with the Phase 0 spike. Force-stopped apps do
  not receive alarms until reopened. OEM battery optimizers may delay notifications; provide
  guidance, not a guarantee.

### 7.6 Archived references

- Archiving a wallet with active subscriptions is blocked with a clear message. The user must
  archive or reassign those subscriptions first.
- Hard-deleting a wallet with a subscription is blocked by `ON DELETE RESTRICT`; the repository
  surfaces a friendly `ConflictFailure`.
- If a category becomes archived, the runner marks the subscription overdue with
  `CATEGORY_ARCHIVED` instead of writing.

---

## 8. AI (BYOK only)

### 8.1 Modes and consent

- AI is **off** on a fresh install.
- Settings offer `Off` and `BYOK`.
- Enabling AI requires a consent screen that explains:
  - The quick-entry text is sent to the chosen provider.
  - Chat sends the user's question and aggregate tool results to the provider.
  - Raw transaction rows and notes are not sent for chat.
  - The provider's own privacy policy applies.
- Consent version and timestamp are stored locally. Revoking consent disables AI and clears the
  stored key after confirmation.
- No proxy, no server, no bundled key.

### 8.2 Providers and keys

- Presets: OpenAI and DeepSeek (OpenAI-compatible chat completions).
- Gemini is a candidate preset only if its OpenAI-compatible endpoint supports the required calls,
  verified in Phase 0; otherwise it is deferred.
- The user pastes an API key. It is stored in `flutter_secure_storage` and never written to SQLite,
  logs, analytics, or crash reports.
- Settings can test the connection, show a masked key, and disconnect.
- Keys are cleared on disconnect and never sent anywhere except the provider.
- Model names are configurable presets; the app must not hardcode a model that may be retired.

### 8.3 Natural-language quick-entry

Entry point: a card/text field on the Dashboard. If AI is off, show "Connect an AI provider".
If AI is on but the device is offline, the provider fails, the response times out, or the response
is invalid, show a SnackBar and open the manual entry form with the raw text in the note.

The provider must return strict JSON:

```json
{
  "amount_text": "150.00",
  "transaction_type": "EXPENSE",
  "wallet_name": "GCash",
  "category_name": "Food & Dining",
  "note": "iced coffee"
}
```

- `amount_text` is a string parsed by `Money.parsePesos`; no floating-point amounts.
- `transaction_type` is `EXPENSE` or `INCOME` in v1.5. Transfers remain manual.
- Names are hints, not IDs. Map them locally:
  - Exact case-insensitive match first.
  - Then normalization (trim, collapse spaces, remove punctuation).
  - Then fuzzy matching only if there is a unique match above the threshold.
  - Exclude archived wallets/categories.
  - Category must match the transaction type.
  - If ambiguous or missing, leave the field blank and let the user choose.
- Validate the JSON as untrusted input: reject unknown fields, zero/negative amounts, unsupported
  types, and overlong notes (200 characters).
- Never auto-save. The form opens pre-filled; the user confirms.
- The AI call has a 15-second timeout and at most one retry on transient network/5xx errors. Do not
  retry 401/400 responses.

### 8.4 AI analytics chat

A full-screen chat reachable from the Dashboard app bar. It uses fixed, read-only tools; the model
never generates SQL and never receives raw transaction rows.

Tools:

| Tool | Arguments | Returns |
|---|---|---|
| `get_category_spending` | `category_name`, `start_date`, `end_date` | Total centavos in the local-date range |
| `get_wallet_balances` | none | Active wallet names and balances; archived with non-zero balances |
| `get_monthly_summary` | `year`, `month` | Income, expense (including fees), fees, net |

Rules:

- Validate category names, ISO dates, ranges (end >= start, at most 366 days), years, and months.
- Maximum 4 tool rounds per user message.
- No write tools, no SQL, no arbitrary table access.
- Chat history is in memory for the session only; no persistence in v1.5.
- The provider receives the question and aggregate tool results. It does not receive transaction
  rows or notes.
- Show a small "AI can be wrong; check the dashboard" disclaimer.
- Handle 401 (invalid key), 429 (rate limit), timeout, offline, and malformed responses with clear
  messages; never crash.

### 8.5 Token and latency budgets

- Quick-entry: target at most 500 input tokens for the system prompt, schema, and user text;
  truncate user input to 400 characters.
- Analytics: target at most 2,000 input tokens and 500 output tokens, with the last 6 messages;
  cap tool rounds at 4.
- Network timeout: 15 seconds per provider request.
- Token counting differs by provider; these are enforced targets, not exact guarantees.

### 8.6 Privacy boundary

- Quick-entry sends the prompt text (which may contain a note).
- Chat sends the question and aggregate results only.
- Keys stay on the device.
- No telemetry, no prompt logging, no proxy.
- The app remains fully usable with AI off.

---

## 9. Functional requirements

### FR-7 Transfer fees

- **7.1** The transfer form has an optional fee field.
- **7.2** Source is debited `amount + fee`; target is credited `amount`.
- **7.3** Net worth decreases by exactly the fee; monthly expense includes the fee; the breakdown
  shows a "Transfer fees" row.
- **7.4** Editing/deleting a transfer reverses and reapplies the fee atomically.
- **7.5** Fee is shown in the transaction detail and activity list.

### FR-8 Subscriptions and reminders

- **8.1** Create/edit/archive/delete subscriptions with name, amount, wallet, category, cycle, next
  billing date/time, and auto-deduct.
- **8.2** Validate amount > 0, active wallet/category, and a supported cycle.
- **8.3** Schedule 24-hour and billing-day notifications.
- **8.4** Process due subscriptions on app start/resume and when the Subscriptions screen opens.
- **8.5** Insufficient balance: no write, no date advance, overdue state, notification.
- **8.6** "Mark as Paid" processes one cycle and re-checks the balance.
- **8.7** "Catch up all" processes all due cycles after confirmation, oldest first, stopping on
  insufficient balance.
- **8.8** `auto_deduct = 0` reminds only; no automatic write.
- **8.9** Archived wallet/category: no charge; overdue with a reason.
- **8.10** Archive stops reminders and deductions; hard delete only when no generated transactions.

### FR-9 AI quick-entry

- **9.1** Dashboard provides a natural-language input.
- **9.2** With AI configured and online, the app calls the provider directly and receives JSON.
- **9.3** The app validates the JSON, maps names locally, and opens the manual form pre-filled.
- **9.4** The user must confirm; nothing is auto-saved.
- **9.5** Offline/disabled/error/timeout/invalid JSON falls back to manual entry with the text in
  the note and a SnackBar.

### FR-10 AI analytics chat

- **10.1** A chat screen is reachable from the Dashboard.
- **10.2** The model uses the fixed read-only tools above.
- **10.3** No SQL generation, no write tools, no raw transaction rows.
- **10.4** Tool arguments are validated and bounded.
- **10.5** Chat history is session-only; a disclaimer is shown.

### FR-11 Settings, security, and privacy

- **11.1** AI mode: Off or BYOK. No proxy.
- **11.2** Keys stored only in `flutter_secure_storage`; never logged.
- **11.3** Consent is explicit and revocable.
- **11.4** Connection test and clear-key actions exist.
- **11.5** Notification permission status is visible with a link to system settings.
- **11.6** The app works fully with AI off.

### FR-12 Migration and integrity

- **12.1** v1 → v2 migration preserves 100% of wallets, categories, and transactions.
- **12.2** `verifyBalances()` includes transfer fees.
- **12.3** Subscription charges are idempotent via the subscription/period unique index and atomic
  date advancement.
- **12.4** Existing tests are updated for the new schema, indexes, and transaction fields.

---

## 10. Non-functional and security requirements

- **Offline core:** wallets, transactions, transfers, fees, subscriptions, reminders, and reports
  work in airplane mode. AI does not.
- **Migration:** additive, tested with real v1 data. `ALTER ADD COLUMN` with the fee `CHECK` plus
  table/index creation should complete well under 100 ms on a 10,000-row database; measure it. No
  table rebuild is required.
- **Performance:** dashboard and list queries remain under 50 ms with 10,000 transactions. Add
  fee aggregates and the subscription due query to the benchmark.
- **Key security:** no keys in source, logs, error messages, analytics, or crash reports. Keys are
  excluded from normal database storage.
- **AI output is untrusted:** strict JSON validation; no auto-save; no SQL; no write tools.
- **Privacy:** disclose exactly what is sent; no telemetry; no prompt logging; no proxy.
- **Accessibility:** 48dp targets, 1.3x/2.0x text scaling, light/dark contrast, semantic labels for
  new icon buttons and notification actions.
- **Battery/permissions:** reminders are best-effort; force-stop and OEM battery savers are
  documented limitations.
- **Backward compatibility:** the v1 database and all v1 features continue to work.

---

## 11. Acceptance criteria

```gherkin
Scenario: Internal transfer with a fee
  Given a "Bank" wallet with ₱5,000.00 and a "GCash" wallet with ₱1,000.00
  When the user transfers ₱1,000.00 from "Bank" to "GCash" with a ₱15.00 fee
  Then "Bank" balance is ₱3,985.00
  And "GCash" balance is ₱2,000.00
  And Net Worth decreases by exactly ₱15.00
  And the fee appears in the monthly expense total and the "Transfer fees" breakdown row

Scenario: Transfer with no fee
  Given a transfer of ₱1,000.00 with no fee
  Then Net Worth is unchanged
  And no "Transfer fees" row is shown for that transfer

Scenario: Edit and delete a fee transfer
  Given a ₱1,000.00 transfer with a ₱15.00 fee
  When the user edits the fee to ₱25.00
  Then the source wallet is debited ₱1,025.00 in total
  When the user deletes the transfer
  Then both wallet balances return to their pre-transfer values
  And Net Worth returns to its pre-transfer value

Scenario: Subscription renewal with sufficient balance
  Given an active "Claude Pro" subscription of ₱1,150.00 due today on "GCash" (₱2,000.00)
  When the app processes due subscriptions
  Then one EXPENSE transaction of ₱1,150.00 is logged with the subscription id and due period
  And "GCash" balance updates to ₱850.00
  And next_billing_at_ms advances by one month
  And a "Subscription paid" notification is requested
  And verifyBalances() returns no mismatches

Scenario: Subscription renewal with insufficient balance
  Given a due subscription of ₱1,150.00 on a wallet with ₱500.00
  When the app processes due subscriptions
  Then no transaction is logged
  And the wallet balance remains ₱500.00
  And the subscription is overdue with reason INSUFFICIENT_BALANCE
  And next_billing_at_ms is unchanged
  And a low-balance notification is requested

Scenario: Subscription processing is idempotent
  Given a subscription that was just paid for the current period
  When the runner executes again immediately
  Then no additional transaction is created
  And the wallet balance is unchanged

Scenario: Catch up all
  Given three overdue cycles for one subscription and a sufficient balance
  When the user taps "Catch up all" and confirms
  Then three EXPENSE transactions are created, oldest first
  And the next billing date advances by three cycles
  And the subscription is no longer overdue

Scenario: Billing on the 31st
  Given a monthly subscription anchored on January 31
  Then the next dates are February 28/29, then March 31

Scenario: Manual payment with insufficient balance
  Given an overdue subscription and a wallet below the amount
  When the user taps "Mark as Paid"
  Then no transaction is logged and the shortfall is shown

Scenario: Auto-deduct disabled
  Given a due subscription with auto-deduct off
  When the app processes due subscriptions
  Then no transaction is logged
  And the subscription is overdue with reason MANUAL_PAYMENT_REQUIRED

Scenario: Archived wallet blocks a charge
  Given an active subscription whose wallet is archived
  When the app processes due subscriptions
  Then no transaction is logged
  And the subscription is overdue with reason WALLET_ARCHIVED

Scenario: Notification permission denied
  Given the user denied notification permission
  When a subscription is due
  Then the app shows an in-app permission banner
  And the deduction still runs when the app opens
  And the app does not crash

Scenario: Natural language entry parsing
  Given AI is enabled with a valid key and the device is online
  When the user enters "Spent 250 on groceries via Cash"
  Then the form opens with Amount ₱250.00, Category "Groceries", Wallet "Cash"
  And the transaction is not saved until the user confirms

Scenario: Ambiguous wallet from AI
  Given the model returns a wallet name that matches multiple wallets
  Then the wallet field is left blank
  And the user must choose before saving

Scenario: Natural language offline fallback
  Given the device is in airplane mode
  When the user submits a natural language prompt
  Then a SnackBar says "Offline — opening manual entry"
  And the manual form opens with the text in the note
  And no network request is made

Scenario: Malformed AI response
  Given the provider returns invalid JSON
  Then the app falls back to manual entry
  And no partial data is saved

Scenario: AI is off by default
  Given a fresh install
  Then no AI provider call is made without the user enabling AI and adding a key

Scenario: AI chat is read-only
  Given an AI chat question
  When the model requests tools
  Then only the three read-only tools can run
  And no write tool or raw SQL is available

Scenario: v1 database migration
  Given a v1 database with wallets, categories, and transactions
  When the app opens with schema v2
  Then every row is preserved
  And existing transactions have fee_minor = 0
  And the subscriptions table and new indexes exist
  And user_version = 2
```

---

## 12. Testing strategy

| Layer | Coverage |
|---|---|
| Money / fees | Zero fee, centavo fees, large fees, fee > amount, parsing, formatting |
| Migration | Real v1 data → v2; row preservation; indexes; `user_version`; 10k rows |
| Ledger | Fee create/edit/delete; `verifyBalances`; reporting; net-worth invariance at zero fee |
| Subscriptions | Due with/without balance; auto-deduct off; archived refs; idempotency; catch-up; manual pay; month-end/leap/year-end; timezone |
| Notifications | Fake scheduler: two stages, stable IDs, cancel/reschedule, permission denied, tap payload |
| AI parsing | Valid JSON; malformed; unknown fields; wrong type; zero/negative; ambiguous wallet; wrong-type category |
| AI fallback | Offline, timeout, 401, 429, 5xx, invalid JSON; no partial writes |
| AI tools | Bounds, aggregate-only, no write tools, max rounds, real in-memory DB |
| Key storage | Fake secure storage; no logging; disconnect; invalid key |
| Widgets | Fee form, subscription list/form/overdue banner, AI settings/consent, chat, quick-entry prefill |
| Accessibility | 1.3x/2.0x text scale, contrast, 48dp targets |
| Performance | 10k transactions: dashboard, fee totals, subscription due query under 50 ms |
| Regression | All v1 tests still pass |

No live provider calls in CI. Use a fake `AiClient` with recorded responses and a fake notification
scheduler.

---

## 13. Changes from the draft v1.5 specification

| # | Draft | Change | Why |
|---|---|---|---|
| 1 | Default proxy + Gemini 1.5 Flash | Removed; BYOK only; no server | No deployed/owned proxy; avoids cost, abuse, and privacy risk |
| 2 | AI on by default | AI off by default, explicit consent | Financial data must not leave the device without consent |
| 3 | "Auto-deduct at billing timestamp via AlarmManager" | Deduction on app open/resume; notifications scheduled locally | `flutter_local_notifications` cannot run DB code in the background |
| 4 | No fee reporting | Fees included in monthly expense + "Transfer fees" row | Net worth dropped without a matching expense |
| 5 | `fee_minor` only | Fee validation, database `CHECK`, reporting, detail display, tests | Fees are user-entered, not fixed at ₱15 |
| 6 | No idempotency fields | `subscription_id`, `billing_period`, unique index, `last_paid_at_ms` | Prevents double charges and duplicate periods |
| 7 | One overdue attempt | One cycle per automatic run + "Catch up all" | Avoids surprise multiple charges |
| 8 | `amount_pesos` number in AI JSON | `amount_text` string parsed locally | Avoids floating-point money |
| 9 | "Text-to-SQL" | Fixed read-only tools; no SQL generation | Security and correctness |
| 10 | No migration test | Mandatory v1 → v2 migration test | The app is installed with real data |
| 11 | No notification platform details | Permission, boot, force-stop, OEM, inexact alarms | Honest best-effort behavior |
| 12 | FR numbering error (9.4/9.5 under FR-10) | Renumbered FR-7…FR-12 | Keep the spec testable |
| 13 | "Supersedes v1.0" | Extends v1.0; separate v1.5 doc | Preserve the shipped baseline |
| 14 | Five-tab assumption | Four tabs + app-bar Chat/Settings | Keeps navigation readable at 2.0x text scale |

---

## 14. Deferred

- Default AI proxy / zero-config AI (future version).
- Background database writes and exact-alarm deductions.
- Gemini native API support (unless its compatibility endpoint passes the Phase 0 spike).
- Persistent chat history and user accounts.
- OCR receipt scanning, cloud sync, multi-currency, bank scrapers, non-Android targets.
