import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/ai/data/ai_provider.dart';
import '../../features/ai/data/models/ai_message.dart';
import '../../features/ai/data/services/voice_service.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../features/profile/data/profile_provider.dart';
import '../../shared/utils/data_refresh.dart';
import '../../ui/ui.dart';
import '../markets/markets_data.dart';
import 'analysis_visual.dart';

/// Assistant Naatal IA : répond d'abord avec les fiches techniques sourcées, et dit
/// clairement quand il s'agit d'un conseil général non vérifié.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  Uint8List? _image;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _image = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La photo n\'a pas pu être ouverte. Vérifiez l\'autorisation de la caméra ou de la galerie.')),
        );
      }
    }
  }

  void _photoSheet() {
    showNaatalSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Photographier une plante', style: T.title(color: ctx.c.ink)),
            const SizedBox(height: Space.xs),
            Text('L\'assistant analyse l\'image et propose un diagnostic. Vérifiez toujours auprès d\'un conseiller agricole.', style: T.body(color: ctx.c.ink2)),
            const SizedBox(height: Space.xl),
            if (!kIsWeb) ...[
              PillButton(
                label: 'Prendre une photo',
                icon: Icons.photo_camera_rounded,
                expand: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _pick(ImageSource.camera);
                },
              ),
              const SizedBox(height: Space.s),
            ],
            PillButton(
              label: 'Choisir dans la galerie',
              icon: Icons.photo_library_rounded,
              variant: PillVariant.secondary,
              expand: true,
              onPressed: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    final image = _image;
    if (text.isEmpty && image == null) return;
    if (ref.read(chatProvider).isLoading) return;
    _controller.clear();
    setState(() => _image = null);
    HapticFeedback.selectionClick();
    final currentLang = ref.read(aiLanguageProvider).trim().toLowerCase();
    ref.read(chatProvider.notifier).sendMessage(
      text,
      imageBase64: image == null ? null : base64Encode(image),
      imageBytes: image,
      language: currentLang == 'wo' ? 'wo' : 'fr',
    );
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: Motion.slow, curve: Motion.out);
      }
    });
  }

  void _retry() {
    final messages = ref.read(chatProvider).messages;
    final last = messages.lastWhere((m) => m.isUser, orElse: () => messages.last);
    if (last.isUser) _send(last.text);
  }

  Future<void> _report() async {
    final profile = ref.read(profileNotifierProvider).valueOrNull;
    final location = (profile?.location.trim().isNotEmpty ?? false) ? profile!.location.trim() : '';
    await showNaatalSheet<void>(context, builder: (ctx) => _ReportSheet(location: location));
  }

  void _promptRename([String? convId, String? currentTitle]) {
    final chat = ref.read(chatProvider);
    final id = convId ?? chat.currentConversationId;
    if (id == null) return;
    final title = currentTitle ?? chat.currentConversationTitle ?? 'Discussion';
    final ctrl = TextEditingController(text: title);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer la discussion'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Titre de la discussion',
            hintText: 'Ex: Diagnostic Mildiou Thiès',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = ctrl.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await ref.read(chatProvider.notifier).renameConversation(id, newTitle);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Discussion renommée.'
                            : 'Échec du renommage de la discussion.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _openConversations() {
    ref.read(chatProvider.notifier).loadConversations();
    showNaatalSheet<void>(
      context,
      builder: (ctx) => _ConversationsSheet(
        onSelect: (id) {
          Navigator.pop(ctx);
          ref.read(chatProvider.notifier).selectConversation(id);
        },
        onNew: () {
          Navigator.pop(ctx);
          ref.read(chatProvider.notifier).startNewConversation();
        },
        onRename: (id, title) => _promptRename(id, title),
      ),
    );
  }

  void _micSheet() {
    showNaatalSheet<void>(
      context,
      builder: (ctx) => _VoiceRecordSheet(
        onTranscribed: (text) {
          _controller.text = text;
          _controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
        },
        onDirectSend: (text) {
          _send(text);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final chat = ref.watch(chatProvider);
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (prev == null || prev.messages.length != next.messages.length || prev.isLoading != next.isLoading) _toBottom();
    });
    final empty = chat.messages.isEmpty && !chat.isLoading;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                _Header(
                  title: chat.currentConversationTitle ?? 'Naatal IA',
                  canClear: chat.messages.isNotEmpty,
                  onClear: () => ref.read(chatProvider.notifier).clearChat(),
                  onHistory: _openConversations,
                  onRename: chat.currentConversationId != null ? () => _promptRename() : null,
                ),
                Expanded(
                  child: chat.isLoadingHistory && chat.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : empty
                          ? _Welcome(onAsk: _send, onPhoto: _photoSheet, onReport: _report)
                          : ListView.builder(
                              controller: _scroll,
                              padding: EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 150 + bottomInset),
                              itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == chat.messages.length) return const _Typing();
                                final m = chat.messages[i];
                                final last = i == chat.messages.length - 1;
                                final canResolve = !chat.isLoading && m.interactionId != null && (m.actionData?.isPending ?? false);
                                return _Bubble(
                                  message: m,
                                  onRetry: m.isError ? _retry : null,
                                  onSuggestion: last && !chat.isLoading ? _send : null,
                                  onResolve: canResolve
                                      ? (confirm) {
                                          HapticFeedback.selectionClick();
                                          ref.read(chatProvider.notifier).resolveProposal(m, confirm: confirm);
                                        }
                                      : null,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom > 0 ? 0 : Space.navClearance - 14),
              child: _Composer(
                controller: _controller,
                image: _image,
                busy: chat.isLoading,
                onSend: _send,
                onPhoto: _photoSheet,
                onMic: _micSheet,
                onRemovePhoto: () => setState(() => _image = null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.canClear,
    required this.onClear,
    required this.onHistory,
    this.onRename,
  });

  final String title;
  final bool canClear;
  final VoidCallback onClear;
  final VoidCallback onHistory;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.fromLTRB(Space.gutter, MediaQuery.paddingOf(context).top + Space.s, Space.s, Space.m),
      decoration: BoxDecoration(color: c.bg, border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.heroTop, c.heroBottom]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: GestureDetector(
              onTap: onRename,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.title(color: c.ink),
                        ),
                      ),
                      if (onRename != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined, size: 14, color: c.ink2),
                      ],
                    ],
                  ),
                  Text('Conseils agricoles sourcés', style: T.caption(color: c.ink2, weight: 500)),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Historique des discussions',
            onPressed: onHistory,
            icon: Icon(Icons.forum_outlined, color: c.ink),
          ),
          IconButton(
            tooltip: 'Nouvelle conversation',
            onPressed: canClear ? onClear : null,
            icon: Icon(Icons.add_comment_outlined, color: canClear ? c.ink : c.ink2.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onAsk, required this.onPhoto, required this.onReport});

  final ValueChanged<String> onAsk;
  final VoidCallback onPhoto;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final name = ref.watch(profileNotifierProvider).valueOrNull?.fullName.trim().split(RegExp(r'\s+')).first ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, 220),
      children: [
        Reveal(
          index: 0,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.l),
              image: const DecorationImage(
                image: AssetImage('assets/images/ui/ui_ia.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.l),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
                ),
              ),
              padding: const EdgeInsets.all(Space.l),
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Conseiller Naatal IA' : 'Bonjour, $name', style: T.title(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Questions agricoles analysées avec l\'IA et l\'ISRA', style: T.caption(color: Colors.white.withValues(alpha: 0.85), weight: 600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.l),
        Reveal(
          index: 1,
          child: AppCard(
            color: c.accent.withValues(alpha: c.isDark ? 0.14 : 0.08),
            border: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: c.accent),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(
                    'Je réponds d\'abord avec des fiches techniques sourcées et je cite mes sources. Sans fiche sur le sujet, je vous préviens que le conseil est général.',
                    style: T.body(color: c.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionHeaderInline('Questions suggérées'),
        for (final (i, q) in const [
          ('Oignon', 'Quand semer l\'oignon dans les Niayes ?'),
          ('Tomate', 'Quels engrais utiliser pour la tomate ?'),
          ('Arachide', 'Comment protéger l\'arachide de la rosette ?'),
        ].indexed)
          Reveal(
            index: 2 + i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: AppCard(
                onTap: () => onAsk(q.$2),
                padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.m),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: c.surfaceAlt,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            productImageForName(q.$1),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, color: c.accent, size: 24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(child: Text(q.$2, style: T.body(color: c.ink, weight: 600))),
                  ],
                ),
              ),
            ),
          ),
        Reveal(
          index: 5,
          child: AppCard(
            onTap: onPhoto,
            padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.m),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: c.accent.withValues(alpha: 0.12),
                    child: Icon(Icons.photo_camera_rounded, color: c.accent, size: 24),
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diagnostiquer une plante malade', style: T.body(color: c.ink, weight: 600)),
                      Text('Prenez ou choisissez une photo', style: T.caption(color: c.ink2, weight: 500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        Reveal(
          index: 6,
          child: PillButton(
            label: 'Signaler une maladie observée',
            icon: Icons.warning_amber_rounded,
            variant: PillVariant.danger,
            expand: true,
            onPressed: onReport,
          ),
        ),
      ],
    );
  }
}

