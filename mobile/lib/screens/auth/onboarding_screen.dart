import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../main.dart';
import '../../ui/ui.dart';

const _pages = [
  (Icons.agriculture_rounded, 'Suivez vos cultures', 'Semis, activités, récoltes : tout votre travail au même endroit, même sans réseau.'),
  (Icons.storefront_rounded, 'Vendez au bon endroit', 'Comparez les prix relevés sur les marchés et repérez où vendre.'),
  (Icons.auto_awesome_rounded, 'Naatal IA', 'Posez vos questions : les réponses s\'appuient sur des fiches techniques sourcées.'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _complete() async {
    ref.read(hasSeenOnboardingProvider.notifier).state = true;
    try {
      await ref.read(sharedPreferencesProvider).setBool('has_seen_onboarding', true);
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(Space.m),
                  child: AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: Motion.base,
                    child: IntrinsicWidth(child: PillButton(label: 'Passer', compact: true, variant: PillVariant.glass, onPressed: last ? null : _complete)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final (icon, title, text) = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Glass(
                            style: GlassStyle.onHero,
                            radius: 36,
                            padding: const EdgeInsets.all(Space.xl),
                            child: Icon(icon, size: 64, color: Colors.white),
                          ),
                          const SizedBox(height: Space.xxl),
                          Text(title, style: T.largeTitle(color: Colors.white)),
                          const SizedBox(height: Space.m),
                          Text(text, style: T.body(color: Colors.white.withValues(alpha: 0.9)).copyWith(fontSize: 18, height: 1.4)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.out,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == _page ? 1 : 0.45), borderRadius: BorderRadius.circular(4)),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: PillButton(
                  label: last ? 'Commencer' : 'Suivant',
                  variant: PillVariant.light,
                  expand: true,
                  onPressed: last ? _complete : () => _controller.nextPage(duration: Motion.slow, curve: Motion.out),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
