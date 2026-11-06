import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/repositories/subscription_repository.dart';

final class GetSubscriptions {
  const GetSubscriptions({required SubscriptionRepository subscriptions})
      : _subscriptionRepo = subscriptions;

  final SubscriptionRepository _subscriptionRepo;

  Future<List<Subscription>> call({bool includeInactive = false}) =>
      _subscriptionRepo.all(includeInactive: includeInactive);
}

final class GetSubscription {
  const GetSubscription({required SubscriptionRepository subscriptions})
      : _subscriptionRepo = subscriptions;

  final SubscriptionRepository _subscriptionRepo;

  Future<Subscription?> call(String id) => _subscriptionRepo.byId(id);
}
