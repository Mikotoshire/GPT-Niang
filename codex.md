# Codex 维护笔记

## 可调压缩曲线（2026-10-20，未发布）

AI 生成修改与文档，未经充分验证。入口 `重力与弹性 → 压缩曲线`，包含模型真实曲线预览和 `压缩减速强度` 滑条（1.5–3.0、步长 0.05、默认 1.6）。数值越大，压缩前段越快，随后越早放慢至末端零速；这是角色垂直形变的速度分配，不是角色窗口的下落速度。横轴为压缩阶段的归一化时间，纵轴为压缩进度。

采用三次 Hermite 多项式 `C(t)=s*t+(3-2s)*t²+(s-2)*t³`，Horner 形式只需几次乘加。`s∈[1.5,3]` 时 C 单调增加、C' 单调下降，起点斜率 s、终点斜率 0；无曲线反求、逐帧数值积分或新计时器。前一段飞行/释放形变也按同一 C(t) 收掉，保证合成后的垂直压缩速度由同一曲线控制；恢复段维持原半余弦及原有较长时序。

模型 `CompressionCurve` / `SetCompressionCurve` / `GetCompressionProgress`；偏好保存本机 `compressionCurve`，旧值缺失或非法时默认 1.6。每次真正撞地捕获当前曲线，调整只影响下次触底，避免中途跳帧。模型 Reset 保留设置。曲线不改变储能、碰撞损耗、反弹速度或落地时长；`动画速度` 仍控制总时长，Q 和转换效率仍控制幅度。菜单预览仅在打开菜单或设置变化时采样 25 个点，直接调用同一个 C# 模型方法，不进入逐帧渲染热路径。

回归 `compression-curve.test.ps1` 覆盖归一化曲线与实际垂直姿态的减速、端点/末端零速、可见差异、物理/时序独立、修改时不跳变、重置及生产偏好桥接。实际 WPF 菜单测试检查预览与标签联动。证据见 `docs/testing/compression-curve.tdd.md`。源码同步与 Release 仍分开执行。

## 能量转换与滑条分工（2026-10-20，未发布）

AI 生成修改与文档，未经充分验证。碰撞效率改为独立的 `能量转换效率`（0–85%，新装默认 40.96%），保存本机 `energyConversion`，模型 `SetEnergyConversion(percent)` / `EnergyConversion` 采用百分数，`EnergyRetention` 返回其除以 100 的比例。0 不储能反弹，最高档仍损耗能量；中途调节不改写当前已捕获的储能，下次撞击生效。

| 滑条 | 当前职责 | 审计处理 |
| --- | --- | --- |
| 重力强度 | 加速下落与滞空时间 | 保留，原功能有效 |
| 起跳能量 | 手动轻点/蓄力的起跳高度及最终停跳阈值 | 原“弹性势能”改名，内部 `elasticStrength` 保留；不再改变碰撞储能比例 |
| 能量转换效率 | 撞击能量保留比例，影响压缩与回弹速度 | 新增，避免与手动起跳重复 |
| 单点压缩程度 | 按压初段基础形变，普通/重力模式均有效 | 保留，不改变输入蓄力时间或能量 |
| Q弹程度 | 触底形变的外观幅度 | 保留，将硬限幅改为平滑限幅，避免高能量时拉动滑条没有变化 |
| 动画速度 | 触底压缩/恢复、松手恢复及起跳拉伸计时 | 保留，不缩放物理时间或按压蓄力阈值 |

旧配置缺少或非法 `energyConversion` 时，按 `min(85%,40.96%×旧 elasticStrength)` 迁移；显式 0 有效，保存后改动起跳能量不再影响转换效率。PowerShell 的 `Math.Min` 必须用 `85.0` 选 double 重载，避免小数变成整数；菜单该滑条不强制吸附整数刻度。旧重力/起跳字段各自捕获解析错误，避免阻断后续偏好加载。

平滑外观限幅为 `depth=0.72×a/(0.30+a)`，其中 `a=Q×SpringCompression`。任意正幅度均有连续响应，深度始终小于 72%；0 仍关闭形变。深度仅在撞击或 Q 调整时缓存，逐帧只乘缓动包络，不新增逐帧能量求解。底层储能与回弹不受外观限幅影响。

