/// How the plant looked in the photo. Deliberately coarse — a photo cannot
/// support a finer diagnosis than this.
enum PlantHealth {
  healthy('Looks healthy'),
  minorIssues('Minor issues'),
  needsAttention('Needs attention'),
  unknown('Not clear');

  const PlantHealth(this.label);

  final String label;

  static PlantHealth parse(Object? raw) {
    return switch (raw.toString().trim().toLowerCase()) {
      'healthy' => PlantHealth.healthy,
      'minor_issues' || 'minor' => PlantHealth.minorIssues,
      'needs_attention' || 'unhealthy' => PlantHealth.needsAttention,
      _ => PlantHealth.unknown,
    };
  }
}

/// A single care fact. [label] names the need, [value] is the advice, and
/// [kind] lets the UI tint water and light facts differently.
class CareFact {
  const CareFact(this.label, this.value, this.kind);

  final String label;
  final String value;
  final CareKind kind;

  Map<String, Object?> toJson() => {
    'label': label,
    'value': value,
    'kind': kind.name,
  };

  static CareFact fromJson(Map<String, Object?> json) => CareFact(
    (json['label'] ?? '').toString(),
    (json['value'] ?? '').toString(),
    CareKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => CareKind.general,
    ),
  );
}

enum CareKind { light, water, soil, climate, feeding, general }

class PlantIdentification {
  const PlantIdentification({
    required this.isPlant,
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.summary,
    required this.health,
    required this.healthNotes,
    required this.care,
    required this.alternateMatches,
    required this.toxicToPets,
  });

  final bool isPlant;
  final String commonName;
  final String scientificName;

  /// 0.0 to 1.0, as reported by the model. Treat it as a hint, not a measurement.
  final double confidence;
  final String summary;
  final PlantHealth health;
  final List<String> healthNotes;
  final List<CareFact> care;

  /// Other species the photo could plausibly show, most likely first.
  final List<String> alternateMatches;
  final bool toxicToPets;

  static const PlantIdentification notAPlant = PlantIdentification(
    isPlant: false,
    commonName: 'No plant found',
    scientificName: '',
    confidence: 0,
    summary: '',
    health: PlantHealth.unknown,
    healthNotes: [],
    care: [],
    alternateMatches: [],
    toxicToPets: false,
  );

  Map<String, Object?> toJson() => {
    'is_plant': isPlant,
    'common_name': commonName,
    'scientific_name': scientificName,
    'confidence': confidence,
    'summary': summary,
    'health': health.name,
    'health_notes': healthNotes,
    'care': care.map((fact) => fact.toJson()).toList(),
    'alternate_matches': alternateMatches,
    'toxic_to_pets': toxicToPets,
  };

  /// Parses both our own stored shape and the model's reply, which uses the
  /// same field names but nests care advice as a flat object.
  static PlantIdentification fromJson(Map<String, Object?> json) {
    if (json['is_plant'] == false) return notAPlant;

    return PlantIdentification(
      isPlant: true,
      commonName: _string(json['common_name'], fallback: 'Unknown plant'),
      scientificName: _string(json['scientific_name']),
      confidence: _confidence(json['confidence']),
      summary: _string(json['summary']),
      health: PlantHealth.parse(json['health']),
      healthNotes: _stringList(json['health_notes']),
      care: _care(json['care']),
      alternateMatches: _stringList(json['alternate_matches']),
      toxicToPets: json['toxic_to_pets'] == true,
    );
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _confidence(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return 0;
    // Accept either 0-1 or 0-100.
    final scaled = number > 1 ? number / 100 : number;
    return scaled.clamp(0, 1).toDouble();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<CareFact> _care(Object? value) {
    // Our stored shape: a list of {label, value, kind}.
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => CareFact.fromJson(item.cast<String, Object?>()))
          .where((fact) => fact.value.isNotEmpty)
          .toList(growable: false);
    }

    // The model's shape: {light: "...", water: "...", ...}.
    if (value is Map) {
      const known = <String, (String, CareKind)>{
        'light': ('Light', CareKind.light),
        'water': ('Water', CareKind.water),
        'soil': ('Soil', CareKind.soil),
        'humidity': ('Humidity', CareKind.water),
        'temperature': ('Temperature', CareKind.climate),
        'fertilizer': ('Feeding', CareKind.feeding),
      };

      return known.entries
          .map((entry) {
            final advice = value[entry.key]?.toString().trim() ?? '';
            return CareFact(entry.value.$1, advice, entry.value.$2);
          })
          .where((fact) => fact.value.isNotEmpty)
          .toList(growable: false);
    }

    return const [];
  }
}
