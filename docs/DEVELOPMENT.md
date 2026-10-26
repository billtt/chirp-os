# 开发指南 / Development

> **Windows 构建约定（2026-10-26）：** 本地测试与正式发行都默认使用精简的 `-setup.exe` 引导安装包。应用不内置 .NET；安装器检测运行环境，缺少时下载并运行微软安装器。不要再把裸 EXE 或自包含 ZIP 作为本地测试默认入口。构建、发布和旧版更新兼容约定见下文，适用于所有机器及 CI。
> **Windows builds:** Use the lightweight bootstrap installer for both local tests and releases. Do not revert local builds to a bare EXE or a self-contained ZIP. See the build and release requirements below.

## 项目结构 / Layout

| 目录 / Directory | 内容 / Contents |
| --- | --- |
| `platforms/macos/` | Swift / AppKit 应用与测试 / App and tests |
| `platforms/windows/` | C# / WinForms / Win32 应用与测试 / App and tests |
| `shared/` | 鸟种定义、像素图集和图标 / Species, atlases, and icon |
| `Assets/` | 文档图片与图标源图 / Documentation images and icon source |
| `scripts/` | 构建与验证脚本 / Build and verification scripts |
| `dist/` | 本地构建输出，不提交 / Local build outputs, ignored by Git |

## macOS

需要 macOS 13+ 和 Swift Command Line Tools。构建使用本机架构。
Requires macOS 13+ and Swift Command Line Tools. Builds target the host architecture.

```bash
./scripts/build.sh
./scripts/run.sh
./scripts/test.sh
```

应用 / App: `dist/ChirpOS.app`。可用 `CHIRPOS_APP_PATH` 指定独立开发包位置，避免覆盖下载的已签名版本。 / Set `CHIRPOS_APP_PATH` to build to a separate development app path.

桌面检查需要已登录的图形会话 / Desktop checks require an unlocked graphical session:

```bash
./scripts/verify-desktop.sh
./scripts/verify-population.sh
./scripts/verify-settings.sh
.build/release/Birding --verify-birds .build/bird-check
```

## Windows

需要 .NET 10 SDK 和 NSIS 3。可在 Windows、macOS 或 Linux 上构建；NSIS 生成的安装引导本身不依赖现代 .NET。Mac 安装编译器：`brew install makensis`；Windows 安装 NSIS 3；Linux 安装 `nsis`。可用 `CHIRPOS_MAKENSIS` 指定编译器路径。
Requires .NET 10 SDK and NSIS 3. Cross-compilation is supported. Set `CHIRPOS_MAKENSIS` if the compiler is not on PATH (the PowerShell script also checks the standard NSIS installation directory).

```powershell
# Windows PowerShell
./scripts/build-windows.ps1 -Runtime win-x64
# Windows ARM64
./scripts/build-windows.ps1 -Runtime win-arm64
```

```bash
# macOS / Linux
./scripts/build-windows.sh win-arm64 win-x64
```

输出 / Outputs:

- `dist/releases/ChirpOS-<version>-win-<arch>-setup.exe`：默认安装和本地测试入口，自动检测并引导安装 .NET 10 Desktop Runtime。
- `dist/releases/ChirpOS-<version>-win-<arch>-framework-dependent.zip`：新版自动更新载荷，不是首次安装入口。
- `dist/windows/<runtime>/ChirpOS.exe`：不含运行时的中间产物，需要已安装对应架构的桌面运行时。

用 `CHIRPOS_PACKAGE_DIR` 指定独立测试输出目录；`CHIRPOS_SHARE_DIR` 可将生成的安装器复制到虚拟机共享目录。共享目录现在复制带版本和架构的 `-setup.exe`，不再复制裸 `ChirpOS.exe`。正式发布也不再生成自包含兼容包。
Set `CHIRPOS_PACKAGE_DIR` for isolated test output and `CHIRPOS_SHARE_DIR` to copy installers to a VM share. The shared artifact is the installer, not the raw app executable.

安装器默认安装到 `%LOCALAPPDATA%\Programs\ChirpOS`，创建开始菜单入口及卸载入口；已有登录启动项会更新到新位置。安装前须退出旧版。设置和观鸟记录保留在 `%LOCALAPPDATA%\ChirpOS`，卸载也不会删除。旧便携 EXE 不会被删除，之后从新快捷方式启动。

核心测试 / Core tests:

