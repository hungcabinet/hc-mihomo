#!/bin/sh

BIN="/usr/local/bin/mihomo"

if [ ! -x "${BIN}" ]; then
	echo "mihomo binary not found"
	exit 0
fi

"${BIN}" -v
