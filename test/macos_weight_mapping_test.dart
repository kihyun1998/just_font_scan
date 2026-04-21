import 'package:just_font_scan/src/macos/macos_font_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('mapWeight — exact Apple NSFontWeight bucket values', () {
    test('−0.80 → 100 (UltraLight)', () => expect(mapWeight(-0.80), 100));
    test('−0.60 → 200 (Thin)', () => expect(mapWeight(-0.60), 200));
    test('−0.40 → 300 (Light)', () => expect(mapWeight(-0.40), 300));
    test('  0.00 → 400 (Regular)', () => expect(mapWeight(0.00), 400));
    test('  0.23 → 500 (Medium)', () => expect(mapWeight(0.23), 500));
    test('  0.30 → 600 (Semibold)', () => expect(mapWeight(0.30), 600));
    test('  0.40 → 700 (Bold)', () => expect(mapWeight(0.40), 700));
    test('  0.56 → 800 (Heavy)', () => expect(mapWeight(0.56), 800));
    test('  0.62 → 900 (Black)', () => expect(mapWeight(0.62), 900));
  });

  group('mapWeight — nearest-bucket snapping', () {
    test('slightly above UltraLight still snaps to 100',
        () => expect(mapWeight(-0.79), 100));
    test('midway between Thin(−0.60) and Light(−0.40): tie → lower (200)',
        () => expect(mapWeight(-0.50), 200));
    test('closer to Light than Regular',
        () => expect(mapWeight(-0.25), 300));
    test('closer to Regular than Light',
        () => expect(mapWeight(-0.15), 400));
    test('between Regular(0.00) and Medium(0.23), closer to Medium',
        () => expect(mapWeight(0.15), 500));
    test('between Semibold(0.30) and Bold(0.40), closer to Bold',
        () => expect(mapWeight(0.36), 700));
    test('midway between Semibold and Bold: tie → lower (600)',
        () => expect(mapWeight(0.35), 600));
    test('between Bold(0.40) and Heavy(0.56), closer to Bold',
        () => expect(mapWeight(0.45), 700));
    test('between Heavy(0.56) and Black(0.62), closer to Heavy',
        () => expect(mapWeight(0.58), 800));
    test('beyond Black still snaps to 900',
        () => expect(mapWeight(0.85), 900));
  });

  group('mapWeight — out-of-range and NaN fallback to 400', () {
    test('NaN', () => expect(mapWeight(double.nan), 400));
    test('below −1.0', () => expect(mapWeight(-1.5), 400));
    test('above 1.0', () => expect(mapWeight(1.5), 400));
    test('negative infinity',
        () => expect(mapWeight(double.negativeInfinity), 400));
    test('positive infinity',
        () => expect(mapWeight(double.infinity), 400));
  });

  group('mapWeight — never produces 950', () {
    test('+1.0 boundary maps to 900 (no ExtraBlack bucket)',
        () => expect(mapWeight(1.0), 900));
  });
}
