import 'package:go_router/go_router.dart';
import '../../feature/battle/domain/entities/hero_entities.dart';
import '../../feature/battle/presentation/pages/team_setup_screen.dart';
import '../../feature/battle/presentation/pages/battle_screen.dart';

class AppRouter {
  static const String teamSetup = '/team-setup';
  static const String battle = '/battle';

  static final GoRouter router = GoRouter(
    initialLocation: teamSetup,
    routes: [
      GoRoute(
        path: teamSetup,
        name: 'teamSetup',
        builder: (context, state) => const TeamSetupScreen(),
      ),
      GoRoute(
        path: battle,
        name: 'battle',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BattleScreen(
            playerTeam: extra?['playerTeam'] as List<HeroCardEntity>?,
            benchHeroes: extra?['benchHeroes'] as List<HeroCardEntity>?,
          );
        },
      ),
    ],
  );
}
