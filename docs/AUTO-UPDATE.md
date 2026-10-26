# 自动更新 / Automatic updates

macOS 和 Windows 从 `billtt/chirp-os` 的 GitHub 正式 Release 检查更新。启动后约 15 秒执行首次到期检查，之后每小时检查一次；下次检查时间跨重启保存，睡眠错过的检查在恢复后一分钟内执行。网络失败按 5、15、60 分钟退避重试，后台失败不弹确认窗口。菜单提供“检查更新”。

检测到更高版本后，后台下载对应进程架构的 ZIP（macOS arm64/x86_64、Windows arm64/x64）。草稿、预发布、同版本及降级均跳过。下载和校验完成才显示一次通知：macOS 使用菜单栏下方不抢焦点的气泡，不请求系统通知权限；Windows 使用托盘通知。点击才展示版本说明及“安装并重启 / 晚点再说”确认框。通知显示前会持久化已提醒版本，因此忽略、选择晚点再说、退出或重启应用均不会重复提醒同一版本。红点与安装菜单入口保留，新版本可再次提醒。Windows 勿扰模式可能抑制气泡，此时仍可使用红点和菜单。

## 下载与安装校验

- 仅访问固定 GitHub 仓库的 HTTPS Release API，并要求精确匹配的官方资产路径；下载重定向限制为 GitHub 的 HTTPS 资产主机。
- 必须存在 GitHub 提供的 SHA-256 digest，核对声明的大小与完整文件摘要；缺少摘要时拒绝安装，不降级为仅检查文件名。GitHub 从 2025 年起为上传资产生成摘要，当前 v0.5.0 的三种平台 ZIP 已具备该字段。[GitHub 说明](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/)
- ZIP 不超过 512 MiB，解压声明总量不超过 1 GiB；检查磁盘空间、路径穿越、重复条目和符号链接。macOS 同时检查中央目录和本地文件名；Windows 只提取根目录的 `ChirpOS.exe`。
- macOS 校验 Bundle ID、版本、最低系统版本、CPU 架构、与现有应用相同的 Developer ID Team，以及 `codesign --deep --strict` 和 Gatekeeper `spctl`。临时签名开发包不执行自动安装；从磁盘映像、App Translocation 或不可写目录运行时保留当前应用并说明需要移动安装位置。
- Windows 校验 PE 架构、产品名及文件版本，并在安装助手中重新解压已校验的 ZIP、对比待替换 EXE 的 SHA-256。当前 Windows 发行版尚无发布者签名，来源保证依赖固定仓库的 HTTPS 元数据与 SHA-256；没有声称提供 Authenticode 验证。

## 事务、确认与恢复

1. 用户确认后重新校验下载文件并生成同目录候选包，确保不可写目录、空间不足及校验失败发生在退出应用之前。
2. 从独立临时目录启动安装助手。助手校验完成后发出就绪标记，主应用才退出。助手启动超时会写入取消标记，防止用户继续使用后又发生延迟安装。
3. macOS 使用同文件系统的原子目录交换；Windows 使用 `File.Replace`，并为退出后短暂存在的防病毒文件句柄做有限重试。原路径不变，启动项继续有效，设置目录不参与替换。
4. 新版启动后，UI 事件循环正常运行约 10 秒才写入包含事务 ID、版本和进程 ID 的健康回执。助手等待上限为 90 秒；启动失败、提前退出或缺少回执时恢复旧版并重新启动旧版。
5. 收到匹配回执后才删除旧版及下载 ZIP、解压内容、事务文件。Windows 正在执行的安装助手不能立即删除，由新应用在助手退出后清理；清理被占用时短暂重试，并在下次启动继续。清理失败不回滚已经正常运行的新版本。
6. 下次正常启动会清理替换前中断的候选文件，并识别当前版本的未完成事务、补写健康回执；仅清理归属于本应用路径的成功事务。手动安装新版本后清理过期的待安装缓存。没有活动事务的孤立下载目录在七天后清理，待安装版本不清理。

