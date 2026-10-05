import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_provider.dart';
import '../../data/ai_provider.dart';
import '../../data/models/ai_message.dart';

// --- Typewriter Effect Widget ---
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const TypewriterText({
    super.key, 
    required this.text, 
    this.style, 
    this.duration = const Duration(milliseconds: 15) // Speed of typing
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.text.length * widget.duration.inMilliseconds),
    );
    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(_controller);
    _controller.forward();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.duration = Duration(milliseconds: widget.text.length * widget.duration.inMilliseconds);
      _characterCount = StepTween(begin: 0, end: widget.text.length).animate(_controller);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        String visibleString = widget.text.substring(0, _characterCount.value);
        return Text(visibleString, style: widget.style);
      },
    );
  }
}

// --- Typing Indicator Widget ---
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double offset = 0.0;
            double progress = _controller.value;
            double delay = index * 0.2;
            double localizedProgress = (progress - delay) % 1.0;
            if (localizedProgress < 0) localizedProgress += 1.0;
            
            if (localizedProgress < 0.5) {
              offset = -5.0 * (localizedProgress * 2);
            } else {
              offset = -5.0 * (2 - localizedProgress * 2);
            }
            
            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  void _sendMessage({String? predefinedText}) async {
    final text = predefinedText ?? _controller.text;
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
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
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
      backgroundColor: const Color(0xFFF9FAFB),
      extendBodyBehindAppBar: true, 
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Naatal IA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF111827))),
                ],
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background mesh gradient
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              Expanded(
                child: messages.isEmpty ? _buildEmptyState() : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 70,
                    bottom: 20,
                    left: 16,
                    right: 16
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isLastAiMessage = index == messages.length - 1 && !message.isUser;
                    return _buildMessageBubble(message, isLastAiMessage);
                  },
                ),
              ),
              if (notifier.isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Row(
                          children: [
                            TypingIndicator(),
                            SizedBox(width: 8),
                            Text('Naatal IA analyse...', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              _buildMessageInput(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60,
        bottom: 24,
        left: 24,
        right: 24
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bonjour,',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.5),
          ),
          const Text(
            'Comment puis-je vous aider ?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: -0.5),
          ),
          const SizedBox(height: 40),
          
          Text("SUGGESTIONS RAPIDES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSuggestionChip(Icons.healing_rounded, 'Diagnostiquer une maladie', 'Identifie une maladie à partir d\'une photo', iconColor: Colors.green),
              _buildSuggestionChip(Icons.trending_up_rounded, 'Calculer ma rentabilité', 'Calcule la rentabilité de mes cultures', iconColor: Colors.blue),
              _buildSuggestionChip(Icons.cloud_outlined, 'Prévisions météo', 'Quelles sont les prévisions pour mes cultures ?', iconColor: Colors.teal),
              _buildSuggestionChip(Icons.warning_amber_rounded, 'Signaler au Radar', '', isRadar: true, iconColor: Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(IconData icon, String title, String prompt, {bool isRadar = false, Color? iconColor}) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: iconColor ?? (isRadar ? Colors.red : AppColors.primary)),
      label: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isRadar ? Colors.red.shade700 : const Color(0xFF374151))),
      backgroundColor: isRadar ? Colors.red.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isRadar ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      elevation: 0,
      onPressed: () {
        if (isRadar) {
          _showRadarDialog();
        } else {
          _sendMessage(predefinedText: prompt);
        }
      },
    );
  }


  Widget _buildMessageBubble(AiMessage message, bool isLastAiMessage) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(24).copyWith(
                  bottomRight: isUser ? const Radius.circular(6) : const Radius.circular(24),
                  bottomLeft: !isUser ? const Radius.circular(6) : const Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isUser ? null : Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(message.imagePath!),
                        width: 240,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (message.text.isNotEmpty)
                    isLastAiMessage
                        ? TypewriterText(
                            text: message.text,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          )
                        : Text(
                            message.text,
                            style: TextStyle(
                              color: isUser ? Colors.white : const Color(0xFF1F2937),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: Colors.transparent, 
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
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
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
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
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      padding: const EdgeInsets.only(left: 12, bottom: 12, right: 8, top: 12),
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF6B7280)),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
                        decoration: const InputDecoration(
                          hintText: 'Posez votre question...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 15),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0, bottom: 6.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _sendMessage(),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                          ),
                        ),
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

  void _showRadarDialog() {
    final cropController = TextEditingController();
    final pestController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: cropController,
                decoration: InputDecoration(
                  labelText: 'Culture concernée',
                  hintText: 'Ex: Tomate',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pestController,
                decoration: InputDecoration(
                  labelText: 'Ravageur / Maladie',
                  hintText: 'Ex: Mildiou',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final crop = cropController.text.trim();
                final pest = pestController.text.trim();
                if (crop.isNotEmpty && pest.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);
                  try {
                    final apiClient = ref.read(apiClientProvider);
                    await apiClient.post('/agriculture/pest-reports/', data: {
                      'pest_name': pest,
                      'location': 'Sénégal',
                      'description': 'Maladie signalée sur la culture: $crop',
                    });
                    if (mounted) {
                      messenger.showSnackBar(
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
                      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Signaler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
