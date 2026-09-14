import 'backend_client.dart';
import 'claude_plant_identifier.dart';
import 'entitlements.dart';
import 'gemini_plant_identifier.dart';
import 'plant_identifier.dart';
import 'sample_plant_identifier.dart';

/// Compile-time configuration, supplied with --dart-define, so no key is ever
/// written into a file that git can pick up.
///
/// Whichever of these is set decides the backend, in this order:
///
///   BACKEND_URL          your Worker: holds the key, meters the free tier,
///                        verifies subscriptions              (ship this one)
///   GEMINI_API_KEY       Gemini direct, no metering           (development)
///   ANTHROPIC_API_KEY    Claude direct, no metering           (development)
///   nothing              canned sample results
///
/// Only BACKEND_URL is fit to release. A key passed to a release build is
/// embedded in the binary and can be extracted from the APK, and a scan limit
/// enforced on the device is bypassed by clearing app data.
const String _backendUrl = String.fromEnvironment('BACKEND_URL');
const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _anthropicKey = String.fromEnvironment('ANTHROPIC_API_KEY');

/// Optional override, since model names on both APIs change often.
const String _modelOverride = String.fromEnvironment('IDENTIFY_MODEL');

/// True when the app is running on canned sample data.
bool get usingSampleData =>
    _backendUrl.isEmpty && _geminiKey.isEmpty && _anthropicKey.isEmpty;

/// True when scans are metered and the paywall is live.
bool get usingBackend => _backendUrl.isNotEmpty;

final PlantIdentifier plantIdentifier = _build();

PlantIdentifier _build() {
  if (_backendUrl.isNotEmpty) {
    final backend = BackendClient(baseUrl: _backendUrl);

    // The entitlement service needs the same client, so the quota that comes
    // back with every identification updates the UI.
    EntitlementService.instance = EntitlementService(backend: backend);

    return BackendPlantIdentifier(
      backend: backend,
      entitlements: EntitlementService.instance,
    );
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
