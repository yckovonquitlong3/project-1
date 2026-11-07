import 'package:get_it/get_it.dart';

import 'core/database/app_database.dart';
import 'core/ledger/ledger_bus.dart';
import 'core/notifications/local_notification_service.dart';
import 'features/ai/data/client/http_ai_client.dart';
import 'features/ai/data/settings/secure_ai_settings_store.dart';
import 'features/ai/domain/repositories/ai_settings_store.dart';
import 'features/ai/domain/services/ai_client.dart';
import 'features/ai/domain/usecases/parse_quick_entry.dart';
import 'features/category/data/repositories/category_repository_impl.dart';
import 'features/category/domain/repositories/category_repository.dart';
import 'features/category/domain/usecases/get_categories.dart';
import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/domain/repositories/dashboard_repository.dart';
import 'features/dashboard/domain/usecases/get_category_breakdown.dart';
import 'features/dashboard/domain/usecases/get_month_summary.dart';
import 'features/dashboard/domain/usecases/get_net_worth.dart';
import 'features/dashboard/domain/usecases/get_recent_transactions.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/subscription/data/repositories/subscription_repository_impl.dart';
import 'features/subscription/data/notifications/local_subscription_notifier.dart';
import 'features/subscription/data/notifications/subscription_reminder_scheduler_impl.dart';
import 'features/subscription/domain/notifications/subscription_notifier.dart';
import 'features/subscription/domain/notifications/subscription_reminder_scheduler.dart';
import 'features/subscription/domain/repositories/subscription_repository.dart';
import 'features/subscription/domain/usecases/create_subscription.dart';
import 'features/subscription/domain/usecases/delete_subscription.dart';
import 'features/subscription/domain/usecases/get_subscriptions.dart';
import 'features/subscription/domain/usecases/run_due_subscriptions.dart';
import 'features/subscription/domain/usecases/set_subscription_active.dart';
import 'features/subscription/domain/usecases/subscription_coordinator.dart';
import 'features/subscription/domain/usecases/update_subscription.dart';
import 'features/subscription/presentation/cubit/subscription_cubit.dart';
import 'features/transaction/data/repositories/transaction_repository_impl.dart';
import 'features/transaction/domain/repositories/transaction_repository.dart';
import 'features/transaction/domain/usecases/add_expense.dart';
import 'features/transaction/domain/usecases/add_income.dart';
import 'features/transaction/domain/usecases/delete_transaction.dart';
import 'features/transaction/domain/usecases/edit_transaction.dart';
import 'features/transaction/domain/usecases/get_recent_transaction_records.dart';
import 'features/transaction/domain/usecases/get_transaction_detail.dart';
import 'features/transaction/domain/usecases/transfer_money.dart';
import 'features/transaction/domain/usecases/verify_balances.dart';
import 'features/transaction/presentation/cubit/transaction_cubit.dart';
import 'features/transaction/presentation/cubit/transaction_list_cubit.dart';
import 'features/wallet/data/repositories/wallet_repository_impl.dart';
import 'features/wallet/domain/repositories/wallet_repository.dart';
import 'features/wallet/domain/usecases/archive_wallet.dart';
import 'features/wallet/domain/usecases/create_wallet.dart';
import 'features/wallet/domain/usecases/delete_wallet.dart';
import 'features/wallet/domain/usecases/get_wallets.dart';
import 'features/wallet/domain/usecases/has_transactions.dart';
import 'features/wallet/domain/usecases/restore_wallet.dart';
import 'features/wallet/domain/usecases/update_wallet.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';

