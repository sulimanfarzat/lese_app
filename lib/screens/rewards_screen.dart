import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';

/// Kinder-Ansicht: alle Geschenke mit Fortschrittsbalken.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key, required this.service});

  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎁 Meine Geschenke')),
      body: StreamBuilder<Profile>(
        stream: service.watchProfile(),
        builder: (context, pSnap) => StreamBuilder<List<Reward>>(
          stream: service.watchRewards(),
          builder: (context, rSnap) {
            if (!pSnap.hasData || !rSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final p = pSnap.data!;
            final open = rSnap.data!.where((r) => !r.redeemed).toList();
            final done = rSnap.data!.where((r) => r.redeemed).toList();

            if (open.isEmpty && done.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Noch keine Geschenke.\nFrag Mama oder Papa, ob sie welche eintragen!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in open) RewardTile(reward: r, profile: p),
                if (done.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
                    child: Text('Schon bekommen ✅',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  for (final r in done) RewardTile(reward: r, profile: p),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class RewardTile extends StatelessWidget {
  const RewardTile({super.key, required this.reward, required this.profile, this.trailing});

  final Reward reward;
  final Profile profile;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final unlocked = reward.isUnlocked(profile);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: unlocked ? scheme.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(reward.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(reward.type == RewardType.points
                      ? '⭐ ${reward.describe()}'
                      : '🏆 ${reward.describe()}'),
                  const SizedBox(height: 6),
                  if (reward.redeemed)
                    const Text('Bekommen ✅')
                  else if (unlocked)
                    const Text('Freigeschaltet! 🎉',
                        style: TextStyle(fontWeight: FontWeight.bold))
                  else
                    LinearProgressIndicator(
                      value: reward.progress(profile),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
