#!/bin/sh
set -eu

DATA_DIR=/home/nonroot
TEMP_DIR="$DATA_DIR/.tmp"
MIN_PASSWORD_LENGTH=32

die() {
	echo "docker-entrypoint: $*" >&2
	exit 1
}

main() {
	[ "$#" -gt 0 ] || set -- serve
	if [ "$1" != serve ]; then
		[ -e "$TEMP_DIR" ] || create_temp_dir > /dev/null 2>&1 || true
		run "$@"
	fi
	shift
	[ -w "$DATA_DIR" ] || die "$DATA_DIR is not writable by $(id -u):$(id -g), expected a volume owned by 65532:65532"
	check_port
	clear_temp_dir
	create_temp_dir || die "neither /tmp nor $DATA_DIR can write and run a file, expected one of them without noexec"
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

clear_temp_dir() {
	rm -rf "$TEMP_DIR"
}

create_temp_dir() {
	if can_execute_in /tmp; then
		ln -s /tmp "$TEMP_DIR"
		return
	fi
	mkdir -m 0700 "$TEMP_DIR" || return
	can_execute_in "$TEMP_DIR" || return
	echo "docker-entrypoint: /tmp is read-only or mounted noexec, temporary files go to $TEMP_DIR, which is cleared on every start"
}

can_execute_in() {
	probe="$1/.docker-entrypoint"
	{ printf '#!/bin/sh\n' > "$probe" && chmod 0700 "$probe" && "$probe"; } 2> /dev/null
	status=$?
	rm -f "$probe"
	return "$status"
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
