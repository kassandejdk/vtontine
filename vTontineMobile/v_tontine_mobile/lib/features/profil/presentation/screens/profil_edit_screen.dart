import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';

class ProfilEditScreen extends StatefulWidget {
  const ProfilEditScreen({super.key});

  @override
  State<ProfilEditScreen> createState() => _ProfilEditScreenState();
}

class _ProfilEditScreenState extends State<ProfilEditScreen> {
  final _authRepo = AuthRepository();
  final _picker = ImagePicker();

  UserModel? _user;
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  String _genre = 'H';
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await _authRepo.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _user = user;
        _nomCtrl.text = user.nom;
        _prenomCtrl.text = user.prenom;
        _genre = user.genre == 'F' ? 'F' : 'H';
      });
    }
  }

  Future<void> _changerPhoto() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (img == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final user = await _authRepo.uploadPhoto(img.path);
      if (mounted) {
        setState(() => _user = user);
        AppToast.show(context, 'Photo mise à jour', error: false);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erreur photo : $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_nomCtrl.text.trim().isEmpty || _prenomCtrl.text.trim().isEmpty) {
      AppToast.show(context, 'Nom et prénom sont requis', error: false);
      return;
    }
    setState(() => _saving = true);
    try {
      await _authRepo.updateProfil(
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        genre: _genre,
      );
      if (mounted) {
        AppToast.show(context, 'Profil mis à jour', error: false);
        context.go(AppRoutes.profil);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, 'Erreur : $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initiale = _prenomCtrl.text.isNotEmpty
        ? _prenomCtrl.text[0].toUpperCase()
        : 'U';
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Modifier le profil',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.profil),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppTheme.primary.withOpacity(0.15),
                  backgroundImage: (_user?.photo != null)
                      ? CachedNetworkImageProvider(_user!.photo!)
                      : null,
                  child: (_user?.photo == null)
                      ? Text(initiale,
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary))
                      : null,
                ),
                GestureDetector(
                  onTap: _uploadingPhoto ? null : _changerPhoto,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _uploadingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _uploadingPhoto ? null : _changerPhoto,
              child: const Text('Changer la photo'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _prenomCtrl,
            decoration: const InputDecoration(labelText: 'Prénom'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nomCtrl,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _genre,
            decoration: const InputDecoration(labelText: 'Genre'),
            items: const [
              DropdownMenuItem(value: 'H', child: Text('Homme')),
              DropdownMenuItem(value: 'F', child: Text('Femme')),
            ],
            onChanged: (v) => setState(() => _genre = v ?? 'H'),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