class SectionHeaderInline extends StatelessWidget {
  const SectionHeaderInline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Space.xl, bottom: Space.m),
        child: Text(text.toUpperCase(), style: T.caption(color: context.c.ink2, weight: 700).copyWith(letterSpacing: 0.8)),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.image,
    required this.busy,
    required this.onSend,
    required this.onPhoto,
    required this.onRemovePhoto,
    this.onMic,
  });

  final TextEditingController controller;
  final Uint8List? image;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback? onMic;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: Glass(
        strong: true,
        radius: 30,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(image!, width: 72, height: 72, fit: BoxFit.cover)),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: onRemovePhoto,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.line)),
                            child: Icon(Icons.close_rounded, size: 18, color: c.clay),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Ajouter une photo',
                  onPressed: onPhoto,
                  icon: Icon(Icons.add_photo_alternate_outlined, color: c.accent, size: 28),
                ),
                if (onMic != null)
                  IconButton(
                    tooltip: 'Entrée vocale',
                    onPressed: onMic,
                    icon: Icon(Icons.mic_none_rounded, color: c.accent, size: 26),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: T.body(color: c.ink),
                    decoration: InputDecoration(
                      hintText: 'Posez votre question…',
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      hintStyle: T.body(color: c.ink2),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PressScale(
                  onTap: busy ? null : onSend,
                  semanticLabel: 'Envoyer',
                  child: AnimatedContainer(
                    duration: Motion.base,
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: busy ? c.ink2 : c.accent, shape: BoxShape.circle),
                    child: Icon(Icons.arrow_upward_rounded, color: c.onAccent, size: 28),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: Space.s),
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m + 2),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.line)),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.35 + 0.65 * (1 - ((_c.value * 3 - i) % 3).clamp(0.0, 1.0))),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, this.onRetry, this.onSuggestion, this.onResolve});

  final AiMessage message;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onSuggestion;

  /// Confirme (`true`) ou annule (`false`) la proposition d'opération portée par ce message.
  final ValueChanged<bool>? onResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = message.isUser;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.84;
    final suggestions = onSuggestion == null ? const <String>[] : message.suggestions;

    final Color bg = user ? c.accent : (message.isError ? c.clay.withValues(alpha: c.isDark ? 0.18 : 0.1) : c.surface);
    final Color fg = user ? c.onAccent : c.ink;

    return Padding(
      padding: const EdgeInsets.only(top: Space.m),
      child: Column(
        crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(user ? 22 : 6),
                  bottomRight: Radius.circular(user ? 6 : 22),
                ),
                border: user ? null : Border.all(color: message.isError ? c.clay.withValues(alpha: 0.4) : c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(message.imageBytes!, width: 180, fit: BoxFit.cover)),
                    ),
                  if (!user && !message.isError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Origin(verified: message.isVerified),
                          if (message.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.volume_up_rounded, size: 20, color: c.accent),
                              tooltip: 'Écouter la réponse vocale',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                final voice = ref.read(voiceServiceProvider);
                                if (!VoiceService.canSpeak(message.language)) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('La lecture à voix haute n\'est pas disponible en wolof : votre téléphone n\'a pas de voix wolof.'),
                                  ));
                                  return;
                                }
                                if (voice.isSpeaking) {
                                  voice.stopSpeaking();
                                } else {
                                  voice.speak(message.text);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    user || message.isError
                        ? Text(message.text, style: T.body(color: message.isError ? c.clay : fg, weight: 500))
                        : _Answer(text: message.text),
                  if (message.sources.isNotEmpty) ...[
                    const SizedBox(height: Space.m),
                    Wrap(
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        for (final s in message.sources)
                          PressScale(
                            onTap: () => showNaatalSheet<void>(context, builder: (ctx) => _SourceSheet(source: s)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: c.accent.withValues(alpha: c.isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(Radii.pill)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 14, color: c.accent),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '${s.number ?? ''} ${s.publisher.isNotEmpty ? s.publisher : s.title}'.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.caption(color: c.accent, weight: 700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (AnalysisVisualCard.isDrawable(message.actionData?.visual))
                    AnalysisVisualCard(visual: message.actionData!.visual!),
                  if (message.actionData != null)
                    _ActionCard(
                      action: message.actionData!,
                      onConfirm: onResolve != null ? () => onResolve!(true) : null,
                      onCancel: onResolve != null ? () => onResolve!(false) : null,
                    ),
                  if (onRetry != null) ...[
                    const SizedBox(height: Space.m),
                    PillButton(label: 'Réessayer', icon: Icons.refresh_rounded, compact: true, onPressed: onRetry),
                  ],
                ],
              ),
            ),
          ),
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final s in suggestions)
                    PressScale(
                      onTap: () => onSuggestion!(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          border: Border.all(color: c.accent, width: 1.5),
                        ),
                        child: Text(s, style: T.caption(color: c.accent, weight: 700)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, this.onConfirm, this.onCancel});

  final AiActionData action;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (action.isPending) {
      return Container(
        margin: const EdgeInsets.only(top: Space.m),
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: c.isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(Radii.m),
          border: Border.all(color: c.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: c.accent, size: 20),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    'Confirmation requise',
                    style: T.caption(color: c.accent, weight: 700),
                  ),
                ),
              ],
            ),
            if (action.summary != null && action.summary!.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              Text(
                action.summary!,
                style: T.body(color: c.ink, weight: 600),
              ),
            ],
            for (final warning in action.warnings) ...[
              const SizedBox(height: Space.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.clay, size: 18),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(warning, style: T.caption(color: c.clay, weight: 600))),
                ],
              ),
            ],
            const SizedBox(height: Space.m),
            Row(
              children: [
                if (onConfirm != null)
                  Expanded(
                    child: PillButton(
                      label: 'Confirmer',
                      icon: Icons.check_circle_outline_rounded,
                      compact: true,
                      onPressed: onConfirm,
                    ),
                  ),
                if (onConfirm != null && onCancel != null) const SizedBox(width: Space.s),
                if (onCancel != null)
                  Expanded(
                    child: PillButton(
                      label: 'Annuler',
                      icon: Icons.close_rounded,
                      variant: PillVariant.secondary,
                      compact: true,
                      onPressed: onCancel,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    // Proposition déjà traitée : simple rappel de son issue (le résultat détaillé est dans le message suivant)
    if (action.isProposal) {
      if (action.isExecuted) return _StatusLine(icon: Icons.check_circle_rounded, label: 'Opération confirmée', color: c.accent);
      if (action.isFailed) return _StatusLine(icon: Icons.error_outline_rounded, label: 'Opération non enregistrée', color: c.clay);
      if (action.isCancelled) return _StatusLine(icon: Icons.close_rounded, label: 'Opération annulée', color: c.ink2);
      if (action.isExpired) return _StatusLine(icon: Icons.timer_off_outlined, label: 'Proposition expirée', color: c.ink2);
      if (action.isSuperseded) {
        return _StatusLine(icon: Icons.swap_horiz_rounded, label: 'Remplacée par une demande plus récente', color: c.ink2);
      }
      return const SizedBox.shrink();
    }

    // Résultat d'une proposition : l'état affiché est celui renvoyé par le serveur
    if (action.isExecuted) {
      return _StatusLine(
        icon: Icons.check_circle_rounded,
        label: 'Opération certifiée en base de données',
        color: c.accent,
        filled: true,
      );
    }
    if (action.isFailed) {
      return _StatusLine(
        icon: Icons.error_outline_rounded,
        label: 'Rien n\'a été enregistré',
        color: c.clay,
        filled: true,
      );
    }
    return const SizedBox.shrink();
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.label, required this.color, this.filled = false});

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: Space.s),
        Flexible(child: Text(label, style: T.caption(color: color, weight: 700))),
      ],
    );
    if (!filled) {
      return Padding(padding: const EdgeInsets.only(top: Space.s), child: row);
    }
    return Container(
      margin: const EdgeInsets.only(top: Space.m),
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.m),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: row,
    );
  }
}

