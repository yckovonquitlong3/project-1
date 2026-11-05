import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/widgets/wallet_card.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/widgets/wallet_form_sheet.dart';

import '../../helpers/wallet_test_helpers.dart';

void main() {
  testWidgets('wallet card shows the name, type, balance and archived badge',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: WalletCard(
            wallet: walletFixture(isArchived: true),
            onEdit: () {},
            onArchive: () {},
            onRestore: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('E-Wallet'), findsOneWidget);
    expect(find.text(const Money(100000).format()), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
  });

  testWidgets('wallet form rejects an empty name', (WidgetTester tester) async {
    final MockWalletRepository repository = MockWalletRepository();
    final WalletCubit cubit = buildWalletCubit(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: WalletFormSheet(cubit: cubit)),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add wallet'));
    await tester.pump();
    expect(find.text('Wallet name is required'), findsOneWidget);
    verifyZeroInteractions(repository);
    await tester.runAsync(cubit.close);
  });

  testWidgets('wallet form rejects a negative opening balance',
      (WidgetTester tester) async {
    final MockWalletRepository repository = MockWalletRepository();
    final WalletCubit cubit = buildWalletCubit(repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: WalletFormSheet(cubit: cubit)),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'GCash');
    await tester.enterText(find.byType(TextFormField).last, '-5');
    await tester.tap(find.widgetWithText(FilledButton, 'Add wallet'));
    await tester.pump();

    expect(
      find.text('Enter a valid amount (up to 2 decimals)'),
      findsOneWidget,
    );
    verifyZeroInteractions(repository);

    await tester.runAsync(cubit.close);
  });
}
