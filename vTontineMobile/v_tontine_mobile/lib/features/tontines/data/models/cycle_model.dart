// ─── cycle_model.dart ─────────────────────────────────────────────────────────
// Registre transparent des tours (cycles) d'une tontine.

class CycleMembreModel {
  final int participationId;
  final String fullName;
  final String telephone;
  final int? ordrePrise;
  final bool estCreateur;
  final bool estBeneficiaire;
  final bool aJour;

  const CycleMembreModel({
    required this.participationId,
    required this.fullName,
    required this.telephone,
    this.ordrePrise,
    required this.estCreateur,
    required this.estBeneficiaire,
    required this.aJour,
  });

  /// Accepte aussi bien la forme « membre » (participation_id) que la forme
  /// « bénéficiaire » (id) renvoyées par l'API.
  factory CycleMembreModel.fromJson(Map<String, dynamic> json) {
    final p = (json['participant'] as Map?) ?? {};
    final nom = '${p['prenom'] ?? ''} ${p['nom'] ?? ''}'.trim();
    return CycleMembreModel(
      participationId: json['participation_id'] ?? json['id'] ?? 0,
      fullName: nom.isEmpty ? (p['full_name'] ?? '') : nom,
      telephone: p['telephone'] ?? '',
      ordrePrise: json['ordre_prise'],
      estCreateur: json['est_createur'] ?? false,
      estBeneficiaire: json['est_beneficiaire'] ?? false,
      aJour: json['a_jour'] ?? false,
    );
  }
}

class CycleModel {
  final int id;
  final int numero;
  final String? dateDebut;
  final String? dateFin;
  final String statut; // A_VENIR / EN_COURS / CLOTURE
  final String statutDisplay;
  final bool priseVersee;
  final String? dateVersement;
  final bool estCourant;
  final CycleMembreModel? beneficiaire;
  final List<CycleMembreModel> membres;
  final int nbAJour;
  final int nbTotal;

  const CycleModel({
    required this.id,
    required this.numero,
    this.dateDebut,
    this.dateFin,
    required this.statut,
    required this.statutDisplay,
    required this.priseVersee,
    this.dateVersement,
    required this.estCourant,
    this.beneficiaire,
    required this.membres,
    required this.nbAJour,
    required this.nbTotal,
  });

  factory CycleModel.fromJson(Map<String, dynamic> json) => CycleModel(
        id: json['id'],
        numero: json['numero'],
        dateDebut: json['date_debut'],
        dateFin: json['date_fin'],
        statut: json['statut'] ?? 'A_VENIR',
        statutDisplay: json['statut_display'] ?? '',
        priseVersee: json['prise_versee'] ?? false,
        dateVersement: json['date_versement'],
        estCourant: json['est_courant'] ?? false,
        beneficiaire: json['beneficiaire'] != null
            ? CycleMembreModel.fromJson(json['beneficiaire'])
            : null,
        membres: (json['membres'] as List? ?? [])
            .map((m) => CycleMembreModel.fromJson(m))
            .toList(),
        nbAJour: json['nb_a_jour'] ?? 0,
        nbTotal: json['nb_total'] ?? 0,
      );
}

class RegistreCycles {
  final int tontineId;
  final double montant;
  final String frequenceDisplay;
  final bool estCreateur;
  final int? cycleCourant;
  final List<CycleModel> cycles;

  const RegistreCycles({
    required this.tontineId,
    required this.montant,
    required this.frequenceDisplay,
    required this.estCreateur,
    this.cycleCourant,
    required this.cycles,
  });

  factory RegistreCycles.fromJson(Map<String, dynamic> json) => RegistreCycles(
        tontineId: json['tontine_id'],
        montant: double.tryParse(json['montant'].toString()) ?? 0,
        frequenceDisplay: json['frequence_display'] ?? '',
        estCreateur: json['est_createur'] ?? false,
        cycleCourant: json['cycle_courant'],
        cycles: (json['cycles'] as List? ?? [])
            .map((c) => CycleModel.fromJson(c))
            .toList(),
      );
}
