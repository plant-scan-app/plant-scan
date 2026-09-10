import 'package:flutter/material.dart';

import 'app.dart';
import 'services/device_cameras.dart';
import 'services/scan_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadDeviceCameras();
  await ScanRepository.instance.load();
  runApp(const PlantScanApp());
}