测试入口 `energy-controls.test.ps1` 覆盖转换上下限/非法值、零效率、与手动起跳分离、旧配置迁移、小数保留、高能量 Q 响应及最慢衰减组合；菜单、储能链和其余物理回归继续保留。证据见 `docs/testing/energy-controls.tdd.md`。只同步源码，不打包或发布 Release。

## 单点压缩程度（2026-10-20，未发布）

AI 生成修改与文档，未经充分验证。`重力与弹性 → 单点压缩程度` 范围 0–3×、步长 0.05、默认 1×，保存为本机 `tapCompression`；0 关闭基础按压形变，旧设置缺失或非法时保持默认值。

模型 `TapCompression` / `SetTapCompression` 仅乘初段形变：纵向 `1 − 0.12 × strength × ease − 0.4 × Charge`，横向 `1 + 0.05 × strength × ease + 0.4 × Charge`。220 ms 基础压缩时间、长按追加形变和蓄力/起跳能量保持独立。最大值满蓄力纵向不低于 0.24、横向不超过 1.55；中途调整立即更新按压姿态，不取消交互。

普通模式也应用该偏好。原有整体动画最多使用 1× 的形变，超过部分通过角色本地 `GravityScale` 补足，避免整个气泡超出原来的横向空间。切换重力模式时须清除两个缩放变换的 WPF 动画时钟，防止普通动画覆盖后续物理姿态。测试入口为 `tap-compression.test.ps1`、菜单测试及最大值 WPF 布局/切换测试；证据见 `docs/testing/tap-compression.tdd.md`。只同步源码，不创建新安装包或 Release。

## Q弹程度（触底形变，2026-10-20，未发布）

AI 生成修改与文档，未经充分验证。`重力与弹性 → Q弹程度` 为 0–3×、步长 0.05 的独立滑条，默认 1× 为标准强度，0 关闭触底形变。偏好保存在本机 `squishStrength`，旧配置缺少字段时取 1×，0 是有效值；非法或非有限值不覆盖默认值。

`GptGravityModel.ImpactSquish` / `SetImpactSquish` 控制触底外观倍率。当前采用单位质量的简化弹性能量链：`E撞=0.5v²`，`r=energyConversion/100`，`E弹=r×E撞`，逻辑峰值压缩 `x=sqrt(2E弹/k)`，峰值弹力 `F=kx`，其中艺术化刚度 `k=4000000`。显示深度为 `0.72×(Q×x)/(0.30+Q×x)`，横向增量为该深度的 `0.08/0.15`。不逐帧积分弹簧力；逻辑峰值与已有缓动包络相乘生成显示姿态，外观限幅不反向增加能量。能量转换效率越高，同样撞击的保留能量、压缩和后续反弹越大；Q 只缩放外观。按住与蓄力的设置独立；`Reset` 保留参数并清空储能。以上量是游戏化代理值，不代表真实材料单位。

真正触底后进入独立落地阶段：竖直位置和速度归零，按实际撞地前速度计算并暂存弹性能量；Aether 地面恢复系数置零，避免与储能重复回弹；经过 `0.18 + 0.08 × min(1,v/1200)` 秒压缩/恢复后，才以 `v↑=sqrt(2E弹)` 释放向上速度，并按当前可用高度限幅；释放后储能与峰值弹力归零。压缩占比 `sqrt(2)-1`，用可调三次 Hermite 曲线快入慢出；恢复用半余弦，起止速度为零、中间加速，时长约为压缩的 1.414 倍。两段在最大压缩处的形变量和速度连续；这是视觉缓动，不宣称完整软体动力学模拟。

触底时保留落地前的飞行/释放形变，并按同一条压缩曲线收掉，避免第一帧突然清除拉伸。恢复结束时先达到原形，再释放回弹；后续飞行拉伸以 80 ms SmoothStep 淡入，避免把向上速度立刻映射成拉伸而产生回正跳变。滑条只调幅度，0 倍也保留相同的落地时序与飞行拉伸的平滑收敛。期间继续由 Aether 推进水平滑动和地面摩擦，每次碰撞只削减一次水平速度；不把压缩的每个子步算作新碰撞。最终无需再弹起时也完成形变恢复后停稳。

重置、按住、开始拖动和可用高度变零均清除暂存能量、压缩和待反弹标记，防止取消后突然弹起。`FlingFrom` 的停止阈值同时计算向上/向下的初始竖直动能，避免贴近底部高速向下甩时被误判为低能量落地。物理仍按固定子步推进；没有增加另一个计时器或物理引擎。

