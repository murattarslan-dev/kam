import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../battle/domain/entities/buff_entities.dart';
import '../../../battle/domain/entities/hero_entities.dart';
import '../enum_labels.dart';
import '../widgets/admin_scaffold.dart';

class BuffAdminScreen extends StatefulWidget {
  const BuffAdminScreen({super.key});

  @override
  State<BuffAdminScreen> createState() => _BuffAdminScreenState();
}

class _BuffAdminScreenState extends State<BuffAdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String _id = '';
  String _name = '';
  String _description = '';
  BuffType _type = BuffType.statChange;
  StatType? _statType = StatType.attack;
  int _value = 10;
  int _duration = -1;
  BuffTargetType _targetType = BuffTargetType.self;
  BuffTriggerCondition _triggerCondition = BuffTriggerCondition.passive;
  double? _triggerValue;
  final List<_PrereqDraft> _prereqs = [];

  bool _saving = false;
  String? _editingId;

  List<HeroCardEntity> _heroes = [];

  @override
  void initState() {
    super.initState();
    _loadHeroes();
  }

  Future<void> _loadHeroes() async {
    final snap = await _firestore.collection('heroes').get();
    final heroes = <HeroCardEntity>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      heroes.add(HeroCardEntity.fromMap(data, skills: const []));
    }
    if (mounted) setState(() => _heroes = heroes);
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _id = '';
      _name = '';
      _description = '';
      _type = BuffType.statChange;
      _statType = StatType.attack;
      _value = 10;
      _duration = -1;
      _targetType = BuffTargetType.self;
      _triggerCondition = BuffTriggerCondition.passive;
      _triggerValue = null;
      _prereqs.clear();
    });
    _formKey.currentState?.reset();
  }

  void _loadIntoForm(BuffEntity b) {
    setState(() {
      _editingId = b.id;
      _id = b.id;
      _name = b.name;
      _description = b.description;
      _type = b.type;
      _statType = b.statType ?? StatType.attack;
      _value = b.value;
      _duration = b.duration;
      _targetType = b.targetType;
      _triggerCondition = b.triggerCondition;
      _triggerValue = b.triggerValue;
      _prereqs
        ..clear()
        ..addAll(b.prerequisites.map((p) => _PrereqDraft(p.type, p.value)));
    });
  }

  bool _needsThreshold(BuffTriggerCondition c) =>
      c == BuffTriggerCondition.onHpBelowPercent ||
      c == BuffTriggerCondition.onTeammateHpBelowPercent;

  String _slugify(String s) {
    const map = {
      'ı': 'i', 'İ': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g',
      'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    final id = _editingId ?? (_id.isNotEmpty ? _id : 'buff_${_slugify(_name)}');

    final buff = BuffEntity(
      id: id,
      name: _name,
      description: _description,
      type: _type,
      statType: _type == BuffType.statChange ? _statType : null,
      value: _value,
      duration: _duration,
      targetType: _targetType,
      triggerCondition: _triggerCondition,
      triggerValue: _needsThreshold(_triggerCondition) ? _triggerValue : null,
      prerequisites: _prereqs
          .where((p) => p.type != BuffPrerequisiteType.none)
          .map((p) => BuffPrerequisite(type: p.type, value: p.value))
          .toList(),
    );

    setState(() => _saving = true);
    try {
      await _firestore.collection('buffs').doc(id).set(buff.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedildi: $id')),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buff sil'),
        content: Text('"$id" silinsin mi?'),
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
    await _firestore.collection('buffs').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Buff\'lar',
      currentPath: '/admin/buffs',
      actions: [
        TextButton.icon(
          onPressed: _resetForm,
          icon: const Icon(Icons.add),
          label: const Text('Yeni'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildForm()),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: _buildList()),
              ],
            );
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildForm(),
              const Divider(height: 1),
              SizedBox(height: 600, child: _buildList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editingId != null ? 'Düzenle: $_editingId' : 'Yeni buff',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_editingId != null)
                  TextButton(onPressed: _resetForm, child: const Text('Sıfırla')),
              ],
            ),
            const SizedBox(height: 8),
            AdminSection(
              title: 'Tanımlama',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  TextFormField(
                    key: ValueKey('id-$_editingId'),
                    initialValue: _id,
                    enabled: _editingId == null,
                    decoration: const InputDecoration(
                      labelText: 'ID',
                      helperText: 'Boş bırakılırsa addan üretilir.',
                      hintText: 'passive_tank_damage_soak',
                    ),
                    onSaved: (v) => _id = (v ?? '').trim(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('name-$_editingId'),
                    initialValue: _name,
                    decoration: const InputDecoration(labelText: 'İsim'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    onSaved: (v) => _name = (v ?? '').trim(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('desc-$_editingId'),
                    initialValue: _description,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                    maxLines: 2,
                    onSaved: (v) => _description = (v ?? '').trim(),
                  ),
                ],
              ),
            ),
            AdminSection(
              title: 'Etki',
              icon: Icons.auto_fix_high,
              subtitle: 'Buff hangi mekanikle çalışıyor ve ne kadar değiştiriyor.',
              child: Column(
                children: [
                  DropdownButtonFormField<BuffType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Tip'),
                    items: BuffType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(EnumLabels.fmt(t, EnumLabels.buffType)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  if (_type == BuffType.statChange) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StatType>(
                      initialValue: _statType,
                      decoration: const InputDecoration(labelText: 'Hangi stat'),
                      items: StatType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(EnumLabels.fmt(t, EnumLabels.statType)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _statType = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AdminTwoCol(
                    left: TextFormField(
                      key: ValueKey('value-$_editingId'),
                      initialValue: '$_value',
                      decoration: const InputDecoration(
                        labelText: 'Değer',
                        helperText: 'Negatif = debuff. damageSoak için %.',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Sayı girin' : null,
                      onSaved: (v) => _value = int.parse(v!),
                    ),
                    right: TextFormField(
                      key: ValueKey('dur-$_editingId'),
                      initialValue: '$_duration',
                      decoration: const InputDecoration(
                        labelText: 'Süre',
                        helperText: '-1 = kalıcı, >0 = tur sayısı',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Sayı girin' : null,
                      onSaved: (v) => _duration = int.parse(v!),
                    ),
                  ),
                ],
              ),
            ),
            AdminSection(
              title: 'Hedefleme & Tetik',
              icon: Icons.center_focus_strong,
              child: Column(
                children: [
                  DropdownButtonFormField<BuffTargetType>(
                    initialValue: _targetType,
                    decoration: const InputDecoration(labelText: 'Hedef'),
                    items: BuffTargetType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(EnumLabels.fmt(t, EnumLabels.targetType)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _targetType = v!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<BuffTriggerCondition>(
                    initialValue: _triggerCondition,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tetik koşulu'),
                    items: BuffTriggerCondition.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                EnumLabels.fmt(t, EnumLabels.triggerCondition),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _triggerCondition = v!),
                  ),
                  if (_needsThreshold(_triggerCondition)) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('tval-$_editingId'),
                      initialValue: _triggerValue?.toString() ?? '0.5',
                      decoration: const InputDecoration(
                        labelText: 'HP eşiği (0.0 - 1.0)',
                        helperText: '0.5 = %50',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Ondalık sayı' : null,
                      onSaved: (v) => _triggerValue = double.parse(v!),
                    ),
                  ],
                ],
              ),
            ),
            AdminSection(
              title: 'Ön koşullar',
              icon: Icons.rule,
              subtitle: 'TÜMÜ doğru olmalı. Kahramana özel buff için "Kahraman ID" kullan.',
              child: _buildPrereqsEditor(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_editingId != null ? 'Güncelle' : 'Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrereqsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _prereqs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _PrereqRow(
              key: ValueKey('prereq-$i'),
              draft: _prereqs[i],
              heroes: _heroes,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _prereqs.removeAt(i)),
            ),
          ),
        if (_prereqs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Koşul eklenmedi — buff her zaman uygulanabilir.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _prereqs.add(_PrereqDraft(BuffPrerequisiteType.heroRoleIs, 'tank'));
            }),
            icon: const Icon(Icons.add),
            label: const Text('Koşul ekle'),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('buffs').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Henüz buff yok.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.list, size: 18),
                  const SizedBox(width: 8),
                  Text('Mevcut buff\'lar (${docs.length})',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = Map<String, dynamic>.from(doc.data());
                  data['id'] = doc.id;
                  final buff = BuffEntity.fromMap(data);
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(buff.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          Wrap(spacing: 4, runSpacing: 2, children: [
                            _Chip(EnumLabels.buffType[buff.type] ?? buff.type.name),
                            _Chip(EnumLabels.targetType[buff.targetType] ?? buff.targetType.name),
                            _Chip(EnumLabels.triggerCondition[buff.triggerCondition] ?? buff.triggerCondition.name),
                            _Chip('val=${buff.value}'),
                            _Chip(buff.duration == -1 ? 'kalıcı' : '${buff.duration} tur'),
                          ]),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _loadIntoForm(buff),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _delete(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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

class _PrereqDraft {
  BuffPrerequisiteType type;
  String value;
  _PrereqDraft(this.type, this.value);
}

class _PrereqRow extends StatelessWidget {
  final _PrereqDraft draft;
  final List<HeroCardEntity> heroes;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _PrereqRow({
    super.key,
    required this.draft,
    required this.heroes,
    required this.onChanged,
    required this.onRemove,
  });

  bool get _wantsElement =>
      draft.type == BuffPrerequisiteType.heroElementIs ||
      draft.type == BuffPrerequisiteType.hasTeammateWithElement ||
      draft.type == BuffPrerequisiteType.hasEnemyWithElement;

  bool get _wantsRole =>
      draft.type == BuffPrerequisiteType.heroRoleIs ||
      draft.type == BuffPrerequisiteType.hasTeammateWithRole ||
      draft.type == BuffPrerequisiteType.hasEnemyWithRole;

  bool get _wantsHero =>
      draft.type == BuffPrerequisiteType.heroIdIs ||
      draft.type == BuffPrerequisiteType.hasTeammateWithId;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<BuffPrerequisiteType>(
            initialValue: draft.type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Koşul tipi', isDense: true),
            items: BuffPrerequisiteType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        EnumLabels.fmt(t, EnumLabels.prerequisiteType),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              draft.type = v!;
              draft.value = '';
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _buildValueField()),
        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
      ],
    );
  }

  Widget _buildValueField() {
    if (_wantsElement) {
      return DropdownButtonFormField<String>(
        initialValue: draft.value.isEmpty ? null : draft.value,
        decoration: const InputDecoration(labelText: 'Element', isDense: true),
        items: HeroElement.values
            .map((e) => DropdownMenuItem(
                  value: e.name,
                  child: Text(EnumLabels.fmt(e, EnumLabels.heroElement)),
                ))
            .toList(),
        onChanged: (v) {
          draft.value = v ?? '';
          onChanged();
        },
      );
    }
    if (_wantsRole) {
      return DropdownButtonFormField<String>(
        initialValue: draft.value.isEmpty ? null : draft.value,
        decoration: const InputDecoration(labelText: 'Rol', isDense: true),
        items: HeroRole.values
            .map((r) => DropdownMenuItem(
                  value: r.name,
                  child: Text(EnumLabels.fmt(r, EnumLabels.heroRole)),
                ))
            .toList(),
        onChanged: (v) {
          draft.value = v ?? '';
          onChanged();
        },
      );
    }
    if (_wantsHero) {
      return DropdownButtonFormField<String>(
        initialValue: heroes.any((h) => h.id == draft.value) ? draft.value : null,
        decoration: const InputDecoration(labelText: 'Kahraman', isDense: true),
        isExpanded: true,
        items: heroes
            .map((h) => DropdownMenuItem(value: h.id, child: Text(h.name)))
            .toList(),
        onChanged: (v) {
          draft.value = v ?? '';
          onChanged();
        },
      );
    }
    return TextFormField(
      key: ValueKey('val-${draft.type}'),
      initialValue: draft.value,
      decoration: const InputDecoration(labelText: 'Değer', isDense: true),
      onChanged: (v) {
        draft.value = v;
      },
    );
  }
}
