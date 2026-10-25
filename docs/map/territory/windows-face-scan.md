# windows-face-scan

## What it is
The Windows scan: COM initialisation, the DirectWrite system font collection walked family by family, and each `IDWriteFont` read into a `FontFace` — names, weight, style, stretch, symbol and monospace flags — plus the assembly of `FontFamily`.

## Governing decisions
**None.** Planned in `ROADMAP.md` and `ROADMAP_FACE_METADATA_PHASE2.md`.

## Design model
From reading the source:
- `CoInitializeEx` runs apartment-threaded on every scan; `CoUninitialize` runs only if that call returned `S_OK` or `S_FALSE`, so a thread already in another apartment is left alone.
- A family is DirectWrite's family. Families named with a leading `@` (vertical-writing fonts) are skipped, as are families with no name or no faces.
- Names are read in `en-us` first, then index 0 (`_getLocalizedString`).
- A face whose weight falls outside 1–1000 is dropped; stretch 0 (UNDEFINED) or out of range becomes 5.
- `isMonospace` needs `IDWriteFont1`; a failed `QueryInterface` reports `false` (`_tryIsMonospace`).
- The file path and variable axes are read per face by the two territories below.

## Code
- `lib/src/windows/windows_font_scanner.dart` — `scanFonts`, `_scanFontsWithArena`, `_createFactoryAndScan`, `_scanWithFactory`, `_scanCollection`, `_scanFamily`, `_getFamilyName`, `_getLocalizedString`, `_getFamilyFacesAndAxes`, `_buildFontFace`, `_dwriteStyleToEnum`, `_dwriteStretchToInt`, `_getFaceName`, `_getInformationalString`, `_tryIsMonospace`

## Reference behaviour
- Windows SDK `dwrite.h` / `dwrite_1.h` — `DWRITE_FONT_STRETCH`, `DWRITE_FONT_STYLE`, `DWRITE_INFORMATIONAL_STRING_ID` values (binding).

## Cross-cutting invariants
- [best-effort-scan](../invariant/best-effort-scan.md)
- [bounded-native-input](../invariant/bounded-native-input.md)
- [family-order](../invariant/family-order.md)
- [shared-value-scales](../invariant/shared-value-scales.md)

## Blast radius
- [windows-file-path](windows-file-path.md) and [windows-variable-axes](windows-variable-axes.md) — they run inside this per-face loop and share its arena and the `IDWriteFont` lifetime.
- [macos-face-scan](macos-face-scan.md) — the same `FontFace` fields must mean the same thing on both platforms.
- [font-model](font-model.md) — this builds the model.

## Known holes / open
- No test runs on Windows: `test/` has a `@TestOn('mac-os')` integration test and nothing for Windows.
