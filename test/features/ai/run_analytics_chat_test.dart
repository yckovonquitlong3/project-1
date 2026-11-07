import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/tools/analytics_tools.dart';
import 'package:multi_wallet_tracker/features/ai/domain/usecases/run_analytics_chat.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

import '../../helpers/ai_test_helpers.dart';
import '../../helpers/dashboard_test_helpers.dart';
import '../../helpers/transaction_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  late FakeAiSettingsStore store;
  late FakeAiClient client;
  late MockWalletRepository wallets;
  late MockDashboardRepository dashboard;
  late MockCategoryRepository categories;
  late AnalyticsTools tools;

  setUp(() {
    store = FakeAiSettingsStore(apiKey: 'sk-test', consent: true);
    client = FakeAiClient();
    wallets = MockWalletRepository();
    dashboard = MockDashboardRepository();
    categories = MockCategoryRepository();
    tools = AnalyticsTools(
      dashboard: dashboard,
      wallets: wallets,
      categories: categories,
    );
  });

  RunAnalyticsChat build() {
    return RunAnalyticsChat(
      settings: store,
      client: client,
      tools: tools,
      clock: () => DateTime(2026, 11, 7, 10),
    );
  }

  test('runs one read-only tool and returns the final answer', () async {
    when(() => wallets.all(includeArchived: true)).thenAnswer(
      (_) async => <Wallet>[walletFixture(balanceMinor: 10000)],
    );
    client.chatResponses.addAll(<AiChatResponse>[
      const AiChatResponse(
        toolCalls: <AiToolCall>[
          AiToolCall(
            id: 'call-1',
            name: 'get_wallet_balances',
            arguments: <String, Object?>{},
          ),
        ],
      ),
      const AiChatResponse(content: 'You have ₱100.00 in GCash.'),
    ]);

    final String answer = await build()(
      question: 'What are my balances?',
      history: const <AiChatMessage>[],
    );

    expect(answer, 'You have ₱100.00 in GCash.');
    expect(client.chatCalls, 2);
    verify(() => wallets.all(includeArchived: true)).called(1);
  });

  test('returns a direct answer without tools', () async {
    client.chatResponse = const AiChatResponse(content: 'You spent ₱0.');
    final String answer = await build()(question: 'What did I spend?');
    expect(answer, 'You spent ₱0.');
    expect(client.chatCalls, 1);
  });

  test('refuses when AI is off', () async {
    store.settings = const AiSettings(mode: AiMode.off);
    await expectLater(
      build()(question: 'anything'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.disabled,
        ),
      ),
    );
    expect(client.chatCalls, 0);
  });

  test('refuses without an API key', () async {
    store.apiKey = null;
    await expectLater(
      build()(question: 'anything'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.noKey,
        ),
      ),
    );
    expect(client.chatCalls, 0);
  });

  test('stops after the tool-round limit', () async {
    for (var i = 0; i < 5; i++) {
      client.chatResponses.add(
        AiChatResponse(
          toolCalls: <AiToolCall>[
            AiToolCall(
              id: 'call-$i',
              name: 'get_wallet_balances',
              arguments: <String, Object?>{},
            ),
          ],
        ),
      );
    }
    when(() => wallets.all(includeArchived: true))
        .thenAnswer((_) async => <Wallet>[walletFixture()]);

    await expectLater(
      build()(question: 'anything'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.invalidResponse,
        ),
      ),
    );
  });
}
