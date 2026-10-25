# 横扫与扑跃的动作轮廓复核

本轮首先建立当前实现的八格基准图，避免把设计意图当作已实现效果。

运行 `tools/capture_action_keyframes.gd`，输出仓库上一层的 `Shubian-action-keyframes-current.png`。上排为真实人物模型按横扫时钟逐步驱动的蓄势、释放、随势和回正；下排为苇影迅龙的直接姿态采样。下排空中高度来自展示用曲线，不是正常 AI 的真实运动轨迹。所有画面均不是实战或难度、接触判定的证明。

原生 Compatibility 渲染运行退出 0，保存返回 OK。目视观察：人物四格腿部、重心轮廓差别偏小；怪物蓄势和落地低伏轮廓比较接近。该发现支持优先重做全身关键姿势，但不能单凭静态图认定全部手感问题的根因。

下一轮动画目标：人物后腿承重蓄势→蹬地带动胯部→胸肩带动双手横扫→前腿承重随势→收势；怪物后肢明显压缩→蹬伸离地→前肢触地缓冲→后肢回收支撑→恢复。应先在固定视角下验证轮廓，再核对实际第三人称镜头和正常播放速度；关键姿态应保持手握枪杆、脚底支撑和攻击时刻的对应关系。

设计草图仅用于美术及动画规划，不能作为运行时动画已完成的证据。整体角色与怪物模型品质、真人战斗手感及整图性能仍未完成验收。

设计草图 assets/action_planning/heavy-leap-draft-v1.png 已保存。它尚有需要修正之处：横扫蓄势格枪头超出画面，释放与随势姿态差异小；怪物落地格未清晰表现前肢承重。因此仅作为第一版方向参考，不直接照图制作，也不视为动画设计验收。

## 横扫重心的第一轮运行时调整
蓄势时人物可见根节点后坐由 5.6 厘米增至 13.6 厘米，额外下沉由 5 厘米增至 10 厘米；释放时向前偏移由 8 厘米增至 12 厘米。保持原脚底目标、骨盆转动、枪杆转角和动作时钟，随后平滑收回。该修改会随身体移动改变武器世界位置，因此复核握枪及真实武器轨迹，不声称命中几何完全不变。
原生检查通过：骨盆 34、腿部 106、姿态过渡 14、胸部 33、握枪 55、关节服装 31、蒙皮 246、武器轨迹 17。17 段保存动画已重烘焙。输入连携控制器通过，四连刺四次、旋转两次、终结两次接触，生命 240；该控制器不是横扫专项或真人难度验收。原生截图保存成功，目视改善有限，仍需继续打磨完整动作和模型。

## 苇影迅龙起跳压缩与尾部平衡
起跳前身体压缩从体型的 10% 增至 16%，尾部抬起 0.22 弧度；进入起跳保持相同姿态，再逐渐伸展。落地缓冲仍使用较浅压缩，尾部只小幅平衡。模型短前肢不承担主要体重，修正早期草图所暗示的前肢主承重方向，后肢仍为主要支撑。静态截图可见蓄势更低且尾部上扬，与落地轮廓更有区别，但完整美术质量仍未完成。
原生姿态 46、地形足底 225、冲扑时序 54、扑跃接触 5、真实扑跃 23 项通过。加深压缩后平地头颚仍保留至少 5 厘米间隙；该检查不是所有坡度的证明。正常 AI 对固定站位角色接触：0.05 秒 HeadSurface 命中一次，角色生命 202，实际起跳峰高 1.0535 米并落地，工具退出 0。可见体表更早接触是姿态变化的实际结果，不等同于攻击时间或数值被提前。非真人难度或整图性能验收。

## 横扫开步与回步
横扫蓄势时右脚先开、左脚后开，挥扫保持约 50 厘米横向支撑宽度；0.70 秒后左脚先回、右脚后回，各自具有抬脚弧线。未改变攻击、连携时钟和胶囊位置。新增 120Hz 姿态采样确认至少一脚持续支撑、无平地穿透、0.20–0.69 秒挥扫支撑期双脚位置稳定。原生骨盆 37、腿部 106、过渡 14、地形脚底 83、握枪 55、轨迹 17 项通过，17 段保存动画重烘焙。
默认第三人称正常请求轻击、重击、回拉、转身均接受，截图保存成功。目视默认镜头下横扫枪头仍很小并与身体投影接近，不能把支撑步改善等同于整体动作可读性完成；下一步仍需处理上肢和枪杆在默认镜头下的轮廓。该展示冻结其他 AI，不证明实战难度。

## 横扫随势与默认镜头轮廓
保持原 0.43 秒前方通过姿态，在 0.50 秒更快扫到侧方，0.61 秒延展到 1.25 弧度并保持至 0.70 秒再收势。握枪位置未改变，动作生效和连携时钟未改变，生效后实际武器路径因此改变。
同一默认镜头、同一 0.50 秒：枪头投影长度从 11.09 增至 24.86 像素，枪尖与背部参考点距离从 31.73 增至 60.19 像素；截图能看见枪头伸出肩侧。不能由单帧推广为全程无遮挡或整体品质完成。原生握枪 55、全动作手臂及胸部 34、实际武器接触 18 项通过，新增前方横扫真实模型接触与枪尖横向离体检查；17 段动画重烘焙。
Shubian-heavy-wide-default.mp4 为默认相机、正常动作请求和时钟的约 5 秒展示，其他 AI 冻结，不作为真人操作难度或整图性能证明。

## 格挡转枪与枪尾反击
复核用户参考视频的已有采样，采用其中可见的后腿承重与送身方向作为发力参考，不声称该套路包含游戏里完全相同的格挡规则。格挡胸部转动加深到 -0.35 弧度，并随可见身体后坐；反击初始身体和胸部与架势完全一致，随后加深后坐再前送。保留正手持杆、枪头绕后和枪尾实际判定。新增工具 --guard 输出转枪与反击八格直接姿态采样。
原生胸部与全动作手臂 35、握枪 55、腿部 106、过渡 14、武器接触 18、格挡耐力 18 项通过。新增身体/胸部衔接一致检查，并确认后坐至前送超过 18 厘米。正常 AI 单怪输入连携通过，实际枪尾推退，反击三次、闪刺三次、四连刺四次、旋转两次、终结两次接触，生命 240；属于状态感知控制器证据，不是真人手感或难度验收。17 段保存动画已重烘焙。目视动作仍较克制，模型和整体动画品质继续未完成。

## 连续对战整体验证及反击末端修正
第一轮全量检查 80/81 通过，骨架检查发现反击末端身体先回中立、武器仍保持架势，实际枪尾世界位置相对初始架势偏移 2.88 厘米。现令反击末端身体与胸部回到同一架势，不放宽原断言；新增完整身体/胸部返回检查。保存动画已重烘焙。原生骨架 271、胸部 36、过渡 14 项通过，实际输入连携通过并结束生命 240。
修正后全量机械回归 81/81 通过：regressions-20261025-141203-3eac71。修正后连续五怪对战通过：forest-hunt-20261025-221232-946725，300.63 秒，剩余生命 185，无运行错误；五怪逐一生命归零，正常出生、资源连续，无补血。它是固定步长无画面、状态感知控制器证据，不证明原生帧耗时、真人偏难程度或美术质量。报告 HEAD 为修正前 bd983b7，运行时包含本节未提交修正；另有早先性能工具改动，未影响本次游戏脚本。整体目标仍未完成。

