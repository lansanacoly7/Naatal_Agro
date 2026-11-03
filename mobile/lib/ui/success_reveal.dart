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
        if (animation.isCompleted) {
          return child;
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  bool _checkStarted = false;

  late final Animation<double> _badgeScale = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0.2, 0.65, curve: Curves.easeOutBack),
  );

  late final Animation<double> _badgeOpacity = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _contentSlide = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _contentOpacity = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_onAnimationProgress);
    if (widget.animation.value >= 0.5 || widget.animation.isCompleted) {
      _startCheck();
    }
  }

  void _onAnimationProgress() {
    if (!_checkStarted && (widget.animation.value >= 0.5 || widget.animation.isCompleted)) {
      _startCheck();
    }
  }

  void _startCheck() {
    _checkStarted = true;
    if (mounted) {
      _check.forward();
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onAnimationProgress);
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final green = context.c.accent;
    final reduce = context.reduceEffects;

    return Scaffold(
      backgroundColor: green,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                      vertical: Space.l,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // Badge rond avec coche
                        reduce
                            ? _buildBadge()
                            : ScaleTransition(
                                scale: _badgeScale,
                                child: FadeTransition(
                                  opacity: _badgeOpacity,
                                  child: _buildBadge(),
                                ),
                              ),
                        const SizedBox(height: Space.xl),
                        // Bloc de texte et carte récapitulative
                        reduce
                            ? _buildContent()
                            : AnimatedBuilder(
                                animation: _contentSlide,
                                builder: (context, child) {
                                  final dy = (1.0 - _contentSlide.value) * 16.0;
                                  return Transform.translate(
                                    offset: Offset(0, dy),
                                    child: FadeTransition(
                                      opacity: _contentOpacity,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildContent(),
                              ),
                        const Spacer(flex: 3),
                        // Bouton d'action ancré en bas
                        reduce
                            ? _buildActionButton()
                            : FadeTransition(
                                opacity: _contentOpacity,
                                child: _buildActionButton(),
                              ),
                        const SizedBox(height: Space.s),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          child: AnimatedBuilder(
            animation: _check,
            builder: (context, _) => CustomPaint(
              painter: _CheckPainter(progress: Curves.easeOutCubic.transform(_check.value)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.headline,
          textAlign: TextAlign.center,
          style: T.number(36, color: Colors.white, weight: 800),
        ),
        const SizedBox(height: Space.s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: T.body(color: Colors.white, weight: 700),
          ),
        ),
        if (widget.details.isNotEmpty) ...[
          const SizedBox(height: Space.l),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (int i = 0; i < widget.details.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    Text(
                      widget.details[i],
                      textAlign: TextAlign.center,
                      style: T.body(
                        color: Colors.white.withValues(alpha: i == 0 ? 0.98 : 0.88),
                        weight: i == 0 ? 600 : 500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SizedBox(
        width: double.infinity,
        child: PillButton(
          label: widget.doneLabel,
          variant: PillVariant.light,
          expand: true,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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
