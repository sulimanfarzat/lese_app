import 'dart:math';

/// Reine Zähl-Logik (ohne Mikrofon), damit sie mit Tests geprüft werden kann.
///
/// Die Android-Spracherkennung liefert laufend Teilergebnisse für den
/// „aktuellen Satz“. Nach einer kurzen Lesepause beginnt sie oft intern einen
/// NEUEN Satz – ohne Bescheid zu geben. Das Teilergebnis enthält dann nur noch
/// die neuen Wörter. Würde man es einfach übernehmen, wären alle vorherigen
/// Wörter weg („fängt von vorne an“).
///
/// Darum erkennt [WordTally] solche Satzwechsel und schreibt den alten Satz
/// vorher gut. Außerdem wird die angezeigte Zahl nie kleiner.
class WordTally {
  int _committed = 0; // Wörter aus abgeschlossenen Sätzen
  final List<String> _committedTexts = [];
  List<String> _current = []; // Wörter des aktuellen Satzes
  int _peak = 0; // höchster bisher angezeigter Stand
  int _segment = 0; // Nummer des aktuellen Erkennungs-Abschnitts
  final Map<int, List<String>> _lastOfSegment = {}; // für verspätete Ergebnisse

  /// Gezählte Wörter – wird nie kleiner.
  int get total => max(_peak, _committed + _current.length);

  String get text => [..._committedTexts, _current.join(' ')]
      .where((t) => t.isNotEmpty)
      .join(' ');

  int get segment => _segment;

  void reset() {
    _committed = 0;
    _committedTexts.clear();
    _current = [];
    _peak = 0;
    _segment++;
    _lastOfSegment.clear();
  }

  /// Neues (Teil-)Ergebnis der Spracherkennung für Abschnitt [segment].
  void addResult(String text, {required bool isFinal, required int segment}) {
    final words = splitWords(text);

    if (segment != _segment) {
      _lateResult(words, segment);
      return;
    }
    if (words.isEmpty) {
      // Leeres Teilergebnis löscht nichts.
      if (isFinal) closeSegment();
      return;
    }
    if (_current.isNotEmpty && isNewUtterance(_current, words)) {
      _commitCurrent();
    }
    _current = words;
    _updatePeak();
    if (isFinal) closeSegment();
  }

  /// Abschnitt beenden (Erkennung hat gestoppt) und neuen beginnen.
  /// Gibt die Nummer des neuen Abschnitts zurück.
  int closeSegment() {
    _lastOfSegment[_segment] = List.of(_current);
    _commitCurrent();
    _segment++;
    return _segment;
  }

  void _commitCurrent() {
    if (_current.isEmpty) return;
    _committed += _current.length;
    _committedTexts.add(_current.join(' '));
    _current = [];
    _updatePeak();
  }

  /// Ergebnis eines schon beendeten Abschnitts: nur zusätzliche Wörter
  /// desselben Satzes nachtragen – nie doppelt zählen.
  void _lateResult(List<String> words, int segment) {
    final last = _lastOfSegment[segment];
    if (last == null || words.length <= last.length) return;
    if (last.isNotEmpty && isNewUtterance(last, words)) return;
    final extra = words.sublist(last.length);
    _committed += extra.length;
    _committedTexts.add(extra.join(' '));
    _lastOfSegment[segment] = words;
    _updatePeak();
  }

  void _updatePeak() => _peak = max(_peak, _committed + _current.length);

  // ------------------------------------------------------------ Hilfen

  static String _norm(String w) => w.toLowerCase();

  /// Ist [next] ein neuer Satz (statt einer Verbesserung/Verlängerung von [prev])?
  static bool isNewUtterance(List<String> prev, List<String> next) {
    if (prev.isEmpty || next.isEmpty) return false;
    // Großer Einbruch der Wortzahl → die Erkennung hat neu angefangen.
    if (prev.length >= 3 && next.length < prev.length * 0.5) return true;
    // Gleicher Anfang → derselbe Satz.
    if (_norm(prev.first) == _norm(next.first)) return false;
    // Sonst: Wie viele Wörter haben beide gemeinsam?
    final pool = prev.map(_norm).toList();
    var hits = 0;
    for (final w in next.map(_norm)) {
      final i = pool.indexOf(w);
      if (i >= 0) {
        hits++;
        pool.removeAt(i);
      }
    }
    return hits < min(prev.length, next.length) * 0.5;
  }

  /// Zerlegt Text in Wörter (Satzzeichen werden ignoriert).
  static List<String> splitWords(String text) => text
      .replaceAll(RegExp(r'[.,!?;:"()\[\]{}«»„“”…\-–—]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.trim().isNotEmpty)
      .toList();
}
