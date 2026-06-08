import 'package:get_it/get_it.dart';
import '../auth/auth_service.dart';
import '../firebase/firebase_service.dart';
import '../../feature/battle/domain/repository/battle_repository.dart';
import '../../feature/battle/data/repository/battle_repository_impl.dart';
import '../../feature/battle/data/datasources/battle_datasource.dart';
import '../../feature/battle/data/datasources/firebase_battle_datasource_impl.dart';
import '../../feature/battle/data/datasources/battle_engine_datasource.dart';
import '../../feature/battle/data/datasources/firestore_battle_engine.dart';
import '../../feature/battle/domain/services/bot_ai.dart';
import '../../feature/battle/presentation/manager/battle_cubit.dart';
import '../../feature/battle/domain/usecases/select_hero_usecase.dart';
import '../../feature/battle/domain/usecases/use_skill_usecase.dart';
import '../../feature/battle/domain/usecases/handle_buffs_usecase.dart';
import '../../feature/battle/domain/usecases/swap_hero_usecase.dart';
import '../../feature/battle/domain/usecases/fetch_user_heroes_usecase.dart';

// Küresel servis bulucu (Service Locator)
final sl = GetIt.instance;

Future<void> setupLocator() async {
  //----------------------------------------------------------------------------
  // FEATURE - Battle
  //----------------------------------------------------------------------------

  // Data - DataSources
  sl.registerLazySingleton<BattleDataSource>(() => FirebaseBattleDataSourceImpl());

  // Data - Repositories
  sl.registerLazySingleton<BattleRepository>(() => BattleRepositoryImpl(sl()));

  // Domain - Use Cases (engine kuralları için reuse edilir)
  sl.registerLazySingleton(() => HandleBuffsUseCase());
  sl.registerLazySingleton(() => SelectHeroUseCase());
  sl.registerLazySingleton(() => UseSkillUseCase(sl()));
  sl.registerLazySingleton(() => SwapHeroUseCase(sl()));
  sl.registerLazySingleton(() => FetchUserHeroesUseCase(sl()));

  // Domain - Services
  sl.registerLazySingleton(() => BotAi());

  // Data - Engine (tek pipeline savaş motoru)
  sl.registerLazySingleton<BattleEngineDataSource>(() => FirestoreBattleEngine(
        repository: sl(),
        buffs: sl<HandleBuffsUseCase>(),
        useSkill: sl<UseSkillUseCase>(),
        swap: sl<SwapHeroUseCase>(),
        bot: sl<BotAi>(),
      ));

  // Presentation - Cubit (tek cubit, PvE/PvP)
  sl.registerFactory(() => BattleCubit(
        sl<BattleEngineDataSource>(),
        sl<BattleRepository>(),
        sl<UseSkillUseCase>(),
      ));

  //----------------------------------------------------------------------------
  // CORE / EXTERNAL
  //----------------------------------------------------------------------------

  sl.registerLazySingleton<FirebaseService>(() => FirebaseService());
  sl.registerLazySingleton<AuthService>(() => AuthService());

  // Mevcut oturum varsa kullanıcı bilgilerini (displayName) belleğe yükle.
  await sl<AuthService>().bootstrap();
}
