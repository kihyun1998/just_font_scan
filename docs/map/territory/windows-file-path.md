# windows-file-path

## What it is
Resolving `FontFace.filePath` on Windows: from the face's first font file, through `IDWriteLocalFontFileLoader`, or by parsing the reference key when that interface is refused.

## Governing decisions
**None.** CHANGELOG 0.3.0 "Fixed" records the fallback.

## Design model
From reading the source:
- Only the first file `GetFiles` reports is used; every returned file pointer is released.
- Preferred path: `QueryInterface(IDWriteLocalFontFileLoader)` on the file's loader, then `GetFilePathFromKey`.
- Fallback: Windows 11's font-cache loader refuses that `QueryInterface` with `E_NOINTERFACE`, so `_extractPathFromSystemKey` parses the reference key. Layout A (tag `0x002A` at byte 8) carries a bare filename, resolved against `%SystemRoot%\Fonts`, then `%LOCALAPPDATA%\Microsoft\Windows\Fonts`; if neither exists it still returns the first candidate. Layout B carries an absolute path starting with a drive letter or `\`.
- The key layout is reverse-engineered, not documented (doc on `_extractPathFromSystemKey`).

## Code
- `lib/src/windows/windows_font_scanner.dart` — `_tryGetFontFilePath`, `_readFacePath`, `_readFilePathFromFile`, `_extractPathFromSystemKey`, `_readLocalFilePath`
- `tool/debug_filepath.dart` — `_probe`, which dumps reference keys for named families

## Reference behaviour
- Measured 100% filePath coverage on one Windows 11 machine, 1165 faces in 217 families (CHANGELOG 0.3.0 "Fixed", commit `3193a1a`, 2026-04-23).

## Cross-cutting invariants
- [bounded-native-input](../invariant/bounded-native-input.md)

## Blast radius
- [windows-face-scan](windows-face-scan.md) — this runs once per face, so a slow or throwing path step slows or empties the whole scan.
- [directwrite-bindings](directwrite-bindings.md) — the `IDWriteFontFile` and local-loader slot indices are its.

## Known holes / open
- Layout A returns a path that may not exist when neither candidate file is found.
- A secondary file (pfb + pfm pairs) is never reported.
- The key layouts may change in a future Windows build; nothing would detect it except a drop in `tool/scan_faces.dart` coverage.
