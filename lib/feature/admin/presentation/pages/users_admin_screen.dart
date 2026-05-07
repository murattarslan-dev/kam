import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/admin_scaffold.dart';

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  final _firestore = FirebaseFirestore.instance;

  String? _selectedUid;
  List<String> _userIds = [];
  List<MapEntry<String, String>> _allHeroes = []; // (id, name)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final users = await _firestore.collection('users').get();
    final heroes = await _firestore.collection('heroes').orderBy('name').get();

    final ids = <String>{};
    for (final d in users.docs) {
      ids.add(d.id);
    }
    // Subcollection-only kullanıcılar için: heroes alt-kolleksiyonunda dokümanı
    // olan ama parent dokümanı olmayanları yakala. Firestore listCollectionIds
    // istemci SDK'da yok; bu yüzden auth uid de listede olmayabilir. Ana liste
    // için users.get() çıktısı yeterli — gerekirse "elle ekle" alanı sunulur.

    if (!mounted) return;
    setState(() {
      _userIds = ids.toList()..sort();
      _allHeroes = heroes.docs
          .map((d) => MapEntry(d.id, d.data()['name'] as String? ?? d.id))
          .toList();
      _loading = false;
      _selectedUid ??= _userIds.isNotEmpty ? _userIds.first : null;
    });
  }

  Future<void> _addUidManually() async {
    final controller = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcı UID gir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'IKATT9z1LnPFpxuU0wVED4NgyC03'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Aç'),
          ),
        ],
      ),
    );
    if (uid != null && uid.isNotEmpty) {
      setState(() {
        if (!_userIds.contains(uid)) _userIds = [..._userIds, uid]..sort();
        _selectedUid = uid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Kullanıcılar',
      currentPath: '/admin/users',
      actions: [
        TextButton.icon(
          onPressed: _addUidManually,
          icon: const Icon(Icons.person_add),
          label: const Text('UID ile aç'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        IconButton(
          tooltip: 'Yenile',
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadAll,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final list = _buildUserList();
                final detail = _selectedUid == null
                    ? const Center(child: Text('Kullanıcı seç.'))
                    : _UserDetail(
                        key: ValueKey(_selectedUid),
                        uid: _selectedUid!,
                        allHeroes: _allHeroes,
                      );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 280, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(child: detail),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(height: 220, child: list),
                    const Divider(height: 1),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildUserList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.list, size: 18),
              const SizedBox(width: 8),
              Text('Kullanıcılar (${_userIds.length})',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Expanded(
          child: _userIds.isEmpty
              ? const Center(child: Text('Kullanıcı yok'))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _userIds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (ctx, i) {
                    final uid = _userIds[i];
                    final selected = uid == _selectedUid;
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
                        title: Text(uid, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        onTap: () => setState(() => _selectedUid = uid),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _UserDetail extends StatefulWidget {
  final String uid;
  final List<MapEntry<String, String>> allHeroes;
  const _UserDetail({super.key, required this.uid, required this.allHeroes});

  @override
  State<_UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends State<_UserDetail> {
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> _meta = {};
  bool _metaLoading = true;
  bool _metaSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final doc = await _firestore.collection('users').doc(widget.uid).get();
    if (!mounted) return;
    setState(() {
      _meta = Map<String, dynamic>.from(doc.data() ?? {});
      _metaLoading = false;
    });
  }

  Future<void> _saveMeta() async {
    setState(() => _metaSaving = true);
    try {
      await _firestore.collection('users').doc(widget.uid).set(_meta, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meta kaydedildi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _metaSaving = false);
    }
  }

  Future<void> _addMetaField() async {
    final keyCtrl = TextEditingController();
    final valCtrl = TextEditingController();
    String type = 'string';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Yeni alan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(labelText: 'Anahtar'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Tip'),
                items: const [
                  DropdownMenuItem(value: 'string', child: Text('Metin')),
                  DropdownMenuItem(value: 'int', child: Text('Tamsayı')),
                  DropdownMenuItem(value: 'double', child: Text('Ondalık')),
                  DropdownMenuItem(value: 'bool', child: Text('Doğru/Yanlış')),
                ],
                onChanged: (v) => setLocal(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valCtrl,
                decoration: const InputDecoration(labelText: 'Değer'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle')),
          ],
        ),
      ),
    );
    if (saved != true || keyCtrl.text.isEmpty) return;
    final raw = valCtrl.text;
    dynamic parsed;
    switch (type) {
      case 'int':
        parsed = int.tryParse(raw) ?? 0;
        break;
      case 'double':
        parsed = double.tryParse(raw) ?? 0.0;
        break;
      case 'bool':
        parsed = raw.toLowerCase() == 'true' || raw == '1';
        break;
      default:
        parsed = raw;
    }
    setState(() => _meta[keyCtrl.text] = parsed);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.uid,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('users/${widget.uid}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontFamily: 'monospace',
                  )),
          const SizedBox(height: 16),
          AdminSection(
            title: 'Meta veriler',
            icon: Icons.person_outline,
            subtitle: 'users/{uid} dokümanının root alanları.',
            child: _metaLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildMetaEditor(),
          ),
          AdminSection(
            title: 'Sahip olunan kahramanlar',
            icon: Icons.shield,
            subtitle: 'users/{uid}/heroes alt-koleksiyonu (xp düzenlenebilir).',
            child: _buildHeroesEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_meta.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bu kullanıcının dokümanında alan yok. "Alan ekle" ile başla.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          )
        else
          for (final key in _meta.keys.toList())
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(key,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: _MetaValueField(
                      value: _meta[key],
                      onChanged: (v) => setState(() => _meta[key] = v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _meta.remove(key)),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton.icon(
              onPressed: _addMetaField,
              icon: const Icon(Icons.add),
              label: const Text('Alan ekle'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _metaSaving ? null : _saveMeta,
              icon: _metaSaving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroesEditor() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .doc(widget.uid)
          .collection('heroes')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data?.docs ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Kullanıcının kahramanı yok.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              )
            else
              for (final doc in docs)
                _UserHeroRow(
                  key: ValueKey(doc.id),
                  uid: widget.uid,
                  docId: doc.id,
                  data: doc.data(),
                  allHeroes: widget.allHeroes,
                ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addHeroDialog,
                icon: const Icon(Icons.add),
                label: const Text('Kahraman ekle'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addHeroDialog() async {
    String? heroId;
    final xpCtrl = TextEditingController(text: '0');
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Kahraman ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: heroId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kahraman'),
                  items: widget.allHeroes
                      .map((h) => DropdownMenuItem(
                            value: h.key,
                            child: Text('${h.value} (${h.key})'),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => heroId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: xpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Başlangıç XP'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: heroId == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
    if (added != true || heroId == null) return;
    await _firestore
        .collection('users')
        .doc(widget.uid)
        .collection('heroes')
        .add({
      'hero_id': heroId,
      'xp': int.tryParse(xpCtrl.text) ?? 0,
    });
  }
}

class _UserHeroRow extends StatefulWidget {
  final String uid;
  final String docId;
  final Map<String, dynamic> data;
  final List<MapEntry<String, String>> allHeroes;
  const _UserHeroRow({
    super.key,
    required this.uid,
    required this.docId,
    required this.data,
    required this.allHeroes,
  });

  @override
  State<_UserHeroRow> createState() => _UserHeroRowState();
}

class _UserHeroRowState extends State<_UserHeroRow> {
  late TextEditingController _xpCtrl;
  late String _heroId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _heroId = widget.data['hero_id'] as String? ?? '';
    final rawXp = widget.data['xp'];
    final xp = rawXp is int ? rawXp : (int.tryParse('$rawXp') ?? 0);
    _xpCtrl = TextEditingController(text: '$xp');
  }

  @override
  void dispose() {
    _xpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('heroes')
          .doc(widget.docId)
          .update({
        'hero_id': _heroId,
        'xp': int.tryParse(_xpCtrl.text) ?? 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncellendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: Text('${widget.docId} silinsin mi?'),
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
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('heroes')
        .doc(widget.docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final knownHero = widget.allHeroes.any((h) => h.key == _heroId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              initialValue: knownHero ? _heroId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kahraman', isDense: true),
              items: [
                if (!knownHero && _heroId.isNotEmpty)
                  DropdownMenuItem(
                    value: _heroId,
                    child: Text('(silinmiş) $_heroId'),
                  ),
                ...widget.allHeroes.map((h) => DropdownMenuItem(
                      value: h.key,
                      child: Text(h.value),
                    )),
              ],
              onChanged: (v) => setState(() => _heroId = v ?? _heroId),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _xpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'XP', isDense: true),
            ),
          ),
          IconButton(
            tooltip: 'Kaydet',
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            onPressed: _saving ? null : _save,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: _delete,
          ),
        ],
      ),
    );
  }
}

class _MetaValueField extends StatefulWidget {
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  const _MetaValueField({required this.value, required this.onChanged});

  @override
  State<_MetaValueField> createState() => _MetaValueFieldState();
}

class _MetaValueFieldState extends State<_MetaValueField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value ?? ''}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value is bool) {
      return Switch(
        value: widget.value as bool,
        onChanged: widget.onChanged,
      );
    }
    final isInt = widget.value is int;
    final isDouble = widget.value is double;
    return TextField(
      controller: _ctrl,
      keyboardType: isInt || isDouble
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: const InputDecoration(isDense: true),
      onChanged: (v) {
        if (isInt) {
          widget.onChanged(int.tryParse(v) ?? 0);
        } else if (isDouble) {
          widget.onChanged(double.tryParse(v) ?? 0.0);
        } else {
          widget.onChanged(v);
        }
      },
    );
  }
}
