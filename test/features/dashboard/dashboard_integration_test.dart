import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:multi_wallet_tracker/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/transfer_money.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/dashboard_test_helpers.dart';

void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late TransactionRepositoryImpl transactions;
  late DashboardRepositoryImpl dashboard;

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
    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  test('a transfer leaves the dashboard net worth unchanged', () async {
    final Wallet bank = await wallets.create(
      name: 'Bank',
      accountType: AccountType.bank,
      iconIdentifier: 'account_balance',
      openingBalance: const Money(500000),
    );
    final Wallet maya = await wallets.create(
      name: 'Maya',
      accountType: AccountType.eWallet,
      iconIdentifier: 'phone_android',
      openingBalance: const Money(20000),
    );

    final DashboardCubit cubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
      ledgerBus: ledgerBus,
      clock: () => DateTime(2026, 11, 5),
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect((cubit.state as DashboardLoaded).netWorth, const Money(520000));

    await TransferMoney(transactions: transactions, wallets: wallets)(
      amount: const Money(100000),
      sourceWalletId: bank.id,
      targetWalletId: maya.id,
    );

    await cubit.load();
    expect((cubit.state as DashboardLoaded).netWorth, const Money(520000));
  });
}
