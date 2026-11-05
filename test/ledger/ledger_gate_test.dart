import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The ledger gate: ten tests that must pass before any UI work starts.
///
/// They exercise the real schema through the real repositories against an
/// in-memory SQLite database, so the SQL, the CHECK constraints, and the
/// transaction boundaries are all under test.
void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late TransactionRepositoryImpl transactions;
  late DashboardRepositoryImpl dashboard;

  var nextId = 0;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    nextId = 0;
    appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ledgerBus = LedgerBus();
    wallets = WalletRepositoryImpl(database: appDatabase, ledgerBus: ledgerBus);
    transactions = TransactionRepositoryImpl(
      database: appDatabase,
      ledgerBus: ledgerBus,
    );
    dashboard = DashboardRepositoryImpl(database: appDatabase);
    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  Future<Wallet> createWallet(
    String name, {
    int openingMinor = 0,
    AccountType type = AccountType.cash,
  }) async {
    final Wallet created = await wallets.create(
      name: name,
      accountType: type,
      iconIdentifier: 'payments',
      openingBalance: Money(openingMinor),
    );
    return created;
  }

  Future<Money> balanceOf(String walletId) async {
    final Wallet? wallet = await wallets.byId(walletId);
    expect(wallet, isNotNull);
    return wallet!.balance;
  }

  TransactionRecord record({
    required TransactionType type,
    required int amountMinor,
    required String sourceWalletId,
    String? targetWalletId,
    String? categoryId,
    DateTime? occurredAt,
    String? id,
  }) {
    final DateTime when = occurredAt ?? DateTime.now();
    return TransactionRecord(
      id: id ?? 'tx-${nextId++}',
      amount: Money(amountMinor),
      type: type,
      sourceWalletId: sourceWalletId,
      targetWalletId: targetWalletId,
      categoryId: categoryId,
      occurredAt: when,
      localDate: localDateOf(when),
      createdAt: when,
      updatedAt: when,
    );
  }

  const String expenseCategory = 'cat-exp-food-dining';
  const String incomeCategory = 'cat-inc-salary';

  test('1. expense decreases one wallet by the exact amount', () async {
    final Wallet wallet = await createWallet('GCash', openingMinor: 100000);

    await transactions.record(
      record(
        type: TransactionType.expense,
        amountMinor: 15000,
        sourceWalletId: wallet.id,
        categoryId: expenseCategory,
      ),
    );

    expect(await balanceOf(wallet.id), const Money(85000));
    expect(await dashboard.netWorth(), const Money(85000));
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('2. income increases one wallet by the exact amount', () async {
    final Wallet wallet = await createWallet('Cash', openingMinor: 50000);

    await transactions.record(
      record(
        type: TransactionType.income,
        amountMinor: 200000,
        sourceWalletId: wallet.id,
        categoryId: incomeCategory,
      ),
    );

    expect(await balanceOf(wallet.id), const Money(250000));
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('3. transfer moves money and leaves net worth unchanged', () async {
    final Wallet bank = await createWallet(
      'Bank',
      openingMinor: 500000,
      type: AccountType.bank,
    );
    final Wallet maya = await createWallet(
      'Maya',
      openingMinor: 20000,
      type: AccountType.eWallet,
    );
    final Money before = await dashboard.netWorth();

    await transactions.record(
      record(
        type: TransactionType.transfer,
        amountMinor: 100000,
        sourceWalletId: bank.id,
        targetWalletId: maya.id,
      ),
    );

    expect(await balanceOf(bank.id), const Money(400000));
    expect(await balanceOf(maya.id), const Money(120000));
    expect(await dashboard.netWorth(), before);
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('4. editing an expense reverses the old amount and applies the new one',
      () async {
    final Wallet wallet = await createWallet('GCash', openingMinor: 100000);
    final TransactionRecord original = record(
      type: TransactionType.expense,
      amountMinor: 15000,
      sourceWalletId: wallet.id,
      categoryId: expenseCategory,
    );
    await transactions.record(original);
    expect(await balanceOf(wallet.id), const Money(85000));

    final TransactionRecord stored = (await transactions.byId(original.id))!;
    final TransactionRecord updated = record(
      id: stored.id,
      type: TransactionType.expense,
      amountMinor: 10000,
      sourceWalletId: wallet.id,
      categoryId: expenseCategory,
      occurredAt: stored.occurredAt,
    );
    await transactions.edit(stored, updated);

    expect(await balanceOf(wallet.id), const Money(90000));
    expect(await dashboard.netWorth(), const Money(90000));
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('5. deleting an expense restores the pre-transaction balance', () async {
    final Wallet wallet = await createWallet('GCash', openingMinor: 100000);
    final TransactionRecord expense = record(
      type: TransactionType.expense,
      amountMinor: 15000,
      sourceWalletId: wallet.id,
      categoryId: expenseCategory,
    );
    await transactions.record(expense);
    expect(await balanceOf(wallet.id), const Money(85000));

    final TransactionRecord stored = (await transactions.byId(expense.id))!;
    await transactions.delete(stored);

    expect(await balanceOf(wallet.id), const Money(100000));
    expect(await transactions.byId(expense.id), isNull);
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('6. deleting a transfer restores both wallets', () async {
    final Wallet bank = await createWallet('Bank', openingMinor: 500000);
    final Wallet maya = await createWallet('Maya', openingMinor: 20000);
    final Money before = await dashboard.netWorth();

    final TransactionRecord transfer = record(
      type: TransactionType.transfer,
      amountMinor: 100000,
      sourceWalletId: bank.id,
      targetWalletId: maya.id,
    );
    await transactions.record(transfer);
    final TransactionRecord stored = (await transactions.byId(transfer.id))!;
    await transactions.delete(stored);

    expect(await balanceOf(bank.id), const Money(500000));
    expect(await balanceOf(maya.id), const Money(20000));
    expect(await dashboard.netWorth(), before);
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('7. rollback: a failure after the balance update leaves no trace',
      () async {
    final Wallet wallet = await createWallet('GCash', openingMinor: 100000);
    final TransactionRecord original = record(
      type: TransactionType.expense,
      amountMinor: 15000,
      sourceWalletId: wallet.id,
      categoryId: expenseCategory,
    );
    await transactions.record(original);
    expect(await balanceOf(wallet.id), const Money(85000));

    // The edit path reverses the old effect, then writes the row, then applies
    // the new effect. An amount of zero violates the CHECK constraint on the
    // update, i.e. the failure happens *after* the reversal. The whole unit of
    // work must roll back.
    final TransactionRecord stored = (await transactions.byId(original.id))!;
    final TransactionRecord invalid = record(
      id: stored.id,
      type: TransactionType.expense,
      amountMinor: 0,
      sourceWalletId: wallet.id,
      categoryId: expenseCategory,
      occurredAt: stored.occurredAt,
    );

    await expectLater(
      transactions.edit(stored, invalid),
      throwsA(isA<DatabaseFailure>()),
    );

    expect(await balanceOf(wallet.id), const Money(85000));
    expect((await transactions.byId(original.id))!.amount, const Money(15000));
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('8. a transfer to the same wallet is rejected and writes nothing',
      () async {
    final Wallet wallet = await createWallet('Cash');

    await expectLater(
      transactions.record(
        record(
          type: TransactionType.transfer,
          amountMinor: 1000,
          sourceWalletId: wallet.id,
          targetWalletId: wallet.id,
        ),
      ),
      throwsA(isA<Failure>()),
    );

    expect(await balanceOf(wallet.id), Money.zero);
    expect(await transactions.forWallet(wallet.id), isEmpty);
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('9. verifyBalances is empty after 200 randomized mutations', () async {
    final Random random = Random(42);
    final List<Wallet> list = <Wallet>[];
    for (var i = 0; i < 4; i++) {
      list.add(await createWallet('Wallet $i', openingMinor: random.nextInt(500000) + 1));
    }
    final List<String> live = <String>[];

    for (var step = 0; step < 200; step++) {
      final int action = random.nextInt(11);
      final int amount = random.nextInt(20000) + 1;

      if (action < 4) {
        final Wallet source = list[random.nextInt(list.length)];
        final TransactionRecord created = record(
          type: TransactionType.expense,
          amountMinor: amount,
          sourceWalletId: source.id,
          categoryId: expenseCategory,
        );
        await transactions.record(created);
        live.add(created.id);
      } else if (action < 7) {
        final Wallet source = list[random.nextInt(list.length)];
        final TransactionRecord created = record(
          type: TransactionType.income,
          amountMinor: amount,
          sourceWalletId: source.id,
          categoryId: incomeCategory,
        );
        await transactions.record(created);
        live.add(created.id);
      } else if (action < 9) {
        final int fromIndex = random.nextInt(list.length);
        var toIndex = random.nextInt(list.length - 1);
        if (toIndex >= fromIndex) {
          toIndex++;
        }
        final TransactionRecord created = record(
          type: TransactionType.transfer,
          amountMinor: amount,
          sourceWalletId: list[fromIndex].id,
          targetWalletId: list[toIndex].id,
        );
        await transactions.record(created);
        live.add(created.id);
      } else if (action == 9 && live.isNotEmpty) {
        final String id = live[random.nextInt(live.length)];
        final TransactionRecord? stored = await transactions.byId(id);
        if (stored != null) {
          await transactions.edit(
            stored,
            record(
              id: stored.id,
              type: stored.type,
              amountMinor: amount,
              sourceWalletId: stored.sourceWalletId,
              targetWalletId: stored.targetWalletId,
              categoryId: stored.categoryId,
              occurredAt: stored.occurredAt,
            ),
          );
        }
      } else if (live.isNotEmpty) {
        final String id = live.removeAt(random.nextInt(live.length));
        final TransactionRecord? stored = await transactions.byId(id);
        if (stored != null) {
          await transactions.delete(stored);
        }
      }
    }

    expect(await transactions.verifyBalances(), isEmpty);

    // Independent re-computation of the invariant in Dart.
    int signedDelta(TransactionRecord value, String walletId) {
      switch (value.type) {
        case TransactionType.expense:
          return value.sourceWalletId == walletId ? -value.amount.minorUnits : 0;
        case TransactionType.income:
          return value.sourceWalletId == walletId ? value.amount.minorUnits : 0;
        case TransactionType.transfer:
          if (value.sourceWalletId == walletId) {
            return -value.amount.minorUnits;
          }
          if (value.targetWalletId == walletId) {
            return value.amount.minorUnits;
          }
          return 0;
      }
    }

    var totalMinor = 0;
    final List<Wallet> all = await wallets.all();
    for (final Wallet wallet in all) {
      final List<TransactionRecord> history =
          await transactions.forWallet(wallet.id, limit: 100000);
      final int expected = history.fold(
        0,
        (int sum, TransactionRecord item) =>
            sum + signedDelta(item, wallet.id),
      );
      expect(
        wallet.balance.minorUnits,
        expected,
        reason: 'wallet ${wallet.name} drifted from its ledger',
      );
      totalMinor += wallet.balance.minorUnits;
    }
    expect((await dashboard.netWorth()).minorUnits, totalMinor);
  });

  test('10. monthly summary groups on the local calendar date', () async {
    final Wallet wallet = await createWallet('Cash');

    await transactions.record(
      record(
        type: TransactionType.income,
        amountMinor: 100000,
        sourceWalletId: wallet.id,
        categoryId: incomeCategory,
        occurredAt: DateTime(2026, 11, 1, 7),
      ),
    );
    await transactions.record(
      record(
        type: TransactionType.expense,
        amountMinor: 25000,
        sourceWalletId: wallet.id,
        categoryId: expenseCategory,
        occurredAt: DateTime(2026, 10, 31, 23, 59),
      ),
    );

    final november = await dashboard.monthSummary(DateTime(2026, 11, 15));
    expect(november.income, const Money(100000));
    expect(november.expense, Money.zero);

    final october = await dashboard.monthSummary(DateTime(2026, 10, 15));
    expect(october.income, Money.zero);
    expect(october.expense, const Money(25000));
  });
}
