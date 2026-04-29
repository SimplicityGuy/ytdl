<div align="center">

# 🎬 ytdl

[![Build](https://github.com/SimplicityGuy/ytdl/actions/workflows/build.yml/badge.svg)](https://github.com/SimplicityGuy/ytdl/actions/workflows/build.yml)
![License: MIT](https://img.shields.io/github/license/SimplicityGuy/ytdl)
[![Docker](https://img.shields.io/badge/docker-ghcr.io-blue?logo=docker)](https://github.com/SimplicityGuy/ytdl/pkgs/container/ytdl)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)
[![hadolint](https://img.shields.io/badge/hadolint-checked-blue)](https://github.com/hadolint/hadolint)
[![ShellCheck](https://img.shields.io/badge/shellcheck-checked-yellow)](https://www.shellcheck.net/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-powered-orange?logo=anthropic&logoColor=white)](https://claude.ai/code)

**A Docker image that ships [yt-dlp](https://github.com/yt-dlp/yt-dlp) with every optional dependency pre-installed — `docker run` and you have working downloads.**

</div>

<p align="center">

[🚀 Quick Start](#-quick-start) | [📦 Image](#-image) | [🛠️ Development](#%EF%B8%8F-development) | [📄 License](#-license)

</p>

## 🚀 Quick Start

```bash
docker run --rm -v "$(pwd)/downloads:/data" \
  ghcr.io/simplicityguy/ytdl:latest \
  "https://www.youtube.com/watch?v=VIDEO_ID"
```

Downloads land in `./downloads`, organized by uploader:

```
downloads/<uploader>/<title>-<id>.<ext>
downloads/<uploader>/<title>-<id>.info.json
```

A `.info.json` metadata sidecar is written alongside each download.

## 📦 Image

Published to GitHub Container Registry as multi-arch (`linux/amd64`, `linux/arm64`):

| Tag                | What                                                |
| ------------------ | --------------------------------------------------- |
| `latest`           | Latest build off `main`                             |
| `main`             | Same as `latest`                                    |
| `pr-<n>`           | Per-PR preview builds (not pushed for forks)        |
| `sha-<short>`      | Immutable, commit-pinned tag                        |
| `YYYYMMDD`         | Weekly scheduled rebuild — picks up the latest yt-dlp |

The container runs as the non-root `ytdl` user. Mount a host directory to `/data` to persist downloads.

### What's inside

#### System packages

- **atomicparsley** — embed thumbnails in mp4/m4a files
- **ffmpeg** (includes ffprobe) — merge video/audio streams, post-processing
- **mpv** — RTSP/MMS stream playback
- **deno** (replaces nodejs) — JavaScript runtime for `yt-dlp-ejs`
- **rtmpdump** — RTMP stream downloads

#### Python packages

- **brotli** — Brotli content encoding support
- **certifi** — Mozilla root certificate bundle
- **curl_cffi** — browser impersonation (Chrome, Edge, Safari)
- **mutagen** — embed thumbnails in audio formats
- **pycryptodomex** — decrypt AES-128 HLS streams
- **requests** — HTTPS proxy and persistent connections
- **websockets** — websocket-based downloads
- **xattr** — write extended file attributes (metadata)
- **yt-dlp** — the downloader itself
- **yt-dlp-ejs** — full YouTube support via JavaScript extraction

### OCI image labels

The image carries [OCI image-spec annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md) so your tooling can introspect provenance:

```bash
docker inspect ghcr.io/simplicityguy/ytdl:latest \
  --format '{{json .Config.Labels}}' | jq
```

Notable labels: `org.opencontainers.image.{title,version,revision,created,source,licenses}` plus `com.simplicityguy.ytdl.{dependencies,python.version}`.

## 🛠️ Development

### Prerequisites

- Docker (with Buildx for multi-arch local builds)
- Python 3 + [pre-commit](https://pre-commit.com/) (`pip install pre-commit`)

### One-time setup

```bash
git clone https://github.com/SimplicityGuy/ytdl.git
cd ytdl
pre-commit install
```

### Lint everything (matches CI exactly)

```bash
pre-commit run --all-files
```

The hooks cover:

- **hadolint** — Dockerfile lint
- **shellcheck** — bash static analysis (`--severity=warning`)
- **shfmt** — bash formatting (`--indent=2 --case-indent`, applied with `--write`)
- **actionlint** + **check-jsonschema** — GitHub Actions workflow validation
- Standard hygiene: trailing whitespace, EOF newlines, merge-conflict markers, executable shebangs, private-key detection

### Build locally

```bash
docker build -t ytdl .
docker run --rm -v "$(pwd)/downloads:/data" ytdl "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Build with full label metadata

```bash
docker build \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg BUILD_VERSION="$(git describe --tags --always)" \
  --build-arg VCS_REF="$(git rev-parse HEAD)" \
  -t ytdl .
```

### CI/CD

| Workflow                                                          | Trigger                                 | Purpose                                                |
| ----------------------------------------------------------------- | --------------------------------------- | ------------------------------------------------------ |
| [`build.yml`](.github/workflows/build.yml)                         | push, PR, weekly cron, manual           | Lint → multi-arch buildx → push to GHCR with provenance + SBOM |
| [`cleanup-cache.yml`](.github/workflows/cleanup-cache.yml)         | PR closed                               | Drop GitHub Actions caches scoped to the closed PR     |
| [`cleanup-images.yml`](.github/workflows/cleanup-images.yml)       | monthly cron (15th), manual             | Prune untagged + old GHCR images, keep last 5 tagged   |

See [CLAUDE.md](CLAUDE.md) for development conventions and architecture notes.

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

______________________________________________________________________

<div align="center">
Made with ❤️ in the Pacific Northwest
</div>
