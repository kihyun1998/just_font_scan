// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// COM/DirectWrite bindings follow Windows SDK naming conventions:
// types use PascalCase (GUID, HRESULT) and constants use ALL_CAPS
// (DWRITE_FACTORY_TYPE_SHARED), which conflict with Dart lint rules.

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

// --- HRESULT helper ---

bool succeeded(int hr) => hr >= 0;

// --- Font weight range (DWRITE_FONT_WEIGHT) ---

/// Minimum valid DWRITE_FONT_WEIGHT value.
const int kDWriteFontWeightMin = 1;

/// Maximum valid DWRITE_FONT_WEIGHT value (DWRITE_FONT_WEIGHT_ULTRA_BLACK = 950,
/// but values up to 1000 are accepted by some implementations).
const int kDWriteFontWeightMax = 1000;

/// Maximum sane font name length in characters.
const int kMaxFontNameLength = 32767;

/// Maximum sane font family count (guard against corrupt COM data).
const int kMaxFontFamilyCount = 10000;

/// Maximum sane font count per family.
const int kMaxFontCount = 1000;

// --- GUIDs ---

/// GUID struct for COM interfaces.
base class GUID extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Uint8()
  external int data4_0;
  @Uint8()
  external int data4_1;
  @Uint8()
  external int data4_2;
  @Uint8()
  external int data4_3;
  @Uint8()
  external int data4_4;
  @Uint8()
  external int data4_5;
  @Uint8()
  external int data4_6;
  @Uint8()
  external int data4_7;
}

/// Allocates and fills IID_IDWriteFactory:
/// {b859ee5a-d838-4b5b-a2e8-1adc7d93db48}
Pointer<GUID> allocIIDWriteFactory(Arena arena) {
  final guid = arena<GUID>();
  guid.ref.data1 = 0xb859ee5a;
  guid.ref.data2 = 0xd838;
  guid.ref.data3 = 0x4b5b;
  guid.ref.data4_0 = 0xa2;
  guid.ref.data4_1 = 0xe8;
  guid.ref.data4_2 = 0x1a;
  guid.ref.data4_3 = 0xdc;
  guid.ref.data4_4 = 0x7d;
  guid.ref.data4_5 = 0x93;
  guid.ref.data4_6 = 0xdb;
  guid.ref.data4_7 = 0x48;
  return guid;
}

// --- DWriteCreateFactory ---

/// DWRITE_FACTORY_TYPE_SHARED = 0
const int DWRITE_FACTORY_TYPE_SHARED = 0;

/// HRESULT DWriteCreateFactory(
///   DWRITE_FACTORY_TYPE factoryType,
///   REFIID iid,
///   IUnknown **factory
/// )
///
/// Note: `Pointer<IntPtr>` is the Dart FFI idiom for an opaque COM interface
/// pointer. The actual native type is `IUnknown*`, but Dart FFI does not have
/// a COM-aware type, so we use IntPtr-width pointers throughout.
typedef DWriteCreateFactoryNative = Int32 Function(
  Int32 factoryType,
  Pointer<GUID> iid,
  Pointer<Pointer<IntPtr>> factory,
);
typedef DWriteCreateFactoryDart = int Function(
  int factoryType,
  Pointer<GUID> iid,
  Pointer<Pointer<IntPtr>> factory,
);

// --- COM lifecycle (ole32.dll) ---

typedef CoInitializeExNative = Int32 Function(
  Pointer<Void> reserved,
  Uint32 dwCoInit,
);
typedef CoInitializeExDart = int Function(
  Pointer<Void> reserved,
  int dwCoInit,
);

typedef CoUninitializeNative = Void Function();
typedef CoUninitializeDart = void Function();

/// COINIT_APARTMENTTHREADED = 0x2
const int COINIT_APARTMENTTHREADED = 0x2;

// --- DLL loading with absolute System32 path (W-1: prevent DLL hijacking) ---

String _system32Path() {
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  return '$systemRoot\\System32';
}

DynamicLibrary loadOle32() =>
    DynamicLibrary.open('${_system32Path()}\\ole32.dll');

DynamicLibrary loadDWrite() =>
    DynamicLibrary.open('${_system32Path()}\\dwrite.dll');

// --- COM vtable helpers ---

/// Reads the vtable pointer array from a COM interface pointer.
///
/// comPtr points to the object, whose first field is a pointer to the vtable.
/// Throws [StateError] if the COM pointer or vtable pointer is null, preventing
/// an unrecoverable process crash from null-pointer dereference.
Pointer<IntPtr> _vtable(Pointer<IntPtr> comPtr) {
  if (comPtr.address == 0) {
    throw StateError('COM pointer is null — cannot read vtable');
  }
  final vtableAddr = comPtr.value;
  if (vtableAddr == 0) {
    throw StateError('vtable pointer is null');
  }
  return Pointer<IntPtr>.fromAddress(vtableAddr);
}

