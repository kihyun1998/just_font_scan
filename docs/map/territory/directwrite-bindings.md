# directwrite-bindings

## What it is
The hand-written `dart:ffi` layer over COM and DirectWrite: library loading, GUIDs, HRESULT handling, vtable-slot calls, and the constants the Windows scanner reads.

## Governing decisions
**None.** `ROADMAP.md` is the original plan, and requires vtable offsets to be checked against `dwrite.h` declaration order.

## Design model
From reading the source:
- Every COM method is called through `vtableSlot(comPtr, slotIndex)`; the slot index is the method's position in the interface's declaration order in the Windows SDK headers, counting `IUnknown`'s three methods first. A wrong index calls the wrong function, which usually crashes the process.
- Slot comments record the header order they were derived from, e.g. the `IDWriteFactory` block "Verified against dwrite.h (Windows SDK) and MSDN".
- `_vtable` throws `StateError` on a null object or vtable pointer instead of dereferencing it.
- `vtableSlot` asserts `slotIndex < 64`. The highest slots used are `IDWriteFontFace5` 55–56.
- `comRelease` is null-safe; every interface the scanner obtains is released in a `finally`.
- Axis tags are DirectWrite `FOUR_CC` values, packed little-endian: the byte-reverse of the CoreText constants.

## Code
- `lib/src/windows/dwrite_bindings.dart` — `succeeded`, `loadOle32`, `loadDWrite`, `_system32Path`, `_vtable`, `vtableSlot`, `comRelease`, `comQueryInterface`, `allocIIDWriteFactory`, `allocIIDWriteFont1`, `allocIIDWriteLocalFontFileLoader`, `allocIIDWriteFontFace5`, and one wrapper per method (`factoryGetSystemFontCollection` … `localizedStringsGetString`); constants `kDWriteFontWeightMin/Max`, `kMaxFontCount`, `kDWriteFontAxisTag*`, `kMaxFontPathLength`, `kMaxFilesPerFace`, `kDWriteInfoString*`, `kDWriteFontStyle*`
- `test/axis_tag_test.dart` — group `DirectWrite FOUR_CC (little-endian)`

## Reference behaviour
- Windows SDK headers `dwrite.h`, `dwrite_1.h`, `dwrite_3.h` — settle every slot index and enum value (binding, read raw).
- Microsoft Learn — `DWRITE_INFORMATIONAL_STRING_ID` is linked from the `kDWriteInfoString*` block. It is summarized: `ROADMAP_FACE_METADATA_PHASE2.md` records a draft value of 4 for `FULL_NAME` that the SDK had as 16.

## Cross-cutting invariants
- [absolute-library-paths](../invariant/absolute-library-paths.md)
- [bounded-native-input](../invariant/bounded-native-input.md)
- [best-effort-scan](../invariant/best-effort-scan.md)
- [five-registered-axes](../invariant/five-registered-axes.md)

## Blast radius
- [windows-face-scan](windows-face-scan.md), [windows-file-path](windows-file-path.md), [windows-variable-axes](windows-variable-axes.md) — each calls these wrappers and trusts that the slot index and signature match the header.
- [diagnostic-tools](diagnostic-tools.md) — `tool/debug_filepath.dart` imports this file directly.

## Known holes / open
- No test checks each slot index directly. The Windows integration test, run in CI on `windows-latest`, catches a wrong slot on the scan path through its results: shifting `GetWeight` by one fails it (#7). Slots whose results the test does not assert are a different case: `IsSymbolFont` (`isSymbol`), `GetInformationalStrings` (`postScriptName`) and `IsMonospacedFont` (`isMonospace`). A crash there still fails CI, because every scan runs them, but a wrong value goes unnoticed.