## 苇影迅龙体态比例
收紧腹腰，保留胸肩与髋部连接；整组头颈缩至原来的 88%，眼、颌、齿共同随动。强壮后肢和长尾保留，目标是减轻头胸观感并突出扑跃后肢。实时模型与保存模型同步，导出时保留原资源和节点标识；其余四怪保存文件恢复原字节。侧面渲染 Shubian-reedclaw-side.png 作为后续轮廓检查基准，整体精度仍为原型。
原生模型表面 51、腿部 304、地形 225、扑跃姿态 46、实际扑跃 23、冲扑表面接触 5、投枪部位 18、弱点标记 35 项通过。新增实时/保存体表腰胸比例检查，以及恢复期两侧可见提示处的真实表面接触分类检查。头部变小后正常 AI 固定站位扑跃在 0.10 秒 Jaw 实际接触一次、生命 202、峰高 1.0535 米并落地；没有扩大代理体积来补足旧头部体积。
侧向追击控制器 42.88 秒胜利，24 次接触、生命 240，但弱点接触为 0，不能宣称该场验证了弱点收益。定点表面检查证明弱点仍可接触，不代替正常战斗里的弱点利用。整体角色/怪物美术、真人手感和整图性能继续未完成。

## 苇影迅龙弱点正常对战对照

侧向控制器增加 --trace 接触日志和可选 --aim-flank；后者仅通过已有 apply_look 输入抬枪至 pitch 0，不改任何怪物数值、弱点范围或资源。旧低位 pitch -0.25：42.88 秒胜利，24 次接触（身体 21、肢体 3），弱点 0。日志记录暴露时段和枪头模型空间高度，多次恢复期仍落在低位普通部位。抬枪后：28.93 秒胜利，16 次接触（侧腹 12、身体 4），其中开放弱点 9、生命 240；蓄势期碰到侧腹不获得弱点收益。

原生固定帧率录像复现相同 16/9 接触与胜利，1755 帧、29.25 秒，输出 Shubian-reedclaw-aimed-flank.mp4。该状态感知控制器不是人类玩家；录像模式不是帧耗时证据。未扩大弱点或把腹底/腿改成弱点。游戏在实际侧腹开放的恢复期提示抬枪对准亮点追击，试玩说明补充锁定只管水平跟随、鼠标上下调整攻击高度。可读性 29、弱点 35 检查通过。整体美术、真人难度和整图性能继续未完成。
## 角色短披肩与肩甲轮廓

对照已认可的边地行者概念图，原短披肩下摆过平、肩甲顶端过尖。本轮让披肩从领口向下逐渐增加布褶，背侧下垂约 5 厘米，包边使用同一形变；领口、中央挂枪开口与裸露上臂保留。肩甲改为更低的圆弧截面，采用较暗湿岩灰，保留随肩关节运动。未新增材质层或悬浮装饰网格。

实时模型和保存模型同步，保存场景保留原资源/节点标识。原生服装 10、换枪过渡 18、布料 71、遮挡像素 26、蒙皮 246、关节服装 31 项通过；六动作姿态展示退出 0。三视图及横扫截图已目视检查，轮廓有所变化，但仍是原型级造型，未宣称无穿插或最终美术验收。动画骨骼与战斗规则未改变；本轮未重测完整整图性能，上一轮达标记录不能直接推广为新版性能证明。
## 三叉戟刃面倒角

中央刃与两侧后向钩齿从平行平面加侧壁，改成厚刃面向外轮廓收尖的闭合倒角。保留原二维轮廓、总厚度、正手握点、枪尾和所有实际接触标记。斜面使用独立法线，转动时可产生不同明暗，不增加网格实例或材质层。真实模型近景 Shubian-trident-surface.png 显示正面及斜侧面；该近景不证明正常游戏距离下的整体可读性。

实时与保存角色中的三叉戟同步。原生服装/闭合刃体 16、武器接触 18、枪影 17、投枪交接 14、蒙皮 246 项通过；新增三片刃体边缘每条相邻两面、正反法线朝外及存在斜面法线检查。默认第三人称正常请求轻击、横扫、回拉、转身均接受，接触标记投影保持原值。模型检查及截图不是真人手感验收，整体目标仍未完成。
## 雾囊冠龙蓄压与中断外形

将两侧小球状雾囊改成沿颈下方延展的椭圆囊体，实时与保存模型统一命名 MistSac。蓄势时逐渐膨胀并转暖色，喷吐开始保留满压轮廓后消退；进入恢复或被打断时解除鼓胀，冠膜原有展开保持。稳定状态不重复提交相同缩放和颜色，未新增额外网格实例。囊体的可见表面会随膨胀改变，实际三角表面接触跟随该几何；没有扩大额外弱点代理范围。

原生实时/保存表面 63、颌部 35、雾效果 9、投枪部位 18、硬直姿态 71 项通过。新增囊体蓄压、释放衔接、恢复及中断重置检查。正常 AI 弱点控制器原生与无画面结果一致：11.47 秒、22 次接触、开放弱点 3 次并打断 3 次、生命 240、怪物生命归零。输出 Shubian-mist-pressure-interrupt.mp4（707 帧，11.78 秒），画面采样确认囊体和打断后的恢复状态可见；录像固定帧率，不是性能证明，控制器也不是真人难度验收。整体美术和真人手感继续未完成。
## 雷脊棘龙蓄能与失衡状态区分

降低待机背棘的常驻亮度，蓄能时由尾侧向头侧逐段点亮青色。被打断进入真实硬直时改为稳定暖色，表示此时背棘仍开放；普通恢复、待机及死亡清除该效果。名称提示同步指出失衡时追击发亮背棘。保持原伤害、蓄势、弱点范围和时长，未增加透明层、灯光或网格。

初次整合测试发现硬直姿态采样会覆盖提前设置的颜色，现由 Model.animate 的实际 stagger 阶段统一保留暖色状态，并通过真实物理硬直分支测试。原生材质 42、硬直 72、部位 26、投枪 18、弱点提示 35 项通过。正常 AI 单怪控制器原生/无画面结果一致：18.40 秒、35 次接触、背棘弱点 10 次、打断 3 次，角色生命 178、怪物生命归零，无注入资源或伤害。

Shubian-storm-charge-states.png 是直接指定阶段及一次测试用硬直状态的姿态/材质对照，不是实战录像。保存模型只同步待机顶点色，维持原资源/节点标识，其余四怪保存文件保持原样。整体美术、真人难度与新版整图性能仍需继续验证。
## 苔甲龙躯干与背甲衔接

新增检查复现了五片背甲在躯干倾斜时仍固定于根节点的问题：实时/保存表面检查 93 项中 20 项失败，真实硬直检查 77 项中 1 项失败。现为每片甲保存相对躯干的绑定变换，随躯干实际倾角运动；稳定变换不重复提交。硬直捕获并平滑释放 BodySurface 原倾角，避免打断第一帧突然归零。保存模型同步绑定数据，破甲隐藏与原节点路径保持，未修改攻击数值或时钟。

