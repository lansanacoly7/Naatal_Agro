import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ai/data/ai_provider.dart';
import 'dart:math' as math;

class PriceAnalysisScreen extends ConsumerStatefulWidget {
  final String productName;
  final double currentPrice;
  final double initialStock;

  const PriceAnalysisScreen({
    super.key,
    required this.productName,
    required this.currentPrice,
    this.initialStock = 0.0,
  });

  @override
  ConsumerState<PriceAnalysisScreen> createState() => _PriceAnalysisScreenState();
}

class _PriceAnalysisScreenState extends ConsumerState<PriceAnalysisScreen> {
  int _selectedDays = 7;
  late TextEditingController _stockController;
  final TextEditingController _chatController = TextEditingController();
  
  final List<Map<String, String>> _messages = [
    {'sender': 'ia', 'text': 'Bonjour ! Je suis Naatal IA. Comment puis-je vous aider à optimiser vos revenus aujourd\'hui ?'},
  ];

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(
      text: widget.initialStock > 0 ? widget.initialStock.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  // Calcul déterministe pour avoir des baisses et hausses réalistes selon le produit
  double get _predictedPrice {
    final seed = widget.productName.codeUnits.reduce((a, b) => a + b) + _selectedDays;
    final random = math.Random(seed);
    
    // Entre -15% et +20%
    double changePercent = (random.nextDouble() * 0.35) - 0.15;
    
    return widget.currentPrice * (1 + changePercent);
  }

  double get _estimatedRevenue {
    final stockText = _stockController.text.trim();
    if (stockText.isEmpty) return 0;
    final stock = double.tryParse(stockText) ?? 0;
    return stock * _predictedPrice;
  }

  String get _aiAdvice {
    final diff = _predictedPrice - widget.currentPrice;
    final percent = (diff / widget.currentPrice).abs() * 100;
    final percentStr = percent.toStringAsFixed(1);
    
    if (diff > 0) {
      return "Le prix de ${widget.productName} sera $percentStr% plus élevé dans $_selectedDays jours. Si vous le pouvez, conservez votre stock pour le vendre au meilleur prix.";
    } else {
      return "Le prix de ${widget.productName} risque de baisser de $percentStr% dans $_selectedDays jours. Il est conseillé d'écouler votre stock rapidement avant la dépréciation.";
    }
  }

  bool _isTyping = false;

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _chatController.clear();
      _isTyping = true;
    });

    try {
      final repository = ref.read(aiRepositoryProvider);
      // On enrichit le contexte de la question avec les infos du produit
      final contextualQuery = "Concernant le produit ${widget.productName} (Prix actuel: ${widget.currentPrice.toInt()} FCFA): $text";
      final responseText = await repository.askQuestion(contextualQuery);
      
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'ia', 'text': responseText});
          _isTyping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'ia', 'text': 'Désolé, je rencontre des difficultés de connexion. Veuillez réessayer.'});
          _isTyping = false;
        });
      }
    }
  }

  String _getImageForProduct(String productName) {
    final nameLower = productName.toLowerCase();
    if (nameLower.contains('oignon')) return 'assets/images/products/oignon.png';
    if (nameLower.contains('tomate')) return 'assets/images/products/tomate.png';
    if (nameLower.contains('mil')) return 'assets/images/products/mil.png';
    if (nameLower.contains('arachide')) return 'assets/images/products/arachide.png';
    if (nameLower.contains('maïs') || nameLower.contains('mais')) return 'assets/images/products/mais.png';
    if (nameLower.contains('riz')) return 'assets/images/products/riz.png';
    if (nameLower.contains('pomme de terre')) return 'assets/images/products/pomme_de_terre.png';
    if (nameLower.contains('pasteque') || nameLower.contains('pastèque')) return 'assets/images/products/pasteque.png';
    if (nameLower.contains('papaye')) return 'assets/images/products/papaye.png';
    if (nameLower.contains('mangue')) return 'assets/images/products/mangue.png';
    if (nameLower.contains('fraise')) return 'assets/images/products/fraise.png';
    if (nameLower.contains('pomme')) return 'assets/images/products/pomme.png';
    return 'assets/images/naatal_agro_logo-removebg-preview.png';
  }

  @override
  Widget build(BuildContext context) {
    final predicted = _predictedPrice;
    final diff = predicted - widget.currentPrice;
    final percent = (diff / widget.currentPrice).abs() * 100;
    final isUp = diff >= 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BANNIÈRE IMAGE
                  Stack(
                    children: [
                      Image.asset(
                        _getImageForProduct(widget.productName),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 220,
                          width: double.infinity,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 8,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: 
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Analyse IA',
                                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      widget.productName,
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('Prix actuel', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                                      Text(
                                        '${widget.currentPrice.toInt()} F',
                                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // Timeframe Selector
                  const Text(
                    'Période de prédiction',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTimeframeButton(7, '7 Jours'),
                      const SizedBox(width: 12),
                      _buildTimeframeButton(15, '15 Jours'),
                      const SizedBox(width: 12),
                      _buildTimeframeButton(30, '1 Mois'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Prediction Result Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUp 
                          ? [Colors.green.shade50, Colors.green.shade100] // Dégradé vert très doux
                          : [Colors.red.shade50, Colors.red.shade100], // Dégradé rouge très doux
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isUp ? Colors.green.shade200 : Colors.red.shade200, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: (isUp ? Colors.green : Colors.red).withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prix estimé (${_selectedDays}j)',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${predicted.toInt()} FCFA',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (isUp ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(isUp ? Icons.trending_up : Icons.trending_down, color: isUp ? Colors.green : Colors.red, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${isUp ? '+' : '-'}${percent.toStringAsFixed(1)}%',
                                    style: TextStyle(color: isUp ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isUp ? Colors.green.shade100 : Colors.red.shade100),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline, color: isUp ? Colors.green.shade700 : Colors.red.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _aiAdvice,
                                  style: TextStyle(color: isUp ? Colors.green.shade900 : Colors.red.shade900, fontSize: 13, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Revenue Estimator - MISE EN VALEUR
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.monetization_on, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Projection des revenus',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Quantité en stock',
                                  suffixText: 'kg',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Colors.green),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Revenu potentiel', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_estimatedRevenue.toInt()} FCFA',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 20),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Discuter avec Naatal IA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  
                  // Chat Messages Area (inside the scroll)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['sender'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isUser ? null : Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            msg['text']!,
                            style: TextStyle(
                              color: isUser ? Colors.white : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_isTyping)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Text('Naatal IA réfléchit...', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
          
          // Chat Input Area (Fixed at bottom)
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: 'Posez une question...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeButton(int days, String label) {
    final isSelected = _selectedDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDays = days;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
