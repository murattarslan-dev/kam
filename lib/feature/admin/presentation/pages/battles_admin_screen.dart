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
              if (result != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isVictory == true ? Colors.green : Colors.red)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isVictory == true ? Colors.green : Colors.red)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result['message'] as String? ?? '',
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (result['rewards'] is List)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Ödüller: ${(result['rewards'] as List).join(", ")}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AdminSection(
                title: 'Takımlar',
                icon: Icons.groups,
                child: AdminTwoCol(
                  left: _TeamColumn(
                    title: 'Host (oyuncu)',
                    snapshots: data['hostTeam'] as List?,
                  ),
                  right: _TeamColumn(
                    title: 'Guest (rakip)',
                    snapshots: data['guestTeam'] as List?,
                  ),
                ),
              ),
              if (result != null && result['heroStats'] is List)
                AdminSection(
                  title: 'Kahraman istatistikleri',
                  icon: Icons.bar_chart,
                  child: _HeroStatsTable(rows: result['heroStats'] as List),
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

class _TeamColumn extends StatelessWidget {
  final String title;
  final List? snapshots;
  const _TeamColumn({required this.title, this.snapshots});

  @override
  Widget build(BuildContext context) {
    final team = snapshots ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (team.isEmpty)
          Text('—', style: TextStyle(color: Theme.of(context).hintColor))
        else
          for (final h in team)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Builder(builder: (_) {
                final m = Map<String, dynamic>.from(h as Map);
                final hp = (m['health'] as num?)?.toInt() ?? 0;
                final maxHp = (m['cp'] as num?)?.toInt() ?? 0;
                final alive = hp > 0;
                return Row(
                  children: [
                    Icon(
                      alive ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: alive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m['name'] as String? ?? '?')),
                    Text(
                      'HP $hp/$maxHp · Kut ${m['kut'] ?? 0}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                );
              }),
            ),
      ],
    );
  }
}

class _HeroStatsTable extends StatelessWidget {
  final List rows;
  const _HeroStatsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        columns: const [
          DataColumn(label: Text('Kahraman')),
          DataColumn(label: Text('Taraf')),
          DataColumn(label: Text('Yedek')),
          DataColumn(label: Text('Verilen')),
          DataColumn(label: Text('Alınan')),
          DataColumn(label: Text('XP')),
        ],
        rows: rows.map<DataRow>((r) {
          final m = Map<String, dynamic>.from(r as Map);
          return DataRow(cells: [
            DataCell(Text(m['name'] as String? ?? '?')),
            DataCell(Text(m['side'] as String? ?? '?')),
            DataCell(Text(m['isBench'] == true ? '✓' : '')),
            DataCell(Text('${m['damageDealt'] ?? 0}')),
            DataCell(Text('${m['damageReceived'] ?? 0}')),
            DataCell(Text('${m['xpGained'] ?? 0}')),
          ]);
        }).toList(),
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
