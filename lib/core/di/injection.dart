import 'package:get_it/get_it.dart';
import '../firebase/firebase_service.dart';
import '../../feature/battle/domain/repository/battle_repository.dart';
import '../../feature/battle/data/repository/battle_repository_impl.dart';
import '../../feature/battle/data/datasources/battle_datasource.dart';
import '../../feature/battle/data/datasources/firebase_battle_datasource_impl.dart';
import '../../feature/battle/presentation/manager/battle_cubit.dart';
import '../../feature/battle/domain/usecases/start_battle_usecase.dart';
import '../../feature/battle/domain/usecases/select_hero_usecase.dart';
import '../../feature/battle/domain/usecases/execute_player_attack_usecase.dart';
import '../../feature/battle/domain/usecases/apply_player_attack_usecase.dart';
import '../../feature/battle/domain/usecases/use_skill_usecase.dart';
import '../../feature/battle/domain/usecases/execute_enemy_turn_usecase.dart';
import '../../feature/battle/domain/usecases/finalize_xp_usecase.dart';

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

  // Domain - Use Cases
  sl.registerLazySingleton(() => StartBattleUseCase(sl()));
  sl.registerLazySingleton(() => SelectHeroUseCase());
  sl.registerLazySingleton(() => ExecutePlayerAttackUseCase());
  sl.registerLazySingleton(() => ApplyPlayerAttackUseCase());
  sl.registerLazySingleton(() => UseSkillUseCase());
  sl.registerLazySingleton(() => ExecuteEnemyTurnUseCase());
  sl.registerLazySingleton(() => FinalizeXpUseCase(sl()));

  // Presentation - Cubit
  sl.registerFactory(() => BattleCubit(
    sl(), sl(), sl(), sl(), sl(), sl(), sl(),
  ));

  //----------------------------------------------------------------------------
  // CORE / EXTERNAL
  //----------------------------------------------------------------------------

  // Firebase veya diğer harici servisler buraya gelecek.
  sl.registerLazySingleton<FirebaseService>(() => FirebaseService());
  
  // Geçici olarak statik giriş yap (Geliştirme aşaması için)
  final firebaseService = sl<FirebaseService>();
  await firebaseService.signInWithEmailAndPassword('kam@official.com', '123456');
}