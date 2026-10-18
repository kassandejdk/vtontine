// ─── tontine_model.dart ───────────────────────────────────────────────────────

class RegleModel {
  final int id;
  final String titre;
  final String description;
  final String categorie;
  final String categorieDisplay;
  final bool estObligatoire;
  final int ordre;

  const RegleModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.categorie,
    required this.categorieDisplay,
    required this.estObligatoire,
    required this.ordre,
  });

  factory RegleModel.fromJson(Map<String, dynamic> json) => RegleModel(
    id: json['id'],
    titre: json['titre'],
    description: json['description'] ?? '',
    categorie: json['categorie'] ?? 'AUTRE',
    categorieDisplay: json['categorie_display'] ?? '',
    estObligatoire: json['est_obligatoire'] ?? true,
    ordre: json['ordre'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'titre': titre,
    'description': description,
    'categorie': categorie,
    'est_obligatoire': estObligatoire,
    'ordre': ordre,
  };
}


class MethodePaiementModel {
  final int id;
  final String libelle;
  final String codeUssd;
  final int ordre;

  const MethodePaiementModel({
    required this.id,
    required this.libelle,
    required this.codeUssd,
    required this.ordre,
  });

  /// Code USSD avec le montant injecté.
  String ussdPour(double montant) =>
      codeUssd.replaceAll('{montant}', montant.toStringAsFixed(0));

  factory MethodePaiementModel.fromJson(Map<String, dynamic> json) =>
      MethodePaiementModel(
        id: json['id'],
        libelle: json['libelle'] ?? '',
        codeUssd: json['code_ussd'] ?? '',
        ordre: json['ordre'] ?? 0,
      );
}


class TontineModel {
  final int id;
  final String nom;
  final String description;
  final int frequenceValeur;
  final String frequenceType;
  final String frequenceDisplay;
  final int nbreParticipant;
  final int nbreParticipantsActuels;
  final double montant;
  final String statut;
  final bool visibilite;
  final bool createurEstMembre;

  // Prise
  final String typePrise;
  final String typePriseDisplay;
  final double? montantPrise;
  final String descriptionProduitPrise;
  final double? valeurEstimeeProduit;
  final String priseDisplay;

  // Règles
  final List<RegleModel> regles;

  // Moyens de paiement (définis par le créateur)
  final List<MethodePaiementModel> methodesPaiement;

  final String? dateDebut;
  final String dateCreation;
  final bool estMembre;
  final bool estCreateur;
  final Map<String, dynamic>? createur;

  const TontineModel({
    required this.id,
    required this.nom,
    required this.description,
    required this.frequenceValeur,
    required this.frequenceType,
    required this.frequenceDisplay,
    required this.nbreParticipant,
    required this.nbreParticipantsActuels,
    required this.montant,
    required this.statut,
    required this.visibilite,
    required this.createurEstMembre,
    required this.typePrise,
    required this.typePriseDisplay,
    this.montantPrise,
    required this.descriptionProduitPrise,
    this.valeurEstimeeProduit,
    required this.priseDisplay,
    required this.regles,
    this.methodesPaiement = const [],
    this.dateDebut,
    required this.dateCreation,
    required this.estMembre,
    required this.estCreateur,
    this.createur,
  });

  factory TontineModel.fromJson(Map<String, dynamic> json) => TontineModel(
    id: json['id'],
    nom: json['nom'],
    description: json['description'] ?? '',
    frequenceValeur: json['frequence_valeur'],
    frequenceType: json['frequence_type'],
    frequenceDisplay: json['frequence_display'] ?? '',
    nbreParticipant: json['nbre_participant'],
    nbreParticipantsActuels: json['nbre_participants_actuels'] ?? 0,
    montant: double.parse(json['montant'].toString()),
    statut: json['statut'] ?? 'INCOMPLET',
    visibilite: json['visibilite'] ?? true,
    createurEstMembre: json['createur_est_membre'] ?? false,
    typePrise: json['type_prise'] ?? 'ARGENT',
    typePriseDisplay: json['type_prise_display'] ?? '',
    montantPrise: json['montant_prise'] != null
        ? double.tryParse(json['montant_prise'].toString())
        : null,
    descriptionProduitPrise: json['description_produit_prise'] ?? '',
    valeurEstimeeProduit: json['valeur_estimee_produit'] != null
        ? double.tryParse(json['valeur_estimee_produit'].toString())
        : null,
    priseDisplay: json['prise_display'] ?? '',
    regles: (json['regles'] as List? ?? [])
        .map((r) => RegleModel.fromJson(r))
        .toList(),
    methodesPaiement: (json['methodes_paiement'] as List? ?? [])
        .map((m) => MethodePaiementModel.fromJson(m))
        .toList(),
    dateDebut: json['date_debut'],
    dateCreation: json['date_creation'] ?? '',
    estMembre: json['est_membre'] ?? false,
    estCreateur: json['est_createur'] ?? false,
    createur: json['createur'],
  );

  // ── Helpers ──
  double get progression =>
      nbreParticipant > 0 ? nbreParticipantsActuels / nbreParticipant : 0.0;

  // Statuts backend : INCOMPLET (recrutement) / COMPLET (au complet) / TERMINE (clôturé)
  bool get estIncomplet => statut == 'INCOMPLET';
  bool get estTermine => statut == 'TERMINE';
  bool get estComplet =>
      statut == 'COMPLET' || nbreParticipantsActuels >= nbreParticipant;

