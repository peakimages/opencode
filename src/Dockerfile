# syntax=docker/dockerfile:1

# Set by scripts/check-upstream.sh
ARG OPENCODE_VERSION=2.4.1
# https://hub.docker.com/r/oven/bun/tags?name=1.4.4-alpine
ARG BUN_IMAGE=oven/bun:1.4.4-alpine@sha256:4cf82f5686b196504fe119db3fcd9185b191f82ece82c40680e597228ec6070a

# Dependencies
# https://hub.docker.com/_/alpine/tags?name=3.24.4
ARG BASE_IMAGE=alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
ARG DISTRO=alpine-3.24
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/musl
ARG MUSL_VERSION=1.2.6-r3
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/libstdc++
ARG GCC_VERSION=15.2.0-r5
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/busybox
ARG BUSYBOX_VERSION=1.37.0-r31
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/bash
ARG BASH_PACKAGE_VERSION=5.3.9-r1
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/git
ARG GIT_VERSION=2.54.1-r0
# https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/ripgrep
ARG RIPGREP_VERSION=15.1.0-r0
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/ca-certificates-bundle
ARG CA_CERTIFICATES_VERSION=20261020-r0
# https://pkgs.alpinelinux.org/package/v3.24/community/x86_64/tini
ARG TINI_VERSION=0.19.0-r3

# Tools for AI agents
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/coreutils
ARG COREUTILS_VERSION=9.11-r0
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/findutils
ARG FINDUTILS_VERSION=4.10.0-r1
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/grep
ARG GREP_VERSION=3.12-r0
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/sed
ARG SED_VERSION=4.9-r2
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/tar
ARG TAR_VERSION=1.35-r5
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/xz
ARG XZ_VERSION=5.8.4-r0
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/zstd
ARG ZSTD_VERSION=1.5.7-r2
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/unzip
ARG UNZIP_VERSION=6.0-r16
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/curl
ARG CURL_VERSION=8.23.0-r0
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/openssh-client-default
ARG OPENSSH_VERSION=10.3_p1-r2
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/jq
ARG JQ_VERSION=1.8.2-r0
# https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/make
ARG MAKE_VERSION=4.4.1-r4
# https://github.com/cli/cli/releases/tag/v2.104.0
ARG GITHUB_CLI_VERSION=2.104.0
ARG GITHUB_CLI_AMD64_SHA256=98cb101ad87dbbd3f6b2f2bfcbd43197ccd07643140121d8a9cfaa91eadbc24e
ARG GITHUB_CLI_ARM64_SHA256=cb34cefc6f4e77b90731374a2b737516bb8f3033c6ca46aa949e5344f68069e3
# https://github.com/jdx/mise/releases/tag/v2026.11.9
ARG MISE_VERSION=2026.11.9
ARG MISE_AMD64_SHA256=e55de2c37a08a9dfdb3ca95490f90f914b5ef362b62761f1bb2110e5d57210f7
ARG MISE_ARM64_SHA256=b15e52c9285a07854f4e81ec7e281625b56b0c23e4c0e8a553eb0e06fe4ae0a3

# Set by the build workflow
ARG IMAGE_VERSION
ARG SOURCE_DATE_EPOCH
ARG CREATED
ARG GIT_SHA

FROM ${BUN_IMAGE} AS compile

ARG OPENCODE_VERSION
ARG TARGETARCH

# binutils, git and jq are only used during the build stage, so they are not pinned to a specific version
# hadolint ignore=DL3018
RUN apk add --no-cache binutils git jq

WORKDIR /src
COPY --chmod=0644 upstream.json verify.sh sbom.sh ./
RUN jq --arg version "$OPENCODE_VERSION" '.opencode[] | select(.version == $version)' upstream.json > opencode.json \
    && git -c advice.detachedHead=false -c transfer.fsckObjects=true clone --quiet --depth 1 \
        --revision="refs/tags/v${OPENCODE_VERSION}" "$(jq -r .repository opencode.json).git" source \
    && sh verify.sh

# npm packages raised for a known vulnerability, see PATCHES.md
COPY --chmod=0644 patche[s]/dependencies.patch ./
RUN if [ -f dependencies.patch ]; then git -C source apply --verbose /src/dependencies.patch; fi

WORKDIR /src/source
RUN bun install --frozen-lockfile

