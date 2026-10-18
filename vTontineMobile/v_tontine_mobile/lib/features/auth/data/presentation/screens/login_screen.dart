import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_theme.dart';
import '../../repositories/auth_repository.dart';


final _authRepo = AuthRepository();

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _telephoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _telephoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authRepo.login(_telephoneCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Téléphone ou mot de passe incorrect', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo / Titre
                Center(
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', width: 110, height: 110),
                      const SizedBox(height: 16),
                      Text(
                        'vTontine',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connectez-vous à votre compte',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Champ téléphone
                Text('Numéro de téléphone',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _telephoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '74415998',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Entrez votre numéro' : null,
                ),

                const SizedBox(height: 20),

                // Champ mot de passe
                Text('Mot de passe',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Entrez votre mot de passe' : null,
                ),

                const SizedBox(height: 32),

                // Bouton connexion
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Se connecter'),
                ),

                const SizedBox(height: 24),

                // Lien inscription
                Center(
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.register),
                    child: RichText(
                      text: TextSpan(
                        text: "Pas encore de compte ? ",
                        style: TextStyle(color: AppTheme.textGrey),
                        children: [
                          TextSpan(
                            text: "S'inscrire",
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }
}