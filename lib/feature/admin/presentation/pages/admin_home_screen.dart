import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'arenas_admin_screen.dart';
import 'battles_admin_screen.dart';
import 'buff_admin_screen.dart';
import 'hero_admin_screen.dart';
import 'skill_admin_screen.dart';
import 'users_admin_screen.dart';

/// Admin sayfalarına tab dışından (örn. Kahramanlar tabından "Yeteneklere geç")
/// hâkimiyet kurmak için InheritedWidget köprüsü.
class AdminTabBus extends InheritedWidget {
  final TabController controller;
  final void Function({String? heroId}) openSkills;

  const AdminTabBus({
    super.key,
    required this.controller,
    required this.openSkills,
    required super.child,
  });

  static AdminTabBus of(BuildContext context) {
    final bus = context.dependOnInheritedWidgetOfExactType<AdminTabBus>();
    assert(bus != null, 'AdminTabBus not found in widget tree');
    return bus!;
  }

  @override
  bool updateShouldNotify(AdminTabBus old) =>
      controller != old.controller || openSkills != old.openSkills;
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  String? _skillsHeroId;

  static const int _skillsTabIndex = 2;

  static const _tabs = <_AdminTab>[
    _AdminTab(label: 'Buff\'lar', icon: Icons.flash_on),
    _AdminTab(label: 'Kahramanlar', icon: Icons.shield),
    _AdminTab(label: 'Yetenekler', icon: Icons.auto_awesome),
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

  void _openSkills({String? heroId}) {
    setState(() => _skillsHeroId = heroId);
    _controller.animateTo(_skillsTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabBus(
      controller: _controller,
      openSkills: _openSkills,
      child: Scaffold(
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
          children: [
            const BuffAdminScreen(),
            const HeroAdminScreen(),
            SkillAdminScreen(heroId: _skillsHeroId),
            const UsersAdminScreen(),
            const ArenasAdminScreen(),
            const BattlesAdminScreen(),
          ],
        ),
      ),
    );
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  const _AdminTab({required this.label, required this.icon});
}
