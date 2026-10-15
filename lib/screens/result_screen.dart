import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final SessionResult result;

  bool get _reachedThreshold => result.words >= result.pointsThreshold;

  String get _praise {
    if (result.isNewRecord) return 'NEUER REKORD! 🏆';
    if (_reachedThreshold) return 'Super gemacht! 🌟';
    if (result.words > 0) return 'Gut gelesen! 👍';
    return 'Ich habe nichts gehört 🙉\nLies lauter!';
  }

  @override
  Widget build(BuildContext context) {
    final missing = result.pointsThreshold - result.words;
    return Scaffold(
      appBar: AppBar(title: const Text('Dein Ergebnis')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_praise,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            // Echse jubelt mit
            Stack(
              alignment: Alignment.center,
              children: [
                Image.asset('assets/kasem.png', height: 190),
                if (result.isNewRecord || _reachedThreshold)
                  const Positioned(
                    top: 0,
                    child: Text('🎉   ✨   🎉', style: TextStyle(fontSize: 34)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: KasemColors.sky,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Text('${result.words}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 80, fontWeight: FontWeight.w900, color: Colors.white)),
                  const Text('Wörter in 1 Minute',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: KasemColors.yellow,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const Text('⭐', style: TextStyle(fontSize: 36)),
                title: Text(
                  result.points > 0 ? '+${result.points} Punkte' : 'Noch keine Punkte',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  _reachedThreshold
                      ? (result.isNewRecord
                          ? 'mit Rekord-Bonus! Alter Rekord: ${result.previousBest}'
                          : 'Dein Rekord: ${result.previousBest}')
                      : (result.isNewRecord
                          ? 'Rekord-Bonus! Noch $missing Wörter bis zu den Lese-Punkten.'
                          : 'Noch $missing Wörter mehr – dann gibt es Punkte! 💪'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (result.newlyUnlocked.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: KasemColors.pink,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('🎁 Geschenk freigeschaltet! 🎁',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 8),
                      for (final r in result.newlyUnlocked)
                        Text('${r.emoji} ${r.title}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text('Zeig das Mama oder Papa!',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              result.savedOnline
                  ? '☁️ Gespeichert'
                  : '📶 Gespeichert auf dem Handy – wird hochgeladen, sobald Internet da ist',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fertig', style: TextStyle(fontSize: 22)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