回归 `impact-squish.test.ps1` 覆盖滑条、配置与独立性；`landing-cycle.test.ps1` 覆盖落地时序与取消；`landing-easing.test.ps1` 覆盖触底衔接、压缩减速、较长恢复、恢复变速、原形起跳和拉伸淡入。另有重力、WPF 镜像/脚底、惯性、近地接触及帧率回归。能量转换关联、高处落下的更强形变、安全上限、原形起跳以及受控能量保留由 `elastic-impact.test.ps1` 覆盖；该测试已接入 Windows 运行器。`collision-energy.test.ps1` 进一步验证能量保留比例、线性弹力/压缩、恢复后释放、清零、取消与逐次衰减；详见 `docs/testing/collision-energy.tdd.md`。TDD 证据位于 `docs/testing/`。这些功能尚未纳入既有 1.4.4 Release，旧标签和附件不移动或覆盖。

## 额度读取、缓存与有限重连（2026-10-20）

AI 生成修改与文档，未经充分验证。此变更纳入 1.4.4 独立测试版，旧版本标签及附件不替换。发布须绑定本机验收过的精确提交；升级与回退见 README。

- `readUsageWithRetry` 每轮最多两次连接，间隔 750 ms，共用 38 秒截止；单次上限 24 秒，第二次按剩余预算缩短。只对超时、连接关闭、初始化和账户/额度 RPC 读取失败重连，不对不支持的登录方式、缺失程序、无效窗口重试。每次通过新的只读 app-server 查询，保留原三种 RPC；不发送聊天或模型请求。
- `Show-Quota` 和窗口重新可见时，60 秒内成功缓存直接展示；刷新按钮可主动请求。获取中抑制重复点击，标记最多有效 40 秒；写入请求有 2 秒防抖。原有可见时约每分钟后台刷新保留。
- 成功完整快照与本轮查询状态分别处理。`refreshing`/`refreshStartedAt` 描述获取中，失败只更新错误、检查时间和 `queryOk`，不替换同账号完整窗口与 `observedAt`。标题直接显示 `↻` 或 `⚠`，详细状态见额度气泡悬停提示。
- 当前 worker 内已验证的旧数据，可在尚未重新确认身份的瞬时故障时带警告保留；确认不同账号、无身份或不支持的登录方式即清除。worker 启动不直接信任磁盘上的旧账号快照。保留旧值并不代表它仍是当前可用额度。
- `quota-diagnostics.jsonl` 增加白名单事件 `query_retry`，仅写失败类别，不保存原始错误、账号、凭据、额度或路径。故障不会触发无限立即重试；下一次用户操作或既有可见时心跳可发起新一轮有限查询。
- 回归与覆盖率证据：`docs/testing/quota-retry.tdd.md`。不要将测试沙箱无法启动 CLI 与本机后台的网络失败混为一谈。

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

用户当前要求：继续同步代码作为备份；不自动打包发行文件、创建发布标签或发布 Release，等用户明确要求发布。两类操作分别授权。

### 动画速度

AI 生成修改与文档，未经充分验证。重力与弹性菜单的 `动画速度` 为 0.25–3×、默认 1×，本机保存 `animationSpeed`。仅以倍率推进触底形变、松手恢复与起跳拉伸计时器；不缩放物理 dt 或按压/蓄力阈值。中途调整保留当前动画相位，重置模型保留设置。慢速触底停留更久，因此地面摩擦作用时间也更久；回弹仍使用碰撞时储存的引擎速度。设置不改变渲染目标帧率。

测试入口：`animation-speed.test.ps1`，与现有菜单、形变、物理回归及 Windows 测试运行器相连；证据见 `docs/testing/animation-speed.tdd.md`。

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

## 本地市场验证与干净包验收（1.4.2）

安装器的全局 `plugin list --json` 会枚举其他市场。改用 CLI 帮助中提供的 `plugin list --marketplace gpt-niang-local --json`，保留严格版本、installed/enabled 与唯一性检查。错误输出并行排空但不持久化；验证进程超时后清理。`installation-verification.json` 仅保留允许字段的最新一次摘要，失败也更新，避免旧成功记录误导排查；记录写入失败发出通用警告。

