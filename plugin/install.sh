#!/bin/sh
#
# Install (or remove) the mihomo plugin files on OPNsense.
# Run this on the firewall, from a checkout of this directory.
# This copies the plugin tree only. It does not install the binary.

set -e

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
SRCDIR="${BASEDIR}/src"
ACTION="${1:-install}"

install_file()
{
	src="$1"
	dst="$2"
	mode="$3"

	mkdir -p "$(dirname "${dst}")"
	cp "${src}" "${dst}"
	chmod "${mode}" "${dst}"
}

file_mode()
{
	rel="$1"
	case "${rel}" in
	usr/local/etc/rc.d/*|usr/local/etc/rc.syshook.d/*|usr/local/opnsense/scripts/mihomo/*)
		echo 0755
		;;
	*)
		echo 0644
		;;
	esac
}

install_tree()
{
	if [ ! -d "${SRCDIR}" ]; then
		echo "Source tree not found: ${SRCDIR}" >&2
		exit 1
	fi

	find "${SRCDIR}" -type f | while IFS= read -r src; do
		rel="${src#${SRCDIR}/}"
		install_file "${src}" "/${rel}" "$(file_mode "${rel}")"
	done
}

remove_tree()
{
	if [ ! -d "${SRCDIR}" ]; then
		echo "Source tree not found: ${SRCDIR}" >&2
		exit 1
	fi

	find "${SRCDIR}" -type f | while IFS= read -r src; do
		rel="${src#${SRCDIR}/}"
		rm -f "/${rel}"
	done
}

restart_backend()
{
	service configd restart >/dev/null 2>&1 || true
	if [ -f /usr/local/opnsense/scripts/mihomo/migrate.php ] && command -v php >/dev/null 2>&1; then
		php /usr/local/opnsense/scripts/mihomo/migrate.php >/dev/null 2>&1 || true
	fi
	if command -v configctl >/dev/null 2>&1; then
		configctl template reload OPNsense/Mihomo >/dev/null 2>&1 || true
		configctl template reload OPNsense/Syslog >/dev/null 2>&1 || true
	fi
	if command -v pluginctl >/dev/null 2>&1; then
		pluginctl -c cron >/dev/null 2>&1 || true
		pluginctl -s syslog restart >/dev/null 2>&1 || true
	elif command -v configctl >/dev/null 2>&1; then
		configctl syslog restart >/dev/null 2>&1 || true
	fi
	rm -f /tmp/opnsense_menu_cache.xml /tmp/opnsense_acl_cache.json
}

case "${ACTION}" in
install)
	install_tree

	rm -f /usr/local/etc/cron.d/mihomo
	rm -f /usr/local/etc/newsyslog.conf.d/mihomo.conf

	mkdir -p /usr/local/etc/mihomo /var/log/mihomo
	if [ ! -f /usr/local/etc/mihomo/config.yaml ] && [ -f /usr/local/share/examples/mihomo/config.yaml ]; then
		cp /usr/local/share/examples/mihomo/config.yaml /usr/local/etc/mihomo/config.yaml
		chmod 0600 /usr/local/etc/mihomo/config.yaml
	fi

	restart_backend
	echo "Installed mihomo plugin files. Open Services → Mihomo, or start with: service mihomo start"
	echo "Add health check in the GUI: System → Settings → Cron → Mihomo health check"
	;;
uninstall)
	/usr/local/etc/rc.d/mihomo stop >/dev/null 2>&1 || true

	remove_tree
	rm -f /usr/local/etc/cron.d/mihomo
	rm -f /usr/local/etc/newsyslog.conf.d/mihomo.conf
	rm -f /var/run/mihomo.pid /var/run/mihomo.stopped /var/run/mihomo.health.lock /var/run/mihomo.config.lock

	restart_backend
	echo "Removed mihomo plugin files. config.yaml, logs, and the binary were left in place."
	;;
*)
	echo "Usage: $0 [install|uninstall]" >&2
	exit 1
	;;
esac
