import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _authRepo = AuthRepository();
  UserModel? _user;
  String _fullName = 'Chargement...';
  String _telephone = '';
  bool _notifPush = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authRepo.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _user = user;
        _fullName = '${user.prenom} ${user.nom}';
        _telephone = user.telephone;
      });
    }
    // Rafraîchit depuis le serveur (récupère notamment le flag admin).
    final fresh = await _authRepo.refreshCurrentUser();
    if (fresh != null && mounted) {
      setState(() {
        _user = fresh;
        _fullName = '${fresh.prenom} ${fresh.nom}';
        _telephone = fresh.telephone;
      });
    }
  }

  void _editProfil() => context.go(AppRoutes.profilEdit);

  Future<void> _changePassword() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(authRepo: _authRepo),
    );
    if (ok == true && mounted) {
      AppToast.show(context, 'Mot de passe modifié', error: false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _authRepo.logout();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Avatar
            GestureDetector(
              onTap: _editProfil,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    backgroundImage: (_user?.photo != null)
                        ? NetworkImage(_user!.photo!)
                        : null,
                    child: (_user?.photo == null)
                        ? Text(
                            _fullName.isNotEmpty ? _fullName[0] : 'U',
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary),
                          )
                        : null,
                  ),
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(_fullName,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_telephone,
                style: const TextStyle(color: AppTheme.textGrey)),

            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: _editProfil,
                child: const Text('Modifier le profil'),
              ),
            ),

            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('PARAMÈTRES DU COMPTE',
                    style: TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
            ),

            _buildSettingRow(
              icon: Icons.person_outline,
              label: 'Informations personnelles',
              onTap: _editProfil,
            ),
            _buildSettingRow(
              icon: Icons.notifications_outlined,
              label: 'Notifications push',
              trailing: Switch(
                value: _notifPush,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _notifPush = v),
              ),
            ),
            _buildSettingRow(
              icon: Icons.lock_outline,
              label: 'Changer le mot de passe',
              onTap: _changePassword,
            ),

            // Réservé aux administrateurs plateforme.
            if (_user?.isAdmin == true) ...[
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ADMINISTRATION',
                      style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
              ),
              _buildSettingRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Espace admin',
                onTap: () => context.go(AppRoutes.adminDashboard),
              ),
            ],

            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _logout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout, color: AppTheme.danger),
                      SizedBox(width: 8),
                      Text('Se déconnecter',
                          style: TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('version 1.5.6',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        onTap: (i) {
          switch (i) {
            case 0: context.go(AppRoutes.home); break;
            case 1: context.go(AppRoutes.tontines); break;
            case 2: context.go(AppRoutes.notifications); break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textGrey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Tontines'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Activité'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: trailing ?? (onTap != null
            ? const Icon(Icons.chevron_right, color: AppTheme.textGrey)
            : null),
        onTap: onTap,
      ),
    );
  }
}

/// Bottom sheet de changement de mot de passe.
class _ChangePasswordSheet extends StatefulWidget {
  final AuthRepository authRepo;
  const _ChangePasswordSheet({required this.authRepo});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_newCtrl.text.length < 8) {
      setState(() => _error = 'Le nouveau mot de passe doit faire au moins 8 caractères.');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.authRepo.changePassword(
        current: _currentCtrl.text,
        nouveau: _newCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Mot de passe actuel incorrect ou erreur serveur.';
        });
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
            const Text('Changer le mot de passe',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmer le nouveau'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            ],
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
                    : const Text('Modifier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}