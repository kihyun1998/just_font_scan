// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// CoreFoundation / CoreText bindings follow Apple naming conventions:
// types use PascalCase (CFStringRef, CTFontDescriptorRef) and constants use
// k-prefixed camelCase (kCTFontWeightTrait), which conflict with Dart lints.

import 'dart:ffi';

import '../limits.dart';

// --- macOS-specific limits ---

/// Max CoreText font descriptor count (face-level entries, not families).
/// Each family typically contributes 1–20 descriptors, so ~10× the family
/// limit is a comfortable sanity cap.
const int kMaxDescriptorCount = kMaxFontFamilyCount * 10;

// --- CF type aliases ---

/// All CoreFoundation/CoreText reference types are opaque pointers.
/// `CFArrayRef`, `CFDictionaryRef`, `CFStringRef`, `CFNumberRef`,
/// `CTFontCollectionRef`, `CTFontDescriptorRef` all map to `Pointer<Void>`.
typedef CFTypeRef = Pointer<Void>;

// --- CF enum constants ---

/// `kCFStringEncodingUTF8` (CFStringBuiltInEncodings).
const int kCFStringEncodingUTF8 = 0x08000100;

/// `kCFNumberDoubleType` — matches the C `double` type.
/// Dart's `double` is IEEE-754 64-bit, which is ABI-compatible.
const int kCFNumberDoubleType = 13;

/// `kCFNumberSInt32Type` — 4-byte signed integer. Used for reading the
/// `CTFontSymbolicTraits` bitmask (defined as `uint32_t` in CoreText).
const int kCFNumberSInt32Type = 3;

/// `kCFNumberSInt64Type` — 8-byte signed integer.
/// Used for reading variation axis identifiers (4-char OpenType tags
/// stored as 32-bit ints; SInt64 is wide enough with no precision loss).
const int kCFNumberSInt64Type = 4;

/// OpenType `'wght'` axis tag as a big-endian FourCC integer
/// (`'w'`<<24 | `'g'`<<16 | `'h'`<<8 | `'t'`).
const int kOpenTypeWghtTag = 0x77676874;

/// OpenType `'wdth'` axis tag (big-endian FourCC).
const int kOpenTypeWdthTag = 0x77647468;

/// OpenType `'slnt'` axis tag (big-endian FourCC).
/// `slnt` values are typically negative degrees.
const int kOpenTypeSlntTag = 0x736c6e74;

/// OpenType `'ital'` axis tag (big-endian FourCC).
const int kOpenTypeItalTag = 0x6974616c;

/// OpenType `'opsz'` axis tag (big-endian FourCC). Values are in points.
const int kOpenTypeOpszTag = 0x6f70737a;

// --- CTFontSymbolicTraits bit masks ---
// Values from `<CoreText/CTFontDescriptor.h>`. The top 4 bits encode the
// stylistic class; the lower bits are independent trait flags.

/// `kCTFontTraitItalic` — face is italic (designed or marked as italic).
const int kCTFontTraitItalic = 1 << 0;

/// `kCTFontTraitBold` — face is bold weight.
const int kCTFontTraitBold = 1 << 1;

/// `kCTFontTraitExpanded` — expanded width.
const int kCTFontTraitExpanded = 1 << 5;

/// `kCTFontTraitCondensed` — condensed width.
const int kCTFontTraitCondensed = 1 << 6;

/// `kCTFontTraitMonoSpace` — every glyph has the same advance width.
const int kCTFontTraitMonoSpace = 1 << 10;

/// Mask covering the top-4-bits stylistic class field.
const int kCTFontClassMaskTrait = 0xF << 28;

/// `kCTFontClassSymbolic` — the face is a symbol/dingbat font.
const int kCTFontClassSymbolic = 12 << 28;

// --- DynamicLibrary loaders (absolute framework paths; mirrors Windows System32 policy) ---

DynamicLibrary _loadCoreFoundation() => DynamicLibrary.open(
      '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
    );

DynamicLibrary _loadCoreText() => DynamicLibrary.open(
      '/System/Library/Frameworks/CoreText.framework/CoreText',
    );

DynamicLibrary _loadObjc() => DynamicLibrary.open('/usr/lib/libobjc.A.dylib');

// --- CoreFoundation function typedefs ---

typedef _CFReleaseNative = Void Function(CFTypeRef);
typedef _CFReleaseDart = void Function(CFTypeRef);

