import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/ai/domain/tools/analytics_tools.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late TransactionRepositoryImpl transactions;
  late AnalyticsTools tools;

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
    final CategoryRepositoryImpl categories =
        CategoryRepositoryImpl(database: appDatabase);
    final DashboardRepositoryImpl dashboard =
        DashboardRepositoryImpl(database: appDatabase);
    tools = AnalyticsTools(
      dashboard: dashboard,
      wallets: wallets,
      categories: categories,
    );
    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  Future<Wallet> seedWallet() {
    return wallets.create(
      name: 'GCash',
      accountType: AccountType.eWallet,
      iconIdentifier: 'phone_android',
      openingBalance: Money.zero,
    );
  }

  TransactionRecord entry({
    required String id,
    required TransactionType type,
    required int amountMinor,
    required String categoryId,
    required DateTime occurredAt,
    required String walletId,
  }) {
    return TransactionRecord(
      id: id,
      amount: Money(amountMinor),
      type: type,
      sourceWalletId: walletId,
      categoryId: categoryId,
      occurredAt: occurredAt,
      localDate: localDateOf(occurredAt),
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );
  }

  test('sums a category over an inclusive date range', () async {
    final Wallet wallet = await seedWallet();
    await transactions.record(
      entry(
        id: 'oct-food',
        type: TransactionType.expense,
        amountMinor: 25000,
        categoryId: 'cat-exp-food-dining',
        occurredAt: DateTime(2026, 10, 15, 10),
        walletId: wallet.id,
      ),
    );
    await transactions.record(
      entry(
        id: 'nov-food',
        type: TransactionType.expense,
        amountMinor: 10000,
        categoryId: 'cat-exp-food-dining',
        occurredAt: DateTime(2026, 11, 2, 10),
        walletId: wallet.id,
      ),
    );
    await transactions.record(
      entry(
        id: 'nov-groceries',
        type: TransactionType.expense,
        amountMinor: 5000,
        categoryId: 'cat-exp-groceries',
        occurredAt: DateTime(2026, 11, 2, 11),
        walletId: wallet.id,
      ),
    );

    final Map<String, Object?> october = await tools.execute(
      name: 'get_category_spending',
      arguments: <String, Object?>{
        'category_name': 'food & dining',
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
      },
    );
    expect(october['total_minor'], 25000);
    expect(october['category'], 'Food & Dining');

    final Map<String, Object?> november = await tools.execute(
      name: 'get_category_spending',
      arguments: <String, Object?>{
        'category_name': 'Food & Dining',
        'start_date': '2026-11-01',
        'end_date': '2026-11-30',
      },
    );
    expect(november['total_minor'], 10000);
  });

  test('returns wallet balances and net worth without ids', () async {
    final Wallet wallet = await seedWallet();
    await transactions.record(
      entry(
        id: 'income',
        type: TransactionType.income,
        amountMinor: 50000,
        categoryId: 'cat-inc-salary',
        occurredAt: DateTime(2026, 11, 2, 9),
        walletId: wallet.id,
      ),
    );
    await transactions.record(
      entry(
        id: 'expense',
        type: TransactionType.expense,
        amountMinor: 15000,
        categoryId: 'cat-exp-food-dining',
        occurredAt: DateTime(2026, 11, 2, 10),
        walletId: wallet.id,
      ),
    );

    final Map<String, Object?> result = await tools.execute(
      name: 'get_wallet_balances',
      arguments: <String, Object?>{},
    );

    expect(result['net_worth_minor'], 35000);
    final List<Map<String, Object?>> list =
        (result['wallets']! as List<Object?>).cast<Map<String, Object?>>();
    expect(list.length, 1);
    expect(list.single.keys, isNot(contains('id')));
    expect(list.single['name'], 'GCash');
    expect(list.single['balance_minor'], 35000);
  });

  test('returns a monthly aggregate', () async {
    final Wallet wallet = await seedWallet();
    await transactions.record(
      entry(
        id: 'nov-income',
        type: TransactionType.income,
        amountMinor: 50000,
        categoryId: 'cat-inc-salary',
        occurredAt: DateTime(2026, 11, 2, 9),
        walletId: wallet.id,
      ),
    );
    await transactions.record(
      entry(
        id: 'nov-expense',
        type: TransactionType.expense,
        amountMinor: 15000,
        categoryId: 'cat-exp-food-dining',
        occurredAt: DateTime(2026, 11, 2, 10),
        walletId: wallet.id,
      ),
    );

    final Map<String, Object?> result = await tools.execute(
      name: 'get_monthly_summary',
      arguments: <String, Object?>{'year': 2026, 'month': 11},
    );

    expect(result['income_minor'], 50000);
    expect(result['expense_minor'], 15000);
    expect(result['fees_minor'], 0);
    expect(result['net_minor'], 35000);
  });

  test('returns errors for invalid requests', () async {
    expect(
      (await tools.execute(
        name: 'get_category_spending',
        arguments: <String, Object?>{
          'category_name': 'Nonexistent Category',
          'start_date': '2026-11-01',
          'end_date': '2026-11-02',
        },
      ))['error'],
      isNotNull,
    );
    expect(
      (await tools.execute(
        name: 'get_category_spending',
        arguments: <String, Object?>{
          'category_name': 'Food & Dining',
          'start_date': '2026-11-30',
          'end_date': '2026-11-01',
        },
      ))['error'],
      isNotNull,
    );
    expect(
      (await tools.execute(
        name: 'get_monthly_summary',
        arguments: <String, Object?>{'year': 2026, 'month': 13},
      ))['error'],
      isNotNull,
    );
    expect(
      (await tools.execute(
        name: 'missing_tool',
        arguments: <String, Object?>{},
      ))['error'],
      isNotNull,
    );
  });
}
