import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_draft.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

import '../../helpers/transaction_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  testWidgets('an AI draft pre-fills the form without saving',
      (WidgetTester tester) async {
    final MockTransactionRepository transactions = MockTransactionRepository();
    final MockWalletRepository wallets = MockWalletRepository();
    final MockCategoryRepository categories = MockCategoryRepository();
    final TransactionCubit cubit = buildTransactionCubit(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );
    final Wallet wallet = walletFixture();
    final Category category = categoryFixture();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AddTransactionScreen(
          cubit: cubit,
          draft: const TransactionDraft(
            amount: Money(15000),
            note: 'iced coffee',
          ),
          activeWallets: <Wallet>[wallet],
          categories: <Category>[category],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Review the AI suggestion'), findsOneWidget);
    final TextFormField amountField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(amountField.controller?.text, '150.00');
    final TextFormField noteField =
        tester.widget<TextFormField>(find.byType(TextFormField).last);
    expect(noteField.controller?.text, 'iced coffee');

    verifyZeroInteractions(transactions);
    verifyZeroInteractions(wallets);
    verifyZeroInteractions(categories);

    await tester.runAsync(cubit.close);
  });
}
