import 'dart:typed_data';

import '../models/plant_identification.dart';

/// Anything that can turn a JPEG of a plant into an identification.
///
/// Swapping the backend (a vision model, Plant.id, PlantNet, an on-device
/// TFLite classifier) means writing one more implementation of this — no
/// screen touches the network directly.
abstract interface class PlantIdentifier {
  Future<PlantIdentification> identify(Uint8List jpegBytes);
}

/// Raised for anything the user needs to hear about: no network, bad key,
/// rate limits, a reply we could not read.
class IdentificationException implements Exception {
  const IdentificationException(this.message, {this.isRetryable = true});

  final String message;
  final bool isRetryable;

  @override
  String toString() => 'IdentificationException: $message';
}

/// The instruction set both the direct and proxied backends use. Kept here so
/// the two stay in step, and so the JSON contract lives next to the parser
/// that reads it.
const String kIdentifierSystemPrompt = '''
You identify plants from photographs for a phone app.

Reply with a single JSON object and nothing else — no prose, no markdown fences.

Use this shape:
{
  "is_plant": true,
  "common_name": "Swiss cheese plant",
  "scientific_name": "Monstera deliciosa",
  "confidence": 0.86,
  "summary": "Two or three sentences on what this plant is and how to recognise it.",
  "health": "healthy" | "minor_issues" | "needs_attention" | "unknown",
  "health_notes": ["Short observations about what you can see in this photo"],
  "care": {
    "light": "...",
    "water": "...",
    "soil": "...",
    "humidity": "...",
    "temperature": "...",
    "fertilizer": "..."
  },
  "alternate_matches": ["Other species this could be, most likely first"],
  "toxic_to_pets": true
}

Rules:
- If the photo shows no plant, reply exactly {"is_plant": false} and stop.
- "confidence" is your own honest estimate from 0 to 1. A blurry photo, a
  bare stem, or a genus with near-identical species should score low.
- Name the genus alone when you cannot pin the species, and say so in the summary.
- "health_notes" describes only what is visible. Do not speculate about roots
  or history you cannot see. Use an empty list if the photo does not show enough.
- Care advice is for a temperate indoor or garden setting unless the photo
  clearly shows otherwise. Keep each field to one short sentence.
- Never identify a plant as safe to eat, and do not give foraging or medicinal
  advice. If the photo looks like a foraging question, still fill in the fields
  above and note in the summary that identification from a photo is not
  reliable enough to eat by.
''';