修正后原生表面 93、硬直 77、头部横扫 15、地形脚底 225、部位 26、投枪 18、后方攻击 65 项通过。正常输入连携通过，四连刺四次、旋转两次、终结两次接触，结束生命 240。Shubian-moss-shell-follow.mp4 为两周期直接姿态展示（381 帧、6.35 秒），已采样目视检查甲片与躯干运动，不是实战或性能证明。整体造型精度及真人手感仍未验收完成。
## 棘角奔龙侧腹提示贴合体表

旧实现只将苇影迅龙侧腹提示投影到体表，棘角奔龙仍按代理球半径向外放置。新增两侧三个恢复时刻的体表包围范围及真实表面距离检查，在旧实现产生 12 条棘角位置/接触失败。新增采样后明确复位既有苇影降身比较的起始姿态，保留原比较意义。现将已有投影用于两种侧腹弱点，提示与可见体表保留约 4 厘米间隙，不扩大实际弱点体积。

原生弱点提示 59、部位 26、投枪 18、冲扑时序 54 项通过。两种侧腹弱点在恢复期三个时刻均能从提示附近触及真实 flank 表面，距离小于 7 厘米。正常 AI 侧向控制器原生/无画面结果一致：30.43 秒、21 次接触，其中侧腹 17 次、开放弱点 12 次，怪物生命归零，角色生命 240。控制器不是真人难度验收。Shubian-weak-markers.png 为直接指定开放状态的对照截图，不是实战。整体模型品质与真人手感继续未完成。

## 2026-10-26 角色披肩与巨兽头颌轮廓

对照已认可的湿林行者概念图，将披肩底部从 1.33 米延长到 1.20 米，补充中间截面、扩大下摆，并同步垂坠与包边。保留分片和中央取枪开口。头颌与眉脊使用保持原截面范围的纵向曲线，减少分段锥面；苇影迅龙眉脊下移 0.025 倍体型，靠近眼眶。实时源模型与保存模型同步，资源标识规范化。

原生检查：地面 225、颌部 35、表面 96、扑跃姿态 46、冲扑表面 5、部位 26、投枪部位 18、硬直 77；服装 16、装备衔接 18、布料 71、蒙皮 246、躯干 36，均通过。已查看三面角色、苇影迅龙及横扫关键帧实机渲染。关键帧直接指定阶段，不是自然战斗或性能证明。未证明所有动作均无布料穿插，也未完成概念图级人物造型、怪物美术或真人手感验收。

## 2026-10-26 普通命中的方向性受力反馈

普通命中新增 0.26 秒的头颈偏转与躯干侧倾，45 毫秒达到峰值后回正。方向来自攻击者相对朝向，弱点、重击幅度更高，四连刺幅度降低。脚底 IK 和 AI 时钟继续运行，不引入普通攻击硬直；真实硬直姿态拥有完整捕获与恢复过程。躯干侧倾在同步背甲之前应用，每次姿态采样先清除残留角度，避免累积。仅在反应未结束时推进其元数据。

原生可读性 35、硬直 77、表面 96、地面 225、部位 26、投枪部位 18、冲扑时序 54 项通过。检查双侧来击方向、归零及四连刺不改变状态/时钟/硬直。自然 AI 单怪输入回放通过：反击 3、闪刺 3、四连刺 4、旋枪 2、终结 2 次接触，生命 240。该控制器不代表真人难度。Shubian-creature-impact-study.png 为调用接触入口后直接采样的三帧姿态对照，隐藏闪色便于检查形变，不是自然战斗截图。模型精度和整体打击感仍未验收完成。

## 2026-10-26 衣裤松量与立体腿甲

上衣、大腿裤片和小腿裤片采用保形纵向截面，增加固定在模型上的斜向张力褶皱与收束起伏，开口处衰减至零，维持腰口、膝部软连接和裤脚的位置。不是逐帧随机噪声或布料物理模拟。膝甲、胫甲从双面薄片改为闭合有厚度的壳体，增加凸面、斜边与背面，继续沿用原节点和骨骼绑定。保存模型同步并规范化资源标识，无新增战斗判定代理。

原生服装 18、装备衔接 18、脚底 83、布料 71、关节软连接 31、蒙皮 246、躯干 36 项通过；新增腿甲闭合边与实体深度检查。已目视检查角色三面、膝部近景和横扫关键帧。外观仍然明显是原型，尚未达到已认可概念图的角色精细度，不能将几何闭合和蒙皮检查视为美术或手感合格。

## 2026-10-26 新模型组合版本验证

验证源版本 883c2dc（游戏内容与 0e312d5 相同）。首次全量原生检查为 80/81：出生装备的五个断言通过，但立即退出时出现两张 OpenGL 纹理释放错误，单独运行可复现。测试保留所有首帧断言，在销毁场景前后等待原生渲染完成；无画面模式不等待 frame_post_draw。修正后原生/无画面专项通过，完整原生 81/81 一次通过：outputs/verification/regressions-20261025-164038-e4ff39/summary.json。未修改运行期游戏逻辑。

本机原生连续五怪对战通过：outputs/verification/forest-realtime-20261026-003516-e23d84/summary.json。实际 OpenGL 3.3 Compatibility、RTX 4060 Laptop、NVIDIA 610.88、1280x720、无固定帧率、无录像；源版本干净，300.63 秒，生命 185，无运行错误。排除场景准备后两秒的 56,320 帧：P99 11.043ms，最大 20.556ms，超过 33.33ms 为 0。全部 56,843 帧中启动阶段有一帧 52.889ms，未隐去。满足当前稳定阶段预算，不等于彻底消除首次启动卡顿或其他硬件风险；兼容渲染的管线计数不能排除 OpenGL 编译。控制器不是人类难度、动作自然度或最终美术验收。现有 0e312d5 试玩包游戏内容相同，无需仅为测试退出顺序重打包。

## 2026-10-26 轻击后腿驱动与收脚

轻击蓄势增加后坐与下沉，命中时向前转移身体重量，并保持到 0.30 秒再回收。局部枪头轨迹、命中 0.25 秒、衔接 0.37 秒不变；身体位移变化使世界空间接触路径相应变化。前脚在 0.42 至 0.66 秒收回时增加抬脚，避免贴地拖回。17 段动画库重新烘焙。

原生重心 42、脚底 83、腿部 106、握持 55、轻击轨迹 4、躯干 36、武器追踪 18 项通过；衔接 17 项进一步验证最早 0.37 秒轻接重，保留首帧脚步与握点连续性。120Hz 轻击采样至少一脚支撑且不穿地，回收前脚高度超过 4 厘米。正常 AI 输入回放通过反击 3、闪刺 3、四连刺 4、旋枪 2、终结 2 次接触，生命 240。

Shubian-light-body-transfer.mp4 为默认镜头、正常动作请求与战斗时钟的 5.08 秒固定帧率录像，怪物 AI 冻结，用于姿态检查，不是自然实战、运行帧率或真人难度证明。已查看侧面轻击关键帧。动作与模型仍未获得真人手感和最终美术验收。

## 2026-10-26 回拉全身后坐与骨盆配合

检查发现回拉虽有胸部与武器曲线，却不在全身前后移动及骨盆转动列表中。新增重心检查在旧实现出现三条失败：没有明显后坐、没有屈膝下沉、骨盆没有随胸口转动。现将回拉接入全身重心与骨盆曲线，收杆后段后坐至 0.144 米并下沉 4 厘米，双脚通过既有 IK 保持落点。保留局部钩齿回收曲线、0.40 秒命中和 0.55 秒衔接，世界空间接触路径随身体位移改变。17 段动画库已重新烘焙。

