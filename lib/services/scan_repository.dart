import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/plant_identification.dart';
import '../models/scan_record.dart';

/// Saved scans, kept as photo files plus a JSON index in the app's documents
/// directory. No database — the collection is small, always read whole, and
/// this keeps the project buildable with no native setup.
class ScanRepository extends ChangeNotifier {
  ScanRepository._();

  static final ScanRepository instance = ScanRepository._();

  static const String _indexFileName = 'scans.json';
  static const String _imageDirName = 'scans';

  final List<ScanRecord> _records = [];
  Directory? _root;
  bool _loaded = false;

  /// Newest first.
  List<ScanRecord> get records => List.unmodifiable(_records);

  bool get isEmpty => _records.isEmpty;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    try {
      _root = await getApplicationDocumentsDirectory();
      await Directory(p.join(_root!.path, _imageDirName)).create(
        recursive: true,
      );

      final index = File(p.join(_root!.path, _indexFileName));
      if (!index.existsSync()) return;

      final decoded = jsonDecode(await index.readAsString());
      if (decoded is! List) return;

      _records
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((item) => ScanRecord.fromJson(item.cast<String, Object?>())),
        );
      _sort();
      notifyListeners();
      await _sweepOrphanPhotos();
    } catch (error) {
      // A corrupt index should not stop the app from opening; the user can
      // scan again and we will write a fresh one.
      debugPrint('Could not load saved scans: $error');
    }
  }

  /// Resolves a record's photo against the current documents directory.
  File imageFileFor(ScanRecord record) =>
      File(p.join(_root?.path ?? '', _imageDirName, record.imagePath));

  Future<ScanRecord> save({
    required Uint8List jpegBytes,
    required PlantIdentification identification,
  }) async {
    _root ??= await getApplicationDocumentsDirectory();

    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final fileName = '$id.jpg';
    final file = File(p.join(_root!.path, _imageDirName, fileName));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(jpegBytes, flush: true);

    final record = ScanRecord(
      id: id,
      imagePath: fileName,
      scannedAt: DateTime.now(),
      identification: identification,
    );

    _records.add(record);
    _sort();
    notifyListeners();
    await _flush();
    return record;
  }

  Future<void> rename(String id, String? nickname) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) return;

    _records[index] = _records[index].copyWith(nickname: nickname);
    notifyListeners();
    await _flush();
  }

  /// Drops the record but leaves the photo on disk, so [restore] can bring the
  /// whole thing back. Orphaned photos are swept up at the next launch.
  Future<void> delete(String id) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) return;

    _records.removeAt(index);
    notifyListeners();
    await _flush();
  }

  /// Puts a deleted record back, for undo.
  Future<void> restore(ScanRecord record) async {
    if (_records.any((existing) => existing.id == record.id)) return;
    _records.add(record);
    _sort();
    notifyListeners();
    await _flush();
  }

  void _sort() =>
      _records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

  /// Deletes photos no record points at any more — the leftovers from scans
  /// the user discarded or deleted in an earlier session.
  Future<void> _sweepOrphanPhotos() async {
    if (_root == null) return;
    try {
      final directory = Directory(p.join(_root!.path, _imageDirName));
      if (!directory.existsSync()) return;

      final kept = _records.map((record) => record.imagePath).toSet();
      for (final entity in directory.listSync().whereType<File>()) {
        if (!kept.contains(p.basename(entity.path))) await entity.delete();
      }
    } catch (error) {
      debugPrint('Could not sweep old photos: $error');
    }
  }

  Future<void> _flush() async {
    if (_root == null) return;
    try {
      final index = File(p.join(_root!.path, _indexFileName));
      await index.writeAsString(
        jsonEncode(_records.map((record) => record.toJson()).toList()),
        flush: true,
      );
    } catch (error) {
      debugPrint('Could not write the scan index: $error');
    }
  }
}
