import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Rejouer la requête avec le nouveau token
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  // Un seul refresh à la fois : les requêtes parallèles qui tombent en 401
  // partagent la MÊME opération de refresh (évite la course qui vidait l'écran).
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshToken() {
    return _refreshInFlight ??=
        _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) {
        return false;
      }

      final response = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      )).post(
        '${AppConstants.baseUrl}/auth/refresh/',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final newAccessToken = response.data['access_token'];

      await _storage.write(
          key: AppConstants.accessTokenKey, value: newAccessToken);
      return true;
    } catch (e) {
      await _storage.deleteAll();
      return false;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params, Map<String, String>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters ?? params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  /// Envoi multipart (upload de fichier).
  Future<Response> postMultipart(String path, FormData data) => _dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}