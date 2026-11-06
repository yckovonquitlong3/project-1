import 'dart:async';

import 'package:flutter/material.dart';

import 'core/notifications/local_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/subscription/domain/usecases/subscription_coordinator.dart';
import 'features/subscription/presentation/screens/subscriptions_screen.dart';
import 'features/transaction/presentation/screens/transactions_screen.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'features/wallet/presentation/screens/wallet_list_screen.dart';
import 'injection_container.dart';

class MultiWalletApp extends StatelessWidget {
  const MultiWalletApp({
    required this.walletCubit,
    required this.dashboardCubit,
    this.notificationService,
    super.key,
  });

  final WalletCubit walletCubit;
  final DashboardCubit dashboardCubit;
  final LocalNotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Wallet Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: HomeShell(
        walletCubit: walletCubit,
        dashboardCubit: dashboardCubit,
        notificationService: notificationService,
      ),
    );
  }
}

/// Bottom navigation between the four top-level views.
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.walletCubit,
    required this.dashboardCubit,
    this.notificationService,
    super.key,
  });

  final WalletCubit walletCubit;
  final DashboardCubit dashboardCubit;
  final LocalNotificationService? notificationService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  StreamSubscription<String>? _tapSubscription;

  void _select(int index) => setState(() => _index = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final LocalNotificationService? service = widget.notificationService;
    if (service != null) {
      _tapSubscription = service.subscriptionTapIds.listen((_) {
        if (mounted) {
          _select(3);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (service.takePendingTap() != null) {
          _select(3);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tapSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_processSubscriptions());
    }
  }

  Future<void> _processSubscriptions() async {
    try {
      await sl<SubscriptionCoordinator>().onStart();
    } catch (_) {
      // The ledger remains usable if the notification layer is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _index != 0) {
          _select(0);
        }
      },
      child: Scaffold(
        body: switch (_index) {
          0 => DashboardScreen(
              cubit: widget.dashboardCubit,
              onOpenWallets: () => _select(1),
              onOpenActivity: () => _select(2),
            ),
          1 => WalletListScreen(cubit: widget.walletCubit),
          2 => const TransactionsScreen(),
          _ => const SubscriptionsScreen(),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallets',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.autorenew),
              selectedIcon: Icon(Icons.autorenew),
              label: 'Subscriptions',
            ),
          ],
        ),
      ),
    );
  }
}
