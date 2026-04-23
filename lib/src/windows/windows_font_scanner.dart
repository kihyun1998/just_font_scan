import 'dart:ffi';
import 'dart:io' show File, Platform;

import 'package:ffi/ffi.dart';

import '../limits.dart';
import '../models.dart';
import 'dwrite_bindings.dart';

/// Internal record bundling the five registered OpenType variation axes.
/// `null` fields mean the font does not declare that axis.
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

    final result = _getFamilyFacesAndAxes(family, arena);
    if (result.faces.isEmpty) return null;

    return FontFamily(
      name: name,
      faces: result.faces,
      weightAxis: result.axes.weight,
      widthAxis: result.axes.width,
      slantAxis: result.axes.slant,
      italicAxis: result.axes.italic,
      opticalSizeAxis: result.axes.opticalSize,
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

({List<FontFace> faces, _AxisSet axes}) _getFamilyFacesAndAxes(
  Pointer<IntPtr> family,
  Arena arena,
) {
  final fontCount = fontListGetFontCount(family).clamp(0, kMaxFontCount);
  final faces = <FontFace>[];
  var axes = _emptyAxisSet;

  for (var i = 0; i < fontCount; i++) {
    final ppFont = arena<Pointer<IntPtr>>();
    final hr = fontListGetFont(family, i, ppFont);
    if (!succeeded(hr)) continue;

    final font = ppFont.value;
    if (font.address == 0) continue;

    try {
      final face = _buildFontFace(font, arena);
      if (face != null) faces.add(face);

      // Variable font axes: take the first set encountered in the family.
      // All faces in a VF family share the same font resource and therefore
      // identical axis ranges — subsequent reads would be redundant.
      if (_axisSetIsEmpty(axes)) {
        axes = _tryReadAllAxes(font, arena);
      }
    } finally {
      comRelease(font);
    }
  }

  return (faces: faces, axes: axes);
}

FontFace? _buildFontFace(Pointer<IntPtr> font, Arena arena) {
  final weight = fontGetWeight(font);
  if (weight < kDWriteFontWeightMin || weight > kDWriteFontWeightMax) {
    return null;
  }

  final style = _dwriteStyleToEnum(fontGetStyle(font));
  final stretch = _dwriteStretchToInt(fontGetStretch(font));
  final isSymbol = fontIsSymbolFont(font) != 0;

  final faceName = _getFaceName(font, arena) ?? '';
  final postScriptName =
      _getInformationalString(font, kDWriteInfoStringPostScriptName, arena);
  final fullName =
      _getInformationalString(font, kDWriteInfoStringFullName, arena);

  final isMonospace = _tryIsMonospace(font, arena);
  final filePath = _tryGetFontFilePath(font, arena);

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

FontStyle _dwriteStyleToEnum(int raw) {
  switch (raw) {
    case kDWriteFontStyleOblique:
      return FontStyle.oblique;
    case kDWriteFontStyleItalic:
      return FontStyle.italic;
    default:
      return FontStyle.normal;
  }
}

/// `DWRITE_FONT_STRETCH` is declared as 1–9 with 0 meaning UNDEFINED.
/// Clamp defensively and map UNDEFINED to Normal (5).
int _dwriteStretchToInt(int raw) {
  if (raw < 1 || raw > 9) return 5;
  return raw;
}

String? _getFaceName(Pointer<IntPtr> font, Arena arena) {
  final ppNames = arena<Pointer<IntPtr>>();
  if (!succeeded(fontGetFaceNames(font, ppNames))) return null;

  final names = ppNames.value;
  if (names.address == 0) return null;

  try {
    return _getLocalizedString(names, arena);
  } finally {
    comRelease(names);
  }
}

String? _getInformationalString(
  Pointer<IntPtr> font,
  int stringId,
  Arena arena,
) {
  final ppStrings = arena<Pointer<IntPtr>>();
  final pExists = arena<Int32>();
  final hr = fontGetInformationalStrings(font, stringId, ppStrings, pExists);
  if (!succeeded(hr) || pExists.value == 0) return null;

  final strings = ppStrings.value;
  if (strings.address == 0) return null;

  try {
    return _getLocalizedString(strings, arena);
  } finally {
    comRelease(strings);
  }
}

/// `QueryInterface` for `IDWriteFont1`. Returns `false` on pre-Windows-8
/// builds or any COM failure — callers should treat the result as
/// "monospace unknown, assume no".
bool _tryIsMonospace(Pointer<IntPtr> font, Arena arena) {
  final ppFont1 = arena<Pointer<IntPtr>>();
  final iid = allocIIDWriteFont1(arena);
  if (!succeeded(comQueryInterface(font, iid, ppFont1))) return false;

  final font1 = ppFont1.value;
  if (font1.address == 0) return false;

  try {
    return font1IsMonospacedFont(font1) != 0;
  } finally {
    comRelease(font1);
  }
}

/// Returns the absolute path of the first font file backing [font], or
/// `null` if the face uses a non-local loader (memory / network) or any
/// COM call fails.
String? _tryGetFontFilePath(Pointer<IntPtr> font, Arena arena) {
  final ppFace = arena<Pointer<IntPtr>>();
  if (!succeeded(fontCreateFontFace(font, ppFace))) return null;
  final face = ppFace.value;
  if (face.address == 0) return null;

  try {
    return _readFacePath(face, arena);
  } finally {
    comRelease(face);
  }
}

String? _readFacePath(Pointer<IntPtr> face, Arena arena) {
  // First GetFiles call with nullptr fills the count.
  final pCount = arena<Uint32>();
  if (!succeeded(fontFaceGetFiles(face, pCount, nullptr))) return null;

  final fileCount = pCount.value.clamp(0, kMaxFilesPerFace);
  if (fileCount == 0) return null;

  // Second call retrieves file pointers.
  final files = arena<Pointer<IntPtr>>(fileCount);
  if (!succeeded(fontFaceGetFiles(face, pCount, files))) return null;

  // Use the first file; secondary files (pfb+pfm pairs) are rare in
  // modern system collections.
  final file = (files + 0).value;
  if (file.address == 0) return null;

  try {
    return _readFilePathFromFile(file, arena);
  } finally {
    // Release every file pointer returned by GetFiles.
    for (var i = 0; i < fileCount; i++) {
      final f = (files + i).value;
      if (f.address != 0) comRelease(f);
    }
  }
}

String? _readFilePathFromFile(Pointer<IntPtr> file, Arena arena) {
  final pKey = arena<Pointer<Void>>();
  final pKeySize = arena<Uint32>();
  if (!succeeded(fontFileGetReferenceKey(file, pKey, pKeySize))) {
    return null;
  }
  final key = pKey.value;
  final keySize = pKeySize.value;
  if (key.address == 0 || keySize == 0) return null;

  final ppLoader = arena<Pointer<IntPtr>>();
  if (!succeeded(fontFileGetLoader(file, ppLoader))) return null;
  final loader = ppLoader.value;
  if (loader.address == 0) return null;

  try {
    // Preferred: ask the loader directly if it is IDWriteLocalFontFileLoader.
    // Works on older Windows builds that expose the local loader.
    final ppLocal = arena<Pointer<IntPtr>>();
    final iid = allocIIDWriteLocalFontFileLoader(arena);
    if (succeeded(comQueryInterface(loader, iid, ppLocal))) {
      final local = ppLocal.value;
      if (local.address != 0) {
        try {
          final p = _readLocalFilePath(local, key, keySize, arena);
          if (p != null) return p;
        } finally {
          comRelease(local);
        }
      }
    }

    // Fallback: Windows 11's system font-cache loader refuses the QI above
    // with E_NOINTERFACE. Its reference-key layout is stable in practice:
    //   [0..7]  FILETIME       (font-file last-write time)
    //   [8..9]  UINT16         location tag (0x002A = system fonts dir)
    //   [10..]  WCHAR[]        filename + trailing NUL
    // Parse the filename out and pair it with the system fonts directory.
    return _extractPathFromSystemKey(key, keySize);
  } finally {
    comRelease(loader);
  }
}

/// Reverse-engineered parser for the Windows-11 system font-cache loader's
/// reference key. Returns the absolute path if the key matches a known
/// layout, otherwise `null`.
///
/// Two layouts observed in the wild:
///
///   A) System fonts (shipped with Windows):
///        [0..7]   FILETIME
///        [8..9]   UINT16 tag == 0x002A
///        [10..N]  WCHAR filename (no directory)
///        [N..N+1] NUL
///
///   B) User-installed or app-packaged fonts:
///        [0..7]   FILETIME
///        [8..N]   WCHAR absolute path (starts with drive letter or '\\')
///        [N..N+1] NUL
///
/// The first WCHAR at offset 8 disambiguates: 0x002A means layout A;
/// an ASCII-letter or backslash means layout B.
String? _extractPathFromSystemKey(Pointer<Void> key, int keySize) {
  const filetimeBytes = 8;
  const nulBytes = 2;
  if (keySize <= filetimeBytes + nulBytes) return null;

  final bytes = key.cast<Uint8>();
  final firstChar = (bytes + filetimeBytes).cast<Uint16>().value;

  if (firstChar == 0x002A) {
    final filenameStart = filetimeBytes + 2;
    final filenameByteCount = keySize - filenameStart - nulBytes;
    if (filenameByteCount <= 0 || filenameByteCount.isOdd) return null;

    final String filename;
    try {
      filename = (bytes + filenameStart)
          .cast<Utf16>()
          .toDartString(length: filenameByteCount ~/ 2);
    } catch (_) {
      return null;
    }
    if (filename.isEmpty || filename.contains('\\') || filename.contains('/')) {
      return null;
    }

    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final candidates = <String>[
      '$systemRoot\\Fonts\\$filename',
      if (Platform.environment['LOCALAPPDATA'] != null)
        '${Platform.environment['LOCALAPPDATA']}\\Microsoft\\Windows\\Fonts\\$filename',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return candidates.first;
  }

  // Layout B: drive letter (A–Z, a–z) or UNC '\\' prefix.
  final isDriveLetter = (firstChar >= 0x0041 && firstChar <= 0x005A) ||
      (firstChar >= 0x0061 && firstChar <= 0x007A);
  final isUncPrefix = firstChar == 0x005C;
  if (!isDriveLetter && !isUncPrefix) return null;

  final pathByteCount = keySize - filetimeBytes - nulBytes;
  if (pathByteCount <= 0 || pathByteCount.isOdd) return null;

  try {
    final path = (bytes + filetimeBytes)
        .cast<Utf16>()
        .toDartString(length: pathByteCount ~/ 2);
    if (path.isEmpty) return null;
    return path;
  } catch (_) {
    return null;
  }
}

String? _readLocalFilePath(
  Pointer<IntPtr> local,
  Pointer<Void> key,
  int keySize,
  Arena arena,
) {
  final pLength = arena<Uint32>();
  if (!succeeded(
    localLoaderGetFilePathLengthFromKey(local, key, keySize, pLength),
  )) {
    return null;
  }
  final length = pLength.value;
  if (length == 0 || length > kMaxFontPathLength) return null;

  final buffer = arena<Uint16>(length + 1).cast<Utf16>();
  if (!succeeded(
    localLoaderGetFilePathFromKey(local, key, keySize, buffer, length + 1),
  )) {
    return null;
  }
  return buffer.toDartString(length: length);
}

/// Reads all five registered OpenType variation axes (`wght`, `wdth`,
/// `slnt`, `ital`, `opsz`) from [font] if it is a variable font, otherwise
/// returns [_emptyAxisSet]. Silently swallows all COM failures — notably
/// `E_NOINTERFACE` from `QueryInterface(IDWriteFontFace5)` on Windows builds
/// older than 1803, where variable-font support is genuinely unavailable.
_AxisSet _tryReadAllAxes(Pointer<IntPtr> font, Arena arena) {
  final ppFace = arena<Pointer<IntPtr>>();
  if (!succeeded(fontCreateFontFace(font, ppFace))) return _emptyAxisSet;
  final face = ppFace.value;
  if (face.address == 0) return _emptyAxisSet;

  try {
    final ppFace5 = arena<Pointer<IntPtr>>();
    final iid = allocIIDWriteFontFace5(arena);
    final qiHr = comQueryInterface(face, iid, ppFace5);
    if (!succeeded(qiHr)) return _emptyAxisSet;
    final face5 = ppFace5.value;
    if (face5.address == 0) return _emptyAxisSet;

    try {
      if (fontFace5HasVariations(face5) == 0) return _emptyAxisSet;

      final ppResource = arena<Pointer<IntPtr>>();
      if (!succeeded(fontFace5GetFontResource(face5, ppResource))) {
        return _emptyAxisSet;
      }
      final resource = ppResource.value;
      if (resource.address == 0) return _emptyAxisSet;

      try {
        return _readAllAxesFromResource(resource, arena);
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

/// Extracts the five registered axis ranges from an `IDWriteFontResource`.
/// Any axis not declared by the font maps to `null`. Returns [_emptyAxisSet]
/// if the axis count is zero or the range fetch fails.
_AxisSet _readAllAxesFromResource(
  Pointer<IntPtr> resource,
  Arena arena,
) {
  final axisCount =
      fontResourceGetFontAxisCount(resource).clamp(0, kMaxFontAxisCount);
  if (axisCount == 0) return _emptyAxisSet;

  final ranges = arena<DWRITE_FONT_AXIS_RANGE>(axisCount);
  if (!succeeded(fontResourceGetFontAxisRanges(resource, ranges, axisCount))) {
    return _emptyAxisSet;
  }

  // Collect (min, max) by tag.
  final mins = <int, double>{};
  final maxes = <int, double>{};
  for (var i = 0; i < axisCount; i++) {
    final r = (ranges + i).ref;
    if (_isRegisteredAxisTag(r.axisTag)) {
      mins[r.axisTag] = r.minValue;
      maxes[r.axisTag] = r.maxValue;
    }
  }
  if (mins.isEmpty) return _emptyAxisSet;

  // Defaults come from a separate API and may differ from the axis midpoint.
  // If the call fails, fall back to (min+max)/2 for any axis we saw.
  final defaults = <int, double>{};
  final defaultValues = arena<DWRITE_FONT_AXIS_VALUE>(axisCount);
  if (succeeded(
    fontResourceGetDefaultFontAxisValues(resource, defaultValues, axisCount),
  )) {
    for (var i = 0; i < axisCount; i++) {
      final v = (defaultValues + i).ref;
      if (_isRegisteredAxisTag(v.axisTag)) {
        defaults[v.axisTag] = v.value;
      }
    }
  }

  VariationAxis? build(int tag) {
    final min = mins[tag];
    final max = maxes[tag];
    if (min == null || max == null) return null;
    final def = defaults[tag] ?? ((min + max) / 2);
    return VariationAxis(
      min: min.round(),
      max: max.round(),
      defaultValue: def.round(),
    );
  }

  return (
    weight: build(kDWriteFontAxisTagWeight),
    width: build(kDWriteFontAxisTagWidth),
    slant: build(kDWriteFontAxisTagSlant),
    italic: build(kDWriteFontAxisTagItalic),
    opticalSize: build(kDWriteFontAxisTagOpticalSize),
  );
}

bool _isRegisteredAxisTag(int tag) =>
    tag == kDWriteFontAxisTagWeight ||
    tag == kDWriteFontAxisTagWidth ||
    tag == kDWriteFontAxisTagSlant ||
    tag == kDWriteFontAxisTagItalic ||
    tag == kDWriteFontAxisTagOpticalSize;
