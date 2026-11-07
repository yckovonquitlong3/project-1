import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/quick_entry_suggestion.dart';
import 'package:multi_wallet_tracker/features/ai/domain/services/ai_client.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

class HttpAiClient implements AiClient {
  HttpAiClient({
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _requestTimeout = timeout;

  static const String _systemPrompt = '''
You convert one personal-finance sentence into strict JSON.
Return ONLY a JSON object with exactly these keys:
{"amount_text":"500.00","transaction_type":"TRANSFER","wallet_name":"Maribank","target_wallet_name":"Pocket Money","category_name":null,"fee_text":"15.00","note":"withdrawal"}
Rules:
- amount_text is a string greater than zero with at most 2 decimals.
- transaction_type is EXPENSE, INCOME, or TRANSFER.
- wallet_name is the source wallet for every type.
- target_wallet_name is only for TRANSFER, otherwise null.
- category_name is only for EXPENSE or INCOME, otherwise null.
- fee_text is a string zero or greater with at most 2 decimals for TRANSFER, otherwise null.
- note is a short string or null.
- No markdown, no explanations, no extra keys.
''';

  final http.Client _client;
  final Duration _requestTimeout;

  @override
  Future<QuickEntrySuggestion> parseQuickEntry({
    required String text,
    required AiSettings settings,
    required String apiKey,
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'model': settings.model,
      'messages': <Map<String, String>>[
        <String, String>{'role': 'system', 'content': _systemPrompt},
        <String, String>{'role': 'user', 'content': text},
      ],
      'temperature': 0,
      'max_tokens': 300,
      'stream': false,
    };

    final http.Response response = await _post(
      settings: settings,
      apiKey: apiKey,
      body: body,
    );
    return _parseContent(response.body);
  }

  @override
  Future<void> testConnection({
    required AiSettings settings,
    required String apiKey,
  }) async {
    await _post(
      settings: settings,
      apiKey: apiKey,
      body: <String, Object?>{
        'model': settings.model,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'user', 'content': 'Reply with OK.'},
        ],
        'temperature': 0,
        'max_tokens': 5,
        'stream': false,
      },
    );
  }

  @override
  Future<AiChatResponse> chat({
    required List<AiChatMessage> messages,
    required List<AiToolDefinition> tools,
    required AiSettings settings,
    required String apiKey,
  }) async {
    final http.Response response = await _post(
      settings: settings,
      apiKey: apiKey,
      body: <String, Object?>{
        'model': settings.model,
        'messages': messages
            .map(_messageToJson)
            .toList(growable: false),
        'tools': tools.map((AiToolDefinition tool) => tool.toJson()).toList(
              growable: false,
            ),
        'tool_choice': 'auto',
        'temperature': 0.1,
        'max_tokens': 500,
        'stream': false,
      },
    );
    return _parseChatResponse(response.body);
  }

  Map<String, Object?> _messageToJson(AiChatMessage message) {
    switch (message.role) {
      case AiChatRole.system:
      case AiChatRole.user:
        return <String, Object?>{
          'role': message.role.name,
          'content': message.content ?? '',
        };
      case AiChatRole.assistant:
        return <String, Object?>{
          'role': 'assistant',
          'content': message.content,
          if (message.toolCalls.isNotEmpty)
            'tool_calls': message.toolCalls
                .map(
                  (AiToolCall call) => <String, Object?>{
                    'id': call.id,
                    'type': 'function',
                    'function': <String, Object?>{
                      'name': call.name,
                      'arguments': jsonEncode(call.arguments),
                    },
                  },
                )
                .toList(growable: false),
        };
      case AiChatRole.tool:
        return <String, Object?>{
          'role': 'tool',
          'tool_call_id': message.toolCallId,
          'content': message.content ?? '',
        };
    }
  }

  AiChatResponse _parseChatResponse(String responseBody) {
    try {
      final Object? decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not an object');
      }
      final Object? choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const FormatException('No choices in response');
      }
      final Object? rawMessage =
          (choices.first as Map<String, dynamic>)['message'];
      if (rawMessage is! Map<String, dynamic>) {
        throw const FormatException('No message in response');
      }

      final Object? rawContent = rawMessage['content'];
      if (rawContent != null && rawContent is! String) {
        throw const FormatException('Bad content');
      }

