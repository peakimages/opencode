# Changelog

All notable changes to this project will be documented in this file. OpenCode version bumps are not listed, every release tag names the OpenCode version it ships.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v0.1.0] - 2026-11-17

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

