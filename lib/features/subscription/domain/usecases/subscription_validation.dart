import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

void validateSubscriptionInput({
  required String name,
  required Money amount,
}) {
  if (name.trim().isEmpty) {
    throw const ValidationFailure('Subscription name is required');
  }
  if (!amount.isPositive) {
    throw const ValidationFailure('Subscription amount must be greater than zero');
  }
}

Future<({Wallet wallet, Category category})> validateSubscriptionReferences({
  required WalletRepository wallets,
  required CategoryRepository categories,
  required String walletId,
  required String categoryId,
}) async {
  final Wallet? wallet = await wallets.byId(walletId);
  if (wallet == null) {
    throw const NotFoundFailure('Wallet not found');
  }
  if (wallet.isArchived) {
    throw const ValidationFailure('That wallet is archived');
  }

  final Category? category = await categories.byId(categoryId);
  if (category == null) {
    throw const NotFoundFailure('Category not found');
  }
  if (category.isArchived) {
    throw const ValidationFailure('That category is archived');
  }
  if (category.type != CategoryType.expense) {
    throw const ValidationFailure('Choose an expense category');
  }

  return (wallet: wallet, category: category);
}
