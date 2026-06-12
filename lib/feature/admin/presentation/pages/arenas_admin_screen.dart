import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../battle/domain/entities/arena_entities.dart';
import '../../../battle/domain/entities/hero_entities.dart';
import '../widgets/admin_scaffold.dart';

/// Arena CRUD + demo seed. Arenalar `arenas/{id}` koleksiyonunda tutulur.
class ArenasAdminScreen extends StatefulWidget {
  const ArenasAdminScreen({super.key});

  @override
  State<ArenasAdminScreen> createState() => _ArenasAdminScreenState();
}

class _ArenasAdminScreenState extends State<ArenasAdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String _id = '';
  String _name = '';
  String _description = '';
  String _backgroundUrl = '';
  String _thumbnailUrl = '';
  final Map<HeroElement, double> _effects = {
    for (final e in HeroElement.values) e: 1.0,
  };

  bool _saving = false;
  String? _editingId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('arenas');

  void _resetForm() {
    setState(() {
      _editingId = null;
      _id = '';
      _name = '';
      _description = '';
      _backgroundUrl = '';
      _thumbnailUrl = '';
      for (final e in HeroElement.values) {
        _effects[e] = 1.0;
      }
    });
    _formKey.currentState?.reset();
  }

  void _loadIntoForm(ArenaEntity a) {
    setState(() {
      _editingId = a.id;
      _id = a.id;
      _name = a.name;
      _description = a.description;
      _backgroundUrl = a.backgroundUrl;
      _thumbnailUrl = a.thumbnailUrl;
      for (final e in HeroElement.values) {
        _effects[e] = a.elementEffects[e] ?? 1.0;
      }
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    final id = _editingId ?? (_id.isNotEmpty ? _id : 'arena_${_slugify(_name)}');

    final arena = ArenaEntity(
      id: id,
      name: _name,
      description: _description,
      backgroundUrl: _backgroundUrl,
      thumbnailUrl: _thumbnailUrl,
      elementEffects: Map<HeroElement, double>.from(_effects),
    );

    setState(() => _saving = true);
    try {
      await _col.doc(id).set(arena.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arena kaydedildi: ${arena.name}')),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Arenayı sil?'),
        content: Text('$id silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('İPTAL')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('SİL')),
        ],
      ),
    );
    if (confirm != true) return;
    await _col.doc(id).delete();
    if (_editingId == id) _resetForm();
  }

  Future<void> _seedDemo() async {
    final batch = _firestore.batch();
    for (final a in _demoArenas()) {
      batch.set(_col.doc(a.id), a.toMap());
    }
    setState(() => _saving = true);
    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('10 demo arena yazıldı')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seed hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Arenalar',
      currentPath: '/admin/arenas',
      actions: [
        OutlinedButton.icon(
          onPressed: _saving ? null : _seedDemo,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('10 demo arena ekle'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _editingId == null ? null : _resetForm,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Yeni'),
        ),
      ],
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final list = _buildList();
        final form = _buildForm();
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: list),
              const VerticalDivider(width: 1),
              Expanded(flex: 3, child: SingleChildScrollView(child: form)),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(children: [form, const Divider(), list]),
        );
      }),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _col.orderBy('name').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Arena yok. Sağ üstten 10 demo arena ekleyebilirsin.'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final data = docs[i].data();
            data['id'] = docs[i].id;
            final a = ArenaEntity.fromMap(data);
            final effects = a.elementEffects.entries
                .where((e) => e.value != 1.0)
                .map((e) => '${e.key.label} ${e.value.toStringAsFixed(2)}')
                .join(' · ');
            return ListTile(
              leading: a.thumbnailUrl.isNotEmpty
                  ? CircleAvatar(backgroundImage: NetworkImage(a.thumbnailUrl))
                  : const CircleAvatar(child: Icon(Icons.terrain)),
              title: Text(a.name),
              subtitle: Text(
                effects.isEmpty ? 'Tüm elementler nötr' : effects,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _loadIntoForm(a),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => _delete(a.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSection(
              title: _editingId == null ? 'Yeni Arena' : 'Düzenle: $_editingId',
              icon: Icons.terrain,
              child: Column(
                children: [
                  TextFormField(
                    key: ValueKey('name_$_editingId'),
                    initialValue: _name,
                    decoration: const InputDecoration(labelText: 'İsim'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    onSaved: (v) => _name = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('desc_$_editingId'),
                    initialValue: _description,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                    maxLines: 2,
                    onSaved: (v) => _description = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('bg_$_editingId'),
                    initialValue: _backgroundUrl,
                    decoration: const InputDecoration(
                      labelText: 'Arka plan görsel URL',
                    ),
                    onSaved: (v) => _backgroundUrl = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('thumb_$_editingId'),
                    initialValue: _thumbnailUrl,
                    decoration: const InputDecoration(
                      labelText: 'Küçük görsel URL (seçici için)',
                    ),
                    onSaved: (v) => _thumbnailUrl = v?.trim() ?? '',
                  ),
                ],
              ),
            ),
            AdminSection(
              title: 'Element Etkileri',
              subtitle: '1.0 nötr · >1.0 avantaj · <1.0 dezavantaj',
              icon: Icons.balance,
              child: Column(
                children: HeroElement.values.map(_buildEffectRow).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_editingId != null) ...[
                  TextButton(
                    onPressed: _resetForm,
                    child: const Text('VAZGEÇ'),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(_editingId == null ? 'KAYDET' : 'GÜNCELLE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectRow(HeroElement element) {
    final value = _effects[element] ?? 1.0;
    Color color;
    if (value > 1.0) {
      color = Colors.green;
    } else if (value < 1.0) {
      color = Colors.redAccent;
    } else {
      color = Colors.grey;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(element.label),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0.5,
              max: 1.5,
              divisions: 20,
              label: value.toStringAsFixed(2),
              onChanged: (v) => setState(() => _effects[element] = v),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              value.toStringAsFixed(2),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Demo arena seti — 10 tane. Görsel URL'leri Unsplash CDN'inden çekilir
/// (sabit, herkese açık). Tek bir tıkla `arenas` koleksiyonuna yazılır.
List<ArenaEntity> _demoArenas() {
  Map<HeroElement, double> eff(Map<HeroElement, double> overrides) => {
        for (final e in HeroElement.values) e: overrides[e] ?? 1.0,
      };
  String bg(String id) =>
      'https://source.unsplash.com/1600x900/?$id';
  String thumb(String id) =>
      'https://source.unsplash.com/300x300/?$id';

  return [
    ArenaEntity(
      id: 'arena_bozkir',
      name: 'Bozkır',
      description: 'Uçsuz bucaksız bir step. Toynak sesleri bitmez.',
      backgroundUrl: bg('steppe,grassland'),
      thumbnailUrl: thumb('steppe,grassland'),
      elementEffects: eff({
        HeroElement.steppe: 1.3,
        HeroElement.wind: 1.1,
        HeroElement.forest: 0.8,
      }),
    ),
    ArenaEntity(
      id: 'arena_ergenekon',
      name: 'Ergenekon Vadisi',
      description: 'Dağlar arasında saklı, kutsal vadi.',
      backgroundUrl: bg('mountain,valley'),
      thumbnailUrl: thumb('mountain,valley'),
      elementEffects: eff({
        HeroElement.dark: 1.2,
        HeroElement.steppe: 1.1,
        HeroElement.fire: 0.8,
      }),
    ),
    ArenaEntity(
      id: 'arena_yeralti',
      name: 'Yeraltı',
      description: 'Erlik Han\'ın gölgesi her köşede.',
      backgroundUrl: bg('cave,underground'),
      thumbnailUrl: thumb('cave,underground'),
      elementEffects: eff({
        HeroElement.dark: 1.5,
        HeroElement.water: 1.1,
        HeroElement.fire: 0.6,
        HeroElement.wind: 0.7,
      }),
    ),
    ArenaEntity(
      id: 'arena_otuken_ormani',
      name: 'Ötüken Ormanı',
      description: 'Kutsal ağaçların altında savaş.',
      backgroundUrl: bg('ancient,forest'),
      thumbnailUrl: thumb('ancient,forest'),
      elementEffects: eff({
        HeroElement.forest: 1.4,
        HeroElement.fire: 0.6,
        HeroElement.wind: 0.8,
      }),
    ),
    ArenaEntity(
      id: 'arena_tuna',
      name: 'Tuna Nehri',
      description: 'Geniş, hızlı akan suların kıyısı.',
      backgroundUrl: bg('river,flowing'),
      thumbnailUrl: thumb('river,flowing'),
      elementEffects: eff({
        HeroElement.water: 1.4,
        HeroElement.forest: 1.1,
        HeroElement.fire: 0.7,
      }),
    ),
    ArenaEntity(
      id: 'arena_altay',
      name: 'Altay Dağları',
      description: 'Karlı doruklar, kesici rüzgâr.',
      backgroundUrl: bg('snow,mountain'),
      thumbnailUrl: thumb('snow,mountain'),
      elementEffects: eff({
        HeroElement.wind: 1.3,
        HeroElement.water: 1.1,
        HeroElement.fire: 0.8,
        HeroElement.steppe: 0.9,
      }),
    ),
    ArenaEntity(
      id: 'arena_issik_gol',
      name: 'Issık Göl',
      description: 'Soğuk dağ gölü, derinleri loş.',
      backgroundUrl: bg('lake,calm'),
      thumbnailUrl: thumb('lake,calm'),
      elementEffects: eff({
        HeroElement.water: 1.3,
        HeroElement.dark: 1.1,
        HeroElement.fire: 0.8,
      }),
    ),
    ArenaEntity(
      id: 'arena_karakum',
      name: 'Karakum Çölü',
      description: 'Yakıcı kumlar, susuz ufuk.',
      backgroundUrl: bg('desert,dunes'),
      thumbnailUrl: thumb('desert,dunes'),
      elementEffects: eff({
        HeroElement.fire: 1.4,
        HeroElement.steppe: 1.1,
        HeroElement.water: 0.6,
        HeroElement.forest: 0.7,
      }),
    ),
    ArenaEntity(
      id: 'arena_gok_tengri',
      name: 'Gök Tengri',
      description: 'Bulutların üstünde, açık göğün altında.',
      backgroundUrl: bg('sky,clouds'),
      thumbnailUrl: thumb('sky,clouds'),
      elementEffects: eff({
        HeroElement.wind: 1.4,
        HeroElement.fire: 1.1,
        HeroElement.dark: 0.7,
      }),
    ),
    ArenaEntity(
      id: 'arena_karanlik_magara',
      name: 'Karanlık Mağara',
      description: 'Işık zar zor sızar, sesler yankılanır.',
      backgroundUrl: bg('dark,cavern'),
      thumbnailUrl: thumb('dark,cavern'),
      elementEffects: eff({
        HeroElement.dark: 1.4,
        HeroElement.water: 1.0,
        HeroElement.forest: 0.8,
        HeroElement.fire: 0.9,
      }),
    ),
  ];
}
