import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/plant_identification.dart';
import 'plant_identifier.dart';

/// Sends the photo to a Claude vision model and parses the JSON reply.
///
/// Two ways to wire this up:
///
///  * `endpoint` left alone + `apiKey` set — talks straight to the Anthropic
///    API. Fine for development, but the key ships inside the app bundle and
///    can be extracted, so don't release it this way.
///  * `endpoint` pointed at your own server + `apiKey` null — your server
///    holds the key, does the rate limiting, and forwards the request. This is
///    the shape you want in production.
class ClaudePlantIdentifier implements PlantIdentifier {
  ClaudePlantIdentifier({
    this.apiKey,
    this.endpoint = defaultEndpoint,
    this.model = defaultModel,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String defaultEndpoint = 'https://api.anthropic.com/v1/messages';
  static const String defaultModel = 'claude-sonnet-5';
  static const Duration timeout = Duration(seconds: 45);

  final String? apiKey;
  final String endpoint;
  final String model;
  final http.Client _client;

  @override
  Future<PlantIdentification> identify(Uint8List jpegBytes) async {
    final payload = jsonEncode({
      'model': model,
      'max_tokens': 1400,
      'system': kIdentifierSystemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Encode(jpegBytes),
              },
            },
            {'type': 'text', 'text': 'Identify this plant.'},
          ],
        },
      ],
    });

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'content-type': 'application/json',
              if (apiKey != null) ...{
                'x-api-key': apiKey!,
                'anthropic-version': '2023-06-01',
              },
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

    _throwForStatus(response);
    return PlantIdentification.fromJson(_decodeReply(response.body));
  }

  void _throwForStatus(http.Response response) {
    if (response.statusCode == 200) return;

    final message = switch (response.statusCode) {
      401 || 403 =>
        'The API key was rejected. Check the key this build was compiled with.',
      429 =>
        'Too many scans just now. Wait a moment and try again.',
      >= 500 => 'The identification service is down. Try again shortly.',
      _ => 'Identification failed (HTTP ${response.statusCode}).',
    };

    throw IdentificationException(
      message,
      isRetryable: response.statusCode != 401 && response.statusCode != 403,
    );
  }

  /// Pulls the JSON object out of the model's text blocks. Models sometimes
  /// wrap it in fences or add a sentence in front, so we take the outermost
  /// braces rather than trusting the whole string to parse.
  Map<String, Object?> _decodeReply(String body) {
    final Map<String, Object?> envelope;
    try {
      envelope = jsonDecode(body) as Map<String, Object?>;
    } catch (_) {
      throw const IdentificationException('Unreadable reply from the service.');
    }

    final blocks = envelope['content'];
    final text = (blocks is List ? blocks : const [])
        .whereType<Map>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text']?.toString() ?? '')
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
