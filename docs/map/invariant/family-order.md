# Family order

## The fact
`scan()` returns families sorted by name, case-insensitively (`a.name.toLowerCase().compareTo(b.name.toLowerCase())`).

## Why it is cross-cutting
Each scanner sorts its own result; `JustFontScan.scan` does not sort and only promises "sorted by name" in its doc. Changing the comparison in one scanner only gives a different order per platform.

## Territories it holds in
- [windows-face-scan](../territory/windows-face-scan.md) — `_scanCollection`.
- [macos-face-scan](../territory/macos-face-scan.md) — `_scanDescriptorArray`, which sorts before truncating to `kMaxFontFamilyCount`.
- [scan-api](../territory/scan-api.md) — the contract in `JustFontScan.scan`'s doc.

## What a violation looks like
Families appear in a different order on Windows and macOS for the same set of names.

## Discovery history
- Read from the code at `a0ac921` (2026-04-23).

## Where it will recur
Any change to how a scanner builds its result list is subject to this.
