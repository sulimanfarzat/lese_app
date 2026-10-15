import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Struktur in Firestore:
///
/// devices/{uid}                                → welches Handy gehört zu welcher Familie
/// families/{code}                              → PIN-Hash, Punkte-Regel, Mitglieder (Handys)
/// families/{code}/children/{childId}           → Name, Punkte, Rekord, Sprache, übergebene Geschenke
/// families/{code}/children/{childId}/sessions  → jede Lese-Minute als Record
/// families/{code}/rewards/{id}                 → gemeinsame Geschenkliste

final _db = FirebaseFirestore.instance;

String hashPin(String pin) =>
    sha256.convert(utf8.encode('lese_app:$pin')).toString();

/// Normalisiert eine Eingabe wie "k7m-q4p" → "K7MQ4P".
String normalizeCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Anmeldung des Handys bei einer Familie (anlegen, beitreten, verlassen).
class DeviceService {
  DeviceService(this.uid);
  final String uid;

  DocumentReference<Map<String, dynamic>> get _deviceRef =>
      _db.collection('devices').doc(uid);

  static const _prefKey = 'familyCode';

  Future<String?> currentFamilyCode() async {
    final snap = await _deviceRef.get();
    return snap.data()?['familyCode'] as String?;
  }

  /// Familien-Code zusätzlich direkt auf dem Handy speichern.
  static Future<void> _remember(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, code);
    }
  }

  /// Ermittelt die Familie dieses Handys, ohne erneut nach dem Code zu fragen:
  ///  1. Eintrag in Firestore (devices/{uid})
  ///  2. sonst der auf dem Handy gespeicherte Code → still wieder beitreten
  ///     (falls das Handy inzwischen eine neue Anmelde-ID bekommen hat)
  Future<String?> resolveFamilyCode() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_prefKey);

    String? remote;
    try {
      remote = await currentFamilyCode();
    } catch (_) {
      if (local != null) return local; // offline → gespeicherten Code nutzen
      rethrow;
    }

    if (remote != null) {
      if (remote != local) await prefs.setString(_prefKey, remote);
      return remote;
    }
    if (local != null) {
      try {
        final err = await joinFamily(local);
        if (err == null) return local;
        await prefs.remove(_prefKey); // Familie gibt es nicht mehr
      } catch (_) {
        return local;
      }
    }
    return null;
  }

  /// Gut lesbarer Code ohne 0/O/1/I/L: 6 Zeichen ≈ 887 Mio. Möglichkeiten.
  static String _newCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Legt eine neue Familie mit dem ersten Kind an und gibt den Code zurück.
  Future<String> createFamily({
    required String pin,
    required String firstChildName,
  }) async {
    String code;
    DocumentReference<Map<String, dynamic>> famRef;
    // sehr unwahrscheinlich, aber sicher ist sicher: freien Code suchen
    do {
      code = _newCode();
      famRef = _db.collection('families').doc(code);
    } while ((await famRef.get()).exists);

    await famRef.set({
      'pinHash': hashPin(pin),
      'pointsThreshold': 100,
      'recordBonus': 20,
      'members': [uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await famRef.collection('children').add(_newChild(firstChildName, '🦎'));
    await _deviceRef.set({'familyCode': code, 'joinedAt': FieldValue.serverTimestamp()});
    await _remember(code);
    return code;
  }

  /// Tritt einer bestehenden Familie bei. Gibt eine Fehlermeldung oder null zurück.
  Future<String?> joinFamily(String input) async {
    final code = normalizeCode(input);
    if (code.length != 6) return 'Der Code hat 6 Zeichen, z. B. K7M-Q4P.';
    final famRef = _db.collection('families').doc(code);
    final snap = await famRef.get();
    if (!snap.exists) return 'Diese Familie gibt es nicht. Bitte Code prüfen.';
    await famRef.update({
      'members': FieldValue.arrayUnion([uid]),
    });
    await _deviceRef.set({'familyCode': code, 'joinedAt': FieldValue.serverTimestamp()});
    await _remember(code);
    return null;
  }

  /// Handy von der Familie abmelden (Daten der Familie bleiben erhalten).
  Future<void> leaveFamily(String code) async {
    await _db.collection('families').doc(code).update({
      'members': FieldValue.arrayRemove([uid]),
    });
    await _deviceRef.delete();
    await _remember(null);
  }
}

Map<String, dynamic> _newChild(String name, String emoji) => {
      'name': name.trim(),
      'emoji': emoji,
      'pointsTotal': 0,
      'pointsSpent': 0,
      'bestWpm': 0,
      'language': ReadingLanguage.german.code,
      'redeemed': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    };

/// Alle Daten einer Familie – gleich auf allen verbundenen Handys.
class FamilyService {
  FamilyService({required this.uid, required this.code});

  final String uid;
  final String code;

  DocumentReference<Map<String, dynamic>> get _famRef =>
      _db.collection('families').doc(code);
  CollectionReference<Map<String, dynamic>> get _children =>
      _famRef.collection('children');
  CollectionReference<Map<String, dynamic>> get _rewards =>
      _famRef.collection('rewards');
  DocumentReference<Map<String, dynamic>> _childRef(String id) =>
      _children.doc(id);
  CollectionReference<Map<String, dynamic>> _sessions(String childId) =>
      _childRef(childId).collection('sessions');

  // ------------------------------------------------------------- Familie

  Stream<Family> watchFamily() => _famRef.snapshots().map(Family.fromDoc);

  Future<void> setPointRules({required int threshold, required int bonus}) =>
      _famRef.update({'pointsThreshold': threshold, 'recordBonus': bonus});

  Future<void> setPin(String pin) => _famRef.update({'pinHash': hashPin(pin)});

  bool checkPin(Family f, String pin) => f.pinHash == hashPin(pin);

  // ---------------------------------------------------------------- Kinder

  Stream<List<Child>> watchChildren() => _children
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Child.fromDoc).toList());

  Stream<Child> watchChild(String id) =>
      _childRef(id).snapshots().map(Child.fromDoc);

  Future<void> addChild(String name, String emoji) =>
      _children.add(_newChild(name, emoji));

  Future<void> updateChild(String id, {String? name, String? emoji}) =>
      _childRef(id).update({
        if (name != null) 'name': name.trim(),
        if (emoji != null) 'emoji': emoji,
      });

  Future<void> setLanguage(String childId, ReadingLanguage lang) =>
      _childRef(childId).update({'language': lang.code});

  /// Löscht ein Kind samt allen Lese-Runden.
  Future<void> deleteChild(String id) async {
    final sessions = await _sessions(id).get();
    final batch = _db.batch();
    for (final d in sessions.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_childRef(id));
    await batch.commit();
  }

  // ---------------------------------------------------------- Lese-Runden

  /// Liest ein Dokument – vom Server, und wenn das nicht klappt (offline,
  /// schlechtes Netz) aus dem Zwischenspeicher auf dem Handy.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(
      DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return await ref.get().timeout(const Duration(seconds: 6));
    } catch (_) {
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  /// Speichert eine Runde und aktualisiert Punkte + Rekord.
  ///
  /// Bewusst OHNE Transaktion: Transaktionen scheitern bei schlechtem Netz.
  /// Ein Batch wird dagegen sofort auf dem Handy gespeichert und automatisch
  /// hochgeladen, sobald wieder Internet da ist – es geht nichts verloren.
  Future<SessionResult> saveSession({
    required String childId,
    required int words,
    required ReadingLanguage language,
  }) async {
    var rewards = <Reward>[];
    try {
      rewards = (await _rewards.get().timeout(const Duration(seconds: 6)))
          .docs
          .map(Reward.fromDoc)
          .toList();
    } catch (_) {/* ohne Geschenkliste trotzdem speichern */}

    final family = Family.fromDoc(await _getDoc(_famRef));
    final before = Child.fromDoc(await _getDoc(_childRef(childId)));

    final isRecord = words > before.bestWpm && words > 0;
    final points = family.pointsFor(words, isRecord: isRecord);

    final batch = _db.batch();
    batch.set(_sessions(childId).doc(), {
      'words': words,
      'points': points,
      'language': language.code,
      'isRecord': isRecord,
      'durationSeconds': 60,
      'device': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_childRef(childId), {
      'pointsTotal': FieldValue.increment(points),
      if (isRecord) 'bestWpm': words,
    });

    var savedOnline = true;
    try {
      await batch.commit().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Kein Netz: Firestore hat die Runde lokal gespeichert und lädt sie
      // automatisch hoch, sobald das Handy wieder online ist.
      savedOnline = false;
    }

    final after = Child(
      id: before.id,
      name: before.name,
      emoji: before.emoji,
      pointsTotal: before.pointsTotal + points,
      pointsSpent: before.pointsSpent,
      bestWpm: isRecord ? words : before.bestWpm,
      language: before.language,
      redeemed: before.redeemed,
    );
    return SessionResult(
      words: words,
      points: points,
      isNewRecord: isRecord,
      previousBest: before.bestWpm,
      newlyUnlocked: rewards
          .where((r) => r.isUnlockedFor(after) && !r.isUnlockedFor(before))
          .toList(),
      pointsThreshold: family.pointsThreshold,
      savedOnline: savedOnline,
    );
  }

  /// Eltern korrigieren die Wortzahl einer Runde (z. B. wenn die
  /// Spracherkennung zu wenig gezählt hat). Punkte werden neu berechnet,
  /// ein höherer Wert kann auch einen neuen Rekord ergeben.
  /// Ein Rekord wird dabei nie verringert.
  Future<void> correctSessionWords(
      String childId, ReadingSession s, int newWords) async {
    final family = Family.fromDoc(await _getDoc(_famRef));
    final child = Child.fromDoc(await _getDoc(_childRef(childId)));
    final beatsRecord = newWords > child.bestWpm;
    final isRecord = s.isRecord || beatsRecord;
    final newPoints = family.pointsFor(newWords, isRecord: isRecord);

    final batch = _db.batch();
    batch.update(_sessions(childId).doc(s.id), {
      'words': newWords,
      'points': newPoints,
      'isRecord': isRecord,
      'correctedFrom': s.words,
    });
    batch.update(_childRef(childId), {
      'pointsTotal': FieldValue.increment(newPoints - s.points),
      if (beatsRecord) 'bestWpm': newWords,
    });
    await batch.commit();
  }

  Stream<List<ReadingSession>> watchSessions(String childId, {int limit = 50}) =>
      _sessions(childId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ReadingSession.fromDoc).toList());

  /// Löscht eine Runde (z. B. Fehlmessung) und zieht ihre Punkte wieder ab.
  Future<void> deleteSession(String childId, ReadingSession s) async {
    final batch = _db.batch();
    batch.delete(_sessions(childId).doc(s.id));
    batch.update(_childRef(childId), {'pointsTotal': FieldValue.increment(-s.points)});
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
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteReward(Reward r) => _rewards.doc(r.id).delete();

  /// Eltern bestätigen: Geschenk wurde diesem Kind übergeben.
  /// Bei Punkte-Geschenken werden die Punkte des Kindes abgezogen.
  Future<void> redeemReward(Reward r, String childId) =>
      _db.runTransaction((tx) async {
        final ref = _childRef(childId);
        final child = Child.fromDoc(await tx.get(ref));
        if (!r.isUnlockedFor(child)) {
          throw StateError('Dieses Geschenk ist für ${child.name} noch nicht freigeschaltet.');
        }
        tx.update(ref, {
          'redeemed.${r.id}': FieldValue.serverTimestamp(),
          if (r.type == RewardType.points)
            'pointsSpent': FieldValue.increment(r.threshold),
        });
      });
}
