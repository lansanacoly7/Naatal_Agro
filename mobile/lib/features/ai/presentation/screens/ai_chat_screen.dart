import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/ai_provider.dart';
import '../../data/models/ai_message.dart';
import '../../../agriculture/data/agriculture_provider.dart';
import '../../../inventory/data/inventory_provider.dart';
import '../../../dashboard/data/dashboard_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (image != null) setState(() => _selectedImage = image);
  }

  void _sendMessage([String? textValue]) async {
    final text = textValue ?? _controller.text;
    if (text.trim().isEmpty && _selectedImage == null) return;

    String? base64Img;
    String? imgPath;

    if (_selectedImage != null) {
      if (kIsWeb) {
        final bytes = await _selectedImage!.readAsBytes();
        base64Img = base64Encode(bytes);
      } else {
        final bytes = await File(_selectedImage!.path).readAsBytes();
        base64Img = base64Encode(bytes);
      }
      imgPath = _selectedImage!.path;
    }

    _controller.clear();
    setState(() => _selectedImage = null);

    ref.read(chatProvider.notifier).sendMessage(text, imageBase64: base64Img, imagePath: imgPath);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<AiMessage>>(chatProvider, (previous, next) {
      if (previous != null && next.length > previous.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 800;
          return Row(
            children: [
              if (isDesktop)
                SizedBox(
                  width: 260,
                  child: _buildSidebar(),
                ),
              Expanded(
                child: Scaffold(
                  backgroundColor: Colors.white,
                  appBar: isDesktop ? null : AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.black87),
                    title: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFF1A7A4A), size: 20),
                        SizedBox(width: 8),
                        Text('Naatal IA', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  drawer: isDesktop ? null : Drawer(
                    child: _buildSidebar(),
                  ),
                  body: _buildMainContent(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A7A4A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Text('Naatal IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () {
                // Clear chat
                ref.read(chatProvider.notifier).clearChat();
                if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 8),
                    Text('Nouveau chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // NAATAL_IA_IMPROVEMENT : NOUVELLES SECTIONS SIDEBAR
          _buildSidebarItem(context, Icons.folder_outlined, 'Projets', _showProjectsBottomSheet),
          const Divider(indent: 16, endIndent: 16),
          _buildSidebarItem(context, Icons.tune_outlined, 'Paramètres IA', _showSettingsBottomSheet),
          _buildSidebarItem(context, Icons.delete_outline, 'Effacer l\'historique', _showClearHistoryDialog, color: Colors.red.shade400),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final history = ref.watch(aiInteractionProvider);
                if (history.isEmpty) {
                  return const Center(child: Text('Aucun historique', style: TextStyle(color: Colors.grey, fontSize: 12)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final interaction = history[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                      title: Text(interaction.firstMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        // TODO: load interaction
                        if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFEAF3DE),
                  child: Text('PF', style: TextStyle(color: Color(0xFF27500A), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pathé Fall', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Linguère · Sénégal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.settings_outlined, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NAATAL_IA_IMPROVEMENT : Helper item pour la Sidebar
  Widget _buildSidebarItem(BuildContext context, IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: color ?? Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // NAATAL_IA_IMPROVEMENT : Liste de projets (état local)
  final List<String> _projets = ["Saison hivernage 2024", "Étude marché arachide", "Suivi parcelle mil"];

  // NAATAL_IA_IMPROVEMENT : BottomSheet Projets avec ajout
  void _showProjectsBottomSheet() {
    final TextEditingController newProjectCtrl = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Projets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ..._projets.map((p) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(p),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Projet '$p' sélectionné — conversations filtrées")));
                    },
                  )),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newProjectCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Nouveau projet...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF1A7A4A)),
                          onPressed: () {
                            if (newProjectCtrl.text.trim().isNotEmpty) {
                              setStateModal(() {
                                _projets.add(newProjectCtrl.text.trim());
                              });
                              newProjectCtrl.clear();
                            }
                          },
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // NAATAL_IA_IMPROVEMENT : BottomSheet Paramètres IA
  void _showSettingsBottomSheet() {
    bool wolof = false;
    bool contextAuto = true;
    bool proactive = true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Paramètres de Naatal IA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SwitchListTile(
                  title: const Text("Réponses en Wolof"),
                  value: wolof,
                  onChanged: (v) => setStateModal(() => wolof = v),
                ),
                SwitchListTile(
                  title: const Text("Contexte parcelle automatique"),
                  value: contextAuto,
                  onChanged: (v) => setStateModal(() => contextAuto = v),
                ),
                SwitchListTile(
                  title: const Text("Alertes proactives"),
                  value: proactive,
                  onChanged: (v) => setStateModal(() => proactive = v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // NAATAL_IA_IMPROVEMENT : Dialog Effacer Historique
  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Effacer l'historique"),
        content: const Text("Voulez-vous vraiment effacer tout l'historique ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              ref.read(aiInteractionProvider.notifier).state = []; // TODO: Appel au vrai backend si besoin
              ref.read(chatProvider.notifier).clearChat();
              Navigator.pop(context);
            },
            child: const Text("Effacer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final messages = ref.watch(chatProvider);
    if (messages.isEmpty) {
      return _buildEmptyState();
    }
    return _buildActiveChatState(messages);
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A7A4A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bonjour Pathé. On commence ?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Votre copilote agricole — parcelle Maïs · Linguère · 2,5 ha',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double maxWidth = constraints.maxWidth > 500 ? 500 : constraints.maxWidth;
                      return SizedBox(
                        width: maxWidth,
                        child: GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: constraints.maxWidth > 400 ? 2 : 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth > 400 ? 2.2 : 4,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildSuggestionCard(
                              'Irrigation', 
                              'Quand et combien irriguer cette semaine ?',
                              Icons.water_drop_outlined, 
                              const Color(0xFF185FA5),
                              'Quand dois-je irriguer ma parcelle de maïs cette semaine ?'
                            ),
                            _buildSuggestionCard(
                              'Mon stock', 
                              'Valeur et état de mon stock de récolte',
                              Icons.inventory_2_outlined, 
                              const Color(0xFF27500A),
                              'Quel est l\'état actuel de mon stock de maïs et sa valeur estimée ?'
                            ),
                            _buildSuggestionCard(
                              'Météo semaine', 
                              'Prévisions et alertes pour ma parcelle',
                              Icons.cloud_outlined, 
                              const Color(0xFF633806),
                              'Quelles sont les prévisions météo pour ma parcelle cette semaine ?'
                            ),
                            _buildSuggestionCard(
                              'Marchés proches', 
                              'Meilleurs prix autour de Linguère',
                              Icons.storefront_outlined, 
                              const Color(0xFF854F0B),
                              'Quels sont les meilleurs marchés proches de Linguère pour vendre mon maïs ?'
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildInputArea(maxWidth: 680),
      ],
    );
  }

  Widget _buildSuggestionCard(String title, String desc, IconData icon, Color color, String query) {
    return InkWell(
      onTap: () => _sendMessage(query),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChatState(List<AiMessage> messages) {
    final notifier = ref.watch(chatProvider.notifier);
    
    return Column(
      children: [
        _buildChatHeader(),
        _buildContextStrip(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return _buildMessageBubble(messages[index]);
            },
          ),
        ),
        if (notifier.isLoading)
          _buildTypingIndicator(),
        _buildChipsRow(),
        _buildInputArea(hasTopBorder: true),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF1A7A4A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Naatal IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Maïs · Linguère · 2,5 ha', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.language, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildContextStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF3DE),
        border: Border(bottom: BorderSide(color: Color(0xFF97C459), width: 0.5)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.grass, size: 14, color: Color(0xFF27500A)),
              SizedBox(width: 6),
              Text('Maïs · Linguère · Stock : 850 kg', style: TextStyle(color: Color(0xFF27500A), fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            children: [
              Icon(Icons.cloud_queue, size: 14, color: Color(0xFF185FA5)),
              SizedBox(width: 4),
              Text('28°C', style: TextStyle(color: Color(0xFF185FA5), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1A7A4A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFF1A7A4A) : const Color(0xFFF9FAFB),
                border: message.isUser ? null : Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(message.isUser ? 12 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser && message.text.contains('irriguer'))
                    _buildTag('Conseil irrigation', const Color(0xFF0C447C), Icons.water_drop),
                  if (!message.isUser && message.text.contains('stock'))
                    _buildTag('Votre stock', const Color(0xFF27500A), Icons.inventory_2),
                    
                  if (message.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(message.imagePath!, height: 150, width: 200, fit: BoxFit.cover)
                          : Image.file(File(message.imagePath!), height: 150, width: 200, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 30), // Pour équilibrer visuellement
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A7A4A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                _buildDot(150),
                _buildDot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF1A7A4A).withOpacity(0.3 + 0.7 * value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildChipsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionChip('Quand irriguer ?', Icons.water_drop, const Color(0xFF639922), const Color(0xFFEAF3DE), const Color(0xFF27500A)),
            _buildActionChip('État de mon stock', Icons.inventory_2, const Color(0xFF378ADD), const Color(0xFFE6F1FB), const Color(0xFF0C447C)),
            _buildActionChip('Météo cette semaine', Icons.cloud, const Color(0xFFBA7517), const Color(0xFFFAEEDA), const Color(0xFF633806)),
            _buildActionChip('Marchés proches', Icons.storefront, Colors.grey.shade400, Colors.white, Colors.grey.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(String text, IconData icon, Color borderColor, Color bgColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
              Text(text, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea({double? maxWidth, bool hasTopBorder = false}) {
    // NAATAL_IA_IMPROVEMENT : BARRE DE SAISIE VISIBLE ET ESPACEMENT BOTTOM NAV
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    // On ajoute 90px pour s'assurer que la barre n'est pas cachée par la BottomNavigationBar
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 90 + bottomPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
        ],
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedImage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12, left: 16),
                  height: 60, width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: kIsWeb 
                          ? NetworkImage(_selectedImage!.path) as ImageProvider
                          : FileImage(File(_selectedImage!.path)), 
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: const Icon(Icons.add, color: Colors.grey, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Posez votre question...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final currentLang = ref.read(aiLanguageProvider);
                        ref.read(aiLanguageProvider.notifier).state = currentLang == 'Fr' ? 'Wo' : 'Fr';
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3DE),
                          border: Border.all(color: const Color(0xFF97C459), width: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ref.watch(aiLanguageProvider),
                          style: const TextStyle(color: Color(0xFF27500A), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _sendMessage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A7A4A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 14),
                      ),
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
