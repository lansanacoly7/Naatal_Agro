import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/cache/local_cache.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../main.dart';
import '../../auth/data/auth_provider.dart';
import 'models/agronomic_guide.dart';

class GuidesListState {
  final List<AgronomicGuide> guides;
  final bool isLoading;
  final String? error;
  final bool isFromCache;
  final DateTime? cachedAt;

  const GuidesListState({
    this.guides = const [],
    this.isLoading = false,
    this.error,
    this.isFromCache = false,
    this.cachedAt,
  });

  GuidesListState copyWith({
    List<AgronomicGuide>? guides,
    bool? isLoading,
    String? error,
    bool? isFromCache,
    DateTime? cachedAt,
  }) {
    return GuidesListState(
      guides: guides ?? this.guides,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isFromCache: isFromCache ?? this.isFromCache,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

class GuidesNotifier extends StateNotifier<GuidesListState> {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  GuidesNotifier(this._apiClient, this._prefs) : super(const GuidesListState(isLoading: true)) {
    loadGuides();
  }

  Future<void> loadGuides({String? category, String? search}) async {
    state = state.copyWith(isLoading: true, error: null);

    final queryParams = <String, dynamic>{};
    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final cacheKey = 'guides_${category ?? 'all'}_${search ?? ''}';

    try {
      final response = await _apiClient.get(
        AppConstants.agronomicGuidesEndpoint,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawList;
        if (response.data is List) {
          rawList = response.data as List<dynamic>;
        } else if (response.data is Map && response.data['results'] is List) {
          rawList = response.data['results'] as List<dynamic>;
        } else {
          rawList = [];
        }

        final guides = rawList
            .whereType<Map<String, dynamic>>()
            .map(AgronomicGuide.fromJson)
            .toList();

        // Enregistrement dans le cache local
        final userId = await _apiClient.getUserId();
        final cache = LocalCache(_prefs, userId);
        await cache.write(cacheKey, {'results': rawList});

        state = GuidesListState(
          guides: guides,
          isLoading: false,
          isFromCache: false,
          cachedAt: DateTime.now(),
        );
        return;
      }
    } catch (e) {
      // En cas de panne réseau : secours via le cache local
      final isNetworkError = e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout);

      if (isNetworkError) {
        final userId = await _apiClient.getUserId();
        final cache = LocalCache(_prefs, userId);
        final cached = await cache.read(cacheKey);
        if (cached != null) {
          final results = (cached.data['results'] as List<dynamic>?) ?? [];
          final guides = results
              .whereType<Map<String, dynamic>>()
              .map(AgronomicGuide.fromJson)
              .toList();

          state = GuidesListState(
            guides: guides,
            isLoading: false,
            isFromCache: true,
            cachedAt: cached.cachedAt,
          );
          return;
        }
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger les fiches agronomiques.',
      );
    }
  }
}

final guidesNotifierProvider = StateNotifierProvider.autoDispose<GuidesNotifier, GuidesListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return GuidesNotifier(apiClient, prefs);
});

class GuideDetailState {
  final AgronomicGuide? guide;
  final bool isLoading;
  final String? error;
  final bool isFromCache;
  final DateTime? cachedAt;

  const GuideDetailState({
    this.guide,
    this.isLoading = false,
    this.error,
    this.isFromCache = false,
    this.cachedAt,
  });
}

class GuideDetailNotifier extends StateNotifier<GuideDetailState> {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
  final String _slug;

  GuideDetailNotifier(this._apiClient, this._prefs, this._slug)
      : super(const GuideDetailState(isLoading: true)) {
    loadGuide();
  }

  Future<void> loadGuide() async {
    state = const GuideDetailState(isLoading: true);
    final cacheKey = 'guide_detail_$_slug';

    try {
      final response = await _apiClient.get('${AppConstants.agronomicGuidesEndpoint}$_slug/');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final guide = AgronomicGuide.fromJson(data);

        final userId = await _apiClient.getUserId();
        final cache = LocalCache(_prefs, userId);
        await cache.write(cacheKey, data);

        state = GuideDetailState(
          guide: guide,
          isLoading: false,
          isFromCache: false,
          cachedAt: DateTime.now(),
        );
        return;
      }
    } catch (e) {
      final isNetworkError = e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout);

      if (isNetworkError) {
        final userId = await _apiClient.getUserId();
        final cache = LocalCache(_prefs, userId);
        final cached = await cache.read(cacheKey);
        if (cached != null) {
          final guide = AgronomicGuide.fromJson(cached.data);
          state = GuideDetailState(
            guide: guide,
            isLoading: false,
            isFromCache: true,
            cachedAt: cached.cachedAt,
          );
          return;
        }
      }

      state = const GuideDetailState(
        isLoading: false,
        error: 'Impossible de charger le détail de cette fiche agronomique.',
      );
    }
  }
}

final guideDetailProvider = StateNotifierProvider.autoDispose.family<GuideDetailNotifier, GuideDetailState, String>(
  (ref, slug) {
    final apiClient = ref.watch(apiClientProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    return GuideDetailNotifier(apiClient, prefs, slug);
  },
);
