# hc-mihomo

![build](https://github.com/hungcabinet/hc-mihomo/actions/workflows/run.yml/badge.svg)

CI that builds the latest [mihomo](https://github.com/MetaCubeX/mihomo) release for FreeBSD, with patches for TUN, process matching, and redirect.

The `plugin` branch adds an OPNsense plugin (`os-mihomo`) with a **Services → Mihomo** page. The main binary workflow is unchanged. A separate test workflow builds `os-mihomo` packages and publishes them as Actions artifacts. See [plugin/README.md](plugin/README.md).

CI собирает последний релиз [mihomo](https://github.com/MetaCubeX/mihomo) под FreeBSD с патчами: TUN, process match и redirect.

Ветка `plugin` добавляет плагин OPNsense (`os-mihomo`) со страницей **Services → Mihomo**. Основной workflow сборки бинаря не меняется. Отдельный тестовый workflow собирает пакеты `os-mihomo` и кладёт их в артефакты Actions. См. [plugin/README.md](plugin/README.md).
