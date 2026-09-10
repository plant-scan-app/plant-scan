import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Cameras found at launch. Empty on simulators, desktop, and anywhere the
/// platform refuses to enumerate them — the camera screen falls back to the
/// photo library in that case.
List<CameraDescription> deviceCameras = const <CameraDescription>[];

Future<void> loadDeviceCameras() async {
  try {
    deviceCameras = await availableCameras();
  } on CameraException catch (error) {
    debugPrint('No cameras available: ${error.code} ${error.description}');
  } catch (error) {
    debugPrint('Camera enumeration failed: $error');
  }
}
