import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/presentation/screens/login_screen.dart';
import '../../features/auth/data/presentation/screens/register_screen.dart';
import '../../features/notifications/presentation/screens/notification_screen.dart';
import '../constants/app_constants.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/tontines/presentation/screens/tontine_detail_screen.dart';
import '../../features/tontines/presentation/screens/tontine_list_screen.dart';
import '../../features/tontines/presentation/screens/gerer_tontine_screen.dart';
import '../../features/tontines/presentation/screens/cycles_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/tontines/presentation/screens/create_tontine_screen.dart';
import '../../features/tontines/presentation/screens/rejoindre_screen.dart';
import '../../features/tontines/presentation/screens/chat_tontine_screen.dart';
import '../../features/paiements/presentation/screens/paiement_screen.dart';
import '../../features/paiements/presentation/screens/paiements_historique_screen.dart';
import '../../features/profil/presentation/screens/profil_screen.dart';
import '../../features/profil/presentation/screens/profil_edit_screen.dart';

final _authRepo = AuthRepository();

// Deep link reçu alors que l'utilisateur n'est pas connecté : mémorisé ici,
// puis consommé juste après une connexion réussie.
String? _pendingDeepLink;

final appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  redirect: (context, state) async {
    final isLoggedIn = await _authRepo.isLoggedIn();
    final location = state.uri.path;

    final isAuthPage = location == AppRoutes.login ||
        location == AppRoutes.register ||
        location == AppRoutes.splash;

    final isDeepLink = location.startsWith('/rejoindre/');

    if (!isLoggedIn) {
      // On garde le lien d'invitation pour y revenir après connexion
      if (isDeepLink) _pendingDeepLink = state.uri.toString();
      return isAuthPage ? null : AppRoutes.login;
    }

    // Connecté : on consomme un éventuel deep link en attente
    if (_pendingDeepLink != null) {
      final dest = _pendingDeepLink!;
      if (Uri.parse(dest).path != location) {
        _pendingDeepLink = null;
        return dest;
      }
      _pendingDeepLink = null;
    }

    if (isAuthPage) return AppRoutes.home;
    return null;
  },
  routes: [
    // Splash → redirigé par redirect()
    GoRoute(
      path: AppRoutes.splash,
      builder: (ctx, state) => const _SplashScreen(),
    ),

    // Auth
    GoRoute(
      path: AppRoutes.login,
      builder: (ctx, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (ctx, state) => const RegisterScreen(),
    ),

    // App principale
    GoRoute(
      path: AppRoutes.home,
      builder: (ctx, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.rejoindre,
      builder: (ctx, state) => RejoindreScreen(
        token: state.pathParameters['token']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.tontines,
      builder: (ctx, state) => const TontineListScreen(),
    ),
    GoRoute(
      path: AppRoutes.createTontine,
      builder: (ctx, state) => const CreateTontineScreen(),
    ),
    GoRoute(
      path: AppRoutes.gererTontine,
      builder: (ctx, state) => GererTontineScreen(
        tontineId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.cyclesTontine,
      builder: (ctx, state) => CyclesScreen(
        tontineId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.paiementsHistorique,
      builder: (ctx, state) => PaiementsHistoriqueScreen(
        tontineId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.chatTontine,
      builder: (ctx, state) => ChatTontineScreen(
        tontineId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.tontineDetail,
      builder: (ctx, state) => TontineDetailScreen(
        tontineId: state.pathParameters['id']!,
      ),
    ),

    GoRoute(
      path: AppRoutes.paiement,
      builder: (ctx, state) => PaiementScreen(
        tontineId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (ctx, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: AppRoutes.profil,
      builder: (ctx, state) => const ProfilScreen(),
    ),
    GoRoute(
      path: AppRoutes.profilEdit,
      builder: (ctx, state) => const ProfilEditScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      builder: (ctx, state) => const AdminDashboardScreen(),
    ),
  ],
);

// Écran de chargement initial pendant la vérification du token
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}