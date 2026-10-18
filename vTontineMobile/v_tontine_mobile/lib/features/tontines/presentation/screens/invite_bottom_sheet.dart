// ─── invite_bottom_sheet.dart ─────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/tontine_repository.dart';
import '../../data/models/tontine_model.dart';

class InviteBottomSheet extends StatefulWidget {
  final TontineModel tontine;
  final List<ParticipantModel> participants;

  const InviteBottomSheet({
    super.key,
    required this.tontine,
    required this.participants,
  });

  @override
  State<InviteBottomSheet> createState() => _InviteBottomSheetState();
}

class _InviteBottomSheetState extends State<InviteBottomSheet> {
  final _repo = TontineRepository();
  final _telCtrl = TextEditingController();

  int _ongletActif = 0; // ← remplace TabController

  bool _chargementLien = false;
  bool _chargementRecherche = false;
  bool _chargementInvitation = false;
  String? _lienPartage;
  Map<String, dynamic>? _userTrouve;
  String? _erreurRecherche;

  @override
  void dispose() {
    _telCtrl.dispose();
    super.dispose();
  }

  // ─── Scénario 1 : Lien de partage ────────────────────────────────────────

  Future<void> _genererLien() async {
    setState(() => _chargementLien = true);
    try {
      final result = await _repo.genererLienInvitation(widget.tontine.id);
      setState(() => _lienPartage = result['lien_web']);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _chargementLien = false);
    }
  }

  Future<void> _partagerLien() async {
    if (_lienPartage == null) return;
    final message =
        'Bonjour 👋\n'
        'Je vous invite à rejoindre ma tontine "${widget.tontine.nom}" sur vTontine.\n\n'
        '👉 Pour adhérer, ouvrez ce lien : $_lienPartage\n\n'
        "Pas encore l'application ? Téléchargez-la ici : ${AppConstants.appDownloadUrl} "
        'puis ouvrez le lien d\'invitation pour rejoindre la tontine.';
    await Share.share(
      message,
      subject: 'Invitation à la tontine ${widget.tontine.nom}',
    );
  }

  Future<void> _copierLien() async {
    if (_lienPartage == null) return;
    await Clipboard.setData(ClipboardData(text: _lienPartage!));
    if (mounted) {
      AppToast.show(context, 'Lien copié !', error: false);
    }
  }

  // ─── Scénario 2 : Recherche par téléphone ────────────────────────────────

  Future<void> _rechercherUser() async {
    final tel = _telCtrl.text.trim();
    if (tel.isEmpty) return;

    setState(() {
      _chargementRecherche = true;
      _userTrouve = null;
      _erreurRecherche = null;
    });

    try {
      final result = await _repo.rechercherUserParTelephone(tel,widget.tontine.id, );
      setState(() {
        if (result['existe'] == true) {
          _userTrouve = result['user'];
        } else {
          _erreurRecherche = 'Aucun compte trouvé avec ce numéro';
        }
      });
    } catch (e) {
      setState(() => _erreurRecherche = 'Erreur lors de la recherche');
    } finally {
      if (mounted) setState(() => _chargementRecherche = false);
    }
  }

  Future<void> _envoyerInvitation() async {
    if (_userTrouve == null) return;
    setState(() => _chargementInvitation = true);
    try {
      await _repo.inviterParTelephone(
        tontineId: widget.tontine.id,
        telephone: _telCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        AppToast.show(context, 'Invitation envoyée à ${_userTrouve!['nom']} ! '
                'Il recevra une notification.', error: false);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _chargementInvitation = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Inviter quelqu\'un',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            // ← Tabs custom (pas de TabBarView)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTabButton(0, Icons.link, 'Partager un lien'),
                  const SizedBox(width: 10),
                  _buildTabButton(1, Icons.person_search, 'Par téléphone'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),

            // ← Contenu selon onglet actif
            Expanded(
              child: _ongletActif == 0
                  ? _buildOngletLien(scrollCtrl)
                  : _buildOngletTelephone(scrollCtrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final actif = _ongletActif == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _ongletActif = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: actif ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: actif ? AppTheme.primary : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: actif ? AppTheme.primary : Colors.grey),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: actif ? FontWeight.w600 : FontWeight.normal,
                    color: actif ? AppTheme.primary : Colors.grey,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Onglet 1 : Lien ─────────────────────────────────────────────────────

  Widget _buildOngletLien(ScrollController scrollCtrl) {
    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Partagez ce lien avec n\'importe qui. '
                'En cliquant, ils pourront rejoindre la tontine '
                'après avoir accepté les règles.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (_lienPartage == null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _chargementLien ? null : _genererLien,
                icon: _chargementLien
                    ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.generating_tokens_outlined),
                label: const Text('Générer le lien'),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_lienPartage!,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppTheme.primary),
                    onPressed: _copierLien,
                    tooltip: 'Copier',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _partagerLien,
                icon: const Icon(Icons.share),
                label: const Text('Partager via WhatsApp / SMS...'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _genererLien,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Générer un nouveau lien'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Ce lien expire dans 7 jours',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Onglet 2 : Téléphone ────────────────────────────────────────────────

  Widget _buildOngletTelephone(ScrollController scrollCtrl) {
    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entrez le numéro d\'un membre de vTontine. '
                'Il recevra une notification pour accepter ou refuser.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // ← Colonne au lieu de Row pour éviter les conflits de contraintes
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '74415998',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                onSubmitted: (_) => _rechercherUser(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _chargementRecherche ? null : _rechercherUser,
                  icon: _chargementRecherche
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: const Text('Rechercher'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_erreurRecherche != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_off_outlined, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_erreurRecherche!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),

          if (_userTrouve != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      (_userTrouve!['nom'] as String).isNotEmpty
                          ? (_userTrouve!['nom'] as String)[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userTrouve!['nom'],
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(_telCtrl.text,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _chargementInvitation ? null : _envoyerInvitation,
                icon: _chargementInvitation
                    ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: const Text('Envoyer l\'invitation'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success),
              ),
            ),
          ],
        ],
      ),
    );
  }
}