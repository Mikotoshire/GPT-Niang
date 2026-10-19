# GPT娘 · Mikotoshire Windows 维护版

> **AI 生成与验证声明：** 本维护分支相对上游的修改，以及新增或改写的文档，均由 AI 生成，且未经充分验证或独立人工审查。现有自动化测试与 AI 自查仅覆盖有限场景，不能保证正确性、稳定性、安全性或完整合规性，可能存在未发现的问题。仅供试用，请自行评估并备份重要数据。此声明不将上游原作或第三方依赖归为 AI 生成，也不改变原许可和权利归属。

基于 [T7moris/GPT-Niang](https://github.com/T7moris/GPT-Niang) v1.3.4 的非官方维护版本。代码保留 MIT 与原作者署名；角色素材有独立使用范围。本维护版与 OpenAI、上游作者不存在官方发布关系。

## 下载与安装

1. 在[本仓库 Releases](https://github.com/Mikotoshire/GPT-Niang/releases) 下载 `gpt-niang-mikotoshire-v1.4.3-windows.zip`；首版标记为 Pre-release，供非商业小范围试用。
2. 需要 Windows 10/11、Node.js 20+ 和已用你自己的 ChatGPT 账号登录的 Codex 桌面端。Node.js 请从 [nodejs.org](https://nodejs.org/) 获取。安装包不包含 Node.js，也不需要 Python、Git 或开发工具。
3. 完整解压到准备长期保留的文件夹，再双击根目录 `安装GPT娘.cmd`。安装会注册本地插件、当前用户的登录启动任务和启动快捷方式。插件后台随 Codex 窗口出现显示；请勿直接在 ZIP 内运行或安装后移动文件夹。
4. 手动打开用 `打开GPT娘.cmd`。停止使用并移除启动与插件注册用 `停用GPT娘.cmd`，偏好数据会保留。

使用你自己的账号；不要向维护者提供令牌、登录文件或整个状态目录。API Key 登录不提供 ChatGPT 订阅额度。需要核对文件时，将 ZIP 的 SHA256 与同一 Release 的 `SHA256SUMS.txt` 对照。

## 功能与限制

- 读取 Codex 实际返回的额度窗口，点击查看额度和语录。
- 高质量图片缩放、手动镜像、可选重力模式、按压蓄力、惯性、碰撞与滑行。
- 重力和弹性分别调节；动画调度目标 90 Hz，实际效果依设备性能决定。
- 本地额度诊断记录失败阶段、耗时和恢复情况，双击 `查看额度诊断.cmd` 查看。
- 此次仅发布 Windows 包，未发布或验证 Mac 维护版。新设备完整安装、Windows 注销登录及 Codex 退出重开需要试用验收。额度接口仍可能临时超时。

为兼容已有个人安装，内部插件/市场标识保留原值；**不能与上游版本同时安装**。安装器会拒绝接管其他仍存在的安装。已装上游版本的用户请先按上游方式停用，备份个人偏好，再安装此版。自动下载安装更新已关闭，后续从本仓库 Releases 手动获取。

## 隐私、许可与维护

详见[隐私说明](docs/PRIVACY.md)。发布包从已提交的 Git 源码按文件清单构建，不读取维护者工作区内的机器配置，附带 `SOURCE.json`、文件哈希清单和 Release 审查摘要。

代码与文档使用 [MIT](LICENSE)，版权归 T7moris 及 GPT-Niang contributors 等相应作者。保留原图片和其[来源及非商业项目副本声明](gpt-niang-usage/assets/CHARACTER-NOTICE.txt)；第三方参考角色权利不由本项目保证，不单独分发素材或授予商业使用权。语录保留[单独许可](gpt-niang-usage/assets/quotes-LICENSE.txt)。Aether.Physics2D 2.2.0 使用 [MS-PL](gpt-niang-usage/runtime/vendor/aether/LICENSE.txt)，附来源与固定二进制哈希。

开发维护流程见 [codex.md](codex.md)、[个人分支说明](docs/PERSONAL-FORK.md) 和[更新记录](更新记录.md)。上游历史说明可从 Git 历史或上游仓库查阅。问题请向[本仓库](https://github.com/Mikotoshire/GPT-Niang/issues)反馈，公开反馈时只描述现象和错误类型，勿上传账号或完整本机日志。
