import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../limits.dart';
import '../models.dart';
import 'dwrite_bindings.dart';

/// Scans system fonts using DirectWrite COM API.
///
/// Best-effort: individual family failures are silently skipped.
/// Returns an empty list if DirectWrite is unavailable or any fatal error occurs.
List<FontFamily> scanFonts() {
  try {
    return using((arena) => _scanFontsWithArena(arena));
  } catch (_) {
    return const [];
  }
}

List<FontFamily> _scanFontsWithArena(Arena arena) {
  final ole32 = loadOle32();
  final dwrite = loadDWrite();

  // CoInitializeEx — S_OK (0) or S_FALSE (1) means success.
  // RPC_E_CHANGED_MODE means already in a different apartment; proceed anyway.
  final coInitializeEx =
      ole32.lookupFunction<CoInitializeExNative, CoInitializeExDart>(
    'CoInitializeEx',
  );
  final coUninitialize =
      ole32.lookupFunction<CoUninitializeNative, CoUninitializeDart>(
    'CoUninitialize',
  );

  final hrInit = coInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  // Only uninitialize if we actually initialized (S_OK=0 or S_FALSE=1).
  final shouldUninitialize = hrInit == 0 || hrInit == 1;

  try {
    return _createFactoryAndScan(dwrite, arena);
  } finally {
    if (shouldUninitialize) {
      coUninitialize();
    }
  }
}

List<FontFamily> _createFactoryAndScan(DynamicLibrary dwrite, Arena arena) {
  final createFactory =
      dwrite.lookupFunction<DWriteCreateFactoryNative, DWriteCreateFactoryDart>(
    'DWriteCreateFactory',
  );

  final iid = allocIIDWriteFactory(arena);
  final ppFactory = arena<Pointer<IntPtr>>();

  var hr = createFactory(DWRITE_FACTORY_TYPE_SHARED, iid, ppFactory);
  if (!succeeded(hr)) return const [];

  final factory = ppFactory.value;
  if (factory.address == 0) return const [];

  try {
    return _scanWithFactory(factory, arena);
  } finally {
    comRelease(factory);
  }
}

List<FontFamily> _scanWithFactory(Pointer<IntPtr> factory, Arena arena) {
  final ppCollection = arena<Pointer<IntPtr>>();
  var hr = factoryGetSystemFontCollection(factory, ppCollection);
  if (!succeeded(hr)) return const [];

  final collection = ppCollection.value;
  if (collection.address == 0) return const [];

  try {
    return _scanCollection(collection, arena);
  } finally {
    comRelease(collection);
  }
}

List<FontFamily> _scanCollection(
  Pointer<IntPtr> collection,
  Arena arena,
) {
  final familyCount =
      collectionGetFontFamilyCount(collection).clamp(0, kMaxFontFamilyCount);
  final families = <FontFamily>[];

  for (var i = 0; i < familyCount; i++) {
    final family = _scanFamily(collection, i, arena);
    if (family != null) {
      families.add(family);
    }
  }

  families.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return families;
}

FontFamily? _scanFamily(
  Pointer<IntPtr> collection,
  int index,
  Arena arena,
) {
  final ppFamily = arena<Pointer<IntPtr>>();
  var hr = collectionGetFontFamily(collection, index, ppFamily);
  if (!succeeded(hr)) return null;

  final family = ppFamily.value;
  if (family.address == 0) return null;

  try {
    final name = _getFamilyName(family, arena);
    if (name == null || name.isEmpty) return null;

    // Skip vertical writing fonts
    if (name.startsWith('@')) return null;

    final result = _getFamilyWeightsAndAxis(family, arena);
    if (result.weights.isEmpty) return null;

    return FontFamily(
      name: name,
      weights: result.weights,
      weightAxis: result.axis,
    );
  } finally {
    comRelease(family);
  }
}

String? _getFamilyName(Pointer<IntPtr> family, Arena arena) {
  final ppNames = arena<Pointer<IntPtr>>();
  var hr = fontFamilyGetFamilyNames(family, ppNames);
  if (!succeeded(hr)) return null;

  final names = ppNames.value;
  if (names.address == 0) return null;

  try {
    return _getLocalizedString(names, arena);
  } finally {
    comRelease(names);
  }
}

String? _getLocalizedString(Pointer<IntPtr> strings, Arena arena) {
  final pIndex = arena<Uint32>();
  final pExists = arena<Int32>();

  // Try "en-us" first
  final enUs = 'en-us'.toNativeUtf16(allocator: arena);
  var hr = localizedStringsFindLocaleName(strings, enUs, pIndex, pExists);

  int nameIndex;
  if (succeeded(hr) && pExists.value != 0) {
    nameIndex = pIndex.value;
  } else {
    final count = localizedStringsGetCount(strings);
    if (count == 0) return null;
    nameIndex = 0;
  }

  // Get string length
  final pLength = arena<Uint32>();
  hr = localizedStringsGetStringLength(strings, nameIndex, pLength);
  if (!succeeded(hr)) return null;

  final length = pLength.value;
  if (length == 0 || length > kMaxFontNameLength) return null;

  // Get string (length + 1 for null terminator)
  final buffer = arena<Uint16>(length + 1).cast<Utf16>();
  hr = localizedStringsGetString(strings, nameIndex, buffer, length + 1);
  if (!succeeded(hr)) return null;

  return buffer.toDartString(length: length);
}

