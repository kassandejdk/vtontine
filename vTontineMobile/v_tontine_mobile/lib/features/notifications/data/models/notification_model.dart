class NotificationModel {
  final int id;
  final String titre;
  final String message;
  final String dateEnvoie;
  final bool estLu;
  final int? tontineId;
  final String? invitationToken;

  const NotificationModel({
    required this.id,
    required this.titre,
    required this.message,
    required this.dateEnvoie,
    required this.estLu,
    required this.tontineId,
    required this.invitationToken,
  });

  /// True si la notification correspond à une invitation actionnable.
  bool get estInvitation => invitationToken != null && invitationToken!.isNotEmpty;

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'],
        titre: json['titre'] ?? '',
        message: json['message'] ?? '',
        dateEnvoie: json['date_envoie'] ?? '',
        estLu: json['est_lu'] ?? false,
        tontineId: json['tontine_id'],
        invitationToken: json['invitation_token']?.toString(),
      );
}
