#!/bin/sh

CONF="/usr/local/etc/mihomo/config.yaml"

if [ ! -f "${CONF}" ]; then
	exit 0
fi

cat "${CONF}"