typedef _CFArrayGetCountNative = IntPtr Function(CFTypeRef);
typedef CFArrayGetCountDart = int Function(CFTypeRef);

typedef _CFArrayGetValueAtIndexNative = CFTypeRef Function(CFTypeRef, IntPtr);
typedef CFArrayGetValueAtIndexDart = CFTypeRef Function(CFTypeRef, int);

typedef _CFDictionaryGetValueNative = CFTypeRef Function(CFTypeRef, CFTypeRef);
typedef CFDictionaryGetValueDart = CFTypeRef Function(CFTypeRef, CFTypeRef);

typedef _CFStringGetLengthNative = IntPtr Function(CFTypeRef);
typedef CFStringGetLengthDart = int Function(CFTypeRef);

typedef _CFStringGetMaximumSizeForEncodingNative = IntPtr Function(
  IntPtr length,
  Uint32 encoding,
);
typedef CFStringGetMaximumSizeForEncodingDart = int Function(
  int length,
  int encoding,
);

typedef _CFStringGetCStringNative = Uint8 Function(
  CFTypeRef theString,
  Pointer<Uint8> buffer,
  IntPtr bufferSize,
  Uint32 encoding,
);
typedef _CFStringGetCStringDart = int Function(
  CFTypeRef theString,
  Pointer<Uint8> buffer,
  int bufferSize,
  int encoding,
);

typedef _CFNumberGetValueNative = Uint8 Function(
  CFTypeRef number,
  IntPtr type,
  Pointer<Double> valuePtr,
);
typedef _CFNumberGetValueDart = int Function(
  CFTypeRef number,
  int type,
  Pointer<Double> valuePtr,
);

// Same C function (`CFNumberGetValue`) but typed for a 64-bit integer
// out-pointer. The C signature takes `void*`; Dart FFI requires us to
// commit to a concrete pointer type, so we resolve the symbol twice with
// different typedefs rather than casting at call sites.
typedef _CFNumberGetValueInt64Native = Uint8 Function(
  CFTypeRef number,
  IntPtr type,
  Pointer<Int64> valuePtr,
);
typedef _CFNumberGetValueInt64Dart = int Function(
  CFTypeRef number,
  int type,
  Pointer<Int64> valuePtr,
);

// Int32 overload of `CFNumberGetValue` — used for `CTFontSymbolicTraits`,
// which CoreText stores as a `uint32_t` inside the traits dictionary.
typedef _CFNumberGetValueInt32Native = Uint8 Function(
  CFTypeRef number,
  IntPtr type,
  Pointer<Int32> valuePtr,
);
typedef _CFNumberGetValueInt32Dart = int Function(
  CFTypeRef number,
  int type,
  Pointer<Int32> valuePtr,
);

typedef _CFURLGetFileSystemRepresentationNative = Uint8 Function(
  CFTypeRef url,
  Uint8 resolveAgainstBase,
  Pointer<Uint8> buffer,
  IntPtr maxBufLen,
);
typedef _CFURLGetFileSystemRepresentationDart = int Function(
  CFTypeRef url,
  int resolveAgainstBase,
  Pointer<Uint8> buffer,
  int maxBufLen,
);

// --- CoreText function typedefs ---

typedef _CTFontCollectionCreateFromAvailableFontsNative = CFTypeRef Function(
  CFTypeRef options,
);
typedef CTFontCollectionCreateFromAvailableFontsDart = CFTypeRef Function(
  CFTypeRef options,
);

typedef _CTFontCollectionCreateMatchingFontDescriptorsNative = CFTypeRef
    Function(CFTypeRef collection);
typedef CTFontCollectionCreateMatchingFontDescriptorsDart = CFTypeRef Function(
  CFTypeRef collection,
);

typedef _CTFontDescriptorCopyAttributeNative = CFTypeRef Function(
  CFTypeRef descriptor,
  CFTypeRef attribute,
);
typedef CTFontDescriptorCopyAttributeDart = CFTypeRef Function(
  CFTypeRef descriptor,
  CFTypeRef attribute,
);

// --- libobjc autorelease pool (for draining CoreText-internal autoreleased
// NSString / NSDictionary / NSNumber objects — a Dart CLI has no Cocoa
// runloop, so without an explicit pool these accumulate until process exit). ---

typedef _ObjcPoolPushNative = Pointer<Void> Function();
typedef ObjcPoolPushDart = Pointer<Void> Function();

