import 'package:get_it/get_it.dart';
import '../../feature/battle/presentation/manager/battle_cubit.dart';

// Küresel servis bulucu (Service Locator)
final sl = GetIt.instance;

Future<void> setupLocator() async {
  //----------------------------------------------------------------------------
  // FEATURE - Battle
  //----------------------------------------------------------------------------

  // Presentation - Cubit
  // Cubit'leri her seferinde taze bir instance olarak (factory) kaydediyoruz.
  sl.registerFactory(() => BattleCubit());

  // Domain - Use Cases
  // Örn: sl.registerLazySingleton(() => GetBattleDataUseCase(sl()));

  // Data - Repositories
  // Örn: sl.registerLazySingleton<BattleRepository>(() => BattleRepositoryImpl(sl()));

  //----------------------------------------------------------------------------
  // CORE / EXTERNAL
  //----------------------------------------------------------------------------

  // Firebase veya diğer harici servisler buraya gelecek.
}