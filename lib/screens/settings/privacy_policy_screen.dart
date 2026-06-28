import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text('Privacy Policy'),
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, 'Last updated: June 2025'),
                SizedBox(height: 24.h),

                _section(context, 'What We Collect',
                    Icons.data_usage_rounded, AppTheme.neonBlue, [
                  _para('Mend collects only what is necessary to provide '
                      'the service:'),
                  _bullet('Account information — your name and email address '
                      'provided during sign-in.'),
                  _bullet('Session data — voice transcripts generated during '
                      'communication sessions are processed by our AI and '
                      'stored to power session insights and history.'),
                  _bullet('Relationship profile — the partner information and '
                      'onboarding answers you provide to personalise your '
                      'experience.'),
                  _bullet('Usage data — anonymous app interaction data to help '
                      'us improve the product (no personal content included).'),
                ]),

                SizedBox(height: 20.h),
                _section(context, 'How We Use Your Data',
                    Icons.psychology_rounded, AppTheme.primary, [
                  _para('Your data is used solely to operate and improve Mend:'),
                  _bullet('Generate AI-powered session insights and resolution '
                      'plans personalised to your relationship.'),
                  _bullet('Display your session history and progress over time.'),
                  _bullet('Authenticate you securely and maintain your account.'),
                  _bullet('Improve the AI model\'s accuracy in a privacy-safe '
                      'way — we never sell or share your personal data.'),
                ]),

                SizedBox(height: 20.h),
                _section(context, 'Data Storage & Security',
                    Icons.lock_rounded, AppTheme.successGreen, [
                  _para('Your data is stored on secured cloud infrastructure '
                      '(Supabase) with industry-standard encryption at rest '
                      'and in transit.'),
                  _bullet('Voice transcripts are encrypted before storage.'),
                  _bullet('We do not store raw audio recordings after '
                      'transcription is complete.'),
                  _bullet('Access is restricted — only you and your linked '
                      'partner can view your session data.'),
                  _bullet('We conduct periodic security reviews to protect '
                      'your information.'),
                ]),

                SizedBox(height: 20.h),
                _section(context, 'Your Rights',
                    Icons.verified_user_rounded, AppTheme.neonPink, [
                  _bullet('Access — you can view all your stored data inside '
                      'the app at any time.'),
                  _bullet('Deletion — you can permanently delete your account '
                      'and all associated data from Settings → Delete Account.'),
                  _bullet('Portability — contact us to request a copy of '
                      'your data in a portable format.'),
                  _bullet('Correction — update your profile information '
                      'directly within the app.'),
                ]),

                SizedBox(height: 20.h),
                _section(context, 'Third-Party Services',
                    Icons.extension_rounded, AppTheme.neonCoral, [
                  _para('Mend integrates with:'),
                  _bullet('Google Sign-In — for authentication only. We do not '
                      'access your Google account data beyond your name and '
                      'email.'),
                  _bullet('Supabase — for secure backend storage.'),
                  _bullet('ZEGO Cloud — for real-time voice communication '
                      'during sessions.'),
                  _para('Each third-party service has its own privacy policy '
                      'governing how they handle data on their end.'),
                ]),

                SizedBox(height: 20.h),
                _section(context, 'Contact',
                    Icons.mail_rounded, AppTheme.aiActive, [
                  _para('If you have any questions or concerns about how we '
                      'handle your data, please reach out:'),
                  _bullet('Email: privacy@mendapp.io'),
                  _bullet('We aim to respond to all privacy inquiries within '
                      '72 hours.'),
                ]),

                SizedBox(height: 32.h),
                // Container(
                //   padding: EdgeInsets.all(16.w),
                //   decoration: BoxDecoration(
                //     color: AppTheme.glassOverlay,
                //     borderRadius: BorderRadius.circular(AppTheme.radiusM),
                //     border: Border.all(color: AppTheme.glassBorder),
                //   ),
                //   child: Text(
                //     'Mend is designed to supplement — not replace — '
                //     'professional relationship counselling. We are committed '
                //     'to handling your most personal conversations with the '
                //     'highest level of care and discretion.',
                //     style: TextStyle(
                //       color: AppTheme.textTertiary,
                //       fontSize: 12.sp,
                //       height: 1.5,
                //       fontStyle: FontStyle.italic,
                //     ),
                //     textAlign: TextAlign.center,
                //   ),
                // ),
                // SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(
                Icons.privacy_tip_rounded,
                color: AppTheme.primary,
                size: 28.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Divider(color: AppTheme.glassBorder),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }

  Widget _para(String text) => Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.sp,
            height: 1.5,
          ),
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 6.h, right: 8.w),
              child: Container(
                width: 5.w,
                height: 5.w,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13.sp,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
}