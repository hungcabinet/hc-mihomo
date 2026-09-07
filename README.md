**This repo may not be maintained anymore. The tool is enough to speed up some websites, e.g., OpenAI**

精力有限，可能不再维护，目前足以加速某些网站，比如 OpenAI

**Currently, only release versions are supported**

目前，仅更新 release 版

---

# clash-meta for FreeBSD

![build workflow](https://github.com/Vincent-Loeng/clash-meta/actions/workflows/run.yml/badge.svg)

This ***self-use repo*** automatically build the latest version with patches

此***自用仓库***自动使用补丁构建最新的版本

## Enhancements 增强功能

1. Match process 匹配进程

2. Redirect (since `1.19.24`)

## Examples 示例

Please refer to the given [template](template.yaml) 

请参考提供的[模板](template.yaml)


## Notes 注意事项

1. Please add port forwarding rules when using `redirect` (higher performance)

   使用 `redirect`（性能更好）时，请添加端口转发规则

2. The support for `riscv64` is experimental

   对`riscv64`支持仍处于实验阶段
