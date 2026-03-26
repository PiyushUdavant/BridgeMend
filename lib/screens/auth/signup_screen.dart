import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/aurora_background.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      _showErrorSnackBar(
        'Please agree to the Terms of Service and Privacy Policy',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final error = await context.read<FirebaseAppState>().signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (error != null && mounted) {
        _showErrorSnackBar(error);
      } else if (mounted) {
        // Sign out the user immediately after account creation
        await context.read<FirebaseAppState>().signOut();

        // Show verification instructions and navigate back to login
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1F2937),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              title: Row(
                children: [
                  Icon(Icons.mark_email_unread, color: AppTheme.primary),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'Verify Your Email',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account created successfully! 🎉',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'We\'ve sent a verification email to:',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      _emailController.text.trim(),
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    '📧 Please check your email and click the verification link.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '✅ After verification, return here and sign in to access the app.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to login
                  },
                  child: Text(
                    'Got it - Take me to Sign In',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
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
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingText: 'Creating your account...',
      child: Scaffold(
        body: AuroraBackground(
          intensity: 0.6,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // App Logo
                      const AppLogo(size: 100, animate: false),

                      SizedBox(height: AppTheme.spacingL),

                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            AppTheme.gradientStart,
                            AppTheme.gradientEnd,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Create Account',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 32.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingS),

                      Text(
                        'Join thousands building stronger relationships',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 32.h),

                      // Sign Up Form
                      AnimatedCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Email field
                                TextFormField(
                                  controller: _emailController,
                                  validator: _validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    labelStyle: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: AppTheme.primary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.textTertiary.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.interruptionColor,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spacingM),

                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  validator: _validatePassword,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Colors.white),
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
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppTheme.textSecondary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.textTertiary.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.interruptionColor,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spacingS),

                                // Password requirements
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spacingS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusS,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Password requirements:',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildRequirement(
                                        'At least 6 characters',
                                      ),
                                      _buildRequirement('One uppercase letter'),
                                      _buildRequirement('One lowercase letter'),
                                      _buildRequirement('One number'),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spacingM),

                                // Confirm Password field
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  validator: _validateConfirmPassword,
                                  obscureText: _obscureConfirmPassword,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    labelStyle: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: AppTheme.primary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppTheme.textSecondary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.textTertiary.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppTheme.interruptionColor,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AppTheme.spacingM),

                                // Terms and conditions checkbox
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _agreeToTerms,
                                      onChanged: (value) {
                                        setState(() {
                                          _agreeToTerms = value ?? false;
                                        });
                                      },
                                      activeColor: AppTheme.primary,
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          'I agree to the Terms of Service and Privacy Policy',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppTheme.spacingL),

                                // Sign up button
                                SizedBox(
                                  width: double.infinity,
                                  child: GradientButton(
                                    onPressed: _isLoading ? null : _signUp,
                                    text: _isLoading
                                        ? 'Creating Account...'
                                        : 'Create Account',
                                    icon: _isLoading ? null : Icons.person_add,
                                    isLoading: _isLoading,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Sign in link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spacingL),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 12, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
