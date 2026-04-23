import 'package:just_font_scan/just_font_scan.dart';

void main() {
  final families = JustFontScan.scan();
  print('Total families: ${families.length}');

  // 1) Spot-check a few common families
  const probes = [
    'Arial',
    'Segoe UI',
    'Cascadia Code',
    'Cascadia Mono',
    'Consolas',
    'Courier New',
    'Wingdings',
    'Segoe UI Variable Display',
  ];
  for (final name in probes) {
    final f = families.firstWhere(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => FontFamily(name: '', faces: const []),
    );
    if (f.name.isEmpty) {
      print('\n[$name] NOT FOUND');
      continue;
    }
    print('\n[${f.name}] ${f.faces.length} faces'
        '${f.weightAxis != null ? '  (VF: ${f.weightAxis})' : ''}');
    for (final face in f.faces) {
      final flags = <String>[
        if (face.isMonospace) 'mono',
        if (face.isSymbol) 'symbol',
      ];
      print('  "${face.faceName}"'
          '  w=${face.weight}'
          '  ${face.style.name}'
          '  s=${face.stretch}'
          '${flags.isNotEmpty ? '  [${flags.join(',')}]' : ''}');
      print('    ps: ${face.postScriptName}');
      print('    full: ${face.fullName}');
      print('    path: ${face.filePath}');
    }
  }

  // 2) Aggregate coverage stats — nullable fields should be mostly filled
  final allFaces = families.expand((f) => f.faces).toList();
  final pathFilled = allFaces.where((f) => f.filePath != null).length;
  final psFilled = allFaces.where((f) => f.postScriptName != null).length;
  final fullFilled = allFaces.where((f) => f.fullName != null).length;
  final faceNameFilled = allFaces.where((f) => f.faceName.isNotEmpty).length;
  final monoFaces = allFaces.where((f) => f.isMonospace).length;
  final italicFaces =
      allFaces.where((f) => f.style == FontStyle.italic).length;
  final obliqueFaces =
      allFaces.where((f) => f.style == FontStyle.oblique).length;

  print('\n--- coverage over ${allFaces.length} faces ---');
  String pct(int n) => '${(100 * n / allFaces.length).toStringAsFixed(1)}%';
  print('  filePath non-null:      ${pct(pathFilled)} ($pathFilled)');
  print('  postScriptName:         ${pct(psFilled)} ($psFilled)');
  print('  fullName:               ${pct(fullFilled)} ($fullFilled)');
  print('  faceName non-empty:     ${pct(faceNameFilled)} ($faceNameFilled)');
  print('  isMonospace:            ${pct(monoFaces)} ($monoFaces)');
  print('  style=italic:           ${pct(italicFaces)} ($italicFaces)');
  print('  style=oblique:          ${pct(obliqueFaces)} ($obliqueFaces)');

  // 2b) List faces missing filePath (the interesting minority).
  final missing = allFaces.where((f) => f.filePath == null).toList();
  print('\n  faces without filePath: ${missing.length}');
  final missingFamilies = <String>{};
  for (final fam in families) {
    if (fam.faces.any((f) => f.filePath == null)) {
      missingFamilies.add(fam.name);
    }
  }
  for (final n in missingFamilies.take(15)) {
    print('    $n');
  }

  // 3) PostScript name uniqueness check
  final psNames = <String, int>{};
  for (final f in allFaces) {
    final p = f.postScriptName;
    if (p == null) continue;
    psNames[p] = (psNames[p] ?? 0) + 1;
  }
  final duplicates = psNames.entries.where((e) => e.value > 1).toList();
  print('  PostScript name duplicates: ${duplicates.length}');
  for (final d in duplicates.take(10)) {
    print('    ${d.key} × ${d.value}');
  }
}
