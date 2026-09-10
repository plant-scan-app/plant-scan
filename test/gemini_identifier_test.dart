import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plant_scan/services/gemini_plant_identifier.dart';
import 'package:plant_scan/services/plant_identifier.dart';

/// Wraps text the way generateContent does.
http.Response reply(String text, {String finishReason = 'STOP'}) =>
    http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': text},
              ],
            },
            'finishReason': finishReason,
          },
        ],
      }),
      200,
    );

void main() {
  final photo = Uint8List.fromList([9, 8, 7]);

  GeminiPlantIdentifier identifierReturning(http.Response response) =>
      GeminiPlantIdentifier(
        apiKey: 'test-key',
        client: MockClient((_) async => response),
      );

  test('reads a bare JSON reply', () async {
    final identifier = identifierReturning(
      reply('{"common_name": "Bird of paradise", "confidence": 0.77}'),
    );

    final result = await identifier.identify(photo);
    expect(result.commonName, 'Bird of paradise');
    expect(result.confidence, closeTo(0.77, 0.001));
  });

  test('still copes when the model adds fences', () async {
    final identifier = identifierReturning(
      reply('```json\n{"common_name": "Aloe vera"}\n```'),
    );

    expect((await identifier.identify(photo)).commonName, 'Aloe vera');
  });

  test('sends the key as a header and the photo inline', () async {
    Uri? sentUri;
    String? sentBody;
    Map<String, String>? sentHeaders;

    final identifier = GeminiPlantIdentifier(
      apiKey: 'test-key',
      client: MockClient((request) async {
        sentUri = request.url;
        sentBody = request.body;
        sentHeaders = request.headers;
        return reply('{"common_name": "Aloe vera"}');
      }),
    );

    await identifier.identify(photo);

    expect(sentHeaders?['x-goog-api-key'], 'test-key');
    // Under the VM kIsWeb is false, so the key must travel as a header only.
    expect(sentUri?.queryParameters['key'], isNull);
    expect(sentUri?.path, endsWith(':generateContent'));
    expect(sentBody, contains(base64Encode(photo)));
  });

  test('names the model when it is not available to the key', () async {
    final identifier = GeminiPlantIdentifier(
      apiKey: 'test-key',
      model: 'gemini-does-not-exist',
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"message":"This model is no longer available"}}',
          404,
        ),
      ),
    );

    await expectLater(
      identifier.identify(photo),
      throwsA(
        isA<IdentificationException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('gemini-does-not-exist'),
            // Google's own wording is passed through, since a retirement
            // notice names the replacement model.
            contains('no longer available'),
          ),
        ),
      ),
    );
  });

  test('treats a rate limit as retryable and a bad key as not', () async {
    Future<IdentificationException> failWith(int status) async {
      try {
        await identifierReturning(http.Response('{}', status)).identify(photo);
      } on IdentificationException catch (error) {
        return error;
      }
      fail('expected a failure for HTTP $status');
    }

    expect((await failWith(429)).isRetryable, isTrue);
    expect((await failWith(400)).isRetryable, isFalse);
  });

  test('retries a 503 and succeeds on a later attempt', () async {
    var calls = 0;

    final identifier = GeminiPlantIdentifier(
      apiKey: 'test-key',
      client: MockClient((_) async {
        calls++;
        return calls < 3
            ? http.Response('{}', 503)
            : reply('{"common_name": "Aloe vera"}');
      }),
    );

    final result = await identifier.identify(photo);
    expect(calls, 3);
    expect(result.commonName, 'Aloe vera');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('gives up on 503 after the attempt limit and names the model', () async {
    var calls = 0;

    final identifier = GeminiPlantIdentifier(
      apiKey: 'test-key',
      model: 'gemini-3.8-flash',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 503);
      }),
    );

    await expectLater(
      identifier.identify(photo),
      throwsA(
        isA<IdentificationException>().having(
          (error) => error.message,
          'message',
          allOf(contains('gemini-3.8-flash'), contains('overloaded')),
        ),
      ),
    );
    expect(calls, GeminiPlantIdentifier.maxAttempts);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('explains a blocked photo', () async {
    final identifier = identifierReturning(
      http.Response(
        jsonEncode({
          'promptFeedback': {'blockReason': 'SAFETY'},
        }),
        200,
      ),
    );

    await expectLater(
      identifier.identify(photo),
      throwsA(
        isA<IdentificationException>().having(
          (error) => error.message,
          'message',
          contains('refused'),
        ),
      ),
    );
  });

  test('reports a truncated reply', () async {
    final identifier = identifierReturning(
      reply('{"common_name": "Aloe', finishReason: 'MAX_TOKENS'),
    );

    await expectLater(
      identifier.identify(photo),
      throwsA(isA<IdentificationException>()),
    );
  });
}
