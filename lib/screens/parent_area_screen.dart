import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import 'rewards_screen.dart';

/// Fragt die PIN ab (oder legt sie beim ersten Mal an) und öffnet den Elternbereich.
Future<void> openParentArea(
    BuildContext context, FirestoreService service, Profile p) async {
  final firstTime = p.pinHash == null;
  final pin = await showDialog<String>(
    context: context,
    builder: (_) => _PinDialog(createNew: firstTime),
  );
  if (pin == null || !context.mounted) return;

  if (firstTime) {
    await service.setPin(pin);
  } else if (!service.checkPin(p, pin)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Falsche PIN')));
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ParentAreaScreen(service: service),
  ));
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.createNew});
  final bool createNew;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
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
      title: Text(widget.createNew ? 'Eltern-PIN festlegen' : 'Eltern-PIN'),
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

class ParentAreaScreen extends StatelessWidget {
  const ParentAreaScreen({super.key, required this.service});

  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Elternbereich'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.card_giftcard), text: 'Geschenke'),
            Tab(icon: Icon(Icons.history), text: 'Verlauf'),
            Tab(icon: Icon(Icons.settings), text: 'Einstellungen'),
          ]),
        ),
        body: StreamBuilder<Profile>(
          stream: service.watchProfile(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final p = snap.data!;
            return TabBarView(children: [
              _RewardsTab(service: service, profile: p),
              _HistoryTab(service: service),
              _SettingsTab(service: service, profile: p),
            ]);
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Geschenke-Tab

class _RewardsTab extends StatelessWidget {
  const _RewardsTab({required this.service, required this.profile});
  final FirestoreService service;
  final Profile profile;

  Future<void> _redeem(BuildContext context, Reward r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${r.emoji} ${r.title} übergeben?'),
        content: Text(r.type == RewardType.points
            ? 'Es werden ${r.threshold} Punkte abgezogen.'
            : 'Das Geschenk wird als erhalten markiert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Übergeben')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await service.redeemReward(r);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
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
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rewards = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Verfügbar: ${profile.pointsAvailable} Punkte · '
                'Rekord: ${profile.bestWpm} Wörter/Min',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Punkte-Regel: 1 Punkt pro Wort, +${FirestoreService.recordBonus} '
                'Bonus bei neuem Rekord.',
              ),
              const SizedBox(height: 12),
              if (rewards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Noch keine Geschenke. Tippe auf „+ Geschenk“.',
                      textAlign: TextAlign.center),
                ),
              for (final r in rewards)
                RewardTile(
                  reward: r,
                  profile: profile,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.isUnlocked(profile))
                        IconButton.filled(
                          tooltip: 'Übergeben',
                          icon: const Icon(Icons.check),
                          onPressed: () => _redeem(context, r),
                        ),
                      IconButton(
                        tooltip: 'Löschen',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => service.deleteReward(r),
                      ),
                    ],
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
  final FirestoreService service;

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
                    : 'Einmalig, sobald der Rekord erreicht ist',
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
  const _HistoryTab({required this.service});
  final FirestoreService service;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.'
      '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReadingSession>>(
      stream: service.watchSessions(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snap.data!;
        if (sessions.isEmpty) {
          return const Center(child: Text('Noch keine Lese-Runden.'));
        }
        final avg = sessions.map((s) => s.words).reduce((a, b) => a + b) /
            sessions.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${sessions.length} Runden · Ø ${avg.toStringAsFixed(1)} Wörter/Min',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final s in sessions)
              Card(
                child: ListTile(
                  leading: Text(s.language.flag, style: const TextStyle(fontSize: 28)),
                  title: Text('${s.words} Wörter${s.isRecord ? '  🏆' : ''}'),
                  subtitle: Text('${_fmt(s.createdAt)} · +${s.points} Punkte'),
                  trailing: IconButton(
                    tooltip: 'Runde löschen (z. B. Fehlmessung)',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Runde löschen?'),
                          content: Text(
                              'Die ${s.points} Punkte dieser Runde werden abgezogen.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Abbrechen')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Löschen')),
                          ],
                        ),
                      );
                      if (ok == true) await service.deleteSession(s);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------- Einstellungen-Tab

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.service, required this.profile});
  final FirestoreService service;
  final Profile profile;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final _name = TextEditingController(text: widget.profile.childName);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Name des Kindes',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              await widget.service.setChildName(_name.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Gespeichert')));
              }
            },
            child: const Text('Speichern'),
          ),
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('PIN ändern'),
          onTap: () async {
            final pin = await showDialog<String>(
              context: context,
              builder: (_) => const _PinDialog(createNew: true),
            );
            if (pin != null) await widget.service.setPin(pin);
            if (pin != null && context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('PIN geändert')));
            }
          },
        ),
      ],
    );
  }
}
