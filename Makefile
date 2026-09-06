IMAGE_NAME ?= ghcr.io/vorobyevam/devops-engineer-from-scratch-project-318
IMAGE_TAG ?= latest
CONTAINER_NAME ?= project-devops-deploy
APP_PORT ?= 8080
MANAGEMENT_PORT ?= 9090
APP_MANAGEMENT_URL ?= http://127.0.0.1:$(MANAGEMENT_PORT)
NODE_EXPORTER_URL ?= http://127.0.0.1:9100
PROMETHEUS_URL ?= http://111.88.153.136:9090
PROMETHEUS_IMAGE ?= prom/prometheus:v3.12.0
GRAFANA_URL ?= http://111.88.153.136:3000
LOKI_PRIVATE_URL ?= http://10.129.0.4:3100
TEST_IMAGE ?= bulletin-board-test:local
ANSIBLE_LINT_VERSION ?= 26.8.0
LINT_VENV ?= .venv-lint
VAULT_PASSWORD_FILE ?=
VAULT_ARGS = $(if $(VAULT_PASSWORD_FILE),--vault-password-file $(abspath $(VAULT_PASSWORD_FILE)),--ask-vault-pass)

setup:
	@echo "No extra host setup required; Dockerfile installs build dependencies."

app-test:
	@if java -version >/dev/null 2>&1; then \
		./gradlew test; \
	else \
		echo "Java не найдена, тесты выполняются в Docker с JDK 21"; \
		docker build --target backend-builder -t $(TEST_IMAGE) .; \
	fi

$(LINT_VENV)/bin/ansible-lint:
	python3 -m venv $(LINT_VENV)
	$(LINT_VENV)/bin/python -m pip install --upgrade pip
	$(LINT_VENV)/bin/python -m pip install ansible-lint==$(ANSIBLE_LINT_VERSION)

lint: $(LINT_VENV)/bin/ansible-lint
	cd ansible && ANSIBLE_HOME="$(CURDIR)/ansible/.ansible" ../$(LINT_VENV)/bin/ansible-lint .

test: app-test lint

start: run

run:
	./gradlew bootRun

update-gradle:
	./gradlew wrapper --gradle-version 9.7.0

install:
	./gradlew dependencies

build:
	./gradlew build

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run:
	docker run --rm --name $(CONTAINER_NAME) -p $(APP_PORT):8080 -p 127.0.0.1:$(MANAGEMENT_PORT):9090 $(IMAGE_NAME):$(IMAGE_TAG)

docker-start: docker-run

metrics-check:
	curl --fail --show-error --silent $(APP_MANAGEMENT_URL)/actuator/health
	curl --fail --show-error --silent $(APP_MANAGEMENT_URL)/actuator/prometheus | grep -m 1 process_uptime_seconds

node-metrics-check:
	curl --fail --show-error --silent $(NODE_EXPORTER_URL)/metrics | grep -m 1 node_uname_info

ansible-install:
	cd ansible && ansible-galaxy role install -r requirements.yml -p .ansible/roles
	cd ansible && ANSIBLE_COLLECTIONS_PATH="$(CURDIR)/ansible/.ansible/collections" ansible-galaxy collection install -r requirements.yml -p .ansible/collections --force

ansible-check:
	cd ansible && ansible-playbook playbook.yml $(VAULT_ARGS) --check --diff

ansible-syntax:
	cd ansible && ansible-playbook playbook.yml $(VAULT_ARGS) --syntax-check
	cd ansible && ansible-playbook deploy.yml $(VAULT_ARGS) --syntax-check
	cd ansible && ansible-playbook monitoring.yml $(VAULT_ARGS) --syntax-check
	cd ansible && ansible-playbook smoke.yml $(VAULT_ARGS) --syntax-check
	cd ansible && ansible-playbook logging-check.yml $(VAULT_ARGS) --syntax-check

