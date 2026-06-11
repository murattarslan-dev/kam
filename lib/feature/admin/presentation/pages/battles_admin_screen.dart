import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/admin_scaffold.dart';

class BattlesAdminScreen extends StatefulWidget {
  const BattlesAdminScreen({super.key});

  @override
  State<BattlesAdminScreen> createState() => _BattlesAdminScreenState();
}

class _BattlesAdminScreenState extends State<BattlesAdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? _selectedId;
  String _statusFilter = 'all';

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Savaşı sil'),
        content: Text('"$id" ve events alt-koleksiyonu silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ref = _firestore.collection('battles').doc(id);
    final ev = await ref.collection('events').get();
    for (final e in ev.docs) {
      await e.reference.delete();
    }
    await ref.delete();
    if (_selectedId == id) setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Savaşlar',
      currentPath: '/admin/battles',
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final list = _buildList();
          final detail = _selectedId == null
              ? const Center(child: Text('Bir savaş seç.'))
              : _BattleDetail(key: ValueKey(_selectedId), battleId: _selectedId!);
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 360, child: list),
                const VerticalDivider(width: 1),
                Expanded(child: detail),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: 280, child: list),
              const Divider(height: 1),
              Expanded(child: detail),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList() {
    final base = _firestore.collection('battles');
    Query<Map<String, dynamic>> query = base.orderBy('createdAt', descending: true);
    if (_statusFilter != 'all') {
      query = base.where('status', isEqualTo: _statusFilter)
          .orderBy('createdAt', descending: true);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              const Icon(Icons.history, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Savaş geçmişi',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  isDense: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Hepsi')),
                    DropdownMenuItem(value: 'in_progress', child: Text('Devam eden')),
                    DropdownMenuItem(value: 'victory', child: Text('Zafer')),
                    DropdownMenuItem(value: 'defeat', child: Text('Mağlubiyet')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.limit(100).snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Hata: ${snap.error}'),
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Savaş yok.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final status = data['status'] as String? ?? '?';
                  final turn = data['currentTurn'] ?? 0;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final result = data['result'] as Map<String, dynamic>?;
                  final isVictory = result?['isVictory'] as bool?;
                  final selected = doc.id == _selectedId;
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      dense: true,
                      onTap: () => setState(() => _selectedId = doc.id),
                      title: Row(
                        children: [
                          _StatusBadge(status: status, isVictory: isVictory),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              doc.id,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          if (createdAt != null) _fmtDate(createdAt),
                          'Tur $turn',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        onPressed: () => _delete(doc.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BattleDetail extends StatelessWidget {
  final String battleId;
  const _BattleDetail({super.key, required this.battleId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('battles').doc(battleId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data?.data();
        if (data == null) {
          return const Center(child: Text('Savaş bulunamadı.'));
        }

        final status = data['status'] as String? ?? '?';
        final result = data['result'] as Map<String, dynamic>?;
        final isVictory = result?['isVictory'] as bool?;
        final turn = data['currentTurn'] ?? 0;
        final isPlayerTurn = data['isPlayerTurn'] as bool? ?? false;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _StatusBadge(status: status, isVictory: isVictory),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      battleId,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (createdAt != null) 'Başladı: ${_fmtDate(createdAt)}',
                  if (updatedAt != null) 'Güncellendi: ${_fmtDate(updatedAt)}',
                  'Tur: $turn',
                  isPlayerTurn ? 'Sıra: oyuncu' : 'Sıra: düşman',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
              const SizedBox(height: 16),
              if (result != null && result['heroStats'] is List)
                AdminSection(
                  title: 'Kahraman istatistikleri',
                  icon: Icons.bar_chart,
                  child: _HeroStatsTabs(
                    rows: result['heroStats'] as List,
                    result: result,
                    hostName: (data['hostName'] as String?) ?? 'Host',
                    guestName: (data['guestName'] as String?) ?? 'Guest',
                  ),
                ),
              if (data['battleLogs'] is List &&
                  (data['battleLogs'] as List).isNotEmpty)
                AdminSection(
                  title: 'Savaş güncesi',
                  icon: Icons.history_edu,
                  subtitle: '${(data['battleLogs'] as List).length} kayıt',
                  child: _BattleLogsList(
                    logs: (data['battleLogs'] as List)
                        .map((e) => e.toString())
                        .toList(),
                  ),
                ),
              if (data['activeBuffs'] is List &&
                  (data['activeBuffs'] as List).isNotEmpty)
                AdminSection(
                  title: 'Aktif buff\'lar',
                  icon: Icons.flash_on,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (data['activeBuffs'] as List).map((b) {
                      final m = b as Map;
                      return _Chip(
                          '${m['buffId']} → ${m['targetHeroId']} (${m['remainingTurns']})');
                    }).toList(),
                  ),
                ),
              AdminSection(
                title: 'Olay zaman çizelgesi',
                icon: Icons.timeline,
                subtitle: 'battles/$battleId/events (seq sıralı)',
                child: _EventsTimeline(battleId: battleId),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroStatsTabs extends StatefulWidget {
  final List rows;
  final Map<String, dynamic> result;
  final String hostName;
  final String guestName;
  const _HeroStatsTabs({
    required this.rows,
    required this.result,
    required this.hostName,
    required this.guestName,
  });

  @override
  State<_HeroStatsTabs> createState() => _HeroStatsTabsState();
}

class _HeroStatsTabsState extends State<_HeroStatsTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  int _xpOf(Map<String, dynamic> s) => (s['xpGained'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final stats = widget.rows
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final hostStats = stats.where((s) => s['side'] == 'host').toList()
      ..sort((a, b) => _xpOf(b).compareTo(_xpOf(a)));
    final guestStats = stats.where((s) => s['side'] == 'guest').toList()
      ..sort((a, b) => _xpOf(b).compareTo(_xpOf(a)));

    final hostTotal = (widget.result['hostTotalXp'] as num?)?.toInt() ??
        hostStats.fold<int>(0, (a, s) => a + _xpOf(s));
    final guestTotal = (widget.result['guestTotalXp'] as num?)?.toInt() ??
        guestStats.fold<int>(0, (a, s) => a + _xpOf(s));
    final winnerSide = widget.result['winnerSide'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tab,
          tabs: [
            _tabLabel(widget.hostName, 'host', winnerSide, hostTotal,
                hostStats.length),
            _tabLabel(widget.guestName, 'guest', winnerSide, guestTotal,
                guestStats.length),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 420,
          child: TabBarView(
            controller: _tab,
            children: [
              _teamList(hostStats),
              _teamList(guestStats),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabLabel(
      String name, String side, String? winnerSide, int totalXp, int count) {
    final isWinner = side == winnerSide;
    return Tab(
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWinner) ...[
                const Icon(Icons.emoji_events,
                    size: 14, color: Colors.amber),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  '$name ($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '+$totalXp XP',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.amber,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamList(List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) {
      return Center(
        child: Text('Veri yok',
            style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _HeroStatRow(stat: stats[i]),
    );
  }
}

class _HeroStatRow extends StatelessWidget {
  final Map<String, dynamic> stat;
  const _HeroStatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final name = (stat['name'] as String?) ?? 'Adsız';
    final imageUrl = (stat['imageUrl'] as String?) ?? '';
    final isAlive = stat['isAlive'] == true;
    final isBench = stat['isBench'] == true;
    final damageDealt = (stat['damageDealt'] as num?)?.toInt() ?? 0;
    final damageReceived = (stat['damageReceived'] as num?)?.toInt() ?? 0;
    final killBonus = (stat['killBonusXp'] as num?)?.toInt() ?? 0;
    final survivalBonus = (stat['survivalBonusXp'] as num?)?.toInt() ?? 0;
    final xpGained = (stat['xpGained'] as num?)?.toInt() ?? 0;
    final kills = ((stat['kills'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlive
              ? Theme.of(context).dividerColor
              : Colors.redAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.shield, size: 18),
                        )
                      : const Icon(Icons.shield, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          isAlive ? 'Hayatta' : 'Ölü',
                          style: TextStyle(
                            fontSize: 10,
                            color: isAlive
                                ? Colors.green
                                : Colors.redAccent,
                          ),
                        ),
                        if (isBench) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Yedek',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Text('+$xpGained XP',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _pill(context, Icons.flash_on, 'Verilen', damageDealt,
                  Colors.orange),
              const SizedBox(width: 6),
              _pill(context, Icons.shield_outlined, 'Alınan', damageReceived,
                  Colors.redAccent),
            ],
          ),
          if (killBonus > 0 || survivalBonus > 0) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (killBonus > 0)
                  _bonusChip(Icons.local_fire_department,
                      'Öldürme bonusu', killBonus),
                if (survivalBonus > 0)
                  _bonusChip(Icons.favorite, 'Hayatta kalma', survivalBonus),
              ],
            ),
          ],
          if (kills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.deepOrange.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 12, color: Colors.deepOrange),
                      const SizedBox(width: 6),
                      Text(
                        'Öldürdükleri (${kills.length})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final k in kills)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '· ${k['victimName'] ?? '?'}  '
                        '(ATK ${k['victimAttack'] ?? 0} + '
                        'DEF ${k['victimDefense'] ?? 0})  '
                        'T${k['turn'] ?? '?'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label, int value,
      Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          color: color.withValues(alpha: 0.9),
                          letterSpacing: 0.5)),
                  Text('$value',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bonusChip(IconData icon, String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.amber.shade700),
          const SizedBox(width: 4),
          Text('$label +$value',
              style: TextStyle(fontSize: 10, color: Colors.amber.shade700)),
        ],
      ),
    );
  }
}

class _BattleLogsList extends StatelessWidget {
  final List<String> logs;
  const _BattleLogsList({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < logs.length; i++) ...[
            if (i > 0) const Divider(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                logs[i],
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.normal,
                  color: i == 0
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventsTimeline extends StatelessWidget {
  final String battleId;
  const _EventsTimeline({required this.battleId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('battles')
          .doc(battleId)
          .collection('events')
          .orderBy('seq')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Olay yok.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in docs) _EventRow(data: d.data()),
          ],
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EventRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final seq = data['seq'] ?? '?';
    final turn = data['turn'] ?? '?';
    final side = data['side'] as String? ?? 'system';
    final type = data['type'] as String? ?? '?';
    final msg = data['message'] as String? ?? '';

    Color sideColor;
    switch (side) {
      case 'player':
        sideColor = Colors.blue;
        break;
      case 'enemy':
        sideColor = Colors.red;
        break;
      default:
        sideColor = Colors.grey;
    }

    final dmg = data['damage'] as Map<String, dynamic>?;
    final result = data['result'] as Map<String, dynamic>?;
    final extras = <String>[];
    if (dmg != null && dmg['finalDamage'] != null) {
      extras.add('hasar ${dmg['finalDamage']}');
    }
    if (result != null && result['killed'] == true) {
      extras.add('öldü');
    }
    if (result != null && result['kutEarned'] != null && result['kutEarned'] != 0) {
      extras.add('+${result['kutEarned']} kut');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: sideColor, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '#$seq',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              'T$turn',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: sideColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(type, style: const TextStyle(fontSize: 10)),
          ),
          Expanded(
            child: Text(
              [msg, ...extras.map((e) => '· $e')].join(' '),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool? isVictory;
  const _StatusBadge({required this.status, this.isVictory});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    if (status == 'in_progress') {
      color = Colors.orange; label = 'Devam'; icon = Icons.bolt;
    } else if (isVictory == true || status == 'victory') {
      color = Colors.green; label = 'Zafer'; icon = Icons.emoji_events;
    } else {
      color = Colors.red; label = 'Mağlup'; icon = Icons.cancel;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}

String _fmtDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
