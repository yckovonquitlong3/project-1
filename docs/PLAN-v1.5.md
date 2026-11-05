# Implementation Plan — Multi-Wallet Finance Tracker V1.5

Companion to [`SPEC-v1.5.md`](./SPEC-v1.5.md) and the v1.0 baseline in
[`SPEC.md`](./SPEC.md). Each phase has a verification gate that must pass before the next one
starts.

**Rules**

1. The ledger is tested before UI work. Fees must pass the ledger gate before any subscription or
   AI screen is built.
2. No phase may bypass `applyEffect` or weaken `verifyBalances`.
3. No background database writes in v1.5. Notifications are scheduled locally; deductions run in
   the foreground.
4. No proxy, no server, no bundled AI key. AI is BYOK only and off by default.
5. No live AI provider calls in CI. Use fakes with recorded fixtures.
6. Every schema change bumps `kSchemaVersion` and has a migration test.
7. API keys are never logged, committed, or stored in SQLite.

---

## Phase 0 — Spikes and decision confirmation

### Task 0.1 Notification spike on the real phone

Add `flutter_local_notifications`, `timezone`, and `flutter_timezone` behind a small debug-only
test button. Verify:

- A notification scheduled 2 minutes ahead fires with the app backgrounded and swiped away.
- It fires with the screen locked.
- It survives a phone reboot (boot receiver).
- It does **not** fire after a Settings → Force stop (documented limitation).
- The device's battery optimization does not silently block it; note any OEM guidance needed.
- The notification tap payload opens the intended route.

Record the results and any Android setup requirements (desugaring, icon, channels, permissions).

**Gate:** notification behavior confirmed on the target device. If the spike contradicts the plan,
update the spec before proceeding.

### Task 0.2 AI BYOK spike

Using a personal provider key (never committed):

- Confirm direct HTTPS requests to OpenAI and DeepSeek.
- Confirm strict JSON output for quick-entry.
- Confirm tool/function calling for the analytics tools.
- Measure approximate token usage and latency.
- If Gemini is a candidate preset, verify its OpenAI-compatible endpoint and tool support.
- Confirm 401/429/timeout error shapes.

**Gate:** request/response fixtures recorded for tests; provider presets finalized.

### Task 0.3 Migration dry run

Create a v1 database with wallets, categories, and transactions. Run the planned v2 migration on a
copy. Measure duration and verify row counts, `user_version`, and indexes.

**Gate:** migration is additive and preserves all data; the fixture is kept for the migration test.

---

## Phase 1 — Schema v2, transfer fees, reporting, migration

### Task 1.1 Migration

- Set `kSchemaVersion = 2`.
- Make `migrate(db, 0, 2)` the single creation/upgrade path:
  - Case 1: existing v1 schema.
  - Case 2: create `subscriptions`, add `fee_minor` with the combined
    `CHECK (fee_minor >= 0 AND (fee_minor = 0 OR transaction_type = 'TRANSFER'))`,
    add `subscription_id` and `billing_period`, and add the new indexes.
- `onCreate` runs `migrate(db, 0, 2)` then seeds categories.
- Update all tests that assert the index count and `user_version`.
- Add `test/core/migration_v2_test.dart` using a real v1 fixture; assert row preservation,
  `fee_minor = 0`, the new table/indexes, and `user_version = 2`.
- Assert the database rejects a negative fee and a non-transfer transaction with a fee.

### Task 1.2 Domain and data model

- Add `fee` (`Money`, default zero) to `TransactionRecord`.
- Add optional `subscriptionId` and `billingPeriod` fields.
- Map `fee_minor`, `subscription_id`, `billing_period` in `TransactionModel`.
- Add a fee parser that allows zero (do not reuse the amount-only parser without an adjustment).
- Validate: fee >= 0, at most 2 decimals, only on transfers; non-transfers store zero.

### Task 1.3 Ledger

- `TransactionDao.applyEffect`: source `-(amount + fee)`, target `+amount`.
- `verifyBalances()`: include `fee_minor` for transfer sources.
- `TransferMoney`: accept and validate the fee.
- `EditTransaction`: accept and validate fee changes.
- `TransactionDetailScreen` and the activity list show the fee.
- Tests: zero fee invariance, ₱15 fee, large fee, fee > amount warning path, edit fee, delete fee
  transfer, `verifyBalances` empty after each.

### Task 1.4 Reporting

- `MonthSummary` gains `fees`; `expense` includes fees.
- `DashboardDao.monthTotals` adds fee totals.
- Category breakdown adds the synthetic `__transfer_fees__` row when fees exist.
- Dashboard shows the fee portion when non-zero.
- AI monthly-summary tool contract includes `fee_minor` (implemented in Phase 5).
- Tests: monthly totals, breakdown totals sum to expense, zero-fee month has no fee row.

