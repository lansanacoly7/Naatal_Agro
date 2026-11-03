import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/location/location_access.dart';
import 'package:nataal_agro/screens/markets/markets_data.dart' show userLocationProvider;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chaque blocage a une phrase et un bouton pour le lever', () {
    for (final access in LocationAccess.values) {
      expect(locationAccessMessage(access), isNotEmpty);
    }
    expect(locationFixLabel(LocationAccess.denied), 'Activer la localisation');
    expect(locationFixLabel(LocationAccess.disabledByUser), 'Activer la localisation');
    expect(locationFixLabel(LocationAccess.deniedForever), 'Ouvrir les réglages');
    expect(locationFixLabel(LocationAccess.serviceOff), 'Ouvrir les réglages');
  });

  test('désactivée dans le profil : aucune demande au système, et on peut la réactiver', () async {
    SharedPreferences.setMockInitialValues({'location_enabled': false});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(locationEnabledProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(locationEnabledProvider), isFalse);

    await container.read(userLocationProvider.notifier).locate();
    final blocked = container.read(userLocationProvider);
    expect(blocked.position, isNull);
    expect(blocked.access, LocationAccess.disabledByUser);
    expect(blocked.needsFix, isTrue);
  });

  test('l\'interrupteur du profil enregistre le choix', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(userLocationProvider.notifier).disable();
    expect(container.read(locationEnabledProvider), isFalse);
    expect((await SharedPreferences.getInstance()).getBool('location_enabled'), isFalse);
    expect(container.read(userLocationProvider).access, LocationAccess.disabledByUser);

    await container.read(locationEnabledProvider.notifier).set(true);
    expect((await SharedPreferences.getInstance()).getBool('location_enabled'), isTrue);
  });
}
