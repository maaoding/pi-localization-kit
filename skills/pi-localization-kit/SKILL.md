---
name: pi-localization-kit
description: Audit and maintain Pi localization inventories and generate local-only manifests. Use when checking official package hashes, finding new user-visible English strings, comparing versions, or preparing a localization worklist.
---

# Pi 本地化套件

本技能只做只读审计、差异分析和本地骨架生成。仓库不包含译文载荷和部署引擎。

## 只读检查

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\run-all.ps1
```

## 审计新版本

1. 查询 npm 元数据。
2. 建立/更新 inventory 与 catalog。
3. `fetch-official.ps1` 下载官方包。
4. `verify-upstream.mjs` 校验文件哈希。
5. `audit-strings.mjs` 提取候选用户可见英文。
6. `diff-inventory.mjs` 对比新旧版本。
7. 在本机私有仓库生成 local manifest，不把译文写入本仓库。

## 安全规则

- 默认只读；不修改本机安装。
- 不把凭据、会话、模型配置、备份或本机绝对路径带入仓库。
- 不把 `from`/`to` 和 `localizedSha256` 提交到本仓库。
- 发现译文载荷出现在仓库时，视为泄露并停止。
