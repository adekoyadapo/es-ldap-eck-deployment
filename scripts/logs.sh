#!/usr/bin/env bash
set -euo pipefail

kubectl -n elastic-system logs statefulset/elastic-operator --tail=200 || true
kubectl -n lab logs -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch --tail=200 || true
kubectl -n lab logs -l kibana.k8s.elastic.co/name=kibana --tail=200 || true
kubectl -n lab logs deploy/ldap --tail=200 || true
kubectl -n lab logs deploy/phpldapadmin --tail=200 || true
