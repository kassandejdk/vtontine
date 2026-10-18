import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/cycle_model.dart';
import '../../data/repositories/tontine_repository.dart';
import 'participant_calendrier_screen.dart';

/// Registre transparent des tours d'une tontine : pour chaque cycle (période),
/// qui est à jour de sa cotisation, qui reçoit la prise et si elle a été versée.
class CyclesScreen extends StatefulWidget {
  final String tontineId;
  const CyclesScreen({super.key, required this.tontineId});

  @override
  State<CyclesScreen> createState() => _CyclesScreenState();
}

class _CyclesScreenState extends State<CyclesScreen> {
  final _repo = TontineRepository();

  bool _isLoading = true;
  String? _error;
  RegistreCycles? _registre;

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
      final registre = await _repo.getCycles(_id);
      if (mounted) {
        setState(() {
          _registre = registre;
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

  Future<void> _verser(CycleModel c) async {
    final nom = c.beneficiaire?.fullName ?? 'le bénéficiaire';
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verser la prise du tour ${c.numero} ?'),
        content: Text(
            'Confirme que la prise a bien été remise à $nom. '
            'Cette action clôture le tour.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _repo.verserPrise(_id, c.numero);
      if (mounted) AppToast.show(context, 'Prise du tour ${c.numero} versée');
      await _load();
    } catch (e) {
      if (mounted) AppToast.show(context, messageErreur(e), error: true);
    }
  }

  void _ouvrirCalendrier(CycleMembreModel m) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ParticipantCalendrierScreen(
        tontineId: _id,
        participationId: m.participationId,
        participantNom: m.fullName.isEmpty ? m.telephone : m.fullName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Suivi des cycles',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tontines/${widget.tontineId}'),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _registre == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
              const SizedBox(height: 12),
              const Text('Impossible de charger les cycles',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final r = _registre!;
    if (r.cycles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            "Aucun cycle pour le moment.\nLes tours apparaîtront quand la "
            "tontine sera complète et qu'une date de début sera définie.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGrey),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEntete(r),
            const SizedBox(height: 16),
            ...r.cycles.map((c) => _buildCycleCard(r, c)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEntete(RegistreCycles r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cotisation : ${r.montant.toStringAsFixed(0)} FCFA / période',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(r.frequenceDisplay,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          if (r.cycleCourant != null) ...[
            const SizedBox(height: 4),
            Text('Tour en cours : n°${r.cycleCourant}',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildCycleCard(RegistreCycles r, CycleModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: c.estCourant
            ? Border.all(color: AppTheme.primary, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : tour + statut
          Row(
            children: [
              Text('Tour ${c.numero}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              _statutChip(c),
              const Spacer(),
              Text('${c.nbAJour}/${c.nbTotal} à jour',
                  style: const TextStyle(
                      color: AppTheme.textGrey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(_periodeLabel(c),
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),

          // Bénéficiaire
          if (c.beneficiaire != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.card_giftcard,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Bénéficiaire : ${c.beneficiaire!.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (c.priseVersee)
                  const _Badge(text: 'Prise versée', color: AppTheme.success),
              ],
            ),
          ],

          const Divider(height: 20),

          // Détail des membres
          ...c.membres.map((m) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _ouvrirCalendrier(m),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        m.aJour ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: m.aJour ? AppTheme.success : AppTheme.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.fullName.isEmpty ? m.telephone : m.fullName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (m.estBeneficiaire)
                        const _Badge(text: 'reçoit', color: AppTheme.primary),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppTheme.textGrey),
                    ],
                  ),
                ),
              )),

          // Action créateur : verser la prise
          if (r.estCreateur && !c.priseVersee && c.beneficiaire != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _verser(c),
                icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
                label: const Text('Marquer la prise versée'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statutChip(CycleModel c) {
    Color color;
    switch (c.statut) {
      case 'EN_COURS':
        color = AppTheme.warning;
        break;
      case 'CLOTURE':
        color = AppTheme.success;
        break;
      default:
        color = AppTheme.textGrey;
    }
    return _Badge(text: c.statutDisplay, color: color);
  }

  String _periodeLabel(CycleModel c) {
    if (c.dateDebut == null) return 'Dates à définir';
    final d = _fmt(c.dateDebut);
    final f = c.dateFin != null ? _fmt(c.dateFin) : null;
    return f != null ? 'du $d au $f' : 'à partir du $d';
  }

  String _fmt(String? iso) {
    if (iso == null) return '';
    final parts = iso.split('-'); // YYYY-MM-DD
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
