import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import 'auth_gate.dart';
import 'rewards_screen.dart';

const kidEmojis = ['🦎', '🦖', '🐼', '🦊', '🐸', '🐯', '🦄', '🐙', '🐨', '🦁', '🐰', '🐳'];

/// Fragt die Eltern-PIN ab und öffnet den Elternbereich.
Future<void> openParentArea(
  BuildContext context,
  FamilyService service,
  Family family,
  String? currentChildId,
) async {
  final firstTime = family.pinHash == null;
  final pin = await showDialog<String>(
    context: context,
    builder: (_) => PinDialog(createNew: firstTime),
  );
  if (pin == null || !context.mounted) return;

  if (firstTime) {
    await service.setPin(pin);
  } else if (!service.checkPin(family, pin)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Falsche PIN')));
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ParentAreaScreen(service: service, initialChildId: currentChildId),
  ));
}

class PinDialog extends StatefulWidget {
  const PinDialog({super.key, required this.createNew});
  final bool createNew;

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;

  void _submit() {
    if (_pin.text.length < 4) {
      setState(() => _error = 'Mindestens 4 Ziffern');
      return;
    }
    if (widget.createNew && _pin.text != _repeat.text) {
      setState(() => _error = 'PINs stimmen nicht überein');
      return;
    }
    Navigator.of(context).pop(_pin.text);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(widget.createNew ? 'Neue Eltern-PIN' : 'Eltern-PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            maxLength: 8,
            decoration: deco('PIN'),
            onSubmitted: (_) {
              if (!widget.createNew) _submit();
            },
          ),
          if (widget.createNew)
            TextField(
              controller: _repeat,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              maxLength: 8,
              decoration: deco('PIN wiederholen'),
              onSubmitted: (_) => _submit(),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String text, String action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}

void _snack(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

// =====================================================================

class ParentAreaScreen extends StatefulWidget {
  const ParentAreaScreen({super.key, required this.service, this.initialChildId});

  final FamilyService service;
  final String? initialChildId;

  @override
  State<ParentAreaScreen> createState() => _ParentAreaScreenState();
}

class _ParentAreaScreenState extends State<ParentAreaScreen> {
  late final _family = widget.service.watchFamily();
  late final _kids = widget.service.watchChildren();
  late String? _historyChildId = widget.initialChildId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Elternbereich'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: KasemColors.yellow,
            tabs: [
              Tab(icon: Icon(Icons.card_giftcard), text: 'Geschenke'),
              Tab(icon: Icon(Icons.history), text: 'Verlauf'),
              Tab(icon: Icon(Icons.family_restroom), text: 'Familie'),
            ],
          ),
        ),
        body: StreamBuilder<Family>(
          stream: _family,
          builder: (context, fSnap) => StreamBuilder<List<Child>>(
            stream: _kids,
            builder: (context, kSnap) {
              if (!fSnap.hasData || !kSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final family = fSnap.data!;
              final kids = kSnap.data!;
              final historyKid =
                  kids.where((k) => k.id == _historyChildId).firstOrNull ??
                      kids.firstOrNull;
              return TabBarView(children: [
                _RewardsTab(service: widget.service, family: family, kids: kids),
                _HistoryTab(
                  service: widget.service,
                  kids: kids,
                  selected: historyKid,
                  onSelect: (id) => setState(() => _historyChildId = id),
                ),
                _FamilyTab(service: widget.service, family: family, kids: kids),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Geschenke-Tab

class _RewardsTab extends StatelessWidget {
  const _RewardsTab({required this.service, required this.family, required this.kids});
  final FamilyService service;
  final Family family;
  final List<Kid> kids;

  Future<void> _redeem(BuildContext context, Reward r, Kid kid) async {
    final ok = await _confirm(
      context,
      '${r.emoji} ${r.title} an ${kid.name} übergeben?',
      r.type == RewardType.points
          ? '${kid.name} werden ${r.threshold} Punkte abgezogen.'
          : 'Das Geschenk wird für ${kid.name} als erhalten markiert.',
      'Übergeben',
    );
    if (!ok) return;
    try {
      await service.redeemReward(r, kid.id);
      if (context.mounted) _snack(context, '🎁 ${r.title} an ${kid.name} übergeben');
    } catch (e) {
      if (context.mounted) _snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Geschenk'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _AddRewardDialog(service: service),
        ),
      ),
      body: StreamBuilder<List<Reward>>(
        stream: service.watchRewards(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rewards = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Eine Geschenkliste für alle Kinder. Punkte und erhaltene '
                'Geschenke zählen für jedes Kind einzeln.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (rewards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Noch keine Geschenke. Tippe auf „+ Geschenk“.',
                      textAlign: TextAlign.center),
                ),
              for (final r in rewards)
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(r.emoji, style: const TextStyle(fontSize: 34)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(r.type == RewardType.points
                                    ? '⭐ ${r.describe()}'
                                    : '🏆 ${r.describe()}'),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Löschen',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (await _confirm(context, 'Geschenk löschen?',
                                  '${r.title} wird für alle Kinder entfernt.', 'Löschen')) {
                                await service.deleteReward(r);
                              }
                            },
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final k in kids)
                              if (r.isRedeemedBy(k))
                                Chip(label: Text('✅ ${k.emoji} ${k.name}'))
                              else if (r.isUnlockedFor(k))
                                ActionChip(
                                  backgroundColor: KasemColors.pink,
                                  labelStyle: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w800),
                                  label: Text('🎁 an ${k.name} übergeben'),
                                  onPressed: () => _redeem(context, r, k),
                                )
                              else
                                Chip(
                                  label: Text(
                                      '${k.emoji} ${k.name} ${(r.progress(k) * 100).round()} %'),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AddRewardDialog extends StatefulWidget {
  const _AddRewardDialog({required this.service});
  final FamilyService service;

  @override
  State<_AddRewardDialog> createState() => _AddRewardDialogState();
}

class _AddRewardDialogState extends State<_AddRewardDialog> {
  final _title = TextEditingController();
  final _emoji = TextEditingController(text: '🎁');
  final _threshold = TextEditingController();
  RewardType _type = RewardType.points;

  Future<void> _save() async {
    final threshold = int.tryParse(_threshold.text) ?? 0;
    if (_title.text.trim().isEmpty || threshold <= 0) return;
    await widget.service.addReward(
      title: _title.text,
      emoji: _emoji.text.trim(),
      type: _type,
      threshold: threshold,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Geschenk'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                      labelText: 'Was gibt es?', hintText: 'z. B. Eis essen gehen'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            SegmentedButton<RewardType>(
              segments: const [
                ButtonSegment(value: RewardType.points, label: Text('⭐ Punkte')),
                ButtonSegment(value: RewardType.record, label: Text('🏆 Rekord')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _threshold,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _type == RewardType.points
                    ? 'Preis in Punkten'
                    : 'Ziel: Wörter in 1 Minute',
                helperText: _type == RewardType.points
                    ? 'Punkte werden beim Übergeben abgezogen'
                    : 'Einmalig pro Kind, sobald der Rekord erreicht ist',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen')),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

// --------------------------------------------------------------- Verlauf-Tab

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.service,
    required this.kids,
    required this.selected,
    required this.onSelect,
  });

  final FamilyService service;
  final List<Kid> kids;
  final Kid? selected;
  final ValueChanged<String> onSelect;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.'
      '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final kid = selected;
    if (kid == null) return const Center(child: Text('Noch kein Kind angelegt.'));
    return Column(
      children: [
        if (kids.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final k in kids)
                  ChoiceChip(
                    label: Text('${k.emoji} ${k.name}'),
                    selected: k.id == kid.id,
                    onSelected: (_) => onSelect(k.id),
                  ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<List<ReadingSession>>(
            key: ValueKey(kid.id),
            stream: service.watchSessions(kid.id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sessions = snap.data!;
              if (sessions.isEmpty) {
                return Center(child: Text('${kid.name} hat noch nicht gelesen.'));
              }
              final avg = sessions.map((s) => s.words).reduce((a, b) => a + b) /
                  sessions.length;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${kid.name}: ${sessions.length} Runden · Ø ${avg.toStringAsFixed(1)} '
                    'Wörter/Min · Rekord ${kid.bestWpm}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final s in sessions)
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: Text(s.language.flag, style: const TextStyle(fontSize: 28)),
                        title: Text('${s.words} Wörter${s.isRecord ? '  🏆' : ''}'),
                        subtitle: Text('${_fmt(s.createdAt)} · +${s.points} Punkte'),
                        trailing: IconButton(
                          tooltip: 'Runde löschen (z. B. Fehlmessung)',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await _confirm(
                                context,
                                'Runde löschen?',
                                'Die ${s.points} Punkte dieser Runde werden ${kid.name} abgezogen.',
                                'Löschen')) {
                              await service.deleteSession(kid.id, s);
                            }
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Familie-Tab

class _FamilyTab extends StatefulWidget {
  const _FamilyTab({required this.service, required this.family, required this.kids});
  final FamilyService service;
  final Family family;
  final List<Kid> kids;

  @override
  State<_FamilyTab> createState() => _FamilyTabState();
}

class _FamilyTabState extends State<_FamilyTab> {
  late final _threshold =
      TextEditingController(text: '${widget.family.pointsThreshold}');
  late final _bonus = TextEditingController(text: '${widget.family.recordBonus}');

  FamilyService get service => widget.service;

  Future<void> _editChild([Kid? kid]) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _ChildDialog(kid: kid),
    );
    if (result == null) return;
    final (name, emoji) = result;
    if (kid == null) {
      await service.addChild(name, emoji);
    } else {
      await service.updateChild(kid.id, name: name, emoji: emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.family;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Familien-Code
        Card(
          color: KasemColors.yellow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('🔑 Familien-Code',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                SelectableText(f.displayCode,
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
                const Text(
                  'Auf einem anderen Handy die App öffnen → „Mit Familien-Code beitreten“',
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopieren'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: f.displayCode));
                    _snack(context, 'Code kopiert');
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Kinder
        Row(
          children: [
            const Expanded(
              child: Text('👧👦 Kinder',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Kind hinzufügen'),
              onPressed: () => _editChild(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final k in widget.kids)
          Card(
            color: Colors.white,
            child: ListTile(
              leading: Text(k.emoji, style: const TextStyle(fontSize: 32)),
              title: Text(k.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('⭐ ${k.pointsAvailable} Punkte · 🏆 ${k.bestWpm} Wörter/Min'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await _editChild(k);
                  } else if (v == 'delete' &&
                      await _confirm(
                          context,
                          '${k.name} löschen?',
                          'Alle Punkte, Rekorde und Lese-Runden von ${k.name} '
                              'werden auf allen Handys gelöscht.',
                          'Löschen')) {
                    await service.deleteChild(k.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Name / Bild ändern')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen')),
                ],
              ),
            ),
          ),
        const Divider(height: 32),

        // ---- Punkte-Regel
        const Text('⭐ Punkte-Regel (für alle Kinder)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          controller: _threshold,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Punkte ab … Wörtern pro Minute',
            helperText: 'Beispiel 100: 100 Wörter → 1 Punkt, 106 Wörter → 7 Punkte',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bonus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Bonuspunkte bei neuem Rekord',
            helperText: '0 = kein Bonus',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              final t = int.tryParse(_threshold.text) ?? 0;
              final b = int.tryParse(_bonus.text) ?? 0;
              if (t < 1) return;
              await service.setPointRules(threshold: t, bonus: b);
              if (context.mounted) _snack(context, 'Punkte-Regel gespeichert');
            },
            child: const Text('Speichern'),
          ),
        ),
        const Divider(height: 32),

        // ---- PIN + Abmelden
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('Eltern-PIN ändern (gilt auf allen Handys)'),
          onTap: () async {
            final pin = await showDialog<String>(
              context: context,
              builder: (_) => const PinDialog(createNew: true),
            );
            if (pin == null) return;
            await service.setPin(pin);
            if (context.mounted) _snack(context, 'PIN geändert');
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Dieses Handy von der Familie abmelden'),
          subtitle: const Text('Die Daten der Familie bleiben erhalten'),
          onTap: () async {
            if (!await _confirm(
                context,
                'Handy abmelden?',
                'Danach kann das Handy mit dem Code ${f.displayCode} wieder beitreten '
                    'oder eine neue Familie anlegen.',
                'Abmelden')) {
              return;
            }
            await DeviceService(service.uid).leaveFamily(service.code);
            if (context.mounted) AuthGate.restart(context);
          },
        ),
      ],
    );
  }
}

class _ChildDialog extends StatefulWidget {
  const _ChildDialog({this.kid});
  final Kid? kid;

  @override
  State<_ChildDialog> createState() => _ChildDialogState();
}

class _ChildDialogState extends State<_ChildDialog> {
  late final _name = TextEditingController(text: widget.kid?.name ?? '');
  late String _emoji = widget.kid?.emoji ?? kidEmojis[1];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.kid == null ? 'Kind hinzufügen' : 'Kind bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in kidEmojis)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e == _emoji ? KasemColors.yellow : Colors.transparent,
                        border: Border.all(
                            color: e == _emoji ? KasemColors.orange : Colors.black12,
                            width: e == _emoji ? 3 : 1),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop((name, _emoji));
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Kurzname, damit `child` (Flutter-Begriff für Widgets) nicht verwechselt wird.
typedef Kid = Child;
