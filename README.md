# Наблюдаемость приложения Bulletin Board

[![hexlet-check](https://github.com/VorobyevAM/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/VorobyevAM/devops-engineer-from-scratch-project-318/actions)
[![CI](https://github.com/VorobyevAM/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml/badge.svg)](https://github.com/VorobyevAM/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml)

Проект разворачивает доску объявлений на Spring Boot и React, PostgreSQL,
Nginx и стек наблюдаемости: Node Exporter, Nginx Prometheus Exporter,
Prometheus, Grafana, Loki и Promtail. Серверы настраиваются плейбуками из
каталога `ansible`, приложение и сервисы наблюдаемости работают в Docker.

Исходный проект — `hexlet-components/project-devops-deploy`. Репозиторий этого
решения — `VorobyevAM/devops-engineer-from-scratch-project-318`.

## Текущее окружение

### Серверы

| Назначение | Группа inventory | Публичный IP | Приватный IP | Пользователь |
|---|---|---:|---:|---|
| Приложение, PostgreSQL, Nginx, exporters, Promtail | `app_servers` | `62.84.122.118` | `10.129.0.32` | `yc-user` |
| Prometheus, Grafana, Loki | `monitoring` | `111.88.153.136` | `10.129.0.4` | `yc-user` |

Публичные адреса находятся в `ansible/inventory.ini`, приватные — в
`ansible/group_vars/all/main.yml`. При переносе окружения IP меняются только в
этих двух местах.

### URL для проверяющего

| Сервис | URL |
|---|---|
| Приложение | `https://hexlet-vorobev.chickenkiller.com` |
| REST API | `https://hexlet-vorobev.chickenkiller.com/api/bulletins` |
| Swagger UI | `https://hexlet-vorobev.chickenkiller.com/swagger-ui/index.html` |
| Prometheus | `http://111.88.153.136:9090/graph` |
| Цели Prometheus | `http://111.88.153.136:9090/targets` |
| Grafana | `http://111.88.153.136:3000` |
| Страница состояния | `http://111.88.153.136:3000/d/status-page/status-page` |
| Системные ресурсы | `http://111.88.153.136:3000/d/system-resources/system-resources` |
| Состояние приложения | `http://111.88.153.136:3000/d/application-overview/application-overview` |
| HTTP-коды и задержки | `http://111.88.153.136:3000/d/http-performance/http-performance` |
| Метрики Nginx | `http://111.88.153.136:3000/d/nginx-overview/nginx-overview` |
| Централизованные логи | `http://111.88.153.136:3000/d/centralized-logs/centralized-logs` |

Логин Grafana — `admin`. Пароль хранится как `grafana_admin_password` в
зашифрованном Ansible Vault и в репозитории отсутствует.

### Порты и доступ

| ВМ | Порт | Разрешённый источник | Назначение |
|---|---:|---|---|
| приложение | `22/tcp` | IP администратора `/32` | SSH |
| приложение | `80/tcp` | `0.0.0.0/0` | ACME и перенаправление на HTTPS |
| приложение | `443/tcp` | `0.0.0.0/0` | приложение и REST API |
| приложение | `8080/tcp` | только `127.0.0.1` | upstream приложения |
| приложение | `9090/tcp` | `10.129.0.4/32` | Actuator и Nginx exporter через Nginx |
| приложение | `9100/tcp` | `10.129.0.4/32` | Node Exporter через Nginx |
| приложение | `9113/tcp` | только `127.0.0.1` | сырой Nginx exporter |
| приложение | `9080/tcp` | только `127.0.0.1` | readiness Promtail |
| monitoring | `22/tcp` | IP администратора `/32` | SSH |
| monitoring | `9090/tcp` | проверяющий/администратор | UI Prometheus |
| monitoring | `3000/tcp` | проверяющий/администратор | UI Grafana |
| monitoring | `3100/tcp` | `10.129.0.32/32` | приём логов Loki через Basic Auth |
| monitoring | `9091/3001/3101` | только `127.0.0.1` | внутренние порты контейнеров |

Ограничения должны одновременно присутствовать в Security Groups Yandex Cloud
и UFW. Внутренние порты нельзя открывать в Интернет.

### Каналы оповещений

| Канал | Состояние | Настройка |
|---|---|---|
| Почта | активен, доставка подтверждена | отправитель и получатель `vorobyev.93@mail.ru`, SMTP Mail.ru |
| ntfy | contact point подготовлен | секретный URL `grafana_ntfy_webhook_url` в Vault |
| Telegram | не настроен | для подключения нужны token и chat ID в Vault |

Письмо от тестового алерта получено 6 сентября 2026 года. Пример сохранён в
`assets/grafana-email-alert-firing.png`.

## Структура Ansible

| Путь | Назначение |
|---|---|
| `ansible/inventory.ini` | публичные IP и SSH-пользователи |
| `ansible/group_vars/all/main.yml` | приватные IP и окружение |
| `ansible/group_vars/app_servers.yml` | приложение, Nginx, exporters, Promtail |
| `ansible/group_vars/monitoring.yml` | Prometheus, Grafana, Loki и alert rules |
| `ansible/group_vars/all/vault.yml` | общие зашифрованные секреты |
| `ansible/playbook.yml` | подготовка сервера приложения |
| `ansible/deploy.yml` | PostgreSQL, Flyway и приложение |
| `ansible/monitoring.yml` | сервер наблюдаемости |
| `ansible/smoke.yml` | комплексная проверка окружения |
| `ansible/logging-check.yml` | проверка Promtail → Loki |
| `ansible/alert-test.yml` | ручной тест уведомлений |

Все конфигурации шаблонизированы. Пароли и токены в шаблонах отсутствуют.

## Развёртывание с нуля

### 1. Подготовить локальную машину

Необходимы Git, Python 3, Ansible, Docker с Buildx, Java 21, Node.js 24 и npm.
Создайте SSH-ключ и добавьте публичную часть в метаданные ВМ Yandex Cloud:

```bash
ssh-keygen -t ed25519 -C "devops-project"
```

### 2. Создать fork и клонировать репозиторий

```bash
git clone git@github.com:<имя-пользователя>/devops-engineer-from-scratch-project-318.git
cd devops-engineer-from-scratch-project-318
git remote add upstream https://github.com/hexlet-components/project-devops-deploy.git
```

### 3. Создать инфраструктуру

Создайте в одной VPC две Ubuntu 22.04/24.04 ВМ минимум с 2 CPU, 2 ГБ RAM и
20 ГБ диска: `bulletin-board` и `monitoring`. Назначьте Security Groups по
таблице портов выше. Для файлов создайте bucket Yandex Object Storage.

Текущая конфигурация использует PostgreSQL-контейнер с persistent bind mount.
При необходимости вместо него можно указать Managed PostgreSQL через
`SPRING_DATASOURCE_*`.

Создайте DNS A-запись домена на публичный IP приложения и проверьте доступ:

```bash
ssh yc-user@<app-public-ip>
ssh yc-user@<monitoring-public-ip>
dig +short hexlet-vorobev.chickenkiller.com
```

### 4. Заполнить inventory и переменные

`ansible/inventory.ini`:

```ini
[app_servers]
app ansible_host=<app-public-ip> ansible_user=yc-user

[monitoring]
prometheus ansible_host=<monitoring-public-ip> ansible_user=yc-user
```

`ansible/group_vars/all/main.yml`:

```yaml
app_private_ip: <app-private-ip>
monitoring_private_ip: <monitoring-private-ip>
deployment_environment: production
```

Домен и образ задаются в `ansible/group_vars/app_servers.yml`, версии и
параметры monitoring-стека — в `ansible/group_vars/monitoring.yml`.

### 5. Создать Vault

```bash
cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
ansible-vault encrypt ansible/group_vars/all/vault.yml
```

Обязательные общие секреты:

```yaml
monitoring_basic_auth_password: <случайный-пароль-не-короче-16-символов>
grafana_admin_password: <другой-случайный-пароль-не-короче-16-символов>
grafana_ntfy_webhook_url: https://ntfy.sh/<случайный-topic>?template=grafana
grafana_smtp_password: <пароль-приложения-Mail.ru>
```

Создайте отдельный Vault приложения:

```bash
cp ansible/group_vars/app_servers/vault.yml.example ansible/group_vars/app_servers/vault.yml
ansible-vault encrypt ansible/group_vars/app_servers/vault.yml
```

Минимальная конфигурация PostgreSQL:

```yaml
postgres_user: bulletins
postgres_password: <случайный-пароль>
app_secret_env:
  SPRING_DATASOURCE_URL: jdbc:postgresql://bulletin-board-postgres:5432/bulletins
  SPRING_DATASOURCE_USERNAME: bulletins
  SPRING_DATASOURCE_PASSWORD: <тот-же-пароль>
```

Переменные Yandex Object Storage добавляются в `app_secret_env`:

```yaml
STORAGE_S3_BUCKET: <bucket>
STORAGE_S3_REGION: ru-central1
STORAGE_S3_ENDPOINT: https://storage.yandexcloud.net
STORAGE_S3_ACCESSKEY: <access-key-id>
STORAGE_S3_SECRETKEY: <secret-access-key>
```

Vault-файлы и `.vault_pass` перечислены в `.gitignore`.

### 6. Установить зависимости и проверить код

```bash
make ansible-install
make lint
make test
make ansible-syntax VAULT_PASSWORD_FILE=.vault_pass
```

`make lint` создаёт игнорируемое окружение `.venv-lint` и устанавливает
закреплённый `ansible-lint 26.8.0`.

### 7. Подготовить обе ВМ

```bash
make monitoring-deploy VAULT_PASSWORD_FILE=.vault_pass
make ansible-run VAULT_PASSWORD_FILE=.vault_pass
```

Плейбуки устанавливают Docker, Nginx, UFW и агенты. Их можно запускать
повторно: они приводят серверы к описанному состоянию.

### 8. Развернуть приложение

```bash
make deploy VAULT_PASSWORD_FILE=.vault_pass IMAGE_TAG=latest
```

Плейбук запускает PostgreSQL, применяет Flyway-миграции, загружает образ,
извлекает статические файлы для Nginx и ждёт Actuator healthcheck. Откат:

```bash
make rollback VAULT_PASSWORD_FILE=.vault_pass IMAGE_TAG=sha-abcdef1
```

### 9. Выполнить итоговую проверку

```bash
make smoke VAULT_PASSWORD_FILE=.vault_pass
```

Проверяются SSH обеих ВМ, главная страница, статика, REST API, Actuator,
Node Exporter, Docker-контейнеры, Prometheus, Grafana, `up == 1`, наличие логов
в Loki и доставка уникального Nginx-лога через Promtail.

## Обязательные метрики

| Область | Метрика | Назначение |
|---|---|---|
| CPU | `node_load1`, `node_cpu_seconds_total` | load average и загрузка CPU |
| Память | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes` | объём и доступная память |
| Файловые системы | `node_filesystem_size_bytes`, `node_filesystem_avail_bytes` | заполнение диска |
| Диски | `node_disk_read_bytes_total`, `node_disk_written_bytes_total` | дисковый ввод-вывод |
| Сеть | `node_network_receive_bytes_total`, `node_network_transmit_bytes_total` | сетевой трафик |
| Процессы | `node_procs_running`, `node_processes_state` | процессы по состояниям |
| Сервисы | `node_systemd_unit_state` | состояние служб systemd |
| Доступность | `up` | доступность целей Prometheus |
| JVM | `process_uptime_seconds`, `process_cpu_usage`, `jvm_memory_used_bytes` | uptime, CPU и heap |
| GC | `jvm_gc_pause_seconds_count` | паузы сборщика мусора |
| HTTP | `http_server_requests_seconds_count` | запросы и коды по label `status` |
| HTTP | `http_server_requests_seconds_bucket` | p50/p90/p95/p99 latency |
| Nginx | `nginx_up`, `nginx_http_requests_total` | доступность и RPS |
| Nginx | `nginx_connections_active` | активные соединения |
| Nginx | `nginx_connections_reading`, `nginx_connections_writing`, `nginx_connections_waiting` | состояния соединений |

Prometheus опрашивает `/actuator/prometheus`, `/metrics` и
`/nginx-exporter/metrics`. Запрос `up` должен вернуть три ряда со значением
`1`: `node`, `application` и `nginx`.

```bash
make prometheus-check
make nginx-exporter-check
```

## Централизованные логи

Приложение пишет JSON в stdout, Nginx — JSON access/error логи. Promtail
добавляет labels `job`, `env`, `app`, `host`, `log_type` и отправляет записи в
Loki по приватному адресу с Basic Auth.

Полезные LogQL-запросы:

```logql
{job="application",env="production",app="bulletins"} | json
{job="nginx",log_type="access"} | json | status >= 500
sum(count_over_time({job="nginx",log_type="access"} | json | status >= 500 [5m]))
max(quantile_over_time(0.95, {job="nginx",log_type="access"} | json | unwrap request_time | __error__="" [5m]))
{job=~"application|nginx"} |~ "(?i)<пользователь-или-IP>"
```

```bash
make logging-check VAULT_PASSWORD_FILE=.vault_pass
```

Promtail завершил жизненный цикл 2 марта 2026 года. Версия `3.6.11`
закреплена для выполнения задания; для новой production-инфраструктуры следует
планировать миграцию на Grafana Alloy.

## Grafana и алерты

Provisioning создаёт datasources Prometheus и Loki и шесть дашбордов:

- `System Resources`;
- `Application Overview`;
- `HTTP Performance`;
- `Status Page`;
- `Nginx Overview`;
- `Centralized Logs`.

Настроены сценарии падения приложения, роста 5xx, высокого CPU/RAM, заполнения
диска, высокой p95 latency и отсутствия метрик. У правил есть labels `service`
и `severity`, а параметр `for` отсекает кратковременные всплески.

В Grafana правила находятся в **Alerting → Alert rules**, контакты — в
**Alerting → Contact points**, маршрутизация — в **Alerting → Notification
policies**.

Ручной тест почтового уведомления:

```bash
make alert-test VAULT_PASSWORD_FILE=.vault_pass
# Подождать до 45 секунд и проверить Inbox/Spam.
make alert-test-resolve VAULT_PASSWORD_FILE=.vault_pass
```

Тестовое правило по умолчанию выключено.

## Скриншоты

| Файл | Содержимое |
|---|---|
| `assets/grafana-system-resources.jpg` | системные ресурсы |
| `assets/grafana-application-overview.jpg` | состояние приложения |
| `assets/grafana-http-performance.jpg` | HTTP-коды и latency |
| `assets/grafana-nginx-overview.jpg` | метрики Nginx |
| `assets/grafana-centralized-logs.jpg` | логи Loki |
| `assets/grafana-email-alert-firing.png` | полученное тестовое письмо |

## Основные команды

| Команда | Назначение |
|---|---|
| `make lint` | установить и запустить `ansible-lint` |
| `make test` | тесты Spring Boot и Ansible lint |
| `make smoke` | полная проверка работающего окружения |
| `make docker-build` | локальная сборка Docker-образа |
| `make docker-run` | локальный запуск приложения |
| `make ansible-install` | установить Ansible roles и collections |
| `make ansible-syntax` | проверить синтаксис всех плейбуков |
| `make ansible-run` | подготовить сервер приложения |
| `make monitoring-deploy` | развернуть Prometheus, Grafana и Loki |
| `make deploy` | развернуть PostgreSQL и приложение |
| `make logging-deploy` | синхронизировать Loki и Promtail |
| `make logging-check` | проверить доставку тестового лога |
| `make dashboards-update` | обновить provisioning Grafana |
| `make alert-test` | включить тестовый алерт |
| `make alert-test-resolve` | выключить тестовый алерт |
| `make rollback IMAGE_TAG=...` | откатить приложение на предыдущий тег |

## CI/CD

GitHub Actions собирает frontend, запускает Gradle-тесты и собирает Docker
image. При успешном push в `main` образ публикуется в GHCR с тегами `latest` и
`sha-<7-символов-коммита>`. Для private package данные registry должны лежать
в Vault как `app_registry_username` и `app_registry_password`.

Данные PostgreSQL, Prometheus, Grafana, Loki и позиции Promtail находятся в
persistent volumes или bind mounts и переживают пересоздание контейнеров.
