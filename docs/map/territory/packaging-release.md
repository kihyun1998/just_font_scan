# packaging-release

## What it is
How the package ships: `pubspec.yaml` (version, platforms, constraints, the one runtime dependency `ffi`), the CHANGELOG, the README's API reference, `.pubignore`, the lints config, and dependency upkeep.

## Governing decisions
**None.** Dependency upkeep follows the design in #3 (Dependabot).

## Design model
From reading the source:
- The package declares `platforms: windows, macos` and has no native build step: it uses only `dart:ffi` and system libraries.
- Installation is documented as a git dependency (README, "Installation").
- The CHANGELOG records each version with a breaking/added/fixed split; 0.3.0 carries the migration from 0.2.x.
- `.pubignore` keeps `tool/` and some planning docs out of the published archive.
- Dependabot watches the root pubspec only (`.github/dependabot.yml`): weekly, `increase-if-necessary`, PRs labelled `needs-triage`. The root lockfile is git-ignored, so a PR opens only for a release outside a caret constraint, and each one raises a floor for consumers (#3).
- `example/` has no Dependabot entry: its only versioned dependency is `flutter_lints` (#3).
- There is no CI workflow (`.github/workflows/` absent), so Dependabot has no `github-actions` entry.

## Code
- `pubspec.yaml`, `CHANGELOG.md`, `README.md`, `.pubignore`, `analysis_options.yaml`, `LICENSE`, `.github/dependabot.yml`

## Reference behaviour
**None.**

## Cross-cutting invariants
**None.**

## Blast radius
- [example-app](example-app.md) — resolves the package by path, so a constraint change here changes its resolution.
- [scan-api](scan-api.md) and [font-model](font-model.md) — the README documents both; a change there makes the README wrong.

## Known holes / open
- `.pubignore` lists `IMPROVEMENTS.md`, which does not exist, and omits `ROADMAP_FACE_METADATA*.md` and `ROADMAP_VARIABLE_FONTS.md`, which would ship.
- No CI runs `dart analyze` or the tests. Tracked: #7; a workflow would also add a `github-actions` Dependabot entry.
