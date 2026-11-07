import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/quick_entry_suggestion.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';
import 'package:multi_wallet_tracker/features/ai/domain/services/ai_client.dart';

class FakeAiSettingsStore implements AiSettingsStore {
  FakeAiSettingsStore({
    AiSettings? settings,
    this.apiKey,
    this.consent = false,
  }) : settings = settings ??
            const AiSettings(
              mode: AiMode.byok,
              model: 'test-model',
            );

  AiSettings settings;
  String? apiKey;
  bool consent;

  @override
  Future<AiSettings> load() async => settings;

  @override
  Future<void> save(AiSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<String?> readApiKey() async => apiKey;

  @override
  Future<void> saveApiKey(String key) async {
    apiKey = key;
  }

  @override
  Future<void> clearApiKey() async {
    apiKey = null;
  }

  @override
  Future<bool> hasApiKey() async =>
      apiKey != null && apiKey!.trim().isNotEmpty;

  @override
  Future<bool> hasConsent() async => consent;

  @override
  Future<void> grantConsent() async {
    consent = true;
  }

  @override
  Future<void> revokeConsent() async {
    consent = false;
    apiKey = null;
    settings = AiSettings(
      mode: AiMode.off,
      provider: settings.provider,
      model: settings.model,
    );
  }
}

class FakeAiClient implements AiClient {
  FakeAiClient({this.suggestion, this.error});

  QuickEntrySuggestion? suggestion;
  Object? error;
  int parseCalls = 0;
  int testCalls = 0;

  @override
  Future<QuickEntrySuggestion> parseQuickEntry({
    required String text,
    required AiSettings settings,
    required String apiKey,
  }) async {
    parseCalls++;
    if (error != null) {
      throw error!;
    }
    return suggestion!;
  }

  @override
  Future<void> testConnection({
    required AiSettings settings,
    required String apiKey,
  }) async {
    testCalls++;
    if (error != null) {
      throw error!;
    }
  }
}
