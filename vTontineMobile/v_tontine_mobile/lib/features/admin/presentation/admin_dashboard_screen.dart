import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/network/api_error.dart';
import '../../tontines/data/models/tontine_model.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';

/// Espace administrateur plateforme (réservé aux comptes `is_admin`).
/// Vue d'ensemble : statistiques, toutes les tontines, tous les utilisateurs.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repo = AdminRepository();

  AdminStats? _stats;
  List<TontineModel>? _tontines;
  List<AdminUser>? _users;
  String? _erreur;

  final _tontineSearch = TextEditingController();
  final _userSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tontineSearch.dispose();
    _userSearch.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _erreur = null);
    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getTontines(),
        _repo.getUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _tontines = results[1] as List<TontineModel>;
        _users = results[2] as List<AdminUser>;
      });
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _rechercherTontines() async {
    try {
      final list = await _repo.getTontines(q: _tontineSearch.text.trim());
      if (mounted) setState(() => _tontines = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _rechercherUsers() async {
    try {
      final list = await _repo.getUsers(q: _userSearch.text.trim());
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Espace admin',
              style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textGrey,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: 'Tontines'),
              Tab(text: 'Utilisateurs'),
            ],
          ),
        ),
        body: _erreur != null
            ? _buildErreur()
            : Column(
                children: [
                  _buildStats(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTontinesTab(),
                        _buildUsersTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErreur() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
              const SizedBox(height: 12),
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadAll, child: const Text('Réessayer')),
            ],
          ),
        ),
      );

  Widget _buildStats() {
    final s = _stats;
    if (s == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _statTile('Utilisateurs', '${s.nbUtilisateurs}',
              Icons.people_outline, AppTheme.primary),
          _statTile('Tontines', '${s.nbTontines}',
              Icons.savings_outlined, AppTheme.success),
          _statTile('Collecté', '${s.totalCollecte.toStringAsFixed(0)} F',
              Icons.payments_outlined, AppTheme.warning),
          _statTile('Paie. en attente', '${s.paiementsEnAttente}',
              Icons.schedule, AppTheme.danger),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textGrey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTontinesTab() {
    final list = _tontines;
    return Column(
      children: [
        _searchField(_tontineSearch, 'Rechercher une tontine…',
            _rechercherTontines),
        Expanded(
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _rechercherTontines,
                  child: list.isEmpty
                      ? _listeVide('Aucune tontine')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _tontineCard(list[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _tontineCard(TontineModel t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => context.go('/tontines/${t.id}'),
        title: Text(t.nom,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${t.createurNom.isEmpty ? "—" : t.createurNom} · '
          '${t.nbreParticipantsActuels}/${t.nbreParticipant} membres · '
          '${t.montant.toStringAsFixed(0)} FCFA',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _statutChip(t.statutLabel, t.statut),
      ),
    );
  }

  Widget _buildUsersTab() {
    final list = _users;
    return Column(
      children: [
        _searchField(_userSearch, 'Rechercher un utilisateur…', _rechercherUsers),
        Expanded(
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _rechercherUsers,
                  child: list.isEmpty
                      ? _listeVide('Aucun utilisateur')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _userCard(list[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _userCard(AdminUser u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          child: Text(
            u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: AppTheme.primary),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(u.fullName.isEmpty ? u.telephone : u.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (u.isAdmin) ...[
              const SizedBox(width: 6),
              _statutChip('admin', 'COMPLET'),
            ],
            if (!u.isActive) ...[
              const SizedBox(width: 6),
              _statutChip('inactif', 'INCOMPLET'),
            ],
          ],
        ),
        subtitle: Text(
          '${u.telephone} · ${u.nbTontinesCreees} tontine(s) créée(s)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _searchField(
      TextEditingController ctrl, String hint, VoidCallback onSubmit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: ctrl,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: onSubmit,
          ),
        ),
      ),
    );
  }

  Widget _listeVide(String texte) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(texte,
                  style: const TextStyle(color: AppTheme.textGrey)),
            ),
          ),
        ],
      );

  Widget _statutChip(String label, String statut) {
    Color color;
    switch (statut) {
      case 'COMPLET':
        color = AppTheme.success;
        break;
      case 'TERMINE':
        color = AppTheme.textGrey;
        break;
      default:
        color = AppTheme.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
