import 'dart:convert';

import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';
import 'package:multi_wallet_tracker/features/ai/domain/services/ai_client.dart';
import 'package:multi_wallet_tracker/features/ai/domain/tools/analytics_tools.dart';

/// Runs a bounded, read-only tool loop for the analytics chat.
class RunAnalyticsChat {
  const RunAnalyticsChat({
    required AiSettingsStore settings,
    required AiClient client,
    required AnalyticsTools tools,
    DateTime Function()? clock,
  })  : _settingsStore = settings,
        _aiClient = client,
        _toolBox = tools,
        _clock = clock ?? DateTime.now;

  static const int _maxRounds = 4;
  static const int _maxToolCalls = 8;
  static const int _historyLimit = 6;

  final AiSettingsStore _settingsStore;
  final AiClient _aiClient;
  final AnalyticsTools _toolBox;
  final DateTime Function() _clock;

  Future<String> call({
    required String question,
    List<AiChatMessage> history = const <AiChatMessage>[],
  }) async {
    final String text = question.trim();
    if (text.isEmpty) {
      throw const AiFailure(
        'Type a question first.',
        kind: AiFailureKind.invalidResponse,
      );
    }

    final settings = await _settingsStore.load();
    if (!settings.isEnabled) {
      throw const AiFailure(
        'AI is off. Enable it in AI settings.',
        kind: AiFailureKind.disabled,
      );
    }
    if (!await _settingsStore.hasConsent()) {
      throw const AiFailure(
        'Review and accept the AI data notice in Settings first.',
        kind: AiFailureKind.consentRequired,
      );
    }
    final String? apiKey = await _settingsStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiFailure(
        'Add your provider API key in AI settings first.',
        kind: AiFailureKind.noKey,
      );
    }

    final List<AiChatMessage> messages = <AiChatMessage>[
      AiChatMessage(
        role: AiChatRole.system,
        content:
            'You are a read-only financial assistant for the user\'s local '
            'ledger. Today is ${localDateOf(_clock())} (local).\n'
            'Use only the provided tools. Never invent numbers. Do not output '
            'SQL. Do not claim access to raw transaction rows or notes. Use '
            'local dates in YYYY-MM-DD format. Keep answers concise and state '
            'the period being discussed. Reply in plain text with short '
            'sentences and simple hyphen bullets. Never use Markdown tables, '
            'headings, bold, or code fences.',
      ),
      ..._trimHistory(history),
      AiChatMessage(role: AiChatRole.user, content: text),
    ];

    var toolCalls = 0;
    for (var round = 0; round < _maxRounds; round++) {
      final AiChatResponse response = await _aiClient.chat(
        messages: messages,
        tools: AnalyticsTools.definitions,
        settings: settings,
        apiKey: apiKey,
      );

      if (!response.hasToolCalls) {
        final String? content = response.content?.trim();
        if (content == null || content.isEmpty) {
          throw const AiFailure(
            'The AI did not return an answer. Try a simpler question.',
            kind: AiFailureKind.invalidResponse,
          );
        }
        return content;
      }

      messages.add(
        AiChatMessage(
          role: AiChatRole.assistant,
          content: response.content,
          toolCalls: response.toolCalls,
        ),
      );

      for (final AiToolCall call in response.toolCalls) {
        toolCalls++;
        if (toolCalls > _maxToolCalls) {
          throw const AiFailure(
            'The assistant used too many data lookups. Try a simpler question.',
            kind: AiFailureKind.invalidResponse,
          );
        }
        final Map<String, Object?> result = await _toolBox.execute(
          name: call.name,
          arguments: call.arguments,
        );
        messages.add(
          AiChatMessage(
            role: AiChatRole.tool,
            toolCallId: call.id,
            content: jsonEncode(result),
          ),
        );
      }
    }

    throw const AiFailure(
      'The assistant used too many tool steps. Try a simpler question.',
      kind: AiFailureKind.invalidResponse,
    );
  }

  List<AiChatMessage> _trimHistory(List<AiChatMessage> history) {
    final List<AiChatMessage> usable = history
        .where(
          (AiChatMessage message) =>
              (message.role == AiChatRole.user ||
                  message.role == AiChatRole.assistant) &&
              message.content != null &&
              message.content!.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (usable.length <= _historyLimit) {
      return usable;
    }
    return usable.sublist(usable.length - _historyLimit);
  }
}