# objcopy breaks a compiled binary, so the package note of OpenCode goes into the Bun runtime it is compiled with:
# https://github.com/oven-sh/bun/issues/48405
# Bun takes the runtime of the amd64 baseline target, for processors without AVX2, from its cache
WORKDIR /src/source/packages/cli
RUN --network=none target=linux-arm64-musl \
    && ROOT_DIR=/usr/local sh /src/sbom.sh peakimages/opencode "PeakImages OpenCode" \
        "generic|opencode|${OPENCODE_VERSION}|MIT|anoma:opencode|/bin/bun" \
    && if [ "${TARGETARCH}" = amd64 ]; then target=linux-x64-baseline-musl \
        && install -D -m 0755 "$(command -v bun)" "$(bun pm cache)/bun-linux-x64-musl-baseline-v$(bun --version)"; fi \
    && OPENCODE_TARGET="${target}" bun run script/build.ts --skip-install \
    && install -m 0755 "dist/cli-${target}/bin/opencode" /src/opencode

FROM ${BASE_IMAGE} AS build

ARG OPENCODE_VERSION
ARG MUSL_VERSION
ARG GCC_VERSION
ARG BUSYBOX_VERSION
ARG BASH_PACKAGE_VERSION
ARG GIT_VERSION
ARG RIPGREP_VERSION
ARG CA_CERTIFICATES_VERSION
ARG TINI_VERSION
ARG COREUTILS_VERSION
ARG FINDUTILS_VERSION
ARG GREP_VERSION
ARG SED_VERSION
ARG TAR_VERSION
ARG XZ_VERSION
ARG ZSTD_VERSION
ARG UNZIP_VERSION
ARG CURL_VERSION
ARG OPENSSH_VERSION
ARG JQ_VERSION
ARG MAKE_VERSION
ARG GITHUB_CLI_VERSION
ARG GITHUB_CLI_AMD64_SHA256
ARG GITHUB_CLI_ARM64_SHA256
ARG MISE_VERSION
ARG MISE_AMD64_SHA256
ARG MISE_ARM64_SHA256
ARG TARGETARCH

# binutils and jq are only used during the build stage, so they are not pinned to a specific version
# hadolint ignore=DL3018
RUN apk add --no-cache binutils jq libgcc=${GCC_VERSION} libstdc++=${GCC_VERSION}

WORKDIR /src
COPY --from=compile /src/opencode /src/opencode.json /src/
COPY --chmod=u=rwX,go=rX rootfs/ /rootfs/
COPY --chmod=0644 rootfs.sh /src/
RUN sh /src/rootfs.sh

COPY --chmod=0644 sbom.sh /src/
RUN sh /src/sbom.sh peakimages/opencode "PeakImages OpenCode" \
        "generic|mise|${MISE_VERSION}|MIT|jdx:mise|/usr/local/bin/mise"

FROM scratch AS final

ARG DISTRO
ARG OPENCODE_VERSION
ARG IMAGE_VERSION
ARG CREATED
ARG GIT_SHA

COPY --from=build /rootfs/ /

LABEL org.opencontainers.image.title="OpenCode" \
    org.opencontainers.image.description="Hardened OpenCode server Docker image with the tools an agent needs, built from the tagged source." \
    org.opencontainers.image.version="${OPENCODE_VERSION}-v${IMAGE_VERSION}" \
    org.opencontainers.image.revision="${GIT_SHA}" \
    org.opencontainers.image.created="${CREATED}" \
    org.opencontainers.image.licenses="AGPL-3.0-or-later AND MIT" \
    org.opencontainers.image.authors="PeakImages" \
    org.opencontainers.image.vendor="PeakImages" \
    org.opencontainers.image.url="https://hub.docker.com/r/peakimages/opencode" \
    org.opencontainers.image.documentation="https://github.com/peakimages/opencode#readme" \
    org.opencontainers.image.source="https://github.com/peakimages/opencode" \
    org.opencontainers.image.base.name="" \
    org.opencontainers.image.base.digest="" \
    dev.peakimages.image.version="${IMAGE_VERSION}" \
    dev.peakimages.image.upstream.version="${OPENCODE_VERSION}" \
    dev.peakimages.image.distro="${DISTRO}" \
    dev.peakimages.image.variant="runtime" \
    dev.peakimages.image.flavor="" \
    dev.peakimages.image.shell="bash" \
    dev.peakimages.image.package-manager="mise"

ENV PATH=/home/nonroot/.local/share/mise/shims:/home/nonroot/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    BASH_ENV=/etc/bash/mise.sh \
    HOME=/home/nonroot \
    SHELL=/bin/bash \
    TMPDIR=/home/nonroot/.tmp \
    BUN_RUNTIME_TRANSPILER_CACHE_PATH=0 \
    OPENCODE_DISABLE_AUTOUPDATE=1 \
    OPENCODE_PORT=4096

WORKDIR /home/nonroot
USER 65532:65532
EXPOSE 4096

STOPSIGNAL SIGTERM
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

HEALTHCHECK --interval=20s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]