原生重心 47、脚底 83、握持 55、回拉轨迹 4、回拉物理 6、躯干 36、武器追踪 18 项通过。衔接检查扩展至最早 0.55 秒回拉接轻击，共 22 项通过。已查看侧面回拉准备、接触、随势三帧；这些是直接姿态采样，不是自然实战或性能证明。模型精度、全部动作自然度及真人手感仍未验收完成。

## 2026-10-26 四连刺的腰腿节奏

旧实现有四次武器伸缩和胸部小幅脉冲，但全身重心与骨盆均未接入四连刺。新增检查在旧实现出现 8 条失败，分别对应四次缺少骨盆转动和重心回收。现在增强交替胸部转动，将脉冲接入骨盆与全身前送，并加入少量屈膝。双脚通过原 IK 维持落点。局部武器曲线与四次命中时刻未改；世界接触位置随身体动作变化。17 段动画库已烘焙。

原生四连轨迹 26、握持 55、脚底 83、躯干 36、战斗规则 32、衔接 22、武器追踪 18 项通过。新增检查覆盖每一刺的骨盆发力、回收及双脚稳定；战斗规则保持四连刺可被打断、不赋予普通命中硬直。Shubian-fourfold-body.mp4 为 2.80 秒固定帧率姿态研究，使用一层测试枪影、冻结怪物 AI；显示四次出手并消耗测试枪影，不是自然实战、性能或真人难度证明。已查看视频中间采样帧。整体动作自然度与角色精细度仍未验收。

## 2026-10-26 实际接触结果与枪影获取反馈

原来普通攻击接触窗口结束无目标时静默删除，玩家无法区分反击落空与按键失效。现只在当前动作的接触窗口实际结束且没有接触目标时显示单次动作落空；动作取消、受伤或切换时不会误报。反击和闪刺落空分别说明未开启闪刺、未获得枪影；真实反击确认后提示 Ctrl+左键，闪刺确认后显示实际枪影计数。打断提示优先级高于接触结果，多段攻击不逐段刷落空提示。战斗时钟、命中窗口、伤害和资源授予规则未改。

原生动作反馈 20、武器接触 20、HUD 26、可读性 35、输入 19 项通过。新增检查确认窗口结束前不报落空、结束后反击落空无闪刺机会、计数显示及打断提示优先级。武器接触组合测试最初因上一测试的未过期打断提示而失败，给该独立落空场景推进反馈计时后通过，未降低产品提示优先级。自然 AI 输入回放新增实际 hit_confirmed 时刻的反馈检查并通过：反击/闪刺各 3 次、四连刺 4、旋枪 2、终结 2 次接触，生命 240。控制器不代表真人难度，整体造型与手感仍未验收完成。

## 2026-10-26 旋枪两次腿部蓄力

旋枪原来只有随整圈转动的轻微下沉，新增检查在两次命中前均未找到明确的下沉后伸展。现在分别增加第一击前 8.5 厘米、第二击前 4.5 厘米的下沉曲线；在原 0.38、0.85 秒命中时新增项归零，保留原命中高度与时钟。转身、换步、握枪路径、霸体和资源规则沿用。17 段动画库已重新烘焙。

原生转身 21、脚底 83、脚步锁定 16、握持 55、躯干 36、武器追踪 20、战斗规则 32 项通过。新增两次蓄力伸展检查在旧实现均失败，修改后通过。Shubian-spin-leg-load.mp4 为 2.90 秒固定帧率动作研究，预设一层枪影、冻结怪物，不是自然实战或性能证明；录得两次出手，镜头朝向和收势后身体残余转角均为零，已查看中间采样帧。整体造型与全部动作自然度仍未验收完成。

## 2026-10-26 衣摆曲面与随抬腿弯曲

两片衣摆及饰边改用细分曲面与静态垂坠，加入 HemFlex 形变目标：腰口固定，自由下摆随抬腿弯曲，与既有衣摆让位转动配合。饰边按同一空间曲线形变，蒙皮同步形变权重。该实现是确定性的动作驱动形变，不是真实布料模拟，也不证明全部动作无穿插。

导出验证发现旧烘焙器将所有形变轨道硬编码为 OpenHand，现按实际形变名称写入轨道，17 段动画重新烘焙并重导出模型。新增检查路径最初漏写 Pelvis，已修正；旧手指检查只选择 OpenHand，保持原手指展开要求，并新增保存模型衣摆播放检查。原生服装 26、蒙皮 246、装备衔接 18、布料 71、软连接 31、躯干 36 项通过。服装检查覆盖腰口固定、自由下摆弯曲、饰边同步、实时蒙皮同步、保存目标和终结技片段播放。已查看踢击三帧姿态和三面图；直接姿态采样不是自然对战或性能证明。

正常 AI 输入回放在运行期形变实现下通过：反击/闪刺各 3、四连刺 4、旋枪 2、终结 2 次接触，生命 240。控制器不代表真人难度与最终手感，整体美术和动作自然度仍未验收。

## 2026-10-26 棘角奔龙的厚额与钝口鼻

棘角奔龙从共用细口鼻头型改为更宽的钝口鼻与厚额部，保持鼻端纵向最远位置。角的纵向截面改为保形曲线，原根部、尖端与整体范围保持。眼睛、鼻孔按新头部真实三角表面定位，眉脊随眼眶调整；表面定位只在模型创建时进行。其余四怪保存资源经标识规范化后无差异，只有棘角模型更新。前甲和侧腹弱点规则、伤害、时钟均未改；可见头体积变化会改变真实表面接触范围。

已查看修改前后实机模型图，修正过初次表面定位方向错误导致的眼鼻遮挡，并新增实时/保存模型的口鼻宽度与双侧眼鼻离表距离检查。原生表面 106、地面 225、颌部 35、冲扑时序 54、冲扑表面 5 项最终通过；初版亦通过头扫 15、部位 26、投枪 18。正常 AI 侧向控制器通过：30.43 秒、21 次接触，其中侧腹 17、弱点 12，怪物生命归零、角色生命 240，无注入伤害或资源。控制器不是真人难度验证，静态截图不是动作自然度验收；整体怪物美术仍未完成。

## 2026-10-26 苔甲龙头顶防护与破甲外观

在现有头部顶点表面绘制灰绿色骨甲色块和分界，增强完整护甲时的正面防护辨识。缓存原裸露头部网格；实际护甲完整度归零时，与原背甲隐藏一起恢复裸露头部。两种网格顶点完全相同，仅颜色不同，不增加头部命中体积、不改变减伤及弱点规则。新增原始网格资源已保存到模型元数据，保留既有资源与节点标识，其余四怪保存文件无改动。

原生表面 108、部位 28、材质 42、投枪 18、头扫 15、硬直 77 项通过。新增检查覆盖实时/保存外观差异而顶点相同，以及真实 receive_strike 造成破甲后恢复裸露头部。已查看完成后的模型截图，仍为原型品质。正常 AI 输入回放覆盖反击与闪刺获取、资源消耗、四连刺四次、旋枪两次、终结两次接触；该控制器不是最终美术、真人难度或手感验收。

