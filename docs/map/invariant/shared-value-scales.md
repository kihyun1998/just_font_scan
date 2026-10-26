# Shared value scales

## The fact
Both platforms report face values on the same integer scales: `FontFace.weight` is a CSS weight (1–1000), `FontFace.stretch` is the OpenType `usWidthClass` 1–9 (5 = normal, also the fallback), and every `VariationAxis` value is the platform float rounded to the nearest integer. A `VariationAxis` is reported only when its min, max and default were all read. No value is synthesised, so an axis with a missing value is `null` on both platforms.

## Why it is cross-cutting
Windows reads these natively and only range-checks them. macOS converts them from CoreText's normalised −1.0…1.0 floats. The two conversions live in different scanners and share no code; the scale itself is what the model's doc comments promise. Changing a fallback or a rounding rule on one side only makes the same font report different numbers per platform.

## Territories it holds in
- [windows-face-scan](../territory/windows-face-scan.md) — `_buildFontFace` drops faces outside `kDWriteFontWeightMin`…`kDWriteFontWeightMax`; `_dwriteStretchToInt` maps out-of-range to 5.
- [macos-value-mapping](../territory/macos-value-mapping.md) — `mapWeight` (fallback 400), `mapStretch` (fallback 5).
- [macos-face-scan](../territory/macos-face-scan.md) — `_buildFace` defaults to 400 / 5 when the traits dictionary is missing.
- [windows-variable-axes](../territory/windows-variable-axes.md) and [macos-variable-axes](../territory/macos-variable-axes.md) — `.round()` in `_readAllAxesFromResource` and `_readAxisRange`.
- [font-model](../territory/font-model.md) — the scales as documented on `FontFace.weight`, `FontFace.stretch`, `VariationAxis`.

## What a violation looks like
The same family shows different `weights` or `stretch` per platform beyond the documented macOS approximation (README, "macOS weight caveat").

## Discovery history
- Read from the code at `a0ac921` (2026-04-23). CHANGELOG 0.3.0 states the intent of `mapStretch`: "keeping the two platforms on a shared integer scale".
- The platforms differed on a missing axis default: Windows fell back to `(min + max) / 2`, while macOS dropped the axis. Both now drop it (maintainer, 2026-10-26, #5). The OpenType `fvar` spec makes `defaultValue` a fixed field of every `VariationAxisRecord`, so a missing default means a failed platform read, not missing font data.

## Where it will recur
Any function that turns a platform-reported weight, width, slant or axis value into a model field is subject to this.
