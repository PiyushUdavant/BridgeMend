import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mend_ai/services/hive_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/firebase_app_state.dart';
import 'screens/auth/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://tksgdsemivndomklxtjw.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_3e1DFHW-ZIl5rWQw2cxvTA_NLNmzoP1',
    ),
  );

  runApp(const MendApp());
}

class MendApp extends StatelessWidget {
  const MendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FirebaseAppState()..initialize(),
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'Mend',
            theme: AppTheme.lightThemeData,
            darkTheme: AppTheme.themeData,
            themeMode: ThemeMode.system,
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => AuroraBackground(
              intensity: 0.55,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
