import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Reads a photo from the device library, downscaled on the way out. Long
/// edges above ~1500px add upload time without helping identification.
Future<Uint8List?> pickPhotoFromLibrary() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1500,
    maxHeight: 1500,
    imageQuality: 85,
  );
  return picked == null ? null : await picked.readAsBytes();
}