typedef _ObjcPoolPopNative = Void Function(Pointer<Void>);
typedef ObjcPoolPopDart = void Function(Pointer<Void>);

// --- Bindings holder ---

/// Bundle of the five extern `CFStringRef` constants needed to read
/// OpenType variation axis metadata from a `CTFontDescriptor`.
///
/// Held as a single nullable group on [MacFontBindings] so the scanner
/// can degrade gracefully — if any symbol fails to resolve (extremely
/// unlikely, since all five have shipped since macOS 10.5), the whole
/// group becomes null and variable-font detection is silently skipped
/// without breaking the rest of the scan.
class VariationAxisSymbols {
  /// `CFStringRef kCTFontVariationAxesAttribute` —
  /// descriptor attribute returning a `CFArrayRef<CFDictionaryRef>`.
  final CFTypeRef axesAttribute;

  /// `CFStringRef kCTFontVariationAxisIdentifierKey` —
  /// dict key for the axis tag (CFNumber wrapping a 32-bit FourCC).
  final CFTypeRef identifierKey;

  /// `CFStringRef kCTFontVariationAxisMinimumValueKey` —
  /// dict key for the axis lower bound (CFNumber, double).
  final CFTypeRef minKey;

  /// `CFStringRef kCTFontVariationAxisMaximumValueKey` —
  /// dict key for the axis upper bound (CFNumber, double).
  final CFTypeRef maxKey;

  /// `CFStringRef kCTFontVariationAxisDefaultValueKey` —
  /// dict key for the axis default value (CFNumber, double).
  final CFTypeRef defaultKey;

  const VariationAxisSymbols({
    required this.axesAttribute,
    required this.identifierKey,
    required this.minKey,
    required this.maxKey,
    required this.defaultKey,
  });
}

/// Resolved CoreFoundation + CoreText symbols for a single scan session.
///
/// The three extern `CFStringRef` constants
/// (`kCTFontFamilyNameAttribute`, `kCTFontTraitsAttribute`, `kCTFontWeightTrait`)
/// are global variables, not functions. They must be resolved via
/// `lookup<Pointer<CFTypeRef>>(...).value` and cached for the scan's lifetime.
class MacFontBindings {
  // CoreFoundation
  final _CFReleaseDart _cfRelease;
  final CFArrayGetCountDart cfArrayGetCount;
  final CFArrayGetValueAtIndexDart cfArrayGetValueAtIndex;
  final CFDictionaryGetValueDart cfDictionaryGetValue;
  final CFStringGetLengthDart cfStringGetLength;
  final CFStringGetMaximumSizeForEncodingDart cfStringGetMaxSize;
  final _CFStringGetCStringDart _cfStringGetCString;
  final _CFNumberGetValueDart _cfNumberGetValue;
  final _CFNumberGetValueInt64Dart _cfNumberGetValueInt64;
  final _CFNumberGetValueInt32Dart _cfNumberGetValueInt32;
  final _CFURLGetFileSystemRepresentationDart _cfUrlGetFileSystemRepresentation;

  // CoreText
  final CTFontCollectionCreateFromAvailableFontsDart
      ctFontCollectionCreateFromAvailable;
  final CTFontCollectionCreateMatchingFontDescriptorsDart
      ctFontCollectionCreateMatching;
  final CTFontDescriptorCopyAttributeDart ctFontDescriptorCopyAttribute;

  // libobjc
  final ObjcPoolPushDart _objcPoolPush;
  final ObjcPoolPopDart _objcPoolPop;

  /// `CFStringRef kCTFontFamilyNameAttribute`
  final CFTypeRef kFontFamilyNameAttribute;

  /// `CFStringRef kCTFontTraitsAttribute`
  final CFTypeRef kFontTraitsAttribute;

  /// `CFStringRef kCTFontWeightTrait`
  final CFTypeRef kFontWeightTrait;

  /// `CFStringRef kCTFontWidthTrait` — stretch in [−1.0 … 1.0].
  final CFTypeRef kFontWidthTrait;

  /// `CFStringRef kCTFontSlantTrait` — italic slant in [−1.0 … 1.0];
  /// positive values lean right.
  final CFTypeRef kFontSlantTrait;

  /// `CFStringRef kCTFontSymbolicTrait` — `CTFontSymbolicTraits` bitmask.
  final CFTypeRef kFontSymbolicTrait;

