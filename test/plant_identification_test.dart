import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plant_scan/models/plant_identification.dart';
import 'package:plant_scan/services/claude_plant_identifier.dart';
import 'package:plant_scan/services/plant_identifier.dart';

/// Wraps text the way the messages API does.
http.Response reply(String text, [int status = 200]) => http.Response(
  jsonEncode({
    'content': [
      {'type': 'text', 'text': text},
    ],
  }),
  status,
);

void main() {
  group('PlantIdentification.fromJson', () {
    test('reads the model shape, including nested care advice', () {
      final result = PlantIdentification.fromJson({
        'is_plant': true,
        'common_name': 'Snake plant',
        'scientific_name': 'Dracaena trifasciata',
        'confidence': 0.8,
        'health': 'minor_issues',
        'care': {'light': 'Low to bright', 'water': 'Let it dry out'},
        'alternate_matches': ['Dracaena angolensis', ''],
        'toxic_to_pets': true,
      });

      expect(result.commonName, 'Snake plant');
      expect(result.health, PlantHealth.minorIssues);
      expect(result.care.map((fact) => fact.label), ['Light', 'Water']);
      expect(result.care.first.kind, CareKind.light);
      expect(result.alternateMatches, ['Dracaena angolensis']);
      expect(result.toxicToPets, isTrue);
    });

    test('accepts confidence given as a percentage and clamps it', () {
      expect(PlantIdentification.fromJson({'confidence': 86}).confidence, 0.86);
      expect(PlantIdentification.fromJson({'confidence': 400}).confidence, 1.0);
      expect(PlantIdentification.fromJson({'confidence': 'x'}).confidence, 0.0);
    });

    test('survives missing fields', () {
      final result = PlantIdentification.fromJson({});
      expect(result.commonName, 'Unknown plant');
      expect(result.health, PlantHealth.unknown);
      expect(result.care, isEmpty);
    });

    test('round-trips through its own stored shape', () {
      final original = PlantIdentification.fromJson({
        'is_plant': true,
        'common_name': 'Common ivy',
        'confidence': 0.62,
        'health': 'needs_attention',
        'care': {'light': 'Bright indirect'},
        'health_notes': ['Pale mottling'],
      });

      final restored = PlantIdentification.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );

      expect(restored.commonName, original.commonName);
      expect(restored.confidence, original.confidence);
      expect(restored.health, original.health);
      expect(restored.care.single.label, 'Light');
      expect(restored.healthNotes, ['Pale mottling']);
    });
  });

  group('ClaudePlantIdentifier', () {
    final photo = Uint8List.fromList([1, 2, 3]);

    ClaudePlantIdentifier identifierReturning(http.Response response) =>
        ClaudePlantIdentifier(
          apiKey: 'test-key',
          client: MockClient((_) async => response),
        );

    test('pulls JSON out of a fenced reply', () async {
      final identifier = identifierReturning(
        reply('Here you go:\n```json\n{"common_name": "Fern"}\n```'),
      );

      final result = await identifier.identify(photo);
      expect(result.commonName, 'Fern');
    });

    test('reports a not-a-plant reply', () async {
      final identifier = identifierReturning(reply('{"is_plant": false}'));
      expect((await identifier.identify(photo)).isPlant, isFalse);
    });

    test('marks a rejected key as not retryable', () async {
      final identifier = identifierReturning(reply('nope', 401));

      await expectLater(
        identifier.identify(photo),
        throwsA(
          isA<IdentificationException>().having(
            (error) => error.isRetryable,
            'isRetryable',
            isFalse,
          ),
        ),
      );
    });

    test('explains an unparseable reply', () async {
      final identifier = identifierReturning(reply('I cannot tell.'));

      await expectLater(
        identifier.identify(photo),
        throwsA(isA<IdentificationException>()),
      );
    });

    test('sends the photo as base64 with the version header', () async {
      String? sentBody;
      Map<String, String>? sentHeaders;

      final identifier = ClaudePlantIdentifier(
        apiKey: 'test-key',
        client: MockClient((request) async {
          sentBody = request.body;
          sentHeaders = request.headers;
          return reply('{"common_name": "Fern"}');
        }),
      );

      await identifier.identify(photo);

      expect(sentHeaders?['anthropic-version'], '2023-06-01');
      expect(sentHeaders?['x-api-key'], 'test-key');
      expect(sentBody, contains(base64Encode(photo)));
    });
  });
}
