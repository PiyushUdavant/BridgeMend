import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../providers/firebase_app_state.dart';
import '../../services/zego_voice_service.dart';
import '../../services/zego_token_service.dart';
import '../../theme/app_theme.dart';
import '../resolution/user_scoring_screen.dart';
import '../../widgets/mood_checkin_dialog.dart';
import '../../widgets/aurora_background.dart';

class ZegoVoiceChatScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;

  const ZegoVoiceChatScreen({
    super.key,
    required this.sessionCode,
    required this.userId,
  });

  @override
  State<ZegoVoiceChatScreen> createState() => _ZegoVoiceChatScreenState();
}

class _ZegoVoiceChatScreenState extends State<ZegoVoiceChatScreen>
    with TickerProviderStateMixin {
  // ZEGO Voice service
  late ZegoVoiceService _zegoService;

  // Session state
  bool _isConnected = false;
  bool _isInitializing = true;

  // Voice session state
  bool _isMuted = false;
  bool _showInterruptionWarning = false;
  String _currentAIMessage =
      "What's something you've been wanting to say but haven't?";
  int _sessionMinutes = 0;
  int _sessionSeconds = 0;
  Timer? _sessionTimer;
  Timer? _aiPromptTimer;

  // Mood check-in
  bool _moodCheckedIn = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late AnimationController _aiMessageController;
  late AnimationController _warningController;
  late AnimationController _connectionController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _aiMessageAnimation;
  late Animation<double> _warningAnimation;
  late Animation<double> _connectionAnimation;

  // AI Therapy Suggestion System
  String _currentTherapyCategory = 'general';
  int _conversationTurnCount = 0;
  bool _emotionalEscalationDetected = false;
  DateTime _lastSuggestionTime = DateTime.now();

  // Categorized therapy prompts for different situations
  final Map<String, List<String>> _therapySuggestions = {
    'general': [
      "What's something you've been wanting to say but haven't?",
      "Can you share what you need most from your partner right now?",
      "What's one thing you're grateful for about your relationship?",
      "How are you feeling in this moment?",
    ],
    'conflict_resolution': [
      "Let's take a step back. What's the core issue you're both facing?",
      "Can you each share your perspective without interrupting?",
      "What would a solution look like that works for both of you?",
      "Let's focus on 'I' statements. How does this situation make you feel?",
      "What's one thing your partner could do to help you feel heard?",
    ],
    'emotional_regulation': [
      "Let's pause and take three deep breaths together.",
      "What feelings came up for you when you heard that?",
      "Can you help your partner understand what you're experiencing?",
      "It's okay to feel upset. Let's slow down and process this together.",
      "What do you need right now to feel safe in this conversation?",
    ],
    'empathy_building': [
      "Can you reflect back what you just heard from your partner?",
      "How might you approach this differently if you were your partner?",
      "What would it feel like to really be heard in this moment?",
      "Try to imagine your partner's perspective. What might they be feeling?",
      "Can you find something to appreciate about your partner's viewpoint?",
    ],
    'connection_deepening': [
      "Take a moment to appreciate something about your partner right now.",
      "What's one small thing that could help you both feel more connected?",
      "Share a memory that makes you feel close to each other.",
      "What drew you to your partner when you first met?",
      "How can you show love in a way your partner will feel it?",
    ],
    'de_escalation': [
      "Let's pause here. You're both important and your feelings matter.",
      "I notice the energy is getting intense. Let's slow down together.",
      "Can we agree to take a short break and come back to this?",
      "Remember, you're on the same team working through this together.",
      "What would help you both feel safer to continue this conversation?",
    ],
  };

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _startSessionTimer();
    _startAIPromptTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showMoodCheckinIfNeeded(),
    );
  }

  void _initializeServices() async {
    _zegoService = ZegoVoiceService();

    // Set up ZEGO callbacks
    _zegoService.addListener(_onZegoStateChanged);
    _zegoService.onError = (error) {
      if (mounted) {
        _showErrorDialog(error);
      }
    };
    _zegoService.onPartnerConnected = () {
      developer.log('Partner connected via ZEGO');
    };
    _zegoService.onPartnerDisconnected = () {
      developer.log('Partner disconnected via ZEGO');
    };

    try {
      // Initialize ZEGO engine
      await _zegoService.initializeEngine();

      // Get user info
      if (!mounted) return;
      final appState = Provider.of<FirebaseAppState>(context, listen: false);

      // Generate unique user ID for this session to avoid conflicts
      // Use Firebase UID + timestamp to ensure uniqueness
      final firebaseUid = appState.user?.uid ?? widget.userId;
      final sessionUserId =
          '${firebaseUid}_${DateTime.now().millisecondsSinceEpoch}';

      final currentPartner = appState.getCurrentPartner();
      final userName = currentPartner?.name ?? 'User';

      developer.log('=== STARTING ZEGO VOICE CALL ===');
      developer.log('Room ID: ${widget.sessionCode}');
      developer.log('User ID: $sessionUserId');
      developer.log('User Name: $userName');
      developer.log('DEBUG: appState.user?.uid = ${appState.user?.uid}');
      developer.log('DEBUG: widget.userId = ${widget.userId}');
      developer.log(
        'DEBUG: appState.currentUserId = ${appState.currentUserId}',
      );

      // Get secure token from your backend
      String? token = await ZegoTokenService.generateToken(
        sessionUserId,
        widget.sessionCode,
      );

      if (token == null) {
        developer.log(
          'WARNING: Could not get token from backend, joining without token',
        );
      } else {
        developer.log('Successfully obtained token from backend');
      }

      // Join voice room with token
      await _zegoService.joinRoom(
        widget.sessionCode,
        sessionUserId,
        userName,
        token: token,
      );

      setState(() {
        _isInitializing = false;
      });

      developer.log('=== ZEGO VOICE CALL INITIALIZED ===');
    } catch (e) {
      developer.log('CRITICAL ERROR initializing ZEGO: $e');
      setState(() {
        _isInitializing = false;
      });
      _showErrorDialog(
        'Failed to initialize voice connection. Please check your internet connection and try again.',
      );
    }
  }

  // Token fetching is now handled by ZegoTokenService

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _aiMessageController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _warningController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _connectionController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveformAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _waveformController, curve: Curves.easeOutQuart),
    );

    _aiMessageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _aiMessageController, curve: Curves.easeOutCubic),
    );

    _warningAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _warningController, curve: Curves.easeOutQuart),
    );

    _connectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _connectionController, curve: Curves.easeInOut),
    );

    _aiMessageController.forward();
  }

  void _onZegoStateChanged() {
    if (!mounted) return;

    setState(() {
      _isConnected = _zegoService.isConnected;
    });

    // Handle interruption detection
    if (_zegoService.isInterruption && !_showInterruptionWarning) {
      _showInterruptionWarning = true;
      _warningController.forward().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showInterruptionWarning = false;
            });
            _warningController.reverse();
          }
        });
      });
    }

    // Handle audio visualization
    if (_zegoService.isLocalAudioActive || _zegoService.isRemoteAudioActive) {
      _pulseController.repeat(reverse: true);
      _waveformController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _waveformController.stop();
    }

    // Connection status animation
    if (_isConnected) {
      _connectionController.forward();
    } else {
      _connectionController.reverse();
    }
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionSeconds++;
          if (_sessionSeconds >= 60) {
            _sessionSeconds = 0;
            _sessionMinutes++;
          }
        });
      }
    });
  }

  void _startAIPromptTimer() {
    // Check for therapy suggestions every 30 seconds
    _aiPromptTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isConnected) {
        _analyzeConversationAndSuggest();
      }
    });
  }

  void _analyzeConversationAndSuggest() {
    final now = DateTime.now();
    final timeSinceLastSuggestion = now.difference(_lastSuggestionTime);

    // Don't suggest too frequently (minimum 45 seconds apart)
    if (timeSinceLastSuggestion.inSeconds < 45) return;

    // Simulate conversation analysis (in real app, this would analyze audio/transcription)
    _conversationTurnCount++;

    String newCategory = _determineTherapyCategory();
    String suggestion = _getContextualSuggestion(newCategory);

    if (suggestion != _currentAIMessage) {
      setState(() {
        _currentAIMessage = suggestion;
        _currentTherapyCategory = newCategory;
      });
      _aiMessageController.reset();
      _aiMessageController.forward();
      _lastSuggestionTime = now;
    }
  }

  String _determineTherapyCategory() {
    // Simulate intelligent category selection based on conversation analysis
    // In a real implementation, this would analyze:
    // - Voice tone/volume changes
    // - Speech patterns
    // - Interruption frequency
    // - Silence duration
    // - Keyword detection from transcription

    final random = math.Random();
    final sessionLength = _sessionMinutes * 60 + _sessionSeconds;

    // Early conversation - focus on connection
    if (sessionLength < 120) {
      return random.nextBool() ? 'general' : 'connection_deepening';
    }

    // Detect escalation patterns (simplified simulation)
    if (_zegoService.isInterruption || _showInterruptionWarning) {
      _emotionalEscalationDetected = true;
      return 'de_escalation';
    }

    // If speaking levels are very different, encourage participation
    final localActive = _zegoService.isLocalAudioActive;
    final remoteActive = _zegoService.isRemoteAudioActive;

    if (localActive && !remoteActive) {
      return 'empathy_building'; // Encourage listening
    }

    // Conflict resolution patterns
    if (_conversationTurnCount > 0 && _conversationTurnCount % 8 == 0) {
      return 'conflict_resolution';
    }

    // Emotional regulation if escalation was detected recently
    if (_emotionalEscalationDetected && random.nextDouble() < 0.4) {
      _emotionalEscalationDetected = false; // Reset after addressing
      return 'emotional_regulation';
    }

    // Mid-conversation - focus on deeper connection and empathy
    if (sessionLength > 300) {
      final categories = [
        'empathy_building',
        'connection_deepening',
        'general',
      ];
      return categories[random.nextInt(categories.length)];
    }

    return 'general';
  }

  String _getContextualSuggestion(String category) {
    final suggestions =
        _therapySuggestions[category] ?? _therapySuggestions['general']!;
    final random = math.Random();
    return suggestions[random.nextInt(suggestions.length)];
  }

  void _showNewAIMessage() {
    // Manual trigger for new AI message
    _analyzeConversationAndSuggest();
  }

  Future<void> _showMoodCheckinIfNeeded() async {
    if (!_moodCheckedIn) {
      final mood = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MoodCheckinDialog(),
      );
      if (mood != null && mounted) {
        setState(() {
          _moodCheckedIn = true;
        });
      }
    }
  }

  void _toggleMute() async {
    await _zegoService.toggleMute();
    setState(() {
      _isMuted = _zegoService.isMuted;
    });
  }

  void _endSession() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.stop_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('End Voice Session'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you ready to end this conversation?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.successGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.successGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Next: Rate your partner\'s communication',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Talking'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            ),
            child: Text(
              'End & Continue',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Show loading overlay while processing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Ending session...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Capture session info BEFORE ending ZEGO session
      final appState = context.read<FirebaseAppState>();
      final sessionId = appState.currentSession?.id;
      final currentUserId = appState.currentUserId;
      final otherPartner = appState.getOtherPartner();

      print('=== VOICE CHAT ENDING DEBUG ===');
      print('Current session: ${appState.currentSession}');
      print('Session ID: $sessionId');
      print('Current user ID: $currentUserId');
      print('Other partner: $otherPartner');
      print('Other partner ID: ${otherPartner?.id}');
      print('Other partner name: ${otherPartner?.name}');

      // Store session data in app state for navigation
      appState.setTemporarySessionData(
        sessionId: sessionId,
        currentUserId: currentUserId,
        partnerId: otherPartner?.id,
        partnerName: otherPartner?.name,
      );

      await _zegoService.endSession();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate directly to user scoring screen
      if (mounted) {
        print('=== NAVIGATING TO SCORING SCREEN ===');
        print('Passing sessionId: $sessionId');
        print('Passing currentUserId: $currentUserId');
        print('Passing partnerName: ${otherPartner?.name}');
        print('Passing partnerId: ${otherPartner?.id}');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserScoringScreen(
              sessionId: sessionId,
              currentUserId: currentUserId,
              partnerName: otherPartner?.name,
              partnerId: otherPartner?.id,
            ),
          ),
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        intensity: 0.6,
        child: _isInitializing
            ? _buildInitializingScreen()
            : _buildVoiceChatUI(),
      ),
    );
  }

  Widget _buildInitializingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 24.h),
          Text(
            'Connecting to your partner...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceChatUI() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          if (_showInterruptionWarning) _buildInterruptionWarning(),
          SizedBox(height: 20.h),
          _buildAIMessageCard(),
          SizedBox(height: 24.h),
          Expanded(child: _buildPartnerViews()),
          _buildControlsFooter(),
        ],
      ),
    );
  }

  // ========== OLD UI METHODS (RESTORED WITH WORKING LOGIC) ==========

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Connection status with enhanced styling
          AnimatedBuilder(
            animation: _connectionAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + (_connectionAnimation.value * 0.1),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? AppTheme.successGreen.withValues(alpha: 0.2)
                        : AppTheme.interruptionColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: _isConnected
                          ? AppTheme.successGreen
                          : AppTheme.interruptionColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isConnected
                                    ? AppTheme.successGreen
                                    : AppTheme.interruptionColor)
                                .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: _isConnected
                              ? AppTheme.successGreen
                              : AppTheme.interruptionColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isConnected
                                          ? AppTheme.successGreen
                                          : AppTheme.interruptionColor)
                                      .withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _isConnected ? 'Connected' : 'Connecting...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Enhanced session timer with glow
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: AppTheme.primary,
                  size: 16.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  '${_sessionMinutes.toString().padLeft(2, '0')}:${_sessionSeconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterruptionWarning() {
    return AnimatedBuilder(
      animation: _warningAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _warningAnimation.value,
          child: Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.interruptionColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.interruptionColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Let\'s hold space — your partner was still sharing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIMessageCard() {
    return AnimatedBuilder(
      animation: _aiMessageAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _aiMessageAnimation.value) * 50),
          child: Transform.scale(
            scale: 0.8 + (_aiMessageAnimation.value * 0.2),
            child: Opacity(
              opacity: _aiMessageAnimation.value.clamp(0.0, 1.0),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                padding: EdgeInsets.all(20.w),
                decoration: AppTheme.glassmorphicDecoration(borderRadius: 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56.w,
                      height: 56.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // AI Orb with pulsing glow
                          AnimatedBuilder(
                            animation: _aiMessageAnimation,
                            builder: (context, child) {
                              return Container(
                                decoration: AppTheme.aiOrbDecoration(
                                  color: AppTheme.aiActive,
                                  isActive: true,
                                  size: 56,
                                ),
                              );
                            },
                          ),
                          // AI Icon
                          Icon(
                            Icons.psychology_rounded,
                            color: AppTheme.textPrimary,
                            size: 28.sp,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6.w,
                                height: 6.w,
                                decoration: BoxDecoration(
                                  color: AppTheme.aiActive,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.aiActive.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Mend AI Therapist',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor().withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: _getCategoryColor().withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _getCategoryDisplayName(),
                                  style: TextStyle(
                                    color: _getCategoryColor(),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _currentAIMessage,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartnerViews() {
    final appState = Provider.of<FirebaseAppState>(context);
    final currentPartner = appState.getCurrentPartner();

    return Row(
      children: [
        // Partner A (Local User)
        _buildPartnerView(
          name: currentPartner?.name ?? 'You',
          isLocal: true,
          isSpeaking: _zegoService.isLocalAudioActive,
          audioLevel: _zegoService.localAudioLevel,
          backgroundColor: AppTheme.partnerAColor.withValues(alpha: 0.1),
          accentColor: AppTheme.partnerAColor,
          isLeft: true,
        ),

        // Partner B (Remote Partner) - Use ZEGO partner name
        _buildPartnerView(
          name: _zegoService.partnerName ?? 'Partner',
          isLocal: false,
          isSpeaking: _zegoService.isRemoteAudioActive,
          audioLevel: _zegoService.remoteAudioLevel,
          backgroundColor: AppTheme.partnerBColor.withValues(alpha: 0.1),
          accentColor: AppTheme.partnerBColor,
          isLeft: false,
        ),
      ],
    );
  }

  Widget _buildPartnerView({
    required String name,
    required bool isLocal,
    required bool isSpeaking,
    required double audioLevel,
    required Color backgroundColor,
    required Color accentColor,
    required bool isLeft,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSpeaking
              ? backgroundColor.withValues(alpha: 0.3)
              : backgroundColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: isSpeaking
                ? accentColor.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
            width: isSpeaking ? 3 : 1,
          ),
          boxShadow: [
            if (isSpeaking) ...[
              BoxShadow(
                color: accentColor.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 6,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 60,
                spreadRadius: 12,
                offset: const Offset(0, 16),
              ),
            ] else ...[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ],
        ),
        child: Container(
          decoration: AppTheme.glassmorphicDecoration(
            borderRadius: AppTheme.radiusXL,
          ),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile section with enhanced glow
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isSpeaking ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100.w,
                          height: 100.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.5),
                                blurRadius: isSpeaking ? 30 : 15,
                                spreadRadius: isSpeaking ? 8 : 2,
                                offset: const Offset(0, 6),
                              ),
                              if (isSpeaking)
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.3),
                                  blurRadius: 50,
                                  spreadRadius: 15,
                                  offset: const Offset(0, 12),
                                ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 48.sp,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16.h),
                  // Name with enhanced typography
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8.h),

                  // Speaking indicator with glow effect
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSpeaking
                          ? accentColor.withValues(alpha: 0.3)
                          : null,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: isSpeaking
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      isSpeaking
                          ? 'Speaking...'
                          : (isLocal && _isMuted)
                          ? 'Muted'
                          : 'Listening',
                      style: TextStyle(
                        color: isSpeaking
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: 20.h),
                  // Enhanced audio level visualization
                  SizedBox(
                    height: 60.h,
                    child: isSpeaking
                        ? _buildEnhancedWaveform(accentColor, audioLevel)
                        : _buildInactiveWaveform(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedWaveform(Color color, double level) {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(8, (index) {
            final height =
                (15 +
                        (level * 75) *
                            _waveformAnimation.value *
                            (0.3 + math.Random(index).nextDouble() * 0.7))
                    .h;
            final opacity = 0.6 + (_waveformAnimation.value * 0.4);

            return Container(
              width: 6.w,
              height: height,
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(3.w),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildInactiveWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        return Container(
          width: 4.w,
          height: 8.h,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2.w),
          ),
        );
      }),
    );
  }

  Widget _buildControlsFooter() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: AppTheme.glassmorphicDecoration(borderRadius: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute/Unmute button
          _buildOldControlButton(
            onTap: _toggleMute,
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            isActive: !_isMuted,
            backgroundColor: _isMuted ? AppTheme.interruptionColor : null,
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),

          // Speaker toggle button (echo warning)
          _buildOldControlButton(
            onTap: () => _zegoService.toggleSpeaker(),
            icon: _zegoService.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            isActive: _zegoService.isSpeakerOn,
            backgroundColor: _zegoService.isSpeakerOn
                ? AppTheme.interruptionColor
                : null,
            tooltip: _zegoService.isSpeakerOn
                ? 'Speaker On (Use Headphones!)'
                : 'Enable Speaker (May Echo)',
          ),

          // New AI Therapy Suggestion button
          _buildOldControlButton(
            onTap: _showNewAIMessage,
            icon: Icons.psychology_rounded,
            isActive: false,
            tooltip: 'Get Therapy Suggestion',
          ),

          // End session button
          _buildOldControlButton(
            onTap: _endSession,
            icon: Icons.call_end_rounded,
            isActive: false,
            backgroundColor: AppTheme.interruptionColor,
            tooltip: 'End Session',
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    switch (_currentTherapyCategory) {
      case 'conflict_resolution':
        return const Color(0xFFFF6B6B); // Soft red
      case 'emotional_regulation':
        return const Color(0xFFFFD93D); // Warm yellow
      case 'empathy_building':
        return const Color(0xFF6BCF7F); // Soft green
      case 'connection_deepening':
        return const Color(0xFF4ECDC4); // Teal
      case 'de_escalation':
        return const Color(0xFFFF8E53); // Orange
      default:
        return AppTheme.aiActive; // Default blue
    }
  }

  String _getCategoryDisplayName() {
    switch (_currentTherapyCategory) {
      case 'conflict_resolution':
        return 'CONFLICT';
      case 'emotional_regulation':
        return 'EMOTION';
      case 'empathy_building':
        return 'EMPATHY';
      case 'connection_deepening':
        return 'CONNECT';
      case 'de_escalation':
        return 'CALM';
      default:
        return 'THERAPY';
    }
  }

  Widget _buildOldControlButton({
    required VoidCallback onTap,
    required IconData icon,
    required bool isActive,
    Color? backgroundColor,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 60.w,
          height: 60.w,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppTheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: backgroundColor != null
                  ? backgroundColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: backgroundColor != null
                    ? backgroundColor.withValues(alpha: 0.4)
                    : AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28.sp),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _aiPromptTimer?.cancel();
    _zegoService.removeListener(_onZegoStateChanged);
    _zegoService.dispose();
    _pulseController.dispose();
    _waveformController.dispose();
    _aiMessageController.dispose();
    _warningController.dispose();
    _connectionController.dispose();
    super.dispose();
  }
}