```bash
dotnet run --project platforms/windows/ChirpOS.Tests -c Release
```

Windows 桌面检查 / Windows desktop checks: run `ChirpOS.exe --self-test`, or double-click `Verify-Windows.cmd` in the build directory. Results are saved to `%LOCALAPPDATA%\ChirpOS\self-test.json`.

## 美术 / Artwork

像素绘制定义位于 `platforms/macos/Sources/Birding/PixelArt.swift` 、`SpeciesArt.swift` 和 `DetailedBirdArt.swift`。修改后在 Mac 上导出共用资源，并提交 `shared/` 的变化。
Artwork is defined in `platforms/macos/Sources/Birding/PixelArt.swift` `SpeciesArt.swift` and `DetailedBirdArt.swift`. Export on Mac after editing, and commit the updated `shared/` assets.

```bash
./scripts/export-shared.sh
./scripts/preview-species.sh
```

鸟种外形、行为参考及配置兼容说明见 [Bird design](BIRD-DESIGN.md)。
See [Bird design](BIRD-DESIGN.md) for appearance, behavior references and configuration compatibility.

## 自动更新 / Automatic updates

更新流程、发布约定、安全边界和测试入口见 [自动更新说明](AUTO-UPDATE.md)。
See [Automatic updates](AUTO-UPDATE.md) for the protocol, release requirements and verification.

## 本地数据 / Local data

- macOS: `~/Library/Application Support/Birding/settings.json`
- Windows: `%LOCALAPPDATA%\ChirpOS\settings.json`; diagnostics and errors are stored alongside it.

设置与构建缓存分开存储，清理缓存不会重置偏好。
Settings are separate from build caches; removing caches does not reset preferences.

## macOS 发布 / macOS releases

正式发布统一使用以下入口，默认完成 Developer ID 签名（含时间戳和 Hardened Runtime）、Apple 公证、票据附加及 Gatekeeper 验证，全部成功后才生成发布 ZIP：
Use the release entry point for Developer ID signing, timestamping, Hardened Runtime, notarization, stapling, and Gatekeeper validation. A release ZIP is produced only after all steps succeed.

```bash
mkdir -p .local
cp scripts/macos-release.env.example .local/macos-release.env
chmod 600 .local/macos-release.env
# Fill in your own signing identity and Keychain profile name in the local file.
./scripts/release-macos.sh --check
./scripts/release-macos.sh
```

本地文件被 Git 忽略，仅存放签名身份和公证配置的名称；证书私钥、密码和 API 凭据保留在钥匙串中。每台机器单独配置。可用 `CHIRPOS_RELEASE_CONFIG` 指定其他本地文件；非空环境变量优先于文件配置。
The ignored local file stores names only. Private keys and credentials remain in Keychain. Configure each machine separately. `CHIRPOS_RELEASE_CONFIG` selects another local file; nonempty environment variables override file values.

配置缺失或预检查失败时，交互式终端会询问是否使用临时签名（默认否）。无交互环境直接失败，不会自动降级。临时测试包可显式使用 `--ad-hoc`，写入 `dist/adhoc/`，文件名带 `-adhoc`，不经过公证。正式签名或公证执行失败会直接停止。`scripts/build.sh` 是本地开发构建，不代替发布入口。
Missing or unusable credentials prompt for an ad-hoc fallback in an interactive terminal (default: no). Noninteractive runs fail closed. Explicit `--ad-hoc` creates an unnotarized test ZIP under `dist/adhoc/`, with an `-adhoc` suffix. Signing/notarization failures stop the release. `scripts/build.sh` is a development build, not the release entry point.

GitHub Actions uses repository secrets: `MACOS_SIGNING_IDENTITY`, `MACOS_NOTARY_PROFILE`, `MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_API_KEY_P8`, `APPLE_API_KEY_ID`, and `APPLE_API_ISSUER_ID`. Missing credentials stop the workflow. Local Keychain settings are not automatically available to CI.

## Windows 发布 / Windows releases

### 安装流程 / Installer behavior

Windows 正式发布和本地测试统一使用 `ChirpOS-<version>-win-<arch>-setup.exe`，分别提供 ARM64 和 x64。应用使用 `SelfContained=false` 单文件发布，NSIS 引导程序可在未安装现代 .NET 的机器上启动。

