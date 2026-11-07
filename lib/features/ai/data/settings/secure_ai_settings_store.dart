import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_provider.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';

class SecureAiSettingsStore implements AiSettingsStore {
  SecureAiSettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _modeKey = 'ai_mode';
  static const String _providerKey = 'ai_provider';
  static const String _modelKey = 'ai_model';
  static const String _apiKeyKey = 'ai_api_key';
  static const String _consentKey = 'ai_consent_version';
  static const String _consentVersion = '1';

  final FlutterSecureStorage _storage;

  @override
  Future<AiSettings> load() async {
    try {
      final String? mode = await _storage.read(key: _modeKey);
      final String? provider = await _storage.read(key: _providerKey);
      final String? model = await _storage.read(key: _modelKey);
      final AiProviderPreset preset = AiProviderPreset.fromDb(provider);
      return AiSettings(
        mode: AiMode.fromDb(mode),
        provider: preset,
        model: model == null || model.trim().isEmpty
            ? preset.defaultModel
            : model,
      );
    } catch (error) {
      throw AiFailure(
        'Could not read AI settings from secure storage.',
        cause: error,
      );
    }
  }

  @override
  Future<void> save(AiSettings settings) async {
    try {
      await _storage.write(key: _modeKey, value: settings.mode.dbValue);
      await _storage.write(
        key: _providerKey,
        value: settings.provider.dbValue,
      );
      await _storage.write(key: _modelKey, value: settings.model);
    } catch (error) {
      throw AiFailure(
        'Could not save AI settings to secure storage.',
        cause: error,
      );
    }
  }

  @override
  Future<String?> readApiKey() async {
    try {
      return await _storage.read(key: _apiKeyKey);
    } catch (error) {
      throw AiFailure(
        'Could not read the API key from secure storage.',
        cause: error,
      );
    }
  }

  @override
  Future<void> saveApiKey(String key) async {
    try {
      final String trimmed = key.trim();
      if (trimmed.isEmpty) {
        await _storage.delete(key: _apiKeyKey);
        return;
      }
      await _storage.write(key: _apiKeyKey, value: trimmed);
    } catch (error) {
      throw AiFailure(
        'Could not save the API key to secure storage.',
        cause: error,
      );
    }
  }

  @override
  Future<void> clearApiKey() async {
    try {
      await _storage.delete(key: _apiKeyKey);
    } catch (error) {
      throw AiFailure(
        'Could not delete the API key from secure storage.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> hasApiKey() async {
    final String? key = await readApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  @override
  Future<bool> hasConsent() async {
    try {
      return await _storage.read(key: _consentKey) == _consentVersion;
    } catch (error) {
      throw AiFailure(
        'Could not read the AI consent state.',
        cause: error,
      );
    }
  }

  @override
  Future<void> grantConsent() async {
    try {
      await _storage.write(key: _consentKey, value: _consentVersion);
    } catch (error) {
      throw AiFailure(
        'Could not save the AI consent state.',
        cause: error,
      );
    }
  }

  @override
  Future<void> revokeConsent() async {
    try {
      await _storage.delete(key: _consentKey);
      await _storage.delete(key: _apiKeyKey);
      await _storage.write(key: _modeKey, value: AiMode.off.dbValue);
    } catch (error) {
      throw AiFailure(
        'Could not revoke AI access.',
        cause: error,
      );
    }
  }
}
