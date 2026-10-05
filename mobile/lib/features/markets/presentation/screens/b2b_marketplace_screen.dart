import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/markets_provider.dart';

class B2BMarketplaceScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const B2BMarketplaceScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<B2BMarketplaceScreen> createState() => _B2BMarketplaceScreenState();
}

class _B2BMarketplaceScreenState extends ConsumerState<B2BMarketplaceScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(preSaleOffersProvider.notifier).fetchOffers();
    });
  }

  String _getImageForCrop(String cropName) {
    final lower = cropName.toLowerCase();
    if (lower.contains('tomate')) return 'assets/images/products/tomate.png';
    if (lower.contains('arachide')) return 'assets/images/products/arachide.png';
    if (lower.contains('mil')) return 'assets/images/products/mil.png';
    if (lower.contains('oignon')) return 'assets/images/products/oignon.png';
    if (lower.contains('riz')) return 'assets/images/products/riz.jpg';
    if (lower.contains('pomme')) return 'assets/images/products/pomme.jpg';
    if (lower.contains('mais') || lower.contains('maïs')) return 'assets/images/products/mais.jpg';
    if (lower.contains('fraise')) return 'assets/images/products/fraise.jpg';
    return 'assets/images/products/tomate.png'; // default
  }

  @override
  Widget build(BuildContext context) {
    final offersState = ref.watch(preSaleOffersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('Bourse B2B', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Container(
        // Subtle mesh gradient background for premium feel
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.03),
              Colors.transparent,
            ],
            center: const Alignment(0.8, -0.6),
            radius: 1.5,
          ),
        ),
        child: offersState.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : offersState.hasError
                ? Center(child: Text('Erreur: ${offersState.error}'))
                : offersState.value == null || offersState.value!.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16.0, 
                          right: 16.0, 
                          top: widget.isEmbedded ? 100.0 : 16.0, // leave space for segmented control if embedded
                          bottom: 100.0
                        ),
                        itemCount: offersState.value!.length,
                        itemBuilder: (context, index) {
                          final offer = offersState.value![index];
                          return _buildPremiumOfferCard(offer);
                        },
                      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text('Aucune offre disponible', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Les nouvelles offres B2B apparaitront ici.', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildPremiumOfferCard(Map<String, dynamic> offer) {
    final bool isOpen = offer['status'] == 'open';
    final cropName = offer['crop']?['name'] ?? 'Culture inconnue';
    final imageAsset = _getImageForCrop(cropName);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                child: Image.asset(
                  imageAsset,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.green.withValues(alpha: 0.8) : Colors.orange.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isOpen ? Icons.check_circle_rounded : Icons.pending_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            isOpen ? 'Disponible' : 'Réservé',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cropName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 12, color: AppColors.primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ferme: ${offer['farmer']?['name'] ?? 'Inconnu'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Stats Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(Icons.scale_rounded, 'Quantité', '${offer['quantity_kg']} kg'),
                      ),
                      Container(width: 1, height: 30, color: Colors.grey.shade300),
                      Expanded(
                        child: _buildDetailItem(Icons.payments_rounded, 'Prix unitaire', '${offer['unit_price']} F/kg'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.event_available_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      'Récolte prévue le ${offer['expected_harvest_date'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                
                if (isOpen) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _showPremiumReservationDialog(offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_checkout_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Réserver cette offre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 18),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
      ],
    );
  }

  void _showPremiumReservationDialog(Map<String, dynamic> offer) {
    final quantityController = TextEditingController();
    final cropName = offer['crop']?['name'] ?? 'Culture';
    final imageAsset = _getImageForCrop(cropName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: Image.asset(
                        imageAsset,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          height: 5,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.7)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 24,
                      right: 24,
                      child: Text(
                        'Réserver $cropName',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quantité disponible', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('${offer['quantity_kg']} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Prix unitaire', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('${offer['unit_price']} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Quantité souhaitée (kg)',
                          labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.scale_rounded, color: AppColors.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Text('Annuler', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final qty = double.tryParse(quantityController.text);
                                if (qty != null && qty > 0 && qty <= double.parse(offer['quantity_kg'].toString())) {
                                  final messenger = ScaffoldMessenger.of(context);
                                  Navigator.pop(context); // Close bottom sheet
                                  await ref.read(preSaleOffersProvider.notifier).reserveOffer(offer['id'].toString(), qty);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: const [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text('Réservation confirmée avec succès !'),
                                          ],
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      )
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Veuillez entrer une quantité valide'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
