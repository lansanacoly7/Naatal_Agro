import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/network/paginated_response.dart';
import 'package:nataal_agro/features/agriculture/data/models/crop.dart';
import 'package:nataal_agro/features/markets/data/models/market.dart';
import 'package:nataal_agro/core/widgets/notifications_sheet.dart';

void main() {
  group('PaginatedResponse - Décodage des deux formats API', () {
    test('décode le format liste brute historique ([...])', () {
      final rawList = [
        {
          'id': '1',
          'name': 'Mil',
          'crop_type': 'cereale',
          'planting_date': '2026-06-01',
          'expected_harvest_date': '2026-09-30',
          'status': 'active',
          'area_size': '2.5',
          'location': 'Kaolack',
        },
        {
          'id': '2',
          'name': 'Arachide',
          'crop_type': 'legumineuse',
          'planting_date': '2026-07-01',
          'expected_harvest_date': '2026-10-31',
          'status': 'active',
          'area_size': '4.0',
          'location': 'Fatick',
        },
      ];

      final response = PaginatedResponse<Crop>.fromData(
        rawList,
        Crop.fromJson,
      );

      expect(response.count, 2);
      expect(response.hasMore, isFalse);
      expect(response.next, isNull);
      expect(response.previous, isNull);
      expect(response.results.length, 2);
      expect(response.results.first.name, 'Mil');
      expect(response.results.first.areaSize, 2.5);
      expect(response.results.last.name, 'Arachide');
    });

    test('décode le format paginé DRF ({"count", "next", "previous", "results"}) pour les cultures', () {
      final paginatedPayload = {
        'count': 45,
        'next': 'http://127.0.0.1:8000/api/agriculture/crops/?page=2&page_size=20',
        'previous': null,
        'results': [
          {
            'id': '10',
            'name': 'Tomate',
            'crop_type': 'legume',
            'planting_date': '2026-01-10',
            'expected_harvest_date': '2026-04-10',
            'status': 'active',
            'area_size': 1.2,
            'location': 'Niayes',
          },
          {
            'id': '11',
            'name': 'Oignon',
            'crop_type': 'legume',
            'planting_date': '2026-02-01',
            'expected_harvest_date': '2026-05-15',
            'status': 'active',
            'area_size': 3.0,
            'location': 'Podor',
          },
        ],
      };

      final response = PaginatedResponse<Crop>.fromData(
        paginatedPayload,
        Crop.fromJson,
      );

      expect(response.count, 45);
      expect(response.hasMore, isTrue);
      expect(response.next, contains('page=2'));
      expect(response.previous, isNull);
      expect(response.results.length, 2);
      expect(response.results.first.name, 'Tomate');
    });

    test('décode les marchés au format liste brute et au format paginé DRF', () {
      // 1. Liste brute
      final rawMarkets = [
        {
          'id': 'm1',
          'name': 'Marché Castors',
          'region': 'Dakar',
          'location_gps': '14.7167,-17.4677',
        },
      ];
      final respRaw = PaginatedResponse<Market>.fromData(rawMarkets, Market.fromJson);
      expect(respRaw.count, 1);
      expect(respRaw.hasMore, isFalse);
      expect(respRaw.results.first.name, 'Marché Castors');
      expect(respRaw.results.first.latLng?.latitude, closeTo(14.7167, 0.001));

      // 2. DRF Paginé
      final drfMarkets = {
        'count': 15,
        'next': 'http://127.0.0.1:8000/api/markets/?page=2',
        'previous': null,
        'results': [
          {
            'id': 'm2',
            'name': 'Marché Tilène',
            'region': 'Dakar',
            'location_gps': '14.6850,-17.4520',
          },
        ],
      };
      final respDrf = PaginatedResponse<Market>.fromData(drfMarkets, Market.fromJson);
      expect(respDrf.count, 15);
      expect(respDrf.hasMore, isTrue);
      expect(respDrf.results.first.name, 'Marché Tilène');
    });

    test('décode les notifications au format liste brute et au format paginé DRF', () {
      // 1. Liste brute
      final rawNotifs = [
        {
          'id': 'n1',
          'type': 'alert',
          'message': 'Pluie attendue demain',
          'is_read': false,
          'created_at': '2026-10-05T10:00:00Z',
        },
      ];
      final respRaw = PaginatedResponse<AppNotification>.fromData(rawNotifs, AppNotification.fromJson);
      expect(respRaw.count, 1);
      expect(respRaw.hasMore, isFalse);
      expect(respRaw.results.first.message, 'Pluie attendue demain');
      expect(respRaw.results.first.isRead, isFalse);

      // 2. DRF Paginé
      final drfNotifs = {
        'count': 50,
        'next': 'http://127.0.0.1:8000/api/notifications/?page=2',
        'previous': null,
        'results': [
          {
            'id': 'n2',
            'type': 'market',
            'message': 'Hausse du prix de l\'oignon',
            'is_read': true,
            'created_at': '2026-10-05T12:00:00Z',
          },
        ],
      };
      final respDrf = PaginatedResponse<AppNotification>.fromData(drfNotifs, AppNotification.fromJson);
      expect(respDrf.count, 50);
      expect(respDrf.hasMore, isTrue);
      expect(respDrf.results.first.message, contains('oignon'));
      expect(respDrf.results.first.isRead, isTrue);
    });

    test('gère le cas où la dernière page n\'a plus de page suivante (next: null)', () {
      final lastPagePayload = {
        'count': 22,
        'next': null,
        'previous': 'http://127.0.0.1:8000/api/agriculture/crops/?page=1',
        'results': [
          {
            'id': '21',
            'name': 'Mangue',
            'crop_type': 'fruit',
            'planting_date': '2025-01-01',
            'expected_harvest_date': '2026-06-01',
            'status': 'active',
            'area_size': 5.0,
            'location': 'Casamance',
          },
        ],
      };

      final response = PaginatedResponse<Crop>.fromData(
        lastPagePayload,
        Crop.fromJson,
      );

      expect(response.count, 22);
      expect(response.hasMore, isFalse);
      expect(response.next, isNull);
      expect(response.previous, contains('page=1'));
      expect(response.results.length, 1);
    });

    test('gère les réponses vides ou payloads inattendus sans planter', () {
      final emptyListResponse = PaginatedResponse<Crop>.fromData([], Crop.fromJson);
      expect(emptyListResponse.count, 0);
      expect(emptyListResponse.results, isEmpty);
      expect(emptyListResponse.hasMore, isFalse);

      final emptyMapResponse = PaginatedResponse<Crop>.fromData(
        {'count': 0, 'next': null, 'previous': null, 'results': []},
        Crop.fromJson,
      );
      expect(emptyMapResponse.count, 0);
      expect(emptyMapResponse.results, isEmpty);
      expect(emptyMapResponse.hasMore, isFalse);

      final nullPayloadResponse = PaginatedResponse<Crop>.fromData(null, Crop.fromJson);
      expect(nullPayloadResponse.count, 0);
      expect(nullPayloadResponse.results, isEmpty);
      expect(nullPayloadResponse.hasMore, isFalse);
    });

    test('PaginatedState gère correctement les transitions d\'état et les ajouts de pages', () {
      var state = const PaginatedState<String>();
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.hasMore, isFalse);

      // Chargement initial
      state = state.copyWith(isLoading: true);
      expect(state.isLoading, isTrue);

      // Succès page 1
      state = state.copyWith(
        items: ['item1', 'item2'],
        isLoading: false,
        currentPage: 1,
        hasMore: true,
      );
      expect(state.items.length, 2);
      expect(state.hasMore, isTrue);
      expect(state.currentPage, 1);

      // Chargement page 2 (load more)
      state = state.copyWith(isLoadingMore: true);
      expect(state.isLoadingMore, isTrue);

      // Arrivée page 2
      state = state.copyWith(
        items: [...state.items, 'item3', 'item4'],
        isLoadingMore: false,
        currentPage: 2,
        hasMore: false,
      );
      expect(state.items.length, 4);
      expect(state.hasMore, isFalse);
      expect(state.currentPage, 2);
    });
  });
}
