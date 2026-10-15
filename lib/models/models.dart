import 'package:cloud_firestore/cloud_firestore.dart';

/// Sprache, in der das Kind liest (derzeit nur Deutsch).
enum ReadingLanguage {
  german('de', 'Deutsch', '🇩🇪');

  const ReadingLanguage(this.code, this.label, this.flag);
  final String code;
  final String label;
  final String flag;

  static ReadingLanguage fromCode(String? code) =>
      ReadingLanguage.values.firstWhere((l) => l.code == code,
          orElse: () => ReadingLanguage.german);
}

int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;

/// Familie – wird über den Familien-Code von mehreren Handys geteilt.
class Family {
  Family({
    required this.code,
    required this.pinHash,
    required this.pointsThreshold,
    required this.recordBonus,
  });

  final String code; // Dokument-ID, z. B. "K7MQ4P" (angezeigt als K7M-Q4P)
  final String? pinHash;
  final int pointsThreshold; // ab so vielen Wörtern/Minute gibt es Punkte
  final int recordBonus; // Bonuspunkte bei neuem Rekord

  String get displayCode =>
      code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

  /// Punkte-Regel: ab der Schwelle 1 Punkt, danach +1 pro weiterem Wort
  /// (Schwelle 100: 100 → 1, 106 → 7). Neuer Rekord: + Bonus.
  int pointsFor(int words, {required bool isRecord}) {
    final base = words >= pointsThreshold ? words - pointsThreshold + 1 : 0;
    return base + (isRecord ? recordBonus : 0);
  }

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Family(
      code: doc.id,
      pinHash: d['pinHash'] as String?,
      pointsThreshold: _int(d['pointsThreshold'], 100),
      recordBonus: _int(d['recordBonus'], 20),
    );
  }
}

/// Ein Kind in der Familie mit eigenen Punkten und Rekorden.
class Child {
  Child({
    required this.id,
    required this.name,
    required this.emoji,
    required this.pointsTotal,
    required this.pointsSpent,
    required this.bestWpm,
    required this.language,
    required this.redeemed,
  });

  final String id;
  final String name;
  final String emoji;
  final int pointsTotal; // alle jemals gesammelten Punkte
  final int pointsSpent; // für Geschenke eingelöste Punkte
  final int bestWpm; // Rekord: Wörter pro Minute
  final ReadingLanguage language;
  final Map<String, DateTime> redeemed; // Geschenk-ID → wann übergeben

  int get pointsAvailable => pointsTotal - pointsSpent;

  factory Child.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final r = (d['redeemed'] as Map<String, dynamic>?) ?? {};
    return Child(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Kind',
      emoji: (d['emoji'] as String?) ?? '🦎',
      pointsTotal: _int(d['pointsTotal']),
      pointsSpent: _int(d['pointsSpent']),
      bestWpm: _int(d['bestWpm']),
      language: ReadingLanguage.fromCode(d['language'] as String?),
      redeemed: {
        for (final e in r.entries)
          e.key: (e.value is Timestamp)
              ? (e.value as Timestamp).toDate()
              : DateTime.now(),
      },
    );
  }
}

/// Eine Lese-Runde (1 Minute).
class ReadingSession {
  ReadingSession({
    required this.id,
    required this.words,
    required this.points,
    required this.language,
    required this.createdAt,
    required this.isRecord,
  });

  final String id;
  final int words;
  final int points;
  final ReadingLanguage language;
  final DateTime createdAt;
  final bool isRecord;

  factory ReadingSession.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ReadingSession(
      id: doc.id,
      words: _int(d['words']),
      points: _int(d['points']),
      language: ReadingLanguage.fromCode(d['language'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRecord: (d['isRecord'] as bool?) ?? false,
    );
  }
}

/// Art des Geschenks:
/// - [points]: kostet Punkte, wird mit gesammelten Punkten "gekauft"
/// - [record]: wird freigeschaltet, wenn ein Wörter-pro-Minute-Ziel erreicht ist
enum RewardType { points, record }

/// Geschenk aus der gemeinsamen Familien-Liste.
/// Ob es freigeschaltet / übergeben ist, gilt jeweils pro Kind.
class Reward {
  Reward({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    required this.threshold,
  });

  final String id;
  final String title;
  final String emoji;
  final RewardType type;
  final int threshold; // Punkte-Preis oder Wörter/Minute-Ziel

  bool isRedeemedBy(Child c) => c.redeemed.containsKey(id);

  /// Darf dieses Kind das Geschenk gerade bekommen?
  bool isUnlockedFor(Child c) {
    if (isRedeemedBy(c)) return false;
    return switch (type) {
      RewardType.points => c.pointsAvailable >= threshold,
      RewardType.record => c.bestWpm >= threshold,
    };
  }

  /// Fortschritt 0.0 – 1.0 für die Anzeige.
  double progress(Child c) {
    if (threshold <= 0) return 1;
    final current = type == RewardType.points ? c.pointsAvailable : c.bestWpm;
    return (current / threshold).clamp(0, 1).toDouble();
  }

  String describe() => type == RewardType.points
      ? '$threshold Punkte'
      : '$threshold Wörter in 1 Minute';

  factory Reward.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Reward(
      id: doc.id,
      title: (d['title'] as String?) ?? 'Geschenk',
      emoji: (d['emoji'] as String?) ?? '🎁',
      type: (d['type'] == 'record') ? RewardType.record : RewardType.points,
      threshold: _int(d['threshold']),
    );
  }
}

/// Ergebnis, das nach dem Speichern einer Runde angezeigt wird.
class SessionResult {
  SessionResult({
    required this.words,
    required this.points,
    required this.isNewRecord,
    required this.previousBest,
    required this.newlyUnlocked,
    required this.pointsThreshold,
    this.savedOnline = true,
  });

  final int words;
  final int points;
  final bool isNewRecord;
  final int previousBest;
  final List<Reward> newlyUnlocked;
  final int pointsThreshold;
  final bool savedOnline; // false = lokal gespeichert, wird später hochgeladen
}
