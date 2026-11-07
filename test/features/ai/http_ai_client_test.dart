import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:multi_wallet_tracker/features/ai/data/client/http_ai_client.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/quick_entry_suggestion.dart';
import 'package:multi_wallet_tracker/features/ai/domain/tools/analytics_tools.dart';
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

  test('parses a transfer with a target wallet and fee', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient(
        (http.Request request) async => chatResponse(
          jsonEncode(<String, Object?>{
            'amount_text': '500.00',
            'transaction_type': 'TRANSFER',
            'wallet_name': 'Maribank',
            'target_wallet_name': 'Pocket Money',
            'category_name': null,
            'fee_text': '15.00',
            'note': 'withdrawal',
          }),
        ),
      ),
    );

    final QuickEntrySuggestion suggestion = await client.parseQuickEntry(
      text: 'I withdrew 500 from Maribank to Pocket Money with a 15 fee',
      settings: settings,
      apiKey: 'k',
    );

    expect(suggestion.type, TransactionType.transfer);
    expect(suggestion.walletName, 'Maribank');
    expect(suggestion.targetWalletName, 'Pocket Money');
    expect(suggestion.feeText, '15.00');
    expect(suggestion.categoryName, isNull);
  });

  test('accepts JSON inside code fences', () async {    final HttpAiClient client = HttpAiClient(
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

  test('rejects unsupported transaction types', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient((http.Request request) async {
        return chatResponse(
          jsonEncode(<String, Object?>{
            'amount_text': '10.00',
            'transaction_type': 'REFUND',
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

  test('sends tools and parses a tool call from chat', () async {
    final HttpAiClient client = HttpAiClient(
      client: MockClient((http.Request request) async {
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['tool_choice'], 'auto');
        expect(body['messages'], isNotEmpty);
        final List<dynamic> tools = body['tools'] as List<dynamic>;
        expect(
          tools.any(
            (dynamic tool) =>
                (tool as Map<String, dynamic>)['function']['name'] ==
                'get_wallet_balances',
          ),
          isTrue,
        );
        return http.Response(
          jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{
                  'content': null,
                  'tool_calls': <Object?>[
                    <String, Object?>{
                      'id': 'call-1',
                      'type': 'function',
                      'function': <String, Object?>{
                        'name': 'get_wallet_balances',
                        'arguments': '{}',
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final AiChatResponse response = await client.chat(
      messages: <AiChatMessage>[
        const AiChatMessage(role: AiChatRole.system, content: 'system'),
        const AiChatMessage(
          role: AiChatRole.user,
          content: 'What are my balances?',
        ),
      ],
      tools: AnalyticsTools.definitions,
      settings: settings,
      apiKey: 'k',
    );

    expect(response.content, isNull);
    expect(response.toolCalls.length, 1);
    expect(response.toolCalls.single.id, 'call-1');
    expect(response.toolCalls.single.name, 'get_wallet_balances');
    expect(response.toolCalls.single.arguments, isEmpty);
  });
}
