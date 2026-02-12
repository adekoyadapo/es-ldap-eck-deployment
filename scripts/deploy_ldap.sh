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

# Seed POSIX attributes/groups for phpLDAPadmin templates (e.g. gidNumber selection lists).
# This is post-start and idempotent-safe so LDAP bootstrap remains stable.
kubectl -n lab delete pod ldap-posix-seed --ignore-not-found >/dev/null 2>&1 || true
kubectl -n lab run ldap-posix-seed --restart=Never --image=osixia/openldap:1.5.0 --command -- sh -ec '
cat >/tmp/posix-group.ldif <<LDIF
dn: cn=posix-users,ou=groups,dc=example,dc=org
objectClass: top
objectClass: posixGroup
cn: posix-users
gidNumber: 20000
memberUid: jane
LDIF

cat >/tmp/jane-posix.ldif <<LDIF
dn: uid=jane,ou=people,dc=example,dc=org
changetype: modify
add: objectClass
objectClass: posixAccount
-
add: uidNumber
uidNumber: 20000
-
add: gidNumber
gidNumber: 20000
-
add: homeDirectory
homeDirectory: /home/jane
-
add: loginShell
loginShell: /bin/bash
LDIF

ldapadd -x -H ldap://ldap.lab.svc.cluster.local:389 -D "cn=admin,dc=example,dc=org" -w "Admin123!" -c -f /tmp/posix-group.ldif || true
ldapmodify -x -H ldap://ldap.lab.svc.cluster.local:389 -D "cn=admin,dc=example,dc=org" -w "Admin123!" -c -f /tmp/jane-posix.ldif || true
'

kubectl -n lab wait --for=jsonpath='{.status.phase}'=Succeeded pod/ldap-posix-seed --timeout=120s >/dev/null 2>&1 || true
kubectl -n lab logs ldap-posix-seed >/dev/null 2>&1 || true
kubectl -n lab delete pod ldap-posix-seed --ignore-not-found >/dev/null 2>&1 || true
