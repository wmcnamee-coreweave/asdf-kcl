#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/kcl-lang/cli"
RELEASE_TOOL_NAME="kcl"
TOOL_NAME="kcl"

log() {
	printf "%s\n" "${1}" >&2
}

fail() {
	log "asdf-$TOOL_NAME: $*"
	exit 1
}


curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if kcl has other means of determining installable versions.
	list_github_tags
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

	case "$(uname -s)" in
	"Darwin")
		case "$(uname -m)" in
		"arm64")
			url="$GH_REPO/releases/download/v${version}/kcl-v${version}-darwin-arm64.tar.gz"
			;;
		"x86_64")
			url="$GH_REPO/releases/download/v${version}/kcl-v${version}-darwin-amd64.tar.gz"
			;;
		esac
		;;
	"Linux")
		case "$(uname -m)" in
		"armv7l")
			fail "armv7l not supported"
			;;
		"x86_64")
			url="$GH_REPO/releases/download/v${version}/kcl-v${version}-linux-amd64.tar.gz"
			;;
		"aarch64")
			fail "aarch64 not supported"
			;;
		esac
		;;
	esac

	log "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="$3"

	if [ "${install_type}" != "version" ]; then
		fail "asdf-${TOOL_NAME} supports release installs only"
	fi

	(
		mkdir -p "${install_path}"
		cp -r "${ASDF_DOWNLOAD_PATH}"/bin/* "${install_path}"

		# ls -la "${install_path}" >&2
		chmod +x "${install_path}/${RELEASE_TOOL_NAME}"
		chmod +x "${install_path}/${LANGUAGE_SERVER_TOOL_NAME}"

		tool_path="${install_path}/${TOOL_NAME}"
		# symlink `kclvm_cli` to `kcl` incase something relies on the original filename
		ln -s "${install_path}/${RELEASE_TOOL_NAME}" "${tool_path}"

		# ls -la "${install_path}" >&2

		"${tool_path}" --version || fail "tool test failed!"

		log "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
