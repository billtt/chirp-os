# 啾啾 ChirpOS · Windows

[下载 / Download](https://github.com/billtt/chirp-os/releases/latest) · [项目介绍 / About ChirpOS](https://github.com/billtt/chirp-os#readme) · [开发指南 / Development](https://github.com/billtt/chirp-os/blob/main/docs/DEVELOPMENT.md)

## 中文

当前开发构建与下一次发布使用对应架构的 `ChirpOS-<版本>-win-<架构>-setup.exe`。本地测试也使用安装包。运行安装包后，若缺少 .NET 10 桌面运行时，会提示并自动下载微软安装器；这一步需要联网，可能请求管理员权限。已有兼容运行时时直接安装啾啾。

- **x64**：Intel / AMD 64 位 Windows 10/11。
- **ARM64**：Windows 11 ARM64，包括 Apple Silicon 上的 UTM。

右键点击系统托盘中的小鸟图标，可以设置鸟群数量、鸟种概率、体型与动作，切换语言，启用随系统启动或退出。图标可能位于隐藏图标区域。

安装前先从托盘退出旧版。应用安装在 `%LOCALAPPDATA%\Programs\ChirpOS`，从开始菜单打开；已有登录启动设置会指向新位置。安装完成页也可勾选启动应用。设置和观鸟记录继续保存在 `%LOCALAPPDATA%\ChirpOS`，安装和卸载不会删除这些记录。

若微软安装器要求重启，请重启 Windows 后再运行啾啾安装包。网络失败、取消权限或安装失败时，可查看安装详情并重试。`-framework-dependent.zip` 供新版自动更新器使用，不是首次安装入口；不再提供旧格式自包含兼容包，旧版用户需手动运行一次新安装器后才能继续自动更新。已经发布的 v0.7.0 及以前 ZIP 仍是无需另装 .NET 的自包含版本。

## English

For current development builds and the next release, run `ChirpOS-<version>-win-<architecture>-setup.exe`. Use this installer for local tests too. Setup detects .NET 10 Desktop Runtime and, if missing, offers to download and run Microsoft's installer. That step requires internet access and may request administrator permission. Compatible existing runtimes are reused.

- **x64:** Intel/AMD Windows 10/11.
- **ARM64:** Windows 11 ARM64, including UTM on Apple Silicon.

Right-click the bird in the system tray to configure population, species probabilities, size and behavior, language, launch at login, or quit. The icon may be in the hidden-icons area.

Quit the old app from its tray menu first. ChirpOS installs to `%LOCALAPPDATA%\Programs\ChirpOS` with a Start menu shortcut; an existing launch-at-login setting is redirected to this location. You can also select Launch on the final setup page. Settings and Life List data remain in `%LOCALAPPDATA%\ChirpOS`, including after uninstallation.

If Microsoft's installer requires a restart, restart Windows and run ChirpOS Setup again. On network, permission or installation failure, inspect the setup details and retry. The `-framework-dependent.zip` is for the new automatic updater, not first-time installation. Self-contained compatibility ZIPs are no longer produced; users of older builds must run the new installer once to migrate to the lightweight update channel. Previously published v0.7.0 and earlier ZIPs are still self-contained.
