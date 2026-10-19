# Codex 维护笔记

> **AI 生成与验证声明：** 本维护分支相对上游的修改，以及新增或改写的文档，均由 AI 生成，且未经充分验证或独立人工审查。现有自动化测试与 AI 自查仅覆盖有限场景，不能保证正确性、稳定性、安全性或完整合规性，可能存在未发现的问题。仅供试用，请自行评估并备份重要数据。此声明不将上游原作或第三方依赖归为 AI 生成，也不改变原许可和权利归属。

这是 `Mikotoshire/GPT-Niang` 的 Windows 个人维护分支。先读 `AGENTS.md` 和 `docs/PERSONAL-FORK.md`。保留上游 MIT、角色素材来源/非商业范围、语录许可；不得上传账号和运行状态。发布渠道为个人仓库 `origin/main`，原项目的 Release 更新保持禁用。

## 重力模式（2026-10-19）

右键菜单的“重力模式”与“外观设置”同级，默认关闭；勾选即开启，开关写入本机 `settings.json` 的 `gravityEnabled`。关闭后终止物理渲染循环、清除形变并恢复普通拖动/点击。恢复位置操作同时清除当前弹跳。

### 交互约定

- 单击：即使很快松开，也先完成 220 ms 的基础压缩，再轻跳 `24 × 弹性强度` 个设计 DIP；首次触底时速度归零。
- 长按：基础压缩结束后，再用 1.2 秒逐步蓄满。纵向比例由 0.88 降到 0.48，横向由 1.05 增至 1.45。松开后的额外跳高为 `260 × charge² × 弹性强度`，达到上限后继续按住不再无限增加能量。
- 蓄力弹跳：松开后用 100 ms 平滑恢复形状，同时开始起跳；每次触地将竖直速度乘以 0.64。允许最后一次小跳实际发生，当该次最高高度不超过单击的 `24 × 弹性强度` DIP 阈值后，下次落地速度归零。
- 惯性：拖动时独立采样最近约 100 ms 的原生鼠标位置，转换到设计 DIP/s，水平/竖直各限制在 ±1600。停住至少 80 ms 再松手不沿用旧速度。边缘回弹，落地摩擦逐渐停止；垂直停止阈值不取消仍存在的水平滑动。
- 依赖：`runtime/vendor/aether` 保留固定 DLL、完整 MS-PL 许可、来源及 SHA256；不运行时下载。不修改原项目 MIT 和素材/语录许可。
- 拖动：超过原有 3 像素阈值即取消按压蓄力，恢复形状。放手从实际位置自由落体，再按同一回弹规则衰减。拖动释放不打开额度气泡。
- 抓住空中的角色可中止下落、重新按压或拖动。丢失鼠标捕获时按拖放处理，避免永久停在压扁状态。
- 跟随 Codex 时以当前可见窗口底边为地面；桌面模式使用当前显示器工作区底边。窗口不可见时暂停，不在恢复显示时补算大段时间。

### 实现位置

| 文件 | 职责 |
| --- | --- |
| `gpt-niang-usage/runtime/gravity-model.cs` | 纯物理状态机；无 WPF、窗口句柄、文件或系统时间依赖 |
| `gpt-niang-usage/runtime/gravity.ps1` | WPF CompositionTarget.Rendering、Stopwatch 时间、实际窗口尺寸、位置和形变桥接 |
| `gpt-niang-usage/widget.ps1` | 按下/松开/拖动/失去捕获接入，设置保存，窗口跟随，退出清理 |
| `gpt-niang-usage/widget.xaml` | `GravityScale` 仅缩放角色图像，锚定图像右下角；保留高质量采样 |
| `gpt-niang-usage/runtime/ui-settings.ps1` | 同级复选菜单、开关状态、恢复位置时清除弹跳 |

物理单位是设计空间 DIP 与秒；基础重力为 1800 DIP/s²，默认乘以 1.6（2880 DIP/s²）。位置更新使用实际经过的时间，单帧最多推进 100 ms，并按固定子步处理。重力积分、地面/墙面/天花板碰撞和地面摩擦交给固定版本 Aether.Physics2D 2.2.0，按 1/240 秒固定步推进并累计余时。100 DIP 对应引擎 1 米。业务状态机只负责蓄力、停止阈值和形变；引擎接触容差约 0.5 DIP。窗口太矮时限制最高位置；没有可跳空间时安全归零。

角色的可见下沿位于原始 378 DIP 画布的第 364 DIP，末尾 14 DIP 是透明留白。不得直接把整个透明窗口的下沿当作脚底。分数 DPI 下 WPF 会取整，因此 `Get-WidgetGravityGeometry` 读取真实 HWND 尺寸，重新计算 Viewbox 单位和留白；碰撞、原生跟随器和窗口定位使用相同的换算。

