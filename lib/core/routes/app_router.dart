import 'package:go_router/go_router.dart';
import '../../feature/battle/presentation/pages/battle_screen.dart';

class AppRouter {
  // Rota isimlerini sabit olarak tutmak hata payını azaltır
  static const String battle = '/battle';

  static final GoRouter router = GoRouter(
    initialLocation: battle,
    routes: [
      GoRoute(
        path: battle,
        name: 'battle',
        builder: (context, state) => const BattleScreen(),
      ),
      // Yeni ekranlar eklendikçe buraya eklenecek
    ],
  );
}