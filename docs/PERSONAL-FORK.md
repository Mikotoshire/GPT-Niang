# Mikotoshire 的个人维护版本

> **AI 生成与验证声明：** 本维护分支相对上游的修改，以及新增或改写的文档，均由 AI 生成，且未经充分验证或独立人工审查。现有自动化测试与 AI 自查仅覆盖有限场景，不能保证正确性、稳定性、安全性或完整合规性，可能存在未发现的问题。仅供试用，请自行评估并备份重要数据。此声明不将上游原作或第三方依赖归为 AI 生成，也不改变原许可和权利归属。

本仓库 fork 自 [T7moris/GPT-Niang](https://github.com/T7moris/GPT-Niang)，起点为 v1.3.4（`b92159a93c131bd5ba4722d7f507ee04d633d5db`）。保留上游提交历史、作者署名、LICENSE、角色素材来源及语录许可。

## 范围

这是 Mikotoshire 维护的 Windows 分支，用 GitHub 备份代码和迁移设备；1.4.0 起提供遵守现有许可的非商业小范围测试下载。角色原图不变，WPF 使用高质量图像重采样。Windows 的上游 Release 更新已禁用，自动更新开关不可启用。`runtime/fork-policy.json` 也保护不包含 `.git` 的源码副本。本分支仅运行 Windows CI 和提供 Windows 发布包。macOS 源码保留自上游，本分支尚未适配或验证其个人版更新策略，请勿将上游 Mac 安装包视作这个 Windows 个人版本。

代码和一般文档继续按 MIT 许可使用，保留原版权和许可文本。角色图片不属于 MIT 许可，仅在素材声明允许的非商业项目副本中随项目使用，不单独发布素材包或将其用于商业用途。语录遵循 `gpt-niang-usage/assets/quotes-LICENSE.txt`。这不是上游作者或 OpenAI 官方发布的版本。

## 分支和备份

- `origin` 指向 `https://github.com/Mikotoshire/GPT-Niang.git`；`main` 保存已验证版本，本机运行 `main`。
- `upstream` 只用于显式查看原作者变更，不自动合并或更新。
- 新功能使用 `personal/<feature>` 分支；先提交可复现的测试或保留修改前检查点，再修改、验证、合并回 `main` 并上传。
- 修改前保留 `backup/<date>-<description>` 标签；较大修改前在仓库外生成 `git bundle create <backup-file> --all`。不要反复提交整套压缩包。
- 不强制推送，不用 `reset --hard` 或 `clean -fd` 清理用户文件；遇到冲突先保存工作再处理。
- 本机代码与 `origin/main` 对齐表示开发完成后的同步；没有后台轮询或自动执行远端代码的任务。

## 以后继续开发

代码同步与打包发布分开：修改和验证完成后继续同步个人 GitHub，作为备份和迁移来源；仅在用户明确要求时才打包发行文件、创建发布标签或发布 Release。普通代码同步不更新已有安装包。

把本目录作为项目打开，提出需求即可。维护流程为：检查分支和本地改动 → 备份 → 功能分支 → 修改及验证 → 合并 `main` → 上传备份 → 重载挂件 → 确认额度查询。

命令行 Git 的认证和 Codex GitHub 连接分别管理；若命令行认证不可用，可以使用已授权的 GitHub 连接提交，再获取远端提交并对齐本地。对齐前必须保留本地分支、标签或 bundle，且确认工作树内容一致。

## 换设备恢复

1. 安装 Node.js 20+、Git 和 Codex 桌面版，用自己的 ChatGPT 账号登录 Codex。
2. `git clone https://github.com/Mikotoshire/GPT-Niang.git`，保留 `.agents` 等隐藏目录。
3. 在固定目录运行仓库根目录的 `安装GPT娘.cmd`，按新设备路径重新注册插件。
4. 安装器会生成本机 `installation.json` 和绝对路径版 `.mcp.json`。`installation.json` 已被忽略；执行 `git update-index --skip-worktree gpt-niang-usage/.mcp.json`，避免上传本机生成路径。若将来要修改 MCP 模板，先备份生成文件，再取消这个标记并明确处理模板变更。
5. 确认龙娘显示、额度可读取、自动更新关闭。不要下载原作者的 Release 覆盖这个 fork。

账号凭据、令牌、邮箱、聊天记录、额度快照和本机偏好不上传 GitHub。换设备需重新登录；位置、自定义语录等个人偏好可按需单独本地备份。

Windows 自启动曾因 MSIX AppData 重定向返回 `0x8007010B`。现在任务使用系统工作目录及操作系统解析的实际启动器路径；安装配置保存实际状态目录，保留原设置和日志。已验证由 Windows 计划任务启动后台和可见挂件；完整注销/登录及 Codex 退出重开仍需在设备上验收。手动启动可使用仓库根目录 `打开GPT娘.cmd`。

## 验证

```powershell
cd gpt-niang-usage
node --test tests/*.test.mjs
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/fork-policy.test.ps1
```

已有 WPF 脚本中部分文件是无 BOM 的 UTF-8；使用 Windows PowerShell 5.1 时按 UTF-8 读取后以 ScriptBlock 执行，避免系统默认编码误读中文。针对图像缩放修改已运行 60%～250% 预览、288 项物理尺寸检查和挂件布局检查。
