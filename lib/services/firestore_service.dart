import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../models/models.dart';

/// Struktur in Firestore:
///
/// users/{uid}                      → Profil (Punkte, Rekord, PIN-Hash, Sprache)
/// users/{uid}/sessions/{id}        → jede Lese-Minute als Record
/// users/{uid}/rewards/{id}         → Geschenke, die die Eltern festlegen
class FirestoreService {
  FirestoreService(this.uid);

  final String uid;
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _userRef.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _rewards =>
      _userRef.collection('rewards');

  /// Punkte-Regel: 1 Punkt pro gelesenem Wort, +20 Bonus bei neuem Rekord.
  static const int recordBonus = 20;
  static int pointsFor(int words, bool isRecord) =>
      words + (isRecord ? recordBonus : 0);

  // ---------------------------------------------------------------- Profil

  Future<void> ensureProfile() async {
    final snap = await _userRef.get();
    if (!snap.exists) {
      await _userRef.set({
        'childName': '',
        'pointsTotal': 0,
        'pointsSpent': 0,
        'bestWpm': 0,
        'pinHash': null,
        'language': ReadingLanguage.german.code,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<Profile> watchProfile() =>
      _userRef.snapshots().map(Profile.fromDoc);

  Future<void> setChildName(String name) =>
      _userRef.update({'childName': name.trim()});

  Future<void> setLanguage(ReadingLanguage lang) =>
      _userRef.update({'language': lang.code});

  // ------------------------------------------------------------- Eltern-PIN

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('lese_app:$pin')).toString();

  Future<void> setPin(String pin) => _userRef.update({'pinHash': _hash(pin)});

  bool checkPin(Profile p, String pin) => p.pinHash == _hash(pin);

  // ---------------------------------------------------------- Lese-Runden

  /// Speichert eine Runde und aktualisiert Punkte + Rekord in einer Transaktion.
  Future<SessionResult> saveSession({
    required int words,
    required ReadingLanguage language,
  }) async {
    // Zustand der Geschenke vorher merken, um neu freigeschaltete zu erkennen.
    final before = await _userRef.get().then(Profile.fromDoc);
    final rewards = await _rewards.where('redeemed', isEqualTo: false).get();
    final unlockedBefore = rewards.docs
        .map(Reward.fromDoc)
        .where((r) => r.isUnlocked(before))
        .map((r) => r.id)
        .toSet();

    late bool isRecord;
    late int points;
    late int previousBest;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_userRef);
      final p = Profile.fromDoc(snap);
      previousBest = p.bestWpm;
      isRecord = words > p.bestWpm && words > 0;
      points = pointsFor(words, isRecord);

      tx.set(_sessions.doc(), {
        'words': words,
        'points': points,
        'language': language.code,
        'isRecord': isRecord,
        'durationSeconds': 60,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(_userRef, {
        'pointsTotal': FieldValue.increment(points),
        if (isRecord) 'bestWpm': words,
      });
    });

    final after = await _userRef.get().then(Profile.fromDoc);
    final newlyUnlocked = rewards.docs
        .map(Reward.fromDoc)
        .where((r) => r.isUnlocked(after) && !unlockedBefore.contains(r.id))
        .toList();

    return SessionResult(
      words: words,
      points: points,
      isNewRecord: isRecord,
      previousBest: previousBest,
      newlyUnlocked: newlyUnlocked,
    );
  }

  Stream<List<ReadingSession>> watchSessions({int limit = 50}) => _sessions
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(ReadingSession.fromDoc).toList());

  Future<void> deleteSession(ReadingSession s) async {
    // Punkte der gelöschten Runde wieder abziehen (Rekord bleibt bestehen).
    final batch = _db.batch();
    batch.delete(_sessions.doc(s.id));
    batch.update(_userRef, {'pointsTotal': FieldValue.increment(-s.points)});
    await batch.commit();
  }

  // ------------------------------------------------------------- Geschenke

  Stream<List<Reward>> watchRewards() => _rewards
      .orderBy('threshold')
      .snapshots()
      .map((s) => s.docs.map(Reward.fromDoc).toList());

  Future<void> addReward({
    required String title,
    required String emoji,
    required RewardType type,
    required int threshold,
  }) =>
      _rewards.add({
        'title': title.trim(),
        'emoji': emoji.isEmpty ? '🎁' : emoji,
        'type': type == RewardType.record ? 'record' : 'points',
        'threshold': threshold,
        'redeemed': false,
        'redeemedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteReward(Reward r) => _rewards.doc(r.id).delete();

  /// Eltern bestätigen: Geschenk wurde übergeben.
  /// Bei Punkte-Geschenken werden die Punkte abgezogen.
  Future<void> redeemReward(Reward r) => _db.runTransaction((tx) async {
        final snap = await tx.get(_userRef);
        final p = Profile.fromDoc(snap);
        if (!r.isUnlocked(p)) {
          throw StateError('Dieses Geschenk ist noch nicht freigeschaltet.');
        }
        tx.update(_rewards.doc(r.id), {
          'redeemed': true,
          'redeemedAt': FieldValue.serverTimestamp(),
        });
        if (r.type == RewardType.points) {
          tx.update(_userRef, {'pointsSpent': FieldValue.increment(r.threshold)});
        }
      });
}
