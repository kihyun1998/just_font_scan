// Probe the reference-key layout for specific font families.
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:just_font_scan/src/windows/dwrite_bindings.dart';

void main() {
  using((arena) => _probe(arena, {'Cascadia Code', 'Pretendard', 'Arial'}));
}

void _probe(Arena arena, Set<String> targets) {
  final ole32 = loadOle32();
  final dwrite = loadDWrite();
  final coInit = ole32.lookupFunction<CoInitializeExNative, CoInitializeExDart>(
      'CoInitializeEx');
  coInit(nullptr, COINIT_APARTMENTTHREADED);

  final createFactory = dwrite.lookupFunction<DWriteCreateFactoryNative,
      DWriteCreateFactoryDart>('DWriteCreateFactory');
  final iid = allocIIDWriteFactory(arena);
  final ppFactory = arena<Pointer<IntPtr>>();
  createFactory(DWRITE_FACTORY_TYPE_SHARED, iid, ppFactory);
  final factory = ppFactory.value;

  final ppCollection = arena<Pointer<IntPtr>>();
  factoryGetSystemFontCollection(factory, ppCollection);
  final collection = ppCollection.value;

  final count = collectionGetFontFamilyCount(collection);
  for (var fi = 0; fi < count; fi++) {
    final ppFamily = arena<Pointer<IntPtr>>();
    if (!succeeded(collectionGetFontFamily(collection, fi, ppFamily))) continue;
    final family = ppFamily.value;

    final ppNames = arena<Pointer<IntPtr>>();
    if (!succeeded(fontFamilyGetFamilyNames(family, ppNames))) {
      comRelease(family);
      continue;
    }
    final names = ppNames.value;
    final pLen = arena<Uint32>();
    localizedStringsGetStringLength(names, 0, pLen);
    final buf = arena<Uint16>(pLen.value + 1).cast<Utf16>();
    localizedStringsGetString(names, 0, buf, pLen.value + 1);
    final fname = buf.toDartString(length: pLen.value);
    comRelease(names);

    if (!targets.contains(fname)) {
      comRelease(family);
      continue;
    }

    // Probe first font
    final ppFont = arena<Pointer<IntPtr>>();
    if (!succeeded(fontListGetFont(family, 0, ppFont))) {
      comRelease(family);
      continue;
    }
    final font = ppFont.value;
    final ppFace = arena<Pointer<IntPtr>>();
    fontCreateFontFace(font, ppFace);
    final face = ppFace.value;

    final pCount = arena<Uint32>();
    pCount.value = 0;
    fontFaceGetFiles(face, pCount, nullptr);
    final fileCount = pCount.value;
    final files = arena<Pointer<IntPtr>>(fileCount);
    fontFaceGetFiles(face, pCount, files);
    final file = (files + 0).value;

    final pKey = arena<Pointer<Void>>();
    final pKeySize = arena<Uint32>();
    fontFileGetReferenceKey(file, pKey, pKeySize);

    print('=== $fname (keySize=${pKeySize.value}) ===');
    final keyBytes = pKey.value.cast<Uint8>();
    final hex = <String>[];
    for (var i = 0; i < pKeySize.value && i < 128; i++) {
      hex.add((keyBytes + i).value.toRadixString(16).padLeft(2, '0'));
    }
    print('  hex: ${hex.join(' ')}');
    if (pKeySize.value >= 10 && pKeySize.value.isEven) {
      final locTag =
          (keyBytes + 8).value | ((keyBytes + 9).value << 8);
      print('  location tag: 0x${locTag.toRadixString(16)}');
      try {
        final filenameUtf16 = (keyBytes + 10).cast<Utf16>();
        final filenameChars = (pKeySize.value - 10 - 2) ~/ 2;
        if (filenameChars > 0) {
          final s = filenameUtf16.toDartString(length: filenameChars);
          print('  filename: "$s"');
        }
      } catch (_) {}
    }

    for (var i = 0; i < fileCount; i++) {
      final f = (files + i).value;
      if (f.address != 0) comRelease(f);
    }
    comRelease(face);
    comRelease(font);
    comRelease(family);
    print('');
  }

  comRelease(collection);
  comRelease(factory);
}
