import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

import '../../helpers/dashboard_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  late MockDashboardRepository dashboard;
  late MockWalletRepository wallets;

  setUp(() {
    dashboard = MockDashboardRepository();
    wallets = MockWalletRepository();
  });

  testWidgets('renders the dashboard sections', (WidgetTester tester) async {
    stubDashboardLoad(
      dashboard,
      netWorth: const Money(350000),
      summary: monthSummaryFixture(feesMinor: 1500),
      breakdown: <CategoryBreakdown>[breakdownFixture()],
      recent: <DashboardTransaction>[dashboardTransactionFixture()],
    );
    when(() => wallets.all(includeArchived: true)).thenAnswer(
      (_) async => <Wallet>[
        walletFixture(name: 'GCash', balanceMinor: 100000),
      ],
    );
    final DashboardCubit cubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
    );
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DashboardScreen(cubit: cubit),
      ),
    );
    await tester.pump();

    expect(find.text('Net worth'), findsOneWidget);
    expect(find.text(const Money(350000).format()), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('GCash'), findsOneWidget);
    expect(
      find.text('Includes ${const Money(1500).format()} in transfer fees'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Spending by category'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Food & Dining'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.text('Recent activity'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Recent activity'), findsOneWidget);

    await tester.runAsync(cubit.close);
  });

  testWidgets('renders the setup state when there is no data',
      (WidgetTester tester) async {
    stubDashboardLoad(dashboard);
    when(() => wallets.all(includeArchived: true))
        .thenAnswer((_) async => <Wallet>[]);
    final DashboardCubit cubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
    );
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DashboardScreen(cubit: cubit, onOpenWallets: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Set up your ledger'), findsOneWidget);
    expect(find.text('Add a wallet'), findsOneWidget);

    await tester.runAsync(cubit.close);
  });
}
