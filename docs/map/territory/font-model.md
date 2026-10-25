# font-model

## What it is
The value types a scan returns: `FontFamily`, `FontFace`, `FontStyle`, `VariationAxis`, and the back-compat alias `WeightAxis`.

## Governing decisions
**None.** The 0.3.0 model refactor was planned in `ROADMAP_FACE_METADATA.md` and `ROADMAP_FACE_METADATA_PHASE1.md` (planning docs, not decision records). CHANGELOG 0.3.0 "Breaking" records the constructor change.

## Design model
From reading the source:
- Variation axes live on the family, not the face, because every face in a family shares one font resource (doc on `FontFamily`).
- `FontFamily.weights` is derived from `faces`: distinct weights, ascending. It is kept for compatibility with 0.2.x, where weights were stored (CHANGELOG 0.3.0).
- `WeightAxis` is a `typedef` for `VariationAxis` so 0.2.x `WeightAxis(...)` literals still compile.
- All types are immutable with value `==` and `hashCode`; `FontFamily` compares `faces` element-wise (`_listEquals`).
- `FontFace.filePath`, `postScriptName` and `fullName` are nullable: `null` means the platform did not expose a value.

## Code
- `lib/src/models.dart` — `FontFamily`, `FontFamily.weights`, `FontFamily._listEquals`, `FontFace`, `FontStyle`, `VariationAxis`, `WeightAxis`
- `test/just_font_scan_test.dart` — groups `FontFamily`, `FontFace`, `FontStyle`, `VariationAxis`, `WeightAxis typedef (back-compat)`

## Reference behaviour
- OpenType spec — `FontFace.stretch` follows OS/2 `usWidthClass`; the axis units on `VariationAxis` follow the registered-axis definitions (binding; see `docs/agents/thegraph.md`).

## Cross-cutting invariants
- [five-registered-axes](../invariant/five-registered-axes.md)
- [shared-value-scales](../invariant/shared-value-scales.md)

## Blast radius
- [windows-face-scan](windows-face-scan.md) and [macos-face-scan](macos-face-scan.md) — both construct every `FontFace` and `FontFamily` with named arguments; a new required field breaks both.
- [scan-api](scan-api.md) — `weightsFor` returns `FontFamily.weights`.
- [example-app](example-app.md) and [diagnostic-tools](diagnostic-tools.md) — they read the fields directly.
- [packaging-release](packaging-release.md) — a field change is a public API change: README's API reference and the CHANGELOG describe each field.

## Known holes / open
- README's "What this package does not provide" lists informational strings as a candidate `FontFace.info` sub-object; nothing commits to it.
