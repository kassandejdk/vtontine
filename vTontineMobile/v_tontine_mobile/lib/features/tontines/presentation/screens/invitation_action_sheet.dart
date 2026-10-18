import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/constants/app_theme.dart';
import '../../data/models/tontine_model.dart';
import '../../data/repositories/tontine_repository.dart';

/// Résultat renvoyé par le bottom sheet d'invitation.
enum InvitationResultat { acceptee, refusee, annulee, dejaMembre }

/// Affiche le détail d'une tontine + ses règles, et permet d'accepter
/// (en cochant les règles obligatoires) ou de refuser l'invitation.
///
/// Usage :
///   final res = await showModalBottomSheet<InvitationResultat>(
///     context: context, isScrollControlled: true,
///     builder: (_) => InvitationActionSheet(tontineId: ..., token: ...),
///   );
class InvitationActionSheet extends StatefulWidget {
  final int tontineId;
  final String token;

  const InvitationActionSheet({
    super.key,
    required this.tontineId,
    required this.token,
  });

  @override
  State<InvitationActionSheet> createState() => _InvitationActionSheetState();
}

class _InvitationActionSheetState extends State<InvitationActionSheet> {
  final _repo = TontineRepository();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  TontineModel? _tontine;
  final Set<int> _acceptees = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await _repo.getTontine(widget.tontineId);
      if (mounted) {
        setState(() {
          _tontine = t;
          // Pré-cocher les règles non obligatoires
          _acceptees
              .addAll(t.regles.where((r) => !r.estObligatoire).map((r) => r.id));
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

  bool get _peutAccepter {
    final t = _tontine;
    if (t == null) return false;
    return t.reglesObligatoires.every((r) => _acceptees.contains(r.id));
  }

  Future<void> _accepter() async {
    setState(() => _isSubmitting = true);
    try {
      await _repo.rejoindreViaInvitation(
        token: widget.token,
        reglesAcceptees: _acceptees.toList(),
      );
      if (mounted) Navigator.pop(context, InvitationResultat.acceptee);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.show(context, 'Erreur : $e', error: true);
      }
    }
  }

  Future<void> _refuser() async {
    setState(() => _isSubmitting = true);
    try {
      await _repo.refuserInvitation(widget.token);
      if (mounted) Navigator.pop(context, InvitationResultat.refusee);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.show(context, 'Erreur : $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _isLoading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator()))
            : _error != null
                ? _buildError()
                : _buildContent(scrollCtrl),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
          const SizedBox(height: 12),
          const Text("Impossible de charger l'invitation"),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, InvitationResultat.annulee),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScrollController scrollCtrl) {
    final t = _tontine!;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              const Text('Invitation à rejoindre',
                  style: TextStyle(color: AppTheme.textGrey)),
              Text(t.nom,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _infoLigne('Contribution',
                  '${t.montant.toStringAsFixed(0)} FCFA • ${t.frequenceDisplay}'),
              _infoLigne('Membres',
                  '${t.nbreParticipantsActuels}/${t.nbreParticipant}'),
              _infoLigne('Prise', t.priseDisplay),
              if (t.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(t.description,
                    style: const TextStyle(color: AppTheme.textGrey)),
              ],
              if (t.regles.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Règles et conditions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ...t.regles.map(_regleTile),
              ],
            ],
          ),
        ),
        _buildBoutons(),
      ],
    );
  }

  Widget _infoLigne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textGrey)),
            const Spacer(),
            Flexible(
              child: Text(valeur,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _regleTile(RegleModel r) {
    return CheckboxListTile(
      value: _acceptees.contains(r.id),
      onChanged: (v) => setState(() {
        if (v == true) {
          _acceptees.add(r.id);
        } else {
          _acceptees.remove(r.id);
        }
      }),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(r.titre,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (r.estObligatoire)
            const Text('obligatoire',
                style: TextStyle(color: AppTheme.danger, fontSize: 11)),
        ],
      ),
      subtitle: r.description.isNotEmpty ? Text(r.description) : null,
    );
  }

  Widget _buildBoutons() {
    // Déjà membre → on ne repropose pas d'adhérer (corrige le bug de re-clic).
    if (_tontine?.estMembre == true) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                SizedBox(width: 8),
                Text('Vous êtes déjà membre de cette tontine'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, InvitationResultat.dejaMembre),
                child: const Text('Voir la tontine'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _refuser,
              child: const Text('Refuser',
                  style: TextStyle(color: AppTheme.textGrey)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_isSubmitting || !_peutAccepter) ? null : _accepter,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Accepter et rejoindre'),
            ),
          ),
        ],
      ),
    );
  }
}
