import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';

sealed class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class TransactionIdle extends TransactionState {
  const TransactionIdle();
}

final class TransactionSaving extends TransactionState {
  const TransactionSaving();
}

final class TransactionSaved extends TransactionState {
  const TransactionSaved(this.record);

  final TransactionRecord record;

  @override
  List<Object?> get props => <Object?>[record];
}

final class TransactionDeleted extends TransactionState {
  const TransactionDeleted();
}

final class TransactionFailure extends TransactionState {
  const TransactionFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
