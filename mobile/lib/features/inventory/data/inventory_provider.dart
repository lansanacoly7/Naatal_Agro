import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';
import 'models/stock_item.dart';

final inventoryProvider = FutureProvider.autoDispose<List<StockItem>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/inventory/');
  
  if (response.statusCode == 200) {
    final List<dynamic> data = response.data;
    return data.map((json) => StockItem.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load inventory');
  }
});

class InventoryNotifier extends StateNotifier<AsyncValue<List<StockItem>>> {
  final ApiClient _apiClient;

  InventoryNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    fetchInventory();
  }

  Future<void> fetchInventory() async {
    try {
      state = const AsyncValue.loading();
      final response = await _apiClient.get('/inventory/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        state = AsyncValue.data(data.map((json) => StockItem.fromJson(json)).toList());
      } else {
        state = AsyncValue.error('Failed to load inventory', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addStock(StockItem item) async {
    try {
      final response = await _apiClient.post('/inventory/', data: item.toJson());
      if (response.statusCode == 201) {
        await fetchInventory(); // Refresh the list
      }
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  Future<void> recordSale({
    required String productName,
    required double quantity,
    required double unitPrice,
    String? saleDate,
    String? buyer,
  }) async {
    final formattedDate = saleDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final response = await _apiClient.post(
      '/finances/sales/',
      data: {
        'product_name': productName,
        'quantity': quantity,
        'quantity_sold': quantity,
        'unit_price': unitPrice,
        'price_per_unit': unitPrice,
        'date': formattedDate,
        'sale_date': formattedDate,
        if (buyer != null && buyer.isNotEmpty) 'buyer': buyer,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
      await fetchInventory();
    } else {
      throw Exception('Erreur lors de l\'enregistrement de la vente');
    }
  }
}

final inventoryNotifierProvider = StateNotifierProvider<InventoryNotifier, AsyncValue<List<StockItem>>>((ref) {
  return InventoryNotifier(ref.watch(apiClientProvider));
});
