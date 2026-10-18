import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/tontine_model.dart';
import '../../data/repositories/tontine_repository.dart';

import 'invite_bottom_sheet.dart';


class TontineDetailScreen extends StatefulWidget {
  final String tontineId;
  const TontineDetailScreen({super.key, required this.tontineId});

  @override
  State<TontineDetailScreen> createState() => _TontineDetailScreenState();
}

class _TontineDetailScreenState extends State<TontineDetailScreen> {
  final _repo = TontineRepository();
  TontineModel? _tontine;
  List<ParticipantModel> _participants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final id = int.parse(widget.tontineId);
      final results = await Future.wait([
        _repo.getTontine(id),
        _repo.getParticipants(id),
      ]);
      if (mounted) {
        setState(() {
          _tontine = results[0] as TontineModel;
          _participants = results[1] as List<ParticipantModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Rejoindre : bottom sheet règles + demande ────────────────────────────

  Future<void> _rejoindre() async {
    final t = _tontine!;

    // Si pas de règles → envoyer la demande directement
    if (t.regles.isEmpty) {
      await _envoyerDemande(t, []);
      return;
    }

    // Sinon afficher le bottom sheet d'acceptation des règles
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegleAcceptationSheet(
        tontine: t,
        onConfirmer: (reglesAcceptees) async {
          Navigator.pop(context);
          await _envoyerDemande(t, reglesAcceptees);
        },
      ),
    );
  }

  Future<void> _envoyerDemande(TontineModel t, List<int> reglesAcceptees) async {
    try {
      await _repo.demanderAdhesion(
        tontineId: t.id,
        reglesAcceptees: reglesAcceptees,
      );
      if (mounted) {
        AppToast.show(context, 'Demande envoyée ! En attente de validation du créateur.', error: false);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur: $e', error: true);
      }
    }
  }

  // ─── Inviter un contact ───────────────────────────────────────────────────

  Future<void> _inviterContact() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteBottomSheet(
        tontine: _tontine!,
        participants: _participants,
      ),
    );
    // Recharger après une éventuelle invitation
    _loadData();
  }

