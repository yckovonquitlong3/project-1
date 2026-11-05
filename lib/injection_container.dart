import 'package:get_it/get_it.dart';

import 'core/database/app_database.dart';
import 'core/ledger/ledger_bus.dart';
import 'features/category/data/repositories/category_repository_impl.dart';
import 'features/category/domain/repositories/category_repository.dart';
import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/domain/repositories/dashboard_repository.dart';
import 'features/dashboard/domain/usecases/get_category_breakdown.dart';
import 'features/dashboard/domain/usecases/get_month_summary.dart';
import 'features/dashboard/domain/usecases/get_net_worth.dart';
import 'features/dashboard/domain/usecases/get_recent_transactions.dart';
import 'features/transaction/data/repositories/transaction_repository_impl.dart';
import 'features/transaction/domain/repositories/transaction_repository.dart';
import 'features/transaction/domain/usecases/add_expense.dart';
import 'features/transaction/domain/usecases/add_income.dart';
import 'features/transaction/domain/usecases/delete_transaction.dart';
import 'features/transaction/domain/usecases/edit_transaction.dart';
import 'features/transaction/domain/usecases/transfer_money.dart';
import 'features/transaction/domain/usecases/verify_balances.dart';
import 'features/wallet/data/repositories/wallet_repository_impl.dart';
import 'features/wallet/domain/repositories/wallet_repository.dart';
import 'features/wallet/domain/usecases/archive_wallet.dart';
import 'features/wallet/domain/usecases/create_wallet.dart';
import 'features/wallet/domain/usecases/delete_wallet.dart';
import 'features/wallet/domain/usecases/restore_wallet.dart';
import 'features/wallet/domain/usecases/update_wallet.dart';

/// Global service locator.
///
/// Registration happens in [initDependencies]; widgets never resolve
/// dependencies directly, cubits receive them through their constructor.
final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  sl
    ..registerLazySingleton<AppDatabase>(AppDatabase.new)
    ..registerLazySingleton<LedgerBus>(LedgerBus.new)
    ..registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(database: sl(), ledgerBus: sl()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(database: sl(), ledgerBus: sl()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(database: sl()),
    )
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(database: sl()),
    )
    ..registerLazySingleton<CreateWallet>(() => CreateWallet(wallets: sl()))
    ..registerLazySingleton<UpdateWallet>(() => UpdateWallet(wallets: sl()))
    ..registerLazySingleton<ArchiveWallet>(() => ArchiveWallet(wallets: sl()))
    ..registerLazySingleton<RestoreWallet>(() => RestoreWallet(wallets: sl()))
    ..registerLazySingleton<DeleteWallet>(() => DeleteWallet(wallets: sl()))
    ..registerLazySingleton<AddExpense>(
      () => AddExpense(
        transactions: sl(),
        wallets: sl(),
        categories: sl(),
      ),
    )
    ..registerLazySingleton<AddIncome>(
      () => AddIncome(
        transactions: sl(),
        wallets: sl(),
        categories: sl(),
      ),
    )
    ..registerLazySingleton<TransferMoney>(
      () => TransferMoney(transactions: sl(), wallets: sl()),
    )
    ..registerLazySingleton<EditTransaction>(
      () => EditTransaction(
        transactions: sl(),
        wallets: sl(),
        categories: sl(),
      ),
    )
    ..registerLazySingleton<DeleteTransaction>(
      () => DeleteTransaction(transactions: sl()),
    )
    ..registerLazySingleton<VerifyBalances>(
      () => VerifyBalances(transactions: sl()),
    )
    ..registerLazySingleton<GetNetWorth>(() => GetNetWorth(dashboard: sl()))
    ..registerLazySingleton<GetMonthSummary>(
      () => GetMonthSummary(dashboard: sl()),
    )
    ..registerLazySingleton<GetCategoryBreakdown>(
      () => GetCategoryBreakdown(dashboard: sl()),
    )
    ..registerLazySingleton<GetRecentTransactions>(
      () => GetRecentTransactions(dashboard: sl()),
    );

  // Open the database during startup so migrations and seeding finish before
  // the first screen asks for data.
  await sl<AppDatabase>().database;
}
