# just_font_scan

Dart package to scan system font families, faces, variation axes, and file paths using platform-native APIs.

- **Windows**: DirectWrite COM API (`dwrite.dll`) via `dart:ffi`
- **macOS**: CoreText framework via `dart:ffi`

## Features

- Retrieves all system font families grouped by the platform's native family grouping (e.g. "Source Code Pro" is one family with multiple faces, not separate entries per variant)
- Reports **every face** within a family — weight, style (normal/italic/oblique), stretch (1–9), face name ("Bold Italic"), PostScript name, full name, `isMonospace`, `isSymbol`
- Resolves the **absolute file path** of each face (falls back to reference-key parsing on Windows 11 where the font-cache loader hides the local loader)
- Detects OpenType **variable fonts** and exposes all five registered axes (`wght`, `wdth`, `slnt`, `ital`, `opsz`) as `min` / `max` / `default` triples
- Results cached after first scan; repeated `clearCache() → scan()` cycles are memory-safe (verified 1500 scans under ±1 MB steady state on both platforms)
- No native build step — pure `dart:ffi` with system libraries

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

A system font family — a named group of `FontFace` entries plus any family-level variation axes. Variation axes live on the family (not the face) because every face in the family shares the same underlying font resource.

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Family name (e.g. `'Arial'`, `'Source Code Pro'`). |
| `faces` | `List<FontFace>` | Individual faces belonging to this family. Always contains at least one entry when returned by the scanner. |
| `weights` | `List<int>` | Distinct weights declared by `faces`, in ascending order. Derived getter — preserved for backward compatibility with 0.3.x. |
| `weightAxis` | `VariationAxis?` | Continuous `wght` axis range when the family includes a variable font. `null` for static-only families. |
| `widthAxis` | `VariationAxis?` | Continuous `wdth` axis (width). `null` when absent. |
| `slantAxis` | `VariationAxis?` | Continuous `slnt` axis (slant in degrees, typically negative). `null` when absent. |
| `italicAxis` | `VariationAxis?` | Continuous `ital` axis (usually 0.0 or 1.0). `null` when absent. |
| `opticalSizeAxis` | `VariationAxis?` | Continuous `opsz` axis (optical size in points). `null` when absent. |

Supports equality (`==`) and can be used as a map key.

### `FontFace` class

A single face within a family (e.g. "Regular", "Bold Italic"). Each face corresponds to a distinct entry reported by the platform — typically a physical font file on disk for static fonts, or a named instance of a variable font resource.

| Property | Type | Description |
|----------|------|-------------|
| `weight` | `int` | CSS weight (1–1000). Common values: 400 (Regular), 700 (Bold). |
| `style` | `FontStyle` | `normal`, `italic`, or `oblique`. |
| `stretch` | `int` | Width class (1 = Ultra-Condensed … 5 = Normal … 9 = Ultra-Expanded). Follows the OpenType OS/2 `usWidthClass` convention. |
| `faceName` | `String` | Sub-family name as reported by the OS (e.g. `"Regular"`, `"Bold Italic"`). |
| `postScriptName` | `String?` | OpenType PostScript name — the canonical identifier for font matching in CSS / PDF / PostScript. |
| `fullName` | `String?` | Human-readable full name (e.g. `"Arial Bold Italic"`). |
| `filePath` | `String?` | Absolute path to the backing font file. `null` when the face is backed by a non-local loader (memory / remote). |
| `isMonospace` | `bool` | True if every glyph has the same advance width. |
| `isSymbol` | `bool` | True if the face contains symbol glyphs (e.g. Wingdings) rather than textual ones. |

### `FontStyle` enum

| Value | Meaning |
|-------|---------|
| `normal` | Upright. |
| `italic` | A designed italic variant — typically has different letterforms from the upright. |
| `oblique` | A slanted upright. Often synthesized from the normal face by the OS. |

### `VariationAxis` class

Continuous variation axis range for an OpenType variable font.

| Property | Type | Description |
|----------|------|-------------|
| `min` | `int` | Minimum supported value (inclusive). |
| `max` | `int` | Maximum supported value (inclusive). |
| `defaultValue` | `int` | Default value used when no explicit axis value is requested. |

**Units depend on the axis** — see the table below. Platform-reported floats are rounded to the nearest integer.

