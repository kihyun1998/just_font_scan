import 'dart:io' show Platform;

import 'macos/macos_font_scanner.dart' as macos;
import 'models.dart';
import 'windows/windows_font_scanner.dart' as windows;

/// Provides static methods to scan system font families and query their
/// supported weights.
///
/// Supports Windows (DirectWrite) and macOS (CoreText).
///
/// Results are cached after the first [scan] call. Use [clearCache] to
/// force a rescan.
class JustFontScan {
  /// Cache is isolate-local. Calling [scan] from different isolates will
  /// trigger separate scans.
  static List<FontFamily>? _cache;

  /// Scans system font families. Results are sorted by name.
  /// Cached after first call; use [clearCache] to reset.
  static List<FontFamily> scan() {
    if (_cache != null) return _cache!;
    _cache = _scan();
    return _cache!;
  }

  /// Clears the cached scan result so the next [scan] call rescans the system.
  static void clearCache() {
    _cache = null;
  }

  /// Returns the supported weights for [familyName], case-insensitively.
  ///
  /// Returns `[400]` as a default when the family is not found in the
  /// system font collection. To distinguish "found with weight 400" from
  /// "not found", use [scan] directly and search the result.
  static List<int> weightsFor(String familyName) {
    final families = scan();
    final lowerName = familyName.toLowerCase();
    for (final family in families) {
      if (family.name.toLowerCase() == lowerName) {
        return family.weights;
      }
    }
    return const [400];
  }

  static List<FontFamily> _scan() {
    if (Platform.isWindows) {
      return windows.scanFonts();
    }
    if (Platform.isMacOS) {
      return macos.scanFonts();
    }
    return const [];
  }
}
