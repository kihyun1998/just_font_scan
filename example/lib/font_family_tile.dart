import 'package:flutter/material.dart';
import 'package:just_font_scan/just_font_scan.dart';

import 'variable_preview.dart';

class FontFamilyTile extends StatelessWidget {
  final FontFamily family;

  /// Non-null only when [family] has a variable `wght` axis. The tile
  /// hands it through to [VariablePreview] unchanged.
  final ValueNotifier<double>? wghtNotifier;

  const FontFamilyTile({super.key, required this.family, this.wghtNotifier});

  @override
  Widget build(BuildContext context) {
    final axis = family.weightAxis;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(family.name, style: theme.textTheme.titleMedium),
                ),
                if (axis != null) _VfBadge(axis: axis),
              ],
            ),
            const SizedBox(height: 6),
            if (family.weights.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: family.weights.map((w) {
                  return Chip(
                    label: Text('$w', style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            if (axis != null && wghtNotifier != null) ...[
              const SizedBox(height: 8),
              VariablePreview(
                fontFamily: family.name,
                axis: axis,
                wghtNotifier: wghtNotifier!,
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'The quick brown fox jumps over the lazy dog',
                style: TextStyle(fontFamily: family.name, fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VfBadge extends StatelessWidget {
  final WeightAxis axis;
  const _VfBadge({required this.axis});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'VF wght ${axis.min}–${axis.max} · default ${axis.defaultValue}',
        style: TextStyle(
          fontSize: 10,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
