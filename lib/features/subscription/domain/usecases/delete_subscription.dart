import 'package:multi_wallet_tracker/features/subscription/domain/repositories/subscription_repository.dart';

final class DeleteSubscription {
  const DeleteSubscription({required SubscriptionRepository subscriptions})
      : _subscriptionRepo = subscriptions;

  final SubscriptionRepository _subscriptionRepo;

  Future<void> call(String id) => _subscriptionRepo.delete(id);
}
