import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../auth/data/auth_provider.dart';
import 'models/crop.dart';

class AgricultureRepository {
  final ApiClient _apiClient;

  AgricultureRepository(this._apiClient);

  Future<List<Crop>> getCrops() async {
    final response = await _apiClient.get(AppConstants.cropsEndpoint);
    
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((json) => Crop.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors du chargement des cultures');
    }
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
}

// Fournit l'instance de AgricultureRepository
final agricultureRepositoryProvider = Provider<AgricultureRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AgricultureRepository(apiClient);
});

// Récupère la liste des cultures
final cropsProvider = FutureProvider.autoDispose<List<Crop>>((ref) async {
  final repository = ref.watch(agricultureRepositoryProvider);
  return repository.getCrops();
});
