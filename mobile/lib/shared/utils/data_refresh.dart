import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/dashboard/data/dashboard_provider.dart';
import '../../features/finances/data/finances_provider.dart';
import '../../features/inventory/data/inventory_provider.dart';
import '../../features/profile/data/profile_provider.dart';

/// À appeler après toute création, modification ou suppression de données de l'exploitation
/// (culture, stock, transaction, profil…) : toutes les pages qui affichent ces données sont
/// rechargées depuis le serveur, pour qu'aucun écran ne garde une valeur périmée.
void refreshAfterDataChange(WidgetRef ref) {
  ref.invalidate(dashboardDataProvider);
  ref.invalidate(cropsProvider);
  ref.invalidate(cropsPaginationNotifierProvider);
  ref.invalidate(inventoryProvider);
  ref.invalidate(inventoryNotifierProvider);
  ref.invalidate(financialSummaryProvider);
  ref.invalidate(transactionsNotifierProvider);
  // Le profil porte aussi le nombre de cultures
  ref.invalidate(profileNotifierProvider);
}
