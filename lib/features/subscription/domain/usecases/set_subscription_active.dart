import 'package:multi_wallet_tracker/features/subscription/domain/repositories/subscription_repository.dart';

final class SetSubscriptionActive {
  const SetSubscriptionActive({
    required SubscriptionRepository subscriptions,
  }) : _subscriptionRepo = subscriptions;

  final SubscriptionRepository _subscriptionRepo;

  Future<void> call(String id, {required bool active}) =>
      _subscriptionRepo.setActive(id, active: active);
}
