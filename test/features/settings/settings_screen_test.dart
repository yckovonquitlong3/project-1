import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/notifications/app_settings_launcher.dart';
import 'package:multi_wallet_tracker/core/notifications/local_notification_service.dart';
import 'package:multi_wallet_tracker/core/theme/app_theme.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/settings/presentation/screens/settings_screen.dart';

import '../../helpers/ai_test_helpers.dart';

class FakeNotificationService extends LocalNotificationService {
  FakeNotificationService({this.enabled = false});

  bool enabled;
  int requestCalls = 0;

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    requestCalls++;
    enabled = true;
    return true;
  }
}

class FakeSettingsLauncher extends AppSettingsLauncher {
  FakeSettingsLauncher();

  bool opened = false;

  @override
  Future<bool> openNotificationSettings() async {
    opened = true;
    return true;
  }
}

void main() {
  testWidgets('shows AI readiness and the AI privacy summary',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(mode: AiMode.byok, model: 'deepseek-chat'),
      apiKey: 'sk-test',
      consent: true,
    );
    final FakeNotificationService notifications =
        FakeNotificationService(enabled: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          settingsStore: store,
          notificationService: notifications,
          appSettingsLauncher: FakeSettingsLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI features'), findsOneWidget);
    expect(find.textContaining('Ready · OpenAI'), findsOneWidget);
    expect(find.textContaining('Model: deepseek-chat'), findsOneWidget);

    await tester.tap(find.text('What AI can see'));
    await tester.pumpAndSettle();

    expect(
      find.text('Analytics chat sends only aggregate totals:'),
      findsOneWidget,
    );
    expect(find.textContaining('wallet names and current balances'),
        findsOneWidget);
    expect(find.textContaining('never sends raw transactions'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('enables notifications and opens system settings when denied',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(),
    );
    final FakeNotificationService notifications = FakeNotificationService();
    final FakeSettingsLauncher launcher = FakeSettingsLauncher();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          settingsStore: store,
          notificationService: notifications,
          appSettingsLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subscription reminders'), findsOneWidget);
    expect(find.textContaining('Off. Reminders cannot appear'), findsOneWidget);
    expect(find.text('Enable'), findsOneWidget);

    await tester.tap(find.text('Open system notification settings'));
    await tester.pumpAndSettle();

    expect(launcher.opened, isTrue);

    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();

    expect(notifications.requestCalls, 1);
    expect(find.textContaining('On. Reminders are scheduled'), findsOneWidget);
    expect(find.text('Enable'), findsNothing);
  });

  testWidgets('shows that AI is off without a saved key',
      (WidgetTester tester) async {
    final FakeAiSettingsStore store = FakeAiSettingsStore(
      settings: const AiSettings(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SettingsScreen(
          settingsStore: store,
          notificationService: FakeNotificationService(enabled: true),
          appSettingsLauncher: FakeSettingsLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Off · no key saved'), findsOneWidget);
    expect(find.text('Your data stays on this device'), findsOneWidget);
    expect(find.textContaining('no proxy'), findsOneWidget);
  });
}
