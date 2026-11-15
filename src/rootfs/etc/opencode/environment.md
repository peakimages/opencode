This is an Alpine Linux container. You run as an unprivileged user without `sudo` or `apk`, and only `/home/nonroot` is kept, so clone repositories there.

Install languages and tools with `mise`, such as `mise use -g node@24 python go rust`, or `mise trust && mise install` in a repository with a `mise.toml` or `.tool-versions`.
