import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated aurora/nebula background used app-wide.
/// Lightweight custom painter with 3 soft radial blobs and subtle noise overlay.
class AuroraBackground extends StatefulWidget {
  final Widget? child;
  final double intensity;
  final bool blurForeground;

  const AuroraBackground({
    super.key,
    this.child,
    this.intensity = 0.65,
    this.blurForeground = false,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseBg = AppTheme.backgroundPrimary;
    return RepaintBoundary(
      child: Stack(
        children: [
          // Solid base color to ensure good contrast behind aurora
          Positioned.fill(child: ColoredBox(color: baseBg)),
          // Animated aurora blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AuroraPainter(
                    t: _controller.value,
                    intensity: widget.intensity,
                  ),
                );
              },
            ),
          ),
          // Very subtle foreground blur to add depth if requested
          if (widget.blurForeground)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const SizedBox.shrink(),
              ),
            ),
          if (widget.child != null) Positioned.fill(child: widget.child!),
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t; // 0..1 animation progress
  final double intensity;
  const _AuroraPainter({required this.t, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Background subtle vertical gradient to add dimension
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A1022), Color(0xFF0B0F1A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Three aurora blobs move in slow Lissajous-like paths
    final blobs = <_Blob>[
      _Blob(
        color: AppTheme.primary,
        baseRadius: width * 0.55,
        x: width * (0.3 + 0.05 * math.sin(2 * math.pi * (t + 0.10))),
        y: height * (0.25 + 0.06 * math.cos(2 * math.pi * (t + 0.20))),
      ),
      _Blob(
        color: AppTheme.secondary,
        baseRadius: width * 0.60,
        x: width * (0.75 + 0.04 * math.cos(2 * math.pi * (t + 0.45))),
        y: height * (0.45 + 0.05 * math.sin(2 * math.pi * (t + 0.35))),
      ),
      _Blob(
        color: AppTheme.accent,
        baseRadius: width * 0.50,
        x: width * (0.5 + 0.06 * math.sin(2 * math.pi * (t + 0.75))),
        y: height * (0.85 + 0.04 * math.cos(2 * math.pi * (t + 0.65))),
      ),
    ];

    for (final blob in blobs) {
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                blob.color.withValues(alpha: 0.18 * intensity),
                blob.color.withValues(alpha: 0.08 * intensity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(blob.x, blob.y),
                radius: blob.baseRadius,
              ),
            );

      canvas.drawCircle(Offset(blob.x, blob.y), blob.baseRadius, paint);
    }

    // Subtle vignette for focus
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.25)],
        stops: const [0.65, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.intensity != intensity;
}

class _Blob {
  final Color color;
  final double baseRadius;
  final double x;
  final double y;

  _Blob({
    required this.color,
    required this.baseRadius,
    required this.x,
    required this.y,
  });
}