  /// `CFStringRef kCTFontNameAttribute` — PostScript name.
  final CFTypeRef kFontNameAttribute;

  /// `CFStringRef kCTFontDisplayNameAttribute` — human-readable full name.
  final CFTypeRef kFontDisplayNameAttribute;

  /// `CFStringRef kCTFontStyleNameAttribute` — sub-family ("Regular",
  /// "Bold Italic", …).
  final CFTypeRef kFontStyleNameAttribute;

  /// `CFStringRef kCTFontURLAttribute` — CFURLRef for the backing file.
  final CFTypeRef kFontURLAttribute;

  /// Variation-axis-related symbols, or `null` if any failed to resolve
  /// (treat as "variable font support unavailable on this system").
  final VariationAxisSymbols? variationAxes;

  MacFontBindings._({
    required _CFReleaseDart cfRelease,
    required this.cfArrayGetCount,
    required this.cfArrayGetValueAtIndex,
    required this.cfDictionaryGetValue,
    required this.cfStringGetLength,
    required this.cfStringGetMaxSize,
    required _CFStringGetCStringDart cfStringGetCString,
    required _CFNumberGetValueDart cfNumberGetValue,
    required _CFNumberGetValueInt64Dart cfNumberGetValueInt64,
    required _CFNumberGetValueInt32Dart cfNumberGetValueInt32,
    required _CFURLGetFileSystemRepresentationDart
        cfUrlGetFileSystemRepresentation,
    required this.ctFontCollectionCreateFromAvailable,
    required this.ctFontCollectionCreateMatching,
    required this.ctFontDescriptorCopyAttribute,
    required ObjcPoolPushDart objcPoolPush,
    required ObjcPoolPopDart objcPoolPop,
    required this.kFontFamilyNameAttribute,
    required this.kFontTraitsAttribute,
    required this.kFontWeightTrait,
    required this.kFontWidthTrait,
    required this.kFontSlantTrait,
    required this.kFontSymbolicTrait,
    required this.kFontNameAttribute,
    required this.kFontDisplayNameAttribute,
    required this.kFontStyleNameAttribute,
    required this.kFontURLAttribute,
    required this.variationAxes,
  })  : _cfRelease = cfRelease,
        _cfStringGetCString = cfStringGetCString,
        _cfNumberGetValue = cfNumberGetValue,
        _cfNumberGetValueInt64 = cfNumberGetValueInt64,
        _cfNumberGetValueInt32 = cfNumberGetValueInt32,
        _cfUrlGetFileSystemRepresentation = cfUrlGetFileSystemRepresentation,
        _objcPoolPush = objcPoolPush,
        _objcPoolPop = objcPoolPop;

  static MacFontBindings? _cached;

  /// Lazily-initialized shared instance for the current isolate.
  ///
  /// Reuses the same resolved symbols across scans to avoid redundant
  /// `DynamicLibrary.open` and `lookupFunction` calls. If the initial load
  /// throws, `_cached` stays null, so the next call retries rather than
  /// negatively caching the failure.
  static MacFontBindings get instance => _cached ??= load();

