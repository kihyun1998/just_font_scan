# example-app

## What it is
The Flutter demo under `example/`: it scans, lists families with their faces and axes, filters by variable or monospace, and previews a variable font at a chosen weight. It depends on the package through `path: ../` and is not published (`publish_to: 'none'`).

## Governing decisions
**None.** `ROADMAP_FACE_METADATA_PHASE5.md` planned its current form.

## Design model
From reading the source:
- `FontListPage` calls `JustFontScan.scan()`; its refresh calls `clearCache()` first.
- "Variable" means any of the five axis fields is non-null (`_hasAnyAxis`, written twice: in `font_list_page.dart` and as `_FontFamilyTileState._hasAnyAxis`).
- The preview handles `wght` only: its slider starts at `weightAxis.defaultValue` (`_FontListPageState`) and renders through `FontVariation('wght', …)` (`VariablePreview`).
- Platform runners exist for Windows and macOS only (`example/windows`, `example/macos`).

## Code
- `example/lib/main.dart` — `MyApp`
- `example/lib/font_list_page.dart` — `_hasAnyAxis`, `_hasMonospaceFace`, `FontListPage`, `_FontListPageState`
- `example/lib/font_family_tile.dart` — `FontFamilyTile`, `_FontFamilyTileState._hasAnyAxis`, `_FaceList`, `_VfAxisSummary`, `_CountChip`, `_FlagChip`
- `example/lib/variable_preview.dart` — `VariablePreview`
- `example/pubspec.yaml`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [five-registered-axes](../invariant/five-registered-axes.md)

## Blast radius
- [packaging-release](packaging-release.md) — the example's SDK constraint (`^3.9.2`) is separate from the package's (`>=3.0.0`); a dependency PR grouped for `/example` resolves through `path: ../` (#3).

## Known holes / open
- `flutter run` is not verified on both platforms (`ROADMAP_FACE_METADATA_PHASE5.md` unchecked).
