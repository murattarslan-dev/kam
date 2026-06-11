import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../di/injection.dart';
import 'auth_service.dart';
import '../../feature/auth/presentation/pages/auth_screen.dart';

/// FirebaseAuth durumunu dinler. Oturum yoksa [AuthScreen]; varsa [child].
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = sl<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.userChanges,
      initialData: auth.currentUser,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const _Loading();
        }
        if (snap.data == null) return const AuthScreen();
        return child;
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF020617),
      body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );
  }
}
