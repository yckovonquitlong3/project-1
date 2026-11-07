import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';

sealed class AnalyticsChatState extends Equatable {
  const AnalyticsChatState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class AnalyticsChatInitial extends AnalyticsChatState {
  const AnalyticsChatInitial();
}

final class AnalyticsChatLoading extends AnalyticsChatState {
  const AnalyticsChatLoading();
}

final class AnalyticsChatUnavailable extends AnalyticsChatState {
  const AnalyticsChatUnavailable(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

final class AnalyticsChatReady extends AnalyticsChatState {
  const AnalyticsChatReady({
    required this.messages,
    this.sending = false,
  });

  final List<AiChatMessage> messages;
  final bool sending;

  @override
  List<Object?> get props => <Object?>[messages, sending];
}

final class AnalyticsChatFailure extends AnalyticsChatState {
  const AnalyticsChatFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