检查/下载、确认窗口和安装互斥，避免下载较新版本时删除正在安装的旧缓存。已有鸟种、概率、语言和启动设置保持原样。日志与状态分别位于 `~/Library/Application Support/Birding/Updates` 和 `%LOCALAPPDATA%\ChirpOS\Updates`；Windows 错误也写入现有 `errors.log`。版本说明作为纯文本展示，不执行其中的 HTML 或命令。

## 发布约定

Windows 本地测试与正式发布现在默认使用精简的 `ChirpOS-<x.y.z>-win-<arch>-setup.exe`。安装器检测并引导安装 .NET 10 Desktop Runtime；构建入口及验证要求见 [开发指南](DEVELOPMENT.md#windows-发布--windows-releases)。

新版精简应用只选择 `ChirpOS-<x.y.z>-win-<arch>-framework-dependent.zip`，根目录包含 `ChirpOS.exe`；更新器直接替换应用，不执行安装器。按 2026-10-26 的决定，每个 Windows 架构只发布安装器和精简更新 ZIP，不再生成旧名自包含兼容包。旧自包含版只认识 `ChirpOS-<x.y.z>-win-<arch>.zip`，因此需要用户手动安装一次新版才能迁移；发布说明必须告知这一要求。不能把轻量 EXE 放进旧名 ZIP 让旧更新器安装，否则缺少运行时的机器会无法启动。macOS 仍使用 `ChirpOS-<x.y.z>-macOS-<arch>.zip`。

三段数字版本须与 macOS Info.plist / Windows 文件版本一致。macOS 必须经过现有签名、公证流程，同一应用继续使用同一开发者 Team。发布说明来自 Release body。先上传完整资产，再将草稿设为正式版本；现有 GitHub Actions 已按此顺序发布，并附带 SHA256SUMS.txt。工作流已将 Windows 安装器及精简更新 ZIP 纳入上传和校验和。

首次获得此功能需要手动安装包含更新器的正式版本；此前版本没有检查更新的代码。本次实现不修改版本号、不创建标签、不发布 Release。

## 验证

- `swift test`：数字版本顺序、版本/架构筛选、摘要与来源拒绝、同大小损坏/截断文件、ZIP 路径与符号链接、每小时调度与退避、提醒跨重启保存、原子替换、旧版保留、回滚与清理。
- `.build/tools/dotnet/dotnet run --project platforms/windows/ChirpOS.Tests -c Release`：对应 Windows 核心检查，包括 ZIP 提取及 PE 架构。
- `.build/debug/Birding --verify-updates .build/update-ui-check`：本地模拟气泡、红点、菜单、带说明的确认窗口、取消后保留入口及同版本不再提醒；不会下载或安装模拟版本。
- `.build/debug/Birding --verify-update-archive <zip>`：只检查真实 macOS ZIP 结构，不执行安装。

本地已使用当前正式 macOS ZIP 检查大小、SHA-256、归档结构、签名和 Gatekeeper。跨正式版本的完整下载→退出→替换→启动验收仍应在下一次发布前使用两个正式签名版本执行；Windows 需要在对应系统上验证托盘通知及真实进程替换。

## 隐藏调试入口 / Hidden debug controls

在设置窗口内容区右上角的空白区域（约 40 × 44 点）双击两次，两次双击间隔不超过 3 秒，即可在“体型与动作”右侧显示“调试”。入口仅对当前设置窗口生效，不写入偏好设置。

点击“调试 → 模拟有更新”，会通过真实通知、图标红点、安装菜单及确认框展示模拟版本 99.0.0。选择“晚点再说”保留模拟提示；选择“安装并重启”结束模拟并恢复原先的待更新状态，不下载、不安装、不退出。可重复触发预览。更新检查、下载或确认正在进行时，需要稍后再试；模拟期间暂停新检查，不修改真实缓存或已提醒版本记录。

Double-click twice within three seconds in the blank upper-right corner of the settings content to reveal Debug beside Size & behavior. Choose Simulate update to preview the real notification, badge, menu and confirmation dialog. Later keeps the preview; Install and restart ends it and restores the previous pending update without downloading, installing or restarting. Debug visibility lasts for the current settings window only.
