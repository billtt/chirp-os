# 鸟种设计 / Bird design

鸟种参数位于 `platforms/macos/Sources/BirdingCore/Resources/species.json`，通过 `scripts/export-shared.sh` 导出给 Windows。英文名称也由此提供，新增鸟种时同步 README 中唯一的中英文列表。

Species parameters and English names live in `platforms/macos/Sources/BirdingCore/Resources/species.json`. Export shared Windows assets with `scripts/export-shared.sh`, and update the single bilingual species table in README.

## 外形与体型 / Appearance and size

成年鸟代表体长采用幂函数缩放：`scale = (length / 19) ^ (log(2.5) / log(94 / 19))`，红耳鹎为 1×，苍鹭为 2.5×，所有鸟保持体长排序；这是适合桌面观赏的比例压缩，不是精确测量图。姿势、尾长和收颈会改变屏幕上的轮廓。白鹭对应 Little Egret；乌鸦采用大嘴乌鸦。红尾水鸲、绿头鸭、白眉姬鹟、红胁蓝尾鸲等采用成年雄鸟配色；池鹭使用繁殖羽，红嘴鸥使用非繁殖羽。出现概率是可调的游戏频率，不代表全国野外数量排名。

Adult lengths use the power curve `scale = (length / 19) ^ (log(2.5) / log(94 / 19))`: a 19 cm bulbul stays at 1× and a 94 cm Grey Heron becomes 2.5×, preserving size order. This is pixel-art approximation, not a measurement plate: posture, tails and folded necks affect the visible outline. “Egret” means Little Egret and “crow” means Large-billed Crow. Several sexually dimorphic species use adult male plumage; the pond heron uses breeding plumage and the gull non-breeding plumage. Configurable arrival probabilities are game frequencies, not nationwide abundance estimates.

鸟类素材由 `PixelArt.swift`、`SpeciesArt.swift` 和 `DetailedBirdArt.swift` 绘制；由原创轮廓与分羽细节直接栅格化为像素素材，大鸟使用更高分辨率，常规大小下保持约一个屏幕点的像素密度。两个平台共用导出的图集。动作时间线分别在 Swift/C# 的 `SpeciesBehavior`，修改时应保持一致。图集帧名来自 manifest；每种鸟的原生帧尺寸记录在 `frameSizes`，逻辑画布保持 48 点。

Art uses original anatomical paths and feather details, rasterized directly at species-specific resolutions to retain approximately one pixel per screen point at normal size, in `PixelArt.swift`, `SpeciesArt.swift` and `DetailedBirdArt.swift`. Both platforms use the same exported atlas. Keep the Swift and C# `SpeciesBehavior` timelines consistent. Frame names come from the manifest rather than a fixed atlas width.

## 行为 / Behavior

- 夜鹭：长时间静止守望，间隔伸颈、抖毛及短暂排泄动画；不留下永久污渍。/ Night heron: prolonged watch, occasional neck stretch, feather shake and brief dropping animation; no permanent stains.
- 大斑啄木鸟：优先选择未遮挡的窗口左右边缘，面朝窗口，尾部支撑，间歇啄击。/ Woodpecker: prefers exposed vertical edges, faces the window and braces with its tail for intermittent pecking.
- 红尾水鸲、红胁蓝尾鸲、黑卷尾：短促摆尾；猛禽：较慢的巡视；丘鹬：轻微摇摆；小型林鸟：较活跃的头部动作。/ Redstarts, bluetail and drongo flick their tails; raptors scan slowly, woodcock rocks gently and small woodland birds move more actively.
- 悬停识别只读取鼠标位置，命中可见非透明像素后连续计时 1 秒；遮挡、离开或换鸟都会重置。/ Hover identification samples pointer position, requires 1 second on visible opaque bird pixels, and resets on exit, occlusion or a different bird.

## 参考资料 / References

