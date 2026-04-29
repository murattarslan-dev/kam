import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/routes/app_router.dart';

void main() async {
  // Flutter binding'lerini asenkron işlemlerden önce hazırla
  final binding = WidgetsFlutterBinding.ensureInitialized();

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

      // Temel Tema Ayarları (Gelecekte burayı özelleştirebiliriz)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // Fantastik atmosfer için karanlık tema
        ),
      ),
    );
  }
}