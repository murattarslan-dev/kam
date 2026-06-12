import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../battle/domain/entities/buff_entities.dart';
import '../../../battle/domain/entities/hero_entities.dart';
import '../enum_labels.dart';
import '../widgets/admin_scaffold.dart';

class HeroAdminScreen extends StatefulWidget {
  const HeroAdminScreen({super.key});

  @override
  State<HeroAdminScreen> createState() => _HeroAdminScreenState();
}

class _HeroAdminScreenState extends State<HeroAdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String _id = '';
  String _name = '';
  String _description = '';
  HeroElement _element = HeroElement.fire;
  HeroRole _role = HeroRole.warrior;
  int _hp = 800;
  int _atk = 100;
  int _def = 50;
  String _faction = '';
  String _imageUrl = '';
  final List<String> _tozler = [];

  bool _saving = false;
  String? _editingId;

  List<BuffEntity> _allBuffs = const [];

  @override
  void initState() {
    super.initState();
    _loadBuffs();
  }

  Future<void> _loadBuffs() async {
    final snap = await _firestore.collection('buffs').get();
    final buffs = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return BuffEntity.fromMap(data);
    }).toList();
    buffs.sort((a, b) => a.name.compareTo(b.name));
    if (mounted) setState(() => _allBuffs = buffs);
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _id = '';
      _name = '';
      _description = '';
      _element = HeroElement.fire;
      _role = HeroRole.warrior;
      _hp = 800;
      _atk = 100;
      _def = 50;
      _faction = '';
      _imageUrl = '';
      _tozler.clear();
    });
    _formKey.currentState?.reset();
  }

  void _loadIntoForm(String docId, Map<String, dynamic> data) {
    setState(() {
      _editingId = docId;
      _id = docId;
      _name = data['name'] as String? ?? '';
      _description = data['description'] as String? ?? '';
      _element = HeroElement.fromString(data['element'] as String? ?? 'fire');
      _role = HeroRole.fromString(data['role'] as String? ?? 'warrior');
      _hp = (data['hp'] as num?)?.toInt() ?? 0;
      _atk = (data['atk'] as num?)?.toInt() ?? 0;
      _def = (data['def'] as num?)?.toInt() ?? 0;
      _faction = data['faction'] as String? ?? '';
      _imageUrl = data['imageUrl'] as String? ?? '';
      _tozler
        ..clear()
        ..addAll(((data['tozler'] as List?) ?? const [])
            .map((e) => e.toString()));
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
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    final id = _editingId ?? (_id.isNotEmpty ? _id : _slugify(_name));
    if (id.isEmpty) return;

    setState(() => _saving = true);
    try {
      await _firestore.collection('heroes').doc(id).set({
        'name': _name,
        'description': _description,
        'element': _element.name,
        'role': _role.name,
        'hp': _hp,
        'atk': _atk,
        'def': _def,
        'faction': _faction,
        'imageUrl': _imageUrl,
        'tozler': List<String>.from(_tozler),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kahraman sil'),
        content: Text('"$id" kahramanı ve skills alt-koleksiyonu silinsin mi?'),
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
    final ref = _firestore.collection('heroes').doc(id);
    final skillsSnap = await ref.collection('skills').get();
    for (final s in skillsSnap.docs) {
      await s.reference.delete();
    }
    await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Kahramanlar',
      currentPath: '/admin/heroes',
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
                    _editingId != null ? 'Düzenle: $_editingId' : 'Yeni kahraman',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_editingId != null)
                  TextButton(onPressed: _resetForm, child: const Text('Sıfırla')),
              ],
            ),
            const SizedBox(height: 8),
            AdminSection(
              title: 'Kimlik',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  TextFormField(
                    key: ValueKey('id-$_editingId'),
                    initialValue: _id,
                    enabled: _editingId == null,
                    decoration: const InputDecoration(
                      labelText: 'ID (slug)',
                      helperText: 'Boş bırakılırsa addan üretilir.',
                      hintText: 'itbarak',
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
                    maxLines: 3,
                    onSaved: (v) => _description = (v ?? '').trim(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('img-$_editingId'),
                    initialValue: _imageUrl,
                    decoration: const InputDecoration(labelText: 'Görsel URL (opsiyonel)'),
                    onSaved: (v) => _imageUrl = (v ?? '').trim(),
                  ),
                ],
              ),
            ),
            AdminSection(
              title: 'Sınıflandırma',
              icon: Icons.category_outlined,
              child: Column(
                children: [
                  AdminTwoCol(
                    left: DropdownButtonFormField<HeroElement>(
                      initialValue: _element,
                      decoration: const InputDecoration(labelText: 'Element'),
                      items: HeroElement.values
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(EnumLabels.fmt(e, EnumLabels.heroElement)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _element = v!),
                    ),
                    right: DropdownButtonFormField<HeroRole>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: HeroRole.values
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(EnumLabels.fmt(r, EnumLabels.heroRole)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('faction-$_editingId'),
                    initialValue: _faction,
                    decoration: const InputDecoration(
                      labelText: 'Takım (faction)',
                      helperText: 'Kaos / Yer / Gök vs.',
                    ),
                    onSaved: (v) => _faction = (v ?? '').trim(),
                  ),
                ],
              ),
            ),
            AdminSection(
              title: 'Statlar',
              icon: Icons.bolt,
              child: Column(
                children: [
                  AdminTwoCol(
                    left: TextFormField(
                      key: ValueKey('hp-$_editingId'),
                      initialValue: '$_hp',
                      decoration: const InputDecoration(
                        labelText: 'HP / CP',
                        helperText: 'Toplam can',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Sayı' : null,
                      onSaved: (v) => _hp = int.parse(v!),
                    ),
                    right: TextFormField(
                      key: ValueKey('atk-$_editingId'),
                      initialValue: '$_atk',
                      decoration: const InputDecoration(labelText: 'Saldırı'),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Sayı' : null,
                      onSaved: (v) => _atk = int.parse(v!),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('def-$_editingId'),
                    initialValue: '$_def',
                    decoration: const InputDecoration(labelText: 'Savunma'),
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Sayı' : null,
                    onSaved: (v) => _def = int.parse(v!),
                  ),
                ],
              ),
            ),
            AdminSection(
              title: 'Tözler',
              icon: Icons.auto_awesome,
              subtitle:
                  'Kahramanın sahip olduğu Tözler — sadece manuel tetikli buff\'lar seçilebilir. Maliyet ve kullanım koşulu buff\'ın kendisinden okunur.',
              child: _buildTozlerEditor(),
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

  Widget _buildTozlerEditor() {
    final manualBuffs = _allBuffs.where((b) => b.isManual).toList();
    if (manualBuffs.isEmpty) {
      return Text(
        'Henüz manuel tetikli buff yok. Önce Buff\'lar sekmesinden ekleyin.',
        style: TextStyle(color: Theme.of(context).hintColor),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: manualBuffs.map((b) {
        final isSel = _tozler.contains(b.id);
        final cost = b.cost ?? 0;
        return FilterChip(
          label: Text('${b.name} · $cost Kut',
              style: const TextStyle(fontSize: 12)),
          selected: isSel,
          onSelected: (v) => setState(() {
            if (v) {
              if (!_tozler.contains(b.id)) _tozler.add(b.id);
            } else {
              _tozler.remove(b.id);
            }
          }),
        );
      }).toList(),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('heroes').orderBy('name').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Kahraman yok.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.list, size: 18),
                  const SizedBox(width: 8),
                  Text('Kahramanlar (${docs.length})',
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
                  final element = HeroElement.fromString(data['element'] as String? ?? 'fire');
                  final role = HeroRole.fromString(data['role'] as String? ?? 'warrior');
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 36, height: 36,
                        child: (data['imageUrl'] as String?)?.isNotEmpty == true
                            ? ClipOval(
                                child: Image.network(
                                  data['imageUrl'] as String,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.shield, size: 20),
                                ),
                              )
                            : const Icon(Icons.shield, size: 20),
                      ),
                      title: Text(data['name'] as String? ?? doc.id),
                      subtitle: Wrap(spacing: 4, runSpacing: 2, children: [
                        _Chip(EnumLabels.heroElement[element] ?? element.name),
                        _Chip(EnumLabels.heroRole[role] ?? role.name),
                        if ((data['faction'] as String?)?.isNotEmpty ?? false)
                          _Chip(data['faction'] as String),
                        _Chip('hp ${data['hp'] ?? '?'}'),
                        _Chip('atk ${data['atk'] ?? '?'}'),
                        _Chip('def ${data['def'] ?? '?'}'),
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
