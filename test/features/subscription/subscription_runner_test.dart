import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notification.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/run_due_subscriptions.dart';
import 'package:multi_wallet_tracker/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/subscription_test_helpers.dart';

void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late TransactionRepositoryImpl transactions;
  late CategoryRepositoryImpl categories;
  late SubscriptionRepositoryImpl subscriptions;
  late FakeSubscriptionNotifier notifier;

  final DateTime repositoryNow = DateTime(2026, 9, 1, 8);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ledgerBus = LedgerBus();
    wallets = WalletRepositoryImpl(database: appDatabase, ledgerBus: ledgerBus);
    transactions = TransactionRepositoryImpl(
      database: appDatabase,
      ledgerBus: ledgerBus,
    );
    categories = CategoryRepositoryImpl(database: appDatabase);
    subscriptions = SubscriptionRepositoryImpl(
      database: appDatabase,
      clock: () => repositoryNow,
    );
    notifier = FakeSubscriptionNotifier();
    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  Future<Wallet> seedWallet({int openingMinor = 200000}) {
    return wallets.create(
      name: 'GCash',
      accountType: AccountType.eWallet,
      iconIdentifier: 'phone_android',
      openingBalance: Money(openingMinor),
    );
  }

  Future<Subscription> seedSubscription({
    required Wallet wallet,
    int amountMinor = 115000,
    DateTime? nextBillingAt,
    bool autoDeduct = true,
    BillingCycle cycle = BillingCycle.monthly,
    String categoryId = 'cat-exp-subscriptions',
  }) {
    return subscriptions.create(
      name: 'Claude Pro',
      amount: Money(amountMinor),
      walletId: wallet.id,
      categoryId: categoryId,
      cycle: cycle,
      nextBillingAt: nextBillingAt ?? DateTime(2026, 11, 1, 9),
      autoDeduct: autoDeduct,
    );
  }

  RunDueSubscriptions runnerAt(DateTime now) {
    return RunDueSubscriptions(
      subscriptions: subscriptions,
      wallets: wallets,
      categories: categories,
      notifier: notifier,
      ledgerBus: ledgerBus,
      clock: () => now,
    );
  }

  Future<List<TransactionRecord>> chargesFor(String walletId) async {
    final List<TransactionRecord> history =
        await transactions.forWallet(walletId, limit: 1000);
    return history
        .where((TransactionRecord record) => record.subscriptionId != null)
        .toList(growable: false);
  }

  test('pays a due subscription and advances the billing date', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await seedSubscription(wallet: wallet);
    final DateTime now = DateTime(2026, 11, 1, 9, 5);

    final SubscriptionRunResult result =
        await runnerAt(now).runAutomatic();

    expect(result.paid, 1);
    expect(result.failed, 0);
    expect(
      (await wallets.byId(wallet.id))!.balance,
      const Money(85000),
    );

    final List<TransactionRecord> charges = await chargesFor(wallet.id);
    expect(charges.length, 1);
    final TransactionRecord charge = charges.single;
    expect(charge.subscriptionId, subscription.id);
    expect(charge.billingPeriod, '2026-11-01');
    expect(charge.occurredAt, DateTime(2026, 11, 1, 9));
    expect(charge.amount, const Money(115000));
    expect(charge.fee, Money.zero);

    final Subscription updated =
        (await subscriptions.byId(subscription.id))!;
    expect(updated.nextBillingAt, DateTime(2026, 12, 1, 9));
    expect(updated.isOverdue, isFalse);
    expect(updated.lastPaidAt, now);
    expect(updated.lastFailureReason, isNull);
    expect(notifier.events.single, isA<SubscriptionPaidNotification>());
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('an insufficient balance writes nothing and marks overdue', () async {
    final Wallet wallet = await seedWallet(openingMinor: 50000);
    final Subscription subscription = await seedSubscription(wallet: wallet);
    final DateTime now = DateTime(2026, 11, 1, 9, 5);

    final SubscriptionRunResult result =
        await runnerAt(now).runAutomatic();

    expect(result.paid, 0);
    expect(result.failed, 1);
    expect(
      (await wallets.byId(wallet.id))!.balance,
      const Money(50000),
    );
    expect(await chargesFor(wallet.id), isEmpty);

    final Subscription updated =
        (await subscriptions.byId(subscription.id))!;
    expect(updated.nextBillingAt, DateTime(2026, 11, 1, 9));
    expect(updated.isOverdue, isTrue);
    expect(
      updated.lastFailureReason,
      SubscriptionFailureReason.insufficientBalance,
    );
    expect(
      notifier.events.single,
      isA<SubscriptionInsufficientNotification>(),
    );
  });

  test('auto-deduct off reminds first and can be paid manually', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await seedSubscription(
      wallet: wallet,
      autoDeduct: false,
    );
    final DateTime now = DateTime(2026, 11, 1, 9, 5);

    final SubscriptionRunResult automatic =
        await runnerAt(now).runAutomatic();
    expect(automatic.paid, 0);
    expect(automatic.skipped, 1);
    expect(await chargesFor(wallet.id), isEmpty);
    expect(
      (await subscriptions.byId(subscription.id))!.lastFailureReason,
      SubscriptionFailureReason.manualPaymentRequired,
    );
    expect(
      notifier.events.single,
      isA<SubscriptionManualPaymentNotification>(),
    );

    final SubscriptionRunResult manual =
        await runnerAt(now).markPaid(subscription.id);
    expect(manual.paid, 1);
    expect(
      (await wallets.byId(wallet.id))!.balance,
      const Money(85000),
    );
    expect(
      (await subscriptions.byId(subscription.id))!.nextBillingAt,
      DateTime(2026, 12, 1, 9),
    );
  });

  test('processing the same period twice charges once', () async {
    final Wallet wallet = await seedWallet();
    await seedSubscription(wallet: wallet);
    final DateTime now = DateTime(2026, 11, 1, 9, 5);
    final RunDueSubscriptions runner = runnerAt(now);

    final SubscriptionRunResult first = await runner.runAutomatic();
    final SubscriptionRunResult second = await runner.runAutomatic();

    expect(first.paid, 1);
    expect(second.paid, 0);
    expect((await chargesFor(wallet.id)).length, 1);
    expect(
      (await wallets.byId(wallet.id))!.balance,
      const Money(85000),
    );
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('automatic runs pay one cycle, catchUpAll pays the rest', () async {
    final Wallet wallet = await seedWallet(openingMinor: 400000);
    final Subscription subscription = await seedSubscription(
      wallet: wallet,
      nextBillingAt: DateTime(2026, 9, 1, 9),
    );
    final DateTime now = DateTime(2026, 11, 15, 10);

    final SubscriptionRunResult first =
        await runnerAt(now).runAutomatic();
    expect(first.paid, 1);
    Subscription updated = (await subscriptions.byId(subscription.id))!;
    expect(updated.nextBillingAt, DateTime(2026, 10, 1, 9));
    expect(updated.isOverdue, isTrue);

    final SubscriptionRunResult rest =
        await runnerAt(now).catchUpAll();
    expect(rest.paid, 2);

    updated = (await subscriptions.byId(subscription.id))!;
    expect(updated.nextBillingAt, DateTime(2026, 12, 1, 9));
    expect(updated.isOverdue, isFalse);
    expect((await chargesFor(wallet.id)).length, 3);
    expect(
      (await wallets.byId(wallet.id))!.balance,
      const Money(55000),
    );
    expect(await transactions.verifyBalances(), isEmpty);
  });

  test('catchUpAll stops when the balance runs out', () async {
    final Wallet wallet = await seedWallet(openingMinor: 250000);
    final Subscription subscription = await seedSubscription(
      wallet: wallet,
      nextBillingAt: DateTime(2026, 9, 1, 9),
    );
    final DateTime now = DateTime(2026, 11, 15, 10);

    final SubscriptionRunResult result =
        await runnerAt(now).catchUpAll();

    expect(result.paid, 2);
    expect(result.failed, 1);
    expect((await chargesFor(wallet.id)).length, 2);
    expect(
      (await wallets.byId(wallet.id))!.balance,
      const Money(20000),
    );

    final Subscription updated =
        (await subscriptions.byId(subscription.id))!;
    expect(updated.nextBillingAt, DateTime(2026, 11, 1, 9));
    expect(updated.isOverdue, isTrue);
    expect(
      updated.lastFailureReason,
      SubscriptionFailureReason.insufficientBalance,
    );
  });

  test('month-end billing preserves the anchor', () async {
    final Wallet wallet = await seedWallet(openingMinor: 300000);
    final Subscription subscription = await seedSubscription(
      wallet: wallet,
      nextBillingAt: DateTime(2026, 1, 31, 9),
    );

    await runnerAt(DateTime(2026, 1, 31, 9, 5)).runAutomatic();
    Subscription updated = (await subscriptions.byId(subscription.id))!;
    expect(updated.nextBillingAt, DateTime(2026, 2, 28, 9));

    await runnerAt(DateTime(2026, 2, 28, 9, 5)).runAutomatic();
    updated = (await subscriptions.byId(subscription.id))!;
    expect(updated.nextBillingAt, DateTime(2026, 3, 31, 9));

    final List<TransactionRecord> charges = await chargesFor(wallet.id);
    expect(
      charges.map((TransactionRecord record) => record.billingPeriod).toSet(),
      <String>{'2026-01-31', '2026-02-28'},
    );
  });

  test('an archived wallet blocks the charge', () async {
    final Wallet wallet = await seedWallet();
    await wallets.archive(wallet.id);
    final Subscription subscription = await seedSubscription(wallet: wallet);

    final SubscriptionRunResult result =
        await runnerAt(DateTime(2026, 11, 1, 9, 5)).runAutomatic();

    expect(result.paid, 0);
    expect(result.failed, 1);
    expect(await chargesFor(wallet.id), isEmpty);
    final Subscription updated =
        (await subscriptions.byId(subscription.id))!;
    expect(
      updated.lastFailureReason,
      SubscriptionFailureReason.walletArchived,
    );
    expect(
      notifier.events.single,
      isA<SubscriptionArchivedReferenceNotification>(),
    );
  });

  test('an archived category blocks the charge', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await seedSubscription(wallet: wallet);
    final Database db = await appDatabase.database;
    await db.update(
      'categories',
      <String, Object?>{'is_archived': 1},
      where: 'id = ?',
      whereArgs: <Object?>['cat-exp-subscriptions'],
    );

    final SubscriptionRunResult result =
        await runnerAt(DateTime(2026, 11, 1, 9, 5)).runAutomatic();

    expect(result.paid, 0);
    expect(result.failed, 1);
    expect(await chargesFor(wallet.id), isEmpty);
    final Subscription updated =
        (await subscriptions.byId(subscription.id))!;
    expect(
      updated.lastFailureReason,
      SubscriptionFailureReason.categoryArchived,
    );
  });

  test('a wallet with an active subscription cannot be archived or deleted',
      () async {
    final Wallet wallet = await seedWallet(openingMinor: 0);
    await seedSubscription(wallet: wallet);

    await expectLater(
      wallets.archive(wallet.id),
      throwsA(isA<ConflictFailure>()),
    );
    await expectLater(
      wallets.hardDelete(wallet.id),
      throwsA(isA<ConflictFailure>()),
    );
  });

  test('a notification failure does not roll back the charge', () async {
    notifier.throwOnNotify = true;
    final Wallet wallet = await seedWallet();
    await seedSubscription(wallet: wallet);

    final SubscriptionRunResult result =
        await runnerAt(DateTime(2026, 11, 1, 9, 5)).runAutomatic();

    expect(result.paid, 1);
    expect(
      (await wallets.byId(wallet.id))!.balance,
      const Money(85000),
    );
    expect((await chargesFor(wallet.id)).length, 1);
    expect(await transactions.verifyBalances(), isEmpty);
  });
}
