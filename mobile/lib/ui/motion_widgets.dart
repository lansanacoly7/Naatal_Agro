import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'effects.dart';
import 'format.dart';
import 'tokens.dart';

/// Nombre qui se « compte » jusqu'à sa valeur quand elle change (900 ms).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.formatter,
    this.prefix = '',
    this.suffix = '',
    this.duration = Motion.count,
  });

  final num value;
  final TextStyle style;
  final String Function(num)? formatter;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final format = formatter ?? Fmt.grouped;
    if (context.reduceEffects) {
      return Text('$prefix${format(value)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: Motion.out,
      builder: (context, v, _) => Text('$prefix${format(v)}$suffix', style: style),
    );
  }
}

/// Entrée en cascade : chaque élément apparaît avec un léger décalage.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.dy = 16});

  final Widget child;
  final int index;
  final double dy;

  @override
  Widget build(BuildContext context) {
    if (context.reduceEffects) return child;
    final delay = Duration(milliseconds: (index * 55).clamp(0, 440));
    return _DelayedReveal(delay: delay, dy: dy, child: child);
  }
}

class _DelayedReveal extends StatefulWidget {
  const _DelayedReveal({required this.child, required this.delay, required this.dy});

  final Widget child;
  final Duration delay;
  final double dy;

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Motion.out);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.dy),
          child: child,
        ),
      ),
    );
  }
}

/// Anneau de progression animé (avancement d'une culture, par exemple).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.stroke = 7,
    this.color,
    this.track,
    this.child,
  });

  /// Entre 0 et 1.
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final target = value.clamp(0.0, 1.0);
    final ring = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: context.reduceEffects ? target : 0, end: target),
      duration: Motion.count,
      curve: Motion.out,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          value: v,
          stroke: stroke,
          color: color ?? c.accent,
          track: track ?? c.surfaceAlt,
        ),
        child: SizedBox(width: size, height: size, child: Center(child: child)),
      ),
    );
    return ring;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.stroke, required this.color, required this.track});

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(inset, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.stroke != stroke;
}

/// Lueur d'aube qui bouge doucement, derrière les en-têtes sombres.
///
/// Dégradés radiaux seulement (pas de flou) : léger pour le processeur.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));

  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduced = context.reduceEffects;
    if (reduced && _running) {
      _controller.stop();
      _running = false;
    } else if (!reduced && !_running) {
      _controller.repeat(reverse: true);
      _running = true;
    }
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.heroTop, c.heroBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _AuroraPainter(t: reduced ? 0.4 : Motion.inOut.transform(_controller.value), gold: c.gold, mint: c.mint),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t, required this.gold, required this.mint});

  final double t;
  final Color gold;
  final Color mint;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, Color color, double opacity) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    blob(Offset(size.width * (0.92 - 0.10 * t), size.height * (0.12 + 0.10 * t)), size.width * 0.62, gold, 0.55);
    blob(Offset(size.width * (0.05 + 0.14 * t), size.height * (0.62 - 0.12 * t)), size.width * 0.66, mint, 0.34);
    blob(Offset(size.width * 0.78, size.height * (0.95 - 0.08 * t)), size.width * 0.42, const Color(0xFFF08A6A), 0.18);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
