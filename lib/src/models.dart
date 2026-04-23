/// Represents a system font family and its constituent faces.
///
/// A family corresponds to a single entry in the platform's native font
/// collection (e.g. "Arial", "Segoe UI Variable"). Each family contains
/// one or more [FontFace] entries — one per face the OS reports.
///
/// Variation axes (`wght`, `wdth`, `slnt`, `ital`, `opsz`) live on the
/// family because they are properties of the underlying font resource,
/// shared by every face in the family.
class FontFamily {
  /// The font family name (e.g. `'Arial'`, `'Source Code Pro'`).
  final String name;

  /// Individual faces belonging to this family (Regular, Bold, Italic, …).
  ///
  /// Always contains at least one entry when returned by the scanner.
  final List<FontFace> faces;

  /// Continuous `wght` axis range, if the family includes a variable font.
  /// `null` for static-only families.
  final VariationAxis? weightAxis;

  /// Continuous `wdth` axis range (width), if present.
  final VariationAxis? widthAxis;

  /// Continuous `slnt` axis range (slant, in degrees), if present.
  ///
  /// Values are typically negative (e.g. −20…0); the scanner rounds to
  /// integers, so callers should expect negative `min` values here.
  final VariationAxis? slantAxis;

  /// Continuous `ital` axis range (italic), if present.
  ///
  /// In practice fonts declare only 0.0 or 1.0, but the axis is exposed
  /// as a range for uniformity.
  final VariationAxis? italicAxis;

  /// Continuous `opsz` axis range (optical size, in points), if present.
  final VariationAxis? opticalSizeAxis;

  /// Creates a [FontFamily] with the given [name] and [faces], plus any
  /// variation axes supported by the underlying font resource.
  const FontFamily({
    required this.name,
    required this.faces,
    this.weightAxis,
    this.widthAxis,
    this.slantAxis,
    this.italicAxis,
    this.opticalSizeAxis,
  });

  /// Distinct weights declared by the faces in this family, in ascending
  /// order. Derived from [faces] for backward compatibility with earlier
  /// API versions.
  ///
  /// For variable fonts, this contains only the discrete weights of
  /// named instances; the continuous range is exposed via [weightAxis].
  List<int> get weights {
    final set = <int>{};
    for (final face in faces) {
      set.add(face.weight);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamily &&
          name == other.name &&
          _listEquals(faces, other.faces) &&
          weightAxis == other.weightAxis &&
          widthAxis == other.widthAxis &&
          slantAxis == other.slantAxis &&
          italicAxis == other.italicAxis &&
          opticalSizeAxis == other.opticalSizeAxis;

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(faces),
        weightAxis,
        widthAxis,
        slantAxis,
        italicAxis,
        opticalSizeAxis,
      );

  @override
  String toString() {
    final buf = StringBuffer('FontFamily($name, faces: ${faces.length}');
    if (weightAxis != null) buf.write(', weightAxis: $weightAxis');
    if (widthAxis != null) buf.write(', widthAxis: $widthAxis');
    if (slantAxis != null) buf.write(', slantAxis: $slantAxis');
    if (italicAxis != null) buf.write(', italicAxis: $italicAxis');
    if (opticalSizeAxis != null) {
      buf.write(', opticalSizeAxis: $opticalSizeAxis');
    }
    buf.write(')');
    return buf.toString();
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A single face within a [FontFamily] (e.g. "Regular", "Bold Italic").
///
/// Each face corresponds to a distinct entry reported by the platform —
/// typically a physical font file on disk for static fonts, or a named
/// instance of a variable font resource.
class FontFace {
  /// CSS weight (1–1000). Common values: 400 (Regular), 700 (Bold).
  final int weight;

  /// Italic / oblique style.
  final FontStyle style;

  /// Width class (1 = Ultra-Condensed … 5 = Normal … 9 = Ultra-Expanded).
  /// Follows the OpenType OS/2 `usWidthClass` convention.
  final int stretch;

  /// Sub-family name as reported by the OS (e.g. "Regular", "Bold Italic").
  final String faceName;

  /// OpenType PostScript name. Used as the canonical identifier for font
  /// matching in CSS / PDF / PostScript. `null` if the face does not
  /// expose one.
  final String? postScriptName;

  /// Human-readable full name (e.g. "Arial Bold Italic"). `null` if
  /// unavailable.
  final String? fullName;

  /// Absolute path to the backing font file, or `null` if the face is
  /// backed by a non-local loader (memory / network).
  final String? filePath;

  /// True if every glyph has the same advance width.
  final bool isMonospace;

  /// True if the face contains symbol glyphs rather than textual ones
  /// (e.g. Wingdings).
  final bool isSymbol;

  /// Creates a [FontFace] with the given attributes.
  const FontFace({
    required this.weight,
    required this.style,
    required this.stretch,
    required this.faceName,
    required this.postScriptName,
    required this.fullName,
    required this.filePath,
    required this.isMonospace,
    required this.isSymbol,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFace &&
          weight == other.weight &&
          style == other.style &&
          stretch == other.stretch &&
          faceName == other.faceName &&
          postScriptName == other.postScriptName &&
          fullName == other.fullName &&
          filePath == other.filePath &&
          isMonospace == other.isMonospace &&
          isSymbol == other.isSymbol;

  @override
  int get hashCode => Object.hash(
        weight,
        style,
        stretch,
        faceName,
        postScriptName,
        fullName,
        filePath,
        isMonospace,
        isSymbol,
      );

  @override
  String toString() =>
      'FontFace($faceName, weight: $weight, style: ${style.name}, '
      'stretch: $stretch${isMonospace ? ', mono' : ''}'
      '${isSymbol ? ', symbol' : ''})';
}

/// Slant style of a font face.
enum FontStyle {
  /// Upright.
  normal,

  /// Italic — a distinct designed variant, typically with different
  /// letterforms from the upright.
  italic,

  /// Oblique — a slanted version of the upright, usually synthesized.
  oblique,
}

/// Continuous variation axis range for an OpenType variable font.
///
/// Units depend on the axis:
/// - `wght`: CSS weight (1–1000)
/// - `wdth`: width percentage
/// - `slnt`: slant degrees (often negative)
/// - `ital`: 0.0 or 1.0
/// - `opsz`: point size
///
/// Platform-reported floats are rounded to the nearest integer.
class VariationAxis {
  /// Minimum supported value (inclusive).
  final int min;

  /// Maximum supported value (inclusive).
  final int max;

  /// Default value used when no explicit axis value is requested.
  final int defaultValue;

  /// Creates a [VariationAxis] with the given range.
  const VariationAxis({
    required this.min,
    required this.max,
    required this.defaultValue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariationAxis &&
          min == other.min &&
          max == other.max &&
          defaultValue == other.defaultValue;

  @override
  int get hashCode => Object.hash(min, max, defaultValue);

  @override
  String toString() =>
      'VariationAxis(min: $min, max: $max, default: $defaultValue)';
}

/// Backward-compatible alias. Prefer [VariationAxis] in new code.
typedef WeightAxis = VariationAxis;
