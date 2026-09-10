import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/plant_identification.dart';
import '../models/scan_record.dart';
import '../services/identifier_config.dart';
import '../services/plant_identifier.dart';
import '../services/scan_repository.dart';
import '../theme.dart';
import '../widgets/care_grid.dart';
import '../widgets/scan_tile.dart';
import '../widgets/verdict_widgets.dart';

/// Shows what a photo turned out to be.
///
/// Built two ways: [ResultScreen.fromCapture] runs the identification on a
/// fresh photo, [ResultScreen.fromRecord] replays one already in the log.
class ResultScreen extends StatefulWidget {
  const ResultScreen.fromCapture(Uint8List this.bytes, {super.key})
    : record = null;

  const ResultScreen.fromRecord(ScanRecord this.record, {super.key})
    : bytes = null;

  final Uint8List? bytes;
  final ScanRecord? record;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  PlantIdentification? _result;
  ScanRecord? _saved;
  String? _errorMessage;
  bool _identifying = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _saved = widget.record;
      _result = widget.record!.identification;
    } else {
      _identify();
    }
  }

  Future<void> _identify() async {
    setState(() {
      _identifying = true;
      _errorMessage = null;
    });

    try {
      final result = await plantIdentifier.identify(widget.bytes!);
      if (!mounted) return;
      setState(() {
        _result = result;
        _identifying = false;
      });
    } on IdentificationException catch (exception) {
      if (!mounted) return;
      setState(() {
        _errorMessage = exception.message;
        _identifying = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong reading this photo.';
        _identifying = false;
      });
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving) return;

    setState(() => _saving = true);
    final record = await ScanRepository.instance.save(
      jpegBytes: widget.bytes!,
      identification: result,
    );
    if (!mounted) return;
    setState(() {
      _saved = record;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to My plants')),
    );
  }

  Future<void> _rename() async {
    final record = _saved;
    if (record == null) return;

    final controller = TextEditingController(text: record.nickname ?? '');
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Botanic.card,
        title: const Text('Name this plant'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: record.identification.commonName,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 44),
            ),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save name'),
          ),
        ],
      ),
    );

    if (nickname == null) return;
    await ScanRepository.instance.rename(record.id, nickname);
    if (!mounted) return;
    setState(
      () => _saved = record.copyWith(
        nickname: nickname.trim().isEmpty ? null : nickname,
      ),
    );
  }

  Future<void> _delete() async {
    final record = _saved;
    if (record == null) return;

    await ScanRepository.instance.delete(record.id);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${record.displayName} removed'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Botanic.chlorophyll,
          onPressed: () => ScanRepository.instance.restore(record),
        ),
      ),
    );
  }

  ImageProvider get _photo => widget.bytes != null
      ? MemoryImage(widget.bytes!)
      : FileImage(ScanRepository.instance.imageFileFor(widget.record!));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Botanic.surface,
            foregroundColor: const Color(0xFFF2F5EE),
            iconTheme: const IconThemeData(color: Color(0xFFF2F5EE)),
            actions: [
              if (_saved != null) ...[
                IconButton(
                  onPressed: _rename,
                  tooltip: 'Name this plant',
                  icon: const Icon(Icons.drive_file_rename_outline),
                ),
                IconButton(
                  onPressed: _delete,
                  tooltip: 'Remove from My plants',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
            flexibleSpace: DecoratedBox(
              decoration: const BoxDecoration(color: Botanic.ink),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(image: _photo, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                        stops: [0, 0.45],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            sliver: SliverToBoxAdapter(child: _body(context)),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_identifying) return const _Working();

    if (_errorMessage != null) {
      return _Problem(message: _errorMessage!, onRetry: _identify);
    }

    final result = _result;
    if (result == null) return const SizedBox.shrink();
    if (!result.isPlant) return const _NoPlantFound();

    return _Verdict(
      result: result,
      record: _saved,
      saving: _saving,
      onSave: widget.bytes == null ? null : _save,
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.result,
    required this.record,
    required this.saving,
    required this.onSave,
  });

  final PlantIdentification result;
  final ScanRecord? record;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = record?.displayName ?? result.commonName;
    final showSave = record == null && onSave != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, style: text.displaySmall)),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: HealthBadge(health: result.health),
            ),
          ],
        ),
        if (result.scientificName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            result.scientificName,
            style: text.bodyLarge?.copyWith(
              color: Botanic.inkSoft,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.2,
            ),
          ),
        ],
        if (record != null && record!.nickname != null) ...[
          const SizedBox(height: 4),
          Text(
            'Identified as ${result.commonName}',
            style: text.bodyMedium?.copyWith(color: Botanic.inkSoft),
          ),
        ],
        if (record != null) ...[
          const SizedBox(height: 4),
          Text(
            'Scanned ${DateFormat.yMMMMd().format(record!.scannedAt)}',
            style: text.labelSmall?.copyWith(color: Botanic.inkSoft),
          ),
        ],
        const SizedBox(height: 22),
        SurfaceCard(
          child: ConfidenceMeter(
            confidence: result.confidence,
            alternates: result.alternateMatches,
          ),
        ),
        if (result.summary.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(result.summary, style: text.bodyLarge),
        ],
        if (result.toxicToPets) ...[
          const SizedBox(height: 20),
          const _ToxicityNote(),
        ],
        if (result.healthNotes.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text('What the photo shows', style: text.headlineSmall),
          const SizedBox(height: 12),
          for (final note in result.healthNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 12),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Botanic.chlorophyll,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Text(note, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
        if (result.care.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text('How to look after it', style: text.headlineSmall),
          const SizedBox(height: 6),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: CareGrid(facts: result.care),
          ),
        ],
        const SizedBox(height: 26),
        if (showSave)
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFF6F8F3),
                    ),
                  )
                : const Icon(Icons.add),
            label: Text(saving ? 'Saving' : 'Add to My plants'),
          ),
        const SizedBox(height: 20),
        Text(
          'A photo can only say so much. Check an identification against a '
          'second source before you eat, plant, or treat anything.',
          style: text.labelSmall?.copyWith(color: Botanic.inkSoft),
        ),
      ],
    );
  }
}

class _ToxicityNote extends StatelessWidget {
  const _ToxicityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Botanic.apricot.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Botanic.apricot.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pets_outlined, size: 18, color: Botanic.rust),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Toxic to cats and dogs if chewed. Keep it out of reach.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Botanic.rust,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Botanic.chlorophyll,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Working out what this is',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (final width in const [1.0, 0.7, 0.85, 0.45])
          FractionallySizedBox(
            widthFactor: width,
            child: Container(
              height: 14,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Botanic.hairline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Identification failed', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text(message, style: text.bodyLarge?.copyWith(color: Botanic.inkSoft)),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

class _NoPlantFound extends StatelessWidget {
  const _NoPlantFound();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No plant in this photo', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Get closer, fill the frame with leaves or a flower, and keep the '
          'phone steady.',
          style: text.bodyLarge?.copyWith(color: Botanic.inkSoft),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Scan again'),
        ),
      ],
    );
  }
}