class _Origin extends StatelessWidget {
  const _Origin({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = verified ? c.accent : c.clay;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 5),
          Text(verified ? 'Fiches vérifiées' : 'Conseil général · à confirmer', style: T.caption(color: color, weight: 700)),
        ],
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.source});

  final AiSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Source ${source.number ?? ''}'.trim(), style: T.caption(color: c.accent, weight: 700)),
          const SizedBox(height: Space.xs),
          Text(source.title, style: T.title(color: c.ink)),
          if (source.publisher.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text(source.publisher, style: T.body(color: c.ink2)),
          ],
          if (source.url.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            SelectableText(source.url, style: T.caption(color: c.slate, weight: 600)),
            const SizedBox(height: Space.l),
            PillButton(
              label: 'Copier le lien',
              icon: Icons.copy_rounded,
              variant: PillVariant.secondary,
              expand: true,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: source.url));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié.')));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Réponse mise en forme : paragraphes, puces, mots clés en gras.
/// Le pied « Sources : » et les repères [1] sont masqués : les sources s'ouvrent avec leurs pastilles.
class _Answer extends StatelessWidget {
  const _Answer({required this.text});

  final String text;

  static final _citation = RegExp(r'\s*\[\d+\]');
  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  String get _clean => text.split('\n\nSources :').first.replaceAll(_citation, '').trim();

