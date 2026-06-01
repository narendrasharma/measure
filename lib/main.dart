import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/measure_screen.dart';
import 'screens/history_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MeasureApp());
}

class MeasureApp extends StatelessWidget {
  const MeasureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DimScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/home': (_) => const HomeScreen(),
        '/measure': (_) => const MeasureScreen(),
        '/history': (_) => const HistoryScreen(),
      },
    );
  }
}
