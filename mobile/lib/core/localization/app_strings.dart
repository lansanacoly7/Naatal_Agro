class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      // Navigation
      'nav_home': 'Accueil',
      'nav_crops': 'Mes Cultures',
      'nav_markets': 'Marchés',
      'nav_ai': 'Naatal IA',
      'nav_profile': 'Profil',

      // Dashboard
      'greeting_hello': 'Bonjour',
      'greeting_welcome': 'Bienvenue sur Naatal Agro',
      'weather_today': 'Météo du jour',
      'weather_view_details': 'Voir prévisions',
      'market_prices': 'Prix des Marchés',
      'my_crops': 'Mes Parcelles',
      'ai_assistant_card': 'Assistant IA Agricole',
      'ask_ai_btn': 'Poser une question',
      'see_all': 'Voir tout',
      'refresh': 'Actualiser',

      // Weather Screen
      'weather_title': 'Météo & Agro-climat',
      'weather_forecast_5d': 'Prévisions 5 jours',
      'weather_recommendations': 'Recommandations Agricoles',
      'weather_temp': 'Température',
      'weather_humidity': 'Humidité',
      'weather_wind': 'Vent',
      'weather_rain': 'Pluie',

      // Settings
      'language_title': 'Langue',
      'language_fr': 'Français (Sénégal)',
      'language_wo': 'Wolof (Senegaal)',
      'language_saved': 'Langue mise à jour avec succès',

      // Common actions
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'retry': 'Réessayer',
      'loading': 'Chargement...',
    },
    'wo': {
      // Navigation
      'nav_home': 'Kër ga',
      'nav_crops': 'Sama Tool yi',
      'nav_markets': 'Jaar-jaar yi',
      'nav_ai': 'Naatal IA',
      'nav_profile': 'Sa jëmm',

      // Dashboard
      'greeting_hello': 'Nanga def',
      'greeting_welcome': 'Dalal ak jamm ci Naatal Agro',
      'weather_today': 'Asamaan tey',
      'weather_view_details': 'Xool asamaan si',
      'market_prices': 'Njege Marce yi',
      'my_crops': 'Sama Tool yi',
      'ai_assistant_card': 'Ndimbalu IA ci Mbay mi',
      'ask_ai_btn': 'Laajal baatukaay bi',
      'see_all': 'Xool lépp',
      'refresh': 'Yeesal',

      // Weather Screen
      'weather_title': 'Asamaan ak Mbay mi',
      'weather_forecast_5d': 'Asamaan juróomi fan',
      'weather_recommendations': 'Digle yi ci Mbay mi',
      'weather_temp': 'Tàngor',
      'weather_humidity': 'Tooyay',
      'weather_wind': 'Ngélaw',
      'weather_rain': 'Taw',

      // Settings
      'language_title': 'Làkk',
      'language_fr': 'Français (Farañse)',
      'language_wo': 'Wolof',
      'language_saved': 'Làkk bi soppee na ci Wolof',

      // Common actions
      'save': 'Denc ko',
      'cancel': 'Neenal',
      'confirm': 'Dëgëral',
      'retry': 'Jéemât',
      'loading': 'Mu ngi yeb...',
    },
  };

  static String get(String key, {String locale = 'fr'}) {
    final lang = locale.toLowerCase() == 'wo' ? 'wo' : 'fr';
    return _localizedValues[lang]?[key] ?? _localizedValues['fr']?[key] ?? key;
  }
}