回归：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File gpt-niang-usage/tests/plugin-registration.test.ps1`。假 CLI 故意让未限定市场的命令等待，用于复现旧版超时；另覆盖错误输出管道、超时清理、非零退出、无效 JSON、禁用、版本不符、重复条目及诊断字段白名单。

发布前先提交并构建：`python scripts/build-release.py`，然后运行 `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/clean-install.integration.ps1 -Archive dist/gpt-niang-mikotoshire-v1.4.2-windows.zip`。该脚本验证 ZIP 清单后，只在临时副本改写环境绑定（状态目录、Startup、稳定代理、独立计划任务/互斥量及 CODEX_HOME）；使用真实安装和验证逻辑。实际创建任务和快捷方式、观察新鲜心跳及原生可见窗口、重装、卸载后按所有权清理。不会复制账号；不验证额度。需交互式 Windows 会话和已有 Codex/Node，本机隔离不能替代全新设备测试。

发布工作流的 tested_commit 必须等于实际验收的完整提交号；源码变化后重新构建并验收。此人为确认约束不构成独立审查或测试真实性证明。原版 1.4.1 资产不替换，以保留追溯。

## 1.4.2 后续完整 CI 修正（2026-10-19）

已发布提交的 release.yml 成功不等于 test.yml 全部成功。该提交 test.yml 的 Windows 作业在 managed-frames.test.ps1 测得 57.35 Hz 后失败，后续检查没有执行，不能称全部 CI 通过。补跑还发现入口测试使用了缺少重力模块/依赖的旧文件清单；现在从 install-files.json 构造隔离副本，明确排除本机生成的 .mcp.json，不复制用户状态。

帧率测试新增独立的 C# CompositionTarget.Rendering 供帧探针，分别输出 inputHz、renderHz、hardwareQualified。默认严格运行仍要求至少 100 帧且原 58 Hz 容差门槛；每步预算、实际位置变化、脚本通知频率和输入处理能力也继续检查。共享 CI 显式使用 -AllowLimitedCompositor：仅当供帧本身低于 58 Hz 时允许完成供帧跟踪功能测试，并输出 60-Hz hardware acceptance UNQUALIFIED 通知，不视为 60 Hz 性能验收。供帧足够而处理不足仍失败；本地严格模式与发布前硬件验证不得使用此开关。

发布工作流通过 workflow_call 复用完整 test.yml，并将 full-runtime 加入发布依赖；因此完整 Windows/macOS 作业失败会阻止发布。现有 1.4.2 标签和安装包不替换。本次仅修改测试、门禁及文档，不改变动画或安装运行时代码。后续发布前除干净 ZIP 验收外，还须在交互式 Windows 会话运行不带宽容开关的完整 run-windows-tests.ps1，并核对全部关联工作流结果。不得仅以某一个绿色 workflow 代表全部通过。

## 1.4.3 · CPU 预算与窗口等待分开记录

性能诊断 CI 的一次结果：inputHz=57.66、renderHz=56.20、meanStepMs=16.30、physicsMs=0.086、poseMs=0.033、placementMs=16.164。窗口移动占墙钟耗时的绝大部分。共享图形环境中的同步窗口调用可能等待合成，因此原来把墙钟 5 ms 当计算预算会误判；这不等于该 CI 已达到 60 Hz，也不能说明系统等待已被优化。

GptGravityRenderLoop 保留 MeanStepMs/MaxStepMs（墙钟），新增 MeanPhysicsMs/MeanPoseMs/MeanPlacementMs 与 GetThreadTimes 的 MeanCpuMs。CPU 查询失败标记不可用，测试失败，不以零值冒充成功。Start 重置所有累计量；GetThreadTimes 返回值只用于累计 CPU 时间，不保存线程身份、创建时间或账号资料。性能检查维持 5 ms 平均 CPU 预算，实际帧率另查，供帧不足只在显式 CI 开关下打印 UNQUALIFIED；本地严格验收不加开关。

测试的截止 DispatcherTimer 使用 Send 优先级，避免 Render 事件使后台优先级截止饿死。阶段测量在断言前打印，方便真实失败继续排查。数值测量和测试调整不等于动画算法加速。发布前核对所有工作流及精确提交的干净 ZIP 验收。

### 阻塞后集中到达的有效渲染帧

CI 的另一轮测得 inputHz=57.78、renderHz=53.83、meanCpuMs=0.994。发现限帧器按 Stopwatch 到达时间而非 RenderingTime 判断预算；同步窗口调用后，连续送达但 RenderingTime 不同的帧可能因到达间隔太近被误丢。修复只将 90 Hz 限帧预算改为渲染时间，物理 dt 仍为真实经过时间。

managed-frames.test.ps1 通过反射停止到达时钟，注入六个间隔 1/60 秒的 RenderingEventArgs。旧代码只能处理部分帧并失败，修复后六帧全部保留；之后另行执行真实 WPF 帧率测量。不要把注入帧的数量当实际显示器帧率。同步更新干净安装验收轮询，对心跳文件正在发布时的短暂读写/解析竞争按原 45 秒截止重试，其他异常继续抛出。

### 正常供帧抖动与持续预算

主分支复跑测得 inputHz=58.54、renderHz=57.57。继续定位出按固定相位补齐后仍可能误丢 25 ms/8.33 ms 交替、平均 60 Hz 的有效帧。新增七帧确定性回归在该实现失败后，将限帧改为容量两帧、按渲染时间补充的 90 Hz 令牌桶；物理仍用真实时间，不增加运动能量。另用 240 Hz 合成输入验证持续处理量仍约 90 Hz。合成输入测试不能当显示器实测。

发布前额外检查 test.yml 在 main push 事件、同一完整源码提交上的最新运行必须 success；不能以分支单次成功或发布器内部某个绿色作业代替。发布门禁已实际拦住一次完整 Windows 检查失败，publish 为 skipped，未生成新包。

### 输入观测去重

补充确定性测量回归：按 0/25/16.67/25/33.33/33.33 ms 顺序输入，仅四个唯一渲染时间。旧探针只与上次时间比较，会将非连续重复计数，导致源帧率虚高；新探针按完整渲染时间去重并取时间范围的 min/max，且在真实限帧循环启动后才开始采样。该修复针对观测准确性，不把真实掉帧从输出中删除；限制器自身仍有独立的六帧、七帧抖动及 240 Hz 上限回归。保留 CPU 预算和真实帧率检查。

### 强制终止后的恢复测试

发布验证又捕获已有 refresh-client 崩溃恢复用例在第二个 raw spawn 后 4 秒未观察到健康 PID，其他同提交 Node 运行通过。旧测试绕过了生产 requestRefresh 的重试管理器，直接假定首次替代进程必然取得命名管道并发布健康状态。测试改为经真实 requestRefresh 恢复，刻意让首次替代进程退出，再验证重试、健康所有者属于本测试、令牌变化及停机。使用已有可注入的 100 ms 重试/8 秒总截止来限制测试时间，不更改生产默认 5 秒重试/45 秒总截止，也不跳过用例。初始 worker 的 4 秒检查保留并在子进程提前退出时立即失败。

### 统一采样活动区间

供帧探针使用真实 C# 委托读取 CanObserveFrame，只在限帧循环启用且非重入期间统计外层 Rendering 回调；在 Start 前挂接、Stop 后解绑，使输入与处理计数使用同一个活动区间。避免把设置场景、开启/关闭及原生窗口调用中的内层布局回调计作可独立呈现的新帧。新增活动门控回归；不会每帧执行 PowerShell 委托。默认本机帧率门槛、CPU 预算、独立限帧回归都保留。

### 60 Hz 硬件资格与功能 CI

共享 CI 的输入常在 57～59 Hz，低于请求的 60 Hz。限定 CI 模式统一在 inputHz < 60 时标记 hardwareQualified=false / UNQUALIFIED；即便测值偶尔落在本机 58 Hz 容差之内，也不得把它宣称为 60 Hz 硬件验收通过。该模式仍要求输入跟踪比例、CPU 预算、真实位置变化及所有独立限帧/物理断言通过。默认本机模式保持原 58 Hz 测量容差与至少 100 帧要求，没有降低硬件性能目标。足够输入却处理不足继续失败。CI 功能通过与硬件性能验收是不同结论，发布说明须明确。

## Windows-only maintenance CI

AI-generated maintenance change; insufficiently validated. At the user's request, test.yml now runs only the Windows job. The reusable release gate still requires the complete Windows runtime, installer, WPF, Node and packaging checks. Upstream macOS sources and historical results remain for provenance; this fork publishes and maintains Windows only. Existing release tags and assets are unchanged.
