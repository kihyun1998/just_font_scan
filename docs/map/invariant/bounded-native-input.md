# Bounded native input

## The fact
Every count or length a platform API returns is capped before it sizes a loop, an allocation or a string read. The caps are `kMaxFontFamilyCount`, `kMaxFontNameLength` and `kMaxFontAxisCount` (`lib/src/limits.dart`, shared), `kMaxFontCount`, `kMaxFontPathLength` and `kMaxFilesPerFace` (Windows, `dwrite_bindings.dart`), and `kMaxDescriptorCount` (macOS, `coretext_bindings.dart`).

## Why it is cross-cutting
The values come from the OS's font stack, which reads font files the user installed. Each scanner clamps at its own call sites, and only three of the caps are shared. A count left unclamped at any one site lets a corrupt font cache drive an unbounded native read.

## Territories it holds in
- [windows-face-scan](../territory/windows-face-scan.md) — `_scanCollection` (family count), `_getFamilyFacesAndAxes` (face count), `_getLocalizedString` (name length).
- [windows-file-path](../territory/windows-file-path.md) — `_readFacePath` (file count), `_readLocalFilePath` and `_extractPathFromSystemKey` (path length).
- [windows-variable-axes](../territory/windows-variable-axes.md) — `_readAllAxesFromResource` (axis count).
- [macos-face-scan](../territory/macos-face-scan.md) — `_scanDescriptorArray` (descriptor count; family count after grouping), `_cfStringToDart` and `_copyFamilyName` (name length), `_copyFilePath` (fixed 4096-byte buffer).
- [macos-variable-axes](../territory/macos-variable-axes.md) — `_copyAllAxes` (axis count).

## Measured values
- `kMaxFontAxisCount` is 64. Variable fonts in the wild use 1–6 axes (`wght`, `wdth`, `slnt`, `ital`, `opsz`, sometimes one custom axis), so 64 leaves headroom and affects only malformed fonts. The cap changed no family's output in a Windows 11 scan, while lowering it to 1 changed 14 families (#4).
- Above the cap, the two scanners differ. Windows returns no axes, because `GetFontAxisRanges` fails when the buffer is smaller than the real count. macOS reads the first 64 (#4).

## What a violation looks like
A hang, or a native read past a buffer, triggered by one malformed font.

## Discovery history
- Limits were shared across platforms in `65ff8f1` (2026-04-21).
- The reference-key path cap was added in `a0ac921` (2026-04-23) after the gap was found: CHANGELOG 0.3.0, "cap reference-key path length".
- The macOS axis-count gap was found by reading at `a0ac921` while writing this note (2026-10-25). It was closed by sharing `kMaxFontAxisCount` and clamping in `_copyAllAxes` (#4).

## Where it will recur
Any function that reads a count, size or length from an FFI call is subject to this.
