#!/bin/sh

LINES="${1:-200}"
case "${LINES}" in
''|*[!0-9]*)
	LINES=200
	;;
esac

if [ "${LINES}" -gt 2000 ]; then
	LINES=2000
fi

LOGDIR="/var/log/mihomo"
if [ ! -d "${LOGDIR}" ]; then
	echo "No log directory yet."
	exit 0
fi

TODAY="mihomo_$(date +%Y%m%d).log"
if [ -f "${LOGDIR}/${TODAY}" ]; then
	FILE="${LOGDIR}/${TODAY}"
else
	FILE=$(ls -1t "${LOGDIR}"/mihomo_*.log 2>/dev/null | head -n 1)
fi

if [ -z "${FILE}" ] || [ ! -f "${FILE}" ]; then
	echo "No log file yet."
	exit 0
fi

tail -n "${LINES}" "${FILE}"
