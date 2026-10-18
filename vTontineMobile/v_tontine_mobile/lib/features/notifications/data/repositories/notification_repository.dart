import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final _api = ApiClient();

  Future<List<NotificationModel>> liste() async {
    final response = await _api.get('/notifications/');
    return (response.data as List)
        .map((n) => NotificationModel.fromJson(n))
        .toList();
  }

  Future<void> marquerLu(int id) async {
    await _api.post('/notifications/$id/lu/');
  }

  Future<void> marquerToutLu() async {
    await _api.post('/notifications/marquer-tout-lu/');
  }
}
