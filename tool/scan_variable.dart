import 'package:just_font_scan/just_font_scan.dart';

bool _anyAxis(FontFamily f) =>
    f.weightAxis != null ||
    f.widthAxis != null ||
    f.slantAxis != null ||
    f.italicAxis != null ||
    f.opticalSizeAxis != null;

void main() {
  final families = JustFontScan.scan();
  print('Total families: ${families.length}');

  final variable = families.where(_anyAxis).toList();
  print('Variable-font families: ${variable.length}');
  print('');
  for (final f in variable) {
    print('  ${f.name}');
    print('    weights (named instances): ${f.weights}');
    if (f.weightAxis != null) print('    wght: ${f.weightAxis}');
    if (f.widthAxis != null) print('    wdth: ${f.widthAxis}');
    if (f.slantAxis != null) print('    slnt: ${f.slantAxis}');
    if (f.italicAxis != null) print('    ital: ${f.italicAxis}');
    if (f.opticalSizeAxis != null) print('    opsz: ${f.opticalSizeAxis}');
  }

  // Coverage stats
  int count(bool Function(FontFamily) f) => variable.where(f).length;
  print('');
  print('--- axis coverage across ${variable.length} variable families ---');
  print('  wght: ${count((f) => f.weightAxis != null)}');
  print('  wdth: ${count((f) => f.widthAxis != null)}');
  print('  slnt: ${count((f) => f.slantAxis != null)}');
  print('  ital: ${count((f) => f.italicAxis != null)}');
  print('  opsz: ${count((f) => f.opticalSizeAxis != null)}');

  print('');
  print('Sample static-only families (first 5):');
  final staticOnly = families.where((f) => !_anyAxis(f)).take(5);
  for (final f in staticOnly) {
    print('  ${f.name} — weights: ${f.weights}');
  }
}
