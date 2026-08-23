import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../data/ai_provider.dart';
import '../../data/models/ai_message.dart';
import 'package:go_router/go_router.dart';
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
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.removeListener(() {});
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  void _sendMessage() async {
    final text = _controller.text;
    if (text.trim().isEmpty && _selectedImage == null) return;

    String? base64Img;
    String? imgPath;

    if (_selectedImage != null) {
      final bytes = await File(_selectedImage!.path).readAsBytes();
      base64Img = base64Encode(bytes);
      imgPath = _selectedImage!.path;
    }

    _controller.clear();
    setState(() {
      _selectedImage = null;
    });

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
    final messages = ref.watch(chatProvider);
    final notifier = ref.watch(chatProvider.notifier);

    ref.listen<List<AiMessage>>(chatProvider, (previous, next) {
      if (previous != null && next.length > previous.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFF7043)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Naatal IA', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // NAATAL_IA_IMPROVEMENT : Bouton Historique
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.black87),
            onPressed: _showHistoryBottomSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Stack(
        children: [
          // Background subtle decoration
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.05),
              ),
            ),
          ),
          
          Column(
            children: [
              _buildContextCard(),
              Expanded(
                child: messages.isEmpty ? _buildEmptyState() : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
              ),
              if (notifier.isLoading)
                _buildTypingIndicator(),
              _buildQuickSuggestions(),
              _buildMessageInput(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bonjour, je suis Naatal IA',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comment puis-je vous aider aujourd\'hui avec vos cultures ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildActionCard(
              title: 'Calculer ma rentabilité',
              subtitle: 'Estimez vos gains pour la prochaine saison.',
              icon: Icons.calculate_rounded,
              color: AppColors.primary,
              onTap: () {
                _controller.text = "Calcule la rentabilité de mes cultures";
                _sendMessage();
              },
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              title: 'Signaler au Radar',
              subtitle: 'Alertez la communauté d\'une épidémie.',
              icon: Icons.radar_rounded,
              color: Colors.red,
              onTap: _showRadarDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AiMessage message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFF7043)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: isUser ? _buildUserBubble(message) : _buildAIBubble(message),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImage != null)
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12, left: 12),
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                      ],
                      image: DecorationImage(
                        image: FileImage(File(_selectedImage!.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                      ),
                    ),
                  )
                ],
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                    onPressed: () => _pickImage(ImageSource.gallery),
                    tooltip: 'Ajouter une image',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Posez votre question...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  // NAATAL_IA_IMPROVEMENT : Badge de langue
                  GestureDetector(
                    onTap: () {
                      final currentLang = ref.read(aiLanguageProvider);
                      final newLang = currentLang == 'Fr' ? 'Wo' : 'Fr';
                      ref.read(aiLanguageProvider.notifier).state = newLang;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Langue modifiée: $newLang'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ref.watch(aiLanguageProvider), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: InkWell(
                      onTap: _sendMessage,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // NAATAL_IA_IMPROVEMENT : Carte de contexte
  Widget _buildContextCard() {
    final cropsAsync = ref.watch(cropsProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    String cropName = '-';
    String area = '-';
    String region = '-';
    if (cropsAsync is AsyncData && cropsAsync.value != null && cropsAsync.value!.isNotEmpty) {
      final mainCrop = cropsAsync.value!.first;
      cropName = mainCrop.name;
      area = '${mainCrop.areaSize} ha';
      region = mainCrop.location.isNotEmpty ? mainCrop.location : '-';
    }

    String stock = '-';
    if (inventoryAsync is AsyncData && inventoryAsync.value != null && inventoryAsync.value!.isNotEmpty) {
      final mainStock = inventoryAsync.value!.first;
      stock = '${mainStock.quantity} kg';
    }

    String temp = '-';
    if (dashboardAsync is AsyncData && dashboardAsync.value != null) {
      temp = '${dashboardAsync.value!.weather.temp.toInt()}°C';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF3DE),
        border: Border(bottom: BorderSide(color: Color(0xFF97C459), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Culture active: $cropName ($area)', style: const TextStyle(color: Color(0xFF27500A), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('Région: $region • Stock: $stock', style: const TextStyle(color: Color(0xFF27500A), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text(temp, style: const TextStyle(color: Color(0xFF27500A), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NAATAL_IA_IMPROVEMENT : Suggestions rapides
  Widget _buildQuickSuggestions() {
    if (_controller.text.isNotEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildActionChip('Quand irriguer ?', const Color(0xFF1A7A4A)),
          _buildActionChip('Mon stock', const Color(0xFF2E75B6)),
          _buildActionChip('Météo semaine', const Color(0xFFD4820A)),
          _buildActionChip('Marchés proches', Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildActionChip(String text, Color color) {
    return ActionChip(
      label: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: const EdgeInsets.all(4),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  // NAATAL_IA_IMPROVEMENT : Typing Indicator
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24).copyWith(bottomLeft: const Radius.circular(4)),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A7A4A).withOpacity(0.3 + (0.7 * ((value + (index * 0.3)) % 1.0))),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // NAATAL_IA_IMPROVEMENT : Messages Enrichis (Rich Bubbles)
  Widget _buildAIBubble(AiMessage message) {
    String tag = '';
    Color tagColor = AppColors.primary;
    String route = '';
    String routeLabel = '';
    
    if (message.text.toLowerCase().contains('irriguer') || message.text.toLowerCase().contains('irrigation')) {
      tag = 'Conseil irrigation';
      tagColor = const Color(0xFF1A7A4A);
    } else if (message.text.toLowerCase().contains('stock')) {
      tag = 'Gestion des stocks';
      tagColor = const Color(0xFF2E75B6);
      route = '/inventory';
      routeLabel = 'Voir mon stock';
    } else if (message.text.toLowerCase().contains('météo')) {
      tag = 'Prévisions météo';
      tagColor = const Color(0xFFD4820A);
    } else if (message.text.toLowerCase().contains('marché') || message.text.toLowerCase().contains('marchés')) {
      tag = 'Information marché';
      tagColor = Colors.grey.shade600;
      route = '/markets';
      routeLabel = 'Voir les marchés';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24).copyWith(bottomLeft: const Radius.circular(4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tag.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(tag, style: TextStyle(color: tagColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message.text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4),
          ),
          if (route.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push(route),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: tagColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(routeLabel, style: TextStyle(color: tagColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, color: tagColor, size: 12),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildUserBubble(AiMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24).copyWith(
          bottomRight: const Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(message.imagePath!),
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (message.text.isNotEmpty)
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }


  // NAATAL_IA_IMPROVEMENT : BottomSheet Historique
  void _showHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final history = ref.watch(aiInteractionProvider);
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Historique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (history.isEmpty)
                    const Text('Aucune conversation passée.', style: TextStyle(color: Colors.grey))
                  else
                    ...history.map((interaction) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                      title: Text(interaction.firstMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${interaction.date.day}/${interaction.date.month}/${interaction.date.year}', style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    )).toList(),
                ],
              ),
            );
          }
        );
      },
    );
  }
  void _showRadarDialog() {
    final cropController = TextEditingController();
    final pestController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.radar_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Radar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aidez la communauté en signalant une maladie. Si plusieurs signalements sont atteints, une alerte générale sera déclenchée.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: cropController,
                decoration: InputDecoration(
                  labelText: 'Culture concernée',
                  hintText: 'Ex: Tomate',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pestController,
                decoration: InputDecoration(
                  labelText: 'Ravageur / Maladie',
                  hintText: 'Ex: Mildiou',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final crop = cropController.text.trim();
                final pest = pestController.text.trim();
                if (crop.isNotEmpty && pest.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    final apiClient = ref.read(apiClientProvider);
                    await apiClient.post('/agriculture/pest-reports/', data: {
                      'pest_name': pest,
                      'location': 'Sénégal',
                      'description': 'Maladie signalée sur la culture: $crop',
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Signalement envoyé. Merci !'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Signaler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
