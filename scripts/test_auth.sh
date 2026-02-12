#!/usr/bin/env bash
set -euo pipefail

HOST_IP="${HOST_IP:-$(./scripts/detect_host_ip.sh)}"
LDAP_HOST_INTERNAL="ldap.lab.svc.cluster.local"
LDAP_URL="ldaps://${LDAP_HOST_INTERNAL}:636"
ES_URL="https://es.${HOST_IP}.sslip.io"
KIBANA_URL="https://kibana.${HOST_IP}.sslip.io"

kubectl -n lab wait --for=condition=Ready certificate/es-kibana-cert --timeout=180s
kubectl -n lab wait --for=condition=Ready certificate/ldap-ldaps-cert --timeout=180s

CA_B64="$(kubectl -n lab get secret ldap-ldaps-tls -o jsonpath='{.data.ca\.crt}')"
if [[ -z "${CA_B64}" ]]; then
  echo "Root CA not found" >&2
  exit 1
fi

kubectl -n lab delete pod ldap-verify --ignore-not-found >/dev/null
kubectl -n lab run ldap-verify --restart=Never --image=debian:12-slim --env="CA_B64=${CA_B64}" --command -- sh -ec '
set -e
apt-get update >/dev/null
apt-get install -y ldap-utils openssl ca-certificates >/dev/null
printf "%s" "$CA_B64" | base64 -d >/tmp/ca.crt
echo | openssl s_client -connect ldap.lab.svc.cluster.local:636 -servername ldap.lab.svc.cluster.local -CAfile /tmp/ca.crt -showcerts 2>/tmp/sclient.log 1>/tmp/sclient.out || true
awk "/BEGIN CERTIFICATE/{flag=1} flag{print} /END CERTIFICATE/{flag=0}" /tmp/sclient.out > /tmp/ldap.crt
test -s /tmp/ldap.crt
openssl x509 -in /tmp/ldap.crt -noout -ext subjectAltName | tee /tmp/san.txt
grep -q "DNS:ldap.lab.svc.cluster.local" /tmp/san.txt
LDAPTLS_CACERT=/tmp/ca.crt ldapsearch -x -H ldaps://ldap.lab.svc.cluster.local:636 -D "cn=admin,dc=example,dc=org" -w "Admin123!" -b "dc=example,dc=org" "(uid=jane)" dn | grep -q "uid=jane,ou=people,dc=example,dc=org"
'

if ! kubectl -n lab wait --for=jsonpath='{.status.phase}'=Succeeded pod/ldap-verify --timeout=90s >/dev/null 2>&1; then
  kubectl -n lab logs ldap-verify || true
  kubectl -n lab delete pod ldap-verify --ignore-not-found >/dev/null 2>&1 || true
  echo "LDAP verification pod failed" >&2
  exit 1
fi
kubectl -n lab logs ldap-verify >/dev/null
kubectl -n lab delete pod ldap-verify --ignore-not-found >/dev/null

AUTH_RESP="$(curl -sk -u 'jane:Password123!' "${ES_URL}/_security/_authenticate")"
echo "${AUTH_RESP}" | grep -q '"username":"jane"'

KIBANA_CODE="$(curl -sk -o /dev/null -w '%{http_code}' "${KIBANA_URL}")"
if [[ "${KIBANA_CODE}" != "200" && "${KIBANA_CODE}" != "302" ]]; then
  echo "Kibana endpoint check failed. HTTP ${KIBANA_CODE}" >&2
  exit 1
fi

echo "All tests passed"