| Axis | Field on `FontFamily` | Typical unit |
|------|----------------------|--------------|
| `wght` | `weightAxis` | CSS weight (1–1000) |
| `wdth` | `widthAxis` | width percentage (e.g. 50–200) |
| `slnt` | `slantAxis` | slant degrees (often negative, e.g. −20 … 0) |
| `ital` | `italicAxis` | 0.0 (upright) or 1.0 (italic) |
| `opsz` | `opticalSizeAxis` | point size (e.g. 8 … 144) |

`WeightAxis` is preserved as a `typedef` alias for `VariationAxis` so 0.3.x code keeps compiling.

### `JustFontScan` class

All methods are static. No instantiation needed.

#### `JustFontScan.scan()`

```dart
static List<FontFamily> scan()
```

Scans all system font families. Returns a list sorted alphabetically by family name.

- **Returns**: `List<FontFamily>` — all font families found on the system.
- **Caching**: Results are cached after the first call. Subsequent calls return the cached list instantly.
- **Error handling**: Returns `[]` if the platform is unsupported or a native API error occurs. Never throws.
- **Thread safety**: The cache is isolate-local. Calling `scan()` from different isolates triggers separate scans.

#### `JustFontScan.clearCache()`

```dart
static void clearCache()
```

Clears the cached scan result. The next `scan()` call will rescan. Use this after fonts have been installed or removed.

#### `JustFontScan.weightsFor()`

```dart
static List<int> weightsFor(String familyName)
```

Returns the supported weights for a specific family (case-insensitive).

- **Not found**: Returns `[400]` as a default. To distinguish "found with only weight 400" from "not found", use `scan()` directly.

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

Not all fonts support every weight.

#### macOS weight caveat

macOS CoreText reports weight as a normalized float in the range `−1.0` to `1.0`. `just_font_scan` snaps each value to the nearest bucket in Apple's `NSFontWeight` table and reports the corresponding CSS weight. This is an **approximation** — a font whose native weight is e.g. `0.36` (between Semibold `0.30` and Bold `0.40`) reports as `700` because it is closer to Bold. On Windows, `DWRITE_FONT_WEIGHT` values map 1:1, so Windows results are exact.

The CSS weight `950` (ExtraBlack) is never produced on macOS because no public `NSFontWeight` constant corresponds to it.

### Variable fonts

When a family contains an OpenType variable font (`fvar` table), any of the five axis fields on `FontFamily` may be populated. Axes the font does not declare remain `null`.

A family can have both a continuous axis and a set of discrete named instances — the `faces` list contains the named-instance entries, and the axis fields describe the continuous range supported by the underlying variable face:

| Family example | faces weights | axes populated |
|----------------|--------------|----------------|
| `Arial` (static) | `[400, 700, 900]` | all `null` |
| `Cascadia Code` | `[200, 300, 350, 400, 600, 700]` | `weightAxis: 200–700`, `widthAxis`, `slantAxis`, `italicAxis` (fixed ranges) |
| `Segoe UI Variable Display` | `[300, 350, 400, 600, 700]` | `weightAxis: 300–700`, `opticalSizeAxis: 5–36`, plus fixed `wdth`/`slnt`/`ital` |

Note: many variable fonts declare axes with `min == max` (a single-value range). The font technically supports the axis but offers only one value; UIs should hide sliders in that case.

**Platform notes**

- **Windows**: requires Windows 10 1803 (build 17134) or newer for the `IDWriteFontFace5` interface used to read variation axes. On older builds the QueryInterface fails silently and all five axis fields remain `null` — the rest of the scan still works.
- **macOS**: variation axes are read via `kCTFontVariationAxesAttribute`, available since macOS 10.5. The system font (`SF Pro`) is itself a variable font but is hidden under the internal name `.AppleSystemUIFont` and filtered out by the `.`-prefix rule.

### File path resolution

Most faces expose an absolute path via `FontFace.filePath`. Edge cases:

- **Memory / remote loaders**: fonts loaded from memory or downloaded on demand have no local file — `filePath` is `null`.
- **Windows 11 font-cache service**: `IDWriteLocalFontFileLoader::QueryInterface` returns `E_NOINTERFACE` for system fonts on current Windows 11 builds. `just_font_scan` falls back to parsing the reference-key bytes, which contain either a filename (combined with `%SystemRoot%\Fonts`) or an absolute path. Both user-installed and app-packaged fonts are handled.

## Usage

### Basic scan

