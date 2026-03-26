import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import 'enhanced_login_screen.dart';
import '../onboarding/questionnaire_screen.dart';
import '../main/home_screen.dart';
import '../../widgets/aurora_background.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        debugPrint(
          '🔥 AuthWrapper rebuild: isLoading=${appState.isLoading}, user=${appState.user?.uid}, isAuthenticated=${appState.isAuthenticated}, onboarding=${appState.isOnboardingComplete}',
        );

        // Show loading screen while initializing
        if (appState.isLoading) {
          debugPrint('🔥 AuthWrapper: Showing loading screen');
          return Scaffold(
            body: AuroraBackground(
              intensity: 0.6,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3.w,
                ),
              ),
            ),
          );
        }

        // User is authenticated and verified (verification check is handled in sign-in)
        if (appState.user != null) {
          // User is verified - proceed with normal flow
          if (appState.isOnboardingComplete) {
            debugPrint('🔥 AuthWrapper: Navigating to HomeScreen');
            return const HomeScreen();
          } else {
            debugPrint('🔥 AuthWrapper: Navigating to QuestionnaireScreen');
            return const QuestionnaireScreen();
          }
        }

        // Default to login screen
        debugPrint('🔥 AuthWrapper: Navigating to LoginScreen');
        return const EnhancedLoginScreen();
      },
    );
  }
}
