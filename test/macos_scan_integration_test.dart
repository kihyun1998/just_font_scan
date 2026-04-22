@TestOn('mac-os')
library;

import 'package:just_font_scan/just_font_scan.dart';
import 'package:test/test.dart';

void main() {
  group('macOS CoreText integration', () {
    setUp(JustFontScan.clearCache);

    test('scan() returns a non-empty list of families', () {
      final families = JustFontScan.scan();
      expect(families, isNotEmpty,
          reason: 'macOS ships with hundreds of system fonts by default');
    });

    test('no family name starts with "." (system-internal filter)', () {
      final families = JustFontScan.scan();
      final offenders = families.where((f) => f.name.startsWith('.')).toList();
      expect(offenders, isEmpty,
          reason: 'Names like ".SFUI-Regular" should be filtered out');
    });

    test('every family has at least one weight', () {
      final families = JustFontScan.scan();
      final emptyWeightFamilies =
          families.where((f) => f.weights.isEmpty).toList();
      expect(emptyWeightFamilies, isEmpty);
    });

    test('all weights are valid CSS values (100–900, no 950 on macOS)', () {
      final families = JustFontScan.scan();
      for (final family in families) {
        for (final w in family.weights) {
          expect(w, inInclusiveRange(100, 900),
              reason: 'family=${family.name} weights=${family.weights}');
          expect(w % 100 == 0, isTrue,
              reason: 'weight should be a standard bucket, got $w');
        }
      }
    });

    test('weights are sorted ascending within each family', () {
      final families = JustFontScan.scan();
      for (final family in families) {
        final sorted = [...family.weights]..sort();
        expect(family.weights, equals(sorted),
            reason: 'family=${family.name} weights should be ascending');
      }
    });

    test('families are sorted alphabetically (case-insensitive)', () {
      final families = JustFontScan.scan();
      for (var i = 1; i < families.length; i++) {
        final prev = families[i - 1].name.toLowerCase();
        final curr = families[i].name.toLowerCase();
        expect(prev.compareTo(curr), lessThanOrEqualTo(0),
            reason: '"$prev" should come before "$curr"');
      }
    });

    test('common macOS system fonts are present', () {
      final families = JustFontScan.scan();
      final names = families.map((f) => f.name.toLowerCase()).toSet();
      // These ship with every macOS version from at least 10.13 onward.
      expect(names, contains('helvetica'));
      expect(names, contains('menlo'));
    });

    test('weightsFor() is case-insensitive and returns weights of a real font',
        () {
      final weights = JustFontScan.weightsFor('helvetica');
      expect(weights, isNotEmpty);
      // Helvetica always ships with at least Regular (400).
      expect(weights, contains(400));
    });

    test('weightsFor() returns [400] fallback for non-existent family', () {
      final weights = JustFontScan.weightsFor('__this_font_does_not_exist__');
      expect(weights, equals([400]));
    });

    test('cache returns the same list on consecutive calls', () {
      final first = JustFontScan.scan();
      final second = JustFontScan.scan();
      expect(identical(first, second), isTrue,
          reason: 'Second call should return the cached list');
    });

    test('weightAxis fields are internally consistent when present', () {
      // Every shipping macOS includes at least a few variable fonts
      // (Noto Sans Syriac, PingFang, STIX Two Text, …). Where present,
      // the axis must satisfy min ≤ default ≤ max.
      final families = JustFontScan.scan();
      final variable = families.where((f) => f.weightAxis != null).toList();
      expect(variable, isNotEmpty,
          reason: 'macOS ships with several variable fonts by default');

      for (final family in variable) {
        final axis = family.weightAxis!;
        expect(axis.min, lessThanOrEqualTo(axis.max),
            reason: 'family=${family.name} axis=$axis');
        expect(axis.defaultValue, greaterThanOrEqualTo(axis.min),
            reason: 'family=${family.name} axis=$axis');
        expect(axis.defaultValue, lessThanOrEqualTo(axis.max),
            reason: 'family=${family.name} axis=$axis');
      }
    });
  });
}
