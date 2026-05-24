import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/gradient_button.dart';
import 'call_ai_analysis_screen.dart';

/// Full-screen bridge before Gemini analysis so users know what comes next.
class AiInsightsIntroScreen extends StatelessWidget {
  final String sessionId;
  final String raterId;
  final String ratedPartnerId;
  final String ratedPartnerName;
  final String selfName;
  final String selfGender;
  final String partnerGender;
  final bool bothPartnersRated;

  const AiInsightsIntroScreen({
    super.key,
    required this.sessionId,
    required this.raterId,
    required this.ratedPartnerId,
    required this.ratedPartnerName,
    required this.selfName,
    required this.selfGender,
    required this.partnerGender,
    required this.bothPartnersRated,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AuroraBackground(
          intensity: 0.65,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL.w,
                vertical: AppTheme.spacingM.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  Center(
                    child: SizedBox(
                      width: 100.w,
                      height: 100.w,
                      child: Lottie.asset(
                        'assets/lottie/ai_orb.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'You\'re almost done',
                    style: TextStyle(
                      color: AppTheme.aiActive,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'AI conversation insights',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    bothPartnersRated
                        ? 'Great work — both of you rated each other. Next, Bridgemend will analyze your voice session and show a structured report.'
                        : 'Thank you for your rating. Next, Bridgemend will analyze your voice session so you can review communication patterns together.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15.sp,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 28.h),
                  _infoRow(
                    Icons.mic_rounded,
                    'Your call recording is used only to generate this report (STT + AI on our server).',
                  ),
                  SizedBox(height: 14.h),
                  _infoRow(
                    Icons.visibility_rounded,
                    'You\'ll see transcript-style turns, tone, patterns, scores, and practical next steps.',
                  ),
                  SizedBox(height: 14.h),
                  _infoRow(
                    Icons.health_and_safety_outlined,
                    'This is communication feedback — not therapy or legal advice.',
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.w),
                    decoration: AppTheme.glassmorphicDecoration(
                      borderRadius: 14,
                      hasGlow: true,
                      glowColor: AppTheme.partnerAGlow.withValues(alpha: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people_rounded, color: AppTheme.primary, size: 22.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Session partners: $selfName ↔ $ratedPartnerName',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13.sp,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  GradientButton(
                    text: 'Continue to AI insights',
                    icon: Icons.auto_awesome_rounded,
                    width: double.infinity,
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallAiAnalysisScreen(
                            sessionId: sessionId,
                            currentUserId: raterId,
                            partnerName: ratedPartnerName,
                            ratedPartnerId: ratedPartnerId,
                            selfDisplayName: selfName,
                            selfGender: selfGender,
                            partnerGender: partnerGender,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primary, size: 22.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14.sp,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
