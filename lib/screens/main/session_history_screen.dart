import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animated_card.dart';
import '../../models/communication_session.dart';
import '../../widgets/aurora_background.dart';

import 'session_waiting_room_screen.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedFilter = 'All Sessions';
  final List<String> _filterOptions = [
    'All Sessions',
    'This Week',
    'This Month',
    'Last 3 Months',
    'This Year',
  ];

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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text('Session History'),
        actions: [
          IconButton(
            onPressed: () => _showFilterDialog(context),
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
          ),
        ],
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: Consumer<FirebaseAppState>(
          builder: (context, appState, child) {
            final sessions = _getFilteredSessions(appState);

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Filter Summary
                    Container(
                      padding: EdgeInsets.all(24.w),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: AppTheme.primary,
                            size: 20.sp,
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '$_selectedFilter (${sessions.length} sessions)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sessions List
                    Expanded(
                      child: sessions.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              physics: const BouncingScrollPhysics(),
                              itemCount: sessions.length,
                              itemBuilder: (context, index) {
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 600),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 16.h),
                                        child: _buildSessionCard(
                                          context,
                                          sessions[index],
                                          appState,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: Icon(
              Icons.history_rounded,
              color: AppTheme.textSecondary,
              size: 64.sp,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No sessions found',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Start your first communication session\nto see your history here',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    CommunicationSession session,
    FirebaseAppState appState,
  ) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Header
          Row(
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
                        fontSize: 16.sp,
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
                      color: AppTheme.primary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 16.h),

          // Session Details
          Row(
            children: [
              Expanded(
                child: _buildSessionDetail(
                  Icons.access_time_rounded,
                  'Duration',
                  _formatDuration(session.duration),
                ),
              ),
              Expanded(
                child: _buildSessionDetail(
                  Icons.message_rounded,
                  'Messages',
                  '${session.messages.length}',
                ),
              ),
              Expanded(
                child: _buildSessionDetail(
                  Icons.people_rounded,
                  'Participants',
                  '${session.participantStatus.length}',
                ),
              ),
            ],
          ),

          if (session.reflection != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    color: AppTheme.secondary,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      session.reflection!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.sp,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 16.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40.h,
                  child: GradientButton(
                    text: 'View Details',
                    icon: Icons.visibility_rounded,
                    fontSize: 12.sp,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    onPressed: () => _showSessionDetails(context, session),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: SizedBox(
                  height: 40.h,
                  child: GradientButton(
                    text: 'Call Again',
                    icon: Icons.call_rounded,
                    fontSize: 12.sp,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    isSecondary: true,
                    onPressed: () => _startNewSession(context, appState),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16.sp),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.sp),
        ),
      ],
    );
  }

  List<CommunicationSession> _getFilteredSessions(FirebaseAppState appState) {
    final allSessions = appState.getRecentSessions(limit: 100);
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return allSessions
            .where((session) => session.startTime.isAfter(weekStart))
            .toList();
      case 'This Month':
        final monthStart = DateTime(now.year, now.month, 1);
        return allSessions
            .where((session) => session.startTime.isAfter(monthStart))
            .toList();
      case 'Last 3 Months':
        final threeMonthsAgo = now.subtract(const Duration(days: 90));
        return allSessions
            .where((session) => session.startTime.isAfter(threeMonthsAgo))
            .toList();
      case 'This Year':
        final yearStart = DateTime(now.year, 1, 1);
        return allSessions
            .where((session) => session.startTime.isAfter(yearStart))
            .toList();
      default:
        return allSessions;
    }
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Filter Sessions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _filterOptions.map((filter) {
            return ListTile(
              title: Text(
                filter,
                style: TextStyle(
                  color: _selectedFilter == filter
                      ? AppTheme.primary
                      : AppTheme.textPrimary,
                  fontWeight: _selectedFilter == filter
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              trailing: _selectedFilter == filter
                  ? Icon(Icons.check_rounded, color: AppTheme.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSessionDetails(BuildContext context, CommunicationSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Session Details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Session ID', session.id),
              _buildDetailRow(
                'Start Time',
                _formatDetailedDate(session.startTime),
              ),
              if (session.endTime != null)
                _buildDetailRow(
                  'End Time',
                  _formatDetailedDate(session.endTime!),
                ),
              _buildDetailRow('Duration', _formatDuration(session.duration)),
              _buildDetailRow('Messages', '${session.messages.length}'),
              _buildDetailRow(
                'Status',
                session.isCompleted ? 'Completed' : 'Active',
              ),
              if (session.scores != null) ...[
                SizedBox(height: 16.h),
                Text(
                  'Scores',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                ...session.scores!.partnerScores.entries.map((entry) {
                  return _buildDetailRow(
                    'Partner ${entry.key}',
                    '${entry.value.averageScore.toStringAsFixed(1)}/10',
                  );
                }),
                if (session.scores?.overallFeedback != null)
                  _buildDetailRow('Feedback', session.scores!.overallFeedback),
              ],
              if (session.reflection != null) ...[
                SizedBox(height: 16.h),
                Text(
                  'Reflection',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  session.reflection!,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ],
              if (session.suggestedActivities.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Text(
                  'Suggested Activities',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                ...session.suggestedActivities.map((activity) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.successGreen,
                          size: 16.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            activity,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailedDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _startNewSession(BuildContext context, FirebaseAppState appState) {
    final sessionCode = _generateSessionCode();
    final userId = appState.user?.uid ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SessionWaitingRoomScreen(sessionCode: sessionCode, userId: userId),
      ),
    );
  }

  String _generateSessionCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return '${random.toString().substring(0, 6)}';
  }
}
