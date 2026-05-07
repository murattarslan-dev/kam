import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../battle/domain/entities/hero_entities.dart';
import '../enum_labels.dart';
import '../widgets/admin_scaffold.dart';

class SkillAdminScreen extends StatefulWidget {
  final String? heroId;
  const SkillAdminScreen({super.key, this.heroId});

  @override
  State<SkillAdminScreen> createState() => _SkillAdminScreenState();
}

class _SkillAdminScreenState extends State<SkillAdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? _selectedHeroId;
  List<MapEntry<String, String>> _heroes = []; // (id, name)
  List<MapEntry<String, String>> _buffs = [];  // (id, name)

  String _id = '';
  String _name = '';
  String _description = '';
  int _cost = 20;
  SkillType _type = SkillType.attackBuff;
  int _value = 10;
  String? _triggersBuffId;

  bool _saving = false;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _selectedHeroId = widget.heroId;
    _load();
  }

  @override
  void didUpdateWidget(covariant SkillAdminScreen old) {
    super.didUpdateWidget(old);
    if (widget.heroId != old.heroId) {
      setState(() {
        _selectedHeroId = widget.heroId;
        _resetForm();
      });
    }
  }

  Future<void> _load() async {
    final h = await _firestore.collection('heroes').orderBy('name').get();
    final b = await _firestore.collection('buffs').get();
    if (!mounted) return;
    setState(() {
      _heroes = h.docs
          .map((d) => MapEntry(d.id, d.data()['name'] as String? ?? d.id))
          .toList();
      _buffs = b.docs
          .map((d) => MapEntry(d.id, d.data()['name'] as String? ?? d.id))
          .toList();
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _id = '';
      _name = '';
      _description = '';
      _cost = 20;
      _type = SkillType.attackBuff;
      _value = 10;
      _triggersBuffId = null;
    });
    _formKey.currentState?.reset();
  }

  void _loadIntoForm(String docId, Map<String, dynamic> data) {
    setState(() {
      _editingId = docId;
      _id = docId;
      _name = data['name'] as String? ?? '';
      _description = data['description'] as String? ?? '';
      _cost = (data['cost'] as num?)?.toInt() ?? 0;
      _type = SkillType.fromString(data['type'] as String? ?? 'attackBuff');
      _value = (data['value'] as num?)?.toInt() ?? 0;
      _triggersBuffId = data['triggersBuffId'] as String?;
    });
  }

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
    if (_selectedHeroId == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    final id = _editingId ?? (_id.isNotEmpty ? _id : 'skill_${_slugify(_name)}');
    if (id.isEmpty) return;

    setState(() => _saving = true);
    try {
      await _firestore
          .collection('heroes')
          .doc(_selectedHeroId)
          .collection('skills')
          .doc(id)
          .set({
        'name': _name,
        'description': _description,
        'cost': _cost,
        'type': _type.name,
        'value': _value,
        'triggersBuffId': _triggersBuffId,
      }, SetOptions(merge: true));
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
    if (_selectedHeroId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yetenek sil'),
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
    await _firestore
        .collection('heroes')
        .doc(_selectedHeroId)
        .collection('skills')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Yetenekler',
      currentPath: '/admin/skills',
      actions: [
        if (_selectedHeroId != null)
          TextButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.add),
            label: const Text('Yeni'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
      ],
      child: Column(
        children: [
          _buildHeroPicker(),
          const Divider(height: 1),
          Expanded(
            child: _selectedHeroId == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Yetenek düzenlemek için bir kahraman seç.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : LayoutBuilder(
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
                          SizedBox(height: 500, child: _buildList()),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPicker() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _heroes.any((h) => h.key == _selectedHeroId)
                  ? _selectedHeroId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kahraman seç',
                border: OutlineInputBorder(),
              ),
              items: _heroes
                  .map((h) => DropdownMenuItem(
                        value: h.key,
                        child: Text('${h.value} (${h.key})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedHeroId = v;
                _resetForm();
              }),
            ),
          ),
        ],
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
                    _editingId != null ? 'Düzenle: $_editingId' : 'Yeni yetenek',
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
              subtitle:
                  '"Tetiklenen buff" doluysa SkillType yerine o buff uygulanır (hedef/süre buff\'tan gelir).',
              child: Column(
                children: [
                  AdminTwoCol(
                    left: TextFormField(
                      key: ValueKey('cost-$_editingId'),
                      initialValue: '$_cost',
                      decoration: const InputDecoration(
                        labelText: 'Kut maliyeti',
                        helperText: 'Skill\'i kullanmak için gereken Kut',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Sayı' : null,
                      onSaved: (v) => _cost = int.parse(v!),
                    ),
                    right: TextFormField(
                      key: ValueKey('value-$_editingId'),
                      initialValue: '$_value',
                      decoration: const InputDecoration(
                        labelText: 'Değer',
                        helperText: 'Sadece eski SkillType yolu için.',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Sayı' : null,
                      onSaved: (v) => _value = int.parse(v!),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SkillType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Eski SkillType (triggersBuffId boşsa kullanılır)',
                    ),
                    items: SkillType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(EnumLabels.fmt(t, EnumLabels.skillType)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _buffs.any((b) => b.key == _triggersBuffId)
                        ? _triggersBuffId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tetiklenen buff (önerilen)',
                      helperText: 'Yeni yol — buff doc\'undan otomatik hedef/süre/etki.',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Yok —')),
                      ..._buffs.map((b) => DropdownMenuItem<String?>(
                            value: b.key,
                            child: Text(
                              '${b.value} (${b.key})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (v) => setState(() => _triggersBuffId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('heroes')
          .doc(_selectedHeroId)
          .collection('skills')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Bu kahramanın yeteneği yok.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.list, size: 18),
                  const SizedBox(width: 8),
                  Text('Yetenekler (${docs.length})',
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
                  final data = doc.data();
                  final tBuff = data['triggersBuffId'] as String?;
                  final type = SkillType.fromString(data['type'] as String? ?? 'attackBuff');
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(data['name'] as String? ?? doc.id),
                      subtitle: Wrap(spacing: 4, runSpacing: 2, children: [
                        _Chip('cost ${data['cost'] ?? '?'}'),
                        if (tBuff != null && tBuff.isNotEmpty)
                          _Chip('→ buff: $tBuff')
                        else
                          _Chip(EnumLabels.skillType[type] ?? type.name),
                        _Chip('val ${data['value'] ?? '?'}'),
                      ]),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _loadIntoForm(doc.id, data),
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
