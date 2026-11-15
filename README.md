# OpenCode

[![Release](https://img.shields.io/github/actions/workflow/status/peakimages/opencode/release.yaml?branch=main&label=release)](https://github.com/peakimages/opencode/actions/workflows/release.yaml)
[![OpenCode](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fpeakimages%2Fopencode%2Fmain%2Fsrc%2Fupstream.json&query=%24.opencode.latest.version&label=opencode)](https://github.com/peakimages/opencode/releases)
[![License](https://img.shields.io/github/license/peakimages/opencode)](LICENSE)
[![Docker pulls](https://img.shields.io/docker/pulls/peakimages/opencode)](https://hub.docker.com/r/peakimages/opencode)
[![Image size](https://img.shields.io/docker/image-size/peakimages/opencode/latest?arch=amd64)](https://hub.docker.com/r/peakimages/opencode)

## Introduction

A hardened image that runs the [OpenCode](https://opencode.ai?ref=peakimages.dev) server with the tools an agent needs. Connect the desktop app, the mobile app, the web UI or the terminal to it, and your sessions and tools keep running on the server while your laptop is closed.

> [!IMPORTANT]
> `peakimages/opencode` is currently **v0** and subject to breaking changes prior to `v1.0.0`. Pin to a specific version like `peakimages/opencode:2.3.0-v0.1.0` to avoid breaking changes.

### What Makes This Image Different?

The OpenCode server runs the agent and its shell commands, so the image around it decides how much a mistake costs. This image compiles OpenCode from the release tag, runs it unprivileged and brings the tools an agent needs, with mise for every other one.

- ✅ Secure by Default: Runs as unprivileged user `65532` on `scratch`, without `sudo`, a system package manager or setuid files, read-only root filesystem supported
- ✅ Built From Source: Compiled from the release tag with the same build script as the OpenCode releases, without network access during the compilation
- ✅ Verified Source: The release tag must point to the pinned commit and every npm package must match the lockfile before each compilation
- ✅ Patched Dependencies: An npm package with a known vulnerability is raised before OpenCode releases the update, see [PATCHES.md](PATCHES.md)
- ✅ Batteries Included: `bash`, GNU tools, `git`, `gh`, `ripgrep`, `curl`, `jq`, `make`, `gcc` and an SSH client
- ✅ Tools on Demand: mise installs languages and CLIs into the home volume without root, and they are kept across image updates
- ✅ Modern Architecture: Native health check, `tini` init, OCI labels, reproducible builds, provenance and SBOM attestations
- ✅ Always Current: GitHub is checked twice a day and new OpenCode releases become new images
- ✅ Multi-Architecture: Builds for `linux/amd64` and `linux/arm64`
- ✅ Tested: Every release is tested on both platforms before it is published

## Comparison

To see a comparison of this image with other popular OpenCode Docker images, see [docs/comparison.md](docs/comparison.md).

## Getting Started

OpenCode is a client and a server. The server holds the projects (git repositories), the sessions and the provider keys and runs the agent with its shell commands, the clients show it. This container is meant to be used as a server and can be used as a client with the web UI, the desktop app, terminal or the mobile app.

### Docker Pull

```sh
docker pull peakimages/opencode:2.3.0-v0.1.0
```

> [!NOTE]
> The layers of the image are compressed with zstd, pulling it needs Docker Engine 23.0 or later.

### Docker Compose

The server speaks plain HTTP, so put a reverse proxy with HTTPS in front of it:

```yaml
services:
  opencode:
    image: peakimages/opencode:2.3.0-v0.1.0
    restart: unless-stopped
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    volumes:
      - opencode-data:/home/nonroot

  caddy:
    image: caddy:2.11.9-alpine
    restart: unless-stopped
    command:
      - caddy
      - reverse-proxy
      - --from=opencode.example.com
      - --to=opencode:${OPENCODE_PORT:-4096}
      - --header-down=Strict-Transport-Security:max-age=31536000
    depends_on:
      opencode:
        condition: service_healthy
    ports:
      - 80:80
      - 443:443
      - 443:443/udp
    volumes:
      - caddy-data:/data

volumes:
  opencode-data:
  caddy-data:
```

### Coolify

On Coolify, the OpenCode service uses the Coolify managed reverse proxy. Coolify also generates the domain and a secure password for you.

```yaml
services:
  opencode:
    image: peakimages/opencode:2.3.0-v0.1.0
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    environment:
      - SERVICE_URL_OPENCODE_4096
      - OPENCODE_PASSWORD=${SERVICE_PASSWORD_64_OPENCODE}
    volumes:
      - opencode-data:/home/nonroot
```

### Connect to Your Server

The web UI, the desktop app and the mobile app sign in with a link or the OpenCode server password:

1. Print a sign-in link and a QR code, the link works once within 5 minutes and signs in for 30 days:

   ```sh
   docker compose exec opencode opencode pair --url https://opencode.example.com
   ```

2. Open the link in a browser or paste it into the desktop app, or scan the QR code with the mobile app.

The terminal UI signs in with the password:

1. Print the OpenCode server password:

   ```sh
   docker compose exec opencode opencode service get password
   ```

2. Connect from your machine with the password:

   ```sh
   export OPENCODE_PASSWORD=your-password
   opencode --server https://opencode.example.com
   ```

> [!WARNING]
> Whoever has the password runs shell commands in the container. The server speaks plain HTTP and does not limit failed logins, so only reach it through a reverse proxy with HTTPS or a private network. The agent can read the password and the provider keys, so use keys you can revoke.

## Tools

The image brings `bash`, GNU tools, `git`, `gh`, `ripgrep`, `curl`, `jq`, `make`, `gcc` and an SSH client. [mise](https://mise.jdx.dev) installs every other tool into the home volume:

- Languages from its [core tools](https://mise.jdx.dev/core-tools.html) such as Node.js, Bun, Go, Rust, Python, Java and Zig, `mise use -g node@24 go rust`
- Over 1,000 CLIs from its [registry](https://mise.jdx.dev/registry.html) such as pnpm, uv, kubectl and terraform, `mise use -g pnpm`
- The versions a repository pins in `mise.toml` or `.tool-versions`, `mise trust && mise install`
- A command mise knows installs itself on its first run, so `go test` or `cargo build` work out of the box, no configuration needed

## Available Image Variations

All tags follow this pattern:

```sh
peakimages/opencode:{{opencode-version}}-v{{image-version}}
```

| Flavor  | Variant   | Best For               | Example                            |
| ------- | --------- | ---------------------- | ---------------------------------- |
| default | `runtime` | General-purpose agents | `peakimages/opencode:2.3.0-v0.1.0` |

The default is the `runtime` variant, OpenCode on `scratch` with the tools above and without a system package manager.

### Tags

| Tag                 | Meaning                                                                      |
| ------------------- | ---------------------------------------------------------------------------- |
| `2.3.0-v0.1.0`      | Immutable: OpenCode 2.3.0 built as image v0.1.0, never rebuilt               |
| `2.3.0`, `2.3`, `2` | Newest release of that OpenCode patch, minor or major version                |
| `latest`            | Newest release                                                               |
| `preview`           | Newest prerelease, like `2.3.0-v0.2.0-beta.1`, until its release replaces it |

### Registries

| 📦 Registry                                                                                 | 🐳 Image                                                                                                                          |
| ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [Docker Hub](https://hub.docker.com/r/peakimages/opencode)                                  | ![peakimages/opencode](https://img.shields.io/github/v/release/peakimages/opencode?label=peakimages%2Fopencode)                   |
| [GitHub Container Registry](https://github.com/peakimages/opencode/pkgs/container/opencode) | ![ghcr.io/peakimages/opencode](https://img.shields.io/github/v/release/peakimages/opencode?label=ghcr.io%2Fpeakimages%2Fopencode) |

## Configuration

Every variable is optional, set them with `-e` or the `environment` section of a docker compose service.

| Variable                 | Default   | Meaning                                                                                              |
| ------------------------ | --------- | ---------------------------------------------------------------------------------------------------- |
| `OPENCODE_PASSWORD`      | generated | Password of the server, at least 32 characters. Without one OpenCode generates it on the first start |
| `OPENCODE_PASSWORD_FILE` | unset     | File that holds the password, such as a Docker secret                                                |
| `OPENCODE_PORT`          | `4096`    | Port the OpenCode server listens on                                                                  |

OpenCode reads its own variables, the most important ones on a server:

| Variable                              | Default | Meaning                                                                                                      |
| ------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------ |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` | unset   | Key of a [provider](https://opencode.ai/v2/docs/providers), in place of signing in from a client             |
| `OPENCODE_CONFIG_CONTENT`             | unset   | [Configuration](https://opencode.ai/v2/docs/config) as JSON, such as `{"model":"anthropic/claude-opus-5-5"}` |
| `OPENCODE_CONFIG_PROJECT_DISABLE`     | unset   | `1` ignores the `opencode.json`, the plugins and the `AGENTS.md` of a repository, for code you do not trust  |
| `OPENCODE_DISABLE_MODELS_FETCH`       | unset   | `1` keeps the built-in list of models and fetches no newer one from `models.opencode.ai`                     |
| `HTTPS_PROXY`, `NO_PROXY`             | unset   | Proxy for every request of the server, see [network](https://opencode.ai/v2/docs/network)                    |
| `GH_TOKEN`                            | unset   | Token for `gh`, `git` uses it for `https://github.com` as well                                               |
| `MISE_GITHUB_TOKEN`                   | unset   | Token mise asks GitHub with, without one GitHub answers 60 requests per hour                                 |

| Path                                           | Holds                                                                           |
| ---------------------------------------------- | ------------------------------------------------------------------------------- |
| `/home/nonroot`                                | Repositories, sessions and every installed tool. A volume owned by `65532`      |
| `/tmp`                                         | Temporary files, a tmpfs that allows execution with a read-only root filesystem |
| `/home/nonroot/.config/opencode/opencode.json` | Your [configuration](https://opencode.ai/v2/docs/config)                        |
| `/etc/opencode/opencode.json`                  | System configuration, it outranks every other                                   |
| `/etc/mise/config.toml`                        | Settings of mise                                                                |

### Custom Image

`opencode` is one program that runs on any Alpine image with `libgcc`, `libstdc++`, `bash`, `git` and `ripgrep`. Copy it with its entrypoint and its health check into the image of the toolchain you need:

```dockerfile
FROM php:8.5-cli-alpine

RUN apk add --no-cache bash git ripgrep libgcc libstdc++ tini \
    && adduser -D -u 65532 nonroot
COPY --from=peakimages/opencode:2.3.0-v0.1.0 /usr/local/bin/opencode /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh /usr/local/bin/

USER 65532:65532
WORKDIR /home/nonroot
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
HEALTHCHECK CMD ["/usr/local/bin/healthcheck.sh"]
```

## Attestations

Every image carries an SBOM and a provenance attestation.

The SBOM lists the packages of the image, OpenCode, mise and the Alpine packages:

```sh
docker buildx imagetools inspect peakimages/opencode:latest --format '{{ json .SBOM }}'
```

The provenance records how the image was built:

```sh
docker buildx imagetools inspect peakimages/opencode:latest --format '{{ json .Provenance }}'
```

A scanner lists the same packages, Trivy all but OpenCode and mise:

```sh
syft peakimages/opencode:latest
grype peakimages/opencode:latest
trivy image peakimages/opencode:latest
```

## Releases

Every OpenCode release becomes a new version of the image. A check for new OpenCode releases runs twice a day.

The image version follows semantic versioning independently of OpenCode. Changes to the image are listed in [CHANGELOG.md](CHANGELOG.md).