**Gate:** full existing suite plus fee/migration tests pass. Manual check: a fee transfer changes
net worth by exactly the fee and appears in the month's expenses.

---

## Phase 2 — Subscription domain and runner

No UI and no OS notifications in this phase.

### Task 2.1 Data layer

- `Subscription` entity, `SubscriptionModel`, `SubscriptionDao`, `SubscriptionRepository`.
- CRUD, archive, due query (`is_active = 1 AND next_billing_at_ms <= now`), and generated-transaction
  checks.
- Friendly `ConflictFailure` for wallet/category hard deletes with subscriptions.

### Task 2.2 Billing schedule

- Shared helper for `WEEKLY`, `MONTHLY`, `YEARLY`.
- Preserve the anchor day and local time; clamp short months and leap years.
- Late payments advance from the scheduled date, not from now.
- Unit tests: Jan 31 → Feb 28/29 → Mar 31; Dec 31 + 1 year; weekly across month boundaries; local
  time preserved.

### Task 2.3 Runner

`RunDueSubscriptions` with injected clock, notification interface, repository, and ledger bus.

- Process oldest due cycle once per automatic run.
- Re-check wallet/category active state and balance inside the transaction.
- Atomic insert + balance + next billing + `last_paid_at_ms` + overdue recompute.
- Idempotency via the `(subscription_id, billing_period)` unique index.
- `auto_deduct = 0`: no write; overdue with `MANUAL_PAYMENT_REQUIRED`.
- Insufficient balance: no write, no advance, overdue, notify.
- Archived wallet/category: no write, overdue with the matching reason.
- "Mark as Paid" (one cycle) and "Catch up all" (confirmed, oldest first, stops on failure).
- Run lock to prevent overlapping executions.
- Emit `LedgerBus` after successful writes.

### Task 2.4 Tests

- Sufficient, insufficient, auto-deduct off, archived wallet/category.
- Idempotency: run twice; one charge.
- Catch-up: three cycles; one per automatic run; all with `catchUpAll`; stop on insufficient.
- Month-end/leap/year-end.
- Charge transaction has the correct date, period, subscription id, category, and fee = 0.
- `verifyBalances` empty after every path.

**Gate:** all runner tests pass against the real in-memory schema. No notification or UI code yet.

---

## Phase 3 — Subscription UI and local notifications

### Task 3.1 UI

- Add the fourth tab: **Subscriptions**.
- List: name, amount, next billing date, cycle, auto-deduct badge, overdue badge/reason.
- Form: name, amount, wallet, category, cycle, next billing date/time, auto-deduct; validation.
- Detail: edit, archive/restore, delete (blocked when transactions exist), Mark as Paid, Catch up
  all.
- Overdue banner with reason and actions.
- Block archiving a wallet with active subscriptions; friendly hard-delete errors.
- Empty state and loading/error states.

### Task 3.2 Notifications

- `NotificationScheduler` interface and `flutter_local_notifications` adapter.
- Channels, 24-hour and billing-day notifications, stable IDs, payloads.
- Schedule upcoming cycles for 12 months with a documented cap; cancel/reschedule on create, edit,
  archive, delete, and app resume.
- Request `POST_NOTIFICATIONS`; show an in-app banner if denied.
- Tap payload opens the subscription detail route via a navigator key.
- Boot rescheduling per the Phase 0 findings.

### Task 3.3 Triggers

- Run due subscriptions on app start/resume and when the Subscriptions screen opens.
- Optional foreground timer while the app stays open.
- No background DB writes.

### Task 3.4 Tests and manual verification

- Widget tests: list, form validation, overdue banner, mark paid, catch up all, archived section.
- Fake scheduler: correct stages/IDs, cancellation, permission-denied path.
- On-device: notifications fire while the app is closed; deduction happens on next open; force-stop
  limitation confirmed.

**Gate:** device verification passes; no duplicate charges; no background writes.

---

## Phase 4 — AI foundation and quick-entry

### Task 4.1 Settings and secure storage

- AI mode: Off / BYOK.
- Consent screen with exactly what is sent; store consent version.
- Provider presets (OpenAI, DeepSeek; Gemini only if Phase 0 verified it).
- Key entry, masked display, test connection, disconnect/clear.
- Keys in `flutter_secure_storage`; no logging; no SQLite.

### Task 4.2 Provider client

- Direct HTTPS via `http`; 15-second timeout; one retry on transient/5xx, none on 401/400.
- Strict JSON for quick-entry; tool calls for chat.
- Error mapping: offline, timeout, 401, 429, 5xx, malformed JSON.
- `AiClient` interface with a fake for tests.

### Task 4.3 Quick-entry

