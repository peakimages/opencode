# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v2.4.2-v0.1.1] - 2026-11-26

### Changed

- OpenCode from v2.4.1 to v2.4.2, see its [release notes](https://github.com/anomalyco/opencode/releases/tag/v2.4.2)

## [v2.4.1-v0.1.1] - 2026-11-26

### Changed

- gh from v2.104.0 to v2.106.0
- mise from v2026.11.9 to v2026.11.14
- zstd from 1.5.7 to 1.6.0

## [v2.4.1-v0.1.0] - 2026-11-23

### Changed

- OpenCode from v2.3.2 to v2.4.1, see the release notes of [v2.4.0](https://github.com/anomalyco/opencode/releases/tag/v2.4.0) and [v2.4.1](https://github.com/anomalyco/opencode/releases/tag/v2.4.1)

## [v2.3.2-v0.1.0] - 2026-11-18

### Changed

- OpenCode from v2.3.1 to v2.3.2, see its [release notes](https://github.com/anomalyco/opencode/releases/tag/v2.3.2)

## [v2.3.1-v0.1.0] - 2026-11-18

### Changed

- OpenCode from v2.3.0 to v2.3.1, see its [release notes](https://github.com/anomalyco/opencode/releases/tag/v2.3.1)

## [v2.3.0-v0.1.0] - 2026-11-17

### Added

- Hardened OpenCode server image on `scratch` with the tools an agent needs, compiled from the tagged source
  - The image runs as the `nonroot` user `65532`, with the OpenCode server on port 4096 or the port of `OPENCODE_PORT`
  - OpenCode generates a password on the first start and keeps it out of the log, `OPENCODE_PASSWORD` or `OPENCODE_PASSWORD_FILE` can be used to set your own of at least 32 characters
  - The health check asks the OpenCode server for its status
  - A read-only root filesystem needs no `/tmp` mount, temporary files then go to `/home/nonroot/.tmp`, cleared on every start
  - `bash`, GNU tools, `git`, `gh`, `curl`, `jq`, `make`, `gcc`, `mise` and an SSH client are pre-installed
  - mise installs the tools of a project into `/home/nonroot` on their first use or from its `mise.toml`
  - A patch can raise npm packages with a known vulnerability before OpenCode does
  - The platforms are `amd64` and `arm64`
