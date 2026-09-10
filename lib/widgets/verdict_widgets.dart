import 'package:flutter/material.dart';

import '../models/plant_identification.dart';
import '../theme.dart';

/// Names the plant's condition rather than relying on colour alone, so it
/// still reads for colour-blind users and in screenshots.
class HealthBadge extends StatelessWidget {
  const HealthBadge({required this.health, super.key});

  final PlantHealth health;

  @override
  Widget build(BuildContext context) {
    final (tint, icon) = switch (health) {
      PlantHealth.healthy => (Botanic.chlorophyll, Icons.check_circle_outline),
      PlantHealth.minorIssues => (Botanic.apricot, Icons.error_outline),
      PlantHealth.needsAttention => (Botanic.rust, Icons.warning_amber_rounded),
      PlantHealth.unknown => (Botanic.inkSoft, Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          Text(
            health.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tint == Botanic.apricot ? Botanic.rust : tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin measure with the alternates named underneath, so a low score comes
/// with an explanation of what else the photo might be.
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({
    required this.confidence,
    required this.alternates,
    super.key,
  });

  final double confidence;
  final List<String> alternates;

  String get _wording => switch (confidence) {
    >= 0.85 => 'Confident match',
    >= 0.6 => 'Probable match',
    >= 0.35 => 'Uncertain match',
    _ => 'Best guess only',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(_wording, style: text.titleMedium)),
            Text(
              '${(confidence * 100).round()}%',
              style: text.titleMedium?.copyWith(color: Botanic.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: confidence.clamp(0, 1),
            minHeight: 6,
            backgroundColor: Botanic.hairline,
            valueColor: AlwaysStoppedAnimation(
              confidence >= 0.6 ? Botanic.chlorophyll : Botanic.apricot,
            ),
          ),
        ),
        if (alternates.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            alternates.length == 1
                ? 'Could also be ${alternates.first}.'
                : 'Could also be ${alternates.take(3).join(', ')}.',
            style: text.bodyMedium?.copyWith(
              color: Botanic.inkSoft,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