  // ─── Build principal ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_tontine == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tontine introuvable')),
      );
    }

    final t = _tontine!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.nom,
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          if (t.estMembre || t.estCreateur) ...[
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Discussion',
              onPressed: () => context.go('/tontines/${t.id}/chat'),
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Historique des paiements',
              onPressed: () => context.go('/tontines/${t.id}/paiements'),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCagnotteCard(t),
                    if (t.description.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildDescriptionCard(t),
                    ],
                    const SizedBox(height: 20),
                    _buildInfoCard(t),
                    const SizedBox(height: 20),
                    _buildPriseCard(t),
                    if (t.regles.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildReglesCard(t),
                    ],
                    const SizedBox(height: 20),
                    _buildParticipants(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomButton(t),
        ],
      ),
    );
  }

  // ─── Carte cagnotte ───────────────────────────────────────────────────────

  Widget _buildCagnotteCard(TontineModel t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Contribution',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(t.frequenceDisplay,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${(t.montant * t.nbreParticipantsActuels).toStringAsFixed(0)} FCFA',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Barre de progression participants
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t.progression,
              backgroundColor: Colors.white.withOpacity(0.2),
              color: Colors.white,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.people_outline, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              '${t.nbreParticipantsActuels}/${t.nbreParticipant} participants',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            if (t.estComplet)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Complet',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ]),
        ],
      ),
    );
  }

  // ─── Description ──────────────────────────────────────────────────────────

  Widget _buildDescriptionCard(TontineModel t) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.info_outline, 'Description'),
          const SizedBox(height: 10),
          Text(t.description,
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDark.withOpacity(0.75),
                  height: 1.5)),
        ],
      ),
    );
  }

  // ─── Infos générales ──────────────────────────────────────────────────────

  Widget _buildInfoCard(TontineModel t) {
    return _card(
      child: Column(
        children: [
          _infoRow('Statut', _statutWidget(t.statut)),
          const Divider(height: 24),
          _infoRow(
            'Cotisation',
            Text('${t.montant.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 24),
          _infoRow('Fréquence', Text(t.frequenceDisplay)),
          const Divider(height: 24),
          _infoRow(
            'Visibilité',
            Row(children: [
              Icon(
                t.visibilite ? Icons.public : Icons.lock_outline,
                size: 16,
                color: t.visibilite ? AppTheme.success : AppTheme.textGrey,
              ),
              const SizedBox(width: 4),
              Text(t.visibilite ? 'Publique' : 'Privée'),
            ]),
          ),
          if (t.dateDebut != null) ...[
            const Divider(height: 24),
            _infoRow('Date de début', Text(t.dateDebut!)),
          ],
        ],
      ),
    );
  }

  // ─── Prise ────────────────────────────────────────────────────────────────

  Widget _buildPriseCard(TontineModel t) {
    final icone = switch (t.typePrise) {
      'PRODUIT' => Icons.inventory_2_outlined,
      'MIXTE'   => Icons.swap_horiz,
      _         => Icons.payments_outlined,
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(icone, 'Ce que reçoit le bénéficiaire'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icone, color: AppTheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.typePriseDisplay,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(t.priseDisplay,
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textDark.withOpacity(0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Détails si mixte
          if (t.typePrise == 'MIXTE') ...[
            const SizedBox(height: 10),
            if (t.montantPrise != null)
              _infoRow(
                'Montant',
                Text('${t.montantPrise!.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            if (t.descriptionProduitPrise.isNotEmpty) ...[
              const Divider(height: 16),
              _infoRow('Produit', Flexible(child: Text(t.descriptionProduitPrise))),
            ],
            if (t.valeurEstimeeProduit != null) ...[
              const Divider(height: 16),
              _infoRow(
                'Valeur estimée',
                Text('≈ ${t.valeurEstimeeProduit!.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(color: AppTheme.textGrey)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── Règles intérieures ───────────────────────────────────────────────────

  Widget _buildReglesCard(TontineModel t) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.rule_folder_outlined, 'Règles intérieures'),
          const SizedBox(height: 2),
          Text(
            'À accepter pour rejoindre la tontine',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textDark.withOpacity(0.5)),
          ),
          const SizedBox(height: 14),
          ...t.regles.map((r) => _buildRegleRow(r)),
        ],
      ),
    );
  }

  Widget _buildRegleRow(RegleModel r) {
    final categorieColor = switch (r.categorie) {
      'ADHESION'     => Colors.blue,
      'FINANCIER'    => Colors.green,
      'COMPORTEMENT' => Colors.orange,
      _              => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: categorieColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: categorieColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: categorieColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.titre,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    if (r.estObligatoire)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Obligatoire',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r.description,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textDark.withOpacity(0.6))),
                ],
                const SizedBox(height: 4),
                Text(r.categorieDisplay,
                    style: TextStyle(
                        fontSize: 11,
                        color: categorieColor,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Participants ─────────────────────────────────────────────────────────

  Widget _buildParticipants() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PARTICIPANTS (${_participants.length}/${_tontine!.nbreParticipant})',
              style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1),
            ),
            const Spacer(),
            if (_participants.length < _tontine!.nbreParticipant &&
                (_tontine!.estMembre || _tontine!.estCreateur))
              GestureDetector(
                onTap: _inviterContact,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_add_outlined,
                          color: AppTheme.primary, size: 16),
                      SizedBox(width: 4),
                      Text('Inviter',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_participants.isEmpty)
          const Center(child: Text('Aucun participant'))
        else
          ..._participants.map((p) => _buildParticipantRow(p)),
      ],
    );
  }

  Widget _buildParticipantRow(ParticipantModel p) {
    final initials = p.fullName.length >= 2
        ? p.fullName.substring(0, 2).toUpperCase()
        : p.fullName.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(initials,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              // Badge créateur
              if (p.estCreateur)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star,
                        color: Colors.white, size: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(p.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (p.estCreateur) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Créateur',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                Text(p.telephone,
                    style: const TextStyle(
                        color: AppTheme.textGrey, fontSize: 13)),
              ],
            ),
          ),
          if (p.ordrePrise != null)
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('#${p.ordrePrise}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // ─── Bouton bas ───────────────────────────────────────────────────────────
  Widget _buildBottomButton(TontineModel t) {
    if (t.estTermine) return const SizedBox.shrink();

    // ✅ Le créateur ne doit jamais voir "Rejoindre" — mais s'il est aussi
    // membre, il doit pouvoir cotiser en plus de gérer.
    if (t.estCreateur) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        color: AppTheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.estMembre) ...[
              ElevatedButton.icon(
                onPressed: () => context.go('/paiements/${t.id}'),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: Text('Contribuer (${t.montant.toStringAsFixed(0)} FCFA)'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: () => context.go('/tontines/${t.id}/gerer'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Gérer la tontine'),
            ),
          ],
        ),
      );
    }

    if (t.estMembre) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        color: AppTheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.go('/paiements/${t.id}'),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text('Contribuer (${t.montant.toStringAsFixed(0)} FCFA)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.go('/tontines/${t.id}/cycles'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Suivi des cycles'),
            ),
          ],
        ),
      );
    }

    if (t.estComplet) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        color: AppTheme.background,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.group_off_outlined),
          label: const Text('Tontine complète'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      color: AppTheme.background,
      child: ElevatedButton.icon(
        onPressed: _rejoindre,
        icon: const Icon(Icons.person_add_outlined),
        label: Text(t.aReglesObligatoires
            ? 'Rejoindre (règles à accepter)'
            : 'Rejoindre cette tontine'),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
      ),
    );
  }

  // ─── Widgets utilitaires ──────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: AppTheme.primary, size: 18),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14)),
    ],
  );

  Widget _infoRow(String label, Widget value) => Row(
    children: [
      Text(label, style: const TextStyle(color: AppTheme.textGrey)),
      const Spacer(),
      value,
    ],
  );

  Widget _statutWidget(String statut) {
    final (color, bg) = switch (statut) {
      'COMPLET'   => (AppTheme.success, const Color(0xFFE8F8EF)),
      'INCOMPLET' => (AppTheme.warning, const Color(0xFFFFF3E0)),
      _           => (AppTheme.textGrey, const Color(0xFFF0F0F0)),
    };
    final label = switch (statut) {
      'INCOMPLET' => 'Incomplet',
      'COMPLET'   => 'Complet',
      'TERMINE'   => 'Terminé',
      _           => statut,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Bottom sheet acceptation des règles ─────────────────────────────────────

class _RegleAcceptationSheet extends StatefulWidget {
  final TontineModel tontine;
  final void Function(List<int> reglesAcceptees) onConfirmer;

  const _RegleAcceptationSheet({
    required this.tontine,
    required this.onConfirmer,
  });

  @override
  State<_RegleAcceptationSheet> createState() => _RegleAcceptationSheetState();
}

class _RegleAcceptationSheetState extends State<_RegleAcceptationSheet> {
  late final Set<int> _acceptees;

  @override
  void initState() {
    super.initState();
    // Pré-cocher les règles non-obligatoires
    _acceptees = widget.tontine.regles
        .where((r) => !r.estObligatoire)
        .map((r) => r.id)
        .toSet();
  }

  bool get _peutConfirmer {
    // Toutes les règles obligatoires doivent être cochées
    return widget.tontine.reglesObligatoires
        .every((r) => _acceptees.contains(r.id));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Règles intérieures',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Cochez les règles pour manifester votre accord',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: widget.tontine.regles.length,
                itemBuilder: (_, i) {
                  final regle = widget.tontine.regles[i];
                  final checked = _acceptees.contains(regle.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: regle.estObligatoire
                        ? (v) => setState(() {
                      // Obligatoire : toujours coché, on toggle pour signifier l'accord
                      if (v == true) {
                        _acceptees.add(regle.id);
                      } else {
                        _acceptees.remove(regle.id);
                      }
                    })
                        : (v) => setState(() {
                      if (v == true) {
                        _acceptees.add(regle.id);
                      } else {
                        _acceptees.remove(regle.id);
                      }
                    }),
                    activeColor: AppTheme.primary,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(regle.titre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                        if (regle.estObligatoire)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Requis',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    subtitle: regle.description.isNotEmpty
                        ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(regle.description,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600])),
                    )
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  if (!_peutConfirmer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Acceptez toutes les règles obligatoires pour continuer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: Colors.red[400]),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _peutConfirmer
                          ? () => widget.onConfirmer(_acceptees.toList())
                          : null,
                      child: const Text('Confirmer et envoyer la demande'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}