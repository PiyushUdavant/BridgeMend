import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/aurora_background.dart';
import 'auth_wrapper.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class EnhancedLoginScreen extends StatefulWidget {
  const EnhancedLoginScreen({super.key});

  @override
  State<EnhancedLoginScreen> createState() => _EnhancedLoginScreenState();
}

class _EnhancedLoginScreenState extends State<EnhancedLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showEmailForm = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart),
        );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final error = await context.read<FirebaseAppState>().signInWithGoogle();

      if (error != null && mounted) {
        _showErrorSnackBar('Failed to sign in: $error');
      } else if (mounted) {
        // Sign in successful - navigate to AuthWrapper
        debugPrint(
          '🔥 EnhancedLoginScreen: Sign in successful, navigating to AuthWrapper',
        );
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AuthWrapper(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Unexpected error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final error = await context.read<FirebaseAppState>().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (error != null && mounted) {
        _showErrorSnackBar(error);
      } else if (mounted) {
        // Sign in successful - navigate to AuthWrapper
        debugPrint(
          '🔥 EnhancedLoginScreen: Email sign in successful, navigating to AuthWrapper',
        );
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AuthWrapper(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Unexpected error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.interruptionColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
    );
  }

  void _toggleEmailForm() {
    setState(() {
      _showEmailForm = !_showEmailForm;
    });

    if (_showEmailForm) {
      _fadeController.forward();
      _slideController.forward();
    } else {
      _fadeController.reverse();
      _slideController.reverse();
    }
  }

  void _navigateToSignUp() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SignUpScreen(),
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
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ForgotPasswordScreen(email: _emailController.text.trim()),
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
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingText: 'Signing you in...',
      child: Scaffold(
        body: AuroraBackground(
          intensity: 0.6,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 20.h),

                    // App Logo with animation
                    const AppLogo(size: 120, animate: true),

                    SizedBox(height: AppTheme.spacingL),

                    // App Name with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                      ).createShader(bounds),
                      child: Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: 36.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingS),

                    Text(
                      'Sign in to continue your journey',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 40.h),

                    // Google Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _signInWithGoogle,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.gradientStart,
                                AppTheme.gradientEnd,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLoading && !_showEmailForm)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              else ...[
                                SvgPicture.asset(
                                  'assets/google_logo.svg',
                                  width: 20,
                                  height: 20,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppTheme.textTertiary.withValues(alpha: 0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                          ),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppTheme.textTertiary.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Email Sign In button or form
                    if (!_showEmailForm) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _toggleEmailForm,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'Sign in with Email',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Email Sign In Form
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _fadeAnimation,
                          _slideAnimation,
                        ]),
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: AnimatedCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingL,
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        // Email field
                                        TextFormField(
                                          controller: _emailController,
                                          validator: _validateEmail,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Email',
                                            labelStyle: TextStyle(
                                              color: AppTheme.textSecondary,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.email_outlined,
                                              color: AppTheme.primary,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.textTertiary,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.textTertiary
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color:
                                                    AppTheme.interruptionColor,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                          height: AppTheme.spacingM,
                                        ),

                                        // Password field
                                        TextFormField(
                                          controller: _passwordController,
                                          validator: _validatePassword,
                                          obscureText: _obscurePassword,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Password',
                                            labelStyle: TextStyle(
                                              color: AppTheme.textSecondary,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                              color: AppTheme.primary,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: AppTheme.textSecondary,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword =
                                                      !_obscurePassword;
                                                });
                                              },
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.textTertiary,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.textTertiary
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.radiusS,
                                                  ),
                                              borderSide: BorderSide(
                                                color:
                                                    AppTheme.interruptionColor,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                          height: AppTheme.spacingS,
                                        ),

                                        // Forgot password link
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed:
                                                _navigateToForgotPassword,
                                            child: Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                          height: AppTheme.spacingM,
                                        ),

                                        // Sign in button
                                        SizedBox(
                                          width: double.infinity,
                                          child: GradientButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _signInWithEmail,
                                            text: _isLoading && _showEmailForm
                                                ? 'Signing In...'
                                                : 'Sign In',
                                            icon: _isLoading && _showEmailForm
                                                ? null
                                                : Icons.login,
                                            isLoading:
                                                _isLoading && _showEmailForm,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: AppTheme.spacingM,
                                        ),

                                        // Back to options
                                        TextButton(
                                          onPressed: _toggleEmailForm,
                                          child: Text(
                                            'Back to options',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: AppTheme.spacingL),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        TextButton(
                          onPressed: _navigateToSignUp,
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Privacy notice
                    Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppTheme.spacingL),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
