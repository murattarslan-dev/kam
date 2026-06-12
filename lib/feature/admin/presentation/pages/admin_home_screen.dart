import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/skill_to_toz_migration.dart';
import '../../data/toz_seed.dart';
import 'arenas_admin_screen.dart';
import 'battles_admin_screen.dart';
import 'buff_admin_screen.dart';
import 'hero_admin_screen.dart';
import 'users_admin_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  static const _tabs = <_AdminTab>[
    _AdminTab(label: 'Buff\'lar', icon: Icons.flash_on),
    _AdminTab(label: 'Kahramanlar', icon: Icons.shield),
    _AdminTab(label: 'Kullanıcılar', icon: Icons.people),
    _AdminTab(label: 'Arenalar', icon: Icons.terrain),
    _AdminTab(label: 'Savaşlar', icon: Icons.history),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            children: const [
              Icon(Icons.tune, size: 20),
              SizedBox(width: 8),
              Text('Admin'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Skill → Töz migration',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _runSkillToTozMigration(context),
            ),
            IconButton(
              tooltip: 'Basit Töz seed (3 & 5 Kut)',
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => _runTozSeed(context),
            ),
            IconButton(
              tooltip: 'Oyuna dön',
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => context.go('/'),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _controller,
            isScrollable: true,
            tabs: [
              for (final t in _tabs) Tab(icon: Icon(t.icon), text: t.label),
            ],
          ),
        ),
        body: TabBarView(
          controller: _controller,
          children: const [
            BuffAdminScreen(),
            HeroAdminScreen(),
            UsersAdminScreen(),
            ArenasAdminScreen(),
            BattlesAdminScreen(),
          ],
        ),
      );
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  const _AdminTab({required this.label, required this.icon});
}

Future<void> _runSkillToTozMigration(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Skill → Töz Migration'),
      content: const Text(
        'Eski heroes/{id}/skills alt-koleksiyonu okunup her skill için '
        'hero.tozler[] güncellenir; gerekirse `skill_<id>` adıyla yeni '
        'buff dokümanları üretilir.\n\n'
        'İdempotenttir: tozler zaten dolu olan kahramanlar atlanır.\n'
        'Devam edilsin mi?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Çalıştır'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Migration başlatıldı...')),
  );

  try {
    final result = await SkillToTozMigration.run(FirebaseFirestore.instance);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(result.toString()), duration: const Duration(seconds: 8)),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
    );
  }
}

Future<void> _runTozSeed(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Töz Seed'),
      content: const Text(
        '7 basit buff oluşturulur (3 ve 5 Kut, manuel tetik):\n\n'
        '• 3 Kut: Öz Güç, Öz Zırh, Şifalı Nefes\n'
        '• 5 Kut: Takım Kalkanı, Savaş Narası, Düşman Yarası, Kara Zehir\n\n'
        'Her kahramana rolüne göre 1× 3-Kut + 1× 5-Kut töz atanır.\n'
        'İdempotenttir: mevcut buff/töz dokunulmaz.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Çalıştır'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Seed başlatıldı...')));

  try {
    final result = await TozSeed.run(FirebaseFirestore.instance);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(result.toString()), duration: const Duration(seconds: 8)),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
    );
  }
}
