import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/inventory_provider.dart';
import '../../data/models/stock_item.dart';
import '../../../../shared/utils/data_refresh.dart';

class InventoryManagementScreen extends ConsumerWidget {
  const InventoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(inventoryNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestion de Stock', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(inventoryNotifierProvider.notifier).fetchInventory(),
        color: AppColors.primary,
        child: inventoryState.when(
          data: (stocks) {
            if (stocks.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Aucun stock enregistré',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoutez vos récoltes et intrants en stock avec le bouton +.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: stocks.length,
              itemBuilder: (context, index) {
                final stock = stocks[index];
            return _buildStockCard(context, ref, stock);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (error, _) => Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erreur de chargement', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(inventoryNotifierProvider.notifier).fetchInventory(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: () => _showAddStockDialog(context, ref),
    backgroundColor: AppColors.primary,
    child: const Icon(Icons.add, color: Colors.white),
  ),
);
}

Widget _buildStockCard(BuildContext context, WidgetRef ref, StockItem stock) {
return Container(
  margin: const EdgeInsets.only(bottom: 16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                stock.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: stock.alertStatus ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${stock.quantity} ${stock.unit}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: stock.alertStatus ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        if (stock.aiStorageAdvice != null && stock.aiStorageAdvice!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Conseil Naatal IA', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(stock.aiStorageAdvice!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: stock.quantity > 0
                  ? () => _showSaleDialog(context, ref, stock)
                  : null,
              icon: const Icon(Icons.point_of_sale_rounded, size: 16, color: Colors.white),
              label: const Text('Vendre ce stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);
}

void _showSaleDialog(BuildContext context, WidgetRef ref, StockItem stock) {
final quantityController = TextEditingController();
final priceController = TextEditingController();
final buyerController = TextEditingController();
double totalAmount = 0.0;

showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => StatefulBuilder(
    builder: (ctx, setSheetState) {
      void updateTotal() {
        final q = double.tryParse(quantityController.text) ?? 0.0;
        final p = double.tryParse(priceController.text) ?? 0.0;
        setSheetState(() {
          totalAmount = q * p;
        });
      }

      return Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Enregistrer une Vente : ${stock.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Stock disponible : ${stock.quantity} ${stock.unit}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantité vendue (${stock.unit})',
                  hintText: 'Ex: 25.0',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => updateTotal(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Prix unitaire (FCFA / ${stock.unit})',
                  hintText: 'Ex: 400',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => updateTotal(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: buyerController,
                decoration: const InputDecoration(
                  labelText: 'Acheteur / Client (optionnel)',
                  hintText: 'Ex: Marché Tilène, Grossiste...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Recette estimée :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      '${totalAmount.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final qty = double.tryParse(quantityController.text) ?? 0.0;
                    final price = double.tryParse(priceController.text) ?? 0.0;
                    if (qty <= 0 || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez saisir une quantité et un prix valides')),
                      );
                      return;
                    }
                    if (qty > stock.quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Quantité supérieure au stock disponible (${stock.quantity} ${stock.unit})')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(ctx);

                    try {
                      await ref.read(inventoryNotifierProvider.notifier).recordSale(
                        productName: stock.name,
                        quantity: qty,
                        unitPrice: price,
                        buyer: buyerController.text.trim(),
                      );
                      refreshAfterDataChange(ref);
                      nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Vente de $qty ${stock.unit} enregistrée (+${(qty * price).toInt()} FCFA) ! Stock et finances actualisés.'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirmer la vente', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showAddStockDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    String unit = 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ajouter au Stock', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom du produit (ex: Oignon)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownMenu<String>(
                      initialSelection: unit,
                      onSelected: (val) => unit = val ?? 'kg',
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'kg', label: 'kg'),
                        DropdownMenuEntry(value: 'tonnes', label: 'tonnes'),
                        DropdownMenuEntry(value: 'sacs', label: 'sacs'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final quantity = double.tryParse(quantityController.text) ?? 0.0;
                      if (nameController.text.isNotEmpty && quantity > 0) {
                        final newItem = StockItem(
                          id: '',
                          name: nameController.text,
                          quantity: quantity,
                          unit: unit,
                          alertStatus: false,
                          updatedAt: '',
                        );
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        try {
                          await ref.read(inventoryNotifierProvider.notifier).addStock(newItem);
                        } catch (_) {
                          messenger.showSnackBar(const SnackBar(content: Text('Enregistrement impossible. Vérifiez votre connexion.')));
                          return;
                        }
                        refreshAfterDataChange(ref);
                        navigator.pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