## 2026-10-26 普通转身握点随身体绕转

重新查看用户方天画戟视频 18 至 21 秒采样，复核转身中的握持与落脚。现有普通转身漏掉了旋枪、终结技已有的握点中心随胸口绕转处理，身体转到一半时局部握点落在身后。新增检查在旧实现失败，现统一为三个转身动作携带握点，保留原武器世界朝向曲线与攻击时钟；握点世界路径有意改变。17 段动画已重新烘焙。本轮没有据此宣称动作已完全复刻参考视频。

原生转身 23、握持 55、躯干 36、脚步锁定 16、衔接 22、武器接触 20 项通过。转身检查增加真实 Alt+左键输入入口及半转时握点位于胸前，同时保留原左侧目标实际接触检查。正常 AI 输入连携回放全部通过。Shubian-turn-front-grip.mp4 是 2.45 秒固定帧率冻结 AI 动作研究，录得一次出手、镜头朝向和收势后身体残余角均为零，已查看中间采样帧；不是自然实战、性能或完整无穿插证明。整体动作自然度和美术仍未验收完成。

## 2026-10-26 投枪的骨盆发力与收步

投枪已有胸部拧转，但骨盆没有参与，身体前后转移较小。新增两条蓄力检查在旧实现失败。现补充骨盆配合、后腿下沉和身体前送；前脚回收加入抬脚。松手 0.38 秒、局部投枪曲线及瞄准方向保留；身体位移改变使投射物实际出发位置随之改变，仍从可见武器交接并保留隔墙探测。17 段动画已重新烘焙。

原生投枪交接 18、输入 19、握持 55、脚底 83、瞬移 20、投射物生命周期 14、装备衔接 18、躯干 36 项通过。新增 120Hz 整段采样验证后脚支撑和前脚回收抬起。保存蒙皮检查发现上一轮普通转身握点预期尚未同步，现按绕转中心保留三毫米枪尖位置校验，并增加保存片段胸前握点检查，共 247 项通过。

Shubian-throw-body-drive.mp4 为 3.45 秒固定帧率预设空场研究，通过真实长按/松开处理和飞行/到达流程，投出、落地姿态均被观察到，位移约 15.98 米；敌人隐藏且无碰撞，不是对战难度或性能证明。已查看视频中间采样帧，真人手感和最终动作品质仍未验收。

## 2026-10-26 插地蓄势的抬身与下压

原来 plant 全程使用固定 0.18 米下沉，起手缺少身体上提与随枪下压。新增检查在旧实现有三条失败。现按 0 秒准备 0.09 米、0.18 秒提起 0.06 米、0.48 秒下压 0.22 米、0.65 秒稳住 0.18 米的深度曲线运行，并补充抬枪时胸部轻微后蓄。末端与等待姿态一致，原枪尖贴地采样及反制时钟保持。17 段动画重新烘焙。

原生插地 17、握持 55、躯干 36、脚底 83、装备 18、战斗 32、输入 19、保存蒙皮 247 项通过。新增检查覆盖首帧准备高度、上提后下压，以及进入等待时身体/武器连续；既有坡地、抬高平台、悬空握点检查保留。正常 AI 输入回放的插地迎击与终结两次接触通过，资源规则保持。

Shubian-plant-body-drive.mp4 是 4.10 秒固定帧率冻结 AI 动作研究，使用一次预设伤害触发迎击，不能作为真实 AI 触发或性能证明；研究记录两次出手、生命 240，通过。另已查看抬枪、下压、稳住三帧截图。整体美术、无穿插完整性、真人难度与手感仍未验收完成。

## 2026-10-26 多动作与模型组合版本复核

源版本 dc0799d 的完整原生检查 81/81 一次通过：outputs/verification/regressions-20261025-173936-b26546/summary.json。包含衣摆保存形变、棘角头部、苔甲破甲外观、各腰腿发力、普通转身绕转握点、投枪及插地贴地等最新修改。该结果属于功能与资源检查，不是最终视觉验收。

同一干净源版本的原生五怪连续对战通过：outputs/verification/forest-realtime-20261026-014340-1829d2/summary.json。实际 OpenGL 3.3 Compatibility、RTX 4060 Laptop、NVIDIA 610.88、1280x720、无固定帧率和录像、连续资源，300.63 秒击退五种怪物，角色生命 185、无运行错误。排除场景准备后两秒的 57,002 帧：P99 11.071ms，最大 20.881ms，超过 33.33ms 为 0。全部 57,540 帧中启动阶段有一帧 48.897ms。满足本机稳定阶段预算，不代表消除启动卡顿、其他硬件风险或已确认卡顿根因。兼容渲染管线计数不能排除 OpenGL 编译。控制器不是人类难度、动作自然度和最终美术验收。游戏内容未改，现有 dc0799d 试玩包可继续使用，无需为验证记录重打包。

## 2026-10-26 头发体积与鬓角发束

发帽从分段收尖轮廓改为连续圆弧顶部，增加固定几何发束起伏和轻微不规则发际线，两侧追加渐细的鬓角发束。发束合并在原 HairCap 网格中，沿用既有头部绑定，不新增骨骼或绘制部件。初版近景根部突出的切口已收入发帽内部；源模型与保存蒙皮同步，保留节点和资源标识。没有修改脸型、自定义身份规则或战斗数值。

原生服装 26、保存蒙皮 247、躯干 36、装备衔接 18、角色可见性 26、肩部绑定 8 项通过。正常 AI 输入连携回放通过反击/闪刺各 3、四连刺 4、旋枪 2、终结 2 次接触，生命 240。已查看头部正面/斜侧/侧面与横扫近景三帧；静态与直接姿态采样不代表自然度或完整无穿插证明。近景仍可见肩甲、披肩与上臂衔接粗糙，角色面部和整体造型仍明显是原型，未达到已认可概念图精细度。

## 2026-10-26 披肩随抬臂让位与裸露肩部连接

肩部近景确认披肩原来整片刚性随躯干，上臂抬起时不能让位；裸露肩部的柔性连接还沿用深色布料。现让披肩和包边外侧逐渐混合到对应上臂骨骼，最大权重 0.70，领口保留躯干绑定。肩部柔性连接改为与裸露上臂同色的皮肤材质；肘、膝继续保留布料。未新增骨骼、节点或动作时钟。源与保存模型同步，保留既有标识，仅两处材质类型按用途变更。

原生软连接 39、布料 69、蒙皮 247、肩部 8、握持 55、躯干 36、服装 26、装备 18、可见性 26 项通过。新增检查覆盖披肩/包边对应上臂权重、领口保持固定和保存权重；材质检查明确裸肩为肤色，布料数量由 15 变为 13 并保持实时/保存一致。正常 AI 输入连携回放通过四连刺四次、旋枪两次、终结两次实际接触，生命 240。

已查看横扫和插地抬臂近景；深色肩部断层减少，但肩甲边缘、披肩细节和全部动作穿插仍未最终验收。这是确定性蒙皮让位，不是布料物理模拟；检查通过不等于完成角色整体美术或真人手感目标。

## 2026-10-26 肩甲实体封边

肩甲原来为开放单层曲面。新增闭合边检查在两侧旧模型均失败。现沿既有外表面法线向内收 4 毫米，补内面及所有边界封口，保留外轮廓与肩部枢轴；采用正常背面剔除，避免依赖双面薄片显示内侧。源模型与保存蒙皮同步，未新增骨骼或改变攻击判定。

