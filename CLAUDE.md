# CLAUDE.md - Development Guide

## Project Overview

**ytdl** is a single-image Docker project that packages [yt-dlp](https://github.com/yt-dlp/yt-dlp) with all optional dependencies (ffmpeg, mpv, atomicparsley, rtmpdump, deno, curl_cffi, mutagen, etc.) so users can download videos with one `docker run`.

The repository contains exactly three artifacts that ship the image:

```
Dockerfile              # python:3-slim-trixie base, installs yt-dlp + system deps
entrypoint.sh           # bash wrapper that invokes yt-dlp with our default options
.pre-commit-config.yaml # hadolint, shellcheck, shfmt, actionlint, yaml/json checks
```

Plus CI/CD under `.github/workflows/` (build, cleanup-cache, cleanup-images).

## AI Development Rules

- **Open a PR for every change** — never push directly to `main`.
- **Run `pre-commit run --all-files`** before claiming work is complete. The hooks are the source of truth for lint/format.
- **Lowercase filenames** with hyphens for new markdown files (except README and CLAUDE).
- **Emojis in GitHub Actions** step names; single quotes inside `${{ }}` expressions, double quotes for YAML strings.
- **Never inline `${{ github.event.* }}` in `run:` blocks** — bind to `env:` first to avoid command injection.
- **Frozen pre-commit revs** — use `# frozen: <tag>` comment alongside the SHA so `pre-commit autoupdate --freeze` keeps them current.
- **Dockerfile labels are non-negotiable** — every change that bumps behaviour should reflect in `org.opencontainers.image.version` and the build args (`BUILD_DATE`, `BUILD_VERSION`, `VCS_REF`) wired through CI.

## Architecture Notes

- Single-stage `python:3-slim-trixie` image. There is no separate builder stage — the image is small enough that the cache savings would not justify the complexity.
- `yt-dlp` is intentionally **unpinned** (`pip install -U`). The image's purpose is to ship the latest yt-dlp; pinning would defeat the point. Hadolint's `DL3013` is suppressed inline for that exact RUN.
- `deno` is installed via the upstream install script. The `unzip` package is added solely to extract the deno tarball, then `apt-get purge`d in the same layer so the final image stays slim.
- Container runs as the non-root `ytdl` user with `WORKDIR=/data`. Callers mount their host download directory to `/data`.
- `entrypoint.sh` exits non-zero with `❌ Exiting (must set URL)...` if no URL argument is supplied — the container is single-shot, not long-running.

## Commands

### Lint and format (matches CI)

```bash
pre-commit install                 # one-time: install git hooks
pre-commit run --all-files         # run every hook (hadolint, shellcheck, shfmt, actionlint, etc.)
pre-commit autoupdate --freeze     # bump hook versions and refresh frozen SHAs
```

### Build and run locally

```bash
docker build -t ytdl .
docker run --rm -v "$(pwd)/downloads:/data" ytdl "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Build with full label metadata (mirrors CI)

```bash
docker build \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg BUILD_VERSION="$(git describe --tags --always)" \
    --build-arg VCS_REF="$(git rev-parse HEAD)" \
    -t ytdl .
```

### Inspect labels on a built image

```bash
docker inspect ytdl --format '{{json .Config.Labels}}' | jq
```

## CI/CD

| Workflow                              | Triggers                                | Purpose                                                                |
| ------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------- |
| `.github/workflows/build.yml`         | push to `main`, PR, weekly cron, manual | Lint via pre-commit, then multi-arch (amd64+arm64) build + push to GHCR |
| `.github/workflows/cleanup-cache.yml` | PR closed                               | Delete GitHub Actions caches scoped to the closed PR                    |
| `.github/workflows/cleanup-images.yml` | monthly cron (15th), manual            | Prune untagged + old GHCR images, keep last 5 tagged                    |

The build workflow:

- Runs `pre-commit/action` so the same hooks that gate local commits gate CI.
- Frees disk space (removes `dotnet`, `android`, `ghc`, `CodeQL`, prunes Docker) before building, so multi-arch builds fit on the runner.
- Pushes to `ghcr.io/<owner>/ytdl` with tags `latest`, `<branch>`, `pr-<n>`, `sha-<short>`, and a date stamp on cron runs.
- Wires `BUILD_DATE` / `BUILD_VERSION` / `VCS_REF` into Docker build args so the final OCI labels carry provenance.
- Generates SLSA provenance and SBOM via `docker/build-push-action`.

## Code Style

- **Bash**: 2-space indent, `--case-indent`, lower_snake_case for variables, prefer `printf` over `echo` for emoji-bearing output (consistency with the existing entrypoint).
- **Dockerfile**: keep RUN layers consolidated (`apt-get update && apt-get install ... && rm -rf /var/lib/apt/lists/*` in one layer). Use `COPY --chmod=` instead of a separate `RUN chmod`. Always `--no-install-recommends`.
- **Workflows**: emojis in step names. Pin third-party actions to a SHA with a frozen-version comment. Bind any `github.event.*` reference into `env:` before referencing it in `run:`.
- **Hadolint suppressions**: inline `# hadolint ignore=DLxxxx` only — never globally disable. Comment *why* directly above the ignore.

## Common Bug Prevention

### Hadolint pipefail

- Any `RUN` instruction that contains a pipe (`|`) requires `SHELL ["/bin/bash", "-o", "pipefail", "-c"]` set earlier in the Dockerfile, or hadolint's `DL4006` will fail CI.
- Set `SHELL` once at the top of the file rather than per-RUN.

### shfmt / shellcheck drift

- The `shfmt` hook **rewrites files in place** because of `--write`. If a script looks fine locally but CI rejects it, run `pre-commit run shfmt --all-files` and commit the diff.
- ShellCheck runs at `--severity=warning`. Any `info`-level finding (e.g., SC2129) is allowed; warnings and above must be fixed at source — do not add `# shellcheck disable=` without a comment explaining why.

### GitHub Actions injection

- Patterns like `run: echo "${{ github.event.pull_request.title }}"` are command-injection sinks because the title is attacker-controlled. The fix: bind via `env: TITLE: ${{ github.event.pull_request.title }}` and reference `"$TITLE"` in the script.
- This codebase enforces it via the local pre-tool security hook, but the rule applies in code review as well.

### Image pinning vs. recency

- **System packages** (`ffmpeg`, `mpv`, `rtmpdump`, etc.) inherit Debian Trixie's pinning — do not version-pin them by hand; hadolint's `DL3008` is suppressed for that RUN.
- **`yt-dlp` is unpinned** by design. If a future change pins it, that decision must be documented in this file and the image cron rebuild cadence reconsidered.
- **GitHub Actions** are pinned to SHAs (frozen). Bumping `pre-commit/action` etc. should go through `pre-commit autoupdate --freeze` plus manual SHA pinning where the hook does not own the action.