```dart
import 'package:just_font_scan/just_font_scan.dart';

final families = JustFontScan.scan();

for (final family in families) {
  print(family.name);
  for (final face in family.faces) {
    print('  ${face.faceName}: w=${face.weight}, ${face.style.name}, '
          's=${face.stretch}, path=${face.filePath}');
  }
}
// Arial
//   Regular: w=400, normal, s=5, path=C:\Windows\Fonts\arial.ttf
//   Italic:  w=400, italic, s=5, path=C:\Windows\Fonts\ariali.ttf
//   Bold:    w=700, normal, s=5, path=C:\Windows\Fonts\arialbd.ttf
//   ...
```

### Query a specific family

```dart
final weights = JustFontScan.weightsFor('Source Code Pro');
print(weights); // [200, 300, 400, 500, 600, 700, 800, 900]

final missing = JustFontScan.weightsFor('NonExistentFont');
print(missing); // [400]  (default fallback)
```

### Find italic faces

```dart
final families = JustFontScan.scan();
final italics = [
  for (final f in families)
    for (final face in f.faces)
      if (face.style == FontStyle.italic) '${f.name} ${face.faceName}',
];
```

### Filter monospace fonts

```dart
final monoFamilies = JustFontScan.scan().where(
  (f) => f.faces.any((face) => face.isMonospace),
);
```

### Detect variable fonts

```dart
bool hasAnyAxis(FontFamily f) =>
    f.weightAxis != null ||
    f.widthAxis != null ||
    f.slantAxis != null ||
    f.italicAxis != null ||
    f.opticalSizeAxis != null;

for (final f in JustFontScan.scan().where(hasAnyAxis)) {
  print(f.name);
  if (f.weightAxis != null) print('  wght: ${f.weightAxis}');
  if (f.opticalSizeAxis != null) print('  opsz: ${f.opticalSizeAxis}');
}
```

### Render a specific weight from a variable font

```dart
// In a Flutter widget
final family = families.firstWhere((f) => f.name == 'Segoe UI Variable Display');
final axis = family.weightAxis!;

Text(
  'Adjustable weight',
  style: TextStyle(
    fontFamily: family.name,
    fontVariations: [FontVariation('wght', 550.0)], // anywhere in axis.min..axis.max
  ),
);
```

### Rescan after font installation

```dart
JustFontScan.clearCache();
final updated = JustFontScan.scan();
```

## What this package does not provide

These are intentional non-goals. File issues if strongly needed.

- **Informational strings** (designer, copyright, license, trademark, manufacturer, sample text, version) — retrievable from both platforms but rarely used; candidates for a future `FontFace.info` sub-object.
- **Font metrics** (ascent, descent, xHeight, capHeight) — rendering-library territory.
- **Supported Unicode ranges** — bulky data, specialized use case.
- **OpenType feature tags** (`liga`, `smcp`, …) — CoreText exposes them but DirectWrite does not have a direct API; cross-platform parity not yet achievable.
- **Serif / sans / display classification** — requires parsing the OS/2 PANOSE bytes from the font file; no native API on either platform.

## Platform support

| Platform | Status | API |
|----------|--------|-----|
| Windows  | Supported | DirectWrite (`IDWriteFactory`, `IDWriteFont`, `IDWriteFont1`, `IDWriteFontFace5`) |
| macOS    | Supported | CoreText (`CTFontCollection`, `CTFontDescriptor`) |
| Linux    | Not yet | — |

On unsupported platforms, `scan()` returns an empty list and `weightsFor()` always returns `[400]`.

## Requirements

- Dart SDK `>=3.0.0`
- Windows 8+ (DirectWrite with `IDWriteFont1` preinstalled) — variation axes require Windows 10 1803+
- macOS 10.13+ (CoreText preinstalled)

## Migration from 0.2.x

The only breaking change is the `FontFamily` constructor signature. Read-only access is untouched.

```dart
// 0.2.x
final f = FontFamily(name: 'Arial', weights: [400, 700]);

// 0.3.x
final f = FontFamily(
  name: 'Arial',
  faces: [
    FontFace(
      weight: 400, style: FontStyle.normal, stretch: 5,
      faceName: 'Regular', postScriptName: null, fullName: null,
      filePath: null, isMonospace: false, isSymbol: false,
    ),
    FontFace(
      weight: 700, style: FontStyle.normal, stretch: 5,
      faceName: 'Bold', postScriptName: null, fullName: null,
      filePath: null, isMonospace: false, isSymbol: false,
    ),
  ],
);
// f.weights still returns [400, 700].
// WeightAxis literals keep compiling — WeightAxis is a typedef for VariationAxis.
```

In practice, only **tests and mocks** need to construct `FontFamily` directly — real code just reads the values returned by `JustFontScan.scan()`, so most callers need no changes.
