import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jingxin_meditation/providers/meditation_provider.dart';
import 'package:jingxin_meditation/screens/meditation_screen.dart';

/// 第 34 轮长会话稳固性巡检回归：
/// 3 秒倒计时中途退出时，dispose 里 `late Timer` 未赋值即 cancel
/// 会抛 LateInitializationError。修复后任何时刻退出都不崩。
void main() {
  testWidgets('倒计时中途退出不崩溃（late Timer 修复）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MeditationScreen(
          durationMinutes: 1,
          settings: const BreathSettings(4, 4, 6),
        ),
      ),
    );
    // 倒计时（3 秒）尚未走完就卸载——旧实现此处抛 LateInitializationError。
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    // 再让残留的周期计时器空转几秒，确认无异常（无 setState after dispose）。
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('倒计时走完进入冥想后退出也不崩溃', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MeditationScreen(
          durationMinutes: 1,
          settings: const BreathSettings(4, 4, 6),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4)); // 倒计时结束，主计时器接管。
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
