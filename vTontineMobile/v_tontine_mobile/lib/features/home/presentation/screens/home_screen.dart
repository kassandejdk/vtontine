import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../tontines/data/models/tontine_model.dart';
import '../../../tontines/data/repositories/tontine_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authRepo = AuthRepository();
  final _tontineRepo = TontineRepository();

  String _userName = 'Chargement...';
  List<TontineModel> _tontines = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });

    // Charger le user d'abord séparément
    final user = await _authRepo.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _userName = '${user.prenom} ${user.nom}';
      });
    }

    // Ensuite charger les tontines
    try {
      final tontines = await _tontineRepo.getMesTontines();
      if (mounted) {
        setState(() {
          _tontines = tontines;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  double get _epargneTotale =>
      _tontines.fold(0, (sum, t) => sum + t.montant);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildEpargneCard()),
              SliverToBoxAdapter(child: _buildActions()),
              SliverToBoxAdapter(child: _buildTontinesHeader()),
              if (_isLoading)
                const SliverToBoxAdapter(child: _LoadingTontines())
              else if (_error != null)
                SliverToBoxAdapter(child: _buildError())
              else if (_tontines.isEmpty)
                  SliverToBoxAdapter(child: _buildEmpty())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildTontineCard(_tontines[i]),
                      childCount: _tontines.length,
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withOpacity(0.2),
            child: const Icon(Icons.person, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bon retour,',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
              Text(_userName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textDark)),
            ],
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.go(AppRoutes.notifications),
              ),
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.danger, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpargneCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ÉPARGNE TOTALE',
              style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            '${_epargneTotale.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [

          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.createTontine),
              icon: const Icon(Icons.person_add_outlined, color: AppTheme.primary),
              label: const Text('Créer une nouvelle tontine',
                  style: TextStyle(color: AppTheme.primary)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTontinesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text('Mes tontines (${_tontines.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go(AppRoutes.tontines),
            child: const Text('Tout afficher',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTontineCard(TontineModel t) {
    Color tagColor;
    Color tagBg;
    String tagLabel;

    switch (t.statut) {
      case 'COMPLET':
        tagColor = AppTheme.success;
        tagBg = const Color(0xFFE8F8EF);
        tagLabel = 'COMPLET';
        break;
      case 'INCOMPLET':
        tagColor = AppTheme.warning;
        tagBg = const Color(0xFFFFF3E0);
        tagLabel = 'INCOMPLET';
        break;
      default:
        tagColor = AppTheme.textGrey;
        tagBg = const Color(0xFFF0F0F0);
        tagLabel = 'TERMINÉ';
    }

    return GestureDetector(
      onTap: () => context.go('/tontines/${t.id}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                  child: Text(tagLabel,
                      style: TextStyle(
                          color: tagColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${t.nbreParticipantsActuels}/${t.nbreParticipant} membres • ${t.frequenceDisplay}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: AppTheme.textGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Par ${t.createurNom.isEmpty ? "—" : t.createurNom} • ${t.dateCreationCourt}',
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Progression', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Text('${(t.progression * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            LinearPercentIndicator(
              lineHeight: 8,
              percent: t.progression.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF0F0F0),
              progressColor: t.estTermine ? AppTheme.textGrey : AppTheme.primary,
              barRadius: const Radius.circular(4),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Text('${t.montant.toStringAsFixed(0)} FCFA / contribution',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            const Text('Erreur de chargement'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.savings_outlined, color: AppTheme.primary.withOpacity(0.5), size: 64),
            const SizedBox(height: 16),
            const Text('Aucune tontine pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Créez votre première tontine ou rejoignez-en une',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textGrey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.createTontine),
              icon: const Icon(Icons.add),
              label: const Text('Créer une tontine'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (i) {
        switch (i) {
          case 1: context.go(AppRoutes.tontines); break;
          case 2: context.go(AppRoutes.notifications); break;
          case 3: context.go(AppRoutes.profil); break;
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.textGrey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Tontines'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Activité'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
      ],
    );
  }
}

class _LoadingTontines extends StatelessWidget {
  const _LoadingTontines();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) => Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      )),
    );
  }
}