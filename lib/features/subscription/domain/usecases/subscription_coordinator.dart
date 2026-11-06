import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_reminder_scheduler.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/run_due_subscriptions.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

/// Coordinates the foreground runner and the local reminder schedule.
class SubscriptionCoordinator {
  const SubscriptionCoordinator({
    required RunDueSubscriptions runner,
    required SubscriptionReminderScheduler scheduler,
    required SubscriptionRepository subscriptions,
    required WalletRepository wallets,
  })  : _runUseCase = runner,
        _reminderScheduler = scheduler,
        _subscriptionRepo = subscriptions,
        _walletRepo = wallets;

  final RunDueSubscriptions _runUseCase;
  final SubscriptionReminderScheduler _reminderScheduler;
  final SubscriptionRepository _subscriptionRepo;
  final WalletRepository _walletRepo;

  Future<SubscriptionRunResult> processAutomatic() async {
    final SubscriptionRunResult result = await _runUseCase.runAutomatic();
    await syncReminders();
    return result;
  }

  Future<SubscriptionRunResult> catchUpAll() async {
    final SubscriptionRunResult result = await _runUseCase.catchUpAll();
    await syncReminders();
    return result;
  }

  Future<SubscriptionRunResult> markPaid(String id) async {
    final SubscriptionRunResult result = await _runUseCase.markPaid(id);
    await syncReminders();
    return result;
  }

  /// Runs due processing when the app starts or resumes.
  Future<SubscriptionRunResult> onStart() => processAutomatic();

  Future<void> syncReminders() async {
    final List<Subscription> subscriptions = await _subscriptionRepo.all();
    final List<Wallet> wallets = await _walletRepo.all(includeArchived: true);
    final Map<String, String> names = <String, String>{};
    for (final Wallet wallet in wallets) {
      names[wallet.id] = wallet.name;
    }
    await _reminderScheduler.sync(
      subscriptions: subscriptions,
      walletNames: names,
    );
  }

  Future<bool> requestPermission() => _reminderScheduler.requestPermission();

  Future<bool> notificationsEnabled() => _reminderScheduler.notificationsEnabled();
}
