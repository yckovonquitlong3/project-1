import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/local_notification_service.dart';
import 'features/ai/presentation/widgets/ai_quick_entry_card.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/subscription/domain/usecases/subscription_coordinator.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();

  final WalletCubit walletCubit = sl<WalletCubit>();
  final DashboardCubit dashboardCubit = sl<DashboardCubit>();
  final LocalNotificationService notifications = sl<LocalNotificationService>();
  try {
    await notifications.initialize();
  } catch (_) {
    // Notifications are optional; the ledger remains fully usable.
  }

  unawaited(walletCubit.load());
  unawaited(dashboardCubit.load());

  runApp(
    MultiWalletApp(
      walletCubit: walletCubit,
      dashboardCubit: dashboardCubit,
      notificationService: notifications,
      quickEntry: const AiQuickEntryCard(),
    ),
  );

  unawaited(_runSubscriptionsOnStart());
}

Future<void> _runSubscriptionsOnStart() async {
  try {
    await sl<SubscriptionCoordinator>().onStart();
  } catch (_) {
    // A notification or scheduling failure must not block the app.
  }
}
