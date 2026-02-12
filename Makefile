SHELL := /bin/bash

HOST_IP ?= $(shell ./scripts/detect_host_ip.sh)
ES_VERSION ?= 8.19.11
ECK_VERSION ?= 2.16.1
export HOST_IP
export ES_VERSION
export ECK_VERSION

.PHONY: up down status logs test

up:
	@./scripts/validate_version.sh
	@./scripts/create_cluster.sh
	@./scripts/install_ingress.sh
	@./scripts/install_cert_manager.sh
	@./scripts/install_eck.sh
	@./scripts/deploy_ldap.sh
	@./scripts/deploy_elastic.sh
	@./scripts/wait_ready.sh
	@echo ""
	@echo "Environment ready"
	@echo "Kibana:    https://kibana.$${HOST_IP}.sslip.io"
	@echo "Elasticsearch: https://es.$${HOST_IP}.sslip.io"
	@echo "LDAP UI:   https://ldap-ui.$${HOST_IP}.sslip.io"
	@echo "Elastic Stack version: $${ES_VERSION}"
	@echo "LDAP user: jane / Password123!"
	@echo "LDAP admin DN: cn=admin,dc=example,dc=org"
	@echo "LDAP admin password: Admin123!"
	@echo "Elastic password: kubectl -n lab get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d; echo"

down:
	@./scripts/destroy_cluster.sh

status:
	@echo "== Nodes =="
	@kubectl get nodes
	@echo "\n== Pods (all namespaces) =="
	@kubectl get pods -A
	@echo "\n== Ingresses =="
	@kubectl get ingress -A
	@echo "\n== Certificates =="
	@kubectl get certificate -A

logs:
	@./scripts/logs.sh

test:
	@./scripts/test_auth.sh