  /// Loads both frameworks, resolves all symbols, and dereferences the three
  /// extern `CFStringRef` constants. Prefer [instance] for repeated use —
  /// this factory always performs a fresh load.
  ///
  /// Throws if a required symbol cannot be resolved — callers should wrap in
  /// `try/catch` and treat failure as "return empty list".
  static MacFontBindings load() {
    final cf = _loadCoreFoundation();
    final ct = _loadCoreText();
    final objc = _loadObjc();

    // The extern symbol's address points to a CFStringRef variable.
    // Lookup with T=CFTypeRef gives Pointer<CFTypeRef>; .value reads the
    // variable's contents (the actual CFStringRef).
    final famRef = ct.lookup<CFTypeRef>('kCTFontFamilyNameAttribute').value;
    final traitsRef = ct.lookup<CFTypeRef>('kCTFontTraitsAttribute').value;
    final weightRef = ct.lookup<CFTypeRef>('kCTFontWeightTrait').value;
    final widthRef = ct.lookup<CFTypeRef>('kCTFontWidthTrait').value;
    final slantRef = ct.lookup<CFTypeRef>('kCTFontSlantTrait').value;
    final symbolicRef = ct.lookup<CFTypeRef>('kCTFontSymbolicTrait').value;
    final nameRef = ct.lookup<CFTypeRef>('kCTFontNameAttribute').value;
    final displayRef =
        ct.lookup<CFTypeRef>('kCTFontDisplayNameAttribute').value;
    final styleRef = ct.lookup<CFTypeRef>('kCTFontStyleNameAttribute').value;
    final urlRef = ct.lookup<CFTypeRef>('kCTFontURLAttribute').value;

    if (famRef.address == 0 ||
        traitsRef.address == 0 ||
        weightRef.address == 0 ||
        widthRef.address == 0 ||
        slantRef.address == 0 ||
        symbolicRef.address == 0 ||
        nameRef.address == 0 ||
        displayRef.address == 0 ||
        styleRef.address == 0 ||
        urlRef.address == 0) {
      throw StateError(
        'CoreText extern CFStringRef constant resolved to null',
      );
    }

    // Variation-axis symbols are optional. All five have shipped since
    // macOS 10.5, but if any lookup fails or any address is 0 we fall
    // back to "no variable font support" rather than aborting the scan.
    final variationAxes = _loadVariationAxisSymbols(ct);

    return MacFontBindings._(
      cfRelease:
          cf.lookupFunction<_CFReleaseNative, _CFReleaseDart>('CFRelease'),
      cfArrayGetCount:
          cf.lookupFunction<_CFArrayGetCountNative, CFArrayGetCountDart>(
              'CFArrayGetCount'),
      cfArrayGetValueAtIndex: cf.lookupFunction<_CFArrayGetValueAtIndexNative,
          CFArrayGetValueAtIndexDart>('CFArrayGetValueAtIndex'),
      cfDictionaryGetValue: cf.lookupFunction<_CFDictionaryGetValueNative,
          CFDictionaryGetValueDart>('CFDictionaryGetValue'),
      cfStringGetLength:
          cf.lookupFunction<_CFStringGetLengthNative, CFStringGetLengthDart>(
              'CFStringGetLength'),
      cfStringGetMaxSize: cf.lookupFunction<
          _CFStringGetMaximumSizeForEncodingNative,
          CFStringGetMaximumSizeForEncodingDart>(
        'CFStringGetMaximumSizeForEncoding',
      ),
      cfStringGetCString:
          cf.lookupFunction<_CFStringGetCStringNative, _CFStringGetCStringDart>(
              'CFStringGetCString'),
      cfNumberGetValue:
          cf.lookupFunction<_CFNumberGetValueNative, _CFNumberGetValueDart>(
              'CFNumberGetValue'),
      cfNumberGetValueInt64: cf.lookupFunction<_CFNumberGetValueInt64Native,
          _CFNumberGetValueInt64Dart>('CFNumberGetValue'),
      cfNumberGetValueInt32: cf.lookupFunction<_CFNumberGetValueInt32Native,
          _CFNumberGetValueInt32Dart>('CFNumberGetValue'),
      cfUrlGetFileSystemRepresentation: cf.lookupFunction<
          _CFURLGetFileSystemRepresentationNative,
          _CFURLGetFileSystemRepresentationDart>(
        'CFURLGetFileSystemRepresentation',
      ),
      ctFontCollectionCreateFromAvailable: ct.lookupFunction<
          _CTFontCollectionCreateFromAvailableFontsNative,
          CTFontCollectionCreateFromAvailableFontsDart>(
        'CTFontCollectionCreateFromAvailableFonts',
      ),
      ctFontCollectionCreateMatching: ct.lookupFunction<
          _CTFontCollectionCreateMatchingFontDescriptorsNative,
          CTFontCollectionCreateMatchingFontDescriptorsDart>(
        'CTFontCollectionCreateMatchingFontDescriptors',
      ),
      ctFontDescriptorCopyAttribute: ct.lookupFunction<
          _CTFontDescriptorCopyAttributeNative,
          CTFontDescriptorCopyAttributeDart>(
        'CTFontDescriptorCopyAttribute',
      ),
      objcPoolPush: objc.lookupFunction<_ObjcPoolPushNative, ObjcPoolPushDart>(
        'objc_autoreleasePoolPush',
      ),
      objcPoolPop: objc.lookupFunction<_ObjcPoolPopNative, ObjcPoolPopDart>(
        'objc_autoreleasePoolPop',
      ),
      kFontFamilyNameAttribute: famRef,
      kFontTraitsAttribute: traitsRef,
      kFontWeightTrait: weightRef,
      kFontWidthTrait: widthRef,
      kFontSlantTrait: slantRef,
      kFontSymbolicTrait: symbolicRef,
      kFontNameAttribute: nameRef,
      kFontDisplayNameAttribute: displayRef,
      kFontStyleNameAttribute: styleRef,
      kFontURLAttribute: urlRef,
      variationAxes: variationAxes,
    );
  }

