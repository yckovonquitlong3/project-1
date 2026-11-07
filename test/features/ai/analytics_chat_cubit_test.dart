import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/tools/analytics_tools.dart';
import 'package:multi_wallet_tracker/features/ai/domain/usecases/run_analytics_chat.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/cubit/analytics_chat_cubit.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/cubit/analytics_chat_state.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/screens/analytics_chat_screen.dart';

import '../../helpers/ai_test_helpers.dart';
import '../../helpers/dashboard_test_helpers.dart';
import '../../helpers/transaction_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  late FakeAiSettingsStore store;
  late FakeAiClient client;
  late AnalyticsTools tools;

  setUp(() {
    store = FakeAiSettingsStore(apiKey: 'sk-test', consent: true);
    client = FakeAiClient();
    client.chatResponse =
        const AiChatResponse(content: 'You have ₱100.00.');
    tools = AnalyticsTools(
      dashboard: MockDashboardRepository(),
      wallets: MockWalletRepository(),
      categories: MockCategoryRepository(),
    );
  });

  AnalyticsChatCubit buildCubit() {
    return AnalyticsChatCubit(
      settings: store,
      chat: RunAnalyticsChat(
        settings: store,
        client: client,
        tools: tools,
        clock: () => DateTime(2026, 11, 7, 10),
      ),
    );
  }

  test('loads ready when AI is configured', () async {
    final AnalyticsChatCubit cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state, isA<AnalyticsChatReady>());
  });

  test('unavailable states explain what is missing', () async {
    store.settings = const AiSettings(mode: AiMode.off);
    final AnalyticsChatCubit cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state, isA<AnalyticsChatUnavailable>());
  });

  test('sending adds the user and assistant turns', () async {
    final AnalyticsChatCubit cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.load();

    final String? error = await cubit.send('What are my balances?');

    expect(error, isNull);
    final AnalyticsChatReady state = cubit.state as AnalyticsChatReady;
    expect(state.messages.length, 2);
    expect(state.messages.first.role, AiChatRole.user);
    expect(state.messages.last.role, AiChatRole.assistant);
    expect(state.messages.last.content, 'You have ₱100.00.');
    expect(client.chatCalls, 1);
  });

  test('a failed answer restores the previous history and returns a message',
      () async {
    client.error = const AiFailure(
      'No internet',
      kind: AiFailureKind.network,
    );
    final AnalyticsChatCubit cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.load();

    final String? error = await cubit.send('What are my balances?');

    expect(error, 'No internet');
    final AnalyticsChatReady state = cubit.state as AnalyticsChatReady;
    expect(state.messages, isEmpty);
    expect(state.sending, isFalse);
  });

  test('clear removes the conversation', () async {
    final AnalyticsChatCubit cubit = buildCubit();
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.send('What are my balances?');

    cubit.clear();

    final AnalyticsChatReady state = cubit.state as AnalyticsChatReady;
    expect(state.messages, isEmpty);
  });

  testWidgets('chat shows suggestions before the first question',
      (WidgetTester tester) async {
    final AnalyticsChatCubit cubit = buildCubit();
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AnalyticsChatScreen(cubit: cubit),
      ),
    );
    await tester.pump();

    expect(find.text('Ask your ledger'), findsOneWidget);
    expect(
      find.text('What are my wallet balances?'),
      findsOneWidget,
    );

    await tester.runAsync(cubit.close);
  });
}
