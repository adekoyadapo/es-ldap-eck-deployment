#!/usr/bin/env bash
set -euo pipefail

if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
fi

kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s
echo "Using ingress-nginx controller"
