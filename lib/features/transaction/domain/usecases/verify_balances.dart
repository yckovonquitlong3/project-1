import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';

/// Returns the ids of wallets whose stored balance differs from the sum of
/// their transaction deltas. An empty list means the ledger is consistent.
final class VerifyBalances {
  const VerifyBalances({required TransactionRepository transactions})
      : _transactionRepo = transactions;

  final TransactionRepository _transactionRepo;

  Future<List<String>> call() => _transactionRepo.verifyBalances();
}
