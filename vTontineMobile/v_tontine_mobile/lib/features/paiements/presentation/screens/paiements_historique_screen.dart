import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../tontines/data/models/tontine_model.dart';
import '../../../tontines/data/repositories/tontine_repository.dart';
import '../../data/models/paiement_model.dart';
import '../../data/repositories/paiement_repository.dart';

/// Historique des paiements d'une tontine.
/// - Créateur : tous les paiements + possibilité de confirmer ceux en attente.
/// - Membre   : ses propres cotisations.
class PaiementsHistoriqueScreen extends StatefulWidget {
  final String tontineId;
  const PaiementsHistoriqueScreen({super.key, required this.tontineId});

  @override
  State<PaiementsHistoriqueScreen> createState() =>
      _PaiementsHistoriqueScreenState();
}

class _PaiementsHistoriqueScreenState extends State<PaiementsHistoriqueScreen> {
  final _tontineRepo = TontineRepository();
  final _paiementRepo = PaiementRepository();

  bool _isLoading = true;
  String? _error;
  TontineModel? _tontine;
  List<PaiementModel> _paiements = [];

  int get _id => int.parse(widget.tontineId);

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
        _tontineRepo.getTontine(_id),
        _paiementRepo.liste(tontineId: _id),
      ]);
      if (mounted) {
        setState(() {
          _tontine = results[0] as TontineModel;
          _paiements = results[1] as List<PaiementModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmer(PaiementModel p) async {
    try {
      await _paiementRepo.confirmer(p.id);
      if (mounted) {
        AppToast.show(context, 'Paiement confirmé', error: false);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur : $e', error: true);
      }
    }
  }

  Future<void> _refuser(PaiementModel p) async {
    try {
      await _paiementRepo.refuser(p.id);
      if (mounted) {
        AppToast.show(context, 'Paiement refusé', error: false);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur : $e', error: true);
      }
    }
  }

  /// Formate une date ISO en "jj/mm/aaaa hh:mm" (sans dépendance externe).
  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final l = d.toLocal();
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(l.day)}/${deux(l.month)}/${l.year} ${deux(l.hour)}:${deux(l.minute)}';
  }

  double get _totalConfirme => _paiements
      .where((p) => p.estConfirme)
      .fold(0.0, (s, p) => s + p.montant);

  @override
  Widget build(BuildContext context) {
    final estCreateur = _tontine?.estCreateur ?? false;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Historique des paiements',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tontines/${widget.tontineId}'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: _paiements.isEmpty
                      ? _buildEmpty()
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildTotalCard(),
                            const SizedBox(height: 16),
                            ..._paiements
                                .map((p) => _buildPaiementCard(p, estCreateur)),
                          ],
                        ),
                ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOTAL CONFIRMÉ',
              style: TextStyle(
                  color: Colors.white70, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('${_totalConfirme.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_paiements.length} paiement(s) enregistré(s)',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPaiementCard(PaiementModel p, bool estCreateur) {
    final (badgeColor, badgeBg, badgeLabel) = switch (p.statut) {
      'CONFIRME' => (AppTheme.success, const Color(0xFFE8F8EF), 'Confirmé'),
      'REFUSE' => (AppTheme.danger, const Color(0xFFFDECEC), 'Refusé'),
      _ => (AppTheme.warning, const Color(0xFFFFF3E0), 'En attente'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.participantNom.isEmpty ? 'Membre' : p.participantNom,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text('${p.montant.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: badgeBg, borderRadius: BorderRadius.circular(8)),
                child: Text(badgeLabel,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: AppTheme.textGrey),
              const SizedBox(width: 4),
              Text(_formatDate(p.datePaiement),
                  style: const TextStyle(
                      color: AppTheme.textGrey, fontSize: 12)),
              const Spacer(),
              if (estCreateur && p.estEnAttente) ...[
                TextButton(
                  onPressed: () => _refuser(p),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    foregroundColor: AppTheme.danger,
                  ),
                  child: const Text('Refuser'),
                ),
                TextButton(
                  onPressed: () => _confirmer(p),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Confirmer'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.receipt_long_outlined,
            color: AppTheme.primary.withOpacity(0.4), size: 64),
        const SizedBox(height: 16),
        const Center(
          child: Text('Aucun paiement pour le moment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            const Text('Erreur de chargement'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
