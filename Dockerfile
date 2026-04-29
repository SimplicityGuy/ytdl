# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3
FROM python:${PYTHON_VERSION}-slim-trixie

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build arguments for labels
ARG BUILD_DATE
ARG BUILD_VERSION
ARG VCS_REF
ARG PYTHON_VERSION

# OCI Image Spec Annotations
# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="ytdl" \
      org.opencontainers.image.description="Docker image for downloading videos with yt-dlp and all optional dependencies." \
      org.opencontainers.image.authors="Robert Wlodarczyk <robert@simplicityguy.com>" \
      org.opencontainers.image.url="https://github.com/SimplicityGuy/ytdl" \
      org.opencontainers.image.documentation="https://github.com/SimplicityGuy/ytdl/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/SimplicityGuy/ytdl" \
      org.opencontainers.image.vendor="SimplicityGuy" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${BUILD_VERSION:-0.1.0}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/library/python:${PYTHON_VERSION}-slim-trixie" \
      com.simplicityguy.ytdl.dependencies="yt-dlp,yt-dlp-ejs,ffmpeg,mpv,atomicparsley,rtmpdump,deno" \
      com.simplicityguy.ytdl.python.version="${PYTHON_VERSION}"

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
        atomicparsley \
        curl \
        ffmpeg \
        mpv \
        rtmpdump \
        unzip \
    && curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh \
    && apt-get purge -y unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# yt-dlp is intentionally unpinned: this image's purpose is to ship the latest yt-dlp.
# hadolint ignore=DL3013
RUN pip install -U --no-cache-dir \
        "yt-dlp[default,curl-cffi]" \
        xattr

COPY --chmod=0755 entrypoint.sh /entrypoint.sh

RUN useradd -m -s /bin/bash ytdl
USER ytdl
WORKDIR /data

ENTRYPOINT ["/entrypoint.sh"]
