import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../feature/admin/presentation/pages/admin_home_screen.dart';
import '../../feature/admin/presentation/widgets/admin_gate.dart';
import '../../feature/battle/domain/entities/hero_entities.dart';
import '../../feature/battle/presentation/pages/team_setup_screen.dart';
import '../../feature/battle/presentation/pages/battle_screen.dart';
import '../../feature/battle/presentation/pages/battle_result_screen.dart';
import '../../feature/home/presentation/pages/home_screen.dart';
import '../../feature/home/presentation/pages/settings_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String teamSetup = '/team-setup';
  static const String battle = '/battle';
  static const String battleResult = '/battle-result';
  static const String settings = '/settings';
  static const String admin = '/admin';

  static Widget _gated(Widget child) => AdminGate(child: child);

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: teamSetup,
        name: 'teamSetup',
        builder: (context, state) => TeamSetupScreen(
          inviteMatchId: state.uri.queryParameters['match'],
        ),
      ),
      GoRoute(
        path: battle,
        name: 'battle',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BattleScreen(
            playerTeam: extra?['playerTeam'] as List<HeroCardEntity>?,
            benchHeroes: extra?['benchHeroes'] as List<HeroCardEntity>?,
            matchId: state.uri.queryParameters['match'],
            arenaId: extra?['arenaId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '$battleResult/:id',
        name: 'battleResult',
        builder: (context, state) => BattleResultScreen(
          battleId: state.pathParameters['id'] ?? '',
          mySide: state.uri.queryParameters['side'] ?? 'host',
        ),
      ),
      GoRoute(
        path: settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: admin,
        name: 'admin',
        builder: (context, state) => _gated(const AdminHomeScreen()),
      ),
      // Backward-compat: eski admin alt-route'ları tek admin sayfasına yönlendir.
      GoRoute(path: '/admin/buffs', redirect: (_, __) => admin),
      GoRoute(path: '/admin/heroes', redirect: (_, __) => admin),
      GoRoute(path: '/admin/skills', redirect: (_, __) => admin),
      GoRoute(path: '/admin/users', redirect: (_, __) => admin),
      GoRoute(path: '/admin/battles', redirect: (_, __) => admin),
      GoRoute(path: '/buff', redirect: (_, __) => admin),
    ],
  );
}
