import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../limits.dart';
import '../models.dart';
import 'coretext_bindings.dart';

/// Internal record bundling the five registered OpenType variation axes.
/// `null` fields mean the descriptor does not declare that axis.
typedef _AxisSet = ({
  VariationAxis? weight,
  VariationAxis? width,
  VariationAxis? slant,
  VariationAxis? italic,
  VariationAxis? opticalSize,
});

const _AxisSet _emptyAxisSet = (
  weight: null,
  width: null,
  slant: null,
  italic: null,
  opticalSize: null,
);

bool _axisSetIsEmpty(_AxisSet s) =>
    s.weight == null &&
    s.width == null &&
    s.slant == null &&
    s.italic == null &&
    s.opticalSize == null;

/// Scans system fonts using the CoreText API.
///
/// Best-effort: individual descriptor failures are silently skipped.
/// Returns an empty list if CoreText is unavailable or any fatal error occurs.
List<FontFamily> scanFonts() {
  try {
    return using((arena) => _scanWithArena(arena));
  } catch (_) {
    return const [];
  }
}

List<FontFamily> _scanWithArena(Arena arena) {
  final b = MacFontBindings.instance;
  // CoreText internally creates autoreleased NSString/NSDictionary objects.
  // Without a pool, they leak until process exit (~1.3 MB per scan).
  return b.inAutoreleasePool(() => _scanInPool(b, arena));
}

List<FontFamily> _scanInPool(MacFontBindings b, Arena arena) {
  final collection = b.ctFontCollectionCreateFromAvailable(nullptr);
  if (collection.address == 0) return const [];

  try {
    final array = b.ctFontCollectionCreateMatching(collection);
    if (array.address == 0) return const [];
    try {
      return _scanDescriptorArray(b, array, arena);
    } finally {
      b.cfRelease(array);
    }
  } finally {
    b.cfRelease(collection);
  }
}

List<FontFamily> _scanDescriptorArray(
  MacFontBindings b,
  CFTypeRef array,
  Arena arena,
) {
  // Descriptor array holds faces, not families; a family may contribute 1–20+
  // descriptors.
  final count = b.cfArrayGetCount(array).clamp(0, kMaxDescriptorCount);

  final facesByFamily = <String, List<FontFace>>{};
  final axesByFamily = <String, _AxisSet>{};

  for (var i = 0; i < count; i++) {
    final desc = b.cfArrayGetValueAtIndex(array, i); // borrowed
    if (desc.address == 0) continue;
    _scanDescriptor(b, desc, facesByFamily, axesByFamily, arena);
  }

  final families = <FontFamily>[];
  for (final entry in facesByFamily.entries) {
    if (entry.value.isEmpty) continue;
    final axes = axesByFamily[entry.key] ?? _emptyAxisSet;
    families.add(FontFamily(
      name: entry.key,
      faces: entry.value,
      weightAxis: axes.weight,
      widthAxis: axes.width,
      slantAxis: axes.slant,
      italicAxis: axes.italic,
      opticalSizeAxis: axes.opticalSize,
    ));
  }
  families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  if (families.length > kMaxFontFamilyCount) {
    return families.sublist(0, kMaxFontFamilyCount);
  }
  return families;
}

void _scanDescriptor(
  MacFontBindings b,
  CFTypeRef desc,
  Map<String, List<FontFace>> facesAcc,
  Map<String, _AxisSet> axesAcc,
  Arena arena,
) {
  final name = _copyFamilyName(b, desc, arena);
  if (name == null) return;

  final face = _buildFace(b, desc, arena);
  if (face != null) {
    facesAcc.putIfAbsent(name, () => <FontFace>[]).add(face);
  }

  // Extract the variable-font axes at most once per family. Italic and
  // roman descriptors of the same VF report identical axis ranges in
  // practice, so the first non-empty hit wins.
  if (axesAcc.containsKey(name)) return;
  final symbols = b.variationAxes;
  if (symbols == null) return;

  final axes = _copyAllAxes(b, desc, symbols, arena);
  if (!_axisSetIsEmpty(axes)) {
    axesAcc[name] = axes;
  }
}

