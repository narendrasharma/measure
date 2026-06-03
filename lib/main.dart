import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/measure/measure_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Measure',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    initialRoute: '/',
    routes: {
      '/':        (_) => const HomeScreen(),
      '/measure': (_) => const MeasureScreen(),
      '/history': (_) => const HistoryScreen(),
    },
  );
}
