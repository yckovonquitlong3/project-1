import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/get_transaction_detail.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/transaction_detail_screen.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

import '../../helpers/transaction_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  late MockTransactionRepository transactions;
  late MockWalletRepository wallets;
  late MockCategoryRepository categories;

  setUp(() {
    transactions = MockTransactionRepository();
    wallets = MockWalletRepository();
    categories = MockCategoryRepository();
  });

  testWidgets('the form rejects an empty amount', (WidgetTester tester) async {
    final TransactionCubit cubit = buildTransactionCubit(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AddTransactionScreen(
          cubit: cubit,
          activeWallets: <Wallet>[walletFixture()],
          categories: <Category>[categoryFixture()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add transaction'));
    await tester.pump();

    expect(find.text('Enter an amount'), findsOneWidget);
    verifyZeroInteractions(transactions);
    verifyZeroInteractions(wallets);
    verifyZeroInteractions(categories);

    await tester.runAsync(cubit.close);
  });

  testWidgets('a transfer needs a second wallet', (WidgetTester tester) async {
    final TransactionCubit cubit = buildTransactionCubit(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AddTransactionScreen(
          cubit: cubit,
          activeWallets: <Wallet>[walletFixture()],
          categories: <Category>[categoryFixture()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '100');
    final Finder saveButton =
        find.widgetWithText(FilledButton, 'Add transaction');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Choose a destination wallet'), findsOneWidget);
    verifyZeroInteractions(transactions);

    await tester.runAsync(cubit.close);
  });

  testWidgets('the detail screen shows the transaction and its labels',
      (WidgetTester tester) async {
    final TransactionRecord record = recordFixture();
    when(() => transactions.byId(record.id))
        .thenAnswer((_) async => record);
    when(() => wallets.byId(record.sourceWalletId))
        .thenAnswer((_) async => walletFixture());
    when(() => categories.byId(record.categoryId!))
        .thenAnswer((_) async => categoryFixture());

    final GetTransactionDetail loader = GetTransactionDetail(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TransactionDetailScreen(
          transactionId: record.id,
          loader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('-${const Money(15000).format()}'), findsOneWidget);
    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('Food & Dining'), findsOneWidget);
  });
}
