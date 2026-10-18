// ─── admin_models.dart ────────────────────────────────────────────────────────

class AdminStats {
  final int nbUtilisateurs;
  final int nbTontines;
  final int nbIncomplet;
  final int nbComplet;
  final int nbTermine;
  final double totalCollecte;
  final int paiementsEnAttente;

  const AdminStats({
    required this.nbUtilisateurs,
    required this.nbTontines,
    required this.nbIncomplet,
    required this.nbComplet,
    required this.nbTermine,
    required this.totalCollecte,
    required this.paiementsEnAttente,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final parStatut = (json['tontines_par_statut'] as Map?) ?? {};
    return AdminStats(
      nbUtilisateurs: json['nb_utilisateurs'] ?? 0,
      nbTontines: json['nb_tontines'] ?? 0,
      nbIncomplet: parStatut['INCOMPLET'] ?? 0,
      nbComplet: parStatut['COMPLET'] ?? 0,
      nbTermine: parStatut['TERMINE'] ?? 0,
      totalCollecte: double.tryParse('${json['total_collecte'] ?? 0}') ?? 0,
      paiementsEnAttente: json['paiements_en_attente'] ?? 0,
    );
  }
}

class AdminUser {
  final int id;
  final String fullName;
  final String telephone;
  final bool isAdmin;
  final bool isActive;
  final int nbTontinesCreees;
  final String? dateCreation;

  const AdminUser({
    required this.id,
    required this.fullName,
    required this.telephone,
    required this.isAdmin,
    required this.isActive,
    required this.nbTontinesCreees,
    this.dateCreation,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final nom = '${json['prenom'] ?? ''} ${json['nom'] ?? ''}'.trim();
    return AdminUser(
      id: json['id'],
      fullName: nom,
      telephone: json['telephone']?.toString() ?? '',
      isAdmin: json['is_admin'] ?? false,
      isActive: json['is_active'] ?? true,
      nbTontinesCreees: json['nb_tontines_creees'] ?? 0,
      dateCreation: json['date_creation'],
    );
  }
}
