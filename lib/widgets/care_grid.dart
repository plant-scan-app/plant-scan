import 'package:flutter/material.dart';

import '../models/plant_identification.dart';
import '../theme.dart';

/// Care needs as a labelled set. They are not a sequence, so there is no
/// numbering — each fact is tinted by what it is about instead.
class CareGrid extends StatelessWidget {
  const CareGrid({required this.facts, super.key});

  final List<CareFact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var index = 0; index < facts.length; index++) ...[
          _CareRow(fact: facts[index]),
          if (index < facts.length - 1)
            const Divider(indent: 46, endIndent: 0, height: 1),
        ],
      ],
    );
  }
}

class _CareRow extends StatelessWidget {
  const _CareRow({required this.fact});

  final CareFact fact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icon, tint) = switch (fact.kind) {
      CareKind.light => (Icons.wb_sunny_outlined, Botanic.apricot),
      CareKind.water => (Icons.water_drop_outlined, Botanic.mineral),
      CareKind.soil => (Icons.grass_outlined, Botanic.chlorophyllDeep),
      CareKind.climate => (Icons.thermostat_outlined, Botanic.rust),
      CareKind.feeding => (Icons.science_outlined, Botanic.chlorophyll),
      CareKind.general => (Icons.info_outline, Botanic.inkSoft),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fact.label,
                  style: text.labelSmall?.copyWith(color: Botanic.inkSoft),
                ),
                const SizedBox(height: 3),
                Text(fact.value, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
