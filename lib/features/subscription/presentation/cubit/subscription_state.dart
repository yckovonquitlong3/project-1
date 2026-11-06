import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

sealed class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

final class SubscriptionLoading extends SubscriptionState {
  const SubscriptionLoading();
}

final class SubscriptionLoaded extends SubscriptionState {
  const SubscriptionLoaded({
    required this.active,
    required this.archived,
    required this.activeWallets,
    required this.expenseCategories,
    required this.walletNames,
    required this.categoryNames,
    required this.notificationsEnabled,
  });

  final List<Subscription> active;
  final List<Subscription> archived;
  final List<Wallet> activeWallets;
  final List<Category> expenseCategories;
  final Map<String, String> walletNames;
  final Map<String, String> categoryNames;
  final bool notificationsEnabled;

  bool get isEmpty => active.isEmpty && archived.isEmpty;

  @override
  List<Object?> get props => <Object?>[
        active,
        archived,
        activeWallets,
        expenseCategories,
        walletNames,
        categoryNames,
        notificationsEnabled,
      ];
}

final class SubscriptionFailure extends SubscriptionState {
  const SubscriptionFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