- Dashboard card/text field; hidden or "Connect AI" when off.
- Input cap 400 characters; token target ≤ 500.
- JSON contract with `amount_text`, `transaction_type` (EXPENSE/INCOME), wallet/category names, note.
- Strict validation, local fuzzy matching (exact → normalized → unique fuzzy), archived exclusion,
  category type check.
- Open `AddTransactionScreen` with a validated draft; no auto-save.
- Offline/disabled/error fallback opens manual entry with the text in the note and a SnackBar.

### Task 4.4 Tests

- Parser: valid, malformed, unknown fields, zero/negative, wrong type, overlong note.
- Matching: exact, case, punctuation, ambiguous, archived, wrong category type.
- Fallbacks: offline, timeout, 401, 429, 5xx, invalid JSON.
- No provider call when AI is off; no auto-save.
- Key storage fake: save, mask, clear, invalid key.

**Gate:** all tests use fakes; AI remains off by default.

---

## Phase 5 — AI analytics chat

### Task 5.1 Tools

- Implement the three read-only tools against the repositories/DAOs.
- Validate dates, ranges (≤ 366 days), years, months, and category names.
- Return aggregates only; no raw rows, notes, or IDs.
- No write tools, no SQL generation; max 4 tool rounds.

### Task 5.2 Chat

- Full-screen route from the Dashboard app bar.
- Message list, input, send, loading, cancel, clear, disclaimer.
- Session-only history; no persistence.
- Error states: offline, 401, 429, timeout, malformed tool response.
- Token budget: ≤ 2,000 input, ≤ 500 output, last 6 messages.

### Task 5.3 Tests

- Tool argument bounds and `verifyBalances` read-only behavior.
- No write tool is exposed.
- Max rounds, timeout, and error fallbacks.
- Fake provider fixtures; no live calls.

**Gate:** read-only guarantees are tested; chat cannot write to the ledger.

---

## Phase 6 — Navigation, accessibility, privacy polish

- Four tabs: Dashboard, Wallets, Activity, Subscriptions.
- AI Chat and Settings as Dashboard app-bar actions.
- Quick-entry card placement on the Dashboard.
- Notification permission banner and System Settings link.
- Consent/privacy screen; "What AI can see"; clear-key flow.
- 1.3x/2.0x text-scale tests for all new screens; 48dp targets; light/dark contrast.
- Empty, loading, error, and permission-denied states.
- Update README (core offline, AI optional, no proxy) and the offline verification text.

**Gate:** accessibility suite passes; no overflow at 2.0x; four-tab layout verified.

---

## Phase 7 — QA and release

### Task 7.1 Regression and performance

- Full suite: v1 regression + v1.5 tests.
- 10,000-transaction benchmark: dashboard queries, fee aggregates, subscription due query; all
  under 50 ms.
- Migration timing on the 10k fixture.

### Task 7.2 Device verification

- Upgrade a v1 database on the phone to v2; verify wallets, transactions, and balances.
- Test notifications with the app closed, after reboot, and after force-stop.
- Test insufficient balance, manual payment, catch-up, auto-deduct off, archived wallet.
- Airplane mode: core ledger and subscriptions work; AI falls back gracefully.
- BYOK with a real key; test invalid/revoked key; disconnect clears it.

### Task 7.3 Release

- App version `1.5.0+2`; schema v2.
- Release APK; inspect permissions (`INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`, boot).
- Privacy policy/Data Safety notes.
- README and docs updated; tag `v1.5.0` after approval.

**Gate:** tests, device checks, and release build pass; the v1 → v2 upgrade is verified on real
data.

---

## Test gates by phase

| Phase | Gate |
|---|---|
| 0 | Notification spike, AI BYOK spike, migration dry run recorded |
| 1 | Fee ledger, reporting, migration tests; existing suite passes |
| 2 | Subscription runner tests: balance, idempotency, catch-up, dates |
| 3 | Subscription UI, fake scheduler, on-device notifications |
| 4 | AI quick-entry parsing, matching, fallback, key security |
| 5 | Read-only tools, chat errors, no writes |
| 6 | 1.3x/2.0x, contrast, 48dp, four-tab navigation |
| 7 | Full regression, 10k performance, real-device migration, release APK |

---

## Definition of done

- Every acceptance scenario in `SPEC-v1.5.md` has a passing automated test or a documented manual
  device check.
- No background database writes; no proxy; AI is off by default and BYOK only.
- All fee paths go through `applyEffect`; `verifyBalances` is empty.
- The v1 → v2 migration preserves all existing data.
- Keys never appear in logs, source, SQLite, or crash output.
- `flutter analyze` is clean; the full test suite passes.
- The release APK installs over v1 and keeps the existing ledger.