/// Gets a function pointer from vtable at [slotIndex].
Pointer<NativeFunction<T>> vtableSlot<T extends Function>(
  Pointer<IntPtr> comPtr,
  int slotIndex,
) {
  assert(
    slotIndex >= 0 && slotIndex < 64,
    'vtable slot $slotIndex is out of expected range',
  );
  final vtable = _vtable(comPtr);
  final fnAddr = vtable.elementAt(slotIndex).value;
  return Pointer<NativeFunction<T>>.fromAddress(fnAddr);
}

// --- IUnknown ---

/// IUnknown::Release — vtable slot 2
typedef _ReleaseNative = Uint32 Function(Pointer<IntPtr> self);
typedef _ReleaseDart = int Function(Pointer<IntPtr> self);

void comRelease(Pointer<IntPtr> comPtr) {
  if (comPtr.address == 0) return;
  final fn = vtableSlot<_ReleaseNative>(comPtr, 2).asFunction<_ReleaseDart>();
  fn(comPtr);
}

// --- IDWriteFactory vtable ---
// Verified against dwrite.h (Windows SDK) and MSDN.
// IUnknown (3) + IDWriteFactory methods:
//  [3]  GetSystemFontCollection
//  [4]  CreateCustomFontCollection
//  [5]  RegisterFontCollectionLoader
//  [6]  UnregisterFontCollectionLoader
//  [7]  CreateFontFileReference
//  [8]  CreateCustomFontFileReference
//  [9]  CreateFontFace
//  [10] CreateRenderingParams
//  [11] CreateMonitorRenderingParams
//  [12] CreateCustomRenderingParams
//  [13] RegisterFontFileLoader
//  [14] UnregisterFontFileLoader
//  [15] CreateTextFormat
//  [16] CreateTypography
//  [17] GetGdiInterop
//  [18] CreateTextLayout
//  [19] CreateGdiCompatibleTextLayout
//  [20] CreateEllipsisTrimmingSign
//  [21] CreateTextAnalyzer
//  [22] CreateNumberSubstitution
//  [23] CreateGlyphRunAnalysis

/// IDWriteFactory::GetSystemFontCollection — vtable slot 3
typedef _GetSystemFontCollectionNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> fontCollection,
  Int32 checkForUpdates,
);
typedef _GetSystemFontCollectionDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> fontCollection,
  int checkForUpdates,
);

int factoryGetSystemFontCollection(
  Pointer<IntPtr> factory,
  Pointer<Pointer<IntPtr>> outCollection,
) {
  final fn = vtableSlot<_GetSystemFontCollectionNative>(factory, 3)
      .asFunction<_GetSystemFontCollectionDart>();
  return fn(factory, outCollection, 0);
}

// --- IDWriteFontCollection vtable ---
// Verified against dwrite.h.
// IUnknown (3) +
//  [3] GetFontFamilyCount
//  [4] GetFontFamily
//  [5] FindFamilyName
//  [6] GetFontFromFontFace

/// IDWriteFontCollection::GetFontFamilyCount — vtable slot 3
typedef _GetFontFamilyCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontFamilyCountDart = int Function(Pointer<IntPtr> self);

int collectionGetFontFamilyCount(Pointer<IntPtr> collection) {
  final fn = vtableSlot<_GetFontFamilyCountNative>(collection, 3)
      .asFunction<_GetFontFamilyCountDart>();
  return fn(collection);
}

/// IDWriteFontCollection::GetFontFamily — vtable slot 4
typedef _GetFontFamilyNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Pointer<IntPtr>> fontFamily,
);
typedef _GetFontFamilyDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Pointer<IntPtr>> fontFamily,
);

int collectionGetFontFamily(
  Pointer<IntPtr> collection,
  int index,
  Pointer<Pointer<IntPtr>> outFamily,
) {
  final fn = vtableSlot<_GetFontFamilyNative>(collection, 4)
      .asFunction<_GetFontFamilyDart>();
  return fn(collection, index, outFamily);
}

// --- IDWriteFontList vtable ---
// Verified against dwrite.h.
// IUnknown (3) +
//  [3] GetFontCollection
//  [4] GetFontCount
//  [5] GetFont

/// IDWriteFontList::GetFontCount — vtable slot 4
typedef _GetFontCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetFontCountDart = int Function(Pointer<IntPtr> self);

int fontListGetFontCount(Pointer<IntPtr> fontList) {
  final fn = vtableSlot<_GetFontCountNative>(fontList, 4)
      .asFunction<_GetFontCountDart>();
  return fn(fontList);
}

/// IDWriteFontList::GetFont — vtable slot 5
typedef _GetFontNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Pointer<IntPtr>> font,
);
typedef _GetFontDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Pointer<IntPtr>> font,
);

