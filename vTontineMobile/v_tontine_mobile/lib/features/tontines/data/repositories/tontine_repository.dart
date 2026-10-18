// ─── tontine_repository.dart ──────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/tontine_model.dart';
import '../models/cycle_model.dart';

class TontineRepository {
  final _api = ApiClient();

  /// Toutes les tontines de l'utilisateur (créées + participées)
  Future<List<TontineModel>> getMesTontines({String? statut}) async {
    final response = await _api.get(
      '/tontines/',
      queryParameters: statut != null ? {'statut': statut} : null,
    );
    return (response.data as List)
        .map((t) => TontineModel.fromJson(t))
        .toList();
  }

  /// Détail d'une tontine
  Future<TontineModel> getTontine(int id) async {
    final response = await _api.get('/tontines/$id/');
    return TontineModel.fromJson(response.data);
  }

  /// Participants d'une tontine
  Future<List<ParticipantModel>> getParticipants(int tontineId) async {
    final response = await _api.get('/tontines/$tontineId/participants/');
    return (response.data as List)
        .map((p) => ParticipantModel.fromJson(p))
        .toList();
  }

  /// Créer une tontine (avec tous les nouveaux champs)
  Future<TontineModel> creerTontine({
    required String nom,
    required int frequenceValeur,
    required String frequenceType,
    required int nbreParticipant,
    required double montant,
    String description = '',
    bool visibilite = true,
    bool createurEstMembre = false,
    String typePrise = 'ARGENT',
    double? montantPrise,
    String descriptionProduitPrise = '',
    double? valeurEstimeeProduit,
    List<Map<String, dynamic>> regles = const [],
    String? dateDebut,
  }) async {
    final response = await _api.post('/tontines/', data: {
      'nom': nom,
      'description': description,
      'frequence_valeur': frequenceValeur,
      'frequence_type': frequenceType,
      'nbre_participant': nbreParticipant,
      'montant': montant,
      'visibilite': visibilite,
      'createur_est_membre': createurEstMembre,
      'type_prise': typePrise,
      if (montantPrise != null) 'montant_prise': montantPrise,
      if (descriptionProduitPrise.isNotEmpty)
        'description_produit_prise': descriptionProduitPrise,
      if (valeurEstimeeProduit != null)
        'valeur_estimee_produit': valeurEstimeeProduit,
      if (regles.isNotEmpty) 'regles': regles,
      if (dateDebut != null) 'date_debut': dateDebut,
    });
    return TontineModel.fromJson(response.data);
  }

  /// Modifier une tontine
  Future<TontineModel> modifier(int tontineId, Map<String, dynamic> data) async {
    final response = await _api.put('/tontines/$tontineId/', data: data);
    return TontineModel.fromJson(response.data);
  }

  /// Supprimer une tontine
  Future<void> supprimer(int tontineId) async {
    await _api.delete('/tontines/$tontineId/');
  }

  // ── Adhésion ────────────────────────────────────────────────────────────────

  /// Rejoindre via invitation (directe ou lien)
  Future<ParticipantModel> rejoindreViaInvitation({
    required String token,
    required List<int> reglesAcceptees,
  }) async {
    final response = await _api.post(
      '/tontines/rejoindre/$token/',
      data: {'regles_acceptees': reglesAcceptees},
    );
    return ParticipantModel.fromJson(response.data);
  }

  /// Demande spontanée sur tontine publique
  Future<Map<String, dynamic>> demanderAdhesion({
    required int tontineId,
    required List<int> reglesAcceptees,
    String message = '',
  }) async {
    final response = await _api.post(
      '/tontines/$tontineId/demandes/',
      data: {
        'regles_acceptees': reglesAcceptees,
        if (message.isNotEmpty) 'message': message,
      },
    );
    return response.data;
  }

  /// Quitter une tontine
  Future<void> quitter(int tontineId) async {
    await _api.delete('/tontines/$tontineId/quitter/');
  }

  // ─── tontine_repository.dart — nouveaux appels ───────────────────────────────

  /// Générer un lien d'invitation partageable
  Future<Map<String, dynamic>> genererLienInvitation(int tontineId) async {
    final response = await _api.post(
      '/tontines/$tontineId/invitations/lien/',
    );
    return response.data;
  }

  /// Rechercher un user par téléphone
  Future<Map<String, dynamic>> rechercherUserParTelephone(String telephone, int tontineId) async {
    final response = await _api.get(
      '/tontines/$tontineId/invitations/rechercher/',
      queryParameters: {'telephone': telephone},
    );
    return response.data;
  }

  /// Inviter un user existant par téléphone
  Future<Map<String, dynamic>> inviterParTelephone({
    required int tontineId,
    required String telephone,
  }) async {
    final response = await _api.post(
      '/tontines/$tontineId/invitations/telephone/',
      data: {'telephone': telephone},
    );
    return response.data;
  }

  // ─── Découverte ──────────────────────────────────────────────────────────────

  /// Tontines publiques que l'utilisateur peut rejoindre
  Future<List<TontineModel>> decouvrir() async {
    final response = await _api.get('/tontines/decouvrir/');
    return (response.data as List)
        .map((t) => TontineModel.fromJson(t))
        .toList();
  }

  // ─── Gestion (créateur) ──────────────────────────────────────────────────────

  /// Demandes d'adhésion en attente (créateur)
  Future<List<DemandeAdhesionModel>> getDemandes(int tontineId) async {
    final response = await _api.get('/tontines/$tontineId/demandes/');
    return (response.data as List)
        .map((d) => DemandeAdhesionModel.fromJson(d))
        .toList();
  }

