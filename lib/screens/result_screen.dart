import 'package:flutter/material.dart';

import '../models/models.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final SessionResult result;

  String get _praise {
    if (result.isNewRecord) return 'NEUER REKORD! 🏆';
    if (result.words >= result.previousBest * 0.9) return 'Super gemacht! 🌟';
    if (result.words > 0) return 'Gut gelesen! 👍';
    return 'Ich habe nichts gehört 🙉 – lies lauter!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ergebnis')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_praise,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text('${result.words}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary)),
            const Text('Wörter in 1 Minute',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Text('⭐', style: TextStyle(fontSize: 32)),
                title: Text('+${result.points} Punkte',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                subtitle: result.isNewRecord
                    ? Text('inkl. Rekord-Bonus · alter Rekord: ${result.previousBest}')
                    : Text('Dein Rekord: ${result.previousBest}'),
              ),
            ),
            if (result.newlyUnlocked.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('🎉 Geschenk freigeschaltet! 🎉',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final r in result.newlyUnlocked)
                        Text('${r.emoji} ${r.title}',
                            style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      const Text('Zeig das Mama oder Papa!'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Fertig', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
