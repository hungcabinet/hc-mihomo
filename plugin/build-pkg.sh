#!/bin/sh
#
# Build an os-mihomo pkg on FreeBSD.
# Usage:
#   build-pkg.sh --version 1.19.16 --arch amd64 --binary-xz clash-meta-freebsd-amd64.xz
#   build-pkg.sh --version 1.19.16 --arch aarch64 --binary /path/to/mihomo

set -eu

PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${PLUGIN_ROOT}/.." && pwd)"
SRC="${PLUGIN_ROOT}/src"
VERSION=""
ARCH=""
BINARY=""
BINARY_XZ=""
OUTPUT_DIR="${REPO_ROOT}/dist"

usage()
{
	echo "Usage: $0 --version VERSION --arch amd64|aarch64 [--binary-xz FILE | --binary FILE] [--output-dir DIR]" >&2
	exit 1
}

while [ $# -gt 0 ]; do
	case "$1" in
	--version)
		VERSION="${2:-}"
		shift 2
		;;
	--arch)
		ARCH="${2:-}"
		shift 2
		;;
	--binary)
		BINARY="${2:-}"
		shift 2
		;;
	--binary-xz)
		BINARY_XZ="${2:-}"
		shift 2
		;;
	--output-dir)
		OUTPUT_DIR="${2:-}"
		shift 2
		;;
	*)
		usage
		;;
	esac
done

[ -n "${VERSION}" ] || usage
[ -n "${ARCH}" ] || usage

case "${ARCH}" in
amd64)
	ABI="FreeBSD:14:amd64"
	PKG_ARCH="freebsd:14:x86:64"
	;;
aarch64|arm64)
	ARCH="aarch64"
	ABI="FreeBSD:14:aarch64"
	PKG_ARCH="freebsd:14:aarch64:64"
	;;
*)
	echo "Unsupported architecture: ${ARCH}" >&2
	exit 1
	;;
esac

if [ -n "${BINARY_XZ}" ]; then
	if [ ! -f "${BINARY_XZ}" ]; then
		echo "Binary archive not found: ${BINARY_XZ}" >&2
		exit 1
	fi
elif [ -n "${BINARY}" ]; then
	if [ ! -f "${BINARY}" ]; then
		echo "Binary not found: ${BINARY}" >&2
		exit 1
	fi
else
	usage
fi

if [ ! -d "${SRC}" ]; then
	echo "Source tree not found: ${SRC}" >&2
	exit 1
fi

if ! command -v pkg >/dev/null 2>&1; then
	echo "pkg(8) is required. Run this script on FreeBSD." >&2
	exit 1
fi

STAGE="$(mktemp -d /tmp/os-mihomo-stage.XXXXXX)"
META="$(mktemp -d /tmp/os-mihomo-meta.XXXXXX)"
cleanup()
{
	rm -rf "${STAGE}" "${META}"
}
trap cleanup EXIT

mkdir -p "${STAGE}"
(cd "${SRC}" && find . -type f) | while IFS= read -r rel; do
	rel="${rel#./}"
	mkdir -p "${STAGE}/$(dirname "${rel}")"
	cp "${SRC}/${rel}" "${STAGE}/${rel}"
done

mkdir -p "${STAGE}/usr/local/share/examples/mihomo"
cp "${REPO_ROOT}/template.yaml" "${STAGE}/usr/local/share/examples/mihomo/config.yaml"

mkdir -p "${STAGE}/usr/local/bin"
if [ -n "${BINARY_XZ}" ]; then
	xz -dc "${BINARY_XZ}" > "${STAGE}/usr/local/bin/mihomo"
else
	cp "${BINARY}" "${STAGE}/usr/local/bin/mihomo"
fi
chmod 0755 "${STAGE}/usr/local/bin/mihomo"

chmod 0755 "${STAGE}/usr/local/etc/rc.d/mihomo"
chmod 0755 "${STAGE}/usr/local/etc/rc.syshook.d/start/90-mihomo"
find "${STAGE}/usr/local/opnsense/scripts/mihomo" -type f -exec chmod 0755 {} \;

cat > "${META}/+MANIFEST" <<EOF
name: os-mihomo
origin: hungcabinet/os-mihomo
version: "${VERSION}"
comment: "Mihomo service and web UI for OPNsense"
desc: "Runs mihomo as an OPNsense service and provides Services → Mihomo to control it and edit config.yaml."
maintainer: hungcabinet@users.noreply.github.com
www: https://github.com/hungcabinet/hc-mihomo
prefix: /usr/local
categories: [sysutils]
licenselogic: single
licenses: [BSD2CLAUSE]
abi: "${ABI}"
arch: "${PKG_ARCH}"
EOF

cp "${PLUGIN_ROOT}/pkg/+POST_INSTALL" "${META}/+POST_INSTALL"
cp "${PLUGIN_ROOT}/pkg/+PRE_DEINSTALL" "${META}/+PRE_DEINSTALL"
chmod 0755 "${META}/+POST_INSTALL" "${META}/+PRE_DEINSTALL"

(cd "${STAGE}" && find . -type f | sed 's|^\./|/|' | sort) > "${META}/plist"

mkdir -p "${OUTPUT_DIR}"
pkg create -m "${META}" -p "${META}/plist" -r "${STAGE}" -o "${OUTPUT_DIR}"

CREATED="$(find "${OUTPUT_DIR}" -maxdepth 1 -name "os-mihomo-${VERSION}*.pkg" -print | head -n 1)"
if [ -z "${CREATED}" ]; then
	echo "pkg create did not produce os-mihomo-${VERSION}*.pkg" >&2
	exit 1
fi

TARGET="${OUTPUT_DIR}/os-mihomo-${VERSION}.${ARCH}.pkg"
if [ "${CREATED}" != "${TARGET}" ]; then
	mv -f "${CREATED}" "${TARGET}"
fi

echo "Built ${TARGET}"
