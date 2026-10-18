import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../paiements/data/models/paiement_model.dart';
import '../../../paiements/data/repositories/paiement_repository.dart';
import '../../data/models/tontine_model.dart';
import '../../data/repositories/tontine_repository.dart';
import 'invite_bottom_sheet.dart';
import 'participant_calendrier_screen.dart';

class GererTontineScreen extends StatefulWidget {
  final String tontineId;
  const GererTontineScreen({super.key, required this.tontineId});

  @override
  State<GererTontineScreen> createState() => _GererTontineScreenState();
}

class _GererTontineScreenState extends State<GererTontineScreen> {
  final _repo = TontineRepository();
  final _paiementRepo = PaiementRepository();

  bool _isLoading = true;
  String? _error;
  TontineModel? _tontine;
  List<DemandeAdhesionModel> _demandes = [];
  List<ParticipantModel> _participants = [];
  List<PaiementModel> _paiements = [];

  int get _id => int.parse(widget.tontineId);

  /// Paiements en attente de confirmation par le créateur.
  List<PaiementModel> get _paiementsAConfirmer =>
      _paiements.where((p) => p.estEnAttente).toList();

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
      // La tontine est critique ; le reste tolère les erreurs (permissions,
      // hoquet réseau) pour ne jamais afficher un écran vide.
      final tontine = await _repo.getTontine(_id);
      List<DemandeAdhesionModel> demandes = [];
      List<ParticipantModel> participants = [];
      List<PaiementModel> paiements = [];
      try { demandes = await _repo.getDemandes(_id); } catch (_) {}
      try { participants = await _repo.getParticipants(_id); } catch (_) {}
      try { paiements = await _paiementRepo.liste(tontineId: _id); } catch (_) {}

