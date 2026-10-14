import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

/// Kinder-Ansicht: alle Geschenke der Familie mit Fortschritt für dieses Kind.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, required this.service, required this.childId});

  final FamilyService service;
  final String childId;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late final _child = widget.service.watchChild(widget.childId);
  late final _rewards = widget.service.watchRewards();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Child>(
      stream: _child,
      builder: (context, cSnap) => StreamBuilder<List<Reward>>(
        stream: _rewards,
        builder: (context, rSnap) {
          final child = cSnap.data;
          return Scaffold(
            appBar: AppBar(
              title: Text(child == null ? '🎁 Geschenke' : '🎁 Geschenke für ${child.name}'),
            ),
            body: (child == null || !rSnap.hasData)
                ? const Center(child: CircularProgressIndicator())
                : _list(child, rSnap.data!),
          );
        },
      ),
    );
  }

  Widget _list(Child child, List<Reward> rewards) {
    if (rewards.isEmpty) {
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
    final open = rewards.where((r) => !r.isRedeemedBy(child)).toList();
    final done = rewards.where((r) => r.isRedeemedBy(child)).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: KasemColors.yellow,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '⭐ ${child.pointsAvailable} Punkte   ·   🏆 ${child.bestWpm} Wörter/Min',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final r in open) RewardTile(reward: r, child: child),
        if (done.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: Text('Schon bekommen ✅',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          for (final r in done) RewardTile(reward: r, child: child),
        ],
      ],
    );
  }
}

/// Ein Geschenk mit Fortschrittsbalken für ein bestimmtes Kind.
class RewardTile extends StatelessWidget {
  const RewardTile({super.key, required this.reward, required this.child, this.trailing});

  final Reward reward;
  final Child child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final unlocked = reward.isUnlockedFor(child);
    final redeemed = reward.isRedeemedBy(child);
    return Card(
      color: unlocked ? const Color(0xFFFFD6E8) : Colors.white,
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
                  if (redeemed)
                    const Text('Bekommen ✅')
                  else if (unlocked)
                    const Text('Freigeschaltet! 🎉',
                        style: TextStyle(fontWeight: FontWeight.bold))
                  else
                    LinearProgressIndicator(
                      value: reward.progress(child),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
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
