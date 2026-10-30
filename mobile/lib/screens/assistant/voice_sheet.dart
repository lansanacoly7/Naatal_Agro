import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/data/ai_provider.dart';
import '../../features/ai/data/services/voice_service.dart';
import '../../ui/ui.dart';

/// Panneau vocal de Naatal IA : le texte apparaît PENDANT que la personne parle, et se corrige au fil de la phrase.
/// À la fin, elle voit ce qui a été compris et choisit : envoyer, ou recommencer.
class VoiceSheet extends ConsumerStatefulWidget {
  const VoiceSheet({super.key, required this.onSend});

  /// Reçoit le texte confirmé par la personne.
  final ValueChanged<String> onSend;

  @override
  ConsumerState<VoiceSheet> createState() => _VoiceSheetState();
}

enum _Phase { starting, listening, finishing, confirm, error }

class _VoiceSheetState extends ConsumerState<VoiceSheet> with SingleTickerProviderStateMixin {
  /// Un morceau de son est envoyé toutes les ~1,5 s ; en dessous de cette taille, rien d'audible n'est envoyé.
  static const _flushEvery = Duration(milliseconds: 1500);
  static const _minChunkBytes = 8000;
  static const _maxChunkBytes = 200000;

  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  final BytesBuilder _pending = BytesBuilder(copy: false);
  final String _session = '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 30)}';
  StreamSubscription<Uint8List>? _sub;
  Timer? _timer;
  int _seq = 0;
  bool _inFlight = false;
  _Phase _phase = _Phase.starting;
  String _live = '';
  String? _heard;
  String? _error;

  // Gardés dès l'ouverture : `ref` ne doit plus être lu une fois le panneau fermé
  late final VoiceService _voice = ref.read(voiceServiceProvider);
  late final AiRepository _repo = ref.read(aiRepositoryProvider);

  String get _language => ref.read(aiLanguageProvider).toLowerCase().startsWith('wo') ? 'wo' : 'fr';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _pulse.dispose();
    _voice.stopLive();
    super.dispose();
  }

  Future<void> _start() async {
    _pending.clear();
    _seq = 0;
    _live = '';
    _heard = null;
    _error = null;
    setState(() => _phase = _Phase.starting);
    final stream = await _voice.startLive();
    if (!mounted) return;
    if (stream == null) {
      setState(() {
        _phase = _Phase.error;
        _error = 'Impossible d\'activer le micro. Vérifiez les autorisations de l\'appareil.';
      });
      return;
    }
    _sub = stream.listen(_pending.add);
    _timer = Timer.periodic(_flushEvery, (_) => _flush());
    setState(() => _phase = _Phase.listening);
  }

  /// Envoie le son reçu depuis le dernier envoi ; la réponse est tout le texte compris depuis le début.
  Future<void> _flush() async {
    if (_inFlight || _phase != _Phase.listening || _pending.length < _minChunkBytes) return;
    _inFlight = true;
    try {
      final chunk = _take();
      final result = await _repo.sendLiveChunk(session: _session, seq: _seq++, pcm: chunk, language: _language);
      if (mounted && _phase == _Phase.listening && result.text.isNotEmpty) setState(() => _live = result.text);
    } catch (_) {
      // Le texte en direct peut manquer un instant : le texte final, lui, est calculé sur tout l'enregistrement
    } finally {
      _inFlight = false;
    }
  }

  Uint8List _take() {
    final all = _pending.takeBytes();
    if (all.length <= _maxChunkBytes) return all;
    _pending.add(Uint8List.sublistView(all, _maxChunkBytes));
    return Uint8List.sublistView(all, 0, _maxChunkBytes);
  }

  Future<void> _finish() async {
    if (_phase != _Phase.listening) return;
    _timer?.cancel();
    setState(() => _phase = _Phase.finishing);
    await _voice.stopLive();
    unawaited(_sub?.cancel());
    // On laisse finir l'envoi en cours pour que les morceaux restent dans l'ordre
    for (var i = 0; i < 40 && _inFlight; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    try {
      while (_pending.length > _maxChunkBytes) {
        await _repo.sendLiveChunk(session: _session, seq: _seq++, pcm: _take(), language: _language);
      }
      final result = await _repo.sendLiveChunk(
            session: _session, seq: _seq++, pcm: _pending.takeBytes(), language: _language, isFinal: true);
      if (!mounted) return;
      final text = result.text.trim();
      if (text.isEmpty) throw const VoiceException('Je n\'ai rien entendu. Rapprochez-vous du micro et réessayez.');
      setState(() {
        _heard = text;
        _phase = _Phase.confirm;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e is VoiceException ? e.message : 'La transcription a échoué. Réessayez ou écrivez votre message.';
      });
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    unawaited(_sub?.cancel());
    await _voice.stopLive();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final listening = _phase == _Phase.listening;
    final shown = _heard ?? _live;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final scale = listening ? 1.0 + _pulse.value * 0.18 : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: listening ? c.accent : c.surfaceAlt, shape: BoxShape.circle),
                      child: _phase == _Phase.finishing || _phase == _Phase.starting
                          ? Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2.5, color: c.ink2))
                          : Icon(listening ? Icons.mic_rounded : Icons.check_rounded, color: listening ? c.onAccent : c.accent, size: 30),
                    ),
                  );
                },
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text(
                  switch (_phase) {
                    _Phase.starting => 'Je prépare le micro…',
                    _Phase.listening => 'Je vous écoute',
                    _Phase.finishing => 'Un instant…',
                    _Phase.confirm => 'J\'ai compris :',
                    _Phase.error => 'Oups',
                  },
                  style: T.title(color: c.ink),
                ),
              ),
              IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close_rounded), onPressed: _cancel),
            ],
          ),
          const SizedBox(height: Space.l),
          if (_phase == _Phase.error)
            Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(
                color: c.clay.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.l),
                border: Border.all(color: c.clay.withValues(alpha: 0.3)),
              ),
              child: Text(_error ?? 'Une erreur est survenue.', style: T.body(color: c.clay, weight: 700)),
            )
          else
            // Le texte se construit sous les yeux de la personne, pendant qu'elle parle
            Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.l),
                border: Border.all(color: _phase == _Phase.confirm ? c.accent : c.line, width: _phase == _Phase.confirm ? 1.5 : 1),
              ),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: Text(
                  shown.isEmpty ? 'Parlez, le texte s\'écrit ici…' : shown,
                  key: ValueKey(shown),
                  style: T.title(color: shown.isEmpty ? c.ink2 : c.ink).copyWith(fontWeight: shown.isEmpty ? FontWeight.w500 : FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: Space.xl),
          if (_phase == _Phase.confirm) ...[
            PillButton(label: 'Oui, envoyer', icon: Icons.check_rounded, expand: true, onPressed: () {
              final text = _heard!;
              Navigator.pop(context);
              widget.onSend(text);
            }),
            const SizedBox(height: Space.s),
            PillButton(label: 'Non, recommencer', icon: Icons.mic_rounded, variant: PillVariant.secondary, expand: true, onPressed: _start),
          ] else if (_phase == _Phase.error)
            PillButton(label: 'Réessayer', icon: Icons.mic_rounded, expand: true, onPressed: _start)
          else
            PillButton(
              label: 'J\'ai fini de parler',
              icon: Icons.stop_rounded,
              expand: true,
              loading: _phase == _Phase.finishing || _phase == _Phase.starting,
              onPressed: listening ? _finish : null,
            ),
        ],
      ),
    );
  }
}
