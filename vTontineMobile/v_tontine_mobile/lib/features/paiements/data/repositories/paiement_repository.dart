import '../../../../core/network/api_client.dart';
import '../models/paiement_model.dart';

class PaiementRepository {
  final _api = ApiClient();

  /// Paiements de l'utilisateur (ou de la tontine si `tontineId` fourni et créateur).
  Future<List<PaiementModel>> liste({int? tontineId}) async {
    final response = await _api.get(
      '/paiements/',
      queryParameters: tontineId != null ? {'tontine': '$tontineId'} : null,
    );
    return (response.data as List)
        .map((p) => PaiementModel.fromJson(p))
        .toList();
  }

  /// Détail d'un paiement
  Future<PaiementModel> detail(int id) async {
    final response = await _api.get('/paiements/$id/');
    return PaiementModel.fromJson(response.data);
  }

  /// Enregistrer un paiement pour une participation.
  /// `transactionId` est facultatif (généré côté serveur sinon).
  Future<PaiementModel> enregistrer({
    required int participationId,
    required double montant,
    String? transactionId,
  }) async {
    final response = await _api.post('/paiements/', data: {
      'participation': participationId,
      'montant': montant,
      if (transactionId != null && transactionId.isNotEmpty)
        'transaction_id': transactionId,
    });
    return PaiementModel.fromJson(response.data);
  }

  /// Confirmer un paiement (créateur de la tontine).
  Future<PaiementModel> confirmer(int paiementId) async {
    final response = await _api.patch('/paiements/$paiementId/confirmer/');
    return PaiementModel.fromJson(response.data);
  }

  /// Refuser un paiement (créateur de la tontine).
  Future<PaiementModel> refuser(int paiementId, {String motif = ''}) async {
    final response = await _api.patch(
      '/paiements/$paiementId/refuser/',
      data: {if (motif.isNotEmpty) 'motif': motif},
    );
    return PaiementModel.fromJson(response.data);
  }
}
