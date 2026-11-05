import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';

sealed class TransactionListState extends Equatable {
  const TransactionListState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class TransactionListInitial extends TransactionListState {
  const TransactionListInitial();
}

final class TransactionListLoading extends TransactionListState {
  const TransactionListLoading();
}

final class TransactionListLoaded extends TransactionListState {
  const TransactionListLoaded(this.items);

  final List<TransactionRecord> items;

  @override
  List<Object?> get props => <Object?>[items];
}

final class TransactionListFailure extends TransactionListState {
  const TransactionListFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