      if (mounted) {
        setState(() {
          _tontine = tontine;
          _demandes = demandes;
          _participants = participants;
          _paiements = paiements;
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

  Future<void> _confirmerPaiement(PaiementModel p) async {
    try {
      await _paiementRepo.confirmer(p.id);
      _snack('Paiement confirmé');
      await _load();
    } catch (e) {
      _snack('Erreur : $e', error: true);
    }
  }

  Future<void> _refuserPaiement(PaiementModel p) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser ce paiement ?'),
        content: Text(
          '${p.montant.toStringAsFixed(0)} FCFA de '
          '${p.participantNom.isEmpty ? "ce membre" : p.participantNom}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Refuser',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _paiementRepo.refuser(p.id);
      _snack('Paiement refusé');
      await _load();
    } catch (e) {
      _snack('Erreur : $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    AppToast.show(context, msg, error: error);
  }

  Future<void> _traiterDemande(DemandeAdhesionModel d, bool accepter) async {
    try {
      await _repo.traiterDemande(d.id, accepter);
      _snack(accepter ? 'Demande acceptée' : 'Demande refusée');
      await _load();
    } catch (e) {
      _snack('Erreur : $e', error: true);
    }
  }

  Future<void> _exclure(ParticipantModel p) async {
    final motifCtrl = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Exclure ${p.fullName} ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cette personne ne fera plus partie de la tontine.'),
            const SizedBox(height: 12),
            TextField(
              controller: motifCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exclure', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _repo.exclureParticipant(
        tontineId: _id,
        participationId: p.id,
        motif: motifCtrl.text.trim(),
      );
      _snack('${p.fullName} a été exclu(e)');
      await _load();
    } catch (e) {
      _snack('Erreur : $e', error: true);
    }
  }

  Future<void> _terminer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la tontine ?'),
        content: const Text(
            'Cette action est définitive : la tontine sera clôturée. '
            'Elle n\'est possible que si toutes les prises ont été versées '
            'aux bénéficiaires.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _repo.terminer(_id);
      _snack('Tontine terminée');
      await _load();
    } catch (e) {
      _snack(messageErreur(e), error: true);
    }
  }

  Future<void> _inviter() async {
    if (_tontine == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteBottomSheet(
        tontine: _tontine!,
        participants: _participants,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Gérer la tontine',
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
    if (_error != null || _tontine == null) {
      return _buildErreur();
    }
    // `stretch` donne à chaque section une largeur bornée (tight) : sans ça,
    // une largeur infinie remonte jusqu'aux Row internes (bouton + Expanded)
    // et le layout plante.
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPaiementsAConfirmer(),
            _buildDemandes(),
            const SizedBox(height: 24),
            _buildParticipants(),
            const SizedBox(height: 24),
            _buildRegles(),
            const SizedBox(height: 24),
            _buildMethodesPaiement(),
            const SizedBox(height: 24),
            _buildActions(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {int? badge}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          // min : sinon, imbriqué dans un Row (sections avec bouton « Ajouter »),
          // la contrainte de largeur devient infinie et le layout plante.
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (badge != null && badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ],
        ),
      );

  Widget _buildPaiementsAConfirmer() {
    final aConfirmer = _paiementsAConfirmer;
    if (aConfirmer.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Paiements à confirmer', badge: aConfirmer.length),
        ...aConfirmer.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule, color: AppTheme.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.participantNom.isEmpty ? 'Membre' : p.participantNom,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('${p.montant.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                                color: AppTheme.textGrey, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _refuserPaiement(p),
                    tooltip: 'Refuser',
                    icon: const Icon(Icons.close, color: AppTheme.danger),
                  ),
                  ElevatedButton(
                    onPressed: () => _confirmerPaiement(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // Le thème impose minimumSize.width = ∞ (bouton pleine
                      // largeur). Dans une Row mesurée sans borne, ça force une
                      // largeur infinie → crash. On le rend compact ici.
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Confirmer'),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDemandes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Demandes d'adhésion", badge: _demandes.length),
        if (_demandes.isEmpty)
          _emptyCard('Aucune demande en attente')
        else
          ..._demandes.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(d.telephone,
                                  style: const TextStyle(
                                      color: AppTheme.textGrey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (d.message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(d.message,
                          style: const TextStyle(
                              fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _traiterDemande(d, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success),
                            child: const Text('Accepter'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _traiterDemande(d, false),
                            child: const Text('Refuser',
                                style: TextStyle(color: AppTheme.textGrey)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildParticipants() {
    final actifs = _participants.where((p) => p.statut != 'EXCLU').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Participants', badge: actifs.length),
        if (actifs.isEmpty)
          _emptyCard('Aucun participant pour le moment')
        else
          ...actifs.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    if (p.ordrePrise != null)
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 10),
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
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _ouvrirCalendrier(p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                      p.fullName.isEmpty ? p.telephone : p.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.calendar_today_outlined,
                                    size: 13, color: AppTheme.textGrey),
                              ],
                            ),
                            Text(
                              p.estCreateur ? 'Créateur' : p.statutDisplay,
                              style: const TextStyle(
                                  color: AppTheme.textGrey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_vert,
                          color: AppTheme.textGrey, size: 20),
                      tooltip: "Modifier l'ordre de passage",
                      onPressed: () => _modifierOrdre(p),
                    ),
                    if (!p.estCreateur)
                      IconButton(
                        icon: const Icon(Icons.person_remove_outlined,
                            color: AppTheme.danger, size: 20),
                        tooltip: 'Exclure',
                        onPressed: () => _exclure(p),
                      ),
                  ],
                ),
              )),
      ],
    );
  }

  // ─── Règles ────────────────────────────────────────────────────────────────

  Widget _buildRegles() {
    final regles = _tontine?.regles ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle('Règles', badge: regles.length),
            const Spacer(),
            TextButton.icon(
              onPressed: _ajouterRegle,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        if (regles.isEmpty)
          _emptyCard('Aucune règle définie')
        else
          ...regles.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(r.titre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              if (r.estObligatoire) ...[
                                const SizedBox(width: 6),
                                const Text('obligatoire',
                                    style: TextStyle(
                                        color: AppTheme.danger, fontSize: 11)),
                              ],
                            ],
                          ),
                          if (r.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(r.description,
                                style: const TextStyle(
                                    color: AppTheme.textGrey, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.danger, size: 20),
                      tooltip: 'Supprimer',
                      onPressed: () => _supprimerRegle(r),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Future<void> _ajouterRegle() async {
    final ajoutee = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AjouterRegleSheet(tontineId: _id, repo: _repo),
    );
    if (ajoutee == true) await _load();
  }

  Future<void> _supprimerRegle(RegleModel r) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la règle ?'),
        content: Text('« ${r.titre} »'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _repo.supprimerRegle(_id, r.id);
      _snack('Règle supprimée');
      await _load();
    } catch (e) {
      _snack('Erreur : $e', error: true);
    }
  }

  Future<void> _modifierTontine() async {
    final t = _tontine;
    if (t == null) return;
    final maj = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTontineSheet(tontine: t, repo: _repo),
    );
    if (maj == true) {
      _snack('Tontine mise à jour');
      await _load();
    }
  }

  void _ouvrirCalendrier(ParticipantModel p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ParticipantCalendrierScreen(
        tontineId: _id,
        participationId: p.id,
        participantNom: p.fullName.isEmpty ? p.telephone : p.fullName,
      ),
    ));
  }

  Future<void> _modifierOrdre(ParticipantModel p) async {
    final ctrl = TextEditingController(
        text: p.ordrePrise?.toString() ?? '');
    final ordre = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ordre de passage — ${p.fullName}',
            style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Position (≥ 1)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 1) Navigator.pop(ctx, v);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (ordre == null) return;
    try {
      await _repo.modifierOrdre(
          tontineId: _id, participationId: p.id, ordre: ordre);
      _snack('Ordre mis à jour');
      await _load();
    } catch (e) {
      _snack('Erreur : $e', error: true);
    }
  }

  // ─── Moyens de paiement ──────────────────────────────────────────────────────

  Widget _buildMethodesPaiement() {
    final methodes = _tontine?.methodesPaiement ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle('Moyens de paiement', badge: methodes.length),
            const Spacer(),
            TextButton.icon(
              onPressed: _ajouterMethode,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        Text(
          'Définis comment les membres te paient (code USSD Mobile Money avec ton numéro). '
          'Utilise {montant} pour le montant.',
          style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
        ),
        const SizedBox(height: 10),
        if (methodes.isEmpty)
          _emptyCard('Aucun moyen de paiement défini')
        else
          ...methodes.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.dialpad, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.libelle,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(m.codeUssd,
                              style: const TextStyle(
                                  color: AppTheme.textGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.danger, size: 20),
                      onPressed: () => _supprimerMethode(m),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Future<void> _ajouterMethode() async {
    final ajoutee = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AjouterMethodeSheet(tontineId: _id, repo: _repo),
    );
    if (ajoutee == true) await _load();
  }

  Future<void> _supprimerMethode(MethodePaiementModel m) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce moyen de paiement ?'),
        content: Text(m.libelle),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _repo.supprimerMethodePaiement(_id, m.id);
      _snack('Moyen de paiement supprimé');
      await _load();
    } catch (e) {
      _snack('Erreur : $e', error: true);
    }
  }

  Widget _buildActions() {
    final t = _tontine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Actions'),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _modifierTontine,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier la tontine'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _inviter,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Inviter quelqu\'un'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/tontines/${widget.tontineId}/cycles'),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Suivi des cycles'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/tontines/${widget.tontineId}/paiements'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Historique des paiements'),
          ),
        ),
        const SizedBox(height: 10),
        if (t != null && !t.estTermine)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _terminer,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Terminer la tontine'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            ),
          ),
      ],
    );
  }

  Widget _buildErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            const Text('Impossible de charger la tontine',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Center(
          child: Text(text, style: const TextStyle(color: AppTheme.textGrey)),
        ),
      );
}

