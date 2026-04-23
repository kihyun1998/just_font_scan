import 'package:test/test.dart';
import 'package:just_font_scan/just_font_scan.dart';

FontFace _face({
  int weight = 400,
  FontStyle style = FontStyle.normal,
  int stretch = 5,
  String faceName = 'Regular',
  String? postScriptName,
  String? fullName,
  String? filePath,
  bool isMonospace = false,
  bool isSymbol = false,
}) =>
    FontFace(
      weight: weight,
      style: style,
      stretch: stretch,
      faceName: faceName,
      postScriptName: postScriptName,
      fullName: fullName,
      filePath: filePath,
      isMonospace: isMonospace,
      isSymbol: isSymbol,
    );

void main() {
  group('FontFamily', () {
    test('constructor and properties', () {
      final family = FontFamily(
        name: 'Arial',
        faces: [_face(weight: 400), _face(weight: 700, faceName: 'Bold')],
      );
      expect(family.name, 'Arial');
      expect(family.faces.length, 2);
      expect(family.weightAxis, isNull);
    });

    test('weights getter derives sorted, de-duplicated set from faces', () {
      final family = FontFamily(
        name: 'Arial',
        faces: [
          _face(weight: 700, faceName: 'Bold'),
          _face(weight: 400),
          _face(weight: 400, style: FontStyle.italic, faceName: 'Italic'),
          _face(weight: 900, faceName: 'Black'),
        ],
      );
      expect(family.weights, [400, 700, 900]);
    });

    test('weights getter returns empty list for empty faces', () {
      final family = FontFamily(name: 'Ghost', faces: const []);
      expect(family.weights, isEmpty);
    });

    test('equality', () {
      final a = FontFamily(name: 'Arial', faces: [_face(weight: 400)]);
      final b = FontFamily(name: 'Arial', faces: [_face(weight: 400)]);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('weightAxis participates in equality and toString', () {
      final axis = VariationAxis(min: 100, max: 900, defaultValue: 400);
      final a = FontFamily(
        name: 'Inter',
        faces: [_face(weight: 400)],
        weightAxis: axis,
      );
      final b = FontFamily(
        name: 'Inter',
        faces: [_face(weight: 400)],
        weightAxis: VariationAxis(min: 100, max: 900, defaultValue: 400),
      );
      final c = FontFamily(
        name: 'Inter',
        faces: [_face(weight: 400)],
        weightAxis: VariationAxis(min: 100, max: 800, defaultValue: 400),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('weightAxis'));
    });

    test('all five variation axes participate in equality and toString', () {
      final fullAxes = FontFamily(
        name: 'Multi',
        faces: [_face()],
        weightAxis: VariationAxis(min: 100, max: 900, defaultValue: 400),
        widthAxis: VariationAxis(min: 75, max: 125, defaultValue: 100),
        slantAxis: VariationAxis(min: -20, max: 0, defaultValue: 0),
        italicAxis: VariationAxis(min: 0, max: 1, defaultValue: 0),
        opticalSizeAxis: VariationAxis(min: 8, max: 144, defaultValue: 14),
      );
      final s = fullAxes.toString();
      expect(s, contains('weightAxis'));
      expect(s, contains('widthAxis'));
      expect(s, contains('slantAxis'));
      expect(s, contains('italicAxis'));
      expect(s, contains('opticalSizeAxis'));

      final differs = FontFamily(
        name: 'Multi',
        faces: [_face()],
        weightAxis: VariationAxis(min: 100, max: 900, defaultValue: 400),
      );
      expect(fullAxes, isNot(equals(differs)));
    });

    test('toString omits null axes', () {
      final family = FontFamily(name: 'Arial', faces: [_face()]);
      final s = family.toString();
      expect(s, contains('Arial'));
      expect(s, isNot(contains('weightAxis')));
      expect(s, isNot(contains('widthAxis')));
    });
  });

  group('FontFace', () {
    test('equality and hashCode', () {
      final a = _face(weight: 700, faceName: 'Bold');
      final b = _face(weight: 700, faceName: 'Bold');
      final c = _face(weight: 700, faceName: 'Bold', filePath: '/x');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString includes core attributes', () {
      final f = _face(
        weight: 700,
        style: FontStyle.italic,
        faceName: 'Bold Italic',
        isMonospace: true,
      );
      final s = f.toString();
      expect(s, contains('Bold Italic'));
      expect(s, contains('700'));
      expect(s, contains('italic'));
      expect(s, contains('mono'));
    });
  });

  group('FontStyle', () {
    test('enum values and names', () {
      expect(FontStyle.normal.name, 'normal');
      expect(FontStyle.italic.name, 'italic');
      expect(FontStyle.oblique.name, 'oblique');
      expect(FontStyle.values.length, 3);
    });
  });

  group('VariationAxis', () {
    test('properties', () {
      final axis = VariationAxis(min: 1, max: 1000, defaultValue: 400);
      expect(axis.min, 1);
      expect(axis.max, 1000);
      expect(axis.defaultValue, 400);
    });

    test('equality and hashCode', () {
      final a = VariationAxis(min: 100, max: 900, defaultValue: 400);
      final b = VariationAxis(min: 100, max: 900, defaultValue: 400);
      final c = VariationAxis(min: 100, max: 900, defaultValue: 500);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString includes range', () {
      final axis = VariationAxis(min: 100, max: 900, defaultValue: 400);
      final s = axis.toString();
      expect(s, contains('100'));
      expect(s, contains('900'));
      expect(s, contains('400'));
    });

    test('supports negative ranges (e.g. slnt)', () {
      final axis = VariationAxis(min: -20, max: 0, defaultValue: 0);
      expect(axis.min, -20);
      expect(axis.max, 0);
    });
  });

  group('WeightAxis typedef (back-compat)', () {
    test('is an alias for VariationAxis', () {
      final WeightAxis axis =
          VariationAxis(min: 100, max: 900, defaultValue: 400);
      expect(axis, isA<VariationAxis>());
      expect(axis.min, 100);
    });

    test('WeightAxis literal equals VariationAxis literal', () {
      final a = WeightAxis(min: 100, max: 900, defaultValue: 400);
      final b = VariationAxis(min: 100, max: 900, defaultValue: 400);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
