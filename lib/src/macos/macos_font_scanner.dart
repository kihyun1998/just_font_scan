import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../limits.dart';
import '../models.dart';
import 'coretext_bindings.dart';

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

  final weightsByFamily = <String, Set<int>>{};
  final axisByFamily = <String, WeightAxis>{};

  for (var i = 0; i < count; i++) {
    final desc = b.cfArrayGetValueAtIndex(array, i); // borrowed
    if (desc.address == 0) continue;
    _scanDescriptor(b, desc, weightsByFamily, axisByFamily, arena);
  }

  final families = <FontFamily>[];
  for (final entry in weightsByFamily.entries) {
    final weights = entry.value.toList()..sort();
    families.add(FontFamily(
      name: entry.key,
      weights: weights,
      weightAxis: axisByFamily[entry.key],
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
  Map<String, Set<int>> weightsAcc,
  Map<String, WeightAxis> axisAcc,
  Arena arena,
) {
  final name = _copyFamilyName(b, desc, arena);
  if (name == null) return;

  final weight = _copyWeight(b, desc, arena);
  weightsAcc.putIfAbsent(name, () => <int>{}).add(weight);

  // Extract the variable-font wght axis at most once per family. Italic
  // and roman descriptors of the same VF report identical axis ranges in
  // practice, so the first non-null hit wins.
  if (axisAcc.containsKey(name)) return;
  final symbols = b.variationAxes;
  if (symbols == null) return;

  final axis = _copyWghtAxis(b, desc, symbols, arena);
  if (axis != null) {
    axisAcc[name] = axis;
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

int _copyWeight(
  MacFontBindings b,
  CFTypeRef desc,
  Arena arena,
) {
  final traits = b.ctFontDescriptorCopyAttribute(desc, b.kFontTraitsAttribute);
  if (traits.address == 0) return 400;

  try {
    // CFDictionaryGetValue returns a borrowed reference — do not release.
    final weightNum = b.cfDictionaryGetValue(traits, b.kFontWeightTrait);
    if (weightNum.address == 0) return 400;

    final out = arena<Double>();
    final ok = b.cfNumberGetValue(weightNum, kCFNumberDoubleType, out);
    if (ok == 0) return 400;

    return mapWeight(out.value);
  } finally {
    b.cfRelease(traits);
  }
}

/// Returns the `wght` axis range for a variable-font descriptor, or
/// `null` if the descriptor is not a variable font or has no `wght` axis.
WeightAxis? _copyWghtAxis(
  MacFontBindings b,
  CFTypeRef desc,
  VariationAxisSymbols symbols,
  Arena arena,
) {
  final axesArray =
      b.ctFontDescriptorCopyAttribute(desc, symbols.axesAttribute);
  if (axesArray.address == 0) return null;

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
      if (idOut.value != kOpenTypeWghtTag) continue;

      // Found wght — pull min/max/default. If any is missing the
      // descriptor is malformed; skip the axis entirely.
      final min = _copyAxisDouble(b, axisDict, symbols.minKey, arena);
      final max = _copyAxisDouble(b, axisDict, symbols.maxKey, arena);
      final def = _copyAxisDouble(b, axisDict, symbols.defaultKey, arena);
      if (min == null || max == null || def == null) return null;

      return WeightAxis(
        min: min.round(),
        max: max.round(),
        defaultValue: def.round(),
      );
    }
    return null;
  } finally {
    b.cfRelease(axesArray);
  }
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
