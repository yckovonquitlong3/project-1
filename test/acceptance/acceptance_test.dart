import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_net_worth.dart';
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
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/create_wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The acceptance suite from SPEC section 10, executed through the real use
/// cases and an in-memory copy of the real schema.
void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl walletRepository;
  late TransactionRepositoryImpl transactionRepository;
  late DashboardRepositoryImpl dashboardRepository;

  late CreateWallet createWallet;
  late AddExpense addExpense;
  late AddIncome addIncome;
  late TransferMoney transferMoney;
  late EditTransaction editTransaction;
  late DeleteTransaction deleteTransaction;
  late GetNetWorth getNetWorth;
  late GetMonthSummary getMonthSummary;
  late VerifyBalances verifyBalances;

  const String foodCategory = 'cat-exp-food-dining';
  const String salaryCategory = 'cat-inc-salary';

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ledgerBus = LedgerBus();
    walletRepository = WalletRepositoryImpl(
      database: appDatabase,
      ledgerBus: ledgerBus,
    );
    transactionRepository = TransactionRepositoryImpl(
      database: appDatabase,
      ledgerBus: ledgerBus,
    );
    dashboardRepository = DashboardRepositoryImpl(database: appDatabase);
    final CategoryRepositoryImpl categories =
        CategoryRepositoryImpl(database: appDatabase);

    createWallet = CreateWallet(wallets: walletRepository);
    addExpense = AddExpense(
      transactions: transactionRepository,
      wallets: walletRepository,
      categories: categories,
    );
    addIncome = AddIncome(
      transactions: transactionRepository,
      wallets: walletRepository,
      categories: categories,
    );
    transferMoney = TransferMoney(
      transactions: transactionRepository,
      wallets: walletRepository,
    );
    editTransaction = EditTransaction(
      transactions: transactionRepository,
      wallets: walletRepository,
      categories: categories,
    );
    deleteTransaction = DeleteTransaction(transactions: transactionRepository);
    getNetWorth = GetNetWorth(dashboard: dashboardRepository);
    getMonthSummary = GetMonthSummary(dashboard: dashboardRepository);
    verifyBalances = VerifyBalances(transactions: transactionRepository);

    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  Future<Wallet> seedWallet(
    String name, {
    int openingMinor = 0,
    AccountType type = AccountType.cash,
  }) {
    return createWallet(
      name: name,
      accountType: type,
      iconIdentifier: 'payments',
      openingBalance: Money(openingMinor),
    );
  }

  Future<Money> balanceOf(String walletId) async {
    final Wallet? wallet = await walletRepository.byId(walletId);
    return wallet!.balance;
  }

  Future<int> transactionCount() async {
    final Database db = await appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM transactions');
    return rows.first['c']! as int;
  }

  test('Scenario: Logging an expense', () async {
    final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);
    final int before = await transactionCount();

    await addExpense(
      amount: const Money(15000),
      walletId: wallet.id,
      categoryId: foodCategory,
    );

    expect(await balanceOf(wallet.id), const Money(85000));
    expect(await getNetWorth(), const Money(85000));
    expect(await transactionCount(), before + 1);
  });

  test('Scenario: Logging income', () async {
    final Wallet wallet = await seedWallet('Cash', openingMinor: 50000);

    await addIncome(
      amount: const Money(200000),
      walletId: wallet.id,
      categoryId: salaryCategory,
    );

    expect(await balanceOf(wallet.id), const Money(250000));
  });

  test('Scenario: Internal transfer', () async {
    final Wallet bank = await seedWallet(
      'Bank',
      openingMinor: 500000,
      type: AccountType.bank,
    );
    final Wallet maya = await seedWallet(
      'Maya',
      openingMinor: 20000,
      type: AccountType.eWallet,
    );
    final Money before = await getNetWorth();

    await transferMoney(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: maya.id,
    );

    expect(await balanceOf(bank.id), const Money(400000));
    expect(await balanceOf(maya.id), const Money(120000));
    expect(await getNetWorth(), before);
  });

  test('Scenario: Internal transfer with a fee', () async {
    final Wallet bank = await seedWallet(
      'Bank',
      openingMinor: 500000,
      type: AccountType.bank,
    );
    final Wallet gcash = await seedWallet(
      'GCash',
      openingMinor: 100000,
      type: AccountType.eWallet,
    );
    final Money before = await getNetWorth();

    await transferMoney(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: gcash.id,
      fee: const Money(1500),
    );

    expect(await balanceOf(bank.id), const Money(398500));
    expect(await balanceOf(gcash.id), const Money(200000));
    expect(await getNetWorth(), before - const Money(1500));

    final MonthSummary summary =
        await getMonthSummary(month: DateTime.now());
    expect(summary.fees, const Money(1500));
    expect(summary.expense, const Money(1500));
    expect(await verifyBalances(), isEmpty);
  });

  test('Scenario: Transfer to the same wallet', () async {
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

    expect(await balanceOf(wallet.id), const Money(10000));
    expect(await transactionCount(), before);
  });

  test('Scenario: Rollback on failure', () async {
    final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);
    final TransactionRecord original = (await addExpense(
      amount: const Money(15000),
      walletId: wallet.id,
      categoryId: foodCategory,
    ));
    expect(await balanceOf(wallet.id), const Money(85000));

    final TransactionRecord stored =
        (await transactionRepository.byId(original.id))!;
    final TransactionRecord invalid = TransactionRecord(
      id: stored.id,
      amount: Money.zero,
      type: stored.type,
      sourceWalletId: stored.sourceWalletId,
      categoryId: stored.categoryId,
      occurredAt: stored.occurredAt,
      localDate: stored.localDate,
      createdAt: stored.createdAt,
      updatedAt: stored.updatedAt,
    );

    await expectLater(
      transactionRepository.edit(stored, invalid),
      throwsA(isA<DatabaseFailure>()),
    );

    expect(await balanceOf(wallet.id), const Money(85000));
    expect(
      (await transactionRepository.byId(original.id))!.amount,
      const Money(15000),
    );
  });

  test('Scenario: Edit an expense', () async {
    final Wallet wallet = await seedWallet('GCash', openingMinor: 100000);
    final TransactionRecord created = await addExpense(
      amount: const Money(15000),
      walletId: wallet.id,
      categoryId: foodCategory,
    );
    final Money before = await getNetWorth();

    await editTransaction(
      previous: (await transactionRepository.byId(created.id))!,
      amount: const Money(10000),
    );

    expect(await balanceOf(wallet.id), const Money(90000));
    expect(await getNetWorth(), before + const Money(5000));
  });

  test('Scenario: Delete a transfer', () async {
    final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
    final Wallet maya = await seedWallet('Maya', openingMinor: 20000);
    final Money before = await getNetWorth();
    final TransactionRecord transfer = await transferMoney(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: maya.id,
    );

    await deleteTransaction(transfer.id);

    expect(await balanceOf(bank.id), const Money(500000));
    expect(await balanceOf(maya.id), const Money(20000));
    expect(await getNetWorth(), before);
  });

  test('Scenario: Opening balance is auditable', () async {
    final Wallet wallet = await seedWallet('GCash', openingMinor: 250000);

    final List<TransactionRecord> history =
        await transactionRepository.forWallet(wallet.id);
    final List<TransactionRecord> opening = history
        .where(
          (TransactionRecord record) =>
              record.type == TransactionType.income &&
              record.note == 'Opening balance',
        )
        .toList();

    expect(opening.length, 1);
    expect(opening.first.amount, const Money(250000));

    final int deltas = history.fold(
      0,
      (int sum, TransactionRecord record) =>
          sum +
          (record.type == TransactionType.expense
              ? -record.amount.minorUnits
              : record.amount.minorUnits),
    );
    expect(wallet.balance.minorUnits, deltas);
    expect(await verifyBalances(), isEmpty);
  });

  test('Scenario: Balance integrity', () async {
    final Wallet first = await seedWallet('GCash', openingMinor: 100000);
    final Wallet second = await seedWallet('Bank', openingMinor: 250000);

    final TransactionRecord expense = await addExpense(
      amount: const Money(15000),
      walletId: first.id,
      categoryId: foodCategory,
    );
    await addIncome(
      amount: const Money(50000),
      walletId: first.id,
      categoryId: salaryCategory,
    );
    final TransactionRecord transfer = await transferMoney(
      amount: const Money(25000),
      sourceWalletId: second.id,
      targetWalletId: first.id,
    );
    await editTransaction(
      previous: (await transactionRepository.byId(expense.id))!,
      amount: const Money(10000),
    );
    await deleteTransaction(transfer.id);

    expect(await verifyBalances(), isEmpty);

    for (final Wallet wallet in <Wallet>[first, second]) {
      final List<TransactionRecord> history =
          await transactionRepository.forWallet(wallet.id);
      final int deltas = history.fold(
        0,
        (int sum, TransactionRecord record) {
          if (record.sourceWalletId == wallet.id) {
            return sum +
                (record.type == TransactionType.income
                    ? record.amount.minorUnits
                    : -record.amount.minorUnits);
          }
          return sum + record.amount.minorUnits;
        },
      );
      final Wallet? refreshed = await walletRepository.byId(wallet.id);
      expect(refreshed!.balance.minorUnits, deltas);
    }
  });

  test('Scenario: Monthly summary respects local time', () async {
    final Wallet wallet = await seedWallet('Cash');

    await addIncome(
      amount: const Money(100000),
      walletId: wallet.id,
      categoryId: salaryCategory,
      occurredAt: DateTime(2026, 11, 1, 7),
    );

    final MonthSummary november =
        await getMonthSummary(month: DateTime(2026, 11, 15));
    expect(november.income, const Money(100000));
    expect(november.expense, Money.zero);

    final MonthSummary october =
        await getMonthSummary(month: DateTime(2026, 10, 15));
    expect(october.income, Money.zero);
    expect(october.expense, Money.zero);
  });
}
