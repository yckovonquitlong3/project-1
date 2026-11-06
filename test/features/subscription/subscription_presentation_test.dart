import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/usecases/get_categories.dart';
import 'package:multi_wallet_tracker/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/create_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/delete_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/get_subscriptions.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/run_due_subscriptions.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/set_subscription_active.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/subscription_coordinator.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/update_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/cubit/subscription_state.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/screens/subscriptions_screen.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/widgets/subscription_form_sheet.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/subscription_test_helpers.dart';

void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late CategoryRepositoryImpl categories;
  late SubscriptionRepositoryImpl subscriptions;
  late FakeSubscriptionNotifier notifier;
  late FakeSubscriptionReminderScheduler scheduler;
  late SubscriptionCoordinator coordinator;
  late DateTime currentNow;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    currentNow = DateTime(2026, 11, 1, 8);
    appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ledgerBus = LedgerBus();
    wallets = WalletRepositoryImpl(database: appDatabase, ledgerBus: ledgerBus);
    categories = CategoryRepositoryImpl(database: appDatabase);
    subscriptions = SubscriptionRepositoryImpl(
      database: appDatabase,
      clock: () => currentNow,
    );
    notifier = FakeSubscriptionNotifier();
    scheduler = FakeSubscriptionReminderScheduler();
    coordinator = SubscriptionCoordinator(
      runner: RunDueSubscriptions(
        subscriptions: subscriptions,
        wallets: wallets,
        categories: categories,
        notifier: notifier,
        ledgerBus: ledgerBus,
        clock: () => currentNow,
      ),
      scheduler: scheduler,
      subscriptions: subscriptions,
      wallets: wallets,
    );
    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  SubscriptionCubit buildCubit() {
    return SubscriptionCubit(
      getSubscriptions: GetSubscriptions(subscriptions: subscriptions),
      createSubscription: CreateSubscription(
        subscriptions: subscriptions,
        wallets: wallets,
        categories: categories,
      ),
      updateSubscription: UpdateSubscription(
        subscriptions: subscriptions,
        wallets: wallets,
        categories: categories,
      ),
      setSubscriptionActive: SetSubscriptionActive(
        subscriptions: subscriptions,
      ),
      deleteSubscription: DeleteSubscription(subscriptions: subscriptions),
      getWallets: GetWallets(wallets: wallets),
      getCategories: GetCategories(categories: categories),
      coordinator: coordinator,
    );
  }

  Future<Wallet> seedWallet({int openingMinor = 200000}) {
    return wallets.create(
      name: 'GCash',
      accountType: AccountType.eWallet,
      iconIdentifier: 'phone_android',
      openingBalance: Money(openingMinor),
    );
  }

  Future<Subscription> seedSubscription({
    required Wallet wallet,
    bool autoDeduct = true,
    DateTime? nextBillingAt,
  }) {
    return subscriptions.create(
      name: 'Claude Pro',
      amount: const Money(115000),
      walletId: wallet.id,
      categoryId: 'cat-exp-subscriptions',
      cycle: BillingCycle.monthly,
      nextBillingAt: nextBillingAt ?? DateTime(2026, 11, 1, 9),
      autoDeduct: autoDeduct,
    );
  }

  test('loads an empty subscription list', () async {
    await seedWallet();
    final SubscriptionCubit cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.load();

    final SubscriptionLoaded state = cubit.state as SubscriptionLoaded;
    expect(state.isEmpty, isTrue);
    expect(state.activeWallets.length, 1);
    expect(state.notificationsEnabled, isTrue);
    expect(scheduler.syncCount, greaterThan(0));
  });

  test('load processes a due subscription automatically', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await seedSubscription(wallet: wallet);
    currentNow = DateTime(2026, 11, 1, 9, 5);
    final SubscriptionCubit cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.load();

    final SubscriptionLoaded state = cubit.state as SubscriptionLoaded;
    expect(state.active.length, 1);
    expect(state.active.single.nextBillingAt, DateTime(2026, 12, 1, 9));
    expect(state.active.single.isOverdue, isFalse);
    expect((await wallets.byId(wallet.id))!.balance, const Money(85000));
    expect(subscription.id, state.active.single.id);
    expect(notifier.events, isNotEmpty);
  });

  test('marks an auto-deduct-off overdue subscription as paid', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await seedSubscription(
      wallet: wallet,
      autoDeduct: false,
    );
    currentNow = DateTime(2026, 11, 1, 9, 5);
    final SubscriptionCubit cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.load();
    SubscriptionLoaded state = cubit.state as SubscriptionLoaded;
    expect(state.active.single.isOverdue, isTrue);
    expect(
      state.active.single.lastFailureReason,
      SubscriptionFailureReason.manualPaymentRequired,
    );

    final String? error = await cubit.markPaid(subscription.id);
    expect(error, isNull);

    state = cubit.state as SubscriptionLoaded;
    expect(state.active.single.isOverdue, isFalse);
    expect(state.active.single.nextBillingAt, DateTime(2026, 12, 1, 9));
    expect((await wallets.byId(wallet.id))!.balance, const Money(85000));
  });

  test('create validates and adds a subscription', () async {
    final Wallet wallet = await seedWallet();
    final SubscriptionCubit cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.load();

    final String? error = await cubit.create(
      name: '   ',
      amount: const Money(115000),
      walletId: wallet.id,
      categoryId: 'cat-exp-subscriptions',
      cycle: BillingCycle.monthly,
      nextBillingAt: DateTime(2026, 11, 1, 9),
      autoDeduct: true,
    );
    expect(error, 'Subscription name is required');

    final String? saved = await cubit.create(
      name: 'Claude Pro',
      amount: const Money(115000),
      walletId: wallet.id,
      categoryId: 'cat-exp-subscriptions',
      cycle: BillingCycle.monthly,
      nextBillingAt: DateTime(2026, 11, 1, 9),
      autoDeduct: true,
    );
    expect(saved, isNull);
    final SubscriptionLoaded state = cubit.state as SubscriptionLoaded;
    expect(state.active.length, 1);
    expect(state.active.single.name, 'Claude Pro');
    expect(scheduler.syncCount, greaterThan(0));
  });

  testWidgets('subscription list shows an overdue card',
      (WidgetTester tester) async {
    final Wallet wallet = (await tester.runAsync(seedWallet))!;
    await tester.runAsync(
      () => seedSubscription(wallet: wallet, autoDeduct: false),
    );
    currentNow = DateTime(2026, 11, 1, 9, 5);
    scheduler.enabled = false;
    final SubscriptionCubit cubit = buildCubit();
    await tester.runAsync(cubit.load);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SubscriptionsScreen(cubit: cubit),
      ),
    );
    await tester.pump();

    expect(find.text('Claude Pro'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(
      find.text('Auto-deduct is off; payment is waiting.'),
      findsOneWidget,
    );
    expect(find.text('Notifications are off'), findsOneWidget);

    await tester.runAsync(cubit.close);
  });

  testWidgets('subscription form rejects an empty name',
      (WidgetTester tester) async {
    final Wallet wallet = (await tester.runAsync(seedWallet))!;
    final SubscriptionCubit cubit = buildCubit();
    await tester.runAsync(cubit.load);
    final List<Category> categoriesList =
        (await tester.runAsync(
          () => categories.byType(CategoryType.expense),
        ))!;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SubscriptionFormSheet(
            cubit: cubit,
            activeWallets: <Wallet>[wallet],
            expenseCategories: categoriesList,
          ),
        ),
      ),
    );

    final Finder save = find.widgetWithText(FilledButton, 'Add subscription');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    expect(find.text('Subscription name is required'), findsOneWidget);
    final List<Subscription> all =
        (await tester.runAsync(subscriptions.all))!;
    expect(all, isEmpty);

    await tester.runAsync(cubit.close);
  });
}
