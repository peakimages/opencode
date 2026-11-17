#!/bin/sh
set -eu

ROOT_DIR=/rootfs

die() {
	echo "rootfs: $*" >&2
	exit 1
}

main() {
	install_packages
	install_opencode
	install_github_cli
	install_mise
	create_user
	create_directories
	link_applets
	remove_unused_files
	remove_package_manager
	echo "rootfs: OpenCode $OPENCODE_VERSION, $(grep -c '^P:' "$ROOT_DIR/lib/apk/db/installed") Alpine packages and the BusyBox applets installed"
}

install_packages() {
	set -- "musl=$MUSL_VERSION" "libgcc=$GCC_VERSION" "libstdc++=$GCC_VERSION" \
		"busybox=$BUSYBOX_VERSION" "bash=$BASH_PACKAGE_VERSION" "git=$GIT_VERSION" "ripgrep=$RIPGREP_VERSION" \
		"ca-certificates-bundle=$CA_CERTIFICATES_VERSION" "tini=$TINI_VERSION" "coreutils=$COREUTILS_VERSION" "findutils=$FINDUTILS_VERSION" \
		"grep=$GREP_VERSION" "sed=$SED_VERSION" "tar=$TAR_VERSION" "xz=$XZ_VERSION" "zstd=$ZSTD_VERSION" "unzip=$UNZIP_VERSION" \
		"curl=$CURL_VERSION" "openssh-client-default=$OPENSSH_VERSION" "openssh-keygen=$OPENSSH_VERSION" \
		"jq=$JQ_VERSION" "make=$MAKE_VERSION" "gcc=$GCC_VERSION" "musl-dev=$MUSL_VERSION" "musl-utils=$MUSL_VERSION"
	apk add --no-cache --no-scripts --initdb --root "$ROOT_DIR" --keys-dir /etc/apk/keys --repositories-file /etc/apk/repositories "$@" > /dev/null
}

install_opencode() {
	install -D -m 0755 /src/opencode "$ROOT_DIR/usr/local/bin/opencode"
	reported="$(HOME=/tmp "$ROOT_DIR/usr/local/bin/opencode" --version)"
	[ "$reported" = "opencode v$OPENCODE_VERSION" ] || die "opencode reports '$reported', expected 'opencode v$OPENCODE_VERSION'"
}

install_github_cli() {
	asset="gh_${GITHUB_CLI_VERSION}_linux_arm64" sha256="$GITHUB_CLI_ARM64_SHA256"
	[ "$TARGETARCH" != amd64 ] || asset="gh_${GITHUB_CLI_VERSION}_linux_amd64" sha256="$GITHUB_CLI_AMD64_SHA256"
	wget -q -O /src/gh.tar.gz "https://github.com/cli/cli/releases/download/v$GITHUB_CLI_VERSION/$asset.tar.gz" || die "$asset.tar.gz could not be downloaded"
	[ "$(sha256sum /src/gh.tar.gz | cut -d ' ' -f 1)" = "$sha256" ] || die "SHA-256 of $asset.tar.gz does not match the one src/Dockerfile pins"
	tar -xzf /src/gh.tar.gz -C /src "$asset/bin/gh"
	install -D -m 0755 "/src/$asset/bin/gh" "$ROOT_DIR/usr/local/bin/gh"
	reported="$("$ROOT_DIR/usr/local/bin/gh" --version | head -n 1)"
	[ "$(echo "$reported" | cut -d ' ' -f 3)" = "$GITHUB_CLI_VERSION" ] || die "gh reports '$reported', expected $GITHUB_CLI_VERSION"
}

install_mise() {
	asset="mise-v$MISE_VERSION-linux-arm64-musl" sha256="$MISE_ARM64_SHA256"
	[ "$TARGETARCH" != amd64 ] || asset="mise-v$MISE_VERSION-linux-x64-musl" sha256="$MISE_AMD64_SHA256"
	wget -q -O /src/mise "https://github.com/jdx/mise/releases/download/v$MISE_VERSION/$asset" || die "$asset could not be downloaded"
	[ "$(sha256sum /src/mise | cut -d ' ' -f 1)" = "$sha256" ] || die "SHA-256 of $asset does not match the one src/Dockerfile pins"
	strip /src/mise
	install -D -m 0755 /src/mise "$ROOT_DIR/usr/local/bin/mise"
	reported="$(HOME=/tmp "$ROOT_DIR/usr/local/bin/mise" --version)"
	[ "${reported%% *}" = "$MISE_VERSION" ] || die "mise reports '$reported', expected $MISE_VERSION"
	[ -f "$ROOT_DIR/etc/profile.d/00-bashrc.sh" ] || die "bash brings no /etc/profile.d/00-bashrc.sh, expected the file that makes a login shell read /etc/bash"
	ln -s profile.d/00-bashrc.sh "$ROOT_DIR/etc/profile"
}

create_user() {
	echo "nonroot:x:65532:65532:nonroot:/home/nonroot:/bin/bash" > "$ROOT_DIR/etc/passwd"
	echo "nonroot:x:65532:" > "$ROOT_DIR/etc/group"
}

create_directories() {
	install -d -m 0700 -o 65532 -g 65532 "$ROOT_DIR/home/nonroot"
	install -d -m 1777 "$ROOT_DIR/tmp"
}

link_applets() {
	for applet in $("$ROOT_DIR/bin/busybox" --list-full); do
		[ -z "$(find "$ROOT_DIR/bin" "$ROOT_DIR/sbin" "$ROOT_DIR/usr/bin" "$ROOT_DIR/usr/sbin" -name "${applet##*/}")" ] || continue
		mkdir -p "$ROOT_DIR/${applet%/*}"
		ln -s /bin/busybox "$ROOT_DIR/$applet"
	done
}

remove_unused_files() {
	rm -rf "$ROOT_DIR/etc/network" "$ROOT_DIR/etc/udhcpc" "$ROOT_DIR/usr/share/udhcpc" "$ROOT_DIR/etc/logrotate.d" "$ROOT_DIR/etc/securetty" \
		"$ROOT_DIR/usr/bin/git-shell" "$ROOT_DIR/usr/libexec/git-core/git-http-push" "$ROOT_DIR"/usr/libexec/gcc/*/*/lto1
}

remove_package_manager() {
	rm -rf "$ROOT_DIR/etc/apk" "$ROOT_DIR/usr/share/apk" "$ROOT_DIR/lib/apk/exec" "$ROOT_DIR/var/cache" "$ROOT_DIR/var/log"
	[ -s "$ROOT_DIR/lib/apk/db/installed" ] || die "$ROOT_DIR/lib/apk/db/installed is empty, expected the packages a scanner reads"
	[ -z "$(find "$ROOT_DIR" -name apk -type f)" ] || die "apk is in $ROOT_DIR, expected no package manager"
}

main
