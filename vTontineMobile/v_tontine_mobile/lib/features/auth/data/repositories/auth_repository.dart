import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  /// Connexion — retourne l'utilisateur connecté
  Future<UserModel> login(String telephone, String password) async {
    final response = await _api.post('/auth/login/', data: {
      'telephone': telephone,
      'password': password,
    });

    // Sauvegarder les tokens de façon sécurisée
    await _storage.write(
      key: AppConstants.accessTokenKey,
      value: response.data['access_token'],
    );
    await _storage.write(
      key: AppConstants.refreshTokenKey,
      value: response.data['refresh_token'],
    );

    // Récupérer les infos de l'utilisateur
    final meResponse = await _api.get('/auth/me/');
    final user = UserModel.fromJson(meResponse.data);

    // Sauvegarder l'utilisateur localement
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(user.toJson()),
    );

    return user;
  }

  /// Inscription
  Future<void> register({
    required String nom,
    required String prenom,
    required String telephone,
    required String password,
    required String genre,
  }) async {
    await _api.post('/auth/register/', data: {
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'password': password,
      'genre': genre,
    });
  }

  /// Déconnexion
  Future<void> logout() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken != null) {
        await _api.post('/auth/logout/', data: {'refresh_token': refreshToken});
      }
    } finally {
      await _storage.deleteAll();
    }
  }

  /// Vérifie si l'utilisateur est déjà connecté
  Future<UserModel?> getCurrentUser() async {
    final userData = await _storage.read(key: AppConstants.userKey);
    if (userData == null) return null;
    try {
      final decoded = jsonDecode(userData);
      return UserModel.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null;
  }

  /// Rafraîchit l'utilisateur depuis le serveur et met à jour le cache local.
  /// Utile notamment pour obtenir le flag `is_admin` sur un compte déjà connecté
  /// avant l'ajout de ce champ.
  Future<UserModel?> refreshCurrentUser() async {
    try {
      final response = await _api.get('/auth/me/');
      final user = UserModel.fromJson(response.data);
      await _storage.write(
        key: AppConstants.userKey,
        value: jsonEncode(user.toJson()),
      );
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Met à jour le profil (nom/prénom/genre) et rafraîchit le cache local.
  Future<UserModel> updateProfil({
    required String nom,
    required String prenom,
    required String genre,
  }) async {
    final response = await _api.patch('/auth/me/', data: {
      'nom': nom,
      'prenom': prenom,
      'genre': genre,
    });
    final user = UserModel.fromJson(response.data);
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(user.toJson()),
    );
    return user;
  }

  /// Change le mot de passe (vérifie l'actuel côté serveur via Keycloak).
  Future<void> changePassword({
    required String current,
    required String nouveau,
  }) async {
    await _api.post('/auth/change-password/', data: {
      'current_password': current,
      'new_password': nouveau,
    });
  }

  /// Enregistre le raccourci de paiement USSD (ex. "*144*2*1*{montant}#")
  /// et rafraîchit le cache local.
  Future<UserModel> updateCodeUssd(String code) async {
    final response = await _api.patch('/auth/me/', data: {
      'code_paiement_ussd': code,
    });
    final user = UserModel.fromJson(response.data);
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(user.toJson()),
    );
    return user;
  }

  /// Upload de la photo de profil (multipart) + rafraîchit le cache local.
  Future<UserModel> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final response = await _api.postMultipart('/auth/me/photo/', formData);
    final user = UserModel.fromJson(response.data);
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(user.toJson()),
    );
    return user;
  }
}