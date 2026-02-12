#!/usr/bin/env bash
set -euo pipefail

kubectl -n lab wait --for=condition=Ready certificate/es-kibana-cert --timeout=180s
kubectl -n lab wait --for=condition=Ready certificate/ldap-ldaps-cert --timeout=180s

kubectl -n lab wait --for=condition=Ready pod -l app=ldap --timeout=240s
kubectl -n lab wait --for=condition=Ready pod -l app=phpldapadmin --timeout=240s
kubectl -n lab wait --for=condition=Ready pod -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch --timeout=600s
kubectl -n lab wait --for=condition=Ready pod -l kibana.k8s.elastic.co/name=kibana --timeout=420s
