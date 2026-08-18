# Pi 本地化 Agent 套件

这个仓库只保存 **审计与生成工具**，不保存任何中文译文或可部署补丁载荷。

远程仓库不变式：

- 有：包目录、固定版本、官方 integrity/shasum、目标文件清单、上游 SHA-256、汉化边界。
- 无：`from/to` 替换、`localizedSha256`、完整 manifest、备份、安装包、凭据或会话。

完整汉化 manifest 和补丁引擎只应存在于本机私有仓库。

## 目录

| 路径 | 作用 |
| --- | --- |
| `catalog/` | core 与 extensions 的包/版本索引 |
| `inventories/` | 每个固定版本的目标文件、上游 SHA-256、scope |
| `schemas/` | inventory 与本机 manifest JSON schema |
| `tools/` | 官方包校验、候选文案审计、版本差异、本地骨架生成 |
| `validation/` | catalog/inventory 一致性校验 |
| `tests/` | 不依赖真实译文与真实凭据的合成测试 |
| `skills/pi-localization-kit/` | Agent 使用入口说明 |
| `docs/` | 政策、流程与历史清理说明 |

## 当前 inventory

| 包 | 版本 | 目标文件 |
| --- | --- | ---: |
| `@earendil-works/pi-coding-agent` | `0.84.2` | 114 |
| `@99percentpeople/pi-pwsh-adapter` | `1.1.2` | 1 |
| `@juicesharp/rpiv-ask-user-question` | `2.6.1` | 5 |
| `pi-agent-browser-native` | `0.2.72` | 4 |
| `pi-mcp-adapter` | `2.26.0` | 6 |
| `pi-subagents` | `0.50.0` | 13 |
| `pi-voice-stt` | `0.6.0` | 3 |
| `pi-web-access` | `0.23.0` | 3 |

`pi-agent-browser-native` 的本地 0.4.1 包不在 npm registry，本套件只索引 npm 0.2.72。

## 快速验证

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\run-all.ps1
```

`run-all.ps1` 只读取仓库文件并运行合成 fixture，不访问 npm、不修改本机安装。

## Agent 工作流

1. 查询目标包最新版本，获取 `version`、`dist.integrity`、`dist.shasum`。
2. 生成 inventory，录入固定版本、文件路径和上游 SHA-256。
3. 用 `fetch-official.ps1` 下载并校验官方 tarball。
4. 用 `verify-upstream.mjs` 确认解包文件与 inventory 一致。
5. 用 `audit-strings.mjs` 盘点候选用户可见文案。
6. 用 `diff-inventory.mjs` 对比新旧版本。
7. 在本机私有仓库生成并填写 local manifest；译文和部署材料不得提交到这里。
8. 更新本仓库 inventory/catalog，提交。

## 禁止提交

- `local/`、`manifests.local/`、`backups/`、`dist/`、tarball、解包目录。
- `from/to` 中文替换、`localizedSha256`。
- `settings.json`、`auth.json`、模型配置、会话文件。
- 任何本机绝对路径。

## 需要网络的官方包实时校验

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\check-upstream-live.ps1
```

该脚本会按 catalog 逐个 `npm pack`，校验 registry integrity/shasum 和每个目标文件的上游 SHA-256。它只写临时目录，默认清理。

## 本机 manifest

```powershell
node .\tools\generate-local-manifest.mjs .\inventories\extensions\pi-mcp-adapter-2.26.0.json .\local\manifests\pi-mcp-adapter-2.26.0.json
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\check-manifest-local.ps1
```

`local/` 已被 Git 忽略。骨架生成后仍需在本机私有仓库中填写 `replacements` 并计算 `localizedSha256`。
