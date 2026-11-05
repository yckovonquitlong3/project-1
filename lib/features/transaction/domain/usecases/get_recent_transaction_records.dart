import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';

final class GetRecentTransactionRecords {
  const GetRecentTransactionRecords({
    required TransactionRepository transactions,
  }) : _transactionRepo = transactions;

  final TransactionRepository _transactionRepo;

  Future<List<TransactionRecord>> call({int limit = 50}) =>
      _transactionRepo.recent(limit: limit);
}
