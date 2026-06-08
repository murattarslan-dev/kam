import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/di/injection.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: const Text(
            'AYARLAR',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Builder(builder: (context) {
            final auth = sl<AuthService>();
            final user = auth.currentUser;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 24),
                _buildSettingsSection(
                  title: 'HESAP',
                  children: [
                    _buildSettingsItem(
                      context,
                      icon: Icons.person_outline,
                      title: auth.displayName ?? 'Adsız',
                      subtitle: user?.email ?? '—',
                      onTap: null,
                    ),
                    _buildSettingsItem(
                      context,
                      icon: Icons.logout,
                      title: 'Çıkış yap',
                      subtitle: 'Oturumu sonlandır',
                      onTap: () async {
                        await auth.signOut();
                        if (context.mounted) context.go('/');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (auth.isAdmin)
                  _buildSettingsSection(
                    title: 'YÖNETİM',
                    children: [
                      _buildSettingsItem(
                        context,
                        icon: Icons.admin_panel_settings,
                        title: 'Admin Paneli',
                        subtitle: 'Kahraman, Buff ve Beceri Yönetimi',
                        onTap: () => context.go('/admin'),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                _buildSettingsSection(
                  title: 'HAKKINDA',
                  children: [
                    _buildSettingsItem(
                      context,
                      icon: Icons.info_outline,
                      title: 'Sürüm',
                      subtitle: '1.0.0',
                      onTap: null,
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.tealAccent, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward, color: Colors.white30, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
