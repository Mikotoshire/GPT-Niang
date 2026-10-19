# Codex 维护笔记

这是 `Mikotoshire/GPT-Niang` 的 Windows 个人维护分支。先读 `AGENTS.md` 和 `docs/PERSONAL-FORK.md`。保留上游 MIT、角色素材来源/非商业范围、语录许可；不得上传账号和运行状态。发布渠道为个人仓库 `origin/main`，原项目的 Release 更新保持禁用。

## 重力模式（2026-10-19）

右键菜单的“重力模式”与“外观设置”同级，默认关闭；勾选即开启，开关写入本机 `settings.json` 的 `gravityEnabled`。关闭后终止物理计时器、清除形变并恢复普通拖动/点击。恢复位置操作同时清除当前弹跳。

### 交互约定

- 单击：即使很快松开，也先完成 220 ms 的基础压缩，再轻跳 24 个设计 DIP；首次触底时速度归零。
- 长按：基础压缩结束后，再用 1.2 秒逐步蓄满。纵向比例由 0.88 降到 0.48，横向由 1.05 增至 1.45。松开后的额外跳高为 `260 × charge²`，达到上限后继续按住不再无限增加能量。
- 蓄力弹跳：松开后用 100 ms 平滑恢复形状，同时开始起跳；每次触地将竖直速度乘以 0.64。允许最后一次小跳实际发生，当该次最高高度不超过单击的 24 DIP 阈值后，下次落地速度归零。
- 惯性：释放时取最近约 100 ms 的实际窗口移动速度，转换到设计 DIP/s，水平/竖直各限制在 ±1600。停住再松手不沿用旧速度。边缘回弹，落地摩擦逐渐停止；垂直停止阈值不取消仍存在的水平滑动。
- 依赖：`runtime/vendor/aether` 保留固定 DLL、完整 MS-PL 许可、来源及 SHA256；不运行时下载。不修改原项目 MIT 和素材/语录许可。
- 拖动：超过原有 3 像素阈值即取消按压蓄力，恢复形状。放手从实际位置自由落体，再按同一回弹规则衰减。拖动释放不打开额度气泡。
- 抓住空中的角色可中止下落、重新按压或拖动。丢失鼠标捕获时按拖放处理，避免永久停在压扁状态。
- 跟随 Codex 时以当前可见窗口底边为地面；桌面模式使用当前显示器工作区底边。窗口不可见时暂停，不在恢复显示时补算大段时间。

### 实现位置

| 文件 | 职责 |
| --- | --- |
| `gpt-niang-usage/runtime/gravity-model.cs` | 纯物理状态机；无 WPF、窗口句柄、文件或系统时间依赖 |
| `gpt-niang-usage/runtime/gravity.ps1` | 16 ms DispatcherTimer、Stopwatch 时间、实际窗口尺寸、位置和形变桥接 |
| `gpt-niang-usage/widget.ps1` | 按下/松开/拖动/失去捕获接入，设置保存，窗口跟随，退出清理 |
| `gpt-niang-usage/widget.xaml` | `GravityScale` 仅缩放角色图像，锚定图像右下角；保留高质量采样 |
| `gpt-niang-usage/runtime/ui-settings.ps1` | 同级复选菜单、开关状态、恢复位置时清除弹跳 |

物理单位是设计空间 DIP 与秒；重力为 1800 DIP/s²。位置更新使用实际经过的时间，单帧最多推进 100 ms，并按固定子步处理。重力积分、地面/墙面/天花板碰撞和地面摩擦交给固定版本 Aether.Physics2D 2.2.0，按 1/240 秒固定步推进并累计余时。100 DIP 对应引擎 1 米。业务状态机只负责蓄力、停止阈值和形变；引擎接触容差约 0.5 DIP。窗口太矮时限制最高位置；没有可跳空间时安全归零。

角色的可见下沿位于原始 378 DIP 画布的第 364 DIP，末尾 14 DIP 是透明留白。不得直接把整个透明窗口的下沿当作脚底。分数 DPI 下 WPF 会取整，因此 `Get-WidgetGravityGeometry` 读取真实 HWND 尺寸，重新计算 Viewbox 单位和留白；碰撞、原生跟随器和窗口定位使用相同的换算。

运行时动画不逐帧写设置。活动时才启用物理计时器，停稳、关闭模式、隐藏窗口和退出时停止；停稳后保存落地位置。原生窗口跟随继续使用 `host-follow.ps1`，不让 1 秒的常规刷新覆盖物理高度。

本机 `presence.json` 的 `gravity` 字段提供开关、高度、速度、蓄力、回弹次数和活动状态，便于检查落地后 `height=0`、`velocity=0`、`active=false`。该文件属于运行数据，不提交到 GitHub。

## 验证与维护流程

先创建 `backup/<description>-<date>` 标签和仓库外 bundle，再开 `personal/<feature>` 分支。新增行为测试先运行至失败，完成实现后运行相同测试，再做相关回归。代码审查需检查坐标单位、捕获取消、定时器关闭和模式切换；没有验证的功能不能在更新日志中宣称已通过。

```powershell
cd gpt-niang-usage
node --test tests/*.test.mjs
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/gravity.test.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/gravity-wpf.test.ps1
```

另外运行原有尺寸、拖动、菜单、桌面模式和挂件布局测试。含中文且无 BOM 的旧测试须按 UTF-8 解码后执行，使用明确的 TestRoot，避免 Windows PowerShell 5.1 误读脚本。本机运行目录本身是 Git 工作树；机器生成的 `.mcp.json` 使用 skip-worktree，不能把该绝对路径配置提交为模板。

测试通过后提交、合并 `main`、同步个人 GitHub、保存 bundle 并重载挂件。不要强制推送或丢弃用户修改。若命令行推送认证仍不可用，使用已连接的 GitHub 工具发布提交；重新获取远端后，仅在源码树完全一致且已备份的前提下对齐本地记录。

当前功能仅在 Windows 验证。已有 Task Scheduler 错误 `0x8007010B` 与本功能无关，保留已可工作的直接 supervisor 启动方式。

## 公开仓库隐私

仅提交代码、无隐私的测试样例、许可和维护文档。不得记录真实账户、余额、令牌、会话、个人目录或本机设置。发布前检查全部新增提交，而非只检查工作树；依赖二进制只允许来源和哈希已验证的固定公开包。
