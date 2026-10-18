import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_theme.dart';
import '../../repositories/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _genre = 'H';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  final _authRepo = AuthRepository();

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telephoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _authRepo.register(
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        telephone: _telephoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        genre: _genre,
      );
      if (mounted) {
        AppToast.show(context, 'Compte créé ! Connectez-vous.', error: false);
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur : $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Prénom', _prenomCtrl, hint: 'Judicael'),
              _field('Nom', _nomCtrl, hint: 'KASSANDE'),
              _field('Téléphone', _telephoneCtrl,
                  hint: '74415998',
                  keyboardType: TextInputType.phone),
              _passwordField(
                label: 'Mot de passe',
                ctrl: _passwordCtrl,
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ requis';
                  if (v.length < 8) return 'Minimum 8 caractères';
                  return null;
                },
              ),
              _passwordField(
                label: 'Confirmer le mot de passe',
                ctrl: _confirmCtrl,
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ requis';
                  if (v != _passwordCtrl.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),
              Text('Genre',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _genreChip('H', 'Homme'),
                  const SizedBox(width: 12),
                  _genreChip('F', 'Femme'),
                ],
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Text("S'inscrire"),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: RichText(
                    text: TextSpan(
                      text: 'Déjà un compte ? ',
                      style: TextStyle(color: AppTheme.textGrey),
                      children: [
                        TextSpan(
                          text: 'Se connecter',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint,
        bool obscure = false,
        TextInputType? keyboardType,
        int? minLength}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Champ requis';
            if (minLength != null && v.length < minLength)
              return 'Minimum $minLength caractères';
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController ctrl,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: onToggle,
            ),
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _genreChip(String value, String label) {
    final selected = _genre == value;
    return GestureDetector(
      onTap: () => setState(() => _genre = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppTheme.primary : const Color(0xFFE0E0E0)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppTheme.textGrey,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}