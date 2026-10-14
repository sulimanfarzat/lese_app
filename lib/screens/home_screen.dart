import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
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
        final name = p.childName.isEmpty ? 'Kasem' : p.childName;
        final toFirstPoint = p.pointsThreshold;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Kasem Lese App'),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // Echse mit Sprechblase
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/kasem.png', height: 170),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SpeechBubble(
                        text: 'Hallo $name! 👋\nLust zu lesen?',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: '⭐',
                        value: '${p.pointsAvailable}',
                        label: 'Punkte',
                        color: KasemColors.yellow,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: '🏆',
                        value: '${p.bestWpm}',
                        label: 'Rekord\nWörter/Min',
                        color: KasemColors.sky,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Punkte gibt es ab $toFirstPoint Wörtern in einer Minute!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                const Text('In welcher Sprache liest du?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SegmentedButton<ReadingLanguage>(
                  segments: [
                    for (final l in ReadingLanguage.values)
                      ButtonSegment(value: l, label: Text('${l.flag} ${l.label}')),
                  ],
                  selected: {p.language},
                  onSelectionChanged: (s) => service.setLanguage(s.first),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 120,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: KasemColors.green,
                      elevation: 4,
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
                        Text('Lesen starten!',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: KasemColors.pink),
                    icon: const Text('🎁', style: TextStyle(fontSize: 26)),
                    label: const Text('Meine Geschenke',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RewardsScreen(service: service))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KasemColors.green, width: 3),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 30)),
            Text(value,
                style: const TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w900, color: KasemColors.ink)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, color: KasemColors.ink)),
          ],
        ),
      ),
    );
  }
}