  /// Libellé lisible du statut.
  String get statutLabel => switch (statut) {
        'INCOMPLET' => 'Incomplet',
        'COMPLET' => 'Complet',
        'TERMINE' => 'Terminé',
        _ => statut,
      };

  bool get aReglesObligatoires => regles.any((r) => r.estObligatoire);
  List<RegleModel> get reglesObligatoires =>
      regles.where((r) => r.estObligatoire).toList();

  /// Nom lisible du créateur.
  String get createurNom => createur == null
      ? ''
      : '${createur!['prenom'] ?? ''} ${createur!['nom'] ?? ''}'.trim();

  /// Date de création au format jj/mm/aaaa.
  String get dateCreationCourt {
    final d = DateTime.tryParse(dateCreation);
    if (d == null) return '';
    final l = d.toLocal();
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(l.day)}/${deux(l.month)}/${l.year}';
  }
}


class ParticipantModel {
  final int id;
  final Map<String, dynamic> participant; // renommé : était `user`
  final String statut;
  final String statutDisplay;
  final bool estCreateur;
  final int? ordrePrise;
  final String dateAdhesion;

  const ParticipantModel({
    required this.id,
    required this.participant,
    required this.statut,
    required this.statutDisplay,
    required this.estCreateur,
    this.ordrePrise,
    required this.dateAdhesion,
  });

  // Raccourcis lisibles
  String get fullName =>
      '${participant['prenom'] ?? ''} ${participant['nom'] ?? ''}'.trim();
  String get telephone => participant['telephone'] ?? '';
  int get userId => participant['id'];

  factory ParticipantModel.fromJson(Map<String, dynamic> json) =>
      ParticipantModel(
        id: json['id'],
        participant: json['participant'], // ← clé API mise à jour
        statut: json['statut'] ?? 'EN_ATTENTE',
        statutDisplay: json['statut_display'] ?? '',
        estCreateur: json['est_createur'] ?? false,
        ordrePrise: json['ordre_prise'],
        dateAdhesion: json['date_adhesion'] ?? '',
      );
}


/// Demande d'adhésion (vue côté créateur).
class DemandeAdhesionModel {
  final int id;
  final Map<String, dynamic> demandeur;
  final String message;
  final String statut;
  final String dateDemande;

  const DemandeAdhesionModel({
    required this.id,
    required this.demandeur,
    required this.message,
    required this.statut,
    required this.dateDemande,
  });

  String get fullName =>
      '${demandeur['prenom'] ?? ''} ${demandeur['nom'] ?? ''}'.trim();
  String get telephone => demandeur['telephone'] ?? '';

  factory DemandeAdhesionModel.fromJson(Map<String, dynamic> json) =>
      DemandeAdhesionModel(
        id: json['id'],
        demandeur: json['demandeur'] ?? {},
        message: json['message'] ?? '',
        statut: json['statut'] ?? 'EN_ATTENTE',
        dateDemande: json['date_demande'] ?? '',
      );
}


/// Message de la discussion de groupe d'une tontine.
class MessageModel {
  final int id;
  final Map<String, dynamic> auteur;
  final String contenu;
  final String type;          // TEXTE / IMAGE / AUDIO
  final String? pieceJointe;  // URL de l'image ou de l'audio
  final String dateEnvoi;

  const MessageModel({
    required this.id,
    required this.auteur,
    required this.contenu,
    required this.type,
    required this.pieceJointe,
    required this.dateEnvoi,
  });

  int get auteurId => auteur['id'] ?? 0;
  String get auteurNom =>
      '${auteur['prenom'] ?? ''} ${auteur['nom'] ?? ''}'.trim();

  bool get estImage => type == 'IMAGE' && pieceJointe != null;
  bool get estAudio => type == 'AUDIO' && pieceJointe != null;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'],
        auteur: json['auteur'] ?? {},
        contenu: json['contenu'] ?? '',
        type: json['type'] ?? 'TEXTE',
        pieceJointe: json['piece_jointe'],
        dateEnvoi: json['date_envoi'] ?? '',
      );
}


/// Invitation directe reçue par l'utilisateur.
class InvitationRecueModel {
  final int id;
  final TontineModel tontine;
  final Map<String, dynamic>? invitePar;
  final String type;
  final String statut;
  final String statutDisplay;
  final String token;
  final String dateEnvoi;

  const InvitationRecueModel({
    required this.id,
    required this.tontine,
    required this.invitePar,
    required this.type,
    required this.statut,
    required this.statutDisplay,
    required this.token,
    required this.dateEnvoi,
  });

  String get inviteParFullName => invitePar == null
      ? ''
      : '${invitePar!['prenom'] ?? ''} ${invitePar!['nom'] ?? ''}'.trim();

  factory InvitationRecueModel.fromJson(Map<String, dynamic> json) =>
      InvitationRecueModel(
        id: json['id'],
        tontine: TontineModel.fromJson(json['tontine']),
        invitePar: json['invite_par'],
        type: json['type'] ?? 'DIRECTE',
        statut: json['statut'] ?? 'EN_ATTENTE',
        statutDisplay: json['statut_display'] ?? '',
        token: json['token']?.toString() ?? '',
        dateEnvoi: json['date_envoi'] ?? '',
      );
}