import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import 'auth_gate.dart';
import 'parent_area_screen.dart';
import 'reading_screen.dart';
import 'rewards_screen.dart';

/// Startbildschirm: oben „Wer liest?“ (Kinderauswahl), darunter Punkte,
/// Rekord, Sprache und der große Start-Knopf für das gewählte Kind.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.service});

  final FamilyService service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedId;

  FamilyService get service => widget.service;

  // Streams nur einmal anlegen, damit beim Kind-Wechseln nichts neu lädt.
  late final Stream<Family> _family = service.watchFamily();
  late final Stream<List<Child>> _kids = service.watchChildren();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Family>(
      stream: _family,
      builder: (context, famSnap) => StreamBuilder<List<Child>>(
        stream: _kids,
        builder: (context, kidsSnap) {
          if (famSnap.hasError || kidsSnap.hasError) {
            return _NoAccess(error: '${famSnap.error ?? kidsSnap.error}', service: service);
          }
          if (!famSnap.hasData || !kidsSnap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final family = famSnap.data!;
          final kids = kidsSnap.data!;
          final child = kids.where((c) => c.id == _selectedId).firstOrNull ??
              kids.firstOrNull;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Kasem Lese App'),
              actions: [
                IconButton(
                  tooltip: 'Elternbereich',
                  icon: const Icon(Icons.lock_outline),
                  onPressed: () =>
                      openParentArea(context, service, family, child?.id),
                ),
              ],
            ),
            body: SafeArea(
              child: child == null
                  ? const _NoChildren()
                  : _ChildHome(
                      service: service,
                      family: family,
                      kids: kids,
                      child: child,
                      onSelect: (id) => setState(() => _selectedId = id),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ChildHome extends StatelessWidget {
  const _ChildHome({
    required this.service,
    required this.family,
    required this.kids,
    required this.child,
    required this.onSelect,
  });

  final FamilyService service;
  final Family family;
  final List<Child> kids;
  final Child child;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (kids.length > 1) ...[
          const Text('Wer liest?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final k in kids)
                  _KidAvatar(
                    kid: k,
                    selected: k.id == child.id,
                    onTap: () => onSelect(k.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Echse mit Sprechblase
        Row(
          children: [
            Image.asset('assets/kasem.png', height: 160),
            const SizedBox(width: 8),
            Expanded(
              child: _SpeechBubble(
                  text: 'Hallo ${child.name}! ${child.emoji}\nLust zu lesen?'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: '⭐',
                value: '${child.pointsAvailable}',
                label: 'Punkte',
                color: KasemColors.yellow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: '🏆',
                value: '${child.bestWpm}',
                label: 'Rekord\nWörter/Min',
                color: KasemColors.sky,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Punkte gibt es ab ${family.pointsThreshold} Wörtern in einer Minute!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                  childId: child.id,
                  language: child.language,
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
                builder: (_) =>
                    RewardsScreen(service: service, childId: child.id))),
          ),
        ),
      ],
    );
  }
}

class _KidAvatar extends StatelessWidget {
  const _KidAvatar({required this.kid, required this.selected, required this.onTap});

  final Child kid;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? KasemColors.yellow : Colors.white,
                border: Border.all(
                  color: selected ? KasemColors.orange : KasemColors.green,
                  width: selected ? 5 : 2,
                ),
              ),
              child: Text(kid.emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 4),
            Text(kid.name,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _NoChildren extends StatelessWidget {
  const _NoChildren();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/kasem.png', height: 160),
            const SizedBox(height: 16),
            const Text(
              'Noch kein Kind angelegt.\nIm Elternbereich 🔒 → Familie → „Kind hinzufügen“.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wird gezeigt, wenn dieses Handy keinen Zugriff (mehr) auf die Familie hat.
class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.error, required this.service});

  final String error;
  final FamilyService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasem Lese App')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, size: 64),
              const SizedBox(height: 16),
              Text(
                'Kein Zugriff auf die Familie.\n'
                'Ist das Handy online? Wurden die Firestore-Regeln veröffentlicht?\n\n$error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => AuthGate.restart(context),
                child: const Text('Nochmal versuchen'),
              ),
              TextButton(
                onPressed: () async {
                  await DeviceService(service.uid)
                      .leaveFamily(service.code)
                      .catchError((_) {});
                  if (context.mounted) AuthGate.restart(context);
                },
                child: const Text('Neu mit Familien-Code verbinden'),
              ),
            ],
          ),
        ),
      ),
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
