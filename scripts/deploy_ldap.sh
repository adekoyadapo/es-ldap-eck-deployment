#!/usr/bin/env bash
set -euo pipefail

HOST_IP="${HOST_IP:-$(./scripts/detect_host_ip.sh)}"
export HOST_IP

kubectl apply -f manifests/namespaces.yaml
kubectl apply -f manifests/ldap/ldap-tls.yaml

kubectl -n lab create configmap ldap-bootstrap \
  --from-file=manifests/ldap/ldap-bootstrap.ldif \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f manifests/ldap/ldap-service.yaml
kubectl apply -f manifests/ldap/phpldapadmin-service.yaml
kubectl apply -f manifests/ldap/ldap-deployment.yaml
kubectl apply -f manifests/ldap/phpldapadmin-deployment.yaml

sed "s/__HOST_IP__/${HOST_IP}/g" manifests/ingress/ingress-ldap-ui.yaml | kubectl apply -f -

kubectl -n lab rollout status deploy/ldap --timeout=240s
kubectl -n lab rollout status deploy/phpldapadmin --timeout=240s
