import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

/// Ledger rules shared by the transaction use cases.
///
/// Keeping them here means every write checks the same things, and a rule can
/// never be enforced on one screen but forgotten on another.

void requirePositiveAmount(Money amount) {
  if (!amount.isPositive) {
    throw const ValidationFailure('Amount must be greater than zero');
  }
}

Future<Wallet> requireActiveWallet(
  WalletRepository wallets,
  String walletId,
) async {
  final Wallet? wallet = await wallets.byId(walletId);
  if (wallet == null) {
    throw const NotFoundFailure('Wallet not found');
  }
  if (wallet.isArchived) {
    throw const ValidationFailure('That wallet is archived');
  }
  return wallet;
}

Future<Category> requireActiveCategory(
  CategoryRepository categories,
  String categoryId,
  CategoryType expected,
) async {
  final Category? category = await categories.byId(categoryId);
  if (category == null) {
    throw const NotFoundFailure('Category not found');
  }
  if (category.isArchived) {
    throw const ValidationFailure('That category is archived');
  }
  if (category.type != expected) {
    throw ValidationFailure('Pick an ${expected.name} category');
  }
  return category;
}
