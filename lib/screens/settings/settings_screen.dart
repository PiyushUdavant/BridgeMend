import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/gradient_button.dart';
import '../auth/enhanced_login_screen.dart';
import '../../widgets/aurora_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
            title: const Text('Settings'),
          ),
          body: AuroraBackground(
            intensity: 0.6,
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.spacingL.w),
                  child: AnimationLimiter(
                    child: Column(
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 800),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: [
                          _buildPrivacySection(context),
                          SizedBox(height: AppTheme.spacingXL.h),
                          _buildAboutSection(context),
                          SizedBox(height: AppTheme.spacingXL.h),
                          _buildSignOutSection(context, appState),
                          SizedBox(height: AppTheme.spacingXL.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.interruptionColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: AppTheme.interruptionColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'Privacy & Security',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildSettingsItem(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildSettingsItem(
            icon: Icons.gavel_rounded,
            title: 'Terms of Service',
            subtitle: 'App usage terms and conditions',
            onTap: () {
              // TODO: Show terms of service
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildSettingsItem(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently remove your data',
            onTap: () {
              _showDeleteAccountDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'About',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildSettingsItem(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Get help using Mend',
            onTap: () {
              // TODO: Help & support
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildSettingsItem(
            icon: Icons.feedback_rounded,
            title: 'Send Feedback',
            subtitle: 'Share your thoughts with us',
            onTap: () {
              // TODO: Feedback form
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildSettingsItem(
            icon: Icons.star_rounded,
            title: 'Rate App',
            subtitle: 'Rate Mend in the App Store',
            onTap: () {
              // TODO: App store rating
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildSettingsItem(
            icon: Icons.code_rounded,
            title: 'Version',
            subtitle: '1.0.0',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutSection(BuildContext context, FirebaseAppState appState) {
    return AnimatedCard(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: 'Sign Out',
              icon: Icons.logout_rounded,
              isSecondary: true,
              onPressed: () => _showSignOutDialog(context, appState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: AppTheme.glassmorphicDecoration(
          borderRadius: AppTheme.radiusM,
          hasGlow: false,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, FirebaseAppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You\'ll need to sign in again to access your sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );

              try {
                await appState.signOut();

                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog

                  // Show brief success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  // Force navigate directly to login screen
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const EnhancedLoginScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 500),
                    ),
                    (route) => false,
                  );

                  debugPrint('🔥 Navigation to login screen completed');
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign out failed: ${e.toString()}'),
                      backgroundColor: AppTheme.interruptionColor,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppTheme.interruptionColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: AppTheme.interruptionColor,
              size: 24,
            ),
            const SizedBox(width: AppTheme.spacingM),
            const Text('Delete Account'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete your account and all your data including:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppTheme.spacingS),
                const Text(
                  '• All conversation sessions\n• Relationship data\n• Progress insights\n• Account information',
                ),
                const SizedBox(height: AppTheme.spacingM),
                const Text(
                  'This action cannot be undone. Type "DELETE" to confirm:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.interruptionColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                TextFormField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: 'Type DELETE to confirm',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.interruptionColor,
                      ),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              confirmController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (confirmController.text.trim().toUpperCase() != 'DELETE') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type "DELETE" to confirm'),
                    backgroundColor: AppTheme.interruptionColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppTheme.interruptionColor,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      const Text('Deleting account...'),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'This may take a moment',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              try {
                // Store navigator and app state references before deletion
                final navigator = Navigator.of(context);
                final appState = Provider.of<FirebaseAppState>(
                  context,
                  listen: false,
                );

                // Add timeout to the entire delete process
                final error = await appState.deleteAccount().timeout(
                  const Duration(seconds: 45),
                  onTimeout: () {
                    return 'Account deletion timed out. Please check your internet connection and try again.';
                  },
                );

                debugPrint('🔥 Delete account returned with error: $error');
                debugPrint('🔥 Context mounted status: ${context.mounted}');

                confirmController.dispose();

                // Use stored navigator reference (works even if context is unmounted)
                if (error != null) {
                  debugPrint('🔥 Account deletion failed with error: $error');
                  // Close loading dialog
                  navigator.pop();

                  // Show error (this might not work if context is unmounted, but we try)
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: AppTheme.interruptionColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 7),
                      ),
                    );
                  }
                } else {
                  debugPrint(
                    '🔥 Account deletion succeeded, navigating with stored navigator',
                  );
                  // Account deleted successfully - use stored navigator

                  // Close loading dialog and navigate in one go
                  navigator.pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const EnhancedLoginScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                    (route) => false,
                  );

                  debugPrint(
                    '🔥 Navigation to login screen completed using stored navigator',
                  );
                }
              } catch (e) {
                confirmController.dispose();
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unexpected error: ${e.toString()}'),
                      backgroundColor: AppTheme.interruptionColor,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 7),
                      action: SnackBarAction(
                        label: 'Retry',
                        textColor: Colors.white,
                        onPressed: () {
                          _showDeleteAccountDialog(context);
                        },
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(color: AppTheme.interruptionColor),
            ),
          ),
        ],
      ),
    );
  }
}
