import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/di/injection.dart';

/// Admin ekranlarını yalnız izin verilen kullanıcılara açar.
/// Kontrol: kullanıcı email'i [AuthService.adminEmails] içinde mi?
class AdminGate extends StatelessWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = sl<AuthService>();
    if (auth.isAdmin) return child;
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.white54),
                const SizedBox(height: 16),
                const Text(
                  'Yetki yok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  auth.currentUser == null
                      ? 'Yönetim için önce giriş yap.'
                      : 'Bu hesap (${auth.currentUser?.email}) admin değil.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Ana sayfa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
