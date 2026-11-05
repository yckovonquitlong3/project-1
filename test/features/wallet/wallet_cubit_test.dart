import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_state.dart';

import '../../helpers/wallet_test_helpers.dart';

void main() {
  late MockWalletRepository repository;
  String? lastError;

  setUp(() {
    repository = MockWalletRepository();
    lastError = null;
  });

  blocTest<WalletCubit, WalletState>(
    'load splits active and archived wallets',
    build: () {
      final Wallet active = walletFixture();
      final Wallet archived = walletFixture(id: 'w2', isArchived: true);
      when(() => repository.all(includeArchived: true))
          .thenAnswer((_) async => <Wallet>[active, archived]);
      return buildWalletCubit(repository);
    },
    act: (WalletCubit cubit) => cubit.load(),
    expect: () => <WalletState>[
      const WalletLoading(),
      WalletLoaded(
        active: <Wallet>[walletFixture()],
        archived: <Wallet>[walletFixture(id: 'w2', isArchived: true)],
      ),
    ],
  );

  blocTest<WalletCubit, WalletState>(
    'load failure is surfaced as a failure state',
    build: () {
      when(() => repository.all(includeArchived: true)).thenThrow(
        const DatabaseFailure('The database is unavailable'),
      );
      return buildWalletCubit(repository);
    },
    act: (WalletCubit cubit) => cubit.load(),
    expect: () => <WalletState>[
      const WalletLoading(),
      const WalletFailure('The database is unavailable'),
    ],
  );

  blocTest<WalletCubit, WalletState>(
    'create saves the wallet and reloads the list',
    build: () {
      final Wallet created = walletFixture();
      when(() => repository.all(includeArchived: true))
          .thenAnswer((_) async => <Wallet>[created]);
      when(
        () => repository.create(
          name: 'GCash',
          accountType: AccountType.eWallet,
          iconIdentifier: 'phone_android',
          openingBalance: const Money(100000),
        ),
      ).thenAnswer((_) async => created);
      return buildWalletCubit(repository);
    },
    act: (WalletCubit cubit) async {
      await cubit.create(
        name: 'GCash',
        accountType: AccountType.eWallet,
        iconIdentifier: 'phone_android',
        openingBalance: const Money(100000),
      );
    },
    expect: () => <WalletState>[
      const WalletLoading(),
      WalletLoaded(
        active: <Wallet>[walletFixture()],
        archived: const <Wallet>[],
      ),
    ],
    verify: (WalletCubit cubit) {
      verify(
        () => repository.create(
          name: 'GCash',
          accountType: AccountType.eWallet,
          iconIdentifier: 'phone_android',
          openingBalance: const Money(100000),
        ),
      ).called(1);
    },
  );

  blocTest<WalletCubit, WalletState>(
    'a failed create returns a message without losing the loaded list',
    build: () {
      final Wallet wallet = walletFixture();
      when(() => repository.all(includeArchived: true))
          .thenAnswer((_) async => <Wallet>[wallet]);
      when(
        () => repository.create(
          name: 'GCash',
          accountType: AccountType.eWallet,
          iconIdentifier: 'phone_android',
          openingBalance: const Money(100000),
        ),
      ).thenThrow(const DatabaseFailure('Disk is full'));
      return buildWalletCubit(repository);
    },
    act: (WalletCubit cubit) async {
      await cubit.load();
      lastError = await cubit.create(
        name: 'GCash',
        accountType: AccountType.eWallet,
        iconIdentifier: 'phone_android',
        openingBalance: const Money(100000),
      );
    },
    expect: () => <WalletState>[
      const WalletLoading(),
      WalletLoaded(
        active: <Wallet>[walletFixture()],
        archived: const <Wallet>[],
      ),
    ],
    verify: (WalletCubit cubit) {
      expect(lastError, 'Disk is full');
      expect(cubit.state, isA<WalletLoaded>());
    },
  );

  blocTest<WalletCubit, WalletState>(
    'archive moves a wallet to the archived section',
    build: () {
      final Wallet active = walletFixture();
      final Wallet archived = walletFixture(isArchived: true);
      when(() => repository.byId('w1')).thenAnswer((_) async => active);
      when(() => repository.archive('w1')).thenAnswer((_) async {});
      when(() => repository.all(includeArchived: true))
          .thenAnswer((_) async => <Wallet>[archived]);
      return buildWalletCubit(repository);
    },
    act: (WalletCubit cubit) async {
      await cubit.archive('w1');
    },
    expect: () => <WalletState>[
      const WalletLoading(),
      WalletLoaded(
        active: const <Wallet>[],
        archived: <Wallet>[walletFixture(isArchived: true)],
      ),
    ],
    verify: (WalletCubit cubit) {
      verify(() => repository.archive('w1')).called(1);
    },
  );

  test('reloads when another feature signals a ledger change', () async {
    final LedgerBus ledgerBus = LedgerBus();
    final Wallet wallet = walletFixture();
    when(() => repository.all(includeArchived: true))
        .thenAnswer((_) async => <Wallet>[wallet]);

    final WalletCubit cubit =
        buildWalletCubit(repository, ledgerBus: ledgerBus);
    await cubit.load();
    expect(cubit.state, isA<WalletLoaded>());

    ledgerBus.notify();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    verify(() => repository.all(includeArchived: true)).called(2);

    await cubit.close();
    await ledgerBus.dispose();
  });

  test('treats a failed usage lookup as unsafe to delete', () async {
    when(() => repository.hasTransactions('w1')).thenThrow(
      const DatabaseFailure('The database is unavailable'),
    );
    final WalletCubit cubit = buildWalletCubit(repository);

    expect(await cubit.hasTransactions('w1'), isTrue);

    await cubit.close();
  });
}
