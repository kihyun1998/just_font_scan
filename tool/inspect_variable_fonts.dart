// Lists every system font family whose `wght` axis is exposed as a
// continuous range. Run with `dart run tool/inspect_variable_fonts.dart`.
import 'package:just_font_scan/just_font_scan.dart';

void main() {
  final all = JustFontScan.scan();
  final vf = all.where((f) => f.weightAxis != null).toList();

  print('Total families: ${all.length}');
  print('Families with weightAxis: ${vf.length}');
  print('');
  for (final f in vf) {
    print('  ${f.name}');
    print('    weights:    ${f.weights}');
    print('    weightAxis: ${f.weightAxis}');
  }
}
