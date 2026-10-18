class AppConstants {
  // Configurable par environnement :
  //   flutter run --dart-define=API_URL=http://10.0.2.2:8000/api   (émulateur Android)
  //   flutter run --dart-define=API_URL=http://192.168.1.77:8000/api (téléphone physique)
  // À défaut, valeur par défaut ci-dessous.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    // defaultValue: 'http://192.168.11.131:8000/api',
    defaultValue: 'http://10.220.6.35:8000/api',
  );

  // Lien de téléchargement de l'app (utilisé dans les messages d'invitation partagés)
  static const String appDownloadUrl = String.fromEnvironment(
    'APP_DOWNLOAD_URL',
    defaultValue: 'https://vtontine.app',
  );

  static const String keycloakUrl = 'http://10.0.2.2:8080';
  static const String keycloakRealm = 'tontine-realm';
  static const String keycloakClientId = 'tontine-client';


  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String tontines = '/tontines';
  static const String tontineDetail = '/tontines/:id';
  static const String createTontine = '/tontines/create';
  static const String gererTontine = '/tontines/:id/gerer';
  static const String cyclesTontine = '/tontines/:id/cycles';
  static const String paiementsHistorique = '/tontines/:id/paiements';
  static const String chatTontine = '/tontines/:id/chat';
  static const String rejoindre = '/rejoindre/:token';
  static const String paiement = '/paiements/:id';
  static const String notifications = '/notifications';
  static const String profil = '/profil';
  static const String profilEdit = '/profil/edit';
  static const String adminDashboard = '/admin';
}