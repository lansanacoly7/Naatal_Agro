import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_provider.dart';
import '../../../profile/data/profile_provider.dart';
import '../../../../shared/utils/data_refresh.dart';
import '../../data/ai_provider.dart';
import '../../data/models/ai_message.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImage;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _selectedImage = bytes);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _sendMessage({String? predefinedText}) {
    final text = (predefinedText ?? _controller.text).trim();
    final image = _selectedImage;
    if (text.isEmpty && image == null) return;
    if (ref.read(chatProvider).isLoading) return;

    _controller.clear();
    setState(() => _selectedImage = null);

    ref.read(chatProvider.notifier).sendMessage(
          text,
          imageBase64: image == null ? null : base64Encode(image),
          imageBytes: image,
        );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (previous == null || next.messages.length != previous.messages.length || next.isLoading != previous.isLoading) {
        _scrollToBottom();
      }
    });

    final showEmpty = chat.messages.isEmpty && !chat.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.eco_rounded, color: AppColors.textOnPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Naatal IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('Conseils agricoles sourcés', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.textPrimary),
            onPressed: chat.messages.isEmpty ? null : () => ref.read(chatProvider.notifier).clearChat(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.isLoadingHistory && chat.messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : showEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == chat.messages.length) return const _TypingBubble();
                          final message = chat.messages[index];
                          final isLast = index == chat.messages.length - 1;
                          return _MessageBubble(
                            message: message,
                            onRetry: message.isError ? _retryLast : null,
                            onSuggestion: isLast && !chat.isLoading ? (text) => _sendMessage(predefinedText: text) : null,
                          );
                        },
                      ),
          ),
          _buildComposer(chat.isLoading),
        ],
      ),
    );
  }

  /// Renvoie la dernière question de l'utilisateur après une erreur.
  void _retryLast() {
    final messages = ref.read(chatProvider).messages;
    final lastUser = messages.lastWhere((m) => m.isUser, orElse: () => messages.last);
    if (!lastUser.isUser) return;
    _sendMessage(predefinedText: lastUser.text);
  }

  Widget _buildEmptyState() {
    final profile = ref.watch(profileNotifierProvider).valueOrNull;
    final firstName = profile?.fullName.trim().split(RegExp(r'\s+')).first ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(
          firstName.isEmpty ? 'Bonjour' : 'Bonjour, $firstName',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Posez une question sur vos cultures.',
          style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Je réponds d\'abord à partir de fiches techniques vérifiées (ISRA, FAO, ANCAR…) et je cite mes sources. '
                  'Sans fiche sur le sujet, je vous préviens que le conseil est général.',
                  style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text('Essayez par exemple', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _SuggestionTile(
          icon: Icons.grass_rounded,
          title: 'Quand semer l\'oignon ?',
          onTap: () => _sendMessage(predefinedText: 'Quand semer l\'oignon dans les Niayes ?'),
        ),
        _SuggestionTile(
          icon: Icons.science_outlined,
          title: 'Quel engrais pour la tomate ?',
          onTap: () => _sendMessage(predefinedText: 'Quels engrais utiliser pour la tomate ?'),
        ),
        _SuggestionTile(
          icon: Icons.bug_report_outlined,
          title: 'Protéger l\'arachide des maladies',
          onTap: () => _sendMessage(predefinedText: 'Comment protéger l\'arachide contre la rosette et les maladies ?'),
        ),
        _SuggestionTile(
          icon: Icons.photo_camera_outlined,
          title: 'Diagnostiquer une plante malade',
          subtitle: 'Envoyez une photo de la plante',
          onTap: _showImageSourceSheet,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showReportDialog,
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            label: const Text('Signaler une maladie observée'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(bool isLoading) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_selectedImage!, width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Semantics(
                          button: true,
                          label: 'Retirer la photo',
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                              child: const Icon(Icons.cancel, color: AppColors.error, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Ajouter une photo',
                    onPressed: _showImageSourceSheet,
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 28),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Posez votre question…',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Envoyer',
                    child: Material(
                      color: isLoading ? AppColors.textSecondary : AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: isLoading ? null : () => _sendMessage(),
                        child: const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.arrow_upward_rounded, color: AppColors.textOnPrimary, size: 26),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog() {
    final cropController = TextEditingController();
    final pestController = TextEditingController();
    final profile = ref.read(profileNotifierProvider).valueOrNull;
    final location = (profile?.location.trim().isNotEmpty ?? false) ? profile!.location.trim() : 'Sénégal';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Signaler une maladie', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aidez les autres producteurs en signalant une maladie ou un ravageur observé dans vos cultures.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cropController,
                decoration: const InputDecoration(labelText: 'Culture concernée', hintText: 'Ex : Tomate'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pestController,
                decoration: const InputDecoration(labelText: 'Ravageur ou maladie', hintText: 'Ex : Mildiou'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final crop = cropController.text.trim();
                final pest = pestController.text.trim();
                if (crop.isEmpty || pest.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);
                try {
                  await ref.read(apiClientProvider).post('/agriculture/pest-reports/', data: {
                    'pest_name': pest,
                    'location': location,
                    'description': 'Maladie signalée sur la culture : $crop',
                  });
                  refreshAfterDataChange(ref);
                  messenger.showSnackBar(const SnackBar(content: Text('Signalement enregistré. Merci !')));
                } catch (_) {
                  messenger.showSnackBar(const SnackBar(content: Text('Signalement impossible. Vérifiez votre connexion.')));
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(110, 48)),
              child: const Text('Signaler'),
            ),
          ],
        );
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SuggestionTile({required this.icon, required this.title, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (subtitle != null)
                        Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiMessage message;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onSuggestion;

  const _MessageBubble({required this.message, this.onRetry, this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = MediaQuery.of(context).size.width * 0.86;

    final suggestions = onSuggestion == null ? const <String>[] : message.suggestions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.primary
                  : message.isError
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: !isUser ? const Radius.circular(4) : null,
              ),
              border: isUser ? null : Border.all(color: message.isError ? AppColors.error.withValues(alpha: 0.4) : AppColors.surfaceVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser && !message.isError) _OriginBadge(verified: message.isVerified),
                if (message.imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(message.imageBytes!, width: 220, height: 220, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                ],
                if (message.text.isNotEmpty)
                  isUser || message.isError
                      ? SelectableText(
                          message.text,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: isUser ? AppColors.textOnPrimary : AppColors.textPrimary,
                          ),
                        )
                      : _FormattedAnswer(text: message.text),
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _showSources(context),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text('Voir les sources (${message.sources.length})'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 40),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Réessayer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => onSuggestion!(suggestion),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSources(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text('Sources de cette réponse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              for (final source in message.sources)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.number != null ? '[${source.number}] ${source.title}' : source.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      if (source.publisher.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(source.publisher, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ),
                      if (source.url.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SelectableText(source.url, style: const TextStyle(fontSize: 13, color: AppColors.secondary)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginBadge extends StatelessWidget {
  final bool verified;

  const _OriginBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.primary : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(verified ? Icons.verified_rounded : Icons.info_outline_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              verified ? 'Fiches vérifiées' : 'Conseil général · à confirmer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: verified ? AppColors.primary : const Color(0xFF9A5B00)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: const Radius.circular(4)),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = ((_controller.value - i * 0.2) % 1.0 + 1.0) % 1.0;
                    final lift = phase < 0.5 ? -5.0 * (phase * 2) : -5.0 * (2 - phase * 2);
                    return Transform.translate(
                      offset: Offset(0, lift),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.7), shape: BoxShape.circle),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Naatal IA cherche dans les fiches…', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}


/// Texte de réponse mis en forme : paragraphes, puces et mots clés en gras.
/// Le pied « Sources : » et les repères [1] sont masqués ici : les sources s'ouvrent avec le bouton dédié.
class _FormattedAnswer extends StatelessWidget {
  final String text;

  const _FormattedAnswer({required this.text});

  static final _citation = RegExp(r'\s*\[\d+\]');
  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  String get _clean => text.split('\n\nSources :').first.replaceAll(_citation, '').trim();

  List<InlineSpan> _inline(String line) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _bold.allMatches(line)) {
      if (match.start > cursor) spans.add(TextSpan(text: line.substring(cursor, match.start)));
      spans.add(TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      cursor = match.end;
    }
    if (cursor < line.length) spans.add(TextSpan(text: line.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary);
    final children = <Widget>[];
    for (final raw in _clean.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 8));
        continue;
      }
      final bullet = RegExp(r'^[-•*]\s+').firstMatch(line);
      if (bullet != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 9, right: 10),
                child: CircleAvatar(radius: 3, backgroundColor: AppColors.primary),
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
