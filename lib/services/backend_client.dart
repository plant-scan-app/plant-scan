import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/plant_identification.dart';
import '../models/quota.dart';
import 'device_identity.dart';
import 'plant_identifier.dart';

/// Thrown when the day's scans are used up. Carries the quota so the UI can
/// offer the right next step — a rewarded ad, or the paywall.
class QuotaExhaustedException implements Exception {
  const QuotaExhaustedException(this.quota);

  final Quota quota;
}

/// Talks to the Worker in `server/`. The Gemini key lives there, not here, so
/// pulling this app apart yields nothing worth having.
class BackendClient {
  BackendClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  static const Duration timeout = Duration(seconds: 60);

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, String>> _headers() async => {
    'content-type': 'application/json',
    'x-device-id': await DeviceIdentity.instance.id(),
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Quota> quota() async {
    final response = await _get('/v1/quota');
    return _quotaFrom(response);
  }

  /// Identifies a photo and returns the updated quota alongside it.
  Future<({PlantIdentification identification, Quota quota})> identify(
    Uint8List jpegBytes,
  ) async {
    final response = await _post('/v1/identify', {
      'image_base64': base64Encode(jpegBytes),
      'mime_type': 'image/jpeg',
    });

    final body = _decode(response);

    if (response.statusCode == 429) {
      throw QuotaExhaustedException(
        Quota.fromJson((body['quota'] as Map?)?.cast<String, Object?>() ?? {}),
      );
    }

    if (response.statusCode != 200) {
      throw IdentificationException(
        (body['message'] as String?) ??
            switch (response.statusCode) {
              400 => 'That photo could not be read. Try another.',
              502 => 'The identification service failed. Scan again.',
              _ => 'Identification failed (HTTP ${response.statusCode}).',
            },
        isRetryable: body['retryable'] != false,
      );
    }

    return (
      identification: PlantIdentification.fromJson(
        (body['identification'] as Map?)?.cast<String, Object?>() ?? {},
      ),
      quota: _quotaFrom(response),
    );
  }

  /// Called after a rewarded ad has actually been watched to completion.
  /// The server decides whether to grant anything, and caps it per day.
  Future<Quota> claimAdCredit() async {
    final response = await _post('/v1/ad-credit', const {});
    if (response.statusCode == 429) {
      throw const IdentificationException(
        'You have already claimed extra scans today.',
        isRetryable: false,
      );
    }
    return _quotaFrom(response);
  }

  /// Hands a Play purchase token to the server, which verifies it with Google
  /// before granting anything.
  Future<Quota> submitPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final response = await _post('/v1/subscription', {
      'purchase_token': purchaseToken,
      'product_id': productId,
    });

    if (response.statusCode == 402) {
      throw const IdentificationException(
        'Google could not confirm that subscription yet. Try again shortly.',
      );
    }
    return _quotaFrom(response);
  }

  Future<http.Response> _get(String path) async {
    try {
      return await _client
          .get(_uri(path), headers: await _headers())
          .timeout(timeout);
    } on SocketException {
      throw const IdentificationException('No connection.');
    } catch (_) {
      throw const IdentificationException('The server did not respond.');
    }
  }

  Future<http.Response> _post(String path, Map<String, Object?> body) async {
    try {
      return await _client
          .post(_uri(path), headers: await _headers(), body: jsonEncode(body))
          .timeout(timeout);
    } on SocketException {
      throw const IdentificationException(
        'No connection. Reconnect and try again.',
      );
    } catch (_) {
      throw const IdentificationException(
        'That took too long. Try again on a stronger connection.',
      );
    }
  }

  Map<String, Object?> _decode(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map).cast<String, Object?>();
    } catch (_) {
      return const {};
    }
  }

  Quota _quotaFrom(http.Response response) {
    final body = _decode(response);
    final quota = (body['quota'] as Map?)?.cast<String, Object?>();
    if (quota == null) {
      throw const IdentificationException('The server sent an unusable reply.');
    }
    return Quota.fromJson(quota);
  }
}
