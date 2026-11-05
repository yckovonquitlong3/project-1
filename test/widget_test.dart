import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/app.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

import 'helpers/dashboard_test_helpers.dart';
import 'helpers/wallet_test_helpers.dart';

void main() {
  testWidgets('shows the empty dashboard on a fresh install',
      (WidgetTester tester) async {
    final MockDashboardRepository dashboard = MockDashboardRepository();
    final MockWalletRepository wallets = MockWalletRepository();
    stubDashboardLoad(dashboard);
    when(() => wallets.all(includeArchived: true))
        .thenAnswer((_) async => <Wallet>[]);

    final dashboardCubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
    );
    final walletCubit = buildWalletCubit(wallets);
    await dashboardCubit.load();
    await walletCubit.load();

    await tester.pumpWidget(
      MultiWalletApp(
        walletCubit: walletCubit,
        dashboardCubit: dashboardCubit,
      ),
    );
    await tester.pump();

    expect(find.text('Set up your ledger'), findsOneWidget);

    await tester.runAsync(dashboardCubit.close);
    await tester.runAsync(walletCubit.close);
  });

  testWidgets('switches from the dashboard to the wallet list',
      (WidgetTester tester) async {
    final MockDashboardRepository dashboard = MockDashboardRepository();
    final MockWalletRepository wallets = MockWalletRepository();
    stubDashboardLoad(
      dashboard,
      netWorth: const Money(350000),
      summary: monthSummaryFixture(),
    );
    when(() => wallets.all(includeArchived: true)).thenAnswer(
      (_) async => <Wallet>[
        walletFixture(name: 'GCash', balanceMinor: 100000),
        walletFixture(id: 'w2', name: 'BDO', balanceMinor: 250000),
      ],
    );

    final dashboardCubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
    );
    final walletCubit = buildWalletCubit(wallets);
    await dashboardCubit.load();
    await walletCubit.load();

    await tester.pumpWidget(
      MultiWalletApp(
        walletCubit: walletCubit,
        dashboardCubit: dashboardCubit,
      ),
    );
    await tester.pump();

    expect(find.text('Net worth'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Wallets'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BDO'), findsOneWidget);
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text(const Money(350000).format()), findsOneWidget);

    await tester.runAsync(dashboardCubit.close);
    await tester.runAsync(walletCubit.close);
  });
}