- [香港观鸟会：香港鸟类志 / HKBWS Avifauna](https://avifauna.hkbws.org.hk/) — species identification and plumage references.
- [夜鹭 / Black-crowned Night Heron](https://avifauna.hkbws.org.hk/species/0170/022700) and [白鹭 / Little Egret](https://avifauna.hkbws.org.hk/species/0170/023500).
- [央视网 / 科普中国：鸟中顶流夜师傅](https://kepu.cctv.cn/2026/02/26/ARTI4qPfpplKbXnyEvvRLW3k260226.shtml) — quiet lookout posture, folded neck, adult field marks and Chinese community nicknames.
- [Bilibili：夜鹭洗手液](https://www.bilibili.com/video/BV19fNkz6Eux/) — community animation inspiration, not a biological frequency estimate.
- [中国科学院昆明动物研究所：红尾水鸲](https://datacenter.kiz.ac.cn/DataBase/BirdDetail/741) — male blue-gray body and chestnut tail, approximately 13 cm.
- [RSPB: Great Spotted Woodpecker](https://www.rspb.org.uk/birds-and-wildlife/great-spotted-woodpecker) and [Grey Heron](https://www.rspb.org.uk/birds-and-wildlife/grey-heron) — characteristic shapes and adult size reference.

素材不复制参考网站图片。动作周期是适合桌面观赏的设计值，并非野外行为频率。

Artwork does not copy source photographs. Animation timings are designed for desktop viewing rather than field-measured behavior frequencies.

- [Heron Conservation: Little Egret](https://heronconservation.org/herons-of-the-world/list/little-egret/) and [Grey Heron](https://heronconservation.org/herons-of-the-world/list/grey-heron/) — slender necks, leg proportions and flight plumage.

## 43 种鸟逐项检查记录（2026-10-20）

所有鸟种现在统一使用 `DetailedBirdArt` 的逐鸟种身体、头部和尾部比例；旧像素绘制定义保留，当前鸟种与应用图标均使用更新后的鸟形。站姿脚底仍固定在逻辑坐标 `(29,39)` 附近，飞行、降落与窗口遮挡沿用原有定位方式。桌面表现只模拟能够在窗口边缘成立的习性，不模拟水面、猎物或声音。

| 鸟种 | 外形辨识重点 | 桌面习性动作 |
| --- | --- | --- |
| 红耳鹎 | 高黑冠、白颊红耳斑、红臀 | 仰头开嘴与轻跳 |
| 麻雀 | 圆头栗帽、黑颊斑黑喉、短尾、圆翅 | 快速低头点啄与连续小跳 |
| 白头鹎 | 白色后头斑、黑头、橄榄背翼、浅腹 | 抬头巡视与轻跳 |
| 珠颈斑鸠 | 丰满粉胸、小头、黑白点状颈斑、长尾 | 缓慢前伸点头 |
| 乌鸫 | 黑体、黄嘴黄眼圈、较厚胸与长尾 | 低头觅食 |
| 鹊鸲 | 黑白对比羽色、白翼斑与白尾缘 | 显著翘尾，配合小跳 |
| 棕背伯劳 | 黑眼罩、灰头、棕背、极长尾 | 长间隔缓慢巡视 |
| 夜鹭 | 粗壮身体、收颈、黑背红眼、细白饰羽 | 保留长时间守望、伸颈、抖羽与短暂排泄 |
| 红尾水鸲 | 圆头蓝灰身体、栗红短尾 | 快速抬尾再收回 |
| 白鹭 | 纤细白颈、黑腿黄脚、白饰羽 | 抬起一脚、向前探颈 |
| 苍鹭 | 高挑灰体、白头黑眉、颈部纵纹 | 较长静止间隔，缓慢抬头巡视 |
| 红隼 | 灰头、棕红斑背、窄体长尾及黑尾端 | 短促抬头观察，尖翅拍动 |
| 游隼 | 粗壮胸部、深色髭纹、腹部横斑 | 较慢警戒抬头，尖翅飞行 |
| 黑鸢 | 浅褐头、叉尾、宽展翼 | 长间隔巡视、浅幅展翼滑翔 |
| 普通鵟 | 厚实身体、短尾、浅胸深腹斑 | 更慢巡视、宽圆翼滑翔 |
| 喜鹊 | 黑白肩腹、蓝色光泽长尾 | 摆动长尾、轻跳 |
| 灰喜鹊 | 黑帽、浅腹、蓝灰长尾与翼 | 较快摆尾、小跳 |
| 大嘴乌鸦 | 厚重身体、大头粗嘴、较短尾 | 前伸点头，较长休息 |
| 戴胜 | 扇形黑端冠羽、弯嘴、黑白翼带 | 俯身探食 |
| 家燕 | 纤细身体、红喉、深叉尾、窄尖翼 | 短促张翼整理 |
| 绿头鸭 | 横卧宽体、绿头白颈环、栗胸、蓝翼镜、蹼足 | 低头探食与理羽 |
| 噪鹃 | 细长黑体、长尾、红眼浅嘴 | 仰头开嘴的鸣叫姿势（无音效） |
| 暗绿绣眼鸟 | 圆头、完整白眼圈、橄榄背黄喉 | 向上探看、小跳 |
| 红嘴鸥 | 白头耳斑、红嘴、浅灰长翼 | 前伸点头，适中的停顿 |
| 中杓鹬 | 褐背纹理、头顶纵纹、长下弯嘴 | 慢速向下探食 |
| 斑鱼狗 | 大头冠羽、长直嘴、黑白胸带斑纹、短尾 | 分段低头瞄看 |
| 丘鹬 | 矮胖体型、头顶横斑、长直嘴、复杂褐斑 | 身体和头部上下摇摆 |
| 黑卷尾 | 小头黑体、深叉长尾、额部突起 | 短促抬动叉尾 |
| 池鹭 | 栗色头颈、白翼、黄嘴、较短腿 | 收颈后向下探看 |
| 白眉姬鹟 | 黑背黄腹、白眉白翼斑、黄腰 | 张翼轻跳 |
| 黄眉柳莺 | 细长小体型、浅眉、双翼带、细嘴 | 快速向上探看与小跳 |
| 大山雀 | 黑头白颊、黄腹黑纵带、较厚身体 | 连续低头啄击 |
| 黑水鸡 | 红额甲、体侧白线、上翘短尾、长趾 | 短尾上翘 |
| 大斑啄木鸟 | 直立黑白体、白肩斑、红枕红尾下覆羽 | 顶边短啄；侧边保留尾撑与密集啄击 |
| 棕头鸦雀 | 大圆头、短厚嘴、粉喉、细长尾 | 摆尾与较高小跳 |
| 黑翅长脚鹬 | 小头细颈、黑白身体、极长粉腿 | 抬脚、伸头观察 |
| 白骨顶 | 圆厚深色身体、白额甲白嘴、宽趾 | 慢速低头探食 |
| 红嘴相思鸟 | 红嘴、橙喉、黄色眉、红黄翼斑 | 探看与轻跳 |
| 黑领椋鸟 | 浅头黑领、厚胸、白翼斑 | 前伸点头 |
| 普通翠鸟 | 大头短尾、长直嘴、蓝背橙腹、白颈斑 | 较长守望后低头观察 |
| 金眶鸻 | 短圆体、黄色眼圈、黑颈环、短嘴 | 短促低头点啄后休息 |
| 黑尾蜡嘴雀 | 大头厚黄嘴、灰体、黑白翼 | 低头开合嘴模拟啄籽 |
| 红胁蓝尾鸲 | 蓝尾蓝背、橙胁白腹 | 摆尾配合轻跳 |

每种鸟有独立的动作起点、持续时间、重复间隔和速度。动作使用三张姿势关键帧按 `0 → 1 → 2 → 1` 回摆；动作之外留出守望、呼吸、眨眼和理羽的时间。跳跃按完整正弦弧起落，仅用于水平落脚面。夜鹭的 53 秒时间线和啄木鸟的侧边动作保留。图鉴用各鸟种自身的动作速度演示，不再统一点头。

飞行翅形按短圆翅、窄尖翅、宽指状翅区分；黑鸢和普通鵟采用浅幅展翼，其余鸟种保留完整拍翼。飞行路径仍采用原有窗口间轨迹，未把滑翔外观扩展为盘旋、俯冲或悬停轨迹。

预览导出包含 `species-lineup.png`（站姿与飞行）、`species-actions.png`（动作幅度对照）及 `species-animations.gif`。GIF 从各鸟种动作窗口开始，避免短预览只拍到静止阶段。图集检查覆盖全部 43 种、每种 27 帧，以及每种 8 个互异飞行帧和 3 个互异习性动作帧。Swift/C# 测试检查动作可达、休息段与跳跃端点；`scripts/test-species-parity.py` 检查两端时间线参数和共享帧名。

补充参考：[香港鸟类志：黄眉柳莺](https://avifauna.hkbws.org.hk/species/0320/037900)（浅眉和双翼带）、[RSPB：红隼](https://www.rspb.org.uk/birds-and-wildlife/kestrel)（灰头、尾端黑带）。动作周期与幅度均为桌面动画设计值，表中动作不是该鸟种专属行为。

## 新增猫头鹰（2026-10-20）

鸟种总数由 43 增至 46。本次选择中国不同地区较常见的三种，而非全国数量前三。默认出现权重是游戏设计值。三种均使用独立的猫头鹰绘制分支：正面双眼与面盘、短钩嘴、覆羽脚、宽圆翼；飞行时改用向前的面盘与横向身体。

| 鸟种 | 代表体长 | 外形 | 桌面动作 |
| --- | --- | --- | --- |
| 领角鸮 / Collared Scops Owl | 24 cm | 较高身形、耳羽簇、灰色面盘、棕橙眼、树皮状纵纹 | 长时间静候，鸣叫姿势前倾并轻抬耳羽；无音效 |
| 斑头鸺鹠 / Asian Barred Owlet | 23 cm | 圆头无耳羽簇、黄眼、棕色头背密横斑、较长横斑尾 | 转头时面盘透视变化，轻微歪头观察 |
| 纵纹腹小鸮 / Little Owl | 23 cm | 低平宽头、白眉黄眼、背部白斑、腹部纵纹、较矮胖 | 短促点头、身体下蹲后恢复 |

三者的动作周期分别为 19、12、9.5 秒；保留眨眼、呼吸和理羽。这些周期、歪头和点头幅度是动画设计，未模拟昼夜活动限制、捕食或真实鸣声。旧版 43 种配置通过既有新增鸟种提示迁移，保留原概率、锁定和自定义参数；三种新鸟在用户选择分配方式前维持零概率。

参考：[香港鸟类志：领角鸮](https://avifauna.hkbws.org.hk/species/0190/027100)、[香港鸟类志：斑头鸺鹠](https://avifauna.hkbws.org.hk/species/0190/026900)、[中国生态系统研究网络生物多样性知识平台：纵纹腹小鸮](https://wiki.biodiversity.cern.ac.cn/index.php/纵纹腹小鸮)。主要用于核对中国分布、代表体长与识别特征；图片未复制。