安装器检查相应架构的 .NET 10.0 桌面及核心运行时（兼容补丁版；排除预览版）。缺少时征得用户确认，从 `platforms/windows/installer/runtime.json` 固定的微软 HTTPS 地址下载，验证 SHA-512 和微软 Authenticode 签名，再启动微软安装器；系统级运行时安装会请求管理员权限。下载、校验、取消或安装失败会停止替换啾啾并提供重试。微软要求重启时，提示重启后重新运行安装包，不继续启动尚未准备好的应用。

运行时清单来自微软官方 `releases.json`，包含版本、架构、下载地址和 SHA-512。发布前检查是否需要更新清单；下载版本必须满足 `.csproj` 的 `RuntimeFrameworkVersion`（当前 10.0.0）。首次缺少环境时仍需额外下载运行时，应用安装包自身约 2 MB，实际以构建输出为准。

### 自动更新兼容 / Update compatibility

- 精简版只选择 `ChirpOS-<version>-win-<arch>-framework-dependent.zip`；后续应用更新不重复下载运行时。
- 按 2026-10-26 的决定，不再构建或发布自包含兼容包。每个架构只有安装器和精简更新 ZIP 两种产物。
- 旧自包含版只认识 `ChirpOS-<version>-win-<arch>.zip`，因此不能自动迁移到新版；旧用户需手动运行一次新安装器。发布说明须明确告知这一点，不能把旧名 ZIP 偷换成依赖运行时的 EXE。
- 本地和正式构建共用 `./scripts/build-windows.sh win-arm64 win-x64` 或 `./scripts/build-windows.ps1 -Runtime win-x64`（ARM64 同理）。
- GitHub Actions 配置 NSIS 编译器、Windows PowerShell 5.1 引导测试，只上传 Windows 安装器、精简更新 ZIP 及校验和；版本继续来自 `.csproj`。见 [自动更新发布约定](AUTO-UPDATE.md#发布约定)。

### 验证与发布检查 / Verification

```powershell
# Windows PowerShell 5.1，或其他平台上的 pwsh
./scripts/test-windows-installer.ps1
```

脚本验证运行时版本选择、桌面组件要求、架构、下载及安装失败、摘要及签名拒绝、取消和需要重启等分支；外部操作使用模拟，不会安装运行时。PowerShell 构建入口自动运行它，Shell 入口在存在 `pwsh` 时运行；CI 使用真实 Windows PowerShell 5.1 运行。核心测试另外验证新旧更新资产选择隔离。

正式发布前仍须在 Windows x64 / ARM64 上实测：无运行时的干净环境、已有兼容运行时、错误版本 / 架构、网络失败、UAC 取消、重试、旧版升级、卸载及记录保留。自动更新须验证正常替换、启动回执和失败回滚。跨平台编译及模拟测试不等于完成这些实机验收。

发布时同步更新根目录 `README.md` 下载链接和对应版本说明，默认指向安装器；历史发布的 ZIP 说明保留原有实际行为。当前开发测试包仍使用项目版本号，不自动创建标签或上传 Release。

## 观鸟模式 / Life List

观鸟记录独立保存在设置文件旁的 `life-list.json`，以稳定的鸟种 ID 保存计数和首次记录时间；关闭功能不会清除记录。开启时运行默认鸟种配置，不改写用户的概率、锁定项或体型动作配置。现有个体立即失去拍摄资格并飞离；只有开启之后入场的个体可记录，每次到访最多一次。

首次启动或旧记录缺少 `introductionVersion` 时，一次性开启观鸟模式并保存引导标记，不改动已有鸟种记录。后续启动尊重用户开关。菜单入口随模式切换为 Life List 或图鉴，窗口不再提供双视图切换。

The Life List lives in `life-list.json` beside settings. It stores stable species IDs, counts, first observation timestamps and the recording switch independently of bird preferences. Observation mode uses bundled species defaults without overwriting custom preferences. Existing birds depart and become immediately ineligible; only new arrivals can be recorded, once per visit.

macOS 隔离验证（不读写个人记录，同时输出图鉴截图）：

```bash
.build/debug/Birding --verify-observations .build/observation-check
```

核心测试覆盖首次记录保留、跨次到访计数、模式切换失效、持久化及损坏文件保护。桌面手动检查还应覆盖取景框、点击不穿透、不抢焦点、多屏边界、拖动穿过鸟、遮挡，以及 Windows 的实际桌面表现。
