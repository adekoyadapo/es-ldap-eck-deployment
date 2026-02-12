#!/usr/bin/env bash
set -euo pipefail

if command -v k3d >/dev/null 2>&1; then
  if k3d cluster list | awk '{print $1}' | grep -qx "lab-sso"; then
    k3d cluster delete lab-sso
  fi
fi
