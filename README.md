# 戍边

戍边 是一个准备开发的 3D 合作狩猎游戏，目标是四人小队共同挑战大型怪物。正式名称为《戍边》，设计方向参考《怪物猎人：世界》的组队狩猎体验。

当前工程已有可运行的单机第三人称湿林战斗原型，包含三叉戟规则、五种巨兽初稿与弱点伤害判定。人物、巨兽、地形和动作仍为程序化初稿，不是最终建模与动画；难度、连携手感和完整特性尚未验收，四人联机尚未实现。

## 打开项目

1. 使用 Godot 4.7.2 标准版，在项目管理器中导入根目录的 `project.godot`。
2. 打开工程后按 F5，进入湿林战斗原型。角色前方是苔甲龙，其他四种巨兽分布在林地两侧。
3. 当前使用 GDScript 工程基础和 Compatibility 渲染，无需 .NET。

已安装的本机引擎可用 PowerShell 启动，命令在项目根目录执行：

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --editor --path .
```

## 开发目标

- 3D 第三人称动作体验。
- 四人小队协作狩猎大型怪物；暂按队伍总人数为四人理解。
- 围绕怪物招式观察、躲避、攻击时机与队友配合建立战斗循环。
- 逐步形成任务准备、出发狩猎、任务结算与装备成长的循环。

当前单机切片按已确定的三叉戟规则实现；联机服务与后续内容属于开发目标，战斗手感和美术仍需通过实际试玩打磨。

## 目录

- `scenes/main`：启动场景。
- `scenes/players`、`scenes/monsters`、`scenes/levels`、`scenes/ui`：后续游戏场景。
- `scripts/player`、`scripts/combat`、`scripts/monster`、`scripts/network`：后续功能代码。
- `assets/models`、`assets/textures`、`assets/audio`：游戏素材。
- `resources`：后续武器、怪物和任务数据。
- `docs`：项目方向和开发路线。
- `tests`：后续行为与联机测试。
- `builds`：本地导出产物，不提交到 Git。

## 模型重建

五种巨兽的模型源代码为 `scripts/creature_model.gd` 与 `scripts/creature_surface.gd`。在项目根目录执行以下图形模式命令，可重建 `assets/models/*-v1.tscn` 五份预览模型，并在项目父目录输出总览和各物种近景：

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture_creature_models.gd
```

保存的巨兽模型包含五节尾部骨骼，以及各条步行腿独立的髋—膝—踝骨骼、Skin 和混合权重网格；游戏内驱动尾部弯曲、屈膝与抬脚，普通行走加入支撑脚世界锚点和坡面高度/朝向适配。躯干、头颈仍未完成统一全身骨骼，起停过渡与完整转向步态仍需制作，尚不是正式巨兽动作库。tools/replay_tail_skin_study.gd 和 tools/replay_creature_leg_study.gd 可生成尾部、原地步态研究；后者传入 -- --travel 可生成前进步态研究，均不是实战回放。

森林由 `scripts/forest_art.gd` 和 `shaders/forest_*.gdshader` 生成树冠、蕨类、湿地与溪流外观。以下图形模式命令生成地图总览、林下及溪边截图，并输出限定待机视图的渲染采样报告：

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture_forest_views.gd
```

结果位于项目父目录，文件名前缀 `Shubian-forest-`；该采样不代替战斗压力和人工手感验收。

## 版本管理

主分支为 `main`。提交 Godot 场景、脚本、源素材和 `.uid` 文件，忽略 `.godot` 缓存。
模型及部分音频格式已配置 Git LFS，协作者克隆前应安装 Git LFS。
仓库中不保存本机 MCP 配置、访问令牌或商业游戏素材。

参考作品仅用于讨论玩法体验，角色、怪物、地图、音乐与其他资产采用原创或取得授权的素材。

## 下一步

当前实现范围、测试结果与未完成目标见 [战斗实现进度](docs/combat-implementation-status.md)。初始方向见 [项目方向](docs/game-direction.md)。

## 原型操作

WASD 移动，鼠标转视角，Shift 奔跑，空格闪避，中键锁定，Tab 切换目标（Shift+Tab 反向），Esc 释放鼠标，F5 重试。

左键斜刺；右键按下横扫（无长按投枪或瞬移）；E 回拉；Alt 加左键转身；Q 格挡。成功格挡后按 Ctrl，右手握尾横扫命中获得枪意。

基础派生：斜刺→右键挑斩；横扫→左键进步直刺；回拉→右键下劈；闪避末段→左键侧身突刺。需要在前一动作的衔接窗口按键，可提前约 0.18 秒预输入。

锁定时视角平滑跟随目标；横向移动鼠标可短暂接管视角，停止调整后恢复跟随。上下瞄准仍由玩家控制。

刺击和横扫会随鼠标仰俯调整攻击高度。未锁定时朝视角出招，出招中的移动保持攻击方向；头颈偏离躯干时可解除锁定，自由瞄准。攻击高处雾囊或背棘需要调整视角与站位。近战按有效帧中的实际枪头、枪尾或脚部轨迹检测，不再一次结算整个扇形。

有枪影时 Ctrl 加左键四连刺、Ctrl 加右键旋转；每次消耗一层。拔枪时 Ctrl 加空格插地，再单按 Ctrl 开启 0.5 秒反击窗口。R 收枪。

## Windows 原型试玩包

实战界面显示生命、耐力、五层枪影各自的剩余时间和攻击加成；底部随基础动作、派生、格挡、反击及插地状态提示下一步按键。F1 展开/收起完整操作说明，不暂停战斗；锁定巨兽时集中显示生命、特性、弱点及当前攻击提示，并收起该巨兽的头顶重复文字；附近未锁定巨兽只显示简短标识。

在项目根目录运行 `./tools/build_windows_preview.ps1`，会在项目父目录 builds/ 下创建独立试玩文件夹和 ZIP。完整解压后双击 Start-Shubian.bat，无需另行安装 Godot。包内 README.txt 说明操作，build-manifest.json 保存源码提交与引擎、数据包的 SHA-256。

当前使用本机 Godot 编辑器运行程序配合导出的 PCK，因此包较大，不是正式导出模板构建。脚本从引擎读取许可与第三方声明随包附带，排除参考概念图、视频、文档、测试及工具；从包目录运行 12 项资源、模型、移动和实际命中检查，失败不生成 ZIP。正式发布、联网、最终美术、难度与人工手感仍需后续完成。

`./tools/verify_forest_performance.ps1` 以原生 1280×720、无帧率上限运行完整地图狩猎，记录源码、控制器散列、整场帧时间和慢帧分项耗时。约需四分钟，运行时避免其他重负载；不使用无窗口、固定模拟帧率或录像。该工具区分战斗完成与本机帧时间检查，保留开局慢帧，并单独检查开局两秒后的表现。自动控制器的结果不代替人工难度及动作观感验收。

## 验证

在项目根目录执行：

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_combat.gd
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_world.gd
```

真实单敌连携与承伤回放（固定 60 FPS，失败返回非零退出码）：

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path . --script res://tests/replay_weapon_sequence.gd
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path . --script res://tests/replay_interruptions.gd
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path . --script res://tests/replay_weakpoints.gd -- --species=mistfrill
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --fixed-fps 60 --path . --script res://tests/replay_weakpoints.gd -- --species=stormcrest
```

回放读取内部状态并自动选择时机，使用实际移动、动作请求、巨兽伤害和武器接触，不能代表人工难度验收。详细事件报告输出到项目父目录的 `Shubian-weapon-sequence.json` 与 `Shubian-interruptions.json`。

五物种独立战斗与弱点验证入口（每场必须胜利、有实际武器接触和弱点命中；失败返回非零）：

```powershell
./tools/verify_species_encounters.ps1
# 可通过 -GodotPath 指定其他 Godot 可执行文件。
```

每次生成独立的项目父目录 verification/encounters-* 报告，包含五场日志和 summary.json。验证读取本次运行的控制台结果，不以旧报告或仅成功启动作为通过依据。五场分别为独立单敌战斗，不是五敌同时对战；控制器读取内部状态，不证明人工偏难强度或操作手感。

整图连续狩猎：`./tools/verify_forest_hunt.ps1`。从正常出生点穿过森林，五只 AI 全程启用，不重置生命、耐力或枪影；必须存活并依次击退全部五种巨兽才通过。每次保存独立的 verification/forest-hunt-* 日志、源码提交、控制器散列和受伤记录。它使用读取怪物状态的策略控制器，不是人工难度验收，也不表示五敌在同一地点同时围攻。原生结果画面可用 Godot 参数 `--path . --fixed-fps 60 --script res://tests/replay_forest_hunt.gd --quit-after 40000 -- --capture-victory` 生成，输出在项目旁 Shubian-forest-hunt-result.png。

规则检查和场景集成检查不代表实际操作手感、美术、碰撞精度或完整对战已经验收。

架势内不恢复耐力，每次成功格挡消耗 15 点。耐力不足时会被击破，需收势后走位恢复；已获得的格挡反击机会在零耐力时仍可使用。

固定按键节奏难度对照：`./tools/measure_fixed_inputs.ps1`。五场均使用相同节奏，不根据怪物阶段或弱点选择输入；每次在项目旁 verification/fixed-inputs-* 保存日志和结果。胜负均为有效测量，只有缺少完成结果或运行错误才返回失败。初始位置受控、其余四只 AI 冻结，不能代替人工难度验收。

原生战斗帧时间测量：使用 Godot 图形程序运行 `--path . --script res://tools/benchmark_combat.gd --quit-after 30000`。不要添加 `--headless`、`--fixed-fps` 或录屏参数；等待 COMBAT_PERFORMANCE 与 WEAPON_SEQUENCE 两个结束标记。报告保存在项目旁的 verification 目录。本工具关闭垂直同步和帧率限制，仅测单怪连携；不会保存这些显示设置。

整图实时帧时间测量：使用图形程序运行 `--path . --script res://tools/benchmark_forest_hunt.gd --quit-after 250000`。五只 AI 全程启用，正常出生、移动和持续资源结算，约四分钟完成；必须同时看到 FOREST_PERFORMANCE 报告和 FOREST_HUNT 的 passed=true。不接受无窗口、固定模拟帧率或录屏参数；本次进程关闭垂直同步和帧率上限，不保存设置。报告位于项目旁 verification/forest-performance-*.json，包含启动阶段、两秒后帧分布和卡顿时的目标/阶段；只代表本机与本次路线。

跨系统检查：`python tools/verify_regressions.py`；实际渲染专项可用 `python tools/verify_regressions.py --native --only test_hunter_visibility test_forest_art`。每项有超时和完成标记检查，报告保存在项目旁 verification 目录；无窗口结果不证明 GPU 画面或人工手感。

窗口键码诊断：以 Godot 运行 `--path . --script res://tools/trace_window_input.gd`，会打开独立诊断窗口，将该窗口收到的键码和鼠标按钮事件写入项目旁 verification/window-input-*.jsonl，直到关闭窗口。仅排查输入时显式使用；正常试玩不启用记录。

输入分发连携回放：Godot 参数 `--path . --fixed-fps 60 --script res://tests/replay_input_sequence.gd --quit-after 6000`，可加 `--headless`。须同时看到 INPUT_SEQUENCE 与 WEAPON_SEQUENCE 的 passed=true。移动和招式经引擎按键/鼠标事件分发，仍由读取怪物状态的控制器选择时机；报告为项目旁 Shubian-input-sequence.json，不是人工难度验证。
