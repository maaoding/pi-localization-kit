# 工作流

## npm 发布版

1. `npm view "<package>@<version>" version dist.integrity dist.shasum --json`
2. 在 `inventories/` 建立 inventory，只记录上游事实。
3. 同步 `catalog/`。
4. `validation/check-catalog.ps1` 和 `validation/check-inventory.ps1`。
5. `tools/fetch-official.ps1` 下载官方包。
6. `tools/verify-upstream.mjs` 校验目标文件。
7. `tools/audit-strings.mjs` 生成候选文案。
8. `tools/diff-inventory.mjs` 与上一版比较。
9. `tools/generate-local-manifest.mjs` 生成本地骨架。
10. 在本机填写 replacements。
11. `compute-manifest-hashes.mjs` 填哈希。
12. `check-manifest-local.mjs` 校验。
13. `apply-local-manifest.mjs` 写入本机官方包副本。
14. 把 inventory、catalog、scope 和工具更新提交；译文不提交。

## git 来源版（npm 未发布）

1. 确认上游 tag 与 commit：`git ls-remote --tags <repository>`。
2. 在 `inventories/` 建立 inventory，`source.kind = "git"` 并记录：
   - `repository`：HTTPS 仓库地址
   - `tag`：发布 tag（如 `v0.4.5`）
   - `commit`：tag 解引用后的完整 40 位 commit
   - `build`：可复现目标文件的命令数组（如 `["npm ci", "npm run build"]`）
3. 同步 `catalog/` 中的同名来源字段。
4. 克隆 tag、执行 build，再对构建产物运行 `tools/verify-upstream.mjs`；
   `validation/check-upstream-live.ps1` 会自动执行这组步骤。
5. 其余审计、manifest 生成与校验步骤与 npm 发布版一致。

## 保持英文

工具名、Slash command、命令参数、路径、URL、环境变量、API、HTTP、CLI、TUI、Provider、模型名称、模型 ID、JSON/schema、selector、状态枚举、模型可见工具描述与结果协议、官方系统提示词、外部服务响应和原始错误正文。
