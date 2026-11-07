import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';

abstract interface class AiSettingsStore {
  Future<AiSettings> load();

  Future<void> save(AiSettings settings);

  Future<String?> readApiKey();

  Future<void> saveApiKey(String key);

  Future<void> clearApiKey();

  Future<bool> hasApiKey();

  Future<bool> hasConsent();

  Future<void> grantConsent();

  /// Disables AI, deletes the key, and clears consent.
  Future<void> revokeConsent();
}