运行时动画不逐帧写设置。活动时才启用物理渲染循环，停稳、关闭模式、隐藏窗口和退出时停止；停稳后保存落地位置。原生窗口跟随继续使用 `host-follow.ps1`，不让 1 秒的常规刷新覆盖物理高度。

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

当前功能仅在 Windows 验证。早期 Task Scheduler 错误 `0x8007010B` 已在后述 Windows 自启动修复中处理。

## 公开仓库隐私

仅提交代码、无隐私的测试样例、许可和维护文档。不得记录真实账户、余额、令牌、会话、个人目录或本机设置。发布前检查全部新增提交，而非只检查工作树；依赖二进制只允许来源和哈希已验证的固定公开包。

## 手感调节与动画性能（2026-10-19）

- 外观设置中 `角色镜像翻转` 默认为关闭，保持原来右侧的朝向。角色镜像独立于左右位置；气泡文字不跟随镜像。`CharacterMirror` 先绕图像中心翻转，再执行脚底锚定的 `GravityScale`，避免蓄力时越界。
- `重力与弹性` 子菜单有两个独立滑条：重力强度 0.5–4.0×，默认 1.6×；弹性势能 0.25–3.0×，默认 1.0×。弹性线性缩放相同压缩量对应的跳高，也同步缩放轻跳停止阈值；改变重力不改变蓄力目标跳高，而改变落下速度和滞空时间。偏好写入本机 `gravityStrength`、`elasticStrength`、`mirrorCharacter`。
- `GptDragVelocity` 在拖动期间用原生 GetCursorPos 与独立 8 ms .NET Timer 持续采样，不依赖可能拥塞的 MouseMove 消息时间。最近 100 ms 样本决定松手速度；停住至少 80 ms、数据不足或速度小于 35 DIP/s 时归零。开始拖动清空旧样本，松手/失去捕获/关闭模式/退出均停止采样。位置数据仅在内存，不写日志。抓到空中后静止松手仍会受重力下落，这是下落而非保留旧甩动速度。
- 动画使用 `gravity-render.cs` 的 WPF 渲染事件，只在活动时订阅，停止时解除；相同 RenderingTime 不重复推进。避免 16 ms 定时器叠加处理耗时错过渲染帧。图像高质量缩放保持启用，BitmapCache 按实际尺寸和 DPI 设置采样，减少每帧重采样原始图像。
- 原生跟随新增 MovePose，只更新运动位置；保留常规 Configure 处理宿主/DPI/尺寸改变。物理模型不再在每个渲染帧无条件重设刚体位置，以保留 Aether 接触求解缓存。
- 新测试 `motion-tuning.test.ps1` 覆盖迅速松手、停住 0.1/0.5/1 秒后释放、重力与弹性独立、参数重置保留和镜像策略。WPF/菜单测试覆盖实际位移、镜像蓄力不裁切、滑条值和持久化。

## 实机帧率与近地修复（2026-10-19，暂停后继续）

逐帧热路径现在在 C# `gravity-render.cs`：`GptGravityScene` 保存布局快照，`GptGravityRenderLoop` 推进 Aether 模型、更新 ScaleTransform、调用原生窗口跟随。PowerShell Tick 通知最多约 4 Hz，仅同步位置、菜单和结束保存。`Tick-Widget` 每次常规布局前先同步已显示位置，再更新 Scene，防止一秒刷新把运动拉回旧坐标。

调度目标为 90 Hz，给至少约 60 Hz 的应用更新留余量；采用相位截止时间，限制无效高频回调，隐藏、宿主最小化和静止后解除 Rendering 订阅。物理仍按 240 Hz 固定步、真实经过时间推进，速度与动画更新率独立。Rendering 回调可能快于显示器扫描，不能将原始回调次数称作上屏 FPS。`presence.json.gravity` 的 targetFps、renderFps、frameCount、meanStepMs、maxStepMs 是本地应用诊断，空闲前无动画时为零。

近地吸附的根因：Aether 的 PreSolve 回调可能来自宽相预检测，旧代码未判断 `contact.IsTouching` 就按触底处理；从 16 DIP 松手甚至一步归零。现在忽略尚未真正接触的回调，并将地面 Edge 的额外 Shape.Radius 设为 0，由圆形刚体定义脚底边界，避免约 1 DIP 提前接触。0.5、1、2、4、8、16 DIP 释放均应先加速下落；真实碰撞后才停止或回弹。

