import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animated_card.dart';
import '../../models/communication_session.dart';
import '../../widgets/aurora_background.dart';

import 'session_history_screen.dart';

class InsightsDashboardScreen extends StatefulWidget {
  const InsightsDashboardScreen({super.key});

  @override
  State<InsightsDashboardScreen> createState() =>
      _InsightsDashboardScreenState();
}

class _InsightsDashboardScreenState extends State<InsightsDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedTimeRange = 'Last 7 days';
  final List<String> _timeRanges = ['Last 7 days', 'Last 30 days', 'All Time'];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text('Insights Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _showTimeRangeSelector(),
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
        ],
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: Consumer<FirebaseAppState>(
          builder: (context, appState, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(24.w),
                  child: AnimationLimiter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 800),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          verticalOffset: 80.0,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: [
                          // Weekly Summary Card
                          _buildWeeklySummaryCard(context, appState),
                          SizedBox(height: 32.h),

                          // Communication Trends Chart
                          _buildCommunicationTrendsCard(context, appState),
                          SizedBox(height: 32.h),

                          // Session History Section
                          _buildSessionHistorySection(context, appState),
                          SizedBox(height: 32.h),

                          // Reflections & Exercises Panel
                          _buildReflectionsPanel(context, appState),
                          SizedBox(height: 32.h),

                          // Motivational Feedback Block
                          _buildMotivationalFeedback(context, appState),
                          SizedBox(height: 32.h),

                          // Action Buttons
                          _buildActionButtons(context),
                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryCard(
    BuildContext context,
    FirebaseAppState appState,
  ) {
    final weeklyStats = _calculateWeeklyStats(appState);

    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with celebration icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  Icons.celebration_rounded,
                  color: AppTheme.successGreen,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week at a Glance',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${weeklyStats['sessionsThisWeek']} sessions completed, ${weeklyStats['reflections']} new reflections',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Stats Grid
          if (weeklyStats['totalSessions'] > 0) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Sessions',
                    '${weeklyStats['totalSessions']}',
                    Icons.chat_bubble_rounded,
                    AppTheme.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Avg Score',
                    '${weeklyStats['averageScore'].toStringAsFixed(1)}/10',
                    Icons.star_rounded,
                    AppTheme.accent,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Streak',
                    '${weeklyStats['streak']} days',
                    Icons.local_fire_department_rounded,
                    AppTheme.secondary,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Improvement indicator
            if (weeklyStats['improvement'] != null)
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: weeklyStats['improvement'] > 0
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: weeklyStats['improvement'] > 0
                        ? AppTheme.successGreen.withValues(alpha: 0.3)
                        : AppTheme.accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      weeklyStats['improvement'] > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_flat_rounded,
                      color: weeklyStats['improvement'] > 0
                          ? AppTheme.successGreen
                          : AppTheme.accent,
                      size: 20.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        weeklyStats['improvement'] > 0
                            ? 'Your communication improved by ${weeklyStats['improvement'].abs().toStringAsFixed(1)}% recently! 🎉'
                            : 'Keep practicing - growth takes time and consistency! 💪',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 48.sp,
                    color: AppTheme.primary.withValues(alpha: 0.7),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Start Your Journey',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Complete your first session to see insights here',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationTrendsCard(
    BuildContext context,
    FirebaseAppState appState,
  ) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with time range selector
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: AppTheme.accent,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Flexible(
                      child: Text(
                        'Communication Trends',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showTimeRangeSelector,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedTimeRange,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primary,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Chart container
          Container(
            height: 220.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: _buildEnhancedChart(context, appState),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedChart(BuildContext context, FirebaseAppState appState) {
    final sessions = _getFilteredSessions(appState);

    if (sessions.isEmpty) {
      return _buildEmptyChartState();
    }

    return Padding(
      padding: EdgeInsets.all(20.w),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: AppTheme.borderColor, strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < sessions.length) {
                    final session = sessions[value.toInt()];
                    return Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Text(
                        _formatChartDate(session.startTime),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sessions.length - 1).toDouble(),
          minY: 0,
          maxY: 10,
          lineBarsData: [
            // Main trend line
            LineChartBarData(
              spots: sessions.asMap().entries.map((entry) {
                final index = entry.key;
                final session = entry.value;
                final score = session.scores?.averageScore ?? 5.0;
                return FlSpot(index.toDouble(), score);
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppTheme.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.3),
                    AppTheme.primary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up_rounded,
            size: 48.sp,
            color: AppTheme.primary.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'No data yet',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Complete sessions to see trends',
            style: TextStyle(fontSize: 14.sp, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionsPanel(
    BuildContext context,
    FirebaseAppState appState,
  ) {
    final reflections = _getRecentReflections(appState);
    final exercises = _getAIExercises();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reflections section
        AnimatedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: AppTheme.secondary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Flexible(
                    child: Text(
                      'Saved Reflections',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              if (reflections.isEmpty)
                _buildEmptyReflectionsState()
              else
                ...reflections.map(
                  (reflection) => _buildReflectionCard(reflection),
                ),
            ],
          ),
        ),

        SizedBox(height: 20.h),

        // AI Exercises section
        AnimatedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color: AppTheme.accent,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Flexible(
                    child: Text(
                      'AI Exercises',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              ...exercises.map((exercise) => _buildExerciseCard(exercise)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyReflectionsState() {
    return Container(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 48.sp,
            color: AppTheme.secondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'No reflections yet',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Complete sessions and save your thoughts',
            style: TextStyle(fontSize: 14.sp, color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionCard(Map<String, dynamic> reflection) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                reflection['date'],
                style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _expandReflection(reflection),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: AppTheme.textTertiary,
                  size: 20.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            reflection['content'],
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(exercise['icon'], color: AppTheme.accent, size: 16.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['title'],
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  exercise['description'],
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppTheme.accent,
            size: 14.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalFeedback(
    BuildContext context,
    FirebaseAppState appState,
  ) {
    final weeklyStats = _calculateWeeklyStats(appState);
    final message = _getMotivationalMessage(weeklyStats);

    return AnimatedCard(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.1),
              AppTheme.accent.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.primary,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Flexible(
                  child: Text(
                    'Your AI Coach Says',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GradientButton(
            text: 'Start New Session',
            icon: Icons.add_circle_outline_rounded,
            onPressed: () => Navigator.pop(context),
            height: 48.h,
            fontSize: 14.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: GradientButton(
            text: 'Review Reflections',
            icon: Icons.auto_stories_rounded,
            isSecondary: true,
            onPressed: () => _showAllReflections(),
            height: 48.h,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }

  // Helper methods
  void _showTimeRangeSelector() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Time Range',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 20.h),
              ..._timeRanges.map(
                (range) => ListTile(
                  title: Text(range),
                  trailing: _selectedTimeRange == range
                      ? Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedTimeRange = range;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _expandReflection(Map<String, dynamic> reflection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reflection - ${reflection['date']}'),
        content: Text(reflection['content']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAllReflections() {
    // Navigate to detailed reflections view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Detailed reflections view coming soon!')),
    );
  }

  List<dynamic> _getFilteredSessions(FirebaseAppState appState) {
    final allSessions = appState.getRecentSessions(limit: 50);
    switch (_selectedTimeRange) {
      case 'Last 7 days':
        return allSessions.take(7).toList();
      case 'Last 30 days':
        return allSessions.take(30).toList();
      default:
        return allSessions;
    }
  }

  List<Map<String, dynamic>> _getRecentReflections(FirebaseAppState appState) {
    // Mock reflections - in real app, get from Firebase
    return [
      {
        'content':
            'I learned that listening without interrupting really helps my partner feel heard...',
        'date': 'Yesterday',
        'sessionId': '1',
      },
      {
        'content':
            'Today we practiced expressing gratitude and it brought us closer together.',
        'date': '2 days ago',
        'sessionId': '2',
      },
    ];
  }

  List<Map<String, dynamic>> _getAIExercises() {
    return [
      {
        'title': 'Practice active listening tonight',
        'description': 'Give your partner 5 minutes of uninterrupted attention',
        'icon': Icons.hearing_rounded,
      },
      {
        'title': 'Share three gratitudes',
        'description':
            'Tell your partner three things you appreciate about them',
        'icon': Icons.favorite_rounded,
      },
      {
        'title': 'Take a mindful walk together',
        'description': 'Spend 15 minutes walking and talking without phones',
        'icon': Icons.directions_walk_rounded,
      },
    ];
  }

  String _getMotivationalMessage(Map<String, dynamic> stats) {
    if (stats['totalSessions'] == 0) {
      return "Welcome to your relationship growth journey! Every great conversation starts with a single session. You're already taking a meaningful step by being here.";
    } else if (stats['improvement'] != null && stats['improvement'] > 0) {
      return "You've shown remarkable improvement in your communication! Your consistency is making a real difference. Keep nurturing this positive momentum.";
    } else if (stats['streak'] > 0) {
      return "Your commitment to regular practice is inspiring. ${stats['streak']} days of consistent effort shows how much you care about your relationship.";
    } else {
      return "Every session is a step forward, even when progress feels slow. Remember, the strongest relationships are built through patience, practice, and perseverance.";
    }
  }

  String _formatChartDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${date.day}/${date.month}';
    return '${date.day}/${date.month}';
  }

  Map<String, dynamic> _calculateWeeklyStats(FirebaseAppState appState) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final allSessions = appState.getRecentSessions(limit: 100);
    final sessionsThisWeek = allSessions
        .where(
          (session) =>
              session.startTime.isAfter(weekStart) &&
              session.startTime.isBefore(weekEnd),
        )
        .toList();

    final totalSessions = allSessions.length;
    final totalMinutes = allSessions.fold<int>(
      0,
      (sum, session) => sum + session.duration.inMinutes,
    );

    // Calculate streak
    int streak = 0;
    final today = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < 30; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final hasSessionOnDate = allSessions.any((session) {
        final sessionDate = DateTime(
          session.startTime.year,
          session.startTime.month,
          session.startTime.day,
        );
        return sessionDate == checkDate;
      });

      if (hasSessionOnDate) {
        streak++;
      } else {
        break;
      }
    }

    double? improvement;
    if (allSessions.length >= 4) {
      final recentScores = allSessions
          .take(2)
          .map((s) => s.scores?.averageScore ?? 0.0)
          .toList();
      final olderScores = allSessions
          .skip(2)
          .take(2)
          .map((s) => s.scores?.averageScore ?? 0.0)
          .toList();

      if (recentScores.isNotEmpty && olderScores.isNotEmpty) {
        final recentAvg =
            recentScores.reduce((a, b) => a + b) / recentScores.length;
        final olderAvg =
            olderScores.reduce((a, b) => a + b) / olderScores.length;
        improvement = ((recentAvg - olderAvg) / olderAvg * 100);
      }
    }

    final averageScore = allSessions.isNotEmpty
        ? allSessions
                  .map((s) => s.scores?.averageScore ?? 0.0)
                  .reduce((a, b) => a + b) /
              allSessions.length
        : 0.0;

    return {
      'sessionsThisWeek': sessionsThisWeek.length,
      'totalSessions': totalSessions,
      'totalMinutes': totalMinutes,
      'averageScore': averageScore,
      'improvement': improvement,
      'streak': streak,
      'reflections': _getRecentReflections(appState).length,
    };
  }

  Widget _buildSessionHistorySection(
    BuildContext context,
    FirebaseAppState appState,
  ) {
    final recentSessions = appState.getRecentSessions(limit: 5);

    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: AppTheme.primary,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Sessions',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Your communication journey and progress',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Sessions Preview
          if (recentSessions.isNotEmpty) ...[
            ...recentSessions
                .take(3)
                .map((session) => _buildSessionPreviewCard(session)),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'View All Sessions',
                icon: Icons.history_rounded,
                isSecondary: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SessionHistoryScreen(),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.surface.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: AppTheme.textSecondary,
                    size: 32.sp,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No sessions yet',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Start your first communication session\nto see your progress here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionPreviewCard(CommunicationSession session) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.surface.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: session.isCompleted
                  ? AppTheme.successGreen.withValues(alpha: 0.2)
                  : AppTheme.neonCoral.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(
              session.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.pending_rounded,
              color: session.isCompleted
                  ? AppTheme.successGreen
                  : AppTheme.neonCoral,
              size: 16.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session ${session.id.substring(0, 8)}',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatSessionDate(session.startTime),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          if (session.isCompleted && session.scores != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Text(
                '${session.scores!.averageScore.toStringAsFixed(1)}/10',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSessionDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference} days ago';
    if (difference < 30) return '${(difference / 7).floor()} weeks ago';
    if (difference < 365) return '${(difference / 30).floor()} months ago';
    return '${(difference / 365).floor()} years ago';
  }
}
