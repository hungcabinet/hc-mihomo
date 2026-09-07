#!/bin/sh
#
# Restart mihomo when it is enabled, not administratively stopped, and dead.

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

LOCKFILE="/var/run/mihomo.health.lock"
RC="/usr/local/etc/rc.d/mihomo"

# Always succeed for cron: lock contention and a recovered service are both fine.
/usr/bin/lockf -t 0 "${LOCKFILE}" "${RC}" health
exit 0
