import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/ai/data/services/voice_service.dart';
import 'press_scale.dart';
import 'tokens.dart';
import 'typography.dart';

/// Bouton « Écouter » : lit à voix haute l'instruction de l'écran (français), pour ceux qui ne lisent pas.
/// Un second appui arrête la lecture.
class ReadAloudButton extends ConsumerStatefulWidget {
  const ReadAloudButton({super.key, required this.text});

  /// Phrase courte, écrite comme on la dirait à quelqu'un.
  final String text;

  @override
  ConsumerState<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends ConsumerState<ReadAloudButton> {
  bool _speaking = false;
  Timer? _watch;

  @override
  void dispose() {
    _watch?.cancel();
    if (_speaking) ref.read(voiceServiceProvider).stopSpeaking();
    super.dispose();
  }

  Future<void> _toggle() async {
    final voice = ref.read(voiceServiceProvider);
    if (_speaking) {
      await voice.stopSpeaking();
      _watch?.cancel();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await voice.speak(widget.text);
    // La lecture se termine d'elle-même : on surveille pour remettre le bouton au repos
    _watch?.cancel();
    _watch = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted || !ref.read(voiceServiceProvider).isSpeaking) {
        timer.cancel();
        if (mounted) setState(() => _speaking = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: _toggle,
      semanticLabel: _speaking ? 'Arrêter la lecture' : 'Écouter',
      child: Container(
        height: Hit.min,
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        decoration: BoxDecoration(
          color: _speaking ? c.accent : c.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_speaking ? Icons.stop_rounded : Icons.volume_up_rounded, size: 24, color: _speaking ? c.onAccent : c.accent),
            const SizedBox(width: Space.s),
            Text(_speaking ? 'Stop' : 'Écouter', style: T.body(color: _speaking ? c.onAccent : c.accent, weight: 700)),
          ],
        ),
      ),
    );
  }
}
