# Best-effort scan

## The fact
A scan never throws. A failure in one family or face skips that entry; a fatal failure returns an empty list.

## Why it is cross-cutting
Each platform's `scanFonts` wraps its whole scan in its own `try`/`catch` returning `const []`, and each inner step returns `null` or an empty set on a failed call rather than throwing. `JustFontScan.scan` relies on this and has no `try` of its own, so a throw that escaped one scanner would reach the caller.

## Territories it holds in
- [windows-face-scan](../territory/windows-face-scan.md) — `scanFonts`, and the `null` returns throughout `_scanFamily` / `_buildFontFace`.
- [macos-face-scan](../territory/macos-face-scan.md) — `scanFonts`, and `continue` on null descriptors in `_scanDescriptorArray`.
- [scan-api](../territory/scan-api.md) — `JustFontScan.scan`, `JustFontScan._scan`, and the `const []` returned on unsupported platforms.
- [directwrite-bindings](../territory/directwrite-bindings.md) — `_vtable` throws `StateError` on a null pointer, relying on the outer catch to turn a crash into an empty list.
- [coretext-bindings](../territory/coretext-bindings.md) — `MacFontBindings.load` throws on a missing symbol for the same reason; `_loadVariationAxisSymbols` catches and degrades to `null`.

## What a violation looks like
`JustFontScan.scan()` throws on a machine with an unusual font setup.

## Discovery history
- Read from the code at `a0ac921` (2026-04-23); stated in each `scanFonts` doc comment ("Best-effort").

## Where it will recur
Any new native call path is subject to this: it either returns a sentinel or throws only inside a scanner's outer `try`.