  List<InlineSpan> _inline(String line) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _bold.allMatches(line)) {
      if (m.start > cursor) spans.add(TextSpan(text: line.substring(cursor, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800)));
      cursor = m.end;
    }
    if (cursor < line.length) spans.add(TextSpan(text: line.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = T.body(color: c.ink).copyWith(height: 1.45);
    final children = <Widget>[];
    for (final raw in _clean.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(height: Space.s));
        continue;
      }
      final bullet = RegExp(r'^[-•*]\s+').firstMatch(line);
      if (bullet != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 9, right: 10),
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
              ),
              Expanded(child: SelectableText.rich(TextSpan(style: style, children: _inline(line.substring(bullet.end))))),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SelectableText.rich(TextSpan(style: style, children: _inline(line))),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.location});

  final String location;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _crop = TextEditingController();
  final _pest = TextEditingController();
  late final _place = TextEditingController(text: widget.location);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _crop.dispose();
    _pest.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_crop.text.trim().isEmpty || _pest.text.trim().isEmpty || _place.text.trim().isEmpty) {
      setState(() => _error = 'Indiquez la culture, la maladie et le lieu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post('/agriculture/pest-reports/', data: {
        'pest_name': _pest.text.trim(),
        'location': _place.text.trim(),
        'description': 'Maladie signalée sur la culture : ${_crop.text.trim()}',
      });
      refreshAfterDataChange(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement enregistré. Merci !')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Signalement impossible. Vérifiez votre réseau.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Signaler une maladie', style: T.title(color: c.ink)),
          const SizedBox(height: Space.xs),
          Text('Aidez les autres producteurs de votre zone : après plusieurs signalements, une alerte est envoyée.', style: T.body(color: c.ink2)),
          const SizedBox(height: Space.l),
          TextField(controller: _crop, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Culture concernée', hintText: 'Ex. : Tomate')),
          const SizedBox(height: Space.m),
          TextField(controller: _pest, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Maladie ou ravageur', hintText: 'Ex. : Mildiou')),
          const SizedBox(height: Space.m),
          TextField(controller: _place, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Lieu', errorText: _error)),
          const SizedBox(height: Space.xl),
          PillButton(label: 'Signaler', expand: true, loading: _busy, onPressed: _busy ? null : _send),
        ],
      ),
    );
  }
}