FontFace? _buildFace(
  MacFontBindings b,
  CFTypeRef desc,
  Arena arena,
) {
  // Read the entire traits dictionary once — we extract weight, width,
  // slant, and symbolic traits from it.
  final traits = b.ctFontDescriptorCopyAttribute(desc, b.kFontTraitsAttribute);
  final int weight;
  final int stretch;
  final double slant;
  final int symbolic;
  if (traits.address == 0) {
    weight = 400;
    stretch = 5;
    slant = 0.0;
    symbolic = 0;
  } else {
    try {
      weight = _readWeightFromTraits(b, traits, arena);
      stretch = _readStretchFromTraits(b, traits, arena);
      slant = _readSlantFromTraits(b, traits, arena);
      symbolic = _readSymbolicFromTraits(b, traits, arena);
    } finally {
      b.cfRelease(traits);
    }
  }

  final italicBit = (symbolic & kCTFontTraitItalic) != 0;
  final style = _deriveStyle(italicBit, slant);
  final isMonospace = (symbolic & kCTFontTraitMonoSpace) != 0;
  final isSymbol = (symbolic & kCTFontClassMaskTrait) == kCTFontClassSymbolic;

  final faceName =
      _copyStringAttribute(b, desc, b.kFontStyleNameAttribute, arena) ?? '';
  final postScriptName =
      _copyStringAttribute(b, desc, b.kFontNameAttribute, arena);
  final fullName =
      _copyStringAttribute(b, desc, b.kFontDisplayNameAttribute, arena);
  final filePath = _copyFilePath(b, desc, arena);

  return FontFace(
    weight: weight,
    style: style,
    stretch: stretch,
    faceName: faceName,
    postScriptName: postScriptName,
    fullName: fullName,
    filePath: filePath,
    isMonospace: isMonospace,
    isSymbol: isSymbol,
  );
}

int _readWeightFromTraits(
  MacFontBindings b,
  CFTypeRef traits,
  Arena arena,
) {
  final num = b.cfDictionaryGetValue(traits, b.kFontWeightTrait); // borrowed
  if (num.address == 0) return 400;
  final out = arena<Double>();
  final ok = b.cfNumberGetValue(num, kCFNumberDoubleType, out);
  if (ok == 0) return 400;
  return mapWeight(out.value);
}

int _readStretchFromTraits(
  MacFontBindings b,
  CFTypeRef traits,
  Arena arena,
) {
  final num = b.cfDictionaryGetValue(traits, b.kFontWidthTrait); // borrowed
  if (num.address == 0) return 5;
  final out = arena<Double>();
  final ok = b.cfNumberGetValue(num, kCFNumberDoubleType, out);
  if (ok == 0) return 5;
  return mapStretch(out.value);
}

double _readSlantFromTraits(
  MacFontBindings b,
  CFTypeRef traits,
  Arena arena,
) {
  final num = b.cfDictionaryGetValue(traits, b.kFontSlantTrait); // borrowed
  if (num.address == 0) return 0.0;
  final out = arena<Double>();
  final ok = b.cfNumberGetValue(num, kCFNumberDoubleType, out);
  if (ok == 0) return 0.0;
  return out.value;
}

int _readSymbolicFromTraits(
  MacFontBindings b,
  CFTypeRef traits,
  Arena arena,
) {
  final num = b.cfDictionaryGetValue(traits, b.kFontSymbolicTrait); // borrowed
  if (num.address == 0) return 0;
  final out = arena<Int32>();
  final ok = b.cfNumberGetValueInt32(num, kCFNumberSInt32Type, out);
  if (ok == 0) return 0;
  // Symbolic traits are declared as uint32 in CoreText but CFNumber exposes
  // only signed types — reinterpret by masking into the unsigned domain.
  return out.value & 0xFFFFFFFF;
}

/// Minimum |slant| (CoreText normalized −1.0…1.0 scale) to classify a face
/// as oblique when the italic trait bit is not set. 0.05 was too permissive —
/// floating-point rounding in CoreText's internal normalization can leave
/// upright faces with a non-zero slant, causing false oblique classification.
const double _kObliqueSlantThreshold = 0.1;

