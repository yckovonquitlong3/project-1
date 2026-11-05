import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/app.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_cubit.dart';

import 'helpers/wallet_test_helpers.dart';

void main() {
  testWidgets('shows the empty state on a fresh install', (WidgetTester tester) async {
    final MockWalletRepository repository = MockWalletRepository();
    when(() => repository.all(includeArchived: true))
        .thenAnswer((_) async => <Wallet>[]);
    final WalletCubit cubit = buildWalletCubit(repository);
    await cubit.load();

    await tester.pumpWidget(MultiWalletApp(walletCubit: cubit));
    await tester.pump();

    expect(find.text('No wallets yet'), findsOneWidget);
    expect(find.text('Add wallet'), findsNWidgets(2));

    await tester.runAsync(cubit.close);
  });

  testWidgets('lists wallets and their total balance', (WidgetTester tester) async {
    final MockWalletRepository repository = MockWalletRepository();
    final List<Wallet> wallets = <Wallet>[
      walletFixture(name: 'GCash', balanceMinor: 100000),
      walletFixture(
        id: 'w2',
        name: 'BDO',
        accountType: AccountType.bank,
        iconIdentifier: 'account_balance',
        balanceMinor: 250000,
      ),
    ];
    when(() => repository.all(includeArchived: true))
        .thenAnswer((_) async => wallets);
    final WalletCubit cubit = buildWalletCubit(repository);
    await cubit.load();

    await tester.pumpWidget(MultiWalletApp(walletCubit: cubit));
    await tester.pump();

    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('E-Wallet'), findsOneWidget);
    expect(find.text('BDO'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text(const Money(350000).format()), findsOneWidget);

    await tester.runAsync(cubit.close);
  });
}