({List<int> weights, WeightAxis? axis}) _getFamilyWeightsAndAxis(
  Pointer<IntPtr> family,
  Arena arena,
) {
  final fontCount = fontListGetFontCount(family).clamp(0, kMaxFontCount);
  final weightSet = <int>{};
  WeightAxis? axis;

  for (var i = 0; i < fontCount; i++) {
    final ppFont = arena<Pointer<IntPtr>>();
    final hr = fontListGetFont(family, i, ppFont);
    if (!succeeded(hr)) continue;

    final font = ppFont.value;
    if (font.address == 0) continue;

    try {
      final weight = fontGetWeight(font);
      if (weight >= kDWriteFontWeightMin && weight <= kDWriteFontWeightMax) {
        weightSet.add(weight);
      }

      // Variable font axis: take the first wght axis encountered in the
      // family. Multiple faces in a VF family share the same resource and
      // therefore the same axis range, so subsequent extractions would be
      // redundant work.
      axis ??= _tryReadWghtAxis(font, arena);
    } finally {
      comRelease(font);
    }
  }

  final weights = weightSet.toList()..sort();
  return (weights: weights, axis: axis);
}

/// Reads the `wght` variation-axis range of [font] if it is a variable
/// font, otherwise returns `null`. Silently swallows all COM failures —
/// notably `E_NOINTERFACE` from `QueryInterface(IDWriteFontFace5)` on
/// Windows builds older than 1803, where variable-font support is
/// genuinely unavailable.
WeightAxis? _tryReadWghtAxis(Pointer<IntPtr> font, Arena arena) {
  final ppFace = arena<Pointer<IntPtr>>();
  if (!succeeded(fontCreateFontFace(font, ppFace))) return null;
  final face = ppFace.value;
  if (face.address == 0) return null;

  try {
    final ppFace5 = arena<Pointer<IntPtr>>();
    final iid = allocIIDWriteFontFace5(arena);
    final qiHr = comQueryInterface(face, iid, ppFace5);
    if (!succeeded(qiHr)) return null;
    final face5 = ppFace5.value;
    if (face5.address == 0) return null;

    try {
      if (fontFace5HasVariations(face5) == 0) return null;

      final ppResource = arena<Pointer<IntPtr>>();
      if (!succeeded(fontFace5GetFontResource(face5, ppResource))) {
        return null;
      }
      final resource = ppResource.value;
      if (resource.address == 0) return null;

      try {
        return _readWghtAxisFromResource(resource, arena);
      } finally {
        comRelease(resource);
      }
    } finally {
      comRelease(face5);
    }
  } finally {
    comRelease(face);
  }
}

/// Extracts the `wght` axis range and default value from an
/// `IDWriteFontResource`. Returns `null` if the font has no `wght` axis
/// or any of the COM calls fail.
WeightAxis? _readWghtAxisFromResource(
  Pointer<IntPtr> resource,
  Arena arena,
) {
  final axisCount =
      fontResourceGetFontAxisCount(resource).clamp(0, kMaxFontAxisCount);
  if (axisCount == 0) return null;

  final ranges = arena<DWRITE_FONT_AXIS_RANGE>(axisCount);
  if (!succeeded(fontResourceGetFontAxisRanges(resource, ranges, axisCount))) {
    return null;
  }

  var min = 0.0;
  var max = 0.0;
  var found = false;
  for (var i = 0; i < axisCount; i++) {
    final r = (ranges + i).ref;
    if (r.axisTag == kDWriteFontAxisTagWeight) {
      min = r.minValue;
      max = r.maxValue;
      found = true;
      break;
    }
  }
  if (!found) return null;

  // Default value comes from a separate API and may differ from the
  // axis midpoint. If the call fails, fall back to the range midpoint
  // so callers still get a usable hint.
  var def = ((min + max) / 2);
  final defaults = arena<DWRITE_FONT_AXIS_VALUE>(axisCount);
  if (succeeded(
    fontResourceGetDefaultFontAxisValues(resource, defaults, axisCount),
  )) {
    for (var i = 0; i < axisCount; i++) {
      final v = (defaults + i).ref;
      if (v.axisTag == kDWriteFontAxisTagWeight) {
        def = v.value;
        break;
      }
    }
  }

  return WeightAxis(
    min: min.round(),
    max: max.round(),
    defaultValue: def.round(),
  );
}
