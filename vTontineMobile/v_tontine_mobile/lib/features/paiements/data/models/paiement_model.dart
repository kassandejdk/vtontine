class PaiementModel {
  final int id;
  final int participation;
  final Map<String, dynamic>? participant;
  final int? tontineId;
  final String tontineNom;
  final double montant;
  final String datePaiement;
  final String transactionId;
  final bool estConfirme;
  final String statut;        // EN_ATTENTE / CONFIRME / REFUSE
  final String statutDisplay;
  final int? cycleNumero;     // tour (période) auquel se rattache le paiement

  const PaiementModel({
    required this.id,
    required this.participation,
    required this.participant,
    required this.tontineId,
    required this.tontineNom,
    required this.montant,
    required this.datePaiement,
    required this.transactionId,
    required this.estConfirme,
    required this.statut,
    required this.statutDisplay,
    this.cycleNumero,
  });

  String get participantNom => participant == null
      ? ''
      : '${participant!['prenom'] ?? ''} ${participant!['nom'] ?? ''}'.trim();

  bool get estEnAttente => statut == 'EN_ATTENTE';
  bool get estRefuse => statut == 'REFUSE';

  factory PaiementModel.fromJson(Map<String, dynamic> json) => PaiementModel(
        id: json['id'],
        participation: json['participation'],
        participant: json['participant'],
        tontineId: json['tontine_id'],
        tontineNom: json['tontine_nom'] ?? '',
        montant: double.parse(json['montant'].toString()),
        datePaiement: json['date_paiement'] ?? '',
        transactionId: json['transaction_id'] ?? '',
        estConfirme: json['est_confirmer'] ?? false,
        statut: json['statut'] ?? 'EN_ATTENTE',
        statutDisplay: json['statut_display'] ?? '',
        cycleNumero: json['cycle_numero'],
      );
}
