import 'dart:math';
import 'dart:typed_data';

import '../models/plant_identification.dart';
import 'plant_identifier.dart';

/// Returns canned results after a short delay. Used when no API key or proxy
/// URL was compiled in, so the app is fully clickable offline and in tests.
class SamplePlantIdentifier implements PlantIdentifier {
  SamplePlantIdentifier({int? seed}) : _random = Random(seed);

  final Random _random;

  @override
  Future<PlantIdentification> identify(Uint8List jpegBytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    return _samples[_random.nextInt(_samples.length)];
  }

  static const List<PlantIdentification> _samples = [
    PlantIdentification(
      isPlant: true,
      commonName: 'Swiss cheese plant',
      scientificName: 'Monstera deliciosa',
      confidence: 0.91,
      summary:
          'A climbing evergreen from the rainforests of southern Mexico and '
          'Central America. The holes and splits in mature leaves are the '
          'giveaway; young plants have plain heart-shaped leaves instead.',
      health: PlantHealth.minorIssues,
      healthNotes: [
        'Brown crisp edges on two lower leaves, usually dry air or underwatering',
        'New growth is a healthy colour, so the cause is recent',
      ],
      care: [
        CareFact('Light', 'Bright indirect light, out of midday sun', CareKind.light),
        CareFact('Water', 'Water when the top 5cm of soil is dry', CareKind.water),
        CareFact('Soil', 'Chunky, free-draining mix with bark or perlite', CareKind.soil),
        CareFact('Humidity', 'Happiest above 50%; group plants or mist', CareKind.water),
        CareFact('Temperature', 'Keep between 18 and 27°C, no cold draughts', CareKind.climate),
        CareFact('Feeding', 'Balanced feed monthly in spring and summer', CareKind.feeding),
      ],
      alternateMatches: ['Monstera adansonii', 'Epipremnum pinnatum'],
      toxicToPets: true,
    ),
    PlantIdentification(
      isPlant: true,
      commonName: 'Snake plant',
      scientificName: 'Dracaena trifasciata',
      confidence: 0.84,
      summary:
          'A stiff-leaved succulent from West Africa, grown for its upright '
          'banded foliage. It tolerates neglect better than almost any other '
          'houseplant, which is why it survives offices.',
      health: PlantHealth.healthy,
      healthNotes: ['Leaves are firm and upright with no soft base'],
      care: [
        CareFact('Light', 'Anything from low light to full sun', CareKind.light),
        CareFact('Water', 'Let the soil dry out completely between waterings', CareKind.water),
        CareFact('Soil', 'Cactus or succulent mix, never waterlogged', CareKind.soil),
        CareFact('Temperature', 'Above 10°C; it dislikes frost', CareKind.climate),
        CareFact('Feeding', 'Twice a year at most', CareKind.feeding),
      ],
      alternateMatches: ['Dracaena angolensis', 'Sansevieria kirkii'],
      toxicToPets: true,
    ),
    PlantIdentification(
      isPlant: true,
      commonName: 'Common ivy',
      scientificName: 'Hedera helix',
      confidence: 0.62,
      summary:
          'A vigorous European climber with lobed juvenile leaves. Species in '
          'this genus are hard to separate from a single photo, so this could '
          'be a cultivar or a close relative.',
      health: PlantHealth.needsAttention,
      healthNotes: [
        'Pale mottling between the veins suggests spider mites',
        'Check the leaf undersides for fine webbing',
      ],
      care: [
        CareFact('Light', 'Bright indirect light; variegated forms need more', CareKind.light),
        CareFact('Water', 'Keep evenly moist, never sitting in water', CareKind.water),
        CareFact('Soil', 'Standard potting compost', CareKind.soil),
        CareFact('Humidity', 'Dry air invites mites; raise it if you can', CareKind.water),
        CareFact('Feeding', 'Dilute feed every six weeks while growing', CareKind.feeding),
      ],
      alternateMatches: ['Hedera hibernica', 'Hedera canariensis'],
      toxicToPets: true,
    ),
  ];
}
