import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../auth/data/auth_provider.dart';
import 'models/dashboard_data.dart';

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository(this._apiClient);

  Future<DashboardData> getDashboardData() async {
    final response = await _apiClient.get(AppConstants.dashboardEndpoint);
    
    if (response.statusCode == 200) {
      return DashboardData.fromJson(response.data);
    } else {
      throw Exception('Erreur lors du chargement du dashboard');
    }
  }
}

// Fournit l'instance de DashboardRepository
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardRepository(apiClient);
});

// Récupère les données du dashboard et s'actualise lors du tirage vers le bas (pull-to-refresh)
final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getDashboardData();
});