模型与渲染器在运行时一起编译，引用 Aether、PresentationCore 和 WindowsBase；纯模型测试仍可独立编译模型。`Update-WidgetGravity` 保留为显式诊断/回归的单步桥接，不再绑定逐帧 Rendering。原生 `AnimationFrame()` 返回当前宿主与工作区裁切后的边界；委托调用不经过 PowerShell。保留现有镜像、重力、弹性和拖动设置。

新增 `floor-contact.test.ps1` 与 `managed-frames.test.ps1`。后者使用真实图片和 HWND，验证有效帧调度、实际位置改变、平均步耗时、低频脚本通知和位置同步；`-Visible` 可短暂显示测试窗口。测试机器可见窗口约 74.4 Hz、平均步耗时约 2.26 ms；实际挂件目标 90 Hz、测得约 73.6 Hz，仍有单次约 48 ms 的系统/窗口开销峰值。因此不能宣称每一帧或所有设备均恒定超过 60 FPS。

## 横向碰撞与滑行（2026-10-19）

触地不清空横向速度。原先 0.65 的库仑摩擦会在较大竖直冲量下直接抵消横向动量；现在真正落地时的求解器接触摩擦为零，求解后仅把横向速度乘 `HorizontalRetention=0.82`（保留方向、每次损失 18%）。仍由 Aether 处理重力、碰撞与静止后的连续滑动摩擦，`GroundFriction=0.12`。

`touchingFloor/wasTouchingFloor` 区分进入接触与持续接触；只在新的下落碰撞扣速一次。竖直弹跳停止后，只归零 Y，X 继续滑行；地面连续接触不重复乘 0.82。直接在地面开始水平滑动不计为一次下落碰撞。仅两轴速度都已很低时，原有睡眠阈值才结束物理循环。`FloorImpacts` 计数用于模型回归，每次 Reset 清零。

`tests/horizontal-impact.test.ps1` 覆盖左右两方向、多次落地按比例损失、持续接触不重复扣速、竖直归零而横向继续、库摩擦最终停稳，以及地面直接滑动不误判碰撞。

## 额度读取诊断（2026-10-19）

仅在本机状态目录写入 `quota-diagnostics.jsonl` 和轮转备份 `.1`，各最多 256 KiB，总计约 512 KiB。单写入者为额度 worker，保持每分钟/显式请求的原查询频率；不新增远程请求，不改变 18 秒查询超时。日志不能追溯安装前的故障。两个文件均受 Git 忽略规则保护。

事件包括 `worker_start`、`query_start`、查询完成 `query`、状态保存失败 `snapshot_write_failed`。查询完成记录 UTC 时间、总耗时、最后 RPC 阶段与该阶段耗时、超时上限、白名单错误码、成功状态。阶段 `initialize` / `account` / `rate_limits` 分别对应初始化、读取登录状态和读取额度；`recovered=true` 表示同一 worker 内失败后恢复成功。只有开始而无完成事件时，可排查进程退出或仍在查询；不直接断言原因。保存失败的日志写入也可能失败，因此日志缺失不能证明没有故障。

严格白名单过滤：不写账户、账户指纹、套餐、令牌、邮箱、具体额度、接口原文、异常堆栈或本机路径。未知错误类型归为 `QUERY_FAILED`。磁盘不可写时日志失败不影响额度读取。读取入口再次过滤字段，忽略损坏行，最多返回 1000 条。

排查命令（在仓库根目录执行）：

```powershell
node gpt-niang-usage/runtime/control.mjs diagnostics 100
```

命令仅查看日志，不发起查询，也不返回旧 `status` 命令中的真实额度。也可以双击根目录的 `查看额度诊断.cmd`。排查时先读取此接口，关注最近 worker 启动、超时所在阶段、耗时接近 timeoutMs 及是否恢复；必要时再在本机检查 worker 状态和 Codex 运行状态。不要将真实日志提交或附加到公开 issue。日志轮转后较旧事件会被覆盖。

验证：`tests/diagnostics.test.mjs` 覆盖白名单脱敏、轮转、损坏行、不可写目录、RPC 阶段超时、诊断回调异常不破坏查询，以及真实 worker 的失败后恢复。`runtime/install-files.json` 包含诊断模块，避免迁移/更新后缺失依赖。

## Windows 自启动与 MSIX 路径（2026-10-19）

根因：在打包版 Codex 内创建的逻辑 LocalAppData 路径会被 MSIX 重定向，计划任务在包外看不到该逻辑目录。原任务首先因工作目录不存在报 `0x8007010B`；仅改成系统目录后，WScript 仍因找不到脚本返回 1。必须同时修正启动器及共享状态路径，不能只凭任务 Running 判断成功。

