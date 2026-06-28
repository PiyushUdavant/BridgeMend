import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_background.dart';

class AppVersionScreen extends StatelessWidget {
  const AppVersionScreen({super.key});

  static const String _appVersion = '1.0.0';
  static const String _buildNumber = '1';
  static const String _releaseDate = 'June 2025';

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
        title: const Text('Version'),
      ),
      body: AuroraBackground(
        intensity: 0.6,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                SizedBox(height: 16.h),

                // App logo block
                Container(
                  width: MediaQuery.of(context).size.width/1.2,
                  padding: EdgeInsets.symmetric(
                      vertical: 32.h, horizontal: 24.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.12),
                        AppTheme.neonBlue.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72.w,
                        height: 72.w,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.neonBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusL),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: AppTheme.backgroundPrimary,
                          size: 36.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Mend',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      // Text(
                      //   'AI-powered relationship communication',
                      //   style: TextStyle(
                      //     color: AppTheme.textTertiary,
                      //     fontSize: 13.sp,
                      //   ),
                      // ),
                      // SizedBox(height: 20.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXXL),
                          border: Border.all(
                              color:
                                  AppTheme.primary.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Version $_appVersion',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // Build info
                _infoCard(context, [
                  _infoRow('Version', _appVersion, Icons.tag_rounded),
                  _divider(),
                  _infoRow('Build', _buildNumber,
                      Icons.build_circle_rounded),
                  _divider(),
                  _infoRow('Released', _releaseDate,
                      Icons.calendar_today_rounded),
                  _divider(),
                  _infoRow('Platform', 'iOS & Android',
                      Icons.phone_iphone_rounded),
                ]),

                SizedBox(height: 20.h),

                // Powered by
                _sectionLabel(context, 'POWERED BY'),
                SizedBox(height: 12.h),
                _infoCard(context, [
                  _techRow('Flutter', 'UI Framework',
                      Icons.flutter_dash_rounded, AppTheme.neonBlue),
                  _divider(),
                  _techRow('Supabase', 'Backend & Storage',
                      Icons.storage_rounded, AppTheme.successGreen),
                  _divider(),
                  _techRow('ZEGO Cloud', 'Real-time Voice',
                      Icons.mic_rounded, AppTheme.neonViolet),
                  _divider(),
                  _techRow('Node.js', 'Backend Service',
                      Icons.auto_awesome_rounded, AppTheme.aiActive),
                ]),

                SizedBox(height: 20.h),

                // Legal
                _sectionLabel(context, 'LEGAL'),
                SizedBox(height: 12.h),
                _infoCard(context, [
                  _infoRow('Developer', 'Mend Team',
                      Icons.code_rounded),
                  _divider(),
                  _infoRow(
                      'Copyright', '© 2025 Mend', Icons.copyright_rounded),
                ]),

                SizedBox(height: 32.h),
                Text(
                  'Made with care for couples everywhere.',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12.sp,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.primary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(
        color: AppTheme.glassBorder,
        height: 1,
        indent: 16,
        endIndent: 16,
      );

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textTertiary, size: 18.sp),
          SizedBox(width: 12.w),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13.sp,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _techRow(
      String name, String role, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                role,
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}