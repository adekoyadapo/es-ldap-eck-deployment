#!/usr/bin/env bash
set -euo pipefail

if [[ "${HOST_IP:-}" != "" ]]; then
  echo "${HOST_IP}"
  exit 0
fi

OS="$(uname -s)"

if [[ "${OS}" == "Linux" ]]; then
  if command -v ip >/dev/null 2>&1; then
    ip route get 1.1.1.1 | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
    exit 0
  fi
  if command -v hostname >/dev/null 2>&1; then
    hostname -I | awk '{print $1}'
    exit 0
  fi
fi

if [[ "${OS}" == "Darwin" ]]; then
  IFACE="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
  if [[ "${IFACE}" != "" ]]; then
    ifconfig "${IFACE}" 2>/dev/null | awk '/inet /{print $2; exit}'
    exit 0
  fi
fi

echo "Unable to detect host IP. Export HOST_IP manually, for example: export HOST_IP=192.168.1.10" >&2
exit 1
