import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/call_analysis_result.dart';
import '../../providers/firebase_app_state.dart';
import '../../services/firestore_sessions_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class SessionInsightsHistoryScreen extends StatefulWidget {
  final String sessionId;
  final String? partnerName;

  const SessionInsightsHistoryScreen({
    super.key,
    required this.sessionId,
    this.partnerName,
  });

  @override
  State<SessionInsightsHistoryScreen> createState() =>
      _SessionInsightsHistoryScreenState();
}

class _SessionInsightsHistoryScreenState
    extends State<SessionInsightsHistoryScreen> {
  final FirestoreSessionsService _service = FirestoreSessionsService();
  final PageController _pageController = PageController();

  CallAnalysisResult? _result;
  bool _loading = true;
  int _pageIndex = 0;

  static const _pageTitles = ['Overview', 'Conversation', 'Patterns', 'Scores'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await _service.getSessionAiAnalysis(widget.sessionId);
    if (mounted) {
      setState(() {
        _result = result;
        _loading = false;
      });
    }
  }

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
        title: Text(
          'Session Insights',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.aiActive,
              size: 22.sp,
            ),
          ),
        ],
      ),
      body: AuroraBackground(
        intensity: 0.65,
        child: SafeArea(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: AppTheme.aiActive),
                )
              : _result == null
                  ? _buildNotAvailable()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildNotAvailable() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: AppTheme.textSecondary,
              size: 56.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'Insights not available',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'No AI analysis was found for this session. This may be an older session completed before AI insights were introduced.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final analysis = _result!.analysis;
    final transcript = _result!.transcript;

    return Column(
      children: [
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
        SizedBox(height: 8.h),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            children: [
              _buildOverviewPage(analysis),
              _buildTranscriptPage(transcript),
              _buildPatternsPage(analysis),
              _buildScoresPage(analysis),
            ],
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
              Text(feedback.isNotEmpty ? feedback : '—', style: _bodyStyle),
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
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12.sp,
                ),
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
                            border: Border.all(
                              color: color.withValues(alpha: 0.5),
                            ),
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
                        Expanded(child: Text(text, style: _bodyStyle)),
                      ],
                    ),
                  );
                })
              else
                Text(
                  dialogue.isNotEmpty
                      ? dialogue
                      : 'Transcript not available.',
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
              if (patterns.isEmpty)
                Text('None noted.', style: _bodyStyle),
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
          final scores =
              Map<String, dynamic>.from(entry['scores'] as Map? ?? {});
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

  // ── Helpers ───────────────────────────────────────────────────────────────

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
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              Text(
                '$v',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        style: TextStyle(
          color: c,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
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