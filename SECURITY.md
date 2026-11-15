# Security

This page outlines what is in scope, our support policy and how to report vulnerabilities.

## Scope

Report a vulnerability to the project that maintains the affected code:

- **The image** is built in this repository: the Dockerfile and its build settings, the entrypoint and health check scripts, the root filesystem and the workflows that test and publish it. Report it here, see [Reporting a Vulnerability](#reporting-a-vulnerability).
- **OpenCode** is maintained at [anomalyco/opencode](https://github.com/anomalyco/opencode). Report it to the OpenCode team, see its [security policy](https://github.com/anomalyco/opencode/security/policy). Every OpenCode release becomes a new image, usually within a day.
- **Bun** is the runtime inside the `opencode` binary. Report it to Bun, see its [security policy](https://github.com/oven-sh/bun/security/policy), the fix reaches the image with the OpenCode release that upgrades it.
- **mise** is maintained at [jdx/mise](https://github.com/jdx/mise). Report it to mise, see its [security policy](https://github.com/jdx/mise/security/policy), the fix reaches the image with its next release.
- **Alpine and its packages**, such as `git`, `bash`, `gh` and BusyBox, are pinned in the Dockerfile. Report it to Alpine or the upstream project, the fix reaches the image with its next release.

The agent runs shell commands for whoever signs in and is not sandboxed, that is how OpenCode works and that is not a vulnerability of this image.

## Support Policy

Below you can find the support status for different versions of the image. The image version is the `v` part of an image tag, `peakimages/opencode:2.3.0-v0.1.0` is image version `v0.1.0`.

| Version | Supported          | Support Status     |
| ------- | ------------------ | ------------------ |
| **1.x** | :white_check_mark: | Unreleased         |
| **0.x** | :white_check_mark: | Active Development |

Immutable tags such as `2.3.0-v0.1.0` are never rebuilt. A fix ships as a new image version, and the floating tags `2.3.0`, `2.3`, `2` and `latest` move to it. Deployments that pin an immutable tag receive fixes by moving to the newer tag.

## Reporting a Vulnerability

If you find a security vulnerability in a currently supported version, please follow these steps:

1. **DO NOT** disclose the vulnerability publicly.
2. Report it via [GitHub Security Advisories](https://github.com/peakimages/opencode/security/advisories/new).
3. Include in your report:
   - **Explanation:** Detailed explanation of the vulnerability.
   - **Affected Versions:** Which image tags are affected.
   - **Reproduction:** Clear steps to reproduce the vulnerability.
   - **Impact:** Assessment of the potential impact of the vulnerability.
