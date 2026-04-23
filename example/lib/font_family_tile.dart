import 'package:flutter/material.dart';
import 'package:just_font_scan/just_font_scan.dart';

import 'variable_preview.dart';

class FontFamilyTile extends StatefulWidget {
  final FontFamily family;

  /// Non-null only when [family] has a variable `wght` axis. The tile
  /// hands it through to [VariablePreview] unchanged.
  final ValueNotifier<double>? wghtNotifier;

  const FontFamilyTile({super.key, required this.family, this.wghtNotifier});

  @override
  State<FontFamilyTile> createState() => _FontFamilyTileState();
}

class _FontFamilyTileState extends State<FontFamilyTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final family = widget.family;
    final wghtAxis = family.weightAxis;
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
                if (_hasAnyAxis(family)) _VfAxisSummary(family: family),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _CountChip(label: '${family.faces.length} face'
                    '${family.faces.length == 1 ? '' : 's'}'),
                if (family.faces.any((f) => f.isMonospace))
                  const _FlagChip(label: 'mono'),
                if (family.faces.any((f) => f.isSymbol))
                  const _FlagChip(label: 'symbol'),
                for (final w in family.weights)
                  Chip(
                    label: Text('$w', style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (wghtAxis != null && widget.wghtNotifier != null) ...[
              const SizedBox(height: 8),
              VariablePreview(
                fontFamily: family.name,
                axis: wghtAxis,
                wghtNotifier: widget.wghtNotifier!,
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'The quick brown fox jumps over the lazy dog',
                style: TextStyle(fontFamily: family.name, fontSize: 16),
              ),
            ],
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  Text(
                    _expanded ? 'Hide face details' : 'Show face details',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _FaceList(faces: family.faces),
              ),
          ],
        ),
      ),
    );
  }

  static bool _hasAnyAxis(FontFamily f) =>
      f.weightAxis != null ||
      f.widthAxis != null ||
      f.slantAxis != null ||
      f.italicAxis != null ||
      f.opticalSizeAxis != null;
}

class _FaceList extends StatelessWidget {
  final List<FontFace> faces;
  const _FaceList({required this.faces});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final face in faces)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  face.faceName.isEmpty ? '(unnamed face)' : face.faceName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'w=${face.weight}  ${face.style.name}  stretch=${face.stretch}'
                  '${face.isMonospace ? '  mono' : ''}'
                  '${face.isSymbol ? '  symbol' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                if (face.postScriptName != null)
                  Text('ps: ${face.postScriptName}',
                      style: theme.textTheme.bodySmall),
                if (face.filePath != null)
                  Text(
                    face.filePath!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VfAxisSummary extends StatelessWidget {
  final FontFamily family;
  const _VfAxisSummary({required this.family});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tags = <String>[
      if (family.weightAxis != null) 'wght',
      if (family.widthAxis != null) 'wdth',
      if (family.slantAxis != null) 'slnt',
      if (family.italicAxis != null) 'ital',
      if (family.opticalSizeAxis != null) 'opsz',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'VF · ${tags.join(' ')}',
        style: TextStyle(
          fontSize: 10,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  const _CountChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  const _FlagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