/// Converts a CoreText slant value (+/- scalar, typically within [−1.0, 1.0])
/// and italic bit into a [FontStyle].
///
/// - italicBit == true → [FontStyle.italic] (CoreText flags the face as a
///   designed italic — trust that marker over slant magnitude).
/// - italicBit == false + |slant| > threshold → [FontStyle.oblique]
///   (synthesized or pseudo-slanted fonts without an italic trait).
/// - Otherwise → [FontStyle.normal].
FontStyle _deriveStyle(bool italicBit, double slant) {
  if (italicBit) return FontStyle.italic;
  if (slant.abs() > _kObliqueSlantThreshold) return FontStyle.oblique;
  return FontStyle.normal;
}

String? _copyStringAttribute(
  MacFontBindings b,
  CFTypeRef desc,
  CFTypeRef attribute,
  Arena arena,
) {
  final s = b.ctFontDescriptorCopyAttribute(desc, attribute);
  if (s.address == 0) return null;
  try {
    return _cfStringToDart(b, s, arena);
  } finally {
    b.cfRelease(s);
  }
}

String? _copyFilePath(
  MacFontBindings b,
  CFTypeRef desc,
  Arena arena,
) {
  final url = b.ctFontDescriptorCopyAttribute(desc, b.kFontURLAttribute);
  if (url.address == 0) return null;
  try {
    // PATH_MAX on macOS is 1024 bytes; 4 KiB is a safe ceiling that also
    // handles pathological deep directory structures.
    const bufferBytes = 4096;
    final buffer = arena<Uint8>(bufferBytes);
    final ok = b.cfUrlGetFileSystemRepresentation(url, 1, buffer, bufferBytes);
    if (ok == 0) return null;
    return buffer.cast<Utf8>().toDartString();
  } finally {
    b.cfRelease(url);
  }
}

String? _copyFamilyName(
  MacFontBindings b,
  CFTypeRef desc,
  Arena arena,
) {
  final famString =
      b.ctFontDescriptorCopyAttribute(desc, b.kFontFamilyNameAttribute);
  if (famString.address == 0) return null;

  try {
    final name = _cfStringToDart(b, famString, arena);
    if (name == null || name.isEmpty) return null;
    if (name.length > kMaxFontNameLength) return null;
    // Skip Apple system-internal fonts (e.g. `.SFUI-Regular`)
    if (name.startsWith('.')) return null;
    return name;
  } finally {
    b.cfRelease(famString);
  }
}

/// Returns all five registered OpenType variation axes (`wght`, `wdth`,
/// `slnt`, `ital`, `opsz`) for a variable-font descriptor. Axes not
/// declared by the font map to `null`. Returns [_emptyAxisSet] when the
/// descriptor has no variation axes.
_AxisSet _copyAllAxes(
  MacFontBindings b,
  CFTypeRef desc,
  VariationAxisSymbols symbols,
  Arena arena,
) {
  final axesArray =
      b.ctFontDescriptorCopyAttribute(desc, symbols.axesAttribute);
  if (axesArray.address == 0) return _emptyAxisSet;

  VariationAxis? weight;
  VariationAxis? width;
  VariationAxis? slant;
  VariationAxis? italic;
  VariationAxis? opticalSize;

  try {
    final count = b.cfArrayGetCount(axesArray);
    for (var i = 0; i < count; i++) {
      final axisDict = b.cfArrayGetValueAtIndex(axesArray, i); // borrowed
      if (axisDict.address == 0) continue;

      // Identifier is a CFNumber wrapping the 4-char OpenType tag.
      // CFDictionaryGetValue returns a borrowed reference — do not release.
      final idNum = b.cfDictionaryGetValue(axisDict, symbols.identifierKey);
      if (idNum.address == 0) continue;

      final idOut = arena<Int64>();
      final ok = b.cfNumberGetValueInt64(idNum, kCFNumberSInt64Type, idOut);
      if (ok == 0) continue;
      final tag = idOut.value;

      final axis = _readAxisRange(b, axisDict, symbols, arena);
      if (axis == null) continue;

      switch (tag) {
        case kOpenTypeWghtTag:
          weight ??= axis;
          break;
        case kOpenTypeWdthTag:
          width ??= axis;
          break;
        case kOpenTypeSlntTag:
          slant ??= axis;
          break;
        case kOpenTypeItalTag:
          italic ??= axis;
          break;
        case kOpenTypeOpszTag:
          opticalSize ??= axis;
          break;
      }
    }
  } finally {
    b.cfRelease(axesArray);
  }

  return (
    weight: weight,
    width: width,
    slant: slant,
    italic: italic,
    opticalSize: opticalSize,
  );
}

