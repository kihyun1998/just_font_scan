# just_font_scan

Dart package to scan system font families and their supported weights using platform-native APIs.

- **Windows**: DirectWrite COM API (`dwrite.dll`) via `dart:ffi`
- **macOS**: CoreText framework via `dart:ffi`

## Features

- Retrieves all system font families grouped by the platform's native family grouping (e.g. "Source Code Pro" is one family with weights 200--900, not separate entries per variant)
- Reports supported font weights (100--950 on Windows, 100--900 on macOS) per family
- Results cached after first scan; repeated `clearCache() → scan()` cycles are memory-safe
- No native build step -- pure `dart:ffi` with system libraries

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  just_font_scan:
    git:
      url: https://github.com/kihyun1998/just_font_scan.git
```

## API Reference

### `FontFamily` class

Represents a single system font family.

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Font family name (e.g. `'Arial'`, `'Source Code Pro'`). |
| `weights` | `List<int>` | Supported font weights in ascending order. Values follow the CSS/OpenType convention (see weight table below). |

`FontFamily` supports equality comparison (`==`) and can be used as a map key.

### `JustFontScan` class

All methods are static. No instantiation needed.

#### `JustFontScan.scan()`

```dart
static List<FontFamily> scan()
```

Scans all system font families. Returns a list sorted alphabetically by family name.

- **Returns**: `List<FontFamily>` -- all font families found on the system.
- **Caching**: Results are cached after the first call. Subsequent calls return the cached list instantly.
- **Error handling**: Returns an empty list `[]` if the platform is unsupported or if a native API error occurs. Never throws.
- **Thread safety**: The cache is isolate-local. Calling `scan()` from different isolates triggers separate scans.

#### `JustFontScan.clearCache()`

```dart
static void clearCache()
```

Clears the cached scan result. The next `scan()` call will rescan the system. Use this if fonts have been installed or removed since the last scan.

#### `JustFontScan.weightsFor()`

```dart
static List<int> weightsFor(String familyName)
```

Returns the supported weights for a specific font family.

- **Parameter** `familyName` (`String`): The font family name to look up. **Case-insensitive** (e.g. `'arial'` matches `'Arial'`).
- **Returns**: `List<int>` -- weights in ascending order.
- **Not found**: Returns `[400]` as a default when the family does not exist in the system. To distinguish "family exists with only weight 400" from "family not found", use `scan()` directly and search the result.

### Font weight values

Standard `DWRITE_FONT_WEIGHT` / CSS `font-weight` values:

| Value | Name |
|-------|------|
| 100 | Thin |
| 200 | ExtraLight |
| 300 | Light |
| 350 | SemiLight |
| 400 | Regular |
| 500 | Medium |
| 600 | SemiBold |
| 700 | Bold |
| 800 | ExtraBold |
| 900 | Black |
| 950 | ExtraBlack |

Not all fonts support every weight. A font may have any subset of these values.

#### macOS weight caveat

macOS CoreText reports font weight as a normalized float in the range `−1.0` to `1.0`. `just_font_scan` snaps each value to the nearest bucket in Apple's `NSFontWeight` table and reports the corresponding CSS weight. This is an **approximation** — a font whose native weight is e.g. `0.36` (between Semibold `0.30` and Bold `0.40`) will be reported as `700` because it is closer to Bold. On Windows, `DWRITE_FONT_WEIGHT` values map 1:1, so Windows results are exact.

The CSS weight `950` (ExtraBlack) is never produced on macOS because no public `NSFontWeight` constant corresponds to it.

## Usage

### Basic scan

```dart
import 'package:just_font_scan/just_font_scan.dart';

final families = JustFontScan.scan();
// families is List<FontFamily>, sorted by name.

for (final family in families) {
  print('${family.name}: ${family.weights}');
}
// Arial: [400, 700, 900]
// Calibri: [300, 400, 700]
// Source Code Pro: [200, 300, 400, 500, 600, 700, 800, 900]
// ...
```

### Query a specific family

```dart
final weights = JustFontScan.weightsFor('Source Code Pro');
print(weights); // [200, 300, 400, 500, 600, 700, 800, 900]

final missing = JustFontScan.weightsFor('NonExistentFont');
print(missing); // [400]  (default fallback)
```

### Check if a family supports a specific weight

```dart
final weights = JustFontScan.weightsFor('Arial');
if (weights.contains(700)) {
  print('Arial Bold is available');
}
```

### Check if a family exists

```dart
final families = JustFontScan.scan();
final exists = families.any(
  (f) => f.name.toLowerCase() == 'arial',
);
```

### Rescan after font installation

```dart
JustFontScan.clearCache();
final updated = JustFontScan.scan();
```

## Platform support

| Platform | Status | API |
|----------|--------|-----|
| Windows  | Supported | DirectWrite (`IDWriteFactory`) |
| macOS    | Supported | CoreText (`CTFontCollection`) |
| Linux    | Not yet | -- |

On unsupported platforms, `scan()` returns an empty list and `weightsFor()` always returns `[400]`.

## Requirements

- Dart SDK `>=3.9.2`
- Windows 7+ (DirectWrite is preinstalled) **or** macOS 10.13+ (CoreText is preinstalled)
