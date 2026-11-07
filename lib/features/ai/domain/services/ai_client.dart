import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/quick_entry_suggestion.dart';

abstract interface class AiClient {
  Future<QuickEntrySuggestion> parseQuickEntry({
    required String text,
    required AiSettings settings,
    required String apiKey,
  });

  Future<AiChatResponse> chat({
    required List<AiChatMessage> messages,
    required List<AiToolDefinition> tools,
    required AiSettings settings,
    required String apiKey,
  });

  Future<void> testConnection({
    required AiSettings settings,
    required String apiKey,
  });
}
