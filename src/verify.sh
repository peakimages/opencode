#!/bin/sh
set -eu

die() {
	echo "verify: $*" >&2
	exit 1
}

cd "$(dirname "$0")"

main() {
	check_commit
	check_source
	check_bun
	echo "verify: OpenCode $OPENCODE_VERSION, the tag points to commit $commit and is built with Bun $bun"
}

check_commit() {
	commit="$(git -C source rev-parse HEAD)"
	[ "$commit" = "$(pin commit)" ] || die "tag v$OPENCODE_VERSION points to $commit, expected $(pin commit)"
}

check_source() {
	version="$(jq -r .version source/package.json)"
	[ "$version" = "$OPENCODE_VERSION" ] || die "package.json of the tag sets version $version, expected $OPENCODE_VERSION"
}

check_bun() {
	bun="$(bun --version)"
	[ "$bun" = "$(pin bun)" ] || die "BUN_IMAGE has Bun $bun, expected the Bun $(pin bun) that src/upstream.json pins"
	required="$(jq -r .packageManager source/package.json)"
	[ "$required" = "bun@$bun" ] || die "OpenCode $OPENCODE_VERSION is built with $required, expected bun@$bun"
}

pin() {
	jq -r ".$1" opencode.json
}

main