int fontListGetFont(
  Pointer<IntPtr> fontList,
  int index,
  Pointer<Pointer<IntPtr>> outFont,
) {
  final fn =
      vtableSlot<_GetFontNative>(fontList, 5).asFunction<_GetFontDart>();
  return fn(fontList, index, outFont);
}

// --- IDWriteFontFamily vtable (extends IDWriteFontList) ---
// Verified against dwrite.h.
// IDWriteFontList (6) +
//  [6] GetFamilyNames
//  [7] GetFirstMatchingFont
//  [8] GetMatchingFonts

/// IDWriteFontFamily::GetFamilyNames — vtable slot 6
typedef _GetFamilyNamesNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> names,
);
typedef _GetFamilyNamesDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Pointer<IntPtr>> names,
);

int fontFamilyGetFamilyNames(
  Pointer<IntPtr> fontFamily,
  Pointer<Pointer<IntPtr>> outNames,
) {
  final fn = vtableSlot<_GetFamilyNamesNative>(fontFamily, 6)
      .asFunction<_GetFamilyNamesDart>();
  return fn(fontFamily, outNames);
}

// --- IDWriteFont vtable ---
// Verified against dwrite.h (IDWriteFont : IUnknown).
// Ref: https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritefont
// IUnknown (3) +
//  [3]  GetFontFamily
//  [4]  GetWeight         — DWRITE_FONT_WEIGHT GetWeight()
//  [5]  GetStretch
//  [6]  GetStyle
//  [7]  IsSymbolFont
//  [8]  GetFaceNames
//  [9]  GetInformationalStrings
//  [10] GetSimulations
//  [11] GetMetrics
//  [12] HasCharacter
//  [13] CreateFontFace

/// IDWriteFont::GetWeight — vtable slot 4
typedef _GetWeightNative = Int32 Function(Pointer<IntPtr> self);
typedef _GetWeightDart = int Function(Pointer<IntPtr> self);

int fontGetWeight(Pointer<IntPtr> font) {
  final fn =
      vtableSlot<_GetWeightNative>(font, 4).asFunction<_GetWeightDart>();
  return fn(font);
}

// --- IDWriteLocalizedStrings vtable ---
// Verified against dwrite.h.
// Ref: https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritelocalizedstrings
// IUnknown (3) +
//  [3] GetCount
//  [4] FindLocaleName
//  [5] GetLocaleNameLength
//  [6] GetLocaleName
//  [7] GetStringLength
//  [8] GetString

/// IDWriteLocalizedStrings::GetCount — vtable slot 3
typedef _GetCountNative = Uint32 Function(Pointer<IntPtr> self);
typedef _GetCountDart = int Function(Pointer<IntPtr> self);

int localizedStringsGetCount(Pointer<IntPtr> strings) {
  final fn =
      vtableSlot<_GetCountNative>(strings, 3).asFunction<_GetCountDart>();
  return fn(strings);
}

/// IDWriteLocalizedStrings::FindLocaleName — vtable slot 4
typedef _FindLocaleNameNative = Int32 Function(
  Pointer<IntPtr> self,
  Pointer<Utf16> localeName,
  Pointer<Uint32> index,
  Pointer<Int32> exists,
);
typedef _FindLocaleNameDart = int Function(
  Pointer<IntPtr> self,
  Pointer<Utf16> localeName,
  Pointer<Uint32> index,
  Pointer<Int32> exists,
);

int localizedStringsFindLocaleName(
  Pointer<IntPtr> strings,
  Pointer<Utf16> localeName,
  Pointer<Uint32> outIndex,
  Pointer<Int32> outExists,
) {
  final fn = vtableSlot<_FindLocaleNameNative>(strings, 4)
      .asFunction<_FindLocaleNameDart>();
  return fn(strings, localeName, outIndex, outExists);
}

/// IDWriteLocalizedStrings::GetStringLength — vtable slot 7
typedef _GetStringLengthNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Uint32> length,
);
typedef _GetStringLengthDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Uint32> length,
);

int localizedStringsGetStringLength(
  Pointer<IntPtr> strings,
  int index,
  Pointer<Uint32> outLength,
) {
  final fn = vtableSlot<_GetStringLengthNative>(strings, 7)
      .asFunction<_GetStringLengthDart>();
  return fn(strings, index, outLength);
}

/// IDWriteLocalizedStrings::GetString — vtable slot 8
typedef _GetStringNative = Int32 Function(
  Pointer<IntPtr> self,
  Uint32 index,
  Pointer<Utf16> stringBuffer,
  Uint32 size,
);
typedef _GetStringDart = int Function(
  Pointer<IntPtr> self,
  int index,
  Pointer<Utf16> stringBuffer,
  int size,
);

int localizedStringsGetString(
  Pointer<IntPtr> strings,
  int index,
  Pointer<Utf16> buffer,
  int size,
) {
  final fn = vtableSlot<_GetStringNative>(strings, 8)
      .asFunction<_GetStringDart>();
  return fn(strings, index, buffer, size);
}
