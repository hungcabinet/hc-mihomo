# Mihomo plugin for OPNsense

[English](#mihomo-plugin-for-opnsense) · [Русский](#плагин-mihomo-для-opnsense)

OPNsense plugin that runs [mihomo](https://github.com/MetaCubeX/mihomo) as a normal service and adds **Services → Mihomo** in the web UI: status, start/stop/restart, log tail, and a YAML editor with download/upload.

This lives on the `plugin` branch. The main `Build` workflow is not used here. Packages come from the **Plugin package** workflow.

## Install from a test build

1. Open the **Plugin package** workflow in GitHub Actions (`plugin-pkg.yml`). It runs on every push to `plugin`.
2. Open the finished run. The summary has a link of the form `https://github.com/<repo>/actions/runs/<id>`.
3. Download the `os-mihomo` artifact. Inside are:
   - `os-mihomo-<version>.amd64.pkg`
   - `os-mihomo-<version>.aarch64.pkg`
4. Copy the file that matches the firewall (`uname -m`: `amd64` or `arm64`) onto OPNsense and install:

```sh
pkg add os-mihomo-<version>.amd64.pkg
```

5. Reload the OPNsense GUI and open **Services → Mihomo**.
6. Edit or upload `config.yaml`, then click **Start**.

The package ships `/usr/local/bin/mihomo` for that architecture. It is not listed under System → Firmware → Plugins.

Optional: **System → Settings → Cron → Add**, command **Mihomo health check**, every minute. That restarts the process after a crash when the service is enabled.

## What the page does

- **Status** — running/stopped/disabled, rc output, `mihomo -v`. Start and Stop also write `mihomo_enable` so the choice survives a reboot. `service mihomo stop` from the shell still only lasts until the next boot.
- **Log** — last 200 lines from `/var/log/mihomo/`. Full history is **System → Log Files → mihomo**.
- **config.yaml** — text editor, save, download, upload (8 MiB). Save and upload write a temp file, run `mihomo -t`, and replace `/usr/local/etc/mihomo/config.yaml` only when validation succeeds. If the service is running, it is restarted.

The YAML is not stored in `config.xml`. The model only keeps the enable flag.

## Files the package does not remove

Uninstall (`pkg delete os-mihomo` or `sh ./install.sh uninstall`) leaves:

- `/usr/local/etc/mihomo/` including `config.yaml`
- `/var/log/mihomo/`
- `/usr/local/bin/mihomo` is removed by `pkg delete` (it is part of the package). `install.sh uninstall` does not touch the binary.

## install.sh

From this directory on the firewall, `sh ./install.sh` copies the plugin tree without the binary. Use it to iterate on PHP/Volt. Supported install is still `pkg add`.

```sh
sh ./install.sh
sh ./install.sh uninstall
```

## After upgrade from the old script layout

If `/etc/rc.conf.d/mihomo` already has `mihomo_enable="YES"` and the model node does not exist yet, post-install copies that into the model so the service stays enabled.

---

# Плагин Mihomo для OPNsense

[English](#mihomo-plugin-for-opnsense) · [Русский](#плагин-mihomo-для-opnsense)

Плагин OPNsense: mihomo как обычный сервис и страница **Services → Mihomo** — статус, start/stop/restart, хвост лога, редактор YAML, скачивание и загрузка конфига.

Код в ветке `plugin`. Основной workflow `Build` здесь не используется. Пакеты собирает workflow **Plugin package**.

## Установка из тестовой сборки

1. Открыть workflow **Plugin package** в GitHub Actions (`plugin-pkg.yml`). Он запускается на каждый push в `plugin`.
2. Открыть завершённый прогон. В summary есть ссылка вида `https://github.com/<repo>/actions/runs/<id>`.
3. Скачать артефакт `os-mihomo`. Внутри:
   - `os-mihomo-<version>.amd64.pkg`
   - `os-mihomo-<version>.aarch64.pkg`
4. Файл под архитектуру файрвола (`uname -m`: `amd64` или `arm64`) положить на OPNsense и установить:

```sh
pkg add os-mihomo-<version>.amd64.pkg
```

5. Обновить GUI и открыть **Services → Mihomo**.
6. Править или загрузить `config.yaml`, затем **Start**.

В пакете уже есть `/usr/local/bin/mihomo` для этой архитектуры. В System → Firmware → Plugins его не будет.

По желанию: **System → Settings → Cron → Add**, команда **Mihomo health check**, каждую минуту. После падения процесса сервис поднимется, если он включён.

## Что делает страница

- **Status** — running/stopped/disabled, вывод rc, `mihomo -v`. Start и Stop пишут `mihomo_enable`, выбор переживает перезагрузку. `service mihomo stop` из shell действует только до следующей загрузки.
- **Log** — последние 200 строк из `/var/log/mihomo/`. Полный лог: **System → Log Files → mihomo**.
- **config.yaml** — текстовое поле, сохранить, скачать, загрузить (8 МиБ). Save и upload пишут временный файл, гоняют `mihomo -t` и меняют `/usr/local/etc/mihomo/config.yaml` только после успешной проверки. Если сервис запущен, он перезапускается.

YAML в `config.xml` не кладётся. В модели только флаг включения.

## Что пакет не удаляет

Снятие (`pkg delete os-mihomo` или `sh ./install.sh uninstall`) оставляет:

- `/usr/local/etc/mihomo/`, включая `config.yaml`
- `/var/log/mihomo/`
- `/usr/local/bin/mihomo` удаляет `pkg delete` (бинарь внутри пакета). `install.sh uninstall` бинарь не трогает.

## install.sh

Из этого каталога на файрволе `sh ./install.sh` копирует дерево плагина без бинаря. Удобно для правок PHP/Volt. Нормальная установка — `pkg add`.

```sh
sh ./install.sh
sh ./install.sh uninstall
```

## После обновления со старого install.sh

Если в `/etc/rc.conf.d/mihomo` уже `mihomo_enable="YES"`, а узла модели ещё нет, post-install переносит это в модель, чтобы сервис остался включённым.
