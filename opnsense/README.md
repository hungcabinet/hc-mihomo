# Mihomo на OPNsense

Набор файлов, чтобы mihomo работал как обычный сервис OPNsense: старт после сети, `start`/`stop` из shell, логи и автоподъём через cron, если процесс упал.

Веб-интерфейса нет. Конфиг — YAML на диске. Бинарь этот репозиторий не ставит: его нужно положить отдельно.

## Что должно уже быть на файрволе

1. Бинарь:

   ```text
   /usr/local/bin/mihomo
   ```

   Сделать исполняемым: `chmod 0755 /usr/local/bin/mihomo`.

   Архитектура должна совпадать с OPNsense (`uname -m`: `amd64`, `arm64`, …). Готовые сборки — в [Releases](https://github.com/hungcabinet/hc-mihomo/releases) этого репозитория (файлы `clash-meta-freebsd-*`). Пример для amd64:

   ```sh
   xz -dc clash-meta-freebsd-amd64.xz > /usr/local/bin/mihomo
   chmod 0755 /usr/local/bin/mihomo
   /usr/local/bin/mihomo -v
   ```

2. Рабочий каталог и конфиг:

   ```text
   /usr/local/etc/mihomo/
   /usr/local/etc/mihomo/config.yaml
   ```

   Без `config.yaml` сервис не стартует. Пример есть в корне репозитория: `template.yaml`. Скопировать можно так:

   ```sh
   mkdir -p /usr/local/etc/mihomo
   cp template.yaml /usr/local/etc/mihomo/config.yaml
   ```

   Сервис запускает ровно ту команду, которой ты поднимал процесс вручную:

   ```sh
   /usr/local/bin/mihomo -d /usr/local/etc/mihomo -f /usr/local/etc/mihomo/config.yaml
   ```

3. Unix-переводы строк (LF) у shell-скриптов. Файлы из этой папки уже с LF. Если копируешь с Windows вручную, не сохраняй их как CRLF.

## Карта: что куда копировать

Корень этой папки (`opnsense/`) соответствует корню файловой системы OPNsense (`/`). Путь слева — в git, путь справа — на файрволе.

| Файл в репозитории | Куда на OPNsense | Режим | Зачем |
|---|---|---|---|
| `etc/rc.conf.d/mihomo` | `/etc/rc.conf.d/mihomo` | `0644` | Включает сервис (`mihomo_enable="YES"`). Без него `service mihomo start` откажется стартовать. |
| `usr/local/etc/rc.d/mihomo` | `/usr/local/etc/rc.d/mihomo` | `0755` | Сам rc-скрипт: start/stop/restart/status/health. |
| `usr/local/etc/rc.syshook.d/start/90-mihomo` | `/usr/local/etc/rc.syshook.d/start/90-mihomo` | `0755` | Старт после поднятия сети (поздний boot-хук OPNsense). |
| `usr/local/etc/newsyslog.conf.d/mihomo.conf` | `/usr/local/etc/newsyslog.conf.d/mihomo.conf` | `0644` | Ротация `/var/log/mihomo.log` (5 копий, порог 1 МБ, bzip2). |
| `usr/local/etc/inc/plugins.inc.d/mihomo.inc` | `/usr/local/etc/inc/plugins.inc.d/mihomo.inc` | `0644` | Регистрация в OPNsense: `pluginctl`, syslog, рестарт при смене WAN IP. |
| `usr/local/opnsense/scripts/mihomo/health.sh` | `/usr/local/opnsense/scripts/mihomo/health.sh` | `0755` | Скрипт health check (с `lockf`, чтобы два крона не стартовали сервис одновременно). |
| `usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf` | `/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf` | `0644` | Действия configd. Команда **Mihomo health check** появляется в `System` → `Settings` → `Cron`. |

Эти файлы **не** копируются из этой папки — они должны существовать отдельно:

| Путь на OPNsense | Что это |
|---|---|
| `/usr/local/bin/mihomo` | бинарь |
| `/usr/local/etc/mihomo/config.yaml` | конфиг |
| `/var/log/mihomo.log` | лог (создастся сам при старте или `install.sh`) |

Каталоги, которые нужно создать, если их нет:

```text
/etc/rc.conf.d
/usr/local/etc/rc.d
/usr/local/etc/rc.syshook.d/start
/usr/local/etc/newsyslog.conf.d
/usr/local/etc/inc/plugins.inc.d
/usr/local/opnsense/scripts/mihomo
/usr/local/opnsense/service/conf/actions.d
/usr/local/etc/mihomo
```

## Способ 1. Скрипт (предпочтительно)

Папку `opnsense` нужно оказаться **на самом OPNsense** — `/tmp` нормально — и запустить скрипт **из неё**. Он сам разложит файлы по системным путям.

Не копируй содержимое `opnsense/` в корень `/`. Скрипт берёт файлы рядом с собой и пишет их в `/etc/rc.conf.d/mihomo`, `/usr/local/etc/rc.d/mihomo` и остальные пути из таблицы выше.

```sh
# на файрволе, из каталога opnsense
cd /tmp/opnsense
sh ./install.sh
```

Он копирует служебные файлы, выставляет права, создаёт `/usr/local/etc/mihomo` и `/var/log/mihomo.log`, перезапускает `configd`. Health check в crontab сам не прописывает — его добавляют в веб-интерфейсе (см. ниже).

Бинарь и `config.yaml` скрипт **не** ставит. Они должны уже лежать:

- `/usr/local/bin/mihomo`
- `/usr/local/etc/mihomo/config.yaml`

Потом:

```sh
service mihomo start
```

Папку из `/tmp` после установки можно удалить.

Снять сервис (конфиг и бинарь не трогает):

```sh
sh ./install.sh uninstall
```

## Способ 2. Вручную

Все команды — **на OPNsense**, от root. `SRC` — путь к этой папке `opnsense/` на файрволе.

```sh
SRC=/path/to/hc-mihomo/opnsense

mkdir -p \
  /etc/rc.conf.d \
  /usr/local/etc/rc.d \
  /usr/local/etc/rc.syshook.d/start \
  /usr/local/etc/newsyslog.conf.d \
  /usr/local/etc/inc/plugins.inc.d \
  /usr/local/opnsense/scripts/mihomo \
  /usr/local/opnsense/service/conf/actions.d \
  /usr/local/etc/mihomo

cp "${SRC}/etc/rc.conf.d/mihomo" \
  /etc/rc.conf.d/mihomo
cp "${SRC}/usr/local/etc/rc.d/mihomo" \
  /usr/local/etc/rc.d/mihomo
cp "${SRC}/usr/local/etc/rc.syshook.d/start/90-mihomo" \
  /usr/local/etc/rc.syshook.d/start/90-mihomo
cp "${SRC}/usr/local/etc/newsyslog.conf.d/mihomo.conf" \
  /usr/local/etc/newsyslog.conf.d/mihomo.conf
cp "${SRC}/usr/local/etc/inc/plugins.inc.d/mihomo.inc" \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc
cp "${SRC}/usr/local/opnsense/scripts/mihomo/health.sh" \
  /usr/local/opnsense/scripts/mihomo/health.sh
cp "${SRC}/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf" \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf

rm -f /usr/local/etc/cron.d/mihomo

chmod 0644 \
  /etc/rc.conf.d/mihomo \
  /usr/local/etc/newsyslog.conf.d/mihomo.conf \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf

chmod 0755 \
  /usr/local/etc/rc.d/mihomo \
  /usr/local/etc/rc.syshook.d/start/90-mihomo \
  /usr/local/opnsense/scripts/mihomo/health.sh

touch /var/log/mihomo.log
chmod 0640 /var/log/mihomo.log

service configd restart
```

После этого в GUI появится команда **Mihomo health check**. Саму задачу cron нужно добавить вручную — см. раздел ниже.

## После копирования: первый запуск

```sh
# конфиг валиден?
/usr/local/bin/mihomo -t -d /usr/local/etc/mihomo -f /usr/local/etc/mihomo/config.yaml

service mihomo start
service mihomo status
```

Ожидаемый status: `mihomo is running: daemon pid …, mihomo pid …`.

Лог:

```sh
tail -f /var/log/mihomo.log
```

Дальше:

```sh
service mihomo stop
service mihomo restart
service mihomo health

pluginctl -s mihomo start
pluginctl -s mihomo stop
pluginctl -s mihomo restart

configctl mihomo status
```

## Как это живёт после установки

**Старт при загрузке.** `/etc/rc.conf.d/mihomo` включает сервис. Хук `90-mihomo` в `rc.syshook.d/start/` вызывает `service mihomo start` уже после сети. Если WAN сменил IP, plugin рестартует сервис (если ты его не останавливал вручную).

**Стоп руками.** `service mihomo stop` гасит процесс и ставит `/var/run/mihomo.stopped`. Health check этот файл видит и **не** поднимает сервис обратно. После ребута `/var/run` чистый — сервис снова стартует сам (enable остаётся YES). Чтобы не стартовал и после ребута:

```sh
sysrc -f /etc/rc.conf.d/mihomo mihomo_enable=NO
service mihomo stop
```

Вернуть:

```sh
sysrc -f /etc/rc.conf.d/mihomo mihomo_enable=YES
service mihomo start
```

**Падение процесса.** Health check сам по расписанию не ставится. Его добавляют в стандартный cron OPNsense (хранится в `config.xml`, переживает рестарт):

1. `System` → `Settings` → `Cron` → **Add**.
2. **Command:** `Mihomo health check` (это `configctl mihomo health`; пункт есть только после копирования `actions_mihomo.conf` и `service configd restart`).
3. Расписание, например каждую минуту: Minutes `*`, Hours `*`, Days of month `*`, Months `*`, Days of week `*`.
4. Description по желанию, например `mihomo health`.
5. Save / Apply.

Если enable=YES, флага `/var/run/mihomo.stopped` нет и процесса нет — сервис стартует, в syslog будет `mihomo: health check failed; starting service`. После `service mihomo stop` задача cron сервис не поднимает.

Разово без ожидания cron:

```sh
service mihomo health
configctl mihomo health
```

### Вычистить старый файловый cron

Раньше ставились `/usr/local/etc/cron.d/mihomo` и autocron в `/var/cron/tabs/root`. Они не из веб-интерфейса и при пересборке crontab OPNsense пропадают или дублируются. Убрать:

```sh
rm -f /usr/local/etc/cron.d/mihomo
pluginctl -c cron
configctl cron restart
grep mihomo /var/cron/tabs/root /usr/local/etc/cron.d/mihomo
```

`install.sh` при повторном запуске тоже удаляет `/usr/local/etc/cron.d/mihomo`. Задачу из GUI это не трогает.

**TUN.** При старте/стопе rc-скрипт читает `tun.device` из `config.yaml` и сносит зависший интерфейс. В `template.yaml` это `utun0`.

**Опции** в `/etc/rc.conf.d/mihomo` (по умолчанию закомментированы):

```sh
mihomo_enable="YES"
# mihomo_dir="/usr/local/etc/mihomo"
# mihomo_config="/usr/local/etc/mihomo/config.yaml"
# mihomo_flags=""
```

## Проверка, что всё на месте

```sh
ls -l \
  /usr/local/bin/mihomo \
  /usr/local/etc/mihomo/config.yaml \
  /etc/rc.conf.d/mihomo \
  /usr/local/etc/rc.d/mihomo \
  /usr/local/etc/rc.syshook.d/start/90-mihomo \
  /usr/local/etc/newsyslog.conf.d/mihomo.conf \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc \
  /usr/local/opnsense/scripts/mihomo/health.sh \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf

pluginctl -s | grep mihomo
ls /usr/local/etc/cron.d/mihomo 2>/dev/null || echo "no file cron (ok)"
```

## Снятие

```sh
sh ./install.sh uninstall
```

или удалить те же пути вручную и перезапустить `configd`. Не удаляются: `/usr/local/bin/mihomo`, `/usr/local/etc/mihomo/`, `/var/log/mihomo.log`. Задачу **Mihomo health check** в `System` → `Settings` → `Cron` сними отдельно, если добавлял.

## Если не стартует

| Симптом | Что смотреть |
|---|---|
| `mihomo_enable is not set to YES` | `/etc/rc.conf.d/mihomo` |
| `required file not found` | нет бинаря или нет `config.yaml` |
| `configuration validation failed` | `mihomo -t …`, плюс хвост `/var/log/mihomo.log` |
| `already running` | `pgrep -lf mihomo`, при необходимости `service mihomo stop` |
| хук не стартует после ребута | `ls -l /usr/local/etc/rc.syshook.d/start/90-mihomo` — должен быть `0755` |
| cron не поднимает после падения | задача **Mihomo health check** в `System` → `Settings` → `Cron`; `service mihomo health`; нет ли `/var/run/mihomo.stopped` |
| `configctl mihomo …` unknown | `service configd restart` после копирования `actions_mihomo.conf` |
| CRLF в скриптах | `file /usr/local/etc/rc.d/mihomo` — не должно быть `CRLF` / `with CRLF line terminators` |
