#!/bin/sh

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

INCOMING="/tmp/mihomo.incoming.yaml"
WORKDIR="/usr/local/etc/mihomo"
CONF="${WORKDIR}/config.yaml"
BIN="/usr/local/bin/mihomo"
LOCK="/var/run/mihomo.config.lock"
MAX_BYTES=8388608

if [ "${MIHOMO_CONFIG_LOCKED:-0}" -ne 1 ]; then
	export MIHOMO_CONFIG_LOCKED=1
	exec /usr/bin/lockf -s -t 30 "${LOCK}" "$0" "$@"
fi

fail()
{
	echo "FAILED"
	if [ -n "$1" ]; then
		printf '%s\n' "$1"
	fi
	exit 1
}

if [ ! -x "${BIN}" ]; then
	fail "mihomo binary not found."
fi

if [ ! -f "${INCOMING}" ]; then
	fail "Staged config is missing."
fi

SIZE=$(wc -c < "${INCOMING}")
if [ "${SIZE}" -gt "${MAX_BYTES}" ]; then
	fail "Config larger than 8 MiB."
fi

mkdir -p "${WORKDIR}"
TMP=$(mktemp "${WORKDIR}/.config.XXXXXX") || fail "Unable to create a temporary config file."
cp "${INCOMING}" "${TMP}" || {
	rm -f "${TMP}"
	fail "Unable to copy the staged config."
}
chmod 0600 "${TMP}"
chown root:wheel "${TMP}" 2>/dev/null || true

if ! OUT=$("${BIN}" -t -d "${WORKDIR}" -f "${TMP}" 2>&1); then
	rm -f "${TMP}"
	fail "${OUT}"
fi

mv -f "${TMP}" "${CONF}"
chmod 0600 "${CONF}"
chown root:wheel "${CONF}" 2>/dev/null || true
rm -f "${INCOMING}"

if /usr/local/etc/rc.d/mihomo status >/dev/null 2>&1; then
	if ! /usr/local/etc/rc.d/mihomo restart; then
		fail "Config written, but the service failed to restart. See System → Log Files → mihomo."
	fi
	echo "OK"
	echo "reloaded=1"
	exit 0
fi

echo "OK"
echo "reloaded=0"
exit 0
