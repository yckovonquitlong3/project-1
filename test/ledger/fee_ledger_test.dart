import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_net_worth.dart';
import 'package:multi_wallet_tracker/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/delete_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/edit_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/transfer_money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/verify_balances.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late TransactionRepositoryImpl transactions;
  late DashboardRepositoryImpl dashboard;
  late TransferMoney transferMoney;
  late EditTransaction editTransaction;
  late DeleteTransaction deleteTransaction;
  late GetNetWorth getNetWorth;
  late GetMonthSummary getMonthSummary;
  late GetCategoryBreakdown getCategoryBreakdown;
  late VerifyBalances verifyBalances;

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
    dashboard = DashboardRepositoryImpl(database: appDatabase);
    final CategoryRepositoryImpl categories =
        CategoryRepositoryImpl(database: appDatabase);

    transferMoney = TransferMoney(
      transactions: transactions,
      wallets: wallets,
    );
    editTransaction = EditTransaction(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );
    deleteTransaction = DeleteTransaction(transactions: transactions);
    getNetWorth = GetNetWorth(dashboard: dashboard);
    getMonthSummary = GetMonthSummary(dashboard: dashboard);
    getCategoryBreakdown = GetCategoryBreakdown(dashboard: dashboard);
    verifyBalances = VerifyBalances(transactions: transactions);

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
    return wallets.create(
      name: name,
      accountType: type,
      iconIdentifier: 'payments',
      openingBalance: Money(openingMinor),
    );
  }

  Future<Money> balanceOf(String walletId) async {
    final Wallet? wallet = await wallets.byId(walletId);
    return wallet!.balance;
  }

  Future<int> transactionCount() async {
    final Database db = await appDatabase.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM transactions');
    return rows.first['c']! as int;
  }

  test('a transfer fee decreases net worth and is reported', () async {
    final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
    final Wallet gcash = await seedWallet('GCash', openingMinor: 100000);
    final Money before = await getNetWorth();

    final TransactionRecord transfer = await transferMoney(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: gcash.id,
      fee: const Money(1500),
      occurredAt: DateTime(2026, 11, 6, 10),
    );

    expect(await balanceOf(bank.id), const Money(398500));
    expect(await balanceOf(gcash.id), const Money(200000));
    expect(transfer.fee, const Money(1500));
    expect(await getNetWorth(), before - const Money(1500));
    expect(await verifyBalances(), isEmpty);

    final MonthSummary summary =
        await getMonthSummary(month: DateTime(2026, 11));
    expect(summary.expense, const Money(1500));
    expect(summary.fees, const Money(1500));

    final List<CategoryBreakdown> breakdown =
        await getCategoryBreakdown(month: DateTime(2026, 11));
    final CategoryBreakdown fees = breakdown.singleWhere(
      (CategoryBreakdown item) => item.categoryId == '__transfer_fees__',
    );
    expect(fees.total, const Money(1500));
  });

  test('a zero fee keeps net worth unchanged and adds no fee row', () async {
    final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
    final Wallet gcash = await seedWallet('GCash', openingMinor: 100000);
    final Money before = await getNetWorth();

    await transferMoney(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: gcash.id,
      occurredAt: DateTime(2026, 11, 6, 10),
    );

    expect(await getNetWorth(), before);
    expect(await balanceOf(bank.id), const Money(400000));
    expect(await balanceOf(gcash.id), const Money(200000));

    final MonthSummary summary =
        await getMonthSummary(month: DateTime(2026, 11));
    expect(summary.fees, Money.zero);
    final List<CategoryBreakdown> breakdown =
        await getCategoryBreakdown(month: DateTime(2026, 11));
    expect(
      breakdown.where(
        (CategoryBreakdown item) => item.categoryId == '__transfer_fees__',
      ),
      isEmpty,
    );
  });

  test('editing a fee reverses the old fee and applies the new one', () async {
    final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
    final Wallet gcash = await seedWallet('GCash', openingMinor: 100000);
    final Money before = await getNetWorth();

    final TransactionRecord transfer = await transferMoney(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: gcash.id,
      fee: const Money(1500),
      occurredAt: DateTime(2026, 11, 6, 10),
    );
    final TransactionRecord stored =
        (await transactions.byId(transfer.id))!;

    await editTransaction(
      previous: stored,
      amount: const Money(100000),
      fee: const Money(2500),
    );

    expect(await balanceOf(bank.id), const Money(397500));
    expect(await balanceOf(gcash.id), const Money(200000));
    expect(await getNetWorth(), before - const Money(2500));
    expect(await verifyBalances(), isEmpty);
  });

  test('deleting a fee transfer restores both wallets and net worth', () async {
    final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
    final Wallet gcash = await seedWallet('GCash', openingMinor: 100000);
    final Money before = await getNetWorth();

    final TransactionRecord transfer = await transferMoney(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: gcash.id,
      fee: const Money(1500),
      occurredAt: DateTime(2026, 11, 6, 10),
    );
    await deleteTransaction(transfer.id);

    expect(await balanceOf(bank.id), const Money(500000));
    expect(await balanceOf(gcash.id), const Money(100000));
    expect(await getNetWorth(), before);
    expect(await verifyBalances(), isEmpty);
  });

  test('a fee larger than the amount is allowed and applied', () async {
    final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
    final Wallet gcash = await seedWallet('GCash', openingMinor: 100000);
    final Money before = await getNetWorth();

    await transferMoney(
      amount: const Money(10000),
      sourceWalletId: bank.id,
      targetWalletId: gcash.id,
      fee: const Money(15000),
      occurredAt: DateTime(2026, 11, 6, 10),
    );

    expect(await balanceOf(bank.id), const Money(475000));
    expect(await balanceOf(gcash.id), const Money(110000));
    expect(await getNetWorth(), before - const Money(15000));
    expect(await verifyBalances(), isEmpty);
  });

  test('a negative fee is rejected and writes nothing', () async {
    final Wallet bank = await seedWallet('Bank', openingMinor: 500000);
    final Wallet gcash = await seedWallet('GCash', openingMinor: 100000);
    final int before = await transactionCount();

    await expectLater(
      transferMoney(
        amount: const Money(10000),
        sourceWalletId: bank.id,
        targetWalletId: gcash.id,
        fee: const Money(-1),
      ),
      throwsA(isA<ValidationFailure>()),
    );

    expect(await transactionCount(), before);
    expect(await verifyBalances(), isEmpty);
  });
}
