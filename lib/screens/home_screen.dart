import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import 'parent_area_screen.dart';
import 'reading_screen.dart';
import 'rewards_screen.dart';

/// Startbildschirm für das Kind.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.service});

  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Profile>(
      stream: service.watchProfile(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final p = snap.data!;
        final name = p.childName.isEmpty ? 'Lese-Held' : p.childName;
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Lese-Trainer'),
            actions: [
              IconButton(
                tooltip: 'Elternbereich',
                icon: const Icon(Icons.lock_outline),
                onPressed: () => openParentArea(context, service, p),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Hallo $name! 👋',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: '⭐',
                        value: '${p.pointsAvailable}',
                        label: 'Punkte',
                        color: scheme.primaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: '🏆',
                        value: '${p.bestWpm}',
                        label: 'Rekord (Wörter/Min)',
                        color: scheme.tertiaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('In welcher Sprache liest du?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<ReadingLanguage>(
                  segments: [
                    for (final l in ReadingLanguage.values)
                      ButtonSegment(value: l, label: Text('${l.flag} ${l.label}')),
                  ],
                  selected: {p.language},
                  onSelectionChanged: (s) => service.setLanguage(s.first),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 120,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReadingScreen(
                          service: service,
                          language: p.language,
                        ),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📖', style: TextStyle(fontSize: 40)),
                        Text('Lesen starten (1 Minute)',
                            style: TextStyle(fontSize: 22)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Text('🎁', style: TextStyle(fontSize: 22)),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Meine Geschenke', style: TextStyle(fontSize: 18)),
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RewardsScreen(service: service))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final String icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
