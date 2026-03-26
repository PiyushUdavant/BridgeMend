import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/aurora_background.dart';
import '../../theme/app_theme.dart';
import '../../providers/firebase_app_state.dart';
import 'start_screen.dart';
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _navigateToNextScreen();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final appState = context.read<FirebaseAppState>();
    debugPrint(
      '🔥 SplashScreen: Initial state - isLoading=${appState.isLoading}, isAuthenticated=${appState.isAuthenticated}',
    );

    // Wait for Firebase to initialize if it's still loading
    while (appState.isLoading && mounted) {
      debugPrint('🔥 SplashScreen: Still loading, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    debugPrint(
      '🔥 SplashScreen: Final state - isLoading=${appState.isLoading}, isAuthenticated=${appState.isAuthenticated}, onboarding=${appState.isOnboardingComplete}',
    );

    // Check if user is already authenticated
    if (appState.isAuthenticated) {
      debugPrint(
        '🔥 SplashScreen: User is authenticated, navigating to AuthWrapper',
      );
      // Returning user - go directly to AuthWrapper (which will route to appropriate screen)
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      debugPrint(
        '🔥 SplashScreen: User not authenticated, navigating to StartScreen',
      );
      // New user - show start screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const StartScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        intensity: 0.7,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(size: 168, animate: true),
                      SizedBox(height: AppTheme.spacingL),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            AppTheme.gradientStart,
                            AppTheme.gradientEnd,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Mend',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 58.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Healing relationships through AI',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.8,
                              ),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 80.h),
                      SizedBox(
                        width: 30.w,
                        height: 30.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primary.withValues(alpha: 0.6),
                          ),
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
