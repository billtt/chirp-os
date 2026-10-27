# 共用资源 / Shared resources

`species.json` 保存 120 种鸟的体长、动作参数和初始出现频率；`art/` 为每种鸟的 34 帧横向 PNG 图集，帧顺序、48 点逻辑画布、各鸟种原生像素尺寸和足部锚点见 `art/manifest.json`。`AppIcon.ico` 是 Windows 多尺寸图标。它们已纳入版本控制，Windows 构建不需要 Swift 或 macOS。

目前像素绘图的权威定义仍在 `platforms/macos/Sources/Birding/PixelArt.swift`、`SpeciesArt.swift`、`DetailedBirdArt.swift`、`ExpansionBirdArt.swift`、`FeaturedBirdArt.swift` 和 `BirdPlumage.swift`，鸟种定义在 `platforms/macos/Sources/BirdingCore/Resources/species.json`。修改后在 Mac 执行 `./scripts/export-shared.sh`，一起提交生成结果。不要手工修改图集。macOS 运行时由同一份定义生成纹理；Windows 将导出的图集嵌入 exe 并在启动时缓存。

`species.json` contains species size, animation parameters, and initial frequencies. Each PNG in `art/` holds 34 horizontal frames (48-unit logical coordinates, species-dependent pixel density); see `art/manifest.json` for frame order and foot anchor. `AppIcon.ico` is the multi-size Windows icon. These files are checked in so Windows builds need neither Swift nor macOS.

The authoritative drawings currently remain in the macOS `PixelArt.swift`, `SpeciesArt.swift`, `DetailedBirdArt.swift`, `ExpansionBirdArt.swift`, `FeaturedBirdArt.swift` and `BirdPlumage.swift` files, with definitions in `BirdingCore/Resources/species.json`. After editing, run `./scripts/export-shared.sh` on macOS and commit the regenerated resources. macOS generates textures from these definitions; Windows embeds and caches the exported atlas images. Behavioral logic has native implementations on each platform, with regression tests for shared invariants.

默认权重参考全国常见鸟及区域分布进行人工分级，不是全国实测出现概率。扩充鸟种的代表羽色、鉴别特征与选用的动作见 `docs/species-expansion-100.json` 和 `docs/species-expansion-120.json`。既有自定义设置升级时保留；观鸟模式及恢复默认使用新的全国权重。
