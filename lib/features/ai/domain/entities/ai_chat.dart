import 'package:equatable/equatable.dart';

enum AiChatRole { system, user, assistant, tool }

class AiToolDefinition extends Equatable {
  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'function',
        'function': <String, Object?>{
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };

  @override
  List<Object?> get props => <Object?>[name, description, parameters];
}

class AiToolCall extends Equatable {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;

  @override
  List<Object?> get props => <Object?>[id, name, arguments];
}

class AiChatMessage extends Equatable {
  const AiChatMessage({
    required this.role,
    this.content,
    this.toolCalls = const <AiToolCall>[],
    this.toolCallId,
    this.name,
  });

  final AiChatRole role;
  final String? content;
  final List<AiToolCall> toolCalls;
  final String? toolCallId;
  final String? name;

  @override
  List<Object?> get props => <Object?>[
        role,
        content,
        toolCalls,
        toolCallId,
        name,
      ];
}

class AiChatResponse extends Equatable {
  const AiChatResponse({
    this.content,
    this.toolCalls = const <AiToolCall>[],
  });

  final String? content;
  final List<AiToolCall> toolCalls;

  bool get hasToolCalls => toolCalls.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[content, toolCalls];
}
