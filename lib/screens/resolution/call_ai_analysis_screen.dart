import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../models/call_analysis_result.dart';
import '../../providers/firebase_app_state.dart';
import '../../services/session_analysis_loader.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/gradient_button.dart';
import 'post_resolution_screen.dart';

/// Full Gemini call analysis shown after partner rating, before reflection.
class CallAiAnalysisScreen extends StatefulWidget {
  final String sessionId;
  final String? currentUserId;
  final String? partnerName;
  /// Rated partner slot id (`A` / `B`) — passed through when relationship JSON is incomplete.
  final String? ratedPartnerId;
  final String? selfDisplayName;
  final String? selfGender;
  final String? partnerGender;

  const CallAiAnalysisScreen({
    super.key,
    required this.sessionId,
    this.currentUserId,
    this.partnerName,
    this.ratedPartnerId,
    this.selfDisplayName,
    this.selfGender,
    this.partnerGender,
  });

  @override
  State<CallAiAnalysisScreen> createState() => _CallAiAnalysisScreenState();
}

class _CallAiAnalysisScreenState extends State<CallAiAnalysisScreen> {
  final SessionAnalysisLoader _loader = SessionAnalysisLoader();
  final PageController _pageController = PageController();

  CallAnalysisResult? _result;
  String? _error;
  String _statusLabel = 'Preparing AI analysis…';
  int _pageIndex = 0;
  bool _loading = true;

