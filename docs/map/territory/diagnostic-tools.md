# diagnostic-tools

## What it is
Developer scripts under `tool/` that run a real scan and print what it found: coverage stats, variable-font listings, reference-key dumps, and a memory-leak measurement. They are excluded from the published package (`.pubignore`).

## Governing decisions
**None.**

## Design model
From reading the source:
- Each script is a standalone `main`, run with `dart run tool/<name>.dart` on the platform it probes.
- `leak_check.dart` scans three rounds of 500 `clearCache()` → `scan()` cycles, waits after each round for memory to settle, and prints the RSS change per round. It is how the autorelease-pool leak was measured and how a regression would show up.
- `debug_filepath.dart` imports `src/windows/dwrite_bindings.dart` directly, so it is Windows-only and tied to the internal bindings.

## Code
- `tool/leak_check.dart` — `main`, `_quiet`, `_rssMb`
- `tool/scan_faces.dart` — `main` (face metadata coverage)
- `tool/scan_variable.dart` — `_anyAxis`, `main`
- `tool/inspect_variable_fonts.dart` — `main` (`wght` only)
- `tool/debug_filepath.dart` — `_probe`

## Reference behaviour
- README "Features": 1500 scans held under ±1 MB on both platforms. The macOS half is not re-measured since 0.3.0 (maintainer, 2026-10-25).

## Cross-cutting invariants
- [five-registered-axes](../invariant/five-registered-axes.md)

## Blast radius
- [directwrite-bindings](directwrite-bindings.md) — `debug_filepath.dart` breaks when a binding it uses is renamed.

## Known holes / open
- `inspect_variable_fonts.dart` predates the five-axis generalisation and looks only at `weightAxis`.