ansible-run:
	cd ansible && ansible-playbook playbook.yml $(VAULT_ARGS)

ansible-ping:
	cd ansible && ansible app_servers -m ping

monitoring-ping:
	cd ansible && ansible monitoring -m ping

monitoring-check:
	cd ansible && ansible-playbook monitoring.yml $(VAULT_ARGS) --check --diff

monitoring-deploy:
	cd ansible && ansible-playbook monitoring.yml $(VAULT_ARGS)

nginx-exporter-deploy:
	cd ansible && ansible-playbook playbook.yml $(VAULT_ARGS)
	cd ansible && ansible-playbook monitoring.yml $(VAULT_ARGS)

logging-deploy:
	cd ansible && ansible-playbook monitoring.yml $(VAULT_ARGS)
	cd ansible && ansible-playbook playbook.yml $(VAULT_ARGS)

logging-check:
	cd ansible && ansible-playbook logging-check.yml $(VAULT_ARGS)

smoke:
	cd ansible && ansible all -m ping $(VAULT_ARGS)
	cd ansible && ansible-playbook smoke.yml $(VAULT_ARGS)
	cd ansible && ansible-playbook logging-check.yml $(VAULT_ARGS)

promtool-check:
	docker run --rm --entrypoint /bin/promtool \
		-v "$(CURDIR)/ansible/roles/prometheus/templates:/work:ro" \
		$(PROMETHEUS_IMAGE) check rules /work/alerts.yml.j2

prometheus-check:
	curl --fail --show-error --silent $(PROMETHEUS_URL)/-/ready
	curl --fail --show-error --silent --get \
		--data-urlencode 'query=up == 1' \
		$(PROMETHEUS_URL)/api/v1/query

grafana-check:
	curl --fail --show-error --silent $(GRAFANA_URL)/api/health

nginx-exporter-check:
	curl --fail --show-error --silent --get \
		--data-urlencode 'query=nginx_up{job="nginx"}' \
		$(PROMETHEUS_URL)/api/v1/query
	curl --fail --show-error --silent --get \
		--data-urlencode 'query=nginx_connections_active{job="nginx"}' \
		$(PROMETHEUS_URL)/api/v1/query
	curl --fail --show-error --silent --get \
		--data-urlencode 'query=nginx_http_requests_total{job="nginx"}' \
		$(PROMETHEUS_URL)/api/v1/query

dashboards-update: monitoring-deploy

alert-test:
	cd ansible && ansible-playbook alert-test.yml $(VAULT_ARGS) -e grafana_test_alert_enabled=true

alert-test-resolve:
	cd ansible && ansible-playbook alert-test.yml $(VAULT_ARGS) -e grafana_test_alert_enabled=false

deploy:
	cd ansible && ansible-playbook deploy.yml $(VAULT_ARGS) -e app_image_tag=$(IMAGE_TAG)

rollback: deploy

deploy-vault:
	cd ansible && ansible-playbook deploy.yml $(VAULT_ARGS) -e app_image_tag=$(IMAGE_TAG)

deploy-no-vault:
	cd ansible && ansible-playbook deploy.yml -e app_image_tag=$(IMAGE_TAG)

vault-create:
	cp ansible/group_vars/app_servers/vault.yml.example ansible/group_vars/app_servers/vault.yml
	cd ansible && ansible-vault encrypt group_vars/app_servers/vault.yml

vault-edit:
	cd ansible && ansible-vault edit group_vars/app_servers/vault.yml

.PHONY: setup build app-test test lint smoke start run install docker-build docker-run docker-start metrics-check node-metrics-check update-gradle ansible-install ansible-check ansible-syntax ansible-run ansible-ping monitoring-ping monitoring-check monitoring-deploy nginx-exporter-deploy logging-deploy logging-check promtool-check prometheus-check grafana-check nginx-exporter-check dashboards-update alert-test alert-test-resolve deploy rollback deploy-vault deploy-no-vault vault-create vault-edit
