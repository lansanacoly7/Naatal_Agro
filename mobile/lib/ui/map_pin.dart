import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'effects.dart';
import 'tokens.dart';
import 'typography.dart';

/// Balise de carte : une tête ronde prolongée par une pointe. La pointe (bas de la balise) désigne le lieu exact.
///
/// À poser dans un `Marker` avec `alignment: Alignment.topCenter` : le bas de la balise tombe alors sur le point.
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.color, this.child, this.size = 44, this.selected = false});

  /// Couleur de la balise.
  final Color color;

  /// Contenu de la tête (icône, initiales…).
  final Widget? child;

  /// Diamètre de la tête ; la balise est 1,4 fois plus haute.
  final double size;

  /// Balise agrandie quand elle est choisie.
  final bool selected;

  /// Hauteur d'une balise de cette taille (tête + pointe).
  static double heightFor(double size) => size * 1.4;

  @override
  Widget build(BuildContext context) {
    final height = heightFor(size);
    return AnimatedScale(
      scale: selected ? 1.2 : 1,
      alignment: Alignment.bottomCenter,
      duration: Motion.fast,
      curve: Motion.out,
      child: SizedBox(
        width: size,
        height: height,
        child: CustomPaint(
          painter: _PinPainter(color),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: size, height: size, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.color);

  final Color color;

  /// Contour en goutte : un cercle et un triangle tangent qui descend jusqu'à la pointe.
  static Path shape(Size size) {
    final r = size.width / 2;
    final cx = size.width / 2;
    final tipDistance = size.height - r; // du centre du cercle à la pointe
    final phi = math.acos(r / tipDistance);
    final dx = r * math.sin(phi);
    final dy = r + r * math.cos(phi);
    final head = Path()..addOval(Rect.fromCircle(center: Offset(cx, r), radius: r));
    final tail = Path()
      ..moveTo(cx, size.height)
      ..lineTo(cx - dx, dy)
      ..lineTo(cx + dx, dy)
      ..close();
    return Path.combine(PathOperation.union, head, tail);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape(size);
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}

/// Avatar de la personne sur la carte : sa balise bleue avec ses initiales, et un halo qui pulse à sa pointe.
class UserAvatarPin extends StatefulWidget {
  const UserAvatarPin({super.key, this.initials});

  /// Initiales de la personne ; une silhouette est montrée à défaut.
  final String? initials;

  static const double size = 52;

  /// Dimensions du `Marker` qui porte cet avatar.
  static double get markerWidth => size * 1.4;
  static double get markerHeight => MapPin.heightFor(size);

  @override
  State<UserAvatarPin> createState() => _UserAvatarPinState();
}

class _UserAvatarPinState extends State<UserAvatarPin> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = c.domainMeteo;
    if (context.reduceEffects) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
    final initials = (widget.initials ?? '').trim();
    final height = UserAvatarPin.markerHeight;
    return SizedBox(
      width: UserAvatarPin.markerWidth,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Halo posé au sol, à la pointe de la balise
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(painter: _HaloPainter(color, context.reduceEffects ? 0.35 : _pulse.value)),
            ),
          ),
          MapPin(
            color: color,
            size: UserAvatarPin.size,
            child: Container(
              width: UserAvatarPin.size * 0.7,
              height: UserAvatarPin.size * 0.7,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: initials.isEmpty
                  ? Icon(Icons.person_rounded, color: color, size: UserAvatarPin.size * 0.46)
                  : Text(initials, style: T.number(UserAvatarPin.size * 0.3, color: color)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.color, this.t);

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = 8 + 26 * t;
    canvas.drawCircle(center, radius, Paint()..color = color.withValues(alpha: 0.32 * (1 - t)));
    canvas.drawCircle(center, 5, Paint()..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.t != t || old.color != color;
}
