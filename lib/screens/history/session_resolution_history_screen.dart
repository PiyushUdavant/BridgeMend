import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/call_analysis_result.dart';
import '../../services/firestore_sessions_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class SessionResolutionHistoryScreen extends StatefulWidget {
  final String sessionId;
  final String? partnerName;

  const SessionResolutionHistoryScreen({
    super.key,
    required this.sessionId,
    this.partnerName,
  });

  @override
  State<SessionResolutionHistoryScreen> createState() =>
      _SessionResolutionHistoryScreenState();
}

class _SessionResolutionHistoryScreenState
    extends State<SessionResolutionHistoryScreen> {
  final FirestoreSessionsService _service = FirestoreSessionsService();
  final PageController _pageController = PageController();

  CallAnalysisResult? _result;
  bool _loading = true;
  int _pageIndex = 0;

  static const _pageTitles = [
    'Escalators',
    'Actions',
    'Shared plan',
    'Next steps',
  ];

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
          'Resolution Plan',
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
              Icons.auto_fix_high_rounded,
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
              'Resolution plan not available',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'No AI analysis was found for this session.',
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
    final resolutionActions = Map<String, dynamic>.from(
      analysis['resolutionActions'] as Map? ?? {},
    );

    final conflictEscalators =
        resolutionActions['conflictEscalators'] as List? ?? [];
    final partnerActionPlans =
        resolutionActions['partnerActionPlans'] as List? ?? [];
    final sharedSolutions =
        resolutionActions['sharedSolutions'] as List? ?? [];

    final resolutionSteps = _stringList(analysis['resolutionSteps']);
    final improvementSuggestions =
        _stringList(analysis['improvementSuggestions']);
    final bondingActivities =
        _stringList(analysis['suggestedBondingActivities']);

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
                    color: selected
                        ? AppTheme.aiActive
                        : AppTheme.textSecondary,
                    fontSize: 12.sp,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppTheme.aiActive
                        : AppTheme.glassBorder,
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
              _buildEscalatorsPage(conflictEscalators),
              _buildActionsPage(partnerActionPlans),
              _buildSharedPlanPage(sharedSolutions),
              _buildNextStepsPage(
                resolutionSteps,
                improvementSuggestions,
                bondingActivities,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEscalatorsPage(List conflictEscalators) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      children: [
        if (conflictEscalators.isEmpty)
          _glassCard(
            child: Text(
              'No conflict escalators were identified.',
              style: _bodyStyle,
            ),
          )
        else
          _conflictEscalatorsCard(conflictEscalators),
      ],
    );
  }

  Widget _buildActionsPage(List partnerActionPlans) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      children: [
        if (partnerActionPlans.isEmpty)
          _glassCard(
            child: Text(
              'No partner action plans available.',
              style: _bodyStyle,
            ),
          )
        else
          _partnerActionPlansCard(partnerActionPlans),
      ],
    );
  }

  Widget _buildSharedPlanPage(List sharedSolutions) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      children: [
        if (sharedSolutions.isEmpty)
          _glassCard(
            child: Text(
              'No shared solutions available.',
              style: _bodyStyle,
            ),
          )
        else
          _sharedSolutionsCard(sharedSolutions),
      ],
    );
  }

  Widget _buildNextStepsPage(
    List<String> resolutionSteps,
    List<String> improvementSuggestions,
    List<String> bondingActivities,
  ) {
    final isEmpty = resolutionSteps.isEmpty &&
        improvementSuggestions.isEmpty &&
        bondingActivities.isEmpty;

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      children: [
        if (isEmpty)
          _glassCard(
            child: Text('No next steps available.', style: _bodyStyle),
          ),
        if (resolutionSteps.isNotEmpty)
          _simpleListCard(
            title: 'Resolution steps',
            icon: Icons.route_rounded,
            color: AppTheme.successGreen,
            items: resolutionSteps,
          ),
        if (resolutionSteps.isNotEmpty) SizedBox(height: 16.h),
        if (improvementSuggestions.isNotEmpty)
          _simpleListCard(
            title: 'Improve together',
            icon: Icons.trending_up_rounded,
            color: AppTheme.neonBlue,
            items: improvementSuggestions,
          ),
        if (improvementSuggestions.isNotEmpty) SizedBox(height: 16.h),
        if (bondingActivities.isNotEmpty)
          _simpleListCard(
            title: 'Reconnect gently',
            icon: Icons.favorite_border_rounded,
            color: AppTheme.partnerBGlow,
            items: bondingActivities,
          ),
      ],
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _conflictEscalatorsCard(List items) {
    return _glassCard(
      glowColor: AppTheme.neonCoral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'What raised the conflict',
            Icons.local_fire_department_rounded,
          ),
          SizedBox(height: 8.h),
          Text(
            'These are not labels or blame. They are patterns that may have increased tension.',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          ...items.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final partnerName =
                item['partnerName']?.toString() ?? 'Partner';
            final behavior = item['behavior']?.toString() ?? '';
            final impact = item['impact']?.toString() ?? '';
            final betterAlternative =
                item['betterAlternative']?.toString() ?? '';

            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundTertiary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppTheme.glassBorder.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _miniLabel(partnerName, AppTheme.neonCoral),
                    SizedBox(height: 10.h),
                    if (behavior.isNotEmpty)
                      _infoBlock(
                        title: 'Behavior',
                        text: behavior,
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                    if (impact.isNotEmpty) SizedBox(height: 10.h),
                    if (impact.isNotEmpty)
                      _infoBlock(
                        title: 'Possible impact',
                        text: impact,
                        icon: Icons.psychology_alt_rounded,
                      ),
                    if (betterAlternative.isNotEmpty) SizedBox(height: 10.h),
                    if (betterAlternative.isNotEmpty)
                      _infoBlock(
                        title: 'Better alternative',
                        text: betterAlternative,
                        icon: Icons.lightbulb_outline_rounded,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _partnerActionPlansCard(List plans) {
    return _glassCard(
      glowColor: AppTheme.aiActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Actions for each partner',
            Icons.task_alt_rounded,
          ),
          SizedBox(height: 8.h),
          Text(
            'Small, practical actions each person can take to reduce defensiveness and repair trust.',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          ...plans.map((raw) {
            final plan = Map<String, dynamic>.from(raw as Map);
            final partnerName =
                plan['partnerName']?.toString() ?? 'Partner';
            final actions = plan['actions'] as List? ?? [];

            return Padding(
              padding: EdgeInsets.only(bottom: 18.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _miniLabel(partnerName, AppTheme.aiActive),
                  SizedBox(height: 12.h),
                  ...actions.map((rawAction) {
                    final action =
                        Map<String, dynamic>.from(rawAction as Map);
                    return _actionTile(
                      title: action['title']?.toString() ?? 'Action',
                      description:
                          action['description']?.toString() ?? '',
                      whyItHelps:
                          action['whyItHelps']?.toString() ?? '',
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sharedSolutionsCard(List solutions) {
    return _glassCard(
      glowColor: AppTheme.successGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Shared repair plan', Icons.handshake_rounded),
          SizedBox(height: 8.h),
          Text(
            'Steps both partners can try together instead of trying to win the argument.',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16.h),
          ...solutions.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final title = item['title']?.toString() ?? '';
            final description = item['description']?.toString() ?? '';

            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppTheme.successGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.successGreen,
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty)
                            Text(
                              title,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (description.isNotEmpty) SizedBox(height: 6.h),
                          if (description.isNotEmpty)
                            Text(description, style: _bodyStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _simpleListCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return _glassCard(
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, icon),
          SizedBox(height: 12.h),
          ...items.map((item) => _bullet(item, color)),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _actionTile({
    required String title,
    required String description,
    required String whyItHelps,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.backgroundTertiary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppTheme.glassBorder.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.aiActive,
                size: 17.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) SizedBox(height: 8.h),
          if (description.isNotEmpty) Text(description, style: _bodyStyle),
          if (whyItHelps.isNotEmpty) SizedBox(height: 10.h),
          if (whyItHelps.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppTheme.aiActive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Why it helps: $whyItHelps',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12.sp,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoBlock({
    required String title,
    required String text,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textTertiary, size: 16.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniLabel(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
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
