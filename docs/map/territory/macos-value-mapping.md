# macos-value-mapping

## What it is
Converting CoreText's normalised weight and width floats (−1.0…1.0) to the integer scales the model uses: `mapWeight` to CSS weight, `mapStretch` to `usWidthClass` 1–9.

## Governing decisions
**None.** `ROADMAP_MACOS.md` §5.2 holds the snap table.

## Design model
From reading the source:
- `mapWeight` snaps to the nearest of nine `NSFontWeight` buckets (100 at −0.80 … 900 at 0.62); a tie goes to the lighter weight. NaN or out-of-range input gives 400. It never produces 950, since no public `NSFontWeight` constant maps to it (README, "macOS weight caveat").
- `mapStretch` is `(normalized * 4 + 5).round().clamp(1, 9)`; NaN or out-of-range input gives 5.
- Both are top-level so they can be tested off a Mac; neither is exported from the library.

## Code
- `lib/src/macos/macos_font_scanner.dart` — `mapWeight`, `_WeightBucket`, `mapStretch`
- `test/macos_weight_mapping_test.dart`, `test/macos_stretch_mapping_test.dart`

## Reference behaviour
- Apple `NSFontWeight` constants — the bucket values (binding; summarized docs, `ROADMAP_MACOS.md` §5.2).

## Cross-cutting invariants
- [shared-value-scales](../invariant/shared-value-scales.md)

## Blast radius
- [macos-face-scan](macos-face-scan.md) — every face's weight and stretch go through these.
- [packaging-release](packaging-release.md) — the README's macOS weight caveat describes this approximation.

## Known holes / open
**None.**
