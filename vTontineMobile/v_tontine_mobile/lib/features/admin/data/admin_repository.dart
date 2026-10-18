// ─── admin_repository.dart ────────────────────────────────────────────────────

import '../../../core/network/api_client.dart';
import '../../tontines/data/models/tontine_model.dart';
import 'admin_models.dart';

class AdminRepository {
  final _api = ApiClient();

  Future<AdminStats> getStats() async {
    final response = await _api.get('/auth/admin/stats/');
    return AdminStats.fromJson(response.data);
  }

  Future<List<TontineModel>> getTontines({String? q}) async {
    final response = await _api.get(
      '/auth/admin/tontines/',
      queryParameters: (q != null && q.isNotEmpty) ? {'q': q} : null,
    );
    return (response.data as List)
        .map((t) => TontineModel.fromJson(t))
        .toList();
  }

  Future<List<AdminUser>> getUsers({String? q}) async {
    final response = await _api.get(
      '/auth/admin/users/',
      queryParameters: (q != null && q.isNotEmpty) ? {'q': q} : null,
    );
    return (response.data as List)
        .map((u) => AdminUser.fromJson(u))
        .toList();
  }
}
