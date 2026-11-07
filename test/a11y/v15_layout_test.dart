import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/notifications/app_settings_launcher.dart';
import 'package:multi_wallet_tracker/core/notifications/local_notification_service.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/tools/analytics_tools.dart';
import 'package:multi_wallet_tracker/features/ai/domain/usecases/run_analytics_chat.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/cubit/analytics_chat_cubit.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/screens/ai_settings_screen.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/screens/analytics_chat_screen.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/category/domain/usecases/get_categories.dart';
import 'package:multi_wallet_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:multi_wallet_tracker/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/create_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/delete_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/get_subscriptions.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/run_due_subscriptions.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/set_subscription_active.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/subscription_coordinator.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/update_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/screens/subscriptions_screen.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/ai_test_helpers.dart';
import '../helpers/dashboard_test_helpers.dart';
import '../helpers/subscription_test_helpers.dart';
import '../helpers/transaction_test_helpers.dart';
import '../helpers/wallet_test_helpers.dart';

Widget wrap(
  Widget child, {
  required double textScale,
  required Brightness brightness,
}) {
  return MaterialApp(
    theme: (brightness == Brightness.light ? AppTheme.light : AppTheme.dark)
        .copyWith(
      platform: TargetPlatform.android,
      visualDensity: VisualDensity.standard,
    ),
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

class A11yNotificationService extends LocalNotificationService {
  A11yNotificationService({this.enabled = false});

  final bool enabled;

  @override
  Future<bool> notificationsEnabled() async => enabled;
}
Future<void> pumpAtScales(
  WidgetTester tester,
  Widget Function() build,
) async {
  for (final ({double scale, Brightness brightness}) variant
      in <({double scale, Brightness brightness})>[
    (scale: 1.3, brightness: Brightness.light),
    (scale: 2.0, brightness: Brightness.dark),
  ]) {
    await tester.pumpWidget(
      wrap(
        build(),
        textScale: variant.scale,
        brightness: variant.brightness,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'scale ${variant.scale} ${variant.brightness}',
    );

    final Finder list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'after scrolling at ${variant.scale}',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
}

void main() {
  testWidgets('AI settings survives 1.3x and 2.0x text scaling',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(mode: AiMode.byok, model: 'deepseek-chat'),
      apiKey: 'sk-test',
      consent: true,
    );
    final FakeAiClient client = FakeAiClient();

    await pumpAtScales(
      tester,
      () => AiSettingsScreen(store: store, client: client),
    );
  });

  testWidgets('analytics chat survives 1.3x and 2.0x text scaling',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      apiKey: 'sk-test',
      consent: true,
    );
    final FakeAiClient client = FakeAiClient();
    client.chatResponse = const AiChatResponse(
      content: 'You spent ₱1,234.56 on Food & Dining in October 2026.',
    );
    final AnalyticsTools tools = AnalyticsTools(
      dashboard: MockDashboardRepository(),
      wallets: MockWalletRepository(),
      categories: MockCategoryRepository(),
    );
    final AnalyticsChatCubit cubit = AnalyticsChatCubit(
      settings: store,
      chat: RunAnalyticsChat(
        settings: store,
        client: client,
        tools: tools,
        clock: () => DateTime(2026, 11, 7, 9),
      ),
    );
    await cubit.load();

    await pumpAtScales(tester, () => AnalyticsChatScreen(cubit: cubit));

    await tester.runAsync(cubit.close);
  });

  testWidgets('settings hub survives 1.3x and 2.0x text scaling',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(mode: AiMode.byok, model: 'deepseek-chat'),
      apiKey: 'sk-test',
      consent: true,
    );

    await pumpAtScales(
      tester,
      () => SettingsScreen(
        settingsStore: store,
        notificationService: A11yNotificationService(enabled: true),
        appSettingsLauncher: _A11yLauncher(batteryExempt: false),
      ),
    );
  });

  testWidgets('subscriptions survive 1.3x and 2.0x text scaling',
      (WidgetTester tester) async {
    sqfliteFfiInit();
    final AppDatabase appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final LedgerBus ledgerBus = LedgerBus();
    final WalletRepositoryImpl wallets = WalletRepositoryImpl(
      database: appDatabase,
      ledgerBus: ledgerBus,
    );
    final CategoryRepositoryImpl categories =
        CategoryRepositoryImpl(database: appDatabase);
    final SubscriptionRepositoryImpl subscriptions = SubscriptionRepositoryImpl(
      database: appDatabase,
      clock: () => DateTime(2026, 11, 1, 8),
    );
    final FakeSubscriptionReminderScheduler scheduler =
        FakeSubscriptionReminderScheduler()..enabled = false;
    final SubscriptionCoordinator coordinator = SubscriptionCoordinator(
      runner: RunDueSubscriptions(
        subscriptions: subscriptions,
        wallets: wallets,
        categories: categories,
        notifier: FakeSubscriptionNotifier(),
        ledgerBus: ledgerBus,
        clock: () => DateTime(2026, 11, 1, 8),
      ),
      scheduler: scheduler,
      subscriptions: subscriptions,
      wallets: wallets,
    );
    final SubscriptionCubit cubit = SubscriptionCubit(
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

    addTearDown(() async {
      await cubit.close();
      await ledgerBus.dispose();
      await appDatabase.close();
    });

    await tester.runAsync(() async {
      final wallet = await wallets.create(
        name: 'GCash',
        accountType: AccountType.eWallet,
        iconIdentifier: 'phone_android',
        openingBalance: const Money(200000),
      );
      await subscriptions.create(
        name: 'Claude Pro',
        amount: const Money(115000),
        walletId: wallet.id,
        categoryId: 'cat-exp-subscriptions',
        cycle: BillingCycle.monthly,
        nextBillingAt: DateTime(2026, 11, 12, 9),
        autoDeduct: true,
      );
      await cubit.load();
    });

    await pumpAtScales(tester, () => SubscriptionsScreen(cubit: cubit));
  });
}

class _A11yLauncher extends AppSettingsLauncher {
  _A11yLauncher({this.batteryExempt = true});

  final bool batteryExempt;

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => batteryExempt;
}
