import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_provider.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/screens/ai_settings_screen.dart';

import '../../helpers/ai_test_helpers.dart';

void main() {
  testWidgets('enabling BYOK requires consent and stores the key',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(),
    );
    final FakeAiClient client = FakeAiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AiSettingsScreen(store: store, client: client),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BYOK'));
    await tester.pumpAndSettle();

    expect(find.text('Enable AI features?'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'sk-test');
    final Finder save = find.widgetWithText(FilledButton, 'Save settings');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(store.settings.mode, AiMode.byok);
    expect(store.apiKey, 'sk-test');
    expect(store.consent, isTrue);
  });

  testWidgets('disconnecting clears the key and consent',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(mode: AiMode.byok, model: 'test-model'),
      apiKey: 'sk-test',
      consent: true,
    );
    final FakeAiClient client = FakeAiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AiSettingsScreen(store: store, client: client),
      ),
    );
    await tester.pumpAndSettle();

    final Finder disconnect =
        find.text('Disconnect AI and delete key');
    await tester.scrollUntilVisible(
      disconnect,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(disconnect);
    await tester.pumpAndSettle();

    expect(find.text('Disconnect AI?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();

    expect(store.settings.mode, AiMode.off);
    expect(store.apiKey, isNull);
    expect(store.consent, isFalse);
  });

  test('documented provider defaults are editable starting points', () {
    expect(AiProviderPreset.openai.defaultModel, 'gpt-4o-mini');
    expect(AiProviderPreset.deepseek.defaultModel, 'deepseek-chat');
  });

  testWidgets('a custom model is saved', (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(
        mode: AiMode.byok,
        provider: AiProviderPreset.deepseek,
        model: 'deepseek-chat',
      ),
      apiKey: 'sk-test',
      consent: true,
    );
    final FakeAiClient client = FakeAiClient();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AiSettingsScreen(store: store, client: client),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'deepseek-custom');
    final Finder save = find.widgetWithText(FilledButton, 'Save settings');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(store.settings.model, 'deepseek-custom');
  });
}
