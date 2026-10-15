import 'package:flutter/material.dart';

import 'effects.dart';
import 'pill_button.dart';
import 'tokens.dart';
import 'typography.dart';

/// Bloc gris qui pulse pendant le chargement (jamais de roue qui tourne seule).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduced = context.reduceEffects;
    if (reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
    final base = c.surfaceAlt;
    final glow = c.isDark ? const Color(0xFF2A362E) : const Color(0xFFF4F7F3);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: [base, glow, base],
            ),
          ),
        );
      },
    );
  }
}

/// Écran ou bloc vide : explique quoi faire, jamais une valeur inventée.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.xxl, vertical: compact ? Space.xl : Space.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: c.isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(compact ? 18 : 24),
            ),
            child: Icon(icon, size: compact ? 28 : 34, color: c.accent),
          ),
          const SizedBox(height: Space.l),
          Text(title, textAlign: TextAlign.center, style: T.title(color: c.ink)),
          const SizedBox(height: Space.s),
          Text(message, textAlign: TextAlign.center, style: T.body(color: c.ink2)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.xl),
            PillButton(label: actionLabel!, onPressed: onAction, compact: true),
          ],
        ],
      ),
    );
  }
}

/// Erreur : dit ce qui s'est passé et propose de réessayer.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Impossible de charger',
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : 'Réessayer',
      onAction: onRetry,
      compact: compact,
    );
  }
}

/// Bandeau fin pour les états de réseau (hors ligne, données en cache).
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key, required this.text, this.icon = Icons.wifi_off_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.s),
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      decoration: BoxDecoration(
        color: c.clay.withValues(alpha: c.isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.clay),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: T.caption(color: c.clay, weight: 700))),
        ],
      ),
    );
  }
}
