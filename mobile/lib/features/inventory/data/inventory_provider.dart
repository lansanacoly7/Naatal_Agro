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
        fetchInventory(); // Refresh the list
      }
    } catch (e) {
      // Handle error
      rethrow;
    }
  }
}

final inventoryNotifierProvider = StateNotifierProvider<InventoryNotifier, AsyncValue<List<StockItem>>>((ref) {
  return InventoryNotifier(ref.watch(apiClientProvider));
});
