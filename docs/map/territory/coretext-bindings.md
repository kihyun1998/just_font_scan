# coretext-bindings

## What it is
The hand-written `dart:ffi` layer over CoreFoundation, CoreText and the Objective-C runtime: library loading, extern `CFStringRef` constant resolution, typed function wrappers, the autorelease pool, and the constants the macOS scanner reads.

## Governing decisions
**None.** Planned in `ROADMAP_MACOS.md`.

## Design model
From reading the source:
- `MacFontBindings.instance` loads once per isolate and caches the result. A load that throws leaves the cache `null`, so the next call retries (doc on `instance`).
- CoreText attribute names are extern global variables, not functions; they are resolved with `lookup<CFTypeRef>(name).value` (doc on `MacFontBindings`).
- The five variation-axis symbols are resolved as one group, `VariationAxisSymbols`. If any of them is missing the group is `null` and axis reading is skipped; the rest of the scan still runs.
- `inAutoreleasePool` pushes and pops an Objective-C autorelease pool around its body in `try`/`finally`. A Dart CLI process has no Cocoa run loop to drain one (CHANGELOG 0.2.0).
- `cfRelease` is null-safe. `cfDictionaryGetValue` and `cfArrayGetValueAtIndex` return borrowed references that are never released.
- Axis tags are big-endian OpenType tags: the byte-reverse of the DirectWrite constants.

## Code
- `lib/src/macos/coretext_bindings.dart` — `_loadCoreFoundation`, `_loadCoreText`, `_loadObjc`, `VariationAxisSymbols`, `MacFontBindings`, `MacFontBindings.instance`, `MacFontBindings.load`, `MacFontBindings._loadVariationAxisSymbols`, `MacFontBindings.inAutoreleasePool`, `MacFontBindings.cfRelease`; constants `kMaxDescriptorCount`, `kCFNumber*Type`, `kOpenType*Tag`, `kCTFontTrait*`, `kCTFontClassMaskTrait`, `kCTFontClassSymbolic`
- `test/axis_tag_test.dart` — group `CoreText tag (big-endian)`

## Reference behaviour
- Apple CoreText / CoreFoundation SDK headers — attribute names, `CFNumberType` values, `CTFontSymbolicTraits` bits (binding; headers raw, developer.apple.com summarized).

## Cross-cutting invariants
- [absolute-library-paths](../invariant/absolute-library-paths.md)
- [best-effort-scan](../invariant/best-effort-scan.md)
- [five-registered-axes](../invariant/five-registered-axes.md)

## Blast radius
- [macos-face-scan](macos-face-scan.md) and [macos-variable-axes](macos-variable-axes.md) — they call these wrappers and rely on the copy-versus-borrowed ownership each one documents; a wrong release over there is a double free or a leak.
- [diagnostic-tools](diagnostic-tools.md) — `tool/leak_check.dart` is how a lost autorelease pool shows up.

## Known holes / open
- The autorelease-pool leak fix has not been re-measured on a real Mac since the 0.3.0 face metadata was added (`ROADMAP_FACE_METADATA_PHASE3.md` leaves it unchecked; maintainer, 2026-10-25).
