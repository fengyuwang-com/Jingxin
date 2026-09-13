# Jingxin TODO

## 愿景（2026-09-13 定稿）
把静心从冥想工具重构成游戏《静境》：呼吸即唯一操作、无失败无分数、苏醒度即进度、心境星图 + 心镜碎片、睡前长夜收尾。视觉保持 CYBER-ZEN。

## 队列
- [ ] 通宵升级循环运行中：每 20 分钟一轮《静境》游戏化增量（automation-1ded3cbe-a45e-4b61-8964-f74fc9a7ca6a），进度看 UPGRADE-LOG.md 和 git log
- [ ] （可选）装 Visual Studio C++ 工作负载以支持 Windows 桌面构建

## 已完成
 - [x] 第22轮：arm64 瘦身包（--split-per-abi：arm64-v8a 17.3MB / v7a 14.9MB / x86_64 18.7MB，对比 fat release 49MB 降约 65%）+ 世界数值配平巡检（各系统增速/阈值复核无卡死点； awakening/mist_guardian 补设计意图注释；修 weary_heath 灯台余温 clamp 漂移真 bug→decayBeaconFuel；新增 weary_heath_test 4 项共 24 测试全过；analyze 19 基线/ build web 过，commit 8b28d28）
- [x] 第21轮：腾讯镜像手动装 NDK r27c（27.2.12479018，Sdk/ndk/）+ build-tools 35.0.0（Sdk/build-tools/35.0.0），app/build.gradle.kts 固定 ndkVersion；flutter build apk --debug 成功（app-debug.apk 147.5MB fat）+ --release 成功（49.0MB，debug 签名）；analyze 0 error（19基线）/test 20 全过/build web 成功，commit 5158f3b

- [x] 第20轮：Android 构建链路验证（licenses 全签 doctor [√]；修 JDK25↔Gradle8.14 不兼容→Adoptium21 + 项目 gradle.properties 固定；独立 GRADLE_USER_HOME .gradle-jingxin 隔离全局 JDK25 强制配置；web/index.html title「静境 · 用呼吸玩」+description；analyze 0 error/test 20 过/build web 过，commit f155a18；APK 因 AGP 自动下载 NDK r27（dl.google.com 慢）仍在后台进行，下轮收尾）

 - [x] 第18轮：「相会」——眠与惘的稀有时刻（新增 lib/game/reunion.dart：纯函数触发判定 ReunionTrigger（眠游弋期+惘 reveal>0.85+苏醒度>0.5+光灵离两兽连线中点<260，且仅在平稳呼吸循环瞬间评估）+ 小状态机演出 ReunionPhase（approach 26s 各移近≤200px→glow 8s 星光细线+静之径短暂亮起+径上尘聚拢小圈+中点星→3 圈青色深海鸣涟漪 3.2s→retreat 16s 各退回），全程无文字无锁定；双星碎片金色 0xFFe8c96a 走拾取/星图全链路 region「两兽之间」+ 相会偈语池 2 句；swimUntilEpoch 记账每游弋周期至多一次；test/reunion_test.dart 6 项；analyze 0 error（19基线）/test 20 全过/build web 通过，commit e51c665）
- [x] 第17轮：星兽惘——雾林守林者（新增 lib/game/mist_guardian.dart：11 节点星座狐+5 节细尾，锚点 nx0.06/ny0.50 视差 0.80 比林稍深，平时 alpha≤0.06 青灰微光；苏醒与眠差异化=显形度直接跟随雾林沉降度（升限速 60s 最短渐进、雾回升退回雾里），显形后向光灵走出几步≤140px+尾轻摆+眼亮柔光；完全显形>0.85+靠近<300+平稳循环→2.8s 点头轻触送金色心镜碎片（MindShard gift 标记+惘语池 3 句：被看见/不孤单），每显形期至多一次；性能按 16 轮纪律（Path 缓存/画笔复用/眼辉光量化缓存/屏外跳过/低档雾尘 5）；analyze 0 error（19 基线）/test 14 全过/build web 通过）

