import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';

abstract interface class TransactionRepository {
  /// Inserts the record and applies its balance effect atomically.
  Future<TransactionRecord> record(TransactionRecord record);

  /// Reverses [previous], applies [updated], and rewrites the row atomically.
  Future<TransactionRecord> edit(
    TransactionRecord previous,
    TransactionRecord updated,
  );

  /// Reverses the balance effect and removes the row atomically.
  Future<void> delete(TransactionRecord record);

  Future<TransactionRecord?> byId(String id);

  Future<List<TransactionRecord>> recent({int limit = 20});

  Future<List<TransactionRecord>> forWallet(String walletId, {int limit = 50});

  /// Returns the ids of wallets whose stored balance differs from the sum of
  /// their transaction deltas. Empty means the ledger is consistent.
  Future<List<String>> verifyBalances();
}