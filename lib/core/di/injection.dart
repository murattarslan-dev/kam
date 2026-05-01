import 'package:get_it/get_it.dart';
import '../../feature/battle/presentation/manager/battle_cubit.dart';
import '../firebase/firebase_service.dart';

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
  sl.registerLazySingleton<FirebaseService>(() => FirebaseService());
  
  // Geçici olarak statik giriş yap (Geliştirme aşaması için)
  final firebaseService = sl<FirebaseService>();
  await firebaseService.signInWithEmailAndPassword('kam@official.com', '123456');
}