import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/usecases/get_categories.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/create_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/delete_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/get_subscriptions.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/run_due_subscriptions.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/set_subscription_active.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/subscription_coordinator.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/update_subscription.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';

import 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit({
    required GetSubscriptions getSubscriptions,
    required CreateSubscription createSubscription,
    required UpdateSubscription updateSubscription,
    required SetSubscriptionActive setSubscriptionActive,
    required DeleteSubscription deleteSubscription,
    required GetWallets getWallets,
    required GetCategories getCategories,
    required SubscriptionCoordinator coordinator,
  })  : _loadSubscriptions = getSubscriptions,
        _create = createSubscription,
        _update = updateSubscription,
        _setActive = setSubscriptionActive,
        _delete = deleteSubscription,
        _loadWallets = getWallets,
        _loadCategories = getCategories,
        _subscriptionCoordinator = coordinator,
        super(const SubscriptionInitial());

  final GetSubscriptions _loadSubscriptions;
  final CreateSubscription _create;
  final UpdateSubscription _update;
  final SetSubscriptionActive _setActive;
  final DeleteSubscription _delete;
  final GetWallets _loadWallets;
  final GetCategories _loadCategories;
  final SubscriptionCoordinator _subscriptionCoordinator;

  Future<void> load() async {
    if (isClosed) {
      return;
    }
    emit(const SubscriptionLoading());
    try {
      await _subscriptionCoordinator.processAutomatic();
      final List<Subscription> all =
          await _loadSubscriptions(includeInactive: true);
      final List<Subscription> active = all
          .where((Subscription subscription) => subscription.isActive)
          .toList(growable: false);
      final List<Subscription> archived = all
          .where((Subscription subscription) => !subscription.isActive)
          .toList(growable: false);

      final ({List<Wallet> active, List<Wallet> archived}) wallets =
          await _loadWallets();
      final List<Category> categories =
          await _loadCategories(CategoryType.expense);
      final bool enabled = await _subscriptionCoordinator.notificationsEnabled();
      if (isClosed) {
        return;
      }

      emit(
        SubscriptionLoaded(
          active: active,
          archived: archived,
          activeWallets: wallets.active,
          expenseCategories: categories,
          walletNames: <String, String>{
            for (final Wallet wallet in <Wallet>[
              ...wallets.active,
              ...wallets.archived,
            ])
              wallet.id: wallet.name,
          },
          categoryNames: <String, String>{
            for (final Category category in categories)
              category.id: category.name,
          },
          notificationsEnabled: enabled,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed) {
        return;
      }
      emit(SubscriptionFailure(failure.message));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(const SubscriptionFailure('Could not load subscriptions'));
    }
  }

  Future<String?> create({
    required String name,
    required Money amount,
    required String walletId,
    required String categoryId,
    required BillingCycle cycle,
    required DateTime nextBillingAt,
    required bool autoDeduct,
  }) {
    return _write(() async {
      await _create(
        name: name,
        amount: amount,
        walletId: walletId,
        categoryId: categoryId,
        cycle: cycle,
        nextBillingAt: nextBillingAt,
        autoDeduct: autoDeduct,
      );
    });
  }

  Future<String?> update({
    required String id,
    required String name,
    required Money amount,
    required String walletId,
    required String categoryId,
    required BillingCycle cycle,
    required DateTime nextBillingAt,
    required bool autoDeduct,
  }) {
    return _write(() async {
      await _update(
        id: id,
        name: name,
        amount: amount,
        walletId: walletId,
        categoryId: categoryId,
        cycle: cycle,
        nextBillingAt: nextBillingAt,
        autoDeduct: autoDeduct,
      );
    });
  }

  Future<String?> setActive(String id, {required bool active}) {
    return _write(() => _setActive(id, active: active));
  }

  Future<String?> delete(String id) {
    return _write(() => _delete(id));
  }

  Future<String?> markPaid(String id) async {
    try {
      final SubscriptionRunResult result = await _subscriptionCoordinator.markPaid(id);
      await load();
      if (result.busy) {
        return 'Another subscription run is already in progress.';
      }
      if (result.paid > 0) {
        return null;
      }
      if (result.failed > 0) {
        return 'The payment could not be processed. Check the overdue reason.';
      }
      return 'This subscription is not due yet.';
    } on Failure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'The payment could not be processed.';
    }
  }

  Future<String?> catchUpAll() async {
    try {
      final SubscriptionRunResult result = await _subscriptionCoordinator.catchUpAll();
      await load();
      if (result.busy) {
        return 'Another subscription run is already in progress.';
      }
      if (result.paid > 0) {
        return null;
      }
      return 'No overdue subscriptions were paid.';
    } on Failure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'The catch-up run failed.';
    }
  }

  Future<bool> requestNotificationPermission() async {
    final bool granted = await _subscriptionCoordinator.requestPermission();
    await load();
    return granted;
  }

  Future<String?> _write(Future<void> Function() action) async {
    try {
      await action();
      await _subscriptionCoordinator.syncReminders();
      await load();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }
}
