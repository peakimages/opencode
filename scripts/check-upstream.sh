#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
REPOSITORY=anomalyco/opencode
BUN_IMAGE=oven/bun
WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' BLUE=$'\033[34m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

info() { printf '  %sℹ%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap 'rm -rf "$WORK_DIR"' EXIT

main() {
	[ -z "$OPTION" ] || die "'$OPTION' is not an option, expected none"
	read_newest_release
	compare_with_pinned
	read_bun_image
	write_upstream_json
	update_dockerfile
}

read_newest_release() {
	version="$(gh api "repos/$REPOSITORY/releases?per_page=100" --jq '.[] | select((.draft or .prerelease) | not) | .tag_name' \
		| sed -nE 's/^v([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' | sort -V | tail -n 1)"
	[ -n "$version" ] || die "github.com/$REPOSITORY lists no release, expected a tag such as v2.3.0"
	commit="$(gh api "repos/$REPOSITORY/commits/refs/tags/v$version" --jq .sha)"
}

compare_with_pinned() {
	pinned="$(jq -r '.opencode.latest.version' src/upstream.json)"
	if [ "$version" = "$pinned" ]; then
		ok "OpenCode $BOLD$pinned$RESET is pinned and the newest release on GitHub"
		exit 0
	fi
	info "GitHub lists OpenCode $BOLD$version$RESET, $pinned is pinned"
}

read_bun_image() {
	local required digest
	required="$(fetch "$version" package.json | jq -r '.packageManager // empty')"
	[[ "$required" =~ ^bun@[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "package.json of OpenCode $version names '$required' as packageManager, expected bun@ and a version"
	bun="${required#bun@}"
	bun_image="$(sed -n 's/^ARG BUN_IMAGE=//p' src/Dockerfile)"
	if [[ "$bun_image" == "$BUN_IMAGE:$bun-alpine@"* ]]; then
		ok "OpenCode $version is built with Bun $BOLD$bun$RESET, src/Dockerfile pins its image already"
		return
	fi
	digest="$(docker buildx imagetools inspect "$BUN_IMAGE:$bun-alpine" --format '{{.Manifest.Digest}}' 2> /dev/null)" \
		|| die "OpenCode $version is built with Bun $bun, Docker Hub has no $BUN_IMAGE:$bun-alpine"
	bun_image="$BUN_IMAGE:$bun-alpine@$digest"
	ok "OpenCode $version is built with Bun $BOLD$bun$RESET, Docker Hub has its image as $BUN_IMAGE:$bun-alpine"
}

write_upstream_json() {
	jq --tab --arg version "$version" --arg repository "https://github.com/$REPOSITORY" --arg commit "$commit" --arg bun "$bun" \
		'.opencode.latest = {$version, $repository, $commit, $bun}' src/upstream.json > "$WORK_DIR/upstream.json"
	cp "$WORK_DIR/upstream.json" src/upstream.json
	ok "src/upstream.json pins $BOLD$version$RESET with commit ${commit:0:10} and Bun $bun"
}

update_dockerfile() {
	sed -E -e "s|^ARG OPENCODE_VERSION=.*|ARG OPENCODE_VERSION=$version|" -e "s|^ARG BUN_IMAGE=.*|ARG BUN_IMAGE=$bun_image|" \
		-e "s|^# https://hub.docker.com/r/$BUN_IMAGE/tags.*|# https://hub.docker.com/r/$BUN_IMAGE/tags?name=$bun-alpine|" src/Dockerfile > "$WORK_DIR/Dockerfile"
	cp "$WORK_DIR/Dockerfile" src/Dockerfile
	ok "src/Dockerfile sets OPENCODE_VERSION $BOLD$version$RESET and the image of Bun $bun"
}

fetch() {
	curl --proto '=https' --tlsv1.2 -sSf --retry 3 "https://raw.githubusercontent.com/$REPOSITORY/refs/tags/v$1/$2"
}

main
