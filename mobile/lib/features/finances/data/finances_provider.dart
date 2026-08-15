import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';
import 'models/financial_summary.dart';

final financialSummaryProvider = FutureProvider.autoDispose<FinancialSummary>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/finances/summary/');
  
  if (response.statusCode == 200) {
    return FinancialSummary.fromJson(response.data);
  } else {
    throw Exception('Failed to load financial summary');
  }
});

class TransactionsNotifier extends StateNotifier<AsyncValue<List<TransactionItem>>> {
  final ApiClient _apiClient;

  TransactionsNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    try {
      state = const AsyncValue.loading();
      final response = await _apiClient.get('/finances/transactions/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        state = AsyncValue.data(data.map((json) => TransactionItem.fromJson(json)).toList());
      } else {
        state = AsyncValue.error('Failed to load transactions', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction(TransactionItem item) async {
    try {
      final response = await _apiClient.post('/finances/transactions/', data: item.toJson());
      if (response.statusCode == 201) {
        fetchTransactions(); // Refresh the list
      }
    } catch (e) {
      rethrow;
    }
  }
}

final transactionsNotifierProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionItem>>>((ref) {
  return TransactionsNotifier(ref.watch(apiClientProvider));
});
