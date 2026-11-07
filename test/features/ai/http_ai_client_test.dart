import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:multi_wallet_tracker/features/ai/data/client/http_ai_client.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/quick_entry_suggestion.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

http.Response chatResponse(String content) {
  return http.Response(
    jsonEncode(<String, Object?>{
      'choices': <Object?>[
        <String, Object?>{
          'message': <String, Object?>{'content': content},
        },
      ],
    }),
    200,
  );
}

String suggestionJson() => jsonEncode(<String, Object?>{
      'amount_text': '150.00',
      'transaction_type': 'EXPENSE',
      'wallet_name': 'GCash',
      'category_name': 'Food & Dining',
      'note': 'iced coffee',
    });

void main() {
  const AiSettings settings = AiSettings(
    mode: AiMode.byok,
    model: 'gpt-test',
  );

  test('sends a direct provider request and parses strict JSON', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient((http.Request request) async {
        expect(
          request.url.toString(),
          'https://api.openai.com/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer sk-test');
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-test');
        final List<dynamic> messages = body['messages'] as List<dynamic>;
        expect(
          (messages[1] as Map<String, dynamic>)['content'],
          'Spent 150 on groceries via GCash',
        );
        return chatResponse(suggestionJson());
      }),
    );

    final QuickEntrySuggestion suggestion = await client.parseQuickEntry(
      text: 'Spent 150 on groceries via GCash',
      settings: settings,
      apiKey: 'sk-test',
    );

    expect(suggestion.amountText, '150.00');
    expect(suggestion.type, TransactionType.expense);
    expect(suggestion.walletName, 'GCash');
    expect(suggestion.categoryName, 'Food & Dining');
    expect(suggestion.note, 'iced coffee');
  });

  test('accepts JSON inside code fences', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient(
        (http.Request request) async =>
            chatResponse('```json\n${suggestionJson()}\n```'),
      ),
    );

    final QuickEntrySuggestion suggestion = await client.parseQuickEntry(
      text: 'coffee',
      settings: settings,
      apiKey: 'k',
    );
    expect(suggestion.amountText, '150.00');
  });

  test('rejects malformed JSON as an invalid response', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient(
        (http.Request request) async => chatResponse('not json'),
      ),
    );

    await expectLater(
      client.parseQuickEntry(text: 'coffee', settings: settings, apiKey: 'k'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('rejects extra keys and unsupported transaction types', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient((http.Request request) async {
        return chatResponse(
          jsonEncode(<String, Object?>{
            'amount_text': '10.00',
            'transaction_type': 'TRANSFER',
            'wallet_name': 'GCash',
            'category_name': null,
            'note': null,
          }),
        );
      }),
    );

    await expectLater(
      client.parseQuickEntry(text: 'move 10', settings: settings, apiKey: 'k'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('maps 401 to an auth failure without retrying', () async {
    var calls = 0;
    final HttpAiClient client = HttpAiClient(
      client: MockClient((http.Request request) async {
        calls++;
        return http.Response('unauthorized', 401);
      }),
    );

    await expectLater(
      client.parseQuickEntry(text: 'coffee', settings: settings, apiKey: 'bad'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.auth,
        ),
      ),
    );
    expect(calls, 1);
  });

  test('retries once on a 5xx response', () async {
    var calls = 0;
    final HttpAiClient client = HttpAiClient(
      client: MockClient((http.Request request) async {
        calls++;
        if (calls == 1) {
          return http.Response('temporary', 503);
        }
        return chatResponse(suggestionJson());
      }),
    );

    final QuickEntrySuggestion suggestion = await client.parseQuickEntry(
      text: 'coffee',
      settings: settings,
      apiKey: 'k',
    );
    expect(suggestion.amountText, '150.00');
    expect(calls, 2);
  });

  test('maps 429 to a rate-limit failure', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient(
        (http.Request request) async => http.Response('slow down', 429),
      ),
    );

    await expectLater(
      client.parseQuickEntry(text: 'coffee', settings: settings, apiKey: 'k'),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure failure) => failure.kind,
          'kind',
          AiFailureKind.rateLimit,
        ),
      ),
    );
  });

  test('tests a connection with the same provider', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient((http.Request request) async {
        expect(request.headers['Authorization'], 'Bearer k');
        return chatResponse('OK');
      }),
    );

    await client.testConnection(settings: settings, apiKey: 'k');
  });
}
