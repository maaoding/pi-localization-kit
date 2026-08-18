# Localization Audit Kit

面向固定版本软件包的本地化审计与生成套件。仓库只保存上游事实和工具，不保存译文载荷。

## 工作流

1. 建立 inventory：包名、固定版本、registry 元数据、目标文件路径和上游 SHA-256。
2. 获取官方包并校验。
3. 盘点候选用户可见文案。
4. 比较新旧版本差异。
5. 在本机生成 local manifest，填入替换。
6. 计算、校验并应用 local manifest。
7. 只把 inventory/catalog/工具更新提交回仓库。

## 工具

| 命令 | 作用 |
| --- | --- |
| `tools/fetch-official.ps1` | 校验 registry 元数据并下载解包官方包 |
| `tools/verify-upstream.mjs` | 校验目标文件与 inventory 一致 |
| `tools/audit-strings.mjs` | 提取候选用户可见英文 |
| `tools/diff-inventory.mjs` | 对比新旧 inventory |
| `tools/generate-local-manifest.mjs` | 生成本地 manifest 骨架 |
| `tools/compute-manifest-hashes.mjs` | 填写 localizedSha256 |
| `tools/check-manifest-local.mjs` | 正向/反向重放与双哈希校验 |
| `tools/apply-local-manifest.mjs` | 校验后写入本地官方包副本 |

## 快速验证

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\run-all.ps1
```

不访问 npm，不修改本机安装。

## 官方包实时校验

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -File .\validation\check-upstream-live.ps1
```

## 本机 manifest 示例

```powershell
node .\tools\generate-local-manifest.mjs .\inventories\<inventory>.json .\local\manifests\<manifest>.json
# 填写 replacements
node .\tools\compute-manifest-hashes.mjs .\local\manifests\<manifest>.json <package-root>
node .\tools\check-manifest-local.mjs .\local\manifests\<manifest>.json <package-root>
node .\tools\apply-local-manifest.mjs .\local\manifests\<manifest>.json <package-root>
```

`local/` 已被 Git 忽略。译文和 local manifest 不得提交。
