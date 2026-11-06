import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/add_expense.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/add_income.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/delete_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/edit_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/transfer_money.dart';

import 'transaction_state.dart';

/// Drives one transaction form: save, edit, or delete.
class TransactionCubit extends Cubit<TransactionState> {
  TransactionCubit({
    required AddExpense addExpense,
    required AddIncome addIncome,
    required TransferMoney transferMoney,
    required EditTransaction editTransaction,
    required DeleteTransaction deleteTransaction,
  })  : _expenseEntry = addExpense,
        _incomeEntry = addIncome,
        _transferEntry = transferMoney,
        _editEntry = editTransaction,
        _deleteEntry = deleteTransaction,
        super(const TransactionIdle());

  final AddExpense _expenseEntry;
  final AddIncome _incomeEntry;
  final TransferMoney _transferEntry;
  final EditTransaction _editEntry;
  final DeleteTransaction _deleteEntry;

  Future<void> addExpense({
    required Money amount,
    required String walletId,
    required String categoryId,
    DateTime? occurredAt,
    String? note,
  }) {
    return _run(
      () => _expenseEntry(
        amount: amount,
        walletId: walletId,
        categoryId: categoryId,
        occurredAt: occurredAt,
        note: note,
      ),
    );
  }

  Future<void> addIncome({
    required Money amount,
    required String walletId,
    required String categoryId,
    DateTime? occurredAt,
    String? note,
  }) {
    return _run(
      () => _incomeEntry(
        amount: amount,
        walletId: walletId,
        categoryId: categoryId,
        occurredAt: occurredAt,
        note: note,
      ),
    );
  }

  Future<void> addTransfer({
    required Money amount,
    required String sourceWalletId,
    required String targetWalletId,
    Money fee = Money.zero,
    DateTime? occurredAt,
    String? note,
  }) {
    return _run(
      () => _transferEntry(
        amount: amount,
        sourceWalletId: sourceWalletId,
        targetWalletId: targetWalletId,
        fee: fee,
        occurredAt: occurredAt,
        note: note,
      ),
    );
  }

  Future<void> edit({
    required TransactionRecord previous,
    required Money amount,
    Money? fee,
    String? sourceWalletId,
    String? targetWalletId,
    String? categoryId,
    DateTime? occurredAt,
    String? note,
  }) {
    return _run(
      () => _editEntry(
        previous: previous,
        amount: amount,
        fee: fee,
        sourceWalletId: sourceWalletId,
        targetWalletId: targetWalletId,
        categoryId: categoryId,
        occurredAt: occurredAt,
        note: note,
      ),
    );
  }

  Future<void> delete(String id) async {
    emit(const TransactionSaving());
    try {
      await _deleteEntry(id);
      emit(const TransactionDeleted());
    } on Failure catch (failure) {
      emit(TransactionFailure(failure.message));
    } catch (_) {
      emit(const TransactionFailure('Could not delete the transaction'));
    }
  }

  Future<void> _run(Future<TransactionRecord> Function() action) async {
    emit(const TransactionSaving());
    try {
      final TransactionRecord record = await action();
      emit(TransactionSaved(record));
    } on Failure catch (failure) {
      emit(TransactionFailure(failure.message));
    } catch (_) {
      emit(const TransactionFailure('Could not save the transaction'));
    }
  }
}
