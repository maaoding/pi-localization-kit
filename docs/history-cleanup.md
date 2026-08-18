# Git 历史清理

如果旧远程仓库历史已经包含 manifest、备份引用或本机信息，仅删除工作区文件不够，历史中仍可检出。

推荐顺序：

1. 冻结本机完整补丁仓库和备份。
2. 新建一个干净的套件仓库，不迁移旧历史。
3. 从 `localization-kit/` 当前文件初始化；先本地验证 `validation/run-all.ps1`。
4. 推送前做一次干净 clone 检查：
   - 搜索不到 `localizedSha256`、中文 `from/to` 对。
   - 搜索不到绝对路径、`settings.json`、`auth.json`。
   - `git grep` 无本机用户名和备份 ID。
5. 如果必须沿用原远程仓库，使用 `git filter-repo --invert-paths` 清除历史后再 force push，并提前通知协作者。

安全默认：完整补丁仓库永远不关联新远程。
