import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../models.dart';
import 'coretext_bindings.dart';

/// Scans system fonts using the CoreText API.
///
/// Best-effort: individual descriptor failures are silently skipped.
/// Returns an empty list if CoreText is unavailable or any fatal error occurs.
List<FontFamily> scanFonts() {
  try {
    return using((arena) => _scan(arena));
  } catch (_) {
    return const [];
  }
}

List<FontFamily> _scan(Arena arena) {
  final b = MacFontBindings.load();
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
  // descriptors. Clamp with 10× family limit as a sanity guard.
  final count = b.cfArrayGetCount(array).clamp(0, kMaxFontFamilyCount * 10);

  final weightsByFamily = <String, Set<int>>{};

  for (var i = 0; i < count; i++) {
    final desc = b.cfArrayGetValueAtIndex(array, i); // borrowed
    if (desc.address == 0) continue;
    _scanDescriptor(b, desc, weightsByFamily, arena);
  }

  final families = <FontFamily>[];
  for (final entry in weightsByFamily.entries) {
    final weights = entry.value.toList()..sort();
    families.add(FontFamily(name: entry.key, weights: weights));
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
  Map<String, Set<int>> acc,
  Arena arena,
) {
  final name = _copyFamilyName(b, desc, arena);
  if (name == null) return;

  final weight = _copyWeight(b, desc, arena);
  acc.putIfAbsent(name, () => <int>{}).add(weight);
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
  final traits =
      b.ctFontDescriptorCopyAttribute(desc, b.kFontTraitsAttribute);
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
