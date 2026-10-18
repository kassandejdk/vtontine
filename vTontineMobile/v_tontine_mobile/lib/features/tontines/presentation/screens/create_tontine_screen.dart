import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/tontine_repository.dart';

// ─── Modèle local pour une règle en cours de saisie ──────────────────────────
class _RegleLocale {
  final TextEditingController titreCtrl;
  final TextEditingController descCtrl;
  String categorie;
  bool estObligatoire;

  _RegleLocale()
      : titreCtrl = TextEditingController(),
        descCtrl = TextEditingController(),
        categorie = 'ADHESION',
        estObligatoire = true;

  void dispose() {
    titreCtrl.dispose();
    descCtrl.dispose();
  }
}

class CreateTontineScreen extends StatefulWidget {
  const CreateTontineScreen({super.key});

  @override
  State<CreateTontineScreen> createState() => _CreateTontineScreenState();
}

class _CreateTontineScreenState extends State<CreateTontineScreen> {
  final _pageCtrl = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;
  final _repo = TontineRepository();

  // ── Étape 1 : Infos générales ──
  final _formKey1 = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _visibilite = true;
  bool _createurEstMembre = false;

  // ── Étape 2 : Fréquence & participants ──
  final _formKey2 = GlobalKey<FormState>();
  final _participantsCtrl = TextEditingController();
  final _frequenceValeurCtrl = TextEditingController(text: '1');
  String _frequenceType = 'MOIS';

  final _frequenceTypes = [
    {'value': 'JOUR', 'label': 'Jour(s)'},
    {'value': 'SEMAINE', 'label': 'Semaine(s)'},
    {'value': 'MOIS', 'label': 'Mois'},
  ];

  // ── Étape 3 : Montant & prise ──
  final _formKey3 = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  String _typePrise = 'ARGENT';
  final _montantPriseCtrl = TextEditingController();
  final _descProduitCtrl = TextEditingController();
  final _valeurEstimeeCtrl = TextEditingController();

  final _typesPrise = [
    {'value': 'ARGENT', 'label': 'Argent', 'icon': Icons.payments_outlined},
    {'value': 'PRODUIT', 'label': 'Produit', 'icon': Icons.inventory_2_outlined},
    {'value': 'MIXTE', 'label': 'Mixte', 'icon': Icons.swap_horiz},
  ];

  // ── Étape 4 : Règles intérieures ──
  final List<_RegleLocale> _regles = [];

