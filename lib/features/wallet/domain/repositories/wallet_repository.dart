import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

abstract interface class WalletRepository {
  /// Active wallets by default; pass [includeArchived] to see everything.
  Future<List<Wallet>> all({bool includeArchived = false});

  Future<Wallet?> byId(String id);

  /// Creates the wallet and, when [openingBalance] is positive, an auditable
  /// `Opening Balance` income transaction in the same database transaction.
  Future<Wallet> create({
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
    required Money openingBalance,
  });

  Future<Wallet> update({
    required String id,
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
  });

  Future<void> archive(String id);

  Future<void> restore(String id);

  Future<bool> hasTransactions(String id);

  /// Throws [ConflictFailure] when the wallet still has transactions.
  Future<void> hardDelete(String id);
}