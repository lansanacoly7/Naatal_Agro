import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/auth/data/auth_repository.dart';

void main() {
  group('Message d\'erreur d\'inscription', () {
    test('mot de passe refusé : le vrai motif est affiché, pas « numéro déjà utilisé »', () {
      final message = registrationErrorMessage({
        'password': ['Ce mot de passe est trop courant.', 'Ce mot de passe est entièrement numérique.'],
      });
      expect(message, contains('trop courant'));
      expect(message, isNot(contains('numéro')));
    });

    test('numéro déjà associé à un compte', () {
      expect(
        registrationErrorMessage({'phone_number': ['Ce numéro de téléphone est déjà associé à un compte.']}),
        'Ce numéro de téléphone est déjà associé à un compte.',
      );
    });

    test('plusieurs champs en erreur : le numéro passe en premier', () {
      final message = registrationErrorMessage({
        'password': ['Ce mot de passe est trop court.'],
        'phone_number': ['Numéro invalide. Format attendu : +221771234567 (indicatif pays inclus).'],
      });
      expect(message, startsWith('Numéro invalide'));
    });

    test('date de naissance et e-mail sont nommés', () {
      expect(registrationErrorMessage({'date_of_birth': ['Mauvais format.']}), 'Date de naissance : Mauvais format.');
      expect(registrationErrorMessage({'email': ['Saisissez une adresse e-mail valide.']}), startsWith('E-mail : '));
    });

    test('champ inconnu : son message est quand même montré', () {
      expect(registrationErrorMessage({'autre': ['Valeur interdite.']}), 'Valeur interdite.');
    });

    test('réponse inexploitable : message neutre', () {
      expect(registrationErrorMessage(null), contains('Inscription impossible'));
      expect(registrationErrorMessage('<html>erreur</html>'), contains('Inscription impossible'));
    });
  });
}