  final _categories = [
    {'value': 'ADHESION', 'label': "Critère d'adhésion"},
    {'value': 'COMPORTEMENT', 'label': 'Comportement'},
    {'value': 'FINANCIER', 'label': 'Financier'},
    {'value': 'AUTRE', 'label': 'Autre'},
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _participantsCtrl.dispose();
    _frequenceValeurCtrl.dispose();
    _montantCtrl.dispose();
    _montantPriseCtrl.dispose();
    _descProduitCtrl.dispose();
    _valeurEstimeeCtrl.dispose();
    for (final r in _regles) r.dispose();
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  GlobalKey<FormState>? get _currentFormKey => switch (_currentStep) {
    0 => _formKey1,
    1 => _formKey2,
    2 => _formKey3,
    _ => null,
  };

  void _nextStep() {
    if (_currentFormKey != null && !_currentFormKey!.currentState!.validate()) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ─── Soumission finale ───────────────────────────────────────────────────────

  Future<void> _soumettre() async {
    setState(() => _isLoading = true);
    try {
      final regles = _regles
          .where((r) => r.titreCtrl.text.trim().isNotEmpty)
          .map((r) => {
        'titre': r.titreCtrl.text.trim(),
        'description': r.descCtrl.text.trim(),
        'categorie': r.categorie,
        'est_obligatoire': r.estObligatoire,
        'ordre': _regles.indexOf(r),
      })
          .toList();

      final tontine = await _repo.creerTontine(
        nom: _nomCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        visibilite: _visibilite,
        createurEstMembre: _createurEstMembre,
        frequenceValeur: int.parse(_frequenceValeurCtrl.text),
        frequenceType: _frequenceType,
        nbreParticipant: int.parse(_participantsCtrl.text),
        montant: double.parse(_montantCtrl.text),
        typePrise: _typePrise,
        montantPrise: _montantPriseCtrl.text.isNotEmpty
            ? double.tryParse(_montantPriseCtrl.text)
            : null,
        descriptionProduitPrise: _descProduitCtrl.text.trim(),
        valeurEstimeeProduit: _valeurEstimeeCtrl.text.isNotEmpty
            ? double.tryParse(_valeurEstimeeCtrl.text)
            : null,
        regles: regles,
      );

      if (mounted) {
        AppToast.show(context, 'Tontine créée avec succès ! ✓', error: false);
        context.go('/tontines/${tontine.id}');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une tontine'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _currentStep == 0 ? context.go(AppRoutes.home) : _prevStep(),
        ),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ─── Indicateur de progression ───────────────────────────────────────────────

  Widget _buildStepper() {
    final labels = ['Général', 'Fréquence', 'Prise', 'Règles'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDone || isActive
                              ? AppTheme.primary
                              : AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? AppTheme.primary
                              : isDone
                              ? AppTheme.textDark
                              : AppTheme.textDark.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < _totalSteps - 1) const SizedBox(width: 6),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─── Barre de navigation bas ─────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _prevStep,
                child: const Text('Retour'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : (isLast ? _soumettre : _nextStep),
              child: _isLoading
                  ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isLast ? 'Créer la tontine' : 'Suivant'),
                  const SizedBox(width: 8),
                  Icon(isLast ? Icons.check : Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Étape 1 : Infos générales ───────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('NOM DE LA TONTINE'),
            TextFormField(
              controller: _nomCtrl,
              decoration: const InputDecoration(hintText: 'Ex: Wend kunni'),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),

            const SizedBox(height: 20),
            _label('DESCRIPTION (optionnel)'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Décrivez l\'objectif de cette tontine...',
              ),
            ),

            const SizedBox(height: 24),
            _label('VISIBILITÉ'),
            _buildToggleCard(
              icon: _visibilite ? Icons.public : Icons.lock_outline,
              title: _visibilite ? 'Tontine publique' : 'Tontine privée',
              subtitle: _visibilite
                  ? 'Visible dans la liste publique, tout le monde peut faire une demande'
                  : 'Accessible uniquement via invitation',
              value: _visibilite,
              onChanged: (v) => setState(() => _visibilite = v),
            ),

            const SizedBox(height: 16),
            _label('VOTRE PARTICIPATION'),
            _buildToggleCard(
              icon: _createurEstMembre
                  ? Icons.person_add_alt_1
                  : Icons.manage_accounts_outlined,
              title: _createurEstMembre
                  ? 'Vous êtes membre actif'
                  : 'Vous gérez sans participer',
              subtitle: _createurEstMembre
                  ? 'Vous serez compté parmi les participants et recevrez une prise'
                  : 'Vous administrez la tontine sans y cotiser',
              value: _createurEstMembre,
              onChanged: (v) => setState(() => _createurEstMembre = v),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Étape 2 : Fréquence & participants ──────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('NOMBRE DE PARTICIPANTS'),
            TextFormField(
              controller: _participantsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Nombre (min. 2)'),
              validator: (v) {
                if (v!.isEmpty) return 'Requis';
                final n = int.tryParse(v);
                if (n == null || n < 2) return 'Minimum 2 participants';
                return null;
              },
            ),

            const SizedBox(height: 24),
            _label('FRÉQUENCE DE COTISATION'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CHAQUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _frequenceValeurCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return '?';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PÉRIODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _frequenceType,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: _frequenceTypes
                            .map((f) => DropdownMenuItem(
                          value: f['value'],
                          child: Text(f['label']!,
                              overflow: TextOverflow.ellipsis),
                        ))
                            .toList(),
                        onChanged: (v) => setState(() => _frequenceType = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cotisation tous les ${_frequenceValeurCtrl.text.isEmpty ? '?' : _frequenceValeurCtrl.text} '
                          '${_frequenceTypes.firstWhere((f) => f['value'] == _frequenceType)['label']}',
                      style: const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.w600),
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

  // ─── Étape 3 : Montant & prise ───────────────────────────────────────────────

  Widget _buildStep3() {
    final needArgent = _typePrise == 'ARGENT' || _typePrise == 'MIXTE';
    final needProduit = _typePrise == 'PRODUIT' || _typePrise == 'MIXTE';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('MONTANT DE LA COTISATION (FCFA)'),
            TextFormField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                suffixText: 'FCFA',
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Requis';
                if (double.tryParse(v) == null || double.parse(v) <= 0)
                  return 'Montant invalide';
                return null;
              },
            ),

            const SizedBox(height: 24),
            _label('TYPE DE PRISE'),
            const Text(
              'Ce que reçoit le bénéficiaire à chaque tour',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              children: _typesPrise.map((t) {
                final selected = _typePrise == t['value'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _typePrise = t['value'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                          right: t['value'] != 'MIXTE' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(t['icon'] as IconData,
                              color: selected ? Colors.white : AppTheme.primary,
                              size: 22),
                          const SizedBox(height: 6),
                          Text(t['label'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textDark)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Champs conditionnels selon le type de prise
            if (needArgent) ...[
              const SizedBox(height: 20),
              _label('MONTANT DE LA PRISE (FCFA)'),
              TextFormField(
                controller: _montantPriseCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: 'FCFA',
                ),
                validator: (v) {
                  if (!needArgent) return null;
                  if (v!.isEmpty) return 'Requis pour ce type de prise';
                  if (double.tryParse(v) == null || double.parse(v) <= 0)
                    return 'Montant invalide';
                  return null;
                },
              ),
            ],

            if (needProduit) ...[
              const SizedBox(height: 20),
              _label('DESCRIPTION DU PRODUIT'),
              TextFormField(
                controller: _descProduitCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Ex: 6 pagnes wax, 1 sac de riz 50kg...',
                ),
                validator: (v) {
                  if (!needProduit) return null;
                  if (v!.isEmpty) return 'Requis pour ce type de prise';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('VALEUR ESTIMÉE DU PRODUIT (optionnel)'),
              TextFormField(
                controller: _valeurEstimeeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: 'FCFA',
                  prefixIcon: Icon(Icons.calculate_outlined),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Étape 4 : Règles intérieures ────────────────────────────────────────────

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RÈGLES INTÉRIEURES',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Définissez les règles que les membres devront accepter',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textDark.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                // Nouvelle règle en première position
                onPressed: () => setState(() => _regles.insert(0, _RegleLocale())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_regles.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.15),
                    style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.rule_folder_outlined,
                      size: 48, color: AppTheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucune règle définie',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Optionnel — vous pouvez créer la tontine sans règles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textDark.withOpacity(0.5)),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_regles.length, (i) => _buildRegleCard(i)),
        ],
      ),
    );
  }

  Widget _buildRegleCard(int index) {
    final regle = _regles[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primary.withOpacity(0.12),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Règle',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: () => setState(() {
                  regle.dispose();
                  _regles.removeAt(index);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Titre
          TextFormField(
            controller: regle.titreCtrl,
            decoration: const InputDecoration(
              hintText: 'Titre de la règle',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          TextFormField(
            controller: regle.descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Description détaillée...',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Catégorie (pleine largeur)
          DropdownButtonFormField<String>(
            value: regle.categorie,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: _categories
                .map((c) => DropdownMenuItem(
                      value: c['value'],
                      child: Text(c['label']!,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => regle.categorie = v!),
          ),
          const SizedBox(height: 4),
          // Obligatoire (ligne dédiée)
          Row(
            children: [
              const Expanded(
                child: Text('Obligatoire pour rejoindre',
                    style: TextStyle(fontSize: 13)),
              ),
              Switch(
                value: regle.estObligatoire,
                onChanged: (v) => setState(() => regle.estObligatoire = v),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Widgets utilitaires ─────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppTheme.textDark)),
  );

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primary.withOpacity(0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? AppTheme.primary : Colors.grey.withOpacity(0.2),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value
                    ? AppTheme.primary.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: value ? AppTheme.primary : Colors.grey, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: value ? AppTheme.primary : AppTheme.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textDark.withOpacity(0.55))),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}