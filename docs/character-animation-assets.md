# 戍边 角色骨骼与预览动画

打开 assets/models/hunter-forest-v1.tscn，选择 AnimationPreview，在动画面板播放 light、heavy、guard、fourfold 等片段。动画库为 resources/animations/trident_library.tres。

模型保存 Skeleton3D、Skin、带骨骼索引与权重的 ArrayMesh，以及 Spine—上臂—前臂—手部、大腿—小腿—脚部父子层级。双侧主关节使用 Left/Right 加 UpperArm、Forearm、Hand、Thigh、Shin、Foot 的骨骼名称，便于后续编辑。大部分网格仍使用分段刚性权重，内衣腰部混合根部与躯干骨骼的影响；这只是局部过渡，不是完整平滑人体拓扑，也不代表角色概念图的最终建模完成。

17 个片段包括 idle、light、heavy、pull、turn、guard、reply、flash、throw、fourfold、spin、plant、wait、counter_window、finisher、dodge、hurt。片段由当前程序化姿态按 30 FPS 烘焙，供编辑器预览，不是已经完成的手工关键帧动画。

两肘、两膝现有连续布料接头，以相邻上下肢骨骼的渐变权重变形。接头沿初始关节曲线建立，半径收在外层袖管和裤腿以内，避免交界处相交形成锯齿。它补充局部连接，没有将整个角色改为连续人体拓扑。运行 capture_character_turnaround.gd 并传入 --details 可额外生成肘、膝原生近景。

游戏仍由战斗时钟和握点求解驱动骨骼，预览播放器不自动接管战斗。wait 预览循环不决定 30 秒等待，免伤和伤害窗口不由预览动画决定。正式根运动、步态、全身平滑蒙皮、关键帧和运行时 AnimationTree 仍需制作。

躯干加入动作前倾、扭转与收势，肩部跟随后重新求解双手握点。格挡接反击直接承接枪尾朝前姿态，终结技支撑脚有小幅前后调整。装备状态变化另行触发武器过渡：收枪用 0.30 秒侧上方路径，主手持杆到接近挂点，辅助手先释放；拔枪保持 0.10 秒短过渡，可被新的攻击承接，不额外阻塞战斗时钟。这仍是程序化轨迹，不是正式手工拔收枪动画或完整穿模验收。tools/replay_animation_study.gd 可录制六个姿态片段；tools/replay_equipment_study.gd 录制拔收枪研究，均不是实战回放，不能证明操作手感或战斗难度。

下肢通过固定长度的两段求解实现屈膝站姿、交替抬脚和终结技收腿再伸腿。角色着地时，按双脚预期位置向实体地面发射射线，调整双脚高度，并让视觉身体随较低的支撑面下沉；单脚高差限制为正负 0.22 米，踢击脚保留原有轨迹。只探测地面层，不把怪物当成支撑面，离地时停用。Foot 骨骼绕靴底锚点沿坡面法线倾斜，抬脚时逐渐恢复水平；踢击脚不沿坡面倾斜。烘焙预览仍以平地为基准。靴子已改为带封闭平底、加厚底边、鞋头护片和靴筒的截面网格，保留原脚底锚点；未制作完整重心转移、世界空间足底接触锁定、骨盆扭转和连续衣料变形。陡坡、台阶与快速移动仍需细化，不能将支撑平面的检查等同于正式步态验收。

服装与面部基础网格现在由 scripts/hunter_outfit.gd 生成，包括躯干轮廓、交叠领口、分片雨披、开衩下摆、腰带和模块，以及独立头部、发帽、发髻、眼鼻口部件。下摆根据腿部姿态打开，不是布料模拟。袖管、护臂和裤腿使用轮廓截面网格；面部仍是简化形状，没有平滑连续的面部拓扑、表情骨骼或捏脸界面。

三叉戟由 scripts/trident_mesh.gd 生成中央刃、两侧后向钩刃、握把、钝枪尾和玉色嵌件。Marker3D 保存枪尖、侧刃、钩端和枪尾的接触采样位置，游戏从模型读取；回拉使用后向钩端。当前仍是带宽容量的采样扫掠，不能称为刀刃三角网格的精确连续碰撞。

图形模式执行以下命令可生成正、侧、背三视图，图片写入项目父目录 Shubian-character-turnaround.png：

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tools/capture_character_turnaround.gd
```

在项目根目录依次执行可重建文件，现有模型与库会更新：

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/bake_hunter_animations.gd
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/export_hunter_model.gd
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_skin.gd
```

修改武器、关节或姿态后需重新烘焙。技术接口参考：
https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html
https://docs.godotengine.org/en/stable/classes/class_skin.html
