import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/meditation_provider.dart';
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

class ZenApp extends StatefulWidget {
  const ZenApp({super.key});

  @override
  State<ZenApp> createState() => _ZenAppState();
}

class _ZenAppState extends State<ZenApp> {
  late final MeditationProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = MeditationProvider();
    _provider.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<MeditationProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: '静心 | CYBER-ZEN',
            debugShowCheckedModeBanner: false,
            theme: provider.theme,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
