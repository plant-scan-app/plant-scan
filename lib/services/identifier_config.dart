import 'claude_plant_identifier.dart';
import 'gemini_plant_identifier.dart';
import 'plant_identifier.dart';
import 'sample_plant_identifier.dart';

/// Compile-time configuration, supplied with --dart-define, so no key is ever
/// written into a file that git can pick up.
///
/// Whichever of these is set decides the backend, in this order:
///
///   IDENTIFY_PROXY_URL   your own server, which holds the key  (best)
///   GEMINI_API_KEY       Google Gemini, direct
///   ANTHROPIC_API_KEY    Claude, direct
///   nothing              canned sample results
const String _proxyUrl = String.fromEnvironment('IDENTIFY_PROXY_URL');
const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _anthropicKey = String.fromEnvironment('ANTHROPIC_API_KEY');

/// Which backend the proxy speaks to, so the app knows how to read the reply.
/// Either 'gemini' or 'claude'.
const String _proxyFlavour = String.fromEnvironment(
  'IDENTIFY_PROXY_FLAVOUR',
  defaultValue: 'gemini',
);

/// Optional override, since model names on both APIs change often.
const String _modelOverride = String.fromEnvironment('IDENTIFY_MODEL');

/// True when the app is running on canned sample data.
bool get usingSampleData =>
    _proxyUrl.isEmpty && _geminiKey.isEmpty && _anthropicKey.isEmpty;

final PlantIdentifier plantIdentifier = _build();

PlantIdentifier _build() {
  if (_proxyUrl.isNotEmpty) {
    return _proxyFlavour == 'claude'
        ? ClaudePlantIdentifier(endpoint: _proxyUrl)
        : GeminiPlantIdentifier.throughProxy(endpoint: _proxyUrl);
  }

  if (_geminiKey.isNotEmpty) {
    return GeminiPlantIdentifier(
      apiKey: _geminiKey,
      model: _modelOverride.isEmpty
          ? GeminiPlantIdentifier.defaultModel
          : _modelOverride,
    );
  }

  if (_anthropicKey.isNotEmpty) {
    return ClaudePlantIdentifier(
      apiKey: _anthropicKey,
      model: _modelOverride.isEmpty
          ? ClaudePlantIdentifier.defaultModel
          : _modelOverride,
    );
  }

  return SamplePlantIdentifier();
}
