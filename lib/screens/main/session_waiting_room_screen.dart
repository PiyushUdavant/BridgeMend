import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../chat/zego_voice_chat_screen.dart';
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
    with TickerProviderStateMixin {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _sessionStream;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _sessionStream = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionCode)
        .snapshots();

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
    _joinSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _joinSession() async {
    final sessionRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionCode);
    final sessionDoc = await sessionRef.get();
    if (!sessionDoc.exists) {
      // Create session document with this user as first participant
      await sessionRef.set({
        'participants': [widget.userId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Add this user to participants if not already present
      final data = sessionDoc.data()!;
      final List participants = data['participants'] ?? [];
      if (!participants.contains(widget.userId)) {
        await sessionRef.update({
          'participants': FieldValue.arrayUnion([widget.userId]),
        });
      }
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
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionCode);
      await sessionRef.update({
        'participants': FieldValue.arrayRemove([widget.userId]),
      });
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
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _sessionStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildLoadingState();
                  }
                  final data = snapshot.data!.data();
                  final participants =
                      (data?['participants'] as List?)?.cast<String>() ?? [];
                  final isReady = participants.length >= 2;

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

                            // Enhanced header
                            _buildHeaderSection(),

                            SizedBox(height: 40.h),

                            // Session code card
                            _buildSessionCodeCard(),

                            SizedBox(height: 40.h),

                            // Status section
                            if (!isReady)
                              _buildWaitingState(participants.length)
                            else
                              _buildReadyState(),

                            SizedBox(height: 40.h),

                            // Tips section
                            if (!isReady) _buildTipsSection(),

                            SizedBox(height: 32.h),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
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
                onTap: () async {
                  final appState = Provider.of<FirebaseAppState>(
                    context,
                    listen: false,
                  );
                  await appState.startCommunicationSession(
                    sessionCode: widget.sessionCode,
                  );

                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ZegoVoiceChatScreen(
                          sessionCode: widget.sessionCode,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  }
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