/// Bottom sheet d'édition des champs légers d'une tontine.
class _EditTontineSheet extends StatefulWidget {
  final TontineModel tontine;
  final TontineRepository repo;
  const _EditTontineSheet({required this.tontine, required this.repo});

  @override
  State<_EditTontineSheet> createState() => _EditTontineSheetState();
}

class _EditTontineSheetState extends State<_EditTontineSheet> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descCtrl;
  late bool _visibilite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.tontine.nom);
    _descCtrl = TextEditingController(text: widget.tontine.description);
    _visibilite = widget.tontine.visibilite;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom est requis')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.modifier(widget.tontine.id, {
        'nom': _nomCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'visibilite': _visibilite,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modifier la tontine',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nomCtrl,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible publiquement'),
              subtitle: const Text('Apparaît dans « Découvrir »'),
              value: _visibilite,
              onChanged: (v) => setState(() => _visibilite = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet d'ajout d'une règle.
class _AjouterRegleSheet extends StatefulWidget {
  final int tontineId;
  final TontineRepository repo;
  const _AjouterRegleSheet({required this.tontineId, required this.repo});

  @override
  State<_AjouterRegleSheet> createState() => _AjouterRegleSheetState();
}

class _AjouterRegleSheetState extends State<_AjouterRegleSheet> {
  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _categorie = 'ADHESION';
  bool _obligatoire = true;
  bool _saving = false;

  static const _categories = {
    'ADHESION': "Critère d'adhésion",
    'COMPORTEMENT': 'Règle de comportement',
    'FINANCIER': 'Règle financière',
    'AUTRE': 'Autre',
  };

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titreCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titre et description sont requis')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.ajouterRegle(
        tontineId: widget.tontineId,
        titre: _titreCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        categorie: _categorie,
        estObligatoire: _obligatoire,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter une règle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _titreCtrl,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categorie,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: _categories.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _categorie = v ?? 'ADHESION'),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obligatoire'),
              subtitle: const Text('Doit être acceptée pour rejoindre'),
              value: _obligatoire,
              onChanged: (v) => setState(() => _obligatoire = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Ajouter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet d'ajout d'un moyen de paiement (libellé + code USSD).
class _AjouterMethodeSheet extends StatefulWidget {
  final int tontineId;
  final TontineRepository repo;
  const _AjouterMethodeSheet({required this.tontineId, required this.repo});

  @override
  State<_AjouterMethodeSheet> createState() => _AjouterMethodeSheetState();
}

class _AjouterMethodeSheetState extends State<_AjouterMethodeSheet> {
  final _libelleCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_libelleCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Libellé et code USSD sont requis')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.ajouterMethodePaiement(
        tontineId: widget.tontineId,
        libelle: _libelleCtrl.text.trim(),
        codeUssd: _codeCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter un moyen de paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _libelleCtrl,
              decoration: const InputDecoration(
                labelText: 'Libellé',
                hintText: 'Orange Money',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code USSD',
                hintText: '*144*10*70000000*{montant}#',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mets ton numéro dans le code. {montant} sera remplacé automatiquement.',
              style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Ajouter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
