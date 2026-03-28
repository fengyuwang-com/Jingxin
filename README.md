# 静心 (JingXin) - 冥想引导应用

极简风格的移动端冥想应用，支持呼吸、正念、引导、放松四种冥想模式。

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行开发版本
flutter run

# 构建 Web 版本
flutter build web

# 构建 Android APK
flutter build apk --debug

# 构建 iOS
flutter build ios
```

## 项目架构

```
lib/
├── main.dart                     # 应用入口
├── models/
│   └── meditation_session.dart   # 数据模型
├── providers/
│   └── meditation_provider.dart  # 状态管理 (Provider)
├── screens/
│   ├── home_screen.dart          # 首页
│   ├── meditation_screen.dart    # 冥想页面
│   ├── history_screen.dart       # 历史记录
│   └── settings_screen.dart       # 设置
├── widgets/
│   ├── breathing_circle.dart     # 呼吸动画组件
│   └── mode_card.dart            # 模式选择卡片
└── theme/
    └── app_theme.dart            # 主题配置
```

## 核心模块

### 1. 数据模型 (models/)

**MeditationSession** - 冥想记录
- `id`: 唯一标识
- `startTime`: 开始时间
- `durationSeconds`: 持续秒数
- `mode`: 冥想模式 (breathing/mindfulness/guided/relaxation)
- `completed`: 是否完成

### 2. 状态管理 (providers/)

**MeditationProvider** - 全局状态管理
- `_selectedDuration`: 用户选择的冥想时长
- `_selectedMode`: 用户选择的冥想模式
- `_sessions`: 冥想历史记录
- `totalMinutes`: 累计冥想分钟数
- `streakDays`: 连续打卡天数

使用 Provider 模式，通过 `ChangeNotifier` 管理状态。

### 3. 页面 (screens/)

| 页面 | 功能 |
|------|------|
| HomeScreen | 首页，包含快速开始、时长选择、模式选择 |
| MeditationScreen | 冥想进行页面，包含倒计时、动画、控制按钮 |
| HistoryScreen | 历史记录，展示所有冥想记录 |
| SettingsScreen | 设置页面 |

### 4. 组件 (widgets/)

| 组件 | 功能 |
|------|------|
| BreathingCircle | 呼吸动画圆环，4-7-8 呼吸法 |
| ModeCard | 冥想模式选择卡片 |

### 5. 主题 (theme/)

**AppTheme** - 深色主题配置
- 主背景: #0D1117 (深空黑)
- 次背景: #161B22 (深灰)
- 强调色: #58A6FF (宁静蓝)

**AppColors** - 颜色常量
**AppSpacing** - 间距常量
**AppSizes** - 尺寸常量

## 冥想模式

1. **呼吸冥想 (Breathing)** - 4-7-8 呼吸法
   - 吸气 4 秒
   - 屏息 7 秒
   - 呼气 8 秒

2. **正念冥想 (Mindfulness)** - 身体扫描
   - 依次感受脚趾、双脚、腿部、腹部、胸部、手臂、双手、肩膀、颈部、头部

3. **引导冥想 (Guided)** - 步骤引导
   - 10 个步骤的冥想引导

4. **放松冥想 (Relaxation)** - 可视化场景
   - 海浪动画 + 场景描述

## 技术栈

- **Flutter 3.x** - 跨平台框架
- **Provider** - 状态管理
- **shared_preferences** - 本地数据持久化
- **intl** - 日期格式化

## 数据持久化

使用 `shared_preferences` 存储冥想记录为 JSON 格式。

```dart
// 保存
await prefs.setString('meditation_sessions', sessionsJson);

// 加载
final sessionsJson = prefs.getString('meditation_sessions');
```

## 响应式设计

- 使用 `LayoutBuilder` 适配不同屏幕尺寸
- 呼吸动画圆环大小 = 屏幕宽度 * 0.7
- 最小触摸区域 = 44px

## 生命周期处理

使用 `WidgetsBindingObserver` 处理应用生命周期：
- 暂停时记录时间
- 恢复时扣除后台时间
- 确保冥想计时准确

## 构建输出

| 平台 | 命令 | 输出目录 |
|------|------|----------|
| Web | `flutter build web` | build/web/ |
| Android | `flutter build apk --debug` | build/app/outputs/flutter-apk/ |
| iOS | `flutter build ios` | build/ios/ |

## 后续功能规划

- [ ] ambient sounds - 环境音（雨声、海浪声、森林声）
- [ ] haptic feedback - 呼吸切换时的触感反馈
- [ ] streak animations - 连续打卡庆祝动画
- [ ] 冥想数据统计图表
- [ ] 自定义呼吸节奏
- [ ] 多语言支持
