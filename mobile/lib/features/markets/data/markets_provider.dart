import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/market.dart';
import 'models/price.dart';
import 'models/product.dart';

class MarketsRepository {
  final ApiClient _apiClient;

  MarketsRepository(this._apiClient);

  Future<List<Product>> getProducts({String? category, bool? isTrending, String? search}) async {
    final Map<String, dynamic> queryParams = {};
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (isTrending != null) {
      queryParams['is_trending'] = isTrending.toString();
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      '/markets/products/',
      queryParams: queryParams,
    );
    
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((json) => Product.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors du chargement des produits');
    }
  }

  Future<List<Market>> getMarkets() async {
    final response = await _apiClient.get(AppConstants.marketsEndpoint);
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((json) => Market.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors du chargement des marchés');
    }
  }

  Future<List<Price>> getPrices() async {
    final response = await _apiClient.get(AppConstants.pricesEndpoint);
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((json) => Price.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors du chargement des prix');
    }
  }
}

// Provider pour le repository
final marketsRepositoryProvider = Provider<MarketsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MarketsRepository(apiClient);
});

// FutureProvider pour la liste des marchés
final marketsListProvider = FutureProvider.autoDispose<List<Market>>((ref) async {
  final repository = ref.watch(marketsRepositoryProvider);
  return repository.getMarkets();
});

// FutureProvider pour la liste de tous les prix
final pricesListProvider = FutureProvider.autoDispose<List<Price>>((ref) async {
  final repository = ref.watch(marketsRepositoryProvider);
  return repository.getPrices();
});

// FutureProvider pour les tendances du jour
final trendingProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final repository = ref.watch(marketsRepositoryProvider);
  return repository.getProducts(isTrending: true);
});

// Class and Provider pour la recherche/filtre de produits
class ProductFilter {
  final String category;
  final String search;

  ProductFilter({this.category = 'Tout', this.search = ''});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductFilter &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          search == other.search;

  @override
  int get hashCode => category.hashCode ^ search.hashCode;
}

final productFilterProvider = StateProvider<ProductFilter>((ref) => ProductFilter());

final filteredProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final filter = ref.watch(productFilterProvider);
  final repository = ref.watch(marketsRepositoryProvider);
  return repository.getProducts(
    category: filter.category == 'Tout' ? null : filter.category,
    search: filter.search.isEmpty ? null : filter.search,
  );
});

class PreSaleOffersNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final ApiClient _apiClient;

  PreSaleOffersNotifier(this._apiClient) : super(const AsyncValue.loading());

  Future<void> fetchOffers() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get('/markets/b2b-offers/');
      if (response.statusCode == 200) {
        state = AsyncValue.data(List<Map<String, dynamic>>.from(response.data));
      } else {
        state = AsyncValue.error('Erreur de chargement', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reserveOffer(int offerId, double quantity) async {
    try {
      final response = await _apiClient.post(
        '/markets/b2b-offers/$offerId/reserve/',
        data: {'quantity_reserved': quantity},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchOffers(); // Refresh the list
      }
    } catch (e) {
      rethrow;
    }
  }
}

final preSaleOffersProvider = StateNotifierProvider<PreSaleOffersNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PreSaleOffersNotifier(apiClient);
});
