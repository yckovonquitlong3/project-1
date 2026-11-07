import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';

final class DeleteTransaction {
  const DeleteTransaction({required TransactionRepository transactions})
      : _transactionRepo = transactions;

  final TransactionRepository _transactionRepo;

  Future<void> call(String id) async {
    final TransactionRecord? record = await _transactionRepo.byId(id);
    if (record == null) {
      throw const NotFoundFailure('Transaction not found');
    }
    if (record.subscriptionId != null) {
      throw const ConflictFailure(kSubscriptionChargeImmutableMessage);
    }
    await _transactionRepo.delete(record);
  }
}
