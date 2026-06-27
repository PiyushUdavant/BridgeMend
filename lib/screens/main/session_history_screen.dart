import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mend_ai/screens/history/session_insights_history_screen.dart';
import 'package:mend_ai/screens/history/session_resolution_history_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animated_card.dart';
import '../../models/communication_session.dart';
import '../../widgets/aurora_background.dart';
import '../../services/local_session_service.dart';
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

  String _selectedFilter = 'All';
  bool _isRefreshing = false;
  List<CommunicationSession> _sessions = [];

  static const _filters = [
    'All',
    'This Week',
    'This Month',
    'Last 3 Months',
    'This Year',
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadLocal();
    // Auto-sync from remote on first open if local cache is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sessions.isEmpty) _syncFromRemote();
    });
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeOutCubic,
          ),
        );
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
  }

  void _loadLocal() {
    setState(() {
      _sessions = LocalSessionService.getCompletedSessions();
    });
  }

  Future<void> _syncFromRemote() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final appState = context.read<FirebaseAppState>();
      final remote = appState.getRecentSessions(limit: 200);
      if (remote.isNotEmpty) {
        await LocalSessionService.saveSessions(remote);
        _loadLocal();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  List<CommunicationSession> get _filtered {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'This Week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return _sessions.where((s) => s.startTime.isAfter(start)).toList();
      case 'This Month':
        final start = DateTime(now.year, now.month, 1);
        return _sessions.where((s) => s.startTime.isAfter(start)).toList();
      case 'Last 3 Months':
        final start = now.subtract(const Duration(days: 90));
        return _sessions.where((s) => s.startTime.isAfter(start)).toList();
      case 'This Year':
        final start = DateTime(now.year, 1, 1);
        return _sessions.where((s) => s.startTime.isAfter(start)).toList();
      default:
        return _sessions;
    }
  }

  double get _avgScore {
    final scored = _sessions.where((s) => s.scores != null).toList();
    if (scored.isEmpty) return 0.0;
    return scored
            .map((s) => s.scores!.averageScore)
            .reduce((a, b) => a + b) /
        scored.length;
  }

  Duration get _totalTime =>
      _sessions.fold(Duration.zero, (acc, s) => acc + s.duration);

  Color _scoreColor(double score) {
    if (score >= 7.5) return AppTheme.successGreen;
    if (score >= 5.0) return AppTheme.neonCoral;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _filtered;

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
          if (_isRefreshing)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            )
          else
            IconButton(
              onPressed: _syncFromRemote,
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Sync from server',
            ),
        ],
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: _syncFromRemote,
              color: AppTheme.primary,
              backgroundColor: AppTheme.surface,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // SliverToBoxAdapter(child: _buildStatsRow()),
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 4.h),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: AppTheme.primary,
                            size: 15.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '$_selectedFilter  ·  ${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  sessions.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  AnimationConfiguration.staggeredList(
                                    position: index,
                                    duration:
                                        const Duration(milliseconds: 600),
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: 16.h,
                                          ),
                                          child: _buildSessionCard(
                                            sessions[index],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              childCount: sessions.length,
                            ),
                          ),
                        ),
                  SliverToBoxAdapter(child: SizedBox(height: 32.h)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalMin = _totalTime.inMinutes;
    final timeStr = totalMin < 60
        ? '${totalMin}m'
        : '${totalMin ~/ 60}h ${totalMin % 60}m';

    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
      padding: EdgeInsets.all(20.w),
      decoration: AppTheme.glassmorphicDecoration(
        borderRadius: AppTheme.radiusL,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(
            '${_sessions.length}',
            'Sessions',
            Icons.chat_bubble_outline_rounded,
            AppTheme.neonBlue,
          ),
          _buildDivider(),
          _buildStat(
            _avgScore > 0 ? _avgScore.toStringAsFixed(1) : '—',
            'Avg Score',
            Icons.star_outline_rounded,
            _avgScore > 0 ? _scoreColor(_avgScore) : AppTheme.textSecondary,
          ),
          _buildDivider(),
          _buildStat(
            totalMin == 0 ? '0m' : timeStr,
            'Total Time',
            Icons.timer_outlined,
            AppTheme.neonViolet,
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Icon(icon, color: color, size: 18.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.sp),
        ),
      ],
    );
  }

  Widget _buildDivider() => Container(
        width: 1,
        height: 52.h,
        color: AppTheme.glassBorder,
      );

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final f = _filters[i];
          final selected = _selectedFilter == f;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.neonBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected
                      ? null
                      : AppTheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : AppTheme.glassBorder,
                  ),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    color: selected
                        ? AppTheme.backgroundPrimary
                        : AppTheme.textSecondary,
                    fontSize: 12.sp,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
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
              'Your completed sessions will appear here.\nPull down to sync from the server.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: 160.w,
              child: GradientButton(
                text: 'Sync Now',
                icon: Icons.sync_rounded,
                onPressed: _syncFromRemote,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(CommunicationSession session) {
    final score = session.scores?.averageScore;
    final scoreColor =
        score != null ? _scoreColor(score) : AppTheme.textSecondary;

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 24.sp,
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) async {
        await LocalSessionService.deleteSession(session.id);
        setState(() => _sessions.removeWhere((s) => s.id == session.id));
      },
      child: AnimatedCard(
        onTap: () => _showDetails(session),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppTheme.successGreen,
                    size: 16.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatRelativeDate(session.startTime),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatTime(session.startTime),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (score != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: scoreColor,
                          size: 12.sp,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Score progress bar
            if (score != null) ...[
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                child: LinearProgressIndicator(
                  value: score / 10,
                  backgroundColor:
                      AppTheme.glassBorder.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  minHeight: 3,
                ),
              ),
            ],

            SizedBox(height: 5.h),

            // // Info chips
            // Wrap(
            //   spacing: 6.w,
            //   runSpacing: 6.h,
            //   children: [
            //     _buildChip(
            //       Icons.access_time_rounded,
            //       _formatDuration(session.duration),
            //     ),
            //     _buildChip(
            //       Icons.message_outlined,
            //       '${session.messages.length} msgs',
            //     ),
            //     _buildChip(
            //       Icons.people_outline_rounded,
            //       '${session.participantStatus.length} people',
            //     ),
            //   ],
            // ),

            // // Reflection snippet
            // if (session.reflection != null &&
            //     session.reflection!.isNotEmpty) ...[
            //   SizedBox(height: 12.h),
            //   Container(
            //     padding: EdgeInsets.all(10.w),
            //     decoration: BoxDecoration(
            //       color: AppTheme.secondary.withValues(alpha: 0.07),
            //       borderRadius: BorderRadius.circular(AppTheme.radiusM),
            //       border: Border.all(
            //         color: AppTheme.secondary.withValues(alpha: 0.2),
            //       ),
            //     ),
            //     child: Row(
            //       children: [
            //         Icon(
            //           Icons.lightbulb_outline_rounded,
            //           color: AppTheme.secondary,
            //           size: 13.sp,
            //         ),
            //         SizedBox(width: 8.w),
            //         Expanded(
            //           child: Text(
            //             session.reflection!,
            //             style: TextStyle(
            //               color: AppTheme.textSecondary,
            //               fontSize: 12.sp,
            //               fontStyle: FontStyle.italic,
            //             ),
            //             maxLines: 2,
            //             overflow: TextOverflow.ellipsis,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ],

            // SizedBox(height: 10.h),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tap for details  ·  Swipe left to delete',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  fontSize: 10.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppTheme.glassOverlay,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        border: Border.all(
          color: AppTheme.glassBorder.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 11.sp),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove from history?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This removes it from local storage only. The session stays on the server.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(CommunicationSession session) {
    final score = session.scores?.averageScore;
    final scoreColor =
        score != null ? _scoreColor(score) : AppTheme.textSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundSecondary,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL),
            ),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.glassBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Session Details',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (score != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusL),
                          border: Border.all(
                            color: scoreColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${score.toStringAsFixed(1)} / 10',
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Divider(color: AppTheme.glassBorder),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.all(24.w),
                  children: [
                    _detailGroup('Session Info', [
                      _detailRow('Date', _formatDetailedDate(session.startTime)),
                      if (session.endTime != null)
                        _detailRow('Ended', _formatDetailedDate(session.endTime!)),
                      _detailRow('Duration', _formatDuration(session.duration)),
                      // _detailRow('Messages', '${session.messages.length}'),
                      // _detailRow('Participants', '${session.participantStatus.length}'),
                    ]),

                    if (session.scores != null) ...[
                      SizedBox(height: 20.h),
                      _detailGroup('Scores', [
                        ...session.scores!.partnerScores.entries.map(
                          (e) => _detailRow(
                            'Partner ${e.key}',
                            '${e.value.averageScore.toStringAsFixed(1)} / 10',
                          ),
                        ),
                        if (session.scores!.overallFeedback.isNotEmpty)
                          _detailRow('Feedback', session.scores!.overallFeedback),
                      ]),
                    ],

                    SizedBox(height: 20.h),

                    // if (session.reflection != null &&
                    //     session.reflection!.isNotEmpty) ...[
                    //   SizedBox(height: 20.h),
                    //   _sectionLabel('Reflection'),
                    //   SizedBox(height: 8.h),
                    //   Container(
                    //     padding: EdgeInsets.all(14.w),
                    //     decoration: BoxDecoration(
                    //       color: AppTheme.secondary.withValues(alpha: 0.07),
                    //       borderRadius:
                    //           BorderRadius.circular(AppTheme.radiusM),
                    //       border: Border.all(
                    //         color: AppTheme.secondary.withValues(alpha: 0.2),
                    //       ),
                    //     ),
                    //     child: Text(
                    //       session.reflection!,
                    //       style: TextStyle(
                    //         color: AppTheme.textSecondary,
                    //         fontSize: 14.sp,
                    //         fontStyle: FontStyle.italic,
                    //       ),
                    //     ),
                    //   ),
                    // ],

                    // if (session.suggestedActivities.isNotEmpty) ...[
                    //   SizedBox(height: 20.h),
                    //   _sectionLabel('Suggested Activities'),
                    //   SizedBox(height: 8.h),
                    //   ...session.suggestedActivities.map(
                    //     (a) => Padding(
                    //       padding: EdgeInsets.only(bottom: 8.h),
                    //       child: Row(
                    //         crossAxisAlignment: CrossAxisAlignment.start,
                    //         children: [
                    //           Icon(
                    //             Icons.check_circle_rounded,
                    //             color: AppTheme.successGreen,
                    //             size: 16.sp,
                    //           ),
                    //           SizedBox(width: 10.w),
                    //           Expanded(
                    //             child: Text(
                    //               a,
                    //               style: TextStyle(
                    //                 color: AppTheme.textSecondary,
                    //                 fontSize: 14.sp,
                    //               ),
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ),
                    // ],

                    // SizedBox(height: 28.h),
                    // Consumer<FirebaseAppState>(
                    //   builder: (context, appState, _) => GradientButton(
                    //     text: 'Start New Session',
                    //     icon: Icons.call_rounded,
                    //     onPressed: () {
                    //       Navigator.pop(ctx);
                    //       _startNewSession(appState);
                    //     },
                    //   ),
                    // ),
                    // SizedBox(height: 16.h),

                    SizedBox(height: 20.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionInsightsHistoryScreen(
                                sessionId: session.id,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.auto_awesome_rounded, size: 18.sp),
                        label: const Text('See Session Insights'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.aiActive,
                          side: BorderSide(
                            color: AppTheme.aiActive.withValues(alpha: 0.5),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusL),
                          ),
                          textStyle: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionResolutionHistoryScreen(
                                sessionId: session.id,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.auto_fix_high_rounded, size: 18.sp),
                        label: const Text('See Resolution Plan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successGreen,
                          side: BorderSide(
                            color:
                                AppTheme.successGreen.withValues(alpha: 0.5),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusL),
                          ),
                          textStyle: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Consumer<FirebaseAppState>(
                      builder: (context, appState, _) => GradientButton(
                        text: 'Start New Session',
                        icon: Icons.call_rounded,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _startNewSession(appState);
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailGroup(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(title),
        SizedBox(height: 8.h),
        Container(
          decoration: AppTheme.glassmorphicDecoration(
            borderRadius: AppTheme.radiusM,
          ),
          child: Column(
            children: List.generate(rows.length, (i) {
              return Column(
                children: [
                  rows[i],
                  if (i < rows.length - 1)
                    Divider(
                      color: AppTheme.glassBorder.withValues(alpha: 0.5),
                      height: 1,
                      indent: 14.w,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppTheme.primary,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        children: [
          SizedBox(
            width: 90.w,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startNewSession(FirebaseAppState appState) {
    final code =
        DateTime.now().millisecondsSinceEpoch.toString().substring(0, 6);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionWaitingRoomScreen(
          sessionCode: code,
          userId: appState.user?.id ?? '',
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) return '${(diff / 7).floor()}w ago';
    if (diff < 365) return '${(diff / 30).floor()} months ago';
    return '${(diff / 365).floor()}y ago';
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    if (min < 60) return '${min}m';
    return '${min ~/ 60}h ${min % 60}m';
  }

  String _formatDetailedDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}  '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}