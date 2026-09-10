import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/plant_identification.dart';
import 'plant_identifier.dart';

/// Sends the photo to Google's Gemini API and parses the JSON reply.
///
/// Uses the same prompt contract as the other backends, so the parser and the
/// UI are unchanged. `responseMimeType: application/json` asks the model to
/// return bare JSON, which it usually honours — the tolerant extraction below
/// is there for the times it doesn't.
///
/// Model names on this API change often. If a request comes back 404, list
/// what your key can reach:
///
///   curl -H "x-goog-api-key: $KEY" \
///     https://generativelanguage.googleapis.com/v1beta/models
class GeminiPlantIdentifier implements PlantIdentifier {
  GeminiPlantIdentifier({
    required this.apiKey,
    this.model = defaultModel,
    this.baseUrl = defaultBaseUrl,
    http.Client? client,
  }) : _proxied = false,
       _client = client ?? http.Client();

  /// Talks to your own server instead, which holds the key. The server is
  /// expected to accept this class's request body and return Gemini's
  /// response shape untouched.
  GeminiPlantIdentifier.throughProxy({
    required String endpoint,
    http.Client? client,
  }) : apiKey = null,
       model = '',
       baseUrl = endpoint,
       _proxied = true,
       _client = client ?? http.Client();

  static const String defaultBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String defaultModel = 'gemini-3.6-flash';
  static const Duration timeout = Duration(seconds: 45);

  /// A busy or overloaded model answers 503, which is common on the free tier
  /// and on newly released models. Retrying usually clears it, so the user
  /// never sees it.
  static const int maxAttempts = 3;

  final String? apiKey;
  final String model;
  final String baseUrl;
  final http.Client _client;
  final bool _proxied;

  Uri get _endpoint => Uri.parse(
    _proxied ? baseUrl : '$baseUrl/models/$model:generateContent',
  );

  @override
  Future<PlantIdentification> identify(Uint8List jpegBytes) async {
    final payload = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': kIdentifierSystemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Encode(jpegBytes),
              },
            },
            {'text': 'Identify this plant.'},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        // Generous, because thinking models spend part of this budget on
        // reasoning before they emit any JSON. Too low and the reply arrives
        // truncated with finishReason MAX_TOKENS.
        'maxOutputTokens': 3000,
        // Low but not zero: identification should be stable across retries.
        'temperature': 0.2,
      },
    });

    for (var attempt = 1; ; attempt++) {
      final response = await _send(payload);

      // Back off and try again rather than bothering the user: 1s, then 2s.
      if (response.statusCode == 503 && attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
        continue;
      }

      _throwForStatus(response, attempts: attempt);
      return PlantIdentification.fromJson(_decodeReply(response.body));
    }
  }

  Future<http.Response> _send(String payload) async {
    try {
      return await _client
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              // Passed as a header rather than a ?key= query parameter, which
              // would end up in server logs and crash reports.
              if (apiKey != null) 'x-goog-api-key': apiKey!,
            },
            body: payload,
          )
          .timeout(timeout);
    } on SocketException {
      throw const IdentificationException(
        'No connection. Reconnect and scan again.',
      );
    } on http.ClientException {
      throw const IdentificationException(
        'The request was interrupted. Scan again.',
      );
    } catch (_) {
      throw const IdentificationException(
        'That took too long. Scan again on a stronger connection.',
      );
    }
  }

  void _throwForStatus(http.Response response, {int attempts = 1}) {
    if (response.statusCode == 200) return;

    final message = switch (response.statusCode) {
      400 =>
        'The request was rejected. Usually an invalid API key — check the key '
            'this build was compiled with.',
      403 => 'This API key is not allowed to use that model.',
      404 =>
        'Model "$model" is unavailable: ${_serverMessage(response) ?? 'not '
            'found for this key'}.',
      429 =>
        'The free tier limit is reached. Wait a minute and scan again.',
      503 when attempts > 1 =>
        'Model "$model" is overloaded — $attempts attempts failed. Newly '
            'released models run out of capacity often; try another one.',
      >= 500 => 'Google\'s service is busy or down. Try again shortly.',
      _ => 'Identification failed (HTTP ${response.statusCode}).',
    };

    throw IdentificationException(
      message,
      isRetryable: response.statusCode != 400 && response.statusCode != 403,
    );
  }

  /// Google explains itself in the response body, including naming the
  /// replacement when a model has been retired. Worth surfacing verbatim.
  String? _serverMessage(http.Response response) {
    try {
      final error = (jsonDecode(response.body) as Map)['error'];
      final message = (error as Map?)?['message']?.toString().trim();
      return (message == null || message.isEmpty) ? null : message;
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _decodeReply(String body) {
    final Map<String, Object?> envelope;
    try {
      envelope = jsonDecode(body) as Map<String, Object?>;
    } catch (_) {
      throw const IdentificationException('Unreadable reply from the service.');
    }

    final candidates = envelope['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      // A blocked prompt comes back with no candidates and a reason.
      final blocked =
          (envelope['promptFeedback'] as Map?)?['blockReason']?.toString();
      throw IdentificationException(
        blocked == null
            ? 'The service returned nothing. Scan again.'
            : 'That photo was refused by the service. Try a different shot.',
      );
    }

    final candidate = (candidates.first as Map).cast<String, Object?>();
    if (candidate['finishReason'] == 'MAX_TOKENS') {
      throw const IdentificationException(
        'The reply was cut short. Scan again.',
      );
    }

    final parts = (candidate['content'] as Map?)?['parts'];
    final text = (parts is List ? parts : const [])
        .whereType<Map>()
        // Thinking models return their reasoning as extra parts. Splicing
        // those into the answer would corrupt the JSON.
        .where((part) => part['thought'] != true)
        .map((part) => part['text']?.toString() ?? '')
        .join('\n');

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) {
      throw const IdentificationException(
        'Could not read the identification. Scan again.',
      );
    }

    try {
      return jsonDecode(text.substring(start, end + 1)) as Map<String, Object?>;
    } catch (_) {
      throw const IdentificationException(
        'Could not read the identification. Scan again.',
      );
    }
  }
}
