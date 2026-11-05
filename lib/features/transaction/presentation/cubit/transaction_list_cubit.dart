import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/get_recent_transaction_records.dart';

import 'transaction_list_state.dart';

/// Recent ledger entries, refreshed whenever any feature writes.
class TransactionListCubit extends Cubit<TransactionListState> {
  TransactionListCubit({
    required GetRecentTransactionRecords getRecentTransactions,
    required LedgerBus ledgerBus,
  })  : _getRecent = getRecentTransactions,
        super(const TransactionListInitial()) {
    _subscription = ledgerBus.changes.listen((_) {
      if (!isClosed) {
        unawaited(load());
      }
    });
  }

  final GetRecentTransactionRecords _getRecent;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    if (isClosed) {
      return;
    }
    emit(const TransactionListLoading());
    try {
      final List<TransactionRecord> items = await _getRecent();
      if (isClosed) {
        return;
      }
      emit(TransactionListLoaded(items));
    } on Failure catch (failure) {
      if (isClosed) {
        return;
      }
      emit(TransactionListFailure(failure.message));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(const TransactionListFailure('Could not load transactions'));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
