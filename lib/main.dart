import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/di/injection.dart';
import 'core/routes/app_router.dart';
import 'firebase_options.dart';

void main() async {
  // Flutter binding'lerini asenkron işlemlerden önce hazırla
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Dependency Injection (GetIt) kurulumunu başlat
  await setupLocator();

  runApp(const KamApp());
}

class KamApp extends StatelessWidget {
  const KamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kam: Kut\'un Doğuşu',
      debugShowCheckedModeBanner: false,

      // GoRouter yapılandırması
      routerConfig: AppRouter.router,

      // Sistem yazı tipi ölçeğini sınırla (mobil layout korunsun)
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.1,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },

      // Temel Tema Ayarları (Mobil odaklı kompakt yoğunluk)
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // Fantastik atmosfer için karanlık tema
        ),
      ),
    );
  }
}