`Resolve-WidgetPhysicalPath` 用 CreateFile/GetFinalPathNameByHandle 读取现有文件/目录的实际路径，支持目录、长路径前缀和 UNC；不存在的路径在 preflight 中保持原样。安装器在创建目录后再次解析，将实际 `dataDir`、`updateAgent` 保存在本机配置和稳定绑定。`Get-WidgetUpdateAgentDir` 在稳定组件中以自身目录为准，在程序 runtime 中读取经过账户/安装绑定校验的已保存目录，使包内和包外访问同一状态，不复制或清空偏好。

计划任务使用 Windows System32 为工作目录，仍以当前用户 Interactive/Limited 运行，参数只允许一个完整引用的启动脚本路径；身份检查兼容旧逻辑路径及其实际别名，拒绝其他脚本/额外参数/不同账户或绑定。手动打开旧安装会迁移旧工作目录。启动快捷方式也使用实际入口和系统工作目录。后台由计划任务独立启动，持续监测 Codex 窗口；Codex 暂时退出不应终止任务。

排查顺序：检查任务执行路径及最后结果，再检查 `supervisor-status.json` 的时间、进程、widgetRunning，最后核对 `presence.json` 的新鲜度与 visible。启动器错误在本机 `update-diagnostic.txt`，任务修改前的 XML 备份仅在本机状态目录。不要公开真实配置、任务 XML 或诊断中的机器路径。

新增 `startup-directory.test.ps1` 覆盖 OS 实际路径、旧任务迁移、系统工作目录、严格参数和未知目录拒绝；安装/更新回归保留账户及路径绑定检查。实机验收必须由计划任务启动后同时出现新鲜后台心跳、GUI 心跳与可见挂件；未做注销或关闭 Codex 的测试，不宣称已完成这些测试。

## Windows 测试版发布（1.4.0）

首次维护版 Release 标签为 `mikotoshire-v1.4.0-preview.1`，内部严格三段版本为 1.4.0，标记 Pre-release。发布包只含 Windows，不运行上游双平台自动发布或重写已发标签/安装包。插件界面标明维护者与上游出处，内部市场、插件、MCP、状态目录标识为兼容已有个人安装暂时保留；因此不支持与原版并存，安装器身份检查必须保留。

`python scripts/build-release.py` 按 `runtime/install-files.json` 与固定附加清单，从 `git cat-file` 读取已提交 blob。禁止从工作区读取待打包内容，特别是 skip-worktree 的本机 `.mcp.json`。`scripts/release_audit.py` 检查所有已提交文件的敏感文件名、凭据特征、机器目录、PNG 文本/EXIF 元数据、DLL 哈希，并检查最终包的 MCP 便携模板、版本和更新禁用策略。仅允许已验证 Aether DLL，不临时下载二进制。

输出 ZIP、SHA256SUMS、RELEASE-AUDIT 摘要和发布说明；包内 SOURCE.json 指明源码提交，FILE-MANIFEST.json 记录文件哈希。ZIP 时间固定，重复构建应逐字节相同。`test_release.py` 使用虚构 Git 仓库和受污染的工作区验证不会打包机器配置；已提交的坏模板则拒绝打包。扫描结果仅输出文件名/规则，不回显潜在秘密。

发布前运行 Node、Windows 关键回归、Python 打包测试和压缩包内容检查；从压缩包解压的副本检查必需文件、版本、PowerShell 语法和 Node 模块。记录验证限制，不声称未经执行的新设备完整安装已通过。保持安装配置、账户数据、偏好、额度和真实诊断本地保存。发布只上传本次审查的 ZIP、SHA256SUMS、RELEASE-AUDIT；不上传工作目录或 Git bundle。浏览器文件上传受限时，允许经本次显式发布授权手动触发 GitHub Actions：只在本仓库 main、通过 Windows 验证后，以短期仓库令牌构建并创建新的预发布；不覆盖已有标签或资产。

## AI 来源声明（1.4.1）

维护版相对上游的修改与新增/改写文档均由 AI 生成，未经充分验证或独立人工审查。统一声明见 AI-NOTICE.md；显示于主页、插件信息、安装输出、设置菜单和发布说明，并随包分发。构建器拒绝缺少声明的发行包，SOURCE.json 与 RELEASE-AUDIT.json 明确 AI 范围及 insufficiently_validated。旧 Release 说明补充声明，但不覆盖旧标签或附件；1.4.1 提供内置声明的新包。声明不取代测试记录、不改变许可，也不代表上游或第三方库由 AI 生成。
