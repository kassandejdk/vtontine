import 'package:dio/dio.dart';

/// Extrait un message lisible d'une erreur d'API : le champ `error` (ou
/// `detail`) renvoyé par le backend Django, sinon un message générique.
///
/// Utile car [ApiClient] relance les [DioException] brutes, dont le
/// `toString()` est technique et peu compréhensible pour l'utilisateur.
String messageErreur(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final m = data['error'] ?? data['detail'];
      if (m is String && m.trim().isNotEmpty) return m;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return 'Connexion au serveur impossible.';
      default:
        break;
    }
  }
  return 'Une erreur est survenue.';
}
