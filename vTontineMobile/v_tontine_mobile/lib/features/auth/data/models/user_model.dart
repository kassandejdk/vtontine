class UserModel {
  final int id;
  final String nom;
  final String prenom;
  final String telephone;
  final String genre;
  final String codePaiementUssd; // raccourci Mobile Money, avec {montant}
  final String? photo;           // URL de la photo de profil (ou null)
  final bool isAdmin;            // administrateur plateforme (is_staff)

  const UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.genre,
    this.codePaiementUssd = '',
    this.photo,
    this.isAdmin = false,
  });

  String get fullName => '$prenom $nom';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    nom: json['nom'],
    prenom: json['prenom'],
    telephone: json['telephone'].toString(),
    genre: json['genre'],
    codePaiementUssd: json['code_paiement_ussd'] ?? '',
    photo: json['photo'],
    isAdmin: json['is_admin'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'prenom': prenom,
    'telephone': telephone,
    'genre': genre,
    'code_paiement_ussd': codePaiementUssd,
    'photo': photo,
    'is_admin': isAdmin,
  };
}