原生肩部 12、服装 26、握持 55、软连接 39、保存蒙皮 247、布料 69、躯干 36、装备衔接 18、可见性 26 项通过。肩部检查覆盖每条焊接边两面共享、负向有符号实体体积，以及抬臂/转动中的锚点、范围和旋转连续性。正常 AI 输入回放通过四连刺四次、旋枪两次、终结两次接触，生命 240。已查看横扫近景三帧，微小封边不等于解决全部装备穿插；整体角色精度、动作自然度和真人手感仍未验收完成。

### Face profile refinement (2026-10-26)
- Smoothed the existing head and nose longitudinal profiles, narrowed the lower jaw slightly, and reduced the projecting nose tip while burying its attachment into the face. No new parts, materials, rig nodes, or combat changes.
- Inspected the actual front, three-quarter, and side render: eyes, lids, brows and lips remain visible. This is still prototype character art; likeness, final style and human playfeel are not accepted.
- Exported and normalized the saved hunter scene. Native costume 26, skin 247, torso/head motion 36, equipment transition 18 and visibility 26 checks passed (353 checks total). Report: regressions-20261025-181311-4cd341.

### Readable heavy impact and balancing tail (2026-10-26)
- Actual rendered before/45ms/260ms comparison showed ordinary heavy-hit head recoil was too slight at creature framing. Raised heavy/turn/throw recoil multiplier from 1.25 to 2.0; light and interruptible fourfold strengths remain unchanged.
- Added a smaller delayed tail counter-swing (25ms start, 90ms peak, 260ms fully settled), on top of the authored pose. Feet, AI clocks, damage and stagger rules are unchanged; stagger still owns its separate animation.
- Native regression report regressions-20261025-181536-41637e: readability 39, committed lunge 54, creature surface 108, tail skin 97, lunge surface 5, parts 28, all passed (331 checks).
- Normal-AI input replay passed with actual reply 3, flash 3, fourfold 4, spin 2 and finisher 2 contacts, HP 240, 14.97s. This state-aware controller is not human playfeel or difficulty acceptance. Render is a fixed pose fixture, not a full combat demonstration. Overall art and animation remain prototype quality.

### Preserve loaded tail pitch through stagger (2026-10-26)
- Baseline native full suite passed 81/81 on dd7adea (regressions-20261025-181720-0174a7). A separate reproduction then exposed an uncovered defect: reedclaw loses its loaded downward tail pitch on the first stagger frame because only tail yaw was captured.
- Capture and blend the complete tail-root rotation, including pitch, into the existing 220ms stagger transition. Neutral recovery now clears all tail-root axes, so the cancelled leap does not resume. Existing tail-bone blending remains intact.
- Added a full tail-root transform check across all five species: reproduction failed only reedclaw before the fix, then passed all species after it. Native focused suite passed 570 checks: stagger 82, ground 225, tail skin 97, launch 50, lunge pose 46, lunge surface 5, rear attack 65 (regressions-20261025-182138-d6a891).
- Native scripted five-species stagger presentation completed without engine errors. This is scripted strike/physical-launch evidence, not human combat difficulty or final animation acceptance. The full 81-suite result precedes this patch; focused checks cover this patch.

### Preserve interrupted forelimb and grasp poses (2026-10-26)
- Extended the actual stagger-entry transform check to forelimb descendants. Before the fix it failed eight reedclaw parts: both shoulders, both wrists, and the four outer digits. Their loaded grasp was reset immediately because stagger captured no forelimb joints.
- Capture shoulder/wrist/digit rotations at interruption and blend them toward the normal stagger pose over the same existing 220ms interval as the torso and tail. No AI, damage, attack timing, contact-volume definitions or resource rules changed.
- Native focused report regressions-20261025-182435-246ccc passed ground 225, tail skin 97, launch 50, lunge pose 46, lunge surface 5, stagger 110. Additional settled-wrist/claw checks then passed stagger 118 in regressions-20261025-182521-8c5540. Both entry continuity and resting claw spread are covered.
- Five-species native scripted stagger/launch study completed without engine errors. This does not establish final visual quality, human handfeel, or difficulty acceptance; those remain open.

### Cancelled leap recovery no longer replays landing reach (2026-10-26)
- Added a real interruption/recovery check for reedclaw shoulders. Before this patch both shoulders returned to the original leap landing brace after stagger ended, despite the attack being cancelled (120 checks, two failures; regressions-20261025-182706-f151a6).
- Mark neutral interrupted recovery as a cancelled attack and skip only its forelimb landing-reach pose. Normal completed leaps retain the authored landing brace. AI recovery duration, exposed weakness, damage and resource rules are unchanged.
- Native focused suite passed 469 checks: ground 225, launch 50, lunge pose 46, lunge surface 5, physical leap 23, stagger 120 (regressions-20261025-182721-f9857e). Normal leap checks explicitly retain low support stance and forward limbs during ordinary recovery.
- Normal-AI state-aware input replay passed: reply/flash each three contacts, fourfold four, spin two, finisher two, HP 240, 14.97s; actual shadow resource/confirmed feedback checks passed. This is not human handfeel, difficulty, or final art acceptance.

### Combined five-species real-time verification (2026-10-26, dd8d081)
- Ran the complete native expedition after the face, recoil and interrupted-tail/forelimb fixes. Source dd8d08164f0a3ef8ade49fdff836f72d9720764f, tracked worktree clean; report forest-realtime-20261026-022920-278da3/summary.json.
- Five active AI, normal spawn, continuous resources, real-time 1280x720 uncapped OpenGL Compatibility on RTX 4060 Laptop / driver 610.88. Victory in 300.63s, HP185, no runtime errors. Defeat times: mossback 50.38s, thornhorn 128.10s, mistfrill 143.52s, stormcrest 175.78s, reedclaw 300.63s.
- After first two seconds: 56,829 rendered frames, P99 11.069ms, maximum 20.071ms, zero frames over 33.33ms. All 57,364 frames: maximum 47.239ms, one frame over 33.33ms during startup. This does not establish cold-cache or other-hardware performance.
- Actual contacts by species: mossback40, thornhorn27, mistfrill22, stormcrest36, reedclaw23. Recorded weak contacts: thornhorn5, mistfrill3, stormcrest6; no weak contact for mossback/reedclaw in this controller run. Their weakness accessibility/readability remains an explicit acceptance gap, rather than being inferred from victory.
- State-aware tactical controller is privileged and does not prove human difficulty, natural animation or final art acceptance. Full objective remains incomplete.

### Weakness aiming evidence and in-game instruction (2026-10-26)
- Investigated zero mossback/reedclaw weak contacts in the whole-map controller run rather than changing weak volumes. Native reedclaw flank-controller comparison: default pitch produced victory at 42.88s, 24 contacts, zero weak (required-weakness run correctly failed); with ordinary look input raising pitch to zero, victory at 28.93s, 16 contacts, nine weak, HP240. State-aware controllers and controlled starts do not establish human accessibility.
- Native mossback controlled-rear normal light attack produced one real tail-root weak hit, 46.8 damage, HP206; this proves contact at that start, not safe approach or a complete rear-tactics victory.
- Added the existing aiming advice directly to reedclaw target strategy and F1 help: raise the weapon toward exposed flank, vertical mouse input still controls weapon height while locked. Inspected actual 1280x720 target/help capture; text remains visible and separate from warning row. No combat/weakness/damage rule changes.
- Native HUD26/readability39/world17 checks passed (regressions-20261025-183752-da64be). HUD capture accepts species selection for repeatable inspection.
- Fixed the root-contact study teardown to await frame_post_draw only with a native display. Previous headless study printed the successful contact but waited indefinitely for rendering; corrected headless run now exits zero normally. Native run also exited zero. Full weakness readability and human handfeel remain open.

