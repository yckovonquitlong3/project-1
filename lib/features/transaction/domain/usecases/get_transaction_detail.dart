import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_detail.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

/// Loads a transaction together with the wallets and category it references.
///
/// Archived wallets and categories are still resolved: history must remain
/// viewable after a wallet is archived.
final class GetTransactionDetail {
  const GetTransactionDetail({
    required TransactionRepository transactions,
    required WalletRepository wallets,
    required CategoryRepository categories,
  })  : _transactionRepo = transactions,
        _walletRepo = wallets,
        _categoryRepo = categories;

  final TransactionRepository _transactionRepo;
  final WalletRepository _walletRepo;
  final CategoryRepository _categoryRepo;

  Future<TransactionDetail> call(String id) async {
    final TransactionRecord? record = await _transactionRepo.byId(id);
    if (record == null) {
      throw const NotFoundFailure('Transaction not found');
    }

    final Wallet? source = await _walletRepo.byId(record.sourceWalletId);
    if (source == null) {
      throw const NotFoundFailure('Wallet not found');
    }

    Wallet? target;
    if (record.targetWalletId != null) {
      target = await _walletRepo.byId(record.targetWalletId!);
    }

    Category? category;
    if (record.categoryId != null) {
      category = await _categoryRepo.byId(record.categoryId!);
    }

    return TransactionDetail(
      record: record,
      sourceWallet: source,
      targetWallet: target,
      category: category,
    );
  }
}
