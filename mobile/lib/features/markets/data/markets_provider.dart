import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
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
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    
    if (response.statusCode == 200) {
      return PaginatedResponse<Product>.fromData(
        response.data,
        (json) => Product.fromJson(json),
      ).results;
    } else {
      throw Exception('Erreur lors du chargement des produits (${response.statusCode})');
    }
  }

  /// Récupère les marchés avec pagination DRF ({count, next, results}) ou liste brute ([...])
  Future<PaginatedResponse<Market>> getMarketsPaginated({int? page, int? pageSize}) async {
    final Map<String, dynamic> queryParams = {};
    if (page != null) queryParams['page'] = page;
    if (pageSize != null) queryParams['page_size'] = pageSize;

    final response = await _apiClient.get(
      AppConstants.marketsEndpoint,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    if (response.statusCode == 200) {
      return PaginatedResponse<Market>.fromData(
        response.data,
        (json) => Market.fromJson(json),
      );
    } else {
      throw Exception('Erreur lors du chargement des marchés (${response.statusCode})');
    }
  }

  Future<List<Market>> getMarkets() async {
    final paginated = await getMarketsPaginated();
    return paginated.results;
  }

  Future<List<Price>> getPrices() async {
    final response = await _apiClient.get(AppConstants.pricesEndpoint);
    if (response.statusCode == 200) {
      return PaginatedResponse<Price>.fromData(
        response.data,
        (json) => Price.fromJson(json),
      ).results;
    } else {
      throw Exception('Erreur lors du chargement des prix (${response.statusCode})');
    }
  }
}

// Provider pour le repository
final marketsRepositoryProvider = Provider<MarketsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MarketsRepository(apiClient);
});

// FutureProvider pour la liste des marchés (rétro-compatible)
final marketsListProvider = FutureProvider.autoDispose<List<Market>>((ref) async {
  final repository = ref.watch(marketsRepositoryProvider);
  return repository.getMarkets();
});

/// Notifier gérant la pagination des marchés avec chargement progressif ("charger plus")
class MarketsPaginationNotifier extends StateNotifier<PaginatedState<Market>> {
  final MarketsRepository _repository;

  MarketsPaginationNotifier(this._repository) : super(const PaginatedState<Market>()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.getMarketsPaginated(page: 1, pageSize: 20);
      state = state.copyWith(
        items: response.results,
        isLoading: false,
        currentPage: 1,
        hasMore: response.hasMore,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getMarketsPaginated(page: nextPage, pageSize: 20);
      state = state.copyWith(
        items: [...state.items, ...response.results],
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: response.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final marketsPaginationNotifierProvider =
    StateNotifierProvider.autoDispose<MarketsPaginationNotifier, PaginatedState<Market>>((ref) {
  final repo = ref.watch(marketsRepositoryProvider);
  return MarketsPaginationNotifier(repo);
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

// Tous les produits de l'application (sans filtre) pour le sélecteur de la carte
final allProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final repository = ref.watch(marketsRepositoryProvider);
  return repository.getProducts();
});
