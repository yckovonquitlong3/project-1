import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
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

  Future<List<DashboardState>> recordStates(
    DashboardCubit cubit,
    Future<void> Function() action,
  ) async {
    final List<DashboardState> states = <DashboardState>[];
    final StreamSubscription<DashboardState> subscription =
        cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);
    await action();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    return states;
  }

  test('load emits every dashboard section', () async {
    stubDashboardLoad(
      dashboard,
      netWorth: const Money(350000),
      summary: monthSummaryFixture(),
      breakdown: <CategoryBreakdown>[breakdownFixture()],
      recent: <DashboardTransaction>[dashboardTransactionFixture()],
    );
    when(() => wallets.all(includeArchived: true)).thenAnswer(
      (_) async => <Wallet>[
        walletFixture(name: 'GCash', balanceMinor: 100000),
        walletFixture(id: 'w2', name: 'BDO', balanceMinor: 250000),
        walletFixture(id: 'w3', name: 'Old', balanceMinor: 5000, isArchived: true),
      ],
    );
    final DashboardCubit cubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
    );

    final List<DashboardState> states = await recordStates(cubit, cubit.load);

    expect(states.first, isA<DashboardLoading>());
    final DashboardLoaded loaded = states.last as DashboardLoaded;
    expect(loaded.month, DateTime(2026, 11));
    expect(loaded.netWorth, const Money(350000));
    expect(loaded.summary.income, const Money(100000));
    expect(loaded.summary.expense, const Money(25000));
    expect(loaded.breakdown.length, 1);
    expect(loaded.recent.length, 1);
    expect(loaded.walletCount, 2);
    expect(
      loaded.wallets.map((Wallet wallet) => wallet.name).toList(),
      <String>['BDO', 'GCash'],
    );
  });

  test('a load failure is surfaced', () async {
    stubDashboardLoad(dashboard);
    when(() => dashboard.netWorth())
        .thenThrow(const DatabaseFailure('Database is unavailable'));
    when(() => wallets.all(includeArchived: true))
        .thenAnswer((_) async => <Wallet>[]);
    final DashboardCubit cubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
    );

    final List<DashboardState> states = await recordStates(cubit, cubit.load);

    expect(states.first, isA<DashboardLoading>());
    expect(states.last, isA<DashboardFailure>());
    expect(
      (states.last as DashboardFailure).message,
      'Database is unavailable',
    );
  });

  test('reloads when the ledger changes', () async {
    stubDashboardLoad(dashboard);
    when(() => wallets.all(includeArchived: true))
        .thenAnswer((_) async => <Wallet>[]);
    final LedgerBus bus = LedgerBus();
    final DashboardCubit cubit = buildDashboardCubit(
      dashboard: dashboard,
      wallets: wallets,
      ledgerBus: bus,
    );
    addTearDown(cubit.close);
    addTearDown(bus.dispose);

    await cubit.load();
    bus.notify();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    verify(() => dashboard.netWorth()).called(2);
    verify(() => wallets.all(includeArchived: true)).called(2);
  });
}
