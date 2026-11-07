import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_settings_bus.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/usecases/parse_quick_entry.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/widgets/ai_quick_entry_card.dart';

import '../../helpers/ai_test_helpers.dart';
import '../../helpers/transaction_test_helpers.dart';
import '../../helpers/wallet_test_helpers.dart';

void main() {
  testWidgets('quick entry refreshes when AI settings change',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(),
    );
    final FakeAiClient client = FakeAiClient();
    final AiSettingsBus bus = AiSettingsBus();
    addTearDown(bus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AiQuickEntryCard(
            store: store,
            parseQuickEntry: ParseQuickEntry(
              settings: store,
              client: client,
              wallets: MockWalletRepository(),
              categories: MockCategoryRepository(),
            ),
            bus: bus,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up'), findsOneWidget);

    store.settings = const AiSettings(
      mode: AiMode.byok,
      model: 'deepseek-chat',
    );
    store.apiKey = 'sk-test';
    store.consent = true;
    bus.notify();
    await tester.pumpAndSettle();

    expect(find.text('Set up'), findsNothing);
    expect(
      find.text('The AI fills the form; you confirm before saving.'),
      findsOneWidget,
    );
  });
}
