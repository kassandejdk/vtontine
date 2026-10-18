import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/tontine_model.dart';
import '../../data/repositories/tontine_repository.dart';
import 'invitation_action_sheet.dart';

/// Écran d'atterrissage d'un deep link `…/rejoindre/<token>`.
/// Prévisualise la tontine ciblée puis propose d'accepter (avec règles) ou refuser.
class RejoindreScreen extends StatefulWidget {
  final String token;
  const RejoindreScreen({super.key, required this.token});

  @override
  State<RejoindreScreen> createState() => _RejoindreScreenState();
}

class _RejoindreScreenState extends State<RejoindreScreen> {
  final _repo = TontineRepository();

  bool _isLoading = true;
  String? _error;
  TontineModel? _tontine;

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
      final t = await _repo.infosInvitation(widget.token);
      if (mounted) {
        setState(() {
          _tontine = t;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Cette invitation est invalide ou a expiré.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _repondre() async {
    final t = _tontine;
    if (t == null) return;

    // Déjà membre → aller directement au détail
    if (t.estMembre) {
      context.go('/tontines/${t.id}');
      return;
    }

    final res = await showModalBottomSheet<InvitationResultat>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvitationActionSheet(tontineId: t.id, token: widget.token),
    );
    if (!mounted) return;
    if (res == InvitationResultat.acceptee) {
      AppToast.show(context, 'Vous avez rejoint la tontine ! 🎉', error: false);
      context.go('/tontines/${t.id}');
    } else if (res == InvitationResultat.refusee) {
      AppToast.show(context, 'Invitation refusée.', error: false);
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Invitation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildPreview(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, color: AppTheme.danger, size: 56),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text("Retour à l'accueil"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final t = _tontine!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.group_add, color: AppTheme.primary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Vous êtes invité à rejoindre',
              style: TextStyle(color: AppTheme.textGrey)),
          const SizedBox(height: 4),
          Text(t.nom,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _ligne('Contribution',
                    '${t.montant.toStringAsFixed(0)} FCFA • ${t.frequenceDisplay}'),
                const Divider(),
                _ligne('Membres',
                    '${t.nbreParticipantsActuels}/${t.nbreParticipant}'),
                if (t.regles.isNotEmpty) ...[
                  const Divider(),
                  _ligne('Règles', '${t.regles.length} à consulter'),
                ],
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _repondre,
              child: Text(t.estMembre
                  ? 'Voir la tontine'
                  : "Voir les règles et répondre"),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _ligne(String label, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
}
