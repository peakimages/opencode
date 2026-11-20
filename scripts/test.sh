#!/usr/bin/env bash
set -euo pipefail

OPTION="$*"
IMAGE="${1:-}"
CONTAINER=opencode-test
URL=http://127.0.0.1:14096
PASSWORD="$(openssl rand -hex 32)"
WORK_DIR="$(mktemp -d)"

BOLD=$'\033[1m' GREEN=$'\033[32m' RED=$'\033[31m' RESET=$'\033[0m'

heading() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$RESET"; }
ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
die() {
	printf '  %s✖%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cd "$(dirname "$0")/.."
trap cleanup EXIT

main() {
	[[ "$OPTION" =~ ^[^-][^[:space:]]*$ ]] || die "'$OPTION' is not an option, expected an image"
	heading "Testing $IMAGE"
	read_platform
	check_version
	check_refusals
	heading "Server"
	start_container
	check_authentication
	check_web_ui
	check_pairing
	check_generated_password
	check_password_file
	heading "Agent"
	check_shell
	check_mise
	check_terminal
	check_restart
	check_stop
	heading "All tests passed for $IMAGE"
}

read_platform() {
	platform="$(docker image inspect -f '{{.Os}}/{{.Architecture}}{{with .Variant}}/{{.}}{{end}}' "$IMAGE" 2> /dev/null)" || die "$IMAGE is not a local image, build it first"
	ok "$IMAGE is built for $platform"
}

check_version() {
	local printed
	printed="$(docker run --rm --platform "$platform" "$IMAGE" --version)"
	version="${printed#opencode v}"
	jq -e --arg version "$version" 'any(.opencode[]; .version == $version)' src/upstream.json > /dev/null || die "opencode --version prints '$printed', expected a version src/upstream.json pins"
	ok "opencode --version prints $version, a version src/upstream.json pins"
}

check_refusals() {
	docker run --rm --platform "$platform" -e OPENCODE_PASSWORD=hunter2 "$IMAGE" > /dev/null 2>&1 && die "the server started with a password of 7 characters"
	docker run --rm --platform "$platform" -e OPENCODE_PORT=0 "$IMAGE" > /dev/null 2>&1 && die "the server started with OPENCODE_PORT=0"
	docker run --rm --platform "$platform" --read-only --tmpfs /home/nonroot:uid=65532,gid=65532 --tmpfs /tmp "$IMAGE" > /dev/null 2>&1 \
		&& die "the server started with /tmp and /home/nonroot mounted noexec"
	ok "refuses to start with a short password, an invalid port or no directory to run temporary files from"
}

start_container() {
	docker volume create "$CONTAINER" > /dev/null
	docker run -d --name "$CONTAINER" --platform "$platform" -p "${URL#http://}:4097" -v "$CONTAINER:/home/nonroot" \
		--read-only --cap-drop ALL --security-opt no-new-privileges --tmpfs /tmp:exec \
		-e OPENCODE_PASSWORD="$PASSWORD" -e OPENCODE_PORT=4097 \
		--health-interval 2s --health-start-period 1s "$IMAGE" > /dev/null
	wait_healthy "$CONTAINER"
	ok "healthy on OPENCODE_PORT with a read-only root filesystem, all capabilities dropped and /tmp on a tmpfs"
}

check_authentication() {
	local path code
	for path in /api/info /api/session /api/shell; do
		code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$URL$path")"
		[ "$code" = 401 ] || die "GET $path without the password answers $code, expected 401"
	done
	code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' -u "opencode:wrong-$PASSWORD" "$URL/api/info")"
	[ "$code" = 401 ] || die "GET /api/info with a wrong password answers $code, expected 401"
	[ "$(api GET /api/info | jq -r .version)" = "$version" ] || die "GET /api/info with OPENCODE_PASSWORD does not report version $version"
	ok "the API answers 401 without the password or with a wrong one, and reports version $version with OPENCODE_PASSWORD"
}

check_web_ui() {
	local headers
	headers="$(curl -s -m 10 -o /dev/null -D - "$URL/" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
	[[ "$headers" == *"content-type: text/html"* ]] || die "GET / does not answer with the web UI: $headers"
	ok "the web UI is built in"
}

check_pairing() {
	local link token code
	link="$(docker exec "$CONTAINER" opencode pair --url https://opencode.example.com | grep -o 'https://opencode\.example\.com/auth/connect/[A-Za-z0-9_-]*' | head -n 1)"
	[ -n "$link" ] || die "opencode pair prints no link to https://opencode.example.com/auth/connect/"
	token="$(curl -s -m 10 -H 'accept: application/json' "$URL/auth/connect/${link##*/}" | jq -r .token)"
	[ "$(curl -s -m 10 -u "opencode:$token" "$URL/api/info" | jq -r .version)" = "$version" ] || die "the link of opencode pair does not sign in"
	code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' -H 'accept: application/json' "$URL/auth/connect/${link##*/}")"
	[ "$code" = 401 ] || die "a pairing link used twice answers $code, expected 401"
	[ "$(docker exec "$CONTAINER" pgrep -f 'opencode serve' | wc -l | tr -d ' ')" = 1 ] || die "opencode pair started a second server, expected it to find the running one"
	ok "opencode pair prints a link that signs in once, and finds the running server"
}

check_generated_password() {
	local generated
	docker volume create "$CONTAINER-generated" > /dev/null
	docker run -d --name "$CONTAINER-generated" --platform "$platform" -v "$CONTAINER-generated:/home/nonroot" \
		--health-interval 2s --health-start-period 1s "$IMAGE" > /dev/null
	wait_healthy "$CONTAINER-generated"
	generated="$(docker exec "$CONTAINER-generated" opencode service get password)"
	[ "${#generated}" = 43 ] || die "the generated password has ${#generated} characters, expected 43"
	docker logs "$CONTAINER-generated" 2>&1 | grep -qF "$generated" && die "the log holds the generated password"
	docker restart -t 20 "$CONTAINER-generated" > /dev/null
	wait_healthy "$CONTAINER-generated"
	[ "$(docker exec "$CONTAINER-generated" opencode service get password)" = "$generated" ] || die "a restart changed the generated password"
	docker rm -f "$CONTAINER-generated" > /dev/null
	ok "without a password OpenCode generates one of 43 characters, keeps it out of the log and over a restart"
}

check_password_file() {
	printf '%s' "$PASSWORD" > "$WORK_DIR/password"
	chmod 0444 "$WORK_DIR/password"
	docker run -d --name "$CONTAINER-file" --platform "$platform" --network none --read-only --tmpfs /home/nonroot:uid=65532,gid=65532,exec \
		-v "$WORK_DIR/password:/run/secrets/password:ro" -e OPENCODE_PASSWORD_FILE=/run/secrets/password \
		--health-interval 2s --health-start-period 1s "$IMAGE" > /dev/null
	wait_healthy "$CONTAINER-file"
	[ "$(docker exec "$CONTAINER-file" opencode service get password)" = "$PASSWORD" ] || die "the server does not use the password of OPENCODE_PASSWORD_FILE"
	docker exec "$CONTAINER-file" sh -c 'ls /home/nonroot/.tmp/.bun-*.so' > /dev/null || die "the server did not unpack its libraries into /home/nonroot/.tmp with a read-only /tmp"
	docker rm -f "$CONTAINER-file" > /dev/null
	ok "OPENCODE_PASSWORD_FILE sets the password, and the server and docker exec work without a network and with a read-only /tmp, from /home/nonroot/.tmp"
}

check_shell() {
	local output
	output="$(shell 'printenv SHELL; pwd; grep -oP "a\d" <<< a1; git init -q repo && cd repo && echo text > file && git add file && git -c user.name=test -c user.email=test@example.com commit -q -m test && rg -c text file')"
	[ "$output" = $'/bin/bash\n/home/nonroot\na1\n1' ] || die "a shell command reports '$output', expected bash in /home/nonroot, GNU grep, git and rg"
	output="$(shell 'readlink /home/nonroot/.tmp; mktemp | xargs -I {} sh -c "printf \"#!/usr/bin/env bash\necho ran\n\" > {} && chmod +x {} && {}"')"
	[ "$output" = $'/tmp\nran' ] || die "a script in a temporary file reports '$output', expected it to run from TMPDIR, a link to /tmp"
	output="$(shell 'printf "protocol=https\nhost=github.com\n" | GH_TOKEN=token git credential fill | grep password')"
	[ "$output" = password=token ] || die "git asks gh for the credentials of github.com and gets '$output', expected the token of GH_TOKEN"
	ok "the agent runs shell commands in bash in /home/nonroot with GNU grep, git and rg, runs scripts from TMPDIR, a link to /tmp, and git signs in to github.com with GH_TOKEN"
}

check_mise() {
	local output
	output="$(shell 'yq --version > /dev/null 2>&1; mise where yq')"
	[[ "$output" == /home/nonroot/* ]] || die "the first run of yq reports '$output', expected mise to install it into /home/nonroot"
	output="$(shell 'mise use -g node@24 > /dev/null 2>&1; node --version && npm --version')"
	[[ "$output" == v24.*$'\n'[0-9]* ]] || die "node and npm report '$output' after mise use -g node@24, expected their versions"
	output="$(shell 'printf "int main(void) { return 0; }\n" > main.c && cc main.c -o main && ./main && echo compiled')"
	[ "$output" = compiled ] || die "cc reports '$output', expected a C program to compile and run"
	ok "a missing command installs itself, mise installs Node.js into /home/nonroot and cc compiles a C program"
}

check_terminal() {
	local status watcher=""
	status="$(api POST /api/pty '{}' | jq -r .data.status)"
	[ "$status" = running ] || die "a terminal is '$status', expected running"
	for _ in $(seq 10); do
		docker exec "$CONTAINER" sh -c 'grep -q "watcher started.*backend=inotify" ~/.local/share/opencode/log/*' && watcher=started && break
		sleep 1
	done
	[ -n "$watcher" ] || die "the file watcher did not start with inotify within 10 seconds"
	ok "a terminal starts and the file watcher runs on inotify"
}

check_restart() {
	local session
	session="$(api POST /api/session '{}' | jq -r .data.id)"
	docker restart -t 20 "$CONTAINER" > /dev/null
	wait_healthy "$CONTAINER"
	[ "$(api GET "/api/session/$session" | jq -r .data.id)" = "$session" ] || die "session $session is gone after a restart"
	ok "a restart keeps the session in /home/nonroot"
}

check_stop() {
	local code
	SECONDS=0
	docker stop -t 20 "$CONTAINER" > /dev/null
	code="$(docker inspect -f '{{.State.ExitCode}}' "$CONTAINER")"
	[ "$code" = 143 ] || die "the container exited with $code on docker stop, expected 143 for SIGTERM"
	[ "$SECONDS" -lt 10 ] || die "docker stop took $SECONDS seconds, expected the server to end on SIGTERM"
	ok "docker stop ends the server on SIGTERM in under 10 seconds with exit code 143"
}

wait_healthy() {
	for _ in $(seq 60); do
		[ "$(docker inspect -f '{{.State.Health.Status}}' "$1")" = healthy ] && return
		sleep 1
	done
	die "$1 did not become healthy: $(docker logs "$1" 2>&1 | tail -n 3)"
}

api() {
	local method="$1" path="$2" body="${3:-}"
	curl -s -m 30 -u "opencode:$PASSWORD" -X "$method" -H 'content-type: application/json' ${body:+-d "$body"} "$URL$path"
}

shell() {
	local id
	id="$(api POST /api/shell "$(jq -n --arg command "$1" '{command: $command}')" | jq -r .data.id)"
	for _ in $(seq 180); do
		[ "$(api GET "/api/shell/$id" | jq -r .data.status)" = running ] || break
		sleep 1
	done
	api GET "/api/shell/$id/output" | jq -r .data.output
}

cleanup() {
	docker rm -f "$CONTAINER" "$CONTAINER-generated" "$CONTAINER-file" > /dev/null 2>&1 || true
	docker volume rm -f "$CONTAINER" "$CONTAINER-generated" > /dev/null 2>&1 || true
	rm -rf "$WORK_DIR"
}

main
