import 'package:just_font_scan/src/macos/macos_font_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('mapStretch — anchor values', () {
    test('−1.0 → 1 (Ultra-Condensed)', () => expect(mapStretch(-1.0), 1));
    test('−0.5 → 3 (Condensed)', () => expect(mapStretch(-0.5), 3));
    test(' 0.0 → 5 (Normal)', () => expect(mapStretch(0.0), 5));
    test(' 0.5 → 7 (Expanded)', () => expect(mapStretch(0.5), 7));
    test(' 1.0 → 9 (Ultra-Expanded)', () => expect(mapStretch(1.0), 9));
  });

  group('mapStretch — intermediate bucket rounding', () {
    test('−0.75 → 2 (Extra-Condensed)', () => expect(mapStretch(-0.75), 2));
    test('−0.25 → 4 (Semi-Condensed)', () => expect(mapStretch(-0.25), 4));
    test(' 0.25 → 6 (Semi-Expanded)', () => expect(mapStretch(0.25), 6));
    test(' 0.75 → 8 (Extra-Expanded)', () => expect(mapStretch(0.75), 8));
  });

  group('mapStretch — off-bucket values snap to nearest', () {
    test('−0.10 → 5 (closer to Normal than Semi-Condensed)',
        () => expect(mapStretch(-0.10), 5));
    test(' 0.10 → 5 (closer to Normal than Semi-Expanded)',
        () => expect(mapStretch(0.10), 5));
    test('−0.45 → 3 (closer to Condensed)', () => expect(mapStretch(-0.45), 3));
  });

  group('mapStretch — fallback behaviour', () {
    test('NaN → 5', () => expect(mapStretch(double.nan), 5));
    test(
        'below −1.0 → 5', () => expect(mapStretch(double.negativeInfinity), 5));
    test('above  1.0 → 5', () => expect(mapStretch(double.infinity), 5));
    test('−1.5 → 5', () => expect(mapStretch(-1.5), 5));
    test(' 1.5 → 5', () => expect(mapStretch(1.5), 5));
  });

  group('mapStretch — clamp boundaries', () {
    test('never produces 0', () => expect(mapStretch(-1.0), 1));
    test('never exceeds 9', () => expect(mapStretch(1.0), 9));
  });
}
