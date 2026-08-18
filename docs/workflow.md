# 新包 / 新版本流程

1. `npm view "<package>@<version>" version dist.integrity dist.shasum --json`
2. 在 `inventories/` 建立 inventory，只记录上游事实。
3. 更新 `catalog/core.json` 或 `catalog/extensions.json`。
4. 运行 `validation/check-catalog.ps1` 和 `validation/check-inventory.ps1`。
5. 用 `tools/fetch-official.ps1` 取得官方 tarball 并校验。
6. 用 `tools/verify-upstream.mjs` 校验解包文件。
7. 用 `tools/audit-strings.mjs` 产出候选用户可见英文；按 scope 去重、排除 keepEnglish。
8. 用 `tools/diff-inventory.mjs` 与上一版比较。
9. 在本机私有仓库用 `tools/generate-local-manifest.mjs` 生成骨架并填写译文。
10. 在本机私有仓库完成正向/反向重放、语法检查、Apply/Restore 与冒烟测试。
11. 仅把 inventory、catalog、scope 和工具更新提交到本套件仓库。

本套件仓库本身不含 Apply/Restore 引擎；部署验证只在本机私有仓库执行。
