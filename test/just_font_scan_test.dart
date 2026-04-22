import 'package:test/test.dart';
import 'package:just_font_scan/just_font_scan.dart';

void main() {
  group('FontFamily', () {
    test('constructor and properties', () {
      final family = FontFamily(name: 'Arial', weights: [400, 700]);
      expect(family.name, 'Arial');
      expect(family.weights, [400, 700]);
      expect(family.weightAxis, isNull);
    });

    test('equality', () {
      final a = FontFamily(name: 'Arial', weights: [400, 700]);
      final b = FontFamily(name: 'Arial', weights: [400, 700]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      final family = FontFamily(name: 'Arial', weights: [400, 700]);
      expect(family.toString(), contains('Arial'));
    });

    test('weightAxis defaults to null', () {
      final family = FontFamily(name: 'Arial', weights: [400]);
      expect(family.weightAxis, isNull);
      expect(family.toString(), isNot(contains('weightAxis')));
    });

    test('weightAxis is included in equality and toString', () {
      final axis = WeightAxis(min: 100, max: 900, defaultValue: 400);
      final a = FontFamily(
        name: 'Inter',
        weights: const [400, 700],
        weightAxis: axis,
      );
      final b = FontFamily(
        name: 'Inter',
        weights: const [400, 700],
        weightAxis: WeightAxis(min: 100, max: 900, defaultValue: 400),
      );
      final c = FontFamily(
        name: 'Inter',
        weights: const [400, 700],
        weightAxis: WeightAxis(min: 100, max: 800, defaultValue: 400),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('weightAxis'));
    });
  });

  group('WeightAxis', () {
    test('properties', () {
      final axis = WeightAxis(min: 1, max: 1000, defaultValue: 400);
      expect(axis.min, 1);
      expect(axis.max, 1000);
      expect(axis.defaultValue, 400);
    });

    test('equality and hashCode', () {
      final a = WeightAxis(min: 100, max: 900, defaultValue: 400);
      final b = WeightAxis(min: 100, max: 900, defaultValue: 400);
      final c = WeightAxis(min: 100, max: 900, defaultValue: 500);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString includes range', () {
      final axis = WeightAxis(min: 100, max: 900, defaultValue: 400);
      final s = axis.toString();
      expect(s, contains('100'));
      expect(s, contains('900'));
      expect(s, contains('400'));
    });
  });
}
