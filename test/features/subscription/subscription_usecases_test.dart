import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/create_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/delete_subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/get_subscriptions.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/set_subscription_active.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/update_subscription.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late CategoryRepositoryImpl categories;
  late SubscriptionRepositoryImpl subscriptions;
  late CreateSubscription createSubscription;
  late UpdateSubscription updateSubscription;
  late GetSubscriptions getSubscriptions;
  late SetSubscriptionActive setSubscriptionActive;
  late DeleteSubscription deleteSubscription;

  final DateTime now = DateTime(2026, 9, 1, 8);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ledgerBus = LedgerBus();
    wallets = WalletRepositoryImpl(database: appDatabase, ledgerBus: ledgerBus);
    categories = CategoryRepositoryImpl(database: appDatabase);
    subscriptions = SubscriptionRepositoryImpl(
      database: appDatabase,
      clock: () => now,
    );
    createSubscription = CreateSubscription(
      subscriptions: subscriptions,
      wallets: wallets,
      categories: categories,
    );
    updateSubscription = UpdateSubscription(
      subscriptions: subscriptions,
      wallets: wallets,
      categories: categories,
    );
    getSubscriptions = GetSubscriptions(subscriptions: subscriptions);
    setSubscriptionActive = SetSubscriptionActive(subscriptions: subscriptions);
    deleteSubscription = DeleteSubscription(subscriptions: subscriptions);
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

  Future<Subscription> create(
    Wallet wallet, {
    String name = 'Claude Pro',
    int amountMinor = 115000,
    String categoryId = 'cat-exp-subscriptions',
    DateTime? nextBillingAt,
  }) {
    return createSubscription(
      name: name,
      amount: Money(amountMinor),
      walletId: wallet.id,
      categoryId: categoryId,
      cycle: BillingCycle.monthly,
      nextBillingAt: nextBillingAt ?? DateTime(2026, 11, 1, 9, 30),
    );
  }

  test('creates a subscription and derives the billing anchor and time',
      () async {
    final Wallet wallet = await seedWallet();

    final Subscription subscription = await create(wallet);

    expect(subscription.name, 'Claude Pro');
    expect(subscription.amount, const Money(115000));
    expect(subscription.nextBillingAt, DateTime(2026, 11, 1, 9, 30));
    expect(subscription.billingAnchorDay, 1);
    expect(subscription.billingTimeMinutes, 9 * 60 + 30);
    expect(subscription.autoDeduct, isTrue);
    expect((await getSubscriptions()).length, 1);
  });

  test('rejects a blank name', () async {
    final Wallet wallet = await seedWallet();

    await expectLater(
      create(wallet, name: '  '),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await getSubscriptions(), isEmpty);
  });

  test('rejects a zero amount', () async {
    final Wallet wallet = await seedWallet();

    await expectLater(
      create(wallet, amountMinor: 0),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await getSubscriptions(), isEmpty);
  });

  test('rejects an archived wallet', () async {
    final Wallet wallet = await seedWallet();
    await wallets.archive(wallet.id);

    await expectLater(
      create(wallet),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await getSubscriptions(), isEmpty);
  });

  test('rejects an income category', () async {
    final Wallet wallet = await seedWallet();

    await expectLater(
      create(wallet, categoryId: 'cat-inc-salary'),
      throwsA(isA<ValidationFailure>()),
    );
    expect(await getSubscriptions(), isEmpty);
  });

  test('updates a subscription', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await create(wallet);

    final Subscription updated = await updateSubscription(
      id: subscription.id,
      name: 'Spotify',
      amount: const Money(25000),
      walletId: wallet.id,
      categoryId: 'cat-exp-subscriptions',
      cycle: BillingCycle.yearly,
      nextBillingAt: DateTime(2027, 1, 15, 10),
      autoDeduct: false,
    );

    expect(updated.name, 'Spotify');
    expect(updated.amount, const Money(25000));
    expect(updated.cycle, BillingCycle.yearly);
    expect(updated.autoDeduct, isFalse);
    expect(updated.billingAnchorDay, 15);
    expect(updated.billingTimeMinutes, 10 * 60);
  });

  test('archives and restores a subscription', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await create(wallet);

    await setSubscriptionActive(subscription.id, active: false);
    expect(await getSubscriptions(), isEmpty);
    expect(
      (await subscriptions.byId(subscription.id))!.isActive,
      isFalse,
    );

    await setSubscriptionActive(subscription.id, active: true);
    expect((await getSubscriptions()).length, 1);
  });

  test('deletes a subscription with no charges', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await create(wallet);

    await deleteSubscription(subscription.id);
    expect(await subscriptions.byId(subscription.id), isNull);
  });

  test('refuses to delete a subscription with charges', () async {
    final Wallet wallet = await seedWallet();
    final Subscription subscription = await create(wallet);
    final DateTime due = subscription.nextBillingAt;
    final String period = localDateOf(due);

    await subscriptions.recordCharge(
      transaction: TransactionRecord(
        id: 'charge-1',
        amount: subscription.amount,
        type: TransactionType.expense,
        sourceWalletId: wallet.id,
        categoryId: subscription.categoryId,
        occurredAt: due,
        localDate: period,
        note: subscription.name,
        subscriptionId: subscription.id,
        billingPeriod: period,
        createdAt: now,
        updatedAt: now,
      ),
      nextBillingAtMs: epochMillis(DateTime(2026, 12, 1, 9, 30)),
      isOverdue: false,
      paidAt: now,
    );

    await expectLater(
      deleteSubscription(subscription.id),
      throwsA(isA<ConflictFailure>()),
    );
  });
}