  static VariationAxisSymbols? _loadVariationAxisSymbols(DynamicLibrary ct) {
    try {
      final axesRef =
          ct.lookup<CFTypeRef>('kCTFontVariationAxesAttribute').value;
      final idRef =
          ct.lookup<CFTypeRef>('kCTFontVariationAxisIdentifierKey').value;
      final minRef =
          ct.lookup<CFTypeRef>('kCTFontVariationAxisMinimumValueKey').value;
      final maxRef =
          ct.lookup<CFTypeRef>('kCTFontVariationAxisMaximumValueKey').value;
      final defRef =
          ct.lookup<CFTypeRef>('kCTFontVariationAxisDefaultValueKey').value;

      if (axesRef.address == 0 ||
          idRef.address == 0 ||
          minRef.address == 0 ||
          maxRef.address == 0 ||
          defRef.address == 0) {
        return null;
      }

      return VariationAxisSymbols(
        axesAttribute: axesRef,
        identifierKey: idRef,
        minKey: minRef,
        maxKey: maxRef,
        defaultKey: defRef,
      );
    } catch (_) {
      return null;
    }
  }

  /// Null-safe wrapper for `CFRelease` — skips when the pointer is null so
  /// partial-failure cleanup paths don't crash the process.
  void cfRelease(CFTypeRef ref) {
    if (ref.address == 0) return;
    _cfRelease(ref);
  }

  /// Calls `CFStringGetCString`, returning 0/1.
  int cfStringGetCString(
    CFTypeRef theString,
    Pointer<Uint8> buffer,
    int bufferSize,
    int encoding,
  ) =>
      _cfStringGetCString(theString, buffer, bufferSize, encoding);

  /// Calls `CFNumberGetValue`, returning 0/1.
  int cfNumberGetValue(
    CFTypeRef number,
    int type,
    Pointer<Double> valuePtr,
  ) =>
      _cfNumberGetValue(number, type, valuePtr);

  /// Calls `CFNumberGetValue` with a 64-bit integer out-pointer, returning 0/1.
  int cfNumberGetValueInt64(
    CFTypeRef number,
    int type,
    Pointer<Int64> valuePtr,
  ) =>
      _cfNumberGetValueInt64(number, type, valuePtr);

  /// Calls `CFNumberGetValue` with a 32-bit integer out-pointer, returning 0/1.
  /// Used for `CTFontSymbolicTraits` (uint32 bitmask).
  int cfNumberGetValueInt32(
    CFTypeRef number,
    int type,
    Pointer<Int32> valuePtr,
  ) =>
      _cfNumberGetValueInt32(number, type, valuePtr);

  /// Calls `CFURLGetFileSystemRepresentation`, returning 0/1.
  ///
  /// Writes the URL's native filesystem path (UTF-8, no NUL terminator) into
  /// [buffer]. `resolveAgainstBase` = 1 is correct for absolute file-URLs
  /// returned by CoreText; it also works for relative ones by resolving.
  int cfUrlGetFileSystemRepresentation(
    CFTypeRef url,
    int resolveAgainstBase,
    Pointer<Uint8> buffer,
    int maxBufLen,
  ) =>
      _cfUrlGetFileSystemRepresentation(
        url,
        resolveAgainstBase,
        buffer,
        maxBufLen,
      );

  /// Runs [body] inside an Objective-C autorelease pool.
  ///
  /// `CTFontDescriptorCopyAttribute` and related CoreText calls internally
  /// create autoreleased NSString/NSDictionary/NSNumber objects. A Dart CLI
  /// process has no Cocoa runloop to drain the thread's default pool, so
  /// without an explicit pool these objects accumulate until process exit —
  /// about ~1.3 MB per scan. Pushing/popping a pool around each scan drains
  /// them at scan end.
  T inAutoreleasePool<T>(T Function() body) {
    final pool = _objcPoolPush();
    try {
      return body();
    } finally {
      _objcPoolPop(pool);
    }
  }
}
