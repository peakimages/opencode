#!/bin/sh
set -eu

DATA_DIR=/home/nonroot
MIN_PASSWORD_LENGTH=32

die() {
	echo "docker-entrypoint: $*" >&2
	exit 1
}

main() {
	[ "$#" -gt 0 ] || set -- serve
	[ "$1" = serve ] || run "$@"
	shift
	[ -w "$DATA_DIR" ] || die "$DATA_DIR is not writable by $(id -u):$(id -g), expected a volume owned by 65532:65532"
	check_port
	check_temp_dir
	store_password
	exec opencode serve --service --hostname 0.0.0.0 --port "$OPENCODE_PORT" "$@"
}

run() {
	case "$1" in
		-*) exec opencode "$@" ;;
		*/*) [ -x "$1" ] && exec "$@" ;;
		*) command -v "$1" > /dev/null && exec "$@" ;;
	esac
	exec opencode "$@"
}

check_port() {
	case "${OPENCODE_PORT:=4096}" in
		[1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-9][0-9][0-9][0-9][0-9]) [ "$OPENCODE_PORT" -le 65535 ] && return ;;
	esac
	die "OPENCODE_PORT must be a port from 1 to 65535, not '$OPENCODE_PORT'"
}

check_temp_dir() {
	probe="${TMPDIR:-/tmp}/.docker-entrypoint"
	printf '#!/bin/sh\n' 2> /dev/null > "$probe" || die "${TMPDIR:-/tmp} is not writable by $(id -u):$(id -g), expected a tmpfs mount such as --tmpfs /tmp:exec with a read-only root filesystem"
	chmod 0700 "$probe"
	"$probe" 2> /dev/null || die "${TMPDIR:-/tmp} is mounted noexec, expected a mount that allows execution such as --tmpfs /tmp:exec, OpenCode loads the libraries of its terminals and its file watcher from there"
	rm -f "$probe"
}

store_password() {
	[ -z "${OPENCODE_PASSWORD:-}" ] || [ -z "${OPENCODE_PASSWORD_FILE:-}" ] || die "OPENCODE_PASSWORD and OPENCODE_PASSWORD_FILE are both set, expected one of them"
	password="${OPENCODE_PASSWORD:-}"
	if [ -n "${OPENCODE_PASSWORD_FILE:-}" ]; then
		[ -r "$OPENCODE_PASSWORD_FILE" ] || die "$OPENCODE_PASSWORD_FILE is not readable by $(id -u):$(id -g)"
		password="$(cat "$OPENCODE_PASSWORD_FILE")"
	fi
	unset OPENCODE_PASSWORD
	[ -n "$password" ] || return 0
	length="$(printf '%s' "$password" | wc -c | tr -d ' ')"
	[ "$length" -ge "$MIN_PASSWORD_LENGTH" ] || die "the password has $length characters, expected at least $MIN_PASSWORD_LENGTH"
	opencode service set password "$password" || die "could not store the password in the service configuration of OpenCode"
}

main "$@"
