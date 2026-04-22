import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/zego_voice_chat_screen.dart';
import '../../models/communication_session.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class SessionWaitingRoomScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;

  const SessionWaitingRoomScreen({
    super.key,
    required this.sessionCode,
    required this.userId,
  });

  @override
  State<SessionWaitingRoomScreen> createState() =>
      _SessionWaitingRoomScreenState();
}

class _SessionWaitingRoomScreenState extends State<SessionWaitingRoomScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final SupabaseClient _db = Supabase.instance.client;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  bool _navigated = false; // Prevent double navigation
  bool _isJoining = false; // Prevent concurrent joins
  /// Loaded via REST after create/join so we do not depend on Realtime for first paint.
  Map<String, dynamic>? _sessionRow;
  bool _bootstrapping = true;
  String? _bootstrapError;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionRealtimeSub;
  /// Host often misses Realtime; poll until [status] advances (DB trigger keeps it in sync).
  Timer? _participantPollTimer;
  /// Only one auto-navigation runs at a time (poll + stream + build can all fire).
  Future<void>? _voiceAdvanceFuture;
  bool _endedDialogShown = false;
  DateTime? _voiceAdvanceCooldownUntil;
  bool _voiceAdvanceFailureSnackShown = false;

  static List<String> _parseParticipantIds(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    final out = <String>[];
    for (final e in raw) {
      if (e == null) continue;
      final s = e is String ? e : e.toString();
      final t = s.trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  static List<String> _participantIds(Map<String, dynamic>? row) {
    return _parseParticipantIds(row?['participants']);
  }

  static String _participantSignature(Map<String, dynamic>? row) {
    final ids = List<String>.from(_participantIds(row))..sort();
    final st = row?['status']?.toString() ?? '';
    return '$st|${ids.join('\u001f')}';
  }

  bool _sessionRowSnapshotDiffer(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    return _participantSignature(a) != _participantSignature(b);
  }

  /// Normalized `sessions.status` (trigger-maintained).
  static String _normStatus(Map<String, dynamic>? row) {
    final s = row?['status']?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty) return 'waiting';
    return s;
  }

  /// Open / sync voice when DB says both sides are in (`ready`) or call already started (`active`).
  static bool _shouldNavigateToVoice(Map<String, dynamic>? row) {
    final s = _normStatus(row);
    return s == 'ready' || s == 'active';
  }

  static bool _isWaitingStatus(Map<String, dynamic>? row) =>
      _normStatus(row) == 'waiting';

  static bool _isEndedStatus(Map<String, dynamic>? row) =>
      _normStatus(row) == 'ended';

  void _stopParticipantPolling() {
    _participantPollTimer?.cancel();
    _participantPollTimer = null;
  }

  Future<void> _pollSessionParticipantsOnce() async {
    if (!mounted || _navigated || _bootstrapping) return;
    final current = _sessionRow;
    if (_isEndedStatus(current)) {
      _stopParticipantPolling();
      return;
    }
    if (_shouldNavigateToVoice(current)) {
      _stopParticipantPolling();
      _tryAdvanceToVoiceChat();
      return;
    }
    try {
      final fresh = await _fetchSessionRow();
      if (!mounted || _navigated || fresh == null) return;
      if (_sessionRowSnapshotDiffer(current, fresh)) {
        setState(() => _sessionRow = fresh);
      }
      _maybeHandleSessionEnded(fresh);
      _tryAdvanceToVoiceChat();
      if (_isEndedStatus(fresh) || _shouldNavigateToVoice(fresh)) {
        _stopParticipantPolling();
      }
    } catch (e) {
      debugPrint('WaitingRoom: poll failed: $e');
    }
  }

  void _startParticipantPolling() {
    _stopParticipantPolling();
    unawaited(_pollSessionParticipantsOnce());
    _participantPollTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => _pollSessionParticipantsOnce(),
    );
  }

  /// Opens voice when [sessions.status] is `ready` or `active` (DB trigger + app).
  /// [manual] from "Start Session" bypasses cooldown after a failed auto-start.
  void _tryAdvanceToVoiceChat({bool manual = false}) {
    if (!mounted || _navigated || _bootstrapping) return;
    if (!_shouldNavigateToVoice(_sessionRow)) return;
    if (manual) {
      _voiceAdvanceCooldownUntil = null;
      _voiceAdvanceFailureSnackShown = false;
    } else if (_voiceAdvanceCooldownUntil != null &&
        DateTime.now().isBefore(_voiceAdvanceCooldownUntil!)) {
      return;
    }
    _voiceAdvanceFuture ??= _runVoiceAdvanceOnce().whenComplete(() {
      _voiceAdvanceFuture = null;
    });
  }

  Future<void> _runVoiceAdvanceOnce() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    try {
      final appState = Provider.of<FirebaseAppState>(context, listen: false);
      final ok = await appState.startCommunicationSession(
        sessionCode: widget.sessionCode,
      );
      if (!ok) {
        if (mounted) {
          setState(() => _navigated = false);
          _voiceAdvanceCooldownUntil =
              DateTime.now().add(const Duration(seconds: 6));
          if (!_voiceAdvanceFailureSnackShown) {
            _voiceAdvanceFailureSnackShown = true;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not start voice yet. Wait until two people are on this session code, '
                  'or finish inviting your partner in Mend, then tap Start Session.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        return;
      }
      if (!mounted || !context.mounted) {
        if (mounted) setState(() => _navigated = false);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ZegoVoiceChatScreen(
            sessionCode: widget.sessionCode,
            userId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('WaitingRoom: voice advance failed: $e');
      if (mounted) setState(() => _navigated = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
    _bootstrapWaitingRoom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopParticipantPolling();
    _disposeSessionRealtime();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pollSessionParticipantsOnce());
    }
  }

  Future<Map<String, dynamic>?> _fetchSessionRow() async {
    return _db
        .from('sessions')
        .select(
          'id,participants,startTime,messages,participantStatus,status,relationshipId',
        )
        .eq('id', widget.sessionCode)
        .maybeSingle();
  }

  void _applySessionRowFromStream(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      // Realtime can emit an empty batch; recover via REST poll.
      unawaited(_pollSessionParticipantsOnce());
      return;
    }
    final next = Map<String, dynamic>.from(rows.first);
    if (!mounted) return;
    setState(() => _sessionRow = next);
    _maybeHandleSessionEnded(next);
    _tryAdvanceToVoiceChat();
  }

  void _disposeSessionRealtime() {
    _sessionRealtimeSub?.cancel();
    _sessionRealtimeSub = null;
  }

  void _subscribeSessionRealtime() {
    _disposeSessionRealtime();
    _sessionRealtimeSub = _db
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('id', widget.sessionCode)
        .listen(_applySessionRowFromStream);
  }

  void _maybeHandleSessionEnded(Map<String, dynamic>? row) {
    if (!_isEndedStatus(row) || _endedDialogShown || !mounted || _navigated) {
      return;
    }
    _endedDialogShown = true;
    _stopParticipantPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Session ended'),
          content: const Text(
            'This session is no longer active.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted && context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _bootstrapWaitingRoom() async {
    try {
      if (widget.userId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _bootstrapping = false;
          _bootstrapError =
              'Missing your account id. Go back, sign in again, then rejoin the session.';
        });
        return;
      }

      _disposeSessionRealtime();

      await _joinSession();
      if (!mounted) return;

      // Subscribe before fetch so we do not miss the partner's first update.
      _subscribeSessionRealtime();

      var row = await _fetchSessionRow();
      // Brief retry in case of read-after-write lag
      for (var i = 0; i < 3 && row == null && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        row = await _fetchSessionRow();
      }

      if (!mounted) return;

      if (row == null) {
        setState(() {
          _bootstrapping = false;
          _bootstrapError =
              'Could not load this session. Check your connection or try again.';
        });
        return;
      }

      setState(() {
        _sessionRow = row;
        _bootstrapping = false;
        _bootstrapError = null;
      });

      _maybeHandleSessionEnded(row);

      _startParticipantPolling();
    } catch (e, st) {
      debugPrint('WaitingRoom: bootstrap failed: $e\n$st');
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _bootstrapping = false;
        if (msg.contains('Session is full') ||
            msg.contains('at most 2 distinct participants')) {
          _bootstrapError =
              'This session already has two people. Start a new session with a fresh code.';
        } else {
          _bootstrapError =
              'Could not set up the session. Please go back and try again.';
        }
      });
    }
  }

  Future<void> _joinSession() async {
    if (_isJoining) return;
    if (widget.userId.trim().isEmpty) {
      throw Exception('Missing user id');
    }
    _isJoining = true;
    try {
      // Retry a few times to avoid race conditions when both join at once
      const int maxAttempts = 3;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final session = await _db
              .from('sessions')
              .select(
                'id,participants,startTime,messages,participantStatus,status',
              )
              .eq('id', widget.sessionCode)
              .maybeSingle();

          if (session == null) {
            // Create session document with this user as first participant
            await _db.from('sessions').insert({
              'id': widget.sessionCode,
              'startTime': DateTime.now().toIso8601String(),
              'messages': const <Map<String, dynamic>>[],
              'participantStatus': {widget.userId: true},
              'participants': [widget.userId],
              'createdAt': DateTime.now().toIso8601String(),
            });
            debugPrint('WaitingRoom: Created session ${widget.sessionCode}');
            break;
          } else {
            // Add this user to participants if not already present
            final existingIds = _parseParticipantIds(session['participants']);
            if (!existingIds.contains(widget.userId)) {
              final distinct = existingIds.toSet();
              if (distinct.length >= 2) {
                throw Exception('Session is full (max 2 participants).');
              }
              final updatedParticipants = [...existingIds, widget.userId];
              final ps = CommunicationSession.parseParticipantStatusMap(
                session['participantStatus'],
              );
              for (final id in updatedParticipants) {
                ps[id] = true;
              }
              // status + updatedAt: DB trigger recomputes from participants
              await _db.from('sessions').update({
                'participants': updatedParticipants,
                'participantStatus': ps,
              }).eq('id', widget.sessionCode);
              debugPrint(
                'WaitingRoom: Added ${widget.userId} to participants (${updatedParticipants.length})',
              );
            } else {
              debugPrint('WaitingRoom: ${widget.userId} already in participants');
            }
            break;
          }
        } catch (e) {
          debugPrint('WaitingRoom: join attempt $attempt failed: $e');
          if (attempt == maxAttempts) rethrow;
          // Small delay before retry
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }
    } finally {
      _isJoining = false;
    }
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session?'),
        content: const Text(
          'Are you sure you want to leave this session? You will need a new session code to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _leaveSession() async {
    // Remove user from participants list
    try {
      final session = await _db
          .from('sessions')
          .select('participants')
          .eq('id', widget.sessionCode)
          .maybeSingle();
      if (session == null) return;
      final participants = _parseParticipantIds(session['participants']);
      participants.remove(widget.userId);
      await _db.from('sessions').update({
        'participants': participants,
      }).eq('id', widget.sessionCode);
    } catch (e) {
      // Handle error silently or show a message
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _showExitConfirmation();
        if (shouldPop) {
          await _leaveSession();
          if (mounted && navigator.canPop()) {
            navigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary,
              size: 20,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final shouldExit = await _showExitConfirmation();
              if (shouldExit) {
                await _leaveSession();
                if (mounted && navigator.canPop()) {
                  navigator.pop();
                }
              }
            },
          ),
          title: const Text('Waiting Room'),
        ),
        body: AuroraBackground(
          intensity: 0.6,
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildWaitingRoomBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoomBody() {
    if (_bootstrapping) {
      return _buildLoadingState();
    }
    if (_bootstrapError != null && _sessionRow == null) {
      return _buildBootstrapErrorState();
    }
    final data = _sessionRow;
    final participants = _participantIds(data);
    final waiting = _isWaitingStatus(data);
    final showReadyOrConnecting = !waiting && !_isEndedStatus(data);

    if (_shouldNavigateToVoice(data) && !_navigated) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryAdvanceToVoiceChat(manual: false),
      );
    }

    return AnimationLimiter(
      child: SingleChildScrollView(
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 800),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              SizedBox(height: 40.h),
              _buildHeaderSection(),
              SizedBox(height: 40.h),
              _buildSessionCodeCard(),
              SizedBox(height: 40.h),
              if (waiting)
                _buildWaitingState(participants.length)
              else if (_isEndedStatus(data))
                _buildSessionEndedPlaceholder()
              else if (showReadyOrConnecting)
                _buildReadyState(),
              SizedBox(height: 40.h),
              if (waiting) _buildTipsSection(),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionEndedPlaceholder() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Text(
        'This session has ended.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }

  Widget _buildBootstrapErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56.w,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 16.h),
            Text(
              _bootstrapError ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
            ),
            SizedBox(height: 24.h),
            FilledButton(
              onPressed: () {
                setState(() {
                  _bootstrapping = true;
                  _bootstrapError = null;
                });
                _bootstrapWaitingRoom();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppTheme.secondary.withValues(alpha: 0.2),
                    blurRadius: 48,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Setting up your session...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20.sp,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Waiting Room',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Get ready for meaningful conversation',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCodeCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      decoration: AppTheme.glassmorphicDecoration(),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.qr_code_rounded,
                    color: AppTheme.primary,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Code',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        'Share with your partner',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                widget.sessionCode,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingState(int participantCount) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      decoration: AppTheme.glassmorphicDecoration(),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.hourglass_empty_rounded,
                  color: AppTheme.secondary,
                  size: 32.w,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Waiting for your partner...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '$participantCount of 2 participants joined',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyState() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          Container(
            decoration: AppTheme.glassmorphicDecoration(),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Color(0xFF4CAF50)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Ready to Start!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Both participants are here. Begin your session when ready.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Container(
            width: double.infinity,
            height: 56.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: _navigated
                    ? null
                    : () {
                        _tryAdvanceToVoiceChat(manual: true);
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Start Session',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      decoration: AppTheme.glassmorphicDecoration(borderRadius: 20.r),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: AppTheme.accent,
                    size: 20.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'While You Wait',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildTipItem(
              Icons.headphones_rounded,
              'Find a quiet, private space',
            ),
            SizedBox(height: 12.h),
            _buildTipItem(
              Icons.favorite_rounded,
              'Think about what you want to discuss',
            ),
            SizedBox(height: 12.h),
            _buildTipItem(
              Icons.psychology_rounded,
              'Stay open and ready to listen',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18.w),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
