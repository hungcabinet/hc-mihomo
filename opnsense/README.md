# Mihomo on OPNsense

[English](#mihomo-on-opnsense) · [Русский](#mihomo-на-opnsense)

A set of files so mihomo runs as a normal OPNsense service: start after the network is up, `start`/`stop` from the shell, syslog (web UI + system rotation), and cron-based restart if the process dies.

There is no service web UI. The config is YAML on disk. This repo does not install the binary — you have to place it yourself. Logs go to syslog and show up under `System` → `Log Files`.

## Prerequisites on the firewall

1. Binary:

   ```text
   /usr/local/bin/mihomo
   ```

   Make it executable: `chmod 0755 /usr/local/bin/mihomo`.

   Architecture must match OPNsense (`uname -m`: `amd64`, `arm64`, …). Prebuilt binaries are in this repo’s [Releases](https://github.com/hungcabinet/hc-mihomo/releases) (`clash-meta-freebsd-*`). Example for amd64:

   ```sh
   xz -dc clash-meta-freebsd-amd64.xz > /usr/local/bin/mihomo
   chmod 0755 /usr/local/bin/mihomo
   /usr/local/bin/mihomo -v
   ```

2. Working directory and config:

   ```text
   /usr/local/etc/mihomo/
   /usr/local/etc/mihomo/config.yaml
   ```

   Without `config.yaml` the service will not start. There is a sample at the repo root: `template.yaml`. Copy it like this:

   ```sh
   mkdir -p /usr/local/etc/mihomo
   cp template.yaml /usr/local/etc/mihomo/config.yaml
   ```

   The service runs the same command you used to start the process by hand:

   ```sh
   /usr/local/bin/mihomo -d /usr/local/etc/mihomo -f /usr/local/etc/mihomo/config.yaml
   ```

3. Unix line endings (LF) in shell scripts. Files in this folder already use LF. If you copy them from Windows by hand, do not save them as CRLF.

## File map: what goes where

The root of this folder (`opnsense/`) maps to the OPNsense filesystem root (`/`). Left path is in git, right path is on the firewall.

| File in the repo | Destination on OPNsense | Mode | Purpose |
|---|---|---|---|
| `etc/rc.conf.d/mihomo` | `/etc/rc.conf.d/mihomo` | `0644` | Enables the service (`mihomo_enable="YES"`). Without it, `service mihomo start` will refuse to start. |
| `usr/local/etc/rc.d/mihomo` | `/usr/local/etc/rc.d/mihomo` | `0755` | The rc script: start/stop/restart/status/health. Child stdout/stderr go to syslog (`daemon -S -T mihomo`). |
| `usr/local/etc/rc.syshook.d/start/90-mihomo` | `/usr/local/etc/rc.syshook.d/start/90-mihomo` | `0755` | Starts after the network is up (late OPNsense boot hook). |
| `usr/local/etc/inc/plugins.inc.d/mihomo.inc` | `/usr/local/etc/inc/plugins.inc.d/mihomo.inc` | `0644` | OPNsense registration: `pluginctl`, remote-syslog app name, restart on WAN IP change. |
| `usr/local/opnsense/scripts/mihomo/health.sh` | `/usr/local/opnsense/scripts/mihomo/health.sh` | `0755` | Health-check script (`lockf` so two cron jobs cannot start the service at once). |
| `usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf` | `/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf` | `0644` | configd actions. The **Mihomo health check** command appears under `System` → `Settings` → `Cron`. |
| `usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf` | `/usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf` | `0644` | syslog-ng filter: program `mihomo` → `/var/log/mihomo/`. Rotation follows `System` → `Settings` → `Logging`. |

These files are **not** copied from this folder — they must exist separately:

| Path on OPNsense | What it is |
|---|---|
| `/usr/local/bin/mihomo` | binary |
| `/usr/local/etc/mihomo/config.yaml` | config |
| `/var/log/mihomo/` | syslog-ng destination (created on install / first message) |

Directories to create if they are missing:

```text
/etc/rc.conf.d
/usr/local/etc/rc.d
/usr/local/etc/rc.syshook.d/start
/usr/local/etc/inc/plugins.inc.d
/usr/local/opnsense/scripts/mihomo
/usr/local/opnsense/service/conf/actions.d
/usr/local/opnsense/service/templates/OPNsense/Syslog/local
/usr/local/etc/mihomo
```

## Method 1. Script (preferred)

Put the `opnsense` folder **on the OPNsense box** — `/tmp` is fine — and run the script **from that folder**. It copies files to the system paths.

Do not copy the contents of `opnsense/` onto `/`. The script takes files next to itself and writes them to `/etc/rc.conf.d/mihomo`, `/usr/local/etc/rc.d/mihomo`, and the other paths in the table above.

```sh
# on the firewall, from the opnsense directory
cd /tmp/opnsense
sh ./install.sh
```

It copies the service files, sets permissions, creates `/usr/local/etc/mihomo`, and restarts `configd` plus syslog so the mihomo log target appears. It does **not** add the health check to crontab — you add that in the web UI (see below). On upgrade it also removes a leftover `/usr/local/etc/newsyslog.conf.d/mihomo.conf`.

The script does **not** install the binary or `config.yaml`. They must already be at:

- `/usr/local/bin/mihomo`
- `/usr/local/etc/mihomo/config.yaml`

Then:

```sh
service mihomo start
```

You can delete the folder from `/tmp` after install.

Remove the service (does not touch config or binary):

```sh
sh ./install.sh uninstall
```

## Method 2. Manual

All commands run **on OPNsense** as root. `SRC` is the path to this `opnsense/` folder on the firewall.

```sh
SRC=/path/to/hc-mihomo/opnsense

mkdir -p \
  /etc/rc.conf.d \
  /usr/local/etc/rc.d \
  /usr/local/etc/rc.syshook.d/start \
  /usr/local/etc/inc/plugins.inc.d \
  /usr/local/opnsense/scripts/mihomo \
  /usr/local/opnsense/service/conf/actions.d \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local \
  /usr/local/etc/mihomo \
  /var/log/mihomo

cp "${SRC}/etc/rc.conf.d/mihomo" \
  /etc/rc.conf.d/mihomo
cp "${SRC}/usr/local/etc/rc.d/mihomo" \
  /usr/local/etc/rc.d/mihomo
cp "${SRC}/usr/local/etc/rc.syshook.d/start/90-mihomo" \
  /usr/local/etc/rc.syshook.d/start/90-mihomo
cp "${SRC}/usr/local/etc/inc/plugins.inc.d/mihomo.inc" \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc
cp "${SRC}/usr/local/opnsense/scripts/mihomo/health.sh" \
  /usr/local/opnsense/scripts/mihomo/health.sh
cp "${SRC}/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf" \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf
cp "${SRC}/usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf" \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf

rm -f /usr/local/etc/cron.d/mihomo
rm -f /usr/local/etc/newsyslog.conf.d/mihomo.conf

chmod 0644 \
  /etc/rc.conf.d/mihomo \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf

chmod 0755 \
  /usr/local/etc/rc.d/mihomo \
  /usr/local/etc/rc.syshook.d/start/90-mihomo \
  /usr/local/opnsense/scripts/mihomo/health.sh

service configd restart
pluginctl -s syslog restart
```

After that, the **Mihomo health check** command appears in the GUI, and syslog-ng starts writing program `mihomo` to `/var/log/mihomo/`. You still have to add the cron job yourself — see the section below.

## After copy: first start

```sh
# is the config valid?
/usr/local/bin/mihomo -t -d /usr/local/etc/mihomo -f /usr/local/etc/mihomo/config.yaml

service mihomo start
service mihomo status
```

Expected status: `mihomo is running: daemon pid …, mihomo pid …`.

Log (GUI: `System` → `Log Files` → **mihomo**):

```sh
ls /var/log/mihomo
tail -F /var/log/mihomo/mihomo_$(date +%Y%m%d).log
```

Then:

```sh
service mihomo stop
service mihomo restart
service mihomo health

pluginctl -s mihomo start
pluginctl -s mihomo stop
pluginctl -s mihomo restart

configctl mihomo status
```

## How it behaves after install

**Start on boot.** `/etc/rc.conf.d/mihomo` enables the service. The `90-mihomo` hook in `rc.syshook.d/start/` runs `service mihomo start` after the network is up. If WAN changes IP, the plugin restarts the service (unless you stopped it by hand).

**Manual stop.** `service mihomo stop` kills the process and creates `/var/run/mihomo.stopped`. The health check sees that file and will **not** start the service again. After a reboot `/var/run` is empty — the service starts on its own (enable stays YES). To keep it from starting after reboot:

```sh
sysrc -f /etc/rc.conf.d/mihomo mihomo_enable=NO
service mihomo stop
```

Re-enable:

```sh
sysrc -f /etc/rc.conf.d/mihomo mihomo_enable=YES
service mihomo start
```

**Process crash.** The health check is not scheduled automatically. Add it in OPNsense’s standard cron (stored in `config.xml`, survives restarts):

1. `System` → `Settings` → `Cron` → **Add**.
2. **Command:** `Mihomo health check` (this is `configctl mihomo health`; the item exists only after you copy `actions_mihomo.conf` and run `service configd restart`).
3. Schedule, e.g. every minute: Minutes `*`, Hours `*`, Days of month `*`, Months `*`, Days of week `*`.
4. Description optional, e.g. `mihomo health`.
5. Save / Apply.

If enable=YES, `/var/run/mihomo.stopped` is absent, and the process is gone — the service starts, and syslog gets `mihomo: health check failed; starting service`. After `service mihomo stop`, the cron job will not bring it back.

One-shot, without waiting for cron:

```sh
service mihomo health
configctl mihomo health
```

### Remove the old file-based cron

Earlier installs used `/usr/local/etc/cron.d/mihomo` and autocron in `/var/cron/tabs/root`. Those are not from the web UI and disappear or duplicate when OPNsense rebuilds crontab. Remove them:

```sh
rm -f /usr/local/etc/cron.d/mihomo
pluginctl -c cron
configctl cron restart
grep mihomo /var/cron/tabs/root /usr/local/etc/cron.d/mihomo
```

`install.sh` also deletes `/usr/local/etc/cron.d/mihomo` on a re-run. It does not touch the GUI cron job.

**Logs.** Process output goes to syslog with tag `mihomo`, not to `/var/log/mihomo.log`. View in `System` → `Log Files` → **mihomo** (`/ui/diagnostics/log/core/mihomo`). Files live under `/var/log/mihomo/` (`mihomo_YYYYMMDD.log`). Size, keep days, and compression are the same as every other OPNsense log: `System` → `Settings` → `Logging`. After a manual install run `pluginctl -s syslog restart` so syslog-ng picks up the filter. An old `/var/log/mihomo.log` from earlier installs can be deleted.

**TUN.** On start/stop the rc script reads `tun.device` from `config.yaml` and tears down a leftover interface. In `template.yaml` that is `utun0`.

**Options** in `/etc/rc.conf.d/mihomo` (commented out by default):

```sh
mihomo_enable="YES"
# mihomo_dir="/usr/local/etc/mihomo"
# mihomo_config="/usr/local/etc/mihomo/config.yaml"
# mihomo_flags=""
```

## Check that everything is in place

```sh
ls -l \
  /usr/local/bin/mihomo \
  /usr/local/etc/mihomo/config.yaml \
  /etc/rc.conf.d/mihomo \
  /usr/local/etc/rc.d/mihomo \
  /usr/local/etc/rc.syshook.d/start/90-mihomo \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc \
  /usr/local/opnsense/scripts/mihomo/health.sh \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf

pluginctl -s | grep mihomo
ls /usr/local/etc/cron.d/mihomo 2>/dev/null || echo "no file cron (ok)"
ls /usr/local/etc/newsyslog.conf.d/mihomo.conf 2>/dev/null || echo "no file newsyslog (ok)"
ls /var/log/mihomo
```

## Uninstall

```sh
sh ./install.sh uninstall
```

or delete the same paths by hand and restart `configd` plus syslog (`pluginctl -s syslog restart`). Not removed: `/usr/local/bin/mihomo`, `/usr/local/etc/mihomo/`, `/var/log/mihomo/`. Remove the **Mihomo health check** job under `System` → `Settings` → `Cron` separately if you added it.

## If it will not start

| Symptom | What to check |
|---|---|
| `mihomo_enable is not set to YES` | `/etc/rc.conf.d/mihomo` |
| `required file not found` | missing binary or missing `config.yaml` |
| `configuration validation failed` | `mihomo -t …`, plus `System` → `Log Files` → **mihomo** |
| no mihomo page in Log Files | template `…/Syslog/local/mihomo.conf` is in place; `pluginctl -s syslog restart` |
| `already running` | `pgrep -lf mihomo`, then `service mihomo stop` if needed |
| hook does not start after reboot | `ls -l /usr/local/etc/rc.syshook.d/start/90-mihomo` — must be `0755` |
| cron does not restart after a crash | **Mihomo health check** job in `System` → `Settings` → `Cron`; `service mihomo health`; no `/var/run/mihomo.stopped` |
| `configctl mihomo …` unknown | `service configd restart` after copying `actions_mihomo.conf` |
| CRLF in scripts | `file /usr/local/etc/rc.d/mihomo` — must not say `CRLF` / `with CRLF line terminators` |

---

# Mihomo на OPNsense

[English](#mihomo-on-opnsense) · [Русский](#mihomo-на-opnsense)

Набор файлов, чтобы mihomo работал как обычный сервис OPNsense: старт после сети, `start`/`stop` из shell, syslog (веб-интерфейс и системная ротация) и автоподъём через cron, если процесс упал.

Веб-интерфейса сервиса нет. Конфиг — YAML на диске. Бинарь этот репозиторий не ставит: его нужно положить отдельно. Логи идут в syslog и смотрятся в `System` → `Log Files`.

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
| `usr/local/etc/rc.d/mihomo` | `/usr/local/etc/rc.d/mihomo` | `0755` | Сам rc-скрипт: start/stop/restart/status/health. stdout/stderr процесса идут в syslog (`daemon -S -T mihomo`). |
| `usr/local/etc/rc.syshook.d/start/90-mihomo` | `/usr/local/etc/rc.syshook.d/start/90-mihomo` | `0755` | Старт после поднятия сети (поздний boot-хук OPNsense). |
| `usr/local/etc/inc/plugins.inc.d/mihomo.inc` | `/usr/local/etc/inc/plugins.inc.d/mihomo.inc` | `0644` | Регистрация в OPNsense: `pluginctl`, имя приложения для удалённого syslog, рестарт при смене WAN IP. |
| `usr/local/opnsense/scripts/mihomo/health.sh` | `/usr/local/opnsense/scripts/mihomo/health.sh` | `0755` | Скрипт health check (с `lockf`, чтобы два крона не стартовали сервис одновременно). |
| `usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf` | `/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf` | `0644` | Действия configd. Команда **Mihomo health check** появляется в `System` → `Settings` → `Cron`. |
| `usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf` | `/usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf` | `0644` | Фильтр syslog-ng: программа `mihomo` → `/var/log/mihomo/`. Ротация как у всех логов: `System` → `Settings` → `Logging`. |

Эти файлы **не** копируются из этой папки — они должны существовать отдельно:

| Путь на OPNsense | Что это |
|---|---|
| `/usr/local/bin/mihomo` | бинарь |
| `/usr/local/etc/mihomo/config.yaml` | конфиг |
| `/var/log/mihomo/` | каталог syslog-ng (создаётся при установке / первом сообщении) |

Каталоги, которые нужно создать, если их нет:

```text
/etc/rc.conf.d
/usr/local/etc/rc.d
/usr/local/etc/rc.syshook.d/start
/usr/local/etc/inc/plugins.inc.d
/usr/local/opnsense/scripts/mihomo
/usr/local/opnsense/service/conf/actions.d
/usr/local/opnsense/service/templates/OPNsense/Syslog/local
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

Он копирует служебные файлы, выставляет права, создаёт `/usr/local/etc/mihomo`, перезапускает `configd` и syslog, чтобы появился лог mihomo. Health check в crontab сам не прописывает — его добавляют в веб-интерфейсе (см. ниже). При повторной установке ещё удаляет старый `/usr/local/etc/newsyslog.conf.d/mihomo.conf`.

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
  /usr/local/etc/inc/plugins.inc.d \
  /usr/local/opnsense/scripts/mihomo \
  /usr/local/opnsense/service/conf/actions.d \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local \
  /usr/local/etc/mihomo \
  /var/log/mihomo

cp "${SRC}/etc/rc.conf.d/mihomo" \
  /etc/rc.conf.d/mihomo
cp "${SRC}/usr/local/etc/rc.d/mihomo" \
  /usr/local/etc/rc.d/mihomo
cp "${SRC}/usr/local/etc/rc.syshook.d/start/90-mihomo" \
  /usr/local/etc/rc.syshook.d/start/90-mihomo
cp "${SRC}/usr/local/etc/inc/plugins.inc.d/mihomo.inc" \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc
cp "${SRC}/usr/local/opnsense/scripts/mihomo/health.sh" \
  /usr/local/opnsense/scripts/mihomo/health.sh
cp "${SRC}/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf" \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf
cp "${SRC}/usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf" \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf

rm -f /usr/local/etc/cron.d/mihomo
rm -f /usr/local/etc/newsyslog.conf.d/mihomo.conf

chmod 0644 \
  /etc/rc.conf.d/mihomo \
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf

chmod 0755 \
  /usr/local/etc/rc.d/mihomo \
  /usr/local/etc/rc.syshook.d/start/90-mihomo \
  /usr/local/opnsense/scripts/mihomo/health.sh

service configd restart
pluginctl -s syslog restart
```

После этого в GUI появится команда **Mihomo health check**, а syslog-ng начнёт писать программу `mihomo` в `/var/log/mihomo/`. Саму задачу cron нужно добавить вручную — см. раздел ниже.

## После копирования: первый запуск

```sh
# конфиг валиден?
/usr/local/bin/mihomo -t -d /usr/local/etc/mihomo -f /usr/local/etc/mihomo/config.yaml

service mihomo start
service mihomo status
```

Ожидаемый status: `mihomo is running: daemon pid …, mihomo pid …`.

Лог (GUI: `System` → `Log Files` → **mihomo**):

```sh
ls /var/log/mihomo
tail -F /var/log/mihomo/mihomo_$(date +%Y%m%d).log
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

**Логи.** Вывод процесса идёт в syslog с тегом `mihomo`, не в `/var/log/mihomo.log`. Смотреть: `System` → `Log Files` → **mihomo** (`/ui/diagnostics/log/core/mihomo`). Файлы лежат в `/var/log/mihomo/` (`mihomo_YYYYMMDD.log`). Размер, срок хранения и сжатие — как у остальных логов OPNsense: `System` → `Settings` → `Logging`. После ручной установки нужен `pluginctl -s syslog restart`, чтобы syslog-ng подхватил фильтр. Старый `/var/log/mihomo.log` от прошлых установок можно удалить.

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
  /usr/local/etc/inc/plugins.inc.d/mihomo.inc \
  /usr/local/opnsense/scripts/mihomo/health.sh \
  /usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf \
  /usr/local/opnsense/service/templates/OPNsense/Syslog/local/mihomo.conf

pluginctl -s | grep mihomo
ls /usr/local/etc/cron.d/mihomo 2>/dev/null || echo "no file cron (ok)"
ls /usr/local/etc/newsyslog.conf.d/mihomo.conf 2>/dev/null || echo "no file newsyslog (ok)"
ls /var/log/mihomo
```

## Снятие

```sh
sh ./install.sh uninstall
```

или удалить те же пути вручную и перезапустить `configd` и syslog (`pluginctl -s syslog restart`). Не удаляются: `/usr/local/bin/mihomo`, `/usr/local/etc/mihomo/`, `/var/log/mihomo/`. Задачу **Mihomo health check** в `System` → `Settings` → `Cron` сними отдельно, если добавлял.

## Если не стартует

| Симптом | Что смотреть |
|---|---|
| `mihomo_enable is not set to YES` | `/etc/rc.conf.d/mihomo` |
| `required file not found` | нет бинаря или нет `config.yaml` |
| `configuration validation failed` | `mihomo -t …`, плюс `System` → `Log Files` → **mihomo** |
| в Log Files нет страницы mihomo | на месте шаблон `…/Syslog/local/mihomo.conf`; `pluginctl -s syslog restart` |
| `already running` | `pgrep -lf mihomo`, при необходимости `service mihomo stop` |
| хук не стартует после ребута | `ls -l /usr/local/etc/rc.syshook.d/start/90-mihomo` — должен быть `0755` |
| cron не поднимает после падения | задача **Mihomo health check** в `System` → `Settings` → `Cron`; `service mihomo health`; нет ли `/var/run/mihomo.stopped` |
| `configctl mihomo …` unknown | `service configd restart` после копирования `actions_mihomo.conf` |
| CRLF в скриптах | `file /usr/local/etc/rc.d/mihomo` — не должно быть `CRLF` / `with CRLF line terminators` |
