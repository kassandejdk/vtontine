import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/tontine_model.dart';
import '../../data/repositories/tontine_repository.dart';

class ChatTontineScreen extends StatefulWidget {
  final String tontineId;
  const ChatTontineScreen({super.key, required this.tontineId});

  @override
  State<ChatTontineScreen> createState() => _ChatTontineScreenState();
}

class _ChatTontineScreenState extends State<ChatTontineScreen> {
  final _repo = TontineRepository();
  final _authRepo = AuthRepository();
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();

  final List<MessageModel> _messages = [];
  int _monId = 0;
  bool _isLoading = true;
  bool _envoi = false;
  bool _recording = false;
  bool _recorderPret = false;
  bool _playerPret = false;
  int? _audioEnCours; // id du message audio en lecture
  Timer? _timer;

  int get _id => int.parse(widget.tontineId);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    if (_recorderPret) _recorder.closeRecorder();
    if (_playerPret) _player.closePlayer();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await _authRepo.getCurrentUser();
    _monId = user?.id ?? 0;
    await _recorder.openRecorder();
    await _player.openPlayer();
    _recorderPret = true;
    _playerPret = true;
    await _chargerInitial();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _chargerInitial() async {
    try {
      final msgs = await _repo.getMessages(_id);
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(msgs);
          _isLoading = false;
        });
        _scrollBas();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _poll() async {
    if (_messages.isEmpty) return _chargerInitial();
    try {
      final nouveaux = await _repo.getMessages(_id, after: _messages.last.id);
      if (nouveaux.isNotEmpty && mounted) {
        setState(() => _messages.addAll(nouveaux));
        _scrollBas();
      }
    } catch (_) {}
  }

  Future<void> _envoyerTexte() async {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty) return;
    setState(() => _envoi = true);
    _ctrl.clear();
    try {
      final msg = await _repo.envoyerMessage(_id, texte);
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollBas();
      }
    } catch (e) {
      if (mounted) {
        _ctrl.text = texte;
        _snack('Échec : $e');
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _envoyerMedia(String path, String type) async {
    setState(() => _envoi = true);
    try {
      final msg = await _repo.envoyerMessageMedia(
        tontineId: _id, filePath: path, type: type,
      );
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollBas();
      }
    } catch (e) {
      if (mounted) _snack('Échec de l\'envoi : $e');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _choisirPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Appareil photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final img = await _picker.pickImage(
        source: source, maxWidth: 1280, imageQuality: 80);
    if (img != null) await _envoyerMedia(img.path, 'IMAGE');
  }

  Future<void> _demarrerEnregistrement() async {
    if (!_recorderPret) return;
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      _snack('Permission micro refusée');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await _recorder.startRecorder(toFile: path, codec: Codec.aacMP4);
    setState(() => _recording = true);
  }

  Future<void> _arreterEnvoyer() async {
    final path = await _recorder.stopRecorder();
    setState(() => _recording = false);
    if (path != null) await _envoyerMedia(path, 'AUDIO');
  }

  Future<void> _annulerEnregistrement() async {
    await _recorder.stopRecorder();
    setState(() => _recording = false);
  }

  Future<void> _toggleAudio(MessageModel m) async {
    if (!_playerPret) return;
    if (_audioEnCours == m.id) {
      await _player.stopPlayer();
      setState(() => _audioEnCours = null);
    } else {
      if (_player.isPlaying) await _player.stopPlayer();
      await _player.startPlayer(
        fromURI: m.pieceJointe!,
        codec: Codec.aacMP4,
        whenFinished: () {
          if (mounted) setState(() => _audioEnCours = null);
        },
      );
      setState(() => _audioEnCours = m.id);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg, error: true);
  }

  void _scrollBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _heure(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final l = d.toLocal();
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(l.hour)}:${deux(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Discussion', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tontines/${widget.tontineId}'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Aucun message. Lancez la discussion !',
                            style: TextStyle(color: AppTheme.textGrey)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) => _bulle(_messages[i]),
                      ),
          ),
          _recording ? _barreEnregistrement() : _barreSaisie(),
        ],
      ),
    );
  }

  Widget _bulle(MessageModel m) {
    final estMoi = m.auteurId == _monId;
    return Align(
      alignment: estMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: estMoi ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              estMoi ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!estMoi)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(m.auteurNom,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
              ),
            _contenuBulle(m, estMoi),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(_heure(m.dateEnvoi),
                  style: TextStyle(
                      fontSize: 10,
                      color: estMoi ? Colors.white70 : AppTheme.textGrey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenuBulle(MessageModel m, bool estMoi) {
    if (m.estImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          m.pieceJointe!,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, progress) => progress == null
              ? child
              : const SizedBox(
                  width: 220,
                  height: 160,
                  child: Center(child: CircularProgressIndicator())),
          errorBuilder: (c, e, s) => const SizedBox(
              width: 220,
              height: 100,
              child: Icon(Icons.broken_image, color: AppTheme.textGrey)),
        ),
      );
    }
    if (m.estAudio) {
      final enLecture = _audioEnCours == m.id;
      return SizedBox(
        width: 180,
        child: Row(
          children: [
            InkWell(
              onTap: () => _toggleAudio(m),
              child: Icon(
                enLecture ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: estMoi ? Colors.white : AppTheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.graphic_eq,
                color: estMoi ? Colors.white70 : AppTheme.textGrey),
            const SizedBox(width: 6),
            Text('Note vocale',
                style: TextStyle(
                    fontSize: 12,
                    color: estMoi ? Colors.white : AppTheme.textDark)),
          ],
        ),
      );
    }
    // Texte
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(m.contenu,
          style: TextStyle(color: estMoi ? Colors.white : AppTheme.textDark)),
    );
  }

  Widget _barreSaisie() {
    final aDuTexte = _ctrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined, color: AppTheme.primary),
            onPressed: _envoi ? null : _choisirPhoto,
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Votre message...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _envoyerTexte(),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            backgroundColor: AppTheme.primary,
            child: IconButton(
              icon: _envoi
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(aDuTexte ? Icons.send : Icons.mic, color: Colors.white),
              onPressed: _envoi
                  ? null
                  : (aDuTexte ? _envoyerTexte : _demarrerEnregistrement),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barreEnregistrement() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
            tooltip: 'Annuler',
            onPressed: _annulerEnregistrement,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.fiber_manual_record, color: AppTheme.danger, size: 14),
          const SizedBox(width: 8),
          const Expanded(child: Text('Enregistrement en cours...')),
          CircleAvatar(
            backgroundColor: AppTheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              tooltip: 'Envoyer',
              onPressed: _arreterEnvoyer,
            ),
          ),
        ],
      ),
    );
  }
}
