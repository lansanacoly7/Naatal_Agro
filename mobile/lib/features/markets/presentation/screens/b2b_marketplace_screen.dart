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
      body: offersState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : offersState.hasError
              ? Center(child: Text('Erreur: ${offersState.error}'))
              : offersState.value == null || offersState.value!.isEmpty
                  ? const Center(child: Text('Aucune offre disponible pour le moment.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
                      itemCount: offersState.value!.length,
                      itemBuilder: (context, index) {
                        final offer = offersState.value![index];
                        return _buildOfferCard(offer);
                      },
                    ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final bool isOpen = offer['status'] == 'open';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer['crop']?['name'] ?? 'Culture inconnue',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ferme: ${offer['farmer']?['name'] ?? 'Inconnu'}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(isOpen ? Icons.check_circle_rounded : Icons.pending_rounded, size: 14, color: isOpen ? Colors.green : Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? 'Disponible' : 'Réservé',
                        style: TextStyle(
                          color: isOpen ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(Icons.scale_rounded, 'Quantité', '${offer['quantity_kg']} kg'),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    Expanded(
                      child: _buildDetailItem(Icons.payments_rounded, 'Prix', '${offer['unit_price']} FCFA/kg'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      'Récolte prévue: ${offer['expected_harvest_date'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (isOpen) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _showReservationDialog(offer),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white),
                      label: const Text('Réserver cette offre', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        Icon(icon, color: Colors.grey.shade400, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
      ],
    );
  }

  void _showReservationDialog(Map<String, dynamic> offer) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Réserver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quantité disponible: ${offer['quantity_kg']} kg'),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité souhaitée (kg)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(quantityController.text);
                if (qty != null && qty > 0 && qty <= double.parse(offer['quantity_kg'].toString())) {
                  Navigator.pop(context);
                  await ref.read(preSaleOffersProvider.notifier).reserveOffer(offer['id'], qty);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation effectuée')));
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }
}