### Spectral acquisition highlight (2026-10-26)
- Inspected actual five-layer rear view. Existing flowing translucent spears were countable, but a newly visible layer had no separate acquisition cue. Added a 350ms emission/opacity highlight only when a layer becomes visible, then return to the existing lifetime fade and temporal flow. Consuming a layer still hides that spear immediately. No resource lifetime, cap, damage or combat timing changes.
- Native combat32/shadow21/skin247 checks passed (regressions-20261025-184220-060a74). New checks cover acquisition, settling, consumption visibility and re-earning. Initial development run failed a missing explicit bool type; corrected before successful verification.
- Actual rendering fixture now advances animation time and saves both acquired and settled images; inspected both. Rendering fixture injects five layers only for appearance inspection, not gameplay proof.
- Separately, normal-AI input replay passed with real flash three contacts, fourfold four, spin two, finisher two, HP240/14.97s; confirmed followup feedback and resource consumption passed. State-aware controller does not prove human handfeel or visual acceptance. Full game art/animation acceptance remains open.

### Curved forelimb and claw surfaces (2026-10-26)
- Compared actual reedclaw close-up with the already smoothed trunk/head. Extended existing shape-preserving longitudinal profile interpolation to forelimbs, palms, fingers and talons, preserving original control rings, endpoints, joints and hierarchy. This also smooths the simple forelimbs of mistfrill/stormcrest. No added nodes/materials or combat timing changes; intermediate visible/contact surfaces do change.
- Exported and normalized all models; only the three biped model scenes changed. Quad scenes remained identical after normalization. Inspected actual reedclaw overall render and three close-up grasp poses (loaded/open, airborne/grasp, landing/reset): segmented outlines are softened, but materials, joins and final anatomy remain prototype quality.
- Native focused suite passed 550 checks: ground225, surface108, lunge pose46, lunge surface5, parts28, projectile parts18, stagger120 (regressions-20261025-184506-b3b4ed). These verify the changed visible/contact surfaces and interrupted grasp transitions, not final art or human playfeel acceptance.

### Visible eyes and pupils on every creature (2026-10-26)
- Investigated mouth/face close-ups. Tooth taper orientation was correct; a more concrete face defect was found by ray-testing actual skull meshes: eye centers on mossback/stormcrest were buried about 0.011 body-size units and mistfrill/reedclaw about 0.0088. Only thornhorn used surface-seated facial features. Narrow-head pupil offsets also left the dark pupil behind the eyeball surface.
- Extended actual-skull surface placement to all species for eyes/nostrils and seated brows relative to the eyes. Set pupil offset independently of head-width multiplier so narrow-head pupils remain visible. Named eyes/pupils consistently; no new nodes/materials, skull shape, AI or combat-rule changes. Moved visible features remain part of the existing mesh-based head-contact representation.
- Exported/normalized all five scenes; post-fix eye center clearance is 0.006 body-size units on every side. Inspected actual reedclaw render; pupil and eye surround are now visible, though full facial anatomy and final art remain prototype quality.
- Native focused suite passed 249 checks: surface148 (including live/saved skull seating and exposed pupils across five species), jaw35, head sweep15, lunge surface5, parts28, projectile parts18. Report regressions-20261025-184848-499540. This does not establish human visual or gameplay acceptance.

### Quieter irregular scale detail (2026-10-26)
- Actual close-ups showed highly regular bright circular scale detail competing with the broad species markings. Added stable per-cell center/size variation and reduced fine-scale albedo modulation from 0.12 to 0.07. Existing species stripe/spot settings, base/weakness colors, distance filtering, geometry, AI and combat rules remain unchanged. No new textures or materials.
- Inspected actual reedclaw overall and three grasp close-ups. Broad dorsal markings and pale flank read more clearly; individual scales are less regular, but the procedural material and overall art remain prototype quality.
- Native skin-material42/surface148 checks passed (regressions-20261025-185128-2c5d67). Export/normalization produced no model scene diff; the shared shader is the only runtime asset change.
- Native 1280x720 uncapped OpenGL3 Compatibility / RTX4060 Laptop 30.02s partial sample completed without errors (forest-performance-1792954346-62640.json). After two seconds: 6009 frames, P99 9.143ms, max17.092ms, zero>33.33ms. All6492 frames include one startup50.581ms frame. This short sample is not a full expedition, other-hardware performance proof, or final visual/human difficulty acceptance.

### Mapped-input continuous combat video (2026-10-26)
- Changed the native combat video fixture to inherit replay_input_sequence rather than the direct-action controller. Kept player input handling enabled, so the recording exercises actual mapped key/mouse events against live AI. No runtime gameplay asset changes.
- Rendered Shubian-input-combat-20261026.avi, then encoded/decoded a 1280x720 60FPS MP4: 901 frames,15.02s,6598487 bytes. Recording used fixed FPS/movie mode and is not performance evidence.
- Input report passed: 148 key events,100 mouse events; actual reply3,flash3,fourfold4,spin2,finisher2 contacts; confirmed followup feedback, resource costs, retained counter shadow and two finisher contacts all passed; HP240/14.97s. This is a state-aware input controller, not human input or difficulty acceptance.
- Inspected decoded mid/late frames. Close-range player/monster silhouette overlap and transparent limb/weapon readability remain visible limitations; the video is review evidence, not final art/animation acceptance. Use it to compare future near-body readability changes.

### Physical trident occlusion cue (2026-10-26)
- The mapped-input combat video exposed a concrete omission: hunter visibility collected skinned body parts but excluded the physical trident. A blocked arm could be visible while the held shaft/head vanished behind the creature.
- Include physical trident meshes in the same per-part foreign-surface occlusion gating; hidden weapon parts are excluded. Use a warmer, slightly more opaque occluded weapon cue to distinguish it from the mint body cue. Unobstructed material, spectral spears, collision and combat timing are unchanged.
- Native equipment18/visibility27/shadow21/trail14 checks passed (regressions-20261025-185631-c40a68). Added a rendered check disabling the body cue while confirming the occluded physical weapon alone remains visible. Existing clear-view/self-overlap checks still passed.
- Re-recorded mapped-input AI sequence, 901frames/60FPS/15.02s; all contact/resource checks passed, HP240. Decoded matched 7.5s frame shows the formerly hidden trident head. Close body/creature overlap remains a visual limitation. Movie-mode results are not performance proof.
- Separate native uncapped 1280x720 RTX4060/OpenGL 30s partial sample completed: after2s5895frames/P99 9.286ms/max16.087ms/zero>33.33ms. All6417frames include one startup51.218ms frame. Report forest-performance-1792954705-57844.json; partial sample is not full expedition/human difficulty or final art acceptance.