/// Global service locator.
///
/// Registration happens in [initDependencies]; widgets never resolve
/// dependencies directly, cubits receive them through their constructor.
final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  sl
    ..registerLazySingleton<AppDatabase>(AppDatabase.new)
    ..registerLazySingleton<LedgerBus>(LedgerBus.new)
    ..registerLazySingleton<LocalNotificationService>(
      LocalNotificationService.new,
    )
    ..registerLazySingleton<AiSettingsStore>(SecureAiSettingsStore.new)
    ..registerLazySingleton<AiClient>(HttpAiClient.new)
    ..registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(database: sl(), ledgerBus: sl()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(database: sl(), ledgerBus: sl()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(database: sl()),
    )
    ..registerLazySingleton<GetCategories>(
      () => GetCategories(categories: sl()),
    )
    ..registerLazySingleton<CreateSubscription>(
      () => CreateSubscription(
        subscriptions: sl(),
        wallets: sl(),
        categories: sl(),
      ),
    )
    ..registerLazySingleton<UpdateSubscription>(
      () => UpdateSubscription(
        subscriptions: sl(),
        wallets: sl(),
        categories: sl(),
      ),
    )
    ..registerLazySingleton<GetSubscriptions>(
      () => GetSubscriptions(subscriptions: sl()),
    )
    ..registerLazySingleton<GetSubscription>(
      () => GetSubscription(subscriptions: sl()),
    )
    ..registerLazySingleton<SetSubscriptionActive>(
      () => SetSubscriptionActive(subscriptions: sl()),
    )
    ..registerLazySingleton<DeleteSubscription>(
      () => DeleteSubscription(subscriptions: sl()),
    )
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(database: sl()),
    )
    ..registerLazySingleton<SubscriptionRepository>(
      () => SubscriptionRepositoryImpl(database: sl()),
    )
    ..registerLazySingleton<SubscriptionReminderScheduler>(
      () => SubscriptionReminderSchedulerImpl(notifications: sl()),
    )
    ..registerLazySingleton<SubscriptionNotifier>(
      () => LocalSubscriptionNotifier(notifications: sl()),
    )
    ..registerLazySingleton<RunDueSubscriptions>(
      () => RunDueSubscriptions(
        subscriptions: sl(),
        wallets: sl(),
        categories: sl(),
        notifier: sl(),
        ledgerBus: sl(),
      ),
    )
    ..registerLazySingleton<SubscriptionCoordinator>(
      () => SubscriptionCoordinator(
        runner: sl(),
        scheduler: sl(),
        subscriptions: sl(),
        wallets: sl(),
      ),
    )
    ..registerLazySingleton<CreateWallet>(() => CreateWallet(wallets: sl()))
    ..registerLazySingleton<UpdateWallet>(() => UpdateWallet(wallets: sl()))
    ..registerLazySingleton<ArchiveWallet>(() => ArchiveWallet(wallets: sl()))
    ..registerLazySingleton<RestoreWallet>(() => RestoreWallet(wallets: sl()))
    ..registerLazySingleton<DeleteWallet>(() => DeleteWallet(wallets: sl()))
    ..registerLazySingleton<GetWallets>(() => GetWallets(wallets: sl()))
    ..registerLazySingleton<HasTransactions>(
      () => HasTransactions(wallets: sl()),
    )
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
    ..registerLazySingleton<GetRecentTransactionRecords>(
      () => GetRecentTransactionRecords(transactions: sl()),
    )
    ..registerLazySingleton<GetTransactionDetail>(
      () => GetTransactionDetail(
        transactions: sl(),
        wallets: sl(),
        categories: sl(),
      ),
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
    )
    ..registerFactory<WalletCubit>(
      () => WalletCubit(
        getWallets: sl(),
        createWallet: sl(),
        updateWallet: sl(),
        archiveWallet: sl(),
        restoreWallet: sl(),
        deleteWallet: sl(),
        hasTransactions: sl(),
        ledgerBus: sl(),
      ),
    )
    ..registerFactory<TransactionCubit>(
      () => TransactionCubit(
        addExpense: sl(),
        addIncome: sl(),
        transferMoney: sl(),
        editTransaction: sl(),
        deleteTransaction: sl(),
      ),
    )
    ..registerFactory<TransactionListCubit>(
      () => TransactionListCubit(
        getRecentTransactions: sl(),
        ledgerBus: sl(),
      ),
    )
    ..registerFactory<DashboardCubit>(
      () => DashboardCubit(
        getNetWorth: sl(),
        getMonthSummary: sl(),
        getCategoryBreakdown: sl(),
        getRecentTransactions: sl(),
        wallets: sl(),
        ledgerBus: sl(),
      ),
    )
    ..registerFactory<SubscriptionCubit>(
      () => SubscriptionCubit(
        getSubscriptions: sl(),
        createSubscription: sl(),
        updateSubscription: sl(),
        setSubscriptionActive: sl(),
        deleteSubscription: sl(),
        getWallets: sl(),
        getCategories: sl(),
        coordinator: sl(),
      ),
    )
    ..registerLazySingleton<ParseQuickEntry>(
      () => ParseQuickEntry(
        settings: sl(),
        client: sl(),
        wallets: sl(),
        categories: sl(),
      ),
    );

  // Open the database during startup so migrations and seeding finish before
  // the first screen asks for data.
  await sl<AppDatabase>().database;
}
