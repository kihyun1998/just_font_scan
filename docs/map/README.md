# Territory map

<!-- grill-map build stamp: 2adf78f -->
<!-- grill-map synced at: 3b496ff (2026-10-25) -->

The territory map. A comment's why, trap and measured value go to a note here. Notes are added as they come up, or all at once with `grill-map`, which also reads hand-written notes as leads and keeps their paths.

## What it answers

- **If I touch this, what else moves?** Open the territory that holds the code, then follow its `## Blast radius` and `## Cross-cutting invariants`.
- **What decision is this shape derived from?** Open its `## Governing decisions`. Every territory reads **None.**: this repo has no decision records, only the planning docs below, so the reason sits in each note's `## Design model`, sourced.

## How to read it

- `## Blast radius` is a checklist. An edge with nothing to do for your change is a correct outcome.
- A **None.** under a heading is an answer, not a gap in the note.
- Symbols, never line numbers. Plain relative links. A fact another file owns is linked, not copied.
- Every claim carries its evidence (a symbol, a commit) or its source and date, e.g. `(maintainer, 2026-10-25)`.
- Source files and issues are text inside notes, not nodes; the map cannot list "every caller of X" — `git grep` can.

## The shape of the repo

A pure `dart:ffi` package with two independent platform backends behind one static facade. Each backend is a bindings file plus a scanner, and the two share no code beyond the model and `lib/src/limits.dart`. That is why most cross-platform facts are invariants: each one is written out once per backend. The largest gap is verification. No test runs on Windows, and the macOS face metadata and axes have not been checked on a real Mac since 0.3.0 (maintainer, 2026-10-25).

## Territories

- [scan-api](territory/scan-api.md)
- [font-model](territory/font-model.md)
- [directwrite-bindings](territory/directwrite-bindings.md)
- [windows-face-scan](territory/windows-face-scan.md)
- [windows-file-path](territory/windows-file-path.md)
- [windows-variable-axes](territory/windows-variable-axes.md)
- [coretext-bindings](territory/coretext-bindings.md)
- [macos-face-scan](territory/macos-face-scan.md)
- [macos-value-mapping](territory/macos-value-mapping.md)
- [macos-variable-axes](territory/macos-variable-axes.md)
- [diagnostic-tools](territory/diagnostic-tools.md)
- [example-app](territory/example-app.md)
- [packaging-release](territory/packaging-release.md)

## Invariants

- [five-registered-axes](invariant/five-registered-axes.md)
- [shared-value-scales](invariant/shared-value-scales.md)
- [absolute-library-paths](invariant/absolute-library-paths.md)
- [bounded-native-input](invariant/bounded-native-input.md)
- [best-effort-scan](invariant/best-effort-scan.md)
- [family-order](invariant/family-order.md)

## Scope

- **Planning records, not territories:** `ROADMAP*.md` at the root. They are the plans each feature was built from. Their unchecked items are carried into the notes as known holes, and they are not kept current.
- **Out of scope:** README's "What this package does not provide" (informational strings, metrics, Unicode ranges, OpenType features, classification) and Linux. A territory appears when something in the repo commits to it — an issue with a design, a spec, a decision record — and a note's absence before that is correct.
