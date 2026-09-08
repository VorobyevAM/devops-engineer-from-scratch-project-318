# Инфраструктура и наблюдаемость Bulletin Board

[![CI инфраструктуры](https://github.com/VorobyevAM/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml/badge.svg)](https://github.com/VorobyevAM/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml)

Репозиторий содержит Ansible-инфраструктуру для приложения Bulletin Board:
сервер приложения с PostgreSQL, Nginx и агентами, а также отдельный сервер
наблюдаемости с Prometheus, Grafana и Loki. Все компоненты разворачиваются
повторяемыми плейбуками из каталога `ansible`.

Исходный код приложения хранится отдельно — в форке
[`VorobyevAM/project-devops-deploy`](https://github.com/VorobyevAM/project-devops-deploy).
Его GitHub Actions собирает и публикует образ
`ghcr.io/vorobyevam/project-devops-deploy`. В этом репозитории находится только
инфраструктурный код.

## Действующее окружение

### Адреса

| Назначение | Адрес |
|---|---|
| Приложение | [https://62-84-122-118.sslip.io](https://62-84-122-118.sslip.io) |
| REST API | [https://62-84-122-118.sslip.io/api/bulletins](https://62-84-122-118.sslip.io/api/bulletins) |
| Swagger UI | [https://62-84-122-118.sslip.io/swagger-ui/index.html](https://62-84-122-118.sslip.io/swagger-ui/index.html) |
| Prometheus | [http://111.88.153.136:9090/graph](http://111.88.153.136:9090/graph) |
| Цели Prometheus | [http://111.88.153.136:9090/targets](http://111.88.153.136:9090/targets) |
| Grafana | [http://111.88.153.136:3000](http://111.88.153.136:3000) |
| Страница состояния | [Status Page](http://111.88.153.136:3000/d/status-page/status-page) |
| Системные ресурсы | [System Resources](http://111.88.153.136:3000/d/system-resources/system-resources) |
| Состояние приложения | [Application Overview](http://111.88.153.136:3000/d/application-overview/application-overview) |
| HTTP-коды и задержки | [HTTP Performance](http://111.88.153.136:3000/d/http-performance/http-performance) |
| Метрики Nginx | [Nginx Overview](http://111.88.153.136:3000/d/nginx-overview/nginx-overview) |
| Централизованные логи | [Centralized Logs](http://111.88.153.136:3000/d/centralized-logs/centralized-logs) |

Пользователь Grafana — `admin`. Пароль находится в зашифрованной переменной
`grafana_admin_password` и в открытом виде в Git не хранится.

### Серверы

| Группа Ansible | Назначение | Публичный IP | Приватный IP | SSH-пользователь |
|---|---|---:|---:|---|
| `app_servers` | приложение, PostgreSQL, Nginx, экспортёры, Promtail | `62.84.122.118` | `10.129.0.32` | `yc-user` |
| `monitoring` | Prometheus, Grafana, Loki | `111.88.153.136` | `10.129.0.4` | `yc-user` |

Публичные IP задаются в `ansible/inventory.ini`, приватные — в
`ansible/group_vars/all/main.yml`. При смене адресов также обновите домен в
`ansible/group_vars/app_servers.yml` и значения URL по умолчанию в `Makefile`.

### Схема

```text
Интернет
   │ HTTPS :443
   ▼
ВМ приложения ── Nginx ── приложение + PostgreSQL
   │                 ├── Node Exporter
   │ private VPC     ├── Nginx Prometheus Exporter
   │                 └── Promtail
   ▼
ВМ monitoring ── Prometheus + Grafana + Loki
```

Prometheus забирает метрики только по приватной сети. Promtail отправляет логи
в Loki тем же путём. Grafana получает метрики и логи из общей Docker-сети
`monitoring`.

### Порты

| ВМ | Порт | Разрешённый источник | Назначение |
|---|---:|---|---|
| приложение | `22/tcp` | IP администратора `/32` | SSH |
| приложение | `80/tcp` | Интернет | ACME и перенаправление на HTTPS |
| приложение | `443/tcp` | Интернет | приложение и REST API |
| приложение | `8080/tcp` | `127.0.0.1` | внутренний порт приложения |
| приложение | `9090/tcp` | monitoring `10.129.0.4/32` | Actuator, `stub_status`, Nginx exporter через Nginx |
| приложение | `9100/tcp` | monitoring `10.129.0.4/32` | Node Exporter через Nginx |
| приложение | `9113/tcp` | `127.0.0.1` | внутренний Nginx Exporter |
| приложение | `9080/tcp` | `127.0.0.1` | проверка готовности Promtail |
| monitoring | `22/tcp` | IP администратора `/32` | SSH |
| monitoring | `9090/tcp` | проверяющий/администратор | интерфейс Prometheus |
| monitoring | `3000/tcp` | проверяющий/администратор | интерфейс Grafana |
| monitoring | `3100/tcp` | приложение `10.129.0.32/32` | приём логов Loki с Basic Auth |
| monitoring | `9091`, `3001`, `3101` | `127.0.0.1` | внутренние порты контейнеров |

Ограничения должны быть настроены одновременно в Security Groups Yandex Cloud
и UFW. Порты метрик и Loki нельзя открывать всему Интернету.

## Структура репозитория

| Путь | Назначение |
|---|---|
| `ansible/inventory.ini` | публичные IP и SSH-пользователи |
| `ansible/group_vars/all/main.yml` | приватные IP и окружение |
| `ansible/group_vars/app_servers.yml` | приложение, Nginx, экспортёры и Promtail |
| `ansible/group_vars/monitoring.yml` | Prometheus, Grafana, Loki и правила алертов |
| `ansible/group_vars/**/vault.yml.example` | примеры секретных переменных без рабочих значений |
| `ansible/playbook.yml` | подготовка сервера приложения |
| `ansible/deploy.yml` | запуск PostgreSQL и приложения |
| `ansible/monitoring.yml` | развёртывание сервера наблюдаемости |
| `ansible/smoke.yml` | итоговые проверки всего окружения |
| `ansible/logging-check.yml` | сквозная проверка Promtail → Loki |
| `ansible/alert-test.yml` | включение и выключение тестового алерта |
| `ansible/roles/` | собственные роли сервисов |
| `ansible/requirements.yml` | внешние роли и коллекции Ansible |
| `assets/` | снимки дашбордов и тестового уведомления |

Скачанные роли и коллекции устанавливаются в `ansible/.ansible` и игнорируются
Git. Конфигурации сервисов шаблонизированы, секреты в шаблонах отсутствуют.

## Развёртывание с нуля

### 1. Подготовить локальную машину и SSH

Нужны Git, Python 3, Ansible, Docker и доступ к двум ВМ Ubuntu 22.04/24.04.
Создайте ключ и добавьте его публичную часть в метаданные ВМ Yandex Cloud:

```bash
ssh-keygen -t ed25519 -C "devops-project"
ssh yc-user@<app-public-ip>
ssh yc-user@<monitoring-public-ip>
```

### 2. Создать облачные ресурсы

В одной VPC создайте две ВМ минимум с 2 CPU, 2 ГБ RAM и диском 20 ГБ:
`bulletin-board` и `monitoring`. Настройте Security Groups по таблице портов
выше. Для файлов приложения создайте bucket Yandex Object Storage.

В текущем окружении PostgreSQL работает в контейнере с постоянным каталогом
данных на сервере.
Внешний Managed PostgreSQL можно подключить через переменные
`SPRING_DATASOURCE_*`.

Для собственного домена добавьте DNS A-запись на публичный IP приложения.
Адрес вида `<ip-с-дефисами>.sslip.io` подходит для проверки без отдельной
DNS-зоны.

### 3. Клонировать репозиторий и задать адреса

```bash
git clone git@github.com:<имя-пользователя>/devops-engineer-from-scratch-project-318.git
cd devops-engineer-from-scratch-project-318
```

Заполните `ansible/inventory.ini`:

```ini
[app_servers]
app ansible_host=<app-public-ip> ansible_user=yc-user

[monitoring]
prometheus ansible_host=<monitoring-public-ip> ansible_user=yc-user
```

Укажите приватные IP в `ansible/group_vars/all/main.yml`, а домен и адрес
образа — в `ansible/group_vars/app_servers.yml`.

### 4. Создать Ansible Vault

Общие секреты нужны обеим группам серверов:

```bash
cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
ansible-vault encrypt ansible/group_vars/all/vault.yml
```

```yaml
monitoring_basic_auth_password: <случайный-пароль-не-короче-16-символов>
grafana_admin_password: <другой-пароль-не-короче-16-символов>
grafana_ntfy_webhook_url: https://ntfy.sh/<случайный-topic>?template=grafana
grafana_smtp_password: <пароль-приложения-Mail.ru>
```

Создайте отдельный Vault приложения:

```bash
cp ansible/group_vars/app_servers/vault.yml.example ansible/group_vars/app_servers/vault.yml
ansible-vault encrypt ansible/group_vars/app_servers/vault.yml
```

Минимальные переменные базы данных:

```yaml
postgres_user: bulletins
postgres_password: <случайный-пароль>
app_secret_env:
  SPRING_DATASOURCE_URL: jdbc:postgresql://bulletin-board-postgres:5432/bulletins
  SPRING_DATASOURCE_USERNAME: bulletins
  SPRING_DATASOURCE_PASSWORD: <тот-же-пароль>
```

Для Yandex Object Storage добавьте в `app_secret_env`:

```yaml
STORAGE_S3_BUCKET: <bucket>
STORAGE_S3_REGION: ru-central1
STORAGE_S3_ENDPOINT: https://storage.yandexcloud.net
STORAGE_S3_ACCESSKEY: <access-key-id>
STORAGE_S3_SECRETKEY: <secret-access-key>
```

Vault-файлы и файл пароля `.vault_pass` перечислены в `.gitignore`. Не
добавляйте их в Git в незашифрованном виде.

### 5. Установить зависимости и проверить Ansible

```bash
make ansible-install
make test
```

`make test` запускает `ansible-lint` и syntax-check всех пяти плейбуков.
Линтер устанавливается в локальное игнорируемое окружение `.venv-lint`.

### 6. Развернуть сервисы

Сначала поднимите Loki на monitoring-сервере, затем подготовьте сервер
приложения с Promtail и разверните само приложение:

```bash
make monitoring-deploy VAULT_PASSWORD_FILE=.vault_pass
make ansible-run VAULT_PASSWORD_FILE=.vault_pass
make deploy VAULT_PASSWORD_FILE=.vault_pass IMAGE_TAG=latest
```

Плейбуки устанавливают Docker, Nginx и Certbot готовыми ролями из
`ansible/requirements.yml`. Certbot выпускает сертификат методом webroot и
настраивает ежедневное обновление. Повторный запуск плейбуков безопасен.

Для отката укажите опубликованный SHA-тег образа:

```bash
make rollback VAULT_PASSWORD_FILE=.vault_pass IMAGE_TAG=sha-abcdef1
```

### 7. Выполнить итоговую проверку

```bash
make smoke VAULT_PASSWORD_FILE=.vault_pass
```

Команда проверяет SSH обеих ВМ, главную страницу и REST API, Actuator, Node
Exporter, контейнеры, готовность Prometheus и Grafana, три цели со значением
`up == 1`, наличие логов в Loki и доставку уникальной записи Nginx через
Promtail.

## Метрики и точки проверки

### Обязательные метрики

| Область | Метрика | Что контролируется |
|---|---|---|
| CPU | `node_load1`, `node_cpu_seconds_total` | средняя нагрузка и использование CPU |
| Память | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes` | общий и доступный объём памяти |
| Файловые системы | `node_filesystem_size_bytes`, `node_filesystem_avail_bytes` | заполнение диска |
| Диски | `node_disk_read_bytes_total`, `node_disk_written_bytes_total` | дисковый ввод-вывод |
| Сеть | `node_network_receive_bytes_total`, `node_network_transmit_bytes_total` | входящий и исходящий трафик |
| Процессы | `node_procs_running`, `node_processes_state` | состояния процессов |
| Сервисы | `node_systemd_unit_state` | состояние служб systemd |
| Доступность | `up` | доступность целей Prometheus |
| JVM | `process_uptime_seconds`, `process_cpu_usage`, `jvm_memory_used_bytes` | время работы, CPU и память JVM |
| Сборка мусора | `jvm_gc_pause_seconds_count` | паузы GC |
| HTTP | `http_server_requests_seconds_count` | запросы и коды по метке `status` |
| HTTP | `http_server_requests_seconds_bucket` | перцентили задержки |
| Nginx | `nginx_up`, `nginx_http_requests_total` | доступность и RPS |
| Nginx | `nginx_connections_active` | активные соединения |
| Nginx | `nginx_connections_reading`, `nginx_connections_writing`, `nginx_connections_waiting` | состояния соединений |

Prometheus получает три набора метрик: `node` с `/metrics`, `application` с
`/actuator/prometheus` и `nginx` с `/nginx-exporter/metrics`. Защищённые точки
доступа слушают только приватный IP сервера приложения и требуют Basic Auth.

```bash
make prometheus-check
make nginx-exporter-check

# Локальные проверки на ВМ приложения без публикации management-портов наружу
ssh yc-user@62.84.122.118 'curl -fsS http://127.0.0.1:9090/actuator/health'
ssh yc-user@62.84.122.118 'curl -fsS http://127.0.0.1:9090/actuator/prometheus | head'
ssh yc-user@62.84.122.118 'curl -fsS http://127.0.0.1:8081/stub_status'
```

Открытый Nginx `stub_status` предоставляет только счётчики запросов и
соединений. HTTP-коды и задержки берутся из Micrometer приложения, а также из
JSON access-логов через Loki.

## Централизованные логи

Приложение пишет JSON в stdout, Nginx — JSON access/error логи. Promtail
добавляет метки `job`, `env`, `app`, `host`, `log_type` и отправляет записи в
Loki по приватной сети с Basic Auth.

Полезные LogQL-запросы:

```logql
{job="application",env="production",app="bulletins"} | json
{job="nginx",log_type="access"} | json | status >= 500
sum(count_over_time({job="nginx",log_type="access"} | json | status >= 500 [5m]))
max(quantile_over_time(0.95, {job="nginx",log_type="access"} | json | unwrap request_time | __error__="" [5m]))
{job=~"application|nginx"} |~ "(?i)<пользователь-или-IP>"
```

Сквозная проверка доставки нового лога:

```bash
make logging-check VAULT_PASSWORD_FILE=.vault_pass
```

Promtail завершил жизненный цикл 2 марта 2026 года. Версия `3.6.11`
закреплена для учебного проекта; для новой промышленной инфраструктуры следует
планировать переход на Grafana Alloy.

## Grafana и уведомления

Механизм provisioning автоматически создаёт источники Prometheus и Loki, шесть
дашбордов, контактные точки, политику маршрутизации и правила алертов. Настроены
следующие сценарии:

- приложение или точка метрик недоступна;
- доля HTTP 5xx выше 5%;
- CPU выше 85% или RAM выше 90%;
- файловая система заполнена более чем на 85%;
- p95 задержки приложения выше 500 мс;
- метрики приложения или Node Exporter отсутствуют дольше трёх минут.

Правила содержат метки `service` и `severity`; задержка `for` защищает от
кратковременных всплесков. В Grafana они находятся в **Alerting → Alert
rules**, каналы — в **Alerting → Contact points**, маршрутизация — в
**Alerting → Notification policies**.

| Канал | Состояние | Конфигурация |
|---|---|---|
| Почта | активен, тестовая доставка подтверждена | Mail.ru, отправитель и получатель `vorobyev.93@mail.ru` |
| ntfy | contact point подготовлен | секретный `grafana_ntfy_webhook_url` в Vault |
| Telegram | не настроен | для добавления нужны bot token и chat ID в Vault |

Ручная проверка почтового уведомления:

```bash
make alert-test VAULT_PASSWORD_FILE=.vault_pass
# Подождать до 45 секунд и проверить папки «Входящие» и «Спам».
make alert-test-resolve VAULT_PASSWORD_FILE=.vault_pass
```

Тестовое правило по умолчанию выключено. Получение письма подтверждено 6
сентября 2026 года и зафиксировано на снимке ниже.

## Скриншоты

| Материал | Файл |
|---|---|
| Системные ресурсы | [grafana-system-resources.jpg](assets/grafana-system-resources.jpg) |
| Состояние приложения | [grafana-application-overview.jpg](assets/grafana-application-overview.jpg) |
| HTTP-коды и задержки | [grafana-http-performance.jpg](assets/grafana-http-performance.jpg) |
| Метрики Nginx | [grafana-nginx-overview.jpg](assets/grafana-nginx-overview.jpg) |
| Логи Loki | [grafana-centralized-logs.jpg](assets/grafana-centralized-logs.jpg) |
| Полученное тестовое письмо | [grafana-email-alert-firing.png](assets/grafana-email-alert-firing.png) |

## Команды эксплуатации

| Команда | Назначение |
|---|---|
| `make ansible-install` | установить внешние роли и коллекции |
| `make lint` | запустить `ansible-lint` |
| `make test` | выполнить lint и syntax-check всех плейбуков |
| `make ansible-run` | подготовить сервер приложения |
| `make monitoring-deploy` | развернуть Prometheus, Grafana и Loki |
| `make deploy IMAGE_TAG=...` | развернуть PostgreSQL и приложение |
| `make rollback IMAGE_TAG=...` | вернуться на предыдущий образ |
| `make logging-deploy` | синхронизировать Loki и Promtail |
| `make dashboards-update` | синхронизировать provisioning Grafana |
| `make smoke` | выполнить итоговую проверку окружения |
| `make alert-test` | включить тестовый алерт |
| `make alert-test-resolve` | выключить тестовый алерт |

Для команд, читающих Vault, передавайте
`VAULT_PASSWORD_FILE=.vault_pass` или отвечайте на интерактивный запрос
Ansible Vault.

## CI/CD и хранение данных

Сценарий GitHub Actions `CI инфраструктуры` устанавливает Ansible-зависимости
и выполняет `make test` при отправке изменений и запросе на слияние в `main`.
Сборка клиентской части, Gradle-тесты и
публикация Docker-образа выполняются в отдельном репозитории приложения. Образ
публикуется с тегами `latest` и `sha-<7-символов-коммита>`.

Данные PostgreSQL, Prometheus, Grafana, Loki и позиции Promtail находятся в
постоянных Docker-томах или каталогах сервера и сохраняются при пересоздании
контейнеров.
