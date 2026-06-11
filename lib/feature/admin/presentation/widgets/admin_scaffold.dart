import 'package:flutter/material.dart';

/// Tüm admin sayfaları tek bir tablı [AdminScreen] içinde toplandığı için
/// [AdminScaffold] artık kendi Scaffold/AppBar/Nav'ını oluşturmaz —
/// sadece child'ı opsiyonel aksiyonlarla birlikte gösterir.
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
    if (actions.isEmpty) return child;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions,
          ),
        ),
        Expanded(child: child),
      ],
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