  /// Accepter / refuser une demande d'adhésion
  Future<void> traiterDemande(int demandeId, bool accepter) async {
    await _api.patch(
      '/tontines/demandes/$demandeId/traiter/',
      data: {'accepter': accepter},
    );
  }

  /// Exclure un participant (créateur)
  Future<void> exclureParticipant({
    required int tontineId,
    required int participationId,
    String motif = '',
  }) async {
    await _api.post(
      '/tontines/$tontineId/participants/$participationId/exclure/',
      data: {if (motif.isNotEmpty) 'motif': motif},
    );
  }

  /// Modifier l'ordre de prise d'un participant (créateur)
  Future<void> modifierOrdre({
    required int tontineId,
    required int participationId,
    required int ordre,
  }) async {
    await _api.patch(
      '/tontines/$tontineId/participants/$participationId/ordre/',
      data: {'ordre_prise': ordre},
    );
  }

  /// Clôturer définitivement la tontine (créateur)
  Future<TontineModel> terminer(int tontineId) async {
    final response = await _api.post('/tontines/$tontineId/terminer/');
    return TontineModel.fromJson(response.data);
  }

  // ─── Cycles / registre des tours ─────────────────────────────────────────────

  /// Registre transparent des cycles (créateur + membres confirmés).
  Future<RegistreCycles> getCycles(int tontineId) async {
    final response = await _api.get('/tontines/$tontineId/cycles/');
    return RegistreCycles.fromJson(response.data);
  }

  /// Attester le versement de la prise d'un cycle (créateur).
  Future<CycleModel> verserPrise(int tontineId, int numero) async {
    final response =
        await _api.post('/tontines/$tontineId/cycles/$numero/verser-prise/');
    return CycleModel.fromJson(response.data);
  }

  // ─── Invitations reçues ────────────────────────────────────────────────────

  /// Invitations directes reçues par l'utilisateur
  Future<List<InvitationRecueModel>> getInvitationsRecues({String? statut}) async {
    final response = await _api.get(
      '/tontines/invitations/',
      queryParameters: statut != null ? {'statut': statut} : null,
    );
    return (response.data as List)
        .map((i) => InvitationRecueModel.fromJson(i))
        .toList();
  }

  /// Refuser une invitation directe (par token)
  Future<void> refuserInvitation(String token) async {
    await _api.post('/tontines/rejoindre/$token/refuser/');
  }

  /// Prévisualiser la tontine ciblée par un jeton d'invitation (deep link).
  Future<TontineModel> infosInvitation(String token) async {
    final response = await _api.get('/tontines/rejoindre/$token/');
    return TontineModel.fromJson(response.data);
  }

  // ─── Règles (créateur) ───────────────────────────────────────────────────────

  /// Ajouter une règle à une tontine existante.
  Future<RegleModel> ajouterRegle({
    required int tontineId,
    required String titre,
    required String description,
    String categorie = 'ADHESION',
    bool estObligatoire = true,
  }) async {
    final response = await _api.post('/tontines/$tontineId/regles/', data: {
      'titre': titre,
      'description': description,
      'categorie': categorie,
      'est_obligatoire': estObligatoire,
    });
    return RegleModel.fromJson(response.data);
  }

  /// Supprimer une règle.
  Future<void> supprimerRegle(int tontineId, int regleId) async {
    await _api.delete('/tontines/$tontineId/regles/$regleId/');
  }

  // ─── Moyens de paiement (créateur) ───────────────────────────────────────────

  Future<MethodePaiementModel> ajouterMethodePaiement({
    required int tontineId,
    required String libelle,
    required String codeUssd,
  }) async {
    final response = await _api.post(
      '/tontines/$tontineId/methodes-paiement/',
      data: {'libelle': libelle, 'code_ussd': codeUssd},
    );
    return MethodePaiementModel.fromJson(response.data);
  }

  Future<void> supprimerMethodePaiement(int tontineId, int methodeId) async {
    await _api.delete('/tontines/$tontineId/methodes-paiement/$methodeId/');
  }

  // ─── Chat de groupe ──────────────────────────────────────────────────────────

  /// Messages de la discussion (option `after` pour le polling des nouveaux).
  Future<List<MessageModel>> getMessages(int tontineId, {int? after}) async {
    final response = await _api.get(
      '/tontines/$tontineId/messages/',
      queryParameters: after != null ? {'after': '$after'} : null,
    );
    return (response.data as List)
        .map((m) => MessageModel.fromJson(m))
        .toList();
  }

  /// Envoyer un message dans la discussion.
  Future<MessageModel> envoyerMessage(int tontineId, String contenu) async {
    final response = await _api.post(
      '/tontines/$tontineId/messages/',
      data: {'contenu': contenu},
    );
    return MessageModel.fromJson(response.data);
  }

  /// Envoyer un message média (image ou note vocale) via multipart.
  Future<MessageModel> envoyerMessageMedia({
    required int tontineId,
    required String filePath,
    required String type, // 'IMAGE' ou 'AUDIO'
    String contenu = '',
  }) async {
    final formData = FormData.fromMap({
      'type': type,
      if (contenu.isNotEmpty) 'contenu': contenu,
      'piece_jointe': await MultipartFile.fromFile(filePath),
    });
    final response =
        await _api.postMultipart('/tontines/$tontineId/messages/', formData);
    return MessageModel.fromJson(response.data);
  }
}