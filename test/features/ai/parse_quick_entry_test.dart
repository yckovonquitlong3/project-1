import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/quick_entry_suggestion.dart';
import 'package:multi_wallet_tracker/features/ai/domain/usecases/parse_quick_entry.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_draft.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

import '../../helpers/ai_test_helpers.dart';
import '../../helpers/transaction_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  late MockWalletRepository wallets;
  late MockCategoryRepository categories;
  late FakeAiSettingsStore store;
  late FakeAiClient client;

  final Wallet gcash = walletFixture(name: 'GCash');
  final Category food = categoryFixture();
  final Category salary = categoryFixture(
    id: 'cat-inc-salary',
    name: 'Salary',
    type: CategoryType.income,
  );

  setUp(() {
    wallets = MockWalletRepository();
    categories = MockCategoryRepository();
    store = FakeAiSettingsStore(apiKey: 'sk-test', consent: true);
    client = FakeAiClient(
      suggestion: const QuickEntrySuggestion(
        amountText: '150.00',
        type: TransactionType.expense,
        walletName: 'gcash',
        categoryName: 'Food & Dining',
        note: '  iced coffee  ',
      ),
    );

    when(() => wallets.all()).thenAnswer((_) async => <Wallet>[gcash]);
    when(() => categories.byType(CategoryType.expense))
        .thenAnswer((_) async => <Category>[food]);
    when(() => categories.byType(CategoryType.income))
        .thenAnswer((_) async => <Category>[salary]);
  });

  ParseQuickEntry build() {
    return ParseQuickEntry(
      settings: store,
      client: client,
      wallets: wallets,
      categories: categories,
    );
  }

  test('maps the suggestion to local ids and a draft', () async {
    final TransactionDraft draft = await build()('Spent 150 via GCash');

    expect(draft.type, TransactionType.expense);
    expect(draft.amount?.minorUnits, 15000);
    expect(draft.sourceWalletId, gcash.id);
    expect(draft.categoryId, food.id);
    expect(draft.note, 'iced coffee');
    expect(client.parseCalls, 1);
  });

  test('maps a transfer with a target wallet and fee', () async {
    final Wallet maribank = walletFixture(id: 'w-mari', name: 'Maribank');
    final Wallet pocket = walletFixture(id: 'w-pocket', name: 'Pocket Money');
    when(() => wallets.all())
        .thenAnswer((_) async => <Wallet>[maribank, pocket]);
    client.suggestion = const QuickEntrySuggestion(
      amountText: '500.00',
      type: TransactionType.transfer,
      walletName: 'maribank',
      targetWalletName: 'pocket money',
      feeText: '15.00',
      note: 'withdrawal',
    );

    final TransactionDraft draft =
        await build()('I withdrew 500 from Maribank to Pocket Money');

    expect(draft.type, TransactionType.transfer);
    expect(draft.sourceWalletId, maribank.id);
    expect(draft.targetWalletId, pocket.id);
    expect(draft.categoryId, isNull);
    expect(draft.fee, const Money(1500));
    expect(draft.note, 'withdrawal');
  });

  test('leaves an ambiguous transfer target blank', () async {
    final Wallet maribank = walletFixture(id: 'w-mari', name: 'Maribank');
    when(() => wallets.all()).thenAnswer(
      (_) async => <Wallet>[
        maribank,
        walletFixture(id: 'w-p1', name: 'Pocket Money'),
        walletFixture(id: 'w-p2', name: 'Pocket Money'),
      ],
    );
    client.suggestion = const QuickEntrySuggestion(
      amountText: '500.00',
      type: TransactionType.transfer,
      walletName: 'Maribank',
      targetWalletName: 'Pocket Money',
    );

    final TransactionDraft draft = await build()('transfer');
    expect(draft.sourceWalletId, maribank.id);
    expect(draft.targetWalletId, isNull);
    expect(draft.fee, Money.zero);
  });

  test('clears a target that matches the source wallet', () async {
    final Wallet maribank = walletFixture(id: 'w-mari', name: 'Maribank');
    when(() => wallets.all()).thenAnswer((_) async => <Wallet>[maribank]);
    client.suggestion = const QuickEntrySuggestion(
      amountText: '500.00',
      type: TransactionType.transfer,
      walletName: 'Maribank',
      targetWalletName: 'Maribank',
    );

    final TransactionDraft draft = await build()('transfer');
    expect(draft.sourceWalletId, maribank.id);
    expect(draft.targetWalletId, isNull);
  });

  test('rejects an invalid transfer fee', () async {
    final Wallet maribank = walletFixture(id: 'w-mari', name: 'Maribank');
    final Wallet pocket = walletFixture(id: 'w-pocket', name: 'Pocket Money');
    when(() => wallets.all())
        .thenAnswer((_) async => <Wallet>[maribank, pocket]);
    client.suggestion = const QuickEntrySuggestion(
      amountText: '500.00',
      type: TransactionType.transfer,
      walletName: 'Maribank',
      targetWalletName: 'Pocket Money',
      feeText: 'not-a-fee',
    );

    await expectLater(
      build()('transfer'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('leaves ambiguous wallet names blank', () async {    when(() => wallets.all()).thenAnswer(
      (_) async => <Wallet>[
        walletFixture(id: 'w1', name: 'Cash'),
        walletFixture(id: 'w2', name: 'Cash'),
      ],
    );
    client.suggestion = const QuickEntrySuggestion(
      amountText: '20.00',
      type: TransactionType.expense,
      walletName: 'Cash',
      categoryName: 'Food & Dining',
    );

    final TransactionDraft draft = await build()('20 cash');
    expect(draft.sourceWalletId, isNull);
    expect(draft.categoryId, food.id);
  });

  test('does not map a category of the wrong type', () async {
    client.suggestion = const QuickEntrySuggestion(
      amountText: '100.00',
      type: TransactionType.income,
      walletName: 'GCash',
      categoryName: 'Food & Dining',
    );

    final TransactionDraft draft = await build()('got 100');
    expect(draft.type, TransactionType.income);
    expect(draft.categoryId, isNull);
  });

  test('rejects an invalid amount from the model', () async {
    client.suggestion = const QuickEntrySuggestion(
      amountText: 'zero',
      type: TransactionType.expense,
      walletName: 'GCash',
      categoryName: 'Food & Dining',
    );

    await expectLater(
      build()('free coffee'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('refuses when AI is off', () async {
    store.settings = const AiSettings(mode: AiMode.off);

    await expectLater(
      build()('coffee'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.disabled,
        ),
      ),
    );
    expect(client.parseCalls, 0);
  });

  test('refuses without consent', () async {
    store.consent = false;

    await expectLater(
      build()('coffee'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.consentRequired,
        ),
      ),
    );
    expect(client.parseCalls, 0);
  });

  test('refuses without an API key', () async {
    store.apiKey = null;

    await expectLater(
      build()('coffee'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.noKey,
        ),
      ),
    );
    expect(client.parseCalls, 0);
  });

  test('propagates provider failures', () async {
    client.error = const AiFailure(
      'No internet',
      kind: AiFailureKind.network,
    );

    await expectLater(
      build()('coffee'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.network,
        ),
      ),
    );
  });
}
