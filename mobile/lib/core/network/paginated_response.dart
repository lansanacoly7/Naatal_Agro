/// Modèle universel de pagination compatible avec :
/// 1. Le format paginé Django REST Framework : `{"count": 42, "next": "...", "previous": null, "results": [...]}`
/// 2. Le format liste brute historique : `[...]`
class PaginatedResponse<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  PaginatedResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  bool get hasMore => next != null && next!.isNotEmpty;

  /// Fabrique un `PaginatedResponse` à partir de n'importe quel payload API (List ou Map)
  factory PaginatedResponse.fromData(
    dynamic data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (data is List) {
      final items = <T>[];
      for (final element in data) {
        if (element is Map<String, dynamic>) {
          items.add(fromJson(element));
        } else if (element is Map) {
          items.add(fromJson(Map<String, dynamic>.from(element)));
        }
      }
      return PaginatedResponse(
        count: items.length,
        next: null,
        previous: null,
        results: items,
      );
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final rawResults = map['results'];
      final items = <T>[];

      if (rawResults is List) {
        for (final element in rawResults) {
          if (element is Map<String, dynamic>) {
            items.add(fromJson(element));
          } else if (element is Map) {
            items.add(fromJson(Map<String, dynamic>.from(element)));
          }
        }
      }

      final countVal = map['count'];
      final parsedCount = (countVal is num) ? countVal.toInt() : items.length;

      return PaginatedResponse(
        count: parsedCount,
        next: map['next'] as String?,
        previous: map['previous'] as String?,
        results: items,
      );
    }

    return PaginatedResponse(
      count: 0,
      next: null,
      previous: null,
      results: const [],
    );
  }
}

/// État réactif pour la gestion des listes paginées dans les StateNotifiers
class PaginatedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;

  const PaginatedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = false,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? currentPage,
    bool? hasMore,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

