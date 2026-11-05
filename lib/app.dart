import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/transaction/presentation/screens/transactions_screen.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'features/wallet/presentation/screens/wallet_list_screen.dart';

class MultiWalletApp extends StatelessWidget {
  const MultiWalletApp({
    required this.walletCubit,
    required this.dashboardCubit,
    super.key,
  });

  final WalletCubit walletCubit;
  final DashboardCubit dashboardCubit;

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
      ),
    );
  }
}

/// Bottom navigation between the three top-level views.
///
/// Tabs are rebuilt on selection, so the Activity tab only creates its cubit
/// when the user actually visits it.
class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.walletCubit,
    required this.dashboardCubit,
    super.key,
  });

  final WalletCubit walletCubit;
  final DashboardCubit dashboardCubit;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

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
          _ => const TransactionsScreen(),
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
          ],
        ),
      ),
    );
  }
}
