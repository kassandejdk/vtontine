import 'package:flutter/material.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../tontines/presentation/screens/invitation_action_sheet.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationRepository();

  bool _isLoading = true;
  String? _error;
  List<NotificationModel> _notifications = [];

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
      final notifs = await _repo.liste();
      if (mounted) {
        setState(() {
          _notifications = notifs;
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

  Future<void> _toutMarquer() async {
    try {
      await _repo.marquerToutLu();
      await _load();
    } catch (_) {}
  }

  Future<void> _onTap(NotificationModel n) async {
    // Marquer comme lue (best effort)
    if (!n.estLu) {
      try {
        await _repo.marquerLu(n.id);
      } catch (_) {}
    }
    if (!mounted) return;

    if (n.estInvitation && n.tontineId != null) {
      final res = await showModalBottomSheet<InvitationResultat>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => InvitationActionSheet(
          tontineId: n.tontineId!,
          token: n.invitationToken!,
        ),
      );
      if (res == InvitationResultat.dejaMembre && mounted) {
        context.go('/tontines/${n.tontineId}');
        return;
      }
      if (res == InvitationResultat.acceptee && mounted) {
        AppToast.show(context, 'Vous avez rejoint la tontine ! 🎉', error: false);
      } else if (res == InvitationResultat.refusee && mounted) {
        AppToast.show(context, 'Invitation refusée.', error: false);
      }
      await _load();
    } else if (n.tontineId != null && mounted) {
      context.go('/tontines/${n.tontineId}');
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          TextButton(
            onPressed: _toutMarquer,
            child: const Text('Tout marquer',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
          const SizedBox(height: 12),
          const Center(child: Text('Erreur de chargement')),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ),
        ],
      );
    }
    if (_notifications.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.notifications_none,
              color: AppTheme.primary.withOpacity(0.4), size: 64),
          const SizedBox(height: 16),
          const Center(
            child: Text('Aucune notification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _notifications.length,
      itemBuilder: (ctx, i) => _buildNotifCard(_notifications[i]),
    );
  }

  Widget _buildNotifCard(NotificationModel n) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    if (n.estInvitation) {
      icon = Icons.person_add_outlined;
      iconBg = const Color(0xFFEEF0FC);
      iconColor = const Color(0xFF5B6EE8);
    } else if (n.titre.toLowerCase().contains('paiement')) {
      icon = Icons.account_balance_wallet;
      iconBg = const Color(0xFFE8F8EF);
      iconColor = AppTheme.success;
    } else {
      icon = Icons.info_outline;
      iconBg = const Color(0xFFF5F5F5);
      iconColor = AppTheme.textGrey;
    }

    return GestureDetector(
      onTap: () => _onTap(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.estLu ? Colors.white : const Color(0xFFF6F8FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.titre,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (!n.estLu)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppTheme.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(n.message,
                      style: const TextStyle(
                          color: AppTheme.textGrey, fontSize: 13)),
                  if (n.estInvitation) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.touch_app_outlined,
                            size: 14, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text('Voir les règles et répondre',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 2,
      onTap: (i) {
        switch (i) {
          case 0: context.go(AppRoutes.home); break;
          case 1: context.go(AppRoutes.tontines); break;
          case 3: context.go(AppRoutes.profil); break;
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.textGrey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Tontines'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Activité'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
      ],
    );
  }
}
