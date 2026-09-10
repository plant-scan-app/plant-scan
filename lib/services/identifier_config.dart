import 'claude_plant_identifier.dart';
import 'plant_identifier.dart';
import 'sample_plant_identifier.dart';

/// Compile-time configuration, supplied with --dart-define. Nothing secret is
/// committed to the repository this way, though see the note in
/// [ClaudePlantIdentifier] about keys inside a shipped binary.
const String _proxyUrl = String.fromEnvironment('IDENTIFY_PROXY_URL');
const String _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

/// True when the app is running on canned sample data.
bool get usingSampleData => _proxyUrl.isEmpty && _apiKey.isEmpty;

final PlantIdentifier plantIdentifier = _build();

PlantIdentifier _build() {
  if (_proxyUrl.isNotEmpty) {
    return ClaudePlantIdentifier(endpoint: _proxyUrl);
  }
  if (_apiKey.isNotEmpty) {
    return ClaudePlantIdentifier(apiKey: _apiKey);
  }
  return SamplePlantIdentifier();
}
