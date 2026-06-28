import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class RateAppScreen extends StatefulWidget {
  const RateAppScreen({super.key});

  @override
  State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen>
    with SingleTickerProviderStateMixin {
  int _selectedStars = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
        title: const Text('Rate Mend'),
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Pulsing store icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.25),
                          AppTheme.neonBlue.withValues(alpha: 0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          width: 1.5),
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: AppTheme.primary,
                      size: 52.sp,
                    ),
                  ),
                ),

                SizedBox(height: 28.h),

                Text(
                  'Enjoying Mend?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  'Your rating helps other couples discover Mend\nand helps us make it better.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 32.h),

                // Star selector (decorative — no store action yet)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < _selectedStars;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedStars = i + 1),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            key: ValueKey(filled),
                            color: filled
                                ? AppTheme.neonCoral
                                : AppTheme.textTertiary,
                            size: 40.sp,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                SizedBox(height: 36.h),

                // Coming soon banner
                Container(
                  padding: EdgeInsets.symmetric(
                      vertical: 20.h, horizontal: 20.w),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(
                        color: AppTheme.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS),
                            ),
                            child: Icon(
                              Icons.android_rounded,
                              color: AppTheme.successGreen,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Google Play Store',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Rating will be available on launch',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: AppTheme.neonCoral
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXXL),
                              border: Border.all(
                                  color: AppTheme.neonCoral
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                color: AppTheme.neonCoral,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Divider(color: AppTheme.glassBorder, height: 1),
                      SizedBox(height: 14.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppTheme.neonBlue
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS),
                            ),
                            child: Icon(
                              Icons.apple_rounded,
                              color: AppTheme.neonBlue,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apple App Store',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Rating will be available on launch',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: AppTheme.neonCoral
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXXL),
                              border: Border.all(
                                  color: AppTheme.neonCoral
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                color: AppTheme.neonCoral,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Text(
                  'We\'ll notify you when Mend is available\nin the app stores.',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12.sp,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}