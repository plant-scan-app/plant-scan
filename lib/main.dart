import 'package:flutter/material.dart';

import 'app.dart';
import 'services/ads_service.dart';
import 'services/device_cameras.dart';
import 'services/entitlements.dart';
import 'services/identifier_config.dart';
import 'services/scan_repository.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadDeviceCameras();
  await ScanRepository.instance.load();

  // Touching this builds the identifier and, when a backend is configured,
  // replaces the entitlement service with one wired to it. Must happen before
  // anything reads the quota.
  plantIdentifier;

  runApp(const PlantScanApp());

  // Nothing below blocks first paint. Ads and billing both make network calls
  // that have no business delaying the camera.
  if (usingBackend) {
    await EntitlementService.instance.refresh();
    await AdsService.instance.initialise();
    await SubscriptionService.instance.initialise();
  }
}
