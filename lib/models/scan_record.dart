import 'plant_identification.dart';

/// A saved scan: the photo on disk plus what we worked out from it.
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.imagePath,
    required this.scannedAt,
    required this.identification,
    this.nickname,
  });

  final String id;

  /// File name inside the app's `scans/` directory. Stored relative rather
  /// than absolute because the iOS container path changes between installs;
  /// resolve it with `ScanRepository.instance.imageFileFor(record)`.
  final String imagePath;
  final DateTime scannedAt;
  final PlantIdentification identification;

  /// What the owner calls this plant, if they renamed it.
  final String? nickname;

  String get displayName =>
      (nickname?.trim().isNotEmpty ?? false)
          ? nickname!.trim()
          : identification.commonName;

  ScanRecord copyWith({String? nickname}) => ScanRecord(
    id: id,
    imagePath: imagePath,
    scannedAt: scannedAt,
    identification: identification,
    nickname: nickname ?? this.nickname,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'image_path': imagePath,
    'scanned_at': scannedAt.toIso8601String(),
    'nickname': nickname,
    'identification': identification.toJson(),
  };

  static ScanRecord fromJson(Map<String, Object?> json) => ScanRecord(
    id: (json['id'] ?? '').toString(),
    imagePath: (json['image_path'] ?? '').toString(),
    scannedAt:
        DateTime.tryParse((json['scanned_at'] ?? '').toString()) ??
        DateTime.now(),
    nickname: json['nickname']?.toString(),
    identification: PlantIdentification.fromJson(
      (json['identification'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
  );
}
