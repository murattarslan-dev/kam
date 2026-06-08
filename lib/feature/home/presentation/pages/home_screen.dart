import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/di/injection.dart';
import '../../../battle/data/datasources/battle_engine_datasource.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _showJoinDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    String? error;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (dContext) => StatefulBuilder(
        builder: (dContext, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Davet Kodu',
              style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rakibinden aldığın 6 haneli kodu gir.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 24,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'K7M3X9',
                  counterText: '',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.15),
                    letterSpacing: 6,
                  ),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.tealAccent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dContext),
              child: const Text('İPTAL'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
              onPressed: busy
                  ? null
                  : () async {
                      final code = ctrl.text.trim().toUpperCase();
                      if (code.length != 6) {
                        setLocal(() => error = 'Kod 6 karakter olmalı');
                        return;
                      }
                      setLocal(() {
                        busy = true;
                        error = null;
                      });
                      final battleId = await sl<BattleEngineDataSource>()
                          .findLobbyByCode(code);
                      if (battleId == null) {
                        setLocal(() {
                          busy = false;
                          error = 'Kod bulunamadı veya lobi kapanmış';
                        });
                        return;
                      }
                      if (!dContext.mounted) return;
                      Navigator.pop(dContext);
                      context.go('/team-setup?match=$battleId');
                    },
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.login, size: 16, color: Colors.black),
              label: const Text('KATIL',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
          fontFamily: 'Serif',
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Text(
                          'KAM',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 8,
                            shadows: [
                              BoxShadow(
                                color: Colors.deepPurple.withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kahraman Savaş Oyunu',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white54,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hoş geldin, ${sl<AuthService>().displayName ?? "kahraman"}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.tealAccent,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 60),
                        _buildModeButton(
                          context,
                          title: 'OYUNA BAŞLA',
                          subtitle: 'Bota karşı oyna ya da rakip davet et',
                          icon: Icons.shield_outlined,
                          color: Colors.redAccent,
                          onPressed: () => context.go('/team-setup'),
                        ),
                        const SizedBox(height: 16),
                        _buildModeButton(
                          context,
                          title: 'OYUNA KATIL',
                          subtitle: 'Davet koduyla bir maça katıl',
                          icon: Icons.login,
                          color: Colors.tealAccent,
                          onPressed: () => _showJoinDialog(context),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
                  label: const Text(
                    'AYARLAR',
                    style: TextStyle(color: Colors.white70, letterSpacing: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: color.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
