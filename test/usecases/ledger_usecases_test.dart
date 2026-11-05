import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_net_worth.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_recent_transactions.dart';
import 'package:multi_wallet_tracker/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/add_expense.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/add_income.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/delete_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/edit_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/transfer_money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/verify_balances.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/archive_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/create_wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Validation and delegation tests for the use case layer.
///
/// These run against the real repositories and an in-memory database, so a
/// rejected input is proven to leave the ledger untouched.
void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late TransactionRepositoryImpl transactions;
  late CategoryRepositoryImpl categories;
  late DashboardRepositoryImpl dashboard;

  late CreateWallet createWallet;
  late ArchiveWallet archiveWallet;
  late AddExpense addExpense;
  late AddIncome addIncome;
  late TransferMoney transferMoney;
  late EditTransaction editTransaction;
  late DeleteTransaction deleteTransaction;
  late VerifyBalances verifyBalances;

  const String expenseCategory = 'cat-exp-food-dining';
  const String incomeCategory = 'cat-inc-salary';
  const String groceriesCategory = 'cat-exp-groceries';

  DateTime clock() => DateTime(2026, 11, 5, 10);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
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
    categories = CategoryRepositoryImpl(database: appDatabase);
    dashboard = DashboardRepositoryImpl(database: appDatabase);

    createWallet = CreateWallet(wallets: wallets);
    archiveWallet = ArchiveWallet(wallets: wallets);
    addExpense = AddExpense(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
      clock: clock,
    );
    addIncome = AddIncome(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
      clock: clock,
    );
    transferMoney = TransferMoney(
      transactions: transactions,
      wallets: wallets,
      clock: clock,
    );
    editTransaction = EditTransaction(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
      clock: clock,
    );
    deleteTransaction = DeleteTransaction(transactions: transactions);
    verifyBalances = VerifyBalances(transactions: transactions);

    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  Future<Wallet> seedWallet(String name, {int openingMinor = 0}) {
    return createWallet(
      name: name,
      accountType: AccountType.cash,
      iconIdentifier: 'payments',
      openingBalance: Money(openingMinor),
    );
  }

  Future<int> transactionCount() async {
    final Database db = await appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM transactions');
    return rows.first['c']! as int;
  }

  Future<Money> balanceOf(String walletId) async {
    final Wallet? wallet = await wallets.byId(walletId);
    return wallet!.balance;
  }

  group('AddExpense', () {
    test('records the entry and decreases the wallet', () async {
      final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);

      final TransactionRecord saved = await addExpense(
        amount: const Money(15000),
        walletId: wallet.id,
        categoryId: expenseCategory,
        note: '  lunch  ',
      );

      expect(saved.type, TransactionType.expense);
      expect(saved.note, 'lunch');
      expect(saved.localDate, localDateOf(saved.occurredAt));
      expect(await balanceOf(wallet.id), const Money(85000));
      expect(await verifyBalances(), isEmpty);
    });

    test('rejects a zero amount and writes nothing', () async {
      final Wallet wallet = await seedWallet('GCash');

      await expectLater(
        addExpense(
          amount: Money.zero,
          walletId: wallet.id,
          categoryId: expenseCategory,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(await transactionCount(), 0);
      expect(await balanceOf(wallet.id), Money.zero);
    });

    test('rejects a negative amount', () async {
      final Wallet wallet = await seedWallet('GCash');

      await expectLater(
        addExpense(
          amount: const Money(-500),
          walletId: wallet.id,
          categoryId: expenseCategory,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await transactionCount(), 0);
    });

    test('rejects an archived wallet', () async {
      final Wallet wallet = await seedWallet('Old wallet');
      await archiveWallet(wallet.id);

      await expectLater(
        addExpense(
          amount: const Money(500),
          walletId: wallet.id,
          categoryId: expenseCategory,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(await transactionCount(), 0);
    });

    test('rejects a category of the wrong type', () async {
      final Wallet wallet = await seedWallet('Cash');

      await expectLater(
        addExpense(
          amount: const Money(500),
          walletId: wallet.id,
          categoryId: incomeCategory,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(await transactionCount(), 0);
    });

    test('rejects a wallet that does not exist', () async {
      await expectLater(
        addExpense(
          amount: const Money(500),
          walletId: 'missing',
          categoryId: expenseCategory,
        ),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(await transactionCount(), 0);
    });
  });

  group('AddIncome', () {
    test('records the entry and increases the wallet', () async {
      final Wallet wallet = await seedWallet('Cash', openingMinor: 50000);

      await addIncome(
        amount: const Money(200000),
        walletId: wallet.id,
        categoryId: incomeCategory,
      );

      expect(await balanceOf(wallet.id), const Money(250000));
      expect(await verifyBalances(), isEmpty);
    });
  });

  group('TransferMoney', () {
    test('moves money between two wallets', () async {
      final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
      final Wallet maya = await seedWallet('Maya', openingMinor: 20000);

      await transferMoney(
        amount: const Money(100000),
        sourceWalletId: bank.id,
        targetWalletId: maya.id,
      );

      expect(await balanceOf(bank.id), const Money(400000));
      expect(await balanceOf(maya.id), const Money(120000));
      expect(await verifyBalances(), isEmpty);
    });

    test('rejects the same wallet on both sides and writes nothing', () async {
      final Wallet wallet = await seedWallet('Cash', openingMinor: 10000);
      final int before = await transactionCount();

      await expectLater(
        transferMoney(
          amount: const Money(1000),
          sourceWalletId: wallet.id,
          targetWalletId: wallet.id,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(await transactionCount(), before);
      expect(await balanceOf(wallet.id), const Money(10000));
    });
  });

  group('EditTransaction', () {
    test('reverses the old amount and applies the new one', () async {
      final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);
      final TransactionRecord created = await addExpense(
        amount: const Money(15000),
        walletId: wallet.id,
        categoryId: expenseCategory,
      );
      final TransactionRecord stored = (await transactions.byId(created.id))!;

      final TransactionRecord updated = await editTransaction(
        previous: stored,
        amount: const Money(10000),
      );

      expect(updated.id, stored.id);
      expect(updated.type, TransactionType.expense);
      expect(updated.amount, const Money(10000));
      expect(await balanceOf(wallet.id), const Money(90000));
      expect(await verifyBalances(), isEmpty);
    });

    test('keeps history editable after its wallet is archived', () async {
      final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);
      final TransactionRecord created = await addExpense(
        amount: const Money(15000),
        walletId: wallet.id,
        categoryId: expenseCategory,
      );
      await archiveWallet(wallet.id);
      final TransactionRecord stored = (await transactions.byId(created.id))!;

      final TransactionRecord updated = await editTransaction(
        previous: stored,
        amount: const Money(10000),
      );

      expect(updated.amount, const Money(10000));
      expect(await balanceOf(wallet.id), const Money(90000));
      expect(await verifyBalances(), isEmpty);
    });

    test('rejects zero on edit and leaves the old row intact', () async {
      final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);
      final TransactionRecord created = await addExpense(
        amount: const Money(15000),
        walletId: wallet.id,
        categoryId: expenseCategory,
      );
      final TransactionRecord stored = (await transactions.byId(created.id))!;

      await expectLater(
        editTransaction(previous: stored, amount: Money.zero),
        throwsA(isA<ValidationFailure>()),
      );

      expect(await balanceOf(wallet.id), const Money(85000));
      expect((await transactions.byId(created.id))!.amount, const Money(15000));
    });
  });

  group('DeleteTransaction', () {
    test('restores the balance and removes the row', () async {
      final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);
      final TransactionRecord created = await addExpense(
        amount: const Money(15000),
        walletId: wallet.id,
        categoryId: expenseCategory,
      );

      await deleteTransaction(created.id);

      expect(await balanceOf(wallet.id), const Money(100000));
      expect(await transactions.byId(created.id), isNull);
      expect(await verifyBalances(), isEmpty);
    });

    test('reports an unknown transaction', () async {
      await expectLater(
        deleteTransaction('missing'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('CreateWallet', () {
    test('trims the name and records an opening balance', () async {
      final Wallet wallet = await createWallet(
        name: '  GCash  ',
        accountType: AccountType.eWallet,
        iconIdentifier: 'wallet',
        openingBalance: const Money(250000),
      );

      expect(wallet.name, 'GCash');
      expect(wallet.balance, const Money(250000));

      final List<TransactionRecord> history = await transactions.recent();
      expect(history.length, 1);
      expect(history.first.type, TransactionType.income);
      expect(history.first.amount, const Money(250000));
      expect(await verifyBalances(), isEmpty);
    });

    test('rejects a blank name', () {
      expect(
        () => createWallet(
          name: '   ',
          accountType: AccountType.cash,
          iconIdentifier: 'payments',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects a negative opening balance', () {
      expect(
        () => createWallet(
          name: 'Cash',
          accountType: AccountType.cash,
          iconIdentifier: 'payments',
          openingBalance: const Money(-1),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('ArchiveWallet', () {
    test('reports an unknown wallet', () async {
      await expectLater(
        archiveWallet('missing'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('read use cases', () {
    test('compute net worth, month totals, breakdown and recents', () async {
      final Wallet wallet = await seedWallet('Cash');

      await addExpense(
        amount: const Money(3000),
        walletId: wallet.id,
        categoryId: groceriesCategory,
        occurredAt: DateTime(2026, 11, 2, 9),
      );
      await addIncome(
        amount: const Money(100000),
        walletId: wallet.id,
        categoryId: incomeCategory,
        occurredAt: DateTime(2026, 11, 2, 10),
      );

      final Money net = await GetNetWorth(dashboard: dashboard)();
      expect(net, const Money(97000));

      final MonthSummary summary =
          await GetMonthSummary(dashboard: dashboard)(month: DateTime(2026, 11));
      expect(summary.income, const Money(100000));
      expect(summary.expense, const Money(3000));
      expect(summary.net, const Money(97000));

      final List<CategoryBreakdown> breakdown =
          await GetCategoryBreakdown(dashboard: dashboard)(
        month: DateTime(2026, 11),
      );
      expect(breakdown.length, 1);
      expect(breakdown.first.categoryId, groceriesCategory);
      expect(breakdown.first.total, const Money(3000));

      final List<DashboardTransaction> recent =
          await GetRecentTransactions(dashboard: dashboard)(limit: 10);
      expect(recent.length, 2);
      expect(recent.first.type, TransactionType.income);

      expect(await verifyBalances(), isEmpty);
    });
  });
}