class _ConversationsSheet extends ConsumerWidget {
  const _ConversationsSheet({
    required this.onSelect,
    required this.onNew,
    this.onRename,
  });

  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final void Function(String id, String currentTitle)? onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final chat = ref.watch(chatProvider);
    final convs = chat.conversations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, color: c.accent, size: 26),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text('Historique des discussions', style: T.title(color: c.ink)),
              ),
              IconButton(
                tooltip: 'Nouvelle discussion',
                icon: Icon(Icons.add_circle_outline_rounded, color: c.accent),
                onPressed: onNew,
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Retrouvez vos échanges précédents avec Naatal IA.',
            style: T.caption(color: c.ink2),
          ),
          const SizedBox(height: Space.m),
          if (chat.isLoadingConversations && convs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(Space.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (convs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Center(
                child: Text('Aucune discussion enregistrée.', style: T.body(color: c.ink2)),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: convs.length,
                separatorBuilder: (_, __) => const SizedBox(height: Space.s),
                itemBuilder: (context, i) {
                  final item = convs[i];
                  final isCurrent = item.id == chat.currentConversationId;
                  return AppCard(
                    color: isCurrent ? c.accent.withValues(alpha: 0.12) : null,
                    onTap: () => onSelect(item.id),
                    padding: const EdgeInsets.all(Space.m),
                    child: Row(
                      children: [
                        Icon(
                          isCurrent ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                          color: isCurrent ? c.accent : c.ink2,
                          size: 20,
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.body(color: c.ink, weight: isCurrent ? 700 : 500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.messageCount} échange(s)',
                                style: T.caption(color: c.ink2),
                              ),
                            ],
                          ),
                        ),
                        if (onRename != null)
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 18, color: c.ink2),
                            tooltip: 'Renommer',
                            onPressed: () => onRename!(item.id, item.title),
                          ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.clay),
                          tooltip: 'Supprimer',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Supprimer la discussion ?'),
                                content: const Text('Cette action supprimera définitivement cette discussion et son historique.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final ok = await ref.read(chatProvider.notifier).deleteConversation(item.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Discussion supprimée.' : 'Échec de la suppression.'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceRecordSheet extends ConsumerStatefulWidget {
  const _VoiceRecordSheet({
    required this.onTranscribed,
    required this.onDirectSend,
  });

  final ValueChanged<String> onTranscribed;
  final ValueChanged<String> onDirectSend;

  @override
  ConsumerState<_VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends ConsumerState<_VoiceRecordSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  Timer? _timer;
  int _seconds = 0;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    ref.read(voiceServiceProvider).stopRecording();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _seconds = 0;
    });
    final voice = ref.read(voiceServiceProvider);
    final ok = await voice.startRecording();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _isRecording = true;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _seconds++;
        });
      });
    } else {
      setState(() {
        _isRecording = false;
        _error = 'Impossible d\'activer le microphone. Vérifiez les autorisations de l\'appareil.';
      });
    }
  }

  Future<void> _stopAndTranscribe() async {
    _timer?.cancel();
    final voice = ref.read(voiceServiceProvider);
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
      _error = null;
    });

    try {
      final audioBytes = await voice.stopRecording();
      if (!mounted) return;
      if (audioBytes == null || audioBytes.isEmpty) {
        setState(() {
          _isTranscribing = false;
          _error = 'Aucun signal audio enregistré. Réessayez.';
        });
        return;
      }

      final text = await ref.read(aiRepositoryProvider).transcribeAudio(audioBytes);
      if (!mounted) return;

      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        setState(() {
          _isTranscribing = false;
          _error = 'Aucune parole détectée dans l\'enregistrement.';
        });
        return;
      }

      Navigator.pop(context);
      widget.onDirectSend(trimmed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranscribing = false;
        _error = e is VoiceException ? e.message : 'La transcription a échoué. Réessayez ou écrivez votre message.';
      });
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await ref.read(voiceServiceProvider).stopRecording();
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded, color: c.accent, size: 28),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text('Entrée vocale Naatal IA', style: T.title(color: c.ink)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _cancel,
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(
            'Parlez en français ou en wolof. Votre voix sera transcrite automatiquement par Whisper.',
            style: T.body(color: c.ink2),
          ),
          const SizedBox(height: Space.xl),
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (ctx, child) {
                final scale = _isRecording ? 1.0 + (_pulseController.value * 0.15) : 1.0;
                final ringAlpha = _isRecording ? (0.35 - _pulseController.value * 0.25).clamp(0.05, 0.4) : 0.0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isRecording)
                      Container(
                        width: 110 * scale,
                        height: 110 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.accent.withValues(alpha: ringAlpha),
                        ),
                      ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording ? c.accent : (_isTranscribing ? c.ink2 : c.surfaceAlt),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_isRecording)
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: Center(
                        child: _isTranscribing
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Icon(
                                _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: _isRecording ? c.onAccent : c.ink,
                                size: 36,
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Space.m),
          Center(
            child: Text(
              _isTranscribing
                  ? 'Transcription en cours...'
                  : _isRecording
                      ? 'Écoute en cours : ${_formatDuration(_seconds)}'
                      : 'Prêt',
              style: T.caption(color: _isRecording ? c.accent : c.ink2, weight: 700),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.m),
            Container(
              padding: const EdgeInsets.all(Space.m),
              decoration: BoxDecoration(
                color: c.clay.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.m),
                border: Border.all(color: c.clay.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: c.clay, size: 20),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(_error!, style: T.caption(color: c.clay, weight: 600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          if (_isRecording)
            PillButton(
              label: 'Arrêter et envoyer',
              icon: Icons.send_rounded,
              expand: true,
              onPressed: _stopAndTranscribe,
            )
          else if (!_isTranscribing)
            PillButton(
              label: 'Commencer l\'enregistrement',
              icon: Icons.mic_rounded,
              expand: true,
              onPressed: _startRecording,
            ),
          const SizedBox(height: Space.m),
          Divider(color: c.line),
          const SizedBox(height: Space.m),
          Text(
            'Ou utilisez un modèle d\'action rapide :',
            style: T.caption(color: c.ink2, weight: 600),
          ),
          const SizedBox(height: Space.s),
          PillButton(
            label: '« Analyse mes finances »',
            icon: Icons.account_balance_wallet_outlined,
            variant: PillVariant.secondary,
            expand: true,
            compact: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onDirectSend('Analyse mes revenus et dépenses');
            },
          ),
          const SizedBox(height: Space.xs),
          PillButton(
            label: '« J\'ai acheté 3 sacs d\'engrais à 15000 FCFA »',
            icon: Icons.receipt_long_outlined,
            variant: PillVariant.secondary,
            expand: true,
            compact: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onDirectSend('J\'ai acheté 3 sacs d\'engrais à 15000 FCFA');
            },
          ),
        ],
      ),
    );
  }
}

