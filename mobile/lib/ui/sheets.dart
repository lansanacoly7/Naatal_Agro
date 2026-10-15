import 'package:flutter/material.dart';

import 'tokens.dart';

/// Feuille modale commune : coins arrondis, poignée, clavier géré.
Future<T?> showNaatalSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final c = context.c;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    backgroundColor: c.bg,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Space.s + 2),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: ctx.c.line,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation claire avec deux gros boutons (pas de geste caché).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showNaatalSheet<bool>(
    context,
    builder: (ctx) => _ConfirmBody(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.s),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Space.xxl),
          _SheetButton(
            label: confirmLabel,
            filled: true,
            color: destructive ? c.clay : c.accent,
            textColor: destructive ? Colors.white : c.onAccent,
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: Space.s),
          _SheetButton(
            label: 'Annuler',
            filled: false,
            color: c.ink2,
            textColor: c.ink,
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Hit.primary,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: filled ? color : Colors.transparent,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.m + 2)),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
        child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}
