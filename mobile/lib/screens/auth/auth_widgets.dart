import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Message lisible à partir d'une exception de la couche réseau.
String authError(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Fond commun des écrans d'entrée : bandeau aurore avec logo, puis contenu défilant.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.onBack});

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          AuroraBackground(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 44,
                      child: onBack == null
                          ? null
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: PressScale(
                                onTap: onBack,
                                child: Glass(
                                  style: GlassStyle.onHero,
                                  radius: Radii.pill,
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: Space.l),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.eco_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: Space.m),
                        Text('Naatal Agro', style: T.body(color: Colors.white, weight: 800)),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    Text(title, style: T.largeTitle(color: Colors.white)),
                    const SizedBox(height: Space.xs),
                    Text(subtitle, style: T.body(color: Colors.white.withValues(alpha: 0.88))),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.huge),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

/// Message d'erreur en ligne.
class AuthMessage extends StatelessWidget {
  const AuthMessage(this.text, {super.key, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = isError ? c.clay : c.accent;
    return Container(
      padding: const EdgeInsets.all(Space.m),
      margin: const EdgeInsets.only(bottom: Space.m),
      decoration: BoxDecoration(color: color.withValues(alpha: c.isDark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(Radii.m)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: T.caption(color: c.ink, weight: 600))),
        ],
      ),
    );
  }
}

/// Bandeau « mode démonstration » : le code n'est pas envoyé par SMS mais affiché ici.
class DemoCodeCard extends StatelessWidget {
  const DemoCodeCard({super.key, required this.code, required this.onUse});

  final String code;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      margin: const EdgeInsets.only(bottom: Space.l),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: c.isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: c.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_rounded, color: c.gold),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode démonstration', style: T.body(color: c.ink, weight: 800)),
                Text('Aucun SMS n\'est envoyé. Votre code : $code', style: T.caption(color: c.ink, weight: 600)),
              ],
            ),
          ),
          PillButton(label: 'Utiliser', compact: true, variant: PillVariant.secondary, onPressed: onUse),
        ],
      ),
    );
  }
}

/// Champ de code à 4 chiffres, grand et lisible.
class OtpField extends StatelessWidget {
  const OtpField({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 4,
      style: T.number(34, color: c.ink).copyWith(letterSpacing: 14),
      decoration: const InputDecoration(counterText: '', hintText: '••••'),
    );
  }
}
