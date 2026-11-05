import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/get_transaction_detail.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_list_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/transaction_detail_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/transactions_screen.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/screens/wallet_list_screen.dart';

import '../helpers/dashboard_test_helpers.dart';
import '../helpers/transaction_test_helpers.dart';
import '../helpers/wallet_test_helpers.dart';

Widget wrap(
  Widget child, {
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
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

Future<DashboardCubit> loadedDashboard() async {
  final MockDashboardRepository dashboard = MockDashboardRepository();
  final MockWalletRepository wallets = MockWalletRepository();
  stubDashboardLoad(
    dashboard,
    netWorth: const Money(123456789),
    summary: monthSummaryFixture(
      incomeMinor: 12345678,
      expenseMinor: 9876543,
    ),
    breakdown: <CategoryBreakdown>[
      breakdownFixture(totalMinor: 9876543),
      breakdownFixture(
        categoryId: 'cat-exp-transportation',
        name: 'Transportation',
        colorHex: '#2196F3',
        totalMinor: 1234567,
      ),
    ],
    recent: <DashboardTransaction>[
      dashboardTransactionFixture(amountMinor: 123456),
      dashboardTransactionFixture(
        id: 'tx-2',
        type: TransactionType.income,
        amountMinor: 9876543,
        categoryName: 'Salary',
      ),
    ],
  );
  when(() => wallets.all(includeArchived: true)).thenAnswer(
    (_) async => <Wallet>[
      walletFixture(name: 'GCash', balanceMinor: 123456789),
      walletFixture(
        id: 'w2',
        name: 'A very long bank account name',
        balanceMinor: 98765432,
      ),
    ],
  );
  final DashboardCubit cubit =
      buildDashboardCubit(dashboard: dashboard, wallets: wallets);
  await cubit.load();
  return cubit;
}

void main() {
  testWidgets('dashboard survives 1.3x and 2.0x text scaling',
      (WidgetTester tester) async {
    final DashboardCubit cubit = await loadedDashboard();

    for (final double scale in <double>[1.3, 2.0]) {
      await tester.pumpWidget(
        wrap(
          DashboardScreen(
            cubit: cubit,
            onOpenWallets: () {},
            onOpenActivity: () {},
          ),
          textScale: scale,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'scale $scale');

      await tester.drag(find.text('Net worth'), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'dashboard after scrolling at $scale',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }

    await tester.runAsync(cubit.close);
  });

  testWidgets('wallet list handles 2.0x and exposes labelled actions',
      (WidgetTester tester) async {
    final MockWalletRepository repository = MockWalletRepository();
    when(() => repository.all(includeArchived: true)).thenAnswer(
      (_) async => <Wallet>[
        walletFixture(name: 'GCash', balanceMinor: 123456789),
        walletFixture(
          id: 'w2',
          name: 'A very long archived wallet name',
          balanceMinor: 98765432,
          isArchived: true,
        ),
      ],
    );
    final WalletCubit cubit = buildWalletCubit(repository);
    await cubit.load();

    await tester.pumpWidget(
      wrap(WalletListScreen(cubit: cubit), textScale: 2.0),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.byTooltip('Activity'), findsOneWidget);
    expect(find.byTooltip('Add transaction'), findsOneWidget);
    final Finder activityButton = find.widgetWithIcon(
      IconButton,
      Icons.receipt_long_outlined,
    );
    final Size activity = tester.getSize(activityButton);
    expect(activity.width, greaterThanOrEqualTo(48));
    expect(activity.height, greaterThanOrEqualTo(48));

    await tester.drag(find.text('GCash'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.runAsync(cubit.close);
  });

  testWidgets('transaction form handles 2.0x text scaling',
      (WidgetTester tester) async {
    final MockTransactionRepository transactions = MockTransactionRepository();
    final MockWalletRepository wallets = MockWalletRepository();
    final MockCategoryRepository categories = MockCategoryRepository();
    final TransactionCubit cubit = buildTransactionCubit(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );

    await tester.pumpWidget(
      wrap(
        AddTransactionScreen(
          cubit: cubit,
          activeWallets: <Wallet>[
            walletFixture(),
            walletFixture(id: 'w2', name: 'A very long wallet name'),
          ],
          categories: <Category>[
            categoryFixture(),
            categoryFixture(
              id: 'cat-inc-salary',
              name: 'Salary',
              type: CategoryType.income,
            ),
          ],
        ),
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.runAsync(cubit.close);
  });

  testWidgets('activity list handles 2.0x text scaling',
      (WidgetTester tester) async {
    final MockTransactionRepository transactions = MockTransactionRepository();
    when(() => transactions.recent(limit: 50)).thenAnswer(
      (_) async => <TransactionRecord>[
        recordFixture(note: 'A deliberately long transaction note for layout'),
        recordFixture(
          id: 'tx-2',
          type: TransactionType.transfer,
          amountMinor: 123456789,
          targetWalletId: 'w2',
          categoryId: null,
        ),
      ],
    );
    final TransactionListCubit cubit =
        buildTransactionListCubit(transactions: transactions);
    await cubit.load();

    await tester.pumpWidget(
      wrap(TransactionsScreen(cubit: cubit), textScale: 2.0),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.runAsync(cubit.close);
  });

  testWidgets('transaction detail handles 2.0x text scaling',
      (WidgetTester tester) async {
    final MockTransactionRepository transactions = MockTransactionRepository();
    final MockWalletRepository wallets = MockWalletRepository();
    final MockCategoryRepository categories = MockCategoryRepository();
    final TransactionRecord record = recordFixture(
      amountMinor: 123456789,
      note: 'A deliberately long note that should wrap instead of overflowing',
    );
    when(() => transactions.byId(record.id))
        .thenAnswer((_) async => record);
    when(() => wallets.byId(record.sourceWalletId))
        .thenAnswer((_) async => walletFixture());
    when(() => categories.byId(record.categoryId!))
        .thenAnswer((_) async => categoryFixture());

    await tester.pumpWidget(
      wrap(
        TransactionDetailScreen(
          transactionId: record.id,
          loader: GetTransactionDetail(
            transactions: transactions,
            wallets: wallets,
            categories: categories,
          ),
        ),
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('theme text pairs meet the 4.5:1 contrast target', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final ColorScheme scheme = theme.colorScheme;
      expectContrast(scheme.onSurface, scheme.surface);
      expectContrast(scheme.onSurfaceVariant, scheme.surface);
      expectContrast(scheme.onPrimary, scheme.primary);
      expectContrast(scheme.onPrimaryContainer, scheme.primaryContainer);
      expectContrast(scheme.onSecondaryContainer, scheme.secondaryContainer);
      expectContrast(scheme.onErrorContainer, scheme.errorContainer);
    }
  });
}

void expectContrast(Color foreground, Color background) {
  final double first = foreground.computeLuminance();
  final double second = background.computeLuminance();
  final double ratio =
      (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
  expect(ratio, greaterThanOrEqualTo(4.5));
}
