import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';
import 'package:multi_wallet_tracker/features/ai/domain/usecases/run_analytics_chat.dart';

import 'analytics_chat_state.dart';

class AnalyticsChatCubit extends Cubit<AnalyticsChatState> {
  AnalyticsChatCubit({
    required AiSettingsStore settings,
    required RunAnalyticsChat chat,
  })  : _settingsStore = settings,
        _runChat = chat,
        super(const AnalyticsChatInitial());

  final AiSettingsStore _settingsStore;
  final RunAnalyticsChat _runChat;
  List<AiChatMessage> _messages = <AiChatMessage>[];

  Future<void> load() async {
    if (isClosed) {
      return;
    }
    emit(const AnalyticsChatLoading());
    try {
      final settings = await _settingsStore.load();
      if (!settings.isEnabled) {
        emit(const AnalyticsChatUnavailable(
          'AI is off. Enable it in AI settings to ask questions.',
        ));
        return;
      }
      if (!await _settingsStore.hasConsent()) {
        emit(const AnalyticsChatUnavailable(
          'Accept the AI data notice in AI settings first.',
        ));
        return;
      }
      if (!await _settingsStore.hasApiKey()) {
        emit(const AnalyticsChatUnavailable(
          'Add your provider API key in AI settings first.',
        ));
        return;
      }
      if (isClosed) {
        return;
      }
      emit(AnalyticsChatReady(messages: _messages));
    } on Failure catch (failure) {
      if (isClosed) {
        return;
      }
      emit(AnalyticsChatFailure(failure.message));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(const AnalyticsChatFailure('Could not start the AI chat.'));
    }
  }

  Future<String?> send(String question) async {
    final AnalyticsChatState current = state;
    if (current is! AnalyticsChatReady || current.sending) {
      return null;
    }
    final String text = question.trim();
    if (text.isEmpty) {
      return null;
    }

    final List<AiChatMessage> history =
        List<AiChatMessage>.of(current.messages);
    final AiChatMessage userMessage = AiChatMessage(
      role: AiChatRole.user,
      content: text,
    );
    emit(
      AnalyticsChatReady(
        messages: <AiChatMessage>[...history, userMessage],
        sending: true,
      ),
    );

    try {
      final String answer = await _runChat(question: text, history: history);
      _messages = <AiChatMessage>[
        ...history,
        userMessage,
        AiChatMessage(role: AiChatRole.assistant, content: answer),
      ];
      emit(AnalyticsChatReady(messages: _messages));
      return null;
    } on Failure catch (failure) {
      emit(AnalyticsChatReady(messages: history));
      return failure.message;
    } catch (_) {
      emit(AnalyticsChatReady(messages: history));
      return 'The AI could not answer. Try again.';
    }
  }

  void clear() {
    _messages = <AiChatMessage>[];
    final AnalyticsChatState current = state;
    if (current is AnalyticsChatReady) {
      emit(const AnalyticsChatReady(messages: <AiChatMessage>[]));
    }
  }
}
