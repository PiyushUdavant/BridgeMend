import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/gradient_button.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';
import 'auth_wrapper.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        intensity: 0.6,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: AnimatedBuilder(
              animation: Listenable.merge([_slideAnimation, _fadeAnimation]),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom -
                              (AppTheme.spacingL * 2),
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              SizedBox(height: 40.h),

                              const AppLogo(size: 100, animate: false),

                              SizedBox(height: AppTheme.spacingL),

                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        AppTheme.gradientStart,
                                        AppTheme.gradientEnd,
                                      ],
                                    ).createShader(bounds),
                                child: Text(
                                  'Welcome to Mend',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        fontSize: 36.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              SizedBox(height: AppTheme.spacingM),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  'Your journey to better communication starts here',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              SizedBox(height: 40.h),

                              // Feature highlights
                              AnimatedCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingL,
                                  ),
                                  child: Column(
                                    children: [
                                      _buildFeatureHighlight(
                                        Icons.favorite_rounded,
                                        'Strengthen Your Bond',
                                        'AI-guided conversations to deepen understanding',
                                      ),
                                      SizedBox(height: AppTheme.spacingM),
                                      _buildFeatureHighlight(
                                        Icons.chat_bubble_outline_rounded,
                                        'Better Communication',
                                        'Learn effective patterns through guidance',
                                      ),
                                      SizedBox(height: AppTheme.spacingM),
                                      _buildFeatureHighlight(
                                        Icons.insights_rounded,
                                        'Track Progress',
                                        'Monitor your relationship growth with insights',
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const Spacer(),

                              SizedBox(height: 32.h),

                              // Get Started button
                              SizedBox(
                                width: double.infinity,
                                child: GradientButton(
                                  onPressed: _navigateToLogin,
                                  text: 'Get Started',
                                  icon: Icons.arrow_forward_rounded,
                                ),
                              ),

                              SizedBox(height: AppTheme.spacingM),

                              Text(
                                'Join thousands of couples building stronger relationships',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textTertiary),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(height: AppTheme.spacingL),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureHighlight(
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