  static const _pageTitles = [
    'Overview',
    'Conversation',
    'Patterns',
    'Scores',
    'Next steps',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAnalysis());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final appState = context.read<FirebaseAppState>();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _loader.loadOrAnalyze(
        appState: appState,
        sessionId: widget.sessionId,
        routeRatedPartnerId: widget.ratedPartnerId,
        routeRatedPartnerName: widget.partnerName,
        routeRatedPartnerGender: widget.partnerGender,
        routeSelfDisplayName: widget.selfDisplayName,
        routeSelfGender: widget.selfGender,
        onStatus: (label) {
          if (mounted) setState(() => _statusLabel = label);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _goToReflection() {
    context.read<FirebaseAppState>().clearTemporarySessionData();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PostResolutionScreen(
          sessionId: widget.sessionId,
          currentUserId: widget.currentUserId,
          partnerName: widget.partnerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AuroraBackground(
          intensity: 0.65,
          child: SafeArea(
            child: _loading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildResults(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingL.w),
      child: Column(
        children: [
          SizedBox(height: 32.h),
          SizedBox(
            width: 120.w,
            height: 120.w,
            child: Lottie.asset(
              'assets/lottie/ai_orb.json',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Bridgemend AI',
            style: TextStyle(
              color: AppTheme.aiActive,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Analyzing your conversation',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            _statusLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
          ),
          SizedBox(height: 32.h),
          _buildProgressStep('Recording processed', true),
          _buildProgressStep('Speech transcribed', _statusLabel.contains('Analyzing') || _statusLabel.contains('Saving') || _statusLabel.contains('saved')),
          _buildProgressStep('Communication insights', _statusLabel.contains('Saving') || _statusLabel.contains('saved')),
          const Spacer(),
          Text(
            'This usually takes under a minute',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.sp),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String label, bool done) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppTheme.aiActive : AppTheme.textQuaternary,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done ? AppTheme.textPrimary : AppTheme.textTertiary,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingL.w),
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.cloud_off_rounded, color: AppTheme.interruptionColor, size: 56.sp),
          SizedBox(height: 16.h),
          Text(
            'Analysis unavailable',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
          ),
          const Spacer(),
          GradientButton(
            text: 'Retry analysis',
            icon: Icons.refresh_rounded,
            onPressed: _runAnalysis,
            width: double.infinity,
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: _goToReflection,
            child: Text(
              'Skip to reflection',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final analysis = _result!.analysis;
    final transcript = _result!.transcript;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppTheme.aiActive, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'AI session insights',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: _pageTitles.length,
            itemBuilder: (context, i) {
              final selected = i == _pageIndex;
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: ChoiceChip(
                  label: Text(_pageTitles[i]),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _pageIndex = i);
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  selectedColor: AppTheme.aiActive.withValues(alpha: 0.25),
                  backgroundColor: AppTheme.backgroundTertiary,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.aiActive : AppTheme.textSecondary,
                    fontSize: 12.sp,
                  ),
                  side: BorderSide(
                    color: selected ? AppTheme.aiActive : AppTheme.glassBorder,
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            children: [
              _buildOverviewPage(analysis),
              _buildTranscriptPage(transcript),
              _buildPatternsPage(analysis),
              _buildScoresPage(analysis),
              _buildNextStepsPage(analysis),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(20.w),
          child: GradientButton(
            text: 'Continue to reflection',
            icon: Icons.arrow_forward_rounded,
            onPressed: _goToReflection,
            width: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewPage(Map<String, dynamic> analysis) {
    final summary = analysis['sessionSummary']?.toString() ?? '';
    final tone = analysis['sessionEmotionalTone']?.toString() ?? '';
    final feedback = analysis['overallFeedback']?.toString() ?? '';

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Session summary', Icons.summarize_rounded),
              SizedBox(height: 10.h),
              Text(
                summary.isNotEmpty ? summary : 'No summary available.',
                style: _bodyStyle,
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _glassCard(
          glowColor: AppTheme.partnerBGlow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Emotional tone', Icons.mood_rounded),
              SizedBox(height: 10.h),
              Text(tone.isNotEmpty ? tone : '—', style: _bodyStyle),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Overall feedback', Icons.feedback_rounded),
              SizedBox(height: 10.h),
              Text(
                feedback.isNotEmpty ? feedback : '—',
                style: _bodyStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptPage(Map<String, dynamic> transcript) {
    final dialogue = transcript['dialogueText']?.toString() ??
        transcript['fullText']?.toString() ??
        '';
    final segments = transcript['segments'] as List? ?? [];

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        _glassCard(
          glowColor: AppTheme.aiActive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Conversation transcript', Icons.forum_rounded),
              SizedBox(height: 8.h),
              Text(
                'Back-and-forth dialogue from your call',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.sp),
              ),
              SizedBox(height: 16.h),
              if (segments.isNotEmpty)
                ...segments.map((raw) {
                  final seg = Map<String, dynamic>.from(raw as Map);
                  final label = seg['dialogueLabel']?.toString() ??
                      seg['speakerLabel']?.toString() ??
                      'Speaker';
                  final text = seg['text']?.toString() ?? '';
                  final color = _speakerColor(label);
                  return Padding(
                    padding: EdgeInsets.only(bottom: 14.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: color.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(text, style: _bodyStyle),
                        ),
                      ],
                    ),
                  );
                })
              else
                Text(
                  dialogue.isNotEmpty ? dialogue : 'Transcript not available.',
                  style: _bodyStyle.copyWith(height: 1.5),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatternsPage(Map<String, dynamic> analysis) {
    final patterns = _stringList(analysis['communicationPatterns']);
    final behaviors = analysis['harmfulBehaviors'] as List? ?? [];
    final responsibilities = analysis['responsibilityIndicators'] as List? ?? [];

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Communication patterns', Icons.hub_rounded),
              SizedBox(height: 12.h),
              ...patterns.map((p) => _bullet(p, AppTheme.aiActive)),
              if (patterns.isEmpty) Text('None noted.', style: _bodyStyle),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _glassCard(
          glowColor: AppTheme.interruptionColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Behaviors to watch', Icons.warning_amber_rounded),
              SizedBox(height: 12.h),
              if (behaviors.isEmpty)
                Text('No significant concerns flagged.', style: _bodyStyle)
              else
                ...behaviors.map((raw) {
                  final b = Map<String, dynamic>.from(raw as Map);
                  final severity = b['severity']?.toString() ?? 'low';
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _severityChip(severity),
                            SizedBox(width: 8.w),
                            Text(
                              'Observed: ${b['observedIn'] ?? 'unclear'}',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          b['description']?.toString() ?? '',
                          style: _bodyStyle,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Responsibility indicators', Icons.balance_rounded),
              SizedBox(height: 12.h),
              if (responsibilities.isEmpty)
                Text('—', style: _bodyStyle)
              else
                ...responsibilities.map((raw) {
                  final r = Map<String, dynamic>.from(raw as Map);
                  final pid = r['partnerId']?.toString() ?? '';
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Text(
                      '${_partnerLabel(pid)}: ${r['indicator'] ?? ''}',
                      style: _bodyStyle,
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoresPage(Map<String, dynamic> analysis) {
    final partnerScores = analysis['partnerScores'] as List? ?? [];
    final appState = context.read<FirebaseAppState>();

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        Text(
          'AI communication scores (0–100)',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp),
        ),
        SizedBox(height: 16.h),
        ...partnerScores.map((raw) {
          final entry = Map<String, dynamic>.from(raw as Map);
          final partnerId = entry['partnerId']?.toString() ?? '';
          final scores = Map<String, dynamic>.from(entry['scores'] as Map? ?? {});
          final name = _resolvePartnerName(appState, partnerId);
          final color = AppTheme.getPartnerColor(partnerId);

          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: _glassCard(
              glowColor: color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: color,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _scoreBar('Overall', scores['overall'], color),
                  _scoreBar('Empathy', scores['empathy'], color),
                  _scoreBar('Listening', scores['listening'], color),
                  _scoreBar('Reception', scores['reception'], color),
                  _scoreBar('Clarity', scores['clarity'], color),
                  _scoreBar('Respect', scores['respect'], color),
                  _scoreBar('Responsiveness', scores['responsiveness'], color),
                  _scoreBar('Open-mindedness', scores['openMindedness'], color),
                ],
              ),
            ),
          );
        }),
        if (partnerScores.isEmpty)
          _glassCard(
            child: Text('Scores not available.', style: _bodyStyle),
          ),
      ],
    );
  }

  Widget _buildNextStepsPage(Map<String, dynamic> analysis) {
    final steps = _stringList(analysis['resolutionSteps']);
    final suggestions = _stringList(analysis['improvementSuggestions']);
    final bonding = _stringList(analysis['suggestedBondingActivities']);
    final disclaimer = analysis['disclaimer']?.toString() ?? '';

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        _glassCard(
          glowColor: AppTheme.successGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Resolution steps', Icons.route_rounded),
              SizedBox(height: 12.h),
              ...steps.map((s) => _bullet(s, AppTheme.successGreen)),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Improve together', Icons.trending_up_rounded),
              SizedBox(height: 12.h),
              ...suggestions.map((s) => _bullet(s, AppTheme.neonBlue)),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _glassCard(
          glowColor: AppTheme.partnerBGlow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Reconnecting ideas', Icons.favorite_border_rounded),
              SizedBox(height: 12.h),
              ...bonding.map((s) => _bullet(s, AppTheme.partnerBGlow)),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          disclaimer,
          style: TextStyle(
            color: AppTheme.textQuaternary,
            fontSize: 11.sp,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _glassCard({required Widget child, Color? glowColor}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassmorphicDecoration(
        borderRadius: 16,
        hasGlow: glowColor != null,
        glowColor: glowColor ?? AppTheme.aiActive,
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.aiActive, size: 18.sp),
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
    );
  }

  Widget _bullet(String text, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6.h),
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: _bodyStyle)),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, dynamic value, Color color) {
    final v = (value is num) ? value.toInt().clamp(0, 100) : 0;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.sp)),
              Text('$v', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 4.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: v / 100,
              minHeight: 6.h,
              backgroundColor: AppTheme.backgroundQuaternary,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _severityChip(String severity) {
    Color c = AppTheme.textTertiary;
    if (severity == 'high') c = AppTheme.interruptionColor;
    if (severity == 'medium') c = AppTheme.neonCoral;
    if (severity == 'low') c = AppTheme.successGreen;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(color: c, fontSize: 10.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _speakerColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('male') && !l.contains('female')) return AppTheme.partnerAGlow;
    if (l.contains('female')) return AppTheme.partnerBGlow;
    return AppTheme.aiActive;
  }

  String _partnerLabel(String partnerId) =>
      _resolvePartnerName(context.read<FirebaseAppState>(), partnerId);

  String _resolvePartnerName(FirebaseAppState appState, String partnerId) {
    final a = appState.getCurrentPartner();
    final b = appState.getOtherPartner();
    if (a?.id == partnerId) return a!.name;
    if (b?.id == partnerId) return b!.name;
    if (partnerId == 'A') return a?.name ?? 'Partner A';
    if (partnerId == 'B') return b?.name ?? 'Partner B';
    return partnerId;
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  TextStyle get _bodyStyle => TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 14.sp,
        height: 1.45,
      );
}
