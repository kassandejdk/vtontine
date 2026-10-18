import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/tontine_model.dart';
import '../../data/repositories/tontine_repository.dart';

class TontineListScreen extends StatefulWidget {
  const TontineListScreen({super.key});

  @override
  State<TontineListScreen> createState() => _TontineListScreenState();
}

class _TontineListScreenState extends State<TontineListScreen> {
  final _repo = TontineRepository();

  int _tab = 0; // 0 = mes tontines, 1 = découvrir
  bool _isLoading = true;
  String? _error;
  List<TontineModel> _mes = [];
  List<TontineModel> _publiques = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getMesTontines(),
        _repo.decouvrir(),
      ]);
      if (mounted) {
        setState(() {
          _mes = results[0];
          _publiques = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _tab == 0 ? _mes : _publiques;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tontines', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.createTontine),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _tabButton(0, 'Mes tontines'),
                  _tabButton(1, 'Découvrir'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: _buildBody(liste),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody(List<TontineModel> liste) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
          const SizedBox(height: 12),
          const Center(child: Text('Erreur de chargement')),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ),
        ],
      );
    }
    if (liste.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.savings_outlined,
              color: AppTheme.primary.withOpacity(0.4), size: 64),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _tab == 0
                  ? 'Vous n\'avez aucune tontine'
                  : 'Aucune tontine publique à découvrir',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: liste.length,
      itemBuilder: (ctx, i) => _tontineCard(liste[i]),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppTheme.textDark : AppTheme.textGrey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tontineCard(TontineModel t) {
    final (tagColor, tagBg) = switch (t.statut) {
      'COMPLET' => (AppTheme.success, const Color(0xFFE8F8EF)),
      'INCOMPLET' => (AppTheme.warning, const Color(0xFFFFF3E0)),
      _ => (AppTheme.textGrey, const Color(0xFFF0F0F0)),
    };

    return GestureDetector(
      onTap: () => context.go('/tontines/${t.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: tagBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(t.statutLabel,
                      style: TextStyle(
                          color: tagColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${t.nbreParticipantsActuels}/${t.nbreParticipant} membres • ${t.frequenceDisplay}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Par ${t.createurNom.isEmpty ? "—" : t.createurNom} • ${t.dateCreationCourt}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text('${t.montant.toStringAsFixed(0)} FCFA / contribution',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      onTap: (i) {
        switch (i) {
          case 0: context.go(AppRoutes.home); break;
          case 2: context.go(AppRoutes.notifications); break;
          case 3: context.go(AppRoutes.profil); break;
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.textGrey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Tontines'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Activité'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
      ],
    );
  }
}
