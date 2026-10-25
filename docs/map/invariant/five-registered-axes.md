# Five registered axes

## The fact
The package recognises exactly the five registered OpenType variation axes — `wght`, `wdth`, `slnt`, `ital`, `opsz` — and maps each to one `FontFamily` field (`weightAxis`, `widthAxis`, `slantAxis`, `italicAxis`, `opticalSizeAxis`). Any other axis tag a font declares is ignored.

## Why it is cross-cutting
The five-tag set is written out independently at each site: as little-endian `FOUR_CC` constants on Windows, as big-endian tags on macOS, as five named fields in the model, and as a five-way "has any axis" predicate in every consumer. No site calls another or reads the set from one shared list. Adding a sixth axis at one site without the others drops it silently on one platform, or leaves a consumer blind to it.

## Territories it holds in
- [windows-variable-axes](../territory/windows-variable-axes.md) — `_isRegisteredAxisTag` and the five `build(...)` calls in `_readAllAxesFromResource`.
- [directwrite-bindings](../territory/directwrite-bindings.md) — `kDWriteFontAxisTag*` constants.
- [macos-variable-axes](../territory/macos-variable-axes.md) — the `switch (tag)` in `_copyAllAxes`.
- [coretext-bindings](../territory/coretext-bindings.md) — `kOpenType*Tag` constants.
- [font-model](../territory/font-model.md) — the five axis fields on `FontFamily`, its `==`, `hashCode` and `toString`.
- [diagnostic-tools](../territory/diagnostic-tools.md) — `tool/scan_variable.dart — _anyAxis`.
- [example-app](../territory/example-app.md) — `font_list_page.dart — _hasAnyAxis`, `font_family_tile.dart — _FontFamilyTileState._hasAnyAxis`, and the tag list in `_VfAxisSummary`.

## What a violation looks like
A family whose axis is populated on one platform and `null` on the other, or one that the example app's "variable only" filter leaves out even though an axis field is set.

## Discovery history
- Read from the code at `a0ac921` (2026-04-23). The five-axis generalisation landed in `3193a1a` (CHANGELOG 0.3.0, "Added — variable-font axes").
- `test/axis_tag_test.dart` checks the two platforms' tag packings against each other; it checks the constants, not that every site uses all five.

## Where it will recur
Any function that enumerates variation axes or tests whether a family is variable is subject to this. `git grep -nE 'opticalSize|opsz'` lists the current sites.
