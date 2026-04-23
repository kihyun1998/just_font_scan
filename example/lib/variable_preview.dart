import 'package:flutter/material.dart';
import 'package:just_font_scan/just_font_scan.dart';

/// Slider + live sample text driven by a `wght` axis [ValueNotifier].
///
/// The notifier is owned by the parent page so the value survives
/// ListView recycling as the tile scrolls in and out of view. Only
/// this subtree rebuilds when the slider moves — the surrounding list
/// does not.
class VariablePreview extends StatelessWidget {
  final String fontFamily;
  final VariationAxis axis;
  final ValueNotifier<double> wghtNotifier;

  const VariablePreview({
    super.key,
    required this.fontFamily,
    required this.axis,
    required this.wghtNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final minD = axis.min.toDouble();
    final maxD = axis.max.toDouble();

    return ValueListenableBuilder<double>(
      valueListenable: wghtNotifier,
      builder: (context, wght, _) {
        final clamped = wght.clamp(minD, maxD);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'wght ${clamped.round()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: minD,
                    max: maxD,
                    value: clamped,
                    onChanged: (v) => wghtNotifier.value = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'The quick brown fox jumps over the lazy dog',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 20,
                fontVariations: [FontVariation('wght', clamped)],
              ),
            ),
          ],
        );
      },
    );
  }
}
