import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../models/communication_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../services/firestore_sessions_service.dart';
import '../main/home_screen.dart';
import 'ai_insights_intro_screen.dart';
import '../../widgets/aurora_background.dart';

class UserScoringScreen extends StatefulWidget {
  final String? sessionId;
  final String? currentUserId;
  final String? partnerName;
  final String? partnerId;

  const UserScoringScreen({
    super.key,
    this.sessionId,
    this.currentUserId,
    this.partnerName,
    this.partnerId,
  });

  @override
  State<UserScoringScreen> createState() => _UserScoringScreenState();
}

class _UserScoringScreenState extends State<UserScoringScreen>
    with TickerProviderStateMixin {
  final FirestoreSessionsService _sessionsService = FirestoreSessionsService();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _hasAlreadyRated = false;

  // Current user's scores for their partner
  final Map<String, double> _partnerScores = {
    'empathy': 0.0,
    'listening': 0.0,
    'reception': 0.0,
    'clarity': 0.0,
    'respect': 0.0,
    'responsiveness': 0.0,
    'openmindedness': 0.0, // Match the generated key format
  };

  final List<String> _criteriaDescriptions = [
    'How well did your partner understand and share your feelings?',
    'How actively did your partner listen to what you were saying?',
    'How open was your partner to receiving your feedback?',
    'How clearly did your partner express their thoughts and feelings?',
    'How respectfully did your partner communicate with you?',
    'How well did your partner respond to your concerns?',
    'How willing was your partner to consider different perspectives?',
  ];

  final List<String> _criteriaNames = [
    'Empathy',
    'Listening',
    'Reception',
    'Clarity',
    'Respect',
    'Responsiveness',
    'Open-Mindedness',
  ];

  final List<IconData> _criteriaIcons = [
    Icons.favorite_rounded,
    Icons.hearing_rounded,
    Icons.visibility_rounded,
    Icons.lightbulb_rounded,
    Icons.handshake_rounded,
    Icons.chat_bubble_rounded,
    Icons.psychology_rounded,
  ];

  @override
  void initState() {
    super.initState();
    debugPrint(
      'UserScoringScreen init sessionId=${widget.sessionId} '
      'currentUserId=${widget.currentUserId} partner=${widget.partnerName} (${widget.partnerId})',
    );
    _setupAnimations();
    _checkIfAlreadyRated();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _checkIfAlreadyRated() async {
    final appState = context.read<FirebaseAppState>();
    final sessionId = widget.sessionId ?? appState.currentSession?.id;
    final currentUserId =
        appState.getRaterId() ??
        widget.currentUserId ??
        appState.currentUserId;

    debugPrint(
      'Checking if already rated sessionId=$sessionId userId=$currentUserId',
    );

    if (sessionId == null || currentUserId == null) return;

    try {
      // Check if current user has already submitted their rating
      final hasRated = await _sessionsService.hasUserRatedPartner(
        sessionId,
        currentUserId,
      );

      if (mounted) {
        setState(() {
          _hasAlreadyRated = hasRated;
        });
      }
    } catch (e) {
      debugPrint('Error checking rating status: $e');
    }
  }

  bool get _canSubmit {
    final result = _partnerScores.values.every((score) => score > 0.0);
    debugPrint('_canSubmit check: $result, scores: $_partnerScores');
    return result;
  }

  String? _getPartnerIdFromRelationship(
    FirebaseAppState appState,
    String currentUserId,
  ) {
    final relationshipData = appState.relationshipData;
    if (relationshipData == null) return null;

    final partnerA = relationshipData['partnerA'];
    final partnerB = relationshipData['partnerB'];
    final idA = partnerA is Map ? partnerA['id']?.toString() : null;
    final idB = partnerB is Map ? partnerB['id']?.toString() : null;

    if (idA == currentUserId) return idB;
    if (idB == currentUserId) return idA;

    if (currentUserId == 'A') return idB ?? 'B';
    if (currentUserId == 'B') return idA ?? 'A';

    return null;
  }

  Future<void> _submitRating() async {
    debugPrint('=== SUBMIT RATING CALLED ===');
    debugPrint('Can submit: $_canSubmit');
    if (!_canSubmit) {
      debugPrint('Cannot submit - not all criteria rated');
      return;
    }

    debugPrint('Setting loading state to true');
    setState(() {
      _isLoading = true;
    });

    final appState = context.read<FirebaseAppState>();

    // Try to get data from widget params first, then from temporary storage, then from current session
    final tempData = appState.getTemporarySessionData();

    // Create dynamic session ID if none exists
    String sessionId =
        widget.sessionId ??
        tempData?['sessionId'] ??
        appState.currentSession?.id ??
        'session_${DateTime.now().millisecondsSinceEpoch}';

    // Use A/B slot ids for ratings (not Supabase auth uuid).
    String currentUserId =
        appState.getRaterId() ??
        widget.currentUserId ??
        tempData?['currentUserId'] ??
        appState.currentUserId ??
        'unknown_user';

    String? partnerId =
        widget.partnerId ??
        tempData?['partnerId'] ??
        appState.getRatedPartnerId() ??
        _getPartnerIdFromRelationship(appState, currentUserId);

    partnerId ??= currentUserId == 'A' ? 'B' : 'A';

    debugPrint(
      'Submit rating sessionId=$sessionId userId=$currentUserId partnerId=$partnerId '
      'widgetSession=${widget.sessionId} widgetUser=${widget.currentUserId}',
    );
    debugPrint('Temp data: $tempData');

    if (sessionId.isEmpty ||
        currentUserId.isEmpty ||
        partnerId.isEmpty ||
        partnerId == currentUserId) {
      debugPrint(
        'Missing session info sessionId=$sessionId userId=$currentUserId partnerId=$partnerId',
      );
      _showError('Session information not available');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      debugPrint('Creating partner score from ratings: $_partnerScores');
      // Create PartnerScore from the ratings
      final partnerScore = PartnerScore(
        empathy: _partnerScores['empathy']! / 5.0, // Convert 1-5 to 0-1
        listening: _partnerScores['listening']! / 5.0,
        reception: _partnerScores['reception']! / 5.0,
        clarity: _partnerScores['clarity']! / 5.0,
        respect: _partnerScores['respect']! / 5.0,
        responsiveness: _partnerScores['responsiveness']! / 5.0,
        openMindedness: _partnerScores['openmindedness']! / 5.0,
        strengths: _generateStrengths(_partnerScores),
        improvements: _generateImprovements(_partnerScores),
      );

      debugPrint('Saving rating to Firebase...');
      // Save the rating to Firebase
      await _sessionsService.saveUserRating(
        sessionId: sessionId,
        raterId: currentUserId,
        ratedPartnerId: partnerId,
        score: partnerScore,
      );
      debugPrint('Rating saved to Firebase successfully');

      debugPrint('Checking if both partners have rated...');
      // Check if both partners have now rated each other
      final bothRated = await _sessionsService.haveBothPartnersRated(sessionId);
      debugPrint('Both partners rated result: $bothRated');

      if (bothRated) {
        debugPrint('Both partners have rated - completing mutual scoring...');
        // Both partners have rated - generate final scores and complete session
        await _completeMutualScoring(sessionId);
        debugPrint('Mutual scoring completed');
      }

      // Show success and navigate to home screen
      debugPrint(
        'Rating submitted successfully. Both partners rated: $bothRated',
      );
      debugPrint('About to open AI insights intro...');

      if (mounted) {
        _navigateToAiInsightsIntro(bothRated);
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('23505') || message.contains('duplicate key')) {
        if (mounted) {
          setState(() => _hasAlreadyRated = true);
        }
        if (mounted) {
          _navigateToAiInsightsIntro(
            await _sessionsService.haveBothPartnersRated(sessionId),
          );
        }
      } else {
        _showError('Failed to save rating: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeMutualScoring(String sessionId) async {
    try {
      // Get both partner ratings
      final ratings = await _sessionsService.getSessionRatings(sessionId);

      final distinctRaters = ratings
          .map((r) => r['raterId']?.toString())
          .whereType<String>()
          .toSet();
      if (distinctRaters.length >= 2) {
        if (mounted) {
          final appState = context.read<FirebaseAppState>();
          final aiScores = appState.sessionAiScores;
          final aiAnalysis = appState.sessionAiAnalysis;

          // Prefer AI feedback when available; partner ratings supply per-partner scores.
          final communicationScores = CommunicationScores(
            partnerScores: {
              for (var rating in ratings)
                rating['ratedPartnerId']: PartnerScore.fromJson(
                  rating['score'],
                ),
            },
            overallFeedback: aiScores?.overallFeedback ??
                _generateOverallFeedback(ratings),
            improvementSuggestions: aiScores?.improvementSuggestions.isNotEmpty ==
                    true
                ? aiScores!.improvementSuggestions
                : _generateImprovementSuggestions(),
          );

          final bonding = aiAnalysis?['suggestedBondingActivities'];
          final suggestedActivities = bonding is List && bonding.isNotEmpty
              ? bonding.map((e) => e.toString()).toList()
              : [
                  'Continue practicing open communication',
                  'Schedule regular check-ins',
                  'Practice active listening exercises',
                ];

          await appState.endCommunicationSession(
            scores: communicationScores,
            reflection: appState.sessionAiTranscriptSummary ??
                'Session completed with mutual partner evaluation',
            suggestedActivities: suggestedActivities,
          );
        }
      }
    } catch (e) {
      debugPrint('Error completing mutual scoring: $e');
    }
  }

  List<String> _generateStrengths(Map<String, double> scores) {
    final strengths = <String>[];

    if (scores['empathy']! >= 4.0)
      strengths.add("Shows strong emotional understanding");
    if (scores['listening']! >= 4.0)
      strengths.add("Excellent active listening skills");
    if (scores['respect']! >= 4.0)
      strengths.add("Maintains respectful communication");
    if (scores['clarity']! >= 4.0) strengths.add("Expresses thoughts clearly");
    if (scores['responsiveness']! >= 4.0)
      strengths.add("Very responsive to concerns");

    if (strengths.isEmpty) {
      strengths.add("Engaged in the conversation willingly");
    }

    return strengths.take(3).toList();
  }

  List<String> _generateImprovements(Map<String, double> scores) {
    final improvements = <String>[];

    if (scores['empathy']! < 3.0)
      improvements.add("Practice showing more empathy");
    if (scores['listening']! < 3.0)
      improvements.add("Focus on active listening");
    if (scores['reception']! < 3.0)
      improvements.add("Be more open to feedback");
    if (scores['clarity']! < 3.0)
      improvements.add("Work on expressing thoughts more clearly");
    if (scores['respect']! < 3.0)
      improvements.add("Practice more respectful communication");
    if (scores['responsiveness']! < 3.0)
      improvements.add("Respond more thoughtfully to concerns");
    if (scores['openmindedness']! < 3.0)
      improvements.add("Consider alternative perspectives more openly");

    if (improvements.isEmpty) {
      improvements.add("Continue building on current communication strengths");
    }

    return improvements.take(3).toList();
  }

  String _generateOverallFeedback(List<Map<String, dynamic>> ratings) {
    if (ratings.length < 2)
      return "Waiting for both partners to complete their evaluations.";

    // Calculate average of both ratings
    double totalAverage = 0.0;
    for (var rating in ratings) {
      final score = PartnerScore.fromJson(rating['score']);
      totalAverage += score.averageScore;
    }
    totalAverage /= ratings.length;

    if (totalAverage > 0.8) {
      return "Excellent mutual evaluation! You both rated each other highly, showing strong communication and respect.";
    } else if (totalAverage > 0.6) {
      return "Good mutual evaluation. You both recognize each other's communication efforts with room for growth.";
    } else if (totalAverage > 0.4) {
      return "Your mutual evaluation shows areas for improvement. Focus on the specific feedback to strengthen communication.";
    } else {
      return "This evaluation reveals communication challenges. Practice the suggested improvements together.";
    }
  }

  List<String> _generateImprovementSuggestions() {
    return [
      "Practice giving each other regular, constructive feedback",
      "Set aside time for monthly communication check-ins",
      "Use 'I' statements when discussing areas for improvement",
      "Celebrate each other's communication strengths more often",
    ];
  }

  String _genderForPartnerSlot(FirebaseAppState appState, String partnerId) {
    final rel = appState.relationshipData;
    if (rel == null) return '';
    for (final key in ['partnerA', 'partnerB']) {
      final raw = rel[key];
      if (raw is Map && raw['id']?.toString() == partnerId) {
        return raw['gender']?.toString() ?? '';
      }
    }
    return '';
  }

  void _navigateToAiInsightsIntro(bool bothPartnersRated) {
    final appState = context.read<FirebaseAppState>();
    final temp = appState.getTemporarySessionData();

    final sessionId =
        widget.sessionId ??
        temp?['sessionId'] ??
        appState.currentSession?.id;

    final raterId =
        appState.getRaterId() ??
        widget.currentUserId ??
        temp?['currentUserId']?.toString() ??
        'A';

    final ratedPartnerId =
        widget.partnerId ??
        temp?['partnerId']?.toString() ??
        appState.getRatedPartnerId() ??
        (raterId == 'A' ? 'B' : 'A');

    final ratedPartnerName =
        widget.partnerName ??
        temp?['partnerName']?.toString() ??
        appState.getOtherPartner()?.name ??
        'Partner';

    final self = appState.getCurrentPartner();

    if (sessionId == null || sessionId.isEmpty) {
      _showError('Session information missing for AI insights.');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AiInsightsIntroScreen(
          sessionId: sessionId,
          raterId: raterId,
          ratedPartnerId: ratedPartnerId,
          ratedPartnerName: ratedPartnerName,
          selfName: self?.name ?? temp?['selfDisplayName']?.toString() ?? 'You',
          selfGender: self?.gender ?? temp?['selfGender']?.toString() ?? '',
          partnerGender:
              temp?['partnerGender']?.toString() ??
              _genderForPartnerSlot(appState, ratedPartnerId),
          bothPartnersRated: bothPartnersRated,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        final otherPartner = appState.getOtherPartner();
        final displayPartnerName =
            widget.partnerName ?? otherPartner?.name ?? 'Your Partner';

        if (_hasAlreadyRated) {
          return _buildAlreadyRatedScreen();
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            // Prevent back navigation - users must complete the scoring flow
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Rate Your Partner'),
            ),
            body: AuroraBackground(
              intensity: 0.6,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: EdgeInsets.all(20.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              _buildHeader(displayPartnerName),

                              SizedBox(height: 24.h),

                              // Criteria list
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: List.generate(
                                      _criteriaNames.length,
                                      (index) {
                                        final criteriaKey =
                                            _criteriaNames[index]
                                                .toLowerCase()
                                                .replaceAll('-', '');
                                        return _buildCriteriaCard(
                                          criteriaKey,
                                          _criteriaNames[index],
                                          _criteriaDescriptions[index],
                                          _criteriaIcons[index],
                                          _partnerScores[criteriaKey] ?? 0.0,
                                          AppTheme
                                              .partnerBColor, // Color for the partner being rated
                                          (value) {
                                            setState(() {
                                              _partnerScores[criteriaKey] =
                                                  value;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              // Submit button
                              _buildSubmitButton(),
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
        );
      },
    );
  }

  Widget _buildAlreadyRatedScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: AppTheme.glassmorphicDecoration(
                  borderRadius: 20,
                  hasGlow: true,
                  glowColor: AppTheme.successGreen,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successGreen.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 40.sp,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'Rating Complete!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'You have already submitted your rating for this session. Thank you for your feedback!',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16.sp,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        text: 'Return Home',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String partnerName) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: AppTheme.glassmorphicDecoration(
          borderRadius: 20,
          hasGlow: true,
          glowColor: AppTheme.partnerBColor,
        ),
        child: Column(
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: AppTheme.partnerBColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.partnerBColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(Icons.person_rounded, color: Colors.white, size: 30.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              'How did $partnerName communicate?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'Rate each communication skill honestly',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaCard(
    String key,
    String title,
    String description,
    IconData icon,
    double currentValue,
    Color accentColor,
    Function(double) onChanged,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.w),
      decoration: AppTheme.glassmorphicDecoration(borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: accentColor, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13.sp,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1.0;
              final isFilled = currentValue >= starValue;

              return GestureDetector(
                onTap: () => onChanged(starValue),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFilled
                        ? accentColor
                        : Colors.white.withValues(alpha: 0.3),
                    size: 32.sp,
                  ),
                ),
              );
            }),
          ),

          if (currentValue > 0)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Center(
                child: Text(
                  _getRatingLabel(currentValue.toInt()),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Needs Work';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: SizedBox(
        width: double.infinity,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 3,
                ),
              )
            : GradientButton(
                onPressed: _canSubmit ? _submitRating : null,
                text: 'Submit Rating',
              ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
