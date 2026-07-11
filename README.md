<p align="center">
  <img src="assets/logo-mark.svg" alt="agnostic-code-metrics" width="128">
</p>

<h1 align="center">agnostic-code-metrics</h1>

<p align="center">
  <a href="https://github.com/rw-core/agnostic-code-metrics/actions/workflows/ci.yml"><img src="https://github.com/rw-core/agnostic-code-metrics/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/rw-core/agnostic-code-metrics/releases/latest"><img src="https://img.shields.io/github/v/release/rw-core/agnostic-code-metrics" alt="Latest release"></a>
  <a href="https://github.com/marketplace/actions/agnostic-code-metrics"><img src="https://img.shields.io/badge/marketplace-agnostic--code--metrics-blue?logo=github" alt="GitHub Marketplace"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/rw-core/agnostic-code-metrics" alt="License"></a>
</p>

<p align="center"><em>Six legs, six metrics: a language-agnostic code-quality check for every pull request.</em></p>

A GitHub Action that computes **language-agnostic code-quality metrics** for the
files changed in a pull request and reports them as a sticky PR comment and a job
summary, with **base-vs-head deltas** and an optional **quality gate**.

Metrics are produced by the [`rw_git`](https://pub.dev/packages/rw_git) lexical
engine (a fast, allocation-light FSM lexer), so the same six metrics are computed
consistently across Dart, JS/TS, Python, Go, Java, Kotlin, Rust, C/C++, C#, and
more:

| Metric | Meaning | Direction |
|---|---|---|
| Cyclomatic Complexity | Linearly independent paths (McCabe, 1976) | lower is better |
| Cognitive Complexity | Human effort to understand (Campbell, 2018) | lower is better |
| NPath Complexity | Acyclic execution paths (Nejmeh, 1988) | lower is better |
| ABC Score | Assignments + Branches + Conditions (Fitzpatrick, 1997) | lower is better |
| Halstead Est. Bugs | Predicted defect count (Halstead, 1977) | lower is better |
| Maintainability Index | Composite 0–100 (Oman & Hagemeister, 1992) | **higher** is better |

## Usage

```yaml
name: Code Metrics
on:
  pull_request:

permissions:
  contents: read
  pull-requests: write        # required for the sticky PR comment

jobs:
  metrics:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0       # required: deltas need base+head history
      - uses: rw-core/agnostic-code-metrics@v1
```

Pin to a full version (e.g. `@v1.2.3`) for immutability; the rolling `@v1` tag
always points at the latest `v1.x`.

> **Two hard requirements:** `actions/checkout` with `fetch-depth: 0` (the
> base-vs-head delta needs full history) and `pull-requests: write` permission
> (to post/update the comment). Without the token permission, drop the comment
> with `comment: false` and rely on the job summary.

### Quality gate

Fail the check when a changed file crosses a threshold:

```yaml
      - uses: rw-core/agnostic-code-metrics@v1
        with:
          max-cyclomatic: 15
          max-cognitive: 20
          min-maintainability: 50
          fail-on-violation: true
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `github-token` | `${{ github.token }}` | Token for the sticky comment (needs `pull-requests: write`). |
| `include` | _(all source files)_ | Newline/comma globs of files to include. |
| `exclude` | generated + tests | Newline/comma globs of files to exclude. |
| `max-cyclomatic` | _(unset)_ | Flag files above this cyclomatic complexity. |
| `max-cognitive` | _(unset)_ | Flag files above this cognitive complexity. |
| `max-npath` | _(unset)_ | Flag files above this NPath complexity. |
| `max-abc` | _(unset)_ | Flag files above this ABC score. |
| `max-halstead-bugs` | _(unset)_ | Flag files above this delivered-bugs estimate. |
| `min-maintainability` | _(unset)_ | Flag files below this Maintainability Index. |
| `fail-on-violation` | `false` | Exit non-zero when any threshold is violated. |
| `comment` | `true` | Post/update the sticky PR comment. |
| `working-directory` | `.` | Repository root to analyse, relative to the checkout. |

An unset threshold is never enforced. Only files whose extension is a recognised
source language are analysed (unparseable/binary files are skipped silently).

## Outputs

| Output | Description |
|---|---|
| `violation-count` | Number of metric threshold violations. |
| `worst-file` | Path of the file with the highest cyclomatic complexity. |

## Example report

> ## 📊 Code Metrics
>
> ❌ **1** violation(s) across **2** file(s)
>
> | File | Cyclomatic | Cognitive | NPath | ABC | Est. Bugs | Maintainability |
> |------|:--:|:--:|:--:|:--:|:--:|:--:|
> | `lib/sample.dart` | 12 🔺+11 ❌ | 30 🔺+30 | 512 🔺+511 | 14.35 🔺+14.35 | 0.18 🔺+0.16 | 52.41 🔺−24.73 |
> | `lib/added.dart` 🆕 | 1 | 0 | 1 | 0 | 0.01 | 89.52 |

## How it runs (performance)

This is a **composite action optimized with pre-compiled native binaries**, so
there is no Dart SDK setup or on-the-fly compilation on the consumer's runner:

1. On each release, CI sets up the Dart SDK and AOT-compiles standalone
   binaries via `dart compile exe` for **Linux x64, Linux arm64, macOS x64,
   macOS arm64, and Windows x64**, and attaches them (with `.sha256`
   checksums) to the GitHub Release.
2. At runtime the action detects `RUNNER_OS`/`RUNNER_ARCH`, downloads the
   matching binary from the release, **verifies its checksum**, and executes it
   (~instant startup, no `setup-dart`, no `pub get`, no compile).
3. If the binary can't be fetched or verified (an unpublished arch, a network or
   checksum failure, or a commit-SHA pin / vendored `uses: ./` copy), it
   **automatically falls back** to compiling from source with the Dart SDK so
   the action always works.

A quality-gate failure (`fail-on-violation`) is a real exit code and it will fail
the check as intended.

## Development

`rw_git` is a pure-Dart package, so a standalone Dart SDK is all you need:

```bash
dart pub get
dart analyze
dart test
dart compile exe bin/main.dart -o /tmp/acm   # what the release build produces
```

Releases are cut by pushing a `vX.Y.Z` tag; `.github/workflows/release.yml`
builds the platform matrix, publishes the versioned release, and rolls the `vX`
tag.
