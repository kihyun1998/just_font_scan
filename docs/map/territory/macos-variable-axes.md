# macos-variable-axes

## What it is
Reading a family's variation axes on macOS from the descriptor's `kCTFontVariationAxesAttribute` array.

## Governing decisions
**None.** Planned in `ROADMAP_VARIABLE_FONTS.md` and `ROADMAP_FACE_METADATA_PHASE4.md`.

## Design model
From reading the source:
- Axes are read once per family name: the first descriptor with a non-empty set wins, since roman and italic descriptors of one variable font report the same ranges "in practice" (`_scanDescriptor`).
- Each axis dictionary needs an identifier, min, max and default; if any one is missing the axis is skipped (`_readAxisRange`).
- The axis identifier is read as an `Int64` and matched against the big-endian `kOpenType*Tag` constants; the first match per tag wins (`??=`).
- If the variation-axis symbols did not resolve (`b.variationAxes == null`), no axes are read.

## Code
- `lib/src/macos/macos_font_scanner.dart` — `_AxisSet`, `_emptyAxisSet`, `_axisSetIsEmpty`, `_copyAllAxes`, `_readAxisRange`, `_copyAxisDouble`

## Reference behaviour
- Apple CoreText headers — `kCTFontVariationAxis*Key` (binding).
- OpenType spec — registered axis tags (binding).

## Cross-cutting invariants
- [five-registered-axes](../invariant/five-registered-axes.md)
- [shared-value-scales](../invariant/shared-value-scales.md)
- [bounded-native-input](../invariant/bounded-native-input.md) — the axis count is clamped to `kMaxFontAxisCount`, shared with Windows.

## Blast radius
- [windows-variable-axes](windows-variable-axes.md) — `_AxisSet` is a separate copy of the same record there.
- [macos-face-scan](macos-face-scan.md) — keyed by its family name; a change to grouping changes which descriptor's axes win.
- [coretext-bindings](coretext-bindings.md) — `VariationAxisSymbols` decides whether this runs at all.

## Known holes / open
- Multi-axis families (SF Pro `wght` + `opsz`, New York) are not verified on a real Mac (`ROADMAP_FACE_METADATA_PHASE4.md` unchecked; maintainer, 2026-10-25).
