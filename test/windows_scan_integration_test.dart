@TestOn('windows')
library;

import 'package:just_font_scan/just_font_scan.dart';
import 'package:test/test.dart';

void main() {
  group('Windows DirectWrite integration', () {
    setUp(JustFontScan.clearCache);

    test('scan() returns a non-empty list of families', () {
      expect(JustFontScan.scan(), isNotEmpty);
    });

    test('Arial has Regular and Bold faces backed by local .ttf files', () {
      final arial = JustFontScan.scan().firstWhere(
        (f) => f.name.toLowerCase() == 'arial',
        orElse: () => fail('Arial ships with every Windows version'),
      );
      expect(arial.weights, containsAll([400, 700]));
      for (final face in arial.faces) {
        expect(face.filePath, isNotNull, reason: 'face=$face');
        expect(face.filePath!.toLowerCase(), endsWith('.ttf'),
            reason: 'face=$face');
      }
    });

    test('every face weight is a CSS weight (1–1000)', () {
      for (final family in JustFontScan.scan()) {
        for (final w in family.weights) {
          expect(w, inInclusiveRange(1, 1000),
              reason: 'family=${family.name} weights=${family.weights}');
        }
      }
    });

    test('weightAxis fields are internally consistent when present', () {
      final families = JustFontScan.scan();
      for (final family in families.where((f) => f.weightAxis != null)) {
        final axis = family.weightAxis!;
        expect(axis.min, lessThanOrEqualTo(axis.defaultValue),
            reason: 'family=${family.name} axis=$axis');
        expect(axis.defaultValue, lessThanOrEqualTo(axis.max),
            reason: 'family=${family.name} axis=$axis');
      }
    });

    test('Segoe UI Variable exposes wght and opsz axes, where installed', () {
      final matches = JustFontScan.scan()
          .where((f) => f.name.startsWith('Segoe UI Variable'))
          .toList();
      if (matches.isEmpty) {
        markTestSkipped('Segoe UI Variable is not installed on this machine');
        return;
      }
      for (final family in matches) {
        expect(family.weightAxis, isNotNull, reason: 'family=${family.name}');
        expect(family.opticalSizeAxis, isNotNull,
            reason: 'family=${family.name}');
      }
    });
  });
}
