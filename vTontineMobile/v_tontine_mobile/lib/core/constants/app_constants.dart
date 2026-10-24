class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://vtontine.onrender.com/api',
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