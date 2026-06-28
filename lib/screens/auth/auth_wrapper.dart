import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mend_ai/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import 'enhanced_login_screen.dart';
import '../onboarding/questionnaire_screen.dart';
import '../main/home_screen.dart';
import '../../widgets/aurora_background.dart';

class AuthWrapper extends StatefulWidget {
    const AuthWrapper({super.key});

    @override
    State<AuthWrapper> createState() => _AuthWrapperState();
  }

  class _AuthWrapperState extends State<AuthWrapper> {
    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final appState = context.read<FirebaseAppState>();
        if (appState.justSignedOut) {
          appState.consumeSignedOutFlag();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Signed out successfully',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }

    @override
    Widget build(BuildContext context) {
      return Consumer<FirebaseAppState>(
        builder: (context, appState, child) {
          debugPrint(
            '🔥 AuthWrapper rebuild: isLoading=${appState.isLoading}, '
            'user=${appState.user?.id}, '
            'isAuthenticated=${appState.isAuthenticated}, '
            'onboarding=${appState.isOnboardingComplete}',
          );

          if (appState.isLoading) {
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

          if (appState.user != null) {
            if (appState.isOnboardingComplete) {
              return const HomeScreen();
            } else {
              return const QuestionnaireScreen();
            }
          }

          return const EnhancedLoginScreen();
        },
      );
    }
  }
