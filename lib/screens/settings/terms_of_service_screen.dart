import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
        title: const Text('Terms of Service'),
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, 'Effective date: June 2025'),
                SizedBox(height: 24.h),

                _section(context, '1. Acceptance of Terms',
                    Icons.handshake_rounded, AppTheme.primary, [
                  _para('By downloading, installing, or using Mend, you agree '
                      'to be bound by these Terms of Service. If you do not '
                      'agree to these terms, please do not use the app.'),
                  _para('We may update these terms from time to time. '
                      'Continued use of Mend after changes are posted '
                      'constitutes acceptance of the revised terms.'),
                ]),

                SizedBox(height: 16.h),
                _section(context, '2. About Mend',
                    Icons.info_rounded, AppTheme.neonBlue, [
                  _para('Mend is an AI-assisted communication tool designed '
                      'to help couples and partners improve how they '
                      'communicate during difficult conversations.'),
                  _important(
                    'Mend is not a licensed therapy or medical service. '
                    'It does not replace professional counselling, '
                    'psychotherapy, or crisis support. If you are '
                    'experiencing a mental health emergency, please contact '
                    'a qualified professional or emergency services.',
                  ),
                ]),

                SizedBox(height: 16.h),
                _section(context, '3. Eligibility',
                    Icons.person_rounded, AppTheme.neonViolet, [
                  _bullet('You must be at least 18 years old to use Mend.'),
                  _bullet('You must have the legal capacity to enter into '
                      'a binding agreement.'),
                  _bullet('You must not be located in a jurisdiction where '
                      'the app is prohibited.'),
                ]),

                SizedBox(height: 16.h),
                _section(context, '4. Your Account',
                    Icons.account_circle_rounded, AppTheme.aiActive, [
                  _bullet('You are responsible for maintaining the '
                      'confidentiality of your account credentials.'),
                  _bullet('You agree to provide accurate information when '
                      'setting up your account.'),
                  _bullet('You may not share your account with others or '
                      'use another person\'s account without permission.'),
                  _bullet('You are responsible for all activity that occurs '
                      'under your account.'),
                ]),

                SizedBox(height: 16.h),
                _section(context, '5. Acceptable Use',
                    Icons.rule_rounded, AppTheme.successGreen, [
                  _para('You agree not to use Mend to:'),
                  _bullet('Harass, threaten, or harm your partner or '
                      'any other person.'),
                  _bullet('Upload or transmit unlawful, harmful, or '
                      'offensive content.'),
                  _bullet('Attempt to reverse-engineer, exploit, or '
                      'interfere with the app or its services.'),
                  _bullet('Use the app for any commercial purpose without '
                      'our prior written consent.'),
                  _bullet('Circumvent security features or access '
                      'another user\'s data without authorisation.'),
                ]),

                SizedBox(height: 16.h),
                _section(context, '6. AI Limitations',
                    Icons.smart_toy_rounded, AppTheme.neonCoral, [
                  _para('Mend uses artificial intelligence to analyse '
                      'conversations and provide guidance. You acknowledge '
                      'that:'),
                  _bullet('AI-generated insights are provided for '
                      'informational purposes only and may not always '
                      'be accurate or appropriate for your situation.'),
                  _bullet('The AI does not understand context the way a '
                      'trained human professional does.'),
                  _bullet('We are not liable for decisions made based on '
                      'AI-generated content.'),
                ]),

                SizedBox(height: 16.h),
                _section(context, '7. Intellectual Property',
                    Icons.copyright_rounded, AppTheme.neonPink, [
                  _para('All content, design, and technology within Mend '
                      'is the intellectual property of the Mend team and '
                      'is protected by applicable copyright and trademark law.'),
                  _para('You retain ownership of the conversation content '
                      'you generate. By using Mend you grant us a limited, '
                      'non-exclusive licence to process that content solely '
                      'to provide the service.'),
                ]),

                SizedBox(height: 16.h),
                _section(context, '8. Termination',
                    Icons.block_rounded, AppTheme.interruptionColor, [
                  _para('We reserve the right to suspend or terminate your '
                      'access to Mend at any time for violations of these '
                      'terms, without prior notice.'),
                  _para('You may delete your account at any time via '
                      'Settings → Delete Account.'),
                ]),

                SizedBox(height: 16.h),
                _section(context, '9. Contact Us',
                    Icons.mail_rounded, AppTheme.aiActive, [
                  _para('For questions about these terms:'),
                  _bullet('Email: legal@mendapp.io'),
                ]),

                SizedBox(height: 32.h),
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
                color: AppTheme.neonBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(
                Icons.gavel_rounded,
                color: AppTheme.neonBlue,
                size: 28.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terms of Service',
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
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

  Widget _important(String text) => Container(
        margin: EdgeInsets.only(top: 4.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppTheme.neonCoral.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border: Border.all(color: AppTheme.neonCoral.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_rounded,
                color: AppTheme.neonCoral, size: 16.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.sp,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
}