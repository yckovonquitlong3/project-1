import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_list_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_list_state.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_state.dart';

import '../../helpers/transaction_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  late MockTransactionRepository transactions;
  late MockWalletRepository wallets;
  late MockCategoryRepository categories;

  setUpAll(() {
    registerFallbackValue(recordFixture());
  });

  setUp(() {
    transactions = MockTransactionRepository();
    wallets = MockWalletRepository();
    categories = MockCategoryRepository();
  });

  TransactionCubit buildCubit() => buildTransactionCubit(
        transactions: transactions,
        wallets: wallets,
        categories: categories,
      );

  Future<List<TransactionState>> recordStates(
    TransactionCubit cubit,
    Future<void> Function() action,
  ) async {
    final List<TransactionState> states = <TransactionState>[];
    final StreamSubscription<TransactionState> subscription =
        cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);
    await action();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    return states;
  }

  void stubExpenseLookups() {
    when(() => wallets.byId('w1')).thenAnswer((_) async => walletFixture());
    when(() => categories.byId('cat-exp-food-dining'))
        .thenAnswer((_) async => categoryFixture());
  }

  test('addExpense emits saving then saved', () async {
    stubExpenseLookups();
    when(() => transactions.record(any())).thenAnswer(
      (Invocation invocation) async =>
          invocation.positionalArguments.first as TransactionRecord,
    );
    final TransactionCubit cubit = buildCubit();

    final List<TransactionState> states = await recordStates(
      cubit,
      () => cubit.addExpense(
        amount: const Money(15000),
        walletId: 'w1',
        categoryId: 'cat-exp-food-dining',
        occurredAt: DateTime(2026, 11, 5, 10),
        note: '  lunch  ',
      ),
    );

    expect(states.length, 2);
    expect(states.first, isA<TransactionSaving>());
    final TransactionSaved saved = states.last as TransactionSaved;
    expect(saved.record.type, TransactionType.expense);
    expect(saved.record.amount, const Money(15000));
    expect(saved.record.note, 'lunch');
  });

  test('addTransfer emits saved with both wallets', () async {
    when(() => wallets.byId('w1')).thenAnswer((_) async => walletFixture());
    when(() => wallets.byId('w2')).thenAnswer(
      (_) async => walletFixture(id: 'w2', name: 'BDO'),
    );
    when(() => transactions.record(any())).thenAnswer(
      (Invocation invocation) async =>
          invocation.positionalArguments.first as TransactionRecord,
    );
    final TransactionCubit cubit = buildCubit();

    final List<TransactionState> states = await recordStates(
      cubit,
      () => cubit.addTransfer(
        amount: const Money(1000),
        sourceWalletId: 'w1',
        targetWalletId: 'w2',
        fee: const Money(1500),
      ),
    );

    final TransactionSaved saved = states.last as TransactionSaved;
    expect(saved.record.type, TransactionType.transfer);
    expect(saved.record.sourceWalletId, 'w1');
    expect(saved.record.targetWalletId, 'w2');
    expect(saved.record.categoryId, isNull);
    expect(saved.record.fee, const Money(1500));
  });

  test('edit emits saved with the new amount', () async {
    final TransactionRecord previous = recordFixture();
    when(() => transactions.edit(any(), any())).thenAnswer(
      (Invocation invocation) async =>
          invocation.positionalArguments[1] as TransactionRecord,
    );
    final TransactionCubit cubit = buildCubit();

    final List<TransactionState> states = await recordStates(
      cubit,
      () => cubit.edit(previous: previous, amount: const Money(10000)),
    );

    final TransactionSaved saved = states.last as TransactionSaved;
    expect(saved.record.id, previous.id);
    expect(saved.record.amount, const Money(10000));
    expect(saved.record.type, previous.type);
  });

  test('delete emits deleted', () async {
    when(() => transactions.byId('tx-1'))
        .thenAnswer((_) async => recordFixture());
    when(() => transactions.delete(any())).thenAnswer((_) async {});
    final TransactionCubit cubit = buildCubit();

    final List<TransactionState> states = await recordStates(
      cubit,
      () => cubit.delete('tx-1'),
    );

    expect(states.first, isA<TransactionSaving>());
    expect(states.last, isA<TransactionDeleted>());
  });

  test('a repository failure becomes a failure state', () async {
    stubExpenseLookups();
    when(() => transactions.record(any()))
        .thenThrow(const DatabaseFailure('Disk is full'));
    final TransactionCubit cubit = buildCubit();

    final List<TransactionState> states = await recordStates(
      cubit,
      () => cubit.addExpense(
        amount: const Money(15000),
        walletId: 'w1',
        categoryId: 'cat-exp-food-dining',
      ),
    );

    expect(states.first, isA<TransactionSaving>());
    expect(states.last, isA<TransactionFailure>());
    expect((states.last as TransactionFailure).message, 'Disk is full');
  });

  test('a transfer to the same wallet never reaches the repository', () async {
    final TransactionCubit cubit = buildCubit();

    final List<TransactionState> states = await recordStates(
      cubit,
      () => cubit.addTransfer(
        amount: const Money(1000),
        sourceWalletId: 'w1',
        targetWalletId: 'w1',
      ),
    );

    expect(states.last, isA<TransactionFailure>());
    expect(
      (states.last as TransactionFailure).message,
      'Choose two different wallets',
    );
    verifyNever(() => transactions.record(any()));
  });

  group('TransactionListCubit', () {
    test('load emits the recent records', () async {
      when(() => transactions.recent(limit: 50))
          .thenAnswer((_) async => <TransactionRecord>[recordFixture()]);
      final TransactionListCubit cubit =
          buildTransactionListCubit(transactions: transactions);
      addTearDown(cubit.close);
      final List<TransactionListState> states = <TransactionListState>[];
      final StreamSubscription<TransactionListState> subscription =
          cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(states.first, isA<TransactionListLoading>());
      final TransactionListLoaded loaded =
          states.last as TransactionListLoaded;
      expect(loaded.items.length, 1);
      expect(loaded.items.first.id, 'tx-1');
    });

    test('load failure is surfaced', () async {
      when(() => transactions.recent(limit: 50))
          .thenThrow(const DatabaseFailure('Database is unavailable'));
      final TransactionListCubit cubit =
          buildTransactionListCubit(transactions: transactions);
      addTearDown(cubit.close);
      final List<TransactionListState> states = <TransactionListState>[];
      final StreamSubscription<TransactionListState> subscription =
          cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(states.last, isA<TransactionListFailure>());
      expect(
        (states.last as TransactionListFailure).message,
        'Database is unavailable',
      );
    });

    test('reloads when the ledger changes', () async {
      final LedgerBus bus = LedgerBus();
      when(() => transactions.recent(limit: 50))
          .thenAnswer((_) async => <TransactionRecord>[recordFixture()]);
      final TransactionListCubit cubit = buildTransactionListCubit(
        transactions: transactions,
        ledgerBus: bus,
      );
      addTearDown(cubit.close);
      addTearDown(bus.dispose);

      await cubit.load();
      bus.notify();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => transactions.recent(limit: 50)).called(2);
    });
  });
}
