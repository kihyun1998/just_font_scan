# packaging-release

## What it is
How the package ships: `pubspec.yaml` (version, platforms, constraints, the one runtime dependency `ffi`), the CHANGELOG, the README's API reference, `.pubignore`, the lints config, and dependency upkeep.

## Governing decisions
**None.** Dependency upkeep follows the design in #3 (Dependabot).

## Design model
From reading the source:
- The package declares `platforms: windows, macos` and has no native build step: it uses only `dart:ffi` and system libraries.
- Installation is documented as a pub.dev dependency (README, "Installation"), with the caret pinned to the current version, so a release bumps that line too. The README's Requirements state the Flutter SDK floor because the pubspec's `flutter:` constraint means a standalone Dart SDK cannot resolve the package (dart.dev, pubspec "Flutter SDK constraints", read 2026-10-26).
- The CHANGELOG records each version with a breaking/added/fixed split; 0.3.0 carries the migration from 0.2.x.
- `.pubignore` keeps `tool/`, every root `ROADMAP*.md`, `CLAUDE.md` and `docs/` out of the published archive. The archive is the library, its tests, the example, README, CHANGELOG and LICENSE (`dart pub publish --dry-run`, #6).
- Because the root has a `.pubignore`, `dart pub publish` ignores the root `.gitignore` (dart.dev, "Publishing packages", read 2026-10-26). Its rules, such as `/build/` and `/coverage/`, do not apply to the archive.
- Dependabot watches the root pubspec only (`.github/dependabot.yml`): weekly, `increase-if-necessary`, PRs labelled `needs-triage`. The root lockfile is git-ignored, so a PR opens only for a release outside a caret constraint, and each one raises a floor for consumers (#3).
- `example/` has no Dependabot entry: its only versioned dependency is `flutter_lints` (#3).
- CI (`.github/workflows/ci.yml`) runs format, analyze and `dart test` on `windows-latest` and `macos-latest`, using a pinned Flutter SDK. Flutter is needed because pub resolves a `flutter:` environment constraint only inside the `flutter` tool (dart.dev, pubspec "Flutter SDK constraints", read 2026-10-26). Both OSes run because public-repo runners are free and macOS had no other real-machine check (maintainer, 2026-10-26, #7).
- `example/` is resolved before analyze. Without that, root `dart analyze` on a fresh checkout reports 198 issues from `example/` (measured 2026-10-26, #7).
- Dependabot also watches the workflow's actions: monthly, grouped.

## Code
- `pubspec.yaml`, `CHANGELOG.md`, `README.md`, `.pubignore`, `analysis_options.yaml`, `LICENSE`, `.github/dependabot.yml`, `.github/workflows/ci.yml`

## Reference behaviour
**None.**

## Cross-cutting invariants
**None.**

## Blast radius
- [example-app](example-app.md) — resolves the package by path, so a constraint change here changes its resolution.
- [scan-api](scan-api.md) and [font-model](font-model.md) — the README documents both; a change there makes the README wrong.

## Known holes / open
- Dependabot does not bump `FLUTTER_VERSION` in the workflow. It is raised by hand.