- [x] 第16轮：性能 profile 与移动端适配 pass（审计修复：camPos 共享缓冲（原每次读取分配 Vector2）；光灵 7 个每帧 RadialGradient→固定半径着色器缓存+canvas 缩放；渊/荒原全屏渐变、雾团/薄霭/灯笼/眼睛辉光、星岛/碎片辉光按量化参数缓存；星兽星座 Path 静态缓存；星岛剪影 Path 缓存；海层约 30 个每帧 Paint 复用；bbox 剔除全数核查无漏网；触控=TapCallbacks 无拖拽/长按冲突确认；新增 lib/game/quality.dart 画质档位（桌面高档/移动中档/低内存或高DPR或原生移动壳低档：星空减半 45、雾 2 层、尾迹 3、微粒 10、径尘 5、海屑 14、雨丝 10，构造时读取零运行分支，无 UI 呈现）；声景/灵敏度 chips 命中区 ≥44px；长夜 NoSleep 有意不做已注释；build/web 41MB（引擎产物 37MB，应用 3MB，非异常）；analyze 0 error（19 基线）/test 14 全过（+quality_test 5 项）/build web 通过，commit 79575ff）

- [x] 第15轮：「拾忆」——心镜导出与带回（新增 lib/game/memento.dart：MementoCodec 导出 `jx-memo-v1:<base64(utf8(json))>`（v1 格式+schema 注释，含碎片时间戳+禅语+区域+苏醒度+星兽状态），tryDecode 容错静默失败；mergeShards 按时间戳+禅语去重合并不覆盖、按时间排序返回新增数；星图右上角极小「拾忆」图标→玻璃拟态底部抽屉（ZenMotion 入场）：带我的心境走（Clipboard+淡字「已复制，收好」）/看一眼足迹（纯文本第一次+最近一次回顾）/放回心镜（粘贴+归位，失败「这段记忆读不出来」成功「心镜归位了，共 N 片」）；star_beast 加 swimUntilEpoch getter；analyze 0 error（19基线）/flutter test 9 项通过（新增 shard_merge_test.dart 8 项）/build web 通过，commit 5fe9009）
- [x] 第10轮：随息——麦克风呼吸检测输入层（breath_mic.dart 条件导入：Web 用 js_interop+package:web getUserMedia+AnalyserNode RMS；非 Web stub 静默降级、UI 隐藏入口；隐私克制不录音不存储+首次「只听气息，不留声音」；慢速自动增益基线（上涨τ30s/下跌τ1.5s）+灵敏度3档（低/中/高，持久化 jingxin.mic.sens.v1）+两级低通杜绝抖动；吹气=呼气相位映射；双输入最近活跃者仲裁，触控随时接管；失败淡字「随息未就绪，轻触亦可行」绝不弹窗；退出页面彻底 stop 释放轨道；analyze 0 error（19条低于基线）/build web 通过，commit 07e483f）
- [x] 第11轮：手感与视觉打磨 pass（①开场苏醒：星按错落时刻逐颗亮起+光灵缓现+一行淡字「你的呼吸，点亮这个世界」2.2s淡入6s自去；②光灵生命感：边缘28段顶点微扰噪声形变+游动反向尾迹光尘+平静积累 calmGlow（约10平稳循环满，光灵+18%光晕+5%半径）；③相机呼吸微动：camPos=基准跟随+呼吸同相极小位移(1.4/2.2px)getter，组件零改动；④转场统一 ZenMotion 800ms easeOutCubic（首页→冥想/静境 500ms 提升、星图曲线统一）+AppLifecycle 后台声景0.8s缓停/回前台长夜3s浮起；⑤性能：微粒参数预生成+TextPainter只layout一次+碎片逆序遍历去List.of+星空画笔复用+星云着色器量化缓存；稀有「世界的回应」：约6%平稳循环后远处星按平方亲和度同眨一眼0.9s，无文字；analyze 0 error（19基线无新增）/build web 通过，commit c8d924c）
- [x] 第7轮：第二心境区域「焦虑之渊」——区域抽象 regions.dart（深度带 0.80→0.93 漫游即达，无加载无传送门）；乱星36颗快速低亮明灭，平稳呼吸时频率/相位渐被同化为8s温柔脉动、离开极缓恢复杂乱；渊底心跳微光9s极慢脉动；5朵星花按附近乱星同化度开合（当次反馈）；渊中碎片用专属渊语池+「焦虑之渊·XX」九宫格命名；analyze 0 error/build web 通过，commit b5a98e6
- [x] 第6轮：长夜收尾——白噪音声景引擎（soundscape.dart 条件导入：Web 用 js_interop+package:web 合成粉红噪声 Paul Kellet 8s 循环+480Hz 低通+0.06Hz LFO 海潮起伏，淡入4s/淡出3s；非 Web 静音降级；右下角小月亮入口进入长夜——nightAmount 4s 渐变深夜色调/星更亮/光灵光晕收拢，提示语"世界睡了，你也可以睡了"；长夜记忆 shared_preferences 只存不用；AudioContext 手势内创建规避自动播放；analyze 0 error/build web 通过）
- [x] 第5轮：星兽眠——长线苏醒与睁眼（失眠之海深处星座连线巨魟，平时隐约轮廓；独立苏醒累计跨会话持久化：平稳循环+0.004/附近循环+0.012/碎片+0.02；5档每档缓睁一只眼约4s渐变+涟漪+星屑聚拢；满值游弋150s后归零重睡循环而非终局；星图页底部极淡措辞一行；analyze 0 error/build web 通过，commit 7fe81ab）
- [x] 第4轮：心镜碎片收集与静境星图回看（每轮2~4片程序放置，靠近+平稳呼吸循环轻吸入smoothstep 1.6s不打断漫游；禅语玻璃面板淡入停留5s淡出，IgnorePointer不挡操作；20句禅语池近4句不重复；收集史shared_preferences存时间+禅语+九宫格区域名；星图页黄金角螺旋星座+点星看偈语日期+空状态；左下角极小入口；analyze 0 error/build web 通过，commit df1313f）
- [x] 第3轮：失眠之海——呼吸驱动漫游与星岛苏醒（吸气蓄力朝触点上浮/呼气滑行，限速55px/s无急停；3层正弦星潮+26颗失眠星屑视差层；7座星礁靠近+平稳呼吸逐个亮起；世界2400x1800环绕无边界；analyze 0 error/build web 通过，commit 1d5ce39）
- [x] 第2轮：呼吸输入层+苏醒度雏形（TapCallbacks按住吸气/松开呼气，AwakeningState持久化+驱动星空/色温/光晕，顶端极细光线+呼吸提示词，analyze/build通过）
- [x] 第1轮：Flame骨架（flame 1.38.2，游戏循环 + 光灵原型 + 静境入口，analyze/build 通过，commit ba43e63）
- [x] Flutter 3.47.4 安装（C:\FengProj\flutter），pub 镜像 flutter-io.cn，PATH 永久配置
- [x] tag v1.0-pre-jingjing 已推送 GitHub（重构前最终版）
- [x] 基线验证：pub get / analyze 0 error / flutter build web 通过
- [x] 第8轮：多声景——夜雨与篝火（soundscape.dart 扩展为 SoundscapeEngine 三声景 sea/rain/campfire + select 交叉渐变 2.5s；Web 层架构全声景汇入 master gain 0.5 防爆音、层懒构建复用、噪声素材共用；夜雨=粉噪雨幕底+稀疏带通雨滴瞬态（90~410ms 随机音高）+25~60s 遥远低频雷滚；篝火=棕噪 220Hz 暖底+噼啪脉冲簇+0.05Hz 音量摇曳；长夜中玻璃拟态三小字切换（海潮·夜雨·篝火）持久化 jingxin.soundscape.v1；视听联动：夜雨 ≤18 条雨丝 alpha 0.10、篝火暖色偏移 alpha 0.055，随长夜程度消散；analyze 0 error/build web 通过）
- [x] 第9轮：第三心境区域「疲惫荒原」——regions.dart 增 upper 上部带支持（ny 0.05~0.18，与渊镜像对称、上浮即达、smoothstep 淡入）；新建 weary_heath.dart：26 颗暗金余烬星尘（几乎静止≤30）+ ny 0.115 一条黎明地平线微光（16s 极缓明灭）+ 3~4 座灯台剪影「重燃」机制（靠近+平稳呼吸约22s≈2~3循环累积，可倒退不归零，lit 当次会话锁存，重燃后 5.5s 暖光脉动呼应篝火声景）；碎片按 i%3 分区（海/渊/荒原），koans.dart 新增 8 句荒原偈（休息/允许/不勉强）；analyze 0 error（23 条既有无新增）/build web 通过
- [x] 第13轮：第四心境区域「纷心雾林」——雾沉降与墨枝灯笼（regions.dart 新增水平边缘带支持：世界 x 接缝两侧 nx<=0.36 浮现/0.14 深入 + ny 门带 0.28~0.72，与渊/荒原深度带零重叠，regionAt/depthAtPoint 扩展；新建 mist_wood.dart：3 层视差 18 团大尺寸低频雾带缓漂 + 14 颗心事萤（无规则略急促游移）；核心「雾沉降」：林中平稳呼吸 45s 沉到底/乱呼吸 3min 极缓回升——雾团下沉变薄、贴地萤光薄霭浮现、萤轨迹变慢变柔转暖；2 棵墨枝剪影 settle>0.65 枝头 5 节点逐颗点亮成雾灯笼（当次反馈）；碎片 i%3→i%4 四区轮转（雾林碎片贴接缝青灰色），koans 新增 8 句雾语池；analyze 0 error（19 基线）/build web 通过，commit 2c3a4c6）
- [x] 第12轮：闻声——禅语轻声朗读与入睡引导（voice.dart 门面+条件导出：voice_web.dart 用 package:web 调浏览器原生 SpeechSynthesis（优先 zh-CN 声音，onvoiceschanged+温和探测同步 available；lang 恒 zh-CN；rate0.85/pitch0.95/volume0.5），voice_stub.dart 非 Web 静音降级 UI 隐藏；左下角小喇叭开关持久化 jingxin.voice.v1 默认关；触发：碎片禅语朗读/长夜每 90~150s 一句入睡引导（koans.dart 新 10 句极短池）/星图点星可选读偈；礼仪：新读先 cancel、whisper 触摸即停 koan 读完、退出长夜/退出静境/切后台 cancelAll；SoundscapeEngine.duck 0.5→0.3 1s 压下 2s 恢复；analyze 0 error（19 基线）/build web 通过，commit 451eb10）
- [x] 第14轮：「静之径」——区域间的余温旅程线（新增 lib/game/still_path.dart：6 锚点 Catmull-Rom 曲线（荒原顶部→穿雾林接缝 x=0→海中带掠过星兽上空→沉入渊底），81 采样点缓存为静态 Path；渲染按最短环绕距离平移+接缝镜像副本+bbox 剔除，无缝衔接；视觉宽26px柔光带+7px窄芯 alpha 峰值≤0.12 + 10 颗径上尘缓明灭；回应机制：光灵在径上<40px且平稳呼吸→走过段「余温」亮起约16s缓缓褪去；透明度与苏醒度轻联动（0.8+0.2×awakening）；性能：静态 Path 缓存+画笔预建+屏外跳过+update 零分配；analyze 0 error（19基线）/build web 通过，commit ded0ce8）
