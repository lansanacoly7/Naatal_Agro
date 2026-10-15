import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'press_scale.dart';
import 'tokens.dart';
import 'typography.dart';

/// Clavier numérique géant (touches de 56 px) pour saisir quantités et prix.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key, required this.onDigit, required this.onDelete});

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Space.s,
      crossAxisSpacing: Space.s,
      childAspectRatio: 2.15,
      children: [
        for (final k in keys)
          if (k.isEmpty)
            const SizedBox.shrink()
          else
            _Key(
              label: k,
              onTap: () {
                HapticFeedback.lightImpact();
                if (k == 'del') {
                  onDelete();
                } else {
                  onDigit(k);
                }
              },
            ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      haptic: false,
      scale: 0.93,
      semanticLabel: label == 'del' ? 'Effacer' : label,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.m),
        ),
        child: label == 'del'
            ? Icon(Icons.backspace_outlined, size: 24, color: c.ink)
            : Text(label, style: T.number(24, color: c.ink, weight: 700)),
      ),
    );
  }
}
