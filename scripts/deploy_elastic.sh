#!/usr/bin/env bash
set -euo pipefail

HOST_IP="${HOST_IP:-$(./scripts/detect_host_ip.sh)}"
ES_VERSION="${ES_VERSION:-8.19.11}"
export HOST_IP
export ES_VERSION

kubectl apply -f manifests/namespaces.yaml
kubectl apply -f manifests/elastic/elastic-ldap-realm-config.yaml
kubectl apply -f manifests/elastic/role-mapping.yaml
sed "s/__ES_VERSION__/${ES_VERSION}/g" manifests/elastic/elasticsearch.yaml | kubectl apply -f -
sed "s/__ES_VERSION__/${ES_VERSION}/g" manifests/elastic/kibana.yaml | kubectl apply -f -

sed "s/__HOST_IP__/${HOST_IP}/g" manifests/ingress/ingress-es.yaml | kubectl apply -f -
sed "s/__HOST_IP__/${HOST_IP}/g" manifests/ingress/ingress-kibana.yaml | kubectl apply -f -

for _ in $(seq 1 60); do
  if kubectl -n lab get pods -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch -o name | grep -q .; then
    break
  fi
  sleep 2
done
for _ in $(seq 1 60); do
  if kubectl -n lab get pods -l kibana.k8s.elastic.co/name=kibana -o name | grep -q .; then
    break
  fi
  sleep 2
done

kubectl -n lab wait --for=condition=Ready pod -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch --timeout=600s
kubectl -n lab wait --for=condition=Ready pod -l kibana.k8s.elastic.co/name=kibana --timeout=420s

ELASTIC_PASSWORD="$(kubectl -n lab get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d)"
if [[ -z "${ELASTIC_PASSWORD}" ]]; then
  echo "Unable to read elastic password from secret" >&2
  exit 1
fi

for _ in $(seq 1 20); do
  RESP="$(curl -sk -u "elastic:${ELASTIC_PASSWORD}" -X POST "https://es.${HOST_IP}.sslip.io/_license/start_trial?acknowledge=true" || true)"
  if [[ "${RESP}" == *"trial_was_started"* ]] || [[ "${RESP}" == *"Trial was already activated"* ]]; then
    break
  fi
  sleep 2
done
