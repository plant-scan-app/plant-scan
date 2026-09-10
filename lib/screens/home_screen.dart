import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/device_cameras.dart';
import '../services/identifier_config.dart';
import '../services/photo_source.dart';
import '../services/scan_repository.dart';
import '../theme.dart';
import '../widgets/scan_tile.dart';
import 'camera_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openCamera(BuildContext context) async {
    if (deviceCameras.isEmpty) {
      await _openLibrary(context);
      return;
    }
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (bytes != null && context.mounted) _showResult(context, bytes);
  }

  Future<void> _openLibrary(BuildContext context) async {
    final bytes = await pickPhotoFromLibrary();
    if (bytes != null && context.mounted) _showResult(context, bytes);
  }

  void _showResult(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen.fromCapture(bytes)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ScanRepository.instance,
          builder: (context, _) {
            final recent = ScanRepository.instance.records.take(3).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text('Plant scan', style: text.displaySmall),
                const SizedBox(height: 8),
                SizedBox(
                  width: 300,
                  child: Text(
                    'Photograph a leaf, a flower, or the whole plant. '
                    'Fill the frame and keep it still.',
                    style: text.bodyLarge?.copyWith(color: Botanic.inkSoft),
                  ),
                ),
                const SizedBox(height: 28),
                const _LeafFrame(),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _openCamera(context),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan a plant'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openLibrary(context),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose a photo'),
                ),
                if (usingSampleData) ...[
                  const SizedBox(height: 20),
                  const _SampleDataNotice(),
                ],
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 34),
                  Text('Recent scans', style: text.headlineSmall),
                  const SizedBox(height: 14),
                  for (final record in recent) ...[
                    ScanTile(
                      record: record,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ResultScreen.fromRecord(record),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The one piece of decoration on this screen: corner brackets suggesting a
/// viewfinder over a leaf, so the primary action is legible before it is read.
class _LeafFrame extends StatelessWidget {
  const _LeafFrame();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: Botanic.chlorophyllDeep.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Botanic.hairline),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.local_florist_outlined,
              size: 78,
              color: Botanic.chlorophyllDeep.withValues(alpha: 0.35),
            ),
            const Positioned(top: 16, left: 16, child: _Corner()),
            const Positioned(
              top: 16,
              right: 16,
              child: _Corner(quarterTurns: 1),
            ),
            const Positioned(
              bottom: 16,
              right: 16,
              child: _Corner(quarterTurns: 2),
            ),
            const Positioned(
              bottom: 16,
              left: 16,
              child: _Corner(quarterTurns: 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({this.quarterTurns = 0});

  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Botanic.chlorophyll, width: 2.5),
            left: BorderSide(color: Botanic.chlorophyll, width: 2.5),
          ),
        ),
      ),
    );
  }
}

class _SampleDataNotice extends StatelessWidget {
  const _SampleDataNotice();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.construction_outlined, size: 18, color: Botanic.apricot),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Running on sample results. Add an API key or proxy URL at build '
              'time to identify real photos — see the README.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Botanic.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
