import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../models/communication_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import 'scoring_screen.dart';
import '../../widgets/aurora_background.dart';

class MutualScoringScreen extends StatefulWidget {
  const MutualScoringScreen({super.key});

  @override
  State<MutualScoringScreen> createState() => _MutualScoringScreenState();
}

class _MutualScoringScreenState extends State<MutualScoringScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  int _currentPage = 0;

  // Partner A scores Partner B
  final Map<String, double> _partnerAScoresB = {
    'empathy': 0.0,
    'listening': 0.0,
    'reception': 0.0,
    'clarity': 0.0,
    'respect': 0.0,
    'responsiveness': 0.0,
    'openMindedness': 0.0,
  };

  // Partner B scores Partner A
  final Map<String, double> _partnerBScoresA = {
    'empathy': 0.0,
    'listening': 0.0,
    'reception': 0.0,
    'clarity': 0.0,
    'respect': 0.0,
    'responsiveness': 0.0,
    'openMindedness': 0.0,
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
    _setupAnimations();
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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  bool get _canProceed {
    final currentScores = _currentPage == 0
        ? _partnerAScoresB
        : _partnerBScoresA;
    return currentScores.values.every((score) => score > 0.0);
  }

  void _nextPage() {
    if (_currentPage == 0 && _canProceed) {
      setState(() {
        _currentPage = 1;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _slideController.reset();
      _slideController.forward();
    } else if (_currentPage == 1 && _canProceed) {
      _generateMutualScores();
    }
  }

  void _generateMutualScores() async {
    final appState = context.read<FirebaseAppState>();
    final currentSession = appState.currentSession;

    if (currentSession == null) {
      _showError('No active session found.');
      return;
    }

    try {
      // Create PartnerScore objects from the ratings
      final partnerAScore = PartnerScore(
        empathy: _partnerBScoresA['empathy']! / 5.0, // Convert 1-5 to 0-1
        listening: _partnerBScoresA['listening']! / 5.0,
        reception: _partnerBScoresA['reception']! / 5.0,
        clarity: _partnerBScoresA['clarity']! / 5.0,
        respect: _partnerBScoresA['respect']! / 5.0,
        responsiveness: _partnerBScoresA['responsiveness']! / 5.0,
        openMindedness: _partnerBScoresA['openMindedness']! / 5.0,
        strengths: _generateStrengths(_partnerBScoresA),
        improvements: _generateImprovements(_partnerBScoresA),
      );

      final partnerBScore = PartnerScore(
        empathy: _partnerAScoresB['empathy']! / 5.0,
        listening: _partnerAScoresB['listening']! / 5.0,
        reception: _partnerAScoresB['reception']! / 5.0,
        clarity: _partnerAScoresB['clarity']! / 5.0,
        respect: _partnerAScoresB['respect']! / 5.0,
        responsiveness: _partnerAScoresB['responsiveness']! / 5.0,
        openMindedness: _partnerAScoresB['openMindedness']! / 5.0,
        strengths: _generateStrengths(_partnerAScoresB),
        improvements: _generateImprovements(_partnerAScoresB),
      );

      final communicationScores = CommunicationScores(
        partnerScores: {'A': partnerAScore, 'B': partnerBScore},
        overallFeedback: _generateOverallFeedback(partnerAScore, partnerBScore),
        improvementSuggestions: _generateImprovementSuggestions(),
      );

      // End the session with mutual scores
      await appState.endCommunicationSession(
        scores: communicationScores,
        reflection: 'Session completed with mutual partner evaluation',
        suggestedActivities: [
          'Continue practicing open communication',
          'Schedule regular check-ins',
          'Practice active listening exercises',
        ],
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScoringScreen()),
        );
      }
    } catch (e) {
      _showError('Failed to save scores: $e');
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
    if (scores['openMindedness']! < 3.0)
      improvements.add("Consider alternative perspectives more openly");

    if (improvements.isEmpty) {
      improvements.add("Continue building on current communication strengths");
    }

    return improvements.take(3).toList();
  }

  String _generateOverallFeedback(PartnerScore scoreA, PartnerScore scoreB) {
    final avgA = scoreA.averageScore;
    final avgB = scoreB.averageScore;
    final overall = (avgA + avgB) / 2;

    if (overall > 0.8) {
      return "Excellent mutual evaluation! You both rated each other highly, showing strong communication and respect for each other's efforts.";
    } else if (overall > 0.6) {
      return "Good mutual evaluation. You both recognize each other's communication efforts with room for growth together.";
    } else if (overall > 0.4) {
      return "Your mutual evaluation shows areas for improvement. Focus on the specific feedback to strengthen your communication.";
    } else {
      return "This evaluation reveals significant communication challenges. Consider practicing the suggested improvements together.";
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        final currentPartner = appState.getCurrentPartner();
        final otherPartner = appState.getOtherPartner();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Rate Your Partner'),
          ),
          body: AuroraBackground(
            intensity: 0.6,
            child: SafeArea(
              child: Column(
                children: [
                  // Progress indicator
                  _buildProgressIndicator(),

                  // Main content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildScoringPage(
                          raterName: currentPartner?.name ?? 'You',
                          rateeColor: AppTheme.partnerBColor,
                          rateeName: otherPartner?.name ?? 'Your Partner',
                          scores: _partnerAScoresB,
                          pageTitle: 'How did your partner communicate?',
                        ),
                        _buildScoringPage(
                          raterName: otherPartner?.name ?? 'Your Partner',
                          rateeColor: AppTheme.partnerAColor,
                          rateeName: currentPartner?.name ?? 'You',
                          scores: _partnerBScoresA,
                          pageTitle: 'How did you communicate?',
                        ),
                      ],
                    ),
                  ),

                  // Action button
                  _buildActionButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: AppTheme.glassmorphicDecoration(borderRadius: 25),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 6.h,
              decoration: BoxDecoration(
                color: AppTheme.partnerAColor,
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Container(
              height: 6.h,
              decoration: BoxDecoration(
                color: _currentPage >= 1
                    ? AppTheme.partnerBColor
                    : AppTheme.partnerBColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoringPage({
    required String raterName,
    required Color rateeColor,
    required String rateeName,
    required Map<String, double> scores,
    required String pageTitle,
  }) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: AppTheme.glassmorphicDecoration(
                    borderRadius: 20,
                    hasGlow: true,
                    glowColor: rateeColor,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60.w,
                        height: 60.w,
                        decoration: BoxDecoration(
                          color: rateeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: rateeColor.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 30.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        pageTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Rate $rateeName on each communication skill',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // Criteria list
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(_criteriaNames.length, (index) {
                        final criteriaKey = _criteriaNames[index]
                            .toLowerCase()
                            .replaceAll('-', '');
                        return _buildCriteriaCard(
                          criteriaKey,
                          _criteriaNames[index],
                          _criteriaDescriptions[index],
                          _criteriaIcons[index],
                          scores[criteriaKey] ?? 0.0,
                          rateeColor,
                          (value) {
                            setState(() {
                              scores[criteriaKey] = value;
                            });
                          },
                        );
                      }),
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

  Widget _buildActionButton() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: SizedBox(
        width: double.infinity,
        child: GradientButton(
          onPressed: _canProceed ? _nextPage : null,
          text: _currentPage == 0
              ? 'Continue to Next Rating'
              : 'Generate Results',
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
