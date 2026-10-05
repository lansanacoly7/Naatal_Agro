import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/constants/app_constants.dart';
import '../../auth/data/auth_provider.dart';
import 'models/crop.dart';

class AgricultureRepository {
  final ApiClient _apiClient;

  AgricultureRepository(this._apiClient);

  /// Récupère les cultures paginées en supportant le format DRF ({count, next, results})
  /// ainsi que le format liste historique ([...]).
  Future<PaginatedResponse<Crop>> getCropsPaginated({int? page, int? pageSize}) async {
    final Map<String, dynamic> queryParams = {};
    if (page != null) queryParams['page'] = page;
    if (pageSize != null) queryParams['page_size'] = pageSize;

    final response = await _apiClient.get(
      AppConstants.cropsEndpoint,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response.statusCode == 200) {
      return PaginatedResponse<Crop>.fromData(
        response.data,
        (json) => Crop.fromJson(json),
      );
    } else {
      throw Exception('Erreur lors du chargement des cultures (${response.statusCode})');
    }
  }

  Future<List<Crop>> getCrops() async {
    final paginated = await getCropsPaginated();
    return paginated.results;
  }

  Future<void> addCrop(Map<String, dynamic> cropData) async {
    final response = await _apiClient.post(
      AppConstants.cropsEndpoint,
      data: cropData,
    );
    
    if (response.statusCode != 201) {
      throw Exception('Erreur lors de l\'ajout de la culture');
    }
  }

  Future<void> updateCrop(String cropId, Map<String, dynamic> cropData) async {
    final response = await _apiClient.patch(
      '${AppConstants.cropsEndpoint}$cropId/',
      data: cropData,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la mise à jour de la culture');
    }
  }

  Future<void> deleteCrop(String cropId) async {
    final response = await _apiClient.delete(
      '${AppConstants.cropsEndpoint}$cropId/',
    );
    
    if (response.statusCode != 204) {
      throw Exception('Erreur lors de la suppression de la culture');
    }
  }
}

// Fournit l'instance de AgricultureRepository
final agricultureRepositoryProvider = Provider<AgricultureRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AgricultureRepository(apiClient);
});

/// Notifier gérant la pagination des cultures avec chargement progressif
class CropsPaginationNotifier extends StateNotifier<PaginatedState<Crop>> {
  final AgricultureRepository _repository;

  CropsPaginationNotifier(this._repository) : super(const PaginatedState<Crop>()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.getCropsPaginated(page: 1, pageSize: 20);
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
      final response = await _repository.getCropsPaginated(page: nextPage, pageSize: 20);
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

final cropsPaginationNotifierProvider =
    StateNotifierProvider.autoDispose<CropsPaginationNotifier, PaginatedState<Crop>>((ref) {
  final repo = ref.watch(agricultureRepositoryProvider);
  return CropsPaginationNotifier(repo);
});

// Récupère la liste des cultures (rétro-compatible)
final cropsProvider = FutureProvider.autoDispose<List<Crop>>((ref) async {
  final repository = ref.watch(agricultureRepositoryProvider);
  return repository.getCrops();
});

