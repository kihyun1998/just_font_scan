// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// CoreFoundation / CoreText bindings follow Apple naming conventions:
// types use PascalCase (CFStringRef, CTFontDescriptorRef) and constants use
// k-prefixed camelCase (kCTFontWeightTrait), which conflict with Dart lints.

import 'dart:ffi';

// --- Limits (duplicated from windows/dwrite_bindings.dart; see ROADMAP_MACOS §10) ---

/// Maximum sane font name length in UTF-16 code units.
const int kMaxFontNameLength = 32767;

/// Maximum sane font family count (guard against corrupt descriptor arrays).
const int kMaxFontFamilyCount = 10000;

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

  MacFontBindings._({
    required _CFReleaseDart cfRelease,
    required this.cfArrayGetCount,
    required this.cfArrayGetValueAtIndex,
    required this.cfDictionaryGetValue,
    required this.cfStringGetLength,
    required this.cfStringGetMaxSize,
    required _CFStringGetCStringDart cfStringGetCString,
    required _CFNumberGetValueDart cfNumberGetValue,
    required this.ctFontCollectionCreateFromAvailable,
    required this.ctFontCollectionCreateMatching,
    required this.ctFontDescriptorCopyAttribute,
    required ObjcPoolPushDart objcPoolPush,
    required ObjcPoolPopDart objcPoolPop,
    required this.kFontFamilyNameAttribute,
    required this.kFontTraitsAttribute,
    required this.kFontWeightTrait,
  })  : _cfRelease = cfRelease,
        _cfStringGetCString = cfStringGetCString,
        _cfNumberGetValue = cfNumberGetValue,
        _objcPoolPush = objcPoolPush,
        _objcPoolPop = objcPoolPop;

  /// Loads both frameworks, resolves all symbols, and dereferences the three
  /// extern `CFStringRef` constants.
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
    final famPtr = ct.lookup<CFTypeRef>('kCTFontFamilyNameAttribute');
    final traitsPtr = ct.lookup<CFTypeRef>('kCTFontTraitsAttribute');
    final weightPtr = ct.lookup<CFTypeRef>('kCTFontWeightTrait');

    final famRef = famPtr.value;
    final traitsRef = traitsPtr.value;
    final weightRef = weightPtr.value;

    if (famRef.address == 0 ||
        traitsRef.address == 0 ||
        weightRef.address == 0) {
      throw StateError(
        'CoreText extern CFStringRef constant resolved to null',
      );
    }

    return MacFontBindings._(
      cfRelease:
          cf.lookupFunction<_CFReleaseNative, _CFReleaseDart>('CFRelease'),
      cfArrayGetCount: cf.lookupFunction<_CFArrayGetCountNative,
          CFArrayGetCountDart>('CFArrayGetCount'),
      cfArrayGetValueAtIndex: cf.lookupFunction<_CFArrayGetValueAtIndexNative,
          CFArrayGetValueAtIndexDart>('CFArrayGetValueAtIndex'),
      cfDictionaryGetValue: cf.lookupFunction<_CFDictionaryGetValueNative,
          CFDictionaryGetValueDart>('CFDictionaryGetValue'),
      cfStringGetLength: cf.lookupFunction<_CFStringGetLengthNative,
          CFStringGetLengthDart>('CFStringGetLength'),
      cfStringGetMaxSize: cf.lookupFunction<
          _CFStringGetMaximumSizeForEncodingNative,
          CFStringGetMaximumSizeForEncodingDart>(
        'CFStringGetMaximumSizeForEncoding',
      ),
      cfStringGetCString: cf.lookupFunction<_CFStringGetCStringNative,
          _CFStringGetCStringDart>('CFStringGetCString'),
      cfNumberGetValue: cf.lookupFunction<_CFNumberGetValueNative,
          _CFNumberGetValueDart>('CFNumberGetValue'),
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
    );
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
