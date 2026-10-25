# macos-face-scan

## What it is
The macOS scan: every font descriptor from `CTFontCollectionCreateFromAvailableFonts`, grouped into families by family name, with each descriptor read into a `FontFace` — traits, style, names and file URL.

## Governing decisions
**None.** Planned in `ROADMAP_MACOS.md` and `ROADMAP_FACE_METADATA_PHASE3.md`.

## Design model
From reading the source:
- CoreText returns faces, not families; a family is every descriptor that has the same `kCTFontFamilyNameAttribute` string (`_scanDescriptorArray`). Windows uses DirectWrite's own family grouping instead.
- Families whose names start with `.` are Apple-internal and skipped; this hides `.AppleSystemUIFont` (SF Pro) too (README, "Platform notes").
- The whole scan runs inside one autorelease pool (`_scanWithArena`).
- A missing traits dictionary gives weight 400, stretch 5, slant 0, no symbolic traits.
- Style: the italic trait bit wins; otherwise `|slant| > 0.1` is oblique (`_deriveStyle`, `_kObliqueSlantThreshold`). The threshold was raised from 0.05 because upright faces can carry a small non-zero slant (CHANGELOG 0.3.0 "Fixed").
- Symbolic traits are read as `Int32` and masked to unsigned; `isSymbol` is the class mask equal to `kCTFontClassSymbolic`.
- `filePath` is the descriptor's URL in a fixed 4096-byte buffer.
- The family count is truncated to `kMaxFontFamilyCount` after sorting.

## Code
- `lib/src/macos/macos_font_scanner.dart` — `scanFonts`, `_scanWithArena`, `_scanInPool`, `_scanDescriptorArray`, `_scanDescriptor`, `_buildFace`, `_readWeightFromTraits`, `_readStretchFromTraits`, `_readSlantFromTraits`, `_readSymbolicFromTraits`, `_kObliqueSlantThreshold`, `_deriveStyle`, `_copyStringAttribute`, `_copyFilePath`, `_copyFamilyName`, `_cfStringToDart`
- `test/macos_scan_integration_test.dart` — `@TestOn('mac-os')`

## Reference behaviour
- Apple CoreText headers — `kCTFontTraitsAttribute` contents and `CTFontSymbolicTraits` bits (binding).

## Cross-cutting invariants
- [best-effort-scan](../invariant/best-effort-scan.md)
- [bounded-native-input](../invariant/bounded-native-input.md)
- [family-order](../invariant/family-order.md)
- [shared-value-scales](../invariant/shared-value-scales.md)

## Blast radius
- [macos-value-mapping](macos-value-mapping.md) — weight and stretch arrive through it.
- [macos-variable-axes](macos-variable-axes.md) — runs per descriptor inside this loop and keys its result by the same family name.
- [windows-face-scan](windows-face-scan.md) — the same `FontFace` fields must mean the same thing on both platforms.
- [coretext-bindings](coretext-bindings.md) — the pool and the ownership rules are its.

## Known holes / open
- Not verified end-to-end on a real Mac since the face metadata landed: SF Pro / Helvetica Neue faces, `/System/Library/Fonts/` paths, Menlo monospace, italic style, unique PostScript names (`ROADMAP_FACE_METADATA_PHASE3.md` unchecked; maintainer, 2026-10-25).
- Grouping by name string can merge two distinct families that share a name, which DirectWrite would keep apart; not investigated.
