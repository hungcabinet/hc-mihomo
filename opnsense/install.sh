#!/bin/sh
#
# Install (or remove) the mihomo rc service on OPNsense.
# Run this on the firewall, from a checkout of this directory.

set -e

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
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

restart_backend()
{
	service configd restart >/dev/null 2>&1 || true
	if command -v pluginctl >/dev/null 2>&1; then
		pluginctl -c cron >/dev/null 2>&1 || true
	fi
	if [ -f /usr/local/etc/inc/system.inc ]; then
		php -r 'require_once "/usr/local/etc/inc/config.inc"; require_once "/usr/local/etc/inc/system.inc"; if (function_exists("system_cron_configure")) { system_cron_configure(); }' >/dev/null 2>&1 || true
	fi
	if command -v configctl >/dev/null 2>&1; then
		configctl cron restart >/dev/null 2>&1 || true
	fi
}

case "${ACTION}" in
install)
	install_file "${BASEDIR}/etc/rc.conf.d/mihomo" /etc/rc.conf.d/mihomo 0644
	install_file "${BASEDIR}/usr/local/etc/rc.d/mihomo" /usr/local/etc/rc.d/mihomo 0755
	install_file "${BASEDIR}/usr/local/etc/newsyslog.conf.d/mihomo.conf" /usr/local/etc/newsyslog.conf.d/mihomo.conf 0644
	install_file "${BASEDIR}/usr/local/etc/inc/plugins.inc.d/mihomo.inc" /usr/local/etc/inc/plugins.inc.d/mihomo.inc 0644
	install_file "${BASEDIR}/usr/local/etc/rc.syshook.d/start/90-mihomo" /usr/local/etc/rc.syshook.d/start/90-mihomo 0755
	install_file "${BASEDIR}/usr/local/opnsense/scripts/mihomo/health.sh" /usr/local/opnsense/scripts/mihomo/health.sh 0755
	install_file "${BASEDIR}/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf" /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf 0644

	# Drop leftover file-based cron from older installs; use System → Settings → Cron instead.
	rm -f /usr/local/etc/cron.d/mihomo

	mkdir -p /usr/local/etc/mihomo
	touch /var/log/mihomo.log
	chmod 0640 /var/log/mihomo.log 2>/dev/null || true

	restart_backend
	echo "Installed mihomo service. Start with: service mihomo start"
	echo "Add health check in the GUI: System → Settings → Cron → Mihomo health check"
	;;
uninstall)
	/usr/local/etc/rc.d/mihomo stop >/dev/null 2>&1 || true

	rm -f /etc/rc.conf.d/mihomo
	rm -f /usr/local/etc/rc.d/mihomo
	rm -f /usr/local/etc/cron.d/mihomo
	rm -f /usr/local/etc/newsyslog.conf.d/mihomo.conf
	rm -f /usr/local/etc/inc/plugins.inc.d/mihomo.inc
	rm -f /usr/local/etc/rc.syshook.d/start/90-mihomo
	rm -f /usr/local/opnsense/scripts/mihomo/health.sh
	rm -f /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf
	rm -f /var/run/mihomo.pid /var/run/mihomo.stopped /var/run/mihomo.health.lock

	restart_backend
	echo "Removed mihomo service files."
	;;
*)
	echo "Usage: $0 [install|uninstall]" >&2
	exit 1
	;;
esac
