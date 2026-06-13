import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
