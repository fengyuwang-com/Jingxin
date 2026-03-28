import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ZenApp());
}

class ZenApp extends StatelessWidget {
  const ZenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '静心 | CYBER-ZEN',
      debugShowCheckedModeBanner: false,
      theme: ZenTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
