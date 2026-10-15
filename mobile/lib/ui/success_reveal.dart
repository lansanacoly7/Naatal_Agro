import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'effects.dart';
import 'pill_button.dart';
import 'tokens.dart';
import 'typography.dart';

/// Écran de réussite : un disque vert part du bouton touché et envahit l'écran,
/// puis la coche se dessine. Utilisé pour une vente ou une récolte enregistrée.
Future<void> showSuccessReveal(
  BuildContext context, {
  required Offset origin,
  required String headline,
  required String title,
  required List<String> details,
  String doneLabel = 'Terminer',
}) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 650),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondary) => _SuccessPage(
        headline: headline,
        title: title,
        details: details,
        doneLabel: doneLabel,
        animation: animation,
      ),
      transitionsBuilder: (context, animation, secondary, child) {
        if (context.reduceEffects) {
          return FadeTransition(opacity: animation, child: child);
        }
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => ClipPath(
            clipper: _CircleReveal(origin: origin, fraction: Curves.easeInOutCubic.transform(animation.value)),
            child: child,
          ),
        );
      },
    ),
  );
}

class _CircleReveal extends CustomClipper<Path> {
  _CircleReveal({required this.origin, required this.fraction});

  final Offset origin;
  final double fraction;

  @override
  Path getClip(Size size) {
    final far = math.max(
      math.max(origin.distance, (origin - Offset(size.width, 0)).distance),
      math.max((origin - Offset(0, size.height)).distance,
          (origin - Offset(size.width, size.height)).distance),
    );
    return Path()..addOval(Rect.fromCircle(center: origin, radius: far * fraction));
  }

  @override
  bool shouldReclip(_CircleReveal old) => old.fraction != fraction || old.origin != origin;
}

class _SuccessPage extends StatefulWidget {
  const _SuccessPage({
    required this.headline,
    required this.title,
    required this.details,
    required this.doneLabel,
    required this.animation,
  });

  final String headline;
  final String title;
  final List<String> details;
  final String doneLabel;
  final Animation<double> animation;

  @override
  State<_SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<_SuccessPage> with SingleTickerProviderStateMixin {
  late final AnimationController _check =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (mounted) _check.forward();
    });
  }

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F7A45);
    return Scaffold(
      backgroundColor: green,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl + 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: AnimatedBuilder(
                  animation: _check,
                  builder: (context, _) => CustomPaint(
                    painter: _CheckPainter(progress: Curves.easeOutCubic.transform(_check.value)),
                  ),
                ),
              ),
              const SizedBox(height: Space.xxl),
              Text(widget.headline,
                  textAlign: TextAlign.center,
                  style: T.number(40, color: Colors.white)),
              const SizedBox(height: Space.s),
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: T.body(color: Colors.white, weight: 700)),
              const SizedBox(height: Space.m),
              for (final d in widget.details)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(d,
                      textAlign: TextAlign.center,
                      style: T.body(color: Colors.white.withValues(alpha: 0.9), weight: 500)),
                ),
              const SizedBox(height: Space.huge),
              PillButton(
                label: widget.doneLabel,
                variant: PillVariant.light,
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.73, h * 0.36);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