      final List<AiToolCall> calls = <AiToolCall>[];
      final Object? rawCalls = rawMessage['tool_calls'];
      if (rawCalls != null) {
        if (rawCalls is! List) {
          throw const FormatException('Bad tool calls');
        }
        for (final Object? item in rawCalls) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Bad tool call');
          }
          final Object? id = item['id'];
          final Object? function = item['function'];
          if (id is! String || function is! Map<String, dynamic>) {
            throw const FormatException('Bad tool call');
          }
          final Object? name = function['name'];
          final Object? arguments = function['arguments'];
          if (name is! String || arguments is! String) {
            throw const FormatException('Bad tool call');
          }
          final Object? parsedArguments = jsonDecode(arguments);
          if (parsedArguments is! Map<String, dynamic>) {
            throw const FormatException('Bad tool arguments');
          }
          calls.add(
            AiToolCall(
              id: id,
              name: name,
              arguments: Map<String, Object?>.from(parsedArguments),
            ),
          );
        }
      }

      final String? content =
          rawContent is String ? rawContent.trim() : null;
      if ((content == null || content.isEmpty) && calls.isEmpty) {
        throw const FormatException('Empty assistant response');
      }
      return AiChatResponse(content: content, toolCalls: calls);
    } on AiFailure {
      rethrow;
    } catch (error) {
      throw AiFailure(
        'The AI returned an unreadable chat response.',
        kind: AiFailureKind.invalidResponse,
        cause: error,
      );
    }
  }

  Future<http.Response> _post({
    required AiSettings settings,
    required String apiKey,
    required Map<String, Object?> body,
  }) async {
    final Uri uri = Uri.parse(settings.provider.endpoint);
    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final http.Response response = await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          return response;
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw AiFailure(
            '${settings.provider.label} rejected the API key. Make sure the '
            'Provider matches your key (DeepSeek or OpenAI), then paste the '
            'secret value again.',
            kind: AiFailureKind.auth,
          );
        }
        if (response.statusCode == 429) {
          throw const AiFailure(
            'The provider is rate-limiting requests. Try again shortly.',
            kind: AiFailureKind.rateLimit,
          );
        }
        if (response.statusCode >= 500 && attempt == 0) {
          continue;
        }
        throw AiFailure(
          'The provider returned an error (${response.statusCode}).',
          kind: AiFailureKind.unknown,
        );
      } on TimeoutException catch (error) {
        throw AiFailure(
          'The AI request timed out. Try again or enter it manually.',
          kind: AiFailureKind.timeout,
          cause: error,
        );
      } on SocketException catch (error) {
        if (attempt == 0) {
          continue;
        }
        throw AiFailure(
          'No internet connection. Opening manual entry.',
          kind: AiFailureKind.network,
          cause: error,
        );
      } on http.ClientException catch (error) {
        if (attempt == 0) {
          continue;
        }
        throw AiFailure(
          'Could not reach the AI provider. Opening manual entry.',
          kind: AiFailureKind.network,
          cause: error,
        );
      }
    }

    throw const AiFailure(
      'Could not reach the AI provider. Opening manual entry.',
      kind: AiFailureKind.network,
    );
  }

  QuickEntrySuggestion _parseContent(String responseBody) {
    try {
      final Object? decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not an object');
      }
      final Object? choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const FormatException('No choices in response');
      }
      final Object? message = (choices.first as Map<String, dynamic>)['message'];
      if (message is! Map<String, dynamic>) {
        throw const FormatException('No message in response');
      }
      final Object? content = message['content'];
      if (content is! String) {
        throw const FormatException('No content in response');
      }

      String raw = content.trim();
      if (raw.startsWith('```')) {
        raw = raw
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim();
      }
      final Object? parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Content is not an object');
      }

      const Set<String> allowed = <String>{
        'amount_text',
        'transaction_type',
        'wallet_name',
        'target_wallet_name',
        'category_name',
        'fee_text',
        'note',
      };
      if (parsed.keys.any((String key) => !allowed.contains(key))) {
        throw const FormatException('Unexpected keys');
      }

      final Object? amountText = parsed['amount_text'];
      final Object? typeText = parsed['transaction_type'];
      if (amountText is! String || typeText is! String) {
        throw const FormatException('Missing amount or type');
      }
      final String normalizedType = typeText.trim().toUpperCase();
      final TransactionType type;
      if (normalizedType == 'EXPENSE') {
        type = TransactionType.expense;
      } else if (normalizedType == 'INCOME') {
        type = TransactionType.income;
      } else if (normalizedType == 'TRANSFER') {
        type = TransactionType.transfer;
      } else {
        throw const FormatException('Unsupported transaction type');
      }

      final Object? walletName = parsed['wallet_name'];
      final Object? targetWalletName = parsed['target_wallet_name'];
      final Object? categoryName = parsed['category_name'];
      final Object? feeText = parsed['fee_text'];
      final Object? note = parsed['note'];
      if (walletName != null && walletName is! String) {
        throw const FormatException('Bad wallet name');
      }
      if (targetWalletName != null && targetWalletName is! String) {
        throw const FormatException('Bad target wallet name');
      }
      if (categoryName != null && categoryName is! String) {
        throw const FormatException('Bad category name');
      }
      if (feeText != null && feeText is! String) {
        throw const FormatException('Bad fee');
      }
      if (note != null && note is! String) {
        throw const FormatException('Bad note');
      }

      final bool isTransfer = type == TransactionType.transfer;
      final String? trimmedWallet =
          walletName is String && walletName.trim().isNotEmpty
              ? walletName.trim()
              : null;
      final String? trimmedTarget =
          isTransfer && targetWalletName is String &&
                  targetWalletName.trim().isNotEmpty
              ? targetWalletName.trim()
              : null;
      final String? trimmedCategory =
          !isTransfer && categoryName is String &&
                  categoryName.trim().isNotEmpty
              ? categoryName.trim()
              : null;
      final String? trimmedFee =
          isTransfer && feeText is String && feeText.trim().isNotEmpty
              ? feeText.trim()
              : null;
      final String? trimmedNote = note is String && note.trim().isNotEmpty
          ? (note.trim().length <= 200
              ? note.trim()
              : note.trim().substring(0, 200))
          : null;

      return QuickEntrySuggestion(
        amountText: amountText.trim(),
        type: type,
        walletName: trimmedWallet,
        targetWalletName: trimmedTarget,
        categoryName: trimmedCategory,
        feeText: trimmedFee,
        note: trimmedNote,
      );
    } on AiFailure {
      rethrow;
    } catch (error) {
      throw AiFailure(
        'The AI returned an unreadable answer. Opening manual entry.',
        kind: AiFailureKind.invalidResponse,
        cause: error,
      );
    }
  }
}
