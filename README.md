# Localization Audit Kit

仅保存审计、差异分析和清单生成工具。译文载荷与部署材料不进入本仓库。

## 仓库边界

保留：

- 固定包名、版本和 registry 元数据。
- 目标文件相对路径与官方上游 SHA-256。
- 汉化范围说明和验证脚本。

不保留：

- `from/to` 替换、`localizedSha256`、完整汉化 manifest。
- 备份、tarball、解包目录和安装产物。
- 凭据、会话、模型配置和本机绝对路径。

## 目录

| 路径 | 作用 |
| --- | --- |
| `catalog/` | 固定版本包索引 |
| `inventories/` | 目标文件、上游 SHA-256、scope |
| `schemas/` | inventory 与本机 manifest JSON schema |
| `tools/` | 官方包校验、文案审计、版本差异、本地骨架生成 |
| `validation/` | catalog、inventory 与本机 manifest 校验 |
| `tests/` | 不依赖真实译文与真实凭据的合成测试 |
| `skills/` | Agent 使用入口说明 |
| `docs/` | 政策、流程与仓库历史清理说明 |

## 当前覆盖

由 `catalog/` 和 `inventories/` 定义，当前覆盖 **8 个固定版本、149 个目标文件**；具体包名和版本以这两处为准。

## 快速验证

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\run-all.ps1
```

`run-all.ps1` 只读取仓库文件并运行合成 fixture，不访问 npm、不修改本机安装。

## Agent 工作流

1. 查询目标包最新版本，获取 `version`、`dist.integrity`、`dist.shasum`。
2. 在 `inventories/` 建立或更新 inventory，只记录上游事实。
3. 同步更新 `catalog/`。
4. 用 `fetch-official.ps1` 下载并校验官方 tarball。
5. 用 `verify-upstream.mjs` 确认解包文件与 inventory 一致。
6. 用 `audit-strings.mjs` 盘点候选用户可见文案。
7. 用 `diff-inventory.mjs` 对比新旧版本。
8. 在本机私有仓库生成并填写 local manifest；译文和部署材料不得提交到这里。
9. 仅将 inventory、catalog、scope 和工具更新提交到本仓库。

## 需要网络的官方包实时校验

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\check-upstream-live.ps1
```

该脚本会按 catalog 逐个 `npm pack`，校验 registry integrity/shasum 和每个目标文件的上游 SHA-256。它只写临时目录，默认清理。

## 本机 manifest

```powershell
node .\tools\generate-local-manifest.mjs .\inventories\<inventory>.json .\local\manifests\<manifest>.json
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\check-manifest-local.ps1
```

`local/` 已被 Git 忽略。骨架生成后仍需在本机私有仓库中填写 `replacements` 并计算 `localizedSha256`。
