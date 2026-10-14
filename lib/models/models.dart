import 'package:cloud_firestore/cloud_firestore.dart';

/// Sprache, in der das Kind liest.
enum ReadingLanguage {
  german('de', 'Deutsch', '🇩🇪'),
  arabic('ar', 'العربية', '🇸🇾');

  const ReadingLanguage(this.code, this.label, this.flag);
  final String code;
  final String label;
  final String flag;

  static ReadingLanguage fromCode(String? code) =>
      ReadingLanguage.values.firstWhere((l) => l.code == code,
          orElse: () => ReadingLanguage.german);
}

/// Profil des Kindes (ein Dokument pro Gerät/Konto).
class Profile {
  Profile({
    required this.childName,
    required this.pointsTotal,
    required this.pointsSpent,
    required this.bestWpm,
    required this.pinHash,
    required this.language,
    required this.pointsThreshold,
    required this.recordBonus,
  });

  final String childName;
  final int pointsTotal; // alle jemals gesammelten Punkte
  final int pointsSpent; // für Geschenke eingelöste Punkte
  final int bestWpm; // Rekord: Wörter pro Minute
  final String? pinHash; // SHA-256 der Eltern-PIN
  final ReadingLanguage language;
  final int pointsThreshold; // ab so vielen Wörtern/Minute gibt es Punkte
  final int recordBonus; // Bonuspunkte bei neuem Rekord

  /// Punkte-Regel: ab der Schwelle 1 Punkt, danach +1 pro weiterem Wort
  /// (Schwelle 100: 100 → 1, 106 → 7). Neuer Rekord: + Bonus.
  int pointsFor(int words, {required bool isRecord}) {
    final base = words >= pointsThreshold ? words - pointsThreshold + 1 : 0;
    return base + (isRecord ? recordBonus : 0);
  }

  int get pointsAvailable => pointsTotal - pointsSpent;

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Profile(
      childName: (d['childName'] as String?) ?? '',
      pointsTotal: (d['pointsTotal'] as num?)?.toInt() ?? 0,
      pointsSpent: (d['pointsSpent'] as num?)?.toInt() ?? 0,
      bestWpm: (d['bestWpm'] as num?)?.toInt() ?? 0,
      pinHash: d['pinHash'] as String?,
      language: ReadingLanguage.fromCode(d['language'] as String?),
      pointsThreshold: (d['pointsThreshold'] as num?)?.toInt() ?? 100,
      recordBonus: (d['recordBonus'] as num?)?.toInt() ?? 20,
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
      words: (d['words'] as num?)?.toInt() ?? 0,
      points: (d['points'] as num?)?.toInt() ?? 0,
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

class Reward {
  Reward({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    required this.threshold,
    required this.redeemed,
    this.redeemedAt,
  });

  final String id;
  final String title;
  final String emoji;
  final RewardType type;
  final int threshold; // Punkte-Preis oder Wörter/Minute-Ziel
  final bool redeemed;
  final DateTime? redeemedAt;

  /// Darf das Kind dieses Geschenk gerade bekommen?
  bool isUnlocked(Profile p) {
    if (redeemed) return false;
    return switch (type) {
      RewardType.points => p.pointsAvailable >= threshold,
      RewardType.record => p.bestWpm >= threshold,
    };
  }

  /// Fortschritt 0.0 – 1.0 für die Anzeige.
  double progress(Profile p) {
    if (threshold <= 0) return 1;
    final current = type == RewardType.points ? p.pointsAvailable : p.bestWpm;
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
      threshold: (d['threshold'] as num?)?.toInt() ?? 0,
      redeemed: (d['redeemed'] as bool?) ?? false,
      redeemedAt: (d['redeemedAt'] as Timestamp?)?.toDate(),
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
  });

  final int words;
  final int points;
  final bool isNewRecord;
  final int previousBest;
  final List<Reward> newlyUnlocked;
  final int pointsThreshold;
}