/// Reads the (min, max, default) triple for a single axis dictionary.
/// Returns `null` when any of the three values is missing — treat the
/// descriptor as malformed and skip the axis.
VariationAxis? _readAxisRange(
  MacFontBindings b,
  CFTypeRef axisDict,
  VariationAxisSymbols symbols,
  Arena arena,
) {
  final min = _copyAxisDouble(b, axisDict, symbols.minKey, arena);
  final max = _copyAxisDouble(b, axisDict, symbols.maxKey, arena);
  final def = _copyAxisDouble(b, axisDict, symbols.defaultKey, arena);
  if (min == null || max == null || def == null) return null;
  return VariationAxis(
    min: min.round(),
    max: max.round(),
    defaultValue: def.round(),
  );
}

double? _copyAxisDouble(
  MacFontBindings b,
  CFTypeRef dict,
  CFTypeRef key,
  Arena arena,
) {
  final num = b.cfDictionaryGetValue(dict, key); // borrowed
  if (num.address == 0) return null;

  final out = arena<Double>();
  final ok = b.cfNumberGetValue(num, kCFNumberDoubleType, out);
  if (ok == 0) return null;
  return out.value;
}

String? _cfStringToDart(
  MacFontBindings b,
  CFTypeRef cfString,
  Arena arena,
) {
  final utf16Len = b.cfStringGetLength(cfString);
  if (utf16Len <= 0 || utf16Len > kMaxFontNameLength) return null;

  final maxSize = b.cfStringGetMaxSize(utf16Len, kCFStringEncodingUTF8);
  if (maxSize <= 0) return null;

  // +1 for null terminator
  final bufferSize = maxSize + 1;
  final buffer = arena<Uint8>(bufferSize);

  final ok =
      b.cfStringGetCString(cfString, buffer, bufferSize, kCFStringEncodingUTF8);
  if (ok == 0) return null;

  return buffer.cast<Utf8>().toDartString();
}

/// Snap a CoreText normalized weight (−1.0…1.0) to the nearest CSS weight.
///
/// Buckets follow Apple's `NSFontWeight` constants. Ties break toward the
/// lighter weight (iteration is ascending; `<` leaves ties unchanged).
/// NaN or out-of-range input falls back to 400 (Regular).
///
/// Exposed at top level so it can be unit-tested without hitting CoreText.
int mapWeight(double normalized) {
  if (normalized.isNaN) return 400;
  if (normalized < -1.0 || normalized > 1.0) return 400;

  const buckets = <_WeightBucket>[
    _WeightBucket(100, -0.80),
    _WeightBucket(200, -0.60),
    _WeightBucket(300, -0.40),
    _WeightBucket(400, 0.00),
    _WeightBucket(500, 0.23),
    _WeightBucket(600, 0.30),
    _WeightBucket(700, 0.40),
    _WeightBucket(800, 0.56),
    _WeightBucket(900, 0.62),
  ];

  var bestWeight = 400;
  var bestDist = double.infinity;
  for (final bucket in buckets) {
    final d = (normalized - bucket.normalized).abs();
    if (d < bestDist) {
      bestDist = d;
      bestWeight = bucket.cssWeight;
    }
  }
  return bestWeight;
}

class _WeightBucket {
  final int cssWeight;
  final double normalized;
  const _WeightBucket(this.cssWeight, this.normalized);
}

/// Snap a CoreText normalized width (−1.0…1.0) to the OpenType `usWidthClass`
/// scale (1 = Ultra-Condensed, 5 = Normal, 9 = Ultra-Expanded) — matching
/// DirectWrite's `DWRITE_FONT_STRETCH` range.
///
/// NaN or out-of-range input falls back to 5 (Normal).
///
/// Exposed at top level so it can be unit-tested without hitting CoreText.
int mapStretch(double normalized) {
  if (normalized.isNaN) return 5;
  if (normalized < -1.0 || normalized > 1.0) return 5;
  return (normalized * 4 + 5).round().clamp(1, 9);
}
