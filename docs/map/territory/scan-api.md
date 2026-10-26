# scan-api

## What it is
The package's public entry point: `JustFontScan` with `scan`, `clearCache` and `weightsFor`, the isolate-local result cache, the platform dispatch to the Windows or macOS scanner, and the library's exported surface.

## Governing decisions
**None.** CHANGELOG 0.1.0 records the API's introduction; there are no decision records. Caching a failed scan's `[]` follows the maintainer's call in #16 (Design model).

## Design model
From reading the source:
- `scan` caches its first result in the static `_cache` and returns it until `clearCache` sets it to `null`. The cache is per isolate (doc on `_cache`).
- A failed scan's `[]` is cached too, and `clearCache()` is the retry path. Decided by the maintainer (2026-10-26, #16) on this ground: no transient failure has been observed, and the known fatal ones (a missing CoreText symbol, a DirectWrite load or vtable failure) fail the same way on retry, so not caching `[]` would rerun a failing scan on every `scan()` / `weightsFor()` call. Reporting the failure to the caller was set aside because it breaks the never-throws contract ([best-effort-scan](../invariant/best-effort-scan.md)). The macOS bindings take the opposite line one layer down and do not cache a failed load (`MacFontBindings.instance`); that only shows after `clearCache()`.
- `_scan` dispatches on `Platform.isWindows` / `Platform.isMacOS` and returns `const []` on any other platform.
- `weightsFor` matches the family name case-insensitively and returns `const [400]` when it finds nothing, which cannot be told apart from a family that really has only 400 (doc on `weightsFor`).
- The library exports only `src/models.dart` and `src/font_scanner.dart` (`lib/just_font_scan.dart`). The platform scanners, bindings, `mapWeight` and `mapStretch` are not public; tests and tools import them by `src/` path.

## Code
- `lib/just_font_scan.dart` — library exports
- `lib/src/font_scanner.dart` — `JustFontScan.scan`, `JustFontScan.clearCache`, `JustFontScan.weightsFor`, `JustFontScan._scan`, `JustFontScan._cache`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [best-effort-scan](../invariant/best-effort-scan.md)
- [family-order](../invariant/family-order.md)

## Blast radius
- [font-model](font-model.md) — `weightsFor` returns `FontFamily.weights`, so a change to that getter changes this API's result.
- [example-app](example-app.md) — the app calls `scan` and `clearCache` for its refresh; a change to caching changes what the refresh shows.
- [diagnostic-tools](diagnostic-tools.md) — `tool/leak_check.dart` measures `clearCache()` → `scan()` cycles; a change to caching changes what it measures.
- [packaging-release](packaging-release.md) — the README's `JustFontScan` section documents these semantics.

## Known holes / open
- The cache has no invalidation: a font installed after the first scan is invisible until `clearCache()` (README, "Rescan after font installation").
