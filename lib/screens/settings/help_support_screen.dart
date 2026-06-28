import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final Map<String, bool> _expanded = {};

  static const _faqs = [
    (
      q: 'How does Mend work?',
      a: 'Mend listens to your conversation in real-time using your device '
          'microphone and transcribes it with AI. After the session ends, it '
          'analyses the transcript to identify communication patterns, score '
          'each partner\'s engagement, and provide a personalised resolution '
          'plan and reflection prompts.',
    ),
    (
      q: 'Is my conversation private?',
      a: 'Yes. Audio is processed in real-time for transcription and then '
          'discarded — we do not store raw audio recordings. The transcript '
          'and AI analysis are encrypted and stored securely, accessible '
          'only to you and your linked partner.',
    ),
    (
      q: 'How do I invite my partner?',
      a: 'From the home screen, tap "Invite Partner" and share the generated '
          'invite link or code with your partner. Once they accept and join, '
          'you\'re linked and can start sessions together.',
    ),
    (
      q: 'What does the AI score mean?',
      a: 'Scores (0–10) reflect communication quality across dimensions like '
          'empathy, listening, clarity, and respect. They are not judgements '
          '— they are a starting point for reflection. A lower score simply '
          'highlights an area to work on together.',
    ),
    (
      q: 'Can I use Mend without my partner?',
      a: 'You can explore the app and view past sessions solo, but real-time '
          'session analysis requires both partners to join the same voice room '
          'via the session code.',
    ),
    (
      q: 'What happens if my partner and I disconnect during a session?',
      a: 'The session pauses and waits for reconnection. If the connection '
          'cannot be restored you can end the session manually — the analysis '
          'will run on the conversation captured up to that point.',
    ),
    (
      q: 'Is Mend a replacement for couples therapy?',
      a: 'No. Mend is a communication tool, not a licensed therapy service. '
          'It can complement professional counselling, but we strongly '
          'encourage you to work with a qualified therapist for deep or '
          'persistent relationship challenges.',
    ),
    (
      q: 'How do I delete my account?',
      a: 'Go to Settings → Delete Account. You will be asked to type "DELETE" '
          'to confirm. This permanently removes your account, all session '
          'data, and your relationship profile from our servers.',
    ),
  ];

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
        title: const Text('Help & Support'),
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.15),
                        AppTheme.neonBlue.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        color: AppTheme.primary,
                        size: 36.sp,
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How can we help?',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Browse frequently asked questions below or '
                              'reach out directly.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.sp,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // FAQ heading
                Row(
                  children: [
                    Icon(Icons.quiz_rounded,
                        color: AppTheme.primary, size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'FREQUENTLY ASKED QUESTIONS',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // FAQ accordion
                ...List.generate(_faqs.length, (i) {
                  final faq = _faqs[i];
                  final key = faq.q;
                  final open = _expanded[key] ?? false;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundSecondary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: open
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : AppTheme.glassBorder,
                        ),
                      ),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusM),
                        onTap: () =>
                            setState(() => _expanded[key] = !open),
                        child: Padding(
                          padding: EdgeInsets.all(14.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      faq.q,
                                      style: TextStyle(
                                        color: open
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  AnimatedRotation(
                                    turns: open ? 0.5 : 0,
                                    duration:
                                        const Duration(milliseconds: 220),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: open
                                          ? AppTheme.primary
                                          : AppTheme.textTertiary,
                                      size: 20.sp,
                                    ),
                                  ),
                                ],
                              ),
                              if (open) ...[
                                SizedBox(height: 10.h),
                                Divider(
                                    color: AppTheme.glassBorder, height: 1),
                                SizedBox(height: 10.h),
                                Text(
                                  faq.a,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13.sp,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                SizedBox(height: 24.h),

                // Contact section
                Row(
                  children: [
                    Icon(Icons.mail_rounded,
                        color: AppTheme.primary, size: 16.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'STILL NEED HELP?',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Column(
                    children: [
                      _contactRow(
                        icon: Icons.email_rounded,
                        label: 'Email support',
                        value: 'support@mendapp.io',
                        color: AppTheme.primary,
                      ),
                      SizedBox(height: 12.h),
                      Divider(color: AppTheme.glassBorder, height: 1),
                      SizedBox(height: 12.h),
                      _contactRow(
                        icon: Icons.schedule_rounded,
                        label: 'Response time',
                        value: 'Within 48 hours',
                        color: AppTheme.neonBlue,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: color, size: 18.sp),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11.sp,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}