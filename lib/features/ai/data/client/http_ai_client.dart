import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
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
{"amount_text":"150.00","transaction_type":"EXPENSE","wallet_name":"GCash","category_name":"Food & Dining","note":"iced coffee"}
Rules:
- amount_text is a string greater than zero with at most 2 decimals.
- transaction_type is EXPENSE or INCOME.
- wallet_name and category_name are short names from the sentence, or null.
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
          throw const AiFailure(
            'The API key was rejected. Check it in AI settings.',
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
        'category_name',
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
      } else {
        throw const FormatException('Unsupported transaction type');
      }

      final Object? walletName = parsed['wallet_name'];
      final Object? categoryName = parsed['category_name'];
      final Object? note = parsed['note'];
      if (walletName != null && walletName is! String) {
        throw const FormatException('Bad wallet name');
      }
      if (categoryName != null && categoryName is! String) {
        throw const FormatException('Bad category name');
      }
      if (note != null && note is! String) {
        throw const FormatException('Bad note');
      }

      final String? trimmedWallet =
          walletName is String && walletName.trim().isNotEmpty
              ? walletName.trim()
              : null;
      final String? trimmedCategory =
          categoryName is String && categoryName.trim().isNotEmpty
              ? categoryName.trim()
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
        categoryName: trimmedCategory,
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
