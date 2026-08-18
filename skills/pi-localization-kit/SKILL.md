---
name: pi-localization-kit
description: Audit packages, maintain localization inventories, and prepare local-only manifests. Use when checking official package hashes, finding new user-visible strings, comparing versions, or generating and validating a localization worklist.
---

# Pi Localization Kit

只读审计、差异分析和本地 manifest 生命周期。仓库不保存译文载荷。

## 只读检查

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\run-all.ps1
```

## 审计新版本

1. 更新 `inventories/` 与 `catalog/`。
2. `fetch-official.ps1` 取得官方包。
3. `verify-upstream.mjs` 校验哈希。
4. `audit-strings.mjs` 提取候选文案。
5. `diff-inventory.mjs` 对比新旧版本。
6. `generate-local-manifest.mjs` 生成本地骨架。

## 本机 manifest 生命周期

1. 填写 `replacements`。
2. `compute-manifest-hashes.mjs` 计算 localizedSha256。
3. `check-manifest-local.mjs` 正向/反向重放校验。
4. `apply-local-manifest.mjs` 写入本机官方包副本。

## 安全规则

- 默认只读；不修改本机安装。
- 不把凭据、会话、模型配置、备份或本机绝对路径带入仓库。
- 不把 `from`/`to` 和 `localizedSha256` 提交到本仓库。
- 发现译文载荷出现在仓库时，视为泄露并停止。
