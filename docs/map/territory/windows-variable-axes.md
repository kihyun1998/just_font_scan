# windows-variable-axes

## What it is
Reading a family's variation axes on Windows through `IDWriteFontFace5` and `IDWriteFontResource`.

## Governing decisions
**None.** Planned in `ROADMAP_VARIABLE_FONTS.md` and `ROADMAP_FACE_METADATA_PHASE4.md`.

## Design model
From reading the source:
- Axes are read from the first face that has any, then reused for the family: faces of one variable font share one resource (`_getFamilyFacesAndAxes`).
- `QueryInterface(IDWriteFontFace5)` fails before Windows 10 1803; that and every other failure yields an empty axis set (`_tryReadAllAxes`).
- Ranges and defaults come from separate calls. A missing default falls back to `(min + max) / 2`.

## Code
- `lib/src/windows/windows_font_scanner.dart` — `_AxisSet`, `_emptyAxisSet`, `_axisSetIsEmpty`, `_tryReadAllAxes`, `_readAllAxesFromResource`, `_isRegisteredAxisTag`

## Reference behaviour
- Windows SDK `dwrite_3.h` — `IDWriteFontFace5`, `IDWriteFontResource`, `DWRITE_FONT_AXIS_RANGE` (binding).
- OpenType spec — registered axis tags (binding).

## Cross-cutting invariants
- [five-registered-axes](../invariant/five-registered-axes.md)
- [shared-value-scales](../invariant/shared-value-scales.md)
- [bounded-native-input](../invariant/bounded-native-input.md)

## Blast radius
- [macos-variable-axes](macos-variable-axes.md) — `_AxisSet` is a separate copy of the same record there, so a change in its shape is needed in both.
- [windows-face-scan](windows-face-scan.md) — runs inside its face loop.

## Known holes / open
- A missing default falls back to the midpoint here but drops the axis on macOS ([shared-value-scales](../invariant/shared-value-scales.md)).
