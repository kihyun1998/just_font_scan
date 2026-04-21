import 'dart:io';

import 'package:just_font_scan/just_font_scan.dart';

String _rssMb() => (ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(1);

Future<void> _quiet() async {
  for (var i = 0; i < 20; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> main() async {
  print('baseline: ${_rssMb()} MB');

  JustFontScan.scan();
  await _quiet();
  final warm = ProcessInfo.currentRss;
  print('after 1 scan + quiesce        : ${_rssMb()} MB');

  for (var i = 0; i < 500; i++) {
    JustFontScan.clearCache();
    JustFontScan.scan();
  }
  await _quiet();
  final round1 = ProcessInfo.currentRss;
  print('after  500 scans + quiesce    : ${_rssMb()} MB');

  for (var i = 0; i < 500; i++) {
    JustFontScan.clearCache();
    JustFontScan.scan();
  }
  await _quiet();
  final round2 = ProcessInfo.currentRss;
  print('after 1000 scans + quiesce    : ${_rssMb()} MB');

  for (var i = 0; i < 500; i++) {
    JustFontScan.clearCache();
    JustFontScan.scan();
  }
  await _quiet();
  final round3 = ProcessInfo.currentRss;
  print('after 1500 scans + quiesce    : ${_rssMb()} MB');

  print('');
  final d1 = ((round1 - warm) / (1024 * 1024)).toStringAsFixed(2);
  final d2 = ((round2 - round1) / (1024 * 1024)).toStringAsFixed(2);
  final d3 = ((round3 - round2) / (1024 * 1024)).toStringAsFixed(2);
  print('Per-500-scan deltas:');
  print('  round1 − warm  : $d1 MB');
  print('  round2 − round1: $d2 MB');
  print('  round3 − round2: $d3 MB');
}
