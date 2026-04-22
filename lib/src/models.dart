/// Represents a system font family with its supported weights.
///
/// Each instance corresponds to a single font family as grouped by the
/// platform's native font API (e.g. DirectWrite on Windows).
class FontFamily {
  /// The font family name (e.g. `'Arial'`, `'Source Code Pro'`).
  final String name;

  /// Supported font weights in ascending order.
  ///
  /// Values follow the CSS/OpenType convention: 100 (Thin) through
  /// 950 (ExtraBlack). Common values: 400 (Regular), 700 (Bold).
  ///
  /// For variable fonts, this contains the discrete weights of any
  /// named instances declared by the font; the continuous range is
  /// exposed via [weightAxis].
  final List<int> weights;

  /// The continuous `wght` axis range, if this family includes a
  /// variable font. `null` for static-only families.
  ///
  /// When non-null, callers can choose any integer between
  /// [WeightAxis.min] and [WeightAxis.max] inclusive, not just the
  /// discrete values in [weights].
  final WeightAxis? weightAxis;

  /// Creates a [FontFamily] with the given [name], [weights], and
  /// optional [weightAxis] for variable fonts.
  const FontFamily({
    required this.name,
    required this.weights,
    this.weightAxis,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamily &&
          name == other.name &&
          _listEquals(weights, other.weights) &&
          weightAxis == other.weightAxis;

  @override
  int get hashCode => Object.hash(name, Object.hashAll(weights), weightAxis);

  @override
  String toString() {
    final axis = weightAxis;
    if (axis == null) return 'FontFamily($name, weights: $weights)';
    return 'FontFamily($name, weights: $weights, weightAxis: $axis)';
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Continuous `wght` axis range exposed by an OpenType variable font.
///
/// Values follow the CSS/OpenType convention (typically 1–1000). All
/// fields are integers — platform-reported floats are rounded to the
/// nearest whole number.
class WeightAxis {
  /// Minimum supported weight (inclusive).
  final int min;

  /// Maximum supported weight (inclusive).
  final int max;

  /// Default weight used when no explicit value is requested.
  final int defaultValue;

  /// Creates a [WeightAxis] with the given range.
  const WeightAxis({
    required this.min,
    required this.max,
    required this.defaultValue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightAxis &&
          min == other.min &&
          max == other.max &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode => Object.hash(min, max, defaultValue);

  @override
  String toString() =>
      'WeightAxis(min: $min, max: $max, default: $defaultValue)';
}
