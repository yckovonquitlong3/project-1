import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/subscription_validation.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

final class CreateSubscription {
  const CreateSubscription({
    required SubscriptionRepository subscriptions,
    required WalletRepository wallets,
    required CategoryRepository categories,
  })  : _subscriptionRepo = subscriptions,
        _walletRepo = wallets,
        _categoryRepo = categories;

  final SubscriptionRepository _subscriptionRepo;
  final WalletRepository _walletRepo;
  final CategoryRepository _categoryRepo;

  Future<Subscription> call({
    required String name,
    required Money amount,
    required String walletId,
    required String categoryId,
    required BillingCycle cycle,
    required DateTime nextBillingAt,
    bool autoDeduct = true,
  }) async {
    validateSubscriptionInput(name: name, amount: amount);
    await validateSubscriptionReferences(
      wallets: _walletRepo,
      categories: _categoryRepo,
      walletId: walletId,
      categoryId: categoryId,
    );

    return _subscriptionRepo.create(
      name: name.trim(),
      amount: amount,
      walletId: walletId,
      categoryId: categoryId,
      cycle: cycle,
      nextBillingAt: nextBillingAt,
      autoDeduct: autoDeduct,
    );
  }
}
