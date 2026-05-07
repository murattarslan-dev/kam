import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminDestination {
  final String label;
  final IconData icon;
  final String path;
  const AdminDestination({required this.label, required this.icon, required this.path});
}

const adminDestinations = <AdminDestination>[
  AdminDestination(label: 'Buff\'lar', icon: Icons.flash_on, path: '/admin/buffs'),
  AdminDestination(label: 'Kahramanlar', icon: Icons.shield, path: '/admin/heroes'),
  AdminDestination(label: 'Yetenekler', icon: Icons.auto_awesome, path: '/admin/skills'),
  AdminDestination(label: 'Kullanıcılar', icon: Icons.people, path: '/admin/users'),
  AdminDestination(label: 'Savaşlar', icon: Icons.history, path: '/admin/battles'),
];

class AdminScaffold extends StatelessWidget {
  final String title;
  final String currentPath;
  final Widget child;
  final List<Widget> actions;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.currentPath,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final selected = adminDestinations.indexWhere((d) => currentPath.startsWith(d.path));
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.tune, size: 20),
            const SizedBox(width: 8),
            Text('Admin · $title'),
          ],
        ),
        actions: [
          ...actions,
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Oyuna dön',
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => context.go('/team-setup'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          if (wide) {
            return Row(
              children: [
                NavigationRail(
                  extended: c.maxWidth >= 1100,
                  selectedIndex: selected < 0 ? 0 : selected,
                  onDestinationSelected: (i) =>
                      context.go(adminDestinations[i].path),
                  labelType: c.maxWidth >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: adminDestinations
                      .map((d) => NavigationRailDestination(
                            icon: Icon(d.icon),
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: adminDestinations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final d = adminDestinations[i];
                    final isSel = i == (selected < 0 ? 0 : selected);
                    return ChoiceChip(
                      avatar: Icon(d.icon, size: 16),
                      label: Text(d.label),
                      selected: isSel,
                      onSelected: (_) => context.go(d.path),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

/// Form bölümlerini gruplayan ortak kart.
class AdminSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  const AdminSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// İki sütun yan yana, dar ekranda alt alta gösteren küçük yardımcı.
class AdminTwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  const AdminTwoCol({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) {
        return Column(children: [left, const SizedBox(height: 12), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );
    });
  }
}
