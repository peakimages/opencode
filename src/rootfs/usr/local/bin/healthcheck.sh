#!/bin/sh
set -eu

main() {
	[ "$(opencode service status)" != stopped ]
}

main
