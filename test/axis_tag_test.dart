// Verifies the five registered OpenType variation-axis tag constants on
// both platforms produce the correct byte packing. DirectWrite uses a
// little-endian FOUR_CC (first byte in low bits); CoreText uses the
// canonical big-endian OpenType tag (first byte in high bits).
//
// Running these on Windows is fine — both constants are pure ints.

import 'package:just_font_scan/src/macos/coretext_bindings.dart';
import 'package:just_font_scan/src/windows/dwrite_bindings.dart';
import 'package:test/test.dart';

int _leTag(String s) {
  assert(s.length == 4);
  return s.codeUnitAt(0) |
      (s.codeUnitAt(1) << 8) |
      (s.codeUnitAt(2) << 16) |
      (s.codeUnitAt(3) << 24);
}

int _beTag(String s) {
  assert(s.length == 4);
  return (s.codeUnitAt(0) << 24) |
      (s.codeUnitAt(1) << 16) |
      (s.codeUnitAt(2) << 8) |
      s.codeUnitAt(3);
}

void main() {
  group('DirectWrite FOUR_CC (little-endian)', () {
    test('wght', () => expect(kDWriteFontAxisTagWeight, _leTag('wght')));
    test('wdth', () => expect(kDWriteFontAxisTagWidth, _leTag('wdth')));
    test('slnt', () => expect(kDWriteFontAxisTagSlant, _leTag('slnt')));
    test('ital', () => expect(kDWriteFontAxisTagItalic, _leTag('ital')));
    test('opsz', () => expect(kDWriteFontAxisTagOpticalSize, _leTag('opsz')));
  });

  group('CoreText tag (big-endian)', () {
    test('wght', () => expect(kOpenTypeWghtTag, _beTag('wght')));
    test('wdth', () => expect(kOpenTypeWdthTag, _beTag('wdth')));
    test('slnt', () => expect(kOpenTypeSlntTag, _beTag('slnt')));
    test('ital', () => expect(kOpenTypeItalTag, _beTag('ital')));
    test('opsz', () => expect(kOpenTypeOpszTag, _beTag('opsz')));
  });

  group('Endian pairs differ', () {
    test('Windows wght ≠ macOS wght',
        () => expect(kDWriteFontAxisTagWeight, isNot(kOpenTypeWghtTag)));
    test('same four chars reversed',
        () => expect(kDWriteFontAxisTagWeight, 0x74686777));
  });
}
