#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="lab-sso"

if ! command -v k3d >/dev/null 2>&1; then
  echo "k3d is required" >&2
  exit 1
fi

if k3d cluster list | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  echo "k3d cluster ${CLUSTER_NAME} already exists"
else
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 0 \
    --wait \
    --k3s-arg "--disable=traefik@server:0" \
    -p "80:80@loadbalancer" \
    -p "443:443@loadbalancer"
fi

kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null
kubectl get nodes >/dev/null
