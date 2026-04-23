## 0.3.0

### Breaking (vs 0.2.0)

- `FontFamily` constructor now takes `faces: List<FontFace>` instead of `weights: List<int>`. `weights` is preserved as a derived getter (`faces.map((f) => f.weight).toSet().toList()..sort()`) so read-only call sites keep working.

Migration:

```dart
// 0.2.x
FontFamily(name: 'Arial', weights: [400, 700]);

// 0.3.x
FontFamily(
  name: 'Arial',
  faces: [
    FontFace(weight: 400, style: FontStyle.normal, stretch: 5, faceName: 'Regular', ...),
    FontFace(weight: 700, style: FontStyle.normal, stretch: 5, faceName: 'Bold', ...),
  ],
);
// family.weights still returns [400, 700].
```

### Added — variable-font axes

- feat: detect OpenType variable fonts and expose all five registered axes on `FontFamily`: `weightAxis` (`wght`), `widthAxis` (`wdth`), `slantAxis` (`slnt`), `italicAxis` (`ital`), `opticalSizeAxis` (`opsz`). Each is a `VariationAxis?` with `min` / `max` / `defaultValue`.
- feat: Windows reads variation axes via `IDWriteFontFace5` + `IDWriteFontResource` (DirectWrite, Windows 10 1803+); silently falls back to all-null axes on older builds.
- feat: macOS reads variation axes via `kCTFontVariationAxesAttribute` (CoreText 10.5+).

### Added — face metadata

- feat: `FontFace` class exposes per-face metadata: `weight`, `style`, `stretch`, `faceName`, `postScriptName`, `fullName`, `filePath`, `isMonospace`, `isSymbol`.
- feat: `FontStyle` enum: `normal`, `italic`, `oblique`.
- feat: `VariationAxis` class (generalized from 0.2.x's internal weight-axis concept). `WeightAxis` is preserved as a `typedef VariationAxis` so `WeightAxis(...)` literals keep compiling.
- feat: Windows reads face-level `stretch`, `style`, `isSymbolFont`, `isMonospacedFont`, PostScript name, full name, and file path via `IDWriteFont`, `IDWriteFont1`, `IDWriteFontFace::GetFiles`, and `IDWriteLocalFontFileLoader` (with a reference-key-parsing fallback for Windows 11 font-cache service — see Fixed).
- feat: macOS reads face-level `stretch`, `style`, symbolic traits, PostScript name, display name, and file URL via `CTFontDescriptorCopyAttribute` and `CFURLGetFileSystemRepresentation`.
- feat: `mapStretch(double) → int` helper — snaps CoreText normalized width (`−1.0 … 1.0`) to the 1–9 OpenType `usWidthClass` scale used by DirectWrite, keeping the two platforms on a shared integer scale.

### Added — tooling

- feat: `tool/scan_variable.dart` — lists variable-font families and their five axes with coverage stats.
- feat: `tool/scan_faces.dart` — dumps face-level metadata and computes coverage stats (filePath, postScriptName, isMonospace, style) across the system.

### Fixed

- fix: Windows 11 file-path extraction works around the font-cache service loader refusing `QueryInterface(IDWriteLocalFontFileLoader)` (`E_NOINTERFACE`) by parsing the reference key directly. Two key layouts handled: system fonts (`0x002A` tag + filename, resolved against `%SystemRoot%\Fonts`) and user/app-packaged fonts (absolute UTF-16 path). Observed 100% filePath coverage on a Windows 11 machine (1165 faces across 217 families).

### Non-breaking

- `FontFamily.weightAxis` is additive vs 0.2.0; the four new axis fields default to `null` when the font does not declare them.
- Read-only usage (`family.name`, `family.weights`, `family.weightAxis`) continues to work unchanged — only the `FontFamily` constructor signature changed (see Breaking).

## 0.2.0

- feat: macOS support via CoreText (`CTFontCollectionCreateFromAvailableFonts`)
- feat: weight mapping from CoreText normalized float (−1.0…1.0) to CSS weight (100–900) using Apple's `NSFontWeight` buckets
- feat: `.` prefix filter on macOS to hide system-internal fonts (e.g. `.SFUI-Regular`)
- fix: wrap each macOS scan in an Objective-C autorelease pool to drain CoreText-internal autoreleased objects (prevents ~1.3 MB/scan leak in Dart CLI processes, which have no Cocoa runloop)
- note: macOS weights are approximations — see README for caveat

## 0.1.0

- feat: system font family and weight scanning via Windows DirectWrite
- feat: `JustFontScan.scan()` returns font families sorted by name with caching
- feat: `JustFontScan.weightsFor()` queries supported weights for a specific family
- fix: COM null guards, absolute DLL paths, proper CoUninitialize for safety
