import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/firebase_app_state.dart';
import 'screens/auth/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
