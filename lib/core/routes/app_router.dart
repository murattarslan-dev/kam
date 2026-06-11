import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../feature/admin/presentation/pages/admin_home_screen.dart';
import '../../feature/admin/presentation/pages/battles_admin_screen.dart';
import '../../feature/admin/presentation/pages/buff_admin_screen.dart';
import '../../feature/admin/presentation/pages/hero_admin_screen.dart';
import '../../feature/admin/presentation/pages/skill_admin_screen.dart';
import '../../feature/admin/presentation/pages/users_admin_screen.dart';
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
  static const String adminBuffs = '/admin/buffs';
  static const String adminHeroes = '/admin/heroes';
  static const String adminSkills = '/admin/skills';
  static const String adminUsers = '/admin/users';
  static const String adminBattles = '/admin/battles';

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
      GoRoute(
        path: adminBuffs,
        name: 'adminBuffs',
        builder: (context, state) => _gated(const BuffAdminScreen()),
      ),
      GoRoute(
        path: adminHeroes,
        name: 'adminHeroes',
        builder: (context, state) => _gated(const HeroAdminScreen()),
      ),
      GoRoute(
        path: adminSkills,
        name: 'adminSkills',
        builder: (context, state) => _gated(SkillAdminScreen(
          heroId: state.uri.queryParameters['heroId'],
        )),
      ),
      GoRoute(
        path: adminUsers,
        name: 'adminUsers',
        builder: (context, state) => _gated(const UsersAdminScreen()),
      ),
      GoRoute(
        path: adminBattles,
        name: 'adminBattles',
        builder: (context, state) => _gated(const BattlesAdminScreen()),
      ),
      // Backward-compat
      GoRoute(path: '/buff', redirect: (_, __) => adminBuffs),
    ],
  );
}
