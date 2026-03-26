import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../main/home_screen.dart';
import '../../widgets/aurora_background.dart';

class PostResolutionScreen extends StatefulWidget {
  final String? sessionId;
  final String? currentUserId;
  final String? partnerName;

  const PostResolutionScreen({
    super.key,
    this.sessionId,
    this.currentUserId,
    this.partnerName,
  });

  @override
  State<PostResolutionScreen> createState() => _PostResolutionScreenState();
}

class _PostResolutionScreenState extends State<PostResolutionScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  late AnimationController _heartAnimationController;
  late AnimationController _sparkleController;
  late AnimationController _fadeController;
  late Animation<double> _heartAnimation;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;

  int _currentPage = 0;
  String _gratitudeResponse = '';
  String _reflectionResponse = '';
  bool _saveToInsights = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCelebration();
    });
  }

  void _setupAnimations() {
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _heartAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
  }

  void _showCelebration() {
    _heartAnimationController.repeat(reverse: true);
    _sparkleController.forward();
    _fadeController.forward();
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          margin: EdgeInsets.all(AppTheme.spacingL.w),
          padding: EdgeInsets.all(AppTheme.spacingXL.w),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Sparkle animations (subtle)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _sparkleAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SparklesPainter(_sparkleAnimation.value),
                    );
                  },
                ),
              ),

              // Main content
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated heart icon container
                    AnimatedBuilder(
                      animation: _heartAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _heartAnimation.value,
                          child: Container(
                            width: 100.w,
                            height: 100.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.gradientStart,
                                  AppTheme.gradientEnd,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: AppTheme.secondary.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 40,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 48.sp,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: AppTheme.spacingL.h),

                    Text(
                      'Wonderful Progress! 💜',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 28.sp,
                            letterSpacing: -0.8,
                          ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: AppTheme.spacingM.h),

                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        'You\'ve taken an important step toward understanding each other better.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: AppTheme.spacingXL.h),

                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        text: 'Continue',
                        onPressed: () {
                          Navigator.of(context).pop();
                          _startFlowAnimations();
                        },
                        height: 56.h,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startFlowAnimations() {
    _heartAnimationController.stop();
    _sparkleController.reset();
    _fadeController.reset();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeFlow();
    }
  }

  Future<void> _completeFlow() async {
    final appState = context.read<FirebaseAppState>();

    // Use passed parameters as fallback if app state is null
    final sessionId = widget.sessionId ?? appState.currentSession?.id;
    final currentUserId = widget.currentUserId ?? appState.currentUserId;
    final partnerName = widget.partnerName ?? appState.getOtherPartner()?.name;

    debugPrint(
      'Post-resolution flow - Session: $sessionId, User: $currentUserId, Partner: $partnerName',
    );
    debugPrint(
      'Widget params - SessionId: ${widget.sessionId}, UserId: ${widget.currentUserId}, Partner: ${widget.partnerName}',
    );

    // Save user responses to the session if enabled
    if (_saveToInsights) {
      final sessionReflection = {
        'gratitude': _gratitudeResponse,
        'reflection': _reflectionResponse,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // End the session with the user's reflection data
      await appState.endCommunicationSession(
        reflection: sessionReflection.toString(),
        suggestedActivities: [
          'Take a mindful walk together',
          'Cook a favorite meal together',
          'Share three things you\'re grateful for',
          'Plan your next date night',
          'Write each other a short note',
        ],
      );
    }

    // Session completed - navigate to home screen
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        final currentPartner = appState.getCurrentPartner();
        final otherPartner = appState.getOtherPartner();

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              // Prevent going back to voice session - show confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Go Home?'),
                  content: const Text(
                    'Are you sure you want to go back to the home screen? You won\'t be able to return to this session.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              );
            }
          },
          child: Stack(
            children: [
              Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: const Text('Resolution Complete'),
                ),
                body: AuroraBackground(
                  intensity: 0.6,
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Progress indicator card
                        Container(
                          margin: const EdgeInsets.all(AppTheme.spacingL),
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusL,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Step ${_currentPage + 1} of 4',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingM,
                                      vertical: AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successGreen.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                    ),
                                    child: Text(
                                      '${((_currentPage + 1) / 4 * 100).round()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.successGreen,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingM),
                              LinearProgressIndicator(
                                value: (_currentPage + 1) / 4,
                                backgroundColor: AppTheme.borderColor,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.successGreen,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Page content
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            children: [
                              _buildGratitudePage(
                                currentPartner?.name ?? 'You',
                                otherPartner?.name ?? 'Your Partner',
                              ),
                              _buildReflectionPage(),
                              _buildBondingActivitiesPage(),
                              _buildSummaryPage(),
                            ],
                          ),
                        ),

                        // Navigation
                        Container(
                          margin: const EdgeInsets.all(AppTheme.spacingL),
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusL,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              text: _currentPage == 3
                                  ? 'Complete Session'
                                  : 'Continue',
                              onPressed: _nextPage,
                              height: 56,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Confetti overlay
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    AppTheme.primary,
                    AppTheme.secondary,
                    AppTheme.accent,
                    Colors.pink,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGratitudePage(
    String currentPartnerName,
    String otherPartnerName,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Express Gratitude',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: AppTheme.aiOrbDecoration(
                        color: AppTheme.neonPink,
                        isActive: true,
                        size: 48,
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: AppTheme.textPrimary,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Take a second to thank your partner ✨',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Even small steps matter. What do you appreciate about how $otherPartnerName showed up today?',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // Current user's gratitude toward their partner
          _buildPersonalGratitudeSection(otherPartnerName),
        ],
      ),
    );
  }

  Widget _buildPersonalGratitudeSection(String partnerName) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.favorite, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Gratitude',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Express appreciation to $partnerName',
                      style: TextStyle(
                        fontSize: 14.sp,
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
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Share what you appreciated about $partnerName during this conversation...',
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.w),
              ),
              maxLines: 4,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary),
              onChanged: (value) {
                setState(() {
                  _gratitudeResponse = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Beautiful reflection header with AI orb
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(32.w),
            decoration: AppTheme.glassmorphicDecoration(
              borderRadius: 32,
              hasGlow: true,
              glowColor: AppTheme.neonViolet,
            ),
            child: Column(
              children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: AppTheme.aiOrbDecoration(
                    color: AppTheme.neonViolet,
                    isActive: true,
                    size: 100,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 48.sp,
                    color: AppTheme.textPrimary,
                  ),
                ),

                SizedBox(height: 24.h),

                Text(
                  'What felt healing in this talk? ✨',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12.h),

                Text(
                  'Share what moments felt most meaningful to you',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12.h),

                Text(
                  'Take a moment to reflect on what you learned and how you can support each other moving forward.',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: 32.h),

          // Reflection question cards
          _buildReflectionCard(
            icon: Icons.favorite_rounded,
            question:
                'What\'s one thing your partner did during this conversation that you appreciated?',
            color: AppTheme.secondary,
          ),

          SizedBox(height: 20.h),

          _buildReflectionCard(
            icon: Icons.handshake_rounded,
            question:
                'What\'s one thing you can do to support each other going forward?',
            color: AppTheme.primary,
          ),

          SizedBox(height: 32.h),

          // Current user's reflection input
          Consumer<FirebaseAppState>(
            builder: (context, appState, child) {
              final currentPartner = appState.getCurrentPartner();
              return _buildPersonalReflectionInput(
                currentPartner?.name ?? 'You',
                appState.currentUserId ?? 'A',
              );
            },
          ),

          SizedBox(height: 24.h),

          // Save to insights toggle
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: AppTheme.accent,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Save reflections to Insights Dashboard',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: _saveToInsights,
                  onChanged: (value) {
                    setState(() {
                      _saveToInsights = value;
                    });
                  },
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionCard({
    required IconData icon,
    required String question,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              question,
              style: TextStyle(
                fontSize: 15.sp,
                color: AppTheme.textSecondary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalReflectionInput(String userName, String userId) {
    final userColor = AppTheme.getPartnerColor(userId);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: userColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: userColor.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Reflection',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Share your thoughts about this conversation',
                      style: TextStyle(
                        fontSize: 14.sp,
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
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'What did you learn? How did this conversation help you grow?',
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.w),
              ),
              maxLines: 5,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondary),
              onChanged: (value) {
                setState(() {
                  _reflectionResponse = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBondingActivitiesPage() {
    final activities = [
      {
        'title': 'Take a mindful walk together',
        'description': 'Enjoy nature and talk about positive memories',
        'icon': Icons.directions_walk_rounded,
        'color': AppTheme.successGreen,
      },
      {
        'title': 'Cook a favorite meal together',
        'description': 'Bond over creating something delicious',
        'icon': Icons.restaurant_rounded,
        'color': AppTheme.secondary,
      },
      {
        'title': 'Share three things you\'re grateful for',
        'description': 'Practice gratitude and appreciation',
        'icon': Icons.favorite_rounded,
        'color': AppTheme.primary,
      },
      {
        'title': 'Plan your next date night',
        'description': 'Look forward to quality time together',
        'icon': Icons.event_rounded,
        'color': AppTheme.accent,
      },
      {
        'title': 'Write each other a short note',
        'description': 'Express your feelings in writing',
        'icon': Icons.edit_rounded,
        'color': AppTheme.secondary,
      },
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Beautiful bonding header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondary.withValues(alpha: 0.2),
                  AppTheme.accent.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.secondary, AppTheme.accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 40.sp,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 20.h),

                Text(
                  'Strengthen Your Bond',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12.h),

                Text(
                  'Here are some activities to help you connect and build on today\'s progress.',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          SizedBox(height: 32.h),

          // Bonding activities carousel
          SizedBox(
            height: 200.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return Container(
                  width: 280.w,
                  margin: EdgeInsets.only(
                    right: 16.w,
                    left: index == 0 ? 0 : 0,
                  ),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(
                      color: (activity['color'] as Color).withValues(
                        alpha: 0.2,
                      ),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (activity['color'] as Color).withValues(
                          alpha: 0.1,
                        ),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50.w,
                        height: 50.w,
                        decoration: BoxDecoration(
                          color: (activity['color'] as Color).withValues(
                            alpha: 0.15,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          activity['icon'] as IconData,
                          color: activity['color'] as Color,
                          size: 24.sp,
                        ),
                      ),

                      SizedBox(height: 12.h),

                      Flexible(
                        child: Text(
                          activity['title'] as String,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(height: 6.h),

                      Flexible(
                        child: Text(
                          activity['description'] as String,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 32.h),

          // Encouragement message
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.1),
                  AppTheme.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
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
                        'Remember',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Small, consistent actions strengthen relationships more than grand gestures.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.successGreen.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 48,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Session Complete!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'You\'ve successfully completed a guided conversation session.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // What's Next Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timeline_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Text(
                      'What\'s Next?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingL),
                _buildNextStepCard(
                  Icons.analytics_rounded,
                  'View Your Scores',
                  'See detailed feedback on your communication skills',
                ),
                const SizedBox(height: AppTheme.spacingM),
                _buildNextStepCard(
                  Icons.insights_rounded,
                  'Track Progress',
                  'Monitor your relationship growth over time',
                ),
                const SizedBox(height: AppTheme.spacingM),
                _buildNextStepCard(
                  Icons.chat_rounded,
                  'Schedule Next Session',
                  'Regular conversations lead to stronger connections',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // Encouragement Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.1),
                  AppTheme.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Great job working together!',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Your commitment to better communication is strengthening your relationship.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _heartAnimationController.dispose();
    _sparkleController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

class SparklesPainter extends CustomPainter {
  final double animationValue;

  SparklesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(
        alpha: (0.3 * (1 - animationValue * 0.5)).clamp(0.0, 1.0),
      )
      ..strokeWidth = 1.5;

    final random = math.Random(42); // Fixed seed for consistent animation

    for (int i = 0; i < 12; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final progress = (animationValue + (i * 0.1)) % 1.0;

      if (progress < 0.8) {
        final sparkleSize = 3 * (1 - progress) * progress * 4;

        // Draw subtle sparkle as a cross
        canvas.drawLine(
          Offset(x - sparkleSize, y),
          Offset(x + sparkleSize, y),
          paint,
        );
        canvas.drawLine(
          Offset(x, y - sparkleSize),
          Offset(x, y + sparkleSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
