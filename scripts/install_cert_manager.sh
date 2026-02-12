#!/usr/bin/env bash
set -euo pipefail

HOST_IP="${HOST_IP:-$(./scripts/detect_host_ip.sh)}"
export HOST_IP

CERT_MANAGER_VERSION="v1.15.4"

kubectl apply -f manifests/namespaces.yaml

if ! kubectl -n cert-manager get deploy cert-manager >/dev/null 2>&1; then
  kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
fi

kubectl -n cert-manager rollout status deploy/cert-manager --timeout=240s
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=240s
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=240s

kubectl apply -f manifests/cert-manager/issuer-rootca.yaml
kubectl apply -f manifests/cert-manager/issuer-ca.yaml
sed "s/__HOST_IP__/${HOST_IP}/g" manifests/cert-manager/cert-es-kibana.yaml | kubectl apply -f -
sed "s/__HOST_IP__/${HOST_IP}/g" manifests/cert-manager/cert-ldap.yaml | kubectl apply -f -

kubectl -n cert-manager wait --for=condition=Ready certificate/lab-root-ca --timeout=180s
kubectl -n lab wait --for=condition=Ready certificate/es-kibana-cert --timeout=180s
kubectl -n lab wait --for=condition=Ready certificate/ldap-ldaps-cert --timeout=180s
