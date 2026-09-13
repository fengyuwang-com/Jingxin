# Jingxin TODO

## 愿景（2026-09-13 定稿）
把静心从冥想工具重构成游戏《静境》：呼吸即唯一操作、无失败无分数、苏醒度即进度、心境星图 + 心镜碎片、睡前长夜收尾。视觉保持 CYBER-ZEN。

## 队列
- [ ] 通宵升级循环运行中：每 20 分钟一轮《静境》游戏化增量（automation-1ded3cbe-a45e-4b61-8964-f74fc9a7ca6a），进度看 UPGRADE-LOG.md 和 git log
- [ ] （可选）flutter doctor --android-licenses 正在后台签署
- [ ] （可选）装 Visual Studio C++ 工作负载以支持 Windows 桌面构建

## 已完成
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
