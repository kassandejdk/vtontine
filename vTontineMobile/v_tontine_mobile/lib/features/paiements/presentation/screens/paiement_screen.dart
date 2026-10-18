import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../tontines/data/models/tontine_model.dart';
import '../../../tontines/data/repositories/tontine_repository.dart';
import '../../data/repositories/paiement_repository.dart';

class PaiementScreen extends StatefulWidget {
  final String tontineId;
  const PaiementScreen({super.key, required this.tontineId});

  @override
  State<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends State<PaiementScreen> {
  final _tontineRepo = TontineRepository();
  final _paiementRepo = PaiementRepository();
  final _authRepo = AuthRepository();

  bool _isLoading = false;      // pendant l'envoi
  bool _isLoadingData = true;   // chargement initial
  String? _error;

  TontineModel? _tontine;
  int? _participationId;

  int get _id => int.parse(widget.tontineId);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _error = null;
    });
    try {
      final user = await _authRepo.getCurrentUser();
      final results = await Future.wait([
        _tontineRepo.getTontine(_id),
        _tontineRepo.getParticipants(_id),
      ]);
      final tontine = results[0] as TontineModel;
      final participants = results[1] as List<ParticipantModel>;

      ParticipantModel? maPart;
      for (final p in participants) {
        if (user != null && p.userId == user.id && p.statut == 'CONFIRME') {
          maPart = p;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _tontine = tontine;
          _participationId = maPart?.id;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingData = false;
        });
      }
    }
  }

  /// Lance le code USSD de la méthode choisie puis enregistre le paiement.
  /// Le paiement est enregistré (et le créateur notifié) MÊME si le composeur
  /// ne s'ouvre pas — c'est une tentative de paiement à confirmer par le créateur.
  Future<void> _payerAvec(MethodePaiementModel methode) async {
    if (_participationId == null || _tontine == null) return;
    setState(() => _isLoading = true);

    // 1. Ouvre le composeur avec le code USSD (# encodé en %23) — best effort
    try {
      final ussd = methode.ussdPour(_tontine!.montant);
      final tel = Uri.parse('tel:${ussd.replaceAll('#', '%23')}');
      await launchUrl(tel);
    } catch (_) {
      // On continue : on enregistre quand même la tentative.
    }

    // 2. Enregistre le paiement (en attente de confirmation du créateur)
    try {
      await _paiementRepo.enregistrer(
        participationId: _participationId!,
        montant: _tontine!.montant,
      );
      if (mounted) {
        AppToast.show(context, 'Paiement enregistré ! En attente de confirmation.', error: false);
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur lors de l\'enregistrement : $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payer ma cotisation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tontines/${widget.tontineId}'),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
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
            const Text('Impossible de charger la tontine'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final t = _tontine!;
    final estMembre = _participationId != null;
    final methodes = t.methodesPaiement;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Récap
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.savings, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              const Text('Contribution à', style: TextStyle(color: AppTheme.textGrey)),
              Text(t.nom,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.textDark)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Montant', style: TextStyle(color: AppTheme.textGrey)),
              Text('${t.montant.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: AppTheme.textDark)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!estMembre)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.warning),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Vous devez être membre confirmé pour cotiser.')),
              ],
            ),
          )
        else if (methodes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Le créateur n'a pas encore défini de moyen de paiement. "
                    'Contacte-le pour savoir comment payer.',
                  ),
                ),
              ],
            ),
          )
        else ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Choisissez un moyen de paiement',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          ...methodes.map((m) => _methodeCard(m)),
          const SizedBox(height: 8),
          const Text(
            'Le paiement ouvre le composeur avec le code, puis enregistre ta '
            'cotisation (le créateur la confirmera après réception).',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _methodeCard(MethodePaiementModel m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_forwarded, color: AppTheme.primary),
        ),
        title: Text(m.libelle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(m.ussdPour(_tontine!.montant),
            style: const TextStyle(fontSize: 12)),
        trailing: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right, color: AppTheme.primary),
        onTap: _isLoading ? null : () => _payerAvec(m),
      ),
    );
  }
}