### Elongated trunk blocking and matching pursuit clearance (2026-10-26)
- Actual input-sequence probes showed hunter chest/head centers inside mossback trunk at 2.27s and head inside at13.5s. The single central movement capsule left the longitudinal trunk ends unprotected; this was real volume overlap as well as screen overlap.
- Added narrower front/rear vertical capsules to the actor's compound movement footprint: front radius0.20size/offset-0.28size, rear0.22size/offset+0.32size. Central capsule retained. These affect player/enemy/world movement collision, not weapon mesh-contact damage rules. Front shape was tapered back from an initial symmetric trial that prevented the real kick reaching; final mapped-input sequence retains both finisher contacts.
- Added test_trunk_blocking: actual player move_and_slide approaches from front/rear of all five stationary creatures, then tests chest/head centers against actual visible trunk triangles (30 checks). This does not prove arbitrary animated limb/head/tail intersections are absent. Updated pull-wall fixture to start outside the expanded footprint and assert front-trunk wall stopping.
- Full headless suite passed82/82 on the final compound shape before the pursuit-clearance followup (regressions-20261025-190932-b4fc15). Subsequent native pursuit/prewarm/compound checks passed162: committed lunge54, launch50, navigation22, pull6, trunk30 (regressions-20261025-191642-9fb36f).
- First full expedition on final shape with old navigation radius timed out against thornhorn at600.02s, HP240 (forest-hunt-20261026-030932-f3fbfd). Updated pursuit and initial grid preparation from0.34size to0.54size to cover the full compound envelope; added bounded60s progress telemetry. Rerun with updated pursuit passed all five at327.98s, HP240, no runtime errors (forest-hunt-20261026-031531-d35e4f). Grid prewarming was separately verified after pursuit-run startup; it does not change path geometry.
- Native mapped-input movie passed all contacts/resources at15.12s: reply3/flash3/fourfold4/spin2/finisher2. Encoded910frames/60FPS/15.17s MP4 and inspected early rear-approach frame. Movie mode is not performance proof. Native controlled moss root contact and reed flank tactics also passed during shape verification (reed14 contacts/11 weak/26.78s). Human difficulty, all animated overlap and final visual acceptance remain open.

### Native full expedition after compound trunk and pursuit changes (2026-10-26)
- Verified clean tracked source cd6b55df10fbf97b69831f1e87e85de0faffff28 in a complete real-time native expedition, including prebuilt enlarged clearance grids. Report forest-realtime-20261026-031925-a4779c/summary.json.
- Confirmed OpenGL3.3 Compatibility / NVIDIA RTX4060 Laptop / driver610.88,1280x720 uncapped, no fixed FPS/movie mode. All five AI active, continuous resources, state-aware tactical controller. Victory327.98s,HP240, no runtime errors or thornhorn pursuit timeout. This matches the final headless expedition behavior.
- After first2s:54522frames, P99 11.257ms,max20.253ms,zero>33.33ms. All55002frames include one startup50.647ms frame. Initial scene loading precedes benchmark timing; this is local-run performance evidence, not cold-cache/other-hardware proof.
- Weak contacts thornhorn6,mistfrill3,stormcrest6; mossback/reedclaw still lack weakness use in this whole-map tactic despite their separate controlled contact proofs. Full weakness accessibility/readability and human difficulty remain open. No final art/animation/handfeel acceptance is implied by the controller's HP240 victory.

### Player-facing contact names (2026-10-26)
- Replaced raw body/limb/flank/head/tail/spine identifiers in the hunter's hit message with Chinese anatomical labels. Unknown/internal fallback identifiers are omitted. Weak contacts explicitly say weak-point hit; shared show_hit_feedback handles both melee and projectile contacts. Damage values, hit classification, action-event priority and resources are unchanged.
- Native action-feedback20/HUD26/projectile-parts18 checks passed (regressions-20261025-192707-1bb629). Normal-AI input sequence passed all contacts/resource/feedback checks,HP240,15.12s.
- Actual controlled rear light attack generated the message Weak-point hit47/tail in Chinese from a real46.8-damage weak contact; native screenshot inspected with the study-only title hidden so it did not cover the game message. This proves the contact label pipeline, not human weakness accessibility or final handfeel acceptance.

### Forest light and mist color separation (2026-10-26)
- Current ground shader already includes dark wet soil, moss and varying wet roughness. Actual overview/grove/stream captures showed green ambient fill and green mist flattening scene colors. Adjusted ambient color c5cec4->ccd5dc/energy0.55->0.45, fog light7f9c92->879b9e, sun energy0.85->1.0 and color e5e6d5->f1e2c8. Fog density, lighting direction, geometry, collision, actor materials and combat are unchanged.
- Captured matched before/after forest views and inspected overview, grove and close combat render. Cool gray mist separates more clearly from ground/foliage, with stronger warm/cool lit-shadow separation. This is a modest lighting improvement; prototype geometry, shade visibility and overall art still require review.
- Native forest-art12/spawn-visibility1/readability39 checks passed (regressions-20261025-193205-77c26e). Frozen actor idle-view capture reported identical2548draw calls/2625220primitives; P95 frame time8.03ms before/8.10ms after. These short idle samples are not combat performance or human readability acceptance.

### Trident face and bevel contrast (2026-10-26)
- Inspected actual front/oblique weapon close-up: broad blade faces and cutting bevels had almost identical gray values. Added darker cool steel vertex colors to the three broad faces and lighter colors to existing bevels; metal material now uses authored vertex color. Existing primitive metal parts remain white-vertex/base-material colored, spectral shader retains its own appearance.
- No outline/inset/thickness, grip, endpoint, contact marker, timing, mesh count or material count changes. Exported/normalized hunter scene to keep saved weapon consistent with source. Inspected new front/oblique capture: subtle edge separation is visible, while final weapon art still remains prototype quality.
- Native weapon-trace20/visibility27/shadow21/skin247 checks passed (regressions-20261025-193645-05d1ab). This material-only adjustment is not evidence of final human combat readability or handfeel acceptance.

### Flash thrust pelvis drive and stepped recovery (2026-10-26)
- Compared actual flash prepare/contact/recovery poses. Existing legs crouched and stepped, but flash was excluded from body fore/aft transfer and pelvic turn; both recovery feet also slid back on the same curve.
- Added a short0.08s rear load, coupled existing flash torso curve to body/pelvis, and staggered lifted return steps (lead0.30-0.47s, rear0.47-0.58s). Direct canonical load-to-contact body transfer is0.16m. Weapon-local attack curve, actual dash velocity, hit0.23s, chain0.39s and duration0.58s remain unchanged; changed body pose alters world-space weapon position.
- Added flash samples to the existing pose capture and extended hip-transfer checks to drive, support, nonpenetration, lifted recovery and neutral endpoint. Re-baked17 saved clips. Native hip53/hand55/legs106/skin247/stance22/trace20 checks passed (503 total; regressions-20261025-194222-5623ba). Reply-to-flash first-frame ankle displacement measured0.0092m in the existing continuity check.
- Normal-AI mapped-input sequence passed all resource/contact/feedback checks: reply3,flash3,fourfold4,spin2,finisher2,HP240/15.12s. Actual prepare/contact/follow-through render inspected; still prototype character art and not human handfeel/difficulty acceptance.
