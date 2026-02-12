#!/usr/bin/env bash
set -euo pipefail

ECK_VERSION="${ECK_VERSION:-2.16.1}"
OPERATOR_MANIFEST="manifests/elastic/eck-operator.yaml"
CRDS_MANIFEST="manifests/elastic/eck-crds.yaml"

if [[ ! -s "${OPERATOR_MANIFEST}" ]] || ! grep -q "elastic-operator" "${OPERATOR_MANIFEST}"; then
  curl -fsSL "https://download.elastic.co/downloads/eck/${ECK_VERSION}/operator.yaml" -o "${OPERATOR_MANIFEST}"
fi

if [[ ! -s "${CRDS_MANIFEST}" ]] || ! grep -q "CustomResourceDefinition" "${CRDS_MANIFEST}"; then
  curl -fsSL "https://download.elastic.co/downloads/eck/${ECK_VERSION}/crds.yaml" -o "${CRDS_MANIFEST}"
fi

kubectl apply -f manifests/namespaces.yaml
kubectl apply -f "${CRDS_MANIFEST}"
kubectl apply -f "${OPERATOR_MANIFEST}"

kubectl wait --for=condition=Established --timeout=240s crd/elasticsearches.elasticsearch.k8s.elastic.co
kubectl wait --for=condition=Established --timeout=240s crd/kibanas.kibana.k8s.elastic.co
kubectl -n elastic-system rollout status statefulset/elastic-operator --timeout=300s
