import 'package:flutter/material.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/network/api_error.dart';
import '../../../paiements/data/models/paiement_model.dart';
import '../../../paiements/data/repositories/paiement_repository.dart';
import '../../data/models/cycle_model.dart';
import '../../data/repositories/tontine_repository.dart';

/// Calendrier d'un participant : pour chaque tour (période), son statut de
/// paiement (payé le…, en attente, non payé, à venir) et le tour où il reçoit
/// sa prise.
class ParticipantCalendrierScreen extends StatefulWidget {
  final int tontineId;
  final int participationId;
  final String participantNom;

  const ParticipantCalendrierScreen({
    super.key,
    required this.tontineId,
    required this.participationId,
    required this.participantNom,
  });

  @override
  State<ParticipantCalendrierScreen> createState() =>
      _ParticipantCalendrierScreenState();
}

class _ParticipantCalendrierScreenState
    extends State<ParticipantCalendrierScreen> {
  final _repo = TontineRepository();
  final _paiementRepo = PaiementRepository();

  bool _isLoading = true;
  String? _error;
  RegistreCycles? _registre;
  final Map<int, PaiementModel> _paiementParCycle = {};

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
      final registre = await _repo.getCycles(widget.tontineId);
      List<PaiementModel> paiements = [];
      try {
        paiements = await _paiementRepo.liste(tontineId: widget.tontineId);
      } catch (_) {}

      _paiementParCycle.clear();
      for (final p in paiements) {
        if (p.participation != widget.participationId) continue;
        if (p.cycleNumero == null) continue;
        final existant = _paiementParCycle[p.cycleNumero!];
        // On garde en priorité un paiement confirmé pour le tour.
        if (existant == null || (p.statut == 'CONFIRME')) {
          _paiementParCycle[p.cycleNumero!] = p;
        }
      }

      if (mounted) {
        setState(() {
          _registre = registre;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageErreur(e);
          _isLoading = false;
        });
      }
    }
  }

  CycleModel? get _cyclePrise {
    for (final c in _registre?.cycles ?? const <CycleModel>[]) {
      if (c.beneficiaire?.participationId == widget.participationId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.participantNom.isEmpty ? 'Participant' : widget.participantNom,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              Text(_error ?? 'Erreur', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final cycles = _registre!.cycles;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildResume(),
            const SizedBox(height: 16),
            if (cycles.isEmpty)
              _emptyCard('Aucun tour pour le moment.')
            else
              ...cycles.map(_buildLigne),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildResume() {
    final prise = _cyclePrise;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cotisation : ${_registre!.montant.toStringAsFixed(0)} FCFA / période',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_registre!.frequenceDisplay,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.card_giftcard, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prise == null
                      ? 'Ordre de prise non défini'
                      : 'Reçoit sa prise au tour ${prise.numero}'
                          '${prise.dateDebut != null ? " — ${_fmt(prise.dateDebut)}" : ""}'
                          '${prise.priseVersee ? " (versée)" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLigne(CycleModel c) {
    final p = _paiementParCycle[c.numero];
    final estPrise = c.beneficiaire?.participationId == widget.participationId;

    // Statut de paiement du participant pour ce tour.
    String label;
    Color color;
    IconData icon;
    if (p != null) {
      switch (p.statut) {
        case 'CONFIRME':
          label = 'Payé — ${_fmt(p.datePaiement)}';
          color = AppTheme.success;
          icon = Icons.check_circle;
          break;
        case 'REFUSE':
          label = 'Paiement refusé';
          color = AppTheme.danger;
          icon = Icons.cancel;
          break;
        default:
          label = 'En attente de confirmation';
          color = AppTheme.warning;
          icon = Icons.schedule;
      }
    } else if (c.statut == 'A_VENIR') {
      label = 'À venir';
      color = AppTheme.textGrey;
      icon = Icons.radio_button_unchecked;
    } else {
      label = 'Non payé';
      color = AppTheme.danger;
      icon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: estPrise ? Border.all(color: AppTheme.primary, width: 1.4) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Tour ${c.numero}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_periode(c),
                          style: const TextStyle(
                              color: AppTheme.textGrey, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: color, fontSize: 13)),
                if (estPrise)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      c.priseVersee
                          ? '★ Reçoit la prise ce tour — versée'
                          : '★ Reçoit la prise ce tour',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Center(
          child: Text(text, style: const TextStyle(color: AppTheme.textGrey)),
        ),
      );

  String _periode(CycleModel c) {
    if (c.dateDebut == null) return '';
    final d = _fmt(c.dateDebut);
    final f = c.dateFin != null ? _fmt(c.dateFin) : null;
    return f != null ? 'du $d au $f' : 'dès le $d';
  }

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d != null) {
      final l = d.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(l.day)}/${two(l.month)}/${l.year}';
    }
    final parts = iso.split('T')[0].split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return iso;
  }
